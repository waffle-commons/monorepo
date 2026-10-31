#!/usr/bin/env python3
"""scripts/images-pin.py — pin every base and service image to a digest.

A tag such as `redis:7-alpine` or `composer:latest` moves: the next pull may
bring a different image, so a build is neither reproducible nor offline-safe.
A digest (`redis:7-alpine@sha256:…`) names one image for good while the tag
stays readable. This script finds the `FROM` lines of every Dockerfile and the
`image:` lines of every compose file in the template apps and the bench rig
(files git ignores, such as a generated app's own compose file, are left out),
and reports each reference that has no digest; `--write` pins it to the digest of the image
this machine already pulled (`docker image inspect`), so what is pinned is what
was tested. `--pull` fetches an image that is not here yet.

A `FROM` made of build arguments (`dunglas/frankenphp:${FRANKEN_VERSION}-…`)
is read with the defaults of the `ARG` lines above the first `FROM`, so it pins
through an `ARG …_DIGEST`. A pinned digest only says which image a build gets:
Docker resolves `tag@digest` by the digest alone, so a version bump that misses
the digest still builds the old image. `--verify` checks every pinned reference
against the image its tag names on this machine (`--pull` fetches it first),
and `--write` re-pins a stale digest where it is written: the `FROM` or `image:`
line, or the `ARG` line that carries it.

Skipped, and said so: images built locally (`waffle-commons:workspace`,
`waffle-app:dev`, `waffle-bench-engine-a`), build stages (`FROM base AS dev`)
and build arguments without a default.

Usage:   scripts/images-pin.py [--write] [--pull] [--verify] [file…]
Exit:    0 when every pinnable reference has a digest (or was pinned), and with
         --verify the digest of the image its tag names here; 1 otherwise.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCAN_DIRS = ("workspace", "skeleton", "academy", "bench")
LOCAL_IMAGES = re.compile(r"^(waffle-[\w-]*|waffle-commons)(?::|$)")
FROM = re.compile(r"^(\s*FROM\s+(?:--platform=\S+\s+)?)(\S+)(.*)$", re.IGNORECASE)
IMAGE = re.compile(r"^(\s*image:\s*)(['\"]?)([^'\"\s#]+)\2(.*)$")
ARG = re.compile(r"^\s*ARG\s+(\w+)(?:=(['\"]?)(.*?)\2)?\s*$", re.IGNORECASE)
VARIABLE = re.compile(r"\$\{(\w+)(?::-([^}]*))?\}|\$(\w+)")
DIGEST = re.compile(r"sha256:[0-9a-f]{64}")


def ignored(path: pathlib.Path) -> bool:
    """A file git ignores is not built from: the bench's generated Symfony apps carry Flex's own compose files."""
    run = subprocess.run(["git", "-C", str(path.parent), "check-ignore", "-q", path.name], capture_output=True)
    return run.returncode == 0


def files() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    for top in SCAN_DIRS:
        base = ROOT / top
        for path in base.rglob("*"):
            parts = set(path.relative_to(ROOT).parts)
            if parts & {"vendor", "node_modules", ".git", "var"} or not path.is_file():
                continue
            if path.name.startswith("Dockerfile") or re.fullmatch(r"(docker-)?compose(\.[\w-]+)?\.ya?ml", path.name):
                if not ignored(path):
                    found.append(path)
    return sorted(found)


def digests_of(ref: str, pull: bool) -> list[str]:
    """Every repository digest of the image `ref` names here: one image can carry several (an official
    image's `8.5-cli` and `8.5.12-cli` tags are two indexes over the same platform images)."""
    def inspect() -> list[str]:
        run = subprocess.run(["docker", "image", "inspect", "--format", "{{json .RepoDigests}}", ref], capture_output=True, text=True)
        if run.returncode != 0:
            return []
        repo = ref.split("@")[0].rsplit(":", 1)[0] if ":" in ref.split("/")[-1] else ref
        found: list[str] = []
        for item in json.loads(run.stdout or "[]"):
            name, _, digest = item.partition("@")
            if name.split("/")[-1] == repo.split("/")[-1] or name.endswith(repo):
                found.append(digest)
        return found

    digests = inspect()
    if not digests and pull:
        subprocess.run(["docker", "pull", "--quiet", ref], capture_output=True, text=True)
        digests = inspect()
    return digests


def digest_of(ref: str, pull: bool) -> str | None:
    digests = digests_of(ref, pull)
    return digests[0] if digests else None


def expand(ref: str, defaults: dict[str, str]) -> tuple[str, list[str], list[str]]:
    """Substitute the ARG defaults into a FROM reference: (expanded, variables used, variables without a default)."""
    used: list[str] = []
    missing: list[str] = []

    def substitute(match: re.Match[str]) -> str:
        name = match.group(1) or match.group(3)
        used.append(name)
        if defaults.get(name):
            return defaults[name]
        if match.group(2) is not None:
            return match.group(2)
        if name in defaults:
            return ""
        missing.append(name)
        return match.group(0)

    return VARIABLE.sub(substitute, ref), used, missing


def main() -> int:
    parser = argparse.ArgumentParser(description="Pin base and service images to digests")
    parser.add_argument("files", nargs="*", type=pathlib.Path)
    parser.add_argument("--write", action="store_true", help="pin each unpinned reference in place (with --verify, re-pin a stale digest)")
    parser.add_argument("--pull", action="store_true", help="pull an image this machine does not have yet")
    parser.add_argument("--verify", action="store_true", help="check each pinned digest against the image its tag names here")
    args = parser.parse_args()

    targets = [p.resolve() for p in args.files] or files()
    stages: set[str] = set()
    unpinned = 0
    stale = 0
    argless = 0
    for path in targets:
        lines = path.read_text().splitlines(keepends=True)
        changed = False
        rel = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
        dockerfile = path.name.startswith("Dockerfile")
        # Only the ARGs above the first FROM are in scope for a FROM line.
        defaults: dict[str, str] = {}
        arg_lines: dict[str, int] = {}
        seen_from = False
        for i, line in enumerate(lines):
            arg = ARG.match(line) if dockerfile and not seen_from else None
            if arg is not None:
                if arg.group(3) is not None:
                    defaults[arg.group(1)] = arg.group(3)
                    arg_lines[arg.group(1)] = i
                continue
            match = FROM.match(line) if dockerfile else IMAGE.match(line)
            if match is None:
                continue
            ref = match.group(2) if dockerfile else match.group(3)
            if not dockerfile and ref.startswith("!"):
                # A YAML tag (`image: !reset null`) removes the image in an override; it names none.
                continue
            if dockerfile:
                seen_from = True
                stage = re.search(r"\bAS\s+(\S+)", match.group(3), re.IGNORECASE)
                if stage:
                    stages.add(stage.group(1).lower())
            where = f"{rel}:{i + 1}"
            from_arguments = "$" in ref
            carrier, holder = i, ""
            if from_arguments:
                ref, used, missing = expand(ref, defaults)
                if missing:
                    print(f"  · {where}  {ref} (build arguments without a default: {', '.join(missing)})")
                    continue
                holder = next((name for name in used if DIGEST.search(defaults.get(name, ""))), "")
                if holder:
                    carrier = arg_lines[holder]
            via = f" through ARG {holder}" if holder else ""
            if "@sha256:" in ref:
                image, _, pinned = ref.partition("@")
                if not args.verify:
                    print(f"  ✓ {where}  {image} (pinned{via})")
                    continue
                here = digests_of(image, args.pull)
                if not here:
                    print(f"  ✗ {where}  {image}: not pulled here, so the pin cannot be checked (rerun with --pull)")
                    stale += 1
                    continue
                if pinned in here:
                    print(f"  ✓ {where}  {image} (pinned{via}, matches the image here)")
                    continue
                if not args.write:
                    print(f"  ✗ {where}  {image} is {here[0]} here; the pin{via} says {pinned} (rerun with --write to re-pin)")
                    stale += 1
                    continue
                lines[carrier] = lines[carrier].replace(pinned, here[0])
                if holder:
                    defaults[holder] = defaults[holder].replace(pinned, here[0])
                changed = True
                print(f"  ↓ {where}  {image}@{here[0]}" + (f" (ARG {holder}, line {carrier + 1})" if holder else ""))
                continue
            if ref.lower() in stages or ref == "scratch":
                continue
            if from_arguments:
                print(f"  ✗ {where}  {ref}: built from arguments with no digest (pin through an ARG …_DIGEST)")
                argless += 1
                continue
            if LOCAL_IMAGES.match(ref):
                continue
            digest = digest_of(ref, args.pull)
            if digest is None:
                print(f"  ✗ {where}  {ref}: not pulled here (rerun with --pull)")
                unpinned += 1
                continue
            if not args.write:
                print(f"  ✗ {where}  {ref} → {ref}@{digest}")
                unpinned += 1
                continue
            pinned = f"{ref}@{digest}"
            if path.name.startswith("Dockerfile"):
                lines[i] = f"{match.group(1)}{pinned}{match.group(3)}\n"
            else:
                lines[i] = f"{match.group(1)}{match.group(2)}{pinned}{match.group(2)}{match.group(4)}\n"
            changed = True
            print(f"  ↓ {where}  {pinned}")
        if changed:
            path.write_text("".join(lines))
    if unpinned:
        print(f"✗ {unpinned} reference(s) without a digest" + ("" if args.write else " (rerun with --write to pin)"))
    if argless:
        print(f"✗ {argless} reference(s) built from arguments with no digest (add an ARG …_DIGEST by hand)")
    if stale:
        print(f"✗ {stale} pinned reference(s) not checked against, or not matching, the image their tag names here")
    if unpinned or argless or stale:
        return 1
    print("✓ every pinnable image reference has a digest" + (", and each matches the image its tag names here" if args.verify else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())

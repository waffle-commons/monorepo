#!/usr/bin/env python3
"""scripts/images-pin.py — pin every base and service image to a digest.

A tag such as `redis:7-alpine` or `composer:latest` moves: the next pull may
bring a different image, so a build is neither reproducible nor offline-safe.
A digest (`redis:7-alpine@sha256:…`) names one image for good while the tag
stays readable. This script finds the `FROM` lines of every Dockerfile and the
`image:` lines of every compose file in the template apps, and reports each
reference that has no digest; `--write` pins it to the digest of the image
this machine already pulled (`docker image inspect`), so what is pinned is what
was tested. `--pull` fetches an image that is not here yet.

Skipped, and said so: images built locally (`waffle-commons:workspace`,
`waffle-app:dev`), build stages (`FROM base AS dev`) and references made of
build arguments (`dunglas/frankenphp:${FRANKEN_VERSION}-…`), which pin through
an `ARG …_DIGEST` instead.

Usage:   scripts/images-pin.py [--write] [--pull] [file…]
Exit:    0 when every pinnable reference has a digest (or was pinned), 1 otherwise.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCAN_DIRS = ("workspace", "skeleton", "academy")
LOCAL_IMAGES = re.compile(r"^(waffle-[\w-]*|waffle-commons):")
FROM = re.compile(r"^(\s*FROM\s+(?:--platform=\S+\s+)?)(\S+)(.*)$", re.IGNORECASE)
IMAGE = re.compile(r"^(\s*image:\s*)(['\"]?)([^'\"\s#]+)\2(.*)$")


def files() -> list[pathlib.Path]:
    found: list[pathlib.Path] = []
    for top in SCAN_DIRS:
        base = ROOT / top
        for path in base.rglob("*"):
            parts = set(path.relative_to(ROOT).parts)
            if parts & {"vendor", "node_modules", ".git", "var"} or not path.is_file():
                continue
            if path.name.startswith("Dockerfile") or re.fullmatch(r"(docker-)?compose(\.[\w-]+)?\.ya?ml", path.name):
                found.append(path)
    return sorted(found)


def digest_of(ref: str, pull: bool) -> str | None:
    def inspect() -> str | None:
        run = subprocess.run(["docker", "image", "inspect", "--format", "{{json .RepoDigests}}", ref], capture_output=True, text=True)
        if run.returncode != 0:
            return None
        repo = ref.split("@")[0].rsplit(":", 1)[0] if ":" in ref.split("/")[-1] else ref
        for item in json.loads(run.stdout or "[]"):
            name, _, digest = item.partition("@")
            if name.split("/")[-1] == repo.split("/")[-1] or name.endswith(repo):
                return digest
        return None

    digest = inspect()
    if digest is None and pull:
        subprocess.run(["docker", "pull", "--quiet", ref], capture_output=True, text=True)
        digest = inspect()
    return digest


def main() -> int:
    parser = argparse.ArgumentParser(description="Pin base and service images to digests")
    parser.add_argument("files", nargs="*", type=pathlib.Path)
    parser.add_argument("--write", action="store_true", help="pin each unpinned reference in place")
    parser.add_argument("--pull", action="store_true", help="pull an image this machine does not have yet")
    args = parser.parse_args()

    targets = [p.resolve() for p in args.files] or files()
    stages: set[str] = set()
    unpinned = 0
    for path in targets:
        lines = path.read_text().splitlines(keepends=True)
        changed = False
        rel = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
        for i, line in enumerate(lines):
            match = FROM.match(line) if path.name.startswith("Dockerfile") else IMAGE.match(line)
            if match is None:
                continue
            ref = match.group(2) if path.name.startswith("Dockerfile") else match.group(3)
            if path.name.startswith("Dockerfile"):
                stage = re.search(r"\bAS\s+(\S+)", match.group(3), re.IGNORECASE)
                if stage:
                    stages.add(stage.group(1).lower())
            where = f"{rel}:{i + 1}"
            if "@sha256:" in ref:
                print(f"  ✓ {where}  {ref.split('@')[0]} (pinned)")
                continue
            if ref.lower() in stages or ref == "scratch":
                continue
            if "$" in ref:
                print(f"  · {where}  {ref} (build arguments: pin through an ARG …_DIGEST)")
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
        return 1
    print("✓ every pinnable image reference has a digest")
    return 0


if __name__ == "__main__":
    sys.exit(main())

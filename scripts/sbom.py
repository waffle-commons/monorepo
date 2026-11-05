#!/usr/bin/env python3
"""scripts/sbom.py — a CycloneDX 1.5 SBOM for a component, from its composer.lock.

What a release ships depends on, as a machine-readable bill of materials:
every locked package with its version, a purl (pkg:composer/vendor/name@version),
its licences, the dist checksum Composer recorded, and whether it is a runtime
dependency ("required") or a development one ("excluded"). Read-only: it
parses the lock file and writes one JSON file, with no network and no PHP.

Usage:   scripts/sbom.py <component…> | --all [--out-dir DIR] [--version X]
         (default output: tmp/sbom/<component>-<version>.cdx.json)
Exit:    0 on success, 1 when a component has no composer.lock.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent


def components() -> list[str]:
    out = subprocess.run([str(ROOT / "scripts/list-components.sh")], capture_output=True, text=True, check=True)
    return [line.strip() for line in out.stdout.splitlines() if line.strip()]


def release_version() -> str:
    """The version being released: pre-release/<version> on the umbrella, else 'dev'."""
    branch = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True).stdout.strip()
    match = re.fullmatch(r"pre-release/(\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)", branch)
    return match.group(1) if match else "dev"


def purl(name: str, version: str) -> str:
    return f"pkg:composer/{name}@{version}"


def entry(package: dict, scope: str) -> dict:
    name = str(package.get("name", ""))
    version = str(package.get("version", "")).removeprefix("v")
    item: dict = {
        "type": "library",
        "bom-ref": purl(name, version),
        "group": name.split("/")[0] if "/" in name else "",
        "name": name.split("/")[-1],
        "version": version,
        "purl": purl(name, version),
        "scope": scope,
    }
    licences = package.get("license") or []
    if licences:
        item["licenses"] = [{"license": {"id": lic}} if re.fullmatch(r"[A-Za-z0-9.\-+]+", lic) else {"license": {"name": lic}} for lic in licences]
    dist = package.get("dist") or {}
    if dist.get("shasum"):
        item["hashes"] = [{"alg": "SHA-1", "content": dist["shasum"]}]
    refs = []
    source = package.get("source") or {}
    if source.get("url"):
        refs.append({"type": "vcs", "url": source["url"]})
    if dist.get("url"):
        refs.append({"type": "distribution", "url": dist["url"]})
    if refs:
        item["externalReferences"] = refs
    return item


def sbom_of(component: str, version: str) -> dict:
    base = ROOT / component
    lock_path = base / "composer.lock"
    manifest = json.loads((base / "composer.json").read_text())
    lock = json.loads(lock_path.read_text())
    name = str(manifest.get("name", f"waffle-commons/{component}"))
    runtime = [entry(p, "required") for p in lock.get("packages", [])]
    dev = [entry(p, "excluded") for p in lock.get("packages-dev", [])]
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
            "tools": {"components": [{"type": "application", "name": "waffle-commons scripts/sbom.py"}]},
            "component": {
                "type": "library",
                "bom-ref": purl(name, version),
                "name": name,
                "version": version,
                "purl": purl(name, version),
                "licenses": [{"license": {"id": lic}} for lic in manifest.get("license", []) if isinstance(manifest.get("license"), list)]
                or ([{"license": {"id": manifest["license"]}}] if isinstance(manifest.get("license"), str) else []),
            },
            "properties": [
                {"name": "composer:lock:content-hash", "value": str(lock.get("content-hash", ""))},
                {"name": "composer:lock:sha256", "value": hashlib.sha256(lock_path.read_bytes()).hexdigest()},
            ],
        },
        "components": sorted(runtime + dev, key=lambda c: c["purl"]),
        "dependencies": [{"ref": purl(name, version), "dependsOn": [c["bom-ref"] for c in runtime]}],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="CycloneDX 1.5 SBOM from a component's composer.lock")
    parser.add_argument("components", nargs="*")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--out-dir", default=str(ROOT / "tmp/sbom"))
    parser.add_argument("--version", default="")
    args = parser.parse_args()

    known = components()
    targets = known if args.all else args.components
    if not targets:
        parser.error("name one or more components, or --all")
    version = args.version or release_version()
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    failed = 0
    for component in targets:
        if component not in known:
            print(f"✗ unknown component: {component}", file=sys.stderr)
            failed = 1
            continue
        if not (ROOT / component / "composer.lock").is_file():
            if not args.all:
                print(f"✗ {component}: no composer.lock (run composer install in waffle-dev first)", file=sys.stderr)
                failed = 1
            continue
        bom = sbom_of(component, version)
        path = out_dir / f"{component}-{version}.cdx.json"
        path.write_text(json.dumps(bom, indent=2) + "\n")
        runtime = sum(1 for c in bom["components"] if c["scope"] == "required")
        print(f"✓ {component}: {runtime} runtime + {len(bom['components']) - runtime} dev packages → {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}")
    return failed


if __name__ == "__main__":
    sys.exit(main())

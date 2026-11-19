#!/usr/bin/env python3
"""Fail when catalog rows are incomplete or missing from the README."""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "id",
    "threat",
    "owasp",
    "control",
    "attack_fixture",
    "happy_path",
    "expect",
    "proof",
    "residual",
    "operability",
)


def main() -> int:
    catalog = yaml.safe_load((ROOT / "catalog" / "controls.yaml").read_text())
    readme = (ROOT / "README.md").read_text()
    rows = catalog.get("controls") if isinstance(catalog, dict) else None
    if not isinstance(rows, list) or not rows:
        print("catalog/controls.yaml has no controls", file=sys.stderr)
        return 1
    failed = False
    seen: set[str] = set()
    for row in rows:
        control_id = str(row.get("id", ""))
        if not control_id or control_id in seen:
            print(f"missing or duplicate id: {control_id!r}", file=sys.stderr)
            failed = True
            continue
        seen.add(control_id)
        for field in REQUIRED:
            if not str(row.get(field, "")).strip():
                print(f"{control_id}: empty {field}", file=sys.stderr)
                failed = True
        for field in ("control", "attack_fixture", "happy_path"):
            raw = str(row.get(field, ""))
            for rel in raw.split():
                if rel.endswith(".yaml") or rel.endswith(".yml") or "/" in rel:
                    if not (ROOT / rel).exists():
                        print(f"{control_id}: {field} path does not exist: {rel}", file=sys.stderr)
                        failed = True
        if control_id not in readme:
            print(f"{control_id} is missing from README.md", file=sys.stderr)
            failed = True
    if failed:
        return 1
    print(f"ok {len(seen)} catalog rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

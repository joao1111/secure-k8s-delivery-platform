#!/usr/bin/env python3
"""Fail when a suppression is missing ownership fields or has expired."""

from __future__ import annotations

import argparse
import datetime as dt
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from expiry import annotation_errors  # noqa: E402


def documents(path: Path) -> list[tuple[Path, dict]]:
    files = [path] if path.is_file() else sorted(path.rglob("*.yaml")) + sorted(path.rglob("*.yml"))
    found: list[tuple[Path, dict]] = []
    for file in files:
        for doc in yaml.safe_load_all(file.read_text()):
            if isinstance(doc, dict) and doc.get("kind") == "Suppression":
                found.append((file, doc))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    parser.add_argument("--today", default=dt.date.today().isoformat())
    args = parser.parse_args()
    today = dt.date.fromisoformat(args.today)
    docs = documents(args.path)
    if not docs:
        print(f"no Suppression documents under {args.path}", file=sys.stderr)
        return 1
    failed = False
    for file, doc in docs:
        name = (doc.get("metadata") or {}).get("name", file.name)
        errors = annotation_errors((doc.get("metadata") or {}).get("annotations"), today)
        spec = doc.get("spec") or {}
        if not str(spec.get("tool", "")).strip():
            errors.append("missing spec.tool")
        if not str(spec.get("path", "")).strip():
            errors.append("missing spec.path")
        if errors:
            failed = True
            print(f"{file} ({name}): {'; '.join(errors)}", file=sys.stderr)
        else:
            print(f"ok {file} ({name})")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

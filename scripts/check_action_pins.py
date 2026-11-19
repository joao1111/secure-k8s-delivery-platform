#!/usr/bin/env python3
"""Reject GitHub Actions uses: lines that are not pinned to a commit SHA."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

USES = re.compile(r"^\s*-?\s*uses:\s*([^#\s]+)")
SHA = re.compile(r"^[0-9a-f]{40}$")


def unpinned(path: Path) -> list[str]:
    problems: list[str] = []
    files = [path] if path.is_file() else sorted(path.rglob("*.yml")) + sorted(path.rglob("*.yaml"))
    if not files:
        return [f"no workflow files under {path}"]
    for file in files:
        for number, line in enumerate(file.read_text().splitlines(), start=1):
            match = USES.search(line)
            if not match:
                continue
            ref = match.group(1)
            if ref.startswith("./") or ref.startswith("docker://"):
                continue
            if "@" not in ref:
                problems.append(f"{file}:{number}: {ref} has no ref")
                continue
            _, pin = ref.rsplit("@", 1)
            if not SHA.fullmatch(pin):
                problems.append(f"{file}:{number}: {ref} is not a 40-character commit SHA")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    problems = unpinned(args.path)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print(f"ok {args.path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Check files in this repo against sha256 lines stored in git."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIGEST = re.compile(r"[0-9a-f]{64}")


def mismatches(checksum_file: Path) -> list[str]:
    problems: list[str] = []
    checked = 0
    for number, line in enumerate(checksum_file.read_text().splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = stripped.split()
        if len(parts) != 2 or not DIGEST.fullmatch(parts[0]):
            problems.append(f"{checksum_file}:{number}: expected a sha256 and a repo path")
            continue
        digest, rel = parts
        target = (ROOT / rel).resolve()
        if not target.is_relative_to(ROOT):
            problems.append(f"{checksum_file}:{number}: {rel} escapes the repository")
            continue
        if not target.is_file():
            problems.append(f"{checksum_file}:{number}: missing {rel}")
            continue
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        checked += 1
        if actual != digest:
            problems.append(f"{rel}: checksum mismatch")
    if checked == 0 and not problems:
        problems.append(f"{checksum_file}: no checksum lines")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("checksum_file", type=Path)
    args = parser.parse_args()
    problems = mismatches(args.checksum_file)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print(f"ok {args.checksum_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

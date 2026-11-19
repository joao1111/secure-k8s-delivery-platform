#!/usr/bin/env python3
"""Clock and pin checks that do not depend on today's date."""

from __future__ import annotations

import datetime as dt
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from check_action_pins import unpinned  # noqa: E402
from expiry import annotation_errors  # noqa: E402


class ExpiryTest(unittest.TestCase):
    def test_same_day_is_still_valid(self) -> None:
        today = dt.date(2026, 11, 19)
        errors = annotation_errors(
            {
                "security.platform/reason": "because",
                "security.platform/owner": "joao1111",
                "security.platform/ticket": "PLAT-1",
                "security.platform/expires": "2026-11-19",
            },
            today,
        )
        self.assertEqual(errors, [])

    def test_previous_day_is_expired(self) -> None:
        errors = annotation_errors(
            {
                "security.platform/reason": "because",
                "security.platform/owner": "joao1111",
                "security.platform/ticket": "PLAT-1",
                "security.platform/expires": "2026-11-18",
            },
            dt.date(2026, 11, 19),
        )
        self.assertTrue(any("expired" in item for item in errors))

    def test_committed_exception_uses_the_clock_argument(self) -> None:
        script = ROOT / "scripts" / "check_exceptions.py"
        passed = subprocess.run(
            [sys.executable, str(script), "policies/exceptions", "--today", "2026-11-19"],
            cwd=ROOT,
            check=False,
        )
        self.assertEqual(passed.returncode, 0)
        failed = subprocess.run(
            [sys.executable, str(script), "policies/exceptions", "--today", "2028-01-01"],
            cwd=ROOT,
            check=False,
        )
        self.assertEqual(failed.returncode, 1)


class ActionPinTest(unittest.TestCase):
    def test_fixtures(self) -> None:
        self.assertEqual(unpinned(ROOT / "tests/actions/pinned"), [])
        self.assertTrue(unpinned(ROOT / "tests/actions/unpinned"))


if __name__ == "__main__":
    unittest.main()

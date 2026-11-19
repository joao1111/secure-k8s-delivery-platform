#!/usr/bin/env python3
"""Run scanner fixtures. A clean scan of a bad fixture is a failure."""

from __future__ import annotations

import datetime as dt
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from expiry import annotation_errors  # noqa: E402

CHECKS = "CKV_AWS_53,CKV_AWS_54,CKV_AWS_55,CKV_AWS_56"


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True)


def expect(result: subprocess.CompletedProcess[str], *, fail: bool, label: str) -> None:
    leaked = result.returncode != 0
    if leaked != fail:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        wanted = "findings" if fail else "a clean result"
        raise SystemExit(f"{label}: expected {wanted}, exit {result.returncode}")
    print(f"ok {label}")


def suppressions(today: dt.date) -> dict[str, Path]:
    allowed: dict[str, Path] = {}
    for file in sorted((ROOT / "suppressions").glob("*.yaml")):
        doc = yaml.safe_load(file.read_text())
        errors = annotation_errors(doc["metadata"]["annotations"], today)
        if errors:
            raise SystemExit(f"{file}: {'; '.join(errors)}")
        rel = doc["spec"]["path"]
        allowed[doc["spec"]["tool"]] = ROOT / rel
    return allowed


def main() -> None:
    today = dt.date.today()
    allowed = suppressions(today)
    for tool in ("gitleaks", "semgrep", "checkov"):
        if tool not in allowed:
            raise SystemExit(f"missing unexpired suppression for {tool}")

    base = "tests/scanners/gitleaks/gitleaks.toml"
    bad = run(["gitleaks", "detect", "--no-git", "--no-banner", "--redact", "--config", base, "--source", "tests/scanners/gitleaks/bad"])
    expect(bad, fail=True, label="gitleaks bad fixture")
    raw = run(["gitleaks", "detect", "--no-git", "--no-banner", "--redact", "--config", base, "--source", "tests/scanners/gitleaks/allowed"])
    expect(raw, fail=True, label="gitleaks allowed fixture without suppression")

    with tempfile.NamedTemporaryFile("w", suffix=".toml", delete=False) as handle:
        handle.write(f"[extend]\npath = '{(ROOT / base).as_posix()}'\n\n[allowlist]\npaths = [\n")
        handle.write("  '''config.env''',\n")
        handle.write("]\n")
        config = handle.name
    gated = run(["gitleaks", "detect", "--no-git", "--no-banner", "--redact", "--config", config, "--source", "tests/scanners/gitleaks/allowed"])
    expect(gated, fail=False, label="gitleaks allowed fixture with unexpired suppression")

    rule = "tests/scanners/semgrep/hardcoded-password.yaml"
    def semgrep(path: str) -> list[str]:
        return ["semgrep", "scan", "--metrics=off", "--error", "--no-git-ignore", "--config", rule, path]

    expect(run(semgrep("tests/scanners/semgrep/bad")), fail=True, label="semgrep bad fixture")
    expect(run(semgrep("tests/scanners/semgrep/good")), fail=False, label="semgrep paved road")
    expect(run(semgrep("tests/scanners/semgrep/suppressed")), fail=True, label="semgrep suppressed fixture still has a finding")

    def checkov(path: str) -> subprocess.CompletedProcess[str]:
        return run(["checkov", "-d", path, "--framework", "terraform", "--check", CHECKS, "--compact", "--quiet"])

    expect(checkov("tests/scanners/checkov/bad"), fail=True, label="checkov public storage")
    expect(checkov("tests/scanners/checkov/good"), fail=False, label="checkov private storage")
    expect(checkov("tests/scanners/checkov/suppressed"), fail=True, label="checkov suppressed fixture still has a finding")

    trivy_bad = run(["trivy", "fs", "--quiet", "--scanners", "vuln", "--severity", "HIGH,CRITICAL", "--exit-code", "1", "tests/scanners/trivy/bad"])
    expect(trivy_bad, fail=True, label="trivy vulnerable dependency")
    trivy_good = run(["trivy", "fs", "--quiet", "--scanners", "vuln", "--severity", "HIGH,CRITICAL", "--exit-code", "1", "app/image"])
    expect(trivy_good, fail=False, label="trivy paved-road image module")


if __name__ == "__main__":
    main()

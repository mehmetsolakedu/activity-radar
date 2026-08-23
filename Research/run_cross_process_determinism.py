#!/usr/bin/env python3
"""Run the frozen Swift benchmark in fresh processes and compare policy digests."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import platform
import subprocess
import tempfile
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", type=Path, required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runner-commit", required=True)
    parser.add_argument("--processes", type=int, default=100)
    parser.add_argument("--timeout-seconds", type=int, default=30)
    parser.add_argument("--work-directory", type=Path, default=Path.cwd())
    args = parser.parse_args()

    if args.processes < 1:
        raise SystemExit("--processes must be positive")
    if args.timeout_seconds < 1:
        raise SystemExit("--timeout-seconds must be positive")

    executable = args.executable.resolve(strict=True)
    corpus = args.corpus.resolve(strict=True)
    work_directory = args.work_directory.resolve(strict=True)
    started = dt.datetime.now(dt.timezone.utc)
    rows: list[dict[str, object]] = []

    with tempfile.TemporaryDirectory(prefix="aiwingman-cross-process-") as temporary:
        temporary_root = Path(temporary)
        for process_index in range(1, args.processes + 1):
            report = temporary_root / f"run-{process_index:03d}.json"
            completed = subprocess.run(
                [
                    str(executable),
                    "--corpus",
                    str(corpus),
                    "--output",
                    str(report),
                ],
                cwd=work_directory,
                capture_output=True,
                text=True,
                timeout=args.timeout_seconds,
                check=False,
            )
            row: dict[str, object] = {
                "process": process_index,
                "exitCode": completed.returncode,
                "stderrEmpty": completed.stderr == "",
                "stdoutReportedPass": completed.stdout.startswith(
                    "AiWingman continuity benchmark: PASS\nReport: "
                ),
            }
            if report.exists():
                result = json.loads(report.read_text(encoding="utf-8"))
                row.update(
                    {
                        "overallPassed": result["overallPassed"],
                        "conformancePassedCount": result["conformance"]["passedFixtureCount"],
                        "corpusOutputDigestSHA256": result["determinism"][
                            "corpusOutputDigestSHA256"
                        ],
                        "reportSHA256": sha256(report),
                    }
                )
            rows.append(row)

    digests = sorted(
        {
            str(row["corpusOutputDigestSHA256"])
            for row in rows
            if row.get("corpusOutputDigestSHA256")
        }
    )
    all_passed = all(
        row.get("exitCode") == 0
        and row.get("stderrEmpty") is True
        and row.get("stdoutReportedPass") is True
        and row.get("overallPassed") is True
        and row.get("conformancePassedCount") == 155
        for row in rows
    )
    summary = {
        "schemaVersion": "1.0",
        "runnerCommit": args.runner_commit,
        "architecture": platform.machine(),
        "processCount": len(rows),
        "evaluationCount": len(rows) * 155,
        "startedAt": started.isoformat().replace("+00:00", "Z"),
        "completedAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
        "allProcessesPassed": all_passed,
        "uniqueCorpusOutputDigests": digests,
        "uniqueDigestCount": len(digests),
        "claimBoundary": (
            "Fresh-process equality of the canonical continuity-policy output digest on one "
            "machine; excludes cross-architecture, GUI, reader, and remote-model determinism."
        ),
        "runs": rows,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "allProcessesPassed": all_passed,
                "evaluationCount": summary["evaluationCount"],
                "processCount": summary["processCount"],
                "uniqueCorpusOutputDigests": digests,
                "uniqueDigestCount": len(digests),
            },
            sort_keys=True,
        )
    )
    if not all_passed or len(digests) != 1:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

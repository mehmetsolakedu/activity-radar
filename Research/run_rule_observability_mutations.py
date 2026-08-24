#!/usr/bin/env python3
"""Run the post-freeze continuity-rule observability mutation checks.

The frozen V1 corpus is immutable. This supplementary engineering check copies
the current Swift package to a temporary directory, runs six focused regression
tests, then applies one compiling source mutation per test. A mutation is
counted as killed only when the corresponding focused test is named in a
non-zero test result. The repository working tree is never mutated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


KNOWN_TEST = "postFreezeObservabilityDeadlineWithinWeek"
TEST_FILTER = "postFreezeObservability"
SOURCE_RELATIVE = Path("Sources/ActivityRadarCore/WorkContinuity.swift")
TEST_RELATIVE = Path("Tests/ActivityRadarCoreTests/WorkContinuityTests.swift")


@dataclass(frozen=True)
class Mutation:
    identifier: str
    rule: str
    test: str
    before: str
    after: str


MUTATIONS = (
    Mutation(
        "deadline-within-week-weight",
        "deadlineWithinWeek weight 20",
        "postFreezeObservabilityDeadlineWithinWeek",
        "WorkTriageReason(code: .deadlineWithinWeek, weight: 20, evidenceAt: deadline)",
        "WorkTriageReason(code: .deadlineWithinWeek, weight: 21, evidenceAt: deadline)",
    ),
    Mutation(
        "low-importance-weight",
        "lowImportance weight -10",
        "postFreezeObservabilityLowImportance",
        "WorkTriageReason(code: .lowImportance, weight: -10)",
        "WorkTriageReason(code: .lowImportance, weight: -9)",
    ),
    Mutation(
        "aging-seven-to-thirty-weight",
        "agingWithoutPlan weight 12",
        "postFreezeObservabilityAgingWithoutPlanSevenToThirtyDays",
        "let weight = age >= 30 * day ? 18 : 12",
        "let weight = age >= 30 * day ? 18 : 11",
    ),
    Mutation(
        "aging-thirty-or-more-weight",
        "agingWithoutPlan weight 18",
        "postFreezeObservabilityAgingWithoutPlanThirtyDaysOrMore",
        "let weight = age >= 30 * day ? 18 : 12",
        "let weight = age >= 30 * day ? 17 : 12",
    ),
    Mutation(
        "recently-active-weight",
        "recentlyActive weight 8",
        "postFreezeObservabilityRecentlyActive",
        "WorkTriageReason(code: .recentlyActive, weight: 8, evidenceAt: input.item.lastActivityAt)",
        "WorkTriageReason(code: .recentlyActive, weight: 9, evidenceAt: input.item.lastActivityAt)",
    ),
    Mutation(
        "empty-portfolio-abstention",
        "empty portfolio insufficientEvidence result",
        "postFreezeObservabilityEmptyPortfolio",
        """            } else {
                abstentionReason = .insufficientEvidence
            }
            return WorkTriageResult(""",
        """            } else {
                abstentionReason = .noEligibleWork
            }
            return WorkTriageResult(""",
    ),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(command: list[str], cwd: Path, timeout: int = 240) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )


def swift_test_prefix(root: Path, scratch: Path) -> tuple[list[str], str]:
    standard = ["swift", "test", "--scratch-path", str(scratch)]
    listing = run(standard + ["list"], root)
    if listing.returncode == 0 and KNOWN_TEST in listing.stdout:
        return standard, "standard"

    clt_root = Path("/Library/Developer/CommandLineTools")
    framework = clt_root / "Library/Developer/Frameworks"
    interop = clt_root / "Library/Developer/usr/lib"
    fallback = standard + [
        "--disable-xctest",
        "--enable-swift-testing",
        "-Xswiftc",
        "-F",
        "-Xswiftc",
        str(framework),
        "-Xlinker",
        "-rpath",
        "-Xlinker",
        str(framework),
        "-Xlinker",
        "-rpath",
        "-Xlinker",
        str(interop),
    ]
    fallback_listing = run(fallback + ["list"], root)
    if fallback_listing.returncode == 0 and KNOWN_TEST in fallback_listing.stdout:
        return fallback, "command-line-tools-fallback"

    raise RuntimeError(
        "No known post-freeze observability test was discovered.\n"
        f"Standard discovery:\n{listing.stdout}\n"
        f"Fallback discovery:\n{fallback_listing.stdout}"
    )


def replace_exactly_once(text: str, before: str, after: str, identifier: str) -> str:
    count = text.count(before)
    if count != 1:
        raise RuntimeError(
            f"Mutation {identifier!r} expected one source match, observed {count}."
        )
    return text.replace(before, after, 1)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional JSON result path; written only when all checks pass.",
    )
    arguments = parser.parse_args()

    repository = Path(__file__).resolve().parents[1]
    source = repository / SOURCE_RELATIVE
    tests = repository / TEST_RELATIVE
    if not source.is_file() or not tests.is_file():
        raise SystemExit("Required source or test file is missing.")

    with tempfile.TemporaryDirectory(prefix="aiwingman-rule-mutations-") as temporary:
        temporary_root = Path(temporary) / "package"
        temporary_root.mkdir()
        shutil.copy2(repository / "Package.swift", temporary_root / "Package.swift")
        shutil.copytree(repository / "Sources", temporary_root / "Sources")
        shutil.copytree(repository / "Tests", temporary_root / "Tests")

        temporary_source = temporary_root / SOURCE_RELATIVE
        pristine_source = temporary_source.read_text(encoding="utf-8")
        scratch = Path(temporary) / "scratch"
        prefix, discovery_mode = swift_test_prefix(temporary_root, scratch)

        baseline = run(prefix + ["--filter", TEST_FILTER], temporary_root)
        if baseline.returncode != 0:
            raise SystemExit(f"Baseline observability tests failed:\n{baseline.stdout}")
        missing_tests = [mutation.test for mutation in MUTATIONS if mutation.test not in baseline.stdout]
        if missing_tests:
            raise SystemExit(
                "Baseline output did not name every required test: " + ", ".join(missing_tests)
            )

        mutation_rows: list[dict[str, object]] = []
        for mutation in MUTATIONS:
            temporary_source.write_text(
                replace_exactly_once(
                    pristine_source,
                    mutation.before,
                    mutation.after,
                    mutation.identifier,
                ),
                encoding="utf-8",
            )
            result = run(prefix + ["--filter", mutation.test], temporary_root)
            named_target = mutation.test in result.stdout
            killed = result.returncode != 0 and named_target
            mutation_rows.append(
                {
                    "id": mutation.identifier,
                    "rule": mutation.rule,
                    "focusedTest": mutation.test,
                    "exitStatus": result.returncode,
                    "targetTestNamedInFailureOutput": named_target,
                    "killed": killed,
                }
            )
            temporary_source.write_text(pristine_source, encoding="utf-8")
            if not killed:
                raise SystemExit(
                    f"Mutation {mutation.identifier!r} survived or failed outside its target test.\n"
                    f"{result.stdout}"
                )

        swift_version = run(["swift", "--version"], temporary_root, timeout=30)
        payload = {
            "schemaVersion": 1,
            "status": "PASS",
            "evidenceClass": "post-freeze supplementary engineering regression",
            "generatedAtUTC": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            "frozenV1CorpusModified": False,
            "repositoryWorkingTreeMutated": False,
            "source": {
                "path": str(SOURCE_RELATIVE),
                "sha256": sha256(source),
            },
            "tests": {
                "path": str(TEST_RELATIVE),
                "sha256": sha256(tests),
                "filter": TEST_FILTER,
                "requiredCount": len(MUTATIONS),
                "passedCount": len(MUTATIONS),
            },
            "testDiscoveryMode": discovery_mode,
            "swiftVersion": swift_version.stdout.strip(),
            "mutations": mutation_rows,
            "summary": {
                "mutationCount": len(mutation_rows),
                "killedCount": sum(1 for row in mutation_rows if row["killed"]),
                "survivedCount": sum(1 for row in mutation_rows if not row["killed"]),
            },
            "interpretationBoundary": (
                "The six focused tests expose four previously hidden triage reason codes, "
                "with separate cases for both aging weights, plus the zero-input abstention "
                "result. This does not amend V1, establish exhaustive policy coverage, or "
                "validate human utility."
            ),
        }

        if arguments.output:
            output = arguments.output.resolve()
            if not output.parent.is_dir():
                raise SystemExit(f"Output parent does not exist: {output.parent}")
            output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

        print(
            "PASS: "
            f"{len(MUTATIONS)}/{len(MUTATIONS)} focused observability tests passed; "
            f"{payload['summary']['killedCount']}/{len(MUTATIONS)} mutations killed."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

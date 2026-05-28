#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional


REQUIRED_GATE_STEPS_BASE = [
    "build-check",
    "interface-completeness",
    "public-api-coverage",
    "cross-backend-parity",
    "wiring-sync",
    "coverage",
    "simd-list-suites",
    "simd-avx2-fallback",
    "cpuinfo-portable",
    "cpuinfo-x86",
    "run-all-chain",
]
QEMU_CPUINFO_NONX86_STEP = "qemu-cpuinfo-nonx86-evidence"
QEMU_CPUINFO_NONX86_REQUIRE_ENV = "SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE"
QEMU_CPUINFO_NONX86_PLATFORM_ENV = (
    "SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' "
)
QEMU_CPUINFO_NONX86_GATE_CMD = (
    "FAFAFA_BUILD_MODE=Release "
    + QEMU_CPUINFO_NONX86_PLATFORM_ENV
    +
    "SIMD_GATE_QEMU_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=0 "
    "SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 "
    "bash tests/nextpas.core.simd/BuildOrTest.sh gate"
)
QEMU_CPUINFO_NONX86_FULL_STEP = "qemu-cpuinfo-nonx86-full-evidence"
QEMU_CPUINFO_NONX86_FULL_REQUIRE_ENV = "SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE"
QEMU_CPUINFO_NONX86_FULL_PLATFORM_ENV = (
    "SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' "
)
QEMU_CPUINFO_NONX86_FULL_GATE_CMD = (
    "FAFAFA_BUILD_MODE=Release "
    + QEMU_CPUINFO_NONX86_FULL_PLATFORM_ENV
    +
    "SIMD_GATE_QEMU_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 "
    "SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 "
    "bash tests/nextpas.core.simd/BuildOrTest.sh gate"
)
QEMU_CPUINFO_NONX86_FULL_REPEAT_STEP = "qemu-cpuinfo-nonx86-full-repeat"
QEMU_CPUINFO_NONX86_FULL_REPEAT_REQUIRE_ENV = (
    "SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_REPEAT"
)
QEMU_CPUINFO_NONX86_FULL_REPEAT_GATE_CMD = (
    "FAFAFA_BUILD_MODE=Release "
    + QEMU_CPUINFO_NONX86_FULL_PLATFORM_ENV
    +
    "SIMD_GATE_QEMU_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 "
    "SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 "
    "bash tests/nextpas.core.simd/BuildOrTest.sh gate"
)
CROSS_GATE_FAIL_CLOSE_CMD = (
    "FAFAFA_BUILD_MODE=Release "
    + QEMU_CPUINFO_NONX86_PLATFORM_ENV
    +
    "SIMD_GATE_QEMU_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 "
    "SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 "
    "SIMD_GATE_CPUINFO_LAZY_REPEAT=3 "
    "SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 "
    "bash tests/nextpas.core.simd/BuildOrTest.sh gate"
)
CPUINFO_LAZY_REPEAT_STEP = "cpuinfo-lazy-repeat"
CPUINFO_LAZY_REPEAT_REQUIRE_ENV = "SIMD_FREEZE_REQUIRE_CPUINFO_LAZY_REPEAT"
CPUINFO_LAZY_REPEAT_GATE_CMD = (
    "FAFAFA_BUILD_MODE=Release "
    "SIMD_GATE_CPUINFO_LAZY_REPEAT=5 "
    "SIMD_GATE_QEMU_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=0 "
    "SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 "
    "bash tests/nextpas.core.simd/BuildOrTest.sh gate"
)
QEMU_CPUINFO_NONX86_REQUIRED_PLATFORMS = (
    "linux/arm/v7",
    "linux/arm64",
    "linux/riscv64",
)
QEMU_CPUINFO_NONX86_SCENARIO = "cpuinfo-nonx86-evidence"
QEMU_CPUINFO_NONX86_FULL_SCENARIO = "cpuinfo-nonx86-full-evidence"
QEMU_CPUINFO_NONX86_FULL_REPEAT_SCENARIO = "cpuinfo-nonx86-full-repeat"
QEMU_MULTIARCH_DIR_RE = re.compile(r"^qemu-multiarch-(\d{8})-(\d{6})(?:-.+)?$")
WINDOWS_EVIDENCE_LOG_INPUT_RELATIVE_PATHS = (
    "buildOrTest.bat",
    "collect_windows_b07_evidence.bat",
)
WINDOWS_TOOLCHAIN_ACTION = (
    "Provide a real Windows runner with native Windows lazbuild.exe, "
    "or set LAZBUILD to a Windows .exe/.bat/.cmd wrapper; Wine/cmd cannot execute Linux lazbuild"
)


@dataclass
class CheckItem:
    name: str
    required: bool
    status: str
    detail: str


@dataclass
class GateRunCandidate:
    summary_path: Path
    run_rows: List[Dict[str, str]]
    terminal_row: Dict[str, str]
    terminal_time: datetime


@dataclass
class GateRunAssessment:
    candidate: GateRunCandidate
    required_ok_base: bool
    required_detail_base: str
    required_ok_mainline: bool
    required_detail_mainline: str
    required_ok_cross: bool
    required_detail_cross: str


def compute_ready(check_items: List[CheckItem], include_windows: bool) -> bool:
    for item in check_items:
        if not item.required:
            continue
        if not include_windows and item.name.startswith("cross_"):
            continue
        if not include_windows and item.name.startswith("windows_"):
            continue
        if item.status in {"PENDING", "FAIL"}:
            return False
    return True


def parse_gate_summary_rows(summary_path: Path) -> List[Dict[str, str]]:
    if not summary_path.is_file():
        return []

    rows: List[Dict[str, str]] = []
    for raw_line in summary_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            continue
        if line.startswith("| Time |") or line.startswith("|---"):
            continue

        cells = [part.strip() for part in line.strip("|").split("|")]
        if len(cells) < 7:
            continue

        rows.append(
            {
                "time": cells[0],
                "step": cells[1],
                "status": cells[2],
                "duration_ms": cells[3],
                "event": cells[4],
                "detail": cells[5],
                "artifacts": cells[6],
            }
        )

    return rows


def extract_gate_runs(rows: List[Dict[str, str]]) -> List[List[Dict[str, str]]]:
    runs: List[List[Dict[str, str]]] = []
    start_idx: Optional[int] = None

    for idx, row in enumerate(rows):
        if row.get("step") == "gate" and row.get("status") == "START":
            start_idx = idx
            continue
        if row.get("step") == "gate" and row.get("status") in {"PASS", "FAIL"}:
            run_start_idx = start_idx if start_idx is not None else 0
            runs.append(rows[run_start_idx : idx + 1])
            start_idx = None

    return runs


def discover_gate_summary_candidates(
    gate_summary: Path,
    logs_dir: Path,
    explicit_override: bool,
) -> List[Path]:
    candidates: List[Path] = []
    seen: set[str] = set()

    def add_candidate(path: Path) -> None:
        normalized = str(path.expanduser().resolve(strict=False))
        if normalized in seen:
            return
        if not path.is_file():
            return
        seen.add(normalized)
        candidates.append(path)

    add_candidate(gate_summary)
    if explicit_override:
        return candidates

    backup_root = logs_dir / "rehearsal" / "backups"
    if backup_root.is_dir():
        for summary_path in sorted(backup_root.glob("gate_summary.backup.*.md"), reverse=True):
            add_candidate(summary_path)

    closeout_root = logs_dir / "windows-closeout"
    if closeout_root.is_dir():
        for summary_path in sorted(closeout_root.glob("*/gate_summary.md"), reverse=True):
            add_candidate(summary_path)

    return candidates


def assess_gate_runs(
    summary_paths: List[Path],
    required_gate_steps_base: List[str],
    required_gate_steps_mainline: List[str],
    required_gate_steps_cross: List[str],
) -> List[GateRunAssessment]:
    assessments: List[GateRunAssessment] = []

    for summary_path in summary_paths:
        rows = parse_gate_summary_rows(summary_path)
        for run_rows in extract_gate_runs(rows):
            terminal_row = run_rows[-1]
            terminal_time = parse_gate_row_time(terminal_row)
            if terminal_time is None:
                terminal_time = datetime.fromtimestamp(summary_path.stat().st_mtime)
            required_ok_base, required_detail_base = evaluate_required_gate_steps(
                run_rows, required_gate_steps_base
            )
            required_ok_mainline, required_detail_mainline = evaluate_required_gate_steps(
                run_rows, required_gate_steps_mainline
            )
            required_ok_cross, required_detail_cross = evaluate_required_gate_steps(
                run_rows, required_gate_steps_cross
            )
            assessments.append(
                GateRunAssessment(
                    candidate=GateRunCandidate(
                        summary_path=summary_path,
                        run_rows=run_rows,
                        terminal_row=terminal_row,
                        terminal_time=terminal_time,
                    ),
                    required_ok_base=required_ok_base,
                    required_detail_base=required_detail_base,
                    required_ok_mainline=required_ok_mainline,
                    required_detail_mainline=required_detail_mainline,
                    required_ok_cross=required_ok_cross,
                    required_detail_cross=required_detail_cross,
                )
            )

    assessments.sort(
        key=lambda item: (
            item.candidate.terminal_time,
            item.candidate.summary_path.stat().st_mtime,
            str(item.candidate.summary_path),
        ),
        reverse=True,
    )
    return assessments


def gate_run_label(assessment: GateRunAssessment) -> str:
    return (
        f"{assessment.candidate.summary_path} @ "
        f"{assessment.candidate.terminal_row.get('time', '-')}"
    )


def gate_run_fallback_label(assessment: GateRunAssessment) -> str:
    parts_lower = {part.lower() for part in assessment.candidate.summary_path.parts}
    if "windows-closeout" in parts_lower:
        return "selected fallback closeout gate snapshot"
    if "backups" in parts_lower:
        return "selected fallback backup gate snapshot"
    return "selected fallback gate snapshot"


def has_cross_omission_only(
    run_rows: List[Dict[str, str]], cross_only_steps: List[str]
) -> bool:
    if not cross_only_steps:
        return False

    step_status: Dict[str, str] = {}
    step_detail: Dict[str, str] = {}
    for row in run_rows:
        step = row.get("step", "")
        if step == "gate":
            continue
        step_status[step] = row.get("status", "")
        step_detail[step] = row.get("detail", "")

    saw_omission = False
    for step in cross_only_steps:
        status = step_status.get(step)
        detail = step_detail.get(step, "").lower()
        if status is None:
            saw_omission = True
            continue
        if status == "SKIP":
            saw_omission = True
            continue
        if step == "evidence-verify" and status == "PASS" and "skip" in detail:
            saw_omission = True
            continue
        if status != "PASS":
            return False

    return saw_omission


def select_effective_gate_run(
    assessments: List[GateRunAssessment],
    required_gate_steps_selected: List[str],
    linux_only: bool,
) -> tuple[Optional[GateRunAssessment], Optional[GateRunAssessment], bool, str]:
    if not assessments:
        return None, None, False, ""

    latest = assessments[0]
    latest_selected_ok = latest.required_ok_mainline if linux_only else latest.required_ok_cross
    if latest_selected_ok:
        return latest, latest, False, ""

    if not latest.required_ok_base:
        return latest, latest, False, ""

    # In cross mode, a fresh latest gate that already satisfies all mainline-required
    # steps must remain the active source of truth for mainline readiness/freshness.
    # Only fall back when the latest run is still missing mainline coverage.
    if not linux_only and latest.required_ok_mainline:
        return latest, latest, False, ""

    fallback_only_steps = [
        step for step in required_gate_steps_selected if step not in REQUIRED_GATE_STEPS_BASE
    ]
    if not has_cross_omission_only(latest.candidate.run_rows, fallback_only_steps):
        return latest, latest, False, ""

    best_mainline: Optional[GateRunAssessment] = None

    for assessment in assessments[1:]:
        assessment_selected_ok = (
            assessment.required_ok_mainline if linux_only else assessment.required_ok_cross
        )
        if assessment_selected_ok:
            return assessment, latest, True, "cross" if not linux_only else "mainline"
        if not linux_only and best_mainline is None and assessment.required_ok_mainline:
            best_mainline = assessment

    if not linux_only and best_mainline is not None:
        return best_mainline, latest, True, "mainline"

    return latest, latest, False, ""


def check_line_markdown_x(path: Path, contains_text: str) -> Optional[bool]:
    if not path.is_file():
        return None

    matched_non_checkbox = False
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if contains_text in line:
            stripped = line.strip()
            if stripped.startswith("- [x]"):
                return True
            if stripped.startswith("- [ ]"):
                return False
            matched_non_checkbox = True
    if matched_non_checkbox:
        return False
    return False


def run_verify_script(verify_script: Path, log_path: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(verify_script), str(log_path)],
        text=True,
        capture_output=True,
        check=False,
    )


def compact_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value or "").strip()


def is_windows_toolchain_block(detail: Optional[str]) -> bool:
    normalized = compact_whitespace(detail or "").upper()
    return "TOOLCHAIN BLOCK" in normalized or "CMD.EXE CANNOT RESOLVE LAZBUILD" in normalized


def extract_windows_log_failure_hint(log_path: Path) -> Optional[str]:
    if not log_path.is_file():
        return None

    try:
        lines = log_path.read_text(encoding="utf-8", errors="ignore").splitlines()
    except Exception:
        return None

    normalized = [line.rstrip("\r").strip() for line in lines]

    for idx, line in enumerate(normalized):
        if "BUILD FAILED" not in line:
            continue
        hint_parts = [line]
        for follow in normalized[idx + 1 : idx + 4]:
            if not follow:
                continue
            if follow.startswith("[B07]"):
                break
            if follow.startswith("[BUILD] TOOLCHAIN BLOCK:"):
                hint_parts.append(follow)
                break
            if follow.startswith("[") and "FAILED" not in follow and "recognize" not in follow.lower():
                break
            hint_parts.append(follow)
            break
        return compact_whitespace("; ".join(hint_parts))

    for line in normalized:
        if "toolchain block" in line.lower():
            return compact_whitespace(line)

    for line in normalized:
        if "can't recognize" in line.lower():
            return compact_whitespace(line)

    for line in normalized:
        if line.startswith("[B07] GATE_EXIT_CODE=") and not line.endswith("=0"):
            return compact_whitespace(f"gate exited non-zero before evidence completed: {line}")

    return None


def summarize_verify_failure(
    verify_proc: subprocess.CompletedProcess[str], log_path: Path
) -> str:
    raw_detail = (verify_proc.stderr or "").strip()
    if not raw_detail:
        raw_detail = (verify_proc.stdout or "").strip()
    detail_msg = compact_whitespace(raw_detail)

    first_issue = ""
    for raw_line in raw_detail.splitlines():
        line = compact_whitespace(raw_line)
        if line:
            first_issue = line
            break

    hint = extract_windows_log_failure_hint(log_path)
    parts: List[str] = []
    if hint:
        parts.append(f"root-cause hint: {hint}")
    parts.append(f"verifier failed rc={verify_proc.returncode}")
    if first_issue:
        parts.append(f"first verifier issue: {first_issue}")
    return "; ".join(parts)


def parse_bool_env(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    normalized = raw.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off", ""}:
        return False
    return default


def build_required_gate_steps(
    include_windows_evidence_step: bool,
    include_qemu_cpuinfo_nonx86_step: bool = False,
    include_qemu_cpuinfo_nonx86_full_step: bool = False,
    include_qemu_cpuinfo_nonx86_full_repeat_step: bool = False,
    include_cpuinfo_lazy_repeat_step: bool = False,
) -> List[str]:
    steps = list(REQUIRED_GATE_STEPS_BASE)
    if include_windows_evidence_step:
        steps.append("evidence-verify")
    if include_qemu_cpuinfo_nonx86_step:
        steps.append(QEMU_CPUINFO_NONX86_STEP)
    if include_qemu_cpuinfo_nonx86_full_step:
        steps.append(QEMU_CPUINFO_NONX86_FULL_STEP)
    if include_qemu_cpuinfo_nonx86_full_repeat_step:
        steps.append(QEMU_CPUINFO_NONX86_FULL_REPEAT_STEP)
    if include_cpuinfo_lazy_repeat_step:
        steps.append(CPUINFO_LAZY_REPEAT_STEP)
    return steps


def evaluate_required_gate_steps(
    run_rows: List[Dict[str, str]], required_steps: List[str]
) -> tuple[bool, str]:
    step_status: Dict[str, str] = {}
    step_detail: Dict[str, str] = {}
    for row in run_rows:
        step = row.get("step", "")
        if step == "gate":
            continue
        step_status[step] = row.get("status", "")
        step_detail[step] = row.get("detail", "")

    missing_steps: List[str] = []
    non_pass_steps: List[str] = []
    for required_step in required_steps:
        status = step_status.get(required_step)
        if status is None:
            missing_steps.append(required_step)
        elif (
            required_step == "evidence-verify"
            and status == "PASS"
            and "skip" in step_detail.get(required_step, "").lower()
        ):
            non_pass_steps.append("evidence-verify=SKIP(marked-as-pass)")
        elif status != "PASS":
            non_pass_steps.append(f"{required_step}={status}")

    if missing_steps or non_pass_steps:
        parts: List[str] = []
        if missing_steps:
            parts.append(f"missing: {', '.join(missing_steps)}")
        if non_pass_steps:
            parts.append(f"non-pass: {', '.join(non_pass_steps)}")
        return False, "; ".join(parts)

    return True, "all required gate steps are PASS (no SKIP/FAIL)"


def find_latest_step_row(run_rows: List[Dict[str, str]], step_name: str) -> Optional[Dict[str, str]]:
    for row in reversed(run_rows):
        if row.get("step") == step_name:
            return row
    return None


def parse_gate_row_time(row: Dict[str, str]) -> Optional[datetime]:
    raw = row.get("time", "").strip()
    if not raw or raw == "-":
        return None
    try:
        return datetime.strptime(raw, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def freshness_check(name: str, path: Path, max_age_hours: float, required: bool = True) -> CheckItem:
    if not path.is_file():
        return CheckItem(name=name, required=required, status="FAIL", detail=f"missing {path}")

    now = datetime.now()
    mtime = datetime.fromtimestamp(path.stat().st_mtime)
    age_hours = (now - mtime).total_seconds() / 3600.0

    if age_hours <= max_age_hours:
        return CheckItem(
            name=name,
            required=required,
            status="PASS",
            detail=(
                f"mtime={mtime:%Y-%m-%d %H:%M:%S}, age_hours={age_hours:.2f}, "
                f"threshold_hours={max_age_hours:.2f}"
            ),
        )

    return CheckItem(
        name=name,
        required=required,
        status="FAIL",
        detail=(
            f"stale mtime={mtime:%Y-%m-%d %H:%M:%S}, age_hours={age_hours:.2f}, "
            f"threshold_hours={max_age_hours:.2f}"
        ),
    )


SOURCE_CANDIDATE_SUFFIXES = {".pas", ".pp", ".inc", ".stable"}
SOURCE_FRESHNESS_EXCLUDED_NAMES = {
    # Intentional empty include boundary: retired AVX512 fallback wrappers no
    # longer contribute implementation semantics.
    "nextpas.core.simd.avx512.fallback.inc",
    # Intentional empty include boundary: retired NEON platform facade wrappers
    # no longer contribute implementation semantics, so comment/doc churn here
    # should not invalidate gate/evidence freshness.
    "nextpas.core.simd.neon.facade_platform.inc",
    # Intentional empty include boundary: retired NEON dot wrappers no longer
    # contribute implementation semantics.
    "nextpas.core.simd.neon.dot.inc",
}
PASCAL_BRACE_COMMENT_RE = re.compile(r"\{(?!\$).*?\}", re.S)
PASCAL_PAREN_COMMENT_RE = re.compile(r"\(\*(?!\$).*?\*\)", re.S)
LINE_COMMENT_RE = re.compile(r"//.*?$", re.M)


def is_comment_only_source_candidate(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="ignore")
    text = PASCAL_BRACE_COMMENT_RE.sub("", text)
    text = PASCAL_PAREN_COMMENT_RE.sub("", text)
    text = LINE_COMMENT_RE.sub("", text)
    return text.strip() == ""


def iter_simd_source_candidates(src_root: Path) -> Iterable[Path]:
    for path in sorted(src_root.glob("nextpas.core.simd*")):
        if not path.is_file():
            continue
        if path.suffix.lower() not in SOURCE_CANDIDATE_SUFFIXES:
            continue
        if path.name.lower() in SOURCE_FRESHNESS_EXCLUDED_NAMES:
            continue
        if is_comment_only_source_candidate(path):
            continue
        yield path


def iter_windows_evidence_log_input_candidates(root: Path) -> Iterable[Path]:
    for relative_path in WINDOWS_EVIDENCE_LOG_INPUT_RELATIVE_PATHS:
        path = root / relative_path
        if path.is_file():
            yield path


def candidate_paths_not_newer_than_artifact_check(
    name: str, artifact_path: Path, candidate_paths: list[Path], required: bool = True
) -> CheckItem:
    if not artifact_path.is_file():
        return CheckItem(name=name, required=required, status="FAIL", detail=f"missing {artifact_path}")

    file_candidates = [path for path in candidate_paths if path.is_file()]
    if not file_candidates:
        return CheckItem(
            name=name,
            required=required,
            status="PASS",
            detail=f"no candidate producer files found for {artifact_path}",
        )

    latest_candidate = max(file_candidates, key=lambda path: path.stat().st_mtime)
    latest_candidate_mtime = datetime.fromtimestamp(latest_candidate.stat().st_mtime)
    artifact_mtime = datetime.fromtimestamp(artifact_path.stat().st_mtime)

    if latest_candidate_mtime <= artifact_mtime:
        return CheckItem(
            name=name,
            required=required,
            status="PASS",
            detail=(
                f"artifact mtime={artifact_mtime:%Y-%m-%d %H:%M:%S}, "
                f"latest_candidate={latest_candidate} ({latest_candidate_mtime:%Y-%m-%d %H:%M:%S})"
            ),
        )

    return CheckItem(
        name=name,
        required=required,
        status="FAIL",
        detail=(
            f"artifact mtime={artifact_mtime:%Y-%m-%d %H:%M:%S}, "
            f"latest_candidate={latest_candidate} ({latest_candidate_mtime:%Y-%m-%d %H:%M:%S})"
        ),
    )


def artifact_not_older_than_reference_check(
    name: str, artifact_path: Path, reference_path: Path, required: bool = True
) -> CheckItem:
    if not artifact_path.is_file():
        return CheckItem(name=name, required=required, status="FAIL", detail=f"missing {artifact_path}")
    if not reference_path.is_file():
        return CheckItem(name=name, required=required, status="FAIL", detail=f"missing {reference_path}")

    artifact_mtime = datetime.fromtimestamp(artifact_path.stat().st_mtime)
    reference_mtime = datetime.fromtimestamp(reference_path.stat().st_mtime)

    if artifact_mtime >= reference_mtime:
        return CheckItem(
            name=name,
            required=required,
            status="PASS",
            detail=(
                f"artifact mtime={artifact_mtime:%Y-%m-%d %H:%M:%S}, "
                f"reference={reference_path} ({reference_mtime:%Y-%m-%d %H:%M:%S})"
            ),
        )

    return CheckItem(
        name=name,
        required=required,
        status="FAIL",
        detail=(
            f"artifact mtime={artifact_mtime:%Y-%m-%d %H:%M:%S}, "
            f"reference={reference_path} ({reference_mtime:%Y-%m-%d %H:%M:%S})"
        ),
    )


def sources_not_newer_than_artifact_check(
    name: str, artifact_path: Path, candidate_paths: list[Path], required: bool = True
) -> CheckItem:
    if not artifact_path.is_file():
        return CheckItem(name=name, required=required, status="FAIL", detail=f"missing {artifact_path}")

    file_candidates = [path for path in candidate_paths if path.is_file()]
    if not file_candidates:
        return CheckItem(
            name=name,
            required=required,
            status="PASS",
            detail=f"no candidate source files found for {artifact_path}",
        )

    latest_source = max(file_candidates, key=lambda path: path.stat().st_mtime)
    latest_source_mtime = datetime.fromtimestamp(latest_source.stat().st_mtime)
    artifact_mtime = datetime.fromtimestamp(artifact_path.stat().st_mtime)

    if latest_source_mtime <= artifact_mtime:
        return CheckItem(
            name=name,
            required=required,
            status="PASS",
            detail=(
                f"artifact mtime={artifact_mtime:%Y-%m-%d %H:%M:%S}, "
                f"latest_source={latest_source} ({latest_source_mtime:%Y-%m-%d %H:%M:%S})"
            ),
        )

    return CheckItem(
        name=name,
        required=required,
        status="FAIL",
        detail=(
            f"artifact older than latest source: artifact={artifact_path} "
            f"({artifact_mtime:%Y-%m-%d %H:%M:%S}), latest_source={latest_source} "
            f"({latest_source_mtime:%Y-%m-%d %H:%M:%S})"
        ),
    )


def parse_default_fresh_hours() -> float:
    raw = os.environ.get("SIMD_FREEZE_MAX_AGE_HOURS", "72")
    try:
        value = float(raw)
    except ValueError:
        return 72.0
    if value <= 0:
        return 72.0
    return value


def parse_qemu_summary(summary_path: Path) -> Optional[Dict[str, object]]:
    if not summary_path.is_file():
        return None

    scenario = ""
    platform_status: Dict[str, str] = {}
    for raw_line in summary_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw_line.strip()
        if line.startswith("- scenario:"):
            scenario = line.split(":", 1)[1].strip()
            continue

        if not line.startswith("|"):
            continue
        if line.startswith("| Platform |") or line.startswith("|---"):
            continue

        cells = [part.strip() for part in line.strip("|").split("|")]
        if len(cells) < 2:
            continue

        platform = cells[0]
        status = cells[1]
        if platform:
            platform_status[platform] = status

    if not scenario:
        return None

    return {"scenario": scenario, "platform_status": platform_status}


def load_json_object(path: Path) -> Optional[Dict[str, object]]:
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None
    return payload


def parse_utc_timestamp(raw: str) -> Optional[datetime]:
    if not raw:
        return None
    try:
        return datetime.strptime(raw, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def describe_windows_preflight_report(path: Path) -> CheckItem:
    payload = load_json_object(path)
    if payload is None:
        return CheckItem(
            name="windows_preflight_latest",
            required=False,
            status="SKIP",
            detail=f"missing or invalid preflight report: {path}",
        )

    status = str(payload.get("status", "")).strip().upper() or "UNKNOWN"
    code = str(payload.get("code", "")).strip() or "UNKNOWN"
    message = str(payload.get("message", "")).strip() or "no message"
    checked_raw = str(payload.get("checked_at_utc", "")).strip()
    checked_at = parse_utc_timestamp(checked_raw)
    age_detail = ""
    if checked_at is not None:
        age_hours = (datetime.now(timezone.utc) - checked_at).total_seconds() / 3600.0
        age_detail = f", age_hours={age_hours:.2f}"

    item_status = "PASS" if status == "PASS" else "FAIL"
    return CheckItem(
        name="windows_preflight_latest",
        required=False,
        status=item_status,
        detail=(
            f"status={status}, code={code}{age_detail}, report={path}, message={message}"
        ),
    )


def has_recent_windows_billing_block(path: Path) -> bool:
    payload = load_json_object(path)
    if payload is None:
        return False

    if str(payload.get("status", "")).strip().upper() != "FAIL":
        return False
    if str(payload.get("code", "")).strip() != "RECENT_BILLING_BLOCK":
        return False

    checked_at = parse_utc_timestamp(str(payload.get("checked_at_utc", "")).strip())
    if checked_at is None:
        return False

    try:
        billing_window_hours = float(payload.get("billing_window_hours", 24))
    except (TypeError, ValueError):
        billing_window_hours = 24.0
    if billing_window_hours <= 0:
        billing_window_hours = 24.0

    age_hours = (datetime.now(timezone.utc) - checked_at).total_seconds() / 3600.0
    return age_hours <= billing_window_hours


def parse_qemu_multiarch_batch_time(summary_path: Path) -> Optional[datetime]:
    match = QEMU_MULTIARCH_DIR_RE.match(summary_path.parent.name)
    if match is None:
        return None
    raw_batch = f"{match.group(1)}{match.group(2)}"
    try:
        return datetime.strptime(raw_batch, "%Y%m%d%H%M%S")
    except ValueError:
        return None


def find_latest_qemu_summary_for_scenario(
    logs_dir: Path, scenario: str, not_after: Optional[datetime] = None
) -> Optional[Path]:
    candidates: List[tuple[datetime, Path]] = []
    for summary_path in logs_dir.glob("qemu-multiarch-*/summary.md"):
        parsed = parse_qemu_summary(summary_path)
        if parsed is None:
            continue
        if parsed.get("scenario") != scenario:
            continue

        batch_time = parse_qemu_multiarch_batch_time(summary_path)
        sort_time = batch_time or datetime.fromtimestamp(summary_path.stat().st_mtime)
        if not_after is not None and sort_time > not_after:
            continue

        candidates.append((sort_time, summary_path))

    if not candidates:
        return None

    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def qemu_platform_coverage_check(
    name: str,
    logs_dir: Path,
    scenario: str,
    required_platforms: List[str],
    required: bool,
    gate_step_time: Optional[datetime] = None,
) -> CheckItem:
    summary_path = find_latest_qemu_summary_for_scenario(logs_dir, scenario, not_after=gate_step_time)
    if summary_path is None:
        if gate_step_time is None:
            miss_detail = f"missing qemu summary for scenario={scenario}"
        else:
            miss_detail = (
                f"missing qemu summary for scenario={scenario} at/before "
                f"gate-step-time={gate_step_time:%Y-%m-%d %H:%M:%S}"
            )
        return CheckItem(
            name=name,
            required=required,
            status="FAIL" if required else "SKIP",
            detail=miss_detail,
        )

    parsed = parse_qemu_summary(summary_path)
    if parsed is None:
        return CheckItem(
            name=name,
            required=required,
            status="FAIL" if required else "SKIP",
            detail=f"invalid qemu summary format: {summary_path}",
        )

    platform_status = parsed.get("platform_status", {})
    if not isinstance(platform_status, dict):
        return CheckItem(
            name=name,
            required=required,
            status="FAIL" if required else "SKIP",
            detail=f"invalid qemu platform table in {summary_path}",
        )

    missing: List[str] = []
    non_pass: List[str] = []
    for platform in required_platforms:
        status = platform_status.get(platform)
        if status is None:
            missing.append(platform)
        elif status != "PASS":
            non_pass.append(f"{platform}={status}")

    if missing or non_pass:
        parts: List[str] = [f"summary={summary_path}"]
        if missing:
            parts.append(f"missing: {', '.join(missing)}")
        if non_pass:
            parts.append(f"non-pass: {', '.join(non_pass)}")
        return CheckItem(
            name=name,
            required=required,
            status="FAIL" if required else "SKIP",
            detail="; ".join(parts),
        )

    return CheckItem(
        name=name,
        required=required,
        status="PASS",
        detail=(
            f"summary={summary_path}, "
            f"required platforms PASS: {', '.join(required_platforms)}"
        ),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate SIMD cross-platform freeze readiness")
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parent),
        help="Path to tests/nextpas.core.simd directory",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print JSON payload to stdout",
    )
    parser.add_argument(
        "--json-file",
        default="",
        help="Write JSON payload to file",
    )
    parser.add_argument(
        "--linux-only",
        action="store_true",
        help="Evaluate Linux mainline readiness only (ignore Windows closeout items)",
    )
    parser.add_argument(
        "--fresh-hours",
        type=float,
        default=parse_default_fresh_hours(),
        help="Maximum acceptable artifact age in hours (default: env SIMD_FREEZE_MAX_AGE_HOURS or 72)",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    repo_root = root.parent.parent
    logs_dir = root / "logs"

    gate_summary_override = os.environ.get("SIMD_FREEZE_GATE_SUMMARY_FILE", "").strip()
    gate_summary = Path(gate_summary_override).expanduser() if gate_summary_override else logs_dir / "gate_summary.md"

    windows_log_override = os.environ.get("SIMD_FREEZE_WINDOWS_LOG_FILE", "").strip()
    windows_log = Path(windows_log_override).expanduser() if windows_log_override else logs_dir / "windows_b07_gate.log"
    windows_log_sim = logs_dir / "windows_b07_gate.simulated.log"
    closeout_summary_override = os.environ.get("SIMD_FREEZE_WINDOWS_CLOSEOUT_SUMMARY_FILE", "").strip()
    closeout_summary = (
        Path(closeout_summary_override).expanduser()
        if closeout_summary_override
        else logs_dir / "windows_b07_closeout_summary.md"
    )
    closeout_summary_sim = logs_dir / "windows_b07_closeout_summary.simulated.md"
    windows_preflight_override = os.environ.get(
        "SIMD_FREEZE_WINDOWS_PREFLIGHT_JSON_FILE", ""
    ).strip()
    windows_preflight_json = (
        Path(windows_preflight_override).expanduser()
        if windows_preflight_override
        else logs_dir / "win_preflight_latest.json"
    )

    verify_script = root / "verify_windows_b07_evidence.sh"
    windows_evidence_log_input_candidates = list(
        iter_windows_evidence_log_input_candidates(root)
    )

    roadmap_doc = repo_root / "docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md"
    matrix_doc = root / "docs/simd_completeness_matrix.md"
    rc_doc = root / "docs/simd_release_candidate_checklist.md"

    checks: List[CheckItem] = []
    next_actions: List[str] = []
    default_batch_id = f"SIMD-{datetime.now():%Y%m%d}-152"
    require_qemu_cpuinfo_nonx86_step = parse_bool_env(
        QEMU_CPUINFO_NONX86_REQUIRE_ENV, default=not args.linux_only
    )
    require_qemu_cpuinfo_nonx86_full_step = parse_bool_env(
        QEMU_CPUINFO_NONX86_FULL_REQUIRE_ENV, default=False
    )
    require_qemu_cpuinfo_nonx86_full_repeat_step = parse_bool_env(
        QEMU_CPUINFO_NONX86_FULL_REPEAT_REQUIRE_ENV, default=False
    )
    require_cpuinfo_lazy_repeat_step = parse_bool_env(
        CPUINFO_LAZY_REPEAT_REQUIRE_ENV, default=False
    )
    required_gate_steps_mainline = build_required_gate_steps(
        include_windows_evidence_step=False,
        include_qemu_cpuinfo_nonx86_step=require_qemu_cpuinfo_nonx86_step,
        include_qemu_cpuinfo_nonx86_full_step=require_qemu_cpuinfo_nonx86_full_step,
        include_qemu_cpuinfo_nonx86_full_repeat_step=require_qemu_cpuinfo_nonx86_full_repeat_step,
        include_cpuinfo_lazy_repeat_step=require_cpuinfo_lazy_repeat_step,
    )
    required_gate_steps_cross = build_required_gate_steps(
        include_windows_evidence_step=not args.linux_only,
        include_qemu_cpuinfo_nonx86_step=require_qemu_cpuinfo_nonx86_step,
        include_qemu_cpuinfo_nonx86_full_step=require_qemu_cpuinfo_nonx86_full_step,
        include_qemu_cpuinfo_nonx86_full_repeat_step=require_qemu_cpuinfo_nonx86_full_repeat_step,
        include_cpuinfo_lazy_repeat_step=require_cpuinfo_lazy_repeat_step,
    )
    required_gate_steps = (
        required_gate_steps_mainline if args.linux_only else required_gate_steps_cross
    )
    simd_source_candidates = list(iter_simd_source_candidates(repo_root / "src"))

    gate_summary_candidates = discover_gate_summary_candidates(
        gate_summary, logs_dir, explicit_override=bool(gate_summary_override)
    )
    gate_run_assessments = assess_gate_runs(
        gate_summary_candidates,
        REQUIRED_GATE_STEPS_BASE,
        required_gate_steps_mainline,
        required_gate_steps_cross,
    )
    selected_gate_run, latest_gate_run, used_gate_fallback, gate_fallback_scope = select_effective_gate_run(
        gate_run_assessments,
        required_gate_steps,
        args.linux_only,
    )
    effective_gate_summary = gate_summary

    if selected_gate_run is None or latest_gate_run is None:
        checks.append(
            CheckItem(
                name="linux_gate_summary",
                required=True,
                status="FAIL",
                detail=f"missing terminal gate row in {gate_summary}",
            )
        )
        next_actions.append("bash tests/nextpas.core.simd/BuildOrTest.sh gate")
    else:
        effective_gate_summary = selected_gate_run.candidate.summary_path
        terminal_row = selected_gate_run.candidate.terminal_row
        required_ok_mainline = selected_gate_run.required_ok_mainline
        required_detail_mainline = selected_gate_run.required_detail_mainline
        required_ok_cross = selected_gate_run.required_ok_cross
        required_detail_cross = selected_gate_run.required_detail_cross
        selection_suffix = ""
        if used_gate_fallback:
            latest_scope_detail = "only covers mainline-required steps"
            if gate_fallback_scope == "mainline":
                latest_scope_detail = "only covers base-required steps"
            selection_suffix = (
                f"; {gate_run_fallback_label(selected_gate_run)} "
                f"{gate_run_label(selected_gate_run)} because latest snapshot "
                f"{gate_run_label(latest_gate_run)} {latest_scope_detail}"
            )

        if terminal_row["status"] == "PASS":
            checks.append(
                CheckItem(
                    name="linux_gate_summary",
                    required=True,
                    status="PASS",
                    detail=(
                        f"gate PASS at {terminal_row['time']}, event={terminal_row['event']}, "
                        f"duration_ms={terminal_row['duration_ms']}; summary={effective_gate_summary}"
                        f"{selection_suffix}"
                    ),
                )
            )
        elif required_ok_mainline:
            checks.append(
                CheckItem(
                    name="linux_gate_summary",
                    required=True,
                    status="PASS",
                    detail=(
                        "selected gate terminal status is FAIL but all mainline-required "
                        f"steps are PASS; summary={effective_gate_summary}{selection_suffix}"
                    ),
                )
            )
        else:
            checks.append(
                CheckItem(
                    name="linux_gate_summary",
                    required=True,
                    status="FAIL",
                    detail=(
                        f"selected gate status={terminal_row['status']} at {terminal_row['time']} "
                        f"(detail={terminal_row['detail']}); summary={effective_gate_summary}"
                    ),
                )
            )
            next_actions.append("bash tests/nextpas.core.simd/BuildOrTest.sh gate")

        checks.append(
            CheckItem(
                name="linux_gate_required_steps_mainline",
                required=True,
                status="PASS" if required_ok_mainline else "FAIL",
                detail=required_detail_mainline,
            )
        )
        if not required_ok_mainline:
            next_actions.append("bash tests/nextpas.core.simd/BuildOrTest.sh gate")

        if args.linux_only:
            checks.append(
                CheckItem(
                    name="cross_gate_required_steps",
                    required=False,
                    status="SKIP",
                    detail="linux-only mode: cross gate step check skipped",
                )
            )
        else:
            checks.append(
                CheckItem(
                    name="cross_gate_required_steps",
                    required=True,
                    status="PASS" if required_ok_cross else "FAIL",
                    detail=required_detail_cross,
                )
            )
            if not required_ok_cross:
                next_actions.append(CROSS_GATE_FAIL_CLOSE_CMD)

        selected_gate_rows = selected_gate_run.candidate.run_rows

        qemu_cpuinfo_nonx86_row = find_latest_step_row(
            selected_gate_rows, QEMU_CPUINFO_NONX86_STEP
        )
        if qemu_cpuinfo_nonx86_row is None:
            checks.append(
                CheckItem(
                    name="linux_qemu_cpuinfo_nonx86_evidence",
                    required=require_qemu_cpuinfo_nonx86_step,
                    status="FAIL" if require_qemu_cpuinfo_nonx86_step else "SKIP",
                    detail=(
                        f"missing {QEMU_CPUINFO_NONX86_STEP} in selected gate run; "
                        f"set {QEMU_CPUINFO_NONX86_REQUIRE_ENV}=1 to require this step"
                    ),
                )
            )
            if require_qemu_cpuinfo_nonx86_step:
                next_actions.append(
                    QEMU_CPUINFO_NONX86_GATE_CMD if args.linux_only else CROSS_GATE_FAIL_CLOSE_CMD
                )
        else:
            qemu_cpuinfo_nonx86_status = qemu_cpuinfo_nonx86_row.get("status", "")
            qemu_cpuinfo_nonx86_detail = qemu_cpuinfo_nonx86_row.get("detail", "")
            if qemu_cpuinfo_nonx86_status == "PASS":
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_evidence",
                        required=require_qemu_cpuinfo_nonx86_step,
                        status="PASS",
                        detail=(
                            f"step PASS at {qemu_cpuinfo_nonx86_row.get('time', '-')}, "
                            f"event={qemu_cpuinfo_nonx86_row.get('event', '-')}, "
                            f"duration_ms={qemu_cpuinfo_nonx86_row.get('duration_ms', '-')}"
                        ),
                    )
                )
                qemu_cpuinfo_nonx86_step_time = parse_gate_row_time(qemu_cpuinfo_nonx86_row)
                coverage_check = qemu_platform_coverage_check(
                    name="linux_qemu_cpuinfo_nonx86_evidence_platforms",
                    logs_dir=logs_dir,
                    scenario=QEMU_CPUINFO_NONX86_SCENARIO,
                    required_platforms=list(QEMU_CPUINFO_NONX86_REQUIRED_PLATFORMS),
                    required=require_qemu_cpuinfo_nonx86_step,
                    gate_step_time=qemu_cpuinfo_nonx86_step_time,
                )
                checks.append(coverage_check)
                if coverage_check.status == "FAIL":
                    next_actions.append(
                        QEMU_CPUINFO_NONX86_GATE_CMD if args.linux_only else CROSS_GATE_FAIL_CLOSE_CMD
                    )
            elif (
                qemu_cpuinfo_nonx86_status == "SKIP"
                and not require_qemu_cpuinfo_nonx86_step
            ):
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_evidence",
                        required=False,
                        status="SKIP",
                        detail=(
                            f"step SKIP in selected gate run ({qemu_cpuinfo_nonx86_detail}); "
                            f"set {QEMU_CPUINFO_NONX86_REQUIRE_ENV}=1 to enforce"
                        ),
                    )
                )
            else:
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_evidence",
                        required=require_qemu_cpuinfo_nonx86_step,
                        status="FAIL",
                        detail=(
                            f"step status={qemu_cpuinfo_nonx86_status} "
                            f"(detail={qemu_cpuinfo_nonx86_detail})"
                        ),
                    )
                )
                next_actions.append(
                    QEMU_CPUINFO_NONX86_GATE_CMD if args.linux_only else CROSS_GATE_FAIL_CLOSE_CMD
                )

        qemu_cpuinfo_nonx86_full_row = find_latest_step_row(
            selected_gate_rows, QEMU_CPUINFO_NONX86_FULL_STEP
        )
        if qemu_cpuinfo_nonx86_full_row is None:
            checks.append(
                CheckItem(
                    name="linux_qemu_cpuinfo_nonx86_full_evidence",
                    required=require_qemu_cpuinfo_nonx86_full_step,
                    status="FAIL" if require_qemu_cpuinfo_nonx86_full_step else "SKIP",
                    detail=(
                        f"missing {QEMU_CPUINFO_NONX86_FULL_STEP} in selected gate run; "
                        f"set {QEMU_CPUINFO_NONX86_FULL_REQUIRE_ENV}=1 to require this step"
                    ),
                )
            )
            if require_qemu_cpuinfo_nonx86_full_step:
                next_actions.append(QEMU_CPUINFO_NONX86_FULL_GATE_CMD)
        else:
            qemu_cpuinfo_nonx86_full_status = qemu_cpuinfo_nonx86_full_row.get("status", "")
            qemu_cpuinfo_nonx86_full_detail = qemu_cpuinfo_nonx86_full_row.get("detail", "")
            if qemu_cpuinfo_nonx86_full_status == "PASS":
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_full_evidence",
                        required=require_qemu_cpuinfo_nonx86_full_step,
                        status="PASS",
                        detail=(
                            f"step PASS at {qemu_cpuinfo_nonx86_full_row.get('time', '-')}, "
                            f"event={qemu_cpuinfo_nonx86_full_row.get('event', '-')}, "
                            f"duration_ms={qemu_cpuinfo_nonx86_full_row.get('duration_ms', '-')}"
                        ),
                    )
                )
                qemu_cpuinfo_nonx86_full_step_time = parse_gate_row_time(
                    qemu_cpuinfo_nonx86_full_row
                )
                coverage_check = qemu_platform_coverage_check(
                    name="linux_qemu_cpuinfo_nonx86_full_evidence_platforms",
                    logs_dir=logs_dir,
                    scenario=QEMU_CPUINFO_NONX86_FULL_SCENARIO,
                    required_platforms=list(QEMU_CPUINFO_NONX86_REQUIRED_PLATFORMS),
                    required=require_qemu_cpuinfo_nonx86_full_step,
                    gate_step_time=qemu_cpuinfo_nonx86_full_step_time,
                )
                checks.append(coverage_check)
                if coverage_check.status == "FAIL":
                    next_actions.append(QEMU_CPUINFO_NONX86_FULL_GATE_CMD)
            elif (
                qemu_cpuinfo_nonx86_full_status == "SKIP"
                and not require_qemu_cpuinfo_nonx86_full_step
            ):
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_full_evidence",
                        required=False,
                        status="SKIP",
                        detail=(
                            f"step SKIP in selected gate run ({qemu_cpuinfo_nonx86_full_detail}); "
                            f"set {QEMU_CPUINFO_NONX86_FULL_REQUIRE_ENV}=1 to enforce"
                        ),
                    )
                )
            else:
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_full_evidence",
                        required=require_qemu_cpuinfo_nonx86_full_step,
                        status="FAIL",
                        detail=(
                            f"step status={qemu_cpuinfo_nonx86_full_status} "
                            f"(detail={qemu_cpuinfo_nonx86_full_detail})"
                        ),
                    )
                )
                next_actions.append(QEMU_CPUINFO_NONX86_FULL_GATE_CMD)

        qemu_cpuinfo_nonx86_full_repeat_row = find_latest_step_row(
            selected_gate_rows, QEMU_CPUINFO_NONX86_FULL_REPEAT_STEP
        )
        if qemu_cpuinfo_nonx86_full_repeat_row is None:
            checks.append(
                CheckItem(
                    name="linux_qemu_cpuinfo_nonx86_full_repeat",
                    required=require_qemu_cpuinfo_nonx86_full_repeat_step,
                    status="FAIL" if require_qemu_cpuinfo_nonx86_full_repeat_step else "SKIP",
                    detail=(
                        f"missing {QEMU_CPUINFO_NONX86_FULL_REPEAT_STEP} in selected gate run; "
                        f"set {QEMU_CPUINFO_NONX86_FULL_REPEAT_REQUIRE_ENV}=1 to require this step"
                    ),
                )
            )
            if require_qemu_cpuinfo_nonx86_full_repeat_step:
                next_actions.append(QEMU_CPUINFO_NONX86_FULL_REPEAT_GATE_CMD)
        else:
            qemu_cpuinfo_nonx86_full_repeat_status = qemu_cpuinfo_nonx86_full_repeat_row.get(
                "status", ""
            )
            qemu_cpuinfo_nonx86_full_repeat_detail = qemu_cpuinfo_nonx86_full_repeat_row.get(
                "detail", ""
            )
            if qemu_cpuinfo_nonx86_full_repeat_status == "PASS":
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_full_repeat",
                        required=require_qemu_cpuinfo_nonx86_full_repeat_step,
                        status="PASS",
                        detail=(
                            f"step PASS at {qemu_cpuinfo_nonx86_full_repeat_row.get('time', '-')}, "
                            f"event={qemu_cpuinfo_nonx86_full_repeat_row.get('event', '-')}, "
                            f"duration_ms={qemu_cpuinfo_nonx86_full_repeat_row.get('duration_ms', '-')}"
                        ),
                    )
                )
                qemu_cpuinfo_nonx86_full_repeat_step_time = parse_gate_row_time(
                    qemu_cpuinfo_nonx86_full_repeat_row
                )
                coverage_check = qemu_platform_coverage_check(
                    name="linux_qemu_cpuinfo_nonx86_full_repeat_platforms",
                    logs_dir=logs_dir,
                    scenario=QEMU_CPUINFO_NONX86_FULL_REPEAT_SCENARIO,
                    required_platforms=list(QEMU_CPUINFO_NONX86_REQUIRED_PLATFORMS),
                    required=require_qemu_cpuinfo_nonx86_full_repeat_step,
                    gate_step_time=qemu_cpuinfo_nonx86_full_repeat_step_time,
                )
                checks.append(coverage_check)
                if coverage_check.status == "FAIL":
                    next_actions.append(QEMU_CPUINFO_NONX86_FULL_REPEAT_GATE_CMD)
            elif (
                qemu_cpuinfo_nonx86_full_repeat_status == "SKIP"
                and not require_qemu_cpuinfo_nonx86_full_repeat_step
            ):
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_full_repeat",
                        required=False,
                        status="SKIP",
                        detail=(
                            f"step SKIP in selected gate run ({qemu_cpuinfo_nonx86_full_repeat_detail}); "
                            f"set {QEMU_CPUINFO_NONX86_FULL_REPEAT_REQUIRE_ENV}=1 to enforce"
                        ),
                    )
                )
            else:
                checks.append(
                    CheckItem(
                        name="linux_qemu_cpuinfo_nonx86_full_repeat",
                        required=require_qemu_cpuinfo_nonx86_full_repeat_step,
                        status="FAIL",
                        detail=(
                            f"step status={qemu_cpuinfo_nonx86_full_repeat_status} "
                            f"(detail={qemu_cpuinfo_nonx86_full_repeat_detail})"
                        ),
                    )
                )
                next_actions.append(QEMU_CPUINFO_NONX86_FULL_REPEAT_GATE_CMD)

        cpuinfo_lazy_repeat_row = find_latest_step_row(
            selected_gate_rows, CPUINFO_LAZY_REPEAT_STEP
        )
        if cpuinfo_lazy_repeat_row is None:
            checks.append(
                CheckItem(
                    name="linux_cpuinfo_lazy_repeat",
                    required=require_cpuinfo_lazy_repeat_step,
                    status="FAIL" if require_cpuinfo_lazy_repeat_step else "SKIP",
                    detail=(
                        f"missing {CPUINFO_LAZY_REPEAT_STEP} in selected gate run; "
                        f"set {CPUINFO_LAZY_REPEAT_REQUIRE_ENV}=1 to require this step"
                    ),
                )
            )
            if require_cpuinfo_lazy_repeat_step:
                next_actions.append(CPUINFO_LAZY_REPEAT_GATE_CMD)
        else:
            cpuinfo_lazy_repeat_status = cpuinfo_lazy_repeat_row.get("status", "")
            cpuinfo_lazy_repeat_detail = cpuinfo_lazy_repeat_row.get("detail", "")
            if cpuinfo_lazy_repeat_status == "PASS":
                checks.append(
                    CheckItem(
                        name="linux_cpuinfo_lazy_repeat",
                        required=require_cpuinfo_lazy_repeat_step,
                        status="PASS",
                        detail=(
                            f"step PASS at {cpuinfo_lazy_repeat_row.get('time', '-')}, "
                            f"event={cpuinfo_lazy_repeat_row.get('event', '-')}, "
                            f"duration_ms={cpuinfo_lazy_repeat_row.get('duration_ms', '-')}"
                        ),
                    )
                )
            elif (
                cpuinfo_lazy_repeat_status == "SKIP"
                and not require_cpuinfo_lazy_repeat_step
            ):
                checks.append(
                    CheckItem(
                        name="linux_cpuinfo_lazy_repeat",
                        required=False,
                        status="SKIP",
                        detail=(
                            f"step SKIP in selected gate run ({cpuinfo_lazy_repeat_detail}); "
                            f"set {CPUINFO_LAZY_REPEAT_REQUIRE_ENV}=1 to enforce"
                        ),
                    )
                )
            else:
                checks.append(
                    CheckItem(
                        name="linux_cpuinfo_lazy_repeat",
                        required=require_cpuinfo_lazy_repeat_step,
                        status="FAIL",
                        detail=(
                            f"step status={cpuinfo_lazy_repeat_status} "
                            f"(detail={cpuinfo_lazy_repeat_detail})"
                        ),
                    )
                )
                next_actions.append(CPUINFO_LAZY_REPEAT_GATE_CMD)

    checks.append(
        freshness_check(
            "linux_gate_summary_freshness",
            effective_gate_summary,
            args.fresh_hours,
            required=True,
        )
    )
    if checks[-1].status != "PASS":
        next_actions.append("bash tests/nextpas.core.simd/BuildOrTest.sh gate")
    checks.append(
        sources_not_newer_than_artifact_check(
            "linux_sources_not_newer_than_gate",
            effective_gate_summary,
            simd_source_candidates,
            required=True,
        )
    )
    if checks[-1].status != "PASS":
        next_actions.append("bash tests/nextpas.core.simd/BuildOrTest.sh gate")

    if windows_log.is_file():
        checks.append(
            CheckItem(
                name="windows_evidence_log",
                required=True,
                status="PASS",
                detail=f"found {windows_log}",
            )
        )
    elif windows_log_sim.is_file():
        checks.append(
            CheckItem(
                name="windows_evidence_log",
                required=True,
                status="FAIL",
                detail=(
                    f"real log missing ({windows_log}), only simulated exists ({windows_log_sim})"
                ),
            )
        )
        next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")
    else:
        checks.append(
            CheckItem(
                name="windows_evidence_log",
                required=True,
                status="FAIL",
                detail=f"missing {windows_log}",
            )
        )
        next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")

    checks.append(freshness_check("windows_evidence_freshness", windows_log, args.fresh_hours, required=True))
    if checks[-1].status != "PASS":
        next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")
    windows_evidence_inputs_current = True
    checks.append(
        candidate_paths_not_newer_than_artifact_check(
            "windows_evidence_inputs_not_newer_than_log",
            windows_log,
            windows_evidence_log_input_candidates,
            required=True,
        )
    )
    windows_evidence_inputs_current = checks[-1].status == "PASS"
    if checks[-1].status != "PASS":
        next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")
    if not args.linux_only:
        checks.append(
            sources_not_newer_than_artifact_check(
                "windows_sources_not_newer_than_evidence",
                windows_log,
                simd_source_candidates,
                required=True,
            )
        )
        if checks[-1].status != "PASS":
            next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")
        checks.append(describe_windows_preflight_report(windows_preflight_json))

    windows_verify_ok: Optional[bool] = None
    windows_toolchain_block = False
    if args.linux_only:
        windows_verify_ok = None
        checks.append(
            CheckItem(
                name="windows_evidence_verify",
                required=False,
                status="SKIP",
                detail="linux-only mode: verifier skipped",
            )
        )
    elif windows_log.is_file() and verify_script.is_file():
        verify_proc = run_verify_script(verify_script, windows_log)
        if not windows_evidence_inputs_current:
            windows_verify_ok = False
            if verify_proc.returncode == 0:
                verify_detail = (
                    "stale evidence log: newer Windows evidence producer input exists; "
                    "verifier passes on historical log, rerun evidence-win-verify before trusting it"
                )
            else:
                verify_detail = (
                    "stale evidence log: newer Windows evidence producer input exists; "
                    f"historical verifier detail: {summarize_verify_failure(verify_proc, windows_log)}"
                )
            checks.append(
                CheckItem(
                    name="windows_evidence_verify",
                    required=True,
                    status="FAIL",
                    detail=verify_detail,
                )
            )
            next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")
        elif verify_proc.returncode == 0:
            windows_verify_ok = True
            checks.append(
                CheckItem(
                    name="windows_evidence_verify",
                    required=True,
                    status="PASS",
                    detail="verify_windows_b07_evidence.sh passed",
                )
            )
        else:
            windows_verify_ok = False
            verify_detail = summarize_verify_failure(verify_proc, windows_log)
            windows_toolchain_block = is_windows_toolchain_block(verify_detail)
            checks.append(
                CheckItem(
                    name="windows_evidence_verify",
                    required=True,
                    status="FAIL",
                    detail=verify_detail,
                )
            )
            next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")
    elif not verify_script.is_file():
        windows_verify_ok = False
        checks.append(
            CheckItem(
                name="windows_evidence_verify",
                required=True,
                status="FAIL",
                detail=f"missing verifier script: {verify_script}",
            )
        )
    else:
        windows_verify_ok = False
        checks.append(
            CheckItem(
                name="windows_evidence_verify",
                required=True,
                status="FAIL",
                detail="skip until real windows evidence log is available",
            )
        )

    if not args.linux_only:
        cross_gate_check = next(
            (check for check in checks if check.name == "cross_gate_required_steps"),
            None,
        )
        if (
            cross_gate_check is not None
            and "evidence-verify=SKIP" in cross_gate_check.detail
        ):
            if windows_verify_ok is True:
                cross_gate_check.detail += (
                    "; selected gate run skipped Windows evidence enforcement; "
                    "standalone verifier now PASS, but fail-close cross gate still needs a fresh rerun"
                )
            elif windows_verify_ok is False:
                cross_gate_check.detail += (
                    "; selected gate run skipped Windows evidence enforcement; "
                    "see windows_evidence_verify for the current failure root cause"
                )

    if closeout_summary.is_file():
        windows_closeout_summary_current = True
        checks.append(
            artifact_not_older_than_reference_check(
                "windows_closeout_summary_not_older_than_log",
                closeout_summary,
                windows_log,
                required=True,
            )
        )
        windows_closeout_summary_current = checks[-1].status == "PASS"
        if checks[-1].status != "PASS":
            next_actions.append("bash tests/nextpas.core.simd/BuildOrTest.sh finalize-win-evidence")

        summary_text = closeout_summary.read_text(encoding="utf-8", errors="ignore")
        has_result_pass = "- Result: PASS" in summary_text
        has_result_fail = "- Result: FAIL" in summary_text
        if not windows_evidence_inputs_current:
            checks.append(
                CheckItem(
                    name="windows_closeout_summary",
                    required=True,
                    status="FAIL",
                    detail=(
                        "stale summary: newer Windows evidence producer input exists; "
                        f"rerun evidence-win-verify / closeout before trusting {closeout_summary}"
                    ),
                )
            )
            next_actions.append("tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify")
        elif not windows_closeout_summary_current:
            checks.append(
                CheckItem(
                    name="windows_closeout_summary",
                    required=True,
                    status="FAIL",
                    detail=(
                        "stale summary: closeout summary is older than current windows evidence log; "
                        f"rerun finalize-win-evidence before trusting {closeout_summary}"
                    ),
                )
            )
            next_actions.append("bash tests/nextpas.core.simd/BuildOrTest.sh finalize-win-evidence")
        elif windows_verify_ok is True:
            if has_result_pass:
                checks.append(
                    CheckItem(
                        name="windows_closeout_summary",
                        required=True,
                        status="PASS",
                        detail=f"summary matches verifier PASS: {closeout_summary}",
                    )
                )
            else:
                checks.append(
                    CheckItem(
                        name="windows_closeout_summary",
                        required=True,
                        status="FAIL",
                        detail=(
                            "summary missing '- Result: PASS' while verifier passes: "
                            f"{closeout_summary}"
                        ),
                    )
                )
        elif windows_verify_ok is False:
            if has_result_fail:
                checks.append(
                    CheckItem(
                        name="windows_closeout_summary",
                        required=True,
                        status="PASS",
                        detail=f"summary matches verifier FAIL: {closeout_summary}",
                    )
                )
            else:
                checks.append(
                    CheckItem(
                        name="windows_closeout_summary",
                        required=True,
                        status="FAIL",
                        detail=(
                            "stale/invalid closeout summary: verifier fails but summary "
                            "missing '- Result: FAIL': "
                            f"{closeout_summary}"
                        ),
                    )
                )
        elif has_result_pass or has_result_fail:
            checks.append(
                CheckItem(
                    name="windows_closeout_summary",
                    required=True,
                    status="PASS",
                    detail=f"summary contains result marker: {closeout_summary}",
                )
            )
        else:
            checks.append(
                CheckItem(
                    name="windows_closeout_summary",
                    required=True,
                    status="FAIL",
                    detail=(
                        "summary missing '- Result: PASS' or '- Result: FAIL': "
                        f"{closeout_summary}"
                    ),
                )
            )
    elif closeout_summary_sim.is_file():
        checks.append(
            CheckItem(
                name="windows_closeout_summary",
                required=True,
                status="FAIL",
                detail=(
                    f"real closeout summary missing ({closeout_summary}), "
                    f"only simulated exists ({closeout_summary_sim})"
                ),
            )
        )
        next_actions.append(
            f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize {default_batch_id}"
        )
    else:
        checks.append(
            CheckItem(
                name="windows_closeout_summary",
                required=True,
                status="FAIL",
                detail=f"missing {closeout_summary}",
            )
        )
        next_actions.append(
            f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize {default_batch_id}"
        )

    if checks and checks[-1].name == "windows_closeout_summary" and checks[-1].status != "PASS":
        next_actions.append(
            f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize {default_batch_id}"
        )

    checks.append(freshness_check("windows_closeout_freshness", closeout_summary, args.fresh_hours, required=True))
    if checks[-1].status != "PASS":
        next_actions.append(
            f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize {default_batch_id}"
        )

    roadmap_closed = check_line_markdown_x(roadmap_doc, "Windows 实机证据")
    if roadmap_closed is True:
        checks.append(
            CheckItem(
                "roadmap_windows_closed",
                False,
                "PASS",
                "roadmap historical Windows archive marker is [x] (not a current readiness signal)",
            )
        )
    elif roadmap_closed is False:
        checks.append(
            CheckItem(
                "roadmap_windows_closed",
                False,
                "PENDING",
                "roadmap Windows archive marker still [ ]",
            )
        )
    else:
        checks.append(CheckItem("roadmap_windows_closed", False, "FAIL", f"missing doc: {roadmap_doc}"))

    rc_closed = check_line_markdown_x(rc_doc, "Windows 实机证据日志已归档")
    if rc_closed is False:
        rc_closed = check_line_markdown_x(rc_doc, "Windows 实机证据日志曾归档")
    if rc_closed is True:
        checks.append(
            CheckItem(
                "rc_windows_closed",
                False,
                "PASS",
                "RC checklist historical Windows archive row is [x] (not a current readiness signal)",
            )
        )
    elif rc_closed is False:
        checks.append(
            CheckItem(
                "rc_windows_closed",
                False,
                "PENDING",
                "RC checklist Windows archive row still [ ]",
            )
        )
    else:
        checks.append(CheckItem("rc_windows_closed", False, "FAIL", f"missing doc: {rc_doc}"))

    matrix_text = matrix_doc.read_text(encoding="utf-8", errors="ignore") if matrix_doc.is_file() else ""
    if not matrix_text:
        checks.append(CheckItem("matrix_windows_closed", False, "FAIL", f"missing doc: {matrix_doc}"))
    elif (
        "Windows 证据：实机日志已归档" in matrix_text
        or "[x] Windows 实机证据已归档" in matrix_text
        or "[x] Windows 实机证据曾归档" in matrix_text
    ):
        checks.append(
            CheckItem(
                "matrix_windows_closed",
                False,
                "PASS",
                "completeness matrix contains historical Windows archive marker (not a current readiness signal)",
            )
        )
    else:
        checks.append(
            CheckItem(
                "matrix_windows_closed",
                False,
                "PENDING",
                "completeness matrix still indicates pending Windows evidence",
            )
        )

    if args.linux_only:
        for item in checks:
            if item.name.startswith("windows_"):
                item.required = False
                if item.status in {"FAIL", "PENDING"}:
                    item.status = "SKIP"
                    item.detail = f"linux-only mode: {item.detail}"

        next_actions = [
            action
            for action in next_actions
            if "buildOrTest.bat" not in action
            and "finalize-win-evidence" not in action
            and "win-evidence-preflight" not in action
            and "win-closeout-" not in action
        ]

    mainline_ready = compute_ready(checks, include_windows=False)
    if args.linux_only:
        cross_ready: Optional[bool] = None
        freeze_ready = mainline_ready
    else:
        cross_ready = compute_ready(checks, include_windows=True)
        freeze_ready = cross_ready

    if not args.linux_only and freeze_ready:
        preflight_check = next(
            (check for check in checks if check.name == "windows_preflight_latest"),
            None,
        )
        if preflight_check is not None and preflight_check.status == "FAIL":
            preflight_check.status = "SKIP"
            preflight_check.detail += (
                "; GH preflight path remains blocked/noisy, but required Windows evidence "
                "and fail-close cross gate are already green, so this is not a current readiness signal"
            )

    if not freeze_ready and not args.linux_only:
        recent_billing_block = has_recent_windows_billing_block(windows_preflight_json)
        if recent_billing_block:
            preferred_actions = [
                (
                    "Resolve GitHub Billing & plans or switch to a real Windows runner; "
                    "current preflight reports RECENT_BILLING_BLOCK"
                ),
            ]
            if windows_toolchain_block:
                preferred_actions.append(WINDOWS_TOOLCHAIN_ACTION)
            preferred_actions.extend(
                [
                    "bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-preflight",
                    f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-3cmd {default_batch_id}",
                ]
            )
            blocked_actions = {
                (
                    "FAFAFA_BUILD_MODE=Release "
                    f"bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-via-gh {default_batch_id}"
                ),
                "tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify",
                CROSS_GATE_FAIL_CLOSE_CMD,
                f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize {default_batch_id}",
            }
            next_actions = [action for action in next_actions if action not in blocked_actions]
        else:
            preferred_actions = []
            if windows_toolchain_block:
                preferred_actions.append(WINDOWS_TOOLCHAIN_ACTION)
            preferred_actions.extend(
                [
                    "bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-preflight",
                    (
                        "FAFAFA_BUILD_MODE=Release "
                        f"bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-via-gh {default_batch_id}"
                    ),
                    "tests\\nextpas.core.simd\\buildOrTest.bat evidence-win-verify",
                    CROSS_GATE_FAIL_CLOSE_CMD,
                    f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize {default_batch_id}",
                    f"bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-3cmd {default_batch_id}",
                ]
            )
        next_actions = preferred_actions + next_actions
        next_actions = [
            action
            for action in next_actions
            if action != "bash tests/nextpas.core.simd/BuildOrTest.sh gate"
        ]

    dedup_actions: List[str] = []
    for action in next_actions:
        if action not in dedup_actions:
            dedup_actions.append(action)

    payload = {
        "mode": "linux-only" if args.linux_only else "cross-platform",
        "linux_only": args.linux_only,
        # Keep `ready` for backward-compatible consumers.
        "ready": freeze_ready,
        "freeze_ready": freeze_ready,
        "mainline_ready": mainline_ready,
        "cross_ready": cross_ready,
        "require_qemu_cpuinfo_nonx86_full_evidence": require_qemu_cpuinfo_nonx86_full_step,
        "require_qemu_cpuinfo_nonx86_full_repeat": require_qemu_cpuinfo_nonx86_full_repeat_step,
        "require_cpuinfo_lazy_repeat": require_cpuinfo_lazy_repeat_step,
        "root": str(root),
        "fresh_hours": args.fresh_hours,
        "required_gate_steps": required_gate_steps,
        "required_gate_steps_mainline": required_gate_steps_mainline,
        "required_gate_steps_cross": required_gate_steps_cross,
        "gate_summary_file": str(effective_gate_summary),
        "gate_summary_fallback_used": used_gate_fallback,
        "latest_gate_summary_file": (
            str(latest_gate_run.candidate.summary_path) if latest_gate_run is not None else ""
        ),
        "checks": [asdict(item) for item in checks],
        "next_actions": dedup_actions,
    }

    if args.json_file:
        json_path = Path(args.json_file)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))

    display_checks = checks
    if args.linux_only:
        display_checks = [
            item
            for item in checks
            if "windows" not in item.name and not item.name.startswith("cross_")
        ]

    print("[FREEZE] SIMD freeze status")
    cross_ready_display = "N/A" if cross_ready is None else str(cross_ready)
    print(
        f"[FREEZE] mode={payload['mode']}, ready={payload['freeze_ready']}, "
        f"mainline-ready={mainline_ready}, cross-ready={cross_ready_display}, "
        f"fresh_hours={payload['fresh_hours']:.2f}"
    )
    for item in display_checks:
        print(f"[FREEZE] {item.status:<7} {item.name}: {item.detail}")

    if dedup_actions:
        print("[FREEZE] next-actions:")
        for action in dedup_actions:
            print(f"  - {action}")

    return 0 if freeze_ready else 1


if __name__ == "__main__":
    raise SystemExit(main())

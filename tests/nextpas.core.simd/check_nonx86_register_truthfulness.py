#!/usr/bin/env python3
"""Check non-x86 backend register files for truthful implementation ownership."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


ASSIGN_RE = re.compile(
    r"^\s*table\.([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*@([A-Za-z_][A-Za-z0-9_]*)\s*;\s*(?://.*)?$"
)
DEF_RE = re.compile(r"^\s*(function|procedure)\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.IGNORECASE)
IFDEF_RE = re.compile(r"^\s*\{\$IFDEF\s+([A-Za-z_][A-Za-z0-9_]*)\s*\}\s*$", re.IGNORECASE)
IFNDEF_RE = re.compile(r"^\s*\{\$IFNDEF\s+([A-Za-z_][A-Za-z0-9_]*)\s*\}\s*$", re.IGNORECASE)
ELSE_RE = re.compile(r"^\s*\{\$ELSE\s*\}\s*$", re.IGNORECASE)
ENDIF_RE = re.compile(r"^\s*\{\$ENDIF\s*\}\s*$", re.IGNORECASE)

NEON_WIDE_COMPARE_ASM_ONLY_BACKEND_COMPOSED_SLOTS: set[str] = {
    "CmpEqI32x16", "CmpEqI32x8", "CmpEqI64x4", "CmpEqI64x8", "CmpEqU32x8", "CmpEqU64x4",
    "CmpGeI32x16", "CmpGeI32x8", "CmpGeI64x4", "CmpGeI64x8", "CmpGeU32x8", "CmpGeU64x4",
    "CmpGtI32x16", "CmpGtI32x8", "CmpGtI64x4", "CmpGtI64x8", "CmpGtU32x8", "CmpGtU64x4",
    "CmpLeI32x16", "CmpLeI32x8", "CmpLeI64x4", "CmpLeI64x8", "CmpLeU32x8", "CmpLeU64x4",
    "CmpLtI32x16", "CmpLtI32x8", "CmpLtI64x4", "CmpLtI64x8", "CmpLtU32x8", "CmpLtU64x4",
    "CmpNeI32x16", "CmpNeI32x8", "CmpNeI64x4", "CmpNeI64x8", "CmpNeU32x8", "CmpNeU64x4",
}

NEON_FACADE_ASM_ONLY_BACKEND_COMPOSED_SLOTS: set[str] = {
    "AddF32x16", "AddF64x8",
    "DivF32x16", "DivF64x8",
    "MaxF32x16", "MaxF64x8",
    "MinF32x16", "MinF64x8",
    "MulF32x16", "MulF64x8",
    "SubF32x16", "SubF64x8",
    "AndNotI8x16", "AndNotU16x8", "AndNotU8x16",
}

NEON_NO_ASM_ONLY_BACKEND_COMPOSED_SLOTS: set[str] = set()

ALLOWED_ALWAYS_WRAPPER_SLOTS_BY_BACKEND: dict[str, set[str]] = {
    "neon": set(),
    "riscvv": set(),
}

ALLOWED_ALWAYS_BACKEND_COMPOSED_SLOTS_BY_BACKEND: dict[str, set[str]] = {
    "neon": set(),
    "riscvv": set(),
}

ALLOWED_ASM_ONLY_WRAPPER_SLOTS_BY_BACKEND: dict[str, set[str]] = {
    "neon": set(),
    "riscvv": set(),
}

ALLOWED_NO_ASM_ONLY_WRAPPER_SLOTS_BY_BACKEND: dict[str, set[str]] = {
    "neon": set(),
}

ALLOWED_ASM_ONLY_BACKEND_COMPOSED_SLOTS_BY_BACKEND: dict[str, set[str]] = {
    "neon": (
        NEON_WIDE_COMPARE_ASM_ONLY_BACKEND_COMPOSED_SLOTS
        | NEON_FACADE_ASM_ONLY_BACKEND_COMPOSED_SLOTS
    ),
    "riscvv": {
        "AndNotI8x16", "AndNotU16x8", "AndNotU8x16",
    },
    "fixture-composed": {"Compose"},
}

ALLOWED_NO_ASM_ONLY_BACKEND_COMPOSED_SLOTS_BY_BACKEND: dict[str, set[str]] = {
    "neon": NEON_NO_ASM_ONLY_BACKEND_COMPOSED_SLOTS,
}

ALLOWED_ALWAYS_ASM_HELPER_SLOTS_BY_BACKEND: dict[str, set[str]] = {
    "riscvv": {
        "ShiftLeftI32x8", "ShiftRightI32x8", "ShiftRightArithI32x8",
        "ShiftLeftI32x16", "ShiftRightI32x16", "ShiftRightArithI32x16",
        "ShiftLeftI64x4", "ShiftRightI64x4", "ShiftRightArithI64x4",
    },
}


@dataclass
class SymbolFacts:
    has_definition: bool = False
    has_assembler: bool = False
    bodies: list[str] = field(default_factory=list)


@dataclass
class Assignment:
    slot: str
    target: str
    line: int
    context: str


@dataclass
class CheckerConfig:
    backend: str
    asm_symbol: str
    symbol_prefix: str
    register_file: Path
    source_files: list[Path]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check non-x86 register truthfulness")
    parser.add_argument("--backend", choices=("neon", "riscvv"), help="Backend to inspect")
    parser.add_argument("--fixture", choices=("good", "bad", "shadowed", "mixed", "composed"), help="Run against a local fixture instead of real sources")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON")
    parser.add_argument("--summary-line", action="store_true", help="Print one-line summary for log scraping")
    parser.add_argument("--strict", action="store_true", help="Treat wrapper / helper-forwarder bindings as failures")
    args = parser.parse_args()

    if not args.backend and not args.fixture:
        parser.error("one of --backend or --fixture is required")
    if args.backend and args.fixture:
        parser.error("--backend and --fixture are mutually exclusive")
    return args


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def build_config(a_root: Path, a_args: argparse.Namespace) -> CheckerConfig:
    if a_args.fixture:
        l_fixture_root = a_root / "tests" / "nextpas.core.simd" / "fixtures" / "nonx86_register_truthfulness" / a_args.fixture
        return CheckerConfig(
            backend=f"fixture-{a_args.fixture}",
            asm_symbol="MOCK_ASM",
            symbol_prefix="MOCK",
            register_file=l_fixture_root / "mock.backend.register.inc",
            source_files=[l_fixture_root / "mock.backend.pas"],
        )

    l_src = a_root / "src"
    if a_args.backend == "neon":
        l_sources = sorted(l_src.glob("nextpas.core.simd.neon*"))
        l_sources.append(l_src / "nextpas.core.simd.scalar.pas")
        return CheckerConfig(
            backend="neon",
            asm_symbol="FAFAFA_SIMD_NEON_ASM_ENABLED",
            symbol_prefix="NEON",
            register_file=l_src / "nextpas.core.simd.neon.register.inc",
            source_files=[l_file for l_file in l_sources if l_file.is_file()],
        )

    if a_args.backend == "riscvv":
        l_sources = sorted(l_src.glob("nextpas.core.simd.riscvv*"))
        l_sources.append(l_src / "nextpas.core.simd.scalar.pas")
        return CheckerConfig(
            backend="riscvv",
            asm_symbol="RISCVV_ASSEMBLY",
            symbol_prefix="RISCVV",
            register_file=l_src / "nextpas.core.simd.riscvv.register.inc",
            source_files=[l_file for l_file in l_sources if l_file.is_file()],
        )

    raise RuntimeError(f"unsupported backend: {a_args.backend}")


def validate_inputs(a_config: CheckerConfig) -> None:
    if not a_config.register_file.is_file():
        raise RuntimeError(f"missing register file: {a_config.register_file}")
    if not a_config.source_files:
        raise RuntimeError("no source files configured")
    for l_source in a_config.source_files:
        if not l_source.is_file():
            raise RuntimeError(f"missing source file: {l_source}")


def strip_comment(a_line: str) -> str:
    return a_line.split("//", 1)[0].rstrip()


def preprocess_for_asm_state(a_text: str, a_asm_symbol: str, a_asm_enabled: bool) -> str:
    l_lines: list[str] = []
    l_stack: list[tuple[bool, bool, bool]] = []
    l_active = True
    l_asm_symbol_lower = a_asm_symbol.lower()

    for l_line_no, l_line in enumerate(a_text.splitlines(), start=1):
        l_clean = strip_comment(l_line).strip()

        l_ifdef = IFDEF_RE.match(l_clean)
        if l_ifdef is not None:
            l_symbol = l_ifdef.group(1).lower()
            l_is_target = l_symbol == l_asm_symbol_lower
            if l_is_target:
                l_true_branch_active = a_asm_enabled
                l_stack.append((l_active, l_true_branch_active, False))
                l_active = l_active and l_true_branch_active
            continue

        l_ifndef = IFNDEF_RE.match(l_clean)
        if l_ifndef is not None:
            l_symbol = l_ifndef.group(1).lower()
            l_is_target = l_symbol == l_asm_symbol_lower
            if l_is_target:
                l_true_branch_active = not a_asm_enabled
                l_stack.append((l_active, l_true_branch_active, False))
                l_active = l_active and l_true_branch_active
            continue

        if ELSE_RE.match(l_clean):
            if not l_stack:
                continue
            l_parent_active, l_true_branch_active, l_seen_else = l_stack.pop()
            if l_seen_else:
                raise RuntimeError(f"duplicate {{$ELSE}} at line {l_line_no}")
            l_active = l_parent_active and (not l_true_branch_active)
            l_stack.append((l_parent_active, l_true_branch_active, True))
            continue

        if ENDIF_RE.match(l_clean):
            if not l_stack:
                continue
            l_parent_active, _, _ = l_stack.pop()
            l_active = l_parent_active
            continue

        if l_active:
            l_lines.append(l_line)

    if l_stack:
        raise RuntimeError(f"unterminated conditional block for asm symbol {a_asm_symbol}")
    return "\n".join(l_lines)


def collect_symbol_facts(a_files: list[Path], a_asm_symbol: str, a_asm_enabled: bool) -> dict[str, SymbolFacts]:
    l_facts: dict[str, SymbolFacts] = {}
    for l_file in a_files:
        l_text = preprocess_for_asm_state(
            l_file.read_text(encoding="utf-8", errors="ignore"),
            a_asm_symbol,
            a_asm_enabled,
        )
        l_current_name: str | None = None
        l_current_is_assembler = False
        l_current_body: list[str] = []

        def flush_current() -> None:
            nonlocal l_current_name
            nonlocal l_current_is_assembler
            nonlocal l_current_body

            if l_current_name is None:
                return
            if (
                len(l_current_body) == 1
                and re.search(r"\bforward\s*;\s*$", l_current_body[0], re.IGNORECASE)
            ):
                l_current_name = None
                l_current_is_assembler = False
                l_current_body = []
                return
            l_info = l_facts.setdefault(l_current_name, SymbolFacts())
            l_info.has_definition = True
            if l_current_is_assembler:
                l_info.has_assembler = True
            else:
                l_info.bodies.append("\n".join(l_current_body))
            l_current_name = None
            l_current_is_assembler = False
            l_current_body = []

        for l_line in l_text.splitlines():
            l_clean = strip_comment(l_line).strip()
            if not l_clean:
                continue
            l_match = DEF_RE.match(l_clean)
            if l_match is not None:
                flush_current()
                l_current_name = l_match.group(2)
                l_current_is_assembler = "assembler" in l_clean.lower()
                l_current_body = [l_clean]
                continue
            if l_current_name is not None:
                l_current_body.append(l_clean)

        flush_current()
    return l_facts


def merge_symbol_facts(*a_fact_maps: dict[str, SymbolFacts]) -> dict[str, SymbolFacts]:
    l_merged: dict[str, SymbolFacts] = {}
    for l_fact_map in a_fact_maps:
        for l_name, l_info in l_fact_map.items():
            l_target = l_merged.setdefault(l_name, SymbolFacts())
            l_target.has_definition = l_target.has_definition or l_info.has_definition
            l_target.has_assembler = l_target.has_assembler or l_info.has_assembler
            l_target.bodies.extend(l_info.bodies)
    return l_merged


def parse_assignments(a_register_file: Path, a_asm_symbol: str) -> list[Assignment]:
    l_assignments: list[Assignment] = []
    l_context: str | None = None
    l_stack: list[tuple[str | None, str | None, bool]] = []
    l_asm_symbol_lower = a_asm_symbol.lower()

    for l_line_no, l_raw_line in enumerate(a_register_file.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1):
        l_clean = strip_comment(l_raw_line).strip()
        if not l_clean:
            continue

        l_ifdef = IFDEF_RE.match(l_clean)
        if l_ifdef is not None:
            l_symbol = l_ifdef.group(1).lower()
            l_branch_context = "asm-only" if l_symbol == l_asm_symbol_lower else None
            l_stack.append((l_context, l_branch_context, False))
            if l_branch_context is not None:
                l_context = l_branch_context
            continue

        l_ifndef = IFNDEF_RE.match(l_clean)
        if l_ifndef is not None:
            l_symbol = l_ifndef.group(1).lower()
            l_branch_context = "no-asm" if l_symbol == l_asm_symbol_lower else None
            l_stack.append((l_context, l_branch_context, False))
            if l_branch_context is not None:
                l_context = l_branch_context
            continue

        if ELSE_RE.match(l_clean):
            if not l_stack:
                raise RuntimeError(f"unexpected {{$ELSE}} at line {l_line_no}")
            l_parent_context, l_branch_context, l_seen_else = l_stack.pop()
            if l_seen_else:
                raise RuntimeError(f"duplicate {{$ELSE}} at line {l_line_no}")
            if l_branch_context == "asm-only":
                l_context = "no-asm"
            elif l_branch_context == "no-asm":
                l_context = "asm-only"
            else:
                l_context = l_parent_context
            l_stack.append((l_parent_context, l_branch_context, True))
            continue

        if ENDIF_RE.match(l_clean):
            if not l_stack:
                raise RuntimeError(f"unexpected {{$ENDIF}} at line {l_line_no}")
            l_parent_context, _, _ = l_stack.pop()
            l_context = l_parent_context
            continue

        l_match = ASSIGN_RE.match(l_clean)
        if l_match is None:
            continue

        l_assignments.append(
            Assignment(
                slot=l_match.group(1),
                target=l_match.group(2),
                line=l_line_no,
                context=l_context or "always",
            )
        )

    if l_stack:
        raise RuntimeError(f"unterminated conditional block in {a_register_file}")
    return l_assignments


def detect_backend_composed_helper(
    a_target: str,
    a_body_text: str,
    a_backend_prefix: str,
) -> str | None:
    for l_callee in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", a_body_text):
        if l_callee == a_target:
            continue
        if l_callee in {f"{a_target}_ASM", f"{a_target}Asm"}:
            continue
        if l_callee.startswith(a_backend_prefix):
            return l_callee
    return None


def classify_wrapper_body(
    a_target: str,
    a_body_text: str,
    a_facts: dict[str, SymbolFacts],
    a_backend_prefix: str,
) -> tuple[str, str | None]:
    for l_helper in (f"{a_target}_ASM", f"{a_target}Asm"):
        l_helper_info = a_facts.get(l_helper)
        if l_helper_info is not None and l_helper_info.has_assembler:
            if re.search(rf"\b{re.escape(l_helper)}(?:\s*\(|\b)", a_body_text):
                return "asm_helper_forwarder", l_helper
    if re.search(r"\bScalar[A-Za-z0-9_]+\s*\(", a_body_text):
        return "scalar_forwarder", None
    l_backend_helper = detect_backend_composed_helper(a_target, a_body_text, a_backend_prefix)
    if l_backend_helper is not None:
        return "backend_local_composition", l_backend_helper
    return "pascal_owned", None


def detect_wrapper_kind(
    a_target: str,
    a_info: SymbolFacts,
    a_facts: dict[str, SymbolFacts],
    a_backend_prefix: str,
) -> tuple[str, str | None]:
    l_seen_kinds: set[str] = set()
    l_helper: str | None = None

    for l_body_text in a_info.bodies:
        l_kind, l_body_helper = classify_wrapper_body(
            a_target,
            l_body_text,
            a_facts,
            a_backend_prefix,
        )
        l_seen_kinds.add(l_kind)
        if l_kind == "pascal_owned":
            return "pascal_owned", None
        if (l_helper is None) and (l_body_helper is not None):
            l_helper = l_body_helper

    if "backend_local_composition" in l_seen_kinds:
        return "backend_local_composition", l_helper
    if "asm_helper_forwarder" in l_seen_kinds:
        return "asm_helper_forwarder", l_helper
    if "scalar_forwarder" in l_seen_kinds:
        return "scalar_forwarder", None
    return "pascal_owned", None


def classify_target(
    a_target: str,
    a_facts: dict[str, SymbolFacts],
    a_backend_prefix: str,
) -> tuple[str, str | None, str | None]:
    if a_target.startswith("Scalar"):
        return "scalar_passthrough", "external_scalar", None

    l_info = a_facts.get(a_target)
    if l_info is not None and l_info.has_assembler:
        return "asm_exact", "exact_assembler", None

    if l_info is not None and l_info.has_definition:
        l_wrapper_kind, l_helper = detect_wrapper_kind(
            a_target,
            l_info,
            a_facts,
            a_backend_prefix,
        )
        if l_wrapper_kind == "backend_local_composition":
            return "backend_composed", l_wrapper_kind, l_helper
        if l_wrapper_kind == "asm_helper_forwarder":
            return "asm_suffix_only", l_wrapper_kind, l_helper
        return "wrapper_only", l_wrapper_kind, l_helper

    for l_helper in (f"{a_target}_ASM", f"{a_target}Asm"):
        l_helper_info = a_facts.get(l_helper)
        if l_helper_info is not None and l_helper_info.has_assembler:
            return "no_def", "missing_wrapper", l_helper

    return "no_def", "missing_definition", None


def build_reason_list(
    a_backend: str,
    a_assignment: Assignment,
    a_classification: str,
    a_wrapper_kind: str | None,
    a_strict: bool,
) -> list[str]:
    l_reasons: list[str] = []
    l_allowed_always_wrapper_slots = ALLOWED_ALWAYS_WRAPPER_SLOTS_BY_BACKEND.get(a_backend, set())
    l_allowed_asm_only_wrapper_slots = ALLOWED_ASM_ONLY_WRAPPER_SLOTS_BY_BACKEND.get(a_backend, set())
    l_allowed_no_asm_only_wrapper_slots = ALLOWED_NO_ASM_ONLY_WRAPPER_SLOTS_BY_BACKEND.get(a_backend, set())
    l_allowed_always_backend_composed_slots = ALLOWED_ALWAYS_BACKEND_COMPOSED_SLOTS_BY_BACKEND.get(a_backend, set())
    l_allowed_asm_only_backend_composed_slots = ALLOWED_ASM_ONLY_BACKEND_COMPOSED_SLOTS_BY_BACKEND.get(a_backend, set())
    l_allowed_no_asm_only_backend_composed_slots = ALLOWED_NO_ASM_ONLY_BACKEND_COMPOSED_SLOTS_BY_BACKEND.get(a_backend, set())
    l_allowed_always_asm_helper_slots = ALLOWED_ALWAYS_ASM_HELPER_SLOTS_BY_BACKEND.get(a_backend, set())

    if a_classification == "scalar_passthrough":
        l_reasons.append("explicit-scalar-binding")
    elif a_classification == "no_def":
        l_reasons.append("missing-definition")
    elif a_classification == "asm_exact":
        if a_assignment.context == "no-asm":
            l_reasons.append("asm-symbol-bound-inside-no-asm-block")
    elif a_classification == "asm_suffix_only":
        if a_assignment.context == "no-asm":
            l_reasons.append("asm-helper-wrapper-bound-inside-no-asm-block")
        elif (a_assignment.context != "asm-only") and (a_assignment.slot not in l_allowed_always_asm_helper_slots):
            l_reasons.append("asm-helper-wrapper-not-gated-to-asm-only-branch")
    elif a_classification == "backend_composed":
        if a_assignment.context == "asm-only":
            if a_assignment.slot not in l_allowed_asm_only_backend_composed_slots:
                l_reasons.append("backend-composed-bound-inside-asm-block")
        elif a_assignment.context == "no-asm":
            if a_assignment.slot not in l_allowed_no_asm_only_backend_composed_slots:
                l_reasons.append("backend-composed-bound-inside-no-asm-block")
        elif a_assignment.slot not in l_allowed_always_backend_composed_slots:
            if a_strict:
                l_reasons.append("backend-composed-backend-owned-slot")
    elif a_classification == "wrapper_only":
        if a_assignment.context == "asm-only":
            if a_assignment.slot not in l_allowed_asm_only_wrapper_slots:
                l_reasons.append("wrapper-only-bound-inside-asm-block")
        elif a_assignment.context == "no-asm":
            if a_assignment.slot not in l_allowed_no_asm_only_wrapper_slots:
                l_reasons.append("wrapper-only-bound-inside-no-asm-block")
        elif a_assignment.slot not in l_allowed_always_wrapper_slots:
            if a_strict:
                l_reasons.append("wrapper-only-backend-owned-slot")

    return l_reasons


def contexts_overlap(a_left: str, a_right: str) -> bool:
    if a_left == "always" or a_right == "always":
        return True
    return a_left == a_right


def render_summary_line(a_result: dict[str, Any]) -> str:
    return (
        "NONX86_REGISTER_TRUTHFULNESS_SUMMARY "
        f"backend={a_result['backend']} "
        f"assignments={a_result['assignment_count']} "
        f"asm_exact={a_result['asm_exact_count']} "
        f"asm_suffix_only={a_result['asm_suffix_only_count']} "
        f"backend_composed={a_result['backend_composed_count']} "
        f"wrapper_only={a_result['wrapper_only_count']} "
        f"scalar_passthrough={a_result['scalar_passthrough_count']} "
        f"no_def={a_result['no_def_count']} "
        f"miswired={a_result['miswired_count']} "
        f"unused_allowlist={a_result['unused_allowlist_count']} "
        f"strict={1 if a_result['strict'] else 0}"
    )


def print_human_result(a_result: dict[str, Any]) -> None:
    print(f"[REG-TRUTH] backend={a_result['backend']}")
    print(f"  - register file:       {a_result['register_file']}")
    print(f"  - source files:        {a_result['source_file_count']}")
    print(f"  - assignments:         {a_result['assignment_count']}")
    print(f"  - asm exact:           {a_result['asm_exact_count']}")
    print(f"  - asm suffix only:     {a_result['asm_suffix_only_count']}")
    print(f"  - backend composed:    {a_result['backend_composed_count']}")
    print(f"  - wrapper only:        {a_result['wrapper_only_count']}")
    print(f"  - scalar passthrough:  {a_result['scalar_passthrough_count']}")
    print(f"  - no definition:       {a_result['no_def_count']}")
    print(f"  - miswired:            {a_result['miswired_count']}")
    print(f"  - always composed ok:  {a_result['allowed_always_backend_composed_slot_count']}")
    print(f"  - asm-only composed ok:{a_result['allowed_asm_only_backend_composed_slot_count']}")
    print(f"  - no-asm composed ok:  {a_result['allowed_no_asm_only_backend_composed_slot_count']}")
    print(f"  - always wrapper ok:   {a_result['allowed_always_wrapper_slot_count']}")
    print(f"  - asm-only wrapper ok: {a_result['allowed_asm_only_wrapper_slot_count']}")
    print(f"  - no-asm wrapper ok:   {a_result['allowed_no_asm_only_wrapper_slot_count']}")
    print(f"  - unused allowlist:    {a_result['unused_allowlist_count']}")
    print(f"  - conflicting assign:  {a_result['conflicting_assignment_count']}")

    if a_result["unused_allowlist_slots"]:
        print("[REG-TRUTH] Unused allowlist slots:")
        for l_slot in a_result["unused_allowlist_slots"]:
            print(f"  - {l_slot}")

    if a_result["miswired_slots"]:
        print("[REG-TRUTH] Miswired slots:")
        for l_item in a_result["miswired_slots"]:
            l_helper = f", helper={l_item['helper']}" if l_item["helper"] else ""
            l_reason = ",".join(l_item["reasons"])
            l_conflicts = ""
            if l_item["conflicts"]:
                l_conflicts = f", conflicts={'; '.join(l_item['conflicts'])}"
            print(
                f"  - {l_item['slot']} -> {l_item['target']} "
                f"(line={l_item['line']}, context={l_item['context']}, class={l_item['classification']}{l_helper}, reason={l_reason}{l_conflicts})"
            )

    if a_result["ok"]:
        print("[REG-TRUTH] OK")


def build_report(a_config: CheckerConfig, a_strict: bool) -> dict[str, Any]:
    l_facts_asm = collect_symbol_facts(a_config.source_files, a_config.asm_symbol, True)
    l_facts_no_asm = collect_symbol_facts(a_config.source_files, a_config.asm_symbol, False)
    l_facts_combined = merge_symbol_facts(l_facts_asm, l_facts_no_asm)
    l_assignments = parse_assignments(a_config.register_file, a_config.asm_symbol)

    l_counts = {
        "asm_exact_count": 0,
        "asm_suffix_only_count": 0,
        "backend_composed_count": 0,
        "wrapper_only_count": 0,
        "scalar_passthrough_count": 0,
        "no_def_count": 0,
        "scalar_forwarder_count": 0,
        "pascal_owned_count": 0,
    }
    l_assignment_records: list[dict[str, Any]] = []

    for l_assignment in l_assignments:
        if l_assignment.context == "no-asm":
            l_facts = l_facts_no_asm
        elif l_assignment.context == "always":
            l_facts = l_facts_combined
        else:
            l_facts = l_facts_asm
        l_classification, l_wrapper_kind, l_helper = classify_target(
            l_assignment.target,
            l_facts,
            a_config.symbol_prefix,
        )
        l_key = f"{l_classification}_count"
        if l_key in l_counts:
            l_counts[l_key] += 1
        if l_wrapper_kind == "scalar_forwarder":
            l_counts["scalar_forwarder_count"] += 1
        elif l_wrapper_kind == "pascal_owned":
            l_counts["pascal_owned_count"] += 1

        l_reasons = build_reason_list(a_config.backend, l_assignment, l_classification, l_wrapper_kind, a_strict)
        l_assignment_records.append(
            {
                "slot": l_assignment.slot,
                "target": l_assignment.target,
                "line": l_assignment.line,
                "context": l_assignment.context,
                "classification": l_classification,
                "wrapper_kind": l_wrapper_kind,
                "helper": l_helper,
                "reasons": list(l_reasons),
                "conflicts": [],
            }
        )

    l_records_by_slot: dict[str, list[dict[str, Any]]] = {}
    for l_record in l_assignment_records:
        l_records_by_slot.setdefault(l_record["slot"], []).append(l_record)

    for l_slot_records in l_records_by_slot.values():
        for l_index, l_record in enumerate(l_slot_records):
            for l_other in l_slot_records[l_index + 1:]:
                if l_record["target"] == l_other["target"]:
                    continue
                if not contexts_overlap(l_record["context"], l_other["context"]):
                    continue

                l_record["conflicts"].append(
                    f"line={l_other['line']} target={l_other['target']} context={l_other['context']}"
                )
                l_other["conflicts"].append(
                    f"line={l_record['line']} target={l_record['target']} context={l_record['context']}"
                )

                if "overlapping-slot-rebinding" not in l_record["reasons"]:
                    l_record["reasons"].append("overlapping-slot-rebinding")
                if "overlapping-slot-rebinding" not in l_other["reasons"]:
                    l_other["reasons"].append("overlapping-slot-rebinding")

    l_miswired = [
        l_record for l_record in l_assignment_records
        if l_record["reasons"] or l_record["conflicts"]
    ]
    l_conflicting_assignment_count = sum(1 for l_record in l_assignment_records if l_record["conflicts"])
    l_allowed_always_wrapper_slots = ALLOWED_ALWAYS_WRAPPER_SLOTS_BY_BACKEND.get(a_config.backend, set())
    l_allowed_asm_only_wrapper_slots = ALLOWED_ASM_ONLY_WRAPPER_SLOTS_BY_BACKEND.get(a_config.backend, set())
    l_allowed_no_asm_only_wrapper_slots = ALLOWED_NO_ASM_ONLY_WRAPPER_SLOTS_BY_BACKEND.get(a_config.backend, set())
    l_allowed_always_backend_composed_slots = ALLOWED_ALWAYS_BACKEND_COMPOSED_SLOTS_BY_BACKEND.get(a_config.backend, set())
    l_allowed_asm_only_backend_composed_slots = ALLOWED_ASM_ONLY_BACKEND_COMPOSED_SLOTS_BY_BACKEND.get(a_config.backend, set())
    l_allowed_no_asm_only_backend_composed_slots = ALLOWED_NO_ASM_ONLY_BACKEND_COMPOSED_SLOTS_BY_BACKEND.get(a_config.backend, set())
    l_current_backend_composed_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if l_record["classification"] == "backend_composed"
        }
    )
    l_current_always_backend_composed_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if (l_record["classification"] == "backend_composed") and (l_record["context"] == "always")
        }
    )
    l_current_asm_only_backend_composed_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if (l_record["classification"] == "backend_composed") and (l_record["context"] == "asm-only")
        }
    )
    l_current_no_asm_backend_composed_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if (l_record["classification"] == "backend_composed") and (l_record["context"] == "no-asm")
        }
    )
    l_current_wrapper_only_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if l_record["classification"] == "wrapper_only"
        }
    )
    l_current_always_wrapper_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if (l_record["classification"] == "wrapper_only") and (l_record["context"] == "always")
        }
    )
    l_current_asm_only_wrapper_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if (l_record["classification"] == "wrapper_only") and (l_record["context"] == "asm-only")
        }
    )
    l_current_no_asm_wrapper_slots = sorted(
        {
            l_record["slot"]
            for l_record in l_assignment_records
            if (l_record["classification"] == "wrapper_only") and (l_record["context"] == "no-asm")
        }
    )
    l_unused_allowlist_slots = sorted(
        l_allowed_always_wrapper_slots.difference(l_current_always_wrapper_slots).union(
            l_allowed_asm_only_wrapper_slots.difference(l_current_asm_only_wrapper_slots),
            l_allowed_no_asm_only_wrapper_slots.difference(l_current_no_asm_wrapper_slots),
            l_allowed_always_backend_composed_slots.difference(l_current_always_backend_composed_slots),
            l_allowed_asm_only_backend_composed_slots.difference(l_current_asm_only_backend_composed_slots),
            l_allowed_no_asm_only_backend_composed_slots.difference(l_current_no_asm_backend_composed_slots),
        )
    )

    l_result: dict[str, Any] = {
        "backend": a_config.backend,
        "strict": a_strict,
        "register_file": str(a_config.register_file),
        "source_file_count": len(a_config.source_files),
        "source_files": [str(l_file) for l_file in a_config.source_files],
        "assignment_count": len(l_assignments),
        "asm_exact_count": l_counts["asm_exact_count"],
        "asm_suffix_only_count": l_counts["asm_suffix_only_count"],
        "backend_composed_count": l_counts["backend_composed_count"],
        "wrapper_only_count": l_counts["wrapper_only_count"],
        "scalar_passthrough_count": l_counts["scalar_passthrough_count"],
        "no_def_count": l_counts["no_def_count"],
        "scalar_forwarder_count": l_counts["scalar_forwarder_count"],
        "pascal_owned_count": l_counts["pascal_owned_count"],
        "miswired_count": len(l_miswired),
        "allowed_always_backend_composed_slot_count": len(l_allowed_always_backend_composed_slots),
        "allowed_asm_only_backend_composed_slot_count": len(l_allowed_asm_only_backend_composed_slots),
        "allowed_no_asm_only_backend_composed_slot_count": len(l_allowed_no_asm_only_backend_composed_slots),
        "allowed_always_wrapper_slot_count": len(l_allowed_always_wrapper_slots),
        "allowed_asm_only_wrapper_slot_count": len(l_allowed_asm_only_wrapper_slots),
        "allowed_no_asm_only_wrapper_slot_count": len(l_allowed_no_asm_only_wrapper_slots),
        "current_backend_composed_slot_count": len(l_current_backend_composed_slots),
        "current_backend_composed_slots": l_current_backend_composed_slots,
        "current_always_backend_composed_slot_count": len(l_current_always_backend_composed_slots),
        "current_always_backend_composed_slots": l_current_always_backend_composed_slots,
        "current_asm_only_backend_composed_slot_count": len(l_current_asm_only_backend_composed_slots),
        "current_asm_only_backend_composed_slots": l_current_asm_only_backend_composed_slots,
        "current_no_asm_backend_composed_slot_count": len(l_current_no_asm_backend_composed_slots),
        "current_no_asm_backend_composed_slots": l_current_no_asm_backend_composed_slots,
        "current_wrapper_only_slot_count": len(l_current_wrapper_only_slots),
        "current_wrapper_only_slots": l_current_wrapper_only_slots,
        "current_always_wrapper_slot_count": len(l_current_always_wrapper_slots),
        "current_always_wrapper_slots": l_current_always_wrapper_slots,
        "current_asm_only_wrapper_slot_count": len(l_current_asm_only_wrapper_slots),
        "current_asm_only_wrapper_slots": l_current_asm_only_wrapper_slots,
        "current_no_asm_wrapper_slot_count": len(l_current_no_asm_wrapper_slots),
        "current_no_asm_wrapper_slots": l_current_no_asm_wrapper_slots,
        "unused_allowlist_count": len(l_unused_allowlist_slots),
        "unused_allowlist_slots": l_unused_allowlist_slots,
        "conflicting_assignment_count": l_conflicting_assignment_count,
        "miswired_slots": l_miswired,
    }
    l_result["ok"] = (l_result["miswired_count"] == 0) and (l_result["unused_allowlist_count"] == 0)
    l_result["exit_code"] = 0 if l_result["ok"] else 1
    return l_result


def main() -> int:
    l_args = parse_args()
    l_root = repo_root()

    try:
        l_config = build_config(l_root, l_args)
        validate_inputs(l_config)
        l_result = build_report(l_config, bool(l_args.strict))

        if l_args.json:
            print(json.dumps(l_result, ensure_ascii=False, sort_keys=True))
        else:
            print_human_result(l_result)

        if l_args.summary_line:
            print(render_summary_line(l_result))

        return int(l_result["exit_code"])
    except RuntimeError as l_exc:
        l_error = {
            "ok": False,
            "error": "runtime-error",
            "message": str(l_exc),
            "exit_code": 2,
        }
        if l_args.json:
            print(json.dumps(l_error, ensure_ascii=False, sort_keys=True))
        else:
            print(f"[REG-TRUTH] ERROR: {l_exc}")
        return 2


if __name__ == "__main__":
    sys.exit(main())

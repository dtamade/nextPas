#!/usr/bin/env python3
"""Smoke-check the SIMD backend/public-contract roadmap.

This is a source contract, not a feature-completeness proof. It keeps the
public documentation and backend disposition comments honest while the SIMD
roadmap evolves across x86 and non-x86 targets.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
F16_HALF_MARKERS = [
    "tf16",
    "thalf",
    "f16c",
    "avx512bf16",
    "avx-512 fp16",
    "neon fp16",
    "f32 <-> f16",
    "f32 <-> bf16",
    "half precision",
    "f16/half",
]
F16_NEGATION_MARKERS = [
    "not",
    "没有",
    "未",
    "不能",
    "不等于",
    "不代表",
    "而不是",
    "不是",
    "future abi boundary",
    "still",
    "before",
    "之前",
]
F16_IMPLICIT_ARITHMETIC_NEGATION_MARKERS = ["not", "rather than", "而不是", "不是"]
TRANSPOSE_NEGATION_MARKERS = [
    "not",
    "without",
    "before",
    "future",
    "没有",
    "未",
    "不能",
    "不要",
    "不等于",
    "不是",
    "而不是",
    "之前",
]


def read_text(a_rel: str) -> str:
    return (REPO_ROOT / a_rel).read_text(encoding="utf-8", errors="ignore")


def contains_all(a_text: str, a_tokens: list[str]) -> list[str]:
    l_lower = a_text.lower()
    return [l_token for l_token in a_tokens if l_token.lower() not in l_lower]


def require_tokens(a_errors: list[str], a_rel: str, a_tokens: list[str]) -> None:
    l_missing = contains_all(read_text(a_rel), a_tokens)
    if l_missing:
        a_errors.append(f"{a_rel}: missing tokens: {', '.join(l_missing)}")


def require_pattern(
    a_errors: list[str], a_rel: str, a_pattern: str, a_message: str, *, a_flags: int = 0
) -> None:
    if re.search(a_pattern, read_text(a_rel), a_flags) is None:
        a_errors.append(f"{a_rel}: {a_message}")


def require_goal_tree_item_completed(
    a_errors: list[str], a_item_label: str, a_completion_basis: str
) -> None:
    require_pattern(
        a_errors,
        "docs/simd/GOAL_TREE.md",
        rf"(?m)^\s*-\s*\[x\]\s+{re.escape(a_item_label)}:",
        f"{a_item_label} roadmap item must be marked complete once {a_completion_basis}",
    )


def iter_paragraphs(a_text: str) -> list[tuple[int, str]]:
    l_paragraphs: list[tuple[int, str]] = []
    l_lines = a_text.splitlines()
    l_start = 0
    l_buffer: list[str] = []

    for l_index, l_line in enumerate(l_lines, start=1):
        if l_line.strip():
            if not l_buffer:
                l_start = l_index
            l_buffer.append(l_line)
            continue

        if l_buffer:
            l_paragraphs.append((l_start, "\n".join(l_buffer)))
            l_buffer = []

    if l_buffer:
        l_paragraphs.append((l_start, "\n".join(l_buffer)))

    return l_paragraphs


def check_f16_doc_family_readiness(
    a_errors: list[str], a_targets: list[str], a_label: str
) -> None:
    for l_rel in a_targets:
        for l_lineno, l_paragraph in iter_paragraphs(read_text(l_rel)):
            l_lower = l_paragraph.lower()

            if "implicit arithmetic" in l_lower and not any(
                l_marker in l_lower for l_marker in F16_IMPLICIT_ARITHMETIC_NEGATION_MARKERS
            ):
                a_errors.append(
                    f"{l_rel}:{l_lineno}: F16 future {a_label} docs must reject implicit arithmetic, "
                    "not merely mention it"
                )

            if not any(l_marker in l_lower for l_marker in F16_HALF_MARKERS):
                continue

            if (
                "stable abi" in l_lower
                or "稳定 abi" in l_lower
                or "abi ready" in l_lower
                or "api/abi ready" in l_lower
            ) and not any(l_marker in l_lower for l_marker in F16_NEGATION_MARKERS):
                a_errors.append(
                    f"{l_rel}:{l_lineno}: F16/half {a_label} docs must not imply stable ABI/API readiness"
                )


def check_transpose_cross_truth_docs(a_errors: list[str]) -> None:
    l_targets = {
        "docs/simd/README.md": [
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
            "VecF32x4Transpose",
            "LaneTranspose",
            "focused tests",
        ],
        "docs/simd/api.md": [
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
            "VecF32x4Transpose",
            "LaneTranspose",
            "focused tests",
        ],
        "docs/simd/publicabi.md": [
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
            "VecF32x4Transpose",
            "LaneTranspose",
            "focused tests",
        ],
        "docs/simd/publicabi.stability.md": [
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
            "VecF32x4Transpose",
            "LaneTranspose",
            "focused tests",
        ],
        "docs/simd/architecture-guide.md": [
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
            "VecF32x4Transpose",
            "LaneTranspose",
            "focused tests",
        ],
    }
    l_unified_markers = [
        "unified transpose",
        "统一 transpose",
        "统一 transpose surface",
        "统一 transpose abi",
        "transpose wrapper surface",
        "transpose facade",
        "`transpose` facade",
    ]

    for l_rel, l_tokens in l_targets.items():
        l_text = read_text(l_rel)
        l_found_transpose_paragraph = False
        l_transpose_lines = [
            (l_lineno, l_line)
            for l_lineno, l_line in enumerate(l_text.splitlines(), start=1)
            if "simd lane transpose" in l_line.lower()
        ]
        if not l_transpose_lines:
            a_errors.append(
                f"{l_rel}: transpose cross-truth docs must retain a dedicated SIMD lane transpose line"
            )
        else:
            for l_lineno, l_line in l_transpose_lines:
                l_missing = contains_all(l_line, l_tokens)
                if l_missing:
                    a_errors.append(
                        f"{l_rel}:{l_lineno}: transpose cross-truth line must keep owner-specific naming/test boundary; "
                        f"missing tokens: {', '.join(l_missing)}"
                    )

        for l_lineno, l_paragraph in iter_paragraphs(l_text):
            l_lower = l_paragraph.lower()
            if "simd lane transpose" not in l_lower:
                continue

            l_found_transpose_paragraph = True
            l_missing = contains_all(l_paragraph, l_tokens)
            if l_missing:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: transpose cross-truth paragraph must keep owner-specific naming/test boundary; "
                    f"missing tokens: {', '.join(l_missing)}"
                )

            if any(l_marker in l_lower for l_marker in l_unified_markers) and not any(
                l_marker in l_lower for l_marker in TRANSPOSE_NEGATION_MARKERS
            ):
                a_errors.append(
                    f"{l_rel}:{l_lineno}: transpose docs must reject a vague unified/stable Transpose surface"
                )
        if not l_found_transpose_paragraph:
            a_errors.append(
                f"{l_rel}: transpose cross-truth docs must retain a dedicated SIMD lane transpose paragraph"
            )


def check_no_stable_disposition(a_errors: list[str], a_rel: str) -> None:
    l_text = read_text(a_rel)
    if re.search(r"(?im)^\s*//\s*Disposition:\s*STABLE\b", l_text):
        a_errors.append(f"{a_rel}: isolated experimental/stub intrinsics must not claim STABLE disposition")


def check_forbidden_gather_absence_claims(a_errors: list[str]) -> None:
    l_files = [
        "docs/simd/GOAL_TREE.md",
        "docs/simd/architecture-guide.md",
        "docs/simd/maintenance.md",
    ]
    l_patterns = [
        r"gather/scatter\s+(?:is\s+)?(?:completely\s+)?missing",
        r"gather/scatter\s+完全缺失",
        r"gather\s*/\s*scatter\s+完全缺失",
        r"聚集\s*/\s*分散\s+完全缺失",
    ]
    for l_rel in l_files:
        l_text = read_text(l_rel)
        for l_pattern in l_patterns:
            if re.search(l_pattern, l_text, re.IGNORECASE):
                a_errors.append(f"{l_rel}: gather/scatter must be documented as partial coverage, not absent")


def check_public_abi_has_no_future_surface(a_errors: list[str]) -> None:
    l_files = [
        "src/nextpas.core.simd.public_abi.intf.inc",
        "src/nextpas.core.simd.public_abi.impl.inc",
    ]
    l_patterns = [
        r"\b(?:TF16|THalf|TVecF16|TVecBF16)\b",
        r"\bF16\b",
        r"\bBF16\b",
        r"\bGather\b",
        r"\bScatter\b",
        r"\bTranspose\b",
        r"\bLaneTranspose\b",
    ]
    for l_rel in l_files:
        l_text = read_text(l_rel)
        for l_pattern in l_patterns:
            if re.search(l_pattern, l_text):
                a_errors.append(
                    f"{l_rel}: public ABI must not expose gather/F16/transpose before focused API tests"
                )
                break


def check_no_stale_interface_completeness_snapshots(a_errors: list[str]) -> None:
    l_files = [
        "docs/simd/GOAL_TREE.md",
        "docs/simd/README.md",
        "docs/simd/closeout.md",
        "tests/nextpas.core.simd/docs/interface_implementation_completeness.md",
        "tests/nextpas.core.simd/docs/simd_completeness_matrix.md",
        "tests/nextpas.core.simd/docs/simd_release_candidate_checklist.md",
    ]
    l_patterns = [
        r"\bdispatch(?:_slots_total)?\s*=\s*558\b",
        r"\bdispatch slots total[：:]\s*`?558`?",
        r"\bdispatch_slots_total:\s*`?558`?",
        r"\b(?:scalar|sse2|avx2|avx512|neon|riscvv)\s*[:=]\s*`?\d+\s*/\s*558`?",
        r"\b558\s*/\s*558\b",
        r"\b558/558\b",
    ]

    for l_rel in l_files:
        l_text = read_text(l_rel)
        for l_pattern in l_patterns:
            l_match = re.search(l_pattern, l_text, re.IGNORECASE)
            if l_match:
                a_errors.append(
                    f"{l_rel}: stale interface completeness snapshot ({l_match.group(0)!r}); "
                    "refresh from check_interface_implementation_completeness.py --strict"
                )
                break


def check_no_missing_legacy_simd_archive_refs(a_errors: list[str]) -> None:
    l_forbidden = "docs/legacy/simd"
    l_replacement = "docs/simd/map.md plus docs/simd/backend-truth.md"
    for l_path in sorted((REPO_ROOT / "docs/simd").glob("*.md")):
        l_rel = str(l_path.relative_to(REPO_ROOT))
        l_text = l_path.read_text(encoding="utf-8", errors="ignore")
        if l_forbidden in l_text:
            a_errors.append(
                f"{l_rel}: must not point to missing legacy SIMD archive; "
                f"use {l_replacement} for current truth sources"
            )


def check_backend_truth_neon_activation_boundary(a_errors: list[str]) -> None:
    l_rel = "docs/simd/backend-truth.md"
    l_text = read_text(l_rel)
    l_required_tokens = [
        "Entry unit",
        "Dispatch activation",
        "conditional on `SIMD_ARM_AVAILABLE`",
        "default scalar fallback + asm opt-in",
        "NEXTPAS_SIMD_ENABLE_NEON_ASM",
        "NEXTPAS_SIMD_NEON_ASM_COMPILER_READY",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: NEON backend truth table must separate entry-unit presence from "
            f"dispatch activation; missing tokens: {', '.join(l_missing)}"
        )

    for l_lineno, l_line in enumerate(l_text.splitlines(), start=1):
        if re.search(r"\|\s*NEON\s*\|", l_line) and re.search(r"\|\s*yes\s*\|", l_line, re.IGNORECASE):
            a_errors.append(
                f"{l_rel}:{l_lineno}: NEON row must not use bare `yes` for default entry; "
                "spell out conditional unit presence and scalar-fallback/asm-opt-in activation"
            )


def check_readme_has_no_default_neon_fastpath_claims(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_allowed_tokens = [
        "scalar fallback",
        "标量回退",
        "opt-in",
        "显式",
        "asm",
        "默认 public",
    ]

    for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
        l_lower = l_line.lower()

        if "**优化**" in l_line and "AArch64" in l_line and "NEON" in l_line:
            if any(l_token.lower() in l_lower for l_token in l_allowed_tokens):
                continue
            a_errors.append(
                f"{l_rel}:{l_lineno}: README optimization note overstates NEON as default AArch64 fast path; "
                "spell out scalar fallback + asm opt-in truth"
            )
            continue

        if "**当前支持**" in l_line and "NEON" in l_line:
            if "scalar fallback" in l_lower and "opt-in" in l_lower:
                continue
            a_errors.append(
                f"{l_rel}:{l_lineno}: README AArch64 support note must spell out default scalar fallback "
                "and NEON asm opt-in truth"
            )
            continue

        if "| LEVEL_" in l_line and "NEON" in l_line:
            if "scalar fallback" in l_lower or "opt-in" in l_lower:
                continue
            a_errors.append(
                f"{l_rel}:{l_lineno}: README performance-level row must not present NEON as an unqualified "
                "default AArch64 level"
            )
            continue

        if "NEON 为基线" in l_line:
            a_errors.append(
                f"{l_rel}:{l_lineno}: README ABI note must not describe NEON as the default public AArch64 baseline"
            )


def check_quickref_has_no_default_neon_backend_claims(a_errors: list[str]) -> None:
    l_rel = "docs/simd/quickref.md"
    l_patterns = [
        (
            re.compile(r"SSE2\s*/\s*NEON\s+基线", re.IGNORECASE),
            "128-bit quickref title must not describe NEON as an unqualified baseline",
        ),
        (
            re.compile(r"SSE2\s*/\s*NEON\)", re.IGNORECASE),
            "algorithm fallback ladder must not present NEON as an unqualified 128-bit default",
        ),
        (
            re.compile(r"SSE2/AVX2/NEON\s+汇编实现", re.IGNORECASE),
            "dispatch sketch must not imply NEON assembly is always selected",
        ),
        (
            re.compile(r"\|\s*Linux ARM64\s*\|\s*Scalar/NEON\s*\|", re.IGNORECASE),
            "platform support table must mark NEON as opt-in instead of default",
        ),
    ]

    for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
        for l_pattern, l_message in l_patterns:
            if l_pattern.search(l_line):
                a_errors.append(f"{l_rel}:{l_lineno}: {l_message}")
                break


def check_f16_future_api_entry_docs(a_errors: list[str]) -> None:
    check_f16_doc_family_readiness(
        a_errors,
        [
            "docs/simd/README.md",
            "docs/simd/api.md",
        ],
        "API entry",
    )


def check_f16_future_api_truth_docs(a_errors: list[str]) -> None:
    check_f16_doc_family_readiness(
        a_errors,
        [
            "docs/simd/cpuinfo.md",
            "docs/simd/publicabi.md",
            "docs/simd/publicabi.stability.md",
        ],
        "truth",
    )


def check_experimental_backend_truth_docs(a_errors: list[str]) -> None:
    l_quickref = "docs/simd/quickref.md"
    for l_lineno, l_line in enumerate(read_text(l_quickref).splitlines(), start=1):
        if re.search(r"\|\s*Linux RISC-V\s*\|", l_line, re.IGNORECASE):
            l_lower = l_line.lower()
            if "riscvv opt-in" in l_lower and "experimental" in l_lower:
                continue
            a_errors.append(
                f"{l_quickref}:{l_lineno}: Linux RISC-V platform row must mark RISCVV as opt-in "
                "and experimental, not an unqualified default backend"
            )

    l_cpuinfo = read_text("docs/simd/cpuinfo.md")
    l_required_tokens = [
        "CPU capability / supported_on_cpu",
        "不代表 registered / dispatchable / active",
        "不代表 stable backend",
        "LoongArch/LASX",
        "experimental/stub",
    ]
    l_missing = contains_all(l_cpuinfo, l_required_tokens)
    if l_missing:
        a_errors.append(
            "docs/simd/cpuinfo.md: generic feature mapping must separate CPU capability qualification "
            f"from runtime/public backend maturity; missing tokens: {', '.join(l_missing)}"
        )


def check_architecture_impl_neon_activation_boundary(a_errors: list[str]) -> None:
    l_rel = "docs/simd/architecture-impl.md"
    l_text = read_text(l_rel)
    l_required_tokens = [
        "示意代码",
        "default scalar fallback",
        "NEON asm opt-in",
        "experimental isolated",
        "raw leaf",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: NEON architecture example must spell out conceptual-only status and default "
            f"activation boundary; missing tokens: {', '.join(l_missing)}"
        )


def check_cpuinfo_compile_option_boundary(a_errors: list[str]) -> None:
    l_rel = "docs/simd/cpuinfo.md"
    l_text = read_text(l_rel)

    if "{$DEFINE SIMD_BACKEND_NEON}" in l_text:
        a_errors.append(
            f"{l_rel}: cpuinfo compile-options section must not present `SIMD_BACKEND_NEON` as a "
            "capability-layer define"
        )

    l_required_tokens = [
        "nextpas.core.simd.settings.inc",
        "SIMD_ARM_AVAILABLE",
        "SIMD_RISCV_AVAILABLE",
        "SIMD_LOONGARCH_AVAILABLE",
        "不等于 backend opt-in",
        "NEXTPAS_SIMD_ENABLE_NEON_ASM",
        "SIMD_EXPERIMENTAL_RISCVV",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: compile-options section must separate cpuinfo capability defines from backend "
            f"opt-in defines; missing tokens: {', '.join(l_missing)}"
        )


def check_cpuinfo_backend_management_wording(a_errors: list[str]) -> None:
    l_rel = "docs/simd/cpuinfo.md"
    l_text = read_text(l_rel)

    if "自动选择" in l_text and "最佳 SIMD 后端" in l_text:
        a_errors.append(
            f"{l_rel}: backend-management summary must not describe cpuinfo as auto-selecting the current "
            "best SIMD backend"
        )

    l_required_tokens = [
        "supported_on_cpu",
        "不代表当前 active backend",
        "不等于已注册或可派发",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: backend-management summary must state CPU/OS capability semantics instead of runtime "
            f"selection semantics; missing tokens: {', '.join(l_missing)}"
        )


def check_cpuinfo_backend_enum_activation_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/cpuinfo.md"
    l_seen_neon = False
    l_seen_riscvv = False

    for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
        if "sbNEON" in l_line and "//" in l_line:
            l_seen_neon = True
            l_lower = l_line.lower()
            if "supported_on_cpu" not in l_lower or "asm opt-in" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: backend enum comment must present sbNEON as CPU capability "
                    "truth plus separate asm opt-in activation, not a bare ARM NEON implementation"
                )

        if "sbRISCVV" in l_line and "//" in l_line:
            l_seen_riscvv = True
            l_lower = l_line.lower()
            if "opt-in" not in l_lower or "experimental" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: backend enum comment must mark sbRISCVV as opt-in "
                    "and experimental"
                )

    if not l_seen_neon:
        a_errors.append(f"{l_rel}: backend enum snippet is missing sbNEON")
    if not l_seen_riscvv:
        a_errors.append(f"{l_rel}: backend enum snippet is missing sbRISCVV")


def check_cpuinfo_f16_raw_feature_boundary(a_errors: list[str]) -> None:
    l_rel = "docs/simd/cpuinfo.md"
    l_text = read_text(l_rel)
    l_required_tokens = [
        "HasF16C",
        "raw CPU feature",
        "F16/half precision",
        "future ABI boundary",
        "不等于 F16 API/ABI ready",
        "TF16",
        "THalf",
        "AVX512BF16",
        "NEON FP16",
        "scalar fallback",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: F16/half raw CPU feature documentation must not imply API/ABI readiness; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_arrays_header_runtime_dispatch_truth(a_errors: list[str]) -> None:
    l_rel = "src/nextpas.core.simd.arrays.pas"
    l_text = read_text(l_rel)

    if "SIMD backend (Scalar/SSE2/AVX2/AVX-512/NEON)" in l_text:
        a_errors.append(
            f"{l_rel}: public header must not list NEON beside x86 backends without "
            "default scalar fallback / asm opt-in activation truth"
        )

    l_required_tokens = [
        "dispatch table",
        "x86_64",
        "AArch64 default scalar fallback",
        "NEON asm opt-in",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: public header must describe runtime dispatch and AArch64 NEON activation "
            f"truth; missing tokens: {', '.join(l_missing)}"
        )


def check_backend_metadata_description_truth(a_errors: list[str]) -> None:
    l_files = [
        "src/nextpas.core.simd.dispatch.pas",
        "src/nextpas.core.simd.public_abi.impl.inc",
        "src/nextpas.core.simd.neon.register.inc",
        "src/nextpas.core.simd.riscvv.register.inc",
    ]

    for l_rel in l_files:
        for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
            l_lower = l_line.lower()
            if "arm neon 128-bit simd" in l_lower:
                if "asm opt-in" not in l_lower or "scalar fallback" not in l_lower:
                    a_errors.append(
                        f"{l_rel}:{l_lineno}: NEON backend metadata must carry asm opt-in "
                        "and scalar fallback activation truth"
                    )
            if "risc-v vector extension (rvv)" in l_lower:
                if "experimental" not in l_lower or "opt-in" not in l_lower:
                    a_errors.append(
                        f"{l_rel}:{l_lineno}: RISCVV backend metadata must carry experimental "
                        "opt-in maturity truth"
                    )


def check_base_backend_enum_activation_truth(a_errors: list[str]) -> None:
    l_rel = "src/nextpas.core.simd.base.pas"
    l_seen_neon = False
    l_seen_riscvv = False

    for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
        if "sbNEON" in l_line:
            l_seen_neon = True
            l_lower = l_line.lower()
            if "scalar fallback" not in l_lower or "asm opt-in" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: base backend enum comment must retain sbNEON scalar "
                    "fallback + asm opt-in activation truth"
                )

        if "sbRISCVV" in l_line:
            l_seen_riscvv = True
            l_lower = l_line.lower()
            if "experimental" not in l_lower or "opt-in" not in l_lower or "stable public backend" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: base backend enum comment must mark sbRISCVV as "
                    "experimental opt-in and not a stable public backend"
                )

    if not l_seen_neon:
        a_errors.append(f"{l_rel}: backend enum snippet is missing sbNEON")
    if not l_seen_riscvv:
        a_errors.append(f"{l_rel}: backend enum snippet is missing sbRISCVV")


def check_ops_header_runtime_dispatch_truth(a_errors: list[str]) -> None:
    l_rel = "src/nextpas.core.simd.ops.pas"
    l_text = read_text(l_rel)

    if "通过 dispatch 系统自动选择最佳 SIMD 后端" in l_text:
        a_errors.append(
            f"{l_rel}: ops header must not reduce runtime binding to generic best-backend wording"
        )

    l_required_tokens = [
        "dispatch table",
        "x86_64",
        "AArch64 default scalar fallback",
        "NEON asm opt-in",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: ops header must describe runtime dispatch and AArch64 NEON activation truth; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_neon_header_activation_truth(a_errors: list[str]) -> None:
    l_rel = "src/nextpas.core.simd.neon.pas"
    l_text = read_text(l_rel)

    if "ARM NEON SIMD Backend Implementation" in l_text:
        a_errors.append(
            f"{l_rel}: header title must not present NEON as an unqualified backend implementation"
        )

    l_required_tokens = [
        "NEON backend adapter",
        "default public behavior",
        "default scalar fallback",
        "NEON asm opt-in",
        "active dispatch path",
        "CPU support alone does not change",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: header must retain default scalar fallback and asm opt-in activation truth; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_neon_register_init_boundary_truth(a_errors: list[str]) -> None:
    l_rel = "src/nextpas.core.simd.neon.register.inc"
    l_text = read_text(l_rel)

    l_required_tokens = [
        "Test-only opt-in path",
        "non-native hosts",
        "scalar-fallback",
        "DispatchAPI/PublicAbi suites",
        "default public behavior remains",
        "scalar fallback",
        "Only register NEON backend when ASM is available",
        "explicitly opted in",
        "default public path stays scalar",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: initialization contract must distinguish test-only non-native "
            f"scalar-fallback coverage from asm-gated production registration truth; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_riscvv_header_backend_truth(a_errors: list[str]) -> None:
    l_rel = "src/nextpas.core.simd.riscvv.pas"
    l_text = read_text(l_rel)

    if "RISC-V V (Vector Extension) SIMD Backend" in l_text:
        a_errors.append(
            f"{l_rel}: header must not present RISCVV as an unqualified SIMD backend"
        )

    if "This unit implements SIMD operations using RISC-V V extension." in l_text:
        a_errors.append(
            f"{l_rel}: header must not imply the unit is a default RISC-V V implementation "
            "without experimental opt-in maturity truth"
        )

    l_required_tokens = [
        "experimental opt-in backend adapter",
        "source-contract surface",
        "not a default stable public backend",
        "scalar fallback",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: header must describe RISCVV as experimental opt-in adapter/source-contract "
            f"truth, not stable default backend; missing tokens: {', '.join(l_missing)}"
        )


def check_maintenance_nonx86_debt_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/maintenance.md"
    l_seen = False

    for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
        if not re.search(r"\|\s*LoongArch/SVE/SVE2\s*\|", l_line):
            continue

        l_seen = True
        l_lower = l_line.lower()
        if (
            "experimental/stub" not in l_lower
            or "opt-in" not in l_lower
            or "not stable backend" not in l_lower
            or "runtime proof" not in l_lower
        ):
            a_errors.append(
                f"{l_rel}:{l_lineno}: LoongArch/SVE/SVE2 debt row must spell out "
                "experimental/stub opt-in status, not-stable-backend maturity, and "
                "missing runtime proof instead of a vague incomplete-feature label"
            )

    if not l_seen:
        a_errors.append(f"{l_rel}: Known Technical Debt table is missing LoongArch/SVE/SVE2 row")


def check_batch_api_runtime_routing_truth(a_errors: list[str]) -> None:
    l_quickref_rel = "docs/simd/quickref.md"
    l_quickref_text = read_text(l_quickref_rel)
    if "默认自动模式会优先绑定当前可派发的实现" in l_quickref_text:
        a_errors.append(
            f"{l_quickref_rel}: algorithms note must use GetBestDispatchableBackend for the automatic "
            "best-backend choice, not a vague dispatchable-implementation wording"
        )
    l_quickref_required = [
        "dispatch table",
        "当前 active backend",
        "GetBestDispatchableBackend",
        "GetDispatchableBackendList",
        "TrySetCurrentBackend",
        "ResetCurrentBackendSelection",
        "不是简单按“最宽 SIMD”固定选择",
    ]
    l_missing = contains_all(l_quickref_text, l_quickref_required)
    if l_missing:
        a_errors.append(
            f"{l_quickref_rel}: batch/algorithms note must describe dispatch-table routing and runtime "
            f"control-plane semantics; missing tokens: {', '.join(l_missing)}"
        )

    l_readme_rel = "docs/simd/README.md"
    l_readme_text = read_text(l_readme_rel)
    if "运行时自动选择最优后端（AVX2 → SSE2 → Scalar）" in l_readme_text:
        a_errors.append(
            f"{l_readme_rel}: Batch Array API summary must not reduce runtime routing to a fixed "
            "AVX2 -> SSE2 -> Scalar ladder"
        )

    if "自动模式通常会优先绑定 `GetDispatchableBackendList` 中当前可派发的最佳实现" in l_readme_text:
        a_errors.append(
            f"{l_readme_rel}: Batch Array API summary must use GetBestDispatchableBackend for the "
            "automatic best-backend choice, not GetDispatchableBackendList"
        )

    l_readme_required = [
        "dispatch table",
        "GetCurrentBackend",
        "GetDispatchableBackendList",
        "GetBestDispatchableBackend",
        "TrySetCurrentBackend",
        "ResetCurrentBackendSelection",
        "非 x86 backend 仍有 opt-in / experimental 边界",
    ]
    l_missing = contains_all(l_readme_text, l_readme_required)
    if l_missing:
        a_errors.append(
            f"{l_readme_rel}: Batch Array API summary must spell out runtime routing/control-plane truth; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_readme_topline_runtime_dispatch_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    if "**运行时派发**：初始化时根据 CPU/OS 能力选择最优实现；支持环境/宏强制降级" in l_text:
        a_errors.append(
            f"{l_rel}: topline runtime-dispatch bullet must not reduce binding to a pure CPU/OS "
            "best-implementation selection claim"
        )

    l_required_tokens = [
        "dispatchable",
        "active backend",
        "runtime/control-plane",
        "TrySetCurrentBackend",
        "ResetCurrentBackendSelection",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: topline runtime-dispatch overview must retain runtime binding/control-plane anchors; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_readme_topline_api_compatibility_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    if "**API 兼容性**：不改变调用方 API 语义；任何平台/构建环境下均可运行；有 SIMD 则自动用更快实现" in l_text:
        a_errors.append(
            f"{l_rel}: topline API-compatibility bullet must not imply any SIMD-capable target "
            "automatically gets a faster stable-path implementation"
        )

    l_required_tokens = [
        "dispatchable",
        "active backend",
        "scalar fallback",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: topline API-compatibility overview must retain dispatchable/active/scalar-fallback "
            f"truth anchors; missing tokens: {', '.join(l_missing)}"
        )


def check_readme_topline_platform_support_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    if "**跨平台支持**：支持 x86_64 (SSE2/AVX2/AVX-512) 和 AArch64 (NEON) 架构" in l_text:
        a_errors.append(
            f"{l_rel}: topline platform-support bullet must not present AArch64 as an unqualified "
            "NEON public path"
        )

    l_old_x86_line = (
        "- **跨平台支持**：支持 x86_64 (SSE2/AVX2/AVX-512) 和 AArch64（default scalar fallback + "
        "NEON asm opt-in）架构"
    )
    if l_old_x86_line in l_text:
        a_errors.append(
            f"{l_rel}: topline platform-support bullet must not collapse x86 coverage to only SSE2/AVX2/AVX-512"
        )

    l_required_line = (
        "- **跨平台支持**：支持 x86_64 backend family（`SSE2 / SSE3 / SSSE3 / SSE4.1 / SSE4.2 / "
        "AVX2 / AVX-512`）与 AArch64（default scalar fallback + NEON asm opt-in）架构"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: topline platform-support bullet must retain current x86 backend-family coverage plus AArch64 scalar-fallback/opt-in truth"
        )

    l_required_tokens = [
        "AArch64",
        "scalar fallback",
        "NEON asm opt-in",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: topline platform-support overview must retain AArch64 scalar-fallback/opt-in "
            f"truth anchors; missing tokens: {', '.join(l_missing)}"
        )


def check_readme_topline_fallback_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    if "**平滑回退**：标量实现永远可用；汇编不可用/检测失败时自动回退" in l_text:
        a_errors.append(
            f"{l_rel}: topline fallback bullet must not reduce fallback truth to an automatic "
            "assembly-unavailable/detection-failed wording"
        )

    l_required_snippet = (
        "**平滑回退**：`scalar fallback` 永远可用；如果当前没有可绑定的 `dispatchable` SIMD backend，"
        "或 `runtime/control-plane` 没有把 `active backend` 绑定到汇编路径，执行仍保持标量语义"
    )
    if l_required_snippet not in l_text:
        a_errors.append(
            f"{l_rel}: topline fallback bullet must spell out dispatchable/active/runtime fallback truth"
        )


def check_readme_high_level_api_runtime_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_forbidden_lines = [
        "高层 API 让外部模块无需手动管理指针即可使用 SIMD 加速。",
        "// 运算符 (自动 SIMD 加速)",
        "// 链式操作 (自动融合: MulScalar+AddScalar → Linear 单 pass)",
    ]
    for l_line in l_forbidden_lines:
        if l_line in l_text:
            a_errors.append(
                f"{l_rel}: high-level API examples must not present typed arrays/pipeline as "
                f"automatic stable-path SIMD acceleration ({l_line})"
            )

    l_required_tokens = [
        "dispatchable",
        "active backend",
        "scalar fallback",
        "dispatch table",
        "runtime/control-plane",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: high-level API section must retain runtime routing/control-plane truth anchors; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_readme_high_level_api_performance_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)
    if "### 性能特征" not in l_text:
        a_errors.append(f"{l_rel}: high-level API performance section is missing")
        return

    l_section = l_text.split("### 性能特征", 1)[1].split("\n---", 1)[0]

    l_forbidden_lines = [
        "- **Contiguous fast path**: stride=1 时直接调用底层 SIMD batch slot (零开销)",
        "- **Pipeline fusion**: `MulScalar+AddScalar` 自动识别为 `ArrayLinearF32` (单 FMA 指令)",
        "- **对齐分配**: 所有 Create/Zeros 返回的数组自动对齐到最优边界",
        "- **Stride fallback**: 非连续内存自动回退到标量循环",
    ]
    for l_line in l_forbidden_lines:
        if l_line in l_section:
            a_errors.append(
                f"{l_rel}: high-level API performance note must not overstate routing/alignment truth "
                f"({l_line})"
            )

    l_required_tokens = [
        "dispatch table",
        "active backend",
        "ArrayLinearF32",
        "SimdAlloc",
        "AVX-512=64",
        "AVX2=32",
        "16",
        "stride fallback",
        "scalar loop",
    ]
    l_missing = contains_all(l_section, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: high-level API performance section must retain routing/fusion/alignment anchors; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_quickref_algorithm_internal_mechanism_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/quickref.md"
    l_text = read_text(l_rel)

    if "算法层通过 `TSimdLaneInfo` 探测当前最佳宽度，然后按 256-bit → 128-bit → scalar 的阶梯下降处理数据" in l_text:
        a_errors.append(
            f"{l_rel}: internal-mechanism note must not present `TSimdLaneInfo` + 256/128/scalar ladder "
            "as the canonical routing truth for algorithms entrypoints"
        )

    l_required_tokens = [
        "SimdGetBestLaneInfo",
        "宽度提示",
        "GetDirectDispatchTable",
        "published dispatch snapshot",
        "不是新的 control-plane",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: internal-mechanism note must distinguish lane-width hint from direct dataplane "
            f"routing truth; missing tokens: {', '.join(l_missing)}"
        )


def check_quickref_runtime_auto_selection_wording(a_errors: list[str]) -> None:
    l_rel = "docs/simd/quickref.md"
    l_text = read_text(l_rel)

    if "nextpas.core.simd;           // 向量操作 + 自动后端选择" in l_text:
        a_errors.append(
            f"{l_rel}: module quick-start note must not describe nextpas.core.simd as plain "
            "auto-backend-selection entrypoint"
        )

    if "无需额外编译标志。后端在运行时自动检测并选择最优实现。" in l_text:
        a_errors.append(
            f"{l_rel}: compile/usage note must not reduce runtime binding to automatic "
            "best-implementation selection wording"
        )


def check_quickref_backend_enum_activation_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/quickref.md"
    l_seen_neon = False
    l_seen_riscvv = False

    for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
        if "sbNEON" in l_line:
            l_seen_neon = True
            l_lower = l_line.lower()
            if "scalar fallback" not in l_lower or "asm opt-in" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: backend enum comment must not present sbNEON as a bare "
                    "ARM64 128-bit backend; retain scalar fallback + asm opt-in truth"
                )

        if "sbRISCVV" in l_line:
            l_seen_riscvv = True
            l_lower = l_line.lower()
            if "opt-in" not in l_lower or "experimental" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: backend enum comment must mark sbRISCVV as opt-in "
                    "and experimental"
                )

    if not l_seen_neon:
        a_errors.append(f"{l_rel}: backend enum snippet is missing sbNEON")
    if not l_seen_riscvv:
        a_errors.append(f"{l_rel}: backend enum snippet is missing sbRISCVV")


def check_quickref_dispatch_mechanism_execution_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/quickref.md"
    l_text = read_text(l_rel)
    if "## 派发机制" not in l_text:
        a_errors.append(f"{l_rel}: dispatch mechanism section is missing")
        return

    l_section = l_text.split("## 派发机制", 1)[1].split("\n## ", 1)[0]
    if "→ 执行: SSE2/AVX2 汇编实现，或显式 opt-in 的 NEON 汇编实现" in l_section:
        a_errors.append(
            f"{l_rel}: dispatch mechanism must not reduce execution to a fixed SSE2/AVX2/NEON path"
        )

    l_required_tokens = [
        "当前 active backend",
        "published dispatch slot",
        "scalar fallback",
        "NEON asm opt-in",
        "experimental",
    ]
    l_missing = contains_all(l_section, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: dispatch mechanism section must retain active-backend/fallback/non-x86 "
            f"truth anchors; missing tokens: {', '.join(l_missing)}"
        )


def check_api_topline_runtime_dispatch_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/api.md"
    l_text = read_text(l_rel)

    if "`nextpas.core.simd` 是一个跨平台 SIMD 抽象层，支持多后端自动调度。" in l_text:
        a_errors.append(
            f"{l_rel}: topline overview must not reduce nextpas.core.simd to a plain "
            "multi-backend auto-dispatch claim"
        )

    l_required_tokens = [
        "runtime/control-plane",
        "dispatchable",
        "GetCurrentBackend",
        "GetCurrentRuntimeSnapshot",
        "TrySetCurrentBackend",
        "ResetCurrentBackendSelection",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: API overview must retain runtime/dispatch truth anchors; missing tokens: "
            f"{', '.join(l_missing)}"
        )


def check_api_supported_backend_table_activation_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/api.md"
    l_seen_neon = False
    l_seen_riscvv = False

    for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
        if re.search(r"\|\s*NEON\s*\|", l_line):
            l_seen_neon = True
            l_lower = l_line.lower()
            if "scalar fallback" not in l_lower or "asm opt-in" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: supported-backends table must not present NEON as an "
                    "unqualified ARM64 backend; spell out scalar fallback + asm opt-in activation truth"
                )

        if re.search(r"\|\s*RISC-V V\s*\|", l_line):
            l_seen_riscvv = True
            l_lower = l_line.lower()
            if "opt-in" not in l_lower or "experimental" not in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: supported-backends table must mark RISC-V V as opt-in "
                    "and experimental instead of an unqualified platform backend"
                )

    if not l_seen_neon:
        a_errors.append(f"{l_rel}: supported-backends table is missing the NEON row")
    if not l_seen_riscvv:
        a_errors.append(f"{l_rel}: supported-backends table is missing the RISC-V V row")


def check_pipeline_quickstart_dispatch_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/pipeline.quickstart.md"
    l_text = read_text(l_rel)

    if "3. **降到 dispatch**: Fused patterns 降到正式 SIMD dispatch slot，自动利用 SSE2/AVX2/AVX-512" in l_text:
        a_errors.append(
            f"{l_rel}: design-principles dispatch note must not reduce pipeline execution to an "
            "automatic x86 acceleration claim"
        )

    if "4. **后端无关**: 新后端注册后，Pipeline 自动获得加速" in l_text:
        a_errors.append(
            f"{l_rel}: backend-agnostic note must not imply new backends automatically become "
            "public acceleration paths after registration"
        )

    l_required_tokens = [
        "dispatchable",
        "active backend",
        "runtime/control-plane",
        "opt-in / experimental",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: quickstart design principles must retain runtime binding and non-x86 activation "
            f"truth anchors; missing tokens: {', '.join(l_missing)}"
        )


def check_pipeline_quickstart_intro_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/pipeline.quickstart.md"
    l_text = read_text(l_rel)

    if "它让你用链式 API 表达 SIMD 计算，自动进行 pattern fusion 优化，然后降到高性能 dispatch slot 执行。" in l_text:
        a_errors.append(
            f"{l_rel}: intro must not reduce pipeline execution to automatic high-performance "
            "dispatch-slot execution wording"
        )

    l_required_tokens = [
        "dispatchable",
        "active backend",
        "runtime/control-plane",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: intro must retain runtime binding/control-plane anchors; missing tokens: "
            f"{', '.join(l_missing)}"
        )


def check_pipeline_quickstart_example_comment_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/pipeline.quickstart.md"
    l_text = read_text(l_rel)

    if "// 基本用法: Linear + ReLU (自动 fusion 为单 pass fused kernel)" in l_text:
        a_errors.append(
            f"{l_rel}: basic example comment must not reduce fusion to an automatic fixed fused-kernel claim"
        )

    if "// 多输入: alpha*X + Y (自动 fusion 为 Axpy)" in l_text:
        a_errors.append(
            f"{l_rel}: multi-input example comment must not reduce fusion to an automatic fixed Axpy claim"
        )

    l_required_comments = [
        "// 基本用法: Linear + ReLU (optimizer 可折叠为 LinearReLU；执行仍受 runtime/control-plane 绑定的 active backend 约束)",
        "// 多输入: alpha*X + Y (optimizer 可折叠为 Axpy 形态；执行仍从当前 dispatchable 集合里绑定 active backend)",
    ]
    l_missing = contains_all(l_text, l_required_comments)
    if l_missing:
        a_errors.append(
            f"{l_rel}: example comments must retain optimizer-folding plus runtime-binding truth; "
            f"missing snippets: {', '.join(l_missing)}"
        )


def check_facade_unit_comment_runtime_truth(a_errors: list[str]) -> None:
    l_rel = "src/nextpas.core.simd.pas"
    l_text = read_text(l_rel)

    if "@item(Automatic backend selection (Scalar/SSE2/AVX2/AVX-512/NEON))" in l_text:
        a_errors.append(
            f"{l_rel}: facade header must not reduce backend selection to a flat automatic-backend list claim"
        )

    if "c := VecF32x4Add(a, b);  // SIMD accelerated" in l_text:
        a_errors.append(
            f"{l_rel}: quick-start sample must not imply unconditional SIMD acceleration"
        )

    l_required_tokens = [
        "dispatchable backend set",
        "active backend",
        "scalar fallback",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: facade header must retain runtime-binding truth anchors; missing tokens: "
            f"{', '.join(l_missing)}"
        )


def check_pipeline_quickstart_usage_comment_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/pipeline.quickstart.md"
    l_text = read_text(l_rel)

    if "// Pipeline 写法 (自动 fusion 为 1 pass):" in l_text:
        a_errors.append(
            f"{l_rel}: nn example comment must not reduce pipeline execution to an automatic fixed 1-pass claim"
        )

    if "// 生成 440Hz 正弦波 (MulScalar+MulScalar 自动合并)" in l_text:
        a_errors.append(
            f"{l_rel}: signal example comment must not reduce scalar-folding to an unconditional automatic merge claim"
        )

    l_required_comments = [
        "// Pipeline 写法 (optimizer 可折叠并减少 pass 数；实际执行仍从当前 dispatchable 集合里绑定 active backend):",
        "// 生成 440Hz 正弦波 (MulScalar+MulScalar 可在 optimizer 中合并；执行仍受当前 active backend 约束)",
    ]
    l_missing = contains_all(l_text, l_required_comments)
    if l_missing:
        a_errors.append(
            f"{l_rel}: usage comments must retain optimizer-folding plus runtime-binding truth; "
            f"missing snippets: {', '.join(l_missing)}"
        )


def check_batch_api_auto_mode_wording_truth(a_errors: list[str]) -> None:
    l_readme_rel = "docs/simd/README.md"
    l_readme_text = read_text(l_readme_rel)

    if "自动处理对齐、尾部元素和后端选择。" in l_readme_text:
        a_errors.append(
            f"{l_readme_rel}: batch summary must not package backend selection as an automatic helper detail"
        )

    if "自动模式通常会优先绑定 `GetBestDispatchableBackend` 返回的当前最佳可派发实现" in l_readme_text:
        a_errors.append(
            f"{l_readme_rel}: batch summary must not describe runtime binding as a vague automatic-mode preference"
        )

    l_quickref_rel = "docs/simd/quickref.md"
    l_quickref_text = read_text(l_quickref_rel)
    if "默认自动模式会优先绑定 `GetBestDispatchableBackend` 返回的当前最佳可派发实现；" in l_quickref_text:
        a_errors.append(
            f"{l_quickref_rel}: algorithms note must not describe runtime binding as a vague automatic-mode preference"
        )

    l_required_tokens = [
        "runtime/control-plane",
        "dispatchable",
        "active backend",
        "GetBestDispatchableBackend",
        "GetDispatchableBackendList",
        "TrySetCurrentBackend",
        "ResetCurrentBackendSelection",
    ]
    l_missing_readme = contains_all(l_readme_text, l_required_tokens)
    if l_missing_readme:
        a_errors.append(
            f"{l_readme_rel}: batch summary must retain runtime/control-plane anchors; missing tokens: "
            f"{', '.join(l_missing_readme)}"
        )

    l_missing_quickref = contains_all(l_quickref_text, l_required_tokens)
    if l_missing_quickref:
        a_errors.append(
            f"{l_quickref_rel}: algorithms note must retain runtime/control-plane anchors; missing tokens: "
            f"{', '.join(l_missing_quickref)}"
        )


def check_neon_benchmark_abi_cost_truth(a_errors: list[str]) -> None:
    l_rel = "tests/nextpas.core.simd/bench_neon_vs_scalar.lpr"
    l_text = read_text(l_rel)

    l_forbidden_lines = [
        "NEON backend provides **excellent** performance improvement over Scalar backend.",
        "NEON backend provides **good** performance improvement over Scalar backend.",
        "NEON backend provides **moderate** performance improvement over Scalar backend.",
        "NEON backend provides **minimal** performance improvement over Scalar backend.",
    ]
    for l_forbidden in l_forbidden_lines:
        if l_forbidden in l_text:
            a_errors.append(
                f"{l_rel}: benchmark report must not emit unconditional NEON-vs-scalar speedup verdicts without ABI-cost caveats"
            )
            break

    l_required_tokens = [
        "AArch64 ABI caveat",
        "GPR-to-vector",
        "vector-to-GPR",
        "fmov",
        "ins",
        "umov",
        "measured workload",
        "scalar fallback",
        "not a blanket claim",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: NEON benchmark report must retain AArch64 ABI bridge caveat; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_backend_benchmark_settings_include_contract(a_errors: list[str]) -> None:
    l_targets = [
        "tests/nextpas.core.simd/bench_avx512_vs_avx2.lpr",
        "tests/nextpas.core.simd/bench_neon_vs_scalar.lpr",
        "tests/nextpas.core.simd/bench_riscvv_vs_scalar.lpr",
    ]
    l_required_include = "{$i ../../src/nextpas.core.settings.inc}"

    for l_rel in l_targets:
        l_lines = read_text(l_rel).splitlines()
        l_include_lineno = 0

        for l_lineno, l_line in enumerate(l_lines, start=1):
            l_lower = l_line.lower()
            if l_required_include in l_lower:
                l_include_lineno = l_lineno

            if "{$mode" in l_lower or "{$h+}" in l_lower:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: benchmark entrypoint must not duplicate local mode/string directives "
                    "when nextpas.core.settings.inc is included"
                )

        if l_include_lineno == 0:
            a_errors.append(
                f"{l_rel}: benchmark entrypoint must include ../../src/nextpas.core.settings.inc as the compiler-settings owner"
            )


def check_backend_benchmark_summary_caveat_chain(a_errors: list[str]) -> None:
    l_rel = "tests/nextpas.core.simd/run_backend_benchmarks.sh"
    l_text = read_text(l_rel)
    l_required_tokens = [
        "NEON_vs_Scalar_Benchmark_Report.md",
        "Markdown report:",
        "AArch64 ABI caveat",
        "measured workload",
        "not a blanket claim",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: backend benchmark summary chain must retain the NEON markdown-report ABI caveat, "
            f"not just the run log link; missing tokens: {', '.join(l_missing)}"
        )


def check_benchmark_summary_doc_paths_exist(a_errors: list[str]) -> None:
    l_targets = [
        (
            "docs/simd/README.md",
            "当前稳定 benchmark 证据见",
        ),
        (
            "tests/nextpas.core.simd/docs/simd_completeness_matrix.md",
            "最新 backend benchmark summary",
        ),
    ]
    l_path_re = re.compile(r"tests/nextpas\.core\.simd/logs/backend-bench-[0-9-]+/summary\.md")

    for l_rel, l_anchor in l_targets:
        l_found_anchor = False
        for l_lineno, l_line in enumerate(read_text(l_rel).splitlines(), start=1):
            if l_anchor not in l_line:
                continue
            l_found_anchor = True
            l_match = l_path_re.search(l_line)
            if l_match is None:
                a_errors.append(
                    f"{l_rel}:{l_lineno}: benchmark evidence line must point at a concrete backend-bench summary path"
                )
                continue

            l_summary_rel = l_match.group(0)
            if not (REPO_ROOT / l_summary_rel).is_file():
                a_errors.append(
                    f"{l_rel}:{l_lineno}: benchmark evidence path does not exist in the current tree: {l_summary_rel}"
                )
        if not l_found_anchor:
            a_errors.append(f"{l_rel}: benchmark evidence anchor line missing")


def check_readme_allocator_example_alignment_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    if "p := SimdAlloc(1024);        // 自动对齐 (AVX2→32B, AVX-512→64B)" in l_text:
        a_errors.append(
            f"{l_rel}: allocator example comment must not omit active-backend profile semantics "
            "or the default 16-byte fallback"
        )

    l_required_snippet = (
        "p := SimdAlloc(1024);        // `saAuto`：按当前 active backend 的默认 profile 取值 "
        "(AVX-512=64B, AVX2=32B, 其余=16B)"
    )
    if l_required_snippet not in l_text:
        a_errors.append(
            f"{l_rel}: allocator example comment must spell out saAuto active-backend profile truth"
        )


def check_aligned_memory_argument_contract(a_errors: list[str]) -> None:
    l_targets = {
        "docs/simd/GOAL_TREE.md": [
            "Aligned memory argument contract",
            "AlignedAlloc",
            "AlignedRealloc",
            "IsAligned",
            "AlignUp",
            "AlignUpSize",
            "AlignedMemCopy",
            "AlignedMemFill",
            "TAlignedArray<T>",
            "非零 2 次幂",
            "SizeOf(Pointer)",
            "EArgumentError",
            "EOutOfMemory",
            "SIMD allocator size contract",
            "SimdAlloc",
            "SimdRealloc",
            "size + header + alignment",
            "EOutOfMemory",
            "提前释放原指针",
            "SimdAlloc(0)",
            "SimdRealloc(nil, 0)",
            "SimdFree(nil)",
        ],
        "docs/simd/architecture-guide.md": [
            "aligned memory argument contract",
            "AlignedAlloc",
            "AlignedRealloc",
            "IsAligned",
            "AlignUp",
            "AlignUpSize",
            "AlignedMemCopy",
            "AlignedMemFill",
            "TAlignedArray<T>",
            "non-zero power of two",
            "SizeOf(Pointer)",
            "EArgumentError",
            "EOutOfMemory",
            "SIMD_ALIGN_16",
            "SIMD_ALIGN_32",
            "SIMD_ALIGN_64",
            "SimdAlloc",
            "SimdRealloc",
            "size + header + alignment",
            "SimdFree(nil)",
            "have not already been freed",
        ],
        "docs/simd/api.md": [
            "AlignedAlloc",
            "AlignedRealloc",
            "IsAligned",
            "AlignUp",
            "AlignUpSize",
            "AlignedMemCopy",
            "AlignedMemFill",
            "TAlignedArray<T>",
            "非零 2 次幂",
            "SizeOf(Pointer)",
            "EArgumentError",
            "EOutOfMemory",
            "SIMD_ALIGN_16",
            "SIMD_ALIGN_32",
            "SIMD_ALIGN_64",
            "SimdAlloc",
            "SimdRealloc",
            "size + header + alignment",
            "SimdFree(nil)",
            "尚未释放过的指针",
        ],
        "docs/simd/README.md": [
            "AlignedAlloc",
            "AlignedRealloc",
            "IsAligned",
            "AlignUp",
            "AlignUpSize",
            "AlignedMemCopy",
            "AlignedMemFill",
            "TAlignedArray<T>",
            "非零 2 次幂",
            "SizeOf(Pointer)",
            "EArgumentError",
            "EOutOfMemory",
            "SIMD_ALIGN_16",
            "SIMD_ALIGN_32",
            "SIMD_ALIGN_64",
            "SimdAlloc",
            "SimdRealloc",
            "size + header + alignment",
            "SimdFree(nil)",
            "尚未释放过的指针",
        ],
    }
    for l_rel, l_tokens in l_targets.items():
        l_missing = contains_all(read_text(l_rel), l_tokens)
        if l_missing:
            a_errors.append(
                f"{l_rel}: aligned memory argument contract drift; "
                f"missing tokens: {', '.join(l_missing)}"
            )


def check_readme_signal_example_window_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    if "HannWindowF32(@win[0], 1024);               // SIMD 加速窗函数" in l_text:
        a_errors.append(
            f"{l_rel}: signal example must not present HannWindowF32 as an unconditional SIMD-accelerated window function"
        )

    l_required_snippet = (
        "HannWindowF32(@win[0], 1024);               // Hann 窗；索引填充为标量循环，后续 ArrayCosF32/ArrayLinearF32 仍受当前 active backend 约束"
    )
    if l_required_snippet not in l_text:
        a_errors.append(
            f"{l_rel}: signal example must spell out scalar-fill plus active-backend routing truth"
        )


def check_readme_operation_notes_runtime_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = (
        "**优化**：x86_64 使用 SSE2/AVX2；AArch64 默认仍是 scalar fallback，"
        "只有显式启用 NEON asm opt-in 时才会走 NEON 快路径"
    )
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: repeated operation notes must not reduce x86 runtime binding to a fixed SSE2/AVX2 wording"
        )

    l_new_line = (
        "**优化**：x86_64 会经 façade `dispatch table` 从当前 `dispatchable` 集合里绑定 "
        "`active backend`；常见候选包括 SSE2/AVX2，无可派发 SIMD 时继续走 `scalar fallback`。"
        "AArch64 默认仍是 scalar fallback，只有显式启用 NEON asm opt-in 时才会走 NEON 快路径"
    )
    if l_text.count(l_new_line) < 6:
        a_errors.append(
            f"{l_rel}: repeated operation notes must spell out x86 dispatch-table/runtime truth for the API entries"
        )


def check_readme_utf8validate_runtime_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = (
        "**优化**：x86_64 使用 SSE2 ASCII 快路径 + 标量回退；AArch64 默认仍是 scalar fallback，"
        "只有显式启用 NEON asm opt-in 时才会走 NEON ASCII 快路径"
    )
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: Utf8Validate note must not reduce x86 binding to a fixed SSE2 ASCII path or imply a NEON ASCII slot on AArch64"
        )

    l_required_line = (
        "**优化**：x86_64 会经 façade `dispatch table` 从当前 `dispatchable` 集合里绑定 "
        "`active backend`；当前可落到 SSE2 / AVX2，若 `active backend` 为 AVX-512，"
        "则 `Utf8Validate` 继续复用 cloned AVX2 slot；无可派发 SIMD 时回到 `scalar fallback`。"
        "AArch64 当前仍走 `scalar fallback`；现阶段即使启用 NEON asm opt-in，也没有独立 "
        "`Utf8Validate` NEON slot"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: Utf8Validate note must spell out dispatch-table binding, AVX-512 cloned AVX2 slot truth, and current AArch64 scalar-only status"
        )


def check_readme_bitsetpopcount_matrix_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = "  - POPCNT：BitsetPopCount 快路径"
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: BitsetPopCount support-matrix note must not collapse runtime/backend truth into a standalone POPCNT fast-path label"
        )

    l_required_line = (
        "  - BitsetPopCount：x86_64 会经 façade `dispatch table` 绑定当前 `active backend`；"
        "可落到 `SSE2 / AVX2 / AVX-512`，其中 `AVX2 / AVX-512` 内部使用 `POPCNT`，"
        "`SSE2` 保留 SWAR 计数；无可派发 SIMD 时回到 `scalar fallback`"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: BitsetPopCount support-matrix note must spell out x86 dispatch-table binding plus SSE2/AVX2/AVX-512 implementation truth"
        )


def check_readme_utf8_matrix_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = "  - UTF‑8：FastPath（ASCII SSE2 + 非 ASCII 回退标量）"
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: UTF-8 support-matrix note must not collapse runtime/backend truth into a fixed SSE2 ASCII fast-path claim"
        )

    l_required_line = (
        "  - UTF‑8：`Utf8Validate` 会经 façade `dispatch table` 绑定当前 `active backend`；"
        "可落到 `SSE2 / AVX2`，若 `active backend` 为 `AVX-512` 则继续复用 cloned `AVX2` slot；"
        "无可派发 SIMD 时回到 `scalar fallback`"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: UTF-8 support-matrix note must spell out x86 dispatch-table binding plus AVX-512 cloned AVX2 slot truth"
        )


def check_readme_overview_runtime_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = (
        "`nextpas.core.simd` 是一个高性能、跨平台的 SIMD 优化模块，为 FreePascal 应用程序提供内存、文本、位集和搜索操作的硬件加速。"
    )
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: overview must not present SIMD acceleration as an unconditional hardware-acceleration guarantee"
        )

    l_required_line = (
        "`nextpas.core.simd` 是一个高性能、跨平台的 SIMD 优化模块，为 FreePascal 应用程序提供内存、文本、位集和搜索操作的统一 façade；当当前 `dispatchable` SIMD backend 绑定到 `active backend` 时可走硬件加速，否则继续保持 `scalar fallback`。"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: overview must spell out dispatchable/active-backend gating plus scalar-fallback truth"
        )


def check_readme_x86_support_runtime_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = "- **当前支持**：SSE2, AVX2, AVX-512F, POPCNT"
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: x86 support summary must not mix backend labels with capability/internal-instruction names"
        )

    l_required_line = (
        "- **当前支持**：x86_64 backend family 当前覆盖 `SSE2 / SSE3 / SSSE3 / SSE4.1 / SSE4.2 / AVX2 / AVX-512`；"
        "实际 runtime 仍从当前 `dispatchable` 集合里绑定 `active backend`，`AVX-512F` / `POPCNT` 属于 "
        "CPU capability 或 backend 内部实现细节，不是独立 façade backend 名称"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: x86 support summary must separate backend-family coverage from dispatchable/active runtime truth and capability details"
        )


def check_readme_x86_planning_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = "- **规划支持**：AVX-512VL, AVX-512BW（部分子集）"
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: x86 planning summary must not present AVX-512 subfeatures like standalone facade backends"
        )

    l_required_line = (
        "- **规划支持**：`AVX-512` family 的后续 capability frontier 当前聚焦 `AVX-512VL / AVX-512BW`"
        "（部分子集）；它们属于现有 `AVX-512` backend 的子特性扩展，不是新增独立 façade backend 名称"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: x86 planning summary must spell out AVX-512VL/BW as AVX-512 family subfeatures instead of new facade backends"
        )


def check_readme_aarch64_planning_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_line = "- **规划支持**：CRC32, AES, PMULL, SVE"
    if l_old_line in l_text:
        a_errors.append(
            f"{l_rel}: AArch64 planning summary must not flatten capability qualifiers and future vector frontiers into standalone facade backends"
        )

    l_required_line = (
        "- **规划支持**：AArch64 capability / crypto extension frontier 当前聚焦 `CRC32 / AES / PMULL`；"
        "更宽 vector frontier 当前观察 `SVE / SVE2`。这两类都属于 capability qualification、"
        "opt-in / experimental intrinsics 方向与后续 backend frontier，不是已接纳的稳定 façade backend 名称"
    )
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: AArch64 planning summary must separate capability qualification from future SVE frontier instead of presenting new facade backends"
        )


def check_readme_aarch64_performance_levels_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/README.md"
    l_text = read_text(l_rel)

    l_old_level2 = "| LEVEL_2 | AVX2 | NEON+CRC/AES（opt-in） | 增强 SIMD 支持；仅在显式启用 NEON asm 与对应能力后成立 |"
    if l_old_level2 in l_text:
        a_errors.append(
            f"{l_rel}: LEVEL_2 AArch64 row must not flatten NEON plus CRC/AES capability qualifiers into a backend name"
        )

    l_required_level2 = (
        "| LEVEL_2 | AVX2 | NEON asm opt-in + `CRC32 / AES / PMULL` capability qualification | "
        "128-bit AArch64 SIMD 增强层；只有显式启用 NEON asm 且满足对应 capability / crypto extension 条件时才成立 |"
    )
    if l_required_level2 not in l_text:
        a_errors.append(
            f"{l_rel}: LEVEL_2 AArch64 row must separate NEON asm activation from CRC32/AES/PMULL capability qualification"
        )

    l_old_level3 = "| LEVEL_3 | AVX-512 | SVE/SVE2 | 高端 SIMD 支持 |"
    if l_old_level3 in l_text:
        a_errors.append(
            f"{l_rel}: LEVEL_3 AArch64 row must not present SVE/SVE2 as an established stable backend level"
        )

    l_required_level3 = (
        "| LEVEL_3 | AVX-512 | `SVE / SVE2` experimental intrinsics frontier | "
        "更宽 vector frontier；当前仍停留在 intrinsics / capability qualification 方向，不是稳定 façade backend 等级 |"
    )
    if l_required_level3 not in l_text:
        a_errors.append(
            f"{l_rel}: LEVEL_3 AArch64 row must describe SVE/SVE2 as an experimental intrinsics frontier instead of a stable backend level"
        )


def check_architecture_guide_runtime_selection_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/architecture-guide.md"
    l_text = read_text(l_rel)

    if "每个后端在 `initialization` 段自动注册。运行时根据 CPU 能力选择最优后端。" in l_text:
        a_errors.append(
            f"{l_rel}: backend-registration note must not reduce runtime binding to a pure "
            "CPU-capability best-backend selection claim"
        )

    l_required_tokens = [
        "dispatchable",
        "active backend",
        "runtime/control-plane",
        "TrySetCurrentBackend",
        "ResetCurrentBackendSelection",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: backend-registration note must retain runtime binding/control-plane anchors; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_architecture_guide_dispatch_snapshot_truth(a_errors: list[str]) -> None:
    l_rel = "docs/simd/architecture-guide.md"
    l_text = read_text(l_rel)

    if "558 个函数指针槽位" in l_text:
        a_errors.append(
            f"{l_rel}: dispatch-table sketch must not retain stale 558-slot snapshot"
        )

    l_required_tokens = [
        "616 个函数指针槽位",
        "当前快照",
        "source-contract",
    ]
    l_missing = contains_all(l_text, l_required_tokens)
    if l_missing:
        a_errors.append(
            f"{l_rel}: dispatch-table sketch must retain live dispatch snapshot anchors; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_publicabi_refresh_snapshot_truth(a_errors: list[str]) -> None:
    l_publicabi_rel = "docs/simd/publicabi.md"
    l_publicabi_text = read_text(l_publicabi_rel)
    l_publicabi_required = [
        "fresh getter",
        "旧 table",
        "前一份 snapshot metadata",
        "已发布的 metadata table",
    ]
    l_missing = contains_all(l_publicabi_text, l_publicabi_required)
    if l_missing:
        a_errors.append(
            f"{l_publicabi_rel}: refresh section must retain public-ABI metadata reuse truth; "
            f"missing tokens: {', '.join(l_missing)}"
        )

    l_stability_rel = "docs/simd/publicabi.stability.md"
    l_stability_text = read_text(l_stability_rel)

    if "`GetSimdPublicApi` 返回的是当前最新绑定 snapshot" in l_stability_text:
        a_errors.append(
            f"{l_stability_rel}: refresh contract must not reduce GetSimdPublicApi to an "
            "always-latest-binding-snapshot claim"
        )

    l_stability_required = [
        "fresh getter",
        "旧 table",
        "前一份 snapshot metadata",
        "复用之前已发布的 metadata table",
    ]
    l_missing = contains_all(l_stability_text, l_stability_required)
    if l_missing:
        a_errors.append(
            f"{l_stability_rel}: refresh contract must retain metadata-snapshot reuse truth; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_publicabi_maturity_bullet_format(a_errors: list[str]) -> None:
    l_files = [
        "docs/simd/publicabi.md",
        "docs/simd/publicabi.stability.md",
    ]
    l_bad_lines = [
        "- `only `sbRISCVV` currently carries that maturity flag`",
        "- `sbNEON` keeps the normal stable public-backend maturity reading`",
    ]
    l_required_lines = [
        "- only `sbRISCVV` currently carries that maturity flag",
        "- `sbNEON` keeps the normal stable public-backend maturity reading",
    ]
    for l_rel in l_files:
        l_text = read_text(l_rel)
        for l_bad_line in l_bad_lines:
            if l_bad_line in l_text:
                a_errors.append(f"{l_rel}: maturity flag bullet has malformed inline-code backticks")
        for l_required_line in l_required_lines:
            if l_required_line not in l_text:
                a_errors.append(f"{l_rel}: maturity flag bullet must use normalized inline-code formatting")


def check_layering_implementation_doc_path(a_errors: list[str]) -> None:
    l_legacy_path = "docs/SIMD_LAYERING_IMPLEMENTATION.md"
    l_new_rel = "docs/simd/layering-implementation.md"
    l_docs_dir = REPO_ROOT / "docs/simd"

    for l_path in sorted(l_docs_dir.glob("*.md")):
        l_rel = str(l_path.relative_to(REPO_ROOT))
        l_text = l_path.read_text(encoding="utf-8", errors="ignore")
        if l_legacy_path in l_text:
            a_errors.append(
                f"{l_rel}: must not point to missing legacy layering doc; use {l_new_rel}"
            )

    l_missing = contains_all(
        read_text(l_new_rel) if (REPO_ROOT / l_new_rel).is_file() else "",
        [
            "stable façade / control-plane",
            "control/publication seam",
            "thin backend adapter",
            "raw intrinsics leaf",
            "not a two-layer façade -> intrinsics shortcut",
            "default stable backend adapter",
            "active leaf",
            "experimental isolated",
        ],
    )
    if l_missing:
        a_errors.append(
            f"{l_new_rel}: layering implementation doc is missing or incomplete; "
            f"missing tokens: {', '.join(l_missing)}"
        )


def check_audit_runs_intrinsics_experimental_checker(a_errors: list[str]) -> None:
    l_rel = "tests/nextpas.core.simd/Makefile"
    l_text = read_text(l_rel)
    l_required_line = "$(PYTHON) check_intrinsics_experimental_status.py --summary-line"
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: audit target must run check_intrinsics_experimental_status.py --summary-line "
            "so experimental intrinsics isolation stays in the default focused audit gate"
        )


def check_audit_runs_sse2_structure_checker(a_errors: list[str]) -> None:
    l_rel = "tests/nextpas.core.simd/Makefile"
    l_text = read_text(l_rel)
    l_required_line = "$(PYTHON) check_sse2_structure.py --summary-line"
    if l_required_line not in l_text:
        a_errors.append(
            f"{l_rel}: audit target must run check_sse2_structure.py --summary-line "
            "so backend truth docs and SSE2 ownership contracts stay in the default focused audit gate"
        )


def check_active_intrinsics_leaf_headers(a_errors: list[str]) -> None:
    l_active_leaf_tokens = {
        "src/nextpas.core.simd.intrinsics.base.pas": [
            "Disposition: STABLE",
            "Foundational intrinsics type leaf",
            "no concrete ISA implementation",
            "TM128/TM256/TM512 storage model",
        ],
        "src/nextpas.core.simd.intrinsics.sse.pas": [
            "Disposition: STABLE",
            "Active SSE intrinsics leaf",
            "only qualified on x86/x86_64 targets",
        ],
        "src/nextpas.core.simd.intrinsics.avx2.pas": [
            "Disposition: STABLE",
            "Active AVX2 intrinsics leaf",
            "Compatibility: Intel Haswell",
        ],
        "src/nextpas.core.simd.intrinsics.mmx.pas": [
            "Disposition: STABLE",
            "Active MMX intrinsics leaf",
            "only qualified on x86/x86_64 hosts",
        ],
        "src/nextpas.core.simd.intrinsics.x86.sse2.pas": [
            "Disposition: STABLE",
            "Active SSE2 intrinsics leaf",
            "only qualified on x86/x86_64 targets",
        ],
    }
    for l_rel, l_tokens in l_active_leaf_tokens.items():
        l_text = read_text(l_rel)
        l_missing = contains_all(l_text, l_tokens)
        if l_missing:
            a_errors.append(
                f"{l_rel}: active intrinsics leaf header must not look like an experimental placeholder; "
                f"missing tokens: {', '.join(l_missing)}"
            )
        if "isolated experimental bring-up" in l_text.lower():
            a_errors.append(
                f"{l_rel}: active intrinsics leaf header must not claim isolated experimental bring-up"
            )


def check_intrinsics_support_leaf_headers(a_errors: list[str]) -> None:
    l_support_leaf_tokens = {
        "src/nextpas.core.simd.intrinsics.sve.base.pas": [
            "Disposition: Experimental Support",
            "SVE/SVE2 shared type leaf",
            "no runtime primitives",
            "not a stable public backend",
        ],
    }
    for l_rel, l_tokens in l_support_leaf_tokens.items():
        l_text = read_text(l_rel)
        l_missing = contains_all(l_text, l_tokens)
        if l_missing:
            a_errors.append(
                f"{l_rel}: experimental support leaf header must state type-only status; "
                f"missing tokens: {', '.join(l_missing)}"
            )


def main() -> int:
    l_errors: list[str] = []

    require_tokens(
        l_errors,
        "docs/simd/GOAL_TREE.md",
        [
            "G13",
            "SIMD contract qualification roadmap",
            "512-bit record alignment",
            "NEON public backend status",
            "RISC-V V and LoongArch/LASX",
            "gather/scatter partial coverage",
            "F16/half precision design",
            "transpose API boundary",
            "NEON AArch64 ABI GPR-to-vector",
        ],
    )
    require_goal_tree_item_completed(
        l_errors,
        "NEON public backend status",
        "the public/backend truth is contract-bound",
    )
    require_goal_tree_item_completed(
        l_errors,
        "RISC-V V and LoongArch/LASX",
        "experimental/stub truth and test-isolation boundary are contract-bound",
    )
    require_goal_tree_item_completed(
        l_errors,
        "gather/scatter partial coverage",
        "the x4 facade and masked coverage boundary are contract-bound",
    )
    require_goal_tree_item_completed(
        l_errors,
        "F16/half precision design",
        "the future ABI boundary and scalar-fallback semantics are contract-bound",
    )
    require_goal_tree_item_completed(
        l_errors,
        "transpose API boundary",
        "the matrix-vs-lane owner boundary and naming/test rules are contract-bound",
    )
    require_goal_tree_item_completed(
        l_errors,
        "NEON AArch64 ABI GPR-to-vector",
        "the NEON benchmark caveat and ABI bridge cost are contract-bound",
    )

    require_tokens(
        l_errors,
        "docs/simd/architecture-guide.md",
        [
            "512-bit record alignment contract",
            "FPC RECORDMIN=32",
            "ordinary record/stack/array/object fields",
            "SimdAlloc(..., sa64)",
            "AlignedAlloc(..., SIMD_ALIGN_64)",
            "NEON public backend status",
            "default scalar fallback",
            "NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM",
            "NEXTPAS_SIMD_ENABLE_NEON_ASM",
            "NEXTPAS_SIMD_NEON_ASM_COMPILER_READY",
            "FPC 3.3.1+",
            "AArch64 ABI",
            "GPR-to-vector",
            "RISC-V V and LoongArch/LASX are experimental/stub",
            "gather/scatter partial coverage",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "avx2_gather",
            "public facade",
            "F16/half precision design",
            "TF16",
            "F16C",
            "AVX512BF16",
            "NEON FP16",
            "scalar fallback",
            "transpose API boundary",
            "linalg matrix transpose",
            "SIMD lane transpose",
            "public ABI wrapper",
            "tests before ABI changes",
            "GatherSelect",
            "ScatterSelect",
            "duplicate indices",
            "lane order",
            "later lanes overwrite earlier writes",
            "last enabled lane wins",
            "nil-base boundary",
            "EArgumentNil",
            "enable=0",
            "returns `orVal`",
            "no-op",
        ],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.utils.pas",
        ["VecF32x4GatherSelect", "VecI32x4GatherSelect", "VecF32x4ScatterSelect", "VecI32x4ScatterSelect"],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.avx2.pas",
        ["avx2_gather_epi32", "avx2_gather_epi64", "avx2_gather_ps", "avx2_gather_pd"],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.linalg.pas",
        ["TSimdF32Matrix.Transpose", "TSimdF64Matrix.Transpose"],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.pas",
        [
            "Historical umbrella — not part of stable surface.",
            "experimental family 自动提升为默认主线",
            "ARM: NEON (experimental isolated stub",
            "SVE/SVE2 (experimental isolated stubs)",
            "RISC-V: RVV (experimental isolated stub)",
            "LoongArch: LASX (experimental isolated stub)",
        ],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.neon.pas",
        [
            "default scalar fallback",
            "NEON asm opt-in",
            "default behavior - no NEON registered",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/intrinsics.neon.md",
        [
            "default public backend state is scalar fallback",
            "inline asm is opt-in",
            "FPC 3.3.1+",
            "NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM",
            "NEXTPAS_SIMD_ENABLE_NEON_ASM",
            "NEXTPAS_SIMD_NEON_ASM_COMPILER_READY",
            "AArch64 ABI",
            "GPR-to-vector",
            "benchmark",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/README.md",
        [
            "NEON default public status",
            "default scalar fallback",
            "asm opt-in",
            "FPC 3.3.1+",
            "AArch64 ABI GPR-to-vector",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "VecF32x4Scatter",
            "VecI32x4Scatter",
            "public facade",
            "public ABI wrapper",
            "not part of the current stable public ABI wrapper",
            "TF16",
            "THalf",
            "AVX512BF16",
            "NEON FP16",
            "future ABI boundary",
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/README.md",
        [
            "explicit conversion APIs",
            "implicit arithmetic",
            "F32 <-> F16",
            "F32 <-> BF16",
            "F16C",
            "AVX-512 FP16",
            "rounding",
            "NaN payload",
            "infinities",
            "denormals",
            "saturation",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/quickref.md",
        [
            "STABLE 只指 public facade",
            "default scalar fallback",
            "NEON asm opt-in",
            "sbRISCVV",
            "experimental",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/checklist.md",
        [
            "public ABI wrapper",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "not part of the current stable public ABI wrapper",
            "TF16",
            "THalf",
            "AVX512BF16",
            "NEON FP16",
            "future ABI boundary",
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/api.md",
        [
            "public ABI wrapper",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "not part of the current stable public ABI wrapper",
            "duplicate indices",
            "lane order",
            "later lanes overwrite earlier writes",
            "last enabled lane wins",
            "Gather/scatter nil-base contract",
            "EArgumentNil",
            "enable=0",
            "returns `orVal`",
            "no-op",
            "TF16",
            "THalf",
            "AVX512BF16",
            "NEON FP16",
            "future ABI boundary",
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/api.md",
        [
            "explicit conversion APIs",
            "implicit arithmetic",
            "F32 <-> F16",
            "F32 <-> BF16",
            "F16C",
            "AVX-512 FP16",
            "rounding",
            "NaN payload",
            "infinities",
            "denormals",
            "saturation",
        ],
    )

    require_tokens(
        l_errors,
        "tests/nextpas.core.simd/nextpas.core.simd.testcase.pas",
        [
            "Test_VecF32x4_Gather_DuplicateIndices_DuplicateValues",
            "Test_VecI32x4_Scatter_DuplicateIndices_LastLaneWins",
            "Test_VecF32x4_ScatterSelect_DuplicateIndices_LastEnabledLaneWins",
            "Test_VecF32x4_Gather_NilBase_Raises_EArgumentNil",
            "Test_VecF32x4_GatherSelect_NilBase_AllDisabled_Returns_OrValue",
            "Test_VecF32x4_ScatterSelect_NilBase_EnabledLane_Raises_EArgumentNil",
        ],
    )

    require_tokens(
        l_errors,
        "tests/nextpas.core.simd/test_api_coverage_gather_scatter.pas",
        [
            "TestGatherScatterDuplicateIndexSemantics",
            "TestGatherScatterNilBaseContract",
            "duplicate gather f32 preserves lane duplication",
            "duplicate scatter i32 last lane wins",
            "duplicate scatter select f32 last enabled lane wins",
            "gather facade f32 nil base raises EArgumentNil",
            "gather select facade f32 nil base all-disabled returns orVal",
            "scatter select facade f32 nil base enabled lane raises EArgumentNil",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/cpuinfo.md",
        [
            "explicit conversion APIs",
            "implicit arithmetic",
            "F32 <-> F16",
            "F32 <-> BF16",
            "AVX-512 FP16",
            "AVX512BF16",
            "NEON FP16",
            "rounding",
            "NaN payload",
            "infinities",
            "denormals",
            "saturation",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/api.md",
        [
            "sbNEON",
            "default scalar fallback",
            "NEON asm opt-in",
            "dispatch / activation truth",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/map.md",
        [
            "public ABI wrapper",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "not part of the current stable public ABI wrapper",
            "TF16",
            "THalf",
            "AVX512BF16",
            "NEON FP16",
            "future ABI boundary",
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/maintenance.md",
        [
            "public ABI wrapper",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "not part of the current stable public ABI wrapper",
            "TF16",
            "THalf",
            "AVX512BF16",
            "NEON FP16",
            "future ABI boundary",
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.md",
        [
            "experimental",
            "sbRISCVV",
            "sbNEON",
            "only `sbRISCVV` currently carries that maturity flag",
            "`sbNEON` keeps the normal stable public-backend maturity reading",
            "asm opt-in",
            "dispatch / activation truth",
            "ABI maturity flag",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.md",
        [
            "future ABI boundary",
            "VecF32x4Gather",
            "VecI32x4Gather",
            "VecF32x4Scatter",
            "VecI32x4Scatter",
            "not part of the current stable public ABI wrapper",
            "TF16",
            "THalf",
            "F16C",
            "AVX512BF16",
            "NEON FP16",
            "scalar fallback",
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.md",
        [
            "explicit conversion APIs",
            "implicit arithmetic",
            "F32 <-> F16",
            "F32 <-> BF16",
            "AVX-512 FP16",
            "rounding",
            "NaN payload",
            "infinities",
            "denormals",
            "saturation",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.stability.md",
        [
            "GetSimdPublicApiV2",
            "TNextPasSimdPublicApiV2",
            "SnapshotGeneration",
            "SnapshotFlags",
            "FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND",
            "FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.stability.md",
        [
            "experimental",
            "sbRISCVV",
            "sbNEON",
            "only `sbRISCVV` currently carries that maturity flag",
            "`sbNEON` keeps the normal stable public-backend maturity reading",
            "scalar fallback",
            "asm opt-in",
            "dispatch / activation truth",
            "ABI maturity flag",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.stability.md",
        [
            "LoongArch/LASX",
            "experimental/stub",
            "public ABI backend enum/flag",
            "not part of the current stable public ABI backend set",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.stability.md",
        [
            "VecF32x4Gather",
            "VecI32x4Gather",
            "VecF32x4Scatter",
            "VecI32x4Scatter",
            "public facade",
            "public ABI wrapper",
            "not part of the current stable public ABI wrapper",
            "TF16",
            "THalf",
            "AVX512BF16",
            "NEON FP16",
            "future ABI boundary",
            "TSimdF32Matrix.Transpose",
            "TSimdF64Matrix.Transpose",
            "SIMD lane transpose",
        ],
    )

    require_tokens(
        l_errors,
        "docs/simd/publicabi.stability.md",
        [
            "explicit conversion APIs",
            "implicit arithmetic",
            "F32 <-> F16",
            "F32 <-> BF16",
            "AVX-512 FP16",
            "rounding",
            "NaN payload",
            "infinities",
            "denormals",
            "saturation",
        ],
    )

    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.neon.pas",
        [
            "Disposition: Experimental Isolated",
            "stub",
            "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS",
            "ISA qualification only",
            "not a stable public backend",
        ],
    )
    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.rvv.pas",
        [
            "Disposition: Experimental Isolated",
            "stub",
            "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS",
            "ISA qualification only",
            "not a stable public backend",
        ],
    )
    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.lasx.pas",
        [
            "Disposition: Experimental Isolated",
            "stub",
            "LoongArch/LASX",
            "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS",
            "ISA qualification only",
            "not a stable public backend",
        ],
    )
    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.sve.pas",
        [
            "Disposition: Experimental Isolated",
            "stub",
            "SVE",
            "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS",
            "ISA qualification only",
            "not a stable public backend",
        ],
    )
    require_tokens(
        l_errors,
        "src/nextpas.core.simd.intrinsics.sve2.pas",
        [
            "Disposition: Experimental Isolated",
            "stub",
            "SVE2",
            "NEXTPAS_SIMD_EXPERIMENTAL_INTRINSICS",
            "ISA qualification only",
            "not a stable public backend",
        ],
    )

    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.neon.pas")
    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.rvv.pas")
    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.lasx.pas")
    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.sve.pas")
    check_no_stable_disposition(l_errors, "src/nextpas.core.simd.intrinsics.sve2.pas")
    check_forbidden_gather_absence_claims(l_errors)
    check_public_abi_has_no_future_surface(l_errors)
    check_no_stale_interface_completeness_snapshots(l_errors)
    check_no_missing_legacy_simd_archive_refs(l_errors)
    check_backend_truth_neon_activation_boundary(l_errors)
    check_readme_has_no_default_neon_fastpath_claims(l_errors)
    check_quickref_has_no_default_neon_backend_claims(l_errors)
    check_experimental_backend_truth_docs(l_errors)
    check_architecture_impl_neon_activation_boundary(l_errors)
    check_cpuinfo_compile_option_boundary(l_errors)
    check_cpuinfo_backend_management_wording(l_errors)
    check_cpuinfo_backend_enum_activation_truth(l_errors)
    check_cpuinfo_f16_raw_feature_boundary(l_errors)
    check_batch_api_runtime_routing_truth(l_errors)
    check_readme_topline_runtime_dispatch_truth(l_errors)
    check_readme_topline_api_compatibility_truth(l_errors)
    check_readme_topline_platform_support_truth(l_errors)
    check_readme_topline_fallback_truth(l_errors)
    check_readme_high_level_api_runtime_truth(l_errors)
    check_readme_high_level_api_performance_truth(l_errors)
    check_quickref_algorithm_internal_mechanism_truth(l_errors)
    check_quickref_runtime_auto_selection_wording(l_errors)
    check_quickref_backend_enum_activation_truth(l_errors)
    check_quickref_dispatch_mechanism_execution_truth(l_errors)
    check_api_topline_runtime_dispatch_truth(l_errors)
    check_api_supported_backend_table_activation_truth(l_errors)
    check_arrays_header_runtime_dispatch_truth(l_errors)
    check_backend_metadata_description_truth(l_errors)
    check_base_backend_enum_activation_truth(l_errors)
    check_ops_header_runtime_dispatch_truth(l_errors)
    check_transpose_cross_truth_docs(l_errors)
    check_f16_future_api_entry_docs(l_errors)
    check_f16_future_api_truth_docs(l_errors)
    check_neon_header_activation_truth(l_errors)
    check_neon_register_init_boundary_truth(l_errors)
    check_riscvv_header_backend_truth(l_errors)
    check_maintenance_nonx86_debt_truth(l_errors)
    check_pipeline_quickstart_dispatch_truth(l_errors)
    check_pipeline_quickstart_intro_truth(l_errors)
    check_pipeline_quickstart_example_comment_truth(l_errors)
    check_facade_unit_comment_runtime_truth(l_errors)
    check_pipeline_quickstart_usage_comment_truth(l_errors)
    check_batch_api_auto_mode_wording_truth(l_errors)
    check_neon_benchmark_abi_cost_truth(l_errors)
    check_backend_benchmark_settings_include_contract(l_errors)
    check_backend_benchmark_summary_caveat_chain(l_errors)
    check_benchmark_summary_doc_paths_exist(l_errors)
    check_readme_allocator_example_alignment_truth(l_errors)
    check_aligned_memory_argument_contract(l_errors)
    check_readme_signal_example_window_truth(l_errors)
    check_readme_operation_notes_runtime_truth(l_errors)
    check_readme_utf8validate_runtime_truth(l_errors)
    check_readme_bitsetpopcount_matrix_truth(l_errors)
    check_readme_utf8_matrix_truth(l_errors)
    check_readme_overview_runtime_truth(l_errors)
    check_readme_x86_support_runtime_truth(l_errors)
    check_readme_x86_planning_truth(l_errors)
    check_readme_aarch64_planning_truth(l_errors)
    check_readme_aarch64_performance_levels_truth(l_errors)
    check_architecture_guide_runtime_selection_truth(l_errors)
    check_architecture_guide_dispatch_snapshot_truth(l_errors)
    check_publicabi_refresh_snapshot_truth(l_errors)
    check_publicabi_maturity_bullet_format(l_errors)
    check_layering_implementation_doc_path(l_errors)
    check_audit_runs_intrinsics_experimental_checker(l_errors)
    check_audit_runs_sse2_structure_checker(l_errors)
    check_active_intrinsics_leaf_headers(l_errors)
    check_intrinsics_support_leaf_headers(l_errors)

    if l_errors:
        print("[SIMD-CONTRACT-ROADMAP] FAIL")
        for l_error in l_errors:
            print(f"  - {l_error}")
        return 1

    print("[SIMD-CONTRACT-ROADMAP] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

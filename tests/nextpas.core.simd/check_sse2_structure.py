#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def configure_console_streams() -> None:
    # Windows cmd redirection may expose a legacy code page (for example cp1252)
    # that cannot encode the section markers emitted by this audit report.
    for stream_name in ('stdout', 'stderr'):
        stream = getattr(sys, stream_name, None)
        if stream is None or not hasattr(stream, 'reconfigure'):
            continue
        try:
            stream.reconfigure(encoding='utf-8', errors='backslashreplace')
        except (AttributeError, OSError, ValueError):
            continue


INCLUDE_RE = re.compile(r'^\s*\{\$I\s+([^}]+)\}\s*$', re.IGNORECASE | re.MULTILINE)
REGISTER_HEADER_RE = re.compile(r'^\s*procedure\s+RegisterSSE2Backend\s*;', re.IGNORECASE | re.MULTILINE)
SYMBOL_HEADER_TEMPLATE = r'^\s*(?:function|procedure)\s+{name}\b'
MARKDOWN_TABLE_RE = re.compile(r'^\|(.+)\|\s*$', re.MULTILINE)
MARKDOWN_SEPARATOR_RE = re.compile(r'^:?-{3,}:?$')
ASM_ROUTINE_RE = re.compile(
    r'^\s*(function|procedure)\s+(simd_[A-Za-z0-9_]+)\s*\((.*?)\)\s*(?::[^\n;]+)?\s*;'
    r'.*?^\s*asm\s*(.*?)^\s*end\s*;',
    re.IGNORECASE | re.MULTILINE | re.DOTALL,
)
ALIGNED_CONSTREF_LOAD_RE = re.compile(
    r'\b(movdqa|movapd|movaps)\s+xmm\d+\s*,\s*\[(rcx|rdx|rdi|rsi|eax|edx)\]',
    re.IGNORECASE,
)

FORBIDDEN_RAW_FLOAT_OPCODES_BY_ROUTINE = {
    'simd_add_ps': ('addps',),
    'simd_sub_ps': ('subps',),
    'simd_mul_ps': ('mulps',),
    'simd_div_ps': ('divps',),
    'simd_sqrt_ps': ('sqrtps',),
    'simd_min_ps': ('minps',),
    'simd_max_ps': ('maxps',),
    'simd_add_pd': ('addpd',),
    'simd_sub_pd': ('subpd',),
    'simd_mul_pd': ('mulpd',),
    'simd_div_pd': ('divpd',),
    'simd_sqrt_pd': ('sqrtpd',),
    'simd_min_pd': ('minpd',),
    'simd_max_pd': ('maxpd',),
    'simd_add_sd': ('addsd',),
    'simd_sub_sd': ('subsd',),
    'simd_mul_sd': ('mulsd',),
    'simd_div_sd': ('divsd',),
    'simd_sqrt_sd': ('sqrtsd',),
    'simd_min_sd': ('minsd',),
    'simd_max_sd': ('maxsd',),
    'simd_cmpeq_pd': ('cmppd',),
    'simd_cmplt_pd': ('cmppd',),
    'simd_cmple_pd': ('cmppd',),
    'simd_cmpgt_pd': ('cmppd',),
    'simd_cmpge_pd': ('cmppd',),
    'simd_cmpneq_pd': ('cmppd',),
    'simd_cmpnlt_pd': ('cmppd',),
    'simd_cmpnle_pd': ('cmppd',),
    'simd_cmpngt_pd': ('cmppd',),
    'simd_cmpnge_pd': ('cmppd',),
    'simd_cmpord_pd': ('cmppd',),
    'simd_cmpunord_pd': ('cmppd',),
    'simd_cmpeq_sd': ('cmpsd',),
    'simd_cmplt_sd': ('cmpsd',),
    'simd_cmple_sd': ('cmpsd',),
    'simd_cmpgt_sd': ('cmpsd',),
    'simd_cmpge_sd': ('cmpsd',),
    'simd_cmpneq_sd': ('cmpsd',),
    'simd_cmpnlt_sd': ('cmpsd',),
    'simd_cmpnle_sd': ('cmpsd',),
    'simd_cmpngt_sd': ('cmpsd',),
    'simd_cmpnge_sd': ('cmpsd',),
    'simd_cmpord_sd': ('cmpsd',),
    'simd_cmpunord_sd': ('cmpsd',),
    'simd_comieq_sd': ('comisd',),
    'simd_comilt_sd': ('comisd',),
    'simd_comile_sd': ('comisd',),
    'simd_comigt_sd': ('comisd',),
    'simd_comige_sd': ('comisd',),
    'simd_comineq_sd': ('comisd',),
    'simd_ucomieq_sd': ('ucomisd',),
    'simd_ucomilt_sd': ('ucomisd',),
    'simd_ucomile_sd': ('ucomisd',),
    'simd_ucomigt_sd': ('ucomisd',),
    'simd_ucomige_sd': ('ucomisd',),
    'simd_ucomineq_sd': ('ucomisd',),
}

REQUIRED_SIDE_EFFECT_OPCODES_BY_ROUTINE = {
    'simd_clflush': ('clflush',),
    'simd_lfence': ('lfence',),
    'simd_mfence': ('mfence',),
    'simd_pause': ('pause',),
}

ALLOWED_INTRINSICS_STATUS = {
    'active leaf',
    'experimental isolated',
    'transitional',
    'retire target',
}

EXPECTED_BACKEND_TRUTH = {
    'Scalar': ('backend adapter', 'src/nextpas.core.simd.scalar.pas', 'yes'),
    'SSE2': ('backend adapter', 'src/nextpas.core.simd.sse2.pas', 'yes'),
    'SSE3': ('backend adapter', 'src/nextpas.core.simd.sse3.pas', 'yes'),
    'SSSE3': ('backend adapter', 'src/nextpas.core.simd.ssse3.pas', 'yes'),
    'SSE4.1': ('backend adapter', 'src/nextpas.core.simd.sse41.pas', 'yes'),
    'SSE4.2': ('backend adapter', 'src/nextpas.core.simd.sse42.pas', 'yes'),
    'AVX-512': ('backend adapter', 'src/nextpas.core.simd.avx512.pas', 'yes'),
    'AVX2': ('backend adapter', 'src/nextpas.core.simd.avx2.pas', 'yes'),
    'NEON': ('backend adapter', 'src/nextpas.core.simd.neon.pas', 'yes'),
    'RISCVV': ('backend adapter', 'src/nextpas.core.simd.riscvv.pas', 'opt-in only'),
}

EXPECTED_INTRINSICS_DISPOSITION = {
    'nextpas.core.simd.intrinsics': 'transitional',
    'nextpas.core.simd.intrinsics.aes': 'experimental isolated',
    'nextpas.core.simd.intrinsics.avx': 'experimental isolated',
    'nextpas.core.simd.intrinsics.avx2': 'active leaf',
    'nextpas.core.simd.intrinsics.avx512': 'experimental isolated',
    'nextpas.core.simd.intrinsics.base': 'active leaf',
    'nextpas.core.simd.intrinsics.fma3': 'experimental isolated',
    'nextpas.core.simd.intrinsics.lasx': 'experimental isolated',
    'nextpas.core.simd.intrinsics.mmx': 'active leaf',
    'nextpas.core.simd.intrinsics.neon': 'experimental isolated',
    'nextpas.core.simd.intrinsics.rvv': 'experimental isolated',
    'nextpas.core.simd.intrinsics.sha': 'experimental isolated',
    'nextpas.core.simd.intrinsics.sse': 'active leaf',
    'nextpas.core.simd.intrinsics.sse2': 'retire target',
    'nextpas.core.simd.intrinsics.sse3': 'experimental isolated',
    'nextpas.core.simd.intrinsics.sse41': 'experimental isolated',
    'nextpas.core.simd.intrinsics.sse42': 'experimental isolated',
    'nextpas.core.simd.intrinsics.sve.base': 'active leaf',
    'nextpas.core.simd.intrinsics.sve': 'experimental isolated',
    'nextpas.core.simd.intrinsics.sve2': 'experimental isolated',
    'nextpas.core.simd.intrinsics.x86.sse2': 'active leaf',
}

ROOT_ROLE_MARKERS = [
    'thin backend adapter / backend assembly layer',
    'owns tvec* / tmask* facade semantics, dispatch registration, compare-mask translation',
    'wide_emulation, mem/text/stat helpers, and multi-register composition stay here',
    'must not depend on nextpas.core.simd.intrinsics.sse2',
]

RAW_LEAF_ROLE_MARKERS = [
    'active raw isa leaf for sse2 128-bit primitives',
    'tm128/raw intrinsic surface only',
    'no tvec/tmask facade, no dispatch registration, no runtime control-plane knowledge',
]

RAW_LEAF_FORBIDDEN_PATTERNS = {
    'TVec facade token': r'\bTVec[A-Za-z0-9_]*\b',
    'TMask facade token': r'\bTMask[A-Za-z0-9_]*\b',
    'dispatch contract token': r'\bTSimdDispatchTable\b',
    'backend registration token': r'\bRegisterSSE2Backend\b',
    'runtime control-plane token': r'\b(?:GetCurrentRuntimeSnapshot|TrySetCurrentBackend|SetCurrentBackend|ResetCurrentBackendSelection)\b',
    'dispatch unit dependency': r'fafafa\.core\.simd\.dispatch\b',
    'runtime unit dependency': r'fafafa\.core\.simd\.runtime\b',
    'cpuinfo unit dependency': r'fafafa\.core\.simd\.cpuinfo\b',
    'wide emulation token': r'\bwide_emulation\b',
}

MIGRATION_DOC_REQUIRED_SECTIONS = [
    '## A - 迁入 `intrinsics.x86.sse2`',
    '## B - 永久保留在 `simd.sse2`',
    '## C - 迁移后删除 / 废弃',
]

MIGRATION_DOC_REQUIRED_TOKENS = [
    '当前发布真相源仍然是 `src/nextpas.core.simd.sse2.pas`',
    'SSE2AddF32x4',
    'SSE2LoadF32x4',
    'RegisterSSE2Backend',
    'MemEqual_SSE2',
    'Utf8Validate_SSE2',
    'wide_emulation',
    'retire target',
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Check SSE2 backend structural contracts, ownership docs, and raw-leaf boundaries.'
    )
    parser.add_argument('--json', action='store_true', help='Print machine-readable JSON output.')
    parser.add_argument(
        '--summary-line',
        action='store_true',
        help='Print a single-line summary for log scraping.',
    )
    return parser.parse_args()


def collect_include_names(a_text: str) -> list[str]:
    return [match.group(1).strip().strip("'\"") for match in INCLUDE_RE.finditer(a_text)]


def strip_pascal_comments(a_text: str) -> str:
    l_text = re.sub(r'//.*', '', a_text)
    l_text = re.sub(r'\(\*.*?\*\)', '', l_text, flags=re.DOTALL)
    l_text = re.sub(r'\{(?!\$).*?\}', '', l_text, flags=re.DOTALL)
    return l_text


def extract_markdown_rows(a_text: str) -> list[list[str]]:
    l_rows: list[list[str]] = []
    for match in MARKDOWN_TABLE_RE.finditer(a_text):
        l_cells = [cell.strip().strip('`') for cell in match.group(1).split('|')]
        if all(MARKDOWN_SEPARATOR_RE.fullmatch(cell.replace(' ', '')) for cell in l_cells if cell):
            continue
        l_rows.append(l_cells)
    return l_rows


def extract_backend_truth(a_text: str) -> dict[str, tuple[str, str, str]]:
    l_rows = extract_markdown_rows(a_text)
    l_result: dict[str, tuple[str, str, str]] = {}
    for l_cells in l_rows:
        if len(l_cells) < 4:
            continue
        if l_cells[0] == 'Backend':
            continue
        l_result[l_cells[0]] = (l_cells[1], l_cells[2], l_cells[3])
    return l_result


def extract_intrinsics_disposition(a_text: str) -> dict[str, str]:
    l_rows = extract_markdown_rows(a_text)
    l_result: dict[str, str] = {}
    for l_cells in l_rows:
        if len(l_cells) < 2:
            continue
        if l_cells[0] == 'Unit':
            continue
        l_result[l_cells[0]] = l_cells[1]
    return l_result


def collect_repo_intrinsics_units(a_src_dir: Path) -> list[str]:
    l_units: list[str] = []
    for l_path in sorted(a_src_dir.glob('nextpas.core.simd.intrinsics*.pas')):
        l_units.append(l_path.stem)
    return l_units


def collect_role_marker_failures(a_text: str, a_markers: list[str], a_label: str) -> list[str]:
    l_lower = a_text.lower()
    l_failures: list[str] = []
    for l_marker in a_markers:
        if l_marker not in l_lower:
            l_failures.append(f'{a_label} missing role marker: {l_marker}')
    return l_failures


def collect_uses_clause_hits(a_text: str, a_unit_name: str) -> list[str]:
    l_hits: list[str] = []
    l_stripped = strip_pascal_comments(a_text)
    for l_match in re.finditer(r'\buses\b(.*?);', l_stripped, flags=re.IGNORECASE | re.DOTALL):
        l_block = l_match.group(1)
        if re.search(r'(?<![A-Za-z0-9_])' + re.escape(a_unit_name) + r'(?![A-Za-z0-9_])', l_block, flags=re.IGNORECASE):
            l_hits.append(' '.join(l_block.split()))
    return l_hits


def collect_forbidden_pattern_hits(a_text: str, a_patterns: dict[str, str]) -> list[str]:
    l_stripped = strip_pascal_comments(a_text)
    l_hits: list[str] = []
    for l_label, l_pattern in a_patterns.items():
        if re.search(l_pattern, l_stripped, flags=re.IGNORECASE):
            l_hits.append(l_label)
    return l_hits


def collect_constref_aligned_load_violations(a_text: str) -> list[str]:
    l_violations: list[str] = []
    for l_routine_match in ASM_ROUTINE_RE.finditer(a_text):
        l_routine_name = l_routine_match.group(2)
        l_signature = l_routine_match.group(3)
        l_body = l_routine_match.group(4)
        if 'constref' not in l_signature.lower():
            continue
        for l_load_match in ALIGNED_CONSTREF_LOAD_RE.finditer(l_body):
            l_line_no = a_text.count('\n', 0, l_routine_match.start(4) + l_load_match.start()) + 1
            l_opcode = l_load_match.group(1).lower()
            l_reg = l_load_match.group(2).lower()
            l_violations.append(
                f'{l_routine_name}: line {l_line_no} uses {l_opcode} source load from constref parameter register [{l_reg}]'
            )
    return l_violations


def collect_forbidden_raw_float_opcode_hits(a_text: str) -> list[str]:
    l_hits: list[str] = []
    for l_routine_match in ASM_ROUTINE_RE.finditer(a_text):
        l_routine_name = l_routine_match.group(2).lower()
        l_body = l_routine_match.group(4)
        l_forbidden_opcodes = FORBIDDEN_RAW_FLOAT_OPCODES_BY_ROUTINE.get(l_routine_name)
        if l_forbidden_opcodes is None:
            continue
        for l_opcode in l_forbidden_opcodes:
            for l_opcode_match in re.finditer(r'\b' + re.escape(l_opcode) + r'\b', l_body, flags=re.IGNORECASE):
                l_line_no = a_text.count('\n', 0, l_routine_match.start(4) + l_opcode_match.start()) + 1
                l_hits.append(f'{l_routine_name}: line {l_line_no} still emits raw {l_opcode}')
    return l_hits


def collect_missing_required_side_effect_opcodes(a_text: str) -> list[str]:
    l_missing: list[str] = []
    for l_routine_match in ASM_ROUTINE_RE.finditer(a_text):
        l_routine_name = l_routine_match.group(2).lower()
        l_body = l_routine_match.group(4)
        l_required_opcodes = REQUIRED_SIDE_EFFECT_OPCODES_BY_ROUTINE.get(l_routine_name)
        if l_required_opcodes is None:
            continue
        for l_opcode in l_required_opcodes:
            if re.search(r'\b' + re.escape(l_opcode) + r'\b', l_body, flags=re.IGNORECASE) is None:
                l_missing.append(f'{l_routine_name}: missing required side-effect opcode {l_opcode}')
    return l_missing


def main() -> int:
    configure_console_streams()
    args = parse_args()

    root = Path(__file__).resolve().parents[2]
    src_dir = root / 'src'
    docs_dir = root / 'docs'

    root_unit_path = src_dir / 'nextpas.core.simd.sse2.pas'
    register_inc_path = src_dir / 'nextpas.core.simd.sse2.register.inc'
    wide_inc_path = src_dir / 'nextpas.core.simd.sse2.wide_emulation.inc'
    select_inc_path = src_dir / 'nextpas.core.simd.sse2.select.inc'
    intrinsics_raw_leaf_path = src_dir / 'nextpas.core.simd.intrinsics.x86.sse2.pas'
    backend_truth_doc_path = docs_dir / 'SIMD_BACKEND_TRUTH.md'
    intrinsics_disposition_doc_path = docs_dir / 'SIMD_INTRINSICS_DISPOSITION.md'
    migration_map_doc_path = docs_dir / 'SIMD_SSE2_MIGRATION_MAP.md'

    failures: list[str] = []
    duplicate_leaf_names: list[str] = []
    duplicate_leaf_records: list[dict[str, object]] = []
    root_symbol_counts: dict[str, int] = {}
    wide_symbol_counts: dict[str, int] = {}
    select_symbol_counts: dict[str, int] = {}
    wide_section_counts: dict[str, int] = {}

    root_unit_text = root_unit_path.read_text(encoding='utf-8', errors='replace') if root_unit_path.exists() else ''
    if not root_unit_path.exists():
        failures.append(f'missing root unit: {root_unit_path.name}')

    register_exists = register_inc_path.exists()
    register_text = register_inc_path.read_text(encoding='utf-8', errors='replace') if register_exists else ''
    if not register_exists:
        failures.append(f'missing register include: {register_inc_path.name}')

    select_exists = select_inc_path.exists()
    select_text = select_inc_path.read_text(encoding='utf-8', errors='replace') if select_exists else ''
    if not select_exists:
        failures.append(f'missing select include: {select_inc_path.name}')

    wide_text = wide_inc_path.read_text(encoding='utf-8', errors='replace') if wide_inc_path.exists() else ''
    wide_include_names = collect_include_names(wide_text) if wide_inc_path.exists() else []
    if not wide_inc_path.exists():
        failures.append(f'missing wide include: {wide_inc_path.name}')

    intrinsics_raw_leaf_text = (
        intrinsics_raw_leaf_path.read_text(encoding='utf-8', errors='replace')
        if intrinsics_raw_leaf_path.exists()
        else ''
    )
    if not intrinsics_raw_leaf_path.exists():
        failures.append(f'missing intrinsics raw leaf: {intrinsics_raw_leaf_path.name}')

    root_include_names = collect_include_names(root_unit_text)
    root_include_count = sum(1 for item in root_include_names if item.lower() == register_inc_path.name.lower())
    if root_include_count != 1:
        failures.append(
            f'root unit must include {register_inc_path.name} exactly once (found {root_include_count})'
        )

    root_wide_include_count = sum(1 for item in root_include_names if item.lower() == wide_inc_path.name.lower())
    if root_wide_include_count != 1:
        failures.append(
            f'root unit must include {wide_inc_path.name} exactly once (found {root_wide_include_count})'
        )

    root_select_include_count = sum(1 for item in root_include_names if item.lower() == select_inc_path.name.lower())
    if root_select_include_count != 1:
        failures.append(
            f'root unit must include {select_inc_path.name} exactly once (found {root_select_include_count})'
        )

    root_register_header_count = len(REGISTER_HEADER_RE.findall(root_unit_text))
    if root_register_header_count != 1:
        failures.append(
            'root unit should keep only the interface declaration for RegisterSSE2Backend '
            f'(found {root_register_header_count} headers)'
        )

    register_header_count = len(REGISTER_HEADER_RE.findall(register_text)) if register_exists else 0
    if register_exists and register_header_count != 1:
        failures.append(
            f'{register_inc_path.name} must define RegisterSSE2Backend exactly once '
            f'(found {register_header_count})'
        )

    if select_exists and not select_text.strip():
        failures.append(f'{select_inc_path.name} must not be empty')

    wide_self_include_count = sum(1 for item in wide_include_names if item.lower() == wide_inc_path.name.lower())
    if wide_self_include_count != 0:
        failures.append(f'{wide_inc_path.name} must not self-include (found {wide_self_include_count})')

    leaf_occurrences: dict[str, list[int]] = {}
    for line_no, line in enumerate(wide_text.splitlines(), 1):
        match = INCLUDE_RE.match(line)
        if match is None:
            continue
        include_name = match.group(1).strip().strip("'\"")
        if not include_name.lower().startswith('nextpas.core.simd.sse2.'):
            continue
        if include_name.lower() == wide_inc_path.name.lower():
            continue
        leaf_occurrences.setdefault(include_name, []).append(line_no)

    for include_name, line_numbers in sorted(leaf_occurrences.items()):
        if len(line_numbers) > 1:
            duplicate_leaf_names.append(include_name)
            duplicate_leaf_records.append({'include': include_name, 'lines': line_numbers})
    if duplicate_leaf_names:
        failures.append(
            f'{wide_inc_path.name} has duplicate leaf includes: {", ".join(duplicate_leaf_names)}'
        )

    representative_wide_symbols = [
        'SSE2AddF32x16',
        'SSE2AddF64x8',
        'SSE2AddI32x16',
        'SSE2AddI64x4',
        'SSE2AddU32x8',
        'SSE2AddU64x4',
        'SSE2AddI64x8',
        'MemDiffRange_SSE2',
        'Utf8Validate_SSE2',
    ]
    for symbol_name in representative_wide_symbols:
        pattern = re.compile(SYMBOL_HEADER_TEMPLATE.format(name=re.escape(symbol_name)), re.IGNORECASE | re.MULTILINE)
        root_symbol_counts[symbol_name] = len(pattern.findall(root_unit_text))
        wide_symbol_counts[symbol_name] = len(pattern.findall(wide_text))
        if root_symbol_counts[symbol_name] != 1:
            failures.append(
                f'root unit should expose exactly one declaration for {symbol_name} '
                f'(found {root_symbol_counts[symbol_name]})'
            )
        if wide_symbol_counts[symbol_name] != 1:
            failures.append(
                f'{wide_inc_path.name} should provide exactly one implementation header for {symbol_name} '
                f'(found {wide_symbol_counts[symbol_name]})'
            )

    select_symbol_pattern = re.compile(
        SYMBOL_HEADER_TEMPLATE.format(name=re.escape('SSE2SelectF64x2')),
        re.IGNORECASE | re.MULTILINE,
    )
    select_symbol_counts['SSE2SelectF64x2'] = len(select_symbol_pattern.findall(select_text))
    if select_symbol_counts['SSE2SelectF64x2'] != 1:
        failures.append(
            f'{select_inc_path.name} should define SSE2SelectF64x2 exactly once '
            f'(found {select_symbol_counts["SSE2SelectF64x2"]})'
        )
    if len(select_symbol_pattern.findall(wide_text)) != 0:
        failures.append(f'{wide_inc_path.name} must not duplicate SSE2SelectF64x2')

    forbidden_wide_markers = [
        '// === SSE2 Arithmetic Operations ===',
        '// === SSE2 Comparison Operations ===',
        '// === SSE2 Math Functions ===',
        '// === SSE2 Reduction Operations ===',
        '// === SSE2 Memory Operations ===',
        '// === SSE2 Utility Operations ===',
    ]
    for marker in forbidden_wide_markers:
        count = wide_text.count(marker)
        wide_section_counts[marker] = count
        if count != 0:
            failures.append(f'{wide_inc_path.name} must not contain stale duplicated marker: {marker}')

    expected_wide_sections = [
        '// === F32x16 操作 (16×Float32) - 使用 2×F32x8 ===',
        '// === F64x8 操作 (8×Float64) - 使用 2×F64x4 ===',
        '// === I32x16 操作 (16×Int32) - 使用 2×I32x8 ===',
    ]
    for marker in expected_wide_sections:
        count = wide_text.count(marker)
        wide_section_counts[marker] = count
        if count != 1:
            failures.append(
                f'{wide_inc_path.name} should contain section marker exactly once: {marker} (found {count})'
            )

    failures.extend(collect_role_marker_failures(root_unit_text, ROOT_ROLE_MARKERS, root_unit_path.name))
    failures.extend(
        collect_role_marker_failures(
            intrinsics_raw_leaf_text,
            RAW_LEAF_ROLE_MARKERS,
            intrinsics_raw_leaf_path.name,
        )
    )

    root_uses_hits = collect_uses_clause_hits(root_unit_text, 'nextpas.core.simd.intrinsics.sse2')
    if root_uses_hits:
        failures.append(
            f'{root_unit_path.name} must not depend on nextpas.core.simd.intrinsics.sse2 in uses clauses'
        )

    raw_leaf_forbidden_hits = collect_forbidden_pattern_hits(intrinsics_raw_leaf_text, RAW_LEAF_FORBIDDEN_PATTERNS)
    for hit in raw_leaf_forbidden_hits:
        failures.append(f'{intrinsics_raw_leaf_path.name} leaked forbidden higher-level dependency: {hit}')

    constref_aligned_load_violations = collect_constref_aligned_load_violations(intrinsics_raw_leaf_text)
    for violation in constref_aligned_load_violations:
        failures.append(
            f'{intrinsics_raw_leaf_path.name} must not use aligned source loads for constref TM128 parameters: {violation}'
        )

    forbidden_raw_float_opcode_hits = collect_forbidden_raw_float_opcode_hits(intrinsics_raw_leaf_text)
    for hit in forbidden_raw_float_opcode_hits:
        failures.append(
            f'{intrinsics_raw_leaf_path.name} must keep special-value helper wrappers instead of raw float opcodes: {hit}'
        )

    missing_required_side_effect_opcodes = collect_missing_required_side_effect_opcodes(intrinsics_raw_leaf_text)
    for hit in missing_required_side_effect_opcodes:
        failures.append(
            f'{intrinsics_raw_leaf_path.name} must preserve required side-effect opcodes for cache-control/fence helpers: {hit}'
        )

    backend_truth_doc_exists = backend_truth_doc_path.exists()
    backend_truth_text = backend_truth_doc_path.read_text(encoding='utf-8', errors='replace') if backend_truth_doc_exists else ''
    intrinsics_disposition_doc_exists = intrinsics_disposition_doc_path.exists()
    intrinsics_disposition_text = (
        intrinsics_disposition_doc_path.read_text(encoding='utf-8', errors='replace')
        if intrinsics_disposition_doc_exists
        else ''
    )
    migration_map_doc_exists = migration_map_doc_path.exists()
    migration_map_text = migration_map_doc_path.read_text(encoding='utf-8', errors='replace') if migration_map_doc_exists else ''

    if not backend_truth_doc_exists:
        failures.append(f'missing truth doc: {backend_truth_doc_path.name}')
    if not intrinsics_disposition_doc_exists:
        failures.append(f'missing truth doc: {intrinsics_disposition_doc_path.name}')
    if not migration_map_doc_exists:
        failures.append(f'missing truth doc: {migration_map_doc_path.name}')

    backend_truth_rows = extract_backend_truth(backend_truth_text) if backend_truth_doc_exists else {}
    intrinsics_disposition_rows = (
        extract_intrinsics_disposition(intrinsics_disposition_text)
        if intrinsics_disposition_doc_exists
        else {}
    )

    if backend_truth_rows:
        if set(backend_truth_rows) != set(EXPECTED_BACKEND_TRUTH):
            failures.append(
                'SIMD_BACKEND_TRUTH.md backend rows drifted from expected mainline set: '
                f'missing={sorted(set(EXPECTED_BACKEND_TRUTH) - set(backend_truth_rows))}, '
                f'extra={sorted(set(backend_truth_rows) - set(EXPECTED_BACKEND_TRUTH))}'
            )
        for backend_name, expected_row in EXPECTED_BACKEND_TRUTH.items():
            actual_row = backend_truth_rows.get(backend_name)
            if actual_row is None:
                continue
            if actual_row != expected_row:
                failures.append(
                    f'SIMD_BACKEND_TRUTH.md row mismatch for {backend_name}: '
                    f'expected={expected_row}, actual={actual_row}'
                )
            expected_path = root / actual_row[1]
            if not expected_path.exists():
                failures.append(f'SIMD_BACKEND_TRUTH.md points to missing file for {backend_name}: {actual_row[1]}')

    repo_intrinsics_units = collect_repo_intrinsics_units(src_dir)
    invalid_intrinsics_status_rows: list[str] = []
    for unit_name, status in intrinsics_disposition_rows.items():
        if status not in ALLOWED_INTRINSICS_STATUS:
            invalid_intrinsics_status_rows.append(f'{unit_name}={status}')
    if invalid_intrinsics_status_rows:
        failures.append(
            'SIMD_INTRINSICS_DISPOSITION.md contains invalid status rows: '
            + ', '.join(sorted(invalid_intrinsics_status_rows))
        )

    if intrinsics_disposition_rows:
        # Allow retire-target units to not have corresponding files
        active_disposition_units = {u for u, s in intrinsics_disposition_rows.items() if s != 'retire target'}
        if active_disposition_units != set(repo_intrinsics_units):
            failures.append(
                'SIMD_INTRINSICS_DISPOSITION.md unit rows drifted from repo units: '
                f'missing={sorted(set(repo_intrinsics_units) - active_disposition_units)}, '
                f'extra={sorted(active_disposition_units - set(repo_intrinsics_units))}'
            )
        for unit_name, expected_status in EXPECTED_INTRINSICS_DISPOSITION.items():
            actual_status = intrinsics_disposition_rows.get(unit_name)
            if actual_status is None:
                continue
            if actual_status != expected_status:
                failures.append(
                    f'SIMD_INTRINSICS_DISPOSITION.md row mismatch for {unit_name}: '
                    f'expected={expected_status}, actual={actual_status}'
                )

    migration_missing_sections: list[str] = []
    migration_missing_tokens: list[str] = []
    if migration_map_doc_exists:
        for section in MIGRATION_DOC_REQUIRED_SECTIONS:
            if section not in migration_map_text:
                migration_missing_sections.append(section)
        for token in MIGRATION_DOC_REQUIRED_TOKENS:
            if token not in migration_map_text:
                migration_missing_tokens.append(token)
        if migration_missing_sections:
            failures.append(
                f'{migration_map_doc_path.name} missing required sections: {migration_missing_sections}'
            )
        if migration_missing_tokens:
            failures.append(
                f'{migration_map_doc_path.name} missing required sentinel tokens: {migration_missing_tokens}'
            )

    payload = {
        'root_unit': root_unit_path.name,
        'register_include': register_inc_path.name,
        'wide_include': wide_inc_path.name,
        'select_include': select_inc_path.name,
        'register_include_exists': register_exists,
        'root_include_count': root_include_count,
        'root_wide_include_count': root_wide_include_count,
        'root_select_include_count': root_select_include_count,
        'root_register_header_count': root_register_header_count,
        'register_header_count': register_header_count,
        'select_include_exists': select_exists,
        'wide_self_include_count': wide_self_include_count,
        'duplicate_leaf_names': duplicate_leaf_names,
        'duplicate_leaf_records': duplicate_leaf_records,
        'root_symbol_counts': root_symbol_counts,
        'wide_symbol_counts': wide_symbol_counts,
        'select_symbol_counts': select_symbol_counts,
        'wide_section_counts': wide_section_counts,
        'root_uses_hits': root_uses_hits,
        'raw_leaf_forbidden_hits': raw_leaf_forbidden_hits,
        'constref_aligned_load_violations': constref_aligned_load_violations,
        'forbidden_raw_float_opcode_hits': forbidden_raw_float_opcode_hits,
        'missing_required_side_effect_opcodes': missing_required_side_effect_opcodes,
        'backend_truth_doc_exists': backend_truth_doc_exists,
        'backend_truth_rows_count': len(backend_truth_rows),
        'intrinsics_disposition_doc_exists': intrinsics_disposition_doc_exists,
        'intrinsics_disposition_rows_count': len(intrinsics_disposition_rows),
        'repo_intrinsics_units_count': len(repo_intrinsics_units),
        'migration_map_doc_exists': migration_map_doc_exists,
        'migration_missing_sections': migration_missing_sections,
        'migration_missing_tokens': migration_missing_tokens,
        'failure_count': len(failures),
        'failures': failures,
        'status': 'ok' if not failures else 'fail',
    }

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0 if not failures else 1

    print('[SSE2-STRUCTURE] SSE2 register/include structural contract')
    print(f'  - register_include_exists:        {register_exists}')
    print(f'  - root_include_count:             {root_include_count}')
    print(f'  - root_wide_include_count:        {root_wide_include_count}')
    print(f'  - root_select_include_count:      {root_select_include_count}')
    print(f'  - root_header_count:              {root_register_header_count}')
    print(f'  - register_header_count:          {register_header_count}')
    print(f'  - select_include_exists:          {select_exists}')
    print(f'  - wide_self_include_count:        {wide_self_include_count}')
    print(f'  - duplicate_leaf_names:           {len(duplicate_leaf_names)}')
    print(f'  - root_uses_hits:                 {len(root_uses_hits)}')
    print(f'  - raw_leaf_forbidden_hits:        {len(raw_leaf_forbidden_hits)}')
    print(f'  - constref_aligned_load_violations:{len(constref_aligned_load_violations)}')
    print(f'  - forbidden_raw_float_opcode_hits:{len(forbidden_raw_float_opcode_hits)}')
    print(f'  - missing_required_side_effect_opcodes:{len(missing_required_side_effect_opcodes)}')
    print(f'  - backend_truth_rows_count:       {len(backend_truth_rows)}')
    print(f'  - intrinsics_disposition_rows:    {len(intrinsics_disposition_rows)}')
    print(f'  - repo_intrinsics_units_count:    {len(repo_intrinsics_units)}')
    print(f'  - migration_missing_sections:     {len(migration_missing_sections)}')
    print(f'  - migration_missing_tokens:       {len(migration_missing_tokens)}')
    if duplicate_leaf_records:
        print('  - duplicate_leaf_details:')
        for record in duplicate_leaf_records:
            print(f"    - {record['include']}: lines={record['lines']}")
    if root_symbol_counts:
        print('  - root_symbol_counts:')
        for symbol_name in sorted(root_symbol_counts):
            print(f'    - {symbol_name}: {root_symbol_counts[symbol_name]}')
    if wide_symbol_counts:
        print('  - wide_symbol_counts:')
        for symbol_name in sorted(wide_symbol_counts):
            print(f'    - {symbol_name}: {wide_symbol_counts[symbol_name]}')
    if select_symbol_counts:
        print('  - select_symbol_counts:')
        for symbol_name in sorted(select_symbol_counts):
            print(f'    - {symbol_name}: {select_symbol_counts[symbol_name]}')
    if wide_section_counts:
        print('  - wide_section_counts:')
        for marker, count in sorted(wide_section_counts.items()):
            print(f'    - {marker}: {count}')
    if failures:
        print('  - failures:')
        for item in failures:
            print(f'    - {item}')
    if args.summary_line:
        print(
            'SSE2_STRUCTURE_SUMMARY '
            f'register_include_exists={int(register_exists)} '
            f'root_include_count={root_include_count} '
            f'root_wide_include_count={root_wide_include_count} '
            f'root_select_include_count={root_select_include_count} '
            f'root_header_count={root_register_header_count} '
            f'register_header_count={register_header_count} '
            f'select_include_exists={int(select_exists)} '
            f'wide_self_include_count={wide_self_include_count} '
            f'duplicate_leaf_names={len(duplicate_leaf_names)} '
            f'root_uses_hits={len(root_uses_hits)} '
            f'raw_leaf_forbidden_hits={len(raw_leaf_forbidden_hits)} '
            f'constref_aligned_load_violations={len(constref_aligned_load_violations)} '
            f'forbidden_raw_float_opcode_hits={len(forbidden_raw_float_opcode_hits)} '
            f'missing_required_side_effect_opcodes={len(missing_required_side_effect_opcodes)} '
            f'backend_truth_rows={len(backend_truth_rows)} '
            f'intrinsics_disposition_rows={len(intrinsics_disposition_rows)} '
            f'migration_missing_sections={len(migration_missing_sections)} '
            f'migration_missing_tokens={len(migration_missing_tokens)} '
            f'failure_count={len(failures)} '
            f'status={payload["status"]}'
        )
    if failures:
        return 1
    print('[SSE2-STRUCTURE] OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())

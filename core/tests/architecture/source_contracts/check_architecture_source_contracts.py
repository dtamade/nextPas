#!/usr/bin/env python3
"""Source-contract gate for core architecture governance."""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CORE_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_REGISTRY = SCRIPT_DIR / "architecture_contract_registry.json"
REQUIRED_REGISTRY_KEYS = (
    ("version", int),
    ("l0_modules", list),
    ("truth_levels", list),
    ("l0_module_contracts", list),
    ("l0_support_units", list),
    ("l0_dependency_allowlist", list),
    ("raw_ffi_tokens", list),
    ("raw_ffi_owner_allowlist", list),
    ("raw_ffi_explicit_allowlist", list),
    ("governance_docs", list),
)


class RegistryError(Exception):
    pass


@dataclass(frozen=True)
class UsesEntry:
    rel_path: str
    line: int
    unit: str


@dataclass(frozen=True)
class RawTokenEntry:
    rel_path: str
    line: int
    token: str
    source: str


@dataclass(frozen=True)
class RegistryRow:
    module: str
    layer: str
    owner: str
    facade: str
    allowed_deps: str
    truth_level: str


@dataclass(frozen=True)
class L0ModuleProfile:
    module: str
    layer: str
    owner: str
    facade_path: str
    doc_path: str
    allowed_dependency_policy: str
    boundary_truth: str
    runtime_truth: str


def read_text(a_path: Path) -> str:
    return a_path.read_text(encoding="utf-8", errors="ignore")


def normalize_rel_path(a_path: Path, a_source_root: Path) -> str:
    return "src/" + a_path.relative_to(a_source_root).as_posix()


def normalize_unit(a_unit: str) -> str:
    return a_unit.strip().lower()


def normalize_token(a_token: str) -> str:
    return a_token.strip().lower()


def strip_pascal_comments(a_text: str, *, keep_directives: bool = False) -> str:
    l_output: list[str] = []
    l_index = 0
    while l_index < len(a_text):
        if a_text.startswith("//", l_index):
            l_newline = a_text.find("\n", l_index)
            if l_newline < 0:
                break
            l_output.append("\n")
            l_index = l_newline + 1
            continue

        if a_text.startswith("(*", l_index):
            l_end = a_text.find("*)", l_index + 2)
            l_comment = a_text[l_index:] if l_end < 0 else a_text[l_index : l_end + 2]
            l_output.append("\n" * l_comment.count("\n"))
            l_index = len(a_text) if l_end < 0 else l_end + 2
            continue

        if a_text[l_index] == "{":
            l_end = a_text.find("}", l_index + 1)
            l_comment = a_text[l_index:] if l_end < 0 else a_text[l_index : l_end + 1]
            if keep_directives and l_comment.startswith("{$"):
                l_output.append(l_comment)
            else:
                l_output.append("\n" * l_comment.count("\n"))
            l_index = len(a_text) if l_end < 0 else l_end + 1
            continue

        l_output.append(a_text[l_index])
        l_index += 1

    return "".join(l_output)


def iter_pascal_source_files(a_source_root: Path) -> Iterable[Path]:
    yield from sorted(a_source_root.glob("nextpas.core*.pas"))


def iter_uses_units(a_text: str, a_rel_path: str) -> Iterable[UsesEntry]:
    l_in_uses = False
    for l_line_no, l_line in enumerate(a_text.splitlines(), start=1):
        l_work = l_line.strip()
        if not l_in_uses:
            if re.match(r"(?i)^uses\b", l_work) is None:
                continue
            l_in_uses = True
            l_work = re.sub(r"(?i)^uses\b", "", l_work, count=1)

        for l_part in re.split(r"[,;]", l_work):
            l_part = l_part.strip()
            if not l_part or l_part.startswith("$"):
                continue
            l_match = re.match(r"([A-Za-z_][A-Za-z0-9_.]*)", l_part)
            if l_match is not None:
                yield UsesEntry(a_rel_path, l_line_no, l_match.group(1))

        if ";" in l_work:
            l_in_uses = False


def module_from_core_unit(a_unit: str) -> str | None:
    l_unit = normalize_unit(a_unit)
    if not l_unit.startswith("nextpas.core."):
        return None
    return l_unit.removeprefix("nextpas.core.").split(".", 1)[0]


def module_from_path(a_rel_path: str) -> str | None:
    l_name = Path(a_rel_path).name.lower()
    if not l_name.startswith("nextpas.core."):
        return None
    return l_name.removeprefix("nextpas.core.").split(".", 1)[0]


def load_registry(a_path: Path) -> dict:
    if not a_path.is_file():
        raise RegistryError(f"registry not found: {a_path}")

    try:
        l_registry = json.loads(read_text(a_path))
    except json.JSONDecodeError as l_error:
        raise RegistryError(
            f"registry is not valid JSON: {a_path}:{l_error.lineno}:{l_error.colno}"
        ) from l_error

    if not isinstance(l_registry, dict):
        raise RegistryError(f"registry root must be a JSON object: {a_path}")

    for l_key, l_type in REQUIRED_REGISTRY_KEYS:
        if l_key not in l_registry:
            raise RegistryError(f"registry missing key `{l_key}`")
        if not isinstance(l_registry[l_key], l_type):
            raise RegistryError(
                f"registry key `{l_key}` must be {l_type.__name__}, "
                f"got {type(l_registry[l_key]).__name__}"
            )

    return l_registry


def collect_top_level_modules(a_source_root: Path) -> set[str]:
    l_modules: set[str] = set()
    for l_path in iter_pascal_source_files(a_source_root):
        l_stem = l_path.stem.lower()
        if l_stem == "nextpas.core" or not l_stem.startswith("nextpas.core."):
            continue
        l_modules.add(l_stem.removeprefix("nextpas.core.").split(".", 1)[0])
    return l_modules


def parse_markdown_table_rows(a_text: str, a_header_prefix: str) -> list[list[str]]:
    l_rows: list[list[str]] = []
    l_in_table = False
    for l_line in a_text.splitlines():
        if not l_in_table:
            if l_line.startswith(a_header_prefix):
                l_in_table = True
            continue

        if not l_line.startswith("|"):
            if l_rows:
                break
            continue

        l_cells = [l_cell.strip() for l_cell in l_line.strip().strip("|").split("|")]
        if not l_cells or set("".join(l_cells)) <= {"-", " "}:
            continue
        if l_cells[0].lower() == "module":
            continue
        l_rows.append(l_cells)
    return l_rows


def parse_module_registry(a_core_root: Path) -> list[RegistryRow]:
    l_path = a_core_root / "docs/core-module-registry.md"
    l_rows: list[RegistryRow] = []
    for l_cells in parse_markdown_table_rows(read_text(l_path), "| Module | Layer |"):
        if len(l_cells) != 6:
            continue
        l_module = l_cells[0].strip("` ").lower()
        l_rows.append(
            RegistryRow(
                module=l_module,
                layer=l_cells[1],
                owner=l_cells[2],
                facade=l_cells[3],
                allowed_deps=l_cells[4],
                truth_level=l_cells[5],
            )
        )
    return l_rows


def parse_l0_module_profile(a_item: dict) -> L0ModuleProfile:
    l_required = (
        "module",
        "layer",
        "owner",
        "facade_path",
        "doc_path",
        "allowed_dependency_policy",
        "boundary_truth",
        "runtime_truth",
    )
    for l_key in l_required:
        if l_key not in a_item:
            raise RegistryError(f"l0_module_contracts item missing key `{l_key}`")
        if not isinstance(a_item[l_key], str):
            raise RegistryError(f"l0_module_contracts key `{l_key}` must be string")

    return L0ModuleProfile(
        module=normalize_unit(a_item["module"]),
        layer=a_item["layer"],
        owner=a_item["owner"],
        facade_path=a_item["facade_path"],
        doc_path=a_item["doc_path"],
        allowed_dependency_policy=a_item["allowed_dependency_policy"],
        boundary_truth=a_item["boundary_truth"],
        runtime_truth=a_item["runtime_truth"],
    )


def collect_uses_entries(a_source_root: Path) -> list[UsesEntry]:
    l_entries: list[UsesEntry] = []
    for l_path in iter_pascal_source_files(a_source_root):
        l_rel_path = normalize_rel_path(l_path, a_source_root)
        l_text = strip_pascal_comments(read_text(l_path))
        l_entries.extend(iter_uses_units(l_text, l_rel_path))
    return l_entries


def collect_include_raw_tokens(
    a_path: Path,
    a_source_root: Path,
    a_tokens: set[str],
) -> list[RawTokenEntry]:
    l_rel_path = normalize_rel_path(a_path, a_source_root)
    l_entries: list[RawTokenEntry] = []
    l_text = strip_pascal_comments(read_text(a_path), keep_directives=True)
    for l_match in re.finditer(r"\{\$I\s+([^}]+)\}", l_text, flags=re.IGNORECASE):
        l_include = l_match.group(1)
        l_line = l_text.count("\n", 0, l_match.start()) + 1
        for l_token in a_tokens:
            if l_token != "ctypes":
                continue
            l_pattern = rf"(?i)(^|[^A-Za-z0-9_]){re.escape(l_token)}([^A-Za-z0-9_]|$)"
            if re.search(l_pattern, l_include):
                l_entries.append(RawTokenEntry(l_rel_path, l_line, l_token, "include"))
    return l_entries


def collect_raw_token_entries(
    a_source_root: Path,
    a_registry: dict,
) -> list[RawTokenEntry]:
    l_raw_tokens = {normalize_token(l_token) for l_token in a_registry["raw_ffi_tokens"]}
    l_entries: list[RawTokenEntry] = []
    for l_entry in collect_uses_entries(a_source_root):
        l_unit = normalize_token(l_entry.unit)
        if l_unit in l_raw_tokens:
            l_entries.append(
                RawTokenEntry(l_entry.rel_path, l_entry.line, l_unit, "uses")
            )

    for l_path in iter_pascal_source_files(a_source_root):
        l_entries.extend(collect_include_raw_tokens(l_path, a_source_root, l_raw_tokens))

    return sorted(l_entries, key=lambda a_entry: (a_entry.rel_path, a_entry.line, a_entry.token))


def registry_units(a_registry: dict, a_key: str) -> set[str]:
    return {normalize_unit(l_item["unit"]) for l_item in a_registry[a_key]}


def is_l0_dependency_allowed(a_entry: UsesEntry, a_registry: dict) -> bool:
    l_unit = normalize_unit(a_entry.unit)
    if l_unit in registry_units(a_registry, "l0_support_units"):
        return True

    for l_item in a_registry["l0_dependency_allowlist"]:
        if a_entry.rel_path == l_item["path"] and l_unit == normalize_unit(l_item["unit"]):
            return True

    return False


def check_l0_dependencies(a_source_root: Path, a_registry: dict) -> list[str]:
    l_issues: list[str] = []
    l_l0_modules = {normalize_unit(l_module) for l_module in a_registry["l0_modules"]}

    for l_entry in collect_uses_entries(a_source_root):
        l_source_module = module_from_path(l_entry.rel_path)
        if l_source_module not in l_l0_modules:
            continue

        l_target_module = module_from_core_unit(l_entry.unit)
        if l_target_module is None or l_target_module in l_l0_modules:
            continue

        if is_l0_dependency_allowed(l_entry, a_registry):
            continue

        l_issues.append(
            f"l0-dependency: {l_entry.rel_path}:{l_entry.line}: "
            f"L0 module `{l_source_module}` must not use upper module "
            f"`{l_target_module}` through `{l_entry.unit}`"
        )

    return l_issues


def raw_token_owner_allowed(a_entry: RawTokenEntry, a_registry: dict) -> bool:
    l_token = normalize_token(a_entry.token)
    for l_owner in a_registry["raw_ffi_owner_allowlist"]:
        if l_token not in {normalize_token(l_item) for l_item in l_owner["tokens"]}:
            continue
        for l_glob in l_owner["path_globs"]:
            if fnmatch.fnmatchcase(a_entry.rel_path, l_glob):
                return True
    return False


def raw_token_explicit_allowed(a_entry: RawTokenEntry, a_registry: dict) -> bool:
    l_token = normalize_token(a_entry.token)
    for l_item in a_registry["raw_ffi_explicit_allowlist"]:
        if a_entry.rel_path == l_item["path"] and l_token == normalize_token(l_item["token"]):
            return True
    return False


def check_raw_ffi_tokens(a_source_root: Path, a_registry: dict) -> list[str]:
    l_issues: list[str] = []
    for l_entry in collect_raw_token_entries(a_source_root, a_registry):
        if raw_token_owner_allowed(l_entry, a_registry):
            continue
        if raw_token_explicit_allowed(l_entry, a_registry):
            continue
        l_issues.append(
            f"raw-ffi-token: {l_entry.rel_path}:{l_entry.line}: "
            f"`{l_entry.token}` from {l_entry.source} is outside owner/allowlist"
        )
    return l_issues


def check_governance_docs(a_core_root: Path, a_registry: dict) -> list[str]:
    l_issues: list[str] = []
    for l_doc in a_registry["governance_docs"]:
        l_path = a_core_root / l_doc["path"]
        if not l_path.is_file():
            l_issues.append(f"governance-doc: missing required doc `{l_doc['path']}`")
            continue

        l_text = read_text(l_path)
        l_line_count = len(l_text.splitlines())
        if l_line_count > int(l_doc["max_lines"]):
            l_issues.append(
                f"governance-doc: {l_doc['path']} has {l_line_count} lines "
                f"over max {l_doc['max_lines']}"
            )

        for l_phrase in l_doc.get("forbidden_phrases", []):
            if l_phrase in l_text:
                l_issues.append(
                    f"governance-doc: {l_doc['path']} contains forbidden phrase `{l_phrase}`"
                )

        for l_pattern in l_doc.get("forbidden_patterns", []):
            for l_line_no, l_line in enumerate(l_text.splitlines(), start=1):
                if re.search(l_pattern, l_line):
                    l_issues.append(
                        f"governance-doc: {l_doc['path']}:{l_line_no} "
                        f"matches forbidden pattern `{l_pattern}`"
                    )

        for l_heading in l_doc.get("required_headings", []):
            if l_heading not in l_text:
                l_issues.append(
                    f"governance-doc: {l_doc['path']} is missing heading `{l_heading}`"
                )

        for l_token in l_doc.get("required_truth_tokens", []):
            if l_token not in l_text:
                l_issues.append(
                    f"governance-doc: {l_doc['path']} is missing truth token `{l_token}`"
                )

    return l_issues


def check_module_registry(
    a_core_root: Path,
    a_source_root: Path,
    a_registry: dict,
) -> list[str]:
    l_issues: list[str] = []
    l_rows = parse_module_registry(a_core_root)
    l_row_by_module = {l_row.module: l_row for l_row in l_rows}
    l_live_modules = collect_top_level_modules(a_source_root)
    l_truth_levels = set(a_registry["truth_levels"])
    l_l0_modules = {normalize_unit(l_module) for l_module in a_registry["l0_modules"]}

    for l_module in sorted(l_live_modules - set(l_row_by_module)):
        l_issues.append(f"module-registry: live module `{l_module}` is missing")

    for l_module in sorted(set(l_row_by_module) - l_live_modules):
        l_issues.append(f"module-registry: registered module `{l_module}` has no source family")

    for l_row in l_rows:
        if "," in l_row.module:
            l_issues.append(
                f"module-registry: `{l_row.module}` must be one module, not a grouped row"
            )
        if not l_row.owner or not l_row.allowed_deps:
            l_issues.append(f"module-registry: `{l_row.module}` must name owner and dependencies")
        if l_row.facade not in {"yes", "no", "mixed"}:
            l_issues.append(
                f"module-registry: `{l_row.module}` has invalid facade marker `{l_row.facade}`"
            )
        l_row_truth_tokens = {
            l_token.strip()
            for l_part in re.split(r";|\+", l_row.truth_level)
            for l_token in [l_part.strip()]
            if l_token.strip()
        }
        if not l_row_truth_tokens:
            l_issues.append(f"module-registry: `{l_row.module}` must name a truth level")
        for l_token in l_row_truth_tokens:
            if l_token not in l_truth_levels:
                l_issues.append(
                    f"module-registry: `{l_row.module}` has unknown truth level `{l_token}`"
                )

    l_profile_by_module: dict[str, L0ModuleProfile] = {}
    for l_item in a_registry["l0_module_contracts"]:
        l_profile = parse_l0_module_profile(l_item)
        if l_profile.module in l_profile_by_module:
            l_issues.append(f"module-registry-profile: duplicate L0 profile `{l_profile.module}`")
        l_profile_by_module[l_profile.module] = l_profile

    for l_module in sorted(l_l0_modules - set(l_profile_by_module)):
        l_issues.append(f"module-registry-profile: missing L0 profile `{l_module}`")

    for l_module in sorted(set(l_profile_by_module) - l_l0_modules):
        l_issues.append(f"module-registry-profile: unknown L0 profile `{l_module}`")

    for l_profile in sorted(l_profile_by_module.values(), key=lambda a_item: a_item.module):
        l_row = l_row_by_module.get(l_profile.module)
        if l_row is None:
            continue

        if not l_profile.layer.lower().startswith("l0"):
            l_issues.append(
                f"module-registry-profile: `{l_profile.module}` layer must be L0, "
                f"got `{l_profile.layer}`"
            )
        if l_row.layer != l_profile.layer:
            l_issues.append(
                f"module-registry-profile: `{l_profile.module}` layer `{l_profile.layer}` "
                f"does not match markdown `{l_row.layer}`"
            )
        if l_profile.boundary_truth != "source-contract":
            l_issues.append(
                f"module-registry-profile: `{l_profile.module}` boundary_truth must be "
                "`source-contract`"
            )
        for l_truth in (l_profile.boundary_truth, l_profile.runtime_truth):
            if l_truth not in l_truth_levels:
                l_issues.append(
                    f"module-registry-profile: `{l_profile.module}` has unknown truth `{l_truth}`"
                )
        for l_path_key, l_rel_path in (
            ("facade", l_profile.facade_path),
            ("doc", l_profile.doc_path),
        ):
            if not (a_core_root / l_rel_path).is_file():
                l_issues.append(
                    f"module-registry-profile: `{l_profile.module}` {l_path_key} path "
                    f"`{l_rel_path}` is missing"
                )
        if not l_profile.owner or not l_profile.allowed_dependency_policy:
            l_issues.append(
                f"module-registry-profile: `{l_profile.module}` must name owner and policy"
            )

    return l_issues


def render_registry_summary(a_registry: dict) -> str:
    return (
        "ARCH_SOURCE_CONTRACT_REGISTRY "
        f"l0_modules={len(a_registry['l0_modules'])} "
        f"truth_levels={len(a_registry['truth_levels'])} "
        f"l0_module_contracts={len(a_registry['l0_module_contracts'])} "
        f"l0_dependency_allowlist={len(a_registry['l0_dependency_allowlist'])} "
        f"raw_ffi_tokens={len(a_registry['raw_ffi_tokens'])} "
        f"raw_ffi_owner_allowlist={len(a_registry['raw_ffi_owner_allowlist'])} "
        f"raw_ffi_explicit_allowlist={len(a_registry['raw_ffi_explicit_allowlist'])} "
        f"governance_docs={len(a_registry['governance_docs'])}"
    )


def main() -> int:
    l_parser = argparse.ArgumentParser(
        description="Check nextpas.core architecture source contracts"
    )
    l_parser.add_argument(
        "--check",
        choices=("all", "module-registry", "dependency-boundary", "host-raw-ffi", "governance-docs"),
        default="all",
        help="subset to run",
    )
    l_parser.add_argument(
        "--core-root",
        type=Path,
        default=DEFAULT_CORE_ROOT,
        help="core project root, default: inferred from this script",
    )
    l_parser.add_argument(
        "--source-root",
        type=Path,
        default=None,
        help="Pascal source root to scan, default: <core-root>/src",
    )
    l_parser.add_argument(
        "--registry",
        type=Path,
        default=DEFAULT_REGISTRY,
        help="JSON registry/allowlist path",
    )
    l_parser.add_argument(
        "--summary-line",
        action="store_true",
        help="print registry and issue summary lines",
    )
    l_args = l_parser.parse_args()

    try:
        l_registry = load_registry(l_args.registry)
    except RegistryError as l_error:
        print(f"[ARCH-SOURCE-CONTRACT] FAIL: {l_error}", file=sys.stderr)
        return 2

    l_source_root = l_args.source_root or (l_args.core_root / "src")
    l_needs_source_root = l_args.check in (
        "all",
        "module-registry",
        "dependency-boundary",
        "host-raw-ffi",
    )
    if l_needs_source_root and not l_source_root.is_dir():
        print(f"[ARCH-SOURCE-CONTRACT] FAIL: source root not found: {l_source_root}", file=sys.stderr)
        return 2

    l_issues: list[str] = []
    try:
        if l_args.check in ("all", "module-registry"):
            l_issues.extend(check_module_registry(l_args.core_root, l_source_root, l_registry))
        if l_args.check in ("all", "dependency-boundary"):
            l_issues.extend(check_l0_dependencies(l_source_root, l_registry))
        if l_args.check in ("all", "host-raw-ffi"):
            l_issues.extend(check_raw_ffi_tokens(l_source_root, l_registry))
        if l_args.check in ("all", "governance-docs"):
            l_issues.extend(check_governance_docs(l_args.core_root, l_registry))
    except RegistryError as l_error:
        print(f"[ARCH-SOURCE-CONTRACT] FAIL: {l_error}", file=sys.stderr)
        return 2

    if l_args.summary_line:
        print(render_registry_summary(l_registry))
        print(f"ARCH_SOURCE_CONTRACT_SUMMARY check={l_args.check} issues={len(l_issues)}")

    if l_issues:
        print("[ARCH-SOURCE-CONTRACT] FAIL")
        for l_issue in l_issues:
            print(f"  - {l_issue}")
        return 1

    print("[ARCH-SOURCE-CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

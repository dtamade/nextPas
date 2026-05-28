#!/usr/bin/env python3
"""Check that public unsigned SIMD Vec functions have matching operators."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime
from pathlib import Path


IMPLEMENTATION_RE = re.compile(r"^\s*implementation\b", re.IGNORECASE | re.MULTILINE)
FUNC_RE = re.compile(
    r"^\s*function\s+"
    r"(?P<name>Vec(?P<family>U\d+x\d+)(?P<op>Add|Sub|Mul|And|Or|Xor|Not))"
    r"\s*\((?P<params>[^)]*)\)\s*:\s*(?P<ret>TVecU\d+x\d+)\s*;",
    re.IGNORECASE | re.MULTILINE,
)
OP_RE = re.compile(
    r"^\s*operator\s+(?P<symbol>\+|-|\*|and|or|xor|not)"
    r"\s*\((?P<params>[^)]*)\)\s*:\s*(?P<ret>TVecU\d+x\d+)\s*;",
    re.IGNORECASE | re.MULTILINE,
)
OP_IMPL_RE = re.compile(
    r"^\s*operator\s+(?P<symbol>\+|-|\*|and|or|xor|not)"
    r"\s*\((?P<params>[^)]*)\)\s*:\s*(?P<ret>TVecU\d+x\d+)\s*;"
    r"(?P<body>.*?^\s*end\s*;)",
    re.IGNORECASE | re.MULTILINE | re.DOTALL,
)

OP_TO_SYMBOL = {
    "Add": "+",
    "Sub": "-",
    "Mul": "*",
    "And": "and",
    "Or": "or",
    "Xor": "xor",
    "Not": "not",
}
SYMBOL_TO_OP = {a_symbol: a_name for a_name, a_symbol in OP_TO_SYMBOL.items()}


@dataclass(frozen=True)
class VecTarget:
    family: str
    op: str
    vec_function: str
    return_type: str
    sources: tuple[str, ...]

    @property
    def vec_type(self) -> str:
        return f"TVec{self.family}"

    @property
    def symbol(self) -> str:
        return OP_TO_SYMBOL[self.op]

    @property
    def arity(self) -> str:
        return "unary" if self.op == "Not" else "binary"

    @property
    def key(self) -> str:
        return f"{self.family}:{self.op}"


@dataclass
class MutableTarget:
    family: str
    op: str
    vec_function: str
    return_type: str
    sources: set[str] = field(default_factory=set)

    def freeze(self) -> VecTarget:
        return VecTarget(
            family=self.family,
            op=self.op,
            vec_function=self.vec_function,
            return_type=self.return_type,
            sources=tuple(sorted(self.sources)),
        )


@dataclass(frozen=True)
class OperatorEntry:
    symbol: str
    family: str
    op: str
    arity: str
    return_type: str
    body: str = ""

    @property
    def key(self) -> str:
        return f"{self.family}:{self.op}"


def parse_args() -> argparse.Namespace:
    l_parser = argparse.ArgumentParser(
        description=(
            "Fail when public unsigned VecU* Add/Sub/Mul/And/Or/Xor/Not "
            "functions are not matched by default nextpas.core.simd operators."
        )
    )
    l_parser.add_argument("--json", action="store_true", help="print JSON payload")
    l_parser.add_argument("--json-file", default="", help="write JSON payload")
    l_parser.add_argument(
        "--summary-line",
        action="store_true",
        help="print one-line summary for log scraping",
    )
    return l_parser.parse_args()


def mask_gap_char(a_char: str) -> str:
    if a_char in {"\n", "\r"}:
        return a_char
    return " "


def strip_pascal_non_code(a_text: str) -> str:
    l_chars = list(a_text)
    l_len = len(l_chars)
    l_idx = 0

    while l_idx < l_len:
        l_char = l_chars[l_idx]
        l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""

        if l_char == "'":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                l_chars[l_idx] = mask_gap_char(l_char)
                if l_char == "'":
                    if l_next == "'":
                        l_chars[l_idx + 1] = " "
                        l_idx += 2
                        continue
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "{" and l_next != "$":
            l_chars[l_idx] = " "
            l_idx += 1
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_chars[l_idx] = mask_gap_char(l_char)
                if l_char == "}":
                    l_idx += 1
                    break
                l_idx += 1
            continue

        if l_char == "(" and l_next == "*":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                l_next = l_chars[l_idx + 1] if l_idx + 1 < l_len else ""
                if l_char == "*" and l_next == ")":
                    l_chars[l_idx] = " "
                    l_chars[l_idx + 1] = " "
                    l_idx += 2
                    break
                l_chars[l_idx] = mask_gap_char(l_char)
                l_idx += 1
            continue

        if l_char == "/" and l_next == "/":
            l_chars[l_idx] = " "
            l_chars[l_idx + 1] = " "
            l_idx += 2
            while l_idx < l_len:
                l_char = l_chars[l_idx]
                if l_char in {"\n", "\r"}:
                    l_idx += 1
                    break
                l_chars[l_idx] = " "
                l_idx += 1
            continue

        l_idx += 1

    return "".join(l_chars)


def split_main_unit(a_text: str) -> tuple[str, str]:
    l_masked = strip_pascal_non_code(a_text)
    l_match = IMPLEMENTATION_RE.search(l_masked)
    if l_match is None:
        return l_masked, ""
    return l_masked[: l_match.start()], l_masked[l_match.end() :]


def normalize_type_name(a_name: str) -> str:
    l_name = a_name.strip()
    if l_name.lower().startswith("tvec"):
        return "TVec" + l_name[4:]
    return l_name


def parse_operator_match(a_match: re.Match[str], a_include_body: bool) -> OperatorEntry | None:
    l_symbol = a_match.group("symbol").lower()
    l_op = SYMBOL_TO_OP.get(l_symbol)
    if l_op is None:
        return None

    l_params = re.sub(r"\s+", " ", a_match.group("params").strip()).lower()
    l_ret = normalize_type_name(a_match.group("ret"))
    l_family = l_ret[4:]
    l_expected_type = f"tvec{l_family.lower()}"

    if l_op == "Not":
        l_arity = "unary"
        l_expected_params = f"const a: {l_expected_type}"
    else:
        l_arity = "binary"
        l_expected_params = f"const a, b: {l_expected_type}"

    if l_params != l_expected_params:
        return None

    return OperatorEntry(
        symbol=l_symbol,
        family=l_family,
        op=l_op,
        arity=l_arity,
        return_type=l_ret,
        body=a_match.group("body") if a_include_body and "body" in a_match.groupdict() else "",
    )


def collect_vec_targets(a_repo_root: Path) -> tuple[dict[str, VecTarget], set[str], set[str]]:
    l_sources = [
        a_repo_root / "src" / "nextpas.core.simd.pas",
        a_repo_root / "src" / "generated" / "nextpas.core.simd.facade.decl.inc",
    ]
    l_targets: dict[str, MutableTarget] = {}
    l_main_public_funcs: set[str] = set()
    l_main_impl_funcs: set[str] = set()

    l_main_path = a_repo_root / "src" / "nextpas.core.simd.pas"
    l_interface, l_implementation = split_main_unit(l_main_path.read_text(encoding="utf-8", errors="ignore"))

    for l_match in FUNC_RE.finditer(l_interface):
        l_main_public_funcs.add(l_match.group("name"))
    for l_match in FUNC_RE.finditer(l_implementation):
        l_main_impl_funcs.add(l_match.group("name"))

    for l_path in l_sources:
        if not l_path.is_file():
            continue
        if l_path == l_main_path:
            l_text = l_interface
        else:
            l_text = strip_pascal_non_code(l_path.read_text(encoding="utf-8", errors="ignore"))
        l_rel = str(l_path.relative_to(a_repo_root)).replace("\\", "/")
        for l_match in FUNC_RE.finditer(l_text):
            l_family = l_match.group("family")
            l_op = l_match.group("op")
            l_vec_function = l_match.group("name")
            l_return_type = normalize_type_name(l_match.group("ret"))
            l_key = f"{l_family}:{l_op}"
            l_target = l_targets.get(l_key)
            if l_target is None:
                l_target = MutableTarget(
                    family=l_family,
                    op=l_op,
                    vec_function=l_vec_function,
                    return_type=l_return_type,
                )
                l_targets[l_key] = l_target
            l_target.sources.add(l_rel)

    return {l_key: l_target.freeze() for l_key, l_target in l_targets.items()}, l_main_public_funcs, l_main_impl_funcs


def collect_operators(a_repo_root: Path) -> tuple[dict[str, OperatorEntry], dict[str, OperatorEntry]]:
    l_main_path = a_repo_root / "src" / "nextpas.core.simd.pas"
    l_interface, l_implementation = split_main_unit(l_main_path.read_text(encoding="utf-8", errors="ignore"))
    l_decl_entries: dict[str, OperatorEntry] = {}
    l_impl_entries: dict[str, OperatorEntry] = {}

    for l_match in OP_RE.finditer(l_interface):
        l_entry = parse_operator_match(l_match, a_include_body=False)
        if l_entry is not None:
            l_decl_entries[l_entry.key] = l_entry

    for l_match in OP_IMPL_RE.finditer(l_implementation):
        l_entry = parse_operator_match(l_match, a_include_body=True)
        if l_entry is not None:
            l_impl_entries[l_entry.key] = l_entry

    return l_decl_entries, l_impl_entries


def main() -> int:
    l_args = parse_args()
    l_repo_root = Path(__file__).resolve().parents[2]

    l_targets, l_main_public_funcs, l_main_impl_funcs = collect_vec_targets(l_repo_root)
    l_decl_ops, l_impl_ops = collect_operators(l_repo_root)

    l_missing_public_functions: list[dict[str, str]] = []
    l_missing_vec_implementations: list[dict[str, str]] = []
    l_missing_operator_declarations: list[dict[str, str]] = []
    l_missing_operator_implementations: list[dict[str, str]] = []
    l_bad_operator_bodies: list[dict[str, str]] = []
    l_extra_unsigned_operators: list[dict[str, str]] = []

    for l_key, l_target in sorted(l_targets.items()):
        l_item = asdict(l_target)
        if l_target.vec_function not in l_main_public_funcs:
            l_missing_public_functions.append(l_item)
        if l_target.vec_function not in l_main_impl_funcs:
            l_missing_vec_implementations.append(l_item)
        if l_key not in l_decl_ops:
            l_missing_operator_declarations.append(l_item)
        if l_key not in l_impl_ops:
            l_missing_operator_implementations.append(l_item)
            continue
        if l_target.vec_function not in l_impl_ops[l_key].body:
            l_bad_operator_bodies.append(
                {
                    **l_item,
                    "expected_body_reference": l_target.vec_function,
                }
            )

    for l_key, l_entry in sorted(l_decl_ops.items()):
        if l_key not in l_targets:
            l_extra_unsigned_operators.append(asdict(l_entry))

    l_status_ok = not any(
        (
            l_missing_public_functions,
            l_missing_vec_implementations,
            l_missing_operator_declarations,
            l_missing_operator_implementations,
            l_bad_operator_bodies,
            l_extra_unsigned_operators,
        )
    )

    l_generated_backed = sum(
        1
        for l_target in l_targets.values()
        if "src/generated/nextpas.core.simd.facade.decl.inc" in l_target.sources
    )
    l_payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "analyzer": "public VecU function declarations + generated facade declarations + operator source scan",
        "targets": len(l_targets),
        "generated_backed_targets": l_generated_backed,
        "operator_declarations": len(l_decl_ops),
        "operator_implementations": len(l_impl_ops),
        "missing_public_functions": l_missing_public_functions,
        "missing_vec_implementations": l_missing_vec_implementations,
        "missing_operator_declarations": l_missing_operator_declarations,
        "missing_operator_implementations": l_missing_operator_implementations,
        "bad_operator_bodies": l_bad_operator_bodies,
        "extra_unsigned_operators": l_extra_unsigned_operators,
        "status": "ok" if l_status_ok else "fail",
    }

    if l_args.json_file:
        Path(l_args.json_file).write_text(
            json.dumps(l_payload, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    if l_args.json:
        print(json.dumps(l_payload, ensure_ascii=False, indent=2))
    else:
        print("[PUBLIC-OPERATOR-SURFACE] simd public unsigned operator surface")
        print(f"  - targets:                  {l_payload['targets']}")
        print(f"  - generated_backed_targets: {l_payload['generated_backed_targets']}")
        print(f"  - operator_declarations:    {l_payload['operator_declarations']}")
        print(f"  - operator_implementations: {l_payload['operator_implementations']}")
        print(f"  - missing_public_functions: {len(l_missing_public_functions)}")
        print(f"  - missing_vec_impls:        {len(l_missing_vec_implementations)}")
        print(f"  - missing_operator_decls:   {len(l_missing_operator_declarations)}")
        print(f"  - missing_operator_impls:   {len(l_missing_operator_implementations)}")
        print(f"  - bad_operator_bodies:      {len(l_bad_operator_bodies)}")
        print(f"  - extra_unsigned_operators: {len(l_extra_unsigned_operators)}")

        for l_label, l_items in (
            ("missing operator declarations", l_missing_operator_declarations),
            ("missing operator implementations", l_missing_operator_implementations),
            ("bad operator bodies", l_bad_operator_bodies),
            ("missing public Vec functions", l_missing_public_functions),
            ("missing Vec implementations", l_missing_vec_implementations),
            ("extra unsigned operators", l_extra_unsigned_operators),
        ):
            if not l_items:
                continue
            print(f"  - {l_label}:")
            for l_item in l_items[:20]:
                if "vec_function" in l_item:
                    print(f"    * {l_item['vec_function']} -> operator {OP_TO_SYMBOL[l_item['op']]}")
                else:
                    print(f"    * {l_item['family']}:{l_item['op']}")

        if l_status_ok:
            print("[PUBLIC-OPERATOR-SURFACE] OK")
        else:
            print("[PUBLIC-OPERATOR-SURFACE] FAIL")

    if l_args.summary_line:
        print(
            "PUBLIC_OPERATOR_SURFACE_SUMMARY "
            f"targets={l_payload['targets']} "
            f"generated_backed={l_payload['generated_backed_targets']} "
            f"decls={l_payload['operator_declarations']} "
            f"impls={l_payload['operator_implementations']} "
            f"missing_public={len(l_missing_public_functions)} "
            f"missing_vec_impl={len(l_missing_vec_implementations)} "
            f"missing_decl={len(l_missing_operator_declarations)} "
            f"missing_impl={len(l_missing_operator_implementations)} "
            f"bad_body={len(l_bad_operator_bodies)} "
            f"extra={len(l_extra_unsigned_operators)} "
            f"status={l_payload['status']}"
        )

    return 0 if l_status_ok else 1


if __name__ == "__main__":
    sys.exit(main())

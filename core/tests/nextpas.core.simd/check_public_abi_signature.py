#!/usr/bin/env python3
"""Check the SIMD public ABI wrapper contract signature/layout."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path


INCLUDE_RE = re.compile(r"\{\$I\s+([^}]+)\}", re.IGNORECASE)
RECORD_START_RE = re.compile(
    r"^\s*(T[A-Za-z0-9_]+)\s*=\s*((?:packed\s+)?record)\b", re.IGNORECASE
)

EXPECTED_SECTION_SIGNATURES: dict[str, str] = {
    "simd_backend_enum": "56fba1c6fcf6dfd04a2bf96ad7440055375242a72361c5157deead2bbe7fd1fc",
    "simd_capability_enum": "0d5c0668547e51e0ee31cb419ef410617c0c03e8201e197d1770bd3fbc1c2468",
    "abi_type_alias": "0954da98b066677ae731883e21183f54a3787a01726ae3f6c1205b384c15506f",
    "abi_flag_consts": "50e4c58d110b769e4f49e175705e922092417fc670ecd51b617fe1f4bb34f3c4",
    "backend_pod_record": "c2591834ea165678913c891126089fb55a95d2a2002f5e22f2cfa86d0b920ac1",
    "public_func_types": "3d1ebd89a9488c01f49e140f98230740b867cf11320296386ed649058b90e5af",
    "public_api_record": "95bb6e6554525d5be364351966910a958af38a9c4e22434cadec3558aefd0dd9",
    "public_api_v2_flag_type_alias": "b1a21c60e32e293fb118b2ba87fdb08933a0337c757d0fd4a5c13863ed2c1b41",
    "public_api_v2_flag_consts": "ae05120eb66065d407de9654de87348ea164299e23e843f1c15b5ab06235f2ad",
    "public_api_v2_record": "a73bf14e29b15517cc69ec3cdd9405111a312a45ed69c45becfe06f163552615",
    "pascal_api_decls": "d5c62de7df8ba47d55dd34efc080e3769bb4467a4ab5e9c4766cf9cb9ca786b1",
    "c_export_alias_decls": "fb23891b6a21f948e04c04b9db86e4449836af08ac76427cf6d0b43148d14d85",
    "abi_const_decls": "c4d81b3ce00a3b503f20fa3d552a93cb64f394421b126f9b0705f82a31c57731",
    "smoke_header_flag_alias": "5cb7d615b7070c70a4ae6e17fd2640b518fe624e7242f3c4d5397b8fb77218f9",
    "smoke_header_flag_consts": "a09957d8c74c6c52c31b2e0ec7eb95dec7ef7fd99aab044a76ebf292a53c6425",
    "smoke_header_public_api_v2_flag_alias": "c452933fd46aeb2b47d1efe910ed4c5e2ac308b6ee9246b115625cd6ee81a85f",
    "smoke_header_public_api_v2_flag_consts": "303e5be84e2efc97582cbf3abdea9a6bdfdfb7c5fa8df7a9167479591418f567",
    "smoke_header_func_types": "abf8dfea210f7c7bd9dbd7b1b031046c60f452ff6cb64351779d09dd54c65a5f",
    "smoke_header_backend_pod_struct": "0af9215d775360793a85e6f7a590ca85e16b035a3f8815175fbe34d3e73a0e8d",
    "smoke_header_public_api_struct": "8c8c9f4c24d0ae6ab0a67da1a715a332d00ccb191aa38c75f16499b575903d31",
    "smoke_header_public_api_v2_struct": "7cf4ffa2bbf810d0670730bc6465b750120f8f0c919891218b2c942291e1e6fa",
    "smoke_header_pack_directives": "8fee125e481b3ab5e61a7ab6f2b01572ebb04af8c66ebf0773c066d5d8314e26",
}
EXPECTED_OVERALL_SIGNATURE = "de9da52c4405512e8f0665e246c863b851a6fe1eb3985732c848632297efa47a"

PASCAL_ABI_FLAG_NAMES = [
    "FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU",
    "FAF_SIMD_ABI_FLAG_REGISTERED",
    "FAF_SIMD_ABI_FLAG_DISPATCHABLE",
    "FAF_SIMD_ABI_FLAG_ACTIVE",
    "FAF_SIMD_ABI_FLAG_EXPERIMENTAL",
]

PASCAL_PUBLIC_API_V2_FLAG_NAMES = [
    "FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND",
    "FAF_SIMD_PUBLIC_API_V2_FLAG_DIRECT_DATA_PLANE",
    "FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1",
]

PASCAL_FUNC_TYPE_NAMES = [
    "TFafafaSimdMemEqualFunc",
    "TFafafaSimdMemFindByteFunc",
    "TFafafaSimdMemDiffRangeFunc",
    "TFafafaSimdSumBytesFunc",
    "TFafafaSimdCountByteFunc",
    "TFafafaSimdBitsetPopCountFunc",
    "TFafafaSimdUtf8ValidateFunc",
    "TFafafaSimdAsciiIEqualFunc",
    "TFafafaSimdBytesIndexOfFunc",
    "TFafafaSimdMemCopyFunc",
    "TFafafaSimdMemSetFunc",
    "TFafafaSimdToLowerAsciiFunc",
    "TFafafaSimdToUpperAsciiFunc",
    "TFafafaSimdMemReverseFunc",
    "TFafafaSimdMinMaxBytesFunc",
]

PASCAL_API_NAMES = [
    "GetSimdAbiVersionMajor",
    "GetSimdAbiVersionMinor",
    "GetSimdAbiSignature",
    "TryGetSimdBackendPodInfo",
    "GetSimdBackendNamePtr",
    "GetSimdBackendDescriptionPtr",
    "GetSimdPublicApi",
    "GetSimdPublicApiV2",
]

PASCAL_EXPORT_ALIAS_NAMES = [
    "fafafa_simd_abi_version_major",
    "fafafa_simd_abi_version_minor",
    "fafafa_simd_abi_signature",
    "fafafa_simd_get_backend_pod_info",
    "fafafa_simd_backend_name",
    "fafafa_simd_backend_description",
    "fafafa_simd_get_public_api",
    "fafafa_simd_get_public_api_v2",
]

PASCAL_ABI_CONST_NAMES = [
    "FAFAFA_SIMD_PUBLIC_ABI_VERSION_MAJOR",
    "FAFAFA_SIMD_PUBLIC_ABI_VERSION_MINOR",
    "FAFAFA_SIMD_PUBLIC_ABI_SIGNATURE_HI",
    "FAFAFA_SIMD_PUBLIC_ABI_SIGNATURE_LO",
    "FAFAFA_SIMD_PUBLIC_ABI_V2_VERSION_MAJOR",
    "FAFAFA_SIMD_PUBLIC_ABI_V2_VERSION_MINOR",
    "FAFAFA_SIMD_PUBLIC_ABI_V2_SIGNATURE_HI",
    "FAFAFA_SIMD_PUBLIC_ABI_V2_SIGNATURE_LO",
]

C_HEADER_FLAG_CONST_NAMES = [
    "FAF_SIMD_ABI_FLAG_SUPPORTED_ON_CPU",
    "FAF_SIMD_ABI_FLAG_REGISTERED",
    "FAF_SIMD_ABI_FLAG_DISPATCHABLE",
    "FAF_SIMD_ABI_FLAG_ACTIVE",
    "FAF_SIMD_ABI_FLAG_EXPERIMENTAL",
]

C_HEADER_PUBLIC_API_V2_FLAG_CONST_NAMES = [
    "FAF_SIMD_PUBLIC_API_V2_FLAG_SNAPSHOT_BOUND",
    "FAF_SIMD_PUBLIC_API_V2_FLAG_DIRECT_DATA_PLANE",
    "FAF_SIMD_PUBLIC_API_V2_FLAG_COMPAT_V1",
]

C_HEADER_FUNC_TYPE_NAMES = [
    "fafafa_simd_mem_equal_fn",
    "fafafa_simd_mem_find_byte_fn",
    "fafafa_simd_mem_diff_range_fn",
    "fafafa_simd_sum_bytes_fn",
    "fafafa_simd_count_byte_fn",
    "fafafa_simd_bitset_popcount_fn",
    "fafafa_simd_utf8_validate_fn",
    "fafafa_simd_ascii_iequal_fn",
    "fafafa_simd_bytes_index_of_fn",
    "fafafa_simd_mem_copy_fn",
    "fafafa_simd_mem_set_fn",
    "fafafa_simd_to_lower_ascii_fn",
    "fafafa_simd_to_upper_ascii_fn",
    "fafafa_simd_mem_reverse_fn",
    "fafafa_simd_min_max_bytes_fn",
]


@dataclass(frozen=True)
class PublicAbiSnapshot:
    generated_at: str
    sections: dict[str, list[str]]
    signatures: dict[str, str]
    overall_signature: str
    matches_expected: dict[str, bool]
    overall_matches_expected: bool


def read_text_with_local_includes(path: Path, seen: set[Path] | None = None) -> str:
    if seen is None:
        seen = set()

    path = path.resolve()
    if path in seen:
        return ""
    seen.add(path)

    text = path.read_text(encoding="utf-8", errors="ignore")

    def repl(match: re.Match[str]) -> str:
        include_name = match.group(1).strip().strip("'\"")
        include_path = (path.parent / include_name).resolve()
        if not include_path.exists():
            return match.group(0)
        return read_text_with_local_includes(include_path, seen)

    return INCLUDE_RE.sub(repl, text)


def strip_line_comment(line: str, marker: str) -> str:
    if marker not in line:
        return line
    return line.split(marker, 1)[0]


def normalize_pascal_line(line: str) -> str:
    line = strip_line_comment(line, "//").strip()
    if not line:
        return ""
    return " ".join(line.split())


def normalize_c_line(line: str) -> str:
    line = strip_line_comment(line, "//").strip()
    if not line:
        return ""
    return " ".join(line.split())


def extract_pascal_enum_items(text: str, type_name: str) -> list[str]:
    lines = text.splitlines()
    start_pattern = re.compile(rf"^\s*{re.escape(type_name)}\s*=\s*\(\s*$", re.IGNORECASE)
    end_pattern = re.compile(r"^\s*\);\s*$")

    in_enum = False
    items: list[str] = []

    for line in lines:
        if not in_enum:
            if start_pattern.match(line):
                in_enum = True
            continue

        if end_pattern.match(line):
            if not items:
                raise RuntimeError(f"enum empty: {type_name}")
            return items

        stripped = strip_line_comment(line, "//").strip()
        if not stripped:
            continue

        for raw_item in stripped.split(","):
            normalized = normalize_pascal_line(raw_item)
            if normalized:
                items.append(normalized)

    raise RuntimeError(f"enum not found or unterminated: {type_name}")


def extract_pascal_record_signature_lines(text: str, record_name: str) -> list[str]:
    lines = text.splitlines()
    in_record = False
    signature_lines: list[str] = []

    for line in lines:
        if not in_record:
            match = RECORD_START_RE.match(line)
            if match and match.group(1).lower() == record_name.lower():
                in_record = True
                signature_lines.append(normalize_pascal_line(line))
            continue

        normalized = normalize_pascal_line(line)
        if not normalized:
            continue
        signature_lines.append(normalized)
        if re.match(r"^end;\s*$", normalized, re.IGNORECASE):
            return signature_lines

    raise RuntimeError(f"record not found or unterminated: {record_name}")


def extract_pascal_named_lines(text: str, names: list[str], kind_pattern: str) -> list[str]:
    lines = [normalize_pascal_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]
    result: list[str] = []

    for name in names:
        pattern = re.compile(rf"^{kind_pattern}\s+{re.escape(name)}\b", re.IGNORECASE)
        for line in lines:
            if pattern.match(line):
                result.append(line)
                break
        else:
            raise RuntimeError(f"declaration not found: {name}")

    return result


def extract_pascal_type_decl_lines(text: str, names: list[str]) -> list[str]:
    lines = [normalize_pascal_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]
    result: list[str] = []

    for name in names:
        pattern = re.compile(rf"^{re.escape(name)}\s*=", re.IGNORECASE)
        for line in lines:
            if pattern.match(line):
                result.append(line)
                break
        else:
            raise RuntimeError(f"type declaration not found: {name}")

    return result


def extract_pascal_const_lines(text: str, names: list[str]) -> list[str]:
    lines = [normalize_pascal_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]
    result: list[str] = []

    for name in names:
        pattern = re.compile(rf"^{re.escape(name)}\b", re.IGNORECASE)
        for line in lines:
            if pattern.match(line):
                result.append(line)
                break
        else:
            raise RuntimeError(f"const not found: {name}")

    return result


def extract_c_struct_signature_lines(text: str, struct_name: str) -> list[str]:
    lines = text.splitlines()
    in_struct = False
    signature_lines: list[str] = []

    start_pattern = re.compile(rf"^\s*typedef\s+struct\s+{re.escape(struct_name)}\s*\{{\s*$")
    end_pattern = re.compile(rf"^\s*\}}\s*{re.escape(struct_name)}\s*;\s*$")

    for line in lines:
        if not in_struct:
            if start_pattern.match(line):
                in_struct = True
                signature_lines.append(normalize_c_line(line))
            continue

        normalized = normalize_c_line(line)
        if not normalized:
            continue
        signature_lines.append(normalized)
        if end_pattern.match(line):
            return signature_lines

    raise RuntimeError(f"c struct not found or unterminated: {struct_name}")


def extract_c_named_lines(text: str, names: list[str], prefix_pattern: str) -> list[str]:
    lines = [normalize_c_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]
    result: list[str] = []

    for name in names:
        pattern = re.compile(rf"^{prefix_pattern}{re.escape(name)}\b")
        for line in lines:
            if pattern.match(line):
                result.append(line)
                break
        else:
            raise RuntimeError(f"c declaration not found: {name}")

    return result


def extract_c_exact_lines(text: str, exact_lines: list[str]) -> list[str]:
    lines = [normalize_c_line(line) for line in text.splitlines()]
    lines = [line for line in lines if line]
    result: list[str] = []

    for exact_line in exact_lines:
        normalized = normalize_c_line(exact_line)
        for line in lines:
            if line == normalized:
                result.append(line)
                break
        else:
            raise RuntimeError(f"c exact line not found: {exact_line}")

    return result


def compute_signature(lines: list[str]) -> str:
    payload = "\n".join(lines).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def build_sections(base_text: str, intf_text: str, impl_text: str, header_text: str) -> dict[str, list[str]]:
    sections: dict[str, list[str]] = {}

    sections["simd_backend_enum"] = extract_pascal_enum_items(base_text, "TSimdBackend")
    sections["simd_capability_enum"] = extract_pascal_enum_items(base_text, "TSimdCapability")
    sections["abi_type_alias"] = extract_pascal_type_decl_lines(intf_text, ["TFafafaSimdAbiFlags"])
    sections["public_api_v2_flag_type_alias"] = extract_pascal_type_decl_lines(
        intf_text, ["TFafafaSimdPublicApiV2Flags"]
    )
    sections["abi_flag_consts"] = extract_pascal_const_lines(intf_text, PASCAL_ABI_FLAG_NAMES)
    sections["public_api_v2_flag_consts"] = extract_pascal_const_lines(
        intf_text, PASCAL_PUBLIC_API_V2_FLAG_NAMES
    )
    sections["backend_pod_record"] = extract_pascal_record_signature_lines(intf_text, "TFafafaSimdBackendPodInfo")
    sections["public_func_types"] = extract_pascal_type_decl_lines(intf_text, PASCAL_FUNC_TYPE_NAMES)
    sections["public_api_record"] = extract_pascal_record_signature_lines(intf_text, "TFafafaSimdPublicApi")
    sections["public_api_v2_record"] = extract_pascal_record_signature_lines(intf_text, "TFafafaSimdPublicApiV2")
    sections["pascal_api_decls"] = extract_pascal_named_lines(intf_text, PASCAL_API_NAMES, r"(?:function|procedure)")
    sections["c_export_alias_decls"] = extract_pascal_named_lines(intf_text, PASCAL_EXPORT_ALIAS_NAMES, r"(?:function|procedure)")
    sections["abi_const_decls"] = extract_pascal_const_lines(impl_text, PASCAL_ABI_CONST_NAMES)
    sections["smoke_header_flag_alias"] = extract_c_named_lines(
        header_text, ["fafafa_simd_abi_flags_t"], r"typedef\s+[A-Za-z0-9_]+\s+"
    )
    sections["smoke_header_public_api_v2_flag_alias"] = extract_c_named_lines(
        header_text, ["fafafa_simd_public_api_v2_flags_t"], r"typedef\s+[A-Za-z0-9_]+\s+"
    )
    sections["smoke_header_flag_consts"] = extract_c_named_lines(
        header_text, C_HEADER_FLAG_CONST_NAMES, r""
    )
    sections["smoke_header_public_api_v2_flag_consts"] = extract_c_named_lines(
        header_text, C_HEADER_PUBLIC_API_V2_FLAG_CONST_NAMES, r""
    )
    sections["smoke_header_func_types"] = extract_c_named_lines(
        header_text, C_HEADER_FUNC_TYPE_NAMES, r"typedef\s+.*\(\*"
    )
    sections["smoke_header_backend_pod_struct"] = extract_c_struct_signature_lines(
        header_text, "fafafa_simd_backend_pod_info_t"
    )
    sections["smoke_header_public_api_struct"] = extract_c_struct_signature_lines(
        header_text, "fafafa_simd_public_api_t"
    )
    sections["smoke_header_public_api_v2_struct"] = extract_c_struct_signature_lines(
        header_text, "fafafa_simd_public_api_v2_t"
    )
    sections["smoke_header_pack_directives"] = extract_c_exact_lines(
        header_text,
        ["#pragma pack(push, 1)", "#pragma pack(pop)"],
    )

    return sections


def build_snapshot(base_file: Path, intf_file: Path, impl_file: Path, header_file: Path) -> PublicAbiSnapshot:
    base_text = read_text_with_local_includes(base_file)
    intf_text = read_text_with_local_includes(intf_file)
    impl_text = read_text_with_local_includes(impl_file)
    header_text = header_file.read_text(encoding="utf-8", errors="ignore")

    sections = build_sections(base_text, intf_text, impl_text, header_text)
    signatures = {name: compute_signature(lines) for name, lines in sections.items()}
    overall_lines = [f"{name}:{signatures[name]}" for name in sorted(signatures)]
    overall_signature = compute_signature(overall_lines)
    matches_expected = {
        name: (EXPECTED_SECTION_SIGNATURES.get(name) == signature)
        for name, signature in signatures.items()
    }

    return PublicAbiSnapshot(
        generated_at=datetime.now().isoformat(timespec="seconds"),
        sections=sections,
        signatures=signatures,
        overall_signature=overall_signature,
        matches_expected=matches_expected,
        overall_matches_expected=(overall_signature == EXPECTED_OVERALL_SIGNATURE),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Check SIMD public ABI wrapper signature/layout")
    parser.add_argument("--base-file", default="src/nextpas.core.simd.base.pas")
    parser.add_argument("--public-intf-file", default="src/nextpas.core.simd.public_abi.intf.inc")
    parser.add_argument("--public-impl-file", default="src/nextpas.core.simd.public_abi.impl.inc")
    parser.add_argument("--smoke-header-file", default="tests/nextpas.core.simd.publicabi/publicabi_smoke.h")
    parser.add_argument("--json-file")
    parser.add_argument("--summary-line", action="store_true")
    parser.add_argument("--dump-current", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    base_file = (repo_root / args.base_file).resolve()
    intf_file = (repo_root / args.public_intf_file).resolve()
    impl_file = (repo_root / args.public_impl_file).resolve()
    header_file = (repo_root / args.smoke_header_file).resolve()

    for required_path in (base_file, intf_file, impl_file, header_file):
        if not required_path.exists():
            print(f"[PUBLIC-ABI] Missing required file: {required_path}")
            return 2

    snapshot = build_snapshot(base_file, intf_file, impl_file, header_file)

    if args.json_file:
        json_path = Path(args.json_file)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(asdict(snapshot), ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[PUBLIC-ABI] JSON snapshot: {json_path}")

    if args.summary_line:
        print(
            "PUBLIC_ABI_SIGNATURE "
            f"overall_sha={snapshot.overall_signature} "
            f"backend_enum_sha={snapshot.signatures['simd_backend_enum']} "
            f"public_api_sha={snapshot.signatures['public_api_record']} "
            f"header_public_api_sha={snapshot.signatures['smoke_header_public_api_struct']} "
            f"backends={len(snapshot.sections['simd_backend_enum'])} "
            f"capabilities={len(snapshot.sections['simd_capability_enum'])} "
            f"backend_pod_fields={len(snapshot.sections['backend_pod_record']) - 2} "
            f"public_api_fields={len(snapshot.sections['public_api_record']) - 2} "
            f"pascal_api={len(snapshot.sections['pascal_api_decls'])} "
            f"export_aliases={len(snapshot.sections['c_export_alias_decls'])}"
        )

    if args.dump_current:
        print("[PUBLIC-ABI] dump-current")
        for name in sorted(snapshot.signatures):
            print(f"[PUBLIC-ABI] {name}={snapshot.signatures[name]}")
        print(f"[PUBLIC-ABI] overall_signature={snapshot.overall_signature}")
        return 0

    failed = False
    for name, matched in snapshot.matches_expected.items():
        if not matched:
            print(
                "[PUBLIC-ABI] FAILED: section drift "
                f"name={name} expected={EXPECTED_SECTION_SIGNATURES.get(name)} actual={snapshot.signatures[name]}"
            )
            failed = True

    if not snapshot.overall_matches_expected:
        print(
            "[PUBLIC-ABI] FAILED: overall contract drift "
            f"(expected={EXPECTED_OVERALL_SIGNATURE}, actual={snapshot.overall_signature})"
        )
        failed = True

    if failed:
        print(
            "[PUBLIC-ABI] Hint: if this is an intentional public ABI wrapper change, "
            "update the checker baseline together with docs/STABLE/header/smoke consumers."
        )
        return 1

    print("[PUBLIC-ABI] OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

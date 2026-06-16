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
    "abi_type_alias": "c59aba2a579f26662126de6cf04cc5416e47850530ece9ed980f60170bee3719",
    "abi_flag_consts": "50e4c58d110b769e4f49e175705e922092417fc670ecd51b617fe1f4bb34f3c4",
    "backend_pod_record": "ccfb648e0b521545eee8a337824fd1e7d02f52b12a2497196e048cceb581e4b8",
    "public_func_types": "cdabb84a4ac1860b27395a1b47cc0d05a4a48956d0892ab9e488d68b77fc4bd3",
    "public_api_record": "03a92bcad7f6b6422bba3d074e6a808d5d87b9d1589a0013f25e3a4bff95cafa",
    "public_api_v2_flag_type_alias": "e7e3b165a49f78af79308577122bde3603b7ef725784d88f381ec339cdee6a5d",
    "public_api_v2_flag_consts": "ae05120eb66065d407de9654de87348ea164299e23e843f1c15b5ab06235f2ad",
    "public_api_v2_record": "166feb5b8513b34d9e0f68e25a81bba7b38c54f1f00918157080749e154f4983",
    "pascal_api_decls": "a4ef9ba77541182d41f8710f6b3fc787c790de97aa38b95c546479a19fa2d44b",
    "c_export_alias_decls": "5fcc81bcbfb225ad91bb9a5e6763cbaf168918a49f402d9a2086ad8055ac9b4f",
    "abi_const_decls": "a5bd2ca11df5f727f5572399fac72761c1e7c83c5f2ffbff7aa8107573c949eb",
    "smoke_header_flag_alias": "aa3bc7fd35d9bdcb7cf471808da815e7aa5c5b1a3794fd303f914f97e9094bed",
    "smoke_header_flag_consts": "a09957d8c74c6c52c31b2e0ec7eb95dec7ef7fd99aab044a76ebf292a53c6425",
    "smoke_header_public_api_v2_flag_alias": "61d05f3fe8c9f49d378f122ebb802804fa49afefb92ace70a2e25a4e045bc3f8",
    "smoke_header_public_api_v2_flag_consts": "303e5be84e2efc97582cbf3abdea9a6bdfdfb7c5fa8df7a9167479591418f567",
    "smoke_header_func_types": "80e1d165c79c76242a5000874022b95c232f5eff0a4a1f76422925aaec89d39c",
    "smoke_header_backend_pod_struct": "08edf6c988d4eefd471380630a56b097202b17448b2729edaaf09696f0058026",
    "smoke_header_public_api_struct": "c7fd54b8505cbbf0f11cfaa61f828f2d138eb2deb993eee6e0adfc028693d92d",
    "smoke_header_public_api_v2_struct": "781395f8d962804c98e5ec4490739aea53aef4727649be1004a5d2464f28a00b",
    "smoke_header_pack_directives": "8fee125e481b3ab5e61a7ab6f2b01572ebb04af8c66ebf0773c066d5d8314e26",
}
EXPECTED_OVERALL_SIGNATURE = "76b16c58445a06aea25b259d69b382bb79605acefbca26a33b16bdf3b9bd9c65"

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
    "TNextPasSimdMemEqualFunc",
    "TNextPasSimdMemFindByteFunc",
    "TNextPasSimdMemDiffRangeFunc",
    "TNextPasSimdSumBytesFunc",
    "TNextPasSimdCountByteFunc",
    "TNextPasSimdBitsetPopCountFunc",
    "TNextPasSimdUtf8ValidateFunc",
    "TNextPasSimdAsciiIEqualFunc",
    "TNextPasSimdBytesIndexOfFunc",
    "TNextPasSimdMemCopyFunc",
    "TNextPasSimdMemSetFunc",
    "TNextPasSimdToLowerAsciiFunc",
    "TNextPasSimdToUpperAsciiFunc",
    "TNextPasSimdMemReverseFunc",
    "TNextPasSimdMinMaxBytesFunc",
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
    "nextpas_simd_abi_version_major",
    "nextpas_simd_abi_version_minor",
    "nextpas_simd_abi_signature",
    "nextpas_simd_get_backend_pod_info",
    "nextpas_simd_backend_name",
    "nextpas_simd_backend_description",
    "nextpas_simd_get_public_api",
    "nextpas_simd_get_public_api_v2",
]

PASCAL_ABI_CONST_NAMES = [
    "NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MAJOR",
    "NEXTPAS_SIMD_PUBLIC_ABI_VERSION_MINOR",
    "NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_HI",
    "NEXTPAS_SIMD_PUBLIC_ABI_SIGNATURE_LO",
    "NEXTPAS_SIMD_PUBLIC_ABI_V2_VERSION_MAJOR",
    "NEXTPAS_SIMD_PUBLIC_ABI_V2_VERSION_MINOR",
    "NEXTPAS_SIMD_PUBLIC_ABI_V2_SIGNATURE_HI",
    "NEXTPAS_SIMD_PUBLIC_ABI_V2_SIGNATURE_LO",
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
    "nextpas_simd_mem_equal_fn",
    "nextpas_simd_mem_find_byte_fn",
    "nextpas_simd_mem_diff_range_fn",
    "nextpas_simd_sum_bytes_fn",
    "nextpas_simd_count_byte_fn",
    "nextpas_simd_bitset_popcount_fn",
    "nextpas_simd_utf8_validate_fn",
    "nextpas_simd_ascii_iequal_fn",
    "nextpas_simd_bytes_index_of_fn",
    "nextpas_simd_mem_copy_fn",
    "nextpas_simd_mem_set_fn",
    "nextpas_simd_to_lower_ascii_fn",
    "nextpas_simd_to_upper_ascii_fn",
    "nextpas_simd_mem_reverse_fn",
    "nextpas_simd_min_max_bytes_fn",
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
    sections["abi_type_alias"] = extract_pascal_type_decl_lines(intf_text, ["TNextPasSimdAbiFlags"])
    sections["public_api_v2_flag_type_alias"] = extract_pascal_type_decl_lines(
        intf_text, ["TNextPasSimdPublicApiV2Flags"]
    )
    sections["abi_flag_consts"] = extract_pascal_const_lines(intf_text, PASCAL_ABI_FLAG_NAMES)
    sections["public_api_v2_flag_consts"] = extract_pascal_const_lines(
        intf_text, PASCAL_PUBLIC_API_V2_FLAG_NAMES
    )
    sections["backend_pod_record"] = extract_pascal_record_signature_lines(intf_text, "TNextPasSimdBackendPodInfo")
    sections["public_func_types"] = extract_pascal_type_decl_lines(intf_text, PASCAL_FUNC_TYPE_NAMES)
    sections["public_api_record"] = extract_pascal_record_signature_lines(intf_text, "TNextPasSimdPublicApi")
    sections["public_api_v2_record"] = extract_pascal_record_signature_lines(intf_text, "TNextPasSimdPublicApiV2")
    sections["pascal_api_decls"] = extract_pascal_named_lines(intf_text, PASCAL_API_NAMES, r"(?:function|procedure)")
    sections["c_export_alias_decls"] = extract_pascal_named_lines(intf_text, PASCAL_EXPORT_ALIAS_NAMES, r"(?:function|procedure)")
    sections["abi_const_decls"] = extract_pascal_const_lines(impl_text, PASCAL_ABI_CONST_NAMES)
    sections["smoke_header_flag_alias"] = extract_c_named_lines(
        header_text, ["nextpas_simd_abi_flags_t"], r"typedef\s+[A-Za-z0-9_]+\s+"
    )
    sections["smoke_header_public_api_v2_flag_alias"] = extract_c_named_lines(
        header_text, ["nextpas_simd_public_api_v2_flags_t"], r"typedef\s+[A-Za-z0-9_]+\s+"
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
        header_text, "nextpas_simd_backend_pod_info_t"
    )
    sections["smoke_header_public_api_struct"] = extract_c_struct_signature_lines(
        header_text, "nextpas_simd_public_api_t"
    )
    sections["smoke_header_public_api_v2_struct"] = extract_c_struct_signature_lines(
        header_text, "nextpas_simd_public_api_v2_t"
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

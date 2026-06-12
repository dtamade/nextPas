#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


TEST_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEST_DIR.parents[3]
SOURCE = REPO_ROOT / "core" / "src" / "nextpas.core.hash.util.pas"
HASH_FACADE = REPO_ROOT / "core" / "src" / "nextpas.core.hash.pas"
HASH_FILES = REPO_ROOT / "core" / "src" / "nextpas.core.hash.files.pas"
AUDIT_TEST = TEST_DIR / "test_hash_audit.lpr"
FILE_TEST = TEST_DIR.parent / "test_file" / "test_file.lpr"
HASH_README = REPO_ROOT / "core" / "docs" / "hash" / "README.md"
ACTIVE_HASH_BENCH = (
    REPO_ROOT
    / "core"
    / "benchmarks"
    / "nextpas.core.hash"
    / "bench_hash"
    / "bench_hash.lpr"
)
HEX_FIXTURE_TESTS = [
    REPO_ROOT / "core" / "tests" / "nextpas.core.crypto" / "test_hmac" / "test_hmac.lpr",
    REPO_ROOT / "core" / "tests" / "nextpas.core.crypto" / "test_hkdf" / "test_hkdf.lpr",
]
CRYPTO_OWNER_STANDALONE_TESTS = {
    "test_hmac": {
        "owner_unit": "nextpas.core.crypto.hmac",
        "build_dir": "build/projects/nextpas.core.crypto/test_hmac",
        "markers": ("RFC 4231", "HmacSHA384", "TestHMACClone"),
    },
    "test_hkdf": {
        "owner_unit": "nextpas.core.crypto.hkdf",
        "build_dir": "build/projects/nextpas.core.crypto/test_hkdf",
        "markers": ("RFC 5869", "HKDF_ExtractBytes", "HKDF_ExpandBytes"),
    },
    "test_pbkdf2": {
        "owner_unit": "nextpas.core.crypto.pbkdf2",
        "build_dir": "build/projects/nextpas.core.crypto/test_pbkdf2",
        "markers": ("PBKDF2-HMAC-SHA256", "PBKDF2-HMAC-SHA1", "PBKDF2_SHA256"),
    },
    "test_argon2": {
        "owner_unit": "nextpas.core.crypto.argon2",
        "build_dir": "build/projects/nextpas.core.crypto/test_argon2",
        "markers": ("Argon2id", "Argon2Hash", "atArgon2id"),
    },
}
CRYPTO_OWNED_HASH_TEST_TERMS = (
    "nextpas.core.crypto.hmac",
    "nextpas.core.crypto.hkdf",
    "nextpas.core.crypto.pbkdf2",
    "nextpas.core.crypto.argon2",
    "NewHMAC",
    "HmacSHA",
    "HMAC_",
    "HKDF_",
    "PBKDF2",
    "Argon2",
)
HASHERS = {
    "MD5.Write": REPO_ROOT / "core" / "src" / "nextpas.core.hash.md5.pas",
    "SHA1.Write": REPO_ROOT / "core" / "src" / "nextpas.core.hash.sha1.pas",
    "SHA256.Write": REPO_ROOT / "core" / "src" / "nextpas.core.hash.sha256.pas",
    "SHA512.Write": REPO_ROOT / "core" / "src" / "nextpas.core.hash.sha512.pas",
}
SHA512_VARIANT_CONTEXTS = [
    "HashRequireTotalLength(FTotalLen, ACount, 'SHA384.Write')",
    "HashRequireBuffer(ABuf, ACount, 'SHA384.Write')",
    "HashRequireTotalLength(FTotalLen, ACount, 'SHA512.Write')",
    "HashRequireBuffer(ABuf, ACount, 'SHA512.Write')",
    "HashRequireBuffer(ADst, LOutSize, 'SHA384.Sum')",
    "HashRequireBuffer(ADst, LOutSize, 'SHA512.Sum')",
]
SUM_CONTRACTS = [
    {
        "context": "MD5.Sum",
        "path": REPO_ROOT / "core" / "src" / "nextpas.core.hash.md5.pas",
        "signature": "procedure TMD5Hasher.Sum(out ADst; const ASize: SizeUInt);",
        "next_symbol": "function TMD5Hasher.SumBytes",
        "digest_size": "DigestOutputSize(MD5_DIGEST_SIZE, ASize)",
        "process_markers": ["MD5ProcessBlock("],
    },
    {
        "context": "SHA1.Sum",
        "path": REPO_ROOT / "core" / "src" / "nextpas.core.hash.sha1.pas",
        "signature": "procedure TSHA1Hasher.Sum(out ADst; const ASize: SizeUInt);",
        "next_symbol": "function TSHA1Hasher.SumBytes",
        "digest_size": "DigestOutputSize(SHA1_DIGEST_SIZE, ASize)",
        "process_markers": ["SHA1ProcessBlock("],
    },
    {
        "context": "SHA256.Sum",
        "path": REPO_ROOT / "core" / "src" / "nextpas.core.hash.sha256.pas",
        "signature": "procedure TSHA256Hasher.Sum(out ADst; const ASize: SizeUInt);",
        "next_symbol": "function TSHA256Hasher.SumBytes",
        "digest_size": "DigestOutputSize(SHA256_DIGEST_SIZE, ASize)",
        "process_markers": [
            "ProcessBlockSHANI(",
            "ProcessBlockX64V2(",
            "ProcessBlockX64(",
            "ProcessBlockLocal(",
        ],
    },
    {
        "context": "SHA512.Sum",
        "path": REPO_ROOT / "core" / "src" / "nextpas.core.hash.sha512.pas",
        "signature": "procedure TSHA512Hasher.Sum(out ADst; const ASize: SizeUInt);",
        "next_symbol": "function TSHA512Hasher.SumBytes",
        "digest_size": "DigestOutputSize(LDigestSize, ASize)",
        "process_markers": ["ProcessBlockLocal512("],
    },
]


def extract_body(source: str, signature: str, next_symbol: str) -> str | None:
    start = source.find(signature)
    if start < 0:
        return None
    end = source.find(next_symbol, start)
    if end < 0:
        return None
    return source[start:end]


def first_marker_position(text: str, markers: list[str]) -> int | None:
    positions = [text.find(marker) for marker in markers if text.find(marker) >= 0]
    if not positions:
        return None
    return min(positions)


def check_forbidden_hash_file_wrappers(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    forbidden_helpers = ("MD5FileHex", "SHA1FileHex", "SHA384FileHex")
    for path, text in sources.items():
        for helper in forbidden_helpers:
            if re.search(rf"\b{re.escape(helper)}\b", text):
                errors.append(
                    f"{path} must not expose {helper}; use HashFileHex(AAlgo, APath) instead"
                )
    return errors


def check_forbidden_crypto_owned_hash_surface(sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    forbidden_terms = ("HMAC", "HKDF", "PBKDF2", "Argon2")
    for path, text in sources.items():
        for term in forbidden_terms:
            if re.search(re.escape(term), text, re.IGNORECASE):
                errors.append(
                    f"{path} must not expose crypto-owned {term}; keep it under nextpas.core.crypto"
                )
    return errors


def check_forbidden_crypto_owned_hash_tests(test_sources: dict[str, str]) -> list[str]:
    errors: list[str] = []
    for path, text in test_sources.items():
        for term in CRYPTO_OWNED_HASH_TEST_TERMS:
            if re.search(re.escape(term), text, re.IGNORECASE):
                errors.append(
                    f"{path} must not cover crypto-owned {term}; keep HMAC/HKDF/PBKDF2/Argon2 under nextpas.core.crypto tests"
                )
    return errors


def check_active_hash_benchmark_contract(path: Path, source: str) -> list[str]:
    errors: list[str] = []
    expected = REPO_ROOT / "core" / "benchmarks" / "nextpas.core.hash" / "bench_hash" / "bench_hash.lpr"
    if path != expected:
        errors.append(
            "hash audit active benchmark must use core/benchmarks/nextpas.core.hash/bench_hash/bench_hash.lpr"
        )
    if not (expected.parent / "Makefile").exists():
        errors.append("active hash benchmark must keep focused Makefile beside bench_hash.lpr")
    for term in ("nextpas.core.crypto.", "NewHMAC", "HMAC", "HKDF", "PBKDF2", "Argon2"):
        if re.search(re.escape(term), source, re.IGNORECASE):
            errors.append(
                f"active hash benchmark must not include crypto-owned benchmark term: {term}"
            )
    return errors


def check_contract_checker_guards() -> list[str]:
    errors: list[str] = []
    wrapper_checker = globals().get("check_forbidden_hash_file_wrappers")
    if not callable(wrapper_checker):
        errors.append("hash audit checker must expose forbidden file-wrapper guard")
        return errors

    good_source = (
        "function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string;\n"
        "function SHA256FileHex(const APath: string): string;\n"
        "function SHA512FileHex(const APath: string): string;\n"
    )
    good_errors = wrapper_checker(
        {
            "src/nextpas.core.hash.pas": good_source,
            "src/nextpas.core.hash.files.pas": good_source,
            "core/docs/hash/README.md": "`HashFileHex(AAlgo, APath): string`",
        }
    )
    if good_errors:
        errors.append(
            "hash audit forbidden wrapper self-test must accept allowed file helpers: "
            + "; ".join(good_errors)
        )

    for helper in ("MD5FileHex", "SHA1FileHex", "SHA384FileHex"):
        sample_errors = wrapper_checker(
            {
                "src/nextpas.core.hash.pas": f"function {helper}(const APath: string): string;",
                "src/nextpas.core.hash.files.pas": "",
                "core/docs/hash/README.md": "",
            }
        )
        if not any(helper in error for error in sample_errors):
            errors.append(f"hash audit forbidden wrapper self-test must reject {helper}")

    crypto_surface_checker = globals().get("check_forbidden_crypto_owned_hash_surface")
    if not callable(crypto_surface_checker):
        errors.append("hash audit checker must expose crypto-owned surface guard")
        return errors
    good_crypto_errors = crypto_surface_checker(
        {
            "core/src/nextpas.core.hash.pas": "function SHA256Of(const ABuf; ALen: SizeUInt): TSHA256Digest;",
            "core/src/nextpas.core.hash.files.pas": "function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string;",
        }
    )
    if good_crypto_errors:
        errors.append(
            "hash audit crypto-owned surface self-test must accept hash-only facade: "
            + "; ".join(good_crypto_errors)
        )
    for term in ("HMAC", "HKDF", "PBKDF2", "Argon2"):
        sample_errors = crypto_surface_checker(
            {
                "core/src/nextpas.core.hash.pas": f"function New{term}: IHasher;",
            }
        )
        if not any(term in error for error in sample_errors):
            errors.append(f"hash audit crypto-owned surface self-test must reject {term}")

    crypto_test_checker = globals().get("check_forbidden_crypto_owned_hash_tests")
    if not callable(crypto_test_checker):
        errors.append("hash audit checker must expose crypto-owned hash-test guard")
        return errors
    good_test_errors = crypto_test_checker(
        {
            "core/tests/nextpas.core.hash/test_sha256/test_sha256.lpr": "uses nextpas.core.hash.sha256;",
        }
    )
    if good_test_errors:
        errors.append(
            "hash audit crypto-owned test self-test must accept hash-only tests: "
            + "; ".join(good_test_errors)
        )
    for term in ("nextpas.core.crypto.hmac", "NewHMAC", "HKDF_", "PBKDF2", "Argon2"):
        sample_errors = crypto_test_checker(
            {
                "core/tests/nextpas.core.hash/test_bad/test_bad.lpr": term,
            }
        )
        if not any(term in error for error in sample_errors):
            errors.append(f"hash audit crypto-owned test self-test must reject {term}")

    benchmark_checker = globals().get("check_active_hash_benchmark_contract")
    if not callable(benchmark_checker):
        errors.append("hash audit checker must expose active benchmark route guard")
        return errors
    active_benchmark = REPO_ROOT / "core" / "benchmarks" / "nextpas.core.hash" / "bench_hash" / "bench_hash.lpr"
    good_benchmark_errors = benchmark_checker(
        active_benchmark,
        "program bench_hash; uses nextpas.core.hash;",
    )
    if good_benchmark_errors:
        errors.append(
            "hash audit active benchmark self-test must accept focused hash benchmark: "
            + "; ".join(good_benchmark_errors)
        )
    legacy_benchmark = REPO_ROOT / "benchmarks" / "nextpas.core.hash" / "bench_hash_all.lpr"
    legacy_errors = benchmark_checker(
        legacy_benchmark,
        "program bench_hash_all; uses nextpas.core.hash, nextpas.core.crypto.hmac; NewHMAC",
    )
    if not any("active benchmark must use core/benchmarks" in error for error in legacy_errors):
        errors.append("hash audit active benchmark self-test must reject legacy root benchmark")
    if not any("crypto-owned" in error for error in legacy_errors):
        errors.append("hash audit active benchmark self-test must reject crypto-owned benchmark content")
    return errors


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    facade_source = HASH_FACADE.read_text(encoding="utf-8")
    file_source = HASH_FILES.read_text(encoding="utf-8")
    audit_test_source = AUDIT_TEST.read_text(encoding="utf-8")
    file_test_source = FILE_TEST.read_text(encoding="utf-8")
    readme_source = HASH_README.read_text(encoding="utf-8")
    readme_contract_source = re.sub(r"\s+", " ", readme_source)
    active_bench_source = ACTIVE_HASH_BENCH.read_text(encoding="utf-8")
    errors: list[str] = []
    errors.extend(check_contract_checker_guards())
    errors.extend(check_active_hash_benchmark_contract(ACTIVE_HASH_BENCH, active_bench_source))
    errors.extend(
        check_forbidden_hash_file_wrappers(
            {
                str(HASH_FACADE.relative_to(REPO_ROOT)): facade_source,
                str(HASH_FILES.relative_to(REPO_ROOT)): file_source,
                str(HASH_README.relative_to(REPO_ROOT)): readme_source,
            }
        )
    )
    hash_source_files = sorted((REPO_ROOT / "core" / "src").glob("nextpas.core.hash*.pas"))
    errors.extend(
        check_forbidden_crypto_owned_hash_surface(
            {
                str(path.relative_to(REPO_ROOT)): path.read_text(encoding="utf-8")
                for path in hash_source_files
            }
        )
    )
    hash_test_files = sorted(
        (REPO_ROOT / "core" / "tests" / "nextpas.core.hash").glob("test_*/*.lpr")
    )
    errors.extend(
        check_forbidden_crypto_owned_hash_tests(
            {
                str(path.relative_to(REPO_ROOT)): path.read_text(encoding="utf-8")
                for path in hash_test_files
            }
        )
    )

    guard = "ALen > (High(SizeInt) div 2)"
    allocation = "SetLength(Result, ALen * 2)"
    if guard not in source:
        errors.append("DigestToHex must reject lengths that overflow Pascal string length")
    if allocation not in source:
        errors.append("DigestToHex allocation shape changed; review the length-overflow guard")
    elif source.find(guard) > source.find(allocation):
        errors.append("DigestToHex length guard must appear before SetLength(Result, ALen * 2)")

    if errors:
        print("hash util source contract failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    facade_decl = "function DigestToHex(const ABuf; ALen: SizeUInt): string; inline;"
    facade_forward = "Result := nextpas.core.hash.util.DigestToHex(ABuf, ALen);"
    if facade_decl not in facade_source:
        errors.append("hash facade DigestToHex declaration must stay inline")
    if facade_forward not in facade_source:
        errors.append("hash facade DigestToHex must forward to hash.util.DigestToHex")

    empty_path_guard = "if APath = '' then"
    nul_path_guard = "if Pos(#0, APath) > 0 then"
    stat_guard = "LInfo := FsStat(APath)"
    handle_stat_guard = "LInfo := LFile.Stat"
    regular_file_guard = "LInfo.FileType <> ftRegular"
    regular_file_message = "HashFileHex: path is not a regular file"
    opened_handle_message = "HashFileHex: opened handle is not a regular file"
    fs_open = "LFile := FsOpen(APath, [fmRead])"
    file_read = "LRead := LFile.Read"
    if empty_path_guard not in file_source:
        errors.append("hash file helpers must reject empty paths before opening files")
    if nul_path_guard not in file_source:
        errors.append("hash file helpers must reject embedded NUL paths before opening files")
    if stat_guard not in file_source:
        errors.append("hash file helpers must stat paths before opening files")
    if regular_file_guard not in file_source:
        errors.append("hash file helpers must reject non-regular files")
    if regular_file_message not in file_source:
        errors.append("hash file non-regular error must mention regular file")
    if opened_handle_message not in file_source:
        errors.append("hash file opened-handle non-regular error must mention regular file")
    non_regular_raises = re.findall(
        r"raise\s+EInvalidOperationError\.(?:Create|CreateFmt)\(([^;]+)\);",
        file_source,
        re.IGNORECASE | re.DOTALL,
    )
    non_regular_raises = [
        statement
        for statement in non_regular_raises
        if "regular file" in statement
    ]
    if len(non_regular_raises) != 2:
        errors.append("hash file helpers must keep exactly two non-regular error raises")
    for statement in non_regular_raises:
        if "APath" in statement:
            errors.append("hash file non-regular errors must not echo the raw input path")
        if "CreateFmt" in statement:
            errors.append("hash file non-regular errors must not format raw path data")
    if fs_open not in file_source:
        errors.append("hash file helper open shape changed; review path guard contract")
    else:
        if file_source.find(empty_path_guard) > file_source.find(fs_open):
            errors.append("hash file empty-path guard must run before FsOpen")
        if file_source.find(nul_path_guard) > file_source.find(fs_open):
            errors.append("hash file embedded-NUL guard must run before FsOpen")
        if stat_guard in file_source and file_source.find(stat_guard) > file_source.find(fs_open):
            errors.append("hash file regular-file guard must run before FsOpen")
        if handle_stat_guard not in file_source:
            errors.append("hash file helpers must re-stat the opened handle before reading")
        elif file_read not in file_source:
            errors.append("hash file helper read shape changed; review opened-handle stat contract")
        else:
            if file_source.find(handle_stat_guard) < file_source.find(fs_open):
                errors.append("hash file opened-handle stat must run after FsOpen")
            if file_source.find(handle_stat_guard) > file_source.find(file_read):
                errors.append("hash file opened-handle stat must run before first Read")

    if "CallSHA256FileHexEmbeddedNulPath" not in audit_test_source:
        errors.append("hash audit must cover SHA256FileHex embedded NUL paths")
    if "CallSHA512FileHexEmbeddedNulPath" not in audit_test_source:
        errors.append("hash audit must cover SHA512FileHex embedded NUL paths")
    for facade in ("MD5Of", "SHA1Of", "SHA256Of", "SHA384Of", "SHA512Of"):
        marker = f"Call{facade}NilPositive"
        if marker not in audit_test_source:
            errors.append(f"hash audit must cover {facade} nil+positive one-shot input")
    if "CallSHA384WriteTotalLengthOverflow" not in audit_test_source:
        errors.append("hash audit must cover SHA384 Write total length overflow")
    if "CallSHA256FileHexDirectoryPath" not in file_test_source:
        errors.append("hash file test must cover SHA256FileHex directory paths")
    if "CallSHA512FileHexDirectoryPath" not in file_test_source:
        errors.append("hash file test must cover SHA512FileHex directory paths")
    if "CallHashFileHexEmptyPath" not in file_test_source:
        errors.append("hash file test must cover HashFileHex empty paths")
    if "CallHashFileHexEmbeddedNulPath" not in file_test_source:
        errors.append("hash file test must cover HashFileHex embedded NUL paths")
    if "CallHashFileHexDirectoryPath" not in file_test_source:
        errors.append("hash file test must cover HashFileHex directory paths")
    if "TestHashFileHexFacadeByAlgorithm" not in file_test_source:
        errors.append("hash file test must cover facade HashFileHex by algorithm")
    if "CallHashFileHexInvalidAlgorithm" not in file_test_source:
        errors.append("hash file test must cover HashFileHex invalid algorithm")
    if "HashFileHex invalid algorithm" not in file_test_source:
        errors.append("hash file invalid algorithm test must be registered")
    if "TestHashFileHexEmptyFileByAlgorithm" not in file_test_source:
        errors.append("hash file test must cover HashFileHex empty files by algorithm")
    for marker in (
        "HashFileHex MD5 empty vector",
        "HashFileHex SHA1 empty vector",
        "HashFileHex SHA256 empty vector",
        "HashFileHex SHA384 empty vector",
        "HashFileHex SHA512 empty vector",
    ):
        if marker not in file_test_source:
            errors.append(f"hash file empty vector test must pin {marker}")

    hash_file_hex_facade_decl = (
        "function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string; inline;"
    )
    hash_file_hex_facade_forward = (
        "Result := nextpas.core.hash.files.HashFileHex(AAlgo, APath);"
    )
    if hash_file_hex_facade_decl not in facade_source:
        errors.append("hash facade must declare HashFileHex(AAlgo, APath)")
    if hash_file_hex_facade_forward not in facade_source:
        errors.append("hash facade HashFileHex must forward to hash.files")

    hash_file_hex_files_decl = (
        "function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string;"
    )
    if hash_file_hex_files_decl not in file_source:
        errors.append("hash files unit must expose HashFileHex(AAlgo, APath)")
    for algo in ("haMD5", "haSHA1", "haSHA256", "haSHA384", "haSHA512"):
        if f"Ord({algo})" not in file_source:
            errors.append(f"HashFileHex(AAlgo, APath) must support {algo}")

    if "`SHA256FileHex(APath): string`" not in readme_source:
        errors.append("hash README must list SHA256FileHex facade helper")
    if "`SHA512FileHex(APath): string`" not in readme_source:
        errors.append("hash README must list SHA512FileHex facade helper")
    if "`HashFileHex(AAlgo, APath): string`" not in readme_source:
        errors.append("hash README must list HashFileHex facade helper")

    readme_required_facade_rows = [
        "`GetDigestSize(AAlgo): SizeUInt`",
        "`GetBlockSize(AAlgo): SizeUInt`",
        "`WyHash(AData, ALen, ASeed): UInt64`",
        "`WyHashStr(S, ASeed): UInt64`",
        "`WyHash32(AData, ALen, ASeed): UInt32`",
        "`WyHashStr32(S, ASeed): UInt32`",
    ]
    for row in readme_required_facade_rows:
        if row not in readme_source:
            errors.append(f"hash README must list facade helper {row}")

    readme_required_contract_terms = [
        "non-cryptographic",
        "ASeed",
        "nil with ALen > 0",
        "deterministic regression contract",
        "supported platforms",
        "not an external wyhash compatibility certification",
        "Do not use WyHash output as an unversioned wire or storage format",
    ]
    for term in readme_required_contract_terms:
        if term not in readme_contract_source:
            errors.append(f"hash README must document WyHash contract term: {term}")

    readme_required_roadmap_terms = [
        "长期算法覆盖路线图",
        "子模块覆盖目标",
        "SHA-224",
        "SHA-512/224",
        "SHA-512/256",
        "SHA-3/SHAKE",
        "BLAKE2/BLAKE3",
        "xxHash32/64/XXH3",
        "MurmurHash3",
        "FNV-1a 32/64",
        "CRC32 IEEE",
        "CRC32C",
        "Adler-32",
        "CRC64",
        "CityHash/FarmHash",
        "SipHash/HighwayHash",
        "owner-review",
        "HMAC/HKDF/PBKDF2/Argon2 属于 crypto owner",
        "路线图目标，不是当前实现承诺",
    ]
    for term in readme_required_roadmap_terms:
        if term not in readme_contract_source:
            errors.append(f"hash README must keep compact long-term coverage roadmap term: {term}")
    if "HMAC/HKDF/PBKDF2 boundary after hash/crypto ownership review" in readme_contract_source:
        errors.append("hash README must not present crypto-owned HMAC/HKDF/PBKDF2 as future hash coverage")

    facade_comment_forbidden_terms = [
        "SumBytes[0]",
    ]
    for term in facade_comment_forbidden_terms:
        if term in facade_source:
            errors.append(f"hash facade comment must not teach unsafe dynamic-array access: {term}")
    if "if Length(Data) > 0 then" not in facade_source:
        errors.append("hash facade comment must guard dynamic-array Data[0] writes with Length(Data) > 0")

    if re.search(r"\b\d+(?:\.\d+)?\s*MB/s\b|~\d+\s*MB/s\b", readme_source):
        errors.append("hash README must not publish fixed throughput numbers without checked benchmark evidence")
    if re.search(r"\bSHA-NI\s*>\s*AVX2\s*>\s*SSSE3\s*>\s*scalar\b", readme_source):
        errors.append("hash README must not publish acceleration ordering as a universal performance claim")
    if re.search(r"Reference|compare_go|compare_rust|cross-language", active_bench_source, re.IGNORECASE):
        errors.append("active hash benchmark must not print cross-language reference prompts")

    if "procedure HashRequireTotalLength(" not in source:
        errors.append("hash util must expose a total-length overflow guard")

    sha512_source = HASHERS["SHA512.Write"].read_text(encoding="utf-8")
    for term in SHA512_VARIANT_CONTEXTS:
        if term not in sha512_source:
            errors.append(f"SHA384/SHA512 shared hasher must select public error context: {term}")
    if "LContext: string" in sha512_source:
        errors.append("SHA384/SHA512 shared hasher must not allocate managed context strings on Write/Sum paths")

    hash_test_root = REPO_ROOT / "core" / "tests" / "nextpas.core.hash"
    crypto_test_root = REPO_ROOT / "core" / "tests" / "nextpas.core.crypto"
    for test_name, contract in CRYPTO_OWNER_STANDALONE_TESTS.items():
        owner_unit = contract["owner_unit"]
        hash_test_path = hash_test_root / test_name / f"{test_name}.lpr"
        if hash_test_path.exists():
            errors.append(
                f"{test_name} is crypto-owned and must live under nextpas.core.crypto tests"
            )
            test_source = hash_test_path.read_text(encoding="utf-8")
            if owner_unit not in test_source:
                errors.append(f"{test_name} owner contract changed; expected {owner_unit}")

        crypto_test_path = crypto_test_root / test_name / f"{test_name}.lpr"
        if not crypto_test_path.exists():
            errors.append(f"{test_name} crypto-owned test must exist under nextpas.core.crypto")
        else:
            test_source = crypto_test_path.read_text(encoding="utf-8")
            if owner_unit not in test_source:
                errors.append(f"{test_name} crypto-owned test must use {owner_unit}")
            for marker in contract.get("markers", ()):
                if marker not in test_source:
                    errors.append(f"{test_name} crypto-owned test must keep marker {marker}")

        crypto_makefile_path = crypto_test_root / test_name / "Makefile"
        if not crypto_makefile_path.exists():
            errors.append(f"{test_name} crypto-owned Makefile must exist")
        else:
            makefile_source = crypto_makefile_path.read_text(encoding="utf-8")
            if contract["build_dir"] not in makefile_source:
                errors.append(
                    f"{test_name} build output must stay under {contract['build_dir']}"
                )

    for test_path in HEX_FIXTURE_TESTS:
        if not test_path.exists():
            continue
        test_source = test_path.read_text(encoding="utf-8")
        if "function HexToBytes" not in test_source:
            errors.append(f"{test_path.name} must keep explicit hex fixture conversion visible")
            continue
        if "Length(AHex) div 2" in test_source:
            errors.append(f"{test_path.name} HexToBytes must not silently truncate odd-length fixtures")
        if "Length(AHex) mod 2" not in test_source:
            errors.append(f"{test_path.name} HexToBytes must reject odd-length fixtures")

    for context, path in HASHERS.items():
        hasher_source = path.read_text(encoding="utf-8")
        guard = f"HashRequireTotalLength(FTotalLen, ACount, '{context}')"
        state_update = "Inc(FTotalLen, ACount)"
        if guard not in hasher_source:
            errors.append(f"{context} must validate total length before updating state")
            continue
        if hasher_source.find(guard) > hasher_source.find(state_update):
            errors.append(f"{context} total-length guard must run before Inc(FTotalLen, ACount)")

    for contract in SUM_CONTRACTS:
        hasher_source = contract["path"].read_text(encoding="utf-8")
        body = extract_body(hasher_source, contract["signature"], contract["next_symbol"])
        context = contract["context"]
        if body is None:
            errors.append(f"{context} body shape changed; review Sum output validation contract")
            continue

        digest_pos = body.find(f"LOutSize := {contract['digest_size']}")
        zero_exit_pos = body.find("if LOutSize = 0 then Exit")
        buffer_guard_pos = body.find(f"HashRequireBuffer(ADst, LOutSize, '{context}')")
        first_process_pos = first_marker_position(body, contract["process_markers"])

        if digest_pos < 0:
            errors.append(f"{context} must compute output size before finalization")
        if zero_exit_pos < 0:
            errors.append(f"{context} must keep zero-size Sum as a no-op before buffer validation")
        if buffer_guard_pos < 0:
            errors.append(f"{context} must validate destination buffer before finalization")
        if first_process_pos is None:
            errors.append(f"{context} finalization block shape changed; review output validation order")
            continue
        if digest_pos >= 0 and digest_pos > first_process_pos:
            errors.append(f"{context} output-size calculation must run before final ProcessBlock")
        if zero_exit_pos >= 0 and zero_exit_pos > first_process_pos:
            errors.append(f"{context} zero-size Sum must return before final ProcessBlock")
        if buffer_guard_pos >= 0 and buffer_guard_pos > first_process_pos:
            errors.append(f"{context} destination buffer guard must run before final ProcessBlock")

    if errors:
        print("hash util source contract failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("hash util source contract passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

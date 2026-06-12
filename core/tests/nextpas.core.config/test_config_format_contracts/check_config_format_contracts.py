#!/usr/bin/env python3
"""Guard config/data-format documentation and dependency boundaries."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


SUMMARY_PREFIX = "CONFIG_FORMAT_CONTRACTS"

REQUIRED_DOCS = (
    "docs/config-formats/README.md",
    "docs/config/README.md",
    "docs/json/README.md",
    "docs/toml/README.md",
    "docs/yaml/README.md",
    "docs/xml/README.md",
    "docs/csv/README.md",
    "docs/ini/README.md",
)

REQUIRED_FACADES = (
    "src/nextpas.core.config.pas",
    "src/nextpas.core.json.pas",
    "src/nextpas.core.toml.pas",
    "src/nextpas.core.yaml.pas",
    "src/nextpas.core.xml.pas",
    "src/nextpas.core.csv.pas",
    "src/nextpas.core.ini.pas",
)

REQUIRED_SURFACE_GATES = (
    "tests/nextpas.core.config/test_config_facade_surface/Makefile",
    "tests/nextpas.core.json/test_json_facade_surface/Makefile",
    "tests/nextpas.core.toml/test_toml_facade_surface/Makefile",
    "tests/nextpas.core.yaml/test_yaml_facade_surface/Makefile",
    "tests/nextpas.core.xml/test_xml_facade_surface/Makefile",
    "tests/nextpas.core.csv/test_csv_facade_surface/Makefile",
    "tests/nextpas.core.ini/test_ini_facade_surface/Makefile",
)

CONFIG_INTERNAL_SEAMS = (
    "src/nextpas.core.config.env.pas",
)

FORMAT_SOURCE_GLOBS = (
    "src/nextpas.core.json*.pas",
    "src/nextpas.core.toml*.pas",
    "src/nextpas.core.yaml*.pas",
    "src/nextpas.core.xml*.pas",
    "src/nextpas.core.csv*.pas",
    "src/nextpas.core.ini*.pas",
)

USES_RE = re.compile(r"\buses\b(?P<body>.*?);", re.IGNORECASE | re.DOTALL)
CONFIG_UNIT_RE = re.compile(r"\bnextpas\.core\.config\b", re.IGNORECASE)
PASCAL_PROC_RE_TEMPLATE = (
    r"\bprocedure\s+{name}\s*\([^;]*\)\s*;\s*"
    r"begin(?P<body>.*?)\bend\s*;"
)

CONFIG_SAVE_METHODS = (
    "TConfig.SaveToIni",
    "TConfig.SaveToJson",
    "TConfig.SaveToYaml",
    "TConfig.SaveToToml",
)

REQUIRED_DOC_SNIPPETS = {
    "docs/config-formats/README.md": (
        (
            "common-diagnostics-lifetime-matrix-header",
            "## Common diagnostics and lifetime matrix",
        ),
        ("common-diagnostics-lifetime-matrix-json-row", "| `json` |"),
        ("common-diagnostics-lifetime-matrix-toml-row", "| `toml` |"),
        ("common-diagnostics-lifetime-matrix-yaml-row", "| `yaml` |"),
        ("common-diagnostics-lifetime-matrix-xml-row", "| `xml` |"),
        ("common-diagnostics-lifetime-matrix-csv-row", "| `csv` |"),
        ("common-diagnostics-lifetime-matrix-ini-row", "| `ini` |"),
        ("common-diagnostics-lifetime-matrix-toml-try-parse", "`TryTomlParse`"),
        ("common-diagnostics-lifetime-matrix-toml-col", "`Line`, `Col`, `Offset`"),
        (
            "common-diagnostics-lifetime-matrix-xml-try-parse",
            "`TryXmlParse` returns `False` and keeps `ADoc = nil`",
        ),
        (
            "common-diagnostics-lifetime-matrix-xml-pos",
            "`EXmlError.Pos` carries `ByteOffset`, `Line`, `Column`",
        ),
        (
            "common-diagnostics-lifetime-matrix-borrowing",
            "Borrowing view; keep the owning document alive",
        ),
        (
            "common-diagnostics-lifetime-matrix-diagnostic-stringify",
            "JSON, TOML, and YAML diagnostic documents are error carriers and cannot be stringified.",
        ),
        (
            "config-formats-config-surface-gate",
            "`make -C tests/nextpas.core.config/test_config_facade_surface clean test`",
        ),
        (
            "config-formats-csv-surface-gate",
            "`make -C tests/nextpas.core.csv/test_csv_facade_surface clean test`",
        ),
        (
            "config-formats-ini-surface-gate",
            "`make -C tests/nextpas.core.ini/test_ini_facade_surface clean test`",
        ),
        (
            "config-formats-empty-top-level-key-boundary",
            "JSON, YAML, and TOML empty keys stay a config-adapter concern",
        ),
    ),
    "docs/config/README.md": (
        ("config-readme-builder-adapter-contract-header", "## Builder and adapter contract"),
        (
            "config-readme-default-priority-contract",
            "`AddDefault` values are always replayed before explicit sources. Later defaults replace earlier defaults but never outrank non-default sources.",
        ),
        (
            "config-readme-source-order-contract",
            "`AddIni`, `AddJson`, `AddYaml`, `AddToml`, `AddFile`, and `AddEnv` replay in call order. Later sources override earlier ones for the same key.",
        ),
        (
            "config-readme-fail-closed-source-contract",
            "If a later source fails to load or parse, `Build`, `BuildConfig`, and `TryBuild` fail closed instead of falling back to earlier valid sources or publishing a partial snapshot.",
        ),
        (
            "config-readme-empty-format-key-contract",
            "JSON, YAML, and TOML sources with empty keys fail closed before",
        ),
        (
            "config-readme-try-build-contract",
            "`TryBuild` returns `False`, clears `AConfig`, and reports parse, file-load, interpolation, or required-key failures through `AError`.",
        ),
        (
            "config-readme-try-build-preexisting-contract",
            "If the caller passes an already assigned `AConfig`, `TryBuild` overwrites it with `nil` on failure instead of leaving a stale snapshot in the output slot.",
        ),
        (
            "config-readme-buildconfig-failure-contract",
            "`BuildConfig` uses the same validating builder pipeline as `Build`; malformed sources, interpolation errors, and required-key failures raise `EConfigError` before a mutable `TConfig` is returned.",
        ),
        (
            "config-readme-file-path-contract",
            "`ConfigLoad` and `AddFile(...).Build` share the same validating file-source path, so file errors include the failing path.",
        ),
        (
            "config-readme-export-contract",
            "`ToIni` is lossy-guarded for values the current INI adapter cannot round-trip, while `ToToml` preserves flat keys as literal TOML keys instead of rebuilding tables.",
        ),
        ("config-readme-reload-contract-header", "## Reload and failed-load contract"),
        (
            "config-readme-try-load-preserve-contract",
            "`TryLoadFromFile` returns `False` and leaves the existing config table untouched when file loading or parsing fails.",
        ),
        (
            "config-readme-watcher-preserve-contract",
            "`TConfigWatcher` reloads through a temporary `TConfig` and only calls `ReplaceFrom` after the new file parses successfully.",
        ),
        (
            "config-readme-watcher-callback-contract",
            "`OnReload` fires only after a successful reload. Failed reloads preserve old values and do not fire the callback.",
        ),
    ),
    "docs/toml/README.md": (
        ("toml-readme-failure-contract-header", "## Failure and lifetime contract"),
        (
            "toml-readme-try-parse-contract",
            "`TryTomlParse` returns `False` on parse failure and still assigns a diagnostic document",
        ),
        (
            "toml-readme-error-fields-contract",
            "`TTomlError` exposes `Message`, `Line`, `Col`, and `Offset`",
        ),
        (
            "toml-readme-borrowing-contract",
            "Keep the owning `ITomlDocument` alive while any `TTomlValue` is still in use.",
        ),
    ),
    "docs/json/README.md": (
        ("json-readme-failure-contract-header", "## Failure and lifetime contract"),
        (
            "json-readme-try-parse-contract",
            "`TryJsonParse` returns `False` on parse failure and still assigns a diagnostic document",
        ),
        (
            "json-readme-error-fields-contract",
            "`TJsonError` exposes `Message`, `Line`, `Column`, and `Offset`",
        ),
        (
            "json-readme-string-diagnostic-position-contract",
            "Malformed string diagnostics point at the offending byte",
        ),
        (
            "json-readme-borrowing-contract",
            "Keep the owning `IJsonDocument` alive while any `TJsonValue` is still in use.",
        ),
    ),
    "docs/xml/README.md": (
        ("xml-readme-failure-contract-header", "## Failure and ownership contract"),
        (
            "xml-readme-parse-raise-contract",
            "`XmlParse` and `XmlTokenize` raise `EXmlError` on parse or tokenization failures.",
        ),
        (
            "xml-readme-try-parse-contract",
            "`TryXmlParse` returns `False` on failure and keeps `ADoc = nil`.",
        ),
        (
            "xml-readme-error-fields-contract",
            "`EXmlError.Pos` exposes `ByteOffset`, `Line`, and `Column`.",
        ),
        (
            "xml-readme-ownership-contract",
            "Callers own `TXmlDocument`, `TXmlReader`, and `TXmlWriter` instances and must free them.",
        ),
    ),
    "docs/yaml/README.md": (
        ("yaml-readme-failure-contract-header", "## Failure and lifetime contract"),
        (
            "yaml-readme-try-parse-contract",
            "`TryYamlParse` returns `False` on parse failure and still assigns a diagnostic document.",
        ),
        (
            "yaml-readme-error-fields-contract",
            "`TYamlError` exposes `Message`, `Line`, `Col`, and `Offset`.",
        ),
        (
            "yaml-readme-borrowing-contract",
            "Keep the owning `IYamlDocument` alive while any `TYamlValue` is still in use.",
        ),
        (
            "yaml-readme-diagnostic-stringify-contract",
            "Diagnostic documents cannot be stringified with `Stringify` or `StringifyPretty`.",
        ),
    ),
    "docs/csv/README.md": (
        ("csv-readme-failure-contract-header", "## Failure and lifetime contract"),
        (
            "csv-readme-in-band-failure-contract",
            "`ReadRow` and `ReadAll` report ordinary parse failures in-band through `HasError`, `GetError`, and structured `Error`.",
        ),
        (
            "csv-readme-readall-row-publication-contract",
            "`ReadAll` returns only the complete rows that finished before the failing record. It does not append the malformed or width-mismatched row that set the error state.",
        ),
        (
            "csv-readme-error-fields-contract",
            "`TCsvError` exposes `Message`, `Line`, `Column`, and `Offset`.",
        ),
        (
            "csv-readme-lifetime-contract",
            "`TCsvReader` keeps its input string alive internally, while returned field strings are owned copies.",
        ),
    ),
    "docs/ini/README.md": (
        ("ini-readme-failure-contract-header", "## Failure and ownership contract"),
        (
            "ini-readme-load-contract",
            "`LoadFromString` stays permissive, while `LoadFromFile` raises `ENextPasError` on file I/O failures.",
        ),
        (
            "ini-readme-try-load-contract",
            "`TryLoadFromString` and `TryLoadFromFile` return `False` and populate `Error`.",
        ),
        (
            "ini-readme-newline-contract",
            "`LoadFromString` and the try-load validators recognize LF, CRLF, and lone CR as physical line endings; source diagnostics report byte offsets against the original input.",
        ),
        (
            "ini-readme-duplicate-contract",
            "Duplicate parsed sections merge into the existing section, and duplicate parsed keys update the existing key slot with the last parsed value. Try-load accepts those duplicates.",
        ),
        (
            "ini-readme-error-fields-contract",
            "`TIniError` exposes `Message`, `Line`, `Column`, and `Offset`; non-source file I/O failures use `Line = 0` and `Column = 0`.",
        ),
        (
            "ini-readme-ownership-contract",
            "Callers own `TIniFile` instances and must free them.",
        ),
    ),
}


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str
    line: int
    text: str


@dataclass(frozen=True)
class Report:
    root: str
    scanned_files: int
    findings: list[Finding]

    @property
    def ok(self) -> bool:
        return not self.findings


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check config/data-format docs and dependency contracts."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[3],
        help="core root to scan.",
    )
    parser.add_argument(
        "--json-file",
        default="",
        help="Optional path to write a machine-readable report.",
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a one-line summary for logs.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print detailed findings even with --summary-line.",
    )
    return parser.parse_args()


def mask_char(ch: str) -> str:
    return "\n" if ch in {"\n", "\r"} else " "


def strip_pascal_comments_and_strings(text: str) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    in_string = False
    in_line_comment = False
    in_brace_comment = False
    in_paren_star_comment = False

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_string:
            out.append(mask_char(ch))
            if ch == "'" and nxt == "'":
                out.append(mask_char(nxt))
                i += 2
                continue
            if ch == "'":
                in_string = False
            i += 1
            continue

        if in_line_comment:
            out.append(mask_char(ch))
            if ch == "\n":
                in_line_comment = False
            i += 1
            continue

        if in_brace_comment:
            out.append(mask_char(ch))
            if ch == "}":
                in_brace_comment = False
            i += 1
            continue

        if in_paren_star_comment:
            out.append(mask_char(ch))
            if ch == "*" and nxt == ")":
                out.append(mask_char(nxt))
                i += 2
                in_paren_star_comment = False
                continue
            i += 1
            continue

        if ch == "'":
            in_string = True
            out.append(mask_char(ch))
            i += 1
            continue
        if ch == "/" and nxt == "/":
            in_line_comment = True
            out.append(mask_char(ch))
            out.append(mask_char(nxt))
            i += 2
            continue
        if ch == "{":
            in_brace_comment = True
            out.append(mask_char(ch))
            i += 1
            continue
        if ch == "(" and nxt == "*":
            in_paren_star_comment = True
            out.append(mask_char(ch))
            out.append(mask_char(nxt))
            i += 2
            continue

        out.append(ch)
        i += 1

    return "".join(out)


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def collect_format_sources(root: Path) -> list[Path]:
    paths: set[Path] = set()
    for pattern in FORMAT_SOURCE_GLOBS:
      paths.update(root.glob(pattern))
    return sorted(paths)


def check_required_paths(root: Path, findings: list[Finding]) -> None:
    for rel_path in REQUIRED_DOCS:
        if not (root / rel_path).is_file():
            findings.append(Finding("required-doc", rel_path, 0, "missing module documentation"))
    for rel_path in REQUIRED_FACADES:
        if not (root / rel_path).is_file():
            findings.append(Finding("required-facade", rel_path, 0, "missing facade source"))
    for rel_path in REQUIRED_SURFACE_GATES:
        if not (root / rel_path).is_file():
            findings.append(Finding("required-surface-gate", rel_path, 0, "missing facade surface gate"))


def check_config_internal_seams_are_whitelisted(root: Path, findings: list[Finding]) -> None:
    config_source = root / "src/nextpas.core.config.pas"
    if not config_source.is_file():
        return

    text = config_source.read_text(encoding="utf-8")
    scan_text = strip_pascal_comments_and_strings(text)
    for rel_path in CONFIG_INTERNAL_SEAMS:
        if not (root / rel_path).is_file():
            findings.append(
                Finding(
                    "config-internal-seam-whitelist",
                    rel_path,
                    0,
                    "missing config-owned internal seam",
                )
            )
            continue
        unit_name = Path(rel_path).stem
        if re.search(rf"\b{re.escape(unit_name)}\b", scan_text, re.IGNORECASE):
            continue
        findings.append(
            Finding(
                "config-internal-seam-whitelist",
                rel_path,
                0,
                "config facade must explicitly whitelist this internal seam",
            )
        )


def pascal_method_body(scan_text: str, method_name: str) -> tuple[str, int] | None:
    pattern = re.compile(
        PASCAL_PROC_RE_TEMPLATE.format(name=re.escape(method_name)),
        re.IGNORECASE | re.DOTALL,
    )
    match = pattern.search(scan_text)
    if not match:
        return None
    return match.group("body"), match.start("body")


def check_config_save_uses_atomic_publish(root: Path, findings: list[Finding]) -> None:
    config_source = root / "src/nextpas.core.config.pas"
    if not config_source.is_file():
        return

    text = config_source.read_text(encoding="utf-8")
    scan_text = strip_pascal_comments_and_strings(text)
    if not re.search(r"\bConfigWriteAtomicText\s*\(", scan_text, re.IGNORECASE):
        findings.append(
            Finding(
                "config-save-atomic-helper",
                "src/nextpas.core.config.pas",
                0,
                "config SaveTo* methods must publish through ConfigWriteAtomicText",
            )
        )

    for method_name in CONFIG_SAVE_METHODS:
        body_info = pascal_method_body(scan_text, method_name)
        if body_info is None:
            findings.append(
                Finding(
                    "config-save-atomic-method",
                    "src/nextpas.core.config.pas",
                    0,
                    f"{method_name} method not found",
                )
            )
            continue
        body, body_offset = body_info
        if re.search(r"\bWriteFileText\s*\(", body, re.IGNORECASE):
            findings.append(
                Finding(
                    "config-save-no-truncate-write",
                    "src/nextpas.core.config.pas",
                    line_number(scan_text, body_offset),
                    f"{method_name} must not call WriteFileText",
                )
            )
        if not re.search(r"\bConfigWriteAtomicText\s*\(", body, re.IGNORECASE):
            findings.append(
                Finding(
                    "config-save-atomic-method",
                    "src/nextpas.core.config.pas",
                    line_number(scan_text, body_offset),
                    f"{method_name} must call ConfigWriteAtomicText",
                )
            )


def check_required_doc_snippets(root: Path, findings: list[Finding]) -> None:
    for rel_path, snippets in REQUIRED_DOC_SNIPPETS.items():
        path = root / rel_path
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for rule, needle in snippets:
            if needle not in text:
                findings.append(
                    Finding(
                        rule,
                        rel_path,
                        0,
                        f"documentation must contain {needle!r}",
                    )
                )


def check_format_modules_do_not_depend_on_config(
    root: Path,
    paths: list[Path],
    findings: list[Finding],
) -> None:
    for path in paths:
        rel_path = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        scan_text = strip_pascal_comments_and_strings(text)
        for uses_match in USES_RE.finditer(scan_text):
            body = uses_match.group("body")
            config_match = CONFIG_UNIT_RE.search(body)
            if config_match:
                offset = uses_match.start("body") + config_match.start()
                findings.append(
                    Finding(
                        "format-no-config-dependency",
                        rel_path,
                        line_number(scan_text, offset),
                        "format modules must not use nextpas.core.config",
                    )
                )


def build_report(root: Path) -> Report:
    findings: list[Finding] = []
    check_required_paths(root, findings)
    check_config_internal_seams_are_whitelisted(root, findings)
    check_config_save_uses_atomic_publish(root, findings)
    check_required_doc_snippets(root, findings)
    format_sources = collect_format_sources(root)
    check_format_modules_do_not_depend_on_config(root, format_sources, findings)
    return Report(
        root=str(root),
        scanned_files=len(format_sources),
        findings=findings,
    )


def print_report(report: Report, summary_line: bool, verbose: bool) -> None:
    if summary_line:
        print(
            f"{SUMMARY_PREFIX} scanned_files={report.scanned_files} "
            f"findings={len(report.findings)} status={'ok' if report.ok else 'fail'}"
        )
    if (not summary_line) or verbose or (not report.ok):
        for finding in report.findings:
            location = finding.path if finding.line <= 0 else f"{finding.path}:{finding.line}"
            print(f"{finding.rule}: {location}: {finding.text}")


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    report = build_report(root)
    if args.json_file:
        json_path = Path(args.json_file)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(asdict(report), indent=2) + "\n", encoding="utf-8")
    print_report(report, args.summary_line, args.verbose)
    return 0 if report.ok else 1


if __name__ == "__main__":
    sys.exit(main())

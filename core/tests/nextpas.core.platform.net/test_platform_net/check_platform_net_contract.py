#!/usr/bin/env python3

from pathlib import Path
import re
import sys


SOURCE = Path(__file__).with_name("test_platform_net.lpr")


def update_stack(line: str, stack: list[str]) -> None:
    lower = line.lower()
    match = re.search(r"\{\$if(?:def)?\s+(?:defined\()?([a-z0-9_]+)", lower)
    if match:
        stack.append(match.group(1))
        return
    if "{$endif" in lower and stack:
        stack.pop()


def line_has_required_guard(stack: list[str], guard: str) -> bool:
    return guard in stack


def check_guarded_host_references(source: str) -> list[str]:
    errors: list[str] = []
    stack: list[str] = []
    text_expectations = (
        ("nextpas.core.platform.posix.base", "nextpas_unix"),
        ("nextpas.core.platform.posix.ffi", "nextpas_unix"),
        ("nextpas.core.platform.linux.base", "nextpas_linux"),
        ("nextpas.core.platform.windows.base", "nextpas_windows"),
        ("nextpas.core.platform.windows.ffi", "nextpas_windows"),
        ("winsock_getsockname(", "nextpas_windows"),
    )
    regex_expectations = (
        (
            re.compile(r"(?<!winsock_)getsockname\("),
            "getsockname(",
            "nextpas_unix",
        ),
    )

    for line_no, line in enumerate(source.splitlines(), 1):
        lower = line.lower()
        for token, guard in text_expectations:
            if token in lower and not line_has_required_guard(stack, guard):
                errors.append(
                    f"{SOURCE.name}:{line_no}: {token} must be guarded by {guard}"
                )
        for pattern, label, guard in regex_expectations:
            if pattern.search(lower) and not line_has_required_guard(stack, guard):
                errors.append(
                    f"{SOURCE.name}:{line_no}: {label} must be guarded by {guard}"
                )
        update_stack(lower, stack)
    return errors


def main() -> int:
    source = SOURCE.read_text()
    errors = check_guarded_host_references(source)
    if errors:
        print("platform.net source contract failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print("platform.net source contract passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

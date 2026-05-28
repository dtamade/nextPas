#!/usr/bin/env python3
"""
Convert fafafa.core FPCUnit tests to nextpas.core TTestRunner format.

Usage: python3 convert_tests.py <input.pas> <output.lpr> <module_name>

Transforms:
- FPCUnit TTestCase class → standalone procedures
- AssertEquals → CheckEqual
- AssertTrue/AssertFalse → Check
- CheckException → try/except blocks
- SetUp/TearDown → inline create/free per test
- fafafa.core.* → nextpas.core.*
"""

import sys
import re
from pathlib import Path


def convert_uses(line: str) -> str:
    """Replace fafafa.core with nextpas.core in uses clause."""
    line = line.replace('fafafa.core.', 'nextpas.core.')
    line = line.replace('fpcunit, testutils, testregistry,', '')
    line = line.replace('fpcunit, testutils, testregistry', '')
    line = line.replace('Classes, SysUtils,', 'SysUtils,')
    line = re.sub(r',\s*,', ',', line)
    line = re.sub(r'uses\s*,', 'uses', line)
    return line


def convert_assert(line: str) -> str:
    """Convert FPCUnit assertions to nextpas.core.testing."""
    # AssertEquals(expected, actual, 'msg') or AssertEquals(expected, actual)
    # For integers
    line = re.sub(
        r'AssertEquals\((\d+),\s*(.+?)\)',
        r"CheckEqual(Int64(\1), Int64(\2), '')",
        line
    )
    line = re.sub(
        r"AssertEquals\('([^']*)',\s*(\d+),\s*(.+?)\)",
        r"CheckEqual(Int64(\2), Int64(\3), '\1')",
        line
    )
    # AssertTrue
    line = re.sub(
        r"AssertTrue\('([^']*)',\s*(.+?)\)",
        r"Check(\2, '\1')",
        line
    )
    line = re.sub(
        r'AssertTrue\((.+?)\)',
        r"Check(\1, '')",
        line
    )
    # AssertFalse
    line = re.sub(
        r"AssertFalse\('([^']*)',\s*(.+?)\)",
        r"Check(not (\2), '\1')",
        line
    )
    line = re.sub(
        r'AssertFalse\((.+?)\)',
        r"Check(not (\1), '')",
        line
    )
    # Fail('msg')
    line = re.sub(
        r"Fail\('([^']*)'\)",
        r"Check(False, '\1')",
        line
    )
    return line


def convert_fafafa_symbols(line: str) -> str:
    """Replace FAFAFA_ symbols with NEXTPAS_."""
    line = line.replace('FAFAFA_CORE_', 'NEXTPAS_CORE_')
    line = line.replace('FAFAFA_COLLECTIONS_', 'NEXTPAS_COLLECTIONS_')
    line = line.replace('{$I fafafa.core.settings.inc}', '{$I nextpas.core.settings.inc}')
    return line


def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <input.pas> <output.lpr> <module_name>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    module_name = sys.argv[3]

    content = input_path.read_text(encoding='utf-8')

    # Apply basic transformations
    lines = content.split('\n')
    converted = []
    for line in lines:
        line = convert_fafafa_symbols(line)
        line = convert_uses(line)
        line = convert_assert(line)
        converted.append(line)

    result = '\n'.join(converted)
    output_path.write_text(result, encoding='utf-8')
    print(f"Converted {input_path} -> {output_path}")
    print(f"NOTE: This is a rough conversion. Manual review needed for:")
    print(f"  - SetUp/TearDown → inline create/free")
    print(f"  - CheckException patterns")
    print(f"  - Class method references")
    print(f"  - Program structure (unit → program)")


if __name__ == '__main__':
    main()

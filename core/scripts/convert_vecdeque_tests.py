#!/usr/bin/env python3
"""
Convert fafafa.core FPCUnit VecDeque tests to nextpas.core TTestRunner format.

Handles:
- Class-based TTestCase → standalone procedures
- SetUp/TearDown → inline create/free per test
- AssertEquals/AssertTrue/AssertFalse → CheckEqual/Check
- fafafa.core.* → nextpas.core.*
- FAFAFA_* → NEXTPAS_*
- Generates program .lpr with TTestRunner registration
"""

import re
import sys
from pathlib import Path


def extract_test_bodies(content: str) -> list:
    """Extract all test procedure implementations from the unit."""
    tests = []
    # Match: procedure TTestCase_VecDeque.Test_Xxx;
    pattern = re.compile(
        r'^procedure\s+TTestCase_VecDeque\.(Test_\w+)\s*;(.*?)(?=^procedure\s+TTestCase_VecDeque\.|^end\.)',
        re.MULTILINE | re.DOTALL
    )
    for m in pattern.finditer(content):
        name = m.group(1)
        body = m.group(2).strip()
        tests.append((name, body))
    return tests


def convert_body(body: str) -> str:
    """Convert a single test body from FPCUnit to TTestRunner style."""
    lines = body.split('\n')
    result = []
    for line in lines:
        # Skip empty SetUp-like calls (FVecDeque.Clear at start is fine)
        converted = line

        # AssertEquals('msg', SizeInt(x), SizeInt(y))
        converted = re.sub(
            r"AssertEquals\('([^']*)',\s*SizeInt\((\d+)\),\s*SizeInt\((.+?)\)\)",
            r"CheckEqual(Int64(\2), Int64(\3), '\1')",
            converted
        )
        # AssertEquals('msg', integer, expr)
        converted = re.sub(
            r"AssertEquals\('([^']*)',\s*(-?\d+),\s*(.+?)\)",
            r"CheckEqual(Int64(\2), Int64(\3), '\1')",
            converted
        )
        # AssertEquals(integer, expr) without msg
        converted = re.sub(
            r"AssertEquals\((-?\d+),\s*(.+?)\)",
            r"CheckEqual(Int64(\1), Int64(\2), '')",
            converted
        )
        # AssertTrue('msg', expr)
        converted = re.sub(
            r"AssertTrue\('([^']*)',\s*(.+?)\)",
            r"Check(\2, '\1')",
            converted
        )
        # AssertTrue(expr)
        converted = re.sub(
            r"AssertTrue\((.+?)\)",
            r"Check(\1, '')",
            converted
        )
        # AssertFalse('msg', expr)
        converted = re.sub(
            r"AssertFalse\('([^']*)',\s*(.+?)\)",
            r"Check(not (\2), '\1')",
            converted
        )
        # Fail('msg')
        converted = re.sub(
            r"Fail\('([^']*)'\)",
            r"Check(False, '\1')",
            converted
        )

        # Replace FVecDeque with LD
        converted = converted.replace('FVecDeque', 'LD')

        # fafafa → nextpas
        converted = converted.replace('fafafa.core.', 'nextpas.core.')
        converted = converted.replace('FAFAFA_CORE_', 'NEXTPAS_CORE_')
        converted = converted.replace('FAFAFA_COLLECTIONS_', 'NEXTPAS_COLLECTIONS_')

        # UnChecked → Unchecked (naming cleanup already done in nextpas)
        converted = converted.replace('UnChecked', 'Unchecked')

        result.append(converted)

    return '\n'.join(result)


def make_procedure_name(test_name: str) -> str:
    """Convert Test_Insert_Index_Element → TestInsertIndexElement."""
    parts = test_name.split('_')
    return ''.join(p.capitalize() for p in parts)


def generate_lpr(tests: list, module_name: str) -> str:
    """Generate the complete .lpr program file."""
    proc_names = []
    proc_bodies = []

    for name, body in tests:
        proc_name = make_procedure_name(name)
        proc_names.append(proc_name)

        converted_body = convert_body(body)

        # Wrap in procedure with local LD variable
        proc = f"""procedure {proc_name};
var
  LD: TVecDequeInt;
begin
  LD := TVecDequeInt.Create;
  try
{indent(converted_body, '    ')}
  finally
    LD.Free;
  end;
end;"""
        proc_bodies.append(proc)

    # Build registration block
    registrations = []
    for name, proc_name in zip([t[0] for t in tests], proc_names):
        human_name = name.replace('Test_', '').replace('_', ' ')
        registrations.append(f"  T.Run('{human_name}', @{proc_name});")

    return f"""program test_vecdeque_full;

{{$I nextpas.core.settings.inc}}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections.base,
  nextpas.core.collections.vecdeque;

type
  TVecDequeInt = specialize TVecDeque<Integer>;
  TIntegerArray = specialize TGenericArray<Integer>;

var
  T: TTestRunner;

{''.join(chr(10) + b + chr(10) for b in proc_bodies)}

begin
  T := TTestRunner.Create('{module_name}');
{chr(10).join(registrations)}
  T.Summary;
end.
"""


def indent(text: str, prefix: str) -> str:
    """Indent all lines of text."""
    lines = text.split('\n')
    return '\n'.join(prefix + line if line.strip() else line for line in lines)


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.pas> <output.lpr>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    content = input_path.read_text(encoding='utf-8')
    tests = extract_test_bodies(content)

    print(f"Found {len(tests)} test procedures")

    if not tests:
        print("ERROR: No tests found!")
        sys.exit(1)

    lpr = generate_lpr(tests, 'nextpas.core.collections.vecdeque.full')
    output_path.write_text(lpr, encoding='utf-8')
    print(f"Generated {output_path} with {len(tests)} tests")
    print("NOTE: Manual review needed for:")
    print("  - Helper methods (ExpectSeq, etc.) need to be inlined or extracted")
    print("  - CheckException patterns need try/except")
    print("  - Some tests may reference class fields beyond FVecDeque")


if __name__ == '__main__':
    main()

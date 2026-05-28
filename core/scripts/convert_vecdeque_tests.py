#!/usr/bin/env python3
"""
Convert fafafa.core FPCUnit VecDeque tests to nextpas.core TTestRunner format.
V2: Better handling of test structure, API name mapping, var blocks.
"""

import re
import sys
from pathlib import Path

# API name mappings (old fafafa → new nextpas)
API_RENAMES = {
    '.Remove(': '.RemoveAt(',
    '.RemoveSwap(': '.SwapRemoveAt(',
    '.TryRemove(': '.TryRemoveAt(',
    'OverWrite(': 'Overwrite(',
    'UnChecked': 'Unchecked',
    'FindIF(': 'FindIf(',
    'FindIFNot(': 'FindIfNot(',
    'CountIF(': 'CountIf(',
    'ReplaceIF(': 'ReplaceIf(',
    'SizeUint': 'SizeUInt',
}

# Symbols that should NOT be renamed (Remove is value-based in some contexts)
# We only rename .Remove( when preceded by a VecDeque variable


def apply_api_renames(line: str) -> str:
    """Apply API name mappings."""
    for old, new in API_RENAMES.items():
        line = line.replace(old, new)
    return line


def convert_asserts(line: str) -> str:
    """Convert FPCUnit assertions to TTestRunner."""
    # AssertEquals('msg', SizeInt(x), SizeInt(y))
    line = re.sub(
        r"AssertEquals\('([^']*)',\s*SizeInt\(([^)]+)\),\s*SizeInt\(([^)]+)\)\)",
        r"CheckEqual(Int64(\2), Int64(\3), '\1')",
        line
    )
    # AssertEquals('msg', Integer, expr) - integer literal
    line = re.sub(
        r"AssertEquals\('([^']*)',\s*(-?\d+),\s*(.+?)\)\s*;",
        r"CheckEqual(Int64(\2), Int64(\3), '\1');",
        line
    )
    # AssertEquals(Integer, expr) without msg
    line = re.sub(
        r"AssertEquals\((-?\d+),\s*(.+?)\)\s*;",
        r"CheckEqual(Int64(\1), Int64(\2), '');",
        line
    )
    # AssertEquals('msg', 'str', expr) - string
    line = re.sub(
        r"AssertEquals\('([^']*)',\s*'([^']*)',\s*(.+?)\)\s*;",
        r"CheckEqual('\2', \3, '\1');",
        line
    )
    # AssertTrue('msg', expr)
    line = re.sub(
        r"AssertTrue\('([^']*)',\s*(.+?)\)\s*;",
        r"Check(\2, '\1');",
        line
    )
    # AssertTrue(expr)
    line = re.sub(
        r"AssertTrue\((.+?)\)\s*;",
        r"Check(\1, '');",
        line
    )
    # AssertFalse('msg', expr)
    line = re.sub(
        r"AssertFalse\('([^']*)',\s*(.+?)\)\s*;",
        r"Check(not (\2), '\1');",
        line
    )
    # AssertFalse(expr)
    line = re.sub(
        r"AssertFalse\((.+?)\)\s*;",
        r"Check(not (\1), '');",
        line
    )
    # Fail('msg')
    line = re.sub(
        r"Fail\('([^']*)'\)\s*;",
        r"Check(False, '\1');",
        line
    )
    return line


def convert_symbols(line: str) -> str:
    """Replace fafafa symbols with nextpas."""
    line = line.replace('fafafa.core.', 'nextpas.core.')
    line = line.replace('FAFAFA_CORE_', 'NEXTPAS_CORE_')
    line = line.replace('FAFAFA_COLLECTIONS_', 'NEXTPAS_COLLECTIONS_')
    line = line.replace('{$I fafafa.core.settings.inc}', '{$I nextpas.core.settings.inc}')
    return line


def extract_tests(content: str) -> list:
    """Extract test procedure implementations."""
    # Split on procedure boundaries
    parts = re.split(r'^(procedure\s+TTestCase_VecDeque\.)', content, flags=re.MULTILINE)

    tests = []
    i = 1
    while i < len(parts) - 1:
        header = parts[i]  # "procedure TTestCase_VecDeque."
        body = parts[i + 1]

        # Extract name and body
        m = re.match(r'(Test_\w+)\s*;(.*)', body, re.DOTALL)
        if m:
            name = m.group(1)
            impl = m.group(2).strip()
            # Find the end of this procedure (next 'end;' at indent 0)
            # Simple heuristic: find 'end;' followed by newline
            end_match = re.search(r'^end;', impl, re.MULTILINE)
            if end_match:
                impl = impl[:end_match.end()]
            tests.append((name, impl))
        i += 2

    return tests


def make_proc_name(test_name: str) -> str:
    """Test_Insert_Index_Element → TestInsertIndexElement"""
    parts = test_name.split('_')
    return ''.join(p.capitalize() for p in parts)


def convert_test_body(name: str, body: str) -> str:
    """Convert a single test body."""
    lines = body.split('\n')
    result = []
    in_begin = False
    begin_injected = False
    for line in lines:
        line = convert_symbols(line)
        line = convert_asserts(line)
        line = apply_api_renames(line)
        line = line.replace('FVecDeque', 'LD')

        # Inject LD := Create after first 'begin'
        if not begin_injected and re.match(r'^\s*begin\s*$', line):
            result.append(line)
            result.append('  LD := TVecDequeInt.Create;')
            result.append('  try')
            in_begin = True
            begin_injected = True
            continue

        # Replace final 'end;' with 'finally LD.Free; end;'
        if in_begin and re.match(r'^end;', line):
            result.append('  finally')
            result.append('    LD.Free;')
            result.append('  end;')
            result.append('end;')
            in_begin = False
            continue

        # Indent body inside try block
        if in_begin and begin_injected:
            if line.strip():
                result.append('  ' + line)
            else:
                result.append(line)
        else:
            result.append(line)

    return '\n'.join(result)


def generate_output(tests: list) -> str:
    """Generate the complete .lpr file."""
    # Header
    header = """program test_vecdeque_full;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.vecdeque.base,
  nextpas.core.collections.vecdeque;

type
  TVecDequeInt = specialize TVecDeque<Integer>;
  TIntegerArray = specialize TGenericArray<Integer>;
  TCompareFunc = specialize TCompareFunc<Integer>;

function CompareInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  if A < B then Result := -1
  else if A > B then Result := 1
  else Result := 0;
end;

function CompareIntDesc(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := CompareInt(B, A, aData);
end;

var
  T: TTestRunner;

"""

    # Procedures
    procs = []
    registrations = []

    for name, body in tests:
        proc_name = make_proc_name(name)
        converted = convert_test_body(name, body)

        # Check if body already has var block with LD
        if 'LD: TVecDequeInt' not in converted:
            # Inject var LD declaration
            converted = re.sub(
                r'^(\s*var\b)',
                r'\1\n  LD: TVecDequeInt;',
                converted,
                count=1,
                flags=re.MULTILINE
            )
            if 'var' not in converted.split('begin')[0]:
                # No var block at all - add one
                converted = f"var\n  LD: TVecDequeInt;\n{converted}"

        proc = f"procedure {proc_name};\n{converted}\n"
        procs.append(proc)

        human_name = name.replace('Test_', '').replace('_', ' ')
        registrations.append(f"  T.Run('{human_name}', @{proc_name});")

    # Footer
    footer = f"""
begin
  T := TTestRunner.Create('nextpas.core.collections.vecdeque.full');
{chr(10).join(registrations)}
  T.Summary;
end.
"""

    return header + '\n'.join(procs) + footer


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.pas> <output.lpr>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    content = input_path.read_text(encoding='utf-8')

    # Skip helper methods (SetUp, TearDown, ExpectSeq, etc.)
    # Only extract Test_* procedures
    tests = extract_tests(content)
    print(f"Extracted {len(tests)} test procedures")

    output = generate_output(tests)
    output_path.write_text(output, encoding='utf-8')
    print(f"Written to {output_path} ({len(output)} bytes)")


if __name__ == '__main__':
    main()

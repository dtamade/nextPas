#!/usr/bin/env python3
"""Migrate mem test files from nextpas.core.testing to nextpas.core.test.

Transformations:
  1. uses nextpas.core.testing -> nextpas.core.test
  2. TTestRunner.Create -> TTestSuite.Create (var type stays TTestRunner -> TTestSuite)
  3. T.Run( -> T.Test(
  4. CheckEqual(a, b, 'msg') -> Check(a = b, 'msg')
  5. CheckEqual(a, b) -> CheckEqual(a, b)  (no change — already compatible)
"""
import re
import sys
from pathlib import Path

def find_checkequal_args(s, start):
    """Find the 3 arguments of CheckEqual(paren_content, starting after 'CheckEqual('.
    Returns (arg1, arg2, arg3, end_pos) or None.
    Handles nested parens and string literals."""
    depth = 1
    i = start
    args = []
    current_start = start
    in_string = False

    while i < len(s) and depth > 0:
        ch = s[i]
        if in_string:
            if ch == "'":
                if i + 1 < len(s) and s[i + 1] == "'":
                    i += 2  # skip escaped quote
                    continue
                in_string = False
            i += 1
            continue

        if ch == "'":
            in_string = True
            i += 1
            continue

        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                args.append(s[current_start:i].strip())
                return args, i + 1
        elif ch == ',' and depth == 1:
            args.append(s[current_start:i].strip())
            current_start = i + 1

        i += 1

    return None, start


def migrate_checkequal(content):
    """Convert CheckEqual(a, b, msg) -> Check(a = b, msg)."""
    result = []
    i = 0
    pattern = 'CheckEqual('

    while i < len(content):
        idx = content.find(pattern, i)
        if idx == -1:
            result.append(content[i:])
            break

        # Add everything before this match
        result.append(content[i:idx])

        # Parse the arguments
        args, end = find_checkequal_args(content, idx + len(pattern))

        if args is None or len(args) not in (2, 3):
            # Can't parse — keep original
            result.append(content[idx:end])
            i = end
            continue

        if len(args) == 2:
            # CheckEqual(a, b) — compatible with new API, keep as-is
            result.append(f'CheckEqual({args[0]}, {args[1]})')
        else:
            # CheckEqual(a, b, msg) -> Check(a = b, msg)
            a, b, msg = args
            result.append(f'Check({a} = {b}, {msg})')

        i = end

    return ''.join(result)


def migrate_file(path):
    """Migrate a single .lpr file."""
    content = path.read_text()
    original = content

    # 1. uses directive
    content = content.replace('nextpas.core.testing', 'nextpas.core.test')

    # 2. TTestRunner -> TTestSuite (in variable declarations and Create calls)
    content = content.replace('TTestRunner', 'TTestSuite')

    # 3. T.Run( -> T.Test(
    # Only replace the method call pattern, not arbitrary .Run(
    # Pattern: variable_name followed by .Run(
    # We need to be careful not to replace .Run in other contexts
    # Since we changed TTestSuite, the runner variable is still 'T'
    # The pattern is typically: T.Run(
    content = re.sub(r'(\bT)\.Run\(', r'\1.Test(', content)

    # 4. CheckEqual conversion
    content = migrate_checkequal(content)

    # 5. Insert T.Run; before T.Summary; (new framework needs explicit Run)
    content = re.sub(r'(\s+)(T\.Summary;)', r'\1T.Run;\n\1\2', content)

    if content != original:
        path.write_text(content)
        return True
    return False


def main():
    test_dir = Path('core/tests/nextpas.core.mem')
    migrated = 0
    skipped = 0

    for lpr in sorted(test_dir.glob('test_*/*.lpr')):
        text = lpr.read_text()
        if 'nextpas.core.testing' not in text:
            skipped += 1
            continue
        if migrate_file(lpr):
            print(f'  MIGRATED: {lpr.parent.name}')
            migrated += 1
        else:
            print(f'  UNCHANGED: {lpr.parent.name}')
            skipped += 1

    print(f'\nMigrated: {migrated}, Skipped: {skipped}')


if __name__ == '__main__':
    main()

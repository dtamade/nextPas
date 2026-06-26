#!/usr/bin/env python3
"""Migrate old TBenchRunner benchmarks to TBenchSuite fluent API.

Transforms:
  VARNAME := TBenchRunner.Create;
  try
    VARNAME.Run('name', @Func);
    VARNAME.Summary;
  finally
    VARNAME.Free;
  end;

Into:
  LResults := TBenchSuite.Create('SuiteName')
    .AddLoop('name', @Func)
    .Run;
  WriteLn(LResults.PrintToConsole);
"""
import re
from pathlib import Path


def migrate_content(content):
    lines = content.split('\n')
    result = []
    i = 0
    changed = False

    # Detect variable name used for TBenchRunner
    var_name = None
    for line in lines:
        m = re.match(r'\s*(\w+):\s*TBenchRunner;', line)
        if m:
            var_name = m.group(1)
            break

    if not var_name:
        return content, False

    # Skip files that subclass TBenchRunner
    if re.search(r'class\(' + re.escape(var_name) + r'\)', content):
        return content, False
    # Also check for subclass pattern: SomeName = class(TBenchRunner)
    if re.search(r'=\s*class\s*\(\s*TBenchRunner\s*\)', content):
        return content, False

    v = re.escape(var_name)

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Replace variable declaration: VARNAME: TBenchRunner; → LResults: IBenchResults;
        if re.match(rf'\s*{v}:\s*TBenchRunner;', line):
            indent = re.match(r'(\s*)', line).group(1)
            result.append(f'{indent}LResults: IBenchResults;')
            changed = True
            i += 1
            continue

        # Skip: VARNAME := TBenchRunner.Create;
        if re.match(rf'\s*{v}\s*:=\s*TBenchRunner\.Create\s*;', line):
            changed = True
            i += 1
            continue

        # Detect start of try block with VARNAME.Run calls
        if stripped == 'try':
            j = i + 1
            has_run = False
            run_calls = []
            summary_line = -1
            finally_line = -1

            while j < len(lines):
                s = lines[j].strip()
                if s == '':
                    j += 1
                    continue
                m = re.match(rf"{v}\.Run\('([^']+)',\s*@(\w+)\);", s)
                if m:
                    has_run = True
                    run_calls.append((m.group(1), m.group(2)))
                    j += 1
                    continue
                if s == f'{var_name}.Summary;':
                    summary_line = j
                    j += 1
                    continue
                if s == 'finally':
                    finally_line = j
                    j += 1
                    continue
                if s == f'{var_name}.Free;':
                    j += 1
                    continue
                if s == 'end;':
                    break
                # Other code — not a simple try/Run/finally pattern
                break

            if has_run and summary_line >= 0 and finally_line >= 0:
                first_name = run_calls[0][0]
                if '/' in first_name:
                    suite_name = first_name.split('/')[0]
                else:
                    parts = first_name.split('.')
                    suite_name = parts[0] if parts else 'Benchmark'

                indent = re.match(r'(\s*)', line).group(1)

                result.append(f"{indent}LResults := TBenchSuite.Create('{suite_name}')")
                for name, func in run_calls:
                    result.append(f"{indent}  .AddLoop('{name}', @{func})")
                result.append(f"{indent}  .Run;")
                result.append(f"{indent}WriteLn(LResults.PrintToConsole);")

                i = j + 1
                changed = True
                continue

        # Also handle non-try/finally pattern: direct Run calls followed by Summary
        # Pattern: VARNAME.Run(...); ... VARNAME.Summary;  (no try/finally)
        m = re.match(rf"\s*{v}\.Run\('([^']+)',\s*@(\w+)\);", stripped)
        if m:
            # Collect consecutive Run calls (allow blank lines and WriteLn between)
            run_calls_local = []
            j = i
            pending_passthrough = []  # non-Run lines between Run calls
            while j < len(lines):
                s = lines[j].strip()
                rm = re.match(rf"{v}\.Run\('([^']+)',\s*@(\w+)\);", s)
                if rm:
                    run_calls_local.append((rm.group(1), rm.group(2)))
                    j += 1
                    continue
                if s == '' or s.startswith('WriteLn'):
                    # Skip blank lines and WriteLn between/after Run calls
                    j += 1
                    continue
                if s == f'{var_name}.Summary;' or s == f'{var_name}.Summary':
                    j += 1
                    continue
                if s == f'{var_name}.Free;' or s == f'{var_name}.Free':
                    j += 1
                    continue
                if s == 'end;':
                    # End of begin/end block — proceed with migration
                    break
                # Other code found — abort non-try migration for this block
                break

            if run_calls_local:
                first_name = run_calls_local[0][0]
                if '/' in first_name:
                    suite_name = first_name.split('/')[0]
                else:
                    parts = first_name.split('.')
                    suite_name = parts[0] if parts else 'Benchmark'

                indent = re.match(r'(\s*)', lines[i]).group(1)

                result.append(f"{indent}LResults := TBenchSuite.Create('{suite_name}')")
                for name, func in run_calls_local:
                    result.append(f"{indent}  .AddLoop('{name}', @{func})")
                result.append(f"{indent}  .Run;")
                result.append(f"{indent}WriteLn(LResults.PrintToConsole);")

                i = j
                changed = True
                continue

        result.append(line)
        i += 1

    if changed:
        content_out = '\n'.join(result)
        content_out = re.sub(r'\n{4,}', '\n\n\n', content_out)
        return content_out, True
    return content, False


def migrate_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    if 'TBenchRunner' not in content:
        return False

    new_content, changed = migrate_content(content)

    if changed:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"  OK: {filepath}")
        return True
    else:
        print(f"  SKIP: {filepath}")
        return False


def main():
    base = Path('/home/dtamade/projects/nextPas/.worktrees/bench-framework/core/benchmarks')

    files = []
    for lpr in sorted(base.rglob('*.lpr')):
        with open(lpr) as f:
            if 'TBenchRunner' in f.read():
                files.append(lpr)

    print(f"Found {len(files)} files to migrate\n")

    migrated = 0
    for f in files:
        if migrate_file(str(f)):
            migrated += 1

    print(f"\nDone: {migrated}/{len(files)} migrated")


if __name__ == '__main__':
    main()

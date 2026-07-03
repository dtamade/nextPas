#!/usr/bin/env python3
"""Convert simple core test Makefiles to use common.mk include.

Finds Makefiles matching the standard template pattern and replaces
them with a minimal 2-line Makefile that includes common.mk.

Preserves any extra FPC_FLAGS += lines that differ from the template.
"""

import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COMMON_MK = os.path.join(REPO_ROOT, 'core', 'tests', 'common.mk')

TEMPLATE_FPC_FLAGS = {
    '-MObjFPC', '-Sh', '-O2', '-gl', '-gh',
}

TEMPLATE_VARS = {
    'FPC', 'CORE_ROOT', 'BUILD_DIR', 'PROGRAM', 'SOURCE', 'FPC_FLAGS',
}

TEMPLATE_TARGETS = {'build', 'run', 'test', 'clean'}


def parse_makefile(path):
    """Parse a Makefile into variable assignments and rule bodies."""
    variables = {}
    rules = {}
    current_rule = None
    extra_fpc_flags = []

    with open(path) as f:
        for line in f:
            line = line.rstrip('\n')
            stripped = line.strip()

            # Variable assignment
            m = re.match(r'^(\w+)\s*([?:]?=)\s*(.*)$', stripped)
            if m:
                name, op, value = m.group(1), m.group(2), m.group(3)
                variables[name] = (op, value)
                # Track extra FPC_FLAGS
                if name == 'FPC_FLAGS' and op == '+=':
                    flags = value.split()
                    for flag in flags:
                        if flag not in TEMPLATE_FPC_FLAGS and not flag.startswith(('-FU', '-FE', '-Fu', '-Fi')):
                            extra_fpc_flags.append(flag)
                continue

            # Rule target
            m = re.match(r'^([\w.-]+)\s*:', stripped)
            if m:
                current_rule = m.group(1)
                rules[current_rule] = []
                continue

            # Rule body line
            if current_rule and (line.startswith('\t') or stripped == ''):
                rules[current_rule].append(line)

    return variables, rules, extra_fpc_flags


def is_template_makefile(variables, rules):
    """Check if this Makefile matches the standard template."""
    required_vars = {'FPC', 'CORE_ROOT', 'BUILD_DIR', 'PROGRAM', 'SOURCE', 'FPC_FLAGS'}
    if not required_vars.issubset(variables.keys()):
        return False

    required_targets = {'build', 'run', 'test', 'clean'}
    if not required_targets.issubset(rules.keys()):
        return False

    # Check CORE_ROOT pattern
    op, value = variables['CORE_ROOT']
    if op != ':=' or '../../..' not in value:
        return False

    # Check BUILD_DIR pattern
    op, value = variables['BUILD_DIR']
    if op != '?=' or 'CORE_ROOT' not in value:
        return False

    return True


def convert_makefile(path, program_name, extra_flags):
    """Write a minimal Makefile that includes common.mk."""
    lines = [f'PROGRAM := {program_name}']
    lines.append('include ../../common.mk')
    if extra_flags:
        lines.append(f'FPC_FLAGS += {" ".join(extra_flags)}')
    lines.append('')  # trailing newline

    with open(path, 'w') as f:
        f.write('\n'.join(lines))


def main():
    dry_run = '--dry-run' in sys.argv
    verbose = '--verbose' in sys.argv or '-v' in sys.argv

    core_tests_dir = os.path.join(REPO_ROOT, 'core', 'tests')
    converted = 0
    skipped = 0
    errors = 0

    for root, dirs, files in os.walk(core_tests_dir):
        if 'Makefile' not in files:
            continue
        if 'common.mk' in os.path.basename(root):
            continue

        makefile_path = os.path.join(root, 'Makefile')
        variables, rules, extra_flags = parse_makefile(makefile_path)

        if not is_template_makefile(variables, rules):
            skipped += 1
            if verbose:
                print(f'SKIP (non-template): {os.path.relpath(makefile_path, REPO_ROOT)}')
            continue

        # Get program name
        if 'PROGRAM' not in variables:
            skipped += 1
            continue

        _, program_value = variables['PROGRAM']
        program_name = program_value.strip()

        # Verify PROGRAM matches directory name
        dir_name = os.path.basename(root)
        if program_name != dir_name and verbose:
            print(f'NOTE: PROGRAM={program_name} != dir={dir_name} in {os.path.relpath(makefile_path, REPO_ROOT)}')

        rel_path = os.path.relpath(makefile_path, REPO_ROOT)
        if dry_run:
            print(f'WOULD CONVERT: {rel_path} (PROGRAM={program_name}, extra_flags={extra_flags})')
            converted += 1
        else:
            if verbose:
                print(f'CONVERT: {rel_path}')
            try:
                convert_makefile(makefile_path, program_name, extra_flags)
                converted += 1
            except Exception as e:
                print(f'ERROR: {rel_path}: {e}', file=sys.stderr)
                errors += 1

    print(f'\nSummary: {converted} converted, {skipped} skipped, {errors} errors')
    if dry_run:
        print('(dry run — no files modified)')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""simdgen self-test — validates the code generator's internal consistency."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'simdgen'))
from simdgen import Registry, gen_signature

import subprocess

def main():
    registry = Registry()
    registry.load_all()

    errors = []

    # 1. Registry completeness
    if len(registry.types) < 20:
        errors.append(f'Expected 20+ types, got {len(registry.types)}')
    if len(registry.operations) < 50:
        errors.append(f'Expected 50+ ops, got {len(registry.operations)}')
    if len(registry.slots) < 400:
        errors.append(f'Expected 400+ slots, got {len(registry.slots)}')

    # 2. No duplicate slot names
    slot_names = [s.dispatch_field for s in registry.slots]
    dupes = set(n for n in slot_names if slot_names.count(n) > 1)
    if dupes:
        errors.append(f'Duplicate slots: {dupes}')

    # 3. All signatures valid
    for slot in registry.slots:
        sig = gen_signature(slot)
        if 'unknown' in sig:
            errors.append(f'Unknown sig for {slot.dispatch_field}')
            break

    # 4. Naming conventions
    for slot in registry.slots:
        if slot.type_info is None:
            if slot.facade_name != slot.dispatch_field:
                errors.append(f'Bad helper facade name: {slot.facade_name}')
                break
            if not (slot.scalar_name.endswith('_Scalar') or slot.scalar_name.startswith('Scalar')):
                errors.append(f'Bad helper scalar name: {slot.scalar_name}')
                break
            continue
        if not (slot.facade_name.startswith('Vec') or slot.facade_name.startswith('Mask')):
            errors.append(f'Bad facade name: {slot.facade_name}')
            break
        if not slot.scalar_name.startswith('Scalar'):
            errors.append(f'Bad scalar name: {slot.scalar_name}')
            break

    # 5. Audit produces zero mismatches
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    result = subprocess.run(
        [sys.executable, os.path.join(project_root, 'tools', 'simdgen', 'simdgen.py'), '--audit'],
        capture_output=True, text=True, cwd=project_root
    )
    if 'mismatched=0' not in result.stdout:
        errors.append('Audit has signature mismatches')
    if 'extra=0' not in result.stdout:
        errors.append('Audit has extra slots')

    if errors:
        print(f'SIMDGEN SELF-TEST FAILED ({len(errors)} errors):')
        for e in errors:
            print(f'  - {e}')
        return 1
    else:
        print('SIMDGEN SELF-TEST OK')
        print(f'  types={len(registry.types)} ops={len(registry.operations)} slots={len(registry.slots)}')
        print(f'  no duplicates, no unknown signatures, naming conventions correct')
        print(f'  audit: 0 mismatches, 0 extras')
        return 0


if __name__ == '__main__':
    sys.exit(main())

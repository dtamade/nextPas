#!/usr/bin/env python3
"""
simdgen_dispatch.py - Dispatch table code generator

Generates Pascal code from dispatch_slots.json:
  --record     → TSimdDispatchTable record field declarations
  --defaults   → FillBaseDispatchTable scalar fallback assignments
  --facade     → Facade unit inline wrappers (batch slots only)
  --verify     → Compare generated vs handwritten, report diffs

Usage:
    python3 tools/simdgen/simdgen_dispatch.py --verify
    python3 tools/simdgen/simdgen_dispatch.py --record > generated_record.inc
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SLOTS_JSON = Path(__file__).parent / "ops" / "dispatch_slots.json"
DISPATCH_PAS = ROOT / "src" / "nextpas.core.simd.dispatch.pas"


def load_slots() -> list[dict]:
    with open(SLOTS_JSON) as f:
        data = json.load(f)
    return data["slots"]


def generate_record_fields(slots: list[dict]) -> str:
    """Generate record field declarations."""
    lines = []
    current_section = ""
    for s in slots:
        sec = s.get("section", "")
        if sec != current_section:
            if current_section:
                lines.append("")
            lines.append(f"    // {sec}")
            current_section = sec

        ret = f": {s['return_type']}" if s["return_type"] else ""
        lines.append(f"    {s['name']}: {s['kind']}({s['params']}){ret};")
    return "\n".join(lines)


def generate_scalar_defaults(slots: list[dict]) -> str:
    """Generate FillBaseDispatchTable assignments."""
    lines = []
    for s in slots:
        scalar_name = f"Scalar{s['name']}"
        lines.append(f"  dispatchTable.{s['name']} := @{scalar_name};")
    return "\n".join(lines)


def extract_handwritten_record() -> list[str]:
    """Extract current record fields from dispatch.pas."""
    content = DISPATCH_PAS.read_text()
    start = content.find("TSimdDispatchTable = record")
    chunk = content[start:start+50000]
    end_match = re.search(r'^\s*end;', chunk, re.MULTILINE)
    if not end_match:
        return []
    record_body = chunk[:end_match.start()]
    field_re = re.compile(r'^\s+(\w+)\s*:\s*(function|procedure)', re.MULTILINE)
    return [m.group(1) for m in field_re.finditer(record_body)]


def verify():
    """Compare JSON slot list against handwritten dispatch table."""
    slots = load_slots()
    json_names = [s["name"] for s in slots]
    handwritten_names = extract_handwritten_record()

    json_set = set(json_names)
    hw_set = set(handwritten_names)

    missing_in_json = hw_set - json_set
    extra_in_json = json_set - hw_set

    print(f"=== Dispatch Slot Sync Verification ===")
    print(f"JSON defines: {len(json_set)} slots")
    print(f"Handwritten:  {len(hw_set)} slots")
    print()

    if not missing_in_json and not extra_in_json:
        print("✓ Perfect sync — JSON matches handwritten record exactly")
        # Check order
        order_ok = json_names == handwritten_names
        if order_ok:
            print("✓ Order matches")
        else:
            print("⚠ Order differs (functionally equivalent)")
        return 0

    if missing_in_json:
        print(f"✗ In handwritten but NOT in JSON ({len(missing_in_json)}):")
        for n in sorted(missing_in_json):
            print(f"    + {n}")
    if extra_in_json:
        print(f"✗ In JSON but NOT in handwritten ({len(extra_in_json)}):")
        for n in sorted(extra_in_json):
            print(f"    - {n}")

    return 1 if missing_in_json or extra_in_json else 0


def generate_batch_facade_decl(slots: list[dict]) -> str:
    """Generate facade unit interface declarations for batch slots."""
    batch = [s for s in slots if s["category"] == "batch"]
    lines = ["// Auto-generated batch slot declarations (from dispatch_slots.json)"]
    for s in batch:
        ret = f": {s['return_type']}" if s["return_type"] else ""
        lines.append(f"{s['kind']} {s['name']}({s['params']}){ret}; inline;")
    return "\n".join(lines)


def generate_batch_facade_impl(slots: list[dict]) -> str:
    """Generate facade unit implementation for batch slots."""
    batch = [s for s in slots if s["category"] == "batch"]
    lines = ["// Auto-generated batch slot implementations (from dispatch_slots.json)"]
    for s in batch:
        ret = f": {s['return_type']}" if s["return_type"] else ""
        is_func = s["kind"] == "function"

        # Parse param names for forwarding
        params_raw = s["params"]
        param_names = []
        for part in params_raw.split(";"):
            part = part.strip()
            if not part:
                continue
            # Remove 'const ', 'var ', 'out '
            part = re.sub(r'^(const|var|out)\s+', '', part)
            # Get names before ':'
            names_part = part.split(":")[0].strip()
            for n in names_part.split(","):
                param_names.append(n.strip())

        forward_args = ", ".join(param_names)

        lines.append("")
        lines.append(f"{s['kind']} {s['name']}({s['params']}){ret};")
        lines.append("var LDispatch: PSimdDispatchTable;")
        lines.append("begin")
        lines.append("  LDispatch := GetSimdFacadeDispatchFastPath;")
        if is_func:
            lines.append(f"  Result := LDispatch^.{s['name']}({forward_args});")
        else:
            lines.append(f"  LDispatch^.{s['name']}({forward_args});")
        lines.append("end;")
    return "\n".join(lines)


def generate_all(output_dir: Path):
    """Generate all .inc files to output directory."""
    slots = load_slots()
    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Record fields
    record_code = generate_record_fields(slots)
    (output_dir / "dispatch_slots.generated.inc").write_text(
        f"// Auto-generated from dispatch_slots.json ({len(slots)} slots)\n"
        f"// DO NOT EDIT — regenerate with: python3 tools/simdgen/simdgen_dispatch.py --generate-all\n\n"
        + record_code + "\n"
    )

    # 2. Scalar defaults
    defaults_code = generate_scalar_defaults(slots)
    (output_dir / "dispatch_defaults.generated.inc").write_text(
        f"// Auto-generated scalar defaults ({len(slots)} slots)\n"
        f"// DO NOT EDIT — regenerate with: python3 tools/simdgen/simdgen_dispatch.py --generate-all\n\n"
        + defaults_code + "\n"
    )

    # 3. Batch facade declarations
    batch_slots = [s for s in slots if s["category"] == "batch"]
    decl_code = generate_batch_facade_decl(slots)
    (output_dir / "batch_facade_decl.generated.inc").write_text(
        f"// Auto-generated batch facade declarations ({len(batch_slots)} slots)\n"
        f"// DO NOT EDIT — regenerate with: python3 tools/simdgen/simdgen_dispatch.py --generate-all\n\n"
        + decl_code + "\n"
    )

    # 4. Batch facade implementations
    impl_code = generate_batch_facade_impl(slots)
    (output_dir / "batch_facade_impl.generated.inc").write_text(
        f"// Auto-generated batch facade implementations ({len(batch_slots)} slots)\n"
        f"// DO NOT EDIT — regenerate with: python3 tools/simdgen/simdgen_dispatch.py --generate-all\n\n"
        + impl_code + "\n"
    )

    print(f"Generated 4 files in {output_dir}/:")
    print(f"  dispatch_slots.generated.inc      ({len(slots)} record fields)")
    print(f"  dispatch_defaults.generated.inc   ({len(slots)} scalar assignments)")
    print(f"  batch_facade_decl.generated.inc   ({len(batch_slots)} declarations)")
    print(f"  batch_facade_impl.generated.inc   ({len(batch_slots)} implementations)")


def main():
    if len(sys.argv) < 2:
        print("Usage: simdgen_dispatch.py [--verify|--record|--defaults|--generate-all]")
        return 1

    cmd = sys.argv[1]
    if cmd == "--verify":
        return verify()
    elif cmd == "--record":
        slots = load_slots()
        print(generate_record_fields(slots))
    elif cmd == "--defaults":
        slots = load_slots()
        print(generate_scalar_defaults(slots))
    elif cmd == "--generate-all":
        output_dir = ROOT / "src" / "generated"
        generate_all(output_dir)
    else:
        print(f"Unknown command: {cmd}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

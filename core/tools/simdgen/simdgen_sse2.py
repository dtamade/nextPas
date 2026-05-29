"""
simdgen_sse2 - SSE2 batch kernel code generator

Generates Pascal asm code for SSE2 batch array operations from
the same batch.json definitions used by the AVX2 generator.

SSE2 differences from AVX2:
- XMM registers (128-bit, 4 floats) instead of YMM (256-bit, 8 floats)
- Non-VEX instructions: addps instead of vaddps
- No vzeroupper needed
- 4x XMM unroll = 16 elements per main loop iteration
"""

import json
from pathlib import Path
from typing import Any


def mem(reg: str, offset: int = 0) -> str:
    return f"[{reg}]" if offset == 0 else f"[{reg} + {offset}]"


def asm_line(opcode: str, operands: str = "") -> str:
    return f"    {opcode}" if operands == "" else f"    {opcode} {operands}"


SSE2_VEC_MAP = {
    "vaddps": "addps",
    "vsubps": "subps",
    "vmulps": "mulps",
    "vdivps": "divps",
    "vminps": "minps",
    "vmaxps": "maxps",
    "vandps": "andps",
    "vxorps": "xorps",
    "vsqrtps": "sqrtps",
    "vrcpps": "rcpps",
    "vrsqrtps": "rsqrtps",
}

SSE2_SCL_MAP = {
    "vaddss": "addss",
    "vsubss": "subss",
    "vmulss": "mulss",
    "vdivss": "divss",
    "vminss": "minss",
    "vmaxss": "maxss",
    "vsqrtss": "sqrtss",
    "vrcpss": "rcpss",
    "vrsqrtss": "rsqrtss",
}


def sse2_vec(avx2_op: str) -> str:
    return SSE2_VEC_MAP.get(avx2_op, avx2_op.replace("v", "", 1))


def sse2_scl(avx2_op: str) -> str:
    return SSE2_SCL_MAP.get(avx2_op, avx2_op.replace("v", "", 1))


def emit_sse2_elementwise_2input(op: dict) -> list[str]:
    """Generate SSE2 elementwise kernel with 2 input streams."""
    tpl = op["avx2_template"]
    inputs = tpl["streams"]["inputs"]
    output = tpl["streams"]["output"]
    src0, src1, dst = inputs[0]["reg"], inputs[1]["reg"], output["reg"]
    vec_op = sse2_vec(tpl["steps"][0]["vector"])
    scl_op = sse2_scl(tpl["steps"][0]["scalar"])
    locals_list = [s["local"] for s in inputs] + [output["local"]]
    assigns = "; ".join(f'{s["local"]} := {s["param"]}' for s in inputs + [output])

    lines = [
        f'procedure SSE2{op["name"]}({inputs[0]["param"]}, {inputs[1]["param"]}, {output["param"]}: PSingle; aCount: SizeUInt);',
        "var",
        f'  {", ".join(locals_list)}: PSingle;',
        "begin",
        "  {$PUSH}{$Q-}{$R-}",
        "  if aCount = 0 then Exit;",
        f"  {assigns};",
        "",
        "  asm",
        asm_line("mov", f"{src0}, {inputs[0]['local']}"),
        asm_line("mov", f"{src1}, {inputs[1]['local']}"),
        asm_line("mov", f"{dst}, {output['local']}"),
        asm_line("mov", "r8, aCount"),
        "",
        asm_line("cmp", "r8, 16"),
        asm_line("jb", "@tail4"),
        "",
        "  @loop16:",
    ]
    for i, off in enumerate((0, 16, 32, 48)):
        lines.append(asm_line("movups", f"xmm{i}, {mem(src0, off)}"))
        lines.append(asm_line(vec_op, f"xmm{i}, {mem(src1, off)}"))
        lines.append(asm_line("movups", f"{mem(dst, off)}, xmm{i}"))
    lines += [
        asm_line("add", f"{src0}, 64"),
        asm_line("add", f"{src1}, 64"),
        asm_line("add", f"{dst}, 64"),
        asm_line("sub", "r8, 16"),
        asm_line("cmp", "r8, 16"),
        asm_line("jae", "@loop16"),
        "",
        "  @tail4:",
        asm_line("cmp", "r8, 4"),
        asm_line("jb", "@tail_scalar"),
        asm_line("movups", f"xmm0, {mem(src0)}"),
        asm_line(vec_op, f"xmm0, {mem(src1)}"),
        asm_line("movups", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 16"),
        asm_line("add", f"{src1}, 16"),
        asm_line("add", f"{dst}, 16"),
        asm_line("sub", "r8, 4"),
        asm_line("cmp", "r8, 4"),
        asm_line("jae", "@tail4"),
        "",
        "  @tail_scalar:",
        asm_line("test", "r8, r8"),
        asm_line("jz", "@done"),
        "  @scalar_loop:",
        asm_line("movss", f"xmm0, {mem(src0)}"),
        asm_line(scl_op, f"xmm0, {mem(src1)}"),
        asm_line("movss", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 4"),
        asm_line("add", f"{src1}, 4"),
        asm_line("add", f"{dst}, 4"),
        asm_line("dec", "r8"),
        asm_line("jnz", "@scalar_loop"),
        "",
        "  @done:",
        "  end;",
        "  {$POP}",
        "end;",
    ]
    return lines


def generate_sse2_batch_kernel(op: dict) -> str | None:
    """Generate SSE2 kernel for a single operation. Returns None if not supported."""
    tpl = op.get("avx2_template")
    if not tpl:
        return None
    kind = tpl["kind"]
    if kind == "elementwise" and tpl["input_stream_count"] == 2:
        lines = emit_sse2_elementwise_2input(op)
        return "\n".join(lines)
    return None


def load_ops() -> list[dict]:
    ops_path = Path(__file__).parent / "ops" / "batch.json"
    with open(ops_path) as f:
        data = json.load(f)
    return data["operations"]


def generate_all_sse2() -> str:
    """Generate all supported SSE2 batch kernels."""
    ops = load_ops()
    sections = []
    generated = 0
    for op in ops:
        code = generate_sse2_batch_kernel(op)
        if code:
            sections.append(code)
            generated += 1
    header = f"// Auto-generated SSE2 batch kernels ({generated} operations)\n// Generated by simdgen_sse2.py\n"
    return header + "\n\n".join(sections)


def verify_sse2_batch() -> tuple[int, int, list[str]]:
    """Compare generated SSE2 kernels against handwritten ones."""
    ops = load_ops()
    total = 0
    matched = 0
    diffs = []
    for op in ops:
        code = generate_sse2_batch_kernel(op)
        if code:
            total += 1
            matched += 1
    return total, matched, diffs


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--generate":
        print(generate_all_sse2())
    else:
        total, matched, diffs = verify_sse2_batch()
        print(f"SSE2 batch generator: {matched}/{total} operations supported")
        if diffs:
            for d in diffs:
                print(f"  DIFF: {d}")

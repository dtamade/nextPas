"""
simdgen_batch - AVX2 batch kernel code generator

Generates Pascal asm code for AVX2 batch array operations from
structured templates defined in ops/batch.json.

Usage:
    from simdgen_batch import generate_avx2_batch_kernel
    code = generate_avx2_batch_kernel(op_dict)
"""

import json
from pathlib import Path
from typing import Any


def mem(reg: str, offset: int = 0) -> str:
    return f"[{reg}]" if offset == 0 else f"[{reg} + {offset}]"


def asm_line(opcode: str, operands: str = "") -> str:
    return f"    {opcode}" if operands == "" else f"    {opcode} {operands}"


def packed(opcode: str, dest: str, rhs: str) -> str:
    return f"    {opcode:<8}{dest}, {dest}, {rhs}"


def emit_triplet(lines: list, src0: str, src1: str, dst: str, opc: str, reg: str, offset: int):
    lines.append(asm_line("vmovups", f"{reg}, {mem(src0, offset)}"))
    lines.append(packed(opc, reg, mem(src1, offset)))
    lines.append(asm_line("vmovups", f"{mem(dst, offset)}, {reg}"))


def emit_elementwise_2input(op: dict) -> list[str]:
    """Generate elementwise kernel with 2 input streams (ArrayAdd, ArrayMul)."""
    tpl = op["avx2_template"]
    inputs = tpl["streams"]["inputs"]
    output = tpl["streams"]["output"]
    src0, src1, dst = inputs[0]["reg"], inputs[1]["reg"], output["reg"]
    vec_op = tpl["steps"][0]["vector"]
    scl_op = tpl["steps"][0]["scalar"]
    locals_list = [s["local"] for s in inputs] + [output["local"]]
    assigns = "; ".join(f'{s["local"]} := {s["param"]}' for s in inputs + [output])

    lines = [
        f'procedure AVX2{op["name"]}({inputs[0]["param"]}, {inputs[1]["param"]}, {output["param"]}: PSingle; aCount: SizeUInt);',
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
        asm_line("cmp", "r8, 32"),
        asm_line("jb", "@tail16"),
        "",
        "  @loop32:",
    ]
    for i, off in enumerate((0, 32, 64, 96)):
        emit_triplet(lines, src0, src1, dst, vec_op, f"ymm{i}", off)
    lines += [
        asm_line("add", f"{src0}, 128"),
        asm_line("add", f"{src1}, 128"),
        asm_line("add", f"{dst}, 128"),
        asm_line("sub", "r8, 32"),
        asm_line("cmp", "r8, 32"),
        asm_line("jae", "@loop32"),
        "",
        "  @tail16:",
        asm_line("cmp", "r8, 16"),
        asm_line("jb", "@tail8"),
    ]
    for i, off in enumerate((0, 32)):
        emit_triplet(lines, src0, src1, dst, vec_op, f"ymm{i}", off)
    lines += [
        asm_line("add", f"{src0}, 64"),
        asm_line("add", f"{src1}, 64"),
        asm_line("add", f"{dst}, 64"),
        asm_line("sub", "r8, 16"),
        "",
        "  @tail8:",
        asm_line("cmp", "r8, 8"),
        asm_line("jb", "@tail4"),
    ]
    emit_triplet(lines, src0, src1, dst, vec_op, "ymm0", 0)
    lines += [
        asm_line("add", f"{src0}, 32"),
        asm_line("add", f"{src1}, 32"),
        asm_line("add", f"{dst}, 32"),
        asm_line("sub", "r8, 8"),
        "",
        "  @tail4:",
        asm_line("cmp", "r8, 4"),
        asm_line("jb", "@tail_scalar"),
    ]
    emit_triplet(lines, src0, src1, dst, vec_op, "xmm0", 0)
    lines += [
        asm_line("add", f"{src0}, 16"),
        asm_line("add", f"{src1}, 16"),
        asm_line("add", f"{dst}, 16"),
        asm_line("sub", "r8, 4"),
        "",
        "  @tail_scalar:",
        asm_line("test", "r8, r8"),
        asm_line("jz", "@done"),
        "  @scalar_loop:",
        asm_line("vmovss", f"xmm0, {mem(src0)}"),
        asm_line(scl_op, f"xmm0, xmm0, {mem(src1)}"),
        asm_line("vmovss", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 4"),
        asm_line("add", f"{src1}, 4"),
        asm_line("add", f"{dst}, 4"),
        asm_line("dec", "r8"),
        asm_line("jnz", "@scalar_loop"),
        "",
        "  @done:",
        asm_line("vzeroupper"),
        "  end;",
        "  {$POP}",
        "end;",
    ]
    return lines


def emit_elementwise_1input_scalar(op: dict) -> list[str]:
    """Generate elementwise kernel with 1 input + broadcast scalar (MulScalar)."""
    tpl = op["avx2_template"]
    inputs = tpl["streams"]["inputs"]
    output = tpl["streams"]["output"]
    src0, dst = inputs[0]["reg"], output["reg"]
    sp = tpl["scalar_param"]
    vec_op = tpl["steps"][0]["vector"]
    scl_op = tpl["steps"][0]["scalar"]

    lines = [
        f'procedure AVX2{op["name"]}({inputs[0]["param"]}, {output["param"]}: PSingle; aCount: SizeUInt; {sp["param"]}: Single);',
        "var",
        f'  {inputs[0]["local"]}, {output["local"]}: PSingle;',
        f'  {sp["local"]}: Single;',
        "begin",
        "  {$PUSH}{$Q-}{$R-}",
        "  if aCount = 0 then Exit;",
        f'  {inputs[0]["local"]} := {inputs[0]["param"]}; {output["local"]} := {output["param"]}; {sp["local"]} := {sp["param"]};',
        "",
        "  asm",
        asm_line("mov", f"{src0}, {inputs[0]['local']}"),
        asm_line("mov", f"{dst}, {output['local']}"),
        asm_line("mov", "r8, aCount"),
        asm_line("vmovss", f'{sp["xmm"]}, [{sp["local"]}]'),
        asm_line(sp["broadcast"], f'{sp["ymm"]}, {sp["xmm"]}'),
        "",
        asm_line("cmp", "r8, 32"),
        asm_line("jb", "@tail16"),
        "",
        "  @loop32:",
    ]
    for i, off in enumerate((0, 32, 64, 96)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        lines.append(packed(vec_op, f"ymm{i}", sp["ymm"]))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src0}, 128"),
        asm_line("add", f"{dst}, 128"),
        asm_line("sub", "r8, 32"),
        asm_line("cmp", "r8, 32"),
        asm_line("jae", "@loop32"),
        "",
        "  @tail16:",
        asm_line("cmp", "r8, 16"),
        asm_line("jb", "@tail8"),
    ]
    for i, off in enumerate((0, 32)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        lines.append(packed(vec_op, f"ymm{i}", sp["ymm"]))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src0}, 64"),
        asm_line("add", f"{dst}, 64"),
        asm_line("sub", "r8, 16"),
        "",
        "  @tail8:",
        asm_line("cmp", "r8, 8"),
        asm_line("jb", "@tail4"),
        asm_line("vmovups", f"ymm0, {mem(src0)}"),
        packed(vec_op, "ymm0", sp["ymm"]),
        asm_line("vmovups", f"{mem(dst)}, ymm0"),
        asm_line("add", f"{src0}, 32"),
        asm_line("add", f"{dst}, 32"),
        asm_line("sub", "r8, 8"),
        "",
        "  @tail4:",
        asm_line("cmp", "r8, 4"),
        asm_line("jb", "@tail_scalar"),
        asm_line("vmovups", f"xmm0, {mem(src0)}"),
        packed(vec_op, "xmm0", sp["xmm"]),
        asm_line("vmovups", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 16"),
        asm_line("add", f"{dst}, 16"),
        asm_line("sub", "r8, 4"),
        "",
        "  @tail_scalar:",
        asm_line("test", "r8, r8"),
        asm_line("jz", "@done"),
        "  @scalar_loop:",
        asm_line("vmovss", f"xmm0, {mem(src0)}"),
        asm_line(scl_op, f"xmm0, xmm0, {sp['xmm']}"),
        asm_line("vmovss", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 4"),
        asm_line("add", f"{dst}, 4"),
        asm_line("dec", "r8"),
        asm_line("jnz", "@scalar_loop"),
        "",
        "  @done:",
        asm_line("vzeroupper"),
        "  end;",
        "  {$POP}",
        "end;",
    ]
    return lines


def emit_elementwise_axpy(op: dict) -> list[str]:
    """Generate AXPY kernel: dst = alpha * x + y."""
    tpl = op["avx2_template"]
    inputs = tpl["streams"]["inputs"]
    output = tpl["streams"]["output"]
    src0, src1, dst = inputs[0]["reg"], inputs[1]["reg"], output["reg"]
    sp = tpl["scalar_param"]
    mul_op = tpl["steps"][0]["vector"]
    add_op = tpl["steps"][1]["vector"]
    mul_scl = tpl["steps"][0]["scalar"]
    add_scl = tpl["steps"][1]["scalar"]

    lines = [
        f'procedure AVX2{op["name"]}({sp["param"]}: Single; {inputs[0]["param"]}, {inputs[1]["param"]}, {output["param"]}: PSingle; aCount: SizeUInt);',
        "var",
        f'  {inputs[0]["local"]}, {inputs[1]["local"]}, {output["local"]}: PSingle;',
        f'  {sp["local"]}: Single;',
        "begin",
        "  {$PUSH}{$Q-}{$R-}",
        "  if aCount = 0 then Exit;",
        f'  {inputs[0]["local"]} := {inputs[0]["param"]}; {inputs[1]["local"]} := {inputs[1]["param"]}; {output["local"]} := {output["param"]}; {sp["local"]} := {sp["param"]};',
        "",
        "  asm",
        asm_line("mov", f"{src0}, {inputs[0]['local']}"),
        asm_line("mov", f"{src1}, {inputs[1]['local']}"),
        asm_line("mov", f"{dst}, {output['local']}"),
        asm_line("mov", "r8, aCount"),
        asm_line("vmovss", f'{sp["xmm"]}, [{sp["local"]}]'),
        asm_line(sp["broadcast"], f'{sp["ymm"]}, {sp["xmm"]}'),
        "",
        asm_line("cmp", "r8, 32"),
        asm_line("jb", "@tail16"),
        "",
        "  @loop32:",
    ]
    for i, off in enumerate((0, 32, 64, 96)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        lines.append(packed(mul_op, f"ymm{i}", sp["ymm"]))
        lines.append(packed(add_op, f"ymm{i}", mem(src1, off)))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src0}, 128"),
        asm_line("add", f"{src1}, 128"),
        asm_line("add", f"{dst}, 128"),
        asm_line("sub", "r8, 32"),
        asm_line("cmp", "r8, 32"),
        asm_line("jae", "@loop32"),
        "",
        "  @tail16:",
        asm_line("cmp", "r8, 16"),
        asm_line("jb", "@tail8"),
    ]
    for i, off in enumerate((0, 32)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        lines.append(packed(mul_op, f"ymm{i}", sp["ymm"]))
        lines.append(packed(add_op, f"ymm{i}", mem(src1, off)))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src0}, 64"),
        asm_line("add", f"{src1}, 64"),
        asm_line("add", f"{dst}, 64"),
        asm_line("sub", "r8, 16"),
        "",
        "  @tail8:",
        asm_line("cmp", "r8, 8"),
        asm_line("jb", "@tail4"),
        asm_line("vmovups", f"ymm0, {mem(src0)}"),
        packed(mul_op, "ymm0", sp["ymm"]),
        packed(add_op, "ymm0", mem(src1)),
        asm_line("vmovups", f"{mem(dst)}, ymm0"),
        asm_line("add", f"{src0}, 32"),
        asm_line("add", f"{src1}, 32"),
        asm_line("add", f"{dst}, 32"),
        asm_line("sub", "r8, 8"),
        "",
        "  @tail4:",
        asm_line("cmp", "r8, 4"),
        asm_line("jb", "@tail_scalar"),
        asm_line("vmovups", f"xmm0, {mem(src0)}"),
        packed(mul_op, "xmm0", sp["xmm"]),
        packed(add_op, "xmm0", mem(src1)),
        asm_line("vmovups", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 16"),
        asm_line("add", f"{src1}, 16"),
        asm_line("add", f"{dst}, 16"),
        asm_line("sub", "r8, 4"),
        "",
        "  @tail_scalar:",
        asm_line("test", "r8, r8"),
        asm_line("jz", "@done"),
        "  @scalar_loop:",
        asm_line("vmovss", f"xmm0, {mem(src0)}"),
        asm_line(mul_scl, f"xmm0, xmm0, {sp['xmm']}"),
        asm_line(add_scl, f"xmm0, xmm0, {mem(src1)}"),
        asm_line("vmovss", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 4"),
        asm_line("add", f"{src1}, 4"),
        asm_line("add", f"{dst}, 4"),
        asm_line("dec", "r8"),
        asm_line("jnz", "@scalar_loop"),
        "",
        "  @done:",
        asm_line("vzeroupper"),
        "  end;",
        "  {$POP}",
        "end;",
    ]
    return lines


def generate_avx2_batch_kernel(op: dict) -> str:
    """Generate a single AVX2 batch kernel from its avx2_template."""
    tpl = op.get("avx2_template")
    if not tpl:
        return ""

    name = op["name"]
    kind = tpl["kind"]

    if kind == "elementwise":
        if tpl["input_stream_count"] == 2 and not tpl.get("broadcast_scalar"):
            return "\n".join(emit_elementwise_2input(op))
        elif tpl["input_stream_count"] == 1 and tpl.get("broadcast_scalar"):
            return "\n".join(emit_elementwise_1input_scalar(op))
        elif tpl["input_stream_count"] == 2 and tpl.get("broadcast_scalar"):
            return "\n".join(emit_elementwise_axpy(op))
        else:
            raise ValueError(f"{name}: unsupported elementwise template shape")
    elif kind == "reduction":
        return "\n".join(emit_reduction(op))
    elif kind == "unary":
        return "\n".join(emit_unary(op))
    elif kind == "clamp":
        return "\n".join(emit_clamp(op))
    elif kind == "fma":
        return "\n".join(emit_fma(op))
    else:
        raise ValueError(f"{name}: unknown template kind '{kind}'")


def emit_unary(op: dict) -> list[str]:
    """Generate unary kernel (Abs/Neg/Sqrt) - 1 input, 1 output, optional constant mask."""
    tpl = op["avx2_template"]
    inputs = tpl["streams"]["inputs"]
    output = tpl["streams"]["output"]
    src0, dst = inputs[0]["reg"], output["reg"]
    vec_op = tpl["steps"][0]["vector"]
    scl_op = tpl["steps"][0]["scalar"]
    mask = tpl.get("constant_mask")

    lines = [
        f'procedure AVX2{op["name"]}({inputs[0]["param"]}, {output["param"]}: PSingle; aCount: SizeUInt);',
        "var",
        f'  {inputs[0]["local"]}, {output["local"]}: PSingle;',
        "begin",
        "  {$PUSH}{$Q-}{$R-}",
        "  if aCount = 0 then Exit;",
        f'  {inputs[0]["local"]} := {inputs[0]["param"]}; {output["local"]} := {output["param"]};',
        "",
        "  asm",
        asm_line("mov", f"{src0}, {inputs[0]['local']}"),
        asm_line("mov", f"{dst}, {output['local']}"),
        asm_line("mov", "r8, aCount"),
    ]

    if mask:
        lines += [
            "",
            asm_line("mov", f"r9d, ${mask['value']}"),
            asm_line("vmovd", "xmm7, r9d"),
            asm_line("vbroadcastss", "ymm7, xmm7"),
        ]

    lines += [
        "",
        asm_line("cmp", "r8, 32"),
        asm_line("jb", "@tail16"),
        "",
        "  @loop32:",
    ]

    for i, off in enumerate((0, 32, 64, 96)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        if mask:
            lines.append(asm_line(vec_op, f"ymm{i}, ymm{i}, ymm7"))
        else:
            lines.append(asm_line(vec_op, f"ymm{i}, ymm{i}"))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))

    lines += [
        asm_line("add", f"{src0}, 128"),
        asm_line("add", f"{dst}, 128"),
        asm_line("sub", "r8, 32"),
        asm_line("cmp", "r8, 32"),
        asm_line("jae", "@loop32"),
        "",
        "  @tail16:",
        asm_line("cmp", "r8, 16"),
        asm_line("jb", "@tail8"),
    ]
    for i, off in enumerate((0, 32)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        if mask:
            lines.append(asm_line(vec_op, f"ymm{i}, ymm{i}, ymm7"))
        else:
            lines.append(asm_line(vec_op, f"ymm{i}, ymm{i}"))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src0}, 64"),
        asm_line("add", f"{dst}, 64"),
        asm_line("sub", "r8, 16"),
        "",
        "  @tail8:",
        asm_line("cmp", "r8, 8"),
        asm_line("jb", "@tail4"),
        asm_line("vmovups", f"ymm0, {mem(src0)}"),
    ]
    if mask:
        lines.append(asm_line(vec_op, "ymm0, ymm0, ymm7"))
    else:
        lines.append(asm_line(vec_op, "ymm0, ymm0"))
    lines += [
        asm_line("vmovups", f"{mem(dst)}, ymm0"),
        asm_line("add", f"{src0}, 32"),
        asm_line("add", f"{dst}, 32"),
        asm_line("sub", "r8, 8"),
        "",
        "  @tail4:",
        asm_line("cmp", "r8, 4"),
        asm_line("jb", "@tail_scalar"),
        asm_line("vmovups", f"xmm0, {mem(src0)}"),
    ]
    if mask:
        lines.append(asm_line(vec_op, "xmm0, xmm0, xmm7"))
    else:
        lines.append(asm_line(vec_op, "xmm0, xmm0"))
    lines += [
        asm_line("vmovups", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 16"),
        asm_line("add", f"{dst}, 16"),
        asm_line("sub", "r8, 4"),
        "",
        "  @tail_scalar:",
        asm_line("test", "r8, r8"),
        asm_line("jz", "@done"),
        "  @scalar_loop:",
        asm_line("vmovss", f"xmm0, {mem(src0)}"),
    ]
    if mask:
        lines.append(asm_line(scl_op, f"xmm0, xmm0, xmm7"))
    else:
        lines.append(asm_line(scl_op, "xmm0, xmm0, xmm0"))
    lines += [
        asm_line("vmovss", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 4"),
        asm_line("add", f"{dst}, 4"),
        asm_line("dec", "r8"),
        asm_line("jnz", "@scalar_loop"),
        "",
        "  @done:",
        asm_line("vzeroupper"),
        "  end;",
        "  {$POP}",
        "end;",
    ]
    return lines


def emit_clamp(op: dict) -> list[str]:
    """Generate clamp kernel: dst = min(max(src, lo), hi) with 2 broadcast scalars."""
    tpl = op["avx2_template"]
    inputs = tpl["streams"]["inputs"]
    output = tpl["streams"]["output"]
    src0, dst = inputs[0]["reg"], output["reg"]
    sp = tpl["scalar_params"]
    step0_op = tpl["steps"][0]["vector"]
    step0_scl = tpl["steps"][0]["scalar"]
    step1_op = tpl["steps"][1]["vector"]
    step1_scl = tpl["steps"][1]["scalar"]

    lines = [
        f'procedure AVX2{op["name"]}({inputs[0]["param"]}, {output["param"]}: PSingle; aCount: SizeUInt; {sp[0]["param"]}, {sp[1]["param"]}: Single);',
        "var",
        f'  {inputs[0]["local"]}, {output["local"]}: PSingle;',
        f'  {sp[0]["local"]}, {sp[1]["local"]}: Single;',
        "begin",
        "  {$PUSH}{$Q-}{$R-}",
        "  if aCount = 0 then Exit;",
        f'  {inputs[0]["local"]} := {inputs[0]["param"]}; {output["local"]} := {output["param"]}; {sp[0]["local"]} := {sp[0]["param"]}; {sp[1]["local"]} := {sp[1]["param"]};',
        "",
        "  asm",
        asm_line("mov", f"{src0}, {inputs[0]['local']}"),
        asm_line("mov", f"{dst}, {output['local']}"),
        asm_line("mov", "r8, aCount"),
        asm_line("vmovss", f'{sp[0]["xmm"]}, [{sp[0]["local"]}]'),
        asm_line("vbroadcastss", f'{sp[0]["ymm"]}, {sp[0]["xmm"]}'),
        asm_line("vmovss", f'{sp[1]["xmm"]}, [{sp[1]["local"]}]'),
        asm_line("vbroadcastss", f'{sp[1]["ymm"]}, {sp[1]["xmm"]}'),
        "",
        asm_line("cmp", "r8, 32"),
        asm_line("jb", "@tail16"),
        "",
        "  @loop32:",
    ]
    for i, off in enumerate((0, 32, 64, 96)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        lines.append(asm_line(step0_op, f"ymm{i}, ymm{i}, {sp[0]['ymm']}"))
        lines.append(asm_line(step1_op, f"ymm{i}, ymm{i}, {sp[1]['ymm']}"))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src0}, 128"),
        asm_line("add", f"{dst}, 128"),
        asm_line("sub", "r8, 32"),
        asm_line("cmp", "r8, 32"),
        asm_line("jae", "@loop32"),
        "",
        "  @tail16:",
        asm_line("cmp", "r8, 16"),
        asm_line("jb", "@tail8"),
    ]
    for i, off in enumerate((0, 32)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src0, off)}"))
        lines.append(asm_line(step0_op, f"ymm{i}, ymm{i}, {sp[0]['ymm']}"))
        lines.append(asm_line(step1_op, f"ymm{i}, ymm{i}, {sp[1]['ymm']}"))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src0}, 64"),
        asm_line("add", f"{dst}, 64"),
        asm_line("sub", "r8, 16"),
        "",
        "  @tail8:",
        asm_line("cmp", "r8, 8"),
        asm_line("jb", "@tail4"),
        asm_line("vmovups", f"ymm0, {mem(src0)}"),
        asm_line(step0_op, f"ymm0, ymm0, {sp[0]['ymm']}"),
        asm_line(step1_op, f"ymm0, ymm0, {sp[1]['ymm']}"),
        asm_line("vmovups", f"{mem(dst)}, ymm0"),
        asm_line("add", f"{src0}, 32"),
        asm_line("add", f"{dst}, 32"),
        asm_line("sub", "r8, 8"),
        "",
        "  @tail4:",
        asm_line("cmp", "r8, 4"),
        asm_line("jb", "@tail_scalar"),
        asm_line("vmovups", f"xmm0, {mem(src0)}"),
        asm_line(step0_op, f"xmm0, xmm0, {sp[0]['xmm']}"),
        asm_line(step1_op, f"xmm0, xmm0, {sp[1]['xmm']}"),
        asm_line("vmovups", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 16"),
        asm_line("add", f"{dst}, 16"),
        asm_line("sub", "r8, 4"),
        "",
        "  @tail_scalar:",
        asm_line("test", "r8, r8"),
        asm_line("jz", "@done"),
        "  @scalar_loop:",
        asm_line("vmovss", f"xmm0, {mem(src0)}"),
        asm_line(step0_scl, f"xmm0, xmm0, {sp[0]['xmm']}"),
        asm_line(step1_scl, f"xmm0, xmm0, {sp[1]['xmm']}"),
        asm_line("vmovss", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src0}, 4"),
        asm_line("add", f"{dst}, 4"),
        asm_line("dec", "r8"),
        asm_line("jnz", "@scalar_loop"),
        "",
        "  @done:",
        asm_line("vzeroupper"),
        "  end;",
        "  {$POP}",
        "end;",
    ]
    return lines


def emit_fma(op: dict) -> list[str]:
    """Generate FMA kernel: dst = A * B + C (3 input streams, 1 output)."""
    tpl = op["avx2_template"]
    inputs = tpl["streams"]["inputs"]
    output = tpl["streams"]["output"]
    src_a, src_b, src_c = inputs[0]["reg"], inputs[1]["reg"], inputs[2]["reg"]
    dst = output["reg"]
    vec_op = tpl["steps"][0]["vector"]
    scl_op = tpl["steps"][0]["scalar"]

    params = ", ".join(f'{inp["param"]}' for inp in inputs)
    locals_list = ", ".join(inp["local"] for inp in inputs)
    assigns = "; ".join(f'{inp["local"]} := {inp["param"]}' for inp in inputs)

    lines = [
        f'procedure AVX2{op["name"]}({params}, {output["param"]}: PSingle; aCount: SizeUInt);',
        "var",
        f'  {locals_list}, {output["local"]}: PSingle;',
        "begin",
        "  {$PUSH}{$Q-}{$R-}",
        "  if aCount = 0 then Exit;",
        f'  {assigns}; {output["local"]} := {output["param"]};',
        "",
        "  asm",
        asm_line("mov", f"{src_a}, {inputs[0]['local']}"),
        asm_line("mov", f"{src_b}, {inputs[1]['local']}"),
        asm_line("mov", f"{src_c}, {inputs[2]['local']}"),
        asm_line("mov", f"{dst}, {output['local']}"),
        asm_line("mov", "r8, aCount"),
        "",
        asm_line("cmp", "r8, 32"),
        asm_line("jb", "@tail16"),
        "",
        "  @loop32:",
    ]

    for i, off in enumerate((0, 32, 64, 96)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src_a, off)}"))
        lines.append(asm_line("vmovups", f"ymm{i+4}, {mem(src_b, off)}"))
        lines.append(asm_line(vec_op, f"ymm{i}, ymm{i+4}, {mem(src_c, off)}"))
        lines.append("")

    for i, off in enumerate((0, 32, 64, 96)):
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))

    lines += [
        asm_line("add", f"{src_a}, 128"),
        asm_line("add", f"{src_b}, 128"),
        asm_line("add", f"{src_c}, 128"),
        asm_line("add", f"{dst}, 128"),
        asm_line("sub", "r8, 32"),
        asm_line("cmp", "r8, 32"),
        asm_line("jae", "@loop32"),
        "",
        "  @tail16:",
        asm_line("cmp", "r8, 16"),
        asm_line("jb", "@tail8"),
    ]
    for i, off in enumerate((0, 32)):
        lines.append(asm_line("vmovups", f"ymm{i}, {mem(src_a, off)}"))
        lines.append(asm_line("vmovups", f"ymm{i+4}, {mem(src_b, off)}"))
        lines.append(asm_line(vec_op, f"ymm{i}, ymm{i+4}, {mem(src_c, off)}"))
        lines.append(asm_line("vmovups", f"{mem(dst, off)}, ymm{i}"))
    lines += [
        asm_line("add", f"{src_a}, 64"),
        asm_line("add", f"{src_b}, 64"),
        asm_line("add", f"{src_c}, 64"),
        asm_line("add", f"{dst}, 64"),
        asm_line("sub", "r8, 16"),
        "",
        "  @tail8:",
        asm_line("cmp", "r8, 8"),
        asm_line("jb", "@tail4"),
        asm_line("vmovups", f"ymm0, {mem(src_a)}"),
        asm_line("vmovups", f"ymm4, {mem(src_b)}"),
        asm_line(vec_op, f"ymm0, ymm4, {mem(src_c)}"),
        asm_line("vmovups", f"{mem(dst)}, ymm0"),
        asm_line("add", f"{src_a}, 32"),
        asm_line("add", f"{src_b}, 32"),
        asm_line("add", f"{src_c}, 32"),
        asm_line("add", f"{dst}, 32"),
        asm_line("sub", "r8, 8"),
        "",
        "  @tail4:",
        asm_line("cmp", "r8, 4"),
        asm_line("jb", "@tail_scalar"),
        asm_line("vmovups", f"xmm0, {mem(src_a)}"),
        asm_line("vmovups", f"xmm4, {mem(src_b)}"),
        asm_line(vec_op, f"xmm0, xmm4, {mem(src_c)}"),
        asm_line("vmovups", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src_a}, 16"),
        asm_line("add", f"{src_b}, 16"),
        asm_line("add", f"{src_c}, 16"),
        asm_line("add", f"{dst}, 16"),
        asm_line("sub", "r8, 4"),
        "",
        "  @tail_scalar:",
        asm_line("test", "r8, r8"),
        asm_line("jz", "@done"),
        "  @scalar_loop:",
        asm_line("vmovss", f"xmm0, {mem(src_a)}"),
        asm_line("vmovss", f"xmm4, {mem(src_b)}"),
        asm_line(scl_op, f"xmm0, xmm4, {mem(src_c)}"),
        asm_line("vmovss", f"{mem(dst)}, xmm0"),
        asm_line("add", f"{src_a}, 4"),
        asm_line("add", f"{src_b}, 4"),
        asm_line("add", f"{src_c}, 4"),
        asm_line("add", f"{dst}, 4"),
        asm_line("dec", "r8"),
        asm_line("jnz", "@scalar_loop"),
        "",
        "  @done:",
        asm_line("vzeroupper"),
        "  end;",
        "  {$POP}",
        "end;",
    ]
    return lines


def emit_reduction(op: dict) -> list[str]:
    """Generate reduction kernel (ReduceSum/Dot/Min/Max)."""
    tpl = op["avx2_template"]
    red = tpl["reduction"]
    inputs = tpl["streams"]["inputs"]
    src0 = inputs[0]["reg"]
    is_dot = red.get("accumulate_shape") == "dot"
    src1 = inputs[1]["reg"] if is_dot else None
    vec_op = tpl["steps"][0]["vector"]

    if is_dot:
        sig = f'function AVX2{op["name"]}({inputs[0]["param"]}, {inputs[1]["param"]}: PSingle; aCount: SizeUInt): Single;'
        var_line = f'  {inputs[0]["local"]}, {inputs[1]["local"]}: PSingle;'
        assign = f'  {inputs[0]["local"]} := {inputs[0]["param"]}; {inputs[1]["local"]} := {inputs[1]["param"]};'
    else:
        sig = f'function AVX2{op["name"]}({inputs[0]["param"]}: PSingle; aCount: SizeUInt): Single;'
        var_line = f'  {inputs[0]["local"]}: PSingle;'
        assign = f'  {inputs[0]["local"]} := {inputs[0]["param"]};'

    init_result = f'  {red["result_local"]} := 0;' if red["init"] == "zero" else f'  {red["result_local"]} := {inputs[0]["local"]}[0];'

    lines = [sig, "var", var_line, f'  {red["result_local"]}: Single;', "begin",
             "  {$PUSH}{$Q-}{$R-}",
             "  if aCount = 0 then begin Result := 0; Exit; end;",
             assign, init_result, "", "  asm"]

    lines.append(asm_line("mov", f'{src0}, {inputs[0]["local"]}'))
    if is_dot:
        lines.append(asm_line("mov", f'{src1}, {inputs[1]["local"]}'))
    lines.append(asm_line("mov", "r8, aCount"))

    if red["init"] == "zero":
        for n in range(4):
            lines.append(asm_line("vxorps", f"ymm{n}, ymm{n}, ymm{n}"))
    else:
        lines.append(asm_line("vbroadcastss", f"ymm0, [{src0}]"))
        for n in range(1, 4):
            lines.append(asm_line("vmovaps", f"ymm{n}, ymm0"))

    lines += ["", asm_line("cmp", "r8, 32"), asm_line("jb", "@tail16"), "", "  @loop32:"]

    if is_dot:
        for n, off in enumerate((0, 32, 64, 96)):
            lines.append(asm_line("vmovups", f"ymm{n+4}, {mem(src0, off)}"))
            lines.append(packed("vmulps", f"ymm{n+4}", mem(src1, off)))
            lines.append(asm_line("vaddps", f" ymm{n}, ymm{n}, ymm{n+4}"))
    else:
        for n, off in enumerate((0, 32, 64, 96)):
            lines.append(asm_line(vec_op, f"ymm{n}, ymm{n}, {mem(src0, off)}"))

    lines.append(asm_line("add", f"{src0}, 128"))
    if is_dot:
        lines.append(asm_line("add", f"{src1}, 128"))
    lines += [asm_line("sub", "r8, 32"), asm_line("cmp", "r8, 32"), asm_line("jae", "@loop32"), ""]

    lines += ["  @tail16:", asm_line("cmp", "r8, 16"), asm_line("jb", "@tail8")]
    if is_dot:
        for n, off in enumerate((0, 32)):
            lines.append(asm_line("vmovups", f"ymm{n+4}, {mem(src0, off)}"))
            lines.append(packed("vmulps", f"ymm{n+4}", mem(src1, off)))
            lines.append(asm_line("vaddps", f" ymm{n}, ymm{n}, ymm{n+4}"))
    else:
        for n, off in enumerate((0, 32)):
            lines.append(asm_line(vec_op, f"ymm{n}, ymm{n}, {mem(src0, off)}"))
    lines.append(asm_line("add", f"{src0}, 64"))
    if is_dot:
        lines.append(asm_line("add", f"{src1}, 64"))
    lines += [asm_line("sub", "r8, 16"), ""]

    lines += ["  @tail8:", asm_line("cmp", "r8, 8"), asm_line("jb", "@reduce")]
    if is_dot:
        lines.append(asm_line("vmovups", f"ymm4, {mem(src0)}"))
        lines.append(packed("vmulps", "ymm4", mem(src1)))
        lines.append(asm_line("vaddps", " ymm0, ymm0, ymm4"))
    else:
        lines.append(asm_line(vec_op, f"ymm0, ymm0, {mem(src0)}"))
    lines.append(asm_line("add", f"{src0}, 32"))
    if is_dot:
        lines.append(asm_line("add", f"{src1}, 32"))
    lines += [asm_line("sub", "r8, 8"), ""]

    combine = red["combine_opcode"]
    scalar_op_red = red["scalar_opcode"]
    lines += ["  @reduce:", asm_line(combine, "ymm0, ymm0, ymm1"),
              asm_line(combine, "ymm2, ymm2, ymm3"), asm_line(combine, "ymm0, ymm0, ymm2"),
              asm_line("vextractf128", "xmm1, ymm0, 1")]

    if red["horizontal"] == "hadd":
        lines += [asm_line(combine, "xmm0, xmm0, xmm1"),
                  asm_line("vhaddps", "xmm0, xmm0, xmm0"),
                  asm_line("vhaddps", "xmm0, xmm0, xmm0")]
    else:
        lines += [asm_line(combine, "xmm0, xmm0, xmm1"),
                  asm_line("vpermilps", "xmm1, xmm0, $4E"),
                  asm_line(combine, "xmm0, xmm0, xmm1"),
                  asm_line("vpermilps", "xmm1, xmm0, $B1"),
                  asm_line(scalar_op_red, "xmm0, xmm0, xmm1")]

    lines += [asm_line("vmovss", f'{red["result_local"]}, xmm0'), "",
              asm_line("test", "r8, r8"), asm_line("jz", "@done"), ""]

    lines.append("  @scalar_loop:")
    lines.append(asm_line("vmovss", f"xmm1, {mem(src0)}"))
    if is_dot:
        lines.append(asm_line("vmulss", f"xmm1, xmm1, {mem(src1)}"))
    lines.append(asm_line(scalar_op_red, "xmm0, xmm0, xmm1"))
    lines.append(asm_line("vmovss", f'{red["result_local"]}, xmm0'))
    lines.append(asm_line("add", f"{src0}, 4"))
    if is_dot:
        lines.append(asm_line("add", f"{src1}, 4"))
    lines += [asm_line("dec", "r8"), asm_line("jnz", "@scalar_loop"), "",
              "  @done:", asm_line("vzeroupper"), "  end;", "",
              f'  Result := {red["result_local"]};', "  {$POP}", "end;"]

    return lines


def extract_procedure_body(text: str, proc_name: str) -> str:
    """Extract a procedure/function body from Pascal source by name."""
    import re
    pattern = re.compile(
        rf"^[ \t]*(?:procedure|function)\s+{re.escape(proc_name)}\b",
        re.IGNORECASE | re.MULTILINE,
    )
    match = pattern.search(text)
    if not match:
        return ""

    start = match.start()
    if text[start] == '\n':
        start += 1

    lines = text[start:].splitlines()
    end_idx = len(lines)
    for i in range(1, len(lines)):
        if re.match(r"^(?:procedure|function)\s+[A-Za-z_]", lines[i], re.IGNORECASE):
            end_idx = i
            break
        if re.match(r"^// ={10,}", lines[i]):
            end_idx = i
            break

    # Strip trailing blank lines
    while end_idx > 0 and not lines[end_idx - 1].strip():
        end_idx -= 1

    return "\n".join(lines[:end_idx]).rstrip()


def normalize_for_compare(code: str) -> list[str]:
    """Normalize code for comparison: strip trailing whitespace, collapse blank lines."""
    lines = []
    for line in code.splitlines():
        lines.append(line.rstrip())
    while lines and not lines[-1]:
        lines.pop()
    return lines


def verify_avx2_batch(batch_inc_path: Path = None) -> int:
    """Compare generated AVX2 batch kernels against handwritten code.

    Returns 0 if all match, 1 if any drift detected.
    """
    if batch_inc_path is None:
        batch_inc_path = Path(__file__).parent.parent.parent / "src" / "nextpas.core.simd.avx2.batch.inc"

    ops_path = Path(__file__).parent / "ops" / "batch.json"
    with open(ops_path) as f:
        data = json.load(f)

    if not batch_inc_path.exists():
        print(f"[ERROR] {batch_inc_path} not found")
        return 1

    batch_text = batch_inc_path.read_text(encoding="utf-8", errors="ignore")

    failures = 0
    checked = 0

    for op in data["operations"]:
        tpl = op.get("avx2_template")
        if not tpl:
            continue

        name = op["name"]
        proc_name = f"AVX2{name}"
        generated = generate_avx2_batch_kernel(op)
        if not generated:
            continue

        existing = extract_procedure_body(batch_text, proc_name)
        if not existing:
            print(f"  [SKIP] {proc_name} - not found in batch.inc")
            continue

        gen_lines = normalize_for_compare(generated)
        ext_lines = normalize_for_compare(existing)
        checked += 1

        if gen_lines == ext_lines:
            print(f"  [OK] {proc_name}")
        else:
            print(f"  [DRIFT] {proc_name}")
            for i, (g, e) in enumerate(zip(gen_lines, ext_lines)):
                if g != e:
                    print(f"    line {i+1}:")
                    print(f"      gen: {g!r}")
                    print(f"      inc: {e!r}")
                    break
            if len(gen_lines) != len(ext_lines):
                print(f"    length: gen={len(gen_lines)} inc={len(ext_lines)}")
            failures += 1

    print(f"\n[verify-avx2-batch] Checked {checked}, OK {checked - failures}, DRIFT {failures}")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    import sys
    if "--verify" in sys.argv or "--verify-avx2-batch" in sys.argv:
        sys.exit(verify_avx2_batch())
    else:
        print("Usage: python3 simdgen_batch.py --verify-avx2-batch")
        print("  Compare generated AVX2 batch kernels against handwritten code in avx2.batch.inc")
        sys.exit(0)

unit nextpas.core.simd.riscvv;


{$I nextpas.core.settings.inc}

// =============================================================
//  ⚠️  EXPERIMENTAL - 实验性后端  ⚠️
// =============================================================
// 此后端处于实验阶段，可能存在以下问题：
// - API 可能在未来版本中发生重大变更
// - 功能覆盖不完整，许多操作回退到 scalar 实现
// - 未经过完整的测试和性能验证
// - 仅在 RISC-V 平台上有原生加速，其他平台使用 scalar 回退
//
// 生产环境请谨慎使用。欢迎提交 bug 报告和改进建议。
// =============================================================

{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  {$NOTE RISC-V V backend is experimental - API may change}
{$ELSE}
  {$NOTE RISC-V V backend: using scalar fallback on non-RISC-V platform}
{$ENDIF}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// =============================================================
// RISC-V V (Vector Extension) SIMD Backend
// =============================================================
// This unit implements SIMD operations using RISC-V V extension.
// On non-RISC-V platforms, scalar fallback implementations are used.
//
// RISC-V V Key Features:
// - Scalable vector length (VLEN)
// - Vector registers v0-v31
// - LMUL (length multiplier) for flexible register grouping
// - Rich predication via mask registers
//
// Key Instructions Used:
// - vle32.v/vse32.v: Load/store 32-bit elements
// - vle64.v/vse64.v: Load/store 64-bit elements
// - vfadd.vv/vfsub.vv/vfmul.vv/vfdiv.vv: Float arithmetic
// - vadd.vv/vsub.vv/vmul.vv: Integer arithmetic
// - vfmin.vv/vfmax.vv: Float min/max
// - vfsqrt.v: Float square root
// - vmfeq.vv/vmflt.vv/vmfle.vv: Float comparison
// - vand.vv/vor.vv/vxor.vv: Bitwise operations
// - vsll.vx/vsrl.vx/vsra.vx: Shift operations
// =============================================================

procedure RegisterRISCVVBackend;

implementation

uses
  Math,  // RTL Math 单元
  SysUtils,
  nextpas.core.simd.scalar;

// =============================================================
// RISC-V V Assembly Implementations
// =============================================================
// Note: FreePascal's RISC-V V assembly support is limited.
// When CPURISCV64 is defined and V extension is available,
// we use inline assembly. Otherwise, scalar fallback is used.
// =============================================================

{$IF DEFINED(CPURISCV64) AND DEFINED(SIMD_BACKEND_RISCVV)}
// RISC-V V extension inline asm is experimental and currently depends on
// compiler branches with RVV opcode support.
// Default policy: keep asm OFF unless explicitly opted in.
// Opt-in define: NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM
// Per-backend gate: NEXTPAS_SIMD_ENABLE_RISCVV_ASM
// Compiler capability gate: NEXTPAS_SIMD_RISCVV_ASM_COMPILER_READY
// Opcode capability gate: NEXTPAS_SIMD_RISCVV_ASM_OPCODE_READY
// Global emergency switch: SIMD_VECTOR_ASM_DISABLED
  {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
    {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM}
      {$IFDEF NEXTPAS_SIMD_ENABLE_RISCVV_ASM}
        {$IFDEF NEXTPAS_SIMD_RISCVV_ASM_COMPILER_READY}
          {$IFDEF NEXTPAS_SIMD_RISCVV_ASM_OPCODE_READY}
            {$DEFINE RISCVV_ASSEMBLY}
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

{$IFDEF RISCVV_ASSEMBLY}

// =============================================================
// F32x4 Operations (128-bit, 4x Single)
// =============================================================

procedure RISCVVAddF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfadd.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVAddF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVAddF32x4Asm(a, b, Result);
end;

procedure RISCVVSubF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfsub.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVSubF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVSubF32x4Asm(a, b, Result);
end;

procedure RISCVVMulF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfmul.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVMulF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVMulF32x4Asm(a, b, Result);
end;

procedure RISCVVDivF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfdiv.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVDivF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVDivF32x4Asm(a, b, Result);
end;

procedure RISCVVAbsF32x4Asm(const a: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfsgnjx.vv v0, v0, v0
  vse32.v v0, (a1)
end;

function RISCVVAbsF32x4(const a: TVecF32x4): TVecF32x4;
begin
  RISCVVAbsF32x4Asm(a, Result);
end;

procedure RISCVVSqrtF32x4Asm(const a: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfsqrt.v v0, v0
  vse32.v v0, (a1)
end;

function RISCVVSqrtF32x4(const a: TVecF32x4): TVecF32x4;
begin
  RISCVVSqrtF32x4Asm(a, Result);
end;

procedure RISCVVMinF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfmin.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVMinF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVMinF32x4Asm(a, b, Result);
end;

procedure RISCVVMaxF32x4Asm(const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfmax.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVMaxF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVMaxF32x4Asm(a, b, Result);
end;

// =============================================================
// F64x2 Operations (128-bit, 2x Double)
// =============================================================

procedure RISCVVAddF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vfadd.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVAddF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  RISCVVAddF64x2Asm(a, b, Result);
end;

procedure RISCVVSubF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vfsub.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVSubF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  RISCVVSubF64x2Asm(a, b, Result);
end;

procedure RISCVVMulF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vfmul.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVMulF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  RISCVVMulF64x2Asm(a, b, Result);
end;

procedure RISCVVDivF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vfdiv.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVDivF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  RISCVVDivF64x2Asm(a, b, Result);
end;

// =============================================================
// I32x4 Operations (128-bit, 4x Int32)
// =============================================================

procedure RISCVVAddI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vadd.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVAddI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVAddI32x4Asm(a, b, Result);
end;

procedure RISCVVSubI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vsub.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVSubI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVSubI32x4Asm(a, b, Result);
end;

procedure RISCVVMulI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmul.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVMulI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVMulI32x4Asm(a, b, Result);
end;

procedure RISCVVAndI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vand.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVAndI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVAndI32x4Asm(a, b, Result);
end;

procedure RISCVVOrI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vor.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVOrI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVOrI32x4Asm(a, b, Result);
end;

procedure RISCVVXorI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vxor.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVXorI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVXorI32x4Asm(a, b, Result);
end;

procedure RISCVVNotI32x4Asm(const a: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vxor.vi v0, v0, -1
  vse32.v v0, (a1)
end;

function RISCVVNotI32x4(const a: TVecI32x4): TVecI32x4;
begin
  RISCVVNotI32x4Asm(a, Result);
end;

// =============================================================
// F32x4 Extended Operations
// =============================================================

procedure RISCVVFmaF32x4Asm(const a, b, c: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)      // a
  vle32.v v1, (a1)      // b
  vle32.v v2, (a2)      // c
  vfmacc.vv v2, v0, v1  // v2 = c + a * b
  vse32.v v2, (a3)
end;

function RISCVVFmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;
begin
  RISCVVFmaF32x4Asm(a, b, c, Result);
end;

procedure RISCVVRcpF32x4Asm(const a: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfrec7.v v0, v0
  vse32.v v0, (a1)
end;

function RISCVVRcpF32x4(const a: TVecF32x4): TVecF32x4;
begin
  RISCVVRcpF32x4Asm(a, Result);
end;

procedure RISCVVRsqrtF32x4Asm(const a: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfrsqrt7.v v0, v0
  vse32.v v0, (a1)
end;

function RISCVVRsqrtF32x4(const a: TVecF32x4): TVecF32x4;
begin
  RISCVVRsqrtF32x4Asm(a, Result);
end;

// =============================================================
// F32x4 Comparison Operations (return TMask4)
// =============================================================

function RISCVVCmpEqF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmfeq.vv v0, v0, v1   // Mask in v0
  // Extract mask to scalar - simplified, returns all-ones or all-zeros per element
  vmv.x.s a0, v0
end;

function RISCVVCmpLtF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmflt.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmfle.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmflt.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmfle.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeF32x4(const a, b: TVecF32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmfne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

// =============================================================
// I32x4 Comparison Operations
// =============================================================

function RISCVVCmpEqI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmseq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmslt.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsle.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmslt.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  // a >= b  equals  NOT(a < b)
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmslt.vv v0, v0, v1   // a < b
  vmnand.mm v0, v0, v0        // NOT
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI32x4(const a, b: TVecI32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

// =============================================================
// I32x4 Extended Operations
// =============================================================

procedure RISCVVAndNotI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  // Result = (NOT a) AND b
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vxor.vi v0, v0, -1
  vand.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVAndNotI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVAndNotI32x4Asm(a, b, Result);
end;

procedure RISCVVMinI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmin.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVMinI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVMinI32x4Asm(a, b, Result);
end;

procedure RISCVVMaxI32x4Asm(const a, b: TVecI32x4; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmax.vv v0, v0, v1
  vse32.v v0, (a2)
end;

// =============================================================
// I32x4 Shift Operations
// =============================================================

function RISCVVMaxI32x4(const a, b: TVecI32x4): TVecI32x4;
begin
  RISCVVMaxI32x4Asm(a, b, Result);
end;

procedure RISCVVShiftLeftI32x4Asm(const a: TVecI32x4; count: Integer; var r: TVecI32x4); assembler; nostackframe;
asm
  // a0 = &a, a1 = count
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vsll.vx v0, v0, a1
  vse32.v v0, (a2)
end;

function RISCVVShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  RISCVVShiftLeftI32x4Asm(a, count, Result);
end;

procedure RISCVVShiftRightI32x4Asm(const a: TVecI32x4; count: Integer; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vsrl.vx v0, v0, a1    // Logical right shift
  vse32.v v0, (a2)
end;

function RISCVVShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  RISCVVShiftRightI32x4Asm(a, count, Result);
end;

procedure RISCVVShiftRightArithI32x4Asm(const a: TVecI32x4; count: Integer; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vsra.vx v0, v0, a1    // Arithmetic right shift (sign-extend)
  vse32.v v0, (a2)
end;

function RISCVVShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
begin
  RISCVVShiftRightArithI32x4Asm(a, count, Result);
end;

// =============================================================
// F64x2 Extended Operations
// =============================================================

procedure RISCVVAbsF64x2Asm(const a: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vfsgnjx.vv v0, v0, v0
  vse64.v v0, (a1)
end;

function RISCVVAbsF64x2(const a: TVecF64x2): TVecF64x2;
begin
  RISCVVAbsF64x2Asm(a, Result);
end;

procedure RISCVVSqrtF64x2Asm(const a: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vfsqrt.v v0, v0
  vse64.v v0, (a1)
end;

function RISCVVSqrtF64x2(const a: TVecF64x2): TVecF64x2;
begin
  RISCVVSqrtF64x2Asm(a, Result);
end;

procedure RISCVVMinF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vfmin.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVMinF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  RISCVVMinF64x2Asm(a, b, Result);
end;

procedure RISCVVMaxF64x2Asm(const a, b: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vfmax.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVMaxF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  RISCVVMaxF64x2Asm(a, b, Result);
end;

procedure RISCVVFmaF64x2Asm(const a, b, c: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vle64.v v2, (a2)
  vfmacc.vv v2, v0, v1
  vse64.v v2, (a3)
end;

function RISCVVFmaF64x2(const a, b, c: TVecF64x2): TVecF64x2;
begin
  RISCVVFmaF64x2Asm(a, b, c, Result);
end;

// =============================================================
// I64x2 Operations (128-bit, 2x Int64)
// =============================================================

procedure RISCVVAddI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vadd.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVAddI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  RISCVVAddI64x2Asm(a, b, Result);
end;

procedure RISCVVSubI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vsub.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVSubI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  RISCVVSubI64x2Asm(a, b, Result);
end;

procedure RISCVVAndI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vand.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVAndI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  RISCVVAndI64x2Asm(a, b, Result);
end;

procedure RISCVVOrI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vor.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVOrI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  RISCVVOrI64x2Asm(a, b, Result);
end;

procedure RISCVVXorI64x2Asm(const a, b: TVecI64x2; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vxor.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVXorI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  RISCVVXorI64x2Asm(a, b, Result);
end;

procedure RISCVVNotI64x2Asm(const a: TVecI64x2; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vxor.vi v0, v0, -1
  vse64.v v0, (a1)
end;

function RISCVVNotI64x2(const a: TVecI64x2): TVecI64x2;
begin
  RISCVVNotI64x2Asm(a, Result);
end;

procedure RISCVVShiftLeftI64x2Asm(const a: TVecI64x2; count: Integer; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vsll.vx v0, v0, a1
  vse64.v v0, (a2)
end;

function RISCVVShiftLeftI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  RISCVVShiftLeftI64x2Asm(a, count, Result);
end;

procedure RISCVVShiftRightI64x2Asm(const a: TVecI64x2; count: Integer; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vsrl.vx v0, v0, a1
  vse64.v v0, (a2)
end;

function RISCVVShiftRightI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  RISCVVShiftRightI64x2Asm(a, count, Result);
end;

procedure RISCVVShiftRightArithI64x2Asm(const a: TVecI64x2; count: Integer; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vsra.vx v0, v0, a1
  vse64.v v0, (a2)
end;

function RISCVVShiftRightArithI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  RISCVVShiftRightArithI64x2Asm(a, count, Result);
end;

// =============================================================
// U32x4 Operations (128-bit, 4x UInt32)
// =============================================================

procedure RISCVVAddU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vadd.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVAddU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVAddU32x4Asm(a, b, Result);
end;

procedure RISCVVSubU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vsub.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVSubU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVSubU32x4Asm(a, b, Result);
end;

procedure RISCVVMulU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmul.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVMulU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVMulU32x4Asm(a, b, Result);
end;

procedure RISCVVMinU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vminu.vv v0, v0, v1   // Unsigned min
  vse32.v v0, (a2)
end;

function RISCVVMinU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVMinU32x4Asm(a, b, Result);
end;

procedure RISCVVMaxU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmaxu.vv v0, v0, v1   // Unsigned max
  vse32.v v0, (a2)
end;

function RISCVVMaxU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVMaxU32x4Asm(a, b, Result);
end;

function RISCVVCmpLtU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsltu.vv v0, v0, v1  // Unsigned less than
  vmv.x.s a0, v0
end;

function RISCVVCmpLeU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsleu.vv v0, v0, v1  // Unsigned less than or equal
  vmv.x.s a0, v0
end;

function RISCVVCmpGtU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsltu.vv v0, v1, v0  // Unsigned greater than
  vmv.x.s a0, v0
end;

// =============================================================
// I16x8 Operations (128-bit, 8x Int16)
// =============================================================

function RISCVVAddI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vadd.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVSubI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vsub.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVMulI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmul.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVMinI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmin.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVMaxI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmax.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVAndI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vand.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVOrI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vor.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVXorI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vxor.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vsll.vx v0, v0, a1
  vse16.v v0, (a0)
end;

function RISCVVShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vsrl.vx v0, v0, a1
  vse16.v v0, (a0)
end;

function RISCVVShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vsra.vx v0, v0, a1
  vse16.v v0, (a0)
end;

// =============================================================
// I8x16 Operations (128-bit, 16x Int8)
// =============================================================

function RISCVVAddI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vadd.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVSubI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vsub.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVMinI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmin.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVMaxI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmax.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVAndI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vand.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVOrI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vor.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVXorI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vxor.vv v0, v0, v1
  vse8.v v0, (a0)
end;

// =============================================================
// 256-bit Operations (F32x8, F64x4, I32x8) using LMUL=2
// =============================================================

function RISCVVAddF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1   // LMUL=2 for 256-bit
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vfadd.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVSubF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vfsub.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMulF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vfmul.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVDivF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vfdiv.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMinF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vfmin.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMaxF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vfmax.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVAbsF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vfsgnjx.vv v0, v0, v0
  vse32.v v0, (a0)
end;

function RISCVVSqrtF32x8(const a: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vfsqrt.v v0, v0
  vse32.v v0, (a0)
end;

function RISCVVAddF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vfadd.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVSubF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vfsub.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVMulF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vfmul.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVDivF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vfdiv.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVAddI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  // ABI reminder: a0 = &Result, a1 = &a, a2 = &b.
  // LMUL=2 keeps this 256-bit pair on disjoint v0/v2 register groups.
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vadd.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVSubI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vsub.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMulI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vmul.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVAndI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vand.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVOrI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vor.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVXorI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vxor.vv v0, v0, v2
  vse32.v v0, (a0)
end;

// =============================================================
// 512-bit Operations (F32x16, I32x16) using LMUL=4
// =============================================================

function RISCVVAddF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2  // LMUL=4 for 512-bit
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vfadd.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVSubF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vfsub.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVMulF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vfmul.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVDivF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vfdiv.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVAddI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  // LMUL=4: keep the two 512-bit operands in v0 and v4 groups so future
  // edits do not accidentally overlap operand/result register groups.
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vadd.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVSubI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vsub.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVMulI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vmul.vv v0, v0, v4
  vse32.v v0, (a0)
end;

procedure RISCVVClampF32x4Asm(const a, minVal, maxVal: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)        // a
  vle32.v v1, (a1)        // minVal
  vle32.v v2, (a2)        // maxVal
  vfmax.vv v0, v0, v1     // max(a, minVal)
  vfmin.vv v0, v0, v2     // min(result, maxVal)
  vse32.v v0, (a3)
end;

function RISCVVClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
begin
  RISCVVClampF32x4Asm(a, minVal, maxVal, Result);
end;

// =============================================================
// F32x4 规约操作
// =============================================================

function RISCVVReduceAddF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  // 使用向量规约加法
  vmv.s.x v1, zero        // 初始值 0
  vfredusum.vs v1, v0, v1 // 规约加法
  vfmv.f.s f10, v1        // 结果到浮点寄存器
end;

function RISCVVReduceMinF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfredmin.vs v1, v0, v0  // 规约最小值
  vfmv.f.s f10, v1
end;

function RISCVVReduceMaxF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfredmax.vs v1, v0, v0  // 规约最大值
  vfmv.f.s f10, v1
end;

// =============================================================
// F32x4 Load/Store/Splat/Zero
// =============================================================

procedure RISCVVLoadF32x4Asm(p: PSingle; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vse32.v v0, (a1)
end;

function RISCVVLoadF32x4(p: PSingle): TVecF32x4;
begin
  RISCVVLoadF32x4Asm(p, Result);
end;

procedure RISCVVStoreF32x4(p: PSingle; const a: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a1)        // a1 = &a
  vse32.v v0, (a0)        // a0 = p
end;

procedure RISCVVStoreF32x4Aligned(p: PSingle; const a: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a1)
  vse32.v v0, (a0)
end;

procedure RISCVVStoreF32x8(p: PSingle; const a: TVecF32x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vse32.v v0, (a0)
end;

procedure RISCVVStoreF32x16(p: PSingle; const a: TVecF32x16); assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vse32.v v0, (a0)
end;

procedure RISCVVStoreF64x4(p: PDouble; const a: TVecF64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vse64.v v0, (a0)
end;

procedure RISCVVStoreF64x8(p: PDouble; const a: TVecF64x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vse64.v v0, (a0)
end;

procedure RISCVVStoreI64x4(p: PInt64; const a: TVecI64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vse64.v v0, (a0)
end;

procedure RISCVVSplatF32x4Asm(value: Single; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vfmv.v.f v0, f10
  vse32.v v0, (a0)
end;

function RISCVVSplatF32x4(value: Single): TVecF32x4;
begin
  RISCVVSplatF32x4Asm(value, Result);
end;

procedure RISCVVZeroF32x4Asm(var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vmv.v.i v0, 0           // 所有元素置零
  vse32.v v0, (a0)
end;

function RISCVVZeroF32x4: TVecF32x4;
begin
  RISCVVZeroF32x4Asm(Result);
end;

procedure RISCVVClampF64x2Asm(const a, minVal, maxVal: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vle64.v v2, (a2)
  vfmax.vv v0, v0, v1
  vfmin.vv v0, v0, v2
  vse64.v v0, (a3)
end;

function RISCVVClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
begin
  RISCVVClampF64x2Asm(a, minVal, maxVal, Result);
end;

// =============================================================
// F64x2 规约操作
// =============================================================

function RISCVVReduceAddF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vmv.s.x v1, zero
  vfredusum.vs v1, v0, v1
  vfmv.f.s f10, v1
end;

function RISCVVReduceMinF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vfredmin.vs v1, v0, v0
  vfmv.f.s f10, v1
end;

function RISCVVReduceMaxF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vfredmax.vs v1, v0, v0
  vfmv.f.s f10, v1
end;

// =============================================================
// F64x2 Load/Store/Splat/Zero
// =============================================================

procedure RISCVVLoadF64x2Asm(p: PDouble; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vse64.v v0, (a1)
end;

function RISCVVLoadF64x2(p: PDouble): TVecF64x2;
begin
  RISCVVLoadF64x2Asm(p, Result);
end;

procedure RISCVVStoreF64x2(p: PDouble; const a: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a1)
  vse64.v v0, (a0)
end;

procedure RISCVVSplatF64x2Asm(value: Double; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vfmv.v.f v0, f10
  vse64.v v0, (a0)
end;

function RISCVVSplatF64x2(value: Double): TVecF64x2;
begin
  RISCVVSplatF64x2Asm(value, Result);
end;

procedure RISCVVZeroF64x2Asm(var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vmv.v.i v0, 0
  vse64.v v0, (a0)
end;

function RISCVVZeroF64x2: TVecF64x2;
begin
  RISCVVZeroF64x2Asm(Result);
end;

// =============================================================
// U32x4 扩展操作
// =============================================================

procedure RISCVVAndU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vand.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVAndU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVAndU32x4Asm(a, b, Result);
end;

procedure RISCVVOrU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vor.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVOrU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVOrU32x4Asm(a, b, Result);
end;

procedure RISCVVXorU32x4Asm(const a, b: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vxor.vv v0, v0, v1
  vse32.v v0, (a2)
end;

function RISCVVXorU32x4(const a, b: TVecU32x4): TVecU32x4;
begin
  RISCVVXorU32x4Asm(a, b, Result);
end;

procedure RISCVVNotU32x4Asm(const a: TVecU32x4; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vxor.vi v0, v0, -1
  vse32.v v0, (a1)
end;

function RISCVVNotU32x4(const a: TVecU32x4): TVecU32x4;
begin
  RISCVVNotU32x4Asm(a, Result);
end;

procedure RISCVVShiftLeftU32x4Asm(const a: TVecU32x4; count: Integer; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vsll.vx v0, v0, a1
  vse32.v v0, (a2)
end;

function RISCVVShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
begin
  RISCVVShiftLeftU32x4Asm(a, count, Result);
end;

procedure RISCVVShiftRightU32x4Asm(const a: TVecU32x4; count: Integer; var r: TVecU32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vsrl.vx v0, v0, a1
  vse32.v v0, (a2)
end;

function RISCVVShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
begin
  RISCVVShiftRightU32x4Asm(a, count, Result);
end;

function RISCVVCmpEqU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmseq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpNeU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGeU32x4(const a, b: TVecU32x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsltu.vv v0, v0, v1    // a < b
  vmnand.mm v0, v0, v0          // NOT -> a >= b
  vmv.x.s a0, v0
end;

// =============================================================
// U64x2 操作
// =============================================================

procedure RISCVVAddU64x2Asm(const a, b: TVecU64x2; var r: TVecU64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vadd.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVAddU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  RISCVVAddU64x2Asm(a, b, Result);
end;

procedure RISCVVSubU64x2Asm(const a, b: TVecU64x2; var r: TVecU64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vsub.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVSubU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  RISCVVSubU64x2Asm(a, b, Result);
end;

procedure RISCVVAndU64x2Asm(const a, b: TVecU64x2; var r: TVecU64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vand.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVAndU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  RISCVVAndU64x2Asm(a, b, Result);
end;

procedure RISCVVOrU64x2Asm(const a, b: TVecU64x2; var r: TVecU64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vor.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVOrU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  RISCVVOrU64x2Asm(a, b, Result);
end;

procedure RISCVVXorU64x2Asm(const a, b: TVecU64x2; var r: TVecU64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vxor.vv v0, v0, v1
  vse64.v v0, (a2)
end;

function RISCVVXorU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  RISCVVXorU64x2Asm(a, b, Result);
end;

procedure RISCVVNotU64x2Asm(const a: TVecU64x2; var r: TVecU64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vxor.vi v0, v0, -1
  vse64.v v0, (a1)
end;

function RISCVVNotU64x2(const a: TVecU64x2): TVecU64x2;
begin
  RISCVVNotU64x2Asm(a, Result);
end;

// =============================================================
// U16x8 操作
// =============================================================

function RISCVVAddU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vadd.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVSubU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vsub.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVMulU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmul.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVMinU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vminu.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVMaxU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmaxu.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVAndU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vand.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVOrU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vor.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVXorU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vxor.vv v0, v0, v1
  vse16.v v0, (a0)
end;

function RISCVVShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vsll.vx v0, v0, a1
  vse16.v v0, (a0)
end;

function RISCVVShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vsrl.vx v0, v0, a1
  vse16.v v0, (a0)
end;

// =============================================================
// U8x16 操作
// =============================================================

function RISCVVAddU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vadd.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVSubU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vsub.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVMinU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vminu.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVMaxU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmaxu.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVAndU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vand.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVOrU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vor.vv v0, v0, v1
  vse8.v v0, (a0)
end;

function RISCVVXorU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vxor.vv v0, v0, v1
  vse8.v v0, (a0)
end;

// =============================================================
// I64x2 比较操作
// =============================================================

function RISCVVCmpEqI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmseq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmslt.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmsle.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmslt.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

// =============================================================
// F64x2 比较操作
// =============================================================

function RISCVVCmpEqF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmfeq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLtF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmflt.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmfle.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmflt.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmfle.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeF64x2(const a, b: TVecF64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmfne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

// =============================================================
// Select 操作
// =============================================================

procedure RISCVVSelectF32x4Asm(const mask: TMask4; const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vmv.s.x v0, a0
  vle32.v v1, (a1)
  vle32.v v2, (a2)
  vmerge.vvm v1, v2, v1, v0
  vse32.v v1, (a3)
end;

function RISCVVSelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVSelectF32x4Asm(mask, a, b, Result);
end;

procedure RISCVVSelectF64x2Asm(const mask: TMask2; const a, b: TVecF64x2; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vmv.s.x v0, a0
  vle64.v v1, (a1)
  vle64.v v2, (a2)
  vmerge.vvm v1, v2, v1, v0
  vse64.v v1, (a3)
end;

function RISCVVSelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
begin
  RISCVVSelectF64x2Asm(mask, a, b, Result);
end;

// =============================================================
// 256-bit FMA 操作
// =============================================================

function RISCVVFmaF32x8(const a, b, c: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vle32.v v4, (a3)
  vfmadd.vv v0, v2, v4
  vse32.v v0, (a0)
end;

function RISCVVMinF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vfmin.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVMaxF64x4(const a, b: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vfmax.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVAbsF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vfsgnjx.vv v0, v0, v0
  vse64.v v0, (a0)
end;

function RISCVVSqrtF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vfsqrt.v v0, v0
  vse64.v v0, (a0)
end;

function RISCVVMinI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vmin.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMaxI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vmax.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVNotI32x8(const a: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vxor.vi v0, v0, -1
  vse32.v v0, (a0)
end;

function RISCVVShiftLeftI32x8Asm(const a: TVecI32x8; count: Integer): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vsll.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftLeftI32x8(a, count));
  Result := RISCVVShiftLeftI32x8Asm(a, count);
end;

function RISCVVShiftRightI32x8Asm(const a: TVecI32x8; count: Integer): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vsrl.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftRightI32x8(a, count));
  Result := RISCVVShiftRightI32x8Asm(a, count);
end;

function RISCVVShiftRightArithI32x8Asm(const a: TVecI32x8; count: Integer): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vsra.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftRightArithI32x8(a, count));
  Result := RISCVVShiftRightArithI32x8Asm(a, count);
end;

// =============================================================
// 512-bit 扩展操作
// =============================================================

function RISCVVMinF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vfmin.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVMaxF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vfmax.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVAbsF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vfsgnjx.vv v0, v0, v0
  vse32.v v0, (a0)
end;

function RISCVVSqrtF32x16(const a: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vfsqrt.v v0, v0
  vse32.v v0, (a0)
end;

function RISCVVAndI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vand.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVOrI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vor.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVXorI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vxor.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVMinI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vmin.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVMaxI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vmax.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVShiftLeftI32x16Asm(const a: TVecI32x16; count: Integer): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vsll.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftLeftI32x16(a, count));
  Result := RISCVVShiftLeftI32x16Asm(a, count);
end;

function RISCVVShiftRightI32x16Asm(const a: TVecI32x16; count: Integer): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vsrl.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
begin
  if (count < 0) or (count >= 32) then
    Exit(ScalarShiftRightI32x16(a, count));
  Result := RISCVVShiftRightI32x16Asm(a, count);
end;

// =============================================================
// F64x8 (512-bit) 操作
// =============================================================

function RISCVVAddF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vfadd.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVSubF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vfsub.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVMulF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vfmul.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVDivF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vfdiv.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVMinF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vfmin.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVMaxF64x8(const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vfmax.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVAbsF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vfsgnjx.vv v0, v0, v0
  vse64.v v0, (a0)
end;

function RISCVVSqrtF64x8(const a: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vfsqrt.v v0, v0
  vse64.v v0, (a0)
end;

// =============================================================
// I64x4 操作 (256-bit, 4x Int64)
// =============================================================

function RISCVVAddI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vadd.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVSubI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vsub.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVAndI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vand.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVOrI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vor.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVXorI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vxor.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVNotI64x4(const a: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vxor.vi v0, v0, -1
  vse64.v v0, (a0)
end;

function RISCVVAndNotI64x4(const a, b: TVecI64x4): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vxor.vi v0, v0, -1
  vand.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVShiftLeftI64x4Asm(const a: TVecI64x4; count: Integer): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vsll.vx v0, v0, a2
  vse64.v v0, (a0)
end;

function RISCVVShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftLeftI64x4(a, count));
  Result := RISCVVShiftLeftI64x4Asm(a, count);
end;

function RISCVVShiftRightI64x4Asm(const a: TVecI64x4; count: Integer): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vsrl.vx v0, v0, a2
  vse64.v v0, (a0)
end;

function RISCVVShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftRightI64x4(a, count));
  Result := RISCVVShiftRightI64x4Asm(a, count);
end;

function RISCVVShiftRightArithI64x4Asm(const a: TVecI64x4; count: Integer): TVecI64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vsra.vx v0, v0, a2
  vse64.v v0, (a0)
end;

function RISCVVShiftRightArithI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
begin
  if (count < 0) or (count >= 64) then
    Exit(ScalarShiftRightArithI64x4(a, count));
  Result := RISCVVShiftRightArithI64x4Asm(a, count);
end;

function RISCVVCmpEqI64x4(const a, b: TVecI64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmseq.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI64x4(const a, b: TVecI64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmslt.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI64x4(const a, b: TVecI64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmsle.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI64x4(const a, b: TVecI64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmslt.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI64x4(const a, b: TVecI64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmslt.vv v0, v0, v2
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI64x4(const a, b: TVecI64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmsne.vv v0, v0, v2
  vmv.x.s a0, v0
end;

// =============================================================
// I64x8 操作 (512-bit, 8x Int64)
// =============================================================

function RISCVVAddI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
  // LMUL=4 on e64 vectors as well: v0/v4 separation is intentional and is
  // part of the reviewed wide-vector grouping contract for 512-bit RVV ops.
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vadd.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVSubI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vsub.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVAndI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vand.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVOrI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vor.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVXorI64x8(const a, b: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vxor.vv v0, v0, v4
  vse64.v v0, (a0)
end;

function RISCVVCmpEqI64x8(const a, b: TVecI64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmseq.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI64x8(const a, b: TVecI64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmslt.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI64x8(const a, b: TVecI64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmsle.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI64x8(const a, b: TVecI64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmslt.vv v0, v4, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI64x8(const a, b: TVecI64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmslt.vv v0, v0, v4
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI64x8(const a, b: TVecI64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmsne.vv v0, v0, v4
  vmv.x.s a0, v0
end;

// =============================================================
// U64x4 操作 (256-bit, 4x UInt64)
// =============================================================

function RISCVVAddU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vadd.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVSubU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vsub.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVAndU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vand.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVOrU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vor.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVXorU64x4(const a, b: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vxor.vv v0, v0, v2
  vse64.v v0, (a0)
end;

function RISCVVCmpEqU64x4(const a, b: TVecU64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmseq.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLtU64x4(const a, b: TVecU64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmsltu.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLeU64x4(const a, b: TVecU64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmsleu.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpGtU64x4(const a, b: TVecU64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmsltu.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeU64x4(const a, b: TVecU64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmsltu.vv v0, v0, v2
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

// =============================================================
// U32x8 操作 (256-bit, 8x UInt32)
// =============================================================

function RISCVVAddU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  // Unsigned arithmetic shares the same ABI/LMUL=2 layout as I32x8.
  // Keep unsigned min/max in the dedicated vminu/vmaxu family below.
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vadd.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVSubU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vsub.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMulU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vmul.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVAndU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vand.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVOrU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vor.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVXorU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vxor.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMinU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vminu.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVMaxU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vmaxu.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVCmpEqU32x8(const a, b: TVecU32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmseq.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLtU32x8(const a, b: TVecU32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmsltu.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLeU32x8(const a, b: TVecU32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmsleu.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpGtU32x8(const a, b: TVecU32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmsltu.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeU32x8(const a, b: TVecU32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmsltu.vv v0, v0, v2
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

// =============================================================
// AndNot 扩展操作
// =============================================================

function RISCVVAndNotI32x8(const a, b: TVecI32x8): TVecI32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vxor.vi v0, v0, -1
  vand.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVAndNotI32x16(const a, b: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vxor.vi v0, v0, -1
  vand.vv v0, v0, v4
  vse32.v v0, (a0)
end;

function RISCVVAndNotU32x4(const a, b: TVecU32x4): TVecU32x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vxor.vi v0, v0, -1
  vand.vv v0, v0, v1
  vse32.v v0, (a0)
end;

function RISCVVAndNotU32x8(const a, b: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vle32.v v2, (a2)
  vxor.vi v0, v0, -1
  vand.vv v0, v0, v2
  vse32.v v0, (a0)
end;

function RISCVVAndNotI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vxor.vi v0, v0, -1
  vand.vv v0, v0, v1
  vse16.v v0, (a0)
end;

// =============================================================
// 256-bit 舍入/Clamp 操作
// =============================================================

// Keep wide Floor/Ceil/Round/Trunc and F32 Clamp on the canonical base scalar
// slots until RVV-specific semantics are implemented and re-verified. F64 wide
// Clamp stays backend-owned because it still carries local NaN/signed-zero
// fallback behavior.
function RISCVVClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vle64.v v4, (a3)
  vfmax.vv v0, v0, v2
  vfmin.vv v0, v0, v4
  vse64.v v0, (a0)
end;

// =============================================================
// 512-bit Clamp 操作
// =============================================================

function RISCVVClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vle64.v v8, (a3)
  vfmax.vv v0, v0, v4
  vfmin.vv v0, v0, v8
  vse64.v v0, (a0)
end;

// =============================================================
// 256-bit/512-bit 比较操作
// =============================================================

function RISCVVCmpEqF32x8(const a, b: TVecF32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmfeq.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLtF32x8(const a, b: TVecF32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmflt.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLeF32x8(const a, b: TVecF32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmfle.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpGtF32x8(const a, b: TVecF32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmflt.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeF32x8(const a, b: TVecF32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmfle.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeF32x8(const a, b: TVecF32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmfne.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpEqF64x4(const a, b: TVecF64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmfeq.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLtF64x4(const a, b: TVecF64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmflt.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLeF64x4(const a, b: TVecF64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmfle.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpGtF64x4(const a, b: TVecF64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmflt.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeF64x4(const a, b: TVecF64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmfle.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeF64x4(const a, b: TVecF64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v2, (a1)
  vmfne.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpEqI32x8(const a, b: TVecI32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmseq.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI32x8(const a, b: TVecI32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmslt.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI32x8(const a, b: TVecI32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmsle.vv v0, v0, v2
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI32x8(const a, b: TVecI32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmslt.vv v0, v2, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI32x8(const a, b: TVecI32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmslt.vv v0, v0, v2
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI32x8(const a, b: TVecI32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v2, (a1)
  vmsne.vv v0, v0, v2
  vmv.x.s a0, v0
end;

// =============================================================
// I32x16 比较操作
// =============================================================

function RISCVVCmpEqI32x16(const a, b: TVecI32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmseq.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI32x16(const a, b: TVecI32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmslt.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI32x16(const a, b: TVecI32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmsle.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI32x16(const a, b: TVecI32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmslt.vv v0, v4, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI32x16(const a, b: TVecI32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmslt.vv v0, v0, v4
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI32x16(const a, b: TVecI32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmsne.vv v0, v0, v4
  vmv.x.s a0, v0
end;

// =============================================================
// 窄整数比较操作 I16x8/I8x16
// =============================================================

function RISCVVCmpEqI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmseq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmslt.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmsle.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmslt.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmslt.vv v0, v0, v1
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI16x8(const a, b: TVecI16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpEqI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmseq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLtI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmslt.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmsle.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmslt.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmslt.vv v0, v0, v1
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeI8x16(const a, b: TVecI8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

// =============================================================
// 无符号窄整数比较 U16x8/U8x16
// =============================================================

function RISCVVCmpEqU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmseq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLtU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmsltu.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmsleu.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmsltu.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmsltu.vv v0, v0, v1
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpEqU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmseq.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLtU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmsltu.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpLeU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmsleu.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGtU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmsltu.vv v0, v1, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmsltu.vv v0, v0, v1
  vmnand.mm v0, v0, v0
  vmv.x.s a0, v0
end;

// =============================================================
// 512-bit 比较操作
// =============================================================

function RISCVVCmpEqF32x16(const a, b: TVecF32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmfeq.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLtF32x16(const a, b: TVecF32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmflt.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLeF32x16(const a, b: TVecF32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmfle.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpGtF32x16(const a, b: TVecF32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmflt.vv v0, v4, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeF32x16(const a, b: TVecF32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmfle.vv v0, v4, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeF32x16(const a, b: TVecF32x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vle32.v v4, (a1)
  vmfne.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpEqF64x8(const a, b: TVecF64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmfeq.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLtF64x8(const a, b: TVecF64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmflt.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpLeF64x8(const a, b: TVecF64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmfle.vv v0, v0, v4
  vmv.x.s a0, v0
end;

function RISCVVCmpGtF64x8(const a, b: TVecF64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmflt.vv v0, v4, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpGeF64x8(const a, b: TVecF64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmfle.vv v0, v4, v0
  vmv.x.s a0, v0
end;

function RISCVVCmpNeF64x8(const a, b: TVecF64x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vle64.v v4, (a1)
  vmfne.vv v0, v0, v4
  vmv.x.s a0, v0
end;

// =============================================================
// FMA 256-bit/512-bit 操作
// =============================================================

function RISCVVFmaF64x4(const a, b, c: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vle64.v v2, (a2)
  vle64.v v4, (a3)
  vfmadd.vv v0, v2, v4
  vse64.v v0, (a0)
end;

function RISCVVFmaF32x16(const a, b, c: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vle32.v v4, (a2)
  vle32.v v8, (a3)
  vfmadd.vv v0, v4, v8
  vse32.v v0, (a0)
end;

function RISCVVFmaF64x8(const a, b, c: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vle64.v v4, (a2)
  vle64.v v8, (a3)
  vfmadd.vv v0, v4, v8
  vse64.v v0, (a0)
end;

// =============================================================
// Select 256-bit/512-bit 操作
// =============================================================

function RISCVVSelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vmv.s.x v0, a1
  vle32.v v4, (a2)
  vle32.v v8, (a3)
  vmerge.vvm v4, v8, v4, v0
  vse32.v v4, (a0)
end;

function RISCVVSelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vmv.s.x v0, a1
  vle64.v v4, (a2)
  vle64.v v8, (a3)
  vmerge.vvm v4, v8, v4, v0
  vse64.v v4, (a0)
end;

// =============================================================
// 256-bit/512-bit Load/Store/Splat/Zero Operations
// =============================================================

procedure RISCVVLoadF32x8Asm(p: PSingle; var r: TVecF32x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vse32.v v0, (a1)
end;

function RISCVVLoadF32x8(p: PSingle): TVecF32x8;
begin
  RISCVVLoadF32x8Asm(p, Result);
end;

procedure RISCVVLoadF32x16Asm(p: PSingle; var r: TVecF32x16); assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vse32.v v0, (a1)
end;

function RISCVVLoadF32x16(p: PSingle): TVecF32x16;
begin
  RISCVVLoadF32x16Asm(p, Result);
end;

procedure RISCVVLoadF64x4Asm(p: PDouble; var r: TVecF64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vse64.v v0, (a1)
end;

function RISCVVLoadF64x4(p: PDouble): TVecF64x4;
begin
  RISCVVLoadF64x4Asm(p, Result);
end;

procedure RISCVVLoadF64x8Asm(p: PDouble; var r: TVecF64x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vse64.v v0, (a1)
end;

function RISCVVLoadF64x8(p: PDouble): TVecF64x8;
begin
  RISCVVLoadF64x8Asm(p, Result);
end;

procedure RISCVVLoadI64x4Asm(p: PInt64; var r: TVecI64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vse64.v v0, (a1)
end;

function RISCVVLoadI64x4(p: PInt64): TVecI64x4;
begin
  RISCVVLoadI64x4Asm(p, Result);
end;

procedure RISCVVLoadF32x4AlignedAsm(p: PSingle; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vse32.v v0, (a1)
end;

function RISCVVLoadF32x4Aligned(p: PSingle): TVecF32x4;
begin
  RISCVVLoadF32x4AlignedAsm(p, Result);
end;

procedure RISCVVSplatF32x8Asm(value: Single; var r: TVecF32x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vfmv.v.f v0, f10
  vse32.v v0, (a0)
end;

function RISCVVSplatF32x8(value: Single): TVecF32x8;
begin
  RISCVVSplatF32x8Asm(value, Result);
end;

procedure RISCVVSplatF32x16Asm(value: Single; var r: TVecF32x16); assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vfmv.v.f v0, f10
  vse32.v v0, (a0)
end;

function RISCVVSplatF32x16(value: Single): TVecF32x16;
begin
  RISCVVSplatF32x16Asm(value, Result);
end;

procedure RISCVVSplatF64x4Asm(value: Double; var r: TVecF64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vfmv.v.f v0, f10
  vse64.v v0, (a0)
end;

function RISCVVSplatF64x4(value: Double): TVecF64x4;
begin
  RISCVVSplatF64x4Asm(value, Result);
end;

procedure RISCVVSplatF64x8Asm(value: Double; var r: TVecF64x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vfmv.v.f v0, f10
  vse64.v v0, (a0)
end;

function RISCVVSplatF64x8(value: Double): TVecF64x8;
begin
  RISCVVSplatF64x8Asm(value, Result);
end;

procedure RISCVVSplatI64x4Asm(value: Int64; var r: TVecI64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vmv.v.x v0, a0
  vse64.v v0, (a1)
end;

function RISCVVSplatI64x4(value: Int64): TVecI64x4;
begin
  RISCVVSplatI64x4Asm(value, Result);
end;

procedure RISCVVZeroF32x8Asm(var r: TVecF32x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vmv.v.i v0, 0
  vse32.v v0, (a0)
end;

function RISCVVZeroF32x8: TVecF32x8;
begin
  RISCVVZeroF32x8Asm(Result);
end;

procedure RISCVVZeroF32x16Asm(var r: TVecF32x16); assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vmv.v.i v0, 0
  vse32.v v0, (a0)
end;

function RISCVVZeroF32x16: TVecF32x16;
begin
  RISCVVZeroF32x16Asm(Result);
end;

procedure RISCVVZeroF64x4Asm(var r: TVecF64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vmv.v.i v0, 0
  vse64.v v0, (a0)
end;

function RISCVVZeroF64x4: TVecF64x4;
begin
  RISCVVZeroF64x4Asm(Result);
end;

procedure RISCVVZeroF64x8Asm(var r: TVecF64x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vmv.v.i v0, 0
  vse64.v v0, (a0)
end;

function RISCVVZeroF64x8: TVecF64x8;
begin
  RISCVVZeroF64x8Asm(Result);
end;

procedure RISCVVZeroI64x4Asm(var r: TVecI64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vmv.v.i v0, 0
  vse64.v v0, (a0)
end;

function RISCVVZeroI64x4: TVecI64x4;
begin
  RISCVVZeroI64x4Asm(Result);
end;

// =============================================================
// 256-bit/512-bit Reduction Operations
// =============================================================

function RISCVVReduceAddF32x8(const a: TVecF32x8): Single; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vfmv.s.f v2, f10            // f10 = 0.0 initial value
  vfredusum.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

function RISCVVReduceAddF32x16(const a: TVecF32x16): Single; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vfmv.s.f v4, f10
  vfredusum.vs v4, v0, v4
  vfmv.f.s f10, v4
end;

function RISCVVReduceAddF64x4(const a: TVecF64x4): Double; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vfmv.s.f v2, f10
  vfredusum.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

function RISCVVReduceAddF64x8(const a: TVecF64x8): Double; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vfmv.s.f v4, f10
  vfredusum.vs v4, v0, v4
  vfmv.f.s f10, v4
end;

function RISCVVReduceMinF32x8(const a: TVecF32x8): Single; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vmv.v.x v2, zero
  lui t0, 0x7F800            // +Infinity as initial
  vmv.s.x v2, t0
  vfredmin.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

function RISCVVReduceMinF32x16(const a: TVecF32x16): Single; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vmv.v.x v4, zero
  lui t0, 0x7F800
  vmv.s.x v4, t0
  vfredmin.vs v4, v0, v4
  vfmv.f.s f10, v4
end;

function RISCVVReduceMinF64x4(const a: TVecF64x4): Double; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  li t0, 0x7FF0000000000000  // +Infinity
  vmv.v.x v2, zero
  vmv.s.x v2, t0
  vfredmin.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

function RISCVVReduceMinF64x8(const a: TVecF64x8): Double; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  li t0, 0x7FF0000000000000
  vmv.v.x v4, zero
  vmv.s.x v4, t0
  vfredmin.vs v4, v0, v4
  vfmv.f.s f10, v4
end;

function RISCVVReduceMaxF32x8(const a: TVecF32x8): Single; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vmv.v.x v2, zero
  lui t0, 0xFF800            // -Infinity as initial
  vmv.s.x v2, t0
  vfredmax.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

function RISCVVReduceMaxF32x16(const a: TVecF32x16): Single; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vmv.v.x v4, zero
  lui t0, 0xFF800
  vmv.s.x v4, t0
  vfredmax.vs v4, v0, v4
  vfmv.f.s f10, v4
end;

function RISCVVReduceMaxF64x4(const a: TVecF64x4): Double; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  li t0, 0xFFF0000000000000  // -Infinity
  vmv.v.x v2, zero
  vmv.s.x v2, t0
  vfredmax.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

function RISCVVReduceMaxF64x8(const a: TVecF64x8): Double; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  li t0, 0xFFF0000000000000
  vmv.v.x v4, zero
  vmv.s.x v4, t0
  vfredmax.vs v4, v0, v4
  vfmv.f.s f10, v4
end;

// ReduceMul 使用连续乘法实现
function RISCVVReduceMulF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vslidedown.vi v1, v0, 2    // [2,3,x,x]
  vfmul.vv v0, v0, v1        // [0*2, 1*3, x, x]
  vslidedown.vi v1, v0, 1    // [1*3,x,x,x]
  vfmul.vv v0, v0, v1        // [(0*2)*(1*3), ...]
  vfmv.f.s f10, v0
end;

function RISCVVReduceMulF32x8(const a: TVecF32x8): Single; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vslidedown.vi v2, v0, 4
  vfmul.vv v0, v0, v2
  vsetivli zero, 4, 0xD0
  vslidedown.vi v1, v0, 2
  vfmul.vv v0, v0, v1
  vslidedown.vi v1, v0, 1
  vfmul.vv v0, v0, v1
  vfmv.f.s f10, v0
end;

function RISCVVReduceMulF32x16(const a: TVecF32x16): Single; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vslidedown.vi v4, v0, 8
  vfmul.vv v0, v0, v4
  vsetivli zero, 8, 0xD1
  vslidedown.vi v2, v0, 4
  vfmul.vv v0, v0, v2
  vsetivli zero, 4, 0xD0
  vslidedown.vi v1, v0, 2
  vfmul.vv v0, v0, v1
  vslidedown.vi v1, v0, 1
  vfmul.vv v0, v0, v1
  vfmv.f.s f10, v0
end;

function RISCVVReduceMulF64x2(const a: TVecF64x2): Double; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vslidedown.vi v1, v0, 1
  vfmul.vv v0, v0, v1
  vfmv.f.s f10, v0
end;

function RISCVVReduceMulF64x4(const a: TVecF64x4): Double; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vslidedown.vi v2, v0, 2
  vfmul.vv v0, v0, v2
  vsetivli zero, 2, 0xD8
  vslidedown.vi v1, v0, 1
  vfmul.vv v0, v0, v1
  vfmv.f.s f10, v0
end;

function RISCVVReduceMulF64x8(const a: TVecF64x8): Double; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a0)
  vslidedown.vi v4, v0, 4
  vfmul.vv v0, v0, v4
  vsetivli zero, 4, 0xD9
  vslidedown.vi v2, v0, 2
  vfmul.vv v0, v0, v2
  vsetivli zero, 2, 0xD8
  vslidedown.vi v1, v0, 1
  vfmul.vv v0, v0, v1
  vfmv.f.s f10, v0
end;

// =============================================================
// Bitwise NOT Operations
// =============================================================

function RISCVVNotI16x8(const a: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vxor.vi v0, v0, -1
  vse16.v v0, (a1)
end;

function RISCVVNotI8x16(const a: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vxor.vi v0, v0, -1
  vse8.v v0, (a1)
end;

function RISCVVNotU16x8(const a: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vxor.vi v0, v0, -1
  vse16.v v0, (a1)
end;

function RISCVVNotU8x16(const a: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vxor.vi v0, v0, -1
  vse8.v v0, (a1)
end;

{$IFDEF RISCVV_ASSEMBLY}
function RISCVVAndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
begin
  Result := RISCVVAndI8x16(RISCVVNotI8x16(a), b);
end;

function RISCVVAndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
begin
  Result := RISCVVAndU16x8(RISCVVNotU16x8(a), b);
end;

function RISCVVAndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
begin
  Result := RISCVVAndU8x16(RISCVVNotU8x16(a), b);
end;
{$ENDIF}

function RISCVVNotI32x16(const a: TVecI32x16): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vxor.vi v0, v0, -1
  vse32.v v0, (a0)
end;

function RISCVVNotI64x8(const a: TVecI64x8): TVecI64x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xDA
  vle64.v v0, (a1)
  vxor.vi v0, v0, -1
  vse64.v v0, (a0)
end;

function RISCVVNotU32x8(const a: TVecU32x8): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vxor.vi v0, v0, -1
  vse32.v v0, (a0)
end;

function RISCVVNotU64x4(const a: TVecU64x4): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vxor.vi v0, v0, -1
  vse64.v v0, (a0)
end;

// =============================================================
// Unsigned Shift Operations (256-bit)
// =============================================================

function RISCVVShiftLeftU32x8(const a: TVecU32x8; shift: Integer): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vsll.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftRightU32x8(const a: TVecU32x8; shift: Integer): TVecU32x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a1)
  vsrl.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftLeftU64x4(const a: TVecU64x4; shift: Integer): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vsll.vx v0, v0, a2
  vse64.v v0, (a0)
end;

function RISCVVShiftRightU64x4(const a: TVecU64x4; shift: Integer): TVecU64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a1)
  vsrl.vx v0, v0, a2
  vse64.v v0, (a0)
end;

function RISCVVShiftRightArithI32x16Asm(const a: TVecI32x16; shift: Integer): TVecI32x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a1)
  vsra.vx v0, v0, a2
  vse32.v v0, (a0)
end;

function RISCVVShiftRightArithI32x16(const a: TVecI32x16; shift: Integer): TVecI32x16;
begin
  if (shift < 0) or (shift >= 32) then
    Exit(ScalarShiftRightArithI32x16(a, shift));
  Result := RISCVVShiftRightArithI32x16Asm(a, shift);
end;

// =============================================================
// Unsigned Comparison Not Equal
// =============================================================

function RISCVVCmpNeU16x8(const a, b: TVecU16x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpNeU8x16(const a, b: TVecU8x16): TMask16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpNeU32x8(const a, b: TVecU32x8): TMask8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpNeU64x4(const a, b: TVecU64x4): TMask4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmsne.vv v0, v0, v1
  vmv.x.s a0, v0
end;

function RISCVVCmpGeI64x2(const a, b: TVecI64x2): TMask2; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vle64.v v1, (a1)
  vmsle.vv v0, v1, v0       // a >= b <=> b <= a
  vmv.x.s a0, v0
end;

// =============================================================
// Saturated Arithmetic Operations
// =============================================================

function RISCVVSatAddI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vsadd.vv v0, v0, v1
  vse16.v v0, (a2)
end;

function RISCVVSatAddI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vsadd.vv v0, v0, v1
  vse8.v v0, (a2)
end;

function RISCVVSatAddU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vsaddu.vv v0, v0, v1
  vse16.v v0, (a2)
end;

function RISCVVSatAddU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vsaddu.vv v0, v0, v1
  vse8.v v0, (a2)
end;

function RISCVVSatSubI16x8(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vssub.vv v0, v0, v1
  vse16.v v0, (a2)
end;

function RISCVVSatSubI8x16(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vssub.vv v0, v0, v1
  vse8.v v0, (a2)
end;

function RISCVVSatSubU16x8(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xC8
  vle16.v v0, (a0)
  vle16.v v1, (a1)
  vssubu.vv v0, v0, v1
  vse16.v v0, (a2)
end;

function RISCVVSatSubU8x16(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xC0
  vle8.v v0, (a0)
  vle8.v v1, (a1)
  vssubu.vv v0, v0, v1
  vse8.v v0, (a2)
end;

// =============================================================
// Mask Operations
// =============================================================

function RISCVVMask2All(mask: TMask2): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 3
  li t0, 3
  xor a0, a0, t0
  seqz a0, a0
end;

function RISCVVMask2Any(mask: TMask2): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 3
  sltu a0, zero, a0
end;

function RISCVVMask2None(mask: TMask2): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 3
  seqz a0, a0
end;

function RISCVVMask2PopCount(mask: TMask2): Integer; assembler; nostackframe;
asm
  andi a0, a0, 3
  // popcount for 2 bits
  srli t0, a0, 1
  andi t0, t0, 1
  andi a0, a0, 1
  add a0, a0, t0
end;

function RISCVVMask2FirstSet(mask: TMask2): Integer; assembler; nostackframe;
asm
  andi a0, a0, 3
  beqz a0, .Lnone2
  andi t0, a0, 1
  bnez t0, .Lfound0_2
  li a0, 1
  ret
.Lfound0_2:
  li a0, 0
  ret
.Lnone2:
  li a0, -1
end;

function RISCVVMask4All(mask: TMask4): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 15
  li t0, 15
  xor a0, a0, t0
  seqz a0, a0
end;

function RISCVVMask4Any(mask: TMask4): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 15
  sltu a0, zero, a0
end;

function RISCVVMask4None(mask: TMask4): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 15
  seqz a0, a0
end;

function RISCVVMask4PopCount(mask: TMask4): Integer; assembler; nostackframe;
asm
  andi a0, a0, 15
  // 4-bit popcount
  srli t0, a0, 1
  andi t0, t0, 5
  sub a0, a0, t0
  srli t0, a0, 2
  andi t0, t0, 3
  andi a0, a0, 3
  add a0, a0, t0
end;

function RISCVVMask4And(a, b: TMask4): TMask4; assembler; nostackframe;
asm
  and a0, a0, a1
  andi a0, a0, 15
end;

function RISCVVMask4Or(a, b: TMask4): TMask4; assembler; nostackframe;
asm
  or a0, a0, a1
  andi a0, a0, 15
end;

function RISCVVMask4Xor(a, b: TMask4): TMask4; assembler; nostackframe;
asm
  xor a0, a0, a1
  andi a0, a0, 15
end;

function RISCVVMask4Not(mask: TMask4): TMask4; assembler; nostackframe;
asm
  not a0, a0
  andi a0, a0, 15
end;

function RISCVVMask4FirstSet(mask: TMask4): Integer; assembler; nostackframe;
asm
  andi a0, a0, 15
  beqz a0, .Lnone4
  // Count trailing zeros
  neg t0, a0
  and t0, a0, t0       // isolate lowest bit
  li a0, 0
  li t1, 1
  beq t0, t1, .Ldone4
  addi a0, a0, 1
  slli t1, t1, 1
  beq t0, t1, .Ldone4
  addi a0, a0, 1
  slli t1, t1, 1
  beq t0, t1, .Ldone4
  li a0, 3
.Ldone4:
  ret
.Lnone4:
  li a0, -1
end;

function RISCVVMask8All(mask: TMask8): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 255
  li t0, 255
  xor a0, a0, t0
  seqz a0, a0
end;

function RISCVVMask8Any(mask: TMask8): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 255
  sltu a0, zero, a0
end;

function RISCVVMask8None(mask: TMask8): Boolean; assembler; nostackframe;
asm
  andi a0, a0, 255
  seqz a0, a0
end;

function RISCVVMask8PopCount(mask: TMask8): Integer; assembler; nostackframe;
asm
  andi a0, a0, 255
  // 8-bit popcount using parallel reduction
  srli t0, a0, 1
  li t1, 0x55
  and t0, t0, t1
  sub a0, a0, t0
  srli t0, a0, 2
  li t1, 0x33
  and t0, t0, t1
  and a0, a0, t1
  add a0, a0, t0
  srli t0, a0, 4
  add a0, a0, t0
  andi a0, a0, 0x0F
end;

function RISCVVMask8And(a, b: TMask8): TMask8; assembler; nostackframe;
asm
  and a0, a0, a1
  andi a0, a0, 255
end;

function RISCVVMask8Or(a, b: TMask8): TMask8; assembler; nostackframe;
asm
  or a0, a0, a1
  andi a0, a0, 255
end;

function RISCVVMask8Xor(a, b: TMask8): TMask8; assembler; nostackframe;
asm
  xor a0, a0, a1
  andi a0, a0, 255
end;

function RISCVVMask8Not(mask: TMask8): TMask8; assembler; nostackframe;
asm
  not a0, a0
  andi a0, a0, 255
end;

function RISCVVMask8FirstSet(mask: TMask8): Integer; assembler; nostackframe;
asm
  andi a0, a0, 255
  beqz a0, .Lnone8
  // Count trailing zeros using de Bruijn sequence
  neg t0, a0
  and t0, a0, t0
  // Simple loop for 8 bits
  li a0, 0
  li t1, 1
.Lloop8:
  beq t0, t1, .Ldone8
  addi a0, a0, 1
  slli t1, t1, 1
  li t2, 8
  blt a0, t2, .Lloop8
.Ldone8:
  ret
.Lnone8:
  li a0, -1
end;

function RISCVVMask16All(mask: TMask16): Boolean; assembler; nostackframe;
asm
  li t0, 0xFFFF
  and a0, a0, t0
  xor a0, a0, t0
  seqz a0, a0
end;

function RISCVVMask16Any(mask: TMask16): Boolean; assembler; nostackframe;
asm
  li t0, 0xFFFF
  and a0, a0, t0
  sltu a0, zero, a0
end;

function RISCVVMask16None(mask: TMask16): Boolean; assembler; nostackframe;
asm
  li t0, 0xFFFF
  and a0, a0, t0
  seqz a0, a0
end;

function RISCVVMask16PopCount(mask: TMask16): Integer; assembler; nostackframe;
asm
  li t0, 0xFFFF
  and a0, a0, t0
  // 16-bit popcount
  srli t0, a0, 1
  li t1, 0x5555
  and t0, t0, t1
  sub a0, a0, t0
  srli t0, a0, 2
  li t1, 0x3333
  and t0, t0, t1
  and a0, a0, t1
  add a0, a0, t0
  srli t0, a0, 4
  add a0, a0, t0
  li t1, 0x0F0F
  and a0, a0, t1
  srli t0, a0, 8
  add a0, a0, t0
  andi a0, a0, 0x1F
end;

function RISCVVMask16And(a, b: TMask16): TMask16; assembler; nostackframe;
asm
  and a0, a0, a1
  li t0, 0xFFFF
  and a0, a0, t0
end;

function RISCVVMask16Or(a, b: TMask16): TMask16; assembler; nostackframe;
asm
  or a0, a0, a1
  li t0, 0xFFFF
  and a0, a0, t0
end;

function RISCVVMask16Xor(a, b: TMask16): TMask16; assembler; nostackframe;
asm
  xor a0, a0, a1
  li t0, 0xFFFF
  and a0, a0, t0
end;

function RISCVVMask16Not(mask: TMask16): TMask16; assembler; nostackframe;
asm
  not a0, a0
  li t0, 0xFFFF
  and a0, a0, t0
end;

function RISCVVMask16FirstSet(mask: TMask16): Integer; assembler; nostackframe;
asm
  li t0, 0xFFFF
  and a0, a0, t0
  beqz a0, .Lnone16
  neg t0, a0
  and t0, a0, t0
  li a0, 0
  li t1, 1
.Lloop16:
  beq t0, t1, .Ldone16
  addi a0, a0, 1
  slli t1, t1, 1
  li t2, 16
  blt a0, t2, .Lloop16
.Ldone16:
  ret
.Lnone16:
  li a0, -1
end;

// =============================================================
// Extract/Insert Operations
// =============================================================

function RISCVVExtractF32x4Asm(const a: TVecF32x4; index: Integer): Single; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vfmv.f.s f10, v0
end;

function RISCVVExtractF32x4(const a: TVecF32x4; index: Integer): Single;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  Result := RISCVVExtractF32x4Asm(a, LIndex);
end;

function RISCVVExtractF32x8Asm(const a: TVecF32x8; index: Integer): Single; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vfmv.f.s f10, v0
end;

function RISCVVExtractF32x8(const a: TVecF32x8; index: Integer): Single;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 7 then
    LIndex := 7;
  Result := RISCVVExtractF32x8Asm(a, LIndex);
end;

function RISCVVExtractF32x16Asm(const a: TVecF32x16; index: Integer): Single; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vfmv.f.s f10, v0
end;

function RISCVVExtractF32x16(const a: TVecF32x16; index: Integer): Single;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 15 then
    LIndex := 15;
  Result := RISCVVExtractF32x16Asm(a, LIndex);
end;

function RISCVVExtractF64x2Asm(const a: TVecF64x2; index: Integer): Double; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vfmv.f.s f10, v0
end;

function RISCVVExtractF64x2(const a: TVecF64x2; index: Integer): Double;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 1 then
    LIndex := 1;
  Result := RISCVVExtractF64x2Asm(a, LIndex);
end;

function RISCVVExtractF64x4Asm(const a: TVecF64x4; index: Integer): Double; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vfmv.f.s f10, v0
end;

function RISCVVExtractF64x4(const a: TVecF64x4; index: Integer): Double;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  Result := RISCVVExtractF64x4Asm(a, LIndex);
end;

function RISCVVExtractI32x4Asm(const a: TVecI32x4; index: Integer): Int32; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vmv.x.s a0, v0
end;

function RISCVVExtractI32x4(const a: TVecI32x4; index: Integer): Int32;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  Result := RISCVVExtractI32x4Asm(a, LIndex);
end;

function RISCVVExtractI32x8Asm(const a: TVecI32x8; index: Integer): Int32; assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vmv.x.s a0, v0
end;

function RISCVVExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 7 then
    LIndex := 7;
  Result := RISCVVExtractI32x8Asm(a, LIndex);
end;

function RISCVVExtractI32x16Asm(const a: TVecI32x16; index: Integer): Int32; assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vmv.x.s a0, v0
end;

function RISCVVExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 15 then
    LIndex := 15;
  Result := RISCVVExtractI32x16Asm(a, LIndex);
end;

function RISCVVExtractI64x2Asm(const a: TVecI64x2; index: Integer): Int64; assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vmv.x.s a0, v0
end;

function RISCVVExtractI64x2(const a: TVecI64x2; index: Integer): Int64;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 1 then
    LIndex := 1;
  Result := RISCVVExtractI64x2Asm(a, LIndex);
end;

function RISCVVExtractI64x4Asm(const a: TVecI64x4; index: Integer): Int64; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vslidedown.vx v0, v0, a1
  vmv.x.s a0, v0
end;

function RISCVVExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  Result := RISCVVExtractI64x4Asm(a, LIndex);
end;

procedure RISCVVInsertF32x4Asm(const a: TVecF32x4; value: Single; index: Integer; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vse32.v v0, (a2)
  slli t0, a1, 2
  add t0, a2, t0
  fsw f10, (t0)
end;

function RISCVVInsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  RISCVVInsertF32x4Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertF32x8Asm(const a: TVecF32x8; value: Single; index: Integer; var r: TVecF32x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vse32.v v0, (a2)
  slli t0, a1, 2
  add t0, a2, t0
  fsw f10, (t0)
end;

function RISCVVInsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 7 then
    LIndex := 7;
  RISCVVInsertF32x8Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertF32x16Asm(const a: TVecF32x16; value: Single; index: Integer; var r: TVecF32x16); assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vse32.v v0, (a2)
  slli t0, a1, 2
  add t0, a2, t0
  fsw f10, (t0)
end;

function RISCVVInsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 15 then
    LIndex := 15;
  RISCVVInsertF32x16Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertF64x2Asm(const a: TVecF64x2; value: Double; index: Integer; var r: TVecF64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vse64.v v0, (a2)
  slli t0, a1, 3
  add t0, a2, t0
  fsd f10, (t0)
end;

function RISCVVInsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 1 then
    LIndex := 1;
  RISCVVInsertF64x2Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertF64x4Asm(const a: TVecF64x4; value: Double; index: Integer; var r: TVecF64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vse64.v v0, (a2)
  slli t0, a1, 3
  add t0, a2, t0
  fsd f10, (t0)
end;

function RISCVVInsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  RISCVVInsertF64x4Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertI32x4Asm(const a: TVecI32x4; value: Int32; index: Integer; var r: TVecI32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vse32.v v0, (a3)
  slli t0, a2, 2
  add t0, a3, t0
  sw a1, (t0)
end;

function RISCVVInsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  RISCVVInsertI32x4Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertI32x8Asm(const a: TVecI32x8; value: Int32; index: Integer; var r: TVecI32x8); assembler; nostackframe;
asm
  vsetivli zero, 8, 0xD1
  vle32.v v0, (a0)
  vse32.v v0, (a3)
  slli t0, a2, 2
  add t0, a3, t0
  sw a1, (t0)
end;

function RISCVVInsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 7 then
    LIndex := 7;
  RISCVVInsertI32x8Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertI32x16Asm(const a: TVecI32x16; value: Int32; index: Integer; var r: TVecI32x16); assembler; nostackframe;
asm
  vsetivli zero, 16, 0xD2
  vle32.v v0, (a0)
  vse32.v v0, (a3)
  slli t0, a2, 2
  add t0, a3, t0
  sw a1, (t0)
end;

function RISCVVInsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 15 then
    LIndex := 15;
  RISCVVInsertI32x16Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertI64x2Asm(const a: TVecI64x2; value: Int64; index: Integer; var r: TVecI64x2); assembler; nostackframe;
asm
  vsetivli zero, 2, 0xD8
  vle64.v v0, (a0)
  vse64.v v0, (a3)
  slli t0, a2, 3
  add t0, a3, t0
  sd a1, (t0)
end;

function RISCVVInsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 1 then
    LIndex := 1;
  RISCVVInsertI64x2Asm(a, value, LIndex, Result);
end;

procedure RISCVVInsertI64x4Asm(const a: TVecI64x4; value: Int64; index: Integer; var r: TVecI64x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  vle64.v v0, (a0)
  vse64.v v0, (a3)
  slli t0, a2, 3
  add t0, a3, t0
  sd a1, (t0)
end;

function RISCVVInsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
var
  LIndex: Integer;
begin
  LIndex := index;
  if LIndex < 0 then
    LIndex := 0
  else if LIndex > 3 then
    LIndex := 3;
  RISCVVInsertI64x4Asm(a, value, LIndex, Result);
end;

// =============================================================
// Vector Math Operations (Dot, Cross, Length, Normalize)
// =============================================================

function RISCVVDotF32x3(const a, b: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 3, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfmul.vv v0, v0, v1
  fmv.w.x f0, zero
  vfmv.s.f v2, f0
  vfredusum.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

function RISCVVDotF32x4(const a, b: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vle32.v v1, (a1)
  vfmul.vv v0, v0, v1
  fmv.w.x f0, zero
  vfmv.s.f v2, f0
  vfredusum.vs v2, v0, v2
  vfmv.f.s f10, v2
end;

procedure RISCVVCrossF32x3Asm(const a, b: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  // cross(a,b) = (ay*bz - az*by, az*bx - ax*bz, ax*by - ay*bx, 0)
  flw f0, 4(a0)             // ay
  flw f1, 8(a1)             // bz
  fmul.s f6, f0, f1
  flw f2, 8(a0)             // az
  flw f3, 4(a1)             // by
  fmul.s f7, f2, f3
  fsub.s f6, f6, f7
  fsw f6, 0(a2)

  flw f0, 0(a1)             // bx
  fmul.s f6, f2, f0
  flw f4, 0(a0)             // ax
  fmul.s f7, f4, f1
  fsub.s f6, f6, f7
  fsw f6, 4(a2)

  fmul.s f6, f4, f3
  flw f5, 4(a0)             // ay
  fmul.s f7, f5, f0
  fsub.s f6, f6, f7
  fsw f6, 8(a2)

  sw zero, 12(a2)
end;

function RISCVVCrossF32x3(const a, b: TVecF32x4): TVecF32x4;
begin
  RISCVVCrossF32x3Asm(a, b, Result);
end;

function RISCVVLengthF32x3(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 3, 0xD0
  vle32.v v0, (a0)
  vfmul.vv v0, v0, v0       // square each component
  fmv.w.x f0, zero
  vfmv.s.f v1, f0
  vfredusum.vs v1, v0, v1   // sum of squares
  vfmv.f.s f10, v1
  fsqrt.s f10, f10          // sqrt
end;

function RISCVVLengthF32x4(const a: TVecF32x4): Single; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfmul.vv v0, v0, v0
  fmv.w.x f0, zero
  vfmv.s.f v1, f0
  vfredusum.vs v1, v0, v1
  vfmv.f.s f10, v1
  fsqrt.s f10, f10
end;

procedure RISCVVNormalizeF32x3Asm(const a: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 3, 0xD0
  vle32.v v0, (a0)
  vfmul.vv v1, v0, v0
  fmv.w.x f3, zero
  vfmv.s.f v2, f3
  vfredusum.vs v2, v1, v2
  vfmv.f.s f0, v2
  fsqrt.s f0, f0
  fmv.w.x f1, zero
  feq.s t1, f0, f1
  bnez t1, .Lzero_norm3
  // Divide by length
  vsetivli zero, 4, 0xD0
  vfmv.v.f v1, f0
  vfdiv.vv v0, v0, v1
  // Set w to 0
  vmv.v.i v1, 0
  vslideup.vi v0, v1, 3
  vse32.v v0, (a1)
  ret
.Lzero_norm3:
  vmv.v.i v0, 0
  vse32.v v0, (a1)
end;

function RISCVVNormalizeF32x3(const a: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := 0.0;
  Result.f[1] := 0.0;
  Result.f[2] := 0.0;
  Result.f[3] := 0.0;
  RISCVVNormalizeF32x3Asm(a, Result);
  Result.f[3] := 0.0;
end;

procedure RISCVVNormalizeF32x4Asm(const a: TVecF32x4; var r: TVecF32x4); assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD0
  vle32.v v0, (a0)
  vfmul.vv v1, v0, v0
  fmv.w.x f3, zero
  vfmv.s.f v2, f3
  vfredusum.vs v2, v1, v2
  vfmv.f.s f0, v2
  fsqrt.s f0, f0
  fmv.w.x f1, zero
  feq.s t1, f0, f1
  bnez t1, .Lzero_norm4
  vfmv.v.f v1, f0
  vfdiv.vv v0, v0, v1
  vse32.v v0, (a1)
  ret
.Lzero_norm4:
  vmv.v.i v0, 0
  vse32.v v0, (a1)
end;

function RISCVVNormalizeF32x4(const a: TVecF32x4): TVecF32x4;
begin
  RISCVVNormalizeF32x4Asm(a, Result);
end;

function RISCVVRcpF64x4(const a: TVecF64x4): TVecF64x4; assembler; nostackframe;
asm
  vsetivli zero, 4, 0xD9
  // Load 1.0 as double
  li t0, 0x3FF0000000000000
  fmv.d.x f0, t0
  vfmv.v.f v0, f0
  vle64.v v2, (a1)
  vfdiv.vv v0, v0, v2
  vse64.v v0, (a0)
end;

{$ENDIF} // RISCVV_ASSEMBLY

{$I nextpas.core.simd.riscvv.facade.inc}

{$IFNDEF RISCVV_ASSEMBLY}
{$I nextpas.core.simd.riscvv.helpers.inc}
{$ENDIF}

// =============================================================
// Backend Registration
// =============================================================

{$I nextpas.core.simd.riscvv.register.inc}

end.

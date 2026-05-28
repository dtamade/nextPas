unit nextpas.core.simd.intrinsics.mmx;
// Disposition: STABLE — foundational intrinsics

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

{
  === nextpas.core.simd.intrinsics.mmx ===
  Placeholder MMX intrinsics surface for isolated legacy x86 bring-up.
  MMX is Intel's original 64-bit SIMD extension from 1997.

  Highlights:
  - 64-bit vector registers (mm0-mm7)
  - integer arithmetic (8/16/32-bit lanes)
  - saturation helpers and legacy multimedia primitives

  Notes:
  - the default path keeps a Pascal fallback for portability
  - inline asm is only relevant on x86/x64 hosts
  - modern code should prefer SSE2 or newer SIMD families
}

interface

type
  // MMX 64-bit 向量类型
  TM64 = record
    case Integer of
      0: (mm_u64: UInt64);
      1: (mm_i64: Int64);
      2: (mm_u32: array[0..1] of UInt32);
      3: (mm_i32: array[0..1] of LongInt);
      4: (mm_u16: array[0..3] of UInt16);
      5: (mm_i16: array[0..3] of SmallInt);
      6: (mm_u8: array[0..7] of UInt8);
      7: (mm_i8: array[0..7] of ShortInt);
  end;
  PM64 = ^TM64;

// === Load / Store ===
// Transfer data between memory and MMX registers.
function mmx_movd_mm(const Ptr: Pointer): TM64;
procedure mmx_movd_mm_store(var Dest: LongInt; const Src: TM64);
function mmx_movq_mm(const Ptr: Pointer): TM64;
procedure mmx_movq_mm_store(var Dest; const Src: TM64);

// === Set / Zero ===
// Initialize or zero MMX registers.
function mmx_setzero_si64: TM64;
function mmx_set1_pi8(Value: ShortInt): TM64;
function mmx_set1_pi16(Value: SmallInt): TM64;
function mmx_set1_pi32(Value: LongInt): TM64;
function mmx_set_pi8(a7, a6, a5, a4, a3, a2, a1, a0: ShortInt): TM64;
function mmx_set_pi16(a3, a2, a1, a0: SmallInt): TM64;
function mmx_set_pi32(a1, a0: LongInt): TM64;

// === Integer Arithmetic ===
// 整数运算指令，支持加法、减法、乘法和饱和运算

function mmx_paddb(a, b: TM64): TM64;
function mmx_paddw(a, b: TM64): TM64;
function mmx_paddd(a, b: TM64): TM64;
function mmx_paddq(a, b: TM64): TM64;
function mmx_paddsb(a, b: TM64): TM64;
function mmx_paddsw(a, b: TM64): TM64;
function mmx_paddusb(a, b: TM64): TM64;
function mmx_paddusw(a, b: TM64): TM64;
function mmx_psubb(a, b: TM64): TM64;
function mmx_psubw(a, b: TM64): TM64;
function mmx_psubd(a, b: TM64): TM64;
function mmx_psubq(a, b: TM64): TM64;
function mmx_psubsb(a, b: TM64): TM64;
function mmx_psubsw(a, b: TM64): TM64;
function mmx_psubusb(a, b: TM64): TM64;
function mmx_psubusw(a, b: TM64): TM64;
function mmx_pmullw(a, b: TM64): TM64;
function mmx_pmulhw(a, b: TM64): TM64;
function mmx_pmaddwd(a, b: TM64): TM64;

// === 5️⃣ Logical Operations ===
// 逻辑运算指令，支持位操作

function mmx_pand(a, b: TM64): TM64;
function mmx_pandn(a, b: TM64): TM64;
function mmx_por(a, b: TM64): TM64;
function mmx_pxor(a, b: TM64): TM64;

// === 6️⃣ Compare ===
// Compare lanes and produce mask results.
function mmx_pcmpeqb(a, b: TM64): TM64;
function mmx_pcmpeqw(a, b: TM64): TM64;
function mmx_pcmpeqd(a, b: TM64): TM64;
function mmx_pcmpgtb(a, b: TM64): TM64;
function mmx_pcmpgtw(a, b: TM64): TM64;
function mmx_pcmpgtd(a, b: TM64): TM64;

// === 7️⃣ Shift ===
// Shift lanes with logical or arithmetic semantics.
function mmx_psllw(a: TM64; count: TM64): TM64;
function mmx_pslld(a: TM64; count: TM64): TM64;
function mmx_psllq(a: TM64; count: TM64): TM64;
function mmx_psllw_imm(a: TM64; imm8: Byte): TM64;
function mmx_pslld_imm(a: TM64; imm8: Byte): TM64;
function mmx_psllq_imm(a: TM64; imm8: Byte): TM64;
function mmx_psrlw(a: TM64; count: TM64): TM64;
function mmx_psrld(a: TM64; count: TM64): TM64;
function mmx_psrlq(a: TM64; count: TM64): TM64;
function mmx_psrlw_imm(a: TM64; imm8: Byte): TM64;
function mmx_psrld_imm(a: TM64; imm8: Byte): TM64;
function mmx_psrlq_imm(a: TM64; imm8: Byte): TM64;
function mmx_psraw(a: TM64; count: TM64): TM64;
function mmx_psrad(a: TM64; count: TM64): TM64;
function mmx_psraw_imm(a: TM64; imm8: Byte): TM64;
function mmx_psrad_imm(a: TM64; imm8: Byte): TM64;

// === 10️⃣ Pack / Unpack ===
// 打包和解包指令，用于数据格式转换

function mmx_packsswb(a, b: TM64): TM64;
function mmx_packssdw(a, b: TM64): TM64;
function mmx_packuswb(a, b: TM64): TM64;
function mmx_punpckhbw(a, b: TM64): TM64;
function mmx_punpckhwd(a, b: TM64): TM64;
function mmx_punpckhdq(a, b: TM64): TM64;
function mmx_punpcklbw(a, b: TM64): TM64;
function mmx_punpcklwd(a, b: TM64): TM64;
function mmx_punpckldq(a, b: TM64): TM64;

// === 11️⃣ Miscellaneous ===
// Miscellaneous MMX state-management helpers.
procedure mmx_emms;

// === 🆕 补充的真正MMX指令 ===

// Extra data-transfer helpers.
function mmx_movd_r32(mm: TM64): LongWord;        // Extract the low 32-bit integer from MMX.
function mmx_movd_r32_to_mm(r32: LongWord): TM64; // Move a 32-bit integer into MMX.

// Extra variable-count shift helpers.
function mmx_psllw_mm(a, count: TM64): TM64;      // Shift 16-bit lanes left with an MMX count register.
function mmx_psrlw_mm(a, count: TM64): TM64;      // Shift 16-bit lanes right logically with an MMX count register.
function mmx_psraw_mm(a, count: TM64): TM64;      // Shift 16-bit lanes right arithmetically with an MMX count register.

// Extra packing helper.
function mmx_packusdw(a, b: TM64): TM64;          // 32位到16位无符号打包

// Extra unpack helpers with memory operands.
function mmx_punpcklbw_mem(a: TM64; mem: Pointer): TM64; // Unpack low bytes from memory.
function mmx_punpcklwd_mem(a: TM64; mem: Pointer): TM64; // 从内存解包低位字
function mmx_punpckldq_mem(a: TM64; mem: Pointer): TM64; // Unpack low doublewords from memory.
implementation

// === 1️⃣ Load / Store 实现 ===

// Load a 32-bit integer into the low MMX half and clear the high half.
function mmx_movd_mm(const Ptr: Pointer): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: RCX = Ptr
    movd mm0, dword ptr [rcx]
  {$ELSE}
    // SysV x64: RDI = Ptr
    movd mm0, dword ptr [rdi]
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  // x86: parameter is passed on the stack.
  mov eax, Ptr
  movd mm0, dword ptr [eax]
  movd eax, mm0
  xor edx, edx
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Store the low 32-bit integer from an MMX register to memory.
procedure mmx_movd_mm_store(var Dest: LongInt; const Src: TM64); {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: RCX = @Dest, RDX = Src
    movq mm0, rdx
    movd dword ptr [rcx], mm0
  {$ELSE}
    // SysV x64: RDI = @Dest, RSI = Src
    movq mm0, rsi
    movd dword ptr [rdi], mm0
  {$ENDIF}
{$ELSE}
  // x86: parameter is passed on the stack.
  movq mm0, qword ptr [Src]
  mov eax, Dest
  movd dword ptr [eax], mm0
{$ENDIF}
end;

// Load a full 64-bit value from memory into an MMX register.
function mmx_movq_mm(const Ptr: Pointer): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: RCX = Ptr
    movq mm0, qword ptr [rcx]
  {$ELSE}
    // SysV x64: RDI = Ptr
    movq mm0, qword ptr [rdi]
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  // x86: parameter is passed on the stack.
  mov eax, Ptr
  movq mm0, qword ptr [eax]
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [Ptr]
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// 功能：将MMX寄存器的64位数据存储到内存
// Store a full 64-bit MMX register value to memory.
procedure mmx_movq_mm_store(var Dest; const Src: TM64); {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: RCX = @Dest, RDX = Src
    movq mm0, rdx
    movq qword ptr [rcx], mm0
  {$ELSE}
    // SysV x64: RDI = @Dest, RSI = Src
    movq mm0, rsi
    movq qword ptr [rdi], mm0
  {$ENDIF}
{$ELSE}
  // x86: parameter is passed on the stack.
  movq mm0, qword ptr [Src]
  mov eax, Dest
  movq qword ptr [eax], mm0
{$ENDIF}
end;

// === 2️⃣ Set / Zero 实现 ===

// Return an all-zero MMX value.
function mmx_setzero_si64: TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  pxor mm0, mm0
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  pxor mm0, mm0
  movd eax, mm0
  xor edx, edx
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Broadcast one signed 8-bit value to all eight lanes.
function mmx_set1_pi8(Value: ShortInt): TM64;
begin
  Result.mm_i8[0] := Value;
  Result.mm_i8[1] := Value;
  Result.mm_i8[2] := Value;
  Result.mm_i8[3] := Value;
  Result.mm_i8[4] := Value;
  Result.mm_i8[5] := Value;
  Result.mm_i8[6] := Value;
  Result.mm_i8[7] := Value;
end;

// Broadcast one signed 16-bit value to all four lanes.
function mmx_set1_pi16(Value: SmallInt): TM64;
begin
  Result.mm_i16[0] := Value;
  Result.mm_i16[1] := Value;
  Result.mm_i16[2] := Value;
  Result.mm_i16[3] := Value;
end;

// Broadcast one signed 32-bit value to both lanes.
function mmx_set1_pi32(Value: LongInt): TM64;
begin
  Result.mm_i32[0] := Value;
  Result.mm_i32[1] := Value;
end;

// Construct an MMX value from eight signed 8-bit lanes, high to low.
function mmx_set_pi8(a7, a6, a5, a4, a3, a2, a1, a0: ShortInt): TM64;
begin
  Result.mm_i8[0] := a0;
  Result.mm_i8[1] := a1;
  Result.mm_i8[2] := a2;
  Result.mm_i8[3] := a3;
  Result.mm_i8[4] := a4;
  Result.mm_i8[5] := a5;
  Result.mm_i8[6] := a6;
  Result.mm_i8[7] := a7;
end;

// Construct an MMX value from four signed 16-bit lanes, high to low.
function mmx_set_pi16(a3, a2, a1, a0: SmallInt): TM64;
begin
  Result.mm_i16[0] := a0;
  Result.mm_i16[1] := a1;
  Result.mm_i16[2] := a2;
  Result.mm_i16[3] := a3;
end;

// Construct an MMX value from two signed 32-bit lanes, high to low.
function mmx_set_pi32(a1, a0: LongInt): TM64;
begin
  Result.mm_i32[0] := a0;
  Result.mm_i32[1] := a1;
end;

// === 3️⃣ Integer Arithmetic 实现 ===

// Add eight 8-bit lanes without saturation.
function mmx_paddb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: RCX=a, RDX=b
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    // SysV x64: RDI=a, RSI=b
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  // x86: parameter is passed on the stack.
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Add four 16-bit lanes without saturation.
function mmx_paddw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Add two 32-bit lanes without saturation.
function mmx_paddd(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddd mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddd mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddd mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Add one 64-bit lane without saturation.
function mmx_paddq(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddq mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Add eight signed 8-bit lanes with saturation.
function mmx_paddsb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddsb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddsb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddsb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Add four signed 16-bit lanes with saturation.
function mmx_paddsw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddsw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddsw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddsw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Add eight unsigned 8-bit lanes with saturation.
function mmx_paddusb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddusb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddusb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddusb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Add four unsigned 16-bit lanes with saturation.
function mmx_paddusw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  paddusw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddusw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  paddusw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract eight 8-bit lanes without saturation.
function mmx_psubb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract four 16-bit lanes without saturation.
function mmx_psubw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract two 32-bit lanes without saturation.
function mmx_psubd(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubd mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubd mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubd mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract one 64-bit lane without saturation.
function mmx_psubq(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubq mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract eight signed 8-bit lanes with saturation.
function mmx_psubsb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubsb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubsb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubsb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract four signed 16-bit lanes with saturation.
function mmx_psubsw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubsw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubsw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubsw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract eight unsigned 8-bit lanes with saturation.
function mmx_psubusb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubusb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubusb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubusb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Subtract four unsigned 16-bit lanes with saturation.
function mmx_psubusw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psubusw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubusw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  psubusw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Multiply four 16-bit lanes and keep the low 16 bits of each product.
function mmx_pmullw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pmullw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pmullw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pmullw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Multiply four 16-bit lanes and keep the high 16 bits of each product.
function mmx_pmulhw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pmulhw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pmulhw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pmulhw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Multiply four signed 16-bit lanes pairwise and add adjacent products into two 32-bit lanes.
function mmx_pmaddwd(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pmaddwd mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pmaddwd mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pmaddwd mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// === 5️⃣ Logical Operations 实现 ===

// 功能：对64位寄存器执行按位AND操作
function mmx_pand(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pand mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pand mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pand mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Bitwise AND NOT across 64 bits (~a & b).
function mmx_pandn(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pandn mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pandn mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pandn mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// 功能：对64位寄存器执行按位OR操作
function mmx_por(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  por mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  por mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  por mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// 功能：对64位寄存器执行按位XOR操作
function mmx_pxor(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pxor mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pxor mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pxor mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// === 6️⃣ Compare 实现 ===

// Compare eight 8-bit lanes for equality and return mask lanes.
function mmx_pcmpeqb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pcmpeqb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpeqb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpeqb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Compare four 16-bit lanes for equality and return mask lanes.
function mmx_pcmpeqw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pcmpeqw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpeqw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpeqw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Compare two 32-bit lanes for equality and return mask lanes.
function mmx_pcmpeqd(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pcmpeqd mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpeqd mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpeqd mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Compare signed 8-bit lanes for greater-than and return mask lanes.
function mmx_pcmpgtb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pcmpgtb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpgtb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpgtb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Compare signed 16-bit lanes for greater-than and return mask lanes.
function mmx_pcmpgtw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pcmpgtw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpgtw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpgtw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Compare signed 32-bit lanes for greater-than and return mask lanes.
function mmx_pcmpgtd(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pcmpgtd mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpgtd mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  pcmpgtd mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// === 7️⃣ Shift 实现 ===

// Shift four 16-bit lanes left logically with an MMX count operand.
function mmx_psllw(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psllw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psllw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psllw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift two 32-bit lanes left logically with an MMX count operand.
function mmx_pslld(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  pslld mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  pslld mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  pslld mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift one 64-bit lane left logically with an MMX count operand.
function mmx_psllq(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psllq mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psllq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psllq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift four 16-bit lanes left logically with an immediate count.
function mmx_psllw_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    psllw mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    psllw mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psllw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psllw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift two 32-bit lanes left logically with an immediate count.
function mmx_pslld_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    pslld mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    pslld mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  pslld mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  pslld mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift one 64-bit lane left logically with an immediate count.
function mmx_psllq_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    psllq mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    psllq mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psllq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psllq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// 逻辑右移
// Shift four 16-bit lanes right logically with an MMX count operand.
function mmx_psrlw(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psrlw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrlw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrlw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift two 32-bit lanes right logically with an MMX count operand.
function mmx_psrld(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psrld mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrld mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrld mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift one 64-bit lane right logically with an MMX count operand.
function mmx_psrlq(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psrlq mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrlq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrlq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift four 16-bit lanes right logically with an immediate count.
function mmx_psrlw_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    psrlw mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    psrlw mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrlw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrlw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift two 32-bit lanes right logically with an immediate count.
function mmx_psrld_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    psrld mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    psrld mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrld mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrld mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift one 64-bit lane right logically with an immediate count.
function mmx_psrlq_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    psrlq mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    psrlq mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrlq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrlq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift four signed 16-bit lanes right arithmetically with an MMX count operand.
function mmx_psraw(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psraw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psraw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psraw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift two signed 32-bit lanes right arithmetically with an MMX count operand.
function mmx_psrad(a: TM64; count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psrad mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrad mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrad mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift four signed 16-bit lanes right arithmetically with an immediate count.
function mmx_psraw_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    psraw mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    psraw mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psraw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psraw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift two signed 32-bit lanes right arithmetically with an immediate count.
function mmx_psrad_imm(a: TM64; imm8: Byte): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movd mm1, edx
    psrad mm0, mm1
  {$ELSE}
    movq mm0, rdi
    movd mm1, esi
    psrad mm0, mm1
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrad mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movd mm1, imm8
  psrad mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// === 10️⃣ Pack / Unpack 实现 ===

// Pack eight signed 16-bit lanes into signed 8-bit lanes with saturation.
function mmx_packsswb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  packsswb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  packsswb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  packsswb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Pack four signed 32-bit lanes into signed 16-bit lanes with saturation.
function mmx_packssdw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  packssdw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  packssdw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  packssdw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Pack eight signed 16-bit lanes into unsigned 8-bit lanes with saturation.
function mmx_packuswb(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  packuswb mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  packuswb mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  packuswb mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Unpack and interleave the high 8-bit lanes from two MMX registers.
function mmx_punpckhbw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  punpckhbw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckhbw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckhbw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Unpack and interleave the high 16-bit lanes from two MMX registers.
function mmx_punpckhwd(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  punpckhwd mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckhwd mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckhwd mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Unpack and interleave the high 32-bit lanes from two MMX registers.
function mmx_punpckhdq(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  punpckhdq mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckhdq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckhdq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Unpack and interleave the low 8-bit lanes from two MMX registers.
function mmx_punpcklbw(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  punpcklbw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpcklbw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpcklbw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Unpack and interleave the low 16-bit lanes from two MMX registers.
function mmx_punpcklwd(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  punpcklwd mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpcklwd mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpcklwd mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Unpack and interleave the low 32-bit lanes from two MMX registers.
function mmx_punpckldq(a, b: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  punpckldq mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckldq mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [b]
  punpckldq mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// === 11️⃣ Miscellaneous 实现 ===

// Clear MMX state and restore x87/FPU availability before returning to FPU code.
procedure mmx_emms; {$IFDEF FPC}assembler;{$ENDIF}
asm
  emms
end;

// === 🆕 补充的真正MMX指令实现 ===

// Move the low 32 bits of an MMX register into a 32-bit general-purpose result.
function mmx_movd_r32(mm: TM64): LongWord; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
  {$ELSE}
    movq mm0, rdi
  {$ENDIF}
  movd eax, mm0
{$ELSE}
  movq mm0, qword ptr [mm]
  movd eax, mm0
{$ENDIF}
end;

// Move a 32-bit scalar value into the low 32 bits of an MMX register.
function mmx_movd_r32_to_mm(r32: LongWord): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movd mm0, ecx
  {$ELSE}
    movd mm0, edi
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movd mm0, r32
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movd mm0, r32
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift 16-bit lanes left by counts supplied in an MMX register.
function mmx_psllw_mm(a, count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psllw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psllw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psllw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift 16-bit lanes right logically by counts supplied in an MMX register.
function mmx_psrlw_mm(a, count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psrlw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrlw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psrlw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Shift 16-bit lanes right arithmetically by counts supplied in an MMX register.
function mmx_psraw_mm(a, count: TM64): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    movq mm1, rdx
  {$ELSE}
    movq mm0, rdi
    movq mm1, rsi
  {$ENDIF}
  psraw mm0, mm1
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psraw mm0, mm1
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  movq mm1, qword ptr [count]
  psraw mm0, mm1
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// 功能：32位到16位无符号饱和打包（模拟 PACKUSDW 语义，MMX 原生无此指令）
function mmx_packusdw(a, b: TM64): TM64;
var
  LIndex: Integer;
  LTemp: TM64;
  LValue: LongInt;
begin
  // 模拟 SSE4.1 PACKUSDW：有符号32位输入，饱和到无符号16位输出
  for LIndex := 0 to 1 do
  begin
    LValue := a.mm_i32[LIndex];
    if LValue < 0 then
      LTemp.mm_u16[LIndex] := 0
    else if LValue > 65535 then
      LTemp.mm_u16[LIndex] := 65535
    else
      LTemp.mm_u16[LIndex] := UInt16(LValue);

    LValue := b.mm_i32[LIndex];
    if LValue < 0 then
      LTemp.mm_u16[LIndex + 2] := 0
    else if LValue > 65535 then
      LTemp.mm_u16[LIndex + 2] := 65535
    else
      LTemp.mm_u16[LIndex + 2] := UInt16(LValue);
  end;

  Result := LTemp;
end;

// 功能：从内存解包低位字节
function mmx_punpcklbw_mem(a: TM64; mem: Pointer): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    punpcklbw mm0, qword ptr [rdx]
  {$ELSE}
    movq mm0, rdi
    punpcklbw mm0, qword ptr [rsi]
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  punpcklbw mm0, qword ptr [mem]
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  punpcklbw mm0, qword ptr [mem]
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// Unpack and interleave low 16-bit lanes using a memory operand.
function mmx_punpcklwd_mem(a: TM64; mem: Pointer): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    punpcklwd mm0, qword ptr [rdx]
  {$ELSE}
    movq mm0, rdi
    punpcklwd mm0, qword ptr [rsi]
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  punpcklwd mm0, qword ptr [mem]
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  punpcklwd mm0, qword ptr [mem]
  movq qword ptr [Result], mm0
{$ENDIF}
end;

// 功能：从内存解包低位双字
function mmx_punpckldq_mem(a: TM64; mem: Pointer): TM64; {$IFDEF FPC}assembler;{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq mm0, rcx
    punpckldq mm0, qword ptr [rdx]
  {$ELSE}
    movq mm0, rdi
    punpckldq mm0, qword ptr [rsi]
  {$ENDIF}
  movq rax, mm0
  movq qword ptr [Result], mm0
{$ELSE}
  movq mm0, qword ptr [a]
  punpckldq mm0, qword ptr [mem]
  movd eax, mm0
  psrlq mm0, 32
  movd edx, mm0
  movq mm0, qword ptr [a]
  punpckldq mm0, qword ptr [mem]
  movq qword ptr [Result], mm0
{$ENDIF}
end;

end.



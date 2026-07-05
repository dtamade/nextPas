{
  nextpas.core.simd.bitops.pas

  Cross-platform bit manipulation intrinsics.
  Pure inline, no dispatch table, no function pointers.
  Each function compiles to a single instruction (or two) on the target arch.

  Future: nextpas compiler emits these as native machine instructions directly.
}

unit nextpas.core.simd.bitops;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

type
  TU32 = {$IFDEF FPC}UInt32{$ELSE}Cardinal{$ENDIF};
  TU64 = {$IFDEF FPC}UInt64{$ELSE}UInt64{$ENDIF};

{** Count Leading Zeros — number of zero bits above the highest set bit.
    Returns 32/64 for AValue = 0. }
function Clz32(AValue: TU32): TU32;
function Clz64(AValue: TU64): TU32;

{** Count Trailing Zeros — number of zero bits below the lowest set bit.
    Returns 32/64 for AValue = 0. }
function Ctz32(AValue: TU32): TU32;
function Ctz64(AValue: TU64): TU32;

{** Population Count — number of set bits. }
function PopCount32(AValue: TU32): TU32;
function PopCount64(AValue: TU64): TU32;

{** Bit Scan Forward — index of lowest set bit. Undefined for AValue = 0. }
function Bsf32(AValue: TU32): TU32;
function Bsf64(AValue: TU64): TU32;

{** Bit Scan Reverse — index of highest set bit. Undefined for AValue = 0. }
function Bsr32(AValue: TU32): TU32;
function Bsr64(AValue: TU64): TU32;

{** Integer log2 (floor). Returns 0 for AValue = 0.
    Equivalent to Bsr, but safe for 0 input. }
function Log2Floor32(AValue: TU32): TU32;
function Log2Floor64(AValue: TU64): TU32;

{** Integer log2 (ceiling). Returns 0 for AValue = 0. }
function Log2Ceil32(AValue: TU32): TU32;
function Log2Ceil64(AValue: TU64): TU32;

{** Next power of two >= AValue. Returns 0 for AValue = 0 (overflow). }
function NextPow2_32(AValue: TU32): TU32;
function NextPow2_64(AValue: TU64): TU64;

{** Check if AValue is a power of two (positive). }
function IsPow2_32(AValue: TU32): Boolean;
function IsPow2_64(AValue: TU64): Boolean;

implementation

// ============================================================
// x86 / x86-64: BSF, BSR, POPCNT instructions
// ============================================================
{$IFDEF SIMD_X86_AVAILABLE}

function Clz32(AValue: TU32): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsr eax, edi
  jnz @@nz
  mov eax, 32
  jmp @@done
@@nz:
  mov ecx, 31
  sub ecx, eax
  mov eax, ecx
@@done:
  {$ELSE}
  bsr eax, AValue
  jnz @@nz
  mov eax, 32
  jmp @@done
@@nz:
  mov ecx, 31
  sub ecx, eax
  mov eax, ecx
@@done:
  {$ENDIF}
end;

function Clz64(AValue: TU64): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsr rax, rdi
  jnz @@nz
  mov eax, 64
  jmp @@done
@@nz:
  mov ecx, 63
  sub ecx, eax
  mov eax, ecx
@@done:
  {$ELSE}
  // i386: 64-bit value in edx:eax (high:low)
  test edx, edx
  jnz @@hi
  bsr eax, eax
  jnz @@lo_nz
  mov eax, 32
  jmp @@done
@@hi:
  bsr eax, edx
  mov ecx, 31
  sub ecx, eax
  mov eax, ecx
  jmp @@done
@@lo_nz:
  mov ecx, 31
  sub ecx, eax
  add ecx, 32
  mov eax, ecx
@@done:
  {$ENDIF}
end;

function Ctz32(AValue: TU32): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsf eax, edi
  jnz @@nz
  mov eax, 32
@@nz:
  {$ELSE}
  bsf eax, AValue
  jnz @@nz
  mov eax, 32
@@nz:
  {$ENDIF}
end;

function Ctz64(AValue: TU64): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsf rax, rdi
  jnz @@nz
  mov eax, 64
@@nz:
  {$ELSE}
  // i386: edx:eax
  bsf eax, eax
  jnz @@done
  bsf eax, edx
  jnz @@hi_nz
  mov eax, 64
  jmp @@done
@@hi_nz:
  add eax, 32
@@done:
  {$ENDIF}
end;

function PopCount32(AValue: TU32): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  popcnt eax, edi
  {$ELSE}
  popcnt eax, AValue
  {$ENDIF}
end;

function PopCount64(AValue: TU64): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  popcnt rax, rdi
  {$ELSE}
  // i386: popcnt each half, add
  popcnt eax, eax
  mov ecx, eax
  popcnt eax, edx
  add eax, ecx
  {$ENDIF}
end;

function Bsf32(AValue: TU32): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsf eax, edi
  {$ELSE}
  bsf eax, AValue
  {$ENDIF}
end;

function Bsf64(AValue: TU64): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsf rax, rdi
  {$ELSE}
  bsf eax, eax
  jnz @@done
  bsf eax, edx
  add eax, 32
@@done:
  {$ENDIF}
end;

function Bsr32(AValue: TU32): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsr eax, edi
  {$ELSE}
  bsr eax, AValue
  {$ENDIF}
end;

function Bsr64(AValue: TU64): TU32; assembler; nostackframe;
asm
  {$IFDEF CPUX86_64}
  bsr rax, rdi
  {$ELSE}
  // i386: check high dword first
  test edx, edx
  jnz @@hi
  bsr eax, eax
  jmp @@done
@@hi:
  bsr eax, edx
  add eax, 32
@@done:
  {$ENDIF}
end;

// ============================================================
// ARM / AArch64: CLZ, RBIT instructions
// ============================================================
{$ELSEIF DEFINED(CPUAARCH64)}

function Clz32(AValue: TU32): TU32; assembler; nostackframe;
asm
  clz w0, w0
end;

function Clz64(AValue: TU64): TU32; assembler; nostackframe;
asm
  clz x0, x0
end;

function Ctz32(AValue: TU32): TU32; assembler; nostackframe;
asm
  rbit w0, w0
  clz w0, w0
end;

function Ctz64(AValue: TU64): TU32; assembler; nostackframe;
asm
  rbit x0, x0
  clz x0, x0
end;

function PopCount32(AValue: TU32): TU32; assembler; nostackframe;
asm
  fmov s0, w0
  cnt v0.8b, v0.8b
  addv b0, v0.8b
  fmov w0, s0
end;

function PopCount64(AValue: TU64): TU32; assembler; nostackframe;
asm
  fmov d0, x0
  cnt v0.8b, v0.8b
  addv b0, v0.8b
  fmov w0, s0
end;

function Bsf32(AValue: TU32): TU32;
begin
  if AValue = 0 then
    Result := 0
  else
    Result := Ctz32(AValue);
end;

function Bsf64(AValue: TU64): TU32;
begin
  if AValue = 0 then
    Result := 0
  else
    Result := Ctz64(AValue);
end;

function Bsr32(AValue: TU32): TU32;
begin
  if AValue = 0 then
    Result := 0
  else
    Result := 31 - Clz32(AValue);
end;

function Bsr64(AValue: TU64): TU32;
begin
  if AValue = 0 then
    Result := 0
  else
    Result := 63 - Clz64(AValue);
end;

// ============================================================
// RISC-V: Zbb extension (clz, cpop, ctz)
// ============================================================
{$ELSEIF DEFINED(CPURISCV64)}

function Clz32(AValue: TU32): TU32; assembler; nostackframe;
asm
  clz.w a0, a0
end;

function Clz64(AValue: TU64): TU32; assembler; nostackframe;
asm
  clz a0, a0
end;

function Ctz32(AValue: TU32): TU32; assembler; nostackframe;
asm
  ctz.w a0, a0
end;

function Ctz64(AValue: TU64): TU32; assembler; nostackframe;
asm
  ctz a0, a0
end;

function PopCount32(AValue: TU32): TU32; assembler; nostackframe;
asm
  cpop.w a0, a0
end;

function PopCount64(AValue: TU64): TU32; assembler; nostackframe;
asm
  cpop a0, a0
end;

function Bsf32(AValue: TU32): TU32;
begin
  if AValue = 0 then Result := 0
  else Result := Ctz32(AValue);
end;

function Bsf64(AValue: TU64): TU32;
begin
  if AValue = 0 then Result := 0
  else Result := Ctz64(AValue);
end;

function Bsr32(AValue: TU32): TU32;
begin
  if AValue = 0 then Result := 0
  else Result := 31 - Clz32(AValue);
end;

function Bsr64(AValue: TU64): TU32;
begin
  if AValue = 0 then Result := 0
  else Result := 63 - Clz64(AValue);
end;

// ============================================================
// Scalar fallback: pure Pascal
// ============================================================
{$ELSE}

function Clz32(AValue: TU32): TU32;
var
  LMask: TU32;
begin
  Result := 0;
  LMask := TU32($80000000);
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shr 1;
  end;
end;

function Clz64(AValue: TU64): TU32;
var
  LMask: TU64;
begin
  Result := 0;
  LMask := TU64($8000000000000000);
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shr 1;
  end;
end;

function Ctz32(AValue: TU32): TU32;
var
  LMask: TU32;
begin
  Result := 0;
  LMask := 1;
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shl 1;
  end;
end;

function Ctz64(AValue: TU64): TU32;
var
  LMask: TU64;
begin
  Result := 0;
  LMask := 1;
  while (LMask <> 0) and ((AValue and LMask) = 0) do
  begin
    Inc(Result);
    LMask := LMask shl 1;
  end;
end;

function PopCount32(AValue: TU32): TU32;
begin
  AValue := AValue - ((AValue shr 1) and $55555555);
  AValue := (AValue and $33333333) + ((AValue shr 2) and $33333333);
  AValue := (AValue + (AValue shr 4)) and $0F0F0F0F;
  Result := (AValue * $01010101) shr 24;
end;

function PopCount64(AValue: TU64): TU32;
begin
  AValue := AValue - ((AValue shr 1) and $5555555555555555);
  AValue := (AValue and $3333333333333333) + ((AValue shr 2) and $3333333333333333);
  AValue := (AValue + (AValue shr 4)) and $0F0F0F0F0F0F0F0F;
  Result := TU32((AValue * $0101010101010101) shr 56);
end;

function Bsf32(AValue: TU32): TU32;
begin
  if AValue = 0 then Exit(0);
  Result := Ctz32(AValue);
end;

function Bsf64(AValue: TU64): TU32;
begin
  if AValue = 0 then Exit(0);
  Result := Ctz64(AValue);
end;

function Bsr32(AValue: TU32): TU32;
begin
  if AValue = 0 then Exit(0);
  Result := 31 - Clz32(AValue);
end;

function Bsr64(AValue: TU64): TU32;
begin
  if AValue = 0 then Exit(0);
  Result := 63 - Clz64(AValue);
end;

{$ENDIF}

// ============================================================
// Platform-independent derived functions (pure Pascal, inline)
// ============================================================

function Log2Floor32(AValue: TU32): TU32;
begin
  if AValue = 0 then Exit(0);
  Result := Bsr32(AValue);
end;

function Log2Floor64(AValue: TU64): TU32;
begin
  if AValue = 0 then Exit(0);
  Result := Bsr64(AValue);
end;

function Log2Ceil32(AValue: TU32): TU32;
begin
  if AValue <= 1 then Exit(0);
  Result := Log2Floor32(AValue - 1) + 1;
end;

function Log2Ceil64(AValue: TU64): TU32;
begin
  if AValue <= 1 then Exit(0);
  Result := Log2Floor64(AValue - 1) + 1;
end;

function NextPow2_32(AValue: TU32): TU32;
begin
  if AValue = 0 then Exit(0);
  Dec(AValue);
  AValue := AValue or (AValue shr 1);
  AValue := AValue or (AValue shr 2);
  AValue := AValue or (AValue shr 4);
  AValue := AValue or (AValue shr 8);
  AValue := AValue or (AValue shr 16);
  Result := AValue + 1;
end;

function NextPow2_64(AValue: TU64): TU64;
begin
  if AValue = 0 then Exit(0);
  Dec(AValue);
  AValue := AValue or (AValue shr 1);
  AValue := AValue or (AValue shr 2);
  AValue := AValue or (AValue shr 4);
  AValue := AValue or (AValue shr 8);
  AValue := AValue or (AValue shr 16);
  AValue := AValue or (AValue shr 32);
  Result := AValue + 1;
end;

function IsPow2_32(AValue: TU32): Boolean;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

function IsPow2_64(AValue: TU64): Boolean;
begin
  Result := (AValue <> 0) and ((AValue and (AValue - 1)) = 0);
end;

end.

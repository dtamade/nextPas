unit nextpas.core.simd.sse2.i386;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$ASMMODE INTEL}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// === i386 SSE2 Backend Implementation ===
// Provides SIMD-accelerated operations using 32-bit x86 SSE2 instructions.
// This backend is available on i386 processors with SSE2 support (Pentium 4+).
//
// Key differences from x86_64 SSE2:
//   - 32-bit registers: EAX, EDX, ECX instead of RAX, RDX, RCX
//   - FPC register calling convention: EAX, EDX, ECX for first 3 params
//   - XMM0-XMM7 available (vs XMM0-XMM15 on x86_64)
//   - No 64-bit popcnt; use SWAR popcount

// Register the i386 SSE2 backend
procedure RegisterSSE2i386Backend;

// === i386 SSE2 Facade Functions ===
function MemEqual_SSE2_i386(a, b: Pointer; len: SizeUInt): LongBool;
function MemFindByte_SSE2_i386(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
function SumBytes_SSE2_i386(p: Pointer; len: SizeUInt): UInt64;
function CountByte_SSE2_i386(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
function BitsetPopCount_SSE2_i386(p: Pointer; len: SizeUInt): SizeUInt;

// === i386 SSE2 Vector Operations ===
function SSE2AddF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
function SSE2SubF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
function SSE2MulF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
function SSE2DivF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
function SSE2AddI32x4_i386(const a, b: TVecI32x4): TVecI32x4;
function SSE2SubI32x4_i386(const a, b: TVecI32x4): TVecI32x4;
function SSE2MulI32x4_i386(const a, b: TVecI32x4): TVecI32x4;
function SSE2AddF64x2_i386(const a, b: TVecF64x2): TVecF64x2;
function SSE2SubF64x2_i386(const a, b: TVecF64x2): TVecF64x2;
function SSE2MulF64x2_i386(const a, b: TVecF64x2): TVecF64x2;
function SSE2DivF64x2_i386(const a, b: TVecF64x2): TVecF64x2;

implementation

uses
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.scalar;

// === i386 SSE2 Memory Functions ===
// FPC i386 register calling convention:
//   - First param: EAX
//   - Second param: EDX
//   - Third param: ECX
//   - Return value: EAX (or EDX:EAX for 64-bit)

function MemEqual_SSE2_i386(a, b: Pointer; len: SizeUInt): LongBool;
var
  pa, pb: PByte;
  i: SizeUInt;
  maskVal: Integer;
begin
  {$PUSH}{$Q-}{$R-}
  if len = 0 then
  begin
    Result := True;
    Exit;
  end;

  if (a = nil) or (b = nil) then
  begin
    Result := (a = b);
    Exit;
  end;

  if a = b then
  begin
    Result := True;
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);
  i := 0;

  // Process 16 bytes at a time using SSE2
  while i + 16 <= len do
  begin
    asm
      push ebx
      mov  eax, pa
      mov  edx, pb
      add  eax, i
      add  edx, i
      movdqu xmm0, [eax]
      movdqu xmm1, [edx]
      pcmpeqb xmm0, xmm1
      pmovmskb eax, xmm0
      mov  maskVal, eax
      pop  ebx
    end;

    if maskVal <> $FFFF then
    begin
      Result := False;
      Exit;
    end;

    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    if pa[i] <> pb[i] then
    begin
      Result := False;
      Exit;
    end;
    Inc(i);
  end;

  Result := True;
  {$POP}
end;

function MemFindByte_SSE2_i386(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
var
  pb: PByte;
  i: SizeUInt;
  maskVal: Integer;
  bitPos: Integer;
  broadcastVal: Integer;
begin
  if (len = 0) or (p = nil) then
  begin
    Result := -1;
    Exit;
  end;

  pb := PByte(p);
  i := 0;
  broadcastVal := value;

  // Process 16 bytes at a time using SSE2
  while i + 16 <= len do
  begin
    asm
      push ebx
      // Broadcast value to all 16 bytes
      mov  eax, broadcastVal
      movd xmm1, eax
      punpcklbw xmm1, xmm1
      pshuflw xmm1, xmm1, 0
      punpcklqdq xmm1, xmm1
      
      // Load and compare
      mov  eax, pb
      add  eax, i
      movdqu xmm0, [eax]
      pcmpeqb xmm0, xmm1
      pmovmskb eax, xmm0
      mov  maskVal, eax
      pop  ebx
    end;

    if maskVal <> 0 then
    begin
      // Find first set bit using BSF
      asm
        bsf eax, maskVal
        mov bitPos, eax
      end;
      Result := PtrInt(i) + bitPos;
      Exit;
    end;

    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    if pb[i] = value then
    begin
      Result := PtrInt(i);
      Exit;
    end;
    Inc(i);
  end;

  Result := -1;
end;

function SumBytes_SSE2_i386(p: Pointer; len: SizeUInt): UInt64;
var
  pb: PByte;
  i: SizeUInt;
  sum0, sum1: UInt32;
  tempLo, tempHi: UInt32;
begin
  {$PUSH}{$Q-}{$R-}
  if (len = 0) or (p = nil) then
  begin
    Result := 0;
    Exit;
  end;

  pb := PByte(p);
  i := 0;
  sum0 := 0;
  sum1 := 0;

  // Process 16 bytes at a time using SSE2 psadbw
  while i + 16 <= len do
  begin
    asm
      push ebx
      mov  eax, pb
      add  eax, i
      movdqu xmm0, [eax]
      pxor   xmm1, xmm1      // Zero register
      psadbw xmm0, xmm1      // Sum bytes: result in low 16 bits of each 64-bit lane
      
      // Extract lower 64-bit sum
      movd   eax, xmm0
      add    sum0, eax
      
      // Extract upper 64-bit sum (shift right 8 bytes)
      psrldq xmm0, 8
      movd   eax, xmm0
      add    sum1, eax
      pop    ebx
    end;
    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    Inc(sum0, pb[i]);
    Inc(i);
  end;

  Result := UInt64(sum0) + UInt64(sum1);
  {$POP}
end;

// SWAR popcount for 32-bit mask (no native popcnt on older i386)
function PopCount32_SWAR(x: UInt32): UInt32; inline;
begin
  x := x - ((x shr 1) and $55555555);
  x := (x and $33333333) + ((x shr 2) and $33333333);
  x := (x + (x shr 4)) and $0F0F0F0F;
  x := x + (x shr 8);
  x := x + (x shr 16);
  Result := x and $3F;
end;

function CountByte_SSE2_i386(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
var
  pb: PByte;
  i: SizeUInt;
  maskVal: UInt32;
  count: SizeUInt;
  broadcastVal: Integer;
begin
  if (len = 0) or (p = nil) then
  begin
    Result := 0;
    Exit;
  end;

  pb := PByte(p);
  i := 0;
  count := 0;
  broadcastVal := value;

  // Process 16 bytes at a time using SSE2
  while i + 16 <= len do
  begin
    asm
      push ebx
      // Broadcast value to all 16 bytes
      mov  eax, broadcastVal
      movd xmm1, eax
      punpcklbw xmm1, xmm1
      pshuflw xmm1, xmm1, 0
      punpcklqdq xmm1, xmm1
      
      // Load and compare
      mov  eax, pb
      add  eax, i
      movdqu xmm0, [eax]
      pcmpeqb xmm0, xmm1
      pmovmskb eax, xmm0
      mov  maskVal, eax
      pop  ebx
    end;

    // Count bits using SWAR (no popcnt on i386)
    Inc(count, PopCount32_SWAR(maskVal));
    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    if pb[i] = value then
      Inc(count);
    Inc(i);
  end;

  Result := count;
end;

// Popcount lookup table for byte values
const
  PopCountTable: array[0..255] of Byte = (
    0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4,1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8
  );

// === SSE2 Optimized BitsetPopCount ===
// Uses psadbw to count bits in parallel:
// 1. Use lookup table in XMM register to map nibbles to bit counts
// 2. Use pshufb (SSSE3) or fallback for nibble lookup
// For SSE2, we use psadbw with a precomputed popcount for each byte
function BitsetPopCount_SSE2_i386(p: Pointer; len: SizeUInt): SizeUInt;
var
  pb: PByte;
  i: SizeUInt;
  count: SizeUInt;
  sum0, sum1: UInt32;
 begin
  if (len = 0) or (p = nil) then
  begin
    Result := 0;
    Exit;
  end;

  pb := PByte(p);
  i := 0;
  count := 0;
  sum0 := 0;
  sum1 := 0;

  // Process 16 bytes at a time using SSE2
  // Strategy: load bytes, lookup popcount for each byte, sum with psadbw
  while i + 16 <= len do
  begin
    asm
      push ebx
      push esi
      
      mov  eax, pb
      add  eax, i
      movdqu xmm0, [eax]      // Load 16 bytes
      
      // Split into nibbles and lookup popcount
      // SSE2 doesn't have pshufb, so we use a different approach:
      // For each byte, compute popcount using bit manipulation
      
      // Method: Use the parallel bit count algorithm with SSE2
      // popcount(x) = x - ((x >> 1) & 0x55) 
      //             = (x & 0x33) + ((x >> 2) & 0x33)
      //             = (x + (x >> 4)) & 0x0F
      
      // Create constants
      mov  eax, $55555555
      movd xmm1, eax
      pshufd xmm1, xmm1, 0     // xmm1 = 0x55555555... (broadcast)
      
      mov  eax, $33333333
      movd xmm2, eax
      pshufd xmm2, xmm2, 0     // xmm2 = 0x33333333...
      
      mov  eax, $0F0F0F0F
      movd xmm3, eax
      pshufd xmm3, xmm3, 0     // xmm3 = 0x0F0F0F0F...
      
      // Step 1: x = x - ((x >> 1) & 0x55)
      movdqa xmm4, xmm0
      psrlw  xmm4, 1           // Shift right by 1 (word-wise, but works for bytes)
      pand   xmm4, xmm1
      psubb  xmm0, xmm4
      
      // Step 2: x = (x & 0x33) + ((x >> 2) & 0x33)
      movdqa xmm4, xmm0
      psrlw  xmm4, 2
      pand   xmm0, xmm2
      pand   xmm4, xmm2
      paddb  xmm0, xmm4
      
      // Step 3: x = (x + (x >> 4)) & 0x0F
      movdqa xmm4, xmm0
      psrlw  xmm4, 4
      paddb  xmm0, xmm4
      pand   xmm0, xmm3
      
      // Now each byte contains the popcount of the original byte (0-8)
      // Sum all bytes using psadbw with zero
      pxor   xmm1, xmm1
      psadbw xmm0, xmm1        // Sum bytes in each 64-bit half
      
      // Extract sums
      movd   eax, xmm0
      add    sum0, eax
      psrldq xmm0, 8
      movd   eax, xmm0
      add    sum1, eax
      
      pop  esi
      pop  ebx
    end;
    Inc(i, 16);
  end;

  count := SizeUInt(sum0) + SizeUInt(sum1);

  // Handle remaining bytes using lookup table
  while i < len do
  begin
    Inc(count, PopCountTable[pb[i]]);
    Inc(i);
  end;

  Result := count;
end;

// === i386 SSE Vector Arithmetic Operations ===
// Note: For i386, we use SSE instructions with proper stack-based result handling.
// FPC i386 passes const record params by reference (pointer on stack).

function SSE2AddF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
var
  tmp: TVecF32x4;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movups xmm0, [eax]
    movups xmm1, [edx]
    addps  xmm0, xmm1
    movups [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2SubF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
var
  tmp: TVecF32x4;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movups xmm0, [eax]
    movups xmm1, [edx]
    subps  xmm0, xmm1
    movups [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2MulF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
var
  tmp: TVecF32x4;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movups xmm0, [eax]
    movups xmm1, [edx]
    mulps  xmm0, xmm1
    movups [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2DivF32x4_i386(const a, b: TVecF32x4): TVecF32x4;
var
  tmp: TVecF32x4;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movups xmm0, [eax]
    movups xmm1, [edx]
    divps  xmm0, xmm1
    movups [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2AddI32x4_i386(const a, b: TVecI32x4): TVecI32x4;
var
  tmp: TVecI32x4;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    paddd  xmm0, xmm1
    movdqu [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2SubI32x4_i386(const a, b: TVecI32x4): TVecI32x4;
var
  tmp: TVecI32x4;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    psubd  xmm0, xmm1
    movdqu [ecx], xmm0
  end;
  Result := tmp;
end;

// SSE2 reconstructs 4x32-bit low products with PMULUDQ on even lanes and a
// second shifted pass for odd lanes. Signed low 32-bit results match modulo 2^32.
function SSE2MulI32x4_i386(const a, b: TVecI32x4): TVecI32x4;
var
  tmp: TVecI32x4;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr

    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    movdqa xmm2, xmm0
    movdqa xmm3, xmm1

    pmuludq xmm0, xmm1

    psrldq xmm2, 4
    psrldq xmm3, 4
    pmuludq xmm2, xmm3

    pshufd xmm0, xmm0, $08
    pshufd xmm2, xmm2, $08
    punpckldq xmm0, xmm2

    movdqu [ecx], xmm0
  end;
  Result := tmp;
end;

// === F64x2 Operations ===
function SSE2AddF64x2_i386(const a, b: TVecF64x2): TVecF64x2;
var
  tmp: TVecF64x2;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movupd xmm0, [eax]
    movupd xmm1, [edx]
    addpd  xmm0, xmm1
    movupd [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2SubF64x2_i386(const a, b: TVecF64x2): TVecF64x2;
var
  tmp: TVecF64x2;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movupd xmm0, [eax]
    movupd xmm1, [edx]
    subpd  xmm0, xmm1
    movupd [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2MulF64x2_i386(const a, b: TVecF64x2): TVecF64x2;
var
  tmp: TVecF64x2;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movupd xmm0, [eax]
    movupd xmm1, [edx]
    mulpd  xmm0, xmm1
    movupd [ecx], xmm0
  end;
  Result := tmp;
end;

function SSE2DivF64x2_i386(const a, b: TVecF64x2): TVecF64x2;
var
  tmp: TVecF64x2;
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @tmp;
  asm
    mov  eax, pa
    mov  edx, pb
    mov  ecx, pr
    movupd xmm0, [eax]
    movupd xmm1, [edx]
    divpd  xmm0, xmm1
    movupd [ecx], xmm0
  end;
  Result := tmp;
end;

{$I nextpas.core.simd.sse2.i386.register.inc}


end.

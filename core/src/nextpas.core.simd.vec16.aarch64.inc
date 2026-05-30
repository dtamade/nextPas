// AArch64 NEON implementation of vec16 primitives
// Uses NEON 128-bit vector instructions for 16-byte operations.
//
// Bitmask extraction: NEON has no pmovmskb equivalent.
// Strategy: ushr #7 to get 0/1 per byte, then weighted add to pack into 16 bits.
// Uses the classic shrn+fmov approach for efficient mask extraction.

{$IFDEF CPUAARCH64}

function Vec16CmpEq(AData: PByte; AValue: Byte): TMask16; assembler; nostackframe;
asm
  ldr   q0, [x0]                 // v0 = load 16 bytes
  dup   v1.16b, w1               // v1 = broadcast(AValue)
  cmeq  v0.16b, v0.16b, v1.16b  // v0 = 0xFF where equal, 0 otherwise
  // Extract bitmask: shift each byte right by 7 to get 0/1
  ushr  v0.16b, v0.16b, #7
  // Weighted sum to pack 16 bytes into 16 bits
  // Weights: byte[i] contributes to bit i of result
  // Use shrn to narrow 128→64 bits, then extract
  mov   x2, #0x0102040810204080  // bit weights for bytes 0-7
  fmov  d1, x2
  mov   x2, #0x0102040810204080  // bit weights for bytes 8-15
  fmov  d2, x2
  // Multiply each byte by its weight and sum
  umull v3.8h, v0.8b, v1.8b     // low 8 bytes * weights
  umull2 v4.8h, v0.16b, v2.16b  // high 8 bytes * weights
  addv  h3, v3.8h               // sum low → h3
  addv  h4, v4.8h               // sum high → h4
  umov  w0, v3.h[0]             // low byte of mask
  umov  w2, v4.h[0]             // high byte of mask
  orr   w0, w0, w2, lsl #8     // combine: mask = hi:lo
end;

function Vec16CmpEq2(AData, APattern: PByte): TMask16; assembler; nostackframe;
asm
  ldr   q0, [x0]
  ldr   q1, [x1]
  cmeq  v0.16b, v0.16b, v1.16b
  ushr  v0.16b, v0.16b, #7
  mov   x2, #0x0102040810204080
  fmov  d1, x2
  fmov  d2, x2
  umull v3.8h, v0.8b, v1.8b
  umull2 v4.8h, v0.16b, v2.16b
  addv  h3, v3.8h
  addv  h4, v4.8h
  umov  w0, v3.h[0]
  umov  w2, v4.h[0]
  orr   w0, w0, w2, lsl #8
end;

function Vec16CmpLtU(AData: PByte; AThreshold: Byte): TMask16; assembler; nostackframe;
asm
  ldr   q0, [x0]
  dup   v1.16b, w1
  cmhi  v0.16b, v1.16b, v0.16b  // threshold > data ≡ data < threshold (unsigned)
  ushr  v0.16b, v0.16b, #7
  mov   x2, #0x0102040810204080
  fmov  d1, x2
  fmov  d2, x2
  umull v3.8h, v0.8b, v1.8b
  umull2 v4.8h, v0.16b, v2.16b
  addv  h3, v3.8h
  addv  h4, v4.8h
  umov  w0, v3.h[0]
  umov  w2, v4.h[0]
  orr   w0, w0, w2, lsl #8
end;

function Vec16CmpGtU(AData: PByte; AThreshold: Byte): TMask16; assembler; nostackframe;
asm
  ldr   q0, [x0]
  dup   v1.16b, w1
  cmhi  v0.16b, v0.16b, v1.16b  // data > threshold (unsigned)
  ushr  v0.16b, v0.16b, #7
  mov   x2, #0x0102040810204080
  fmov  d1, x2
  fmov  d2, x2
  umull v3.8h, v0.8b, v1.8b
  umull2 v4.8h, v0.16b, v2.16b
  addv  h3, v3.8h
  addv  h4, v4.8h
  umov  w0, v3.h[0]
  umov  w2, v4.h[0]
  orr   w0, w0, w2, lsl #8
end;

function Vec16CmpRange(AData: PByte; ALo, AHi: Byte): TMask16;
begin
  if ALo > AHi then begin Result := 0; Exit; end;
  Result := Vec16CmpGtU(AData, ALo - 1) and (not Vec16CmpGtU(AData, AHi));
end;

function Vec16Ctz(AMask: TMask16): Int32; assembler; nostackframe;
asm
  ands  w0, w0, #0xFFFF
  b.eq  .Lctz_none
  rbit  w0, w0
  clz   w0, w0
  sub   w0, w0, #16
  ret
.Lctz_none:
  mov   w0, #-1
end;

function Vec16FirstSet(AMask: TMask16): Int32; assembler; nostackframe;
asm
  ands  w0, w0, #0xFFFF
  b.eq  .Lfs_none
  rbit  w0, w0
  clz   w0, w0
  sub   w0, w0, #16
  ret
.Lfs_none:
  mov   w0, #-1
end;

function Vec16Popcnt(AMask: TMask16): Int32; assembler; nostackframe;
asm
  and   w0, w0, #0xFFFF
  fmov  s0, w0
  cnt   v0.8b, v0.8b
  addv  b0, v0.8b
  umov  w0, v0.b[0]
end;

procedure Vec16AddWhere(AData: PByte; AMask: TMask16; ADelta: Byte); inline;
var
  i: Integer;
begin
  if AMask = 0 then Exit;
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then
      AData[i] := AData[i] + ADelta;
  {$POP}
end;

procedure Vec16SubWhere(AData: PByte; AMask: TMask16; ADelta: Byte); inline;
var
  i: Integer;
begin
  if AMask = 0 then Exit;
  {$PUSH}{$R-}{$Q-}
  for i := 0 to 15 do
    if (AMask and (1 shl i)) <> 0 then
      AData[i] := AData[i] - ADelta;
  {$POP}
end;

procedure Vec16ProbeGroup(AData: PByte; AH2: Byte; out AMatchMask, AEmptyMask: TMask16); inline;
begin
  AMatchMask := Vec16CmpEq(AData, AH2);
  AEmptyMask := Vec16CmpEq(AData, $FF);
end;

{$ELSE}
// Non-AArch64: should not reach here (vec16.pas selects this file only for CPUAARCH64)
{$FATAL vec16.aarch64.inc included on non-AArch64 platform}
{$ENDIF}

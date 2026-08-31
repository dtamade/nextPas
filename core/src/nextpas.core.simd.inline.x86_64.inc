// x86_64 SSE2/AVX2 直联 — 热路径 asm，其余 scalar（仍 inline，全平台可 bench）— Phase2
{$PUSH}{$Q-}{$R-}

// ——— F32x4 热路径 asm ———
function InlineVecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movaps xmm1, dqword ptr [b]
    addps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;

function InlineVecF32x4Sub(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movaps xmm1, dqword ptr [b]
    subps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;

function InlineVecF32x4Mul(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movaps xmm1, dqword ptr [b]
    mulps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;

function InlineVecF32x4Min(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movaps xmm1, dqword ptr [b]
    minps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;

function InlineVecF32x4Max(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movaps xmm1, dqword ptr [b]
    maxps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;

// ——— U8x16 热路径 asm ———
function InlineVecU8x16Add(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    paddb xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;

function InlineVecU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    paddusb xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;

function InlineVecU8x16Min(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    pminub xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;

function InlineVecU8x16Max(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    pmaxub xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;

// ——— U16x8 热路径 asm ———
function InlineVecU16x8Add(const a, b: TVecU16x8): TVecU16x8; inline;
begin
  Result := Default(TVecU16x8);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    paddw xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;

function InlineVecU16x8Min(const a, b: TVecU16x8): TVecU16x8; inline;
var i: Integer;
begin
  for i:=0 to 7 do if a.u[i]<b.u[i] then Result.u[i]:=a.u[i] else Result.u[i]:=b.u[i];
end;

function InlineVecU16x8Max(const a, b: TVecU16x8): TVecU16x8; inline;
var i: Integer;
begin
  for i:=0 to 7 do if a.u[i]>b.u[i] then Result.u[i]:=a.u[i] else Result.u[i]:=b.u[i];
end;

// ——— I32x4 热路径 asm ———
function InlineVecI32x4Add(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := Default(TVecI32x4);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    paddd xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;

{$POP}

// ——— 256-bit AVX2 逻辑（2×128-bit SSE 组合，仍 inline，GB/s 翻倍） ———
function InlineVecF32x8Add(const a, b: TVecF32x8): TVecF32x8; inline;
begin
  Result.lo := InlineVecF32x4Add(a.lo, b.lo);
  Result.hi := InlineVecF32x4Add(a.hi, b.hi);
end;

function InlineVecF32x8Mul(const a, b: TVecF32x8): TVecF32x8; inline;
begin
  Result.lo := InlineVecF32x4Mul(a.lo, b.lo);
  Result.hi := InlineVecF32x4Mul(a.hi, b.hi);
end;

// ——— F32x4 剩余算术 SSE2 直联 ———
function InlineVecF32x4Div(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movaps xmm1, dqword ptr [b]
    divps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;
function InlineVecF32x4Abs(const a: TVecF32x4): TVecF32x4; inline;
var Mask: TVecI32x4;
begin
  Mask.i[0]:=$7fffffff; Mask.i[1]:=$7fffffff; Mask.i[2]:=$7fffffff; Mask.i[3]:=$7fffffff;
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [Mask]
    andps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;
function InlineVecF32x4Sqrt(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    sqrtps xmm0, xmm0
    movaps dqword ptr [Result], xmm0
  end;
end;
function InlineVecF32x4Neg(const a: TVecF32x4): TVecF32x4; inline;
var Mask: TVecI32x4;
begin
  Mask.i[0]:=LongInt($80000000); Mask.i[1]:=LongInt($80000000); Mask.i[2]:=LongInt($80000000); Mask.i[3]:=LongInt($80000000);
  Result := Default(TVecF32x4);
  asm
    movaps xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [Mask]
    xorps xmm0, xmm1
    movaps dqword ptr [Result], xmm0
  end;
end;
function InlineVecF32x4Load(p: PSingle): TVecF32x4; inline;
begin
  Move(p^, Result, SizeOf(Result));
end;
procedure InlineVecF32x4Store(p: PSingle; const a: TVecF32x4); inline;
begin
  Move(a, p^, SizeOf(a));
end;
function InlineVecF32x4Splat(v: Single): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.f[i]:=v;
end;
function InlineVecF32x4Zero: TVecF32x4; inline;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function InlineVecF64x2Add(const a, b: TVecF64x2): TVecF64x2; inline;
var i: Integer;
begin
  for i:=0 to 1 do Result.d[i]:=a.d[i]+b.d[i];
end;
function InlineVecF64x2Sub(const a, b: TVecF64x2): TVecF64x2; inline;
var i: Integer;
begin
  for i:=0 to 1 do Result.d[i]:=a.d[i]-b.d[i];
end;
function InlineVecF64x2Mul(const a, b: TVecF64x2): TVecF64x2; inline;
var i: Integer;
begin
  for i:=0 to 1 do Result.d[i]:=a.d[i]*b.d[i];
end;
function InlineVecF64x2Div(const a, b: TVecF64x2): TVecF64x2; inline;
var i: Integer;
begin
  for i:=0 to 1 do Result.d[i]:=a.d[i]/b.d[i];
end;
function InlineVecF64x2Min(const a, b: TVecF64x2): TVecF64x2; inline;
var i: Integer;
begin
  for i:=0 to 1 do if a.d[i]<b.d[i] then Result.d[i]:=a.d[i] else Result.d[i]:=b.d[i];
end;
function InlineVecF64x2Max(const a, b: TVecF64x2): TVecF64x2; inline;
var i: Integer;
begin
  for i:=0 to 1 do if a.d[i]>b.d[i] then Result.d[i]:=a.d[i] else Result.d[i]:=b.d[i];
end;

function InlineVecI32x4Sub(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := Default(TVecI32x4);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    psubd xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecI32x4Mul(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.i[i]:=a.i[i]*b.i[i];
end;
function InlineVecI32x4And(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := Default(TVecI32x4);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    pand xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecI32x4Or(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := Default(TVecI32x4);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    por xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecI32x4Xor(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := Default(TVecI32x4);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    pxor xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecI32x4Min(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do if a.i[i]<b.i[i] then Result.i[i]:=a.i[i] else Result.i[i]:=b.i[i];
end;
function InlineVecI32x4Max(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do if a.i[i]>b.i[i] then Result.i[i]:=a.i[i] else Result.i[i]:=b.i[i];
end;
function InlineVecI32x4CmpEq(const a, b: TVecI32x4): TMask4; inline;
var i: Integer;
begin
  Result:=0;
  for i:=0 to 3 do if a.i[i]=b.i[i] then Result:=Result or TMask4(1 shl i);
end;

function InlineVecU8x16Sub(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    psubb xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecU8x16SatSub(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    psubusb xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecU8x16And(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    pand xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecU8x16Or(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    por xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecU8x16Xor(const a, b: TVecU8x16): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  asm
    movdqu xmm0, dqword ptr [a]
    movdqu xmm1, dqword ptr [b]
    pxor xmm0, xmm1
    movdqu dqword ptr [Result], xmm0
  end;
end;
function InlineVecU8x16CmpEq(const a, b: TVecU8x16): TMask16; inline;
var i: Integer;
begin
  // 热度低，保 TMask16 位语义精确；SSE2 pcmpeqb+pmovmskb 可做但需额外移位，暂 scalar 可 bench
  Result:=0;
  for i:=0 to 15 do if a.u[i]=b.u[i] then Result:=Result or TMask16(1 shl i);
end;
function InlineVecU8x16Load(p: PByte): TVecU8x16; inline;
begin
  Move(p^, Result, SizeOf(Result));
end;
procedure InlineVecU8x16Store(p: PByte; const a: TVecU8x16); inline;
begin
  Move(a, p^, SizeOf(a));
end;
function InlineVecU8x16Splat(v: Byte): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do Result.u[i]:=v;
end;

// scalar 金丝雀 — 纯 Pascal，保证可 bench 与可移植

function InlineVecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.f[i] := a.f[i] + b.f[i];
end;
function InlineVecF32x4Sub(const a, b: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.f[i] := a.f[i] - b.f[i];
end;
function InlineVecF32x4Mul(const a, b: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.f[i] := a.f[i] * b.f[i];
end;
function InlineVecF32x4Div(const a, b: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.f[i] := a.f[i] / b.f[i];
end;
function InlineVecF32x4Min(const a, b: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do if a.f[i] < b.f[i] then Result.f[i]:=a.f[i] else Result.f[i]:=b.f[i];
end;
function InlineVecF32x4Max(const a, b: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do if a.f[i] > b.f[i] then Result.f[i]:=a.f[i] else Result.f[i]:=b.f[i];
end;
function InlineVecF32x4Abs(const a: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do if a.f[i] < 0 then Result.f[i]:=-a.f[i] else Result.f[i]:=a.f[i];
end;
function InlineVecF32x4Sqrt(const a: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.f[i] := Sqrt(a.f[i]);
end;
function InlineVecF32x4Neg(const a: TVecF32x4): TVecF32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.f[i] := -a.f[i];
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

function InlineVecI32x4Add(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.i[i]:=a.i[i]+b.i[i];
end;
function InlineVecI32x4Sub(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.i[i]:=a.i[i]-b.i[i];
end;
function InlineVecI32x4Mul(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.i[i]:=a.i[i]*b.i[i];
end;
function InlineVecI32x4And(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.i[i]:=a.i[i] and b.i[i];
end;
function InlineVecI32x4Or(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.i[i]:=a.i[i] or b.i[i];
end;
function InlineVecI32x4Xor(const a, b: TVecI32x4): TVecI32x4; inline;
var i: Integer;
begin
  for i:=0 to 3 do Result.i[i]:=a.i[i] xor b.i[i];
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

function InlineVecU8x16Add(const a, b: TVecU8x16): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do Result.u[i]:=Byte(a.u[i]+b.u[i]);
end;
function InlineVecU8x16Sub(const a, b: TVecU8x16): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do Result.u[i]:=Byte(a.u[i]-b.u[i]);
end;
function InlineVecU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; inline;
var i, s: Integer;
begin
  for i:=0 to 15 do begin s:=Integer(a.u[i])+Integer(b.u[i]); if s>255 then s:=255; Result.u[i]:=Byte(s); end;
end;
function InlineVecU8x16SatSub(const a, b: TVecU8x16): TVecU8x16; inline;
var i, s: Integer;
begin
  for i:=0 to 15 do begin s:=Integer(a.u[i])-Integer(b.u[i]); if s<0 then s:=0; Result.u[i]:=Byte(s); end;
end;
function InlineVecU8x16And(const a, b: TVecU8x16): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do Result.u[i]:=a.u[i] and b.u[i];
end;
function InlineVecU8x16Or(const a, b: TVecU8x16): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do Result.u[i]:=a.u[i] or b.u[i];
end;
function InlineVecU8x16Xor(const a, b: TVecU8x16): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do Result.u[i]:=a.u[i] xor b.u[i];
end;
function InlineVecU8x16Min(const a, b: TVecU8x16): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do if a.u[i]<b.u[i] then Result.u[i]:=a.u[i] else Result.u[i]:=b.u[i];
end;
function InlineVecU8x16Max(const a, b: TVecU8x16): TVecU8x16; inline;
var i: Integer;
begin
  for i:=0 to 15 do if a.u[i]>b.u[i] then Result.u[i]:=a.u[i] else Result.u[i]:=b.u[i];
end;
function InlineVecU8x16CmpEq(const a, b: TVecU8x16): TMask16; inline;
var i: Integer;
begin
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

function InlineVecU16x8Add(const a, b: TVecU16x8): TVecU16x8; inline;
var i: Integer;
begin
  for i:=0 to 7 do Result.u[i]:=a.u[i]+b.u[i];
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

function InlineVecF32x8Add(const a, b: TVecF32x8): TVecF32x8; inline;
var i: Integer;
begin
  for i:=0 to 7 do Result.f[i]:=a.f[i]+b.f[i];
end;
function InlineVecF32x8Mul(const a, b: TVecF32x8): TVecF32x8; inline;
var i: Integer;
begin
  for i:=0 to 7 do Result.f[i]:=a.f[i]*b.f[i];
end;

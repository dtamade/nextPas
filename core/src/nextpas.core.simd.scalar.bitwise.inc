// === Saturating Arithmetic Implementation ===
// 饱和算术：结果超出类型范围时钳位到边界值

{$PUSH}{$R-}{$Q-}  // 禁用溢出检查，我们自己处理饱和

// I8x16 Signed Saturating Add: [-128, 127]
function ScalarI8x16SatAdd(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
  sum: Int32;
begin
  for i := 0 to 15 do
  begin
    sum := Int32(a.i[i]) + Int32(b.i[i]);
    if sum > 127 then
      Result.i[i] := 127
    else if sum < -128 then
      Result.i[i] := -128
    else
      Result.i[i] := Int8(sum);
  end;
end;

// I8x16 Signed Saturating Sub: [-128, 127]
function ScalarI8x16SatSub(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
  diff: Int32;
begin
  for i := 0 to 15 do
  begin
    diff := Int32(a.i[i]) - Int32(b.i[i]);
    if diff > 127 then
      Result.i[i] := 127
    else if diff < -128 then
      Result.i[i] := -128
    else
      Result.i[i] := Int8(diff);
  end;
end;

// I16x8 Signed Saturating Add: [-32768, 32767]
function ScalarI16x8SatAdd(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
  sum: Int32;
begin
  for i := 0 to 7 do
  begin
    sum := Int32(a.i[i]) + Int32(b.i[i]);
    if sum > 32767 then
      Result.i[i] := 32767
    else if sum < -32768 then
      Result.i[i] := -32768
    else
      Result.i[i] := Int16(sum);
  end;
end;

// I16x8 Signed Saturating Sub: [-32768, 32767]
function ScalarI16x8SatSub(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
  diff: Int32;
begin
  for i := 0 to 7 do
  begin
    diff := Int32(a.i[i]) - Int32(b.i[i]);
    if diff > 32767 then
      Result.i[i] := 32767
    else if diff < -32768 then
      Result.i[i] := -32768
    else
      Result.i[i] := Int16(diff);
  end;
end;

// U8x16 Unsigned Saturating Add: [0, 255]
function ScalarU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
  sum: UInt32;
begin
  for i := 0 to 15 do
  begin
    sum := UInt32(a.u[i]) + UInt32(b.u[i]);
    if sum > 255 then
      Result.u[i] := 255
    else
      Result.u[i] := UInt8(sum);
  end;
end;

// U8x16 Unsigned Saturating Sub: [0, 255]
function ScalarU8x16SatSub(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
  begin
    // 无符号减法：如果 b > a，结果饱和到 0
    if b.u[i] > a.u[i] then
      Result.u[i] := 0
    else
      Result.u[i] := a.u[i] - b.u[i];
  end;
end;

// U16x8 Unsigned Saturating Add: [0, 65535]
function ScalarU16x8SatAdd(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
  sum: UInt32;
begin
  for i := 0 to 7 do
  begin
    sum := UInt32(a.u[i]) + UInt32(b.u[i]);
    if sum > 65535 then
      Result.u[i] := 65535
    else
      Result.u[i] := UInt16(sum);
  end;
end;

// U16x8 Unsigned Saturating Sub: [0, 65535]
function ScalarU16x8SatSub(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    // 无符号减法：如果 b > a，结果饱和到 0
    if b.u[i] > a.u[i] then
      Result.u[i] := 0
    else
      Result.u[i] := a.u[i] - b.u[i];
  end;
end;

// Mask 操作实现
// === TMask2 操作 (2 有效位) ===
function ScalarMask2All(mask: TMask2): Boolean;
begin
  Result := (mask and $03) = $03;  // 两位都设置
end;

function ScalarMask2Any(mask: TMask2): Boolean;
begin
  Result := (mask and $03) <> 0;  // 至少一位设置
end;

function ScalarMask2None(mask: TMask2): Boolean;
begin
  Result := (mask and $03) = 0;  // 没有位设置
end;

function ScalarMask2PopCount(mask: TMask2): Integer;
var
  m: Byte;
begin
  m := mask and $03;
  Result := (m and 1) + ((m shr 1) and 1);
end;

function ScalarMask2FirstSet(mask: TMask2): Integer;
var
  m: Byte;
begin
  m := mask and $03;
  if m = 0 then
    Result := -1
  else if (m and 1) <> 0 then
    Result := 0
  else
    Result := 1;
end;

// === TMask4 操作 (4 有效位) ===
function ScalarMask4All(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) = $0F;
end;

function ScalarMask4Any(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) <> 0;
end;

function ScalarMask4None(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) = 0;
end;

function ScalarMask4PopCount(mask: TMask4): Integer;
var
  m: Byte;
begin
  m := mask and $0F;
  Result := 0;
  while m <> 0 do
  begin
    Inc(Result, m and 1);
    m := m shr 1;
  end;
end;

function ScalarMask4FirstSet(mask: TMask4): Integer;
var
  m: Byte;
  i: Integer;
begin
  m := mask and $0F;
  if m = 0 then
    Exit(-1);
  for i := 0 to 3 do
    if (m and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

// === TMask8 操作 (8 有效位) ===
function ScalarMask8All(mask: TMask8): Boolean;
begin
  Result := mask = $FF;
end;

function ScalarMask8Any(mask: TMask8): Boolean;
begin
  Result := mask <> 0;
end;

function ScalarMask8None(mask: TMask8): Boolean;
begin
  Result := mask = 0;
end;

function ScalarMask8PopCount(mask: TMask8): Integer;
var
  m: Byte;
begin
  m := mask;
  Result := 0;
  while m <> 0 do
  begin
    Inc(Result, m and 1);
    m := m shr 1;
  end;
end;

function ScalarMask8FirstSet(mask: TMask8): Integer;
var
  i: Integer;
begin
  if mask = 0 then
    Exit(-1);
  for i := 0 to 7 do
    if (mask and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

// === TMask16 操作 (16 有效位) ===
function ScalarMask16All(mask: TMask16): Boolean;
begin
  Result := mask = $FFFF;
end;

function ScalarMask16Any(mask: TMask16): Boolean;
begin
  Result := mask <> 0;
end;

function ScalarMask16None(mask: TMask16): Boolean;
begin
  Result := mask = 0;
end;

function ScalarMask16PopCount(mask: TMask16): Integer;
var
  m: Word;
begin
  m := mask;
  Result := 0;
  while m <> 0 do
  begin
    Inc(Result, m and 1);
    m := m shr 1;
  end;
end;

function ScalarMask16FirstSet(mask: TMask16): Integer;
var
  i: Integer;
begin
  if mask = 0 then
    Exit(-1);
  for i := 0 to 15 do
    if (mask and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

// F64x2 Select 实现
function ScalarSelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
begin
  // mask 位 0 控制元素 0，位 1 控制元素 1
  // 位为 1 时选择 a，位为 0 时选择 b
  if (mask and 1) <> 0 then
    Result.d[0] := a.d[0]
  else
    Result.d[0] := b.d[0];
  if (mask and 2) <> 0 then
    Result.d[1] := a.d[1]
  else
    Result.d[1] := b.d[1];
end;

function ScalarSelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if (mask and (1 shl i)) <> 0 then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := b.f[i];
end;

function ScalarSelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if (mask and (1 shl i)) <> 0 then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := b.d[i];
end;

// Select 操作实现 (条件选择: mask[i] != 0 ? a[i] : b[i])

function ScalarSelectI32x4(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := (a.i[i] and mask.i[i]) or (b.i[i] and (not mask.i[i]));
end;

function ScalarSelectF32x8(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
var i: Integer;
    la, lb, lr: UInt32;
begin
  for i := 0 to 7 do
  begin
    la := PDWord(@a.f[i])^;
    lb := PDWord(@b.f[i])^;
    lr := (la and mask.u[i]) or (lb and (not mask.u[i]));
    PDWord(@Result.f[i])^ := lr;
  end;
end;

function ScalarSelectF64x4(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;
var i: Integer;
    la, lb, lr: UInt64;
begin
  for i := 0 to 3 do
  begin
    la := PQWord(@a.d[i])^;
    lb := PQWord(@b.d[i])^;
    lr := (la and mask.u[i]) or (lb and (not mask.u[i]));
    PQWord(@Result.d[i])^ := lr;
  end;
end;


// === F32x16 Arithmetic Operations (512-bit) ===
{$I generated/nextpas.core.simd.scalar.f32x16.arith.inc}

// === F64x8 Arithmetic Operations (512-bit) ===
{$I generated/nextpas.core.simd.scalar.f64x8.arith.inc}

// === I32x16 Arithmetic Operations (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.i32x16.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    for i := 0 to 15 do
      Result.i[i] := 0;
  end
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] shl count;
  end;
end;

function ScalarShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    for i := 0 to 15 do
      Result.i[i] := 0;
  end
  else
  begin
    // 逻辑右移（无符号）
    for i := 0 to 15 do
      Result.i[i] := Int32(UInt32(a.i[i]) shr count);
  end;
end;

function ScalarShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var i: Integer;
begin
  if count <= 0 then
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i];
  end
  else if count >= 32 then
  begin
    // 算术右移超过31位，结果为全0或全1（取决于符号位）
    for i := 0 to 15 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
  end
  else
  begin
    // 算术右移（保留符号）
    for i := 0 to 15 do
      Result.i[i] := SarLongint(a.i[i], count);
  end;
end;

{$POP}

// === U32x16 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.u32x16.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
    for i := 0 to 15 do
      Result.u[i] := 0
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] shl count;
end;

function ScalarShiftRightU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
    for i := 0 to 15 do
      Result.u[i] := 0
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] shr count;
end;

{$POP}

// === U64x8 Arithmetic/Bitwise/Shift/Comparison (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.u64x8.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then
    for i := 0 to 7 do
      Result.u[i] := 0
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shl count;
end;

function ScalarShiftRightU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then
    for i := 0 to 7 do
      Result.u[i] := 0
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shr count;
end;

{$POP}

// === I16x32 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.i16x32.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var i: Integer;
begin
  if (count <= 0) or (count >= 16) then
  begin
    for i := 0 to 31 do Result.i[i] := 0;
    Exit;
  end;
  for i := 0 to 31 do
    Result.i[i] := a.i[i] shl count;
end;

function ScalarShiftRightI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then
    for i := 0 to 31 do
      Result.i[i] := 0
  else
    for i := 0 to 31 do
      Result.i[i] := Int16(UInt16(a.i[i]) shr count);
end;

function ScalarShiftRightArithI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var i: Integer;
begin
  if count <= 0 then
    for i := 0 to 31 do
      Result.i[i] := a.i[i]
  else if count >= 16 then
    for i := 0 to 31 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0
  else
    for i := 0 to 31 do
      Result.i[i] := Int16(SarLongint(a.i[i], count));
end;

{$POP}

// === I8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===
{$I generated/nextpas.core.simd.scalar.i8x64.inc}

// === U8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===
{$I generated/nextpas.core.simd.scalar.u8x64.inc}


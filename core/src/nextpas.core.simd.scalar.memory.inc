// === Memory Operations ===

// Assert for nil pointer (performance-sensitive code)
function ScalarLoadF32x4(p: PSingle): TVecF32x4;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF32x4: pointer is nil');
  for i := 0 to 3 do
    Result.f[i] := p[i];
end;

function ScalarLoadF32x4Aligned(p: PSingle): TVecF32x4;
begin
  // For scalar implementation, aligned and unaligned are the same
  Result := ScalarLoadF32x4(p);
end;

procedure ScalarStoreF32x4(p: PSingle; const a: TVecF32x4);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF32x4: pointer is nil');
  for i := 0 to 3 do
    p[i] := a.f[i];
end;

procedure ScalarStoreF32x4Aligned(p: PSingle; const a: TVecF32x4);
begin
  // For scalar implementation, aligned and unaligned are the same
  ScalarStoreF32x4(p, a);
end;

// === Utility Operations ===

// 展开循环优化
function ScalarSplatF32x4(value: Single): TVecF32x4;
begin
  Result.f[0] := value;
  Result.f[1] := value;
  Result.f[2] := value;
  Result.f[3] := value;
end;

// 展开循环优化
function ScalarZeroF32x4: TVecF32x4;
begin
  Result.f[0] := 0.0;
  Result.f[1] := 0.0;
  Result.f[2] := 0.0;
  Result.f[3] := 0.0;
end;

function ScalarSelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if (mask and (1 shl i)) <> 0 then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := b.f[i];
end;

function ScalarExtractF32x4(const a: TVecF32x4; index: Integer): Single;
var
  safeIndex: Integer;
begin
  // use saturation strategy for index bounds (per project spec)
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.f[safeIndex];
end;

function ScalarInsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
var
  safeIndex: Integer;
begin
  // use saturation strategy for index bounds (per project spec)
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.f[safeIndex] := value;
end;

// === Extract/Insert Lane Operations ===

// F64x2 (128-bit)
function ScalarExtractF64x2(const a: TVecF64x2; index: Integer): Double;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a.d[safeIndex];
end;

function ScalarInsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a;
  Result.d[safeIndex] := value;
end;

// I32x4 (128-bit)
function ScalarExtractI32x4(const a: TVecI32x4; index: Integer): Int32;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.i[safeIndex];
end;

function ScalarInsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.i[safeIndex] := value;
end;

// I64x2 (128-bit)
function ScalarExtractI64x2(const a: TVecI64x2; index: Integer): Int64;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a.i[safeIndex];
end;

function ScalarInsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a;
  Result.i[safeIndex] := value;
end;

// F32x8 (256-bit)
function ScalarExtractF32x8(const a: TVecF32x8; index: Integer): Single;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a.f[safeIndex];
end;

function ScalarInsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a;
  Result.f[safeIndex] := value;
end;

// F64x4 (256-bit)
function ScalarExtractF64x4(const a: TVecF64x4; index: Integer): Double;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.d[safeIndex];
end;

function ScalarInsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.d[safeIndex] := value;
end;

// I32x8 (256-bit)
function ScalarExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a.i[safeIndex];
end;

function ScalarInsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a;
  Result.i[safeIndex] := value;
end;

// I64x4 (256-bit)
function ScalarExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.i[safeIndex];
end;

function ScalarInsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.i[safeIndex] := value;
end;

// F32x16 (512-bit)
function ScalarExtractF32x16(const a: TVecF32x16; index: Integer): Single;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a.f[safeIndex];
end;

function ScalarInsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a;
  Result.f[safeIndex] := value;
end;

// I32x16 (512-bit)
function ScalarExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a.i[safeIndex];
end;

function ScalarInsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a;
  Result.i[safeIndex] := value;
end;

// === Wide Vector Load/Store/Splat/Zero Functions ===

// F64x2 (128-bit)
function ScalarLoadF64x2(p: PDouble): TVecF64x2;
begin
  Assert(p <> nil, 'ScalarLoadF64x2: pointer is nil');
  Result.d[0] := p[0];
  Result.d[1] := p[1];
end;

procedure ScalarStoreF64x2(p: PDouble; const a: TVecF64x2);
begin
  Assert(p <> nil, 'ScalarStoreF64x2: pointer is nil');
  p[0] := a.d[0];
  p[1] := a.d[1];
end;

function ScalarSplatF64x2(value: Double): TVecF64x2;
begin
  Result.d[0] := value;
  Result.d[1] := value;
end;

function ScalarZeroF64x2: TVecF64x2;
begin
  Result.d[0] := 0.0;
  Result.d[1] := 0.0;
end;

// F32x8 (256-bit)
function ScalarLoadF32x8(p: PSingle): TVecF32x8;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF32x8: pointer is nil');
  for i := 0 to 7 do
    Result.f[i] := p[i];
end;

procedure ScalarStoreF32x8(p: PSingle; const a: TVecF32x8);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF32x8: pointer is nil');
  for i := 0 to 7 do
    p[i] := a.f[i];
end;

// 展开循环优化
function ScalarSplatF32x8(value: Single): TVecF32x8;
begin
  Result.f[0] := value;
  Result.f[1] := value;
  Result.f[2] := value;
  Result.f[3] := value;
  Result.f[4] := value;
  Result.f[5] := value;
  Result.f[6] := value;
  Result.f[7] := value;
end;

// 展开循环优化
function ScalarZeroF32x8: TVecF32x8;
begin
  Result.f[0] := 0.0;
  Result.f[1] := 0.0;
  Result.f[2] := 0.0;
  Result.f[3] := 0.0;
  Result.f[4] := 0.0;
  Result.f[5] := 0.0;
  Result.f[6] := 0.0;
  Result.f[7] := 0.0;
end;

// F64x4 (256-bit)
function ScalarLoadF64x4(p: PDouble): TVecF64x4;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF64x4: pointer is nil');
  for i := 0 to 3 do
    Result.d[i] := p[i];
end;

procedure ScalarStoreF64x4(p: PDouble; const a: TVecF64x4);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF64x4: pointer is nil');
  for i := 0 to 3 do
    p[i] := a.d[i];
end;

// 展开循环优化
function ScalarSplatF64x4(value: Double): TVecF64x4;
begin
  Result.d[0] := value;
  Result.d[1] := value;
  Result.d[2] := value;
  Result.d[3] := value;
end;

// 展开循环优化
function ScalarZeroF64x4: TVecF64x4;
begin
  Result.d[0] := 0.0;
  Result.d[1] := 0.0;
  Result.d[2] := 0.0;
  Result.d[3] := 0.0;
end;

// F32x16 (512-bit)
function ScalarLoadF32x16(p: PSingle): TVecF32x16;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF32x16: pointer is nil');
  for i := 0 to 15 do
    Result.f[i] := p[i];
end;

procedure ScalarStoreF32x16(p: PSingle; const a: TVecF32x16);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF32x16: pointer is nil');
  for i := 0 to 15 do
    p[i] := a.f[i];
end;

function ScalarSplatF32x16(value: Single): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := value;
end;

function ScalarZeroF32x16: TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := 0.0;
end;

// F64x8 (512-bit)
function ScalarLoadF64x8(p: PDouble): TVecF64x8;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF64x8: pointer is nil');
  for i := 0 to 7 do
    Result.d[i] := p[i];
end;

procedure ScalarStoreF64x8(p: PDouble; const a: TVecF64x8);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF64x8: pointer is nil');
  for i := 0 to 7 do
    p[i] := a.d[i];
end;

function ScalarSplatF64x8(value: Double): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := value;
end;

function ScalarZeroF64x8: TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := 0.0;
end;


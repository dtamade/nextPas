// === High-Level Vector Operations Implementation ===

function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4AddFunc;
begin
  LFunc := TVecF32x4AddFunc(LoadSimdFacadeFastPath(g_FastVecF32x4AddPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4AddFunc(LoadSimdFacadeFastPath(g_FastVecF32x4AddPtr));
  end;
  Result := LFunc(a, b);
end;

function VecF32x4Sub(const a, b: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.SubF32x4(a, b);
end;

function VecF32x4Mul(const a, b: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.MulF32x4(a, b);
end;

function VecF32x4Div(const a, b: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.DivF32x4(a, b);
end;

function VecF32x4CmpEq(const a, b: TVecF32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CmpEqF32x4(a, b);
end;

function VecF32x4CmpLt(const a, b: TVecF32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CmpLtF32x4(a, b);
end;

function VecF32x4CmpLe(const a, b: TVecF32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CmpLeF32x4(a, b);
end;

function VecF32x4CmpGt(const a, b: TVecF32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CmpGtF32x4(a, b);
end;

function VecF32x4CmpGe(const a, b: TVecF32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CmpGeF32x4(a, b);
end;

function VecF32x4CmpNe(const a, b: TVecF32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CmpNeF32x4(a, b);
end;

function VecF32x4Abs(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.AbsF32x4(a);
end;

function VecF32x4Sqrt(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.SqrtF32x4(a);
end;

function VecF32x4Min(const a, b: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.MinF32x4(a, b);
end;

function VecF32x4Max(const a, b: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.MaxF32x4(a, b);
end;

// === Extended Math Functions ===

function VecF32x4Fma(const a, b, c: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.FmaF32x4(a, b, c);
end;

function VecF32x4Rcp(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.RcpF32x4(a);
end;

function VecF32x4Rsqrt(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.RsqrtF32x4(a);
end;

function VecF32x4Floor(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.FloorF32x4(a);
end;

function VecF32x4Ceil(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CeilF32x4(a);
end;

function VecF32x4Round(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.RoundF32x4(a);
end;

function VecF32x4Trunc(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.TruncF32x4(a);
end;

function VecF32x4Clamp(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ClampF32x4(a, minVal, maxVal);
end;

// === 3D/4D Vector Math ===

function VecF32x4Dot(const a, b: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.DotF32x4(a, b);
end;

function VecF32x3Dot(const a, b: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.DotF32x3(a, b);
end;

function VecF32x3Cross(const a, b: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CrossF32x3(a, b);
end;

function VecF32x4Length(const a: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.LengthF32x4(a);
end;

function VecF32x3Length(const a: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.LengthF32x3(a);
end;

function VecF32x4Normalize(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.NormalizeF32x4(a);
end;

function VecF32x3Normalize(const a: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.NormalizeF32x3(a);
end;

// FMA-optimized Dot Product Functions

function VecF32x8Dot(const a, b: TVecF32x8): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.DotF32x8(a, b);
end;

function VecF64x2Dot(const a, b: TVecF64x2): Double;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.DotF64x2(a, b);
end;

function VecF64x4Dot(const a, b: TVecF64x4): Double;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.DotF64x4(a, b);
end;


function VecF32x4ReduceAdd(const a: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ReduceAddF32x4(a);
end;

function VecF32x4ReduceMin(const a: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ReduceMinF32x4(a);
end;

function VecF32x4ReduceMax(const a: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ReduceMaxF32x4(a);
end;

function VecF32x4ReduceMul(const a: TVecF32x4): Single;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ReduceMulF32x4(a);
end;

function VecF32x4Load(p: PSingle): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.LoadF32x4(p);
end;

function VecF32x4LoadAligned(p: PSingle): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.LoadF32x4Aligned(p);
end;

procedure VecF32x4Store(p: PSingle; const a: TVecF32x4);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  dispatch^.StoreF32x4(p, a);
end;

procedure VecF32x4StoreAligned(p: PSingle; const a: TVecF32x4);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  dispatch^.StoreF32x4Aligned(p, a);
end;

function VecF32x4Splat(value: Single): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.SplatF32x4(value);
end;

function VecF32x4Make(x, y, z, w: Single): TVecF32x4;
begin
  Result.f[0] := x;
  Result.f[1] := y;
  Result.f[2] := z;
  Result.f[3] := w;
end;

function VecF32x4Zero: TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ZeroF32x4();
end;

function VecF32x4Select(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.SelectF32x4(mask, a, b);
end;

function VecF32x4Extract(const a: TVecF32x4; index: Integer): Single;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractF32x4) then
    Result := dispatch^.ExtractF32x4(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a.f[LIndex];
  end;
end;

function VecF32x4Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertF32x4) then
    Result := dispatch^.InsertF32x4(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a;
    Result.f[LIndex] := value;
  end;
end;

// === Extract/Insert Lane Operations Implementation ===

// F64x2 (128-bit)
function VecF64x2Extract(const a: TVecF64x2; index: Integer): Double;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractF64x2) then
    Result := dispatch^.ExtractF64x2(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 1 then LIndex := 1;
    Result := a.d[LIndex];
  end;
end;

function VecF64x2Insert(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertF64x2) then
    Result := dispatch^.InsertF64x2(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 1 then LIndex := 1;
    Result := a;
    Result.d[LIndex] := value;
  end;
end;

// I32x4 (128-bit)
function VecI32x4Extract(const a: TVecI32x4; index: Integer): Int32;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractI32x4) then
    Result := dispatch^.ExtractI32x4(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a.i[LIndex];
  end;
end;

function VecI32x4Insert(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertI32x4) then
    Result := dispatch^.InsertI32x4(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a;
    Result.i[LIndex] := value;
  end;
end;

// I64x2 (128-bit)
function VecI64x2Extract(const a: TVecI64x2; index: Integer): Int64;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractI64x2) then
    Result := dispatch^.ExtractI64x2(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 1 then LIndex := 1;
    Result := a.i[LIndex];
  end;
end;

function VecI64x2Insert(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertI64x2) then
    Result := dispatch^.InsertI64x2(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 1 then LIndex := 1;
    Result := a;
    Result.i[LIndex] := value;
  end;
end;

// F32x8 (256-bit)
function VecF32x8Extract(const a: TVecF32x8; index: Integer): Single;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractF32x8) then
    Result := dispatch^.ExtractF32x8(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 7 then LIndex := 7;
    Result := a.f[LIndex];
  end;
end;

function VecF32x8Insert(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertF32x8) then
    Result := dispatch^.InsertF32x8(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 7 then LIndex := 7;
    Result := a;
    Result.f[LIndex] := value;
  end;
end;

// F64x4 (256-bit)
function VecF64x4Extract(const a: TVecF64x4; index: Integer): Double;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractF64x4) then
    Result := dispatch^.ExtractF64x4(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a.d[LIndex];
  end;
end;

function VecF64x4Insert(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertF64x4) then
    Result := dispatch^.InsertF64x4(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a;
    Result.d[LIndex] := value;
  end;
end;

// I32x8 (256-bit)
function VecI32x8Extract(const a: TVecI32x8; index: Integer): Int32;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractI32x8) then
    Result := dispatch^.ExtractI32x8(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 7 then LIndex := 7;
    Result := a.i[LIndex];
  end;
end;

function VecI32x8Insert(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertI32x8) then
    Result := dispatch^.InsertI32x8(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 7 then LIndex := 7;
    Result := a;
    Result.i[LIndex] := value;
  end;
end;

// I64x4 (256-bit)
function VecI64x4Extract(const a: TVecI64x4; index: Integer): Int64;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractI64x4) then
    Result := dispatch^.ExtractI64x4(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a.i[LIndex];
  end;
end;

function VecI64x4Insert(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertI64x4) then
    Result := dispatch^.InsertI64x4(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 3 then LIndex := 3;
    Result := a;
    Result.i[LIndex] := value;
  end;
end;

// F32x16 (512-bit)
function VecF32x16Extract(const a: TVecF32x16; index: Integer): Single;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractF32x16) then
    Result := dispatch^.ExtractF32x16(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 15 then LIndex := 15;
    Result := a.f[LIndex];
  end;
end;

function VecF32x16Insert(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertF32x16) then
    Result := dispatch^.InsertF32x16(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 15 then LIndex := 15;
    Result := a;
    Result.f[LIndex] := value;
  end;
end;

function VecF32x16Load(p: PSingle): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.LoadF32x16(p);
end;

procedure VecF32x16Store(p: PSingle; const a: TVecF32x16);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.StoreF32x16(p, a);
end;

function VecF32x16Splat(value: Single): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SplatF32x16(value);
end;

function VecF32x16Zero: TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ZeroF32x16();
end;

function VecF64x8Load(p: PDouble): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.LoadF64x8(p);
end;

procedure VecF64x8Store(p: PDouble; const a: TVecF64x8);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.StoreF64x8(p, a);
end;

function VecF64x8Splat(value: Double): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SplatF64x8(value);
end;

function VecF64x8Zero: TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ZeroF64x8();
end;

// I32x16 (512-bit)
function VecI32x16Extract(const a: TVecI32x16; index: Integer): Int32;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ExtractI32x16) then
    Result := dispatch^.ExtractI32x16(a, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 15 then LIndex := 15;
    Result := a.i[LIndex];
  end;
end;

function VecI32x16Insert(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
var dispatch: PSimdDispatchTable;
    LIndex: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.InsertI32x16) then
    Result := dispatch^.InsertI32x16(a, value, index)
  else
  begin
    LIndex := index;
    if LIndex < 0 then LIndex := 0
    else if LIndex > 15 then LIndex := 15;
    Result := a;
    Result.i[LIndex] := value;
  end;
end;

// === F64x2 Operations Implementation ===
// F64x2 高级 API 实现

function VecF64x2Add(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddF64x2) then
    Result := dispatch^.AddF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] + b.d[0];
    Result.d[1] := a.d[1] + b.d[1];
  end;
end;

function VecF64x2Sub(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubF64x2) then
    Result := dispatch^.SubF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] - b.d[0];
    Result.d[1] := a.d[1] - b.d[1];
  end;
end;

function VecF64x2Mul(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulF64x2) then
    Result := dispatch^.MulF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] * b.d[0];
    Result.d[1] := a.d[1] * b.d[1];
  end;
end;

function VecF64x2Div(const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.DivF64x2) then
    Result := dispatch^.DivF64x2(a, b)
  else
  begin
    Result.d[0] := a.d[0] / b.d[0];
    Result.d[1] := a.d[1] / b.d[1];
  end;
end;

// F64x2 比较操作 - 使用派发表

function VecF64x2CmpEq(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqF64x2) then
    Result := dispatch^.CmpEqF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] = b.d[0] then Result := Result or 1;
    if a.d[1] = b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpLt(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtF64x2) then
    Result := dispatch^.CmpLtF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] < b.d[0] then Result := Result or 1;
    if a.d[1] < b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpLe(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeF64x2) then
    Result := dispatch^.CmpLeF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] <= b.d[0] then Result := Result or 1;
    if a.d[1] <= b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpGt(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtF64x2) then
    Result := dispatch^.CmpGtF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] > b.d[0] then Result := Result or 1;
    if a.d[1] > b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpGe(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeF64x2) then
    Result := dispatch^.CmpGeF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] >= b.d[0] then Result := Result or 1;
    if a.d[1] >= b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2CmpNe(const a, b: TVecF64x2): TMask2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeF64x2) then
    Result := dispatch^.CmpNeF64x2(a, b)
  else begin
    Result := 0;
    if a.d[0] <> b.d[0] then Result := Result or 1;
    if a.d[1] <> b.d[1] then Result := Result or 2;
  end;
end;

function VecF64x2Abs(const a: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AbsF64x2) then
    Result := LDispatch^.AbsF64x2(a)
  else
  begin
    Result.d[0] := Abs(a.d[0]);
    Result.d[1] := Abs(a.d[1]);
  end;
end;

function VecF64x2Sqrt(const a: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SqrtF64x2) then
    Result := LDispatch^.SqrtF64x2(a)
  else
  begin
    Result.d[0] := Sqrt(a.d[0]);
    Result.d[1] := Sqrt(a.d[1]);
  end;
end;

function VecF64x2Min(const a, b: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinF64x2) then
    Result := LDispatch^.MinF64x2(a, b)
  else
  begin
    if a.d[0] < b.d[0] then Result.d[0] := a.d[0] else Result.d[0] := b.d[0];
    if a.d[1] < b.d[1] then Result.d[1] := a.d[1] else Result.d[1] := b.d[1];
  end;
end;

function VecF64x2Max(const a, b: TVecF64x2): TVecF64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxF64x2) then
    Result := LDispatch^.MaxF64x2(a, b)
  else
  begin
    if a.d[0] > b.d[0] then Result.d[0] := a.d[0] else Result.d[0] := b.d[0];
    if a.d[1] > b.d[1] then Result.d[1] := a.d[1] else Result.d[1] := b.d[1];
  end;
end;

// === F64x2 Extended Math Functions ===

function VecF64x2Fma(const a, b, c: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.FmaF64x2(a, b, c);
end;

// === F64x2 Rounding Functions ===

function VecF64x2Floor(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.FloorF64x2(a);
end;

function VecF64x2Ceil(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.CeilF64x2(a);
end;

function VecF64x2Round(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.RoundF64x2(a);
end;

function VecF64x2Trunc(const a: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.TruncF64x2(a);
end;

function VecF64x2Clamp(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.ClampF64x2(a, minVal, maxVal);
end;

function VecF64x2ReduceAdd(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceAddF64x2) then
    Result := LDispatch^.ReduceAddF64x2(a)
  else
    Result := a.d[0] + a.d[1];
end;

function VecF64x2ReduceMin(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMinF64x2) then
    Result := LDispatch^.ReduceMinF64x2(a)
  else if a.d[0] < a.d[1] then
    Result := a.d[0]
  else
    Result := a.d[1];
end;

function VecF64x2ReduceMax(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMaxF64x2) then
    Result := LDispatch^.ReduceMaxF64x2(a)
  else if a.d[0] > a.d[1] then
    Result := a.d[0]
  else
    Result := a.d[1];
end;

function VecF64x2ReduceMul(const a: TVecF64x2): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ReduceMulF64x2) then
    Result := LDispatch^.ReduceMulF64x2(a)
  else
    Result := a.d[0] * a.d[1];
end;

// F64x2 memory operations
function VecF64x2Load(p: PDouble): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.LoadF64x2) then
    Result := dispatch^.LoadF64x2(p)
  else
  begin
    Result.d[0] := p[0];
    Result.d[1] := p[1];
  end;
end;

procedure VecF64x2Store(p: PDouble; const a: TVecF64x2);
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.StoreF64x2) then
    dispatch^.StoreF64x2(p, a)
  else
  begin
    p[0] := a.d[0];
    p[1] := a.d[1];
  end;
end;

function VecF64x2Splat(value: Double): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SplatF64x2) then
    Result := dispatch^.SplatF64x2(value)
  else
  begin
    Result.d[0] := value;
    Result.d[1] := value;
  end;
end;

function VecF64x2Zero: TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ZeroF64x2) then
    Result := dispatch^.ZeroF64x2()
  else
  begin
    Result.d[0] := 0.0;
    Result.d[1] := 0.0;
  end;
end;

function VecF64x2Select(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectF64x2) then
    Result := dispatch^.SelectF64x2(mask, a, b)
  else
  begin
    // 标量回退实现
    if (mask and 1) <> 0 then Result.d[0] := a.d[0] else Result.d[0] := b.d[0];
    if (mask and 2) <> 0 then Result.d[1] := a.d[1] else Result.d[1] := b.d[1];
  end;
end;

// 缺失的 Select 操作实现

function VecI32x4Select(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
var
  dispatch: PSimdDispatchTable;
  i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectI32x4) then
    Result := dispatch^.SelectI32x4(mask, a, b)
  else
  begin
    for i := 0 to 3 do
      Result.i[i] := (a.i[i] and mask.i[i]) or (b.i[i] and (not mask.i[i]));
  end;
end;

function VecF32x8Select(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
var
  dispatch: PSimdDispatchTable;
  i: Integer;
  la, lb, lr: UInt32;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectF32x8) then
    Result := dispatch^.SelectF32x8(mask, a, b)
  else
  begin
    for i := 0 to 7 do
    begin
      la := PDWord(@a.f[i])^;
      lb := PDWord(@b.f[i])^;
      lr := (la and mask.u[i]) or (lb and (not mask.u[i]));
      PDWord(@Result.f[i])^ := lr;
    end;
  end;
end;

function VecF64x4Select(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;
var
  dispatch: PSimdDispatchTable;
  i: Integer;
  la64, lb64, lr64: UInt64;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SelectF64x4) then
    Result := dispatch^.SelectF64x4(mask, a, b)
  else
  begin
    for i := 0 to 3 do
    begin
      la64 := PQWord(@a.d[i])^;
      lb64 := PQWord(@b.d[i])^;
      lr64 := (la64 and mask.u[i]) or (lb64 and (not mask.u[i]));
      PQWord(@Result.d[i])^ := lr64;
    end;
  end;
end;

// Mask Operations Implementation
function Mask2All(mask: TMask2): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2All(mask);
end;

function Mask2Any(mask: TMask2): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2Any(mask);
end;

function Mask2None(mask: TMask2): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2None(mask);
end;

function Mask2PopCount(mask: TMask2): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2PopCount(mask);
end;

function Mask2FirstSet(mask: TMask2): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask2FirstSet(mask);
end;

function Mask4All(mask: TMask4): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4All(mask);
end;

function Mask4Any(mask: TMask4): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4Any(mask);
end;

function Mask4None(mask: TMask4): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4None(mask);
end;

function Mask4PopCount(mask: TMask4): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4PopCount(mask);
end;

function Mask4FirstSet(mask: TMask4): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask4FirstSet(mask);
end;

function Mask8All(mask: TMask8): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8All(mask);
end;

function Mask8Any(mask: TMask8): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8Any(mask);
end;

function Mask8None(mask: TMask8): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8None(mask);
end;

function Mask8PopCount(mask: TMask8): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8PopCount(mask);
end;

function Mask8FirstSet(mask: TMask8): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask8FirstSet(mask);
end;

function Mask16All(mask: TMask16): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16All(mask);
end;

function Mask16Any(mask: TMask16): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16Any(mask);
end;

function Mask16None(mask: TMask16): Boolean;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16None(mask);
end;

function Mask16PopCount(mask: TMask16): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16PopCount(mask);
end;

function Mask16FirstSet(mask: TMask16): Integer;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.Mask16FirstSet(mask);
end;

// === I32x4 Operations Implementation ===
// I32x4 高级 API 实现

function VecI32x4Add(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI32x4) then
    Result := dispatch^.AddI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] + b.i[0];
    Result.i[1] := a.i[1] + b.i[1];
    Result.i[2] := a.i[2] + b.i[2];
    Result.i[3] := a.i[3] + b.i[3];
  end;
end;

function VecI32x4Sub(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI32x4) then
    Result := dispatch^.SubI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] - b.i[0];
    Result.i[1] := a.i[1] - b.i[1];
    Result.i[2] := a.i[2] - b.i[2];
    Result.i[3] := a.i[3] - b.i[3];
  end;
end;

// === Core Operator Overloads Implementation ===

operator + (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Add(a, b);
end;

operator - (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Sub(a, b);
end;

operator * (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Mul(a, b);
end;

operator / (const a, b: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Div(a, b);
end;

operator - (const a: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Sub(VecF32x4Splat(0.0), a);
end;

operator * (const a: TVecF32x4; s: Single): TVecF32x4;
begin
  Result := VecF32x4Mul(a, VecF32x4Splat(s));
end;

operator * (s: Single; const a: TVecF32x4): TVecF32x4;
begin
  Result := VecF32x4Mul(VecF32x4Splat(s), a);
end;

operator / (const a: TVecF32x4; s: Single): TVecF32x4;
begin
  Result := VecF32x4Div(a, VecF32x4Splat(s));
end;

operator + (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Add(a, b);
end;

operator - (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Sub(a, b);
end;

operator * (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Mul(a, b);
end;

operator / (const a, b: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Div(a, b);
end;

operator - (const a: TVecF64x2): TVecF64x2;
begin
  Result := VecF64x2Sub(VecF64x2Splat(0.0), a);
end;

{$PUSH}{$R-}{$Q-}
operator + (const a, b: TVecI32x4): TVecI32x4;
begin
  Result := VecI32x4Add(a, b);
end;

operator - (const a, b: TVecI32x4): TVecI32x4;
begin
  Result := VecI32x4Sub(a, b);
end;

operator * (const a, b: TVecI32x4): TVecI32x4;
begin
  Result := VecI32x4Mul(a, b);
end;

operator - (const a: TVecI32x4): TVecI32x4;
var zero: TVecI32x4;
begin
  zero.i[0] := 0; zero.i[1] := 0; zero.i[2] := 0; zero.i[3] := 0;
  Result := VecI32x4Sub(zero, a);
end;
{$POP}

{$PUSH}{$R-}{$Q-}
// === Unsigned operator overloads (128/256/512-bit) ===

operator + (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Add(a, b);
end;

operator - (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Sub(a, b);
end;

operator * (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Mul(a, b);
end;

operator and (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4And(a, b);
end;

operator or (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Or(a, b);
end;

operator xor (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Xor(a, b);
end;

operator not (const a: TVecU32x4): TVecU32x4;
begin
  Result := VecU32x4Not(a);
end;

operator + (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Add(a, b);
end;

operator - (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Sub(a, b);
end;

operator and (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2And(a, b);
end;

operator or (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Or(a, b);
end;

operator xor (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Xor(a, b);
end;

operator not (const a: TVecU64x2): TVecU64x2;
begin
  Result := VecU64x2Not(a);
end;

operator + (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Add(a, b);
end;

operator - (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Sub(a, b);
end;

operator * (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Mul(a, b);
end;

operator and (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8And(a, b);
end;

operator or (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Or(a, b);
end;

operator xor (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Xor(a, b);
end;

operator not (const a: TVecU16x8): TVecU16x8;
begin
  Result := VecU16x8Not(a);
end;

operator + (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Add(a, b);
end;

operator - (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Sub(a, b);
end;

operator and (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16And(a, b);
end;

operator or (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Or(a, b);
end;

operator xor (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Xor(a, b);
end;

operator not (const a: TVecU8x16): TVecU8x16;
begin
  Result := VecU8x16Not(a);
end;

operator + (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Add(a, b);
end;

operator - (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Sub(a, b);
end;

operator * (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Mul(a, b);
end;

operator and (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8And(a, b);
end;

operator or (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Or(a, b);
end;

operator xor (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Xor(a, b);
end;

operator not (const a: TVecU32x8): TVecU32x8;
begin
  Result := VecU32x8Not(a);
end;

operator + (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Add(a, b);
end;

operator - (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Sub(a, b);
end;

operator and (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4And(a, b);
end;

operator or (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Or(a, b);
end;

operator xor (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Xor(a, b);
end;

operator not (const a: TVecU64x4): TVecU64x4;
begin
  Result := VecU64x4Not(a);
end;

operator + (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Add(a, b);
end;

operator - (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Sub(a, b);
end;

operator * (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Mul(a, b);
end;

operator and (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16And(a, b);
end;

operator or (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Or(a, b);
end;

operator xor (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Xor(a, b);
end;

operator not (const a: TVecU32x16): TVecU32x16;
begin
  Result := VecU32x16Not(a);
end;

operator + (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Add(a, b);
end;

operator - (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Sub(a, b);
end;

operator and (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8And(a, b);
end;

operator or (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Or(a, b);
end;

operator xor (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Xor(a, b);
end;

operator not (const a: TVecU64x8): TVecU64x8;
begin
  Result := VecU64x8Not(a);
end;

operator + (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Add(a, b);
end;

operator - (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Sub(a, b);
end;

operator and (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64And(a, b);
end;

operator or (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Or(a, b);
end;

operator xor (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Xor(a, b);
end;

operator not (const a: TVecU8x64): TVecU8x64;
begin
  Result := VecU8x64Not(a);
end;
{$POP}

function VecI32x4Mul(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulI32x4) then
    Result := dispatch^.MulI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] * b.i[0];
    Result.i[1] := a.i[1] * b.i[1];
    Result.i[2] := a.i[2] * b.i[2];
    Result.i[3] := a.i[3] * b.i[3];
  end;
end;

function VecI32x4And(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndI32x4) then
    Result := dispatch^.AndI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] and b.i[0];
    Result.i[1] := a.i[1] and b.i[1];
    Result.i[2] := a.i[2] and b.i[2];
    Result.i[3] := a.i[3] and b.i[3];
  end;
end;

function VecI32x4Or(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrI32x4) then
    Result := dispatch^.OrI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] or b.i[0];
    Result.i[1] := a.i[1] or b.i[1];
    Result.i[2] := a.i[2] or b.i[2];
    Result.i[3] := a.i[3] or b.i[3];
  end;
end;

function VecI32x4Xor(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorI32x4) then
    Result := dispatch^.XorI32x4(a, b)
  else
  begin
    Result.i[0] := a.i[0] xor b.i[0];
    Result.i[1] := a.i[1] xor b.i[1];
    Result.i[2] := a.i[2] xor b.i[2];
    Result.i[3] := a.i[3] xor b.i[3];
  end;
end;

function VecI32x4Not(const a: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotI32x4) then
    Result := dispatch^.NotI32x4(a)
  else
  begin
    Result.i[0] := not a.i[0];
    Result.i[1] := not a.i[1];
    Result.i[2] := not a.i[2];
    Result.i[3] := not a.i[3];
  end;
end;

function VecI32x4AndNot(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotI32x4) then
    Result := dispatch^.AndNotI32x4(a, b)
  else
  begin
    Result.i[0] := (not a.i[0]) and b.i[0];
    Result.i[1] := (not a.i[1]) and b.i[1];
    Result.i[2] := (not a.i[2]) and b.i[2];
    Result.i[3] := (not a.i[3]) and b.i[3];
  end;
end;

function VecI32x4ShiftLeft(const a: TVecI32x4; count: Integer): TVecI32x4;
var dispatch: PSimdDispatchTable;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Result.i[2] := 0;
    Result.i[3] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftI32x4) then
    Result := dispatch^.ShiftLeftI32x4(a, LCount)
  else
  begin
    Result.i[0] := a.i[0] shl LCount;
    Result.i[1] := a.i[1] shl LCount;
    Result.i[2] := a.i[2] shl LCount;
    Result.i[3] := a.i[3] shl LCount;
  end;
end;

function VecI32x4ShiftRight(const a: TVecI32x4; count: Integer): TVecI32x4;
var dispatch: PSimdDispatchTable;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Result.i[2] := 0;
    Result.i[3] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightI32x4) then
    Result := dispatch^.ShiftRightI32x4(a, LCount)
  else
  begin
    // Logical shift (unsigned)
    Result.i[0] := Int32(UInt32(a.i[0]) shr LCount);
    Result.i[1] := Int32(UInt32(a.i[1]) shr LCount);
    Result.i[2] := Int32(UInt32(a.i[2]) shr LCount);
    Result.i[3] := Int32(UInt32(a.i[3]) shr LCount);
  end;
end;

function VecI32x4ShiftRightArith(const a: TVecI32x4; count: Integer): TVecI32x4;
var dispatch: PSimdDispatchTable;
    LCount: Integer;
begin
  LCount := count;
  if LCount < 0 then
  begin
    Result := a;
    Exit;
  end;

  if LCount >= 32 then
  begin
    if a.i[0] < 0 then Result.i[0] := -1 else Result.i[0] := 0;
    if a.i[1] < 0 then Result.i[1] := -1 else Result.i[1] := 0;
    if a.i[2] < 0 then Result.i[2] := -1 else Result.i[2] := 0;
    if a.i[3] < 0 then Result.i[3] := -1 else Result.i[3] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightArithI32x4) then
    Result := dispatch^.ShiftRightArithI32x4(a, LCount)
  else
  begin
    // Arithmetic shift (signed)
    Result.i[0] := SarLongint(a.i[0], LCount);
    Result.i[1] := SarLongint(a.i[1], LCount);
    Result.i[2] := SarLongint(a.i[2], LCount);
    Result.i[3] := SarLongint(a.i[3], LCount);
  end;
end;

function VecI32x4CmpEq(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqI32x4) then
    Result := dispatch^.CmpEqI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] = b.i[0] then Result := Result or 1;
    if a.i[1] = b.i[1] then Result := Result or 2;
    if a.i[2] = b.i[2] then Result := Result or 4;
    if a.i[3] = b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpLt(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtI32x4) then
    Result := dispatch^.CmpLtI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] < b.i[0] then Result := Result or 1;
    if a.i[1] < b.i[1] then Result := Result or 2;
    if a.i[2] < b.i[2] then Result := Result or 4;
    if a.i[3] < b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpGt(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtI32x4) then
    Result := dispatch^.CmpGtI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] > b.i[0] then Result := Result or 1;
    if a.i[1] > b.i[1] then Result := Result or 2;
    if a.i[2] > b.i[2] then Result := Result or 4;
    if a.i[3] > b.i[3] then Result := Result or 8;
  end;
end;

// 添加 I32x4 缺失比较函数
function VecI32x4CmpLe(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeI32x4) then
    Result := dispatch^.CmpLeI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <= b.i[0] then Result := Result or 1;
    if a.i[1] <= b.i[1] then Result := Result or 2;
    if a.i[2] <= b.i[2] then Result := Result or 4;
    if a.i[3] <= b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpGe(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeI32x4) then
    Result := dispatch^.CmpGeI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] >= b.i[0] then Result := Result or 1;
    if a.i[1] >= b.i[1] then Result := Result or 2;
    if a.i[2] >= b.i[2] then Result := Result or 4;
    if a.i[3] >= b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4CmpNe(const a, b: TVecI32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpNeI32x4) then
    Result := dispatch^.CmpNeI32x4(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <> b.i[0] then Result := Result or 1;
    if a.i[1] <> b.i[1] then Result := Result or 2;
    if a.i[2] <> b.i[2] then Result := Result or 4;
    if a.i[3] <> b.i[3] then Result := Result or 8;
  end;
end;

function VecI32x4Min(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinI32x4) then
    Result := dispatch^.MinI32x4(a, b)
  else
  begin
    for i := 0 to 3 do
      if a.i[i] < b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

function VecI32x4Max(const a, b: TVecI32x4): TVecI32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxI32x4) then
    Result := dispatch^.MaxI32x4(a, b)
  else
  begin
    for i := 0 to 3 do
      if a.i[i] > b.i[i] then
        Result.i[i] := a.i[i]
      else
        Result.i[i] := b.i[i];
  end;
end;

// === I64x2 Operations Implementation ===
// I64x2 高级 API 实现

function VecI64x2Add(const a, b: TVecI64x2): TVecI64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddI64x2) then
    Result := dispatch^.AddI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] + b.i[0];
    Result.i[1] := a.i[1] + b.i[1];
  end;
end;

function VecI64x2Sub(const a, b: TVecI64x2): TVecI64x2;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubI64x2) then
    Result := dispatch^.SubI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] - b.i[0];
    Result.i[1] := a.i[1] - b.i[1];
  end;
end;

function VecI64x2And(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndI64x2) then
    Result := LDispatch^.AndI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] and b.i[0];
    Result.i[1] := a.i[1] and b.i[1];
  end;
end;

function VecI64x2Or(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.OrI64x2) then
    Result := LDispatch^.OrI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] or b.i[0];
    Result.i[1] := a.i[1] or b.i[1];
  end;
end;

function VecI64x2Xor(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.XorI64x2) then
    Result := LDispatch^.XorI64x2(a, b)
  else
  begin
    Result.i[0] := a.i[0] xor b.i[0];
    Result.i[1] := a.i[1] xor b.i[1];
  end;
end;

function VecI64x2Not(const a: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.NotI64x2) then
    Result := LDispatch^.NotI64x2(a)
  else
  begin
    Result.i[0] := not a.i[0];
    Result.i[1] := not a.i[1];
  end;
end;

function VecI64x2AndNot(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotI64x2) then
    Result := LDispatch^.AndNotI64x2(a, b)
  else
  begin
    // (~a) and b
    Result.i[0] := (not a.i[0]) and b.i[0];
    Result.i[1] := (not a.i[1]) and b.i[1];
  end;
end;

// I64x2 完整 API 实现 - 移位/比较/Min/Max

function VecI64x2ShiftLeft(const a: TVecI64x2; count: Integer): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftLeftI64x2) then
    Result := LDispatch^.ShiftLeftI64x2(a, LCount)
  else
  begin
    Result.i[0] := a.i[0] shl LCount;
    Result.i[1] := a.i[1] shl LCount;
  end;
end;

function VecI64x2ShiftRight(const a: TVecI64x2; count: Integer): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    Result.i[0] := 0;
    Result.i[1] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftRightI64x2) then
    Result := LDispatch^.ShiftRightI64x2(a, LCount)
  else
  begin
    // 逻辑右移 (无符号)
    Result.i[0] := Int64(UInt64(a.i[0]) shr LCount);
    Result.i[1] := Int64(UInt64(a.i[1]) shr LCount);
  end;
end;

function VecI64x2ShiftRightArith(const a: TVecI64x2; count: Integer): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
  LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 64 then
  begin
    if a.i[0] < 0 then Result.i[0] := -1 else Result.i[0] := 0;
    if a.i[1] < 0 then Result.i[1] := -1 else Result.i[1] := 0;
    Exit;
  end;

  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.ShiftRightArithI64x2) then
    Result := LDispatch^.ShiftRightArithI64x2(a, LCount)
  else
  begin
    // 算术右移 (保留符号位)
    Result.i[0] := SarInt64(a.i[0], LCount);
    Result.i[1] := SarInt64(a.i[1], LCount);
  end;
end;

function VecI64x2CmpEq(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpEqI64x2) then
    Result := LDispatch^.CmpEqI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] = b.i[0] then Result := Result or 1;
    if a.i[1] = b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpLt(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLtI64x2) then
    Result := LDispatch^.CmpLtI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] < b.i[0] then Result := Result or 1;
    if a.i[1] < b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpGt(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGtI64x2) then
    Result := LDispatch^.CmpGtI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] > b.i[0] then Result := Result or 1;
    if a.i[1] > b.i[1] then Result := Result or 2;
  end;
end;

// 添加 I64x2 缺失比较函数
function VecI64x2CmpLe(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLeI64x2) then
    Result := LDispatch^.CmpLeI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <= b.i[0] then Result := Result or 1;
    if a.i[1] <= b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpGe(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGeI64x2) then
    Result := LDispatch^.CmpGeI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] >= b.i[0] then Result := Result or 1;
    if a.i[1] >= b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2CmpNe(const a, b: TVecI64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpNeI64x2) then
    Result := LDispatch^.CmpNeI64x2(a, b)
  else
  begin
    Result := 0;
    if a.i[0] <> b.i[0] then Result := Result or 1;
    if a.i[1] <> b.i[1] then Result := Result or 2;
  end;
end;

function VecI64x2Min(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinI64x2) then
    Result := LDispatch^.MinI64x2(a, b)
  else
  begin
    if a.i[0] < b.i[0] then Result.i[0] := a.i[0] else Result.i[0] := b.i[0];
    if a.i[1] < b.i[1] then Result.i[1] := a.i[1] else Result.i[1] := b.i[1];
  end;
end;

function VecI64x2Max(const a, b: TVecI64x2): TVecI64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxI64x2) then
    Result := LDispatch^.MaxI64x2(a, b)
  else
  begin
    if a.i[0] > b.i[0] then Result.i[0] := a.i[0] else Result.i[0] := b.i[0];
    if a.i[1] > b.i[1] then Result.i[1] := a.i[1] else Result.i[1] := b.i[1];
  end;
end;

// === U64x2 Operations Implementation ===
// U64x2 (128-bit, 2x UInt64) 高级 API 实现

function VecU64x2Add(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AddU64x2) then
    Result := LDispatch^.AddU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] + b.u[0];
    Result.u[1] := a.u[1] + b.u[1];
  end;
end;

function VecU64x2Sub(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.SubU64x2) then
    Result := LDispatch^.SubU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] - b.u[0];
    Result.u[1] := a.u[1] - b.u[1];
  end;
end;

function VecU64x2And(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndU64x2) then
    Result := LDispatch^.AndU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] and b.u[0];
    Result.u[1] := a.u[1] and b.u[1];
  end;
end;

function VecU64x2Or(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.OrU64x2) then
    Result := LDispatch^.OrU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] or b.u[0];
    Result.u[1] := a.u[1] or b.u[1];
  end;
end;

function VecU64x2Xor(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.XorU64x2) then
    Result := LDispatch^.XorU64x2(a, b)
  else
  begin
    Result.u[0] := a.u[0] xor b.u[0];
    Result.u[1] := a.u[1] xor b.u[1];
  end;
end;

function VecU64x2Not(const a: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.NotU64x2) then
    Result := LDispatch^.NotU64x2(a)
  else
  begin
    Result.u[0] := not a.u[0];
    Result.u[1] := not a.u[1];
  end;
end;

function VecU64x2AndNot(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.AndNotU64x2) then
    Result := LDispatch^.AndNotU64x2(a, b)
  else
  begin
    // (~a) and b
    Result.u[0] := (not a.u[0]) and b.u[0];
    Result.u[1] := (not a.u[1]) and b.u[1];
  end;
end;

function VecU64x2CmpEq(const a, b: TVecU64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpEqU64x2) then
    Result := LDispatch^.CmpEqU64x2(a, b)
  else
  begin
    Result := 0;
    if a.u[0] = b.u[0] then Result := Result or 1;
    if a.u[1] = b.u[1] then Result := Result or 2;
  end;
end;

function VecU64x2CmpLt(const a, b: TVecU64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpLtU64x2) then
    Result := LDispatch^.CmpLtU64x2(a, b)
  else
  begin
    Result := 0;
    if a.u[0] < b.u[0] then Result := Result or 1;  // 无符号比较
    if a.u[1] < b.u[1] then Result := Result or 2;
  end;
end;

function VecU64x2CmpGt(const a, b: TVecU64x2): TMask2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.CmpGtU64x2) then
    Result := LDispatch^.CmpGtU64x2(a, b)
  else
  begin
    Result := 0;
    if a.u[0] > b.u[0] then Result := Result or 1;  // 无符号比较
    if a.u[1] > b.u[1] then Result := Result or 2;
  end;
end;

function VecU64x2Min(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MinU64x2) then
    Result := LDispatch^.MinU64x2(a, b)
  else
  begin
    if a.u[0] < b.u[0] then Result.u[0] := a.u[0] else Result.u[0] := b.u[0];
    if a.u[1] < b.u[1] then Result.u[1] := a.u[1] else Result.u[1] := b.u[1];
  end;
end;

function VecU64x2Max(const a, b: TVecU64x2): TVecU64x2;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  if (LDispatch <> nil) and Assigned(LDispatch^.MaxU64x2) then
    Result := LDispatch^.MaxU64x2(a, b)
  else
  begin
    if a.u[0] > b.u[0] then Result.u[0] := a.u[0] else Result.u[0] := b.u[0];
    if a.u[1] > b.u[1] then Result.u[1] := a.u[1] else Result.u[1] := b.u[1];
  end;
end;

// === U32x4 Operations Implementation ===
// U32x4 (128-bit Unsigned) 高级 API 实现
// 修改为使用 dispatch table 以获得 SIMD 加速
// 注意: 无符号整数 SIMD 操作在位层面与有符号相同,
// 区别在于比较和 min/max 使用无符号语义

function VecU32x4Add(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AddU32x4) then
    Result := dispatch^.AddU32x4(a, b)
  else
    Result := a + b;
end;

function VecU32x4Sub(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.SubU32x4) then
    Result := dispatch^.SubU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] - b.u[i];
end;

function VecU32x4Mul(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MulU32x4) then
    Result := dispatch^.MulU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] * b.u[i];
end;

function VecU32x4And(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndU32x4) then
    Result := dispatch^.AndU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] and b.u[i];
end;

function VecU32x4Or(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.OrU32x4) then
    Result := dispatch^.OrU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] or b.u[i];
end;

function VecU32x4Xor(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.XorU32x4) then
    Result := dispatch^.XorU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] xor b.u[i];
end;

function VecU32x4Not(const a: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.NotU32x4) then
    Result := dispatch^.NotU32x4(a)
  else
    for i := 0 to 3 do
      Result.u[i] := not a.u[i];
end;

function VecU32x4AndNot(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.AndNotU32x4) then
    Result := dispatch^.AndNotU32x4(a, b)
  else
    for i := 0 to 3 do
      Result.u[i] := (not a.u[i]) and b.u[i];
end;

function VecU32x4ShiftLeft(const a: TVecU32x4; count: Integer): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftLeftU32x4) then
    Result := dispatch^.ShiftLeftU32x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shl LCount;
end;

function VecU32x4ShiftRight(const a: TVecU32x4; count: Integer): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
    LCount: Integer;
begin
  LCount := count;
  if LCount <= 0 then begin Result := a; Exit; end;
  if LCount >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
    Exit;
  end;

  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.ShiftRightU32x4) then
    Result := dispatch^.ShiftRightU32x4(a, LCount)
  else
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shr LCount;  // 逻辑右移 (无符号)
end;

function VecU32x4CmpEq(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpEqU32x4) then
    Result := dispatch^.CmpEqU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] = b.u[0] then Result := Result or 1;
    if a.u[1] = b.u[1] then Result := Result or 2;
    if a.u[2] = b.u[2] then Result := Result or 4;
    if a.u[3] = b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpLt(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLtU32x4) then
    Result := dispatch^.CmpLtU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] < b.u[0] then Result := Result or 1;
    if a.u[1] < b.u[1] then Result := Result or 2;
    if a.u[2] < b.u[2] then Result := Result or 4;
    if a.u[3] < b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpGt(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGtU32x4) then
    Result := dispatch^.CmpGtU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] > b.u[0] then Result := Result or 1;
    if a.u[1] > b.u[1] then Result := Result or 2;
    if a.u[2] > b.u[2] then Result := Result or 4;
    if a.u[3] > b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpLe(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpLeU32x4) then
    Result := dispatch^.CmpLeU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] <= b.u[0] then Result := Result or 1;
    if a.u[1] <= b.u[1] then Result := Result or 2;
    if a.u[2] <= b.u[2] then Result := Result or 4;
    if a.u[3] <= b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4CmpGe(const a, b: TVecU32x4): TMask4;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.CmpGeU32x4) then
    Result := dispatch^.CmpGeU32x4(a, b)
  else
  begin
    Result := 0;
    if a.u[0] >= b.u[0] then Result := Result or 1;
    if a.u[1] >= b.u[1] then Result := Result or 2;
    if a.u[2] >= b.u[2] then Result := Result or 4;
    if a.u[3] >= b.u[3] then Result := Result or 8;
  end;
end;

function VecU32x4Min(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MinU32x4) then
    Result := dispatch^.MinU32x4(a, b)
  else
    for i := 0 to 3 do
      if a.u[i] < b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

function VecU32x4Max(const a, b: TVecU32x4): TVecU32x4;
var dispatch: PSimdDispatchTable;
    i: Integer;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  if (dispatch <> nil) and Assigned(dispatch^.MaxU32x4) then
    Result := dispatch^.MaxU32x4(a, b)
  else
    for i := 0 to 3 do
      if a.u[i] > b.u[i] then
        Result.u[i] := a.u[i]
      else
        Result.u[i] := b.u[i];
end;

// === P1 Missing Functions: Integer Abs ===

function VecI32x4Abs(const a: TVecI32x4): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if a.i[i] < 0 then
      Result.i[i] := -a.i[i]
    else
      Result.i[i] := a.i[i];
end;

function VecI16x8Abs(const a: TVecI16x8): TVecI16x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if a.i[i] < 0 then
      Result.i[i] := -a.i[i]
    else
      Result.i[i] := a.i[i];
end;

function VecI8x16Abs(const a: TVecI8x16): TVecI8x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] < 0 then
      Result.i[i] := -a.i[i]
    else
      Result.i[i] := a.i[i];
end;

// === P1 Missing Functions: I32x4 Splat/Zero/Load/Store ===

function VecI32x4Splat(value: Int32): TVecI32x4;
begin
  Result.i[0] := value;
  Result.i[1] := value;
  Result.i[2] := value;
  Result.i[3] := value;
end;

function VecI32x4Zero: TVecI32x4;
begin
  Result.i[0] := 0;
  Result.i[1] := 0;
  Result.i[2] := 0;
  Result.i[3] := 0;
end;

function VecI32x4Load(p: PInt32): TVecI32x4;
begin
  Result.i[0] := p[0];
  Result.i[1] := p[1];
  Result.i[2] := p[2];
  Result.i[3] := p[3];
end;

procedure VecI32x4Store(p: PInt32; const a: TVecI32x4);
begin
  p[0] := a.i[0];
  p[1] := a.i[1];
  p[2] := a.i[2];
  p[3] := a.i[3];
end;

// === P1 Missing Functions: Integer Clamp ===

function VecI32x4Clamp(const a, minVal, maxVal: TVecI32x4): TVecI32x4;
var i: Integer;
    v: Int32;
begin
  for i := 0 to 3 do
  begin
    v := a.i[i];
    if v < minVal.i[i] then v := minVal.i[i];
    if v > maxVal.i[i] then v := maxVal.i[i];
    Result.i[i] := v;
  end;
end;

// === P1 Missing Functions: Integer Reduce ===

function VecI32x4ReduceAdd(const a: TVecI32x4): Int32;
begin
  Result := a.i[0] + a.i[1] + a.i[2] + a.i[3];
end;

function VecI32x4ReduceMin(const a: TVecI32x4): Int32;
begin
  Result := a.i[0];
  if a.i[1] < Result then Result := a.i[1];
  if a.i[2] < Result then Result := a.i[2];
  if a.i[3] < Result then Result := a.i[3];
end;

function VecI32x4ReduceMax(const a: TVecI32x4): Int32;
begin
  Result := a.i[0];
  if a.i[1] > Result then Result := a.i[1];
  if a.i[2] > Result then Result := a.i[2];
  if a.i[3] > Result then Result := a.i[3];
end;

// === P1 Missing Functions: VecF32x4Lerp ===

function VecF32x4Lerp(const a, b: TVecF32x4; t: Single): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := a.f[i] + t * (b.f[i] - a.f[i]);
end;

// === P1 Missing Functions: VecU32x4CmpNe ===

function VecU32x4CmpNe(const a, b: TVecU32x4): TMask4;
begin
  Result := 0;
  if a.u[0] <> b.u[0] then Result := Result or 1;
  if a.u[1] <> b.u[1] then Result := Result or 2;
  if a.u[2] <> b.u[2] then Result := Result or 4;
  if a.u[3] <> b.u[3] then Result := Result or 8;
end;

// === P1 Missing Functions: Make functions ===

function VecF64x2Make(x, y: Double): TVecF64x2;
begin
  Result.d[0] := x;
  Result.d[1] := y;
end;

function VecI32x4Make(a, b, c, d: Int32): TVecI32x4;
begin
  Result.i[0] := a;
  Result.i[1] := b;
  Result.i[2] := c;
  Result.i[3] := d;
end;

function VecF32x8Make(a, b, c, d, e, f, g, h: Single): TVecF32x8;
begin
  Result.f[0] := a;
  Result.f[1] := b;
  Result.f[2] := c;
  Result.f[3] := d;
  Result.f[4] := e;
  Result.f[5] := f;
  Result.f[6] := g;
  Result.f[7] := h;
end;

// === P2 Completeness: Batch Array F64 Extensions (inline facade) ===

procedure ArrayFmaF64(aSrc1, aSrc2, aSrc3, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] * aSrc2[i] + aSrc3[i];
end;

procedure ArrayMinF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    if aSrc1[i] < aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;

procedure ArrayMaxF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    if aSrc1[i] > aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;

procedure ArrayExpF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Exp(aSrc[i]);
end;

procedure ArrayLogF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Ln(aSrc[i]);
end;

procedure ArraySinF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Sin(aSrc[i]);
end;

procedure ArrayCosF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  for i := 0 to aCount - 1 do
    aDst[i] := System.Cos(aSrc[i]);
end;

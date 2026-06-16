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
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.AddF32x4(a, b);
end;

function VecF32x4Sub(const a, b: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4SubFunc;
begin
  LFunc := TVecF32x4SubFunc(LoadSimdFacadeFastPath(g_FastVecF32x4SubPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4SubFunc(LoadSimdFacadeFastPath(g_FastVecF32x4SubPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.SubF32x4(a, b);
end;

function VecF32x4Mul(const a, b: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4MulFunc;
begin
  LFunc := TVecF32x4MulFunc(LoadSimdFacadeFastPath(g_FastVecF32x4MulPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4MulFunc(LoadSimdFacadeFastPath(g_FastVecF32x4MulPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.MulF32x4(a, b);
end;

function VecF32x4Div(const a, b: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4DivFunc;
begin
  LFunc := TVecF32x4DivFunc(LoadSimdFacadeFastPath(g_FastVecF32x4DivPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4DivFunc(LoadSimdFacadeFastPath(g_FastVecF32x4DivPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.DivF32x4(a, b);
end;

function VecF32x4CmpEq(const a, b: TVecF32x4): TMask4; inline;
var
  LFunc: TVecF32x4CmpEqFunc;
begin
  LFunc := TVecF32x4CmpEqFunc(LoadSimdFacadeFastPath(g_FastVecF32x4CmpEqPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4CmpEqFunc(LoadSimdFacadeFastPath(g_FastVecF32x4CmpEqPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.CmpEqF32x4(a, b);
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

function VecF32x4Abs(const a: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4UnaryFunc;
begin
  LFunc := TVecF32x4UnaryFunc(LoadSimdFacadeFastPath(g_FastVecF32x4AbsPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4UnaryFunc(LoadSimdFacadeFastPath(g_FastVecF32x4AbsPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a)
  else
    Result := GetSimdFacadeDispatchFastPath^.AbsF32x4(a);
end;

function VecF32x4Sqrt(const a: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4UnaryFunc;
begin
  LFunc := TVecF32x4UnaryFunc(LoadSimdFacadeFastPath(g_FastVecF32x4SqrtPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4UnaryFunc(LoadSimdFacadeFastPath(g_FastVecF32x4SqrtPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a)
  else
    Result := GetSimdFacadeDispatchFastPath^.SqrtF32x4(a);
end;

function VecF32x4Min(const a, b: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4MinMaxFunc;
begin
  LFunc := TVecF32x4MinMaxFunc(LoadSimdFacadeFastPath(g_FastVecF32x4MinPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4MinMaxFunc(LoadSimdFacadeFastPath(g_FastVecF32x4MinPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.MinF32x4(a, b);
end;

function VecF32x4Max(const a, b: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4MinMaxFunc;
begin
  LFunc := TVecF32x4MinMaxFunc(LoadSimdFacadeFastPath(g_FastVecF32x4MaxPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4MinMaxFunc(LoadSimdFacadeFastPath(g_FastVecF32x4MaxPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.MaxF32x4(a, b);
end;

// === Extended Math Functions ===

function VecF32x4Fma(const a, b, c: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4FmaFunc;
begin
  LFunc := TVecF32x4FmaFunc(LoadSimdFacadeFastPath(g_FastVecF32x4FmaPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4FmaFunc(LoadSimdFacadeFastPath(g_FastVecF32x4FmaPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b, c)
  else
    Result := GetSimdFacadeDispatchFastPath^.FmaF32x4(a, b, c);
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

function VecF32x4Dot(const a, b: TVecF32x4): Single; inline;
var
  LFunc: TVecF32x4DotFunc;
begin
  LFunc := TVecF32x4DotFunc(LoadSimdFacadeFastPath(g_FastVecF32x4DotPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4DotFunc(LoadSimdFacadeFastPath(g_FastVecF32x4DotPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.DotF32x4(a, b);
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

function VecF32x4Splat(value: Single): TVecF32x4; inline;
var
  LFunc: TVecF32x4SplatFunc;
begin
  LFunc := TVecF32x4SplatFunc(LoadSimdFacadeFastPath(g_FastVecF32x4SplatPtr));
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4SplatFunc(LoadSimdFacadeFastPath(g_FastVecF32x4SplatPtr));
  end;
  if Assigned(LFunc) then
    Result := LFunc(value)
  else
    Result := GetSimdFacadeDispatchFastPath^.SplatF32x4(value);
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


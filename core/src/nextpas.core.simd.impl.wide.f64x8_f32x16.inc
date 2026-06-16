// === F64x8 Operations Implementation ===
// F64x8 (512-bit, 8x Double) 高级 API 实现

function VecF64x8Add(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AddF64x8(a, b);
end;

function VecF64x8Sub(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubF64x8(a, b);
end;

function VecF64x8Mul(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MulF64x8(a, b);
end;

function VecF64x8Div(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.DivF64x8(a, b);
end;

function VecF64x8CmpEq(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqF64x8(a, b);
end;

function VecF64x8CmpLt(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtF64x8(a, b);
end;

function VecF64x8CmpLe(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLeF64x8(a, b);
end;

function VecF64x8CmpGt(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtF64x8(a, b);
end;

function VecF64x8CmpGe(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGeF64x8(a, b);
end;

function VecF64x8CmpNe(const a, b: TVecF64x8): TMask8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpNeF64x8(a, b);
end;

function VecF64x8Abs(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AbsF64x8(a);
end;

function VecF64x8Sqrt(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SqrtF64x8(a);
end;

function VecF64x8Min(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinF64x8(a, b);
end;

function VecF64x8Max(const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MaxF64x8(a, b);
end;

function VecF64x8Clamp(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ClampF64x8(a, minVal, maxVal);
end;

function VecF64x8Fma(const a, b, c: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FmaF64x8(a, b, c);
end;

function VecF64x8Floor(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FloorF64x8(a);
end;

function VecF64x8Ceil(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CeilF64x8(a);
end;

function VecF64x8Round(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.RoundF64x8(a);
end;

function VecF64x8Trunc(const a: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.TruncF64x8(a);
end;

function VecF64x8ReduceAdd(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceAddF64x8(a);
end;

function VecF64x8ReduceMin(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMinF64x8(a);
end;

function VecF64x8ReduceMax(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMaxF64x8(a);
end;

function VecF64x8ReduceMul(const a: TVecF64x8): Double;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMulF64x8(a);
end;

function VecF64x8Select(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SelectF64x8(mask, a, b);
end;

// === F32x16 Operations Implementation ===
// F32x16 (512-bit, 16x Single) 高级 API 实现

function VecF32x16Add(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AddF32x16(a, b);
end;

function VecF32x16Sub(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SubF32x16(a, b);
end;

function VecF32x16Mul(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MulF32x16(a, b);
end;

function VecF32x16Div(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.DivF32x16(a, b);
end;

function VecF32x16CmpEq_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpEqF32x16(a, b);
end;

function VecF32x16CmpLt_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLtF32x16(a, b);
end;

function VecF32x16CmpLe_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpLeF32x16(a, b);
end;

function VecF32x16CmpGt_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGtF32x16(a, b);
end;

function VecF32x16CmpGe_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpGeF32x16(a, b);
end;

function VecF32x16CmpNe_Mask(const a, b: TVecF32x16): TMask16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CmpNeF32x16(a, b);
end;

function VecF32x16Abs(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.AbsF32x16(a);
end;

function VecF32x16Sqrt(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SqrtF32x16(a);
end;

function VecF32x16Min(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MinF32x16(a, b);
end;

function VecF32x16Max(const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.MaxF32x16(a, b);
end;

function VecF32x16Clamp(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ClampF32x16(a, minVal, maxVal);
end;

function VecF32x16Fma(const a, b, c: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FmaF32x16(a, b, c);
end;

function VecF32x16Floor(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.FloorF32x16(a);
end;

function VecF32x16Ceil(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.CeilF32x16(a);
end;

function VecF32x16Round(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.RoundF32x16(a);
end;

function VecF32x16Trunc(const a: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.TruncF32x16(a);
end;

function VecF32x16ReduceAdd(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceAddF32x16(a);
end;

function VecF32x16ReduceMin(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMinF32x16(a);
end;

function VecF32x16ReduceMax(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMaxF32x16(a);
end;

function VecF32x16ReduceMul(const a: TVecF32x16): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMulF32x16(a);
end;

function VecF32x16Select(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.SelectF32x16(mask, a, b);
end;


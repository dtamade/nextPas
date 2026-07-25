// === Batch Array Operations (scalar reference implementations) ===
// Note:  prevents FPC auto-vectorization for fair SIMD vs scalar benchmarks.


procedure ScalarArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;


procedure ScalarArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] - aSrc2[i];
end;


procedure ScalarArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] * aSrc2[i];
end;


procedure ScalarArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] / aSrc2[i];
end;


procedure ScalarArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc1[i] <= aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;


procedure ScalarArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc1[i] >= aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;


procedure ScalarArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LVal: LongWord;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    LVal := PLongWord(@aSrc[i])^ and $7FFFFFFF;
    PLongWord(@aDst[i])^ := LVal;
  end;
end;


procedure ScalarArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LVal: LongWord;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    LVal := PLongWord(@aSrc[i])^ xor $80000000;
    PLongWord(@aDst[i])^ := LVal;
  end;
end;


procedure ScalarArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdSqrtF32(aSrc[i]);
end;


procedure ScalarArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / aSrc[i];
end;


procedure ScalarArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / Sqrt(aSrc[i]);
end;


procedure ScalarArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / aSrc[i];
end;


procedure ScalarArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / Sqrt(aSrc[i]);
end;


procedure ScalarArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScalar;
end;


procedure ScalarArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] + aScalar;
end;


procedure ScalarArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
var
  i: SizeUInt;
  v: Single;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v < aMin then v := aMin
    else if v > aMax then v := aMax;
    aDst[i] := v;
  end;
end;


procedure ScalarArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aA[i] * aB[i] + aC[i];
end;


procedure ScalarArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aAlpha * aX[i] + aY[i];
end;


function ScalarReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc[i];
end;


function ScalarReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc1[i] * aSrc2[i];
end;


function ScalarReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] < Result then Result := aSrc[i];
end;


function ScalarReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] > Result then Result := aSrc[i];
end;

// === Batch Array Operations - F64 (Scalar Reference) ===


procedure ScalarArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;


procedure ScalarArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] - aSrc2[i];
end;


procedure ScalarArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] * aSrc2[i];
end;


procedure ScalarArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] / aSrc2[i];
end;


function ScalarReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc[i];
end;


function ScalarReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc1[i] * aSrc2[i];
end;


function ScalarReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] < Result then Result := aSrc[i];
end;


function ScalarReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] > Result then Result := aSrc[i];
end;


procedure ScalarArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Abs(aSrc[i]);
end;


procedure ScalarArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := -aSrc[i];
end;


procedure ScalarArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Sqrt(aSrc[i]);
end;


procedure ScalarArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScalar;
end;


procedure ScalarArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] + aScalar;
end;


procedure ScalarArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
var i: SizeUInt; v: Double;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v < aMin then v := aMin
    else if v > aMax then v := aMax;
    aDst[i] := v;
  end;
end;


procedure ScalarArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScale + aBias;
end;


procedure ScalarArrayMinF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc1[i] < aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;


procedure ScalarArrayMaxF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc1[i] > aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;


procedure ScalarArrayFmaF64(aA, aB, aC, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aA[i] * aB[i] + aC[i];
end;


procedure ScalarArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Exp(aSrc[i]));
end;


procedure ScalarArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Ln(aSrc[i]));
end;


procedure ScalarArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(SimdPowerF32(aSrc[i], aExponent));
end;


procedure ScalarArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Sin(aSrc[i]));
end;


procedure ScalarArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Cos(aSrc[i]));
end;


procedure ScalarArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;


procedure ScalarArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] - aSrc2[i];
end;


procedure ScalarArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Int16(Int32(aSrc1[i]) * Int32(aSrc2[i]));
end;


procedure ScalarArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);
var
  i: SizeUInt;
  v: Int32;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v > 32767 then v := 32767
    else if v < -32768 then v := -32768;
    aDst[i] := Int16(v);
  end;
end;


procedure ScalarArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Round(aSrc[i]);
end;


procedure ScalarArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(aSrc[i]);
end;


procedure ScalarArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] and aSrc2[i];
end;


procedure ScalarArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] or aSrc2[i];
end;


procedure ScalarArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] xor aSrc2[i];
end;


procedure ScalarArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] shl aShift;
end;


procedure ScalarArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SarLongint(aSrc[i], aShift);
end;

// === Fused Batch Operations ===


procedure ScalarArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScale + aBias;
end;


procedure ScalarArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Abs(aSrc1[i] - aSrc2[i]);
end;


procedure ScalarArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc[i] > 0 then aDst[i] := aSrc[i]
    else aDst[i] := 0;
end;


procedure ScalarArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := (aSrc[i] - aMean) * aInvStd;
end;


procedure ScalarArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var i: SizeUInt; v: Single;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i] * aScale + aBias;
    if v < 0 then v := 0;
    aDst[i] := v;
  end;
end;



procedure ScalarArrayTanF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdTanF32(aSrc[i]);
end;


procedure ScalarArraySinCosF32(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aSinDst = nil) or (aCosDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    aSinDst[i] := SimdSinF32(aSrc[i]);
    aCosDst[i] := SimdCosF32(aSrc[i]);
  end;
end;


procedure ScalarArrayLog2F32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdLnF32(aSrc[i]) / SimdLnF32(2.0);
end;


procedure ScalarArrayLog10F32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdLog10F32(aSrc[i]);
end;


procedure ScalarArrayCeilF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdCeilF32(aSrc[i]);
end;


procedure ScalarArrayFloorF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdFloorF32(aSrc[i]);
end;


procedure ScalarArrayRoundF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdRoundF32(aSrc[i]);
end;


procedure ScalarArrayTruncF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdTruncFloatF32(aSrc[i]);
end;


procedure ScalarArrayLerpF32(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single);
var i: SizeUInt;
begin
  if (aCount = 0) or (aStart = nil) or (aEnd = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aStart[i] + aT * (aEnd[i] - aStart[i]);
end;


procedure ScalarArrayAtan2F32(aY, aX, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aY = nil) or (aX = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdArcTan2F32(aY[i], aX[i]);
end;


procedure ScalarArrayHypotF32(aX, aY, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aX = nil) or (aY = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdSqrtF32(aX[i] * aX[i] + aY[i] * aY[i]);
end;


procedure ScalarArrayFractF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] - Trunc(aSrc[i]);
end;


procedure ScalarArrayModF32(aSrc, aDst: PSingle; aCount: SizeUInt; aDivisor: Single);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] - aDivisor * Trunc(aSrc[i] / aDivisor);
end;


procedure ScalarArraySignF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt; v: Single;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v > 0 then
      aDst[i] := 1.0
    else if v < 0 then
      aDst[i] := -1.0
    else
      aDst[i] := 0.0;
  end;
end;


procedure ScalarArrayStepF32(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aEdge = nil) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    if aSrc[i] < aEdge[i] then
      aDst[i] := 0.0
    else
      aDst[i] := 1.0;
  end;
end;


procedure ScalarArraySmoothstepF32(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt; t, v: Single;
begin
  if (aCount = 0) or (aEdge0 = nil) or (aEdge1 = nil) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := (aSrc[i] - aEdge0[i]) / (aEdge1[i] - aEdge0[i]);
    if v < 0 then v := 0;
    if v > 1 then v := 1;
    t := v * v;
    aDst[i] := t * (3 - 2 * v);
  end;
end;

// === Batch Array Operations - Transcendental F64 ===


procedure ScalarArraySinF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Sin(aSrc[i]);
end;


procedure ScalarArrayCosF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Cos(aSrc[i]);
end;


procedure ScalarArraySinCosF64(aSrc, aSinDst, aCosDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aSinDst = nil) or (aCosDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    aSinDst[i] := System.Sin(aSrc[i]);
    aCosDst[i] := System.Cos(aSrc[i]);
  end;
end;


procedure ScalarArrayExpF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Exp(aSrc[i]);
end;


procedure ScalarArrayLogF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Ln(aSrc[i]);
end;


procedure ScalarArrayLog2F64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Ln(aSrc[i]) * 1.4426950408889634; // 1/ln(2)
end;


procedure ScalarArrayLog10F64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Ln(aSrc[i]) * 0.4342944819032518; // 1/ln(10)
end;


procedure ScalarArrayCeilF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdCeilF64(aSrc[i]);
end;


procedure ScalarArrayFloorF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdFloorF64(aSrc[i]);
end;


procedure ScalarArrayRoundF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdRoundF64(aSrc[i]);
end;


procedure ScalarArrayTruncF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdTruncFloatF64(aSrc[i]);
end;


// === Batch Array Operations - F64 Extended ===


procedure ScalarArrayAxpyF64(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aX = nil) or (aY = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aAlpha * aX[i] + aY[i];
end;


procedure ScalarArrayRcpF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / aSrc[i];
end;


procedure ScalarArrayRsqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / System.Sqrt(aSrc[i]);
end;


procedure ScalarArrayRcpRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / aSrc[i];
end;


procedure ScalarArrayRsqrtRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / System.Sqrt(aSrc[i]);
end;


procedure ScalarArrayTanF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdSinF64(aSrc[i]) / SimdCosF64(aSrc[i]);
end;


procedure ScalarArraySignF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt; v: Double;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v > 0 then
      aDst[i] := 1.0
    else if v < 0 then
      aDst[i] := -1.0
    else
      aDst[i] := 0.0;
  end;
end;


procedure ScalarArrayFractF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] - Trunc(aSrc[i]);
end;


procedure ScalarArrayModF64(aSrc, aDst: PDouble; aCount: SizeUInt; aDivisor: Double);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] - aDivisor * Trunc(aSrc[i] / aDivisor);
end;


procedure ScalarArrayPowF64(aSrc, aDst: PDouble; aCount: SizeUInt; aExponent: Double);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdPowerF64(aSrc[i], aExponent);
end;


procedure ScalarArrayLerpF64(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double);
var i: SizeUInt;
begin
  if (aCount = 0) or (aStart = nil) or (aEnd = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aStart[i] + aT * (aEnd[i] - aStart[i]);
end;


procedure ScalarArrayReLUF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    if aSrc[i] > 0 then aDst[i] := aSrc[i]
    else aDst[i] := 0;
end;


procedure ScalarArrayAbsDiffF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Abs(aSrc1[i] - aSrc2[i]);
end;


procedure ScalarArrayNormF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMean, aInvStd: Double);
var i: SizeUInt;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := (aSrc[i] - aMean) * aInvStd;
end;


procedure ScalarArrayLinearReLUF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var i: SizeUInt; v: Double;
begin
  if (aCount = 0) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i] * aScale + aBias;
    if v < 0 then v := 0;
    aDst[i] := v;
  end;
end;


procedure ScalarArrayStepF64(aEdge, aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aEdge = nil) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    if aSrc[i] < aEdge[i] then
      aDst[i] := 0.0
    else
      aDst[i] := 1.0;
  end;
end;


procedure ScalarArraySmoothstepF64(aEdge0, aEdge1, aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt; t, v: Double;
begin
  if (aCount = 0) or (aEdge0 = nil) or (aEdge1 = nil) or (aSrc = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := (aSrc[i] - aEdge0[i]) / (aEdge1[i] - aEdge0[i]);
    if v < 0 then v := 0;
    if v > 1 then v := 1;
    t := v * v;
    aDst[i] := t * (3 - 2 * v);
  end;
end;


procedure ScalarArrayAtan2F64(aY, aX, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aY = nil) or (aX = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SimdArcTan2F64(aY[i], aX[i]);
end;


procedure ScalarArrayHypotF64(aX, aY, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if (aCount = 0) or (aX = nil) or (aY = nil) or (aDst = nil) then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Sqrt(aX[i] * aX[i] + aY[i] * aY[i]);
end;

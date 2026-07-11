// === Dispatch Table Accessor Implementations ===
// Zero-cost wrappers that delegate to the flat dispatch table

// --- TF32x4Accessor ---

constructor TF32x4Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TF32x4Accessor.Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.AddF32x4(a, b);
end;

function TF32x4Accessor.Sub(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.SubF32x4(a, b);
end;

function TF32x4Accessor.Mul(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.MulF32x4(a, b);
end;

function TF32x4Accessor.Divide(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.DivF32x4(a, b);
end;

function TF32x4Accessor.Neg(const a: TVecF32x4): TVecF32x4; inline;
begin
  // Negate by subtracting from zero
  Result := FTable^.SubF32x4(FTable^.ZeroF32x4(), a);
end;

function TF32x4Accessor.Abs(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.AbsF32x4(a);
end;

function TF32x4Accessor.Sqrt(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.SqrtF32x4(a);
end;

function TF32x4Accessor.Min(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.MinF32x4(a, b);
end;

function TF32x4Accessor.Max(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.MaxF32x4(a, b);
end;

function TF32x4Accessor.Clamp(const a, minVal, maxVal: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.ClampF32x4(a, minVal, maxVal);
end;

function TF32x4Accessor.Fma(const a, b, c: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.FmaF32x4(a, b, c);
end;

function TF32x4Accessor.Floor(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.FloorF32x4(a);
end;

function TF32x4Accessor.Ceil(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CeilF32x4(a);
end;

function TF32x4Accessor.Round(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.RoundF32x4(a);
end;

function TF32x4Accessor.Trunc(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.TruncF32x4(a);
end;

function TF32x4Accessor.Rcp(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.RcpF32x4(a);
end;

function TF32x4Accessor.Rsqrt(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.RsqrtF32x4(a);
end;

function TF32x4Accessor.CmpEq(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CmpEqF32x4(a, b);
end;

function TF32x4Accessor.CmpLt(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CmpLtF32x4(a, b);
end;

function TF32x4Accessor.CmpLe(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CmpLeF32x4(a, b);
end;

function TF32x4Accessor.CmpGt(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CmpGtF32x4(a, b);
end;

function TF32x4Accessor.CmpGe(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CmpGeF32x4(a, b);
end;

function TF32x4Accessor.CmpNe(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CmpNeF32x4(a, b);
end;

function TF32x4Accessor.Dot4(const a, b: TVecF32x4): Single; inline;
begin
  Result := FTable^.DotF32x4(a, b);
end;

function TF32x4Accessor.Dot3(const a, b: TVecF32x4): Single; inline;
begin
  Result := FTable^.DotF32x3(a, b);
end;

function TF32x4Accessor.Cross3(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CrossF32x3(a, b);
end;

function TF32x4Accessor.Length4(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.LengthF32x4(a);
end;

function TF32x4Accessor.Length3(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.LengthF32x3(a);
end;

function TF32x4Accessor.Normalize4(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.NormalizeF32x4(a);
end;

function TF32x4Accessor.Normalize3(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.NormalizeF32x3(a);
end;

function TF32x4Accessor.ReduceAdd(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.ReduceAddF32x4(a);
end;

function TF32x4Accessor.ReduceMin(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.ReduceMinF32x4(a);
end;

function TF32x4Accessor.ReduceMax(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.ReduceMaxF32x4(a);
end;

function TF32x4Accessor.ReduceMul(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.ReduceMulF32x4(a);
end;

function TF32x4Accessor.Load(p: PSingle): TVecF32x4; inline;
begin
  Result := FTable^.LoadF32x4(p);
end;

function TF32x4Accessor.LoadAligned(p: PSingle): TVecF32x4; inline;
begin
  Result := FTable^.LoadF32x4Aligned(p);
end;

procedure TF32x4Accessor.Store(p: PSingle; const a: TVecF32x4); inline;
begin
  FTable^.StoreF32x4(p, a);
end;

procedure TF32x4Accessor.StoreAligned(p: PSingle; const a: TVecF32x4); inline;
begin
  FTable^.StoreF32x4Aligned(p, a);
end;

function TF32x4Accessor.Splat(value: Single): TVecF32x4; inline;
begin
  Result := FTable^.SplatF32x4(value);
end;

function TF32x4Accessor.Zero: TVecF32x4; inline;
begin
  Result := FTable^.ZeroF32x4();
end;

function TF32x4Accessor.Make(x, y, z, w: Single): TVecF32x4; inline;
begin
  // Create vector from individual components using Insert
  Result := FTable^.ZeroF32x4();
  Result := FTable^.InsertF32x4(Result, x, 0);
  Result := FTable^.InsertF32x4(Result, y, 1);
  Result := FTable^.InsertF32x4(Result, z, 2);
  Result := FTable^.InsertF32x4(Result, w, 3);
end;

function TF32x4Accessor.Select(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.SelectF32x4(mask, a, b);
end;

function TF32x4Accessor.Extract(const a: TVecF32x4; index: Integer): Single; inline;
begin
  Result := FTable^.ExtractF32x4(a, index);
end;

function TF32x4Accessor.Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4; inline;
begin
  Result := FTable^.InsertF32x4(a, value, index);
end;

// --- TF64x2Accessor ---

constructor TF64x2Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TF64x2Accessor.Add(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.AddF64x2(a, b);
end;

function TF64x2Accessor.Sub(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.SubF64x2(a, b);
end;

function TF64x2Accessor.Mul(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.MulF64x2(a, b);
end;

function TF64x2Accessor.Divide(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.DivF64x2(a, b);
end;

function TF64x2Accessor.Neg(const a: TVecF64x2): TVecF64x2; inline;
begin
  // Negate by subtracting from zero
  Result := FTable^.SubF64x2(FTable^.ZeroF64x2(), a);
end;

function TF64x2Accessor.Abs(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.AbsF64x2(a);
end;

function TF64x2Accessor.Sqrt(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.SqrtF64x2(a);
end;

function TF64x2Accessor.Min(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.MinF64x2(a, b);
end;

function TF64x2Accessor.Max(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.MaxF64x2(a, b);
end;

function TF64x2Accessor.Clamp(const a, minVal, maxVal: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.ClampF64x2(a, minVal, maxVal);
end;

function TF64x2Accessor.Fma(const a, b, c: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.FmaF64x2(a, b, c);
end;

function TF64x2Accessor.Floor(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.FloorF64x2(a);
end;

function TF64x2Accessor.Ceil(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CeilF64x2(a);
end;

function TF64x2Accessor.Round(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.RoundF64x2(a);
end;

function TF64x2Accessor.Trunc(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.TruncF64x2(a);
end;

function TF64x2Accessor.CmpEq(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CmpEqF64x2(a, b);
end;

function TF64x2Accessor.CmpLt(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CmpLtF64x2(a, b);
end;

function TF64x2Accessor.CmpLe(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CmpLeF64x2(a, b);
end;

function TF64x2Accessor.CmpGt(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CmpGtF64x2(a, b);
end;

function TF64x2Accessor.CmpGe(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CmpGeF64x2(a, b);
end;

function TF64x2Accessor.CmpNe(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CmpNeF64x2(a, b);
end;

function TF64x2Accessor.Dot(const a, b: TVecF64x2): Double; inline;
begin
  Result := FTable^.DotF64x2(a, b);
end;

function TF64x2Accessor.ReduceAdd(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.ReduceAddF64x2(a);
end;

function TF64x2Accessor.ReduceMin(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.ReduceMinF64x2(a);
end;

function TF64x2Accessor.ReduceMax(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.ReduceMaxF64x2(a);
end;

function TF64x2Accessor.ReduceMul(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.ReduceMulF64x2(a);
end;

function TF64x2Accessor.Load(p: PDouble): TVecF64x2; inline;
begin
  Result := FTable^.LoadF64x2(p);
end;

function TF64x2Accessor.LoadAligned(p: PDouble): TVecF64x2; inline;
begin
  // F64x2 doesn't have aligned load in dispatch table, use regular load
  Result := FTable^.LoadF64x2(p);
end;

procedure TF64x2Accessor.Store(p: PDouble; const a: TVecF64x2); inline;
begin
  FTable^.StoreF64x2(p, a);
end;

procedure TF64x2Accessor.StoreAligned(p: PDouble; const a: TVecF64x2); inline;
begin
  // F64x2 doesn't have aligned store in dispatch table, use regular store
  FTable^.StoreF64x2(p, a);
end;

function TF64x2Accessor.Splat(value: Double): TVecF64x2; inline;
begin
  Result := FTable^.SplatF64x2(value);
end;

function TF64x2Accessor.Zero: TVecF64x2; inline;
begin
  Result := FTable^.ZeroF64x2();
end;

function TF64x2Accessor.Make(x, y: Double): TVecF64x2; inline;
begin
  // Create vector from individual components using Insert
  Result := FTable^.ZeroF64x2();
  Result := FTable^.InsertF64x2(Result, x, 0);
  Result := FTable^.InsertF64x2(Result, y, 1);
end;

function TF64x2Accessor.Select(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.SelectF64x2(mask, a, b);
end;

function TF64x2Accessor.Extract(const a: TVecF64x2; index: Integer): Double; inline;
begin
  Result := FTable^.ExtractF64x2(a, index);
end;

function TF64x2Accessor.Insert(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2; inline;
begin
  Result := FTable^.InsertF64x2(a, value, index);
end;

// --- TMemoryAccessor ---

constructor TMemoryAccessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TMemoryAccessor.Equal(a, b: Pointer; len: SizeUInt): LongBool; inline;
begin
  Result := FTable^.MemEqual(a, b, len);
end;

function TMemoryAccessor.FindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt; inline;
begin
  Result := FTable^.MemFindByte(p, len, value);
end;

function TMemoryAccessor.DiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; inline;
begin
  Result := FTable^.MemDiffRange(a, b, len, firstDiff, lastDiff);
end;

procedure TMemoryAccessor.Copy(src, dst: Pointer; len: SizeUInt); inline;
begin
  FTable^.MemCopy(src, dst, len);
end;

procedure TMemoryAccessor.Fill(dst: Pointer; len: SizeUInt; value: Byte); inline;
begin
  FTable^.MemSet(dst, len, value);
end;

procedure TMemoryAccessor.Reverse(p: Pointer; len: SizeUInt); inline;
begin
  FTable^.MemReverse(p, len);
end;

function TMemoryAccessor.SumBytes(p: Pointer; len: SizeUInt): UInt64; inline;
begin
  Result := FTable^.SumBytes(p, len);
end;

procedure TMemoryAccessor.MinMaxBytes(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); inline;
begin
  FTable^.MinMaxBytes(p, len, minVal, maxVal);
end;

function TMemoryAccessor.CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; inline;
begin
  Result := FTable^.CountByte(p, len, value);
end;

function TMemoryAccessor.Utf8Validate(p: Pointer; len: SizeUInt): Boolean; inline;
begin
  Result := FTable^.Utf8Validate(p, len);
end;

function TMemoryAccessor.AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean; inline;
begin
  Result := FTable^.AsciiIEqual(a, b, len);
end;

procedure TMemoryAccessor.ToLowerAscii(p: Pointer; len: SizeUInt); inline;
begin
  FTable^.ToLowerAscii(p, len);
end;

procedure TMemoryAccessor.ToUpperAscii(p: Pointer; len: SizeUInt); inline;
begin
  FTable^.ToUpperAscii(p, len);
end;

function TMemoryAccessor.BytesIndexOf(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; inline;
begin
  Result := FTable^.BytesIndexOf(haystack, haystackLen, needle, needleLen);
end;

function TMemoryAccessor.BitsetPopCount(p: Pointer; len: SizeUInt): SizeUInt; inline;
begin
  Result := FTable^.BitsetPopCount(p, len);
end;

// --- TBatchF32Accessor ---

constructor TBatchF32Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

procedure TBatchF32Accessor.ArrayAdd(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAddF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySub(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArraySubF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayMul(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayMulF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayDiv(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayDivF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayMin(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayMinF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayMax(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayMaxF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAbs(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAbsF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayNeg(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayNegF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySqrt(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArraySqrtF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRcp(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayRcpF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRsqrt(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayRsqrtF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAddScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
begin
  FTable^.ArrayAddScalarF32(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF32Accessor.ArrayMulScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
begin
  FTable^.ArrayMulScalarF32(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF32Accessor.ArrayClamp(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single); inline;
begin
  FTable^.ArrayClampF32(aSrc, aDst, aCount, aMin, aMax);
end;

procedure TBatchF32Accessor.ArrayFma(aA, aB, aC, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayFmaF32(aA, aB, aC, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAxpy(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAxpyF32(aAlpha, aX, aY, aDst, aCount);
end;

function TBatchF32Accessor.ReduceSum(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.ReduceSumF32(aSrc, aCount);
end;

function TBatchF32Accessor.ReduceDot(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.ReduceDotF32(aSrc1, aSrc2, aCount);
end;

function TBatchF32Accessor.ReduceMin(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.ReduceMinF32(aSrc, aCount);
end;

function TBatchF32Accessor.ReduceMax(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.ReduceMaxF32(aSrc, aCount);
end;

procedure TBatchF32Accessor.ArrayExp(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayExpF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLog(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayLogF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayPow(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single); inline;
begin
  FTable^.ArrayPowF32(aSrc, aDst, aCount, aExponent);
end;

procedure TBatchF32Accessor.ArraySin(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArraySinF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayCos(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayCosF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayTan(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayTanF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySinCos(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArraySinCosF32(aSrc, aSinDst, aCosDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLog2(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayLog2F32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLog10(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayLog10F32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAtan2(aY, aX, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAtan2F32(aY, aX, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayHypot(aX, aY, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayHypotF32(aX, aY, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayCeil(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayCeilF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayFloor(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayFloorF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRound(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayRoundF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayTrunc(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayTruncF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayFract(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayFractF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLerp(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single); inline;
begin
  FTable^.ArrayLerpF32(aStart, aEnd, aDst, aCount, aT);
end;

procedure TBatchF32Accessor.ArrayMod(aSrc, aDst: PSingle; aCount: SizeUInt; aDivisor: Single); inline;
begin
  FTable^.ArrayModF32(aSrc, aDst, aCount, aDivisor);
end;

procedure TBatchF32Accessor.ArraySign(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArraySignF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayStep(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayStepF32(aEdge, aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArraySmoothstepF32(aEdge0, aEdge1, aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLinear(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;
begin
  FTable^.ArrayLinearF32(aSrc, aDst, aCount, aScale, aBias);
end;

procedure TBatchF32Accessor.ArrayAbsDiff(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAbsDiffF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayReLU(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.ArrayReLUF32(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayNorm(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single); inline;
begin
  FTable^.ArrayNormF32(aSrc, aDst, aCount, aMean, aInvStd);
end;

procedure TBatchF32Accessor.ArrayLinearReLU(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;
begin
  FTable^.ArrayLinearReLUF32(aSrc, aDst, aCount, aScale, aBias);
end;

// --- TBatchF64Accessor ---

constructor TBatchF64Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

procedure TBatchF64Accessor.ArrayAdd(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAddF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySub(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArraySubF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMul(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayMulF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayDiv(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayDivF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMin(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayMinF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMax(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayMaxF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAbs(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAbsF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayNeg(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayNegF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySqrt(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArraySqrtF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMulScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
begin
  FTable^.ArrayMulScalarF64(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF64Accessor.ArrayAddScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
begin
  FTable^.ArrayAddScalarF64(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF64Accessor.ArrayClamp(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double); inline;
begin
  FTable^.ArrayClampF64(aSrc, aDst, aCount, aMin, aMax);
end;

procedure TBatchF64Accessor.ArrayLinear(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); inline;
begin
  FTable^.ArrayLinearF64(aSrc, aDst, aCount, aScale, aBias);
end;

procedure TBatchF64Accessor.ArrayFma(aA, aB, aC, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayFmaF64(aA, aB, aC, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAxpy(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAxpyF64(aAlpha, aX, aY, aDst, aCount);
end;

function TBatchF64Accessor.ReduceSum(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.ReduceSumF64(aSrc, aCount);
end;

function TBatchF64Accessor.ReduceDot(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.ReduceDotF64(aSrc1, aSrc2, aCount);
end;

function TBatchF64Accessor.ReduceMin(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.ReduceMinF64(aSrc, aCount);
end;

function TBatchF64Accessor.ReduceMax(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.ReduceMaxF64(aSrc, aCount);
end;

procedure TBatchF64Accessor.ArraySin(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArraySinF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayCos(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayCosF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySinCos(aSrc, aSinDst, aCosDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArraySinCosF64(aSrc, aSinDst, aCosDst, aCount);
end;

procedure TBatchF64Accessor.ArrayExp(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayExpF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayLog(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayLogF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayLog2(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayLog2F64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayLog10(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayLog10F64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayCeil(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayCeilF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayFloor(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayFloorF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayRound(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayRoundF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayTrunc(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayTruncF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayTan(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayTanF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySign(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArraySignF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayFract(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayFractF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMod(aSrc, aDst: PDouble; aCount: SizeUInt; aDivisor: Double); inline;
begin
  FTable^.ArrayModF64(aSrc, aDst, aCount, aDivisor);
end;

procedure TBatchF64Accessor.ArrayPow(aSrc, aDst: PDouble; aCount: SizeUInt; aExponent: Double); inline;
begin
  FTable^.ArrayPowF64(aSrc, aDst, aCount, aExponent);
end;

procedure TBatchF64Accessor.ArrayLerp(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double); inline;
begin
  FTable^.ArrayLerpF64(aStart, aEnd, aDst, aCount, aT);
end;

procedure TBatchF64Accessor.ArrayReLU(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayReLUF64(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAbsDiff(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAbsDiffF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayNorm(aSrc, aDst: PDouble; aCount: SizeUInt; aMean, aInvStd: Double); inline;
begin
  FTable^.ArrayNormF64(aSrc, aDst, aCount, aMean, aInvStd);
end;

procedure TBatchF64Accessor.ArrayLinearReLU(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); inline;
begin
  FTable^.ArrayLinearReLUF64(aSrc, aDst, aCount, aScale, aBias);
end;

procedure TBatchF64Accessor.ArrayStep(aEdge, aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayStepF64(aEdge, aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArraySmoothstepF64(aEdge0, aEdge1, aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAtan2(aY, aX, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayAtan2F64(aY, aX, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayHypot(aX, aY, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.ArrayHypotF64(aX, aY, aDst, aCount);
end;

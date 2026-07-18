// === Dispatch Table Accessor Implementations ===
// Zero-cost wrappers that delegate to the flat dispatch table

// --- TF32x4Accessor ---

constructor TF32x4Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TF32x4Accessor.Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.AddF32x4(a, b);
end;

function TF32x4Accessor.Sub(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.SubF32x4(a, b);
end;

function TF32x4Accessor.Mul(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.MulF32x4(a, b);
end;

function TF32x4Accessor.Divide(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.DivF32x4(a, b);
end;

function TF32x4Accessor.Neg(const a: TVecF32x4): TVecF32x4; inline;
begin
  // Negate by subtracting from zero
  Result := FTable^.CoreVectors.SubF32x4(FTable^.CoreVectors.ZeroF32x4(), a);
end;

function TF32x4Accessor.Abs(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.AbsF32x4(a);
end;

function TF32x4Accessor.Sqrt(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.SqrtF32x4(a);
end;

function TF32x4Accessor.Min(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.MinF32x4(a, b);
end;

function TF32x4Accessor.Max(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.MaxF32x4(a, b);
end;

function TF32x4Accessor.Clamp(const a, minVal, maxVal: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.ClampF32x4(a, minVal, maxVal);
end;

function TF32x4Accessor.Fma(const a, b, c: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.FmaF32x4(a, b, c);
end;

function TF32x4Accessor.Floor(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.FloorF32x4(a);
end;

function TF32x4Accessor.Ceil(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.CeilF32x4(a);
end;

function TF32x4Accessor.Round(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.RoundF32x4(a);
end;

function TF32x4Accessor.Trunc(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.TruncF32x4(a);
end;

function TF32x4Accessor.Rcp(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.RcpF32x4(a);
end;

function TF32x4Accessor.Rsqrt(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.RsqrtF32x4(a);
end;

function TF32x4Accessor.CmpEq(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpEqF32x4(a, b);
end;

function TF32x4Accessor.CmpLt(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpLtF32x4(a, b);
end;

function TF32x4Accessor.CmpLe(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpLeF32x4(a, b);
end;

function TF32x4Accessor.CmpGt(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpGtF32x4(a, b);
end;

function TF32x4Accessor.CmpGe(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpGeF32x4(a, b);
end;

function TF32x4Accessor.CmpNe(const a, b: TVecF32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpNeF32x4(a, b);
end;

function TF32x4Accessor.Dot4(const a, b: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.DotF32x4(a, b);
end;

function TF32x4Accessor.Dot3(const a, b: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.DotF32x3(a, b);
end;

function TF32x4Accessor.Cross3(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.CrossF32x3(a, b);
end;

function TF32x4Accessor.Length4(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.LengthF32x4(a);
end;

function TF32x4Accessor.Length3(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.LengthF32x3(a);
end;

function TF32x4Accessor.Normalize4(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.NormalizeF32x4(a);
end;

function TF32x4Accessor.Normalize3(const a: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.NormalizeF32x3(a);
end;

function TF32x4Accessor.ReduceAdd(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.ReduceAddF32x4(a);
end;

function TF32x4Accessor.ReduceMin(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.ReduceMinF32x4(a);
end;

function TF32x4Accessor.ReduceMax(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.ReduceMaxF32x4(a);
end;

function TF32x4Accessor.ReduceMul(const a: TVecF32x4): Single; inline;
begin
  Result := FTable^.CoreVectors.ReduceMulF32x4(a);
end;

function TF32x4Accessor.Load(p: PSingle): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.LoadF32x4(p);
end;

function TF32x4Accessor.LoadAligned(p: PSingle): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.LoadF32x4Aligned(p);
end;

procedure TF32x4Accessor.Store(p: PSingle; const a: TVecF32x4); inline;
begin
  FTable^.CoreVectors.StoreF32x4(p, a);
end;

procedure TF32x4Accessor.StoreAligned(p: PSingle; const a: TVecF32x4); inline;
begin
  FTable^.CoreVectors.StoreF32x4Aligned(p, a);
end;

function TF32x4Accessor.Splat(value: Single): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.SplatF32x4(value);
end;

function TF32x4Accessor.Zero: TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.ZeroF32x4();
end;

function TF32x4Accessor.Make(x, y, z, w: Single): TVecF32x4; inline;
begin
  // Create vector from individual components using Insert
  Result := FTable^.CoreVectors.ZeroF32x4();
  Result := FTable^.CoreVectors.InsertF32x4(Result, x, 0);
  Result := FTable^.CoreVectors.InsertF32x4(Result, y, 1);
  Result := FTable^.CoreVectors.InsertF32x4(Result, z, 2);
  Result := FTable^.CoreVectors.InsertF32x4(Result, w, 3);
end;

function TF32x4Accessor.Select(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.SelectF32x4(mask, a, b);
end;

function TF32x4Accessor.Extract(const a: TVecF32x4; index: Integer): Single; inline;
begin
  Result := FTable^.CoreVectors.ExtractF32x4(a, index);
end;

function TF32x4Accessor.Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4; inline;
begin
  Result := FTable^.CoreVectors.InsertF32x4(a, value, index);
end;

// --- TF64x2Accessor ---

constructor TF64x2Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TF64x2Accessor.Add(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.AddF64x2(a, b);
end;

function TF64x2Accessor.Sub(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.SubF64x2(a, b);
end;

function TF64x2Accessor.Mul(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.MulF64x2(a, b);
end;

function TF64x2Accessor.Divide(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.DivF64x2(a, b);
end;

function TF64x2Accessor.Neg(const a: TVecF64x2): TVecF64x2; inline;
begin
  // Negate by subtracting from zero
  Result := FTable^.CoreVectors.SubF64x2(FTable^.CoreVectors.ZeroF64x2(), a);
end;

function TF64x2Accessor.Abs(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.AbsF64x2(a);
end;

function TF64x2Accessor.Sqrt(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.SqrtF64x2(a);
end;

function TF64x2Accessor.Min(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.MinF64x2(a, b);
end;

function TF64x2Accessor.Max(const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.MaxF64x2(a, b);
end;

function TF64x2Accessor.Clamp(const a, minVal, maxVal: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.ClampF64x2(a, minVal, maxVal);
end;

function TF64x2Accessor.Fma(const a, b, c: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.FmaF64x2(a, b, c);
end;

function TF64x2Accessor.Floor(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.FloorF64x2(a);
end;

function TF64x2Accessor.Ceil(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.CeilF64x2(a);
end;

function TF64x2Accessor.Round(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.RoundF64x2(a);
end;

function TF64x2Accessor.Trunc(const a: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.TruncF64x2(a);
end;

function TF64x2Accessor.CmpEq(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CoreVectors.CmpEqF64x2(a, b);
end;

function TF64x2Accessor.CmpLt(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CoreVectors.CmpLtF64x2(a, b);
end;

function TF64x2Accessor.CmpLe(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CoreVectors.CmpLeF64x2(a, b);
end;

function TF64x2Accessor.CmpGt(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CoreVectors.CmpGtF64x2(a, b);
end;

function TF64x2Accessor.CmpGe(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CoreVectors.CmpGeF64x2(a, b);
end;

function TF64x2Accessor.CmpNe(const a, b: TVecF64x2): TMask2; inline;
begin
  Result := FTable^.CoreVectors.CmpNeF64x2(a, b);
end;

function TF64x2Accessor.Dot(const a, b: TVecF64x2): Double; inline;
begin
  Result := FTable^.CoreVectors.DotF64x2(a, b);
end;

function TF64x2Accessor.ReduceAdd(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.CoreVectors.ReduceAddF64x2(a);
end;

function TF64x2Accessor.ReduceMin(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.CoreVectors.ReduceMinF64x2(a);
end;

function TF64x2Accessor.ReduceMax(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.CoreVectors.ReduceMaxF64x2(a);
end;

function TF64x2Accessor.ReduceMul(const a: TVecF64x2): Double; inline;
begin
  Result := FTable^.CoreVectors.ReduceMulF64x2(a);
end;

function TF64x2Accessor.Load(p: PDouble): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.LoadF64x2(p);
end;

function TF64x2Accessor.LoadAligned(p: PDouble): TVecF64x2; inline;
begin
  // F64x2 doesn't have aligned load in dispatch table, use regular load
  Result := FTable^.CoreVectors.LoadF64x2(p);
end;

procedure TF64x2Accessor.Store(p: PDouble; const a: TVecF64x2); inline;
begin
  FTable^.CoreVectors.StoreF64x2(p, a);
end;

procedure TF64x2Accessor.StoreAligned(p: PDouble; const a: TVecF64x2); inline;
begin
  // F64x2 doesn't have aligned store in dispatch table, use regular store
  FTable^.CoreVectors.StoreF64x2(p, a);
end;

function TF64x2Accessor.Splat(value: Double): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.SplatF64x2(value);
end;

function TF64x2Accessor.Zero: TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.ZeroF64x2();
end;

function TF64x2Accessor.Make(x, y: Double): TVecF64x2; inline;
begin
  // Create vector from individual components using Insert
  Result := FTable^.CoreVectors.ZeroF64x2();
  Result := FTable^.CoreVectors.InsertF64x2(Result, x, 0);
  Result := FTable^.CoreVectors.InsertF64x2(Result, y, 1);
end;

function TF64x2Accessor.Select(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.SelectF64x2(mask, a, b);
end;

function TF64x2Accessor.Extract(const a: TVecF64x2; index: Integer): Double; inline;
begin
  Result := FTable^.CoreVectors.ExtractF64x2(a, index);
end;

function TF64x2Accessor.Insert(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2; inline;
begin
  Result := FTable^.CoreVectors.InsertF64x2(a, value, index);
end;

// --- TMemoryAccessor ---

constructor TMemoryAccessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TMemoryAccessor.Equal(a, b: Pointer; len: SizeUInt): LongBool; inline;
begin
  Result := FTable^.Memory.Equal(a, b, len);
end;

function TMemoryAccessor.FindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt; inline;
begin
  Result := FTable^.Memory.FindByte(p, len, value);
end;

function TMemoryAccessor.DiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; inline;
begin
  Result := FTable^.Memory.DiffRange(a, b, len, firstDiff, lastDiff);
end;

procedure TMemoryAccessor.Copy(src, dst: Pointer; len: SizeUInt); inline;
begin
  FTable^.Memory.Copy(src, dst, len);
end;

procedure TMemoryAccessor.Fill(dst: Pointer; len: SizeUInt; value: Byte); inline;
begin
  FTable^.Memory.Fill(dst, len, value);
end;

procedure TMemoryAccessor.Reverse(p: Pointer; len: SizeUInt); inline;
begin
  FTable^.Memory.Reverse(p, len);
end;

function TMemoryAccessor.SumBytes(p: Pointer; len: SizeUInt): UInt64; inline;
begin
  Result := FTable^.Memory.SumBytes(p, len);
end;

procedure TMemoryAccessor.MinMaxBytes(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); inline;
begin
  FTable^.Memory.MinMaxBytes(p, len, minVal, maxVal);
end;

function TMemoryAccessor.CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; inline;
begin
  Result := FTable^.Memory.CountByte(p, len, value);
end;

function TMemoryAccessor.Utf8Validate(p: Pointer; len: SizeUInt): Boolean; inline;
begin
  Result := FTable^.Memory.Utf8Validate(p, len);
end;

function TMemoryAccessor.AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean; inline;
begin
  Result := FTable^.Memory.AsciiIEqual(a, b, len);
end;

procedure TMemoryAccessor.ToLowerAscii(p: Pointer; len: SizeUInt); inline;
begin
  FTable^.Memory.ToLowerAscii(p, len);
end;

procedure TMemoryAccessor.ToUpperAscii(p: Pointer; len: SizeUInt); inline;
begin
  FTable^.Memory.ToUpperAscii(p, len);
end;

function TMemoryAccessor.BytesIndexOf(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; inline;
begin
  Result := FTable^.Memory.BytesIndexOf(haystack, haystackLen, needle, needleLen);
end;

function TMemoryAccessor.BitsetPopCount(p: Pointer; len: SizeUInt): SizeUInt; inline;
begin
  Result := FTable^.Memory.BitsetPopCount(p, len);
end;

// --- TBatchF32Accessor ---

constructor TBatchF32Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

procedure TBatchF32Accessor.ArrayAdd(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayAdd(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySub(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArraySub(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayMul(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayMul(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayDiv(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayDiv(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayMin(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayMin(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayMax(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayMax(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAbs(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayAbs(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayNeg(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayNeg(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySqrt(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArraySqrt(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRcp(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayRcp(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRsqrt(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayRsqrt(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRcpRefine(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayRcpRefine(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRsqrtRefine(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayRsqrtRefine(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAddScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
begin
  FTable^.BatchF32.ArrayAddScalar(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF32Accessor.ArrayMulScalar(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
begin
  FTable^.BatchF32.ArrayMulScalar(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF32Accessor.ArrayClamp(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single); inline;
begin
  FTable^.BatchF32.ArrayClamp(aSrc, aDst, aCount, aMin, aMax);
end;

procedure TBatchF32Accessor.ArrayFma(aA, aB, aC, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayFma(aA, aB, aC, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAxpy(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayAxpy(aAlpha, aX, aY, aDst, aCount);
end;

function TBatchF32Accessor.ReduceSum(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.BatchF32.ReduceSum(aSrc, aCount);
end;

function TBatchF32Accessor.ReduceDot(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.BatchF32.ReduceDot(aSrc1, aSrc2, aCount);
end;

function TBatchF32Accessor.ReduceMin(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.BatchF32.ReduceMin(aSrc, aCount);
end;

function TBatchF32Accessor.ReduceMax(aSrc: PSingle; aCount: SizeUInt): Single; inline;
begin
  Result := FTable^.BatchF32.ReduceMax(aSrc, aCount);
end;

procedure TBatchF32Accessor.ArrayExp(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayExp(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLog(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayLog(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayPow(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single); inline;
begin
  FTable^.BatchF32.ArrayPow(aSrc, aDst, aCount, aExponent);
end;

procedure TBatchF32Accessor.ArraySin(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArraySin(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayCos(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayCos(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayTan(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayTan(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySinCos(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArraySinCos(aSrc, aSinDst, aCosDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLog2(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayLog2(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLog10(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayLog10(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayAtan2(aY, aX, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayAtan2(aY, aX, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayHypot(aX, aY, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayHypot(aX, aY, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayCeil(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayCeil(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayFloor(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayFloor(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayRound(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayRound(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayTrunc(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayTrunc(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayFract(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayFract(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLerp(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single); inline;
begin
  FTable^.BatchF32.ArrayLerp(aStart, aEnd, aDst, aCount, aT);
end;

procedure TBatchF32Accessor.ArrayMod(aSrc, aDst: PSingle; aCount: SizeUInt; aDivisor: Single); inline;
begin
  FTable^.BatchF32.ArrayMod(aSrc, aDst, aCount, aDivisor);
end;

procedure TBatchF32Accessor.ArraySign(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArraySign(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayStep(aEdge, aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayStep(aEdge, aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayLinear(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;
begin
  FTable^.BatchF32.ArrayLinear(aSrc, aDst, aCount, aScale, aBias);
end;

procedure TBatchF32Accessor.ArrayAbsDiff(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayAbsDiff(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayReLU(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchF32.ArrayReLU(aSrc, aDst, aCount);
end;

procedure TBatchF32Accessor.ArrayNorm(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single); inline;
begin
  FTable^.BatchF32.ArrayNorm(aSrc, aDst, aCount, aMean, aInvStd);
end;

procedure TBatchF32Accessor.ArrayLinearReLU(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;
begin
  FTable^.BatchF32.ArrayLinearReLU(aSrc, aDst, aCount, aScale, aBias);
end;

// --- TBatchF64Accessor ---

constructor TBatchF64Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

procedure TBatchF64Accessor.ArrayAdd(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayAdd(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySub(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArraySub(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMul(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayMul(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayDiv(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayDiv(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMin(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayMin(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMax(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayMax(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAbs(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayAbs(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayNeg(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayNeg(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySqrt(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArraySqrt(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayRcp(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayRcp(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayRsqrt(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayRsqrt(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayRcpRefine(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayRcpRefine(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayRsqrtRefine(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayRsqrtRefine(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMulScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
begin
  FTable^.BatchF64.ArrayMulScalar(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF64Accessor.ArrayAddScalar(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
begin
  FTable^.BatchF64.ArrayAddScalar(aSrc, aDst, aCount, aScalar);
end;

procedure TBatchF64Accessor.ArrayClamp(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double); inline;
begin
  FTable^.BatchF64.ArrayClamp(aSrc, aDst, aCount, aMin, aMax);
end;

procedure TBatchF64Accessor.ArrayLinear(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); inline;
begin
  FTable^.BatchF64.ArrayLinear(aSrc, aDst, aCount, aScale, aBias);
end;

procedure TBatchF64Accessor.ArrayFma(aA, aB, aC, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayFma(aA, aB, aC, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAxpy(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayAxpy(aAlpha, aX, aY, aDst, aCount);
end;

function TBatchF64Accessor.ReduceSum(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.BatchF64.ReduceSum(aSrc, aCount);
end;

function TBatchF64Accessor.ReduceDot(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.BatchF64.ReduceDot(aSrc1, aSrc2, aCount);
end;

function TBatchF64Accessor.ReduceMin(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.BatchF64.ReduceMin(aSrc, aCount);
end;

function TBatchF64Accessor.ReduceMax(aSrc: PDouble; aCount: SizeUInt): Double; inline;
begin
  Result := FTable^.BatchF64.ReduceMax(aSrc, aCount);
end;

procedure TBatchF64Accessor.ArraySin(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArraySin(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayCos(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayCos(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySinCos(aSrc, aSinDst, aCosDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArraySinCos(aSrc, aSinDst, aCosDst, aCount);
end;

procedure TBatchF64Accessor.ArrayExp(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayExp(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayLog(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayLog(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayLog2(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayLog2(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayLog10(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayLog10(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayCeil(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayCeil(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayFloor(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayFloor(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayRound(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayRound(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayTrunc(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayTrunc(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayTan(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayTan(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySign(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArraySign(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayFract(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayFract(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayMod(aSrc, aDst: PDouble; aCount: SizeUInt; aDivisor: Double); inline;
begin
  FTable^.BatchF64.ArrayMod(aSrc, aDst, aCount, aDivisor);
end;

procedure TBatchF64Accessor.ArrayPow(aSrc, aDst: PDouble; aCount: SizeUInt; aExponent: Double); inline;
begin
  FTable^.BatchF64.ArrayPow(aSrc, aDst, aCount, aExponent);
end;

procedure TBatchF64Accessor.ArrayLerp(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double); inline;
begin
  FTable^.BatchF64.ArrayLerp(aStart, aEnd, aDst, aCount, aT);
end;

procedure TBatchF64Accessor.ArrayReLU(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayReLU(aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAbsDiff(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayAbsDiff(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayNorm(aSrc, aDst: PDouble; aCount: SizeUInt; aMean, aInvStd: Double); inline;
begin
  FTable^.BatchF64.ArrayNorm(aSrc, aDst, aCount, aMean, aInvStd);
end;

procedure TBatchF64Accessor.ArrayLinearReLU(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); inline;
begin
  FTable^.BatchF64.ArrayLinearReLU(aSrc, aDst, aCount, aScale, aBias);
end;

procedure TBatchF64Accessor.ArrayStep(aEdge, aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayStep(aEdge, aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArraySmoothstep(aEdge0, aEdge1, aSrc, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayAtan2(aY, aX, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayAtan2(aY, aX, aDst, aCount);
end;

procedure TBatchF64Accessor.ArrayHypot(aX, aY, aDst: PDouble; aCount: SizeUInt); inline;
begin
  FTable^.BatchF64.ArrayHypot(aX, aY, aDst, aCount);
end;

// --- TI32x4Accessor ---

constructor TI32x4Accessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TI32x4Accessor.Add(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.AddI32x4(a, b);
end;

function TI32x4Accessor.Sub(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.SubI32x4(a, b);
end;

function TI32x4Accessor.Mul(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.MulI32x4(a, b);
end;

function TI32x4Accessor.Neg(const a: TVecI32x4): TVecI32x4; inline;
var
  LZero: TVecI32x4;
begin
  // Negate by subtracting from zero
  LZero.i[0] := 0;
  LZero.i[1] := 0;
  LZero.i[2] := 0;
  LZero.i[3] := 0;
  Result := FTable^.CoreVectors.SubI32x4(LZero, a);
end;

function TI32x4Accessor.BitAnd(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.AndI32x4(a, b);
end;

function TI32x4Accessor.BitOr(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.OrI32x4(a, b);
end;

function TI32x4Accessor.BitXor(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.XorI32x4(a, b);
end;

function TI32x4Accessor.BitNot(const a: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.NotI32x4(a);
end;

function TI32x4Accessor.BitAndNot(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.AndNotI32x4(a, b);
end;

function TI32x4Accessor.ShiftLeft(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.ShiftLeftI32x4(a, count);
end;

function TI32x4Accessor.ShiftRight(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.ShiftRightI32x4(a, count);
end;

function TI32x4Accessor.ShiftRightArith(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.ShiftRightArithI32x4(a, count);
end;

function TI32x4Accessor.CmpEq(const a, b: TVecI32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpEqI32x4(a, b);
end;

function TI32x4Accessor.CmpLt(const a, b: TVecI32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpLtI32x4(a, b);
end;

function TI32x4Accessor.CmpGt(const a, b: TVecI32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpGtI32x4(a, b);
end;

function TI32x4Accessor.CmpLe(const a, b: TVecI32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpLeI32x4(a, b);
end;

function TI32x4Accessor.CmpGe(const a, b: TVecI32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpGeI32x4(a, b);
end;

function TI32x4Accessor.CmpNe(const a, b: TVecI32x4): TMask4; inline;
begin
  Result := FTable^.CoreVectors.CmpNeI32x4(a, b);
end;

function TI32x4Accessor.Min(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.MinI32x4(a, b);
end;

function TI32x4Accessor.Max(const a, b: TVecI32x4): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.MaxI32x4(a, b);
end;

function TI32x4Accessor.Load(p: PInt32): TVecI32x4; inline;
begin
  // Not available in dispatch table, use Insert as workaround
  Result.i[0] := p[0];
  Result.i[1] := p[1];
  Result.i[2] := p[2];
  Result.i[3] := p[3];
end;

function TI32x4Accessor.LoadAligned(p: PInt32): TVecI32x4; inline;
begin
  // Not available in dispatch table, use Insert as workaround
  Result.i[0] := p[0];
  Result.i[1] := p[1];
  Result.i[2] := p[2];
  Result.i[3] := p[3];
end;

procedure TI32x4Accessor.Store(p: PInt32; const a: TVecI32x4); inline;
begin
  // Not available in dispatch table, use Extract as workaround
  p[0] := FTable^.CoreVectors.ExtractI32x4(a, 0);
  p[1] := FTable^.CoreVectors.ExtractI32x4(a, 1);
  p[2] := FTable^.CoreVectors.ExtractI32x4(a, 2);
  p[3] := FTable^.CoreVectors.ExtractI32x4(a, 3);
end;

procedure TI32x4Accessor.StoreAligned(p: PInt32; const a: TVecI32x4); inline;
begin
  // Not available in dispatch table, use Extract as workaround
  p[0] := FTable^.CoreVectors.ExtractI32x4(a, 0);
  p[1] := FTable^.CoreVectors.ExtractI32x4(a, 1);
  p[2] := FTable^.CoreVectors.ExtractI32x4(a, 2);
  p[3] := FTable^.CoreVectors.ExtractI32x4(a, 3);
end;

function TI32x4Accessor.Splat(value: Int32): TVecI32x4; inline;
begin
  // Not available in dispatch table, use Insert as workaround
  Result.i[0] := value;
  Result.i[1] := value;
  Result.i[2] := value;
  Result.i[3] := value;
end;

function TI32x4Accessor.Zero: TVecI32x4; inline;
begin
  // Not available in dispatch table, use direct assignment
  Result.i[0] := 0;
  Result.i[1] := 0;
  Result.i[2] := 0;
  Result.i[3] := 0;
end;

function TI32x4Accessor.Make(x, y, z, w: Int32): TVecI32x4; inline;
begin
  // Not available in dispatch table, use direct assignment
  Result.i[0] := x;
  Result.i[1] := y;
  Result.i[2] := z;
  Result.i[3] := w;
end;

function TI32x4Accessor.Select(const mask: TMask4; const a, b: TVecI32x4): TVecI32x4; inline;
begin
  // Dispatch table uses TVecI32x4 as mask, but accessor uses TMask4
  // For now, use a simple approach: if mask bit is set, return a, else b
  Result := b; // Default to b
  if (mask and 1) <> 0 then
    Result.i[0] := a.i[0];
  if (mask and 2) <> 0 then
    Result.i[1] := a.i[1];
  if (mask and 4) <> 0 then
    Result.i[2] := a.i[2];
  if (mask and 8) <> 0 then
    Result.i[3] := a.i[3];
end;

function TI32x4Accessor.Extract(const a: TVecI32x4; index: Integer): Int32; inline;
begin
  Result := FTable^.CoreVectors.ExtractI32x4(a, index);
end;

function TI32x4Accessor.Insert(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4; inline;
begin
  Result := FTable^.CoreVectors.InsertI32x4(a, value, index);
end;

// --- TMaskAccessor ---

constructor TMaskAccessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

function TMaskAccessor.Mask2All(mask: TMask2): Boolean; inline;
begin
  Result := FTable^.Mask.Mask2All(mask);
end;

function TMaskAccessor.Mask2Any(mask: TMask2): Boolean; inline;
begin
  Result := FTable^.Mask.Mask2Any(mask);
end;

function TMaskAccessor.Mask2None(mask: TMask2): Boolean; inline;
begin
  Result := FTable^.Mask.Mask2None(mask);
end;

function TMaskAccessor.Mask2PopCount(mask: TMask2): Integer; inline;
begin
  Result := FTable^.Mask.Mask2PopCount(mask);
end;

function TMaskAccessor.Mask2FirstSet(mask: TMask2): Integer; inline;
begin
  Result := FTable^.Mask.Mask2FirstSet(mask);
end;

function TMaskAccessor.Mask4All(mask: TMask4): Boolean; inline;
begin
  Result := FTable^.Mask.Mask4All(mask);
end;

function TMaskAccessor.Mask4Any(mask: TMask4): Boolean; inline;
begin
  Result := FTable^.Mask.Mask4Any(mask);
end;

function TMaskAccessor.Mask4None(mask: TMask4): Boolean; inline;
begin
  Result := FTable^.Mask.Mask4None(mask);
end;

function TMaskAccessor.Mask4PopCount(mask: TMask4): Integer; inline;
begin
  Result := FTable^.Mask.Mask4PopCount(mask);
end;

function TMaskAccessor.Mask4FirstSet(mask: TMask4): Integer; inline;
begin
  Result := FTable^.Mask.Mask4FirstSet(mask);
end;

function TMaskAccessor.Mask8All(mask: TMask8): Boolean; inline;
begin
  Result := FTable^.Mask.Mask8All(mask);
end;

function TMaskAccessor.Mask8Any(mask: TMask8): Boolean; inline;
begin
  Result := FTable^.Mask.Mask8Any(mask);
end;

function TMaskAccessor.Mask8None(mask: TMask8): Boolean; inline;
begin
  Result := FTable^.Mask.Mask8None(mask);
end;

function TMaskAccessor.Mask8PopCount(mask: TMask8): Integer; inline;
begin
  Result := FTable^.Mask.Mask8PopCount(mask);
end;

function TMaskAccessor.Mask8FirstSet(mask: TMask8): Integer; inline;
begin
  Result := FTable^.Mask.Mask8FirstSet(mask);
end;

function TMaskAccessor.Mask16All(mask: TMask16): Boolean; inline;
begin
  Result := FTable^.Mask.Mask16All(mask);
end;

function TMaskAccessor.Mask16Any(mask: TMask16): Boolean; inline;
begin
  Result := FTable^.Mask.Mask16Any(mask);
end;

function TMaskAccessor.Mask16None(mask: TMask16): Boolean; inline;
begin
  Result := FTable^.Mask.Mask16None(mask);
end;

function TMaskAccessor.Mask16PopCount(mask: TMask16): Integer; inline;
begin
  Result := FTable^.Mask.Mask16PopCount(mask);
end;

function TMaskAccessor.Mask16FirstSet(mask: TMask16): Integer; inline;
begin
  Result := FTable^.Mask.Mask16FirstSet(mask);
end;

// --- TBatchIntegerAccessor ---

constructor TBatchIntegerAccessor.Create(aTable: PSimdDispatchTable);
begin
  FTable := aTable;
end;

procedure TBatchIntegerAccessor.ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer); inline;
begin
  FTable^.BatchInteger.ArrayShlI32(aSrc, aDst, aCount, aShift);
end;

procedure TBatchIntegerAccessor.ArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer); inline;
begin
  FTable^.BatchInteger.ArrayShrI32(aSrc, aDst, aCount, aShift);
end;

procedure TBatchIntegerAccessor.ArrayAddI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddI16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubI16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayMulI16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndI16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrI16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorI16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayPackSatI32toI16(aSrc, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAddI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddI8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubI8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayMulI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayMulI8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndI8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrI8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorI8(aSrc1, aSrc2, aDst: PInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorI8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAddU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayMulU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayMulU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorU32(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAddU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddU16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubU16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayMulU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayMulU16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndU16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrU16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorU16(aSrc1, aSrc2, aDst: PUInt16; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorU16(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAddU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddU8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubU8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayMulU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayMulU8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndU8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrU8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorU8(aSrc1, aSrc2, aDst: PUInt8; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorU8(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAddI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddI64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubI64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayMulI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayMulI64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndI64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrI64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorI64(aSrc1, aSrc2, aDst: PInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorI64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAddU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAddU64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArraySubU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArraySubU64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayMulU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayMulU64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayAndU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayAndU64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayOrU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayOrU64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayXorU64(aSrc1, aSrc2, aDst: PUInt64; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayXorU64(aSrc1, aSrc2, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayF32toI32(aSrc, aDst, aCount);
end;

procedure TBatchIntegerAccessor.ArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt); inline;
begin
  FTable^.BatchInteger.ArrayI32toF32(aSrc, aDst, aCount);
end;

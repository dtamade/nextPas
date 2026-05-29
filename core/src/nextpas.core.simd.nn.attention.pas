unit nextpas.core.simd.nn.attention;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

// Scaled dot-product attention: Output = softmax(Q*K^T / sqrt(d)) * V
// Q: [SeqLen, HeadDim], K: [SeqLen, HeadDim], V: [SeqLen, HeadDim]
// Output: [SeqLen, HeadDim]
procedure ScaledDotProductAttentionF32(
  AQ, AK, AV, AOutput: PSingle;
  ASeqLen, AHeadDim: SizeUInt);

// Multi-head attention wrapper
// Q,K,V: [SeqLen, NumHeads * HeadDim], Output: same shape
procedure MultiHeadAttentionF32(
  AQ, AK, AV, AOutput: PSingle;
  ASeqLen, ANumHeads, AHeadDim: SizeUInt);

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.mathutil,
  nextpas.core.simd.linalg.gemm;

procedure ScaledDotProductAttentionF32(
  AQ, AK, AV, AOutput: PSingle;
  ASeqLen, AHeadDim: SizeUInt);
var
  LScores: PSingle;
  LScale: Single;
  LI, LJ: SizeUInt;
  LMax, LSum, LVal: Single;
begin
  if (ASeqLen = 0) or (AHeadDim = 0) then Exit;

  LScale := 1.0 / System.Sqrt(Single(AHeadDim));

  // Scores = Q * K^T [SeqLen, SeqLen]
  LScores := PSingle(SimdAlloc(ASeqLen * ASeqLen * SizeOf(Single)));
  GemmBlockedTransBF32(AQ, AK, LScores, ASeqLen, ASeqLen, AHeadDim,
    AHeadDim, AHeadDim, ASeqLen);

  // Scale
  ArrayMulScalarF32(LScores, LScores, ASeqLen * ASeqLen, LScale);

  // Row-wise softmax
  for LI := 0 to ASeqLen - 1 do
  begin
    // Find max for numerical stability
    LMax := LScores[LI * ASeqLen];
    for LJ := 1 to ASeqLen - 1 do
      if LScores[LI * ASeqLen + LJ] > LMax then
        LMax := LScores[LI * ASeqLen + LJ];

    // Exp and sum
    LSum := 0;
    for LJ := 0 to ASeqLen - 1 do
    begin
      LVal := System.Exp(LScores[LI * ASeqLen + LJ] - LMax);
      LScores[LI * ASeqLen + LJ] := LVal;
      LSum := LSum + LVal;
    end;

    // Normalize
    if LSum > 0 then
      ArrayMulScalarF32(@LScores[LI * ASeqLen], @LScores[LI * ASeqLen], ASeqLen, 1.0 / LSum);
  end;

  // Output = Scores * V [SeqLen, HeadDim]
  FillChar(AOutput^, ASeqLen * AHeadDim * SizeOf(Single), 0);
  GemmBlockedF32(LScores, AV, AOutput, ASeqLen, AHeadDim, ASeqLen,
    ASeqLen, AHeadDim, AHeadDim);

  SimdFree(LScores);
end;

procedure MultiHeadAttentionF32(
  AQ, AK, AV, AOutput: PSingle;
  ASeqLen, ANumHeads, AHeadDim: SizeUInt);
var
  LH: SizeUInt;
  LStride: SizeUInt;
begin
  LStride := ANumHeads * AHeadDim;
  for LH := 0 to ANumHeads - 1 do
    ScaledDotProductAttentionF32(
      @AQ[LH * AHeadDim], @AK[LH * AHeadDim], @AV[LH * AHeadDim],
      @AOutput[LH * AHeadDim],
      ASeqLen, AHeadDim);
end;

end.

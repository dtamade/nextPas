program test_cnn_inference;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.nn;

var
  LPass, LFail: Integer;

procedure Check(const aName: string; aCondition: Boolean);
begin
  if aCondition then Inc(LPass)
  else begin WriteLn('  FAIL ', aName); Inc(LFail); end;
end;

procedure CheckRange(const aName: string; aVal, aMin, aMax: Single);
begin
  if (aVal >= aMin) and (aVal <= aMax) then Inc(LPass)
  else begin WriteLn('  FAIL ', aName, ': ', aVal:0:6, ' not in [', aMin:0:2, ',', aMax:0:2, ']'); Inc(LFail); end;
end;

var
  LInput: PSingle;
  LConv1Out, LBN1Out, LPool1Out: PSingle;
  LConv2Out, LBN2Out, LPool2Out: PSingle;
  LFlatOut, LFCOut, LSoftOut: PSingle;
  LConv1W, LConv1B: PSingle;
  LConv2W, LConv2B: PSingle;
  LBN1G, LBN1B, LBN1M, LBN1V: PSingle;
  LBN2G, LBN2B, LBN2M, LBN2V: PSingle;
  LFCWeight, LFCBias: PSingle;
  i: Integer;
  LSum: Single;

const
  IN_C = 1; IN_H = 8; IN_W = 8;
  C1_F = 4; C1_KH = 3; C1_KW = 3;
  C1_OH = 6; C1_OW = 6;
  P1_OH = 3; P1_OW = 3;
  C2_F = 8; C2_KH = 3; C2_KW = 3;
  C2_OH = 1; C2_OW = 1;
  NUM_CLASSES = 3;

begin
  LPass := 0;
  LFail := 0;

  // Allocate all buffers
  LInput := PSingle(SimdAlloc(IN_C * IN_H * IN_W * SizeOf(Single)));
  LConv1Out := PSingle(SimdAlloc(C1_F * C1_OH * C1_OW * SizeOf(Single)));
  LBN1Out := PSingle(SimdAlloc(C1_F * C1_OH * C1_OW * SizeOf(Single)));
  LPool1Out := PSingle(SimdAlloc(C1_F * P1_OH * P1_OW * SizeOf(Single)));
  LConv2Out := PSingle(SimdAlloc(C2_F * C2_OH * C2_OW * SizeOf(Single)));
  LBN2Out := PSingle(SimdAlloc(C2_F * C2_OH * C2_OW * SizeOf(Single)));
  LPool2Out := PSingle(SimdAlloc(C2_F * SizeOf(Single)));
  LFCOut := PSingle(SimdAlloc(NUM_CLASSES * SizeOf(Single)));
  LSoftOut := PSingle(SimdAlloc(NUM_CLASSES * SizeOf(Single)));

  // Weights (initialized to small values for stability)
  LConv1W := PSingle(SimdAlloc(C1_F * IN_C * C1_KH * C1_KW * SizeOf(Single)));
  LConv1B := PSingle(SimdAlloc(C1_F * SizeOf(Single)));
  LConv2W := PSingle(SimdAlloc(C2_F * C1_F * C2_KH * C2_KW * SizeOf(Single)));
  LConv2B := PSingle(SimdAlloc(C2_F * SizeOf(Single)));
  LBN1G := PSingle(SimdAlloc(C1_F * SizeOf(Single)));
  LBN1B := PSingle(SimdAlloc(C1_F * SizeOf(Single)));
  LBN1M := PSingle(SimdAlloc(C1_F * SizeOf(Single)));
  LBN1V := PSingle(SimdAlloc(C1_F * SizeOf(Single)));
  LBN2G := PSingle(SimdAlloc(C2_F * SizeOf(Single)));
  LBN2B := PSingle(SimdAlloc(C2_F * SizeOf(Single)));
  LBN2M := PSingle(SimdAlloc(C2_F * SizeOf(Single)));
  LBN2V := PSingle(SimdAlloc(C2_F * SizeOf(Single)));
  LFCWeight := PSingle(SimdAlloc(NUM_CLASSES * C2_F * SizeOf(Single)));
  LFCBias := PSingle(SimdAlloc(NUM_CLASSES * SizeOf(Single)));

  // Initialize input: simple gradient pattern
  for i := 0 to IN_H * IN_W - 1 do
    LInput[i] := (i + 1) / (IN_H * IN_W);

  // Initialize weights (small uniform values)
  for i := 0 to C1_F * IN_C * C1_KH * C1_KW - 1 do
    LConv1W[i] := 0.1;
  for i := 0 to C1_F - 1 do LConv1B[i] := 0.01;

  for i := 0 to C2_F * C1_F * C2_KH * C2_KW - 1 do
    LConv2W[i] := 0.05;
  for i := 0 to C2_F - 1 do LConv2B[i] := 0.01;

  // BN params: identity-like (gamma=1, beta=0, mean=0, var=1)
  for i := 0 to C1_F - 1 do begin LBN1G[i] := 1.0; LBN1B[i] := 0.0; LBN1M[i] := 0.0; LBN1V[i] := 1.0; end;
  for i := 0 to C2_F - 1 do begin LBN2G[i] := 1.0; LBN2B[i] := 0.0; LBN2M[i] := 0.0; LBN2V[i] := 1.0; end;

  // FC weights
  for i := 0 to NUM_CLASSES * C2_F - 1 do
    LFCWeight[i] := 0.1;
  for i := 0 to NUM_CLASSES - 1 do LFCBias[i] := 0.0;

  // === Forward pass ===

  // Layer 1: Conv2D (1ch → 4ch, 3x3) + BN + ReLU + MaxPool(2x2, stride 2)
  Conv2DMultiChannelF32(LInput, LConv1W, LConv1B, LConv1Out,
    IN_C, IN_H, IN_W, C1_KH, C1_KW, C1_F);
  Check('Conv1 output non-zero', LConv1Out[0] <> 0);

  BatchNorm2DInferF32(LConv1Out, LBN1Out, C1_F, C1_OH, C1_OW,
    LBN1G, LBN1B, LBN1M, LBN1V, 1e-5);
  Check('BN1 output matches conv1', System.Abs(LBN1Out[0] - LConv1Out[0]) < 0.01);

  ArrayReLUF32(LBN1Out, LBN1Out, C1_F * C1_OH * C1_OW);
  Check('ReLU1 non-negative', LBN1Out[0] >= 0);

  // MaxPool each channel: 6x6 → 3x3 with kernel 2x2, stride 2
  for i := 0 to C1_F - 1 do
    MaxPool2DF32(@LBN1Out[i * C1_OH * C1_OW], @LPool1Out[i * P1_OH * P1_OW],
      C1_OH, C1_OW, 2, 2, 2, 2);
  Check('Pool1 output valid', LPool1Out[0] > 0);

  // Layer 2: Conv2D (4ch → 8ch, 3x3) + BN + ReLU
  Conv2DMultiChannelF32(LPool1Out, LConv2W, LConv2B, LConv2Out,
    C1_F, P1_OH, P1_OW, C2_KH, C2_KW, C2_F);
  Check('Conv2 output non-zero', LConv2Out[0] <> 0);

  BatchNorm2DInferF32(LConv2Out, LBN2Out, C2_F, C2_OH, C2_OW,
    LBN2G, LBN2B, LBN2M, LBN2V, 1e-5);
  ArrayReLUF32(LBN2Out, LBN2Out, C2_F * C2_OH * C2_OW);

  // Global Average Pooling: 8ch × 1×1 → 8-dim vector
  GlobalAvgPool2DF32(LBN2Out, LPool2Out, C2_F, C2_OH, C2_OW);
  Check('GlobalAvgPool output valid', LPool2Out[0] >= 0);

  // FC Layer: 8 → 3 classes
  LinearLayerF32(LPool2Out, LFCWeight, LFCBias, LFCOut, 1, C2_F, NUM_CLASSES);
  Check('FC output non-zero', (LFCOut[0] <> 0) or (LFCOut[1] <> 0) or (LFCOut[2] <> 0));

  // Softmax
  SoftmaxF32(LFCOut, LSoftOut, NUM_CLASSES);

  // Verify softmax properties
  LSum := 0;
  for i := 0 to NUM_CLASSES - 1 do
  begin
    CheckRange('Softmax[' + IntToStr(i) + '] in [0,1]', LSoftOut[i], 0.0, 1.0);
    LSum := LSum + LSoftOut[i];
  end;
  Check('Softmax sums to 1', System.Abs(LSum - 1.0) < 1e-5);

  // With uniform weights, all classes should have similar probabilities
  CheckRange('Softmax balanced', LSoftOut[0], 0.2, 0.5);

  // Free all buffers
  SimdFree(LInput); SimdFree(LConv1Out); SimdFree(LBN1Out); SimdFree(LPool1Out);
  SimdFree(LConv2Out); SimdFree(LBN2Out); SimdFree(LPool2Out);
  SimdFree(LFCOut); SimdFree(LSoftOut);
  SimdFree(LConv1W); SimdFree(LConv1B);
  SimdFree(LConv2W); SimdFree(LConv2B);
  SimdFree(LBN1G); SimdFree(LBN1B); SimdFree(LBN1M); SimdFree(LBN1V);
  SimdFree(LBN2G); SimdFree(LBN2B); SimdFree(LBN2M); SimdFree(LBN2V);
  SimdFree(LFCWeight); SimdFree(LFCBias);

  WriteLn('CNN Inference Integration Test');
  WriteLn('Architecture: Conv(1→4,3x3) → BN → ReLU → MaxPool(2x2) → Conv(4→8,3x3) → BN → ReLU → GlobalAvgPool → FC(8→3) → Softmax');
  WriteLn('Tests run: ', LPass + LFail);
  WriteLn('Passed: ', LPass);
  WriteLn('Failed: ', LFail);
  if LFail = 0 then WriteLn('All tests passed!')
  else Halt(1);
end.

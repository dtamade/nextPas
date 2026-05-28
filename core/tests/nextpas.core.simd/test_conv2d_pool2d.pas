program test_conv2d_pool2d;

{$mode objfpc}{$H+}

uses
  SysUtils, Math,
  nextpas.core.simd.nn;

var
  LPass, LFail: Integer;

procedure Check(const aName: string; aGot, aExpect: Single; aTol: Single = 1e-4);
begin
  if System.Abs(aGot - aExpect) <= aTol then
    Inc(LPass)
  else
  begin
    WriteLn('  FAIL ', aName, ': got=', aGot:0:6, ' expect=', aExpect:0:6);
    Inc(LFail);
  end;
end;

var
  LInput: array[0..255] of Single;   // up to 4ch * 8x8
  LKernel: array[0..80] of Single;   // up to 2 filters * 4ch * 3x3
  LOutput: array[0..8] of Single;    // 3x3 (valid)
  LPoolOut: array[0..3] of Single;   // 2x2
  LBigOut: array[0..127] of Single;  // up to 2 filters * 6x6
  LBias: array[0..2] of Single;
  LMCOut: array[0..17] of Single;    // multi-channel output
  LGamma, LBeta, LMean, LVar: array[0..2] of Single;
  LGlobalOut: array[0..2] of Single;
  LDWOut: array[0..26] of Single;    // 3 channels * 3x3
  LArgOut: array[0..63] of Int32;
  i, j, ky, kx, c: Integer;
  LExpected: Single;

begin
  LPass := 0;
  LFail := 0;

  // Fill 5x5 input: row-major, values 1..25
  for i := 0 to 24 do
    LInput[i] := i + 1.0;

  // Identity-like kernel: all ones (box filter)
  for i := 0 to 8 do
    LKernel[i] := 1.0;

  // Test Conv2DF32: 5x5 input, 3x3 kernel → 3x3 output
  Conv2DF32(@LInput[0], @LKernel[0], @LOutput[0], 5, 5, 3, 3);

  // Verify: output[oy,ox] = sum of 3x3 window starting at (oy,ox)
  for i := 0 to 2 do
    for j := 0 to 2 do
    begin
      LExpected := 0;
      for ky := 0 to 2 do
        for kx := 0 to 2 do
          LExpected := LExpected + LInput[(i + ky) * 5 + (j + kx)];
      Check('Conv2D[' + IntToStr(i) + ',' + IntToStr(j) + ']',
        LOutput[i * 3 + j], LExpected);
    end;

  // Test Conv2DStridedF32: stride=2 → 2x2 output
  FillChar(LOutput, SizeOf(LOutput), 0);
  Conv2DStridedF32(@LInput[0], @LKernel[0], @LOutput[0], 5, 5, 3, 3, 2, 2);
  for i := 0 to 1 do
    for j := 0 to 1 do
    begin
      LExpected := 0;
      for ky := 0 to 2 do
        for kx := 0 to 2 do
          LExpected := LExpected + LInput[(i*2 + ky) * 5 + (j*2 + kx)];
      Check('Conv2DStrided[' + IntToStr(i) + ',' + IntToStr(j) + ']',
        LOutput[i * 2 + j], LExpected);
    end;

  // Test MaxPool2DF32: 4x4 input, 2x2 kernel, stride 2 → 2x2 output
  for i := 0 to 15 do
    LInput[i] := i + 1.0;  // 4x4: 1..16
  MaxPool2DF32(@LInput[0], @LPoolOut[0], 4, 4, 2, 2, 2, 2);
  // Expected: max of each 2x2 block
  Check('MaxPool2D[0,0]', LPoolOut[0], 6.0);   // max(1,2,5,6)
  Check('MaxPool2D[0,1]', LPoolOut[1], 8.0);   // max(3,4,7,8)
  Check('MaxPool2D[1,0]', LPoolOut[2], 14.0);  // max(9,10,13,14)
  Check('MaxPool2D[1,1]', LPoolOut[3], 16.0);  // max(11,12,15,16)

  // Test AvgPool2DF32: 4x4 input, 2x2 kernel, stride 2 → 2x2 output
  AvgPool2DF32(@LInput[0], @LPoolOut[0], 4, 4, 2, 2, 2, 2);
  Check('AvgPool2D[0,0]', LPoolOut[0], (1+2+5+6)/4.0);
  Check('AvgPool2D[0,1]', LPoolOut[1], (3+4+7+8)/4.0);
  Check('AvgPool2D[1,0]', LPoolOut[2], (9+10+13+14)/4.0);
  Check('AvgPool2D[1,1]', LPoolOut[3], (11+12+15+16)/4.0);

  // Test Conv2D with non-uniform kernel
  LKernel[0] := 1; LKernel[1] := 0; LKernel[2] := -1;
  LKernel[3] := 2; LKernel[4] := 0; LKernel[5] := -2;
  LKernel[6] := 1; LKernel[7] := 0; LKernel[8] := -1;
  for i := 0 to 24 do LInput[i] := i + 1.0;
  Conv2DF32(@LInput[0], @LKernel[0], @LOutput[0], 5, 5, 3, 3);
  for i := 0 to 2 do
    for j := 0 to 2 do
    begin
      LExpected := 0;
      for ky := 0 to 2 do
        for kx := 0 to 2 do
          LExpected := LExpected + LInput[(i + ky) * 5 + (j + kx)] * LKernel[ky * 3 + kx];
      Check('Conv2D_Sobel[' + IntToStr(i) + ',' + IntToStr(j) + ']',
        LOutput[i * 3 + j], LExpected);
    end;

  // Edge case: kernel same size as input
  for i := 0 to 8 do LInput[i] := i + 1.0;
  for i := 0 to 8 do LKernel[i] := 1.0;
  Conv2DF32(@LInput[0], @LKernel[0], @LOutput[0], 3, 3, 3, 3);
  LExpected := 0;
  for i := 0 to 8 do LExpected := LExpected + LInput[i];
  Check('Conv2D_FullOverlap', LOutput[0], LExpected);

  // Test Conv2DBiasF32: 5x5 input, 3x3 kernel, 2 filters
  for i := 0 to 24 do LInput[i] := i + 1.0;
  for i := 0 to 17 do LKernel[i] := 1.0;  // 2 filters * 9 weights
  LBias[0] := 10.0;
  LBias[1] := -5.0;
  Conv2DBiasF32(@LInput[0], @LKernel[0], @LBias[0], @LBigOut[0], 5, 5, 3, 3, 2);
  // Filter 0: sum of 3x3 window + bias[0]=10
  LExpected := 0;
  for ky := 0 to 2 do
    for kx := 0 to 2 do
      LExpected := LExpected + LInput[ky * 5 + kx];
  Check('Conv2DBias_F0[0,0]', LBigOut[0], LExpected + 10.0);
  // Filter 1: same sum + bias[1]=-5
  Check('Conv2DBias_F1[0,0]', LBigOut[9], LExpected - 5.0);

  // Test Conv2DBiasReLUF32: negative bias should be clamped to 0
  LBias[0] := -1000.0;
  Conv2DBiasReLUF32(@LInput[0], @LKernel[0], @LBias[0], @LBigOut[0], 5, 5, 3, 3, 1);
  for i := 0 to 8 do
    Check('Conv2DBiasReLU[' + IntToStr(i) + ']', LBigOut[i], 0.0);

  // Test Conv2DBiasReLUF32: positive result passes through
  LBias[0] := 0;
  Conv2DBiasReLUF32(@LInput[0], @LKernel[0], @LBias[0], @LBigOut[0], 5, 5, 3, 3, 1);
  LExpected := 0;
  for ky := 0 to 2 do
    for kx := 0 to 2 do
      LExpected := LExpected + LInput[ky * 5 + kx];
  Check('Conv2DBiasReLU_pos', LBigOut[0], LExpected);

  // Test Conv2DMultiChannelF32: 3 channels, 5x5, 3x3 kernel, 2 filters
  for i := 0 to 74 do LInput[i] := (i mod 25) + 1.0;  // 3 channels of same data
  for i := 0 to 53 do LKernel[i] := 1.0;  // all-ones kernels
  LBias[0] := 5.0;
  LBias[1] := -3.0;
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], @LBias[0], @LMCOut[0], 3, 5, 5, 3, 3, 2);
  // Filter 0, position [0,0]: sum over 3 channels * 3x3 window + bias
  LExpected := 0;
  for c := 0 to 2 do
    for ky := 0 to 2 do
      for kx := 0 to 2 do
        LExpected := LExpected + LInput[c * 25 + ky * 5 + kx];
  Check('Conv2DMC_F0[0,0]', LMCOut[0], LExpected + 5.0);
  Check('Conv2DMC_F1[0,0]', LMCOut[9], LExpected - 3.0);

  // Test with nil bias
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], nil, @LMCOut[0], 3, 5, 5, 3, 3, 1);
  Check('Conv2DMC_noBias', LMCOut[0], LExpected);

  // Test GlobalAvgPool2DF32: 3 channels, 5x5
  for i := 0 to 74 do LInput[i] := (i mod 25) + 1.0;
  GlobalAvgPool2DF32(@LInput[0], @LGlobalOut[0], 3, 5, 5);
  LExpected := 0;
  for i := 0 to 24 do LExpected := LExpected + LInput[i];
  Check('GlobalAvgPool[0]', LGlobalOut[0], LExpected / 25.0, 1e-4);
  Check('GlobalAvgPool[1]', LGlobalOut[1], LExpected / 25.0, 1e-4);
  Check('GlobalAvgPool[2]', LGlobalOut[2], LExpected / 25.0, 1e-4);

  // Test BatchNorm2DInferF32: identity transform (gamma=1, beta=0, mean=0, var=1)
  for i := 0 to 74 do LInput[i] := i + 1.0;
  for c := 0 to 2 do begin LGamma[c] := 1.0; LBeta[c] := 0.0; LMean[c] := 0.0; LVar[c] := 1.0; end;
  BatchNorm2DInferF32(@LInput[0], @LInput[0], 3, 5, 5, @LGamma[0], @LBeta[0], @LMean[0], @LVar[0], 1e-5);
  Check('BN2D_identity[0]', LInput[0], 1.0, 1e-3);
  Check('BN2D_identity[25]', LInput[25], 26.0, 1e-3);

  // Test BatchNorm2DInferF32: scale + shift
  for i := 0 to 74 do LInput[i] := 10.0;
  LGamma[0] := 2.0; LBeta[0] := 5.0; LMean[0] := 10.0; LVar[0] := 4.0;
  BatchNorm2DInferF32(@LInput[0], @LInput[0], 1, 5, 5, @LGamma[0], @LBeta[0], @LMean[0], @LVar[0], 0);
  // (10 - 10) / sqrt(4) * 2 + 5 = 5
  Check('BN2D_shift', LInput[0], 5.0, 1e-4);

  // Test DepthwiseConv2DF32: 3 channels, 5x5, 3x3 kernel
  for i := 0 to 74 do LInput[i] := (i mod 25) + 1.0;
  for i := 0 to 26 do LKernel[i] := 1.0;  // 3 channels * 3x3 all-ones
  LBias[0] := 1.0; LBias[1] := 2.0; LBias[2] := 3.0;
  DepthwiseConv2DF32(@LInput[0], @LKernel[0], @LBias[0], @LDWOut[0], 3, 5, 5, 3, 3);
  // Channel 0, pos [0,0]: sum of 3x3 window + bias[0]
  LExpected := 0;
  for ky := 0 to 2 do
    for kx := 0 to 2 do
      LExpected := LExpected + LInput[ky * 5 + kx];
  Check('DepthwiseConv[0,0,0]', LDWOut[0], LExpected + 1.0);
  // Channel 1 should have same spatial sum + different bias
  Check('DepthwiseConv[1,0,0]', LDWOut[9], LExpected + 2.0);

  // Test Conv2DSameF32: output has same spatial size as input (5x5 → 5x5)
  for i := 0 to 24 do LInput[i] := i + 1.0;
  for i := 0 to 8 do LKernel[i] := 1.0;  // 1 filter * 1ch * 3x3
  LBias[0] := 0;
  Conv2DSameF32(@LInput[0], @LKernel[0], @LBias[0], @LBigOut[0], 1, 5, 5, 3, 3, 1);
  // Center pixel [2,2]: full 3x3 sum
  LExpected := 0;
  for ky := 0 to 2 do
    for kx := 0 to 2 do
      LExpected := LExpected + LInput[(2 + ky - 1) * 5 + (2 + kx - 1)];
  Check('Conv2DSame_center', LBigOut[2 * 5 + 2], LExpected, 1e-4);
  // Corner [0,0]: only bottom-right 2x2 of kernel sees input
  LExpected := LInput[0] + LInput[1] + LInput[5] + LInput[6];
  Check('Conv2DSame_corner', LBigOut[0], LExpected, 1e-4);

  // === Test UpsampleNearest2DF32 ===
  // 1 channel, 2x2 input, scale 2x2 → 4x4 output
  LInput[0] := 1; LInput[1] := 2;
  LInput[2] := 3; LInput[3] := 4;
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  UpsampleNearest2DF32(@LInput[0], @LBigOut[0], 1, 2, 2, 2, 2);
  // Row 0: [1,1,2,2]
  Check('Upsample[0,0]', LBigOut[0], 1.0);
  Check('Upsample[0,1]', LBigOut[1], 1.0);
  Check('Upsample[0,2]', LBigOut[2], 2.0);
  Check('Upsample[0,3]', LBigOut[3], 2.0);
  // Row 1: [1,1,2,2] (same as row 0)
  Check('Upsample[1,0]', LBigOut[4], 1.0);
  Check('Upsample[1,3]', LBigOut[7], 2.0);
  // Row 2: [3,3,4,4]
  Check('Upsample[2,0]', LBigOut[8], 3.0);
  Check('Upsample[2,1]', LBigOut[9], 3.0);
  Check('Upsample[2,2]', LBigOut[10], 4.0);
  Check('Upsample[2,3]', LBigOut[11], 4.0);
  // Row 3: [3,3,4,4]
  Check('Upsample[3,2]', LBigOut[14], 4.0);

  // Multi-channel upsample: 2 channels, 2x2, scale 1x3
  for i := 0 to 3 do LInput[i] := i + 1.0;  // ch0: 1,2,3,4
  for i := 4 to 7 do LInput[i] := (i - 4) + 10.0;  // ch1: 10,11,12,13
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  UpsampleNearest2DF32(@LInput[0], @LBigOut[0], 2, 2, 2, 1, 3);
  // ch0 row0: [1,1,1,2,2,2], ch0 row1: [3,3,3,4,4,4]
  Check('Upsample_MC_ch0[0,0]', LBigOut[0], 1.0);
  Check('Upsample_MC_ch0[0,2]', LBigOut[2], 1.0);
  Check('Upsample_MC_ch0[0,3]', LBigOut[3], 2.0);
  Check('Upsample_MC_ch0[1,0]', LBigOut[6], 3.0);
  // ch1 starts at offset 2*6=12
  Check('Upsample_MC_ch1[0,0]', LBigOut[12], 10.0);
  Check('Upsample_MC_ch1[0,3]', LBigOut[15], 11.0);

  // === Test ChannelConcatF32 ===
  // 2 channels + 1 channel, 2x2 spatial → 3 channels output
  for i := 0 to 7 do LInput[i] := i + 1.0;  // A: 2ch * 2x2 = [1..8]
  for i := 0 to 3 do LInput[50 + i] := (i + 1) * 10.0;  // B: 1ch * 2x2 = [10,20,30,40]
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  ChannelConcatF32(@LInput[0], @LInput[50], @LBigOut[0], 2, 1, 2, 2);
  // Output: ch0=[1,2,3,4], ch1=[5,6,7,8], ch2=[10,20,30,40]
  Check('Concat_ch0[0]', LBigOut[0], 1.0);
  Check('Concat_ch0[3]', LBigOut[3], 4.0);
  Check('Concat_ch1[0]', LBigOut[4], 5.0);
  Check('Concat_ch1[3]', LBigOut[7], 8.0);
  Check('Concat_ch2[0]', LBigOut[8], 10.0);
  Check('Concat_ch2[3]', LBigOut[11], 40.0);

  // === Test ResidualAddF32 ===
  for i := 0 to 11 do LInput[i] := i + 1.0;
  for i := 0 to 11 do LInput[50 + i] := (i + 1) * 0.1;
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  ResidualAddF32(@LInput[0], @LInput[50], @LBigOut[0], 3, 2, 2);
  Check('Residual[0]', LBigOut[0], 1.0 + 0.1);
  Check('Residual[5]', LBigOut[5], 6.0 + 0.6);
  Check('Residual[11]', LBigOut[11], 12.0 + 1.2);

  // === Test UpsampleBilinear2DF32 ===
  // 1 channel, 2x2 → 3x3 (corners preserved, edges/center interpolated)
  LInput[0] := 0; LInput[1] := 2;
  LInput[2] := 4; LInput[3] := 6;
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  UpsampleBilinear2DF32(@LInput[0], @LBigOut[0], 1, 2, 2, 3, 3);
  // Corners should be exact
  Check('Bilinear[0,0]', LBigOut[0], 0.0, 1e-5);
  Check('Bilinear[0,2]', LBigOut[2], 2.0, 1e-5);
  Check('Bilinear[2,0]', LBigOut[6], 4.0, 1e-5);
  Check('Bilinear[2,2]', LBigOut[8], 6.0, 1e-5);
  // Center should be average of all 4 corners
  Check('Bilinear[1,1]', LBigOut[4], 3.0, 1e-5);
  // Edge midpoints
  Check('Bilinear[0,1]', LBigOut[1], 1.0, 1e-5);  // avg(0,2)
  Check('Bilinear[1,0]', LBigOut[3], 2.0, 1e-5);  // avg(0,4)
  Check('Bilinear[1,2]', LBigOut[5], 4.0, 1e-5);  // avg(2,6)
  Check('Bilinear[2,1]', LBigOut[7], 5.0, 1e-5);  // avg(4,6)

  // 1 channel, 2x2 → 4x4 (scale 2x)
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  UpsampleBilinear2DF32(@LInput[0], @LBigOut[0], 1, 2, 2, 4, 4);
  Check('Bilinear4x4[0,0]', LBigOut[0], 0.0, 1e-5);
  Check('Bilinear4x4[0,3]', LBigOut[3], 2.0, 1e-5);
  Check('Bilinear4x4[3,0]', LBigOut[12], 4.0, 1e-5);
  Check('Bilinear4x4[3,3]', LBigOut[15], 6.0, 1e-5);

  // === Test TransposeConv2DF32 ===
  // 1 channel, 2x2 input, 2x2 kernel, stride=1 → output 3x3
  // output_size = (input-1)*stride + kernel = (2-1)*1 + 2 = 3
  LInput[0] := 1; LInput[1] := 2;
  LInput[2] := 3; LInput[3] := 4;
  LKernel[0] := 1; LKernel[1] := 0;
  LKernel[2] := 0; LKernel[3] := 1;
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  TransposeConv2DF32(@LInput[0], @LKernel[0], nil, @LBigOut[0], 1, 2, 2, 2, 2, 1, 1);
  // Scatter: input[0,0]=1 * kernel → out[0..1,0..1] += [1,0,0,1]
  //          input[0,1]=2 * kernel → out[0..1,1..2] += [2,0,0,2]
  //          input[1,0]=3 * kernel → out[1..2,0..1] += [3,0,0,3]
  //          input[1,1]=4 * kernel → out[1..2,1..2] += [4,0,0,4]
  // out = [1, 2, 0]
  //       [3, 1+4, 2]  = [3, 5, 2]
  //       [0, 3,   4]
  Check('TransConv[0,0]', LBigOut[0], 1.0);
  Check('TransConv[0,1]', LBigOut[1], 2.0);
  Check('TransConv[0,2]', LBigOut[2], 0.0);
  Check('TransConv[1,0]', LBigOut[3], 3.0);
  Check('TransConv[1,1]', LBigOut[4], 5.0);
  Check('TransConv[1,2]', LBigOut[5], 2.0);
  Check('TransConv[2,0]', LBigOut[6], 0.0);
  Check('TransConv[2,1]', LBigOut[7], 3.0);
  Check('TransConv[2,2]', LBigOut[8], 4.0);

  // TransposeConv2D with stride=2: 2x2 input, 2x2 kernel → output 4x4
  // output_size = (2-1)*2 + 2 = 4
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  LKernel[0] := 1; LKernel[1] := 1; LKernel[2] := 1; LKernel[3] := 1;
  TransposeConv2DF32(@LInput[0], @LKernel[0], nil, @LBigOut[0], 1, 2, 2, 2, 2, 1, 2);
  // input[0,0]=1 → out[0..1,0..1]
  // input[0,1]=2 → out[0..1,2..3]
  // input[1,0]=3 → out[2..3,0..1]
  // input[1,1]=4 → out[2..3,2..3]
  Check('TransConvS2[0,0]', LBigOut[0], 1.0);
  Check('TransConvS2[0,1]', LBigOut[1], 1.0);
  Check('TransConvS2[0,2]', LBigOut[2], 2.0);
  Check('TransConvS2[0,3]', LBigOut[3], 2.0);
  Check('TransConvS2[2,0]', LBigOut[8], 3.0);
  Check('TransConvS2[3,3]', LBigOut[15], 4.0);

  // TransposeConv2D with bias
  LBias[0] := 10.0;
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  TransposeConv2DF32(@LInput[0], @LKernel[0], @LBias[0], @LBigOut[0], 1, 2, 2, 2, 2, 1, 2);
  Check('TransConvBias[0,0]', LBigOut[0], 11.0);
  Check('TransConvBias[3,3]', LBigOut[15], 14.0);

  // === Test ChannelArgMaxF32 ===
  // 3 channels, 2x2 spatial
  // ch0: [1, 5, 3, 2], ch1: [4, 2, 6, 1], ch2: [3, 3, 2, 7]
  LInput[0] := 1; LInput[1] := 5; LInput[2] := 3; LInput[3] := 2;  // ch0
  LInput[4] := 4; LInput[5] := 2; LInput[6] := 6; LInput[7] := 1;  // ch1
  LInput[8] := 3; LInput[9] := 3; LInput[10] := 2; LInput[11] := 7; // ch2
  FillChar(LPoolOut, SizeOf(LPoolOut), 0);
  ChannelArgMaxF32(@LInput[0], PInt32(@LPoolOut[0]), 3, 2, 2);
  // pos0: max(1,4,3)=4 → ch1=1
  // pos1: max(5,2,3)=5 → ch0=0
  // pos2: max(3,6,2)=6 → ch1=1
  // pos3: max(2,1,7)=7 → ch2=2
  Check('ArgMax[0]', Single(PInt32(@LPoolOut[0])[0]), 1.0);
  Check('ArgMax[1]', Single(PInt32(@LPoolOut[0])[1]), 0.0);
  Check('ArgMax[2]', Single(PInt32(@LPoolOut[0])[2]), 1.0);
  Check('ArgMax[3]', Single(PInt32(@LPoolOut[0])[3]), 2.0);

  // === Test ChannelSoftmaxF32 ===
  // 2 channels, 1x1 spatial (simplest case)
  LInput[0] := 1.0;  // ch0
  LInput[1] := 3.0;  // ch1
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  ChannelSoftmaxF32(@LInput[0], @LBigOut[0], 2, 1, 1);
  // softmax([1,3]) = [e^1/(e^1+e^3), e^3/(e^1+e^3)]
  LExpected := Exp(1.0) / (Exp(1.0) + Exp(3.0));
  Check('Softmax2D_ch0', LBigOut[0], LExpected, 1e-5);
  Check('Softmax2D_ch1', LBigOut[1], 1.0 - LExpected, 1e-5);
  // Sum should be 1.0
  Check('Softmax2D_sum', LBigOut[0] + LBigOut[1], 1.0, 1e-5);

  // === Edge Case Tests: Zero Dimensions ===
  // These must not crash (just return silently)
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], nil, @LBigOut[0], 0, 5, 5, 3, 3, 1);
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], nil, @LBigOut[0], 1, 0, 5, 3, 3, 1);
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], nil, @LBigOut[0], 1, 5, 0, 3, 3, 1);
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], nil, @LBigOut[0], 1, 5, 5, 0, 3, 1);
  DepthwiseConv2DF32(@LInput[0], @LKernel[0], nil, @LBigOut[0], 0, 5, 5, 3, 3);
  MaxPool2DF32(@LInput[0], @LBigOut[0], 0, 4, 2, 2, 2, 2);
  UpsampleNearest2DF32(@LInput[0], @LBigOut[0], 0, 4, 4, 2, 2);
  UpsampleBilinear2DF32(@LInput[0], @LBigOut[0], 0, 4, 4, 8, 8);
  ChannelConcatF32(@LInput[0], @LInput[0], @LBigOut[0], 0, 0, 0, 0);
  ResidualAddF32(@LInput[0], @LInput[0], @LBigOut[0], 0, 0, 0);
  ChannelSoftmaxF32(@LInput[0], @LBigOut[0], 0, 4, 4);
  ChannelArgMaxF32(@LInput[0], @LArgOut[0], 0, 4, 4);
  Inc(LPass);  // If we got here without crash, pass
  WriteLn('  Edge cases (zero dims): OK');

  // === Large Tensor Test: 4ch 8x8 k3x3 via im2col path ===
  // K = 4*3*3 = 36 >= 16, so im2col path is exercised
  for i := 0 to 4*8*8 - 1 do LInput[i] := (i mod 64) * 0.1;
  for i := 0 to 2*4*9 - 1 do LKernel[i] := 0.1;  // 2 filters * 4ch * 3x3
  LBias[0] := 1.0; LBias[1] := -1.0;
  FillChar(LBigOut, SizeOf(LBigOut), 0);
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], @LBias[0], @LBigOut[0], 4, 8, 8, 3, 3, 2);
  // Verify filter 0, position [0,0] manually
  LExpected := LBias[0];
  for c := 0 to 3 do
    for ky := 0 to 2 do
      for kx := 0 to 2 do
        LExpected := LExpected + LInput[c*64 + ky*8 + kx] * LKernel[c*9 + ky*3 + kx];
  Check('LargeTensor_F0[0,0]', LBigOut[0], LExpected, 1e-3);
  // Verify filter 1, position [0,0]
  LExpected := LBias[1];
  for c := 0 to 3 do
    for ky := 0 to 2 do
      for kx := 0 to 2 do
        LExpected := LExpected + LInput[c*64 + ky*8 + kx] * LKernel[36 + c*9 + ky*3 + kx];
  Check('LargeTensor_F1[0,0]', LBigOut[36], LExpected, 1e-3);

  // === 1x1 Spatial Edge Case ===
  LInput[0] := 5.0; LInput[1] := 3.0;  // 2 channels, 1x1
  LKernel[0] := 2.0; LKernel[1] := 1.0;  // 1 filter, 2ch, 1x1 kernel
  LBias[0] := 0;
  Conv2DMultiChannelF32(@LInput[0], @LKernel[0], @LBias[0], @LBigOut[0], 2, 1, 1, 1, 1, 1);
  Check('1x1_spatial', LBigOut[0], 5.0*2.0 + 3.0*1.0, 1e-5);

  WriteLn('Tests run: ', LPass + LFail);
  WriteLn('Passed: ', LPass);
  WriteLn('Failed: ', LFail);
  if LFail = 0 then
    WriteLn('All tests passed!')
  else
    Halt(1);
end.

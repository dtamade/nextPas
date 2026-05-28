program test_nn_heaptrc;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.simd.nn;

var
  LInput: array[0..255] of Single;
  LOutput: array[0..255] of Single;
  LKernel: array[0..80] of Single;
  LBias: array[0..15] of Single;
  LGamma, LBeta, LMean, LVar: array[0..7] of Single;
  LTargets: array[0..3] of Int32;
  LArgOut: array[0..63] of Int32;
  i: Integer;

begin
  WriteLn('=== nn module HeapTrc leak test ===');

  for i := 0 to 255 do LInput[i] := (i + 1) * 0.1;
  for i := 0 to 80 do LKernel[i] := 1.0;
  for i := 0 to 15 do LBias[i] := 0.5;
  for i := 0 to 7 do begin LGamma[i] := 1.0; LBeta[i] := 0.0; LMean[i] := 0.0; LVar[i] := 1.0; end;

  // Functions with SimdAlloc: Sigmoid, Softmax, LayerNorm, SiLU, GeluApprox
  SigmoidF32(@LInput[0], @LOutput[0], 32);
  WriteLn('  Sigmoid OK');

  SoftmaxF32(@LInput[0], @LOutput[0], 32);
  WriteLn('  Softmax OK');

  LayerNormF32(@LInput[0], @LGamma[0], @LBeta[0], @LOutput[0], 8);
  WriteLn('  LayerNorm OK');

  SiLUF32(@LInput[0], @LOutput[0], 32);
  WriteLn('  SiLU OK');

  GeluApproxF32(@LInput[0], @LOutput[0], 32);
  WriteLn('  GeluApprox OK');

  // BatchNorm (allocates LScale, LBias internally)
  BatchNormF32(@LInput[0], 4, 8, @LMean[0], @LVar[0], @LGamma[0], @LBeta[0], 1e-5, @LOutput[0]);
  WriteLn('  BatchNorm OK');

  // TanhF32, ELUF32 (allocate tmp)
  TanhF32(@LInput[0], @LOutput[0], 32);
  WriteLn('  Tanh OK');

  ELUF32(@LInput[0], @LOutput[0], 32);
  WriteLn('  ELU OK');

  // LogSoftmax, Softplus (allocate tmp)
  LogSoftmaxF32(@LInput[0], @LOutput[0], 16);
  WriteLn('  LogSoftmax OK');

  SoftplusF32(@LInput[0], @LOutput[0], 32);
  WriteLn('  Softplus OK');

  // CrossEntropyLoss (allocates LLogSoftmax)
  LTargets[0] := 0; LTargets[1] := 1; LTargets[2] := 2; LTargets[3] := 0;
  CrossEntropyLossF32(@LInput[0], @LTargets[0], 4, 4);
  WriteLn('  CrossEntropyLoss OK');

  // Conv2DSameF32 (allocates padded buffer)
  Conv2DSameF32(@LInput[0], @LKernel[0], @LBias[0], @LOutput[0], 1, 5, 5, 3, 3, 1);
  WriteLn('  Conv2DSame OK');

  // Functions WITHOUT allocation (verify they don't crash)
  Conv2DF32(@LInput[0], @LKernel[0], @LOutput[0], 5, 5, 3, 3);
  WriteLn('  Conv2D OK');

  MaxPool2DF32(@LInput[0], @LOutput[0], 4, 4, 2, 2, 2, 2);
  WriteLn('  MaxPool2D OK');

  UpsampleNearest2DF32(@LInput[0], @LOutput[0], 1, 4, 4, 2, 2);
  WriteLn('  UpsampleNearest OK');

  UpsampleBilinear2DF32(@LInput[0], @LOutput[0], 1, 4, 4, 8, 8);
  WriteLn('  UpsampleBilinear OK');

  TransposeConv2DF32(@LInput[0], @LKernel[0], @LBias[0], @LOutput[0], 1, 3, 3, 2, 2, 1, 1);
  WriteLn('  TransposeConv2D OK');

  ChannelConcatF32(@LInput[0], @LInput[64], @LOutput[0], 2, 1, 4, 4);
  WriteLn('  ChannelConcat OK');

  ResidualAddF32(@LInput[0], @LInput[64], @LOutput[0], 2, 4, 4);
  WriteLn('  ResidualAdd OK');

  ChannelArgMaxF32(@LInput[0], @LArgOut[0], 4, 4, 4);
  WriteLn('  ChannelArgMax OK');

  ChannelSoftmaxF32(@LInput[0], @LOutput[0], 4, 4, 4);
  WriteLn('  ChannelSoftmax OK');

  WriteLn('=== All nn functions executed, checking heap... ===');
end.

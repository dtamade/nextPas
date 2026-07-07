{
   nextpas.core.simd.nn.testcase - Neural Network 单元专用测试
   覆盖激活函数、归一化、池化、卷积等
}
unit nextpas.core.simd.nn.testcase;

{$I ../../src/nextpas.core.settings.inc}

interface

uses
  Classes, fpcunit, testregistry,
  nextpas.core.simd.nn;

type
  TTestCase_SimdNN = class(TTestCase)
  published
    procedure Test_Sigmoid_Basic;
    procedure Test_Sigmoid_Bounds;
    procedure Test_Softmax_Basic;
    procedure Test_Softmax_SumToOne;
    procedure Test_SiLU_Basic;
    procedure Test_GeluApprox_Basic;
    procedure Test_LeakyReLU_Basic;
    procedure Test_LeakyReLU_NegativeSlope;
    procedure Test_Tanh_Basic;
    procedure Test_Tanh_Bounds;
    procedure Test_HardSigmoid_Basic;
    procedure Test_HardSwish_Basic;
    procedure Test_ELU_Basic;
    procedure Test_MaxPool1D_Basic;
    procedure Test_AvgPool1D_Basic;
    procedure Test_LinearLayer_Basic;
    procedure Test_Conv1D_Basic;
    procedure Test_LayerNorm_Basic;
    procedure Test_LayerNorm_WithGammaBeta;
    procedure Test_CrossEntropyLoss_Basic;
    procedure Test_Conv2D_Basic;
    procedure Test_BatchNorm_Basic;
    procedure Test_Dropout_Basic;
    procedure Test_Conv2DBias_Basic;
    procedure Test_Conv2DBiasReLU_Basic;
    procedure Test_GlobalAvgPool_Basic;
    procedure Test_RMSNorm_Basic;
    procedure Test_LogSoftmax_Basic;
    procedure Test_BatchNorm2DInfer_Basic;
    procedure Test_NilSafety;
  end;

implementation

const
  EPS = 1E-4;

function NearEqual(A, B, AEps: Single): Boolean;
begin
  Result := Abs(A - B) <= AEps;
end;

{ ============================================================================
  Activation Functions
  ============================================================================ }

procedure TTestCase_SimdNN.Test_Sigmoid_Basic;
var
  LSrc: array[0..3] of Single = (0.0, 1.0, -1.0, 10.0);
  LDst: array[0..3] of Single;
begin
  SigmoidF32(@LSrc[0], @LDst[0], 4);
  // sigmoid(0) = 0.5
  CheckTrue(NearEqual(LDst[0], 0.5, EPS), 'sigmoid(0)=0.5');
  // sigmoid(1) ~ 0.7311
  CheckTrue(NearEqual(LDst[1], 0.7311, EPS), 'sigmoid(1)');
  // sigmoid(-1) ~ 0.2689
  CheckTrue(NearEqual(LDst[2], 0.2689, EPS), 'sigmoid(-1)');
  // sigmoid(10) ~ 1.0
  CheckTrue(LDst[3] > 0.999, 'sigmoid(10)~1');
end;

procedure TTestCase_SimdNN.Test_Sigmoid_Bounds;
var
  LSrc: array[0..1] of Single = (-20.0, 20.0);
  LDst: array[0..1] of Single;
begin
  // Use ±20 to avoid exp() overflow (exp(20) ~ 4.8e8, within F32 range)
  SigmoidF32(@LSrc[0], @LDst[0], 2);
  CheckTrue(LDst[0] >= 0.0, 'sigmoid(-20) >= 0');
  CheckTrue(LDst[1] <= 1.0, 'sigmoid(20) <= 1');
  CheckTrue(LDst[0] < 0.001, 'sigmoid(-20) ~ 0');
  CheckTrue(LDst[1] > 0.999, 'sigmoid(20) ~ 1');
end;

procedure TTestCase_SimdNN.Test_Softmax_Basic;
var
  LSrc: array[0..2] of Single = (1.0, 2.0, 3.0);
  LDst: array[0..2] of Single;
begin
  SoftmaxF32(@LSrc[0], @LDst[0], 3);
  // softmax should be monotonically increasing for increasing input
  CheckTrue(LDst[0] < LDst[1], 'softmax monotonic 0<1');
  CheckTrue(LDst[1] < LDst[2], 'softmax monotonic 1<2');
end;

procedure TTestCase_SimdNN.Test_Softmax_SumToOne;
var
  LSrc: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Single;
  LSum: Single;
  I: Integer;
begin
  SoftmaxF32(@LSrc[0], @LDst[0], 4);
  LSum := 0.0;
  for I := 0 to 3 do
    LSum := LSum + LDst[I];
  CheckTrue(NearEqual(LSum, 1.0, EPS), 'softmax sum=1');
end;

procedure TTestCase_SimdNN.Test_SiLU_Basic;
var
  LSrc: array[0..3] of Single = (0.0, 1.0, -1.0, 2.0);
  LDst: array[0..3] of Single;
begin
  SiLUF32(@LSrc[0], @LDst[0], 4);
  // SiLU(0) = 0
  CheckTrue(NearEqual(LDst[0], 0.0, EPS), 'SiLU(0)=0');
  // SiLU(1) = 1 * sigmoid(1) ~ 0.7311
  CheckTrue(NearEqual(LDst[1], 0.7311, EPS), 'SiLU(1)');
end;

procedure TTestCase_SimdNN.Test_GeluApprox_Basic;
var
  LSrc: array[0..3] of Single = (0.0, 1.0, -1.0, 2.0);
  LDst: array[0..3] of Single;
begin
  GeluApproxF32(@LSrc[0], @LDst[0], 4);
  // GELU(0) ~ 0
  CheckTrue(NearEqual(LDst[0], 0.0, EPS), 'GELU(0)=0');
  // GELU(1) ~ 0.8413
  CheckTrue(NearEqual(LDst[1], 0.8413, 0.01), 'GELU(1)');
end;

procedure TTestCase_SimdNN.Test_LeakyReLU_Basic;
var
  LSrc: array[0..3] of Single = (1.0, -1.0, 2.0, -2.0);
  LDst: array[0..3] of Single;
begin
  LeakyReLUF32(@LSrc[0], @LDst[0], 4, 0.01);
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'LeakyReLU positive');
  CheckTrue(NearEqual(LDst[1], -0.01, EPS), 'LeakyReLU negative');
  CheckTrue(NearEqual(LDst[2], 2.0, EPS), 'LeakyReLU positive2');
  CheckTrue(NearEqual(LDst[3], -0.02, EPS), 'LeakyReLU negative2');
end;

procedure TTestCase_SimdNN.Test_LeakyReLU_NegativeSlope;
var
  LSrc: array[0..1] of Single = (1.0, -1.0);
  LDst: array[0..1] of Single;
begin
  LeakyReLUF32(@LSrc[0], @LDst[0], 2, 0.1);
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'LeakyReLU 0.1 positive');
  CheckTrue(NearEqual(LDst[1], -0.1, EPS), 'LeakyReLU 0.1 negative');
end;

procedure TTestCase_SimdNN.Test_Tanh_Basic;
var
  LSrc: array[0..3] of Single = (0.0, 1.0, -1.0, 2.0);
  LDst: array[0..3] of Single;
begin
  TanhF32(@LSrc[0], @LDst[0], 4);
  CheckTrue(NearEqual(LDst[0], 0.0, EPS), 'tanh(0)=0');
  CheckTrue(NearEqual(LDst[1], 0.7616, 0.01), 'tanh(1)');
  CheckTrue(NearEqual(LDst[2], -0.7616, 0.01), 'tanh(-1)');
end;

procedure TTestCase_SimdNN.Test_Tanh_Bounds;
var
  LSrc: array[0..1] of Single = (-10.0, 10.0);
  LDst: array[0..1] of Single;
begin
  TanhF32(@LSrc[0], @LDst[0], 2);
  CheckTrue(LDst[0] < -0.999, 'tanh(-10) ~ -1');
  CheckTrue(LDst[1] > 0.999, 'tanh(10) ~ 1');
end;

procedure TTestCase_SimdNN.Test_HardSigmoid_Basic;
var
  LSrc: array[0..3] of Single = (0.0, 1.0, -1.0, 3.0);
  LDst: array[0..3] of Single;
begin
  HardSigmoidF32(@LSrc[0], @LDst[0], 4);
  // HardSigmoid(0) = 0.5
  CheckTrue(NearEqual(LDst[0], 0.5, EPS), 'HardSigmoid(0)=0.5');
  // Values should be clamped to [0, 1]
  CheckTrue(LDst[2] >= 0.0, 'HardSigmoid >= 0');
end;

procedure TTestCase_SimdNN.Test_HardSwish_Basic;
var
  LSrc: array[0..3] of Single = (0.0, 1.0, -1.0, 3.0);
  LDst: array[0..3] of Single;
begin
  HardSwishF32(@LSrc[0], @LDst[0], 4);
  // HardSwish(0) = 0
  CheckTrue(NearEqual(LDst[0], 0.0, EPS), 'HardSwish(0)=0');
end;

procedure TTestCase_SimdNN.Test_ELU_Basic;
var
  LSrc: array[0..3] of Single = (1.0, -1.0, 0.0, -2.0);
  LDst: array[0..3] of Single;
begin
  ELUF32(@LSrc[0], @LDst[0], 4, 1.0);
  // ELU(1) = 1
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'ELU positive');
  // ELU(-1) = alpha * (exp(-1) - 1) ~ -0.6321
  CheckTrue(NearEqual(LDst[1], -0.6321, 0.01), 'ELU(-1)');
  // ELU(0) = 0
  CheckTrue(NearEqual(LDst[2], 0.0, EPS), 'ELU(0)');
end;

{ ============================================================================
  Pooling
  ============================================================================ }

procedure TTestCase_SimdNN.Test_MaxPool1D_Basic;
var
  LSrc: array[0..7] of Single = (1.0, 3.0, 2.0, 4.0, 5.0, 1.0, 6.0, 2.0);
  LDst: array[0..3] of Single;
begin
  // kernel=2, stride=2: max(1,3)=3, max(2,4)=4, max(5,1)=5, max(6,2)=6
  MaxPool1DF32(@LSrc[0], @LDst[0], 8, 2, 2);
  CheckTrue(NearEqual(LDst[0], 3.0, EPS), 'MaxPool [0]');
  CheckTrue(NearEqual(LDst[1], 4.0, EPS), 'MaxPool [1]');
  CheckTrue(NearEqual(LDst[2], 5.0, EPS), 'MaxPool [2]');
  CheckTrue(NearEqual(LDst[3], 6.0, EPS), 'MaxPool [3]');
end;

procedure TTestCase_SimdNN.Test_AvgPool1D_Basic;
var
  LSrc: array[0..7] of Single = (1.0, 3.0, 2.0, 4.0, 5.0, 1.0, 6.0, 2.0);
  LDst: array[0..3] of Single;
begin
  // kernel=2, stride=2: avg(1,3)=2, avg(2,4)=3, avg(5,1)=3, avg(6,2)=4
  AvgPool1DF32(@LSrc[0], @LDst[0], 8, 2, 2);
  CheckTrue(NearEqual(LDst[0], 2.0, EPS), 'AvgPool [0]');
  CheckTrue(NearEqual(LDst[1], 3.0, EPS), 'AvgPool [1]');
  CheckTrue(NearEqual(LDst[2], 3.0, EPS), 'AvgPool [2]');
  CheckTrue(NearEqual(LDst[3], 4.0, EPS), 'AvgPool [3]');
end;

{ ============================================================================
  Layers
  ============================================================================ }

procedure TTestCase_SimdNN.Test_LinearLayer_Basic;
var
  LInput: array[0..1] of Single = (1.0, 2.0);
  LWeight: array[0..3] of Single = (0.5, 0.5, 0.5, 0.5);  // 2x2 matrix
  LBias: array[0..1] of Single = (0.1, 0.2);
  LOutput: array[0..1] of Single;
begin
  // out[0] = 1*0.5 + 2*0.5 + 0.1 = 1.6
  // out[1] = 1*0.5 + 2*0.5 + 0.2 = 1.7
  LinearLayerF32(@LInput[0], @LWeight[0], @LBias[0], @LOutput[0], 1, 2, 2);
  CheckTrue(NearEqual(LOutput[0], 1.6, EPS), 'Linear out[0]');
  CheckTrue(NearEqual(LOutput[1], 1.7, EPS), 'Linear out[1]');
end;

procedure TTestCase_SimdNN.Test_Conv1D_Basic;
var
  LInput: array[0..5] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
  LKernel: array[0..2] of Single = (1.0, 0.0, -1.0);
  LOutput: array[0..3] of Single;
begin
  // out[0] = 1*1 + 2*0 + 3*(-1) = -2
  // out[1] = 2*1 + 3*0 + 4*(-1) = -2
  // out[2] = 3*1 + 4*0 + 5*(-1) = -2
  // out[3] = 4*1 + 5*0 + 6*(-1) = -2
  Conv1DF32(@LInput[0], @LKernel[0], @LOutput[0], 6, 3, 4);
  CheckTrue(NearEqual(LOutput[0], -2.0, EPS), 'Conv1D [0]');
  CheckTrue(NearEqual(LOutput[1], -2.0, EPS), 'Conv1D [1]');
  CheckTrue(NearEqual(LOutput[2], -2.0, EPS), 'Conv1D [2]');
  CheckTrue(NearEqual(LOutput[3], -2.0, EPS), 'Conv1D [3]');
end;

{ ============================================================================
  LayerNorm
  ============================================================================ }

procedure TTestCase_SimdNN.Test_LayerNorm_Basic;
var
  LX: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Single;
  LMean, LStd: Single;
  I: Integer;
begin
  LayerNormF32(@LX[0], nil, nil, @LDst[0], 4, 1e-5);
  // Output should be zero-mean, unit-variance
  LMean := 0;
  for I := 0 to 3 do LMean := LMean + LDst[I];
  LMean := LMean / 4;
  CheckTrue(NearEqual(LMean, 0.0, EPS), 'LayerNorm mean~0');
  LStd := 0;
  for I := 0 to 3 do LStd := LStd + LDst[I] * LDst[I];
  LStd := System.Sqrt(LStd / 4);
  CheckTrue(NearEqual(LStd, 1.0, 0.05), 'LayerNorm std~1');
end;

procedure TTestCase_SimdNN.Test_LayerNorm_WithGammaBeta;
var
  LX: array[0..1] of Single = (1.0, 2.0);
  LGamma: array[0..1] of Single = (2.0, 2.0);
  LBeta: array[0..1] of Single = (1.0, 1.0);
  LDst: array[0..1] of Single;
begin
  // With gamma=2, beta=1: output = gamma * normalized + beta
  LayerNormF32(@LX[0], @LGamma[0], @LBeta[0], @LDst[0], 2, 1e-5);
  // normalized[0] = -1, normalized[1] = 1 (for 2 elements)
  // dst[0] = 2*(-1) + 1 = -1, dst[1] = 2*1 + 1 = 3
  CheckTrue(NearEqual(LDst[0], -1.0, 0.05), 'LayerNorm gamma beta [0]');
  CheckTrue(NearEqual(LDst[1], 3.0, 0.05), 'LayerNorm gamma beta [1]');
end;

{ ============================================================================
  CrossEntropyLoss
  ============================================================================ }

procedure TTestCase_SimdNN.Test_CrossEntropyLoss_Basic;
var
  // 2 samples, 3 classes
  // Sample 0: logits [2.0, 1.0, 0.1], target = 0 (correct class)
  // Sample 1: logits [0.5, 2.0, 0.3], target = 1 (correct class)
  LLogits: array[0..5] of Single = (2.0, 1.0, 0.1, 0.5, 2.0, 0.3);
  LTargets: array[0..1] of Int32 = (0, 1);
  LLoss: Single;
begin
  LLoss := CrossEntropyLossF32(@LLogits[0], @LTargets[0], 2, 3);
  // Loss should be positive and reasonable (< 2.0 for well-classified data)
  CheckTrue(LLoss > 0.0, 'CrossEntropy > 0');
  CheckTrue(LLoss < 2.0, 'CrossEntropy < 2');
end;

{ ============================================================================
  Conv2D
  ============================================================================ }

procedure TTestCase_SimdNN.Test_Conv2D_Basic;
var
  // 3x3 input, 2x2 kernel → 2x2 output
  LInput: array[0..8] of Single = (1, 2, 3, 4, 5, 6, 7, 8, 9);
  LKernel: array[0..3] of Single = (1, 0, 0, 1);
  LOutput: array[0..3] of Single;
begin
  // out[0,0] = 1*1 + 2*0 + 4*0 + 5*1 = 6
  // out[0,1] = 2*1 + 3*0 + 5*0 + 6*1 = 8
  // out[1,0] = 4*1 + 5*0 + 7*0 + 8*1 = 12
  // out[1,1] = 5*1 + 6*0 + 8*0 + 9*1 = 14
  Conv2DF32(@LInput[0], @LKernel[0], @LOutput[0], 3, 3, 2, 2);
  CheckTrue(NearEqual(LOutput[0], 6.0, EPS), 'Conv2D [0,0]');
  CheckTrue(NearEqual(LOutput[1], 8.0, EPS), 'Conv2D [0,1]');
  CheckTrue(NearEqual(LOutput[2], 12.0, EPS), 'Conv2D [1,0]');
  CheckTrue(NearEqual(LOutput[3], 14.0, EPS), 'Conv2D [1,1]');
end;

{ ============================================================================
  BatchNorm
  ============================================================================ }

procedure TTestCase_SimdNN.Test_BatchNorm_Basic;
var
  // 2 samples, 3 features
  LX: array[0..5] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
  LMean: array[0..2] of Single = (2.5, 3.5, 4.5);
  LVar: array[0..2] of Single = (2.5, 2.5, 2.5);
  LGamma: array[0..2] of Single = (1.0, 1.0, 1.0);
  LBeta: array[0..2] of Single = (0.0, 0.0, 0.0);
  LDst: array[0..5] of Single;
begin
  BatchNormF32(@LX[0], 2, 3, @LMean[0], @LVar[0], @LGamma[0], @LBeta[0], 1e-5, @LDst[0]);
  // After normalization: output should be approximately zero-mean
  // Check that values are in reasonable range
  CheckTrue(Abs(LDst[0]) < 2.0, 'BatchNorm [0]');
  CheckTrue(Abs(LDst[3]) < 2.0, 'BatchNorm [3]');
end;

{ ============================================================================
  Dropout
  ============================================================================ }

procedure TTestCase_SimdNN.Test_Dropout_Basic;
var
  LSrc: array[0..7] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  LDst: array[0..7] of Single;
  LZeroCount, I: Integer;
begin
  // With 50% dropout rate
  FillChar(LDst, SizeOf(LDst), 0);
  DropoutF32(@LSrc[0], @LDst[0], 8, 0.5, 12345);
  // Count zeroed elements (approximately half)
  LZeroCount := 0;
  for I := 0 to 7 do
    if LDst[I] = 0.0 then Inc(LZeroCount);
  // With 50% rate, expect roughly 4 zeros (allow 2-6)
  CheckTrue(LZeroCount >= 2, 'Dropout: enough zeros');
  CheckTrue(LZeroCount <= 6, 'Dropout: not too many zeros');
  // Non-zero values should be scaled by 1/(1-0.5) = 2.0
  for I := 0 to 7 do
    if LDst[I] <> 0.0 then
      CheckTrue(NearEqual(LDst[I], LSrc[I] * 2.0, EPS), 'Dropout: scaled value');
end;

{ ============================================================================
  Conv2DBias / Conv2DBiasReLU
  ============================================================================ }

procedure TTestCase_SimdNN.Test_Conv2DBias_Basic;
var
  // 3x3 input, 1 filter, 2x2 kernel
  LInput: array[0..8] of Single = (1, 2, 3, 4, 5, 6, 7, 8, 9);
  LKernel: array[0..3] of Single = (1, 0, 0, 1);
  LBias: array[0..0] of Single = (0.5);
  LOutput: array[0..3] of Single;
begin
  Conv2DBiasF32(@LInput[0], @LKernel[0], @LBias[0], @LOutput[0], 3, 3, 2, 2, 1);
  // Same as Conv2D but with bias added
  CheckTrue(NearEqual(LOutput[0], 6.5, EPS), 'Conv2DBias [0,0]');
  CheckTrue(NearEqual(LOutput[1], 8.5, EPS), 'Conv2DBias [0,1]');
  CheckTrue(NearEqual(LOutput[2], 12.5, EPS), 'Conv2DBias [1,0]');
  CheckTrue(NearEqual(LOutput[3], 14.5, EPS), 'Conv2DBias [1,1]');
end;

procedure TTestCase_SimdNN.Test_Conv2DBiasReLU_Basic;
var
  // 3x3 input, 1 filter, 2x2 kernel
  LInput: array[0..8] of Single = (1, 2, 3, 4, 5, 6, 7, 8, 9);
  LKernel: array[0..3] of Single = (1, 0, 0, 1);
  LBias: array[0..0] of Single = (-10.0);  // Large negative bias
  LOutput: array[0..3] of Single;
begin
  // Conv2D output: [6, 8, 12, 14]
  // After bias: [-4, -2, 2, 4]
  // After ReLU: [0, 0, 2, 4]
  Conv2DBiasReLUF32(@LInput[0], @LKernel[0], @LBias[0], @LOutput[0], 3, 3, 2, 2, 1);
  CheckTrue(NearEqual(LOutput[0], 0.0, EPS), 'Conv2DBiasReLU [0,0]');
  CheckTrue(NearEqual(LOutput[1], 0.0, EPS), 'Conv2DBiasReLU [0,1]');
  CheckTrue(NearEqual(LOutput[2], 2.0, EPS), 'Conv2DBiasReLU [1,0]');
  CheckTrue(NearEqual(LOutput[3], 4.0, EPS), 'Conv2DBiasReLU [1,1]');
end;

{ ============================================================================
  GlobalAvgPool2D
  ============================================================================ }

procedure TTestCase_SimdNN.Test_GlobalAvgPool_Basic;
var
  // 2 channels, 2x2 spatial
  LInput: array[0..7] of Single = (1, 2, 3, 4, 5, 6, 7, 8);
  LOutput: array[0..1] of Single;
begin
  GlobalAvgPool2DF32(@LInput[0], @LOutput[0], 2, 2, 2);
  // Channel 0: avg(1,2,3,4) = 2.5
  // Channel 1: avg(5,6,7,8) = 6.5
  CheckTrue(NearEqual(LOutput[0], 2.5, EPS), 'GlobalAvgPool ch0');
  CheckTrue(NearEqual(LOutput[1], 6.5, EPS), 'GlobalAvgPool ch1');
end;

{ ============================================================================
  RMSNorm
  ============================================================================ }

procedure TTestCase_SimdNN.Test_RMSNorm_Basic;
var
  LX: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LGamma: array[0..3] of Single = (1.0, 1.0, 1.0, 1.0);
  LDst: array[0..3] of Single;
  LRms: Single;
begin
  RMSNormF32(@LX[0], @LGamma[0], @LDst[0], 4, 1e-5);
  // RMS of input: sqrt((1+4+9+16)/4) = sqrt(7.5) ≈ 2.7386
  LRms := System.Sqrt((1.0 + 4.0 + 9.0 + 16.0) / 4.0);
  // Output should be x / rms * gamma
  CheckTrue(NearEqual(LDst[0], LX[0] / LRms, 0.01), 'RMSNorm [0]');
  CheckTrue(NearEqual(LDst[1], LX[1] / LRms, 0.01), 'RMSNorm [1]');
  CheckTrue(NearEqual(LDst[2], LX[2] / LRms, 0.01), 'RMSNorm [2]');
  CheckTrue(NearEqual(LDst[3], LX[3] / LRms, 0.01), 'RMSNorm [3]');
end;

{ ============================================================================
  LogSoftmax
  ============================================================================ }

procedure TTestCase_SimdNN.Test_LogSoftmax_Basic;
var
  LSrc: array[0..2] of Single = (1.0, 2.0, 3.0);
  LDst: array[0..2] of Single;
  LSum: Single;
  I: Integer;
begin
  LogSoftmaxF32(@LSrc[0], @LDst[0], 3);
  // exp(log_softmax) should sum to 1.0
  LSum := 0.0;
  for I := 0 to 2 do
    LSum := LSum + System.Exp(LDst[I]);
  CheckTrue(NearEqual(LSum, 1.0, 0.01), 'LogSoftmax: exp sum = 1');
  // Values should be in increasing order (log_softmax preserves order)
  CheckTrue(LDst[0] < LDst[1], 'LogSoftmax: ordering [0] < [1]');
  CheckTrue(LDst[1] < LDst[2], 'LogSoftmax: ordering [1] < [2]');
end;

{ ============================================================================
  BatchNorm2DInfer
  ============================================================================ }

procedure TTestCase_SimdNN.Test_BatchNorm2DInfer_Basic;
var
  // 2 channels, 2x2 spatial
  LInput: array[0..7] of Single = (1, 2, 3, 4, 5, 6, 7, 8);
  LOutput: array[0..7] of Single;
  LGamma: array[0..1] of Single = (1.0, 1.0);
  LBeta: array[0..1] of Single = (0.0, 0.0);
  LMean: array[0..1] of Single = (2.5, 6.5);
  LVar: array[0..1] of Single = (1.25, 1.25);
begin
  BatchNorm2DInferF32(@LInput[0], @LOutput[0], 2, 2, 2, @LGamma[0], @LBeta[0], @LMean[0], @LVar[0], 1e-5);
  // After normalization, output should be approximately zero-mean
  // Check values are in reasonable range
  CheckTrue(Abs(LOutput[0]) < 3.0, 'BatchNorm2D [0]');
  CheckTrue(Abs(LOutput[4]) < 3.0, 'BatchNorm2D [4]');
end;

{ ============================================================================
  Edge Cases
  ============================================================================ }

procedure TTestCase_SimdNN.Test_NilSafety;
var
  LDummy: Single;
begin
  // Should not crash on nil pointers with count=0
  SigmoidF32(nil, nil, 0);
  SoftmaxF32(nil, nil, 0);
  SiLUF32(nil, nil, 0);
  LeakyReLUF32(nil, nil, 0, 0.01);
  TanhF32(nil, nil, 0);
  CheckTrue(True, 'Nil safety passed');
end;

initialization
  RegisterTest(TTestCase_SimdNN);

end.

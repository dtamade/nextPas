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

unit nextpas.core.simd.imageproc.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.exception, nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.errors, nextpas.core.simd,
  nextpas.core.simd.testcase, nextpas.core.simd.base,
  nextpas.core.simd.imageproc;

type
  TTestCase_ImageProc = class(TScalarBackendStatefulTestCase)
  private
    FSrc1: TImage;
    FSrc2: TImage;
    FDest: TImage;
    FPreviousBlendAlphaMode: TImageBlendAlphaMode;

    procedure FillImage(var aImg: TImage; const aValues: array of Byte);
    procedure AssertPixelRGBEquals(const aMessage: string; const aPixel: TVecF32x4;
      aR, aG, aB, aA: Double);
  public
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    procedure Test_ImageAdd_Saturates_Grayscale;
    procedure Test_ImageSubtract_ClampsToZero_Grayscale;
    procedure Test_ImageAdd_SimdChunkBoundary_Grayscale;
    procedure Test_ImageSubtract_SimdChunkBoundary_Grayscale;
    procedure Test_ImageMultiply_Clamps_RGB24;
    procedure Test_ImageMultiply_FactorOne_CopyExact_RGB24;
    procedure Test_ImageMultiply_FactorZero_PreserveAlpha_RGBA32;
    procedure Test_ImageBlend_AlphaHalf_Grayscale;
    procedure Test_ImageBlend_RGBA32_AlphaModes;
    procedure Test_RGBToGrayscale_And_GrayscaleToRGB;
    procedure Test_GetSetPixelRGB_RoundTrip_RGBA32;
    procedure Test_ApplyConvolution3x3_Identity_Grayscale;
    procedure Test_ApplyConvolution3x3_Identity_RGB24;
    procedure Test_ApplyConvolution3x3_InPlace_Equals_OutOfPlace_Grayscale;
    procedure Test_ApplyConvolution3x3_InPlace_Equals_OutOfPlace_RGBA32;
    procedure Test_ApplyBrightness_PreserveAlpha_RGBA32;
    procedure Test_ApplyContrast_PreserveAlpha_RGBA32;
    procedure Test_ApplyGamma_PreserveAlpha_RGBA32;
    procedure Test_ApplyBrightness_ClampNegative_Grayscale;
    procedure Test_ApplyContrast_ZeroToMid_Grayscale;
    procedure Test_ApplyGamma_Invalid_Throws;
    procedure Test_ApplyGaussianBlur_SeparableCenter_Grayscale;
    procedure Test_ImageBlend_AlphaZero_CopySource1_RGB24;
    procedure Test_ImageBlend_AlphaOne_CopySource2_RGB24;
    procedure Test_ImageBlend_AlphaZero_CopySource1_RGBA32_Straight;
    procedure Test_ImageBlend_AlphaOne_CopySource2_RGBA32_Straight;
    procedure Test_ImageBlend_AlphaZero_CopySource1_RGBA32_Premult;
    procedure Test_ImageBlend_AlphaOne_CopySource2_RGBA32_Premult;
    procedure Test_ImageBlend_NonRGBA_Quarter_Grayscale;
    procedure Test_ImageBlend_RGBA32_Premult_Quarter;
    procedure Test_ImageBlend_RGBA32_Straight_OpaqueQuarter;
    procedure Test_ImageBlend_AlphaClamp_LowHigh_RGB24;
    procedure Test_SetPixelRGB_Grayscale_Weighted;
    procedure Test_GetPixelRGB_Grayscale_ReturnsReplicated;
    procedure Test_GetPixelRGB_OutOfRange_Raises;
    procedure Test_SetPixelRGB_OutOfRange_Raises;
    procedure Test_CreateImage_NegativeSize_Raises;
    procedure Test_ImageAdd_Mismatch_Raises;
    procedure Test_ImageBlend_Mismatch_Raises;
    procedure Test_RGBToGrayscale_FromRGBA32;
    procedure Test_GrayscaleToRGB_FullChannelReplication;
    procedure Test_ApplyConvolution3x3_SmallImage_NoChange;
    procedure Test_ApplyConvolution3x3_RGBA_AlphaPreserved;
    procedure Test_ApplyGaussianBlur_RGB24_ConstantInvariant;
    procedure Test_FreeImage_ResetsState;
    procedure Test_ImageMultiply_NegativeFactor_GrayscaleZero;
    procedure Test_ImageMultiply_NegativeFactor_RGBAAlphaPreserved;
    procedure Test_ApplyGamma_Identity_Grayscale;
    procedure Test_ApplyBrightness_ClampHigh_Grayscale;
    procedure Test_ApplyContrast_HighClamp_Grayscale;
    procedure Test_ImageBlend_AlphaHalf_RGB24_Deterministic;
    procedure Test_ImageBlend_AlphaHalf_Grayscale_Deterministic;
    procedure Test_ImageBlend_AlphaHalf_BankersRounding_RGB24;
    procedure Test_ImageBlend_AlphaHalf_BankersRounding_Grayscale;
    procedure Test_ImageBlend_AlphaHalf_LutSemantics_OddEven_Grayscale;
    procedure Test_ApplyBrightness_Zero_NoChange_RGB24;
    procedure Test_ApplyContrast_One_NoChange_Grayscale;
    procedure Test_ApplyGamma_One_NoChange_RGBA32;
    procedure Test_ApplySharpen_ConstantImage_Grayscale_Unchanged;
    procedure Test_ApplySharpen_RGBA_AlphaPreserved;
    procedure Test_ApplyEdgeDetection_ConstantImage_Grayscale_InteriorZero;
    procedure Test_ApplyEdgeDetection_SmallImage_NoChange;
    procedure Test_ApplyBrightness_Contrast_Gamma_RGB24;
  end;

implementation

procedure TTestCase_ImageProc.BeforeEach;
begin
  {{inherited SetUp; -- removed} -- removed}
  FillChar(FSrc1, SizeOf(FSrc1), 0);
  FillChar(FSrc2, SizeOf(FSrc2), 0);
  FillChar(FDest, SizeOf(FDest), 0);
  FPreviousBlendAlphaMode := GetImageBlendAlphaMode;
  SetImageBlendAlphaMode(ibamStraight);
end;

procedure TTestCase_ImageProc.AfterEach;
begin
  SetImageBlendAlphaMode(FPreviousBlendAlphaMode);
  FreeImage(FSrc1);
  FreeImage(FSrc2);
  FreeImage(FDest);
  {{inherited TearDown; -- removed} -- removed}
end;

procedure TTestCase_ImageProc.FillImage(var aImg: TImage; const aValues: array of Byte);
var
  LI: Integer;
  LData: PByte;
begin
  CheckEqual(Length(aValues), aImg.DataSize, 'Image data size mismatch');
  LData := aImg.Data;
  for LI := 0 to High(aValues) do
    LData[LI] := aValues[LI];
end;

procedure TTestCase_ImageProc.AssertPixelRGBEquals(const aMessage: string;
  const aPixel: TVecF32x4; aR, aG, aB, aA: Double);
begin
  CheckNear(aR, Double(aPixel.f[0]), 0.01, aMessage + ' R');
  CheckNear(aG, Double(aPixel.f[1]), 0.01, aMessage + ' G');
  CheckNear(aB, Double(aPixel.f[2]), 0.01, aMessage + ' B');
  CheckNear(aA, Double(aPixel.f[3]), 0.01, aMessage + ' A');
end;

procedure TTestCase_ImageProc.Test_ImageAdd_Saturates_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifGrayscale);
  FSrc2 := CreateImage(2, 1, ifGrayscale);
  FillImage(FSrc1, [200, 10]);
  FillImage(FSrc2, [100, 250]);

  ImageAdd(FDest, FSrc1, FSrc2);

  LData := FDest.Data;
  CheckEqual(255, Integer(LData[0]), 'add[0]');
  CheckEqual(255, Integer(LData[1]), 'add[1]');
end;

procedure TTestCase_ImageProc.Test_ImageSubtract_ClampsToZero_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifGrayscale);
  FSrc2 := CreateImage(2, 1, ifGrayscale);
  FillImage(FSrc1, [30, 240]);
  FillImage(FSrc2, [60, 100]);

  ImageSubtract(FDest, FSrc1, FSrc2);

  LData := FDest.Data;
  CheckEqual(0, Integer(LData[0]), 'sub[0]');
  CheckEqual(140, Integer(LData[1]), 'sub[1]');
end;

procedure TTestCase_ImageProc.Test_ImageAdd_SimdChunkBoundary_Grayscale;
var
  LI: Integer;
  LData1, LData2, LDataDest: PByte;
begin
  FSrc1 := CreateImage(17, 1, ifGrayscale);
  FSrc2 := CreateImage(17, 1, ifGrayscale);

  LData1 := FSrc1.Data;
  LData2 := FSrc2.Data;
  for LI := 0 to 16 do
  begin
    LData1[LI] := 200;
    LData2[LI] := 100;
  end;

  ImageAdd(FDest, FSrc1, FSrc2);

  LDataDest := FDest.Data;
  for LI := 0 to 16 do
    CheckEqual(255, Integer(LDataDest[LI]), 'simd add saturate at ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageSubtract_SimdChunkBoundary_Grayscale;
var
  LI: Integer;
  LData1, LData2, LDataDest: PByte;
begin
  FSrc1 := CreateImage(17, 1, ifGrayscale);
  FSrc2 := CreateImage(17, 1, ifGrayscale);

  LData1 := FSrc1.Data;
  LData2 := FSrc2.Data;
  for LI := 0 to 16 do
  begin
    LData1[LI] := 10;
    LData2[LI] := 100;
  end;

  ImageSubtract(FDest, FSrc1, FSrc2);

  LDataDest := FDest.Data;
  for LI := 0 to 16 do
    CheckEqual(0, Integer(LDataDest[LI]), 'simd sub floor at ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_Clamps_RGB24;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [200, 10, 100]);

  ImageMultiply(FDest, FSrc1, 1.5);

  LData := FDest.Data;
  CheckEqual(255, Integer(LData[0]), 'mul R');
  CheckEqual(15, Integer(LData[1]), 'mul G');
  CheckEqual(150, Integer(LData[2]), 'mul B');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaHalf_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifGrayscale);
  FSrc2 := CreateImage(2, 1, ifGrayscale);
  FillImage(FSrc1, [10, 200]);
  FillImage(FSrc2, [110, 100]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.5);

  LData := FDest.Data;
  CheckEqual(60, Integer(LData[0]), 'blend[0]');
  CheckEqual(150, Integer(LData[1]), 'blend[1]');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_RGBA32_AlphaModes;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [100, 50, 0, 255]);
  FillImage(FSrc2, [0, 200, 100, 128]);

  SetImageBlendAlphaMode(ibamStraight);
  ImageBlend(FDest, FSrc1, FSrc2, 0.5);
  LData := FDest.Data;
  CheckEqual(67, Integer(LData[0]), 'straight R');
  CheckEqual(100, Integer(LData[1]), 'straight G');
  CheckEqual(33, Integer(LData[2]), 'straight B');
  CheckEqual(192, Integer(LData[3]), 'straight A');

  SetImageBlendAlphaMode(ibamPremultiplied);
  ImageBlend(FDest, FSrc1, FSrc2, 0.5);
  LData := FDest.Data;
  CheckEqual(50, Integer(LData[0]), 'premul R');
  CheckEqual(125, Integer(LData[1]), 'premul G');
  CheckEqual(50, Integer(LData[2]), 'premul B');
  CheckEqual(192, Integer(LData[3]), 'premul A');
end;

procedure TTestCase_ImageProc.Test_RGBToGrayscale_And_GrayscaleToRGB;
var
  LGray: PByte;
  LRgb: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [255, 0, 0]);

  RGBToGrayscale(FDest, FSrc1);

  LGray := FDest.Data;
  CheckEqual(54, Integer(LGray[0]), 'gray');

  GrayscaleToRGB(FSrc2, FDest);

  LRgb := FSrc2.Data;
  CheckEqual(54, Integer(LRgb[0]), 'rgb R');
  CheckEqual(54, Integer(LRgb[1]), 'rgb G');
  CheckEqual(54, Integer(LRgb[2]), 'rgb B');
end;

procedure TTestCase_ImageProc.Test_GetSetPixelRGB_RoundTrip_RGBA32;
var
  LInColor: TVecF32x4;
  LOutColor: TVecF32x4;
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);

  LInColor := VecF32x4Zero;
  LInColor.f[0] := 10;
  LInColor.f[1] := 20;
  LInColor.f[2] := 30;
  LInColor.f[3] := 40;

  SetPixelRGB(FSrc1, 0, 0, LInColor);
  LOutColor := GetPixelRGB(FSrc1, 0, 0);

  AssertPixelRGBEquals('roundtrip', LOutColor, 10, 20, 30, 40);

  LData := FSrc1.Data;
  CheckEqual(10, Integer(LData[0]), 'raw R');
  CheckEqual(20, Integer(LData[1]), 'raw G');
  CheckEqual(30, Integer(LData[2]), 'raw B');
  CheckEqual(40, Integer(LData[3]), 'raw A');
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_Identity_Grayscale;
const
  LIdentityKernel: TKernel3x3 = (
    0, 0, 0, 0, 1, 0,
    0, 0, 0
  );
var
  LData: PByte;
begin
  FSrc1 := CreateImage(3, 3, ifGrayscale);
  FillImage(FSrc1, [
    1, 2, 3, 4, 5, 6,
    7, 8, 9
  ]);

  ApplyConvolution3x3(FDest, FSrc1, LIdentityKernel);

  LData := FDest.Data;
  CheckEqual(5, Integer(LData[4]), 'center');
  CheckEqual(1, Integer(LData[0]), 'border top-left');
  CheckEqual(9, Integer(LData[8]), 'border bottom-right');
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_Identity_RGB24;
const
  LIdentityKernel: TKernel3x3 = (
    0, 0, 0, 0, 1, 0,
    0, 0, 0
  );
var
  LData: PByte;
  LCenterBase: Integer;
begin
  FSrc1 := CreateImage(3, 3, ifRGB24);
  FillImage(FSrc1, [
     1,  2,  3,   4,  5,  6,   7,  8,  9, 10, 11, 12,  13, 14, 15,  16, 17, 18,
    19, 20, 21,  22, 23, 24,  25, 26, 27
  ]);

  ApplyConvolution3x3(FDest, FSrc1, LIdentityKernel);

  LData := FDest.Data;
  LCenterBase := (1 * 3 + 1) * 3;
  CheckEqual(13, Integer(LData[LCenterBase + 0]), 'center R');
  CheckEqual(14, Integer(LData[LCenterBase + 1]), 'center G');
  CheckEqual(15, Integer(LData[LCenterBase + 2]), 'center B');
  CheckEqual(1, Integer(LData[0]), 'border R');
  CheckEqual(2, Integer(LData[1]), 'border G');
  CheckEqual(3, Integer(LData[2]), 'border B');
end;


procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_InPlace_Equals_OutOfPlace_Grayscale;
const
  LKernel: TKernel3x3 = (
     0, -1,  0, -1,  5, -1,
     0, -1,  0
  );
var
  LI: Integer;
  LSrcData1: PByte;
  LSrcData2: PByte;
  LOutData: PByte;
begin
  FSrc1 := CreateImage(5, 5, ifGrayscale);
  FSrc2 := CreateImage(5, 5, ifGrayscale);

  LSrcData1 := FSrc1.Data;
  for LI := 0 to FSrc1.DataSize - 1 do
    LSrcData1[LI] := Byte((LI * 17 + 23) mod 256);

  LSrcData2 := FSrc2.Data;
  Move(LSrcData1^, LSrcData2^, FSrc1.DataSize);

  ApplyConvolution3x3(FDest, FSrc1, LKernel);
  ApplyConvolution3x3(FSrc2, FSrc2, LKernel);

  LOutData := FDest.Data;
  for LI := 0 to FDest.DataSize - 1 do
    CheckEqual(Integer(LOutData[LI]), Integer(LSrcData2[LI]), 'conv in-place gray equals out-place ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_InPlace_Equals_OutOfPlace_RGBA32;
const
  LKernel: TKernel3x3 = (
    1 / 16, 2 / 16, 1 / 16, 2 / 16, 4 / 16, 2 / 16,
    1 / 16, 2 / 16, 1 / 16
  );
var
  LI: Integer;
  LSrcData1: PByte;
  LSrcData2: PByte;
  LOutData: PByte;
begin
  FSrc1 := CreateImage(5, 5, ifRGBA32);
  FSrc2 := CreateImage(5, 5, ifRGBA32);

  LSrcData1 := FSrc1.Data;
  for LI := 0 to FSrc1.Width * FSrc1.Height - 1 do
  begin
    LSrcData1[LI * 4 + 0] := Byte((LI * 13 + 3) mod 256);
    LSrcData1[LI * 4 + 1] := Byte((LI * 29 + 5) mod 256);
    LSrcData1[LI * 4 + 2] := Byte((LI * 47 + 7) mod 256);
    LSrcData1[LI * 4 + 3] := Byte((LI * 11 + 9) mod 256);
  end;

  LSrcData2 := FSrc2.Data;
  Move(LSrcData1^, LSrcData2^, FSrc1.DataSize);

  ApplyConvolution3x3(FDest, FSrc1, LKernel);
  ApplyConvolution3x3(FSrc2, FSrc2, LKernel);

  LOutData := FDest.Data;
  for LI := 0 to FDest.DataSize - 1 do
    CheckEqual(Integer(LOutData[LI]), Integer(LSrcData2[LI]), 'conv in-place rgba equals out-place ' + IntToStr(LI));
end;
procedure TTestCase_ImageProc.Test_ApplyGaussianBlur_SeparableCenter_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(3, 3, ifGrayscale);
  FillImage(FSrc1, [
    0,   0, 0, 0, 255, 0,
    0,   0, 0
  ]);

  ApplyGaussianBlur(FDest, FSrc1);

  LData := FDest.Data;
  CheckEqual(64, Integer(LData[4]), 'gaussian center');
  CheckEqual(0, Integer(LData[0]), 'gaussian border unchanged');
end;

procedure TTestCase_ImageProc.Test_ApplyBrightness_Contrast_Gamma_RGB24;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [100, 120, 140]);

  ApplyBrightness(FSrc1, 20.0);
  ApplyContrast(FSrc1, 1.0);
  ApplyGamma(FSrc1, 1.0);

  LData := FSrc1.Data;
  CheckEqual(120, Integer(LData[0]), 'post R');
  CheckEqual(140, Integer(LData[1]), 'post G');
  CheckEqual(160, Integer(LData[2]), 'post B');
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_FactorOne_CopyExact_RGB24;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifRGB24);
  FillImage(FSrc1, [1, 2, 3, 4, 5, 6]);

  ImageMultiply(FDest, FSrc1, 1.0);

  LData := FDest.Data;
  for LI := 0 to 5 do
    CheckEqual(Integer(FSrc1.Data[LI]), Integer(LData[LI]), 'mul x1 copy ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_FactorZero_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 77]);

  ImageMultiply(FDest, FSrc1, 0.0);

  LData := FDest.Data;
  CheckEqual(0, Integer(LData[0]), 'mul0 R');
  CheckEqual(0, Integer(LData[1]), 'mul0 G');
  CheckEqual(0, Integer(LData[2]), 'mul0 B');
  CheckEqual(77, Integer(LData[3]), 'mul0 A preserve');
end;

procedure TTestCase_ImageProc.Test_ApplyBrightness_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [100, 100, 100, 66]);

  ApplyBrightness(FSrc1, 30.0);

  LData := FSrc1.Data;
  CheckEqual(130, Integer(LData[0]), 'brightness R');
  CheckEqual(130, Integer(LData[1]), 'brightness G');
  CheckEqual(130, Integer(LData[2]), 'brightness B');
  CheckEqual(66, Integer(LData[3]), 'brightness A preserve');
end;

procedure TTestCase_ImageProc.Test_ApplyContrast_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [130, 128, 126, 77]);

  ApplyContrast(FSrc1, 1.5);

  LData := FSrc1.Data;
  CheckEqual(131, Integer(LData[0]), 'contrast R');
  CheckEqual(128, Integer(LData[1]), 'contrast G');
  CheckEqual(125, Integer(LData[2]), 'contrast B');
  CheckEqual(77, Integer(LData[3]), 'contrast A preserve');
end;

procedure TTestCase_ImageProc.Test_ApplyGamma_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [64, 128, 255, 42]);

  ApplyGamma(FSrc1, 2.0);

  LData := FSrc1.Data;
  CheckEqual(128, Integer(LData[0]), 'gamma R');
  CheckEqual(181, Integer(LData[1]), 'gamma G');
  CheckEqual(255, Integer(LData[2]), 'gamma B');
  CheckEqual(42, Integer(LData[3]), 'gamma A preserve');
end;

procedure TTestCase_ImageProc.Test_ApplyBrightness_ClampNegative_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [10]);

  ApplyBrightness(FSrc1, -30.0);

  LData := FSrc1.Data;
  CheckEqual(0, Integer(LData[0]), 'brightness clamp negative');
end;

procedure TTestCase_ImageProc.Test_ApplyContrast_ZeroToMid_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [10]);

  ApplyContrast(FSrc1, 0.0);

  LData := FSrc1.Data;
  CheckEqual(128, Integer(LData[0]), 'contrast zero to 128');
end;

procedure TTestCase_ImageProc.Test_ApplyGamma_Invalid_Throws;
var
  LRaised: Boolean;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [10]);

  LRaised := False;
  try
    ApplyGamma(FSrc1, 0.0);
  except
    on EArgumentError do
      LRaised := True;
  end;

  CheckTrue(LRaised, 'gamma <= 0 should raise');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaZero_CopySource1_RGB24;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifRGB24);
  FSrc2 := CreateImage(2, 1, ifRGB24);
  FillImage(FSrc1, [1, 2, 3, 4, 5, 6]);
  FillImage(FSrc2, [7, 8, 9, 10, 11, 12]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.0);

  LData := FDest.Data;
  for LI := 0 to 5 do
    CheckEqual(Integer(FSrc1.Data[LI]), Integer(LData[LI]), 'blend alpha0 copy src1 ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaOne_CopySource2_RGB24;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifRGB24);
  FSrc2 := CreateImage(2, 1, ifRGB24);
  FillImage(FSrc1, [1, 2, 3, 4, 5, 6]);
  FillImage(FSrc2, [7, 8, 9, 10, 11, 12]);

  ImageBlend(FDest, FSrc1, FSrc2, 1.0);

  LData := FDest.Data;
  for LI := 0 to 5 do
    CheckEqual(Integer(FSrc2.Data[LI]), Integer(LData[LI]), 'blend alpha1 copy src2 ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaZero_CopySource1_RGBA32_Straight;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 40]);
  FillImage(FSrc2, [100, 110, 120, 130]);

  SetImageBlendAlphaMode(ibamStraight);
  ImageBlend(FDest, FSrc1, FSrc2, 0.0);

  LData := FDest.Data;
  for LI := 0 to 3 do
    CheckEqual(Integer(FSrc1.Data[LI]), Integer(LData[LI]), 'rgba straight alpha0 copy src1 ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaOne_CopySource2_RGBA32_Straight;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 40]);
  FillImage(FSrc2, [100, 110, 120, 130]);

  SetImageBlendAlphaMode(ibamStraight);
  ImageBlend(FDest, FSrc1, FSrc2, 1.0);

  LData := FDest.Data;
  for LI := 0 to 3 do
    CheckEqual(Integer(FSrc2.Data[LI]), Integer(LData[LI]), 'rgba straight alpha1 copy src2 ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaZero_CopySource1_RGBA32_Premult;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 40]);
  FillImage(FSrc2, [100, 110, 120, 130]);

  SetImageBlendAlphaMode(ibamPremultiplied);
  ImageBlend(FDest, FSrc1, FSrc2, 0.0);

  LData := FDest.Data;
  for LI := 0 to 3 do
    CheckEqual(Integer(FSrc1.Data[LI]), Integer(LData[LI]), 'rgba premult alpha0 copy src1 ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaOne_CopySource2_RGBA32_Premult;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 40]);
  FillImage(FSrc2, [100, 110, 120, 130]);

  SetImageBlendAlphaMode(ibamPremultiplied);
  ImageBlend(FDest, FSrc1, FSrc2, 1.0);

  LData := FDest.Data;
  for LI := 0 to 3 do
    CheckEqual(Integer(FSrc2.Data[LI]), Integer(LData[LI]), 'rgba premult alpha1 copy src2 ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ImageBlend_NonRGBA_Quarter_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FSrc2 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [20]);
  FillImage(FSrc2, [220]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.25);

  LData := FDest.Data;
  CheckEqual(70, Integer(LData[0]), 'blend quarter gray');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_RGBA32_Premult_Quarter;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [100, 50, 0, 200]);
  FillImage(FSrc2, [20, 200, 100, 100]);

  SetImageBlendAlphaMode(ibamPremultiplied);
  ImageBlend(FDest, FSrc1, FSrc2, 0.25);

  LData := FDest.Data;
  CheckEqual(80, Integer(LData[0]), 'premult quarter R');
  CheckEqual(88, Integer(LData[1]), 'premult quarter G');
  CheckEqual(25, Integer(LData[2]), 'premult quarter B');
  CheckEqual(175, Integer(LData[3]), 'premult quarter A');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_RGBA32_Straight_OpaqueQuarter;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [100, 50, 0, 255]);
  FillImage(FSrc2, [20, 200, 100, 255]);

  SetImageBlendAlphaMode(ibamStraight);
  ImageBlend(FDest, FSrc1, FSrc2, 0.25);

  LData := FDest.Data;
  CheckEqual(80, Integer(LData[0]), 'straight opaque quarter R');
  CheckEqual(88, Integer(LData[1]), 'straight opaque quarter G');
  CheckEqual(25, Integer(LData[2]), 'straight opaque quarter B');
  CheckEqual(255, Integer(LData[3]), 'straight opaque quarter A');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaClamp_LowHigh_RGB24;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifRGB24);
  FSrc2 := CreateImage(2, 1, ifRGB24);
  FillImage(FSrc1, [1, 2, 3, 4, 5, 6]);
  FillImage(FSrc2, [7, 8, 9, 10, 11, 12]);

  ImageBlend(FDest, FSrc1, FSrc2, -2.0);
  LData := FDest.Data;
  for LI := 0 to 5 do
    CheckEqual(Integer(FSrc1.Data[LI]), Integer(LData[LI]), 'blend clamp low ' + IntToStr(LI));

  ImageBlend(FDest, FSrc1, FSrc2, 3.0);
  LData := FDest.Data;
  for LI := 0 to 5 do
    CheckEqual(Integer(FSrc2.Data[LI]), Integer(LData[LI]), 'blend clamp high ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_SetPixelRGB_Grayscale_Weighted;
var
  LColor: TVecF32x4;
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);

  LColor := VecF32x4Zero;
  LColor.f[0] := 255;
  LColor.f[1] := 0;
  LColor.f[2] := 0;
  LColor.f[3] := 77;

  SetPixelRGB(FSrc1, 0, 0, LColor);

  LData := FSrc1.Data;
  CheckEqual(54, Integer(LData[0]), 'weighted grayscale from red');
end;

procedure TTestCase_ImageProc.Test_GetPixelRGB_Grayscale_ReturnsReplicated;
var
  LPixel: TVecF32x4;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [123]);

  LPixel := GetPixelRGB(FSrc1, 0, 0);
  AssertPixelRGBEquals('gray replicated', LPixel, 123, 123, 123, 255);
end;

procedure TTestCase_ImageProc.Test_GetPixelRGB_OutOfRange_Raises;
var
  LRaised: Boolean;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [1, 2, 3]);

  LRaised := False;
  try
    GetPixelRGB(FSrc1, 1, 0);
  except
    on EArgumentError do
      LRaised := True;
  end;

  CheckTrue(LRaised, 'get pixel out of range should raise');
end;

procedure TTestCase_ImageProc.Test_SetPixelRGB_OutOfRange_Raises;
var
  LRaised: Boolean;
  LColor: TVecF32x4;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [1, 2, 3]);

  LColor := VecF32x4Zero;
  LColor.f[0] := 10;
  LColor.f[1] := 20;
  LColor.f[2] := 30;
  LColor.f[3] := 255;

  LRaised := False;
  try
    SetPixelRGB(FSrc1, 0, 1, LColor);
  except
    on EArgumentError do
      LRaised := True;
  end;

  CheckTrue(LRaised, 'set pixel out of range should raise');
end;

procedure TTestCase_ImageProc.Test_CreateImage_NegativeSize_Raises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    FSrc1 := CreateImage(-1, 1, ifRGB24);
  except
    on EArgumentError do
      LRaised := True;
  end;

  CheckTrue(LRaised, 'negative size should raise');
end;

procedure TTestCase_ImageProc.Test_ImageAdd_Mismatch_Raises;
var
  LRaised: Boolean;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FSrc2 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [1, 2, 3]);
  FillImage(FSrc2, [9]);

  LRaised := False;
  try
    ImageAdd(FDest, FSrc1, FSrc2);
  except
    on Exception do
      LRaised := True;
  end;

  CheckTrue(LRaised, 'image add mismatch should raise');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_Mismatch_Raises;
var
  LRaised: Boolean;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FSrc2 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [1, 2, 3, 4]);
  FillImage(FSrc2, [5, 6, 7]);

  LRaised := False;
  try
    ImageBlend(FDest, FSrc1, FSrc2, 0.5);
  except
    on Exception do
      LRaised := True;
  end;

  CheckTrue(LRaised, 'image blend mismatch should raise');
end;

procedure TTestCase_ImageProc.Test_RGBToGrayscale_FromRGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 240]);

  RGBToGrayscale(FDest, FSrc1);

  LData := FDest.Data;
  CheckEqual(19, Integer(LData[0]), 'rgba to gray');
end;

procedure TTestCase_ImageProc.Test_GrayscaleToRGB_FullChannelReplication;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifGrayscale);
  FillImage(FSrc1, [5, 200]);

  GrayscaleToRGB(FDest, FSrc1);

  LData := FDest.Data;
  CheckEqual(5, Integer(LData[0]), 'pixel0 r');
  CheckEqual(5, Integer(LData[1]), 'pixel0 g');
  CheckEqual(5, Integer(LData[2]), 'pixel0 b');
  CheckEqual(200, Integer(LData[3]), 'pixel1 r');
  CheckEqual(200, Integer(LData[4]), 'pixel1 g');
  CheckEqual(200, Integer(LData[5]), 'pixel1 b');
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_SmallImage_NoChange;
const
  LKernel: TKernel3x3 = (
    1, 2, 1, 2, 4, 2,
    1, 2, 1
  );
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 2, ifGrayscale);
  FillImage(FSrc1, [1, 2, 3, 4]);

  ApplyConvolution3x3(FDest, FSrc1, LKernel);

  LData := FDest.Data;
  for LI := 0 to 3 do
    CheckEqual(Integer(FSrc1.Data[LI]), Integer(LData[LI]), 'small image no change ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_RGBA_AlphaPreserved;
const
  LKernel: TKernel3x3 = (
    0, 0, 0, 0, 1, 0,
    0, 0, 0
  );
var
  LI: Integer;
  LBase: Integer;
  LSrcData: PByte;
  LDestData: PByte;
begin
  FSrc1 := CreateImage(3, 3, ifRGBA32);
  LSrcData := FSrc1.Data;

  for LI := 0 to 8 do
  begin
    LBase := LI * 4;
    LSrcData[LBase + 0] := Byte(LI * 10);
    LSrcData[LBase + 1] := Byte(LI * 10 + 1);
    LSrcData[LBase + 2] := Byte(LI * 10 + 2);
    LSrcData[LBase + 3] := Byte(20 + LI);
  end;

  ApplyConvolution3x3(FDest, FSrc1, LKernel);

  LDestData := FDest.Data;
  for LI := 0 to 8 do
  begin
    LBase := LI * 4;
    CheckEqual(Integer(LSrcData[LBase + 3]), Integer(LDestData[LBase + 3]), 'rgba conv alpha preserve ' + IntToStr(LI));
  end;
end;

procedure TTestCase_ImageProc.Test_ApplyGaussianBlur_RGB24_ConstantInvariant;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(4, 4, ifRGB24);
  LData := FSrc1.Data;

  for LI := 0 to FSrc1.Width * FSrc1.Height - 1 do
  begin
    LData[LI * 3 + 0] := 77;
    LData[LI * 3 + 1] := 88;
    LData[LI * 3 + 2] := 99;
  end;

  ApplyGaussianBlur(FDest, FSrc1);

  LData := FDest.Data;
  for LI := 0 to FDest.Width * FDest.Height - 1 do
  begin
    CheckEqual(77, Integer(LData[LI * 3 + 0]), 'gaussian constant r ' + IntToStr(LI));
    CheckEqual(88, Integer(LData[LI * 3 + 1]), 'gaussian constant g ' + IntToStr(LI));
    CheckEqual(99, Integer(LData[LI * 3 + 2]), 'gaussian constant b ' + IntToStr(LI));
  end;
end;

procedure TTestCase_ImageProc.Test_FreeImage_ResetsState;
begin
  FSrc1 := CreateImage(2, 1, ifRGBA32);
  FillImage(FSrc1, [1, 2, 3, 4, 5, 6, 7, 8]);

  FreeImage(FSrc1);

  CheckEqual(0, FSrc1.Width, 'free width');
  CheckEqual(0, FSrc1.Height, 'free height');
  CheckEqual(0, FSrc1.DataSize, 'free data size');
  CheckTrue(FSrc1.Data = nil, 'free data nil');
  CheckEqual(Integer(ifRGB24), Integer(FSrc1.Format), 'free format reset');
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_NegativeFactor_GrayscaleZero;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifGrayscale);
  FillImage(FSrc1, [10, 200]);

  ImageMultiply(FDest, FSrc1, -1.0);

  LData := FDest.Data;
  CheckEqual(0, Integer(LData[0]), 'mul negative gray 0');
  CheckEqual(0, Integer(LData[1]), 'mul negative gray 1');
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_NegativeFactor_RGBAAlphaPreserved;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 40, 200, 210, 220, 230]);

  ImageMultiply(FDest, FSrc1, -0.25);

  LData := FDest.Data;
  CheckEqual(0, Integer(LData[0]), 'mul negative rgba p0 r');
  CheckEqual(0, Integer(LData[1]), 'mul negative rgba p0 g');
  CheckEqual(0, Integer(LData[2]), 'mul negative rgba p0 b');
  CheckEqual(40, Integer(LData[3]), 'mul negative rgba p0 a');
  CheckEqual(0, Integer(LData[4]), 'mul negative rgba p1 r');
  CheckEqual(0, Integer(LData[5]), 'mul negative rgba p1 g');
  CheckEqual(0, Integer(LData[6]), 'mul negative rgba p1 b');
  CheckEqual(230, Integer(LData[7]), 'mul negative rgba p1 a');
end;

procedure TTestCase_ImageProc.Test_ApplyGamma_Identity_Grayscale;
var
  LI: Integer;
  LData: PByte;
  LExpect: array[0..3] of Byte;
begin
  FSrc1 := CreateImage(4, 1, ifGrayscale);
  FillImage(FSrc1, [0, 64, 128, 255]);

  LExpect[0] := 0;
  LExpect[1] := 64;
  LExpect[2] := 128;
  LExpect[3] := 255;

  ApplyGamma(FSrc1, 1.0);

  LData := FSrc1.Data;
  for LI := 0 to 3 do
    CheckEqual(Integer(LExpect[LI]), Integer(LData[LI]), 'gamma identity gray ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ApplyBrightness_ClampHigh_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [250]);

  ApplyBrightness(FSrc1, 20.0);

  LData := FSrc1.Data;
  CheckEqual(255, Integer(LData[0]), 'brightness clamp high');
end;

procedure TTestCase_ImageProc.Test_ApplyContrast_HighClamp_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [250]);

  ApplyContrast(FSrc1, 2.0);

  LData := FSrc1.Data;
  CheckEqual(255, Integer(LData[0]), 'contrast high clamp');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaHalf_RGB24_Deterministic;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FSrc2 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [11, 21, 31]);
  FillImage(FSrc2, [109, 119, 129]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.5);

  LData := FDest.Data;
  CheckEqual(60, Integer(LData[0]), 'blend half rgb deterministic r');
  CheckEqual(70, Integer(LData[1]), 'blend half rgb deterministic g');
  CheckEqual(80, Integer(LData[2]), 'blend half rgb deterministic b');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaHalf_Grayscale_Deterministic;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FSrc2 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [11]);
  FillImage(FSrc2, [109]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.5);

  LData := FDest.Data;
  CheckEqual(60, Integer(LData[0]), 'blend half gray deterministic');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaHalf_BankersRounding_RGB24;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FSrc2 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [1, 3, 5]);
  FillImage(FSrc2, [1, 3, 5]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.5);

  LData := FDest.Data;
  CheckEqual(0, Integer(LData[0]), 'blend half bankers rgb r');
  CheckEqual(4, Integer(LData[1]), 'blend half bankers rgb g');
  CheckEqual(4, Integer(LData[2]), 'blend half bankers rgb b');
end;

procedure TTestCase_ImageProc.Test_ImageBlend_AlphaHalf_BankersRounding_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FSrc2 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [1]);
  FillImage(FSrc2, [1]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.5);

  LData := FDest.Data;
  CheckEqual(0, Integer(LData[0]), 'blend half bankers gray');
end;


procedure TTestCase_ImageProc.Test_ImageBlend_AlphaHalf_LutSemantics_OddEven_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FSrc2 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [1]);
  FillImage(FSrc2, [2]);

  ImageBlend(FDest, FSrc1, FSrc2, 0.5);

  LData := FDest.Data;
  CheckEqual(1, Integer(LData[0]), 'blend half lut odd-even gray');
end;
procedure TTestCase_ImageProc.Test_ApplyBrightness_Zero_NoChange_RGB24;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 2, ifRGB24);
  FillImage(FSrc1, [1, 2, 3, 100, 150, 200]);

  ApplyBrightness(FSrc1, 0.0);

  LData := FSrc1.Data;
  CheckEqual(1, Integer(LData[0]), 'brightness zero r0');
  CheckEqual(2, Integer(LData[1]), 'brightness zero g0');
  CheckEqual(3, Integer(LData[2]), 'brightness zero b0');
  for LI := 3 to 5 do
    CheckTrue(LData[LI] > 0, 'brightness zero keep tail ' + IntToStr(LI));
  CheckEqual(100, Integer(LData[3]), 'brightness zero r1');
  CheckEqual(150, Integer(LData[4]), 'brightness zero g1');
  CheckEqual(200, Integer(LData[5]), 'brightness zero b1');
end;

procedure TTestCase_ImageProc.Test_ApplyContrast_One_NoChange_Grayscale;
var
  LI: Integer;
  LData: PByte;
  LExpect: array[0..2] of Byte;
begin
  FSrc1 := CreateImage(3, 1, ifGrayscale);
  FillImage(FSrc1, [5, 128, 250]);

  LExpect[0] := 5;
  LExpect[1] := 128;
  LExpect[2] := 250;

  ApplyContrast(FSrc1, 1.0);

  LData := FSrc1.Data;
  for LI := 0 to 2 do
    CheckEqual(Integer(LExpect[LI]), Integer(LData[LI]), 'contrast one keep gray ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ApplyGamma_One_NoChange_RGBA32;
var
  LI: Integer;
  LData: PByte;
  LExpect: array[0..3] of Byte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 60, 250, 33]);

  LExpect[0] := 10;
  LExpect[1] := 60;
  LExpect[2] := 250;
  LExpect[3] := 33;

  ApplyGamma(FSrc1, 1.0);

  LData := FSrc1.Data;
  for LI := 0 to 3 do
    CheckEqual(Integer(LExpect[LI]), Integer(LData[LI]), 'gamma one keep rgba ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ApplySharpen_ConstantImage_Grayscale_Unchanged;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(4, 4, ifGrayscale);
  LData := FSrc1.Data;
  for LI := 0 to FSrc1.DataSize - 1 do
    LData[LI] := 77;

  ApplySharpen(FDest, FSrc1);

  LData := FDest.Data;
  for LI := 0 to FDest.DataSize - 1 do
    CheckEqual(77, Integer(LData[LI]), 'sharpen constant gray keep ' + IntToStr(LI));
end;

procedure TTestCase_ImageProc.Test_ApplySharpen_RGBA_AlphaPreserved;
var
  LI: Integer;
  LBase: Integer;
  LSrcData: PByte;
  LDestData: PByte;
begin
  FSrc1 := CreateImage(3, 3, ifRGBA32);
  LSrcData := FSrc1.Data;

  for LI := 0 to 8 do
  begin
    LBase := LI * 4;
    LSrcData[LBase + 0] := Byte(10 + LI);
    LSrcData[LBase + 1] := Byte(40 + LI);
    LSrcData[LBase + 2] := Byte(80 + LI);
    LSrcData[LBase + 3] := Byte(100 + LI);
  end;

  ApplySharpen(FDest, FSrc1);

  LDestData := FDest.Data;
  for LI := 0 to 8 do
  begin
    LBase := LI * 4;
    CheckEqual(Integer(LSrcData[LBase + 3]), Integer(LDestData[LBase + 3]), 'sharpen rgba alpha preserve ' + IntToStr(LI));
  end;
end;

procedure TTestCase_ImageProc.Test_ApplyEdgeDetection_ConstantImage_Grayscale_InteriorZero;
var
  LX: Integer;
  LY: Integer;
  LIndex: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(5, 5, ifGrayscale);
  LData := FSrc1.Data;
  for LIndex := 0 to FSrc1.DataSize - 1 do
    LData[LIndex] := 100;

  ApplyEdgeDetection(FDest, FSrc1);

  LData := FDest.Data;
  for LY := 0 to FDest.Height - 1 do
  begin
    for LX := 0 to FDest.Width - 1 do
    begin
      LIndex := LY * FDest.Width + LX;
      if (LX = 0) or (LY = 0) or (LX = FDest.Width - 1) or (LY = FDest.Height - 1) then
        CheckEqual(100, Integer(LData[LIndex]), 'edge constant border keep ' + IntToStr(LIndex))
      else
        CheckEqual(0, Integer(LData[LIndex]), 'edge constant interior zero ' + IntToStr(LIndex));
    end;
  end;
end;

procedure TTestCase_ImageProc.Test_ApplyEdgeDetection_SmallImage_NoChange;
var
  LI: Integer;
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 2, ifRGB24);
  FillImage(FSrc1, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);

  ApplyEdgeDetection(FDest, FSrc1);

  LData := FDest.Data;
  for LI := 0 to FDest.DataSize - 1 do
    CheckEqual(Integer(FSrc1.Data[LI]), Integer(LData[LI]), 'edge small image no change ' + IntToStr(LI));
end;

end.
unit nextpas.core.simd.imageproc.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}

interface

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  fpcunit,
  testregistry,
  nextpas.core.errors,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
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
  protected
    procedure SetUp; override;
    procedure TearDown; override;
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

procedure TTestCase_ImageProc.SetUp;
begin
  inherited SetUp;
  FillChar(FSrc1, SizeOf(FSrc1), 0);
  FillChar(FSrc2, SizeOf(FSrc2), 0);
  FillChar(FDest, SizeOf(FDest), 0);
  FPreviousBlendAlphaMode := GetImageBlendAlphaMode;
  SetImageBlendAlphaMode(ibamStraight);
end;

procedure TTestCase_ImageProc.TearDown;
begin
  SetImageBlendAlphaMode(FPreviousBlendAlphaMode);
  FreeImage(FSrc1);
  FreeImage(FSrc2);
  FreeImage(FDest);
  inherited TearDown;
end;

procedure TTestCase_ImageProc.FillImage(var aImg: TImage; const aValues: array of Byte);
var
  LI: Integer;
  LData: PByte;
begin
  AssertEquals('Image data size mismatch', Length(aValues), aImg.DataSize);
  LData := aImg.Data;
  for LI := 0 to High(aValues) do
    LData[LI] := aValues[LI];
end;

procedure TTestCase_ImageProc.AssertPixelRGBEquals(const aMessage: string;
  const aPixel: TVecF32x4; aR, aG, aB, aA: Double);
begin
  AssertEquals(aMessage + ' R', aR, Double(aPixel.f[0]), 0.01);
  AssertEquals(aMessage + ' G', aG, Double(aPixel.f[1]), 0.01);
  AssertEquals(aMessage + ' B', aB, Double(aPixel.f[2]), 0.01);
  AssertEquals(aMessage + ' A', aA, Double(aPixel.f[3]), 0.01);
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
  AssertEquals('add[0]', 255, Integer(LData[0]));
  AssertEquals('add[1]', 255, Integer(LData[1]));
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
  AssertEquals('sub[0]', 0, Integer(LData[0]));
  AssertEquals('sub[1]', 140, Integer(LData[1]));
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
    AssertEquals('simd add saturate at ' + IntToStr(LI), 255, Integer(LDataDest[LI]));
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
    AssertEquals('simd sub floor at ' + IntToStr(LI), 0, Integer(LDataDest[LI]));
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_Clamps_RGB24;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGB24);
  FillImage(FSrc1, [200, 10, 100]);

  ImageMultiply(FDest, FSrc1, 1.5);

  LData := FDest.Data;
  AssertEquals('mul R', 255, Integer(LData[0]));
  AssertEquals('mul G', 15, Integer(LData[1]));
  AssertEquals('mul B', 150, Integer(LData[2]));
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
  AssertEquals('blend[0]', 60, Integer(LData[0]));
  AssertEquals('blend[1]', 150, Integer(LData[1]));
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
  AssertEquals('straight R', 67, Integer(LData[0]));
  AssertEquals('straight G', 100, Integer(LData[1]));
  AssertEquals('straight B', 33, Integer(LData[2]));
  AssertEquals('straight A', 192, Integer(LData[3]));

  SetImageBlendAlphaMode(ibamPremultiplied);
  ImageBlend(FDest, FSrc1, FSrc2, 0.5);
  LData := FDest.Data;
  AssertEquals('premul R', 50, Integer(LData[0]));
  AssertEquals('premul G', 125, Integer(LData[1]));
  AssertEquals('premul B', 50, Integer(LData[2]));
  AssertEquals('premul A', 192, Integer(LData[3]));
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
  AssertEquals('gray', 54, Integer(LGray[0]));

  GrayscaleToRGB(FSrc2, FDest);

  LRgb := FSrc2.Data;
  AssertEquals('rgb R', 54, Integer(LRgb[0]));
  AssertEquals('rgb G', 54, Integer(LRgb[1]));
  AssertEquals('rgb B', 54, Integer(LRgb[2]));
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
  AssertEquals('raw R', 10, Integer(LData[0]));
  AssertEquals('raw G', 20, Integer(LData[1]));
  AssertEquals('raw B', 30, Integer(LData[2]));
  AssertEquals('raw A', 40, Integer(LData[3]));
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_Identity_Grayscale;
const
  LIdentityKernel: TKernel3x3 = (
    0, 0, 0,
    0, 1, 0,
    0, 0, 0
  );
var
  LData: PByte;
begin
  FSrc1 := CreateImage(3, 3, ifGrayscale);
  FillImage(FSrc1, [
    1, 2, 3,
    4, 5, 6,
    7, 8, 9
  ]);

  ApplyConvolution3x3(FDest, FSrc1, LIdentityKernel);

  LData := FDest.Data;
  AssertEquals('center', 5, Integer(LData[4]));
  AssertEquals('border top-left', 1, Integer(LData[0]));
  AssertEquals('border bottom-right', 9, Integer(LData[8]));
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_Identity_RGB24;
const
  LIdentityKernel: TKernel3x3 = (
    0, 0, 0,
    0, 1, 0,
    0, 0, 0
  );
var
  LData: PByte;
  LCenterBase: Integer;
begin
  FSrc1 := CreateImage(3, 3, ifRGB24);
  FillImage(FSrc1, [
     1,  2,  3,   4,  5,  6,   7,  8,  9,
    10, 11, 12,  13, 14, 15,  16, 17, 18,
    19, 20, 21,  22, 23, 24,  25, 26, 27
  ]);

  ApplyConvolution3x3(FDest, FSrc1, LIdentityKernel);

  LData := FDest.Data;
  LCenterBase := (1 * 3 + 1) * 3;
  AssertEquals('center R', 13, Integer(LData[LCenterBase + 0]));
  AssertEquals('center G', 14, Integer(LData[LCenterBase + 1]));
  AssertEquals('center B', 15, Integer(LData[LCenterBase + 2]));
  AssertEquals('border R', 1, Integer(LData[0]));
  AssertEquals('border G', 2, Integer(LData[1]));
  AssertEquals('border B', 3, Integer(LData[2]));
end;


procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_InPlace_Equals_OutOfPlace_Grayscale;
const
  LKernel: TKernel3x3 = (
     0, -1,  0,
    -1,  5, -1,
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
    AssertEquals('conv in-place gray equals out-place ' + IntToStr(LI),
      Integer(LOutData[LI]), Integer(LSrcData2[LI]));
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_InPlace_Equals_OutOfPlace_RGBA32;
const
  LKernel: TKernel3x3 = (
    1 / 16, 2 / 16, 1 / 16,
    2 / 16, 4 / 16, 2 / 16,
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
    AssertEquals('conv in-place rgba equals out-place ' + IntToStr(LI),
      Integer(LOutData[LI]), Integer(LSrcData2[LI]));
end;
procedure TTestCase_ImageProc.Test_ApplyGaussianBlur_SeparableCenter_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(3, 3, ifGrayscale);
  FillImage(FSrc1, [
    0,   0, 0,
    0, 255, 0,
    0,   0, 0
  ]);

  ApplyGaussianBlur(FDest, FSrc1);

  LData := FDest.Data;
  AssertEquals('gaussian center', 64, Integer(LData[4]));
  AssertEquals('gaussian border unchanged', 0, Integer(LData[0]));
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
  AssertEquals('post R', 120, Integer(LData[0]));
  AssertEquals('post G', 140, Integer(LData[1]));
  AssertEquals('post B', 160, Integer(LData[2]));
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
    AssertEquals('mul x1 copy ' + IntToStr(LI), Integer(FSrc1.Data[LI]), Integer(LData[LI]));
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_FactorZero_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 77]);

  ImageMultiply(FDest, FSrc1, 0.0);

  LData := FDest.Data;
  AssertEquals('mul0 R', 0, Integer(LData[0]));
  AssertEquals('mul0 G', 0, Integer(LData[1]));
  AssertEquals('mul0 B', 0, Integer(LData[2]));
  AssertEquals('mul0 A preserve', 77, Integer(LData[3]));
end;

procedure TTestCase_ImageProc.Test_ApplyBrightness_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [100, 100, 100, 66]);

  ApplyBrightness(FSrc1, 30.0);

  LData := FSrc1.Data;
  AssertEquals('brightness R', 130, Integer(LData[0]));
  AssertEquals('brightness G', 130, Integer(LData[1]));
  AssertEquals('brightness B', 130, Integer(LData[2]));
  AssertEquals('brightness A preserve', 66, Integer(LData[3]));
end;

procedure TTestCase_ImageProc.Test_ApplyContrast_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [130, 128, 126, 77]);

  ApplyContrast(FSrc1, 1.5);

  LData := FSrc1.Data;
  AssertEquals('contrast R', 131, Integer(LData[0]));
  AssertEquals('contrast G', 128, Integer(LData[1]));
  AssertEquals('contrast B', 125, Integer(LData[2]));
  AssertEquals('contrast A preserve', 77, Integer(LData[3]));
end;

procedure TTestCase_ImageProc.Test_ApplyGamma_PreserveAlpha_RGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [64, 128, 255, 42]);

  ApplyGamma(FSrc1, 2.0);

  LData := FSrc1.Data;
  AssertEquals('gamma R', 128, Integer(LData[0]));
  AssertEquals('gamma G', 181, Integer(LData[1]));
  AssertEquals('gamma B', 255, Integer(LData[2]));
  AssertEquals('gamma A preserve', 42, Integer(LData[3]));
end;

procedure TTestCase_ImageProc.Test_ApplyBrightness_ClampNegative_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [10]);

  ApplyBrightness(FSrc1, -30.0);

  LData := FSrc1.Data;
  AssertEquals('brightness clamp negative', 0, Integer(LData[0]));
end;

procedure TTestCase_ImageProc.Test_ApplyContrast_ZeroToMid_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [10]);

  ApplyContrast(FSrc1, 0.0);

  LData := FSrc1.Data;
  AssertEquals('contrast zero to 128', 128, Integer(LData[0]));
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

  AssertTrue('gamma <= 0 should raise', LRaised);
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
    AssertEquals('blend alpha0 copy src1 ' + IntToStr(LI), Integer(FSrc1.Data[LI]), Integer(LData[LI]));
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
    AssertEquals('blend alpha1 copy src2 ' + IntToStr(LI), Integer(FSrc2.Data[LI]), Integer(LData[LI]));
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
    AssertEquals('rgba straight alpha0 copy src1 ' + IntToStr(LI), Integer(FSrc1.Data[LI]), Integer(LData[LI]));
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
    AssertEquals('rgba straight alpha1 copy src2 ' + IntToStr(LI), Integer(FSrc2.Data[LI]), Integer(LData[LI]));
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
    AssertEquals('rgba premult alpha0 copy src1 ' + IntToStr(LI), Integer(FSrc1.Data[LI]), Integer(LData[LI]));
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
    AssertEquals('rgba premult alpha1 copy src2 ' + IntToStr(LI), Integer(FSrc2.Data[LI]), Integer(LData[LI]));
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
  AssertEquals('blend quarter gray', 70, Integer(LData[0]));
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
  AssertEquals('premult quarter R', 80, Integer(LData[0]));
  AssertEquals('premult quarter G', 88, Integer(LData[1]));
  AssertEquals('premult quarter B', 25, Integer(LData[2]));
  AssertEquals('premult quarter A', 175, Integer(LData[3]));
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
  AssertEquals('straight opaque quarter R', 80, Integer(LData[0]));
  AssertEquals('straight opaque quarter G', 88, Integer(LData[1]));
  AssertEquals('straight opaque quarter B', 25, Integer(LData[2]));
  AssertEquals('straight opaque quarter A', 255, Integer(LData[3]));
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
    AssertEquals('blend clamp low ' + IntToStr(LI), Integer(FSrc1.Data[LI]), Integer(LData[LI]));

  ImageBlend(FDest, FSrc1, FSrc2, 3.0);
  LData := FDest.Data;
  for LI := 0 to 5 do
    AssertEquals('blend clamp high ' + IntToStr(LI), Integer(FSrc2.Data[LI]), Integer(LData[LI]));
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
  AssertEquals('weighted grayscale from red', 54, Integer(LData[0]));
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

  AssertTrue('get pixel out of range should raise', LRaised);
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

  AssertTrue('set pixel out of range should raise', LRaised);
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

  AssertTrue('negative size should raise', LRaised);
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

  AssertTrue('image add mismatch should raise', LRaised);
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

  AssertTrue('image blend mismatch should raise', LRaised);
end;

procedure TTestCase_ImageProc.Test_RGBToGrayscale_FromRGBA32;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 240]);

  RGBToGrayscale(FDest, FSrc1);

  LData := FDest.Data;
  AssertEquals('rgba to gray', 19, Integer(LData[0]));
end;

procedure TTestCase_ImageProc.Test_GrayscaleToRGB_FullChannelReplication;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifGrayscale);
  FillImage(FSrc1, [5, 200]);

  GrayscaleToRGB(FDest, FSrc1);

  LData := FDest.Data;
  AssertEquals('pixel0 r', 5, Integer(LData[0]));
  AssertEquals('pixel0 g', 5, Integer(LData[1]));
  AssertEquals('pixel0 b', 5, Integer(LData[2]));
  AssertEquals('pixel1 r', 200, Integer(LData[3]));
  AssertEquals('pixel1 g', 200, Integer(LData[4]));
  AssertEquals('pixel1 b', 200, Integer(LData[5]));
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_SmallImage_NoChange;
const
  LKernel: TKernel3x3 = (
    1, 2, 1,
    2, 4, 2,
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
    AssertEquals('small image no change ' + IntToStr(LI), Integer(FSrc1.Data[LI]), Integer(LData[LI]));
end;

procedure TTestCase_ImageProc.Test_ApplyConvolution3x3_RGBA_AlphaPreserved;
const
  LKernel: TKernel3x3 = (
    0, 0, 0,
    0, 1, 0,
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
    AssertEquals('rgba conv alpha preserve ' + IntToStr(LI), Integer(LSrcData[LBase + 3]), Integer(LDestData[LBase + 3]));
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
    AssertEquals('gaussian constant r ' + IntToStr(LI), 77, Integer(LData[LI * 3 + 0]));
    AssertEquals('gaussian constant g ' + IntToStr(LI), 88, Integer(LData[LI * 3 + 1]));
    AssertEquals('gaussian constant b ' + IntToStr(LI), 99, Integer(LData[LI * 3 + 2]));
  end;
end;

procedure TTestCase_ImageProc.Test_FreeImage_ResetsState;
begin
  FSrc1 := CreateImage(2, 1, ifRGBA32);
  FillImage(FSrc1, [1, 2, 3, 4, 5, 6, 7, 8]);

  FreeImage(FSrc1);

  AssertEquals('free width', 0, FSrc1.Width);
  AssertEquals('free height', 0, FSrc1.Height);
  AssertEquals('free data size', 0, FSrc1.DataSize);
  AssertTrue('free data nil', FSrc1.Data = nil);
  AssertEquals('free format reset', Integer(ifRGB24), Integer(FSrc1.Format));
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_NegativeFactor_GrayscaleZero;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifGrayscale);
  FillImage(FSrc1, [10, 200]);

  ImageMultiply(FDest, FSrc1, -1.0);

  LData := FDest.Data;
  AssertEquals('mul negative gray 0', 0, Integer(LData[0]));
  AssertEquals('mul negative gray 1', 0, Integer(LData[1]));
end;

procedure TTestCase_ImageProc.Test_ImageMultiply_NegativeFactor_RGBAAlphaPreserved;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(2, 1, ifRGBA32);
  FillImage(FSrc1, [10, 20, 30, 40, 200, 210, 220, 230]);

  ImageMultiply(FDest, FSrc1, -0.25);

  LData := FDest.Data;
  AssertEquals('mul negative rgba p0 r', 0, Integer(LData[0]));
  AssertEquals('mul negative rgba p0 g', 0, Integer(LData[1]));
  AssertEquals('mul negative rgba p0 b', 0, Integer(LData[2]));
  AssertEquals('mul negative rgba p0 a', 40, Integer(LData[3]));
  AssertEquals('mul negative rgba p1 r', 0, Integer(LData[4]));
  AssertEquals('mul negative rgba p1 g', 0, Integer(LData[5]));
  AssertEquals('mul negative rgba p1 b', 0, Integer(LData[6]));
  AssertEquals('mul negative rgba p1 a', 230, Integer(LData[7]));
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
    AssertEquals('gamma identity gray ' + IntToStr(LI), Integer(LExpect[LI]), Integer(LData[LI]));
end;

procedure TTestCase_ImageProc.Test_ApplyBrightness_ClampHigh_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [250]);

  ApplyBrightness(FSrc1, 20.0);

  LData := FSrc1.Data;
  AssertEquals('brightness clamp high', 255, Integer(LData[0]));
end;

procedure TTestCase_ImageProc.Test_ApplyContrast_HighClamp_Grayscale;
var
  LData: PByte;
begin
  FSrc1 := CreateImage(1, 1, ifGrayscale);
  FillImage(FSrc1, [250]);

  ApplyContrast(FSrc1, 2.0);

  LData := FSrc1.Data;
  AssertEquals('contrast high clamp', 255, Integer(LData[0]));
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
  AssertEquals('blend half rgb deterministic r', 60, Integer(LData[0]));
  AssertEquals('blend half rgb deterministic g', 70, Integer(LData[1]));
  AssertEquals('blend half rgb deterministic b', 80, Integer(LData[2]));
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
  AssertEquals('blend half gray deterministic', 60, Integer(LData[0]));
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
  AssertEquals('blend half bankers rgb r', 0, Integer(LData[0]));
  AssertEquals('blend half bankers rgb g', 4, Integer(LData[1]));
  AssertEquals('blend half bankers rgb b', 4, Integer(LData[2]));
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
  AssertEquals('blend half bankers gray', 0, Integer(LData[0]));
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
  AssertEquals('blend half lut odd-even gray', 1, Integer(LData[0]));
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
  AssertEquals('brightness zero r0', 1, Integer(LData[0]));
  AssertEquals('brightness zero g0', 2, Integer(LData[1]));
  AssertEquals('brightness zero b0', 3, Integer(LData[2]));
  for LI := 3 to 5 do
    AssertTrue('brightness zero keep tail ' + IntToStr(LI), LData[LI] > 0);
  AssertEquals('brightness zero r1', 100, Integer(LData[3]));
  AssertEquals('brightness zero g1', 150, Integer(LData[4]));
  AssertEquals('brightness zero b1', 200, Integer(LData[5]));
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
    AssertEquals('contrast one keep gray ' + IntToStr(LI), Integer(LExpect[LI]), Integer(LData[LI]));
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
    AssertEquals('gamma one keep rgba ' + IntToStr(LI), Integer(LExpect[LI]), Integer(LData[LI]));
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
    AssertEquals('sharpen constant gray keep ' + IntToStr(LI), 77, Integer(LData[LI]));
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
    AssertEquals('sharpen rgba alpha preserve ' + IntToStr(LI),
      Integer(LSrcData[LBase + 3]), Integer(LDestData[LBase + 3]));
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
        AssertEquals('edge constant border keep ' + IntToStr(LIndex), 100, Integer(LData[LIndex]))
      else
        AssertEquals('edge constant interior zero ' + IntToStr(LIndex), 0, Integer(LData[LIndex]));
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
    AssertEquals('edge small image no change ' + IntToStr(LI),
      Integer(FSrc1.Data[LI]), Integer(LData[LI]));
end;
initialization
  RegisterTest(TTestCase_ImageProc);

end.

// Experimental: not part of stable surface.
unit nextpas.core.simd.imageproc;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd;

type
  TImageFormat = (
    ifRGB24,
    ifRGBA32,
    ifGrayscale
  );

  TImageBlendAlphaMode = (
    ibamStraight,
    ibamPremultiplied
  );

  TImage = record
    Width, Height: Integer;
    Format: TImageFormat;
    Data: PByte;
    DataSize: Integer;
  end;

  TKernel3x3 = array[0..8] of Single;

function CreateImage(aWidth, aHeight: Integer; aFormat: TImageFormat): TImage;
procedure FreeImage(var aImg: TImage);

function GetPixelRGB(const aImg: TImage; aX, aY: Integer): TVecF32x4;
procedure SetPixelRGB(var aImg: TImage; aX, aY: Integer; const aColor: TVecF32x4);

procedure ImageAdd(var aDest: TImage; const aSrc1, aSrc2: TImage);
procedure ImageSubtract(var aDest: TImage; const aSrc1, aSrc2: TImage);
procedure ImageMultiply(var aDest: TImage; const aSrc: TImage; aFactor: Single);
procedure ImageBlend(var aDest: TImage; const aSrc1, aSrc2: TImage; aAlpha: Single);

procedure SetImageBlendAlphaMode(aMode: TImageBlendAlphaMode);
function GetImageBlendAlphaMode: TImageBlendAlphaMode;

procedure RGBToGrayscale(var aDest: TImage; const aSrc: TImage);
procedure GrayscaleToRGB(var aDest: TImage; const aSrc: TImage);

procedure ApplyBrightness(var aImg: TImage; aBrightness: Single);
procedure ApplyContrast(var aImg: TImage; aContrast: Single);
procedure ApplyGamma(var aImg: TImage; aGamma: Single);

procedure ApplyConvolution3x3(var aDest: TImage; const aSrc: TImage; const aKernel: TKernel3x3);
procedure ApplyGaussianBlur(var aDest: TImage; const aSrc: TImage);
procedure ApplySharpen(var aDest: TImage; const aSrc: TImage);
procedure ApplyEdgeDetection(var aDest: TImage; const aSrc: TImage);

implementation

uses
  nextpas.core.errors,
  nextpas.core.simd.mathutil;

const
  RGB_TO_GRAY_R = 0.2126;
  RGB_TO_GRAY_G = 0.7152;
  RGB_TO_GRAY_B = 0.0722;

  KERNEL_GAUSSIAN_BLUR: TKernel3x3 = (
    1 / 16, 2 / 16, 1 / 16,
    2 / 16, 4 / 16, 2 / 16,
    1 / 16, 2 / 16, 1 / 16
  );

  KERNEL_SHARPEN: TKernel3x3 = (
     0, -1,  0,
    -1,  5, -1,
     0, -1,  0
  );

  KERNEL_EDGE_DETECTION: TKernel3x3 = (
    -1, -1, -1,
    -1,  8, -1,
    -1, -1, -1
  );

type
  TByteLut = array[0..255] of Byte;

var
  GImageBlendAlphaMode: TImageBlendAlphaMode = ibamStraight;
  GBlendLutCacheValid: Boolean = False;
  GBlendLutCacheAlpha: Single = 0.0;
  GBlendLutCacheSrc1: TByteLut;
  GBlendLutCacheSrc2: TByteLut;

function BytesPerPixel(const aFormat: TImageFormat): Integer; inline;
begin
  Result := 0;
  case aFormat of
    ifRGB24: Result := 3;
    ifRGBA32: Result := 4;
    ifGrayscale: Result := 1;
  end;
end;

function ClampByteFromInteger(const aValue: Integer): Byte; inline;
begin
  if aValue <= 0 then
    Exit(0);
  if aValue >= 255 then
    Exit(255);
  Result := Byte(aValue);
end;

function ClampByteFromSingle(const aValue: Single): Byte; inline;
var
  LRounded: Integer;
begin
  LRounded := Round(aValue);
  Result := ClampByteFromInteger(LRounded);
end;

function LoadVecU8x16(const aData: PByte): TVecU8x16; inline;
begin
  Result := Default(TVecU8x16);
  Move(aData^, Result, SizeOf(Result));
end;


function IsNearlyEqual(const aLeft, aRight: Single): Boolean; inline;
begin
  Result := Abs(aLeft - aRight) <= 1e-6;
end;

procedure BuildLinearLut(aScale, aOffset: Single; out aLut: TByteLut); inline;
var
  LIndex: Integer;
begin
  for LIndex := 0 to 255 do
    aLut[LIndex] := ClampByteFromSingle((LIndex * aScale) + aOffset);
end;

procedure BuildGammaLut(aGamma: Single; out aLut: TByteLut); inline;
var
  LIndex: Integer;
  LInvGamma: Single;
  LNormalized: Single;
begin
  if aGamma <= 0.0 then
    raise EArgumentOutOfRangeException.Create('Gamma must be > 0');

  LInvGamma := 1.0 / aGamma;
  for LIndex := 0 to 255 do
  begin
    LNormalized := LIndex / 255.0;
    aLut[LIndex] := ClampByteFromSingle(SimdPowerF32(LNormalized, LInvGamma) * 255.0);
  end;
end;

procedure ApplyLutToAllBytes(aData: PByte; aCount: Integer; const aLut: TByteLut); inline;
var
  LIndex: Integer;
begin
  for LIndex := 0 to aCount - 1 do
    aData[LIndex] := aLut[aData[LIndex]];
end;

procedure ApplyLutToRgbaRgbChannels(aData: PByte; aPixelCount: Integer; const aLut: TByteLut); inline;
var
  LIndex: Integer;
  LBase: Integer;
begin
  for LIndex := 0 to aPixelCount - 1 do
  begin
    LBase := LIndex * 4;
    aData[LBase + 0] := aLut[aData[LBase + 0]];
    aData[LBase + 1] := aLut[aData[LBase + 1]];
    aData[LBase + 2] := aLut[aData[LBase + 2]];
  end;
end;

procedure MapLutToAllBytes(const aSrc, aDest: PByte; aCount: Integer; const aLut: TByteLut); inline;
var
  LIndex: Integer;
begin
  for LIndex := 0 to aCount - 1 do
    aDest[LIndex] := aLut[aSrc[LIndex]];
end;

procedure MapLutToRgbaRgbChannels(const aSrc, aDest: PByte; aPixelCount: Integer; const aLut: TByteLut); inline;
var
  LIndex: Integer;
  LBase: Integer;
begin
  for LIndex := 0 to aPixelCount - 1 do
  begin
    LBase := LIndex * 4;
    aDest[LBase + 0] := aLut[aSrc[LBase + 0]];
    aDest[LBase + 1] := aLut[aSrc[LBase + 1]];
    aDest[LBase + 2] := aLut[aSrc[LBase + 2]];
    aDest[LBase + 3] := aSrc[LBase + 3];
  end;
end;
procedure RequireImageData(const aImg: TImage; const aName: string); inline;
begin
  if (aImg.DataSize > 0) and (aImg.Data = nil) then
    raise EArgumentException.CreateFmt('%s.Data must not be nil', [aName]);
end;

procedure BuildBlendLuts(aAlpha: Single; out aLutSrc1, aLutSrc2: TByteLut); inline;
var
  LIndex: Integer;
  LAlphaInv: Single;
begin
  if aAlpha < 0.0 then
    aAlpha := 0.0
  else if aAlpha > 1.0 then
    aAlpha := 1.0;

  LAlphaInv := 1.0 - aAlpha;
  for LIndex := 0 to 255 do
  begin
    aLutSrc1[LIndex] := ClampByteFromSingle(LIndex * LAlphaInv);
    aLutSrc2[LIndex] := ClampByteFromSingle(LIndex * aAlpha);
  end;
end;

procedure EnsureBlendLutCache(aAlpha: Single); inline;
begin
  if (not GBlendLutCacheValid) or (not IsNearlyEqual(GBlendLutCacheAlpha, aAlpha)) then
  begin
    BuildBlendLuts(aAlpha, GBlendLutCacheSrc1, GBlendLutCacheSrc2);
    GBlendLutCacheAlpha := aAlpha;
    GBlendLutCacheValid := True;
  end;
end;

function BlendBytesFromLut(aValue1, aValue2: Byte; const aLutSrc1, aLutSrc2: TByteLut): Byte; inline;
begin
  Result := ClampByteFromInteger(Integer(aLutSrc1[aValue1]) + Integer(aLutSrc2[aValue2]));
end;

function RoundHalfByte(aValue: Byte): Byte; inline;
var
  LBase: Integer;
  LCarry: Integer;
begin
  LBase := aValue shr 1;
  LCarry := (aValue and 1) and (LBase and 1);
  Result := Byte(LBase + LCarry);
end;

function BlendBytesHalfBankers(aValue1, aValue2: Byte): Byte; inline;
var
  LSum: Integer;
begin
  LSum := Integer(RoundHalfByte(aValue1)) + Integer(RoundHalfByte(aValue2));
  Result := ClampByteFromInteger(LSum);
end;

procedure ValidateCoordinates(const aImg: TImage; aX, aY: Integer);
begin
  if (aX < 0) or (aX >= aImg.Width) or (aY < 0) or (aY >= aImg.Height) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Pixel coordinate (%d,%d) out of range %dx%d',
      [aX, aY, aImg.Width, aImg.Height]
    );
end;

procedure EnsureImage(var aImg: TImage; aWidth, aHeight: Integer; aFormat: TImageFormat);
var
  LExpectedDataSize: Integer;
begin
  LExpectedDataSize := aWidth * aHeight * BytesPerPixel(aFormat);

  if (aImg.Width <> aWidth) or
     (aImg.Height <> aHeight) or
     (aImg.Format <> aFormat) or
     (aImg.DataSize <> LExpectedDataSize) or
     ((LExpectedDataSize > 0) and (aImg.Data = nil)) then
  begin
    FreeImage(aImg);
    aImg := CreateImage(aWidth, aHeight, aFormat);
  end;
end;

procedure ValidateSameShape(const aSrc1, aSrc2: TImage);
begin
  if (aSrc1.Width <> aSrc2.Width) or
     (aSrc1.Height <> aSrc2.Height) or
     (aSrc1.Format <> aSrc2.Format) then
    raise Exception.Create('图像尺寸或格式不匹配');

  RequireImageData(aSrc1, 'src1');
  RequireImageData(aSrc2, 'src2');
end;

procedure BlendRgbaStraight(const aSrc1, aSrc2: PByte; aAlpha: Single; aDest: PByte);
var
  LChannel: Integer;
  LAlphaInv: Single;
  LSrc1AlphaNorm: Single;
  LSrc2AlphaNorm: Single;
  LOutAlphaNorm: Single;
  LSrc1Premult: Single;
  LSrc2Premult: Single;
  LOutPremult: Single;
begin
  LAlphaInv := 1.0 - aAlpha;
  LSrc1AlphaNorm := aSrc1[3] / 255.0;
  LSrc2AlphaNorm := aSrc2[3] / 255.0;
  LOutAlphaNorm := (LSrc1AlphaNorm * LAlphaInv) + (LSrc2AlphaNorm * aAlpha);

  for LChannel := 0 to 2 do
  begin
    LSrc1Premult := aSrc1[LChannel] * LSrc1AlphaNorm;
    LSrc2Premult := aSrc2[LChannel] * LSrc2AlphaNorm;
    LOutPremult := (LSrc1Premult * LAlphaInv) + (LSrc2Premult * aAlpha);

    if LOutAlphaNorm > 0.0 then
      aDest[LChannel] := ClampByteFromSingle(LOutPremult / LOutAlphaNorm)
    else
      aDest[LChannel] := 0;
  end;

  aDest[3] := ClampByteFromSingle(LOutAlphaNorm * 255.0);
end;

procedure BlendRgbaPremultiplied(const aSrc1, aSrc2: PByte; aAlpha: Single; aDest: PByte);
var
  LChannel: Integer;
  LAlphaInv: Single;
begin
  LAlphaInv := 1.0 - aAlpha;

  for LChannel := 0 to 2 do
    aDest[LChannel] := ClampByteFromSingle(
      (aSrc1[LChannel] * LAlphaInv) + (aSrc2[LChannel] * aAlpha)
    );

  aDest[3] := ClampByteFromSingle(
    (aSrc1[3] * LAlphaInv) + (aSrc2[3] * aAlpha)
  );
end;

procedure ApplyGaussianBlurSeparable(var aDest: TImage; const aSrc: TImage);
var
  LTemp: TImage;
  LWidth, LHeight: Integer;
  LChannels: Integer;
  LX, LY, LChannel: Integer;
  LBase: Integer;
  LLeftIndex, LCenterIndex, LRightIndex: Integer;
  LTopIndex, LBottomIndex: Integer;
  LSrcData, LTempData, LDestData: PByte;
  LSum: Single;
begin
  RequireImageData(aSrc, 'src');
  EnsureImage(aDest, aSrc.Width, aSrc.Height, aSrc.Format);

  LWidth := aSrc.Width;
  LHeight := aSrc.Height;

  if (LWidth < 3) or (LHeight < 3) then
  begin
    if aSrc.DataSize > 0 then
      Move(aSrc.Data^, aDest.Data^, aSrc.DataSize);
    Exit;
  end;

  LChannels := BytesPerPixel(aSrc.Format);
  LTemp.Width := 0;
  LTemp.Height := 0;
  LTemp.Format := ifRGB24;
  LTemp.Data := nil;
  LTemp.DataSize := 0;
  LTemp := CreateImage(LWidth, LHeight, aSrc.Format);
  try
    LSrcData := aSrc.Data;
    LTempData := LTemp.Data;
    LDestData := aDest.Data;

    Move(LSrcData^, LTempData^, aSrc.DataSize);
    Move(LSrcData^, LDestData^, aSrc.DataSize);

    for LY := 0 to LHeight - 1 do
    begin
      for LX := 1 to LWidth - 2 do
      begin
        LBase := (LY * LWidth + LX) * LChannels;

        for LChannel := 0 to LChannels - 1 do
        begin
          if (aSrc.Format = ifRGBA32) and (LChannel = 3) then
          begin
            LTempData[LBase + LChannel] := LSrcData[LBase + LChannel];
            Continue;
          end;

          LLeftIndex := LBase - LChannels + LChannel;
          LCenterIndex := LBase + LChannel;
          LRightIndex := LBase + LChannels + LChannel;

          LSum :=
            LSrcData[LLeftIndex] +
            (2.0 * LSrcData[LCenterIndex]) +
            LSrcData[LRightIndex];

          LTempData[LCenterIndex] := ClampByteFromSingle(LSum * 0.25);
        end;
      end;
    end;

    for LY := 1 to LHeight - 2 do
    begin
      for LX := 1 to LWidth - 2 do
      begin
        LBase := (LY * LWidth + LX) * LChannels;

        for LChannel := 0 to LChannels - 1 do
        begin
          if (aSrc.Format = ifRGBA32) and (LChannel = 3) then
          begin
            LDestData[LBase + LChannel] := LSrcData[LBase + LChannel];
            Continue;
          end;

          LTopIndex := ((LY - 1) * LWidth + LX) * LChannels + LChannel;
          LCenterIndex := LBase + LChannel;
          LBottomIndex := ((LY + 1) * LWidth + LX) * LChannels + LChannel;

          LSum :=
            LTempData[LTopIndex] +
            (2.0 * LTempData[LCenterIndex]) +
            LTempData[LBottomIndex];

          LDestData[LCenterIndex] := ClampByteFromSingle(LSum * 0.25);
        end;
      end;
    end;
  finally
    FreeImage(LTemp);
  end;
end;

function CreateImage(aWidth, aHeight: Integer; aFormat: TImageFormat): TImage;
var
  LDataSize64: Int64;
  LBytesPerPixel: Integer;
begin
  if (aWidth < 0) or (aHeight < 0) then
    raise EArgumentOutOfRangeException.CreateFmt('Invalid image size: %dx%d', [aWidth, aHeight]);

  LBytesPerPixel := BytesPerPixel(aFormat);
  LDataSize64 := Int64(aWidth) * Int64(aHeight) * Int64(LBytesPerPixel);

  if LDataSize64 > High(Integer) then
    raise EOutOfMemory.CreateFmt('Image too large: %dx%d (%d bytes)', [aWidth, aHeight, LDataSize64]);

  Result.Width := aWidth;
  Result.Height := aHeight;
  Result.Format := aFormat;
  Result.DataSize := Integer(LDataSize64);

  if Result.DataSize > 0 then
  begin
    GetMem(Result.Data, Result.DataSize);
    FillChar(Result.Data^, Result.DataSize, 0);
  end
  else
    Result.Data := nil;
end;

procedure FreeImage(var aImg: TImage);
begin
  if Assigned(aImg.Data) then
  begin
    FreeMem(aImg.Data);
    aImg.Data := nil;
  end;
  aImg.Width := 0;
  aImg.Height := 0;
  aImg.DataSize := 0;
  aImg.Format := ifRGB24;
end;

function GetPixelRGB(const aImg: TImage; aX, aY: Integer): TVecF32x4;
var
  LOffset: Integer;
  LBytesPerPixel: Integer;
  LData: PByte;
  LGray: Byte;
begin
  RequireImageData(aImg, 'img');
  ValidateCoordinates(aImg, aX, aY);

  Result := VecF32x4Zero;
  LData := aImg.Data;
  LBytesPerPixel := BytesPerPixel(aImg.Format);
  LOffset := (aY * aImg.Width + aX) * LBytesPerPixel;

  case aImg.Format of
    ifRGB24:
      begin
        Result.f[0] := LData[LOffset + 0];
        Result.f[1] := LData[LOffset + 1];
        Result.f[2] := LData[LOffset + 2];
        Result.f[3] := 255.0;
      end;
    ifRGBA32:
      begin
        Result.f[0] := LData[LOffset + 0];
        Result.f[1] := LData[LOffset + 1];
        Result.f[2] := LData[LOffset + 2];
        Result.f[3] := LData[LOffset + 3];
      end;
    ifGrayscale:
      begin
        LGray := LData[LOffset];
        Result.f[0] := LGray;
        Result.f[1] := LGray;
        Result.f[2] := LGray;
        Result.f[3] := 255.0;
      end;
  end;
end;

procedure SetPixelRGB(var aImg: TImage; aX, aY: Integer; const aColor: TVecF32x4);
var
  LOffset: Integer;
  LBytesPerPixel: Integer;
  LData: PByte;
  LR, LG, LB, LA: Byte;
  LGray: Byte;
begin
  RequireImageData(aImg, 'img');
  ValidateCoordinates(aImg, aX, aY);

  LR := ClampByteFromSingle(aColor.f[0]);
  LG := ClampByteFromSingle(aColor.f[1]);
  LB := ClampByteFromSingle(aColor.f[2]);
  LA := ClampByteFromSingle(aColor.f[3]);

  LData := aImg.Data;
  LBytesPerPixel := BytesPerPixel(aImg.Format);
  LOffset := (aY * aImg.Width + aX) * LBytesPerPixel;

  case aImg.Format of
    ifRGB24:
      begin
        LData[LOffset + 0] := LR;
        LData[LOffset + 1] := LG;
        LData[LOffset + 2] := LB;
      end;
    ifRGBA32:
      begin
        LData[LOffset + 0] := LR;
        LData[LOffset + 1] := LG;
        LData[LOffset + 2] := LB;
        LData[LOffset + 3] := LA;
      end;
    ifGrayscale:
      begin
        LGray := ClampByteFromSingle(
          (LR * RGB_TO_GRAY_R) +
          (LG * RGB_TO_GRAY_G) +
          (LB * RGB_TO_GRAY_B)
        );
        LData[LOffset] := LGray;
      end;
  end;
end;

procedure ImageAdd(var aDest: TImage; const aSrc1, aSrc2: TImage);
var
  LI: Integer;
  LSimdEnd: Integer;
  LVecResult: TVecU8x16;
  LSrc1Data, LSrc2Data, LDestData: PByte;
begin
  ValidateSameShape(aSrc1, aSrc2);
  EnsureImage(aDest, aSrc1.Width, aSrc1.Height, aSrc1.Format);

  LSrc1Data := aSrc1.Data;
  LSrc2Data := aSrc2.Data;
  LDestData := aDest.Data;

  LSimdEnd := aSrc1.DataSize and (not 15);
  LI := 0;
  while LI < LSimdEnd do
  begin
    LVecResult := VecU8x16SatAdd(
      LoadVecU8x16(@LSrc1Data[LI]),
      LoadVecU8x16(@LSrc2Data[LI])
    );
    Move(LVecResult, LDestData[LI], SizeOf(TVecU8x16));
    Inc(LI, SizeOf(TVecU8x16));
  end;

  while LI < aSrc1.DataSize do
  begin
    LDestData[LI] := ClampByteFromInteger(Integer(LSrc1Data[LI]) + Integer(LSrc2Data[LI]));
    Inc(LI);
  end;
end;

procedure ImageSubtract(var aDest: TImage; const aSrc1, aSrc2: TImage);
var
  LI: Integer;
  LSimdEnd: Integer;
  LVecResult: TVecU8x16;
  LSrc1Data, LSrc2Data, LDestData: PByte;
begin
  ValidateSameShape(aSrc1, aSrc2);
  EnsureImage(aDest, aSrc1.Width, aSrc1.Height, aSrc1.Format);

  LSrc1Data := aSrc1.Data;
  LSrc2Data := aSrc2.Data;
  LDestData := aDest.Data;

  LSimdEnd := aSrc1.DataSize and (not 15);
  LI := 0;
  while LI < LSimdEnd do
  begin
    LVecResult := VecU8x16SatSub(
      LoadVecU8x16(@LSrc1Data[LI]),
      LoadVecU8x16(@LSrc2Data[LI])
    );
    Move(LVecResult, LDestData[LI], SizeOf(TVecU8x16));
    Inc(LI, SizeOf(TVecU8x16));
  end;

  while LI < aSrc1.DataSize do
  begin
    LDestData[LI] := ClampByteFromInteger(Integer(LSrc1Data[LI]) - Integer(LSrc2Data[LI]));
    Inc(LI);
  end;
end;

procedure ImageMultiply(var aDest: TImage; const aSrc: TImage; aFactor: Single);
var
  LI: Integer;
  LOffset: Integer;
  LPixelCount: Integer;
  LLut: TByteLut;
  LSrcData, LDestData: PByte;
begin
  RequireImageData(aSrc, 'src');
  EnsureImage(aDest, aSrc.Width, aSrc.Height, aSrc.Format);

  LSrcData := aSrc.Data;
  LDestData := aDest.Data;
  LPixelCount := aSrc.Width * aSrc.Height;

  if IsNearlyEqual(aFactor, 1.0) then
  begin
    if aSrc.DataSize > 0 then
      Move(LSrcData^, LDestData^, aSrc.DataSize);
    Exit;
  end;

  if aFactor <= 0.0 then
  begin
    case aSrc.Format of
      ifRGBA32:
        begin
          for LI := 0 to LPixelCount - 1 do
          begin
            LOffset := LI * 4;
            LDestData[LOffset + 0] := 0;
            LDestData[LOffset + 1] := 0;
            LDestData[LOffset + 2] := 0;
            LDestData[LOffset + 3] := LSrcData[LOffset + 3];
          end;
        end;
      ifRGB24, ifGrayscale:
        if aSrc.DataSize > 0 then
          FillChar(LDestData^, aSrc.DataSize, 0);
    end;
    Exit;
  end;

  BuildLinearLut(aFactor, 0.0, LLut);

  case aSrc.Format of
    ifRGBA32:
      MapLutToRgbaRgbChannels(LSrcData, LDestData, LPixelCount, LLut);
    ifRGB24, ifGrayscale:
      MapLutToAllBytes(LSrcData, LDestData, aSrc.DataSize, LLut);
  end;
end;

procedure ImageBlend(var aDest: TImage; const aSrc1, aSrc2: TImage; aAlpha: Single);
var
  LI: Integer;
  LPixelCount: Integer;
  LSrc1Data, LSrc2Data, LDestData: PByte;
  LSrc1Pixel, LSrc2Pixel, LDestPixel: PByte;
begin
  ValidateSameShape(aSrc1, aSrc2);
  EnsureImage(aDest, aSrc1.Width, aSrc1.Height, aSrc1.Format);

  if aAlpha < 0.0 then
    aAlpha := 0.0
  else if aAlpha > 1.0 then
    aAlpha := 1.0;

  LSrc1Data := aSrc1.Data;
  LSrc2Data := aSrc2.Data;
  LDestData := aDest.Data;

  if IsNearlyEqual(aAlpha, 0.0) then
  begin
    if aSrc1.DataSize > 0 then
      Move(LSrc1Data^, LDestData^, aSrc1.DataSize);
    Exit;
  end;

  if IsNearlyEqual(aAlpha, 1.0) then
  begin
    if aSrc2.DataSize > 0 then
      Move(LSrc2Data^, LDestData^, aSrc2.DataSize);
    Exit;
  end;

  if IsNearlyEqual(aAlpha, 0.5) then
  begin
    if aSrc1.Format = ifRGBA32 then
    begin
      LPixelCount := aSrc1.Width * aSrc1.Height;
      for LI := 0 to LPixelCount - 1 do
      begin
        LSrc1Pixel := @LSrc1Data[LI * 4];
        LSrc2Pixel := @LSrc2Data[LI * 4];
        LDestPixel := @LDestData[LI * 4];

        case GImageBlendAlphaMode of
          ibamStraight:
            begin
              if (LSrc1Pixel[3] = 255) and (LSrc2Pixel[3] = 255) then
              begin
                LDestPixel[0] := BlendBytesHalfBankers(LSrc1Pixel[0], LSrc2Pixel[0]);
                LDestPixel[1] := BlendBytesHalfBankers(LSrc1Pixel[1], LSrc2Pixel[1]);
                LDestPixel[2] := BlendBytesHalfBankers(LSrc1Pixel[2], LSrc2Pixel[2]);
                LDestPixel[3] := 255;
              end
              else
                BlendRgbaStraight(LSrc1Pixel, LSrc2Pixel, aAlpha, LDestPixel);
            end;
          ibamPremultiplied:
            begin
              LDestPixel[0] := BlendBytesHalfBankers(LSrc1Pixel[0], LSrc2Pixel[0]);
              LDestPixel[1] := BlendBytesHalfBankers(LSrc1Pixel[1], LSrc2Pixel[1]);
              LDestPixel[2] := BlendBytesHalfBankers(LSrc1Pixel[2], LSrc2Pixel[2]);
              LDestPixel[3] := BlendBytesHalfBankers(LSrc1Pixel[3], LSrc2Pixel[3]);
            end;
        end;
      end;
      Exit;
    end;

    for LI := 0 to aSrc1.DataSize - 1 do
      LDestData[LI] := BlendBytesHalfBankers(LSrc1Data[LI], LSrc2Data[LI]);
    Exit;
  end;

  EnsureBlendLutCache(aAlpha);

  if aSrc1.Format = ifRGBA32 then
  begin
    LPixelCount := aSrc1.Width * aSrc1.Height;
    for LI := 0 to LPixelCount - 1 do
    begin
      LSrc1Pixel := @LSrc1Data[LI * 4];
      LSrc2Pixel := @LSrc2Data[LI * 4];
      LDestPixel := @LDestData[LI * 4];

      case GImageBlendAlphaMode of
        ibamStraight:
          begin
            if (LSrc1Pixel[3] = 255) and (LSrc2Pixel[3] = 255) then
            begin
              LDestPixel[0] := BlendBytesFromLut(LSrc1Pixel[0], LSrc2Pixel[0], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
              LDestPixel[1] := BlendBytesFromLut(LSrc1Pixel[1], LSrc2Pixel[1], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
              LDestPixel[2] := BlendBytesFromLut(LSrc1Pixel[2], LSrc2Pixel[2], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
              LDestPixel[3] := 255;
            end
            else
              BlendRgbaStraight(LSrc1Pixel, LSrc2Pixel, aAlpha, LDestPixel);
          end;
        ibamPremultiplied:
          begin
            LDestPixel[0] := BlendBytesFromLut(LSrc1Pixel[0], LSrc2Pixel[0], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
            LDestPixel[1] := BlendBytesFromLut(LSrc1Pixel[1], LSrc2Pixel[1], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
            LDestPixel[2] := BlendBytesFromLut(LSrc1Pixel[2], LSrc2Pixel[2], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
            LDestPixel[3] := BlendBytesFromLut(LSrc1Pixel[3], LSrc2Pixel[3], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
          end;
      end;
    end;
    Exit;
  end;

  for LI := 0 to aSrc1.DataSize - 1 do
    LDestData[LI] := BlendBytesFromLut(LSrc1Data[LI], LSrc2Data[LI], GBlendLutCacheSrc1, GBlendLutCacheSrc2);
end;
procedure SetImageBlendAlphaMode(aMode: TImageBlendAlphaMode);
begin
  GImageBlendAlphaMode := aMode;
end;

function GetImageBlendAlphaMode: TImageBlendAlphaMode;
begin
  Result := GImageBlendAlphaMode;
end;

procedure RGBToGrayscale(var aDest: TImage; const aSrc: TImage);
var
  LI: Integer;
  LStride: Integer;
  LOffset: Integer;
  LPixelCount: Integer;
  LSrcData, LDestData: PByte;
  LR, LG, LB: Byte;
begin
  if (aSrc.Format <> ifRGB24) and (aSrc.Format <> ifRGBA32) then
    raise Exception.Create('源图像必须是 RGB24 或 RGBA32 格式');

  RequireImageData(aSrc, 'src');
  EnsureImage(aDest, aSrc.Width, aSrc.Height, ifGrayscale);

  LPixelCount := aSrc.Width * aSrc.Height;
  LStride := BytesPerPixel(aSrc.Format);
  LSrcData := aSrc.Data;
  LDestData := aDest.Data;

  for LI := 0 to LPixelCount - 1 do
  begin
    LOffset := LI * LStride;
    LR := LSrcData[LOffset + 0];
    LG := LSrcData[LOffset + 1];
    LB := LSrcData[LOffset + 2];

    LDestData[LI] := ClampByteFromSingle(
      (LR * RGB_TO_GRAY_R) +
      (LG * RGB_TO_GRAY_G) +
      (LB * RGB_TO_GRAY_B)
    );
  end;
end;

procedure GrayscaleToRGB(var aDest: TImage; const aSrc: TImage);
var
  LI: Integer;
  LOffset: Integer;
  LPixelCount: Integer;
  LGray: Byte;
  LSrcData, LDestData: PByte;
begin
  if aSrc.Format <> ifGrayscale then
    raise Exception.Create('源图像必须是 Grayscale 格式');

  RequireImageData(aSrc, 'src');
  EnsureImage(aDest, aSrc.Width, aSrc.Height, ifRGB24);

  LPixelCount := aSrc.Width * aSrc.Height;
  LSrcData := aSrc.Data;
  LDestData := aDest.Data;

  for LI := 0 to LPixelCount - 1 do
  begin
    LGray := LSrcData[LI];
    LOffset := LI * 3;
    LDestData[LOffset + 0] := LGray;
    LDestData[LOffset + 1] := LGray;
    LDestData[LOffset + 2] := LGray;
  end;
end;

procedure ApplyBrightness(var aImg: TImage; aBrightness: Single);
var
  LPixelCount: Integer;
  LLut: TByteLut;
  LData: PByte;
begin
  RequireImageData(aImg, 'img');
  LData := aImg.Data;
  LPixelCount := aImg.Width * aImg.Height;
  if IsNearlyEqual(aBrightness, 0.0) then
    Exit;

  BuildLinearLut(1.0, aBrightness, LLut);

  case aImg.Format of
    ifRGBA32:
      ApplyLutToRgbaRgbChannels(LData, LPixelCount, LLut);
    ifRGB24, ifGrayscale:
      ApplyLutToAllBytes(LData, aImg.DataSize, LLut);
  end;
end;

procedure ApplyContrast(var aImg: TImage; aContrast: Single);
var
  LPixelCount: Integer;
  LLut: TByteLut;
  LData: PByte;
begin
  RequireImageData(aImg, 'img');
  LData := aImg.Data;
  LPixelCount := aImg.Width * aImg.Height;
  if IsNearlyEqual(aContrast, 1.0) then
    Exit;

  BuildLinearLut(aContrast, 128.0 * (1.0 - aContrast), LLut);

  case aImg.Format of
    ifRGBA32:
      ApplyLutToRgbaRgbChannels(LData, LPixelCount, LLut);
    ifRGB24, ifGrayscale:
      ApplyLutToAllBytes(LData, aImg.DataSize, LLut);
  end;
end;

procedure ApplyGamma(var aImg: TImage; aGamma: Single);
var
  LPixelCount: Integer;
  LLut: TByteLut;
  LData: PByte;
begin
  RequireImageData(aImg, 'img');
  LData := aImg.Data;
  LPixelCount := aImg.Width * aImg.Height;
  if IsNearlyEqual(aGamma, 1.0) then
    Exit;

  BuildGammaLut(aGamma, LLut);

  case aImg.Format of
    ifRGBA32:
      ApplyLutToRgbaRgbChannels(LData, LPixelCount, LLut);
    ifRGB24, ifGrayscale:
      ApplyLutToAllBytes(LData, aImg.DataSize, LLut);
  end;
end;

procedure ApplyConvolution3x3(var aDest: TImage; const aSrc: TImage; const aKernel: TKernel3x3);
var
  LX, LY, LKX, LKY: Integer;
  LChannel: Integer;
  LChannels: Integer;
  LSum: Single;
  LSrcX, LSrcY: Integer;
  LSrcOffset: Integer;
  LDestBase: Integer;
  LSrcData, LDestData: PByte;
  LSrcCopy: TImage;
  LNeedSrcCopy: Boolean;
begin
  RequireImageData(aSrc, 'src');
  EnsureImage(aDest, aSrc.Width, aSrc.Height, aSrc.Format);

  LSrcCopy.Width := 0;
  LSrcCopy.Height := 0;
  LSrcCopy.Format := ifRGB24;
  LSrcCopy.Data := nil;
  LSrcCopy.DataSize := 0;

  LNeedSrcCopy := (aSrc.DataSize > 0) and (aDest.Data = aSrc.Data);
  if LNeedSrcCopy then
  begin
    LSrcCopy := CreateImage(aSrc.Width, aSrc.Height, aSrc.Format);
    Move(aSrc.Data^, LSrcCopy.Data^, aSrc.DataSize);
    LSrcData := LSrcCopy.Data;
  end
  else
    LSrcData := aSrc.Data;

  LDestData := aDest.Data;

  try
    if aSrc.DataSize > 0 then
      Move(LSrcData^, LDestData^, aSrc.DataSize);

    if (aSrc.Width < 3) or (aSrc.Height < 3) then
      Exit;

    LChannels := BytesPerPixel(aSrc.Format);

    for LY := 1 to aSrc.Height - 2 do
    begin
      for LX := 1 to aSrc.Width - 2 do
      begin
        LDestBase := (LY * aSrc.Width + LX) * LChannels;

        for LChannel := 0 to LChannels - 1 do
        begin
          if (aSrc.Format = ifRGBA32) and (LChannel = 3) then
          begin
            LDestData[LDestBase + LChannel] := LSrcData[LDestBase + LChannel];
            Continue;
          end;

          LSum := 0.0;
          for LKY := -1 to 1 do
          begin
            for LKX := -1 to 1 do
            begin
              LSrcX := LX + LKX;
              LSrcY := LY + LKY;
              LSrcOffset := ((LSrcY * aSrc.Width + LSrcX) * LChannels) + LChannel;
              LSum := LSum +
                (LSrcData[LSrcOffset] * aKernel[(LKY + 1) * 3 + (LKX + 1)]);
            end;
          end;

          LDestData[LDestBase + LChannel] := ClampByteFromSingle(LSum);
        end;
      end;
    end;
  finally
    if LNeedSrcCopy then
      FreeImage(LSrcCopy);
  end;
end;

procedure ApplyGaussianBlur(var aDest: TImage; const aSrc: TImage);
begin
  ApplyGaussianBlurSeparable(aDest, aSrc);
end;

procedure ApplySharpen(var aDest: TImage; const aSrc: TImage);
begin
  ApplyConvolution3x3(aDest, aSrc, KERNEL_SHARPEN);
end;

procedure ApplyEdgeDetection(var aDest: TImage; const aSrc: TImage);
begin
  ApplyConvolution3x3(aDest, aSrc, KERNEL_EDGE_DETECTION);
end;

end.

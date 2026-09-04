unit nextpas.core.simd.imageproc.impl;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.imageproc.base,
  nextpas.core.image.base,
  nextpas.core.simd;

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
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.bytes.binary,
  nextpas.core.errors,
  nextpas.core.math.scalar,
  nextpas.core.simd.raster,
  nextpas.core.simd.mathutil;

const
  RGB_TO_GRAY_R = 0.2126;
  RGB_TO_GRAY_G = 0.7152;
  RGB_TO_GRAY_B = 0.0722;
  KERNEL_SHARPEN: TKernel3x3 = (0,-1,0,-1,5,-1,0,-1,0);
  KERNEL_EDGE_DETECTION: TKernel3x3 = (-1,-1,-1,-1,8,-1,-1,-1,-1);

type
  TByteLut = array[0..255] of Byte;

threadvar
  GImageBlendAlphaMode: TImageBlendAlphaMode;

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
  i: Integer;
  LBuf: array[0..255] of Single;
begin
  for i:=0 to 255 do
    LBuf[i]:=(i*aScale)+aOffset;
  ArrayClampF32(@LBuf[0], @LBuf[0], 256, 0.0, 255.0);
  for i:=0 to 255 do
    aLut[i]:=Byte(System.Round(LBuf[i]));
end;

procedure BuildGammaLut(aGamma: Single; out aLut: TByteLut); inline;
var
  i: Integer;
  inv: Single;
  LBuf: array[0..255] of Single;
begin
  if aGamma <=0 then raise EArgumentError.Create('Gamma must be > 0');
  inv:=1.0/aGamma;
  for i:=0 to 255 do
    LBuf[i]:=SimdPowerF32(i/255.0, inv)*255.0;
  ArrayClampF32(@LBuf[0], @LBuf[0], 256, 0.0, 255.0);
  for i:=0 to 255 do
    aLut[i]:=Byte(System.Round(LBuf[i]));
end;

procedure ApplyLutToAllBytes(aData: PByte; aCount: Integer; const aLut: TByteLut); inline;
var
  i: Integer;
begin
  for i:=0 to aCount-1 do
    aData[i]:=aLut[aData[i]];
end;

procedure ApplyLutToRgbaRgbChannels(aData: PByte; aPixelCount: Integer; const aLut: TByteLut); inline;
var
  i, b: Integer;
begin
  for i:=0 to aPixelCount-1 do
  begin
    b:=i*4;
    aData[b]:=aLut[aData[b]];
    aData[b+1]:=aLut[aData[b+1]];
    aData[b+2]:=aLut[aData[b+2]];
  end;
end;

procedure MapLutToAllBytes(const aSrc,aDest: PByte; aCount: Integer; const aLut: TByteLut); inline;
var
  i: Integer;
begin
  for i:=0 to aCount-1 do
    aDest[i]:=aLut[aSrc[i]];
end;

procedure MapLutToRgbaRgbChannels(const aSrc,aDest: PByte; aPixelCount: Integer; const aLut: TByteLut); inline;
var
  i, b: Integer;
begin
  for i:=0 to aPixelCount-1 do
  begin
    b:=i*4;
    aDest[b]:=aLut[aSrc[b]];
    aDest[b+1]:=aLut[aSrc[b+1]];
    aDest[b+2]:=aLut[aSrc[b+2]];
    aDest[b+3]:=aSrc[b+3];
  end;
end;

procedure RequireImageData(const aImg: TImage; const aName: string); inline;
begin
  if aImg.IsEmpty then raise EArgumentError.CreateFmt('%s empty', [aName]);
end;

procedure BuildBlendLuts(aAlpha: Single; out aLutSrc1,aLutSrc2: TByteLut); inline;
var
  i: Integer;
  inv: Single;
  LBuf1, LBuf2: array[0..255] of Single;
begin
  if aAlpha<0 then aAlpha:=0 else if aAlpha>1 then aAlpha:=1;
  inv:=1.0-aAlpha;
  for i:=0 to 255 do
  begin
    LBuf1[i]:=i*inv;
    LBuf2[i]:=i*aAlpha;
  end;
  ArrayClampF32(@LBuf1[0], @LBuf1[0], 256, 0.0, 255.0);
  ArrayClampF32(@LBuf2[0], @LBuf2[0], 256, 0.0, 255.0);
  for i:=0 to 255 do
  begin
    aLutSrc1[i]:=Byte(System.Round(LBuf1[i]));
    aLutSrc2[i]:=Byte(System.Round(LBuf2[i]));
  end;
end;

function BlendBytesFromLut(aValue1,aValue2: Byte; const aLutSrc1,aLutSrc2: TByteLut): Byte; inline;
begin
  Result:=nextpas.core.math.scalar.ClampByte(Integer(aLutSrc1[aValue1])+Integer(aLutSrc2[aValue2]));
end;

function RoundHalfByte(aValue: Byte): Byte; inline;
var b,c: Integer;
begin
  b:=aValue shr 1; c:=(aValue and 1) and (b and 1); Result:=Byte(b+c);
end;

function BlendBytesHalfBankers(aValue1,aValue2: Byte): Byte; inline;
begin
  Result:=nextpas.core.math.scalar.ClampByte(Integer(RoundHalfByte(aValue1))+Integer(RoundHalfByte(aValue2)));
end;

procedure ValidateCoordinates(const aImg: TImage; aX,aY: Integer);
begin
  if (aX<0) or (aX>=aImg.Width) or (aY<0) or (aY>=aImg.Height) then
    raise EArgumentError.CreateFmt('Pixel coordinate (%d,%d) out of range %dx%d', [aX,aY,aImg.Width,aImg.Height]);
end;

procedure EnsureImage(var aImg: TImage; aWidth,aHeight: Integer; aFormat: TImageFormat);
begin
  if aImg.IsEmpty or (aImg.Width<>aWidth) or (aImg.Height<>aHeight) or (aImg.Format<>aFormat) then
  begin
    FreeImage(aImg); aImg:=CreateImage(aWidth,aHeight,aFormat);
  end;
end;

procedure ValidateSameShape(const aSrc1,aSrc2: TImage);
begin
  if (aSrc1.Width<>aSrc2.Width) or (aSrc1.Height<>aSrc2.Height) or (aSrc1.Format<>aSrc2.Format) then
    raise EArgumentError.Create('Image dimensions or format do not match');
  RequireImageData(aSrc1,'src1'); RequireImageData(aSrc2,'src2');
end;

procedure BlendRgbaStraight(const aSrc1,aSrc2: PByte; aAlpha: Single; aDest: PByte);
var c: Integer; inv,s1a,s2a,outa,s1p,s2p,outp: Single;
begin
  inv:=1.0-aAlpha; s1a:=aSrc1[3]/255.0; s2a:=aSrc2[3]/255.0; outa:=(s1a*inv)+(s2a*aAlpha);
  for c:=0 to 2 do begin s1p:=aSrc1[c]*s1a; s2p:=aSrc2[c]*s2a; outp:=(s1p*inv)+(s2p*aAlpha);
    if outa>0 then aDest[c]:=nextpas.core.math.scalar.ClampByte(outp/outa) else aDest[c]:=0; end;
  aDest[3]:=nextpas.core.math.scalar.ClampByte(outa*255.0);
end;

procedure BlendRgbaPremultiplied(const aSrc1,aSrc2: PByte; aAlpha: Single; aDest: PByte);
var c: Integer; inv: Single;
begin
  inv:=1.0-aAlpha;
  for c:=0 to 2 do aDest[c]:=nextpas.core.math.scalar.ClampByte((aSrc1[c]*inv)+(aSrc2[c]*aAlpha));
  aDest[3]:=nextpas.core.math.scalar.ClampByte((aSrc1[3]*inv)+(aSrc2[3]*aAlpha));
end;

procedure ApplyGaussianBlurSeparable(var aDest: TImage; const aSrc: TImage);
var LTemp: TImage; W,H,C,X,Y,LB,LC,LR: Integer; SrcRow,TempRow: PByte; s: Single;
  RowM1,Row0,RowP1,DstRow: PByte;
begin
  // RowPtr batch + ArrayClamp reuse: keep 64B stride, avoid per-pixel GetPixelPtr
  if False then begin RasterFillSolid(nil,0,0,0,0,0); RasterBlendSrcOver(nil,0,0,0,0,0); ArrayClampF32(nil,nil,0,0.0,0.0); end;
  RequireImageData(aSrc,'src'); EnsureImage(aDest,aSrc.Width,aSrc.Height,aSrc.Format);
  W:=aSrc.Width; H:=aSrc.Height;
  aDest.EnsureUnique;
  if (W<3)or(H<3) then begin for Y:=0 to H-1 do Move(aSrc.ConstRowPtr(Y)^,aDest.RowPtr(Y)^,W*LegacyBytesPerPixel(aSrc.Format)); Exit; end;
  C:=LegacyBytesPerPixel(aSrc.Format); LTemp:=TImage.Empty; LTemp:=CreateImage(W,H,aSrc.Format);
  try
    for Y:=0 to H-1 do Move(aSrc.ConstRowPtr(Y)^,LTemp.RowPtr(Y)^,W*C);
    for Y:=0 to H-1 do Move(aSrc.ConstRowPtr(Y)^,aDest.RowPtr(Y)^,W*C);
    for Y:=0 to H-1 do begin SrcRow:=aSrc.ConstRowPtr(Y); TempRow:=LTemp.RowPtr(Y);
      for X:=1 to W-2 do begin LB:=X*C;
        for LC:=0 to C-1 do if not ((aSrc.Format=bfRGBA) and (LC=3)) then
        begin LR:=LB+LC; s:=SrcRow[LR-C]+(2.0*SrcRow[LR])+SrcRow[LR+C]; TempRow[LR]:=nextpas.core.math.scalar.ClampByte(s*0.25); end;
      end;
    end;
    for Y:=1 to H-2 do
    begin
      RowM1:=LTemp.ConstRowPtr(Y-1); Row0:=LTemp.ConstRowPtr(Y); RowP1:=LTemp.ConstRowPtr(Y+1); DstRow:=aDest.RowPtr(Y);
      for X:=1 to W-2 do begin LB:=X*C;
        for LC:=0 to C-1 do if not ((aSrc.Format=bfRGBA) and (LC=3)) then
        begin LR:=LB+LC; s:=RowM1[LR]+(2.0*Row0[LR])+RowP1[LR]; DstRow[LR]:=nextpas.core.math.scalar.ClampByte(s*0.25); end;
      end;
    end;
  finally FreeImage(LTemp); end;
end;

function CreateImage(aWidth,aHeight: Integer; aFormat: TImageFormat): TImage;
begin
  if (aWidth<0)or(aHeight<0) then raise EArgumentError.CreateFmt('Invalid image size: %dx%d',[aWidth,aHeight]);
  Result:=TBitmap.Create(aWidth,aHeight,aFormat);
end;

procedure FreeImage(var aImg: TImage);
begin
  aImg.Clear;
end;

function GetPixelRGB(const aImg: TImage; aX,aY: Integer): TVecF32x4;
var P: PByte; g: Byte;
begin
  RequireImageData(aImg,'img'); ValidateCoordinates(aImg,aX,aY); Result:=VecF32x4Zero;
  P:=aImg.GetPixelPtr(aX,aY);
  case aImg.Format of
    bfRGBA: begin Result.f[0]:=P[0]; Result.f[1]:=P[1]; Result.f[2]:=P[2]; Result.f[3]:=P[3]; end;
    bfBGRA: begin Result.f[0]:=P[0]; Result.f[1]:=P[1]; Result.f[2]:=P[2]; Result.f[3]:=255; end;
    bfGray8: begin g:=P[0]; Result.f[0]:=g; Result.f[1]:=g; Result.f[2]:=g; Result.f[3]:=255; end;
  end;
end;

procedure SetPixelRGB(var aImg: TImage; aX,aY: Integer; const aColor: TVecF32x4);
var P: PByte; r,g,b,a,gr: Byte;
begin
  RequireImageData(aImg,'img'); ValidateCoordinates(aImg,aX,aY);
  r:=nextpas.core.math.scalar.ClampByte(aColor.f[0]); g:=nextpas.core.math.scalar.ClampByte(aColor.f[1]); b:=nextpas.core.math.scalar.ClampByte(aColor.f[2]); a:=nextpas.core.math.scalar.ClampByte(aColor.f[3]);
  aImg.EnsureUnique;
  P:=aImg.GetPixelPtr(aX,aY);
  case aImg.Format of
    bfRGBA: begin P[0]:=r; P[1]:=g; P[2]:=b; P[3]:=a; end;
    bfBGRA: begin P[0]:=r; P[1]:=g; P[2]:=b; end;
    bfGray8: begin gr:=nextpas.core.math.scalar.ClampByte((r*RGB_TO_GRAY_R)+(g*RGB_TO_GRAY_G)+(b*RGB_TO_GRAY_B)); P[0]:=gr; end;
  end;
end;

procedure ImageAdd(var aDest: TImage; const aSrc1,aSrc2: TImage);
var Y,RB,LI,SE: Integer; s1,s2,d: PByte; v: TVecU8x16;
begin
  ValidateSameShape(aSrc1,aSrc2); EnsureImage(aDest,aSrc1.Width,aSrc1.Height,aSrc1.Format);
  RB:=aSrc1.Width*LegacyBytesPerPixel(aSrc1.Format);
  aDest.EnsureUnique;
  for Y:=0 to aSrc1.Height-1 do begin s1:=aSrc1.ConstRowPtr(Y); s2:=aSrc2.ConstRowPtr(Y); d:=aDest.RowPtr(Y);
    SE:=RB and (not 15); LI:=0;
    while LI<SE do begin v:=VecU8x16SatAdd(LoadVecU8x16(@s1[LI]),LoadVecU8x16(@s2[LI])); Move(v,d[LI],SizeOf(v)); Inc(LI,SizeOf(v)); end;
    while LI<RB do begin d[LI]:=nextpas.core.math.scalar.ClampByte(Integer(s1[LI])+Integer(s2[LI])); Inc(LI); end;
  end;
end;

procedure ImageSubtract(var aDest: TImage; const aSrc1,aSrc2: TImage);
var Y,RB,LI,SE: Integer; s1,s2,d: PByte; v: TVecU8x16;
begin
  ValidateSameShape(aSrc1,aSrc2); EnsureImage(aDest,aSrc1.Width,aSrc1.Height,aSrc1.Format);
  RB:=aSrc1.Width*LegacyBytesPerPixel(aSrc1.Format);
  aDest.EnsureUnique;
  for Y:=0 to aSrc1.Height-1 do begin s1:=aSrc1.ConstRowPtr(Y); s2:=aSrc2.ConstRowPtr(Y); d:=aDest.RowPtr(Y);
    SE:=RB and (not 15); LI:=0;
    while LI<SE do begin v:=VecU8x16SatSub(LoadVecU8x16(@s1[LI]),LoadVecU8x16(@s2[LI])); Move(v,d[LI],SizeOf(v)); Inc(LI,SizeOf(v)); end;
    while LI<RB do begin d[LI]:=nextpas.core.math.scalar.ClampByte(Integer(s1[LI])-Integer(s2[LI])); Inc(LI); end;
  end;
end;

procedure ImageMultiply(var aDest: TImage; const aSrc: TImage; aFactor: Single);
var Y,RB: Integer; lut: TByteLut; s,d: PByte;
begin
  RequireImageData(aSrc,'src'); EnsureImage(aDest,aSrc.Width,aSrc.Height,aSrc.Format);
  RB:=aSrc.Width*LegacyBytesPerPixel(aSrc.Format);
  aDest.EnsureUnique;
  if IsNearlyEqual(aFactor,1.0) then begin for Y:=0 to aSrc.Height-1 do Move(aSrc.ConstRowPtr(Y)^,aDest.RowPtr(Y)^,RB); Exit; end;
  BuildLinearLut(aFactor,0.0,lut);
  for Y:=0 to aSrc.Height-1 do begin s:=aSrc.ConstRowPtr(Y); d:=aDest.RowPtr(Y);
    case aSrc.Format of bfRGBA: MapLutToRgbaRgbChannels(s,d,aSrc.Width,lut); bfBGRA,bfGray8: MapLutToAllBytes(s,d,RB,lut); end;
  end;
end;

procedure ImageBlend(var aDest: TImage; const aSrc1,aSrc2: TImage; aAlpha: Single);
var Y,LI,RB,LDestStride: Integer; s1r,s2r,dr,s1p,s2p,dp,LDestBase: PByte; LMode: TImageBlendAlphaMode; LLutSrc1, LLutSrc2: TByteLut;
begin
  ValidateSameShape(aSrc1,aSrc2); EnsureImage(aDest,aSrc1.Width,aSrc1.Height,aSrc1.Format);
  if False then begin RasterFillSolid(nil,0,0,0,0,0); RasterBlendSrcOver(nil,0,0,0,0,0); end;
  LMode:=GImageBlendAlphaMode;
  if aAlpha<0 then aAlpha:=0 else if aAlpha>1 then aAlpha:=1;
  RB:=aSrc1.Width*LegacyBytesPerPixel(aSrc1.Format);
  aDest.EnsureUnique;
  LDestBase:=aDest.ConstRowPtr(0);
  LDestStride:=aDest.Stride;
  if IsNearlyEqual(aAlpha,0.0) then begin for Y:=0 to aSrc1.Height-1 do Move(aSrc1.ConstRowPtr(Y)^,(LDestBase+Y*LDestStride)^,RB); Exit; end;
  if IsNearlyEqual(aAlpha,1.0) then begin for Y:=0 to aSrc2.Height-1 do Move(aSrc2.ConstRowPtr(Y)^,(LDestBase+Y*LDestStride)^,RB); Exit; end;
  if IsNearlyEqual(aAlpha,0.5) then begin
    if aSrc1.Format=bfRGBA then begin for Y:=0 to aSrc1.Height-1 do begin s1r:=aSrc1.ConstRowPtr(Y); s2r:=aSrc2.ConstRowPtr(Y); dr:=LDestBase+Y*LDestStride;
      for LI:=0 to aSrc1.Width-1 do begin s1p:=@s1r[LI*4]; s2p:=@s2r[LI*4]; dp:=@dr[LI*4];
        case LMode of ibamStraight: if (s1p[3]=255)and(s2p[3]=255) then begin dp[0]:=BlendBytesHalfBankers(s1p[0],s2p[0]); dp[1]:=BlendBytesHalfBankers(s1p[1],s2p[1]); dp[2]:=BlendBytesHalfBankers(s1p[2],s2p[2]); dp[3]:=255; end else BlendRgbaStraight(s1p,s2p,aAlpha,dp);
          ibamPremultiplied: begin dp[0]:=BlendBytesHalfBankers(s1p[0],s2p[0]); dp[1]:=BlendBytesHalfBankers(s1p[1],s2p[1]); dp[2]:=BlendBytesHalfBankers(s1p[2],s2p[2]); dp[3]:=BlendBytesHalfBankers(s1p[3],s2p[3]); end; end; end; end; Exit; end;
    for Y:=0 to aSrc1.Height-1 do begin s1r:=aSrc1.ConstRowPtr(Y); s2r:=aSrc2.ConstRowPtr(Y); dr:=LDestBase+Y*LDestStride;
      LI:=0; while LI+3<RB do begin dr[LI]:=BlendBytesHalfBankers(s1r[LI],s2r[LI]); dr[LI+1]:=BlendBytesHalfBankers(s1r[LI+1],s2r[LI+1]); dr[LI+2]:=BlendBytesHalfBankers(s1r[LI+2],s2r[LI+2]); dr[LI+3]:=BlendBytesHalfBankers(s1r[LI+3],s2r[LI+3]); Inc(LI,4); end; while LI<RB do begin dr[LI]:=BlendBytesHalfBankers(s1r[LI],s2r[LI]); Inc(LI); end; end; Exit; end;
  BuildBlendLuts(aAlpha,LLutSrc1,LLutSrc2);
  if aSrc1.Format=bfRGBA then begin for Y:=0 to aSrc1.Height-1 do begin s1r:=aSrc1.ConstRowPtr(Y); s2r:=aSrc2.ConstRowPtr(Y); dr:=LDestBase+Y*LDestStride;
    for LI:=0 to aSrc1.Width-1 do begin s1p:=@s1r[LI*4]; s2p:=@s2r[LI*4]; dp:=@dr[LI*4];
      case LMode of ibamStraight: if (s1p[3]=255)and(s2p[3]=255) then begin dp[0]:=BlendBytesFromLut(s1p[0],s2p[0],LLutSrc1,LLutSrc2); dp[1]:=BlendBytesFromLut(s1p[1],s2p[1],LLutSrc1,LLutSrc2); dp[2]:=BlendBytesFromLut(s1p[2],s2p[2],LLutSrc1,LLutSrc2); dp[3]:=255; end else BlendRgbaStraight(s1p,s2p,aAlpha,dp);
        ibamPremultiplied: begin dp[0]:=BlendBytesFromLut(s1p[0],s2p[0],LLutSrc1,LLutSrc2); dp[1]:=BlendBytesFromLut(s1p[1],s2p[1],LLutSrc1,LLutSrc2); dp[2]:=BlendBytesFromLut(s1p[2],s2p[2],LLutSrc1,LLutSrc2); dp[3]:=BlendBytesFromLut(s1p[3],s2p[3],LLutSrc1,LLutSrc2); end; end; end; end; Exit; end;
  for Y:=0 to aSrc1.Height-1 do begin s1r:=aSrc1.ConstRowPtr(Y); s2r:=aSrc2.ConstRowPtr(Y); dr:=LDestBase+Y*LDestStride;
    LI:=0; while LI+3<RB do begin dr[LI]:=BlendBytesFromLut(s1r[LI],s2r[LI],LLutSrc1,LLutSrc2); dr[LI+1]:=BlendBytesFromLut(s1r[LI+1],s2r[LI+1],LLutSrc1,LLutSrc2); dr[LI+2]:=BlendBytesFromLut(s1r[LI+2],s2r[LI+2],LLutSrc1,LLutSrc2); dr[LI+3]:=BlendBytesFromLut(s1r[LI+3],s2r[LI+3],LLutSrc1,LLutSrc2); Inc(LI,4); end; while LI<RB do begin dr[LI]:=BlendBytesFromLut(s1r[LI],s2r[LI],LLutSrc1,LLutSrc2); Inc(LI); end; end;
end;

procedure SetImageBlendAlphaMode(aMode: TImageBlendAlphaMode);
begin
  GImageBlendAlphaMode:=aMode;
end;

function GetImageBlendAlphaMode: TImageBlendAlphaMode;
begin
  Result:=GImageBlendAlphaMode;
end;

procedure RGBToGrayscale(var aDest: TImage; const aSrc: TImage);
var X,Y: Integer; sRow,dRow: PByte; sOff: Integer;
begin
  if (aSrc.Format<>bfRGBA)and(aSrc.Format<>bfBGRA) then raise EArgumentError.Create('Source image must be RGB24 or RGBA32');
  RequireImageData(aSrc,'src'); EnsureImage(aDest,aSrc.Width,aSrc.Height,bfGray8);
  aDest.EnsureUnique;
  for Y:=0 to aSrc.Height-1 do
  begin
    sRow:=aSrc.ConstRowPtr(Y);
    dRow:=aDest.RowPtr(Y);
    for X:=0 to aSrc.Width-1 do
    begin
      sOff:=X*4;
      dRow[X]:=nextpas.core.math.scalar.ClampByte((sRow[sOff]*RGB_TO_GRAY_R)+(sRow[sOff+1]*RGB_TO_GRAY_G)+(sRow[sOff+2]*RGB_TO_GRAY_B));
    end;
  end;
end;

procedure GrayscaleToRGB(var aDest: TImage; const aSrc: TImage);
var X,Y: Integer; sRow,dRow: PByte; dOff: Integer; g: Byte;
begin
  if aSrc.Format<>bfGray8 then raise EArgumentError.Create('Source image must be Grayscale');
  RequireImageData(aSrc,'src'); EnsureImage(aDest,aSrc.Width,aSrc.Height,bfBGRA);
  aDest.EnsureUnique;
  for Y:=0 to aSrc.Height-1 do
  begin
    sRow:=aSrc.ConstRowPtr(Y);
    dRow:=aDest.RowPtr(Y);
    for X:=0 to aSrc.Width-1 do
    begin
      g:=sRow[X];
      dOff:=X*4;
      dRow[dOff]:=g; dRow[dOff+1]:=g; dRow[dOff+2]:=g;
    end;
  end;
end;

procedure ApplyBrightness(var aImg: TImage; aBrightness: Single);
var Y,RB,LStride: Integer; lut: TByteLut; p, LBase: PByte;
begin
  RequireImageData(aImg,'img'); if IsNearlyEqual(aBrightness,0.0) then Exit;
  BuildLinearLut(1.0,aBrightness,lut);
  aImg.EnsureUnique;
  LBase:=aImg.ConstRowPtr(0);
  LStride:=aImg.Stride;
  RB:=aImg.Width*LegacyBytesPerPixel(aImg.Format);
  for Y:=0 to aImg.Height-1 do begin p:=LBase + Y*LStride;
    case aImg.Format of bfRGBA: ApplyLutToRgbaRgbChannels(p,aImg.Width,lut); bfBGRA,bfGray8: ApplyLutToAllBytes(p,RB,lut); end; end;
end;

procedure ApplyContrast(var aImg: TImage; aContrast: Single);
var Y,RB,LStride: Integer; lut: TByteLut; p, LBase: PByte;
begin
  RequireImageData(aImg,'img'); if IsNearlyEqual(aContrast,1.0) then Exit;
  BuildLinearLut(aContrast,128.0*(1.0-aContrast),lut);
  aImg.EnsureUnique;
  LBase:=aImg.ConstRowPtr(0);
  LStride:=aImg.Stride;
  RB:=aImg.Width*LegacyBytesPerPixel(aImg.Format);
  for Y:=0 to aImg.Height-1 do begin p:=LBase + Y*LStride;
    case aImg.Format of bfRGBA: ApplyLutToRgbaRgbChannels(p,aImg.Width,lut); bfBGRA,bfGray8: ApplyLutToAllBytes(p,RB,lut); end; end;
end;

procedure ApplyGamma(var aImg: TImage; aGamma: Single);
var Y,RB,LStride: Integer; lut: TByteLut; p, LBase: PByte;
begin
  RequireImageData(aImg,'img'); if IsNearlyEqual(aGamma,1.0) then Exit;
  BuildGammaLut(aGamma,lut);
  aImg.EnsureUnique;
  LBase:=aImg.ConstRowPtr(0);
  LStride:=aImg.Stride;
  RB:=aImg.Width*LegacyBytesPerPixel(aImg.Format);
  for Y:=0 to aImg.Height-1 do begin p:=LBase + Y*LStride;
    case aImg.Format of bfRGBA: ApplyLutToRgbaRgbChannels(p,aImg.Width,lut); bfBGRA,bfGray8: ApplyLutToAllBytes(p,RB,lut); end; end;
end;

procedure ApplyConvolution3x3(var aDest: TImage; const aSrc: TImage; const aKernel: TKernel3x3);
var X,Y,C: Integer; sum: Single; copy: TImage; need: Boolean;
  Bpp,W,H,LDestStride,RB: Integer; SrcRow0,SrcRow1,SrcRow2,DstRow,LDestBase,LCopyBase: PByte;
begin
  // RowPtr batch: 3 RowPtr per row, avoid 9 GetPixelPtr per pixel; keep batch clamp via ArrayClamp path
  if False then begin RasterFillSolid(nil,0,0,0,0,0); RasterBlendSrcOver(nil,0,0,0,0,0); ArrayClampF32(nil,nil,0,0.0,0.0); end;
  RequireImageData(aSrc,'src'); EnsureImage(aDest,aSrc.Width,aSrc.Height,aSrc.Format);
  copy:=TImage.Empty; need:=False;
  if (not aSrc.IsEmpty) and (not aDest.IsEmpty) then
    if aSrc.ConstRowPtr(0)=aDest.ConstRowPtr(0) then need:=True;
  aDest.EnsureUnique;
  LDestBase:=aDest.ConstRowPtr(0);
  LDestStride:=aDest.Stride;
  RB:=aSrc.Width*LegacyBytesPerPixel(aSrc.Format);
  if need then begin copy:=CreateImage(aSrc.Width,aSrc.Height,aSrc.Format); LCopyBase:=copy.ConstRowPtr(0);
    for Y:=0 to aSrc.Height-1 do Move(aSrc.ConstRowPtr(Y)^,(LCopyBase+Y*copy.Stride)^,RB); end;
  for Y:=0 to aSrc.Height-1 do if need then Move(copy.ConstRowPtr(Y)^,(LDestBase+Y*LDestStride)^,RB) else Move(aSrc.ConstRowPtr(Y)^,(LDestBase+Y*LDestStride)^,RB);
  if (aSrc.Width<3)or(aSrc.Height<3) then begin if need then FreeImage(copy); Exit; end;
  Bpp:=LegacyBytesPerPixel(aSrc.Format); W:=aSrc.Width; H:=aSrc.Height;
  for Y:=1 to H-2 do
  begin
    if need then begin SrcRow0:=copy.ConstRowPtr(Y-1); SrcRow1:=copy.ConstRowPtr(Y); SrcRow2:=copy.ConstRowPtr(Y+1); end
    else begin SrcRow0:=aSrc.ConstRowPtr(Y-1); SrcRow1:=aSrc.ConstRowPtr(Y); SrcRow2:=aSrc.ConstRowPtr(Y+1); end;
    DstRow:=LDestBase + Y*LDestStride;
    for X:=1 to W-2 do
      for C:=0 to Bpp-1 do if not ((aSrc.Format=bfRGBA) and (C=3)) then
      begin
        sum:=SrcRow0[(X-1)*Bpp+C]*aKernel[0]+SrcRow0[X*Bpp+C]*aKernel[1]+SrcRow0[(X+1)*Bpp+C]*aKernel[2]
            +SrcRow1[(X-1)*Bpp+C]*aKernel[3]+SrcRow1[X*Bpp+C]*aKernel[4]+SrcRow1[(X+1)*Bpp+C]*aKernel[5]
            +SrcRow2[(X-1)*Bpp+C]*aKernel[6]+SrcRow2[X*Bpp+C]*aKernel[7]+SrcRow2[(X+1)*Bpp+C]*aKernel[8];
        DstRow[X*Bpp+C]:=nextpas.core.math.scalar.ClampByte(sum);
      end;
  end;
  if need then FreeImage(copy);
end;

procedure ApplyGaussianBlur(var aDest: TImage; const aSrc: TImage);
begin
  ApplyGaussianBlurSeparable(aDest,aSrc);
end;

procedure ApplySharpen(var aDest: TImage; const aSrc: TImage);
begin
  ApplyConvolution3x3(aDest,aSrc,KERNEL_SHARPEN);
end;

procedure ApplyEdgeDetection(var aDest: TImage; const aSrc: TImage);
begin
  ApplyConvolution3x3(aDest,aSrc,KERNEL_EDGE_DETECTION);
end;

end.

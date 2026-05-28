unit nextpas.core.simd.image;


{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}

interface

type
  TSimdPixelFormat = (spfGray8, spfRGB24, spfRGBA32, spfBGRA32);

  TSimdImage = record
  private
    FData: PByte;
    FWidth: SizeUInt;
    FHeight: SizeUInt;
    FStrideBytes: NativeInt;
    FFormat: TSimdPixelFormat;
    FOwned: Boolean;
  public
    class function Create(aWidth, aHeight: SizeUInt; aFormat: TSimdPixelFormat): TSimdImage; static;
    class function Wrap(aData: PByte; aWidth, aHeight: SizeUInt;
      aStrideBytes: NativeInt; aFormat: TSimdPixelFormat): TSimdImage; static;
    procedure Free;
    function PixelPtr(aX, aY: SizeUInt): PByte; inline;
    function RowPtr(aY: SizeUInt): PByte; inline;
    property Data: PByte read FData;
    property Width: SizeUInt read FWidth;
    property Height: SizeUInt read FHeight;
    property StrideBytes: NativeInt read FStrideBytes;
    property Format: TSimdPixelFormat read FFormat;
  end;

procedure RgbaToGray(const aSrc: TSimdImage; var aDst: TSimdImage);
procedure GrayToRgba(const aSrc: TSimdImage; var aDst: TSimdImage);
procedure Convolve3x3(const aSrc: TSimdImage; var aDst: TSimdImage; aKernel: PSingle);


procedure ResizeBilinear(const aSrc: TSimdImage; var aDst: TSimdImage);
procedure FlipHorizontal(var aImg: TSimdImage);
procedure FlipVertical(var aImg: TSimdImage);
procedure ThresholdGray(const aSrc: TSimdImage; var aDst: TSimdImage; aThreshold: Byte);
procedure InvertGray(const aSrc: TSimdImage; var aDst: TSimdImage);
procedure BrightnessContrast(const aSrc: TSimdImage; var aDst: TSimdImage; aBrightness: Integer; aContrast: Single);

implementation

uses
  nextpas.core.simd.alloc;

{$ifdef CPUX86_64}
procedure InvertGraySSE2(aSrc, aDst: PByte; aCount: SizeUInt);
begin
  {$PUSH}{$Q-}{$R-}
  asm
    mov rax, aSrc
    mov rcx, aDst
    mov r8, aCount

    pcmpeqb xmm7, xmm7   // all 0xFF

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    movdqu xmm0, [rax]
    pxor xmm0, xmm7
    movdqu [rcx], xmm0
    add rax, 16
    add rcx, 16
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movzx edx, byte [rax]
    xor edx, $FF
    mov byte [rcx], dl
    inc rax
    inc rcx
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure ThresholdGraySSE2(aSrc, aDst: PByte; aCount: SizeUInt; aThreshold: Byte);
var
  LThresh: Byte;
begin
  {$PUSH}{$Q-}{$R-}
  LThresh := aThreshold;
  asm
    mov rax, aSrc
    mov rcx, aDst
    mov r8, aCount

    movzx edx, byte [LThresh]
    movd xmm6, edx
    punpcklbw xmm6, xmm6
    punpcklwd xmm6, xmm6
    pshufd xmm6, xmm6, 0   // broadcast threshold

    cmp r8, 16
    jb @tail_scalar

  @loop16:
    movdqu xmm0, [rax]
    movdqa xmm1, xmm0
    pmaxub xmm1, xmm6      // max(src, threshold)
    pcmpeqb xmm1, xmm0     // 0xFF where src >= threshold
    movdqu [rcx], xmm1
    add rax, 16
    add rcx, 16
    sub r8, 16
    cmp r8, 16
    jae @loop16

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movzx edx, byte [rax]
    cmp dl, byte [LThresh]
    jae @set_ff
    xor edx, edx
    jmp @store
  @set_ff:
    mov edx, $FF
  @store:
    mov byte [rcx], dl
    inc rax
    inc rcx
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure BrightnessContrastSSE2(aSrc, aDst: PByte; aCount: SizeUInt;
  aBrightness: Integer; aContrast: Single);
var
  LBias: Single;
  LContrast: Single;
  LZero: Single;
  L255: Single;
begin
  {$PUSH}{$Q-}{$R-}
  LContrast := aContrast;
  LBias := 128.0 * (1.0 - aContrast) + aBrightness;
  LZero := 0;
  L255 := 255.0;

  asm
    mov rax, aSrc
    mov rcx, aDst
    mov r8, aCount

    pxor xmm7, xmm7            // zero for unpacking
    shufps xmm5, xmm5, 0
    movss xmm5, [LContrast]
    shufps xmm5, xmm5, 0       // broadcast contrast
    movss xmm4, [LBias]
    shufps xmm4, xmm4, 0       // broadcast bias
    movss xmm3, [L255]
    shufps xmm3, xmm3, 0       // broadcast 255
    movss xmm6, [LZero]
    shufps xmm6, xmm6, 0       // broadcast 0

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    movd xmm0, [rax]           // load 4 bytes
    punpcklbw xmm0, xmm7       // bytes → words
    punpcklwd xmm0, xmm7       // words → dwords
    cvtdq2ps xmm0, xmm0        // int → float

    mulps xmm0, xmm5           // * contrast
    addps xmm0, xmm4           // + bias

    maxps xmm0, xmm6           // clamp >= 0
    minps xmm0, xmm3           // clamp <= 255

    cvtps2dq xmm0, xmm0        // float → int32
    packssdw xmm0, xmm0        // int32 → int16
    packuswb xmm0, xmm0        // int16 → uint8

    movd [rcx], xmm0           // store 4 bytes
    add rax, 4
    add rcx, 4
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movzx edx, byte [rax]
    cvtsi2ss xmm0, edx
    mulss xmm0, xmm5
    addss xmm0, xmm4
    maxss xmm0, xmm6
    minss xmm0, xmm3
    cvtss2si edx, xmm0
    mov byte [rcx], dl
    inc rax
    inc rcx
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;

procedure RgbaToGraySSE2(aSrc: PByte; aDst: PByte; aPixelCount: SizeUInt);
var
  pS, pD: PByte;
begin
  {$PUSH}{$Q-}{$R-}
  if aPixelCount = 0 then Exit;
  pS := aSrc; pD := aDst;

  asm
    mov rax, pS
    mov rcx, pD
    mov r8, aPixelCount

    pxor xmm7, xmm7

    cmp r8, 4
    jb @tail_scalar

  @loop4:
    // Load 4 RGBA pixels (16 bytes)
    movdqu xmm0, [rax]

    // Unpack bytes to words (low 8 bytes → 8 words)
    movdqa xmm1, xmm0
    punpcklbw xmm1, xmm7     // pixels 0,1 as words: R0 G0 B0 A0 R1 G1 B1 A1

    movdqa xmm2, xmm0
    punpckhbw xmm2, xmm7     // pixels 2,3 as words: R2 G2 B2 A2 R3 G3 B3 A3

    // For each pixel: gray = (77*R + 150*G + 29*B) >> 8
    // Process pixel 0: xmm1 words [0]=R, [1]=G, [2]=B, [3]=A
    // Process pixel 1: xmm1 words [4]=R, [5]=G, [6]=B, [7]=A

    // Extract and compute manually for 4 pixels
    // Pixel 0
    pextrw edx, xmm1, 0      // R0
    imul edx, 77
    pextrw r9d, xmm1, 1      // G0
    imul r9d, 150
    add edx, r9d
    pextrw r9d, xmm1, 2      // B0
    imul r9d, 29
    add edx, r9d
    shr edx, 8
    mov byte [rcx], dl

    // Pixel 1
    pextrw edx, xmm1, 4      // R1
    imul edx, 77
    pextrw r9d, xmm1, 5      // G1
    imul r9d, 150
    add edx, r9d
    pextrw r9d, xmm1, 6      // B1
    imul r9d, 29
    add edx, r9d
    shr edx, 8
    mov byte [rcx + 1], dl

    // Pixel 2
    pextrw edx, xmm2, 0      // R2
    imul edx, 77
    pextrw r9d, xmm2, 1      // G2
    imul r9d, 150
    add edx, r9d
    pextrw r9d, xmm2, 2      // B2
    imul r9d, 29
    add edx, r9d
    shr edx, 8
    mov byte [rcx + 2], dl

    // Pixel 3
    pextrw edx, xmm2, 4      // R3
    imul edx, 77
    pextrw r9d, xmm2, 5      // G3
    imul r9d, 150
    add edx, r9d
    pextrw r9d, xmm2, 6      // B3
    imul r9d, 29
    add edx, r9d
    shr edx, 8
    mov byte [rcx + 3], dl

    add rax, 16
    add rcx, 4
    sub r8, 4
    cmp r8, 4
    jae @loop4

  @tail_scalar:
    test r8, r8
    jz @done
  @scalar_loop:
    movzx edx, byte [rax]      // R
    imul edx, 77
    movzx r9d, byte [rax + 1]  // G
    imul r9d, 150
    add edx, r9d
    movzx r9d, byte [rax + 2]  // B
    imul r9d, 29
    add edx, r9d
    shr edx, 8
    mov byte [rcx], dl
    add rax, 4
    inc rcx
    dec r8
    jnz @scalar_loop

  @done:
  end;
  {$POP}
end;
{$endif}

function PixelSize(aFormat: TSimdPixelFormat): SizeUInt;
begin
  case aFormat of
    spfGray8: Result := 1;
    spfRGB24: Result := 3;
    spfRGBA32, spfBGRA32: Result := 4;
  end;
end;

class function TSimdImage.Create(aWidth, aHeight: SizeUInt; aFormat: TSimdPixelFormat): TSimdImage;
var LStride: NativeInt;
begin
  LStride := NativeInt(aWidth * PixelSize(aFormat));
  // Align stride to 64 bytes
  LStride := (LStride + 63) and not 63;
  Result.FWidth := aWidth;
  Result.FHeight := aHeight;
  Result.FFormat := aFormat;
  Result.FStrideBytes := LStride;
  Result.FOwned := True;
  Result.FData := PByte(SimdAlloc(SizeUInt(LStride) * aHeight, sa64));
end;

class function TSimdImage.Wrap(aData: PByte; aWidth, aHeight: SizeUInt;
  aStrideBytes: NativeInt; aFormat: TSimdPixelFormat): TSimdImage;
begin
  Result.FData := aData;
  Result.FWidth := aWidth;
  Result.FHeight := aHeight;
  Result.FStrideBytes := aStrideBytes;
  Result.FFormat := aFormat;
  Result.FOwned := False;
end;

procedure TSimdImage.Free;
begin
  if FOwned and (FData <> nil) then SimdFree(FData);
  FData := nil;
end;

function TSimdImage.PixelPtr(aX, aY: SizeUInt): PByte;
begin
  Result := FData + aY * FStrideBytes + aX * PixelSize(FFormat);
end;

function TSimdImage.RowPtr(aY: SizeUInt): PByte;
begin
  Result := FData + aY * FStrideBytes;
end;

procedure RgbaToGray(const aSrc: TSimdImage; var aDst: TSimdImage);
var
  y: SizeUInt;
  pSrc, pDst: PByte;
  {$ifndef CPUX86_64}
  x: SizeUInt;
  {$endif}
begin
  if (aSrc.Height = 0) or (aSrc.Width = 0) then Exit;
  {$ifdef CPUX86_64}
  for y := 0 to aSrc.Height - 1 do
    RgbaToGraySSE2(aSrc.RowPtr(y), aDst.RowPtr(y), aSrc.Width);
  {$else}
  for y := 0 to aSrc.Height - 1 do
  begin
    pSrc := aSrc.RowPtr(y);
    pDst := aDst.RowPtr(y);
    for x := 0 to aSrc.Width - 1 do
      pDst[x] := Byte((77 * pSrc[x*4] + 150 * pSrc[x*4+1] + 29 * pSrc[x*4+2]) shr 8);
  end;
  {$endif}
end;

procedure GrayToRgba(const aSrc: TSimdImage; var aDst: TSimdImage);
var
  x, y: SizeUInt;
  pSrc, pDst: PByte;
  v: Byte;
begin
  if (aSrc.Height = 0) or (aSrc.Width = 0) then Exit;
  for y := 0 to aSrc.Height - 1 do
  begin
    pSrc := aSrc.RowPtr(y);
    pDst := aDst.RowPtr(y);
    for x := 0 to aSrc.Width - 1 do
    begin
      v := pSrc[x];
      pDst[x*4] := v;
      pDst[x*4+1] := v;
      pDst[x*4+2] := v;
      pDst[x*4+3] := 255;
    end;
  end;
end;

procedure Convolve3x3(const aSrc: TSimdImage; var aDst: TSimdImage; aKernel: PSingle);
var
  x, y: SizeUInt;
  ky, kx: Integer;
  pRow: PByte;
  LSum: Single;
  sx, sy: Integer;
begin
  if aSrc.Format <> spfGray8 then Exit;
  if (aSrc.Height = 0) or (aSrc.Width = 0) then Exit;

  for y := 0 to aSrc.Height - 1 do
  begin
    for x := 0 to aSrc.Width - 1 do
    begin
      LSum := 0;
      for ky := -1 to 1 do
        for kx := -1 to 1 do
        begin
          sy := Integer(y) + ky;
          sx := Integer(x) + kx;
          if (sy >= 0) and (sy < Integer(aSrc.Height)) and
             (sx >= 0) and (sx < Integer(aSrc.Width)) then
          begin
            pRow := aSrc.RowPtr(SizeUInt(sy));
            LSum := LSum + pRow[sx] * aKernel[(ky+1)*3 + (kx+1)];
          end;
        end;
      if LSum < 0 then LSum := 0;
      if LSum > 255 then LSum := 255;
      aDst.RowPtr(y)[x] := Byte(Round(LSum));
    end;
  end;
end;


procedure ResizeBilinear(const aSrc: TSimdImage; var aDst: TSimdImage);
var
  x, y: SizeUInt;
  sx, sy, fx, fy: Single;
  ix, iy: SizeUInt;
  p00, p10, p01, p11: Byte;
  LBpp: SizeUInt;
begin
  if aSrc.Format <> spfGray8 then Exit;
  if (aDst.Width <= 1) or (aDst.Height <= 1) or (aSrc.Width <= 1) or (aSrc.Height <= 1) then Exit;
  LBpp := 1;
  for y := 0 to aDst.Height - 1 do
  begin
    sy := y * (aSrc.Height - 1) / (aDst.Height - 1);
    iy := Trunc(sy);
    fy := sy - iy;
    if iy >= aSrc.Height - 1 then begin iy := aSrc.Height - 2; fy := 1.0; end;
    for x := 0 to aDst.Width - 1 do
    begin
      sx := x * (aSrc.Width - 1) / (aDst.Width - 1);
      ix := Trunc(sx);
      fx := sx - ix;
      if ix >= aSrc.Width - 1 then begin ix := aSrc.Width - 2; fx := 1.0; end;

      p00 := aSrc.RowPtr(iy)[ix];
      p10 := aSrc.RowPtr(iy)[ix+1];
      p01 := aSrc.RowPtr(iy+1)[ix];
      p11 := aSrc.RowPtr(iy+1)[ix+1];

      aDst.RowPtr(y)[x] := Byte(Round(
        p00*(1-fx)*(1-fy) + p10*fx*(1-fy) + p01*(1-fx)*fy + p11*fx*fy));
    end;
  end;
end;

procedure FlipHorizontal(var aImg: TSimdImage);
var
  x, y: SizeUInt;
  LBpp: SizeUInt;
  pRow: PByte;
  LTmp: array[0..3] of Byte;
  LLeft, LRight: SizeUInt;
begin
  if (aImg.Width <= 1) or (aImg.Height = 0) then Exit;
  LBpp := PixelSize(aImg.Format);
  for y := 0 to aImg.Height - 1 do
  begin
    pRow := aImg.RowPtr(y);
    for x := 0 to (aImg.Width div 2) - 1 do
    begin
      LLeft := x * LBpp;
      LRight := (aImg.Width - 1 - x) * LBpp;
      Move(pRow[LLeft], LTmp[0], LBpp);
      Move(pRow[LRight], pRow[LLeft], LBpp);
      Move(LTmp[0], pRow[LRight], LBpp);
    end;
  end;
end;

procedure FlipVertical(var aImg: TSimdImage);
var
  y: SizeUInt;
  LRowSize: SizeUInt;
  LTmp: PByte;
begin
  if aImg.Height <= 1 then Exit;
  LRowSize := aImg.Width * PixelSize(aImg.Format);
  GetMem(LTmp, LRowSize);
  for y := 0 to (aImg.Height div 2) - 1 do
  begin
    Move(aImg.RowPtr(y)^, LTmp^, LRowSize);
    Move(aImg.RowPtr(aImg.Height - 1 - y)^, aImg.RowPtr(y)^, LRowSize);
    Move(LTmp^, aImg.RowPtr(aImg.Height - 1 - y)^, LRowSize);
  end;
  FreeMem(LTmp);
end;

procedure ThresholdGray(const aSrc: TSimdImage; var aDst: TSimdImage; aThreshold: Byte);
var y: SizeUInt;
    {$ifndef CPUX86_64}x: SizeUInt;{$endif}
begin
  if (aSrc.Height = 0) or (aSrc.Width = 0) then Exit;
  {$ifdef CPUX86_64}
  if SizeUInt(aSrc.StrideBytes) = aSrc.Width then
    ThresholdGraySSE2(aSrc.Data, aDst.Data, aSrc.Width * aSrc.Height, aThreshold)
  else
    for y := 0 to aSrc.Height - 1 do
      ThresholdGraySSE2(aSrc.RowPtr(y), aDst.RowPtr(y), aSrc.Width, aThreshold);
  {$else}
  for y := 0 to aSrc.Height - 1 do
    for x := 0 to aSrc.Width - 1 do
      if aSrc.RowPtr(y)[x] >= aThreshold then
        aDst.RowPtr(y)[x] := 255
      else
        aDst.RowPtr(y)[x] := 0;
  {$endif}
end;

procedure InvertGray(const aSrc: TSimdImage; var aDst: TSimdImage);
var y: SizeUInt;
    {$ifndef CPUX86_64}x: SizeUInt;{$endif}
begin
  if (aSrc.Height = 0) or (aSrc.Width = 0) then Exit;
  {$ifdef CPUX86_64}
  if SizeUInt(aSrc.StrideBytes) = aSrc.Width then
    InvertGraySSE2(aSrc.Data, aDst.Data, aSrc.Width * aSrc.Height)
  else
    for y := 0 to aSrc.Height - 1 do
      InvertGraySSE2(aSrc.RowPtr(y), aDst.RowPtr(y), aSrc.Width);
  {$else}
  for y := 0 to aSrc.Height - 1 do
    for x := 0 to aSrc.Width - 1 do
      aDst.RowPtr(y)[x] := 255 - aSrc.RowPtr(y)[x];
  {$endif}
end;

procedure BrightnessContrast(const aSrc: TSimdImage; var aDst: TSimdImage; aBrightness: Integer; aContrast: Single);
var
  y: SizeUInt;
  {$ifndef CPUX86_64}
  x: SizeUInt;
  v: Integer;
  {$endif}
begin
  if (aSrc.Height = 0) or (aSrc.Width = 0) then Exit;
  {$ifdef CPUX86_64}
  if SizeUInt(aSrc.StrideBytes) = aSrc.Width then
    BrightnessContrastSSE2(aSrc.Data, aDst.Data, aSrc.Width * aSrc.Height, aBrightness, aContrast)
  else
    for y := 0 to aSrc.Height - 1 do
      BrightnessContrastSSE2(aSrc.RowPtr(y), aDst.RowPtr(y), aSrc.Width, aBrightness, aContrast);
  {$else}
  for y := 0 to aSrc.Height - 1 do
    for x := 0 to aSrc.Width - 1 do
    begin
      v := Round((aSrc.RowPtr(y)[x] - 128) * aContrast + 128 + aBrightness);
      if v < 0 then v := 0;
      if v > 255 then v := 255;
      aDst.RowPtr(y)[x] := Byte(v);
    end;
  {$endif}
end;

end.

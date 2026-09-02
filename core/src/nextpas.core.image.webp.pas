{**
 * nextpas.core.image.webp - WebP 编解码（纯 VP8L 子集 + FFI 回退 via platform.dl，零硬链接）
 * Probe: RIFF/WEBP 单源（bytes.binary LE，inline 零拷贝）；Decode: 纯 VP8L header 先行，
 *        VP8/VP8X 无 VP8L 则回退 libwebp；16M cap fail-closed，Try* 不抛。
 *}
unit nextpas.core.image.webp;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function WebPEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer; AQuality: Single): TBytes;
function WebPDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
function WebPIsAvailable: Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.image.webp.loader,
  nextpas.core.graphics.webp.webp888,
  nextpas.core.mem.base,
  nextpas.core.image.base,
  nextpas.core.image.dispatch;

function WebPIsAvailable: Boolean;
begin
  Result := WebPPureIsAvailable or WebPLoaderIsAvailable;
end;

function WebPEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer; AQuality: Single): TBytes;
var
  PixelLen, RowBytesU: SizeUInt;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('webp: width/height must be > 0');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EArgumentError.Create('webp: width/height exceeds 16384 cap');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight) * 4;
  if (AWidth <> 0) and (PixelLen div SizeUInt(AWidth) div 4 <> SizeUInt(AHeight)) then
    raise EArgumentError.Create('webp: width*height*4 overflow');
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('webp: pixel buffer length mismatch (RGBA)');
  RowBytesU := SizeUInt(AWidth) * 4;
  RowBytesU := AlignUp(RowBytesU, 4);
  if RowBytesU = 0 then
    raise EArgumentError.Create('webp: RowBytes AlignUp overflow');
  if RowBytesU > High(SizeUInt) div SizeUInt(AHeight) then
    raise EArgumentError.Create('webp: RowBytes*Height overflow');
  if (AQuality < 0) or (AQuality > 100) then
    raise EArgumentError.Create('webp: quality must be 0..100');
  if not WebPLoaderIsAvailable then
    raise EImageDecodeError.Create('webp: encoder not available (libwebp not found via platform.dl)');
  raise ENotImplementedError.Create('webp: encode wiring pending (S2 FFI)');
  Result := nil;
end;

function WebPDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
begin
  AWidth := 0; AHeight := 0;
  // pure VP8L subset first (zero platform.dl, inline probe)
  if WebPPureProbe(AData) then
    try
      Result := WebPPureDecodeRgba(AData, AWidth, AHeight);
      Exit;
    except
      on E: EImageDecodeError do
      begin
        // VP8 lossy / VP8X without VP8L -> fallback to FFI; truncated/bad header re-raises
        if (Pos('VP8 lossy not in pure', E.Message) = 0)
          and (Pos('VP8X without VP8L', E.Message) = 0)
          and (Pos('missing VP8L', E.Message) = 0) then
          raise;
        // else fall through to FFI
      end;
    end;
  // header validation for non-pure path (keep EImageDecodeError closed)
  if Length(AData) < 12 then
    raise EImageDecodeError.Create('webp: truncated (no RIFF)');
  if (AData[0] <> Ord('R')) or (AData[1] <> Ord('I')) or (AData[2] <> Ord('F')) or (AData[3] <> Ord('F')) then
    raise EImageDecodeError.Create('webp: bad RIFF');
  if (AData[8] <> Ord('W')) or (AData[9] <> Ord('E')) or (AData[10] <> Ord('B')) or (AData[11] <> Ord('P')) then
    raise EImageDecodeError.Create('webp: bad WEBP');
  if not WebPLoaderIsAvailable then
    raise EImageDecodeError.Create('webp: decoder not available (libwebp not found via platform.dl, pure VP8L only)');
  raise ENotImplementedError.Create('webp: decode wiring pending (S2 FFI)');
  Result := nil;
end;

function WebPProbe(const AData: TBytes): Boolean; inline;
begin
  Result := WebPPureProbe(AData);
end;

initialization
  ImageRegisterCodec(ifWebP, @WebPProbe, @WebPDecodeRgba, True);

end.

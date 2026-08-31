{**
 * nextpas.core.image.webp - WebP 编解码（FFI via platform.dl，零硬链接）
 * S1：懒加载 libwebp.so.7/libwebp.so，探针 WebPGetInfo/WebPEncodeRGBA；
 *      未命中则抛 EImageDecodeError，Try* 上层收敛为 false。
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
  nextpas.core.mem.base,
  nextpas.core.image.base,
  nextpas.core.image.dispatch;

function WebPIsAvailable: Boolean;
begin
  Result := WebPLoaderIsAvailable;
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
  if Length(AData) < 12 then
    raise EImageDecodeError.Create('webp: truncated (no RIFF)');
  if (AData[0] <> Ord('R')) or (AData[1] <> Ord('I')) or (AData[2] <> Ord('F')) or (AData[3] <> Ord('F')) then
    raise EImageDecodeError.Create('webp: bad RIFF');
  if (AData[8] <> Ord('W')) or (AData[9] <> Ord('E')) or (AData[10] <> Ord('B')) or (AData[11] <> Ord('P')) then
    raise EImageDecodeError.Create('webp: bad WEBP');
  if not WebPLoaderIsAvailable then
    raise EImageDecodeError.Create('webp: decoder not available (libwebp not found via platform.dl)');
  raise ENotImplementedError.Create('webp: decode wiring pending (S2 FFI)');
  Result := nil;
end;

function WebPProbe(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 12) and (AData[0] = Ord('R')) and (AData[1] = Ord('I'))
    and (AData[2] = Ord('F')) and (AData[3] = Ord('F')) and (AData[8] = Ord('W'))
    and (AData[9] = Ord('E')) and (AData[10] = Ord('B')) and (AData[11] = Ord('P'));
end;

initialization
  ImageRegisterCodec(ifWebP, @WebPProbe, @WebPDecodeRgba, True);

end.

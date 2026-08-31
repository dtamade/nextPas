{**
 * nextpas.core.image.jpeg - JPEG 编解码（FFI via platform.dl，零硬链接）
 * S1：懒加载 libjpeg-turbo/libjpeg.so.8/libjpeg.so，通过 platform.dl 探针；
 *      未命中则抛 EImageDecodeError（Try* 语义收敛），不污染全局符号。
 * 真实解码接线在 S2+ 按需展开（jpeg_std_error/jpg_mem_src 等），此处先闭环形态与错误。
 *}
unit nextpas.core.image.jpeg;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function JpegEncodeRgba(const APixels: TBytes; AWidth, AHeight, AQuality: Integer): TBytes;
function JpegDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
function JpegIsAvailable: Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.image.jpeg.loader,
  nextpas.core.mem.base;

function JpegIsAvailable: Boolean;
begin
  Result := JpegLoaderIsAvailable;
end;

function JpegEncodeRgba(const APixels: TBytes; AWidth, AHeight, AQuality: Integer): TBytes;
var
  PixelLen, RowBytesU: SizeUInt;
begin
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('jpeg: width/height must be > 0');
  if (AWidth > 16384) or (AHeight > 16384) then
    raise EArgumentError.Create('jpeg: width/height exceeds 16384 cap');
  PixelLen := SizeUInt(AWidth) * SizeUInt(AHeight) * 4;
  if (AWidth <> 0) and (PixelLen div SizeUInt(AWidth) div 4 <> SizeUInt(AHeight)) then
    raise EArgumentError.Create('jpeg: width*height*4 overflow');
  if SizeUInt(Length(APixels)) <> PixelLen then
    raise EArgumentError.Create('jpeg: pixel buffer length mismatch (RGBA)');
  RowBytesU := SizeUInt(AWidth) * 4;
  RowBytesU := AlignUp(RowBytesU, 4);
  if RowBytesU = 0 then
    raise EArgumentError.Create('jpeg: RowBytes AlignUp overflow');
  if RowBytesU > High(SizeUInt) div SizeUInt(AHeight) then
    raise EArgumentError.Create('jpeg: RowBytes*Height overflow');
  if (AQuality < 1) or (AQuality > 100) then
    raise EArgumentError.Create('jpeg: quality must be 1..100');
  if not JpegLoaderIsAvailable then
    raise EImageDecodeError.Create('jpeg: encoder not available (libjpeg not found via platform.dl)');
  // S2 接线：此处占位，保持 API 稳定，真实编码经 FFI 展开
  raise ENotImplementedError.Create('jpeg: encode wiring pending (S2 FFI)');
  Result := nil;
end;

function JpegDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
begin
  AWidth := 0; AHeight := 0;
  if Length(AData) < 4 then
    raise EImageDecodeError.Create('jpeg: truncated (no SOI)');
  if (AData[0] <> $FF) or (AData[1] <> $D8) then
    raise EImageDecodeError.Create('jpeg: bad SOI');
  if not JpegLoaderIsAvailable then
    raise EImageDecodeError.Create('jpeg: decoder not available (libjpeg not found via platform.dl)');
  raise ENotImplementedError.Create('jpeg: decode wiring pending (S2 FFI)');
  Result := nil;
end;

end.

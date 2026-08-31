{**
 * nextpas.core.image - 图像编解码门面（纯 re-export，消费方 uses 此单元即可）
 * PNG/BMP 纯 Pascal + JPEG/WebP FFI via platform.dl；嗅探/调度转发至 image.dispatch。
 *}
unit nextpas.core.image;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.image.base,
  nextpas.core.image.intf,
  nextpas.core.image.png,
  nextpas.core.image.bmp,
  nextpas.core.image.jpeg,
  nextpas.core.image.webp,
  nextpas.core.image.dispatch;

type
  TImageFormat = nextpas.core.image.base.TImageFormat;
  TBitmapFormat = nextpas.core.image.base.TBitmapFormat;
  IImageDecoder = nextpas.core.image.intf.IImageDecoder;
  IImageEncoder = nextpas.core.image.intf.IImageEncoder;
  IImageCodec = nextpas.core.image.intf.IImageCodec;

  TImageInfo = nextpas.core.image.base.TImageInfo;

// — PNG 三式（RGBA/RGB/Gray，8-bit）—
function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes; inline;
function PngEncodeRgb(const APixels: TBytes; AWidth, AHeight: Integer): TBytes; inline;
function PngEncodeGray(const APixels: TBytes; AWidth, AHeight: Integer): TBytes; inline;
function PngDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes; inline;

// — BMP（纯 Pascal，BI_RGB 32-bit 编码，32/24/8 解码）—
function BmpEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes; inline;
function BmpDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes; inline;

// — JPEG/WebP（FFI，平台库缺失则 EImageDecodeError）—
function JpegEncodeRgba(const APixels: TBytes; AWidth, AHeight, AQuality: Integer): TBytes; inline;
function JpegDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes; inline;
function WebPEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer; AQuality: Single): TBytes; inline;
function WebPDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes; inline;
function JpegIsAvailable: Boolean; inline;
function WebPIsAvailable: Boolean; inline;

// — 统一嗅探 + 调度（转发至 dispatch，保持门面纯 re-export）—
function DetectImageFormat(const AData: TBytes): TImageFormat; inline;
function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBytes; inline;
function TryImageDecode(const AData: TBytes; out ABitmap: TBytes; out AInfo: TImageInfo): Boolean; inline;

implementation

function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.png.PngEncodeRgba(APixels, AWidth, AHeight); end;

function PngEncodeRgb(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.png.PngEncodeRgb(APixels, AWidth, AHeight); end;

function PngEncodeGray(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.png.PngEncodeGray(APixels, AWidth, AHeight); end;

function PngDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.png.PngDecodeRgba(AData, AWidth, AHeight); end;

function BmpEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.bmp.BmpEncodeRgba(APixels, AWidth, AHeight); end;

function BmpDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.bmp.BmpDecodeRgba(AData, AWidth, AHeight); end;

function JpegEncodeRgba(const APixels: TBytes; AWidth, AHeight, AQuality: Integer): TBytes;
begin Result := nextpas.core.image.jpeg.JpegEncodeRgba(APixels, AWidth, AHeight, AQuality); end;

function JpegDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.jpeg.JpegDecodeRgba(AData, AWidth, AHeight); end;

function WebPEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer; AQuality: Single): TBytes;
begin Result := nextpas.core.image.webp.WebPEncodeRgba(APixels, AWidth, AHeight, AQuality); end;

function WebPDecodeRgba(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
begin Result := nextpas.core.image.webp.WebPDecodeRgba(AData, AWidth, AHeight); end;

function JpegIsAvailable: Boolean;
begin Result := nextpas.core.image.jpeg.JpegIsAvailable; end;

function WebPIsAvailable: Boolean;
begin Result := nextpas.core.image.webp.WebPIsAvailable; end;

function DetectImageFormat(const AData: TBytes): TImageFormat;
begin Result := nextpas.core.image.dispatch.DetectImageFormat(AData); end;

function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBytes;
begin Result := nextpas.core.image.dispatch.ImageDecode(AData, AInfo); end;

function TryImageDecode(const AData: TBytes; out ABitmap: TBytes; out AInfo: TImageInfo): Boolean;
begin Result := nextpas.core.image.dispatch.TryImageDecode(AData, ABitmap, AInfo); end;

end.

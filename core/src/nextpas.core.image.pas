{**
 * nextpas.core.image - 图像门面：纯 re-export（base + png + dispatch 注册表）。
 * 守卫：纯 Pascal 后端恒为 nextpas.core.graphics.<fmt>.<fmt>888，禁 pure 后缀与 image.gif 回退；
 *   dispatch 6 格式 png/jpeg/webp/bmp/gif/qoi 注册不变，L2 仅 L0-L1，同层零循环。
 *   零逻辑门面，inline 零拷贝转发，复用 bytes.ops 单源。
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
  nextpas.core.graphics.gif.gif888,
  nextpas.core.graphics.jpeg.jpeg888,
  nextpas.core.graphics.webp.webp888,
  nextpas.core.graphics.qoi.qoi888,
  nextpas.core.image.dispatch;

type
  TBitmap = nextpas.core.image.base.TBitmap;
  TBitmapFormat = nextpas.core.image.base.TBitmapFormat;
  TImageFormat = nextpas.core.image.base.TImageFormat;
  TImageInfo = nextpas.core.image.base.TImageInfo;
  TImageProbeFunc = nextpas.core.image.dispatch.TImageProbeFunc;
  TImageDecodeFunc = nextpas.core.image.dispatch.TImageDecodeFunc;
  IImageDecoder = nextpas.core.image.intf.IImageDecoder;
  IImageEncoder = nextpas.core.image.intf.IImageEncoder;
  IImageCodec = nextpas.core.image.intf.IImageCodec;

function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes; inline;
procedure ImageRegisterCodec(AFormat: TImageFormat; AProbe: TImageProbeFunc; ADecode: TImageDecodeFunc; AHasAlpha: Boolean); inline;
function DetectImageFormat(const AData: TBytes): TImageFormat; inline;
function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBytes; inline;
function TryImageDecode(const AData: TBytes; out ABitmap: TBytes; out AInfo: TImageInfo): Boolean; inline;

implementation

function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes; inline;
begin
  Result := nextpas.core.image.png.PngEncodeRgba(APixels, AWidth, AHeight);
end;

procedure ImageRegisterCodec(AFormat: TImageFormat; AProbe: TImageProbeFunc; ADecode: TImageDecodeFunc; AHasAlpha: Boolean); inline;
begin
  nextpas.core.image.dispatch.ImageRegisterCodec(AFormat, AProbe, ADecode, AHasAlpha);
end;

function DetectImageFormat(const AData: TBytes): TImageFormat; inline;
begin
  Result := nextpas.core.image.dispatch.DetectImageFormat(AData);
end;

function ImageDecode(const AData: TBytes; out AInfo: TImageInfo): TBytes; inline;
begin
  Result := nextpas.core.image.dispatch.ImageDecode(AData, AInfo);
end;

function TryImageDecode(const AData: TBytes; out ABitmap: TBytes; out AInfo: TImageInfo): Boolean; inline;
begin
  Result := nextpas.core.image.dispatch.TryImageDecode(AData, ABitmap, AInfo);
end;

end.
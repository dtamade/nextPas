{**
 * nextpas.core.image - 图像编码门面：PNG。
 *}

unit nextpas.core.image;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.image.png;

function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes; inline;

{** k54（code888 反哺）：PNG 文件字节 → RGBA 位图（再导出，见 image.png 契约）。 *}
function PngDecodeRgba(const AData: TBytes;
  out AWidth, AHeight: Integer): TBytes; inline;

implementation

function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
begin
  Result := nextpas.core.image.png.PngEncodeRgba(APixels, AWidth, AHeight);
end;

function PngDecodeRgba(const AData: TBytes;
  out AWidth, AHeight: Integer): TBytes;
begin
  Result := nextpas.core.image.png.PngDecodeRgba(AData, AWidth, AHeight);
end;

end.
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

implementation

function PngEncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
begin
  Result := nextpas.core.image.png.PngEncodeRgba(APixels, AWidth, AHeight);
end;

end.
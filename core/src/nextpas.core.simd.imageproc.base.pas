unit nextpas.core.simd.imageproc.base;

{$mode ObjFPC}{$H+}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.image.base;

type
  // Reuse stable container – no parallel format
  TImageFormat = TBitmapFormat;
  TImage = TBitmap;

const
  ifGrayscale = bfGray8;
  ifRGBA32 = bfRGBA;
  ifRGB24 = bfBGRA;

type
  TImageBlendAlphaMode = (ibamStraight, ibamPremultiplied);
  TKernel3x3 = array[0..8] of Single;

function LegacyBytesPerPixel(const AFormat: TImageFormat): Integer; inline;
function ImageToBitmap(const AImage: TImage): TBitmap; inline;
function BitmapToImage(const ABitmap: TBitmap): TImage; inline;

implementation

function LegacyBytesPerPixel(const AFormat: TImageFormat): Integer;
begin
  case AFormat of
    bfGray8: Result := 1;
    bfRGBA: Result := 4;
    bfBGRA: Result := 3;
  else Result := 4;
  end;
end;

function ImageToBitmap(const AImage: TImage): TBitmap;
begin
  Result := AImage;
end;

function BitmapToImage(const ABitmap: TBitmap): TImage;
begin
  Result := ABitmap;
end;

end.

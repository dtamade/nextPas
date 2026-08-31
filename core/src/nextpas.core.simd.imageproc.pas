// Facade pure re-export – stable TBitmap reuse via base
unit nextpas.core.simd.imageproc;

{$mode ObjFPC}{$H+}
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.imageproc.base,
  nextpas.core.simd.imageproc.impl;

type
  TImageFormat = nextpas.core.simd.imageproc.base.TImageFormat;
  TImage = nextpas.core.simd.imageproc.base.TImage;
  TImageBlendAlphaMode = nextpas.core.simd.imageproc.base.TImageBlendAlphaMode;
  TKernel3x3 = nextpas.core.simd.imageproc.base.TKernel3x3;

const
  ifGrayscale = nextpas.core.simd.imageproc.base.ifGrayscale;
  ifRGBA32 = nextpas.core.simd.imageproc.base.ifRGBA32;
  ifRGB24 = nextpas.core.simd.imageproc.base.ifRGB24;

implementation

end.

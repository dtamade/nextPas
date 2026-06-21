unit nextpas.core.font;
{**
 * @desc 字体子系统 Facade 聚合器。
 *       统一导出 TTF 解析器、扫描线光栅化器、精简版塑形器。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.font.base,
  nextpas.core.font.ttface,
  nextpas.core.font.rasterizer,
  nextpas.core.font.shaper;

type
  {** 重新导出核心类型 }
  TTFontFace = nextpas.core.font.ttface.TTFontFace;
  TFontRasterizer = nextpas.core.font.rasterizer.TFontRasterizer;
  TFontLiteShaper = nextpas.core.font.shaper.TFontLiteShaper;

  {** 重新导出数据类型 }
  TFontGlyphOutline = nextpas.core.font.base.TFontGlyphOutline;
  TFontRasterResult = nextpas.core.font.base.TFontRasterResult;
  TFontMetrics = nextpas.core.font.base.TFontMetrics;
  TFontGlyphMetrics = nextpas.core.font.base.TFontGlyphMetrics;
  TFontShapedGlyph = nextpas.core.font.shaper.TFontShapedGlyph;
  TFontShapedGlyphArray = nextpas.core.font.shaper.TFontShapedGlyphArray;

implementation

end.

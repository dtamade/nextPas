{**
 * nextpas.core.graphics.effect.graph.base - 滤镜图值类型底座
 *}
unit nextpas.core.graphics.effect.graph.base;
{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}
interface
uses
  nextpas.core.base,
  nextpas.core.graphics.base;
type
  TEffectKind = (ekBlur, ekDropShadow, ekHue, ekLUT);
  TEffectNode = record
    Kind: TEffectKind;
    Radius: Single;
    Dx, Dy: Single;
    ShadowColor: TColor32;
    HueShift: Single;
    LutData: TBytes;
  end;
  TEffectNodeArray = array of TEffectNode;
const
  BOXBLUR_MAX_PIXELS = 16 * 1024 * 1024;
  BOXBLUR_ARENA_LIMIT = 32 * 1024 * 1024;
  BOXBLUR_TILE = 64;
  BOXBLUR_ALIGN = 64;
implementation
end.

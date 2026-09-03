{**
 * nextpas.core.effect - registry bridge to graphics.effect.* (L2)
 * Physical hosting: effect family lives under nextpas.core.graphics.effect.* ;
 * this top-level unit is a minimal re-export facade (≤30 lines, type aliases only)
 * bridging registry `effect` → `graphics.effect` to satisfy live check.
 * Keep tidy: no logic, only type aliases forwarded inline.
 *}
unit nextpas.core.effect;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.graphics.effect;

type
  TEffectKind = nextpas.core.graphics.effect.TEffectKind;
  TEffectNode = nextpas.core.graphics.effect.TEffectNode;
  TEffectGraph = nextpas.core.graphics.effect.TEffectGraph;

implementation

end.

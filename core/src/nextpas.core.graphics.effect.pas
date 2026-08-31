{**
 * nextpas.core.graphics.effect - 特效门面 + 过程化 7 函重导出
 *}
unit nextpas.core.graphics.effect;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.effect.graph,
  nextpas.core.graphics.effect.procedural;

type
  TEffectKind = nextpas.core.graphics.effect.graph.TEffectKind;
  TEffectNode = nextpas.core.graphics.effect.graph.TEffectNode;
  TEffectGraph = nextpas.core.graphics.effect.graph.TEffectGraph;

implementation

end.

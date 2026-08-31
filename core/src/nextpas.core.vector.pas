{**
 * nextpas.core.vector - 矢量门面（path 布尔/描边 + tess 梯形）
 * 纯 re-export，无逻辑。
 *}
unit nextpas.core.vector;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.vector.path,
  nextpas.core.vector.tess;

type
  TPath = nextpas.core.graphics.path.TPath;
  TPathBuilder = nextpas.core.graphics.path.TPathBuilder;
  TPoly = nextpas.core.vector.path.TPoly;
  TRect = nextpas.core.graphics.base.TRect;
  TStrokeOptions = nextpas.core.graphics.path.TStrokeOptions;
  TTrapezoid = nextpas.core.vector.tess.TTrapezoid;
  TTrapezoids = nextpas.core.vector.tess.TTrapezoids;

implementation

end.

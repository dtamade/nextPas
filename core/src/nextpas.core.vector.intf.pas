{**
 * nextpas.core.vector.intf - 矢量接口契约（ITessellator，面向接口编程时引此单元）
 * L2，依 base/graphics.path，覆盖 tess 与路径扁平化契约。
 *}
unit nextpas.core.vector.intf;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.vector.path,
  nextpas.core.vector.tess;

type
  IVectorTessellator = interface
    ['{A1B2C3D4-E5F6-47A8-9B0C-1D2E3F4A5B6D}']
    function Tessellate(const APath: TPath): TTrapezoids;
    function TessellatePoly(const APoly: TPoly): TTrapezoids;
  end;

  IVectorPathOps = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-222222000003}']
    function Flatten(const APath: TPath; ATol: Single): TPoly;
    function Bounds(const APoly: TPoly): TRect;
    function Union(const A, B: TPath): TPath;
    function Intersect(const A, B: TPath): TPath;
  end;

implementation

end.

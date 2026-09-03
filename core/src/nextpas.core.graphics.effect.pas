{**
 * nextpas.core.graphics.effect - 特效门面 + 过程化 7 函重导出
 * 归属：L2 effect 家族真正门面，四件套 base←graph/procedural←facade；本单元聚合 graph 与 procedural，
 * 顶层 nextpas.core.effect 仅作 registry 桥接，避免双重门面污染。
 * 性能：inline 转发零拷贝；序列化复用 bytes.ops 单源（bytes.binary），无重复实现。
 *}
unit nextpas.core.graphics.effect;

{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.image.base,
  nextpas.core.graphics.effect.graph,
  nextpas.core.graphics.effect.procedural;

type
  TEffectKind = nextpas.core.graphics.effect.graph.TEffectKind;
  TEffectNode = nextpas.core.graphics.effect.graph.TEffectNode;
  TEffectGraph = nextpas.core.graphics.effect.graph.TEffectGraph;

function ProcCheckerboard(Size, TileSize: Integer; C1, C2: TColor32): TBitmap; inline;
function ProcBrick(Size, BrickW, BrickH, Mortar: Integer; BrickC, MortarC: TColor32): TBitmap; inline;
function ProcNoise(Size: Integer; Base: TColor32; Variation: Integer): TBitmap; inline;
function ProcGradientV(Size: Integer; Top, Bottom: TColor32): TBitmap; inline;
function ProcMetal(Size: Integer; Base: TColor32; ScratchCount: Integer): TBitmap; inline;
function ProcGrid(Size, LineWidth: Integer; Bg, Line: TColor32): TBitmap; inline;
function ProcWood(Size: Integer; Base, Ring: TColor32): TBitmap; inline;

implementation

function ProcCheckerboard(Size, TileSize: Integer; C1, C2: TColor32): TBitmap;
begin Result := nextpas.core.graphics.effect.procedural.ProcCheckerboard(Size, TileSize, C1, C2); end;

function ProcBrick(Size, BrickW, BrickH, Mortar: Integer; BrickC, MortarC: TColor32): TBitmap;
begin Result := nextpas.core.graphics.effect.procedural.ProcBrick(Size, BrickW, BrickH, Mortar, BrickC, MortarC); end;

function ProcNoise(Size: Integer; Base: TColor32; Variation: Integer): TBitmap;
begin Result := nextpas.core.graphics.effect.procedural.ProcNoise(Size, Base, Variation); end;

function ProcGradientV(Size: Integer; Top, Bottom: TColor32): TBitmap;
begin Result := nextpas.core.graphics.effect.procedural.ProcGradientV(Size, Top, Bottom); end;

function ProcMetal(Size: Integer; Base: TColor32; ScratchCount: Integer): TBitmap;
begin Result := nextpas.core.graphics.effect.procedural.ProcMetal(Size, Base, ScratchCount); end;

function ProcGrid(Size, LineWidth: Integer; Bg, Line: TColor32): TBitmap;
begin Result := nextpas.core.graphics.effect.procedural.ProcGrid(Size, LineWidth, Bg, Line); end;

function ProcWood(Size: Integer; Base, Ring: TColor32): TBitmap;
begin Result := nextpas.core.graphics.effect.procedural.ProcWood(Size, Base, Ring); end;

end.

unit np_green_tree_core;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}

interface

uses
  nextpas.compiler.syntax.green_tree.base,
  nextpas.compiler.syntax.green_tree.core;

type
  TGreenNode = nextpas.compiler.syntax.green_tree.core.TGreenNode;
  TGreenStringVec = nextpas.compiler.syntax.green_tree.core.TGreenStringVec;
  TGreenForeignProcVec = nextpas.compiler.syntax.green_tree.core.TGreenForeignProcVec;
  TGreenTree = nextpas.compiler.syntax.green_tree.core.TGreenTree;

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string; inline;
function GreenNodeIsNil(const ANode: TGreenNode): Boolean; inline;
function NilGreenNode: TGreenNode; inline;

implementation

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.core.GreenNodeKindLabel(AKind);
end;

function GreenNodeIsNil(const ANode: TGreenNode): Boolean; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.core.GreenNodeIsNil(ANode);
end;

function NilGreenNode: TGreenNode; inline;
begin
  Result := nextpas.compiler.syntax.green_tree.core.NilGreenNode;
end;

end.

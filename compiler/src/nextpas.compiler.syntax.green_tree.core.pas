unit nextpas.compiler.syntax.green_tree.core;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}

interface

uses
  np_green_tree_base,
  np_green_tree_core;

type
  TGreenNode = np_green_tree_core.TGreenNode;
  TGreenStringVec = np_green_tree_core.TGreenStringVec;
  TGreenForeignProcVec = np_green_tree_core.TGreenForeignProcVec;
  TGreenTree = np_green_tree_core.TGreenTree;

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string; inline;
function GreenNodeIsNil(const ANode: TGreenNode): Boolean; inline;
function NilGreenNode: TGreenNode; inline;

implementation

function GreenNodeKindLabel(const AKind: TGreenNodeKind): string; inline;
begin
  Result := np_green_tree_core.GreenNodeKindLabel(AKind);
end;

function GreenNodeIsNil(const ANode: TGreenNode): Boolean; inline;
begin
  Result := np_green_tree_core.GreenNodeIsNil(ANode);
end;

function NilGreenNode: TGreenNode; inline;
begin
  Result := np_green_tree_core.NilGreenNode;
end;

end.

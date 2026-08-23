program m2_mini_tree;

uses
  nextpas.compiler.syntax.green_tree;

var
  T: TGreenTree;

begin
  { Pulls compiler syntax units into the unit graph — the multi-unit
    seeding context where TVec<TGreenNodeData>.Create's bare sibling
    call leaks the template name @TVec.SyncDataPtr in the full build. }
  T := TGreenTree.Create;
  if T.RootKind = 0 then
    T := nil;
end.

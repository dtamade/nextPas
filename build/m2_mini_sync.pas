program m2_mini_sync;

uses
  nextpas.core.collections.vec;

var
  V: specialize TVec<LongInt>;
  N: LongInt;

begin
  { Inline specialization (no alias name) — mirrors nextpas.compiler.syntax.green_tree.pas
    `specialize TVec<TGreenNodeData>.Create(0, AAllocator)`. The 4-arg
    Create overload body ends with a bare implicit-self `SyncDataPtr;`. }
  V := specialize TVec<LongInt>.Create(16, nil, nil, nil);
  N := 0;
  if V.Count > 0 then
    N := 1;
end.

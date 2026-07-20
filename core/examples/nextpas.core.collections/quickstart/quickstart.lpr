{**
 * collections quickstart — dual-uses template (facade + *.intf).
 * Covers MakeVec / MakeMap / MakeSet default path.
 *}
program quickstart;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.collections,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashset.intf;

procedure Fail(const AMessage: string);
begin
  WriteLn('collections-quickstart-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

var
  V: specialize IVec<Integer>;
  M: specialize IHashMap<string, Integer>;
  S: specialize IHashSet<Integer>;
  LValue: Integer;
begin
  WriteLn('collections-quickstart=ready');

  V := specialize MakeVec<Integer>;
  V.Push(1);
  V.Push(2);
  V.Push(3);
  Require(V.GetCount = 3, 'vec count');
  Require(V.Pop = 3, 'vec pop');
  WriteLn('vec-count=', V.GetCount);

  M := specialize MakeMap<string, Integer>;
  M.Put('a', 10);
  M.Put('b', 20);
  Require(M.TryGetValue('a', LValue) and (LValue = 10), 'map try get');
  Require(M.Get('b') = 20, 'map get');
  WriteLn('map-count=', M.GetCount);

  S := specialize MakeSet<Integer>;
  Require(S.Add(1), 'set add 1');
  Require(S.Add(2), 'set add 2');
  Require(not S.Add(1), 'set duplicate');
  Require(S.Contains(2), 'set contains');
  WriteLn('set-count=', S.GetCount);

  WriteLn('collections-quickstart-status=ok');
end.

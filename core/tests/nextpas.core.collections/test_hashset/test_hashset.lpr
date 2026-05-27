program test_hashset;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap.intf,
  nextpas.core.collections.hashmap;

type
  IIntSet = specialize IHashSet<Integer>;
  TIntSet = specialize THashSet<Integer>;
  IStrSet = specialize IHashSet<string>;
  TStrSet = specialize THashSet<string>;

var
  T: TTestRunner;

procedure TestAddContains;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  Check(LS.Add(1), 'add 1');
  Check(LS.Add(2), 'add 2');
  Check(LS.Add(3), 'add 3');
  Check(LS.Contains(1), 'contains 1');
  Check(LS.Contains(2), 'contains 2');
  Check(LS.Contains(3), 'contains 3');
  Check(not LS.Contains(99), 'not contains 99');
  CheckEqual(Int64(3), Int64(LS.Count), 'count');
end;

procedure TestAddDuplicate;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  Check(LS.Add(42), 'first add');
  Check(not LS.Add(42), 'duplicate add');
  CheckEqual(Int64(1), Int64(LS.Count), 'count stays 1');
end;

procedure TestRemove;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Add(10);
  LS.Add(20);
  LS.Add(30);
  Check(LS.Remove(20), 'remove existing');
  Check(not LS.Contains(20), 'removed gone');
  Check(not LS.Remove(99), 'remove missing');
  CheckEqual(Int64(2), Int64(LS.Count), 'count after remove');
end;

procedure TestClear;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Add(1);
  LS.Add(2);
  LS.Clear;
  Check(LS.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LS.Count), 'count 0');
end;

procedure TestStringSet;
var
  LS: IStrSet;
begin
  LS := TStrSet.Create;
  Check(LS.Add('hello'), 'add hello');
  Check(LS.Add('world'), 'add world');
  Check(not LS.Add('hello'), 'dup hello');
  Check(LS.Contains('hello'), 'contains hello');
  Check(not LS.Contains('missing'), 'not contains missing');
  CheckEqual(Int64(2), Int64(LS.Count), 'count');
end;

procedure TestGrow;
var
  LS: IIntSet;
  LI: Integer;
begin
  LS := TIntSet.Create;
  for LI := 0 to 99 do
    LS.Add(LI);
  CheckEqual(Int64(100), Int64(LS.Count), 'count 100');
  for LI := 0 to 99 do
    Check(LS.Contains(LI), 'contains ' + IntToStr(LI));
end;

procedure TestReserve;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Reserve(64);
  Check(LS.Capacity >= 64, 'capacity >= 64');
  Check(LS.IsEmpty, 'still empty');
end;

procedure TestAutoFree;
var
  LS: IIntSet;
begin
  LS := TIntSet.Create;
  LS.Add(1);
  LS := nil;
  Check(True);
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.hashset');
  T.Run('Add/Contains', @TestAddContains);
  T.Run('Add duplicate', @TestAddDuplicate);
  T.Run('Remove', @TestRemove);
  T.Run('Clear', @TestClear);
  T.Run('String set', @TestStringSet);
  T.Run('Grow (100 elements)', @TestGrow);
  T.Run('Reserve', @TestReserve);
  T.Run('Auto free (interface)', @TestAutoFree);
  T.Summary;
end.

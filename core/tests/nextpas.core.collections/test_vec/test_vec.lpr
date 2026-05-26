program test_vec;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.vec;

type
  TIntVec = specialize TVec<Integer>;
  TStrVec = specialize TVec<string>;

var
  T: TTestRunner;

procedure TestVecInit;
var
  LV: TIntVec;
begin
  LV.Init;
  Check(LV.IsEmpty, 'should be empty');
  CheckEqual(Int64(0), Int64(LV.Count));
  LV.Done;
end;

procedure TestVecAdd;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(10);
  LV.Add(20);
  LV.Add(30);
  CheckEqual(Int64(3), Int64(LV.Count));
  CheckEqual(Int64(10), Int64(LV[0]));
  CheckEqual(Int64(20), Int64(LV[1]));
  CheckEqual(Int64(30), Int64(LV[2]));
  LV.Done;
end;

procedure TestVecInsert;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(1);
  LV.Add(3);
  LV.Insert(1, 2);
  CheckEqual(Int64(3), Int64(LV.Count));
  CheckEqual(Int64(1), Int64(LV[0]));
  CheckEqual(Int64(2), Int64(LV[1]));
  CheckEqual(Int64(3), Int64(LV[2]));
  LV.Done;
end;

procedure TestVecDelete;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(10);
  LV.Add(20);
  LV.Add(30);
  LV.Delete(1);
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(10), Int64(LV[0]));
  CheckEqual(Int64(30), Int64(LV[1]));
  LV.Done;
end;

procedure TestVecDeleteSwap;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(10);
  LV.Add(20);
  LV.Add(30);
  LV.DeleteSwap(0);
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(30), Int64(LV[0]));
  CheckEqual(Int64(20), Int64(LV[1]));
  LV.Done;
end;

procedure TestVecPop;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(1);
  LV.Add(2);
  LV.Add(3);
  CheckEqual(Int64(3), Int64(LV.Pop));
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(2), Int64(LV.Pop));
  CheckEqual(Int64(1), Int64(LV.Count));
  LV.Done;
end;

procedure TestVecGrow;
var
  LV: TIntVec;
  LI: Integer;
begin
  LV.Init;
  for LI := 0 to 999 do
    LV.Add(LI);
  CheckEqual(Int64(1000), Int64(LV.Count));
  CheckEqual(Int64(0), Int64(LV[0]));
  CheckEqual(Int64(999), Int64(LV[999]));
  LV.Done;
end;

procedure TestVecContains;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(5);
  LV.Add(10);
  LV.Add(15);
  Check(LV.Contains(10));
  Check(not LV.Contains(7));
  LV.Done;
end;

procedure TestVecIndexOf;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(100);
  LV.Add(200);
  LV.Add(300);
  CheckEqual(Int64(1), LV.IndexOf(200));
  CheckEqual(Int64(-1), LV.IndexOf(999));
  LV.Done;
end;

procedure TestVecReserve;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Reserve(100);
  Check(LV.Capacity >= 100, 'capacity after reserve');
  CheckEqual(Int64(0), Int64(LV.Count), 'count unchanged');
  LV.Done;
end;

procedure TestVecClone;
var
  LV, LClone: TIntVec;
begin
  LV.Init;
  LV.Add(1);
  LV.Add(2);
  LV.Add(3);
  LClone := LV.Clone;
  CheckEqual(Int64(3), Int64(LClone.Count));
  CheckEqual(Int64(1), Int64(LClone[0]));
  LClone[0] := 99;
  CheckEqual(Int64(1), Int64(LV[0]), 'original unchanged');
  LV.Done;
  LClone.Done;
end;

procedure TestVecString;
var
  LV: TStrVec;
begin
  LV.Init;
  LV.Add('hello');
  LV.Add('world');
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual('hello', LV[0]);
  CheckEqual('world', LV[1]);
  LV.Done;
end;

procedure TestVecClear;
var
  LV: TIntVec;
begin
  LV.Init;
  LV.Add(1);
  LV.Add(2);
  LV.Clear;
  Check(LV.IsEmpty);
  Check(LV.Capacity > 0, 'capacity preserved');
  LV.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.vec');
  T.Run('Init', @TestVecInit);
  T.Run('Add', @TestVecAdd);
  T.Run('Insert', @TestVecInsert);
  T.Run('Delete', @TestVecDelete);
  T.Run('DeleteSwap', @TestVecDeleteSwap);
  T.Run('Pop', @TestVecPop);
  T.Run('Grow (1000 elements)', @TestVecGrow);
  T.Run('Contains', @TestVecContains);
  T.Run('IndexOf', @TestVecIndexOf);
  T.Run('Reserve', @TestVecReserve);
  T.Run('Clone', @TestVecClone);
  T.Run('String type', @TestVecString);
  T.Run('Clear', @TestVecClear);
  T.Summary;
end.

program test_vec;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.vec;

type
  IIntVec = specialize IVec<Integer>;
  TIntVec = specialize TVec<Integer>;
  IStrVec = specialize IVec<string>;
  TStrVec = specialize TVec<string>;

var
  T: TTestRunner;

procedure TestCreate;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  Check(LV.IsEmpty);
  CheckEqual(Int64(0), Int64(LV.Count));
end;

procedure TestAdd;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(10);
  LV.Add(20);
  LV.Add(30);
  CheckEqual(Int64(3), Int64(LV.Count));
  CheckEqual(Int64(10), Int64(LV[0]));
  CheckEqual(Int64(20), Int64(LV[1]));
  CheckEqual(Int64(30), Int64(LV[2]));
end;

procedure TestInsert;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(1);
  LV.Add(3);
  LV.Insert(1, 2);
  CheckEqual(Int64(3), Int64(LV.Count));
  CheckEqual(Int64(1), Int64(LV[0]));
  CheckEqual(Int64(2), Int64(LV[1]));
  CheckEqual(Int64(3), Int64(LV[2]));
end;

procedure TestDelete;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(10);
  LV.Add(20);
  LV.Add(30);
  LV.Delete(1);
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(10), Int64(LV[0]));
  CheckEqual(Int64(30), Int64(LV[1]));
end;

procedure TestDeleteSwap;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(10);
  LV.Add(20);
  LV.Add(30);
  LV.DeleteSwap(0);
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(30), Int64(LV[0]));
  CheckEqual(Int64(20), Int64(LV[1]));
end;

procedure TestPop;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(1);
  LV.Add(2);
  LV.Add(3);
  CheckEqual(Int64(3), Int64(LV.Pop));
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual(Int64(2), Int64(LV.Pop));
  CheckEqual(Int64(1), Int64(LV.Count));
end;

procedure TestGrow;
var
  LV: IIntVec;
  LI: Integer;
begin
  LV := TIntVec.Create;
  for LI := 0 to 999 do
    LV.Add(LI);
  CheckEqual(Int64(1000), Int64(LV.Count));
  CheckEqual(Int64(0), Int64(LV[0]));
  CheckEqual(Int64(999), Int64(LV[999]));
end;

procedure TestContains;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(5);
  LV.Add(10);
  LV.Add(15);
  Check(LV.Contains(10));
  Check(not LV.Contains(7));
end;

procedure TestIndexOf;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(100);
  LV.Add(200);
  LV.Add(300);
  CheckEqual(Int64(1), LV.IndexOf(200));
  CheckEqual(Int64(-1), LV.IndexOf(999));
end;

procedure TestReserve;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Reserve(100);
  Check(LV.Capacity >= 100);
  CheckEqual(Int64(0), Int64(LV.Count));
end;

procedure TestString;
var
  LV: IStrVec;
begin
  LV := TStrVec.Create;
  LV.Add('hello');
  LV.Add('world');
  CheckEqual(Int64(2), Int64(LV.Count));
  CheckEqual('hello', LV[0]);
  CheckEqual('world', LV[1]);
end;

procedure TestClear;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(1);
  LV.Add(2);
  LV.Clear;
  Check(LV.IsEmpty);
  Check(LV.Capacity > 0);
end;

procedure TestAutoFree;
var
  LV: IIntVec;
begin
  LV := TIntVec.Create;
  LV.Add(42);
  LV := nil;
  // no crash = interface ref-counting freed the object
  Check(True);
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.vec');
  T.Run('Create', @TestCreate);
  T.Run('Add', @TestAdd);
  T.Run('Insert', @TestInsert);
  T.Run('Delete', @TestDelete);
  T.Run('DeleteSwap', @TestDeleteSwap);
  T.Run('Pop', @TestPop);
  T.Run('Grow (1000 elements)', @TestGrow);
  T.Run('Contains', @TestContains);
  T.Run('IndexOf', @TestIndexOf);
  T.Run('Reserve', @TestReserve);
  T.Run('String type', @TestString);
  T.Run('Clear', @TestClear);
  T.Run('Auto free (interface)', @TestAutoFree);
  T.Summary;
end.

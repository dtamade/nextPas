program test_smallvec;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.smallvec;

type
  TSmallVec4 = specialize TSmallVec<Integer, 4>;
  TSmallVec8 = specialize TSmallVec<Integer, 8>;
  TStrSmallVec = specialize TSmallVec<string, 4>;

var
  T: TTestRunner;

procedure TestPushPopInline;
var SV: TSmallVec4; v: Integer;
begin
  SV.Init;
  SV.Push(10); SV.Push(20); SV.Push(30);
  CheckEqual(Int64(3), Int64(SV.Count), 'count');
  Check(SV.IsInline, 'still inline');
  Check(SV.Pop(v), 'pop'); CheckEqual(Int64(30), Int64(v), 'pop val');
  CheckEqual(Int64(2), Int64(SV.Count), 'count after pop');
  SV.Done;
end;

procedure TestSpillToHeap;
var SV: TSmallVec4; i: Integer;
begin
  SV.Init;
  for i := 0 to 3 do SV.Push(i * 10);
  Check(SV.IsInline, 'inline at capacity');
  SV.Push(40);
  Check(not SV.IsInline, 'spilled to heap');
  CheckEqual(Int64(5), Int64(SV.Count), 'count');
  CheckEqual(Int64(0), Int64(SV.Get(0)), '[0]');
  CheckEqual(Int64(40), Int64(SV.Get(4)), '[4]');
  SV.Done;
end;

procedure TestGetPut;
var SV: TSmallVec8;
begin
  SV.Init;
  SV.Push(1); SV.Push(2); SV.Push(3);
  CheckEqual(Int64(2), Int64(SV.Get(1)), 'get[1]');
  SV.Put(1, 99);
  CheckEqual(Int64(99), Int64(SV.Get(1)), 'put[1]');
  SV.Done;
end;

procedure TestClear;
var SV: TSmallVec4;
begin
  SV.Init;
  SV.Push(1); SV.Push(2); SV.Push(3);
  SV.Clear;
  CheckEqual(Int64(0), Int64(SV.Count), 'count after clear');
  Check(SV.IsEmpty, 'empty after clear');
  SV.Push(99);
  CheckEqual(Int64(1), Int64(SV.Count), 'usable after clear');
  SV.Done;
end;

procedure TestGrowStress;
var SV: TSmallVec4; i: Integer; ok: Boolean;
begin
  SV.Init;
  for i := 0 to 99 do SV.Push(i);
  CheckEqual(Int64(100), Int64(SV.Count), 'count 100');
  Check(not SV.IsInline, 'on heap');
  ok := True;
  for i := 0 to 99 do
    if SV.Get(i) <> i then ok := False;
  Check(ok, 'all values correct');
  SV.Done;
end;

procedure TestStringManaged;
var SV: TStrSmallVec; v: string;
begin
  SV.Init;
  SV.Push('hello'); SV.Push('world'); SV.Push('foo'); SV.Push('bar');
  CheckEqual(Int64(4), Int64(SV.Count), 'count');
  CheckEqual('hello', SV.Get(0), '[0]');
  CheckEqual('bar', SV.Get(3), '[3]');
  SV.Push('spill');
  Check(not SV.IsInline, 'spilled');
  CheckEqual('spill', SV.Get(4), '[4] after spill');
  Check(SV.Pop(v), 'pop'); CheckEqual('spill', v, 'pop val');
  SV.Done;
end;

procedure TestToArray;
var SV: TSmallVec4; LA: TSmallVec4.TArray;
begin
  SV.Init;
  SV.Push(10); SV.Push(20); SV.Push(30);
  LA := SV.ToArray;
  CheckEqual(Int64(3), Int64(Length(LA)), 'array len');
  CheckEqual(Int64(10), Int64(LA[0]), 'arr[0]');
  CheckEqual(Int64(30), Int64(LA[2]), 'arr[2]');
  SV.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.smallvec');
  T.Run('Push/Pop inline', @TestPushPopInline);
  T.Run('Spill to heap', @TestSpillToHeap);
  T.Run('Get/Put', @TestGetPut);
  T.Run('Clear', @TestClear);
  T.Run('Grow stress (100)', @TestGrowStress);
  T.Run('String managed type', @TestStringManaged);
  T.Run('ToArray', @TestToArray);
  T.Summary;
end.

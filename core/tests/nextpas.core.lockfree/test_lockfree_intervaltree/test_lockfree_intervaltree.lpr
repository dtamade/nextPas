{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_intervaltree;

uses
  nextpas.core.text.conv,
  nextpas.core.lockfree.intervaltree;

var
  GTree: TIntervalTree;
  GPassed, GFailed: Int32;

procedure Check(ACondition: Boolean; const AName: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  FAIL: ', AName);
  end;
end;

procedure Test_InsertFind;
var
  LResults: TIntervalArray;
begin
  WriteLn('--- Insert/Find ---');
  GTree := TIntervalTree.Create;
  try
    Check(GTree.IsEmpty, 'IsEmpty initially');

    GTree.Insert(1, 5, 'meeting-a');
    GTree.Insert(3, 8, 'meeting-b');
    GTree.Insert(10, 15, 'meeting-c');
    GTree.Insert(2, 4, 'meeting-d');

    Check(GTree.Count = 4, 'Count = 4');

    { Find intervals overlapping point 3 }
    LResults := GTree.FindOverlapping(3);
    Check(Length(LResults) = 3, 'FindOverlapping(3) returns 3');

    { Find intervals overlapping point 6 }
    LResults := GTree.FindOverlapping(6);
    Check(Length(LResults) = 1, 'FindOverlapping(6) returns 1');

    { Find intervals overlapping point 12 }
    LResults := GTree.FindOverlapping(12);
    Check(Length(LResults) = 1, 'FindOverlapping(12) returns 1');

    { Find intervals overlapping point 20 }
    LResults := GTree.FindOverlapping(20);
    Check(Length(LResults) = 0, 'FindOverlapping(20) returns 0');
  finally
    GTree.Free;
  end;
end;

procedure Test_RangeQuery;
var
  LResults: TIntervalArray;
begin
  WriteLn('--- Range Query ---');
  GTree := TIntervalTree.Create;
  try
    GTree.Insert(1, 5, 'a');
    GTree.Insert(10, 15, 'b');
    GTree.Insert(20, 25, 'c');
    GTree.Insert(30, 35, 'd');

    { Range [3, 12] overlaps with [1,5] and [10,15] }
    LResults := GTree.FindRange(3, 12);
    Check(Length(LResults) = 2, 'FindRange(3, 12) returns 2');

    { Range [6, 9] overlaps nothing }
    LResults := GTree.FindRange(6, 9);
    Check(Length(LResults) = 0, 'FindRange(6, 9) returns 0');

    { Range [0, 100] overlaps all }
    LResults := GTree.FindRange(0, 100);
    Check(Length(LResults) = 4, 'FindRange(0, 100) returns 4');
  finally
    GTree.Free;
  end;
end;

procedure Test_Remove;
var
  LResults: TIntervalArray;
begin
  WriteLn('--- Remove ---');
  GTree := TIntervalTree.Create;
  try
    GTree.Insert(1, 5, 'a');
    GTree.Insert(10, 15, 'b');
    GTree.Insert(20, 25, 'c');

    Check(GTree.Remove(1, 5) = itrOk, 'Remove(1, 5) = ok');
    Check(GTree.Count = 2, 'Count = 2');

    LResults := GTree.FindOverlapping(3);
    Check(Length(LResults) = 0, 'FindOverlapping(3) returns 0 after remove');

    Check(GTree.Remove(1, 5) = itrNotFound, 'Remove(1, 5) again = not found');
    Check(GTree.Remove(99, 100) = itrNotFound, 'Remove(99, 100) = not found');
  finally
    GTree.Free;
  end;
end;

procedure Test_Contains;
begin
  WriteLn('--- Contains ---');
  GTree := TIntervalTree.Create;
  try
    GTree.Insert(1, 5, 'a');
    GTree.Insert(10, 15, 'b');

    Check(GTree.Contains(1, 5), 'Contains(1, 5) = true');
    Check(GTree.Contains(10, 15), 'Contains(10, 15) = true');
    Check(not GTree.Contains(20, 25), 'Contains(20, 25) = false');

    GTree.Remove(1, 5);
    Check(not GTree.Contains(1, 5), 'Contains(1, 5) after remove = false');
  finally
    GTree.Free;
  end;
end;

procedure Test_InvalidInterval;
begin
  WriteLn('--- Invalid Interval ---');
  GTree := TIntervalTree.Create;
  try
    Check(GTree.Insert(5, 3) = itrInvalidInterval, 'Insert(5, 3) = invalid');
    Check(GTree.Count = 0, 'Count = 0');
  finally
    GTree.Free;
  end;
end;

procedure Test_PointIntervals;
var
  LResults: TIntervalArray;
begin
  WriteLn('--- Point Intervals ---');
  GTree := TIntervalTree.Create;
  try
    GTree.Insert(5, 5, 'point-a');
    GTree.Insert(5, 5, 'point-b');
    GTree.Insert(10, 10, 'point-c');

    LResults := GTree.FindOverlapping(5);
    Check(Length(LResults) = 2, 'FindOverlapping(5) returns 2 point intervals');

    LResults := GTree.FindOverlapping(10);
    Check(Length(LResults) = 1, 'FindOverlapping(10) returns 1');
  finally
    GTree.Free;
  end;
end;

procedure Test_LargeScale;
var
  LResults: TIntervalArray;
  I: Int32;
begin
  WriteLn('--- Large Scale ---');
  GTree := TIntervalTree.Create;
  try
    for I := 0 to 999 do
      GTree.Insert(I * 10, I * 10 + 5, 'interval-' + IntToStr(I));

    Check(GTree.Count = 1000, 'Count = 1000');

    LResults := GTree.FindOverlapping(500);
    Check(Length(LResults) = 1, 'FindOverlapping(500) returns 1');

    { Range query spanning multiple intervals }
    LResults := GTree.FindRange(100, 200);
    Check(Length(LResults) >= 10, 'FindRange(100, 200) returns >= 10');
  finally
    GTree.Free;
  end;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('=== Interval Tree Tests ===');
  Test_InsertFind;
  Test_RangeQuery;
  Test_Remove;
  Test_Contains;
  Test_InvalidInterval;
  Test_PointIntervals;
  Test_LargeScale;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.

program test_lockfree_rope;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.rope;

var
  GRope: TRope;
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

procedure TestCreate;
begin
  WriteLn('--- TestCreate ---');
  GRope := TRope.Create;
  try
    Check(GRope.GetLength = 0, 'Empty length');
    Check(GRope.ToString = '', 'Empty string');
  finally
    GRope.Free;
  end;
end;

procedure TestInsert;
begin
  WriteLn('--- TestInsert ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'hello');
    Check(GRope.GetLength = 5, 'Length after insert hello');
    Check(GRope.ToString = 'hello', 'Content hello');
    GRope.Insert(5, ' world');
    Check(GRope.GetLength = 11, 'Length after insert world');
    Check(GRope.ToString = 'hello world', 'Content hello world');
    GRope.Insert(5, ' beautiful');
    Check(GRope.ToString = 'hello beautiful world', 'Content with beautiful');
  finally
    GRope.Free;
  end;
end;

procedure TestDelete;
begin
  WriteLn('--- TestDelete ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'hello world');
    GRope.Delete(5, 6);
    Check(GRope.ToString = 'hello', 'Delete world');
    GRope.Delete(0, 5);
    Check(GRope.ToString = '', 'Delete all');
    Check(GRope.GetLength = 0, 'Length 0');
  finally
    GRope.Free;
  end;
end;

procedure TestSubstring;
var
  LResult: AnsiString;
begin
  WriteLn('--- TestSubstring ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'hello world');
    GRope.Substring(0, 5, LResult);
    Check(LResult = 'hello', 'Substring hello');
    GRope.Substring(6, 5, LResult);
    Check(LResult = 'world', 'Substring world');
    GRope.Substring(0, 11, LResult);
    Check(LResult = 'hello world', 'Substring full');
  finally
    GRope.Free;
  end;
end;

procedure TestOverflowCountsAndFailureOutputs;
var
  LResult: AnsiString;
begin
  WriteLn('--- TestOverflowCountsAndFailureOutputs ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'abcdef');
    Check(GRope.Delete(1, High(Int32)) = rpOk,
      'Large delete count clamps to the remaining text');
    Check(GRope.ToString = 'a', 'Large delete preserves the prefix');
    Check(GRope.GetLength = 1, 'Large delete keeps a valid length');

    LResult := 'stale';
    Check(GRope.Substring(-1, 1, LResult) = rpOutOfBounds,
      'Invalid substring reports out of bounds');
    Check(LResult = '', 'Invalid substring clears its output');
  finally
    GRope.Free;
  end;
end;

procedure TestCharAt;
var
  LChar: AnsiChar;
begin
  WriteLn('--- TestCharAt ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'abc');
    GRope.CharAt(0, LChar);
    Check(LChar = 'a', 'CharAt 0 = a');
    GRope.CharAt(1, LChar);
    Check(LChar = 'b', 'CharAt 1 = b');
    GRope.CharAt(2, LChar);
    Check(LChar = 'c', 'CharAt 2 = c');
    Check(GRope.CharAt(3, LChar) = rpOutOfBounds, 'OutOfBounds');
  finally
    GRope.Free;
  end;
end;

procedure TestMultipleInserts;
begin
  WriteLn('--- TestMultipleInserts ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'aaa');
    GRope.Insert(3, 'bbb');
    GRope.Insert(6, 'ccc');
    Check(GRope.ToString = 'aaabbbccc', 'Multiple inserts');
    Check(GRope.GetLength = 9, 'Length 9');
  finally
    GRope.Free;
  end;
end;

procedure TestNestedMiddleInsertAndCharAt;
var
  LChar: AnsiChar;
begin
  WriteLn('--- TestNestedMiddleInsertAndCharAt ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'abc');
    GRope.Insert(3, 'def');
    GRope.Insert(6, 'ghi');
    GRope.Insert(4, 'X');
    Check(GRope.ToString = 'abcdXefghi', 'Middle insert into nested rope');
    Check(GRope.CharAt(4, LChar) = rpOk, 'CharAt on inserted position succeeds');
    Check(LChar = 'X', 'Inserted character is reachable');
    Check(GRope.CharAt(8, LChar) = rpOk, 'CharAt near tail succeeds');
    Check(LChar = 'h', 'Tail traversal uses full left weight');
    Check(GRope.CharAt(9, LChar) = rpOk, 'CharAt last position succeeds');
    Check(LChar = 'i', 'Last character remains reachable');
  finally
    GRope.Free;
  end;
end;

procedure TestClear;
begin
  WriteLn('--- TestClear ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'hello');
    GRope.Clear;
    Check(GRope.GetLength = 0, 'Cleared length');
    Check(GRope.ToString = '', 'Cleared string');
  finally
    GRope.Free;
  end;
end;

procedure TestClose;
begin
  WriteLn('--- TestClose ---');
  GRope := TRope.Create;
  try
    GRope.Insert(0, 'hello');
    GRope.Close;
    Check(GRope.IsClosed, 'Is closed');
    Check(GRope.Insert(0, 'x') = rpClosed, 'Insert after close fails');
    Check(GRope.Delete(0, 1) = rpClosed, 'Delete after close fails');
  finally
    GRope.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_rope ===');
  GPassed := 0;
  GFailed := 0;
  TestCreate;
  TestInsert;
  TestDelete;
  TestSubstring;
  TestOverflowCountsAndFailureOutputs;
  TestCharAt;
  TestMultipleInserts;
  TestNestedMiddleInsertAndCharAt;
  TestClear;
  TestClose;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.

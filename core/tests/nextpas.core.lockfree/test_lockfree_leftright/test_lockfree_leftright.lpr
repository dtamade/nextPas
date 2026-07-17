program test_lockfree_leftright;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.leftright,
  nextpas.core.test;

var
  GData: array[0..1] of Int64;

procedure WriteCallback(AIndex: Int32; AData: Pointer);
begin
  GData[AIndex] := PInt64(AData)^;
end;

procedure CopyCallback(ASrc, ADst: Int32; AData: Pointer);
begin
  GData[ADst] := GData[ASrc];
end;

procedure TestBasicReadWrite;
var
  LR: TLeftRight;
  LIdx: Int32;
  LValue: Int64;
begin
  LR := TLeftRight.Create;
  try
    GData[0] := 0;
    GData[1] := 0;

    { Write initial value }
    LValue := 42;
    LR.Write(@WriteCallback, @CopyCallback, @LValue);
    CheckEqual(Int64(42), GData[LR.GetReadIndex], 'Read index data');

    { Read }
    LIdx := LR.EnterRead;
    Check(GData[LIdx] = 42, 'Reader should see 42');
    LR.ExitRead(LIdx);
  finally
    LR.Free;
  end;
end;

procedure TestMultipleWrites;
var
  LR: TLeftRight;
  LIdx: Int32;
  LValue: Int64;
begin
  LR := TLeftRight.Create;
  try
    GData[0] := 0;
    GData[1] := 0;

    LValue := 10;
    LR.Write(@WriteCallback, @CopyCallback, @LValue);

    LValue := 20;
    LR.Write(@WriteCallback, @CopyCallback, @LValue);

    LIdx := LR.EnterRead;
    Check(GData[LIdx] = 20, 'Reader should see latest value');
    LR.ExitRead(LIdx);
  finally
    LR.Free;
  end;
end;

procedure TestClose;
var
  LR: TLeftRight;
begin
  LR := TLeftRight.Create;
  try
    LR.Close;
    Check(LR.IsClosed, 'Should be closed');
  finally
    LR.Free;
  end;
end;

procedure TestReaderCountAndReturnedIndex;
var
  LR: TLeftRight;
  LIdx: Int32;
begin
  LR := TLeftRight.Create;
  try
    CheckEqual(Int32(0), LR.GetReaderCount, 'Initial reader count');
    LIdx := LR.EnterRead;
    Check((LIdx = 0) or (LIdx = 1), 'EnterRead should return active data index');
    CheckEqual(Int32(1), LR.GetReaderCount, 'Reader count increments');
    LR.ExitRead(LIdx);
    CheckEqual(Int32(0), LR.GetReaderCount, 'Reader count decrements');
  finally
    LR.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_leftright ===');
  WriteLn;

  TestBasicReadWrite;
  WriteLn('  + Basic read/write');

  TestMultipleWrites;
  WriteLn('  + Multiple writes');

  TestClose;
  WriteLn('  + Close semantics');

  TestReaderCountAndReturnedIndex;
  WriteLn('  + Reader count/index semantics');

  WriteLn;
  WriteLn('All left-right tests passed!');
end.

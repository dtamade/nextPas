program test_lockfree_elimination_stack;

{$mode objfpc}{$H+}

uses
  nextpas.core.lockfree.elimination_stack,
  nextpas.core.test;

type
  TIntElimStack = specialize TEliminationStack<Int64>;

procedure TestBasicPushPop;
var
  LStack: TIntElimStack;
  LValue: Int64;
begin
  LStack := TIntElimStack.Create(64);
  try
    Check(LStack.IsEmpty, 'Stack should be empty');
    Check(not LStack.IsClosed, 'Stack should not be closed');
    CheckEqual(Int32(16), LStack.ElimArraySize, 'Default elim array size should be 16');

    Check(LStack.TryPush(42) = esPushed, 'Should push');
    Check(not LStack.IsEmpty, 'Stack should not be empty');

    Check(LStack.TryPop(LValue) = esPopped, 'Should pop');
    CheckEqual(Int64(42), LValue, 'Popped value should match');
    Check(LStack.IsEmpty, 'Stack should be empty after pop');
  finally
    LStack.Free;
  end;
end;

procedure TestMultiplePushPop;
var
  LStack: TIntElimStack;
  LValue: Int64;
  I: Integer;
begin
  LStack := TIntElimStack.Create(64);
  try
    for I := 1 to 10 do
      Check(LStack.TryPush(Int64(I * 10)) = esPushed, 'Should push');

    CheckEqual(PtrUInt(10), LStack.ApproxCount, 'Count should be 10');

    for I := 10 downto 1 do
    begin
      Check(LStack.TryPop(LValue) = esPopped, 'Should pop');
      CheckEqual(Int64(I * 10), LValue, 'LIFO order');
    end;
    Check(LStack.IsEmpty, 'Stack should be empty');
  finally
    LStack.Free;
  end;
end;

procedure TestClose;
var
  LStack: TIntElimStack;
  LValue: Int64;
begin
  LStack := TIntElimStack.Create(64);
  try
    LStack.TryPush(1);
    LStack.Close;
    Check(LStack.IsClosed, 'Should be closed');

    Check(LStack.TryPop(LValue) = esClosed, 'Should not pop from closed');
    Check(LStack.TryPush(2) = esClosed, 'Should not push to closed');
  finally
    LStack.Free;
  end;
end;

procedure TestEmptyPop;
var
  LStack: TIntElimStack;
  LValue: Int64;
begin
  LStack := TIntElimStack.Create(64);
  try
    Check(LStack.TryPop(LValue) = esEmpty, 'Should not pop from empty stack');
  finally
    LStack.Free;
  end;
end;

procedure TestCustomElimSize;
var
  LStack: TIntElimStack;
begin
  LStack := TIntElimStack.Create(64, 8);
  try
    CheckEqual(Int32(8), LStack.ElimArraySize, 'Custom elim array size');
  finally
    LStack.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_elimination_stack ===');
  WriteLn;

  TestBasicPushPop;
  WriteLn('  + Basic push/pop');

  TestMultiplePushPop;
  WriteLn('  + Multiple push/pop (LIFO order)');

  TestClose;
  WriteLn('  + Close semantics');

  TestEmptyPop;
  WriteLn('  + Empty pop');

  TestCustomElimSize;
  WriteLn('  + Custom elimination array size');

  WriteLn;
  WriteLn('All elimination stack tests passed!');
end.

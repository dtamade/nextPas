{$mode ObjFPC}{$H+}{$J-}
program test_lockfree_deque_lf;

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.lockfree.deque_lf;

var
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

procedure Test_Empty;
var
  LDeque: TLockFreeDeque;
  LVal: AnsiString;
begin
  WriteLn('--- Empty ---');
  LDeque := TLockFreeDeque.Create;
  try
    Check(LDeque.Count = 0, 'empty count = 0');
    Check(LDeque.IsEmpty, 'empty IsEmpty');
    Check(LDeque.PopLeft(LVal) = dqEmpty, 'PopLeft empty');
    Check(LDeque.PopRight(LVal) = dqEmpty, 'PopRight empty');
    Check(LDeque.PeekLeft(LVal) = dqEmpty, 'PeekLeft empty');
    Check(LDeque.PeekRight(LVal) = dqEmpty, 'PeekRight empty');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

procedure Test_PushPopLeft;
var
  LDeque: TLockFreeDeque;
  LVal: AnsiString;
begin
  WriteLn('--- Push/Pop Left ---');
  LDeque := TLockFreeDeque.Create;
  try
    Check(LDeque.PushLeft('a') = dqOk, 'PushLeft(a)');
    Check(LDeque.PushLeft('b') = dqOk, 'PushLeft(b)');
    Check(LDeque.Count = 2, 'count = 2');
    { LIFO from left: b, a }
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'b', 'PopLeft = b');
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'a', 'PopLeft = a');
    Check(LDeque.IsEmpty, 'empty after pops');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

procedure Test_PushPopRight;
var
  LDeque: TLockFreeDeque;
  LVal: AnsiString;
begin
  WriteLn('--- Push/Pop Right ---');
  LDeque := TLockFreeDeque.Create;
  try
    LDeque.PushRight('a');
    LDeque.PushRight('b');
    Check(LDeque.Count = 2, 'count = 2');
    { LIFO from right: b, a }
    Check(LDeque.PopRight(LVal) = dqOk, 'PopRight ok');
    Check(LVal = 'b', 'PopRight = b');
    Check(LDeque.PopRight(LVal) = dqOk, 'PopRight ok');
    Check(LVal = 'a', 'PopRight = a');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

procedure Test_FIFO;
var
  LDeque: TLockFreeDeque;
  LVal: AnsiString;
begin
  WriteLn('--- FIFO (push right, pop left) ---');
  LDeque := TLockFreeDeque.Create;
  try
    LDeque.PushRight('first');
    LDeque.PushRight('second');
    LDeque.PushRight('third');
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'first', 'first');
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'second', 'second');
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'third', 'third');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

procedure Test_Peek;
var
  LDeque: TLockFreeDeque;
  LVal: AnsiString;
begin
  WriteLn('--- Peek ---');
  LDeque := TLockFreeDeque.Create;
  try
    LDeque.PushRight('left');
    LDeque.PushRight('right');
    Check(LDeque.PeekLeft(LVal) = dqOk, 'PeekLeft ok');
    Check(LVal = 'left', 'PeekLeft = left');
    Check(LDeque.PeekRight(LVal) = dqOk, 'PeekRight ok');
    Check(LVal = 'right', 'PeekRight = right');
    Check(LDeque.Count = 2, 'peek does not remove');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

procedure Test_Grow;
var
  LDeque: TLockFreeDeque;
  LVal: AnsiString;
  I: Int32;
begin
  WriteLn('--- Grow ---');
  LDeque := TLockFreeDeque.Create(4); { small initial capacity }
  try
    for I := 0 to 99 do
      LDeque.PushRight('item-' + IntToStr(I));
    Check(LDeque.Count = 100, 'count = 100');
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'item-0', 'first = item-0');
    Check(LDeque.PopRight(LVal) = dqOk, 'PopRight ok');
    Check(LVal = 'item-99', 'last = item-99');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

procedure Test_Mixed;
var
  LDeque: TLockFreeDeque;
  LVal: AnsiString;
begin
  WriteLn('--- Mixed Push/Pop ---');
  LDeque := TLockFreeDeque.Create;
  try
    LDeque.PushLeft('b');
    LDeque.PushRight('c');
    LDeque.PushLeft('a');
    { Order: a, b, c }
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'a', 'first = a');
    Check(LDeque.PopRight(LVal) = dqOk, 'PopRight ok');
    Check(LVal = 'c', 'last = c');
    Check(LDeque.PopLeft(LVal) = dqOk, 'PopLeft ok');
    Check(LVal = 'b', 'middle = b');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

procedure Test_Clear;
var
  LDeque: TLockFreeDeque;
begin
  WriteLn('--- Clear ---');
  LDeque := TLockFreeDeque.Create;
  try
    LDeque.PushLeft('a');
    LDeque.PushRight('b');
    LDeque.Clear;
    Check(LDeque.Count = 0, 'count = 0 after clear');
    Check(LDeque.IsEmpty, 'empty after clear');
    LDeque.Free;
  except
    on E: Exception do
    begin
      Inc(GFailed);
      WriteLn('  FAIL: Exception: ', E.Message);
      LDeque.Free;
    end;
  end;
end;

function ReadTextFile(const APath: string): AnsiString;
begin
  Result := ReadFileText(APath);
end;

procedure Test_SourceContractCASOrder;
var
  LSource: AnsiString;
begin
  WriteLn('--- Source Contract ---');
  { Phase D: impl moved to deque_spin; contract lives with the real lock code }
  LSource := ReadTextFile('../../../src/nextpas.core.lockfree.deque_spin.pas');
  Check(Pos('LCasExpected := 0;', LSource) > 0,
    'lock acquire CAS order uses expected=0 desired=1');
  Check(Pos('atomic_compare_exchange_strong(FLock, LCasExpected, 1', LSource) > 0,
    'lock acquire uses preferred Boolean CAS');
  Check(Pos('atomic_store(FLock, 0, mo_release);', LSource) > 0,
    'lock release uses release store');
end;

begin
  GPassed := 0;
  GFailed := 0;
  WriteLn('=== DequeLF Tests ===');
  Test_Empty;
  Test_PushPopLeft;
  Test_PushPopRight;
  Test_FIFO;
  Test_Peek;
  Test_Grow;
  Test_Mixed;
  Test_Clear;
  Test_SourceContractCASOrder;
  WriteLn;
  WriteLn('Results: ', GPassed, ' passed, ', GFailed, ' failed');
  if GFailed > 0 then
    Halt(1);
end.

program test_stack;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.stack.intf;

type
  IIntStack = specialize IStack<Integer>;

var
  T: TTestRunner;

procedure TestMakeStackBasicLIFO;
var
  LStack: IIntStack;
begin
  LStack := specialize MakeStack<Integer>;
  LStack.Push(1);
  LStack.Push(2);
  LStack.Push(3);
  CheckEqual(Int64(3), Int64(LStack.Count), 'count after 3 pushes');
  CheckEqual(Int64(3), Int64(LStack.Pop), 'pop 1 (LIFO)');
  CheckEqual(Int64(2), Int64(LStack.Pop), 'pop 2 (LIFO)');
  CheckEqual(Int64(1), Int64(LStack.Pop), 'pop 3 (LIFO)');
  Check(LStack.IsEmpty, 'empty after all pops');
end;

procedure TestMakeStackFromArray;
var
  LStack: IIntStack;
begin
  LStack := specialize MakeStack<Integer>([10, 20, 30]);
  CheckEqual(Int64(3), Int64(LStack.Count), 'count from array');
  CheckEqual(Int64(30), Int64(LStack.Pop), 'last pushed is first popped');
end;

procedure TestStackPeek;
var
  LStack: IIntStack;
  LVal: Integer;
begin
  LStack := specialize MakeStack<Integer>;
  LStack.Push(42);
  CheckEqual(Int64(42), Int64(LStack.Peek), 'peek returns top');
  CheckEqual(Int64(1), Int64(LStack.Count), 'peek does not remove');
  Check(LStack.TryPeek(LVal), 'TryPeek succeeds');
  CheckEqual(Int64(42), Int64(LVal), 'TryPeek value');
end;

procedure TestStackTryPopEmpty;
var
  LStack: IIntStack;
  LVal: Integer;
begin
  LStack := specialize MakeStack<Integer>;
  LVal := 999;
  Check(not LStack.TryPeek(LVal), 'TryPeek on empty returns False');
  Check(not LStack.Pop(LVal), 'Pop(out) on empty returns False');
end;

procedure TestStackPopEmptyRaises;
var
  LStack: IIntStack;
  LRaised: Boolean;
begin
  LStack := specialize MakeStack<Integer>;
  LRaised := False;
  try
    LStack.Pop;
  except
    on E: EEmptyCollection do
      LRaised := True;
  end;
  Check(LRaised, 'Pop on empty raises EEmptyCollection');
end;

procedure TestStackClear;
var
  LStack: IIntStack;
begin
  LStack := specialize MakeStack<Integer>([1, 2, 3]);
  LStack.Clear;
  Check(LStack.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LStack.Count), 'count 0 after clear');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.stack');
  T.Run('MakeStack basic LIFO', @TestMakeStackBasicLIFO);
  T.Run('MakeStack from array', @TestMakeStackFromArray);
  T.Run('Stack Peek', @TestStackPeek);
  T.Run('Stack TryPop empty', @TestStackTryPopEmpty);
  T.Run('Stack Pop empty raises', @TestStackPopEmptyRaises);
  T.Run('Stack Clear', @TestStackClear);
  T.Summary;
end.

program test_priorityqueue;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.priorityqueue,
  nextpas.core.collections.priorityqueue.intf;

type
  IIntPQ = specialize IPriorityQueue<Integer>;
  TInspectableIntPQ = class(specialize TPriorityQueue<Integer>)
  public
    procedure CopyToBuffer(aDst: Pointer; aCount: SizeUInt);
  end;

function CompareIntDesc(const A, B: Integer; aData: Pointer): SizeInt;
begin
  if A > B then Result := -1
  else if A < B then Result := 1
  else Result := 0;
end;

var
  T: TTestRunner;

procedure TInspectableIntPQ.CopyToBuffer(aDst: Pointer; aCount: SizeUInt);
begin
  SerializeToArrayBuffer(aDst, aCount);
end;

procedure TestPushAndPop;
var
  LQ: IIntPQ;
begin
  LQ := specialize MakePriorityQueue<Integer>(@CompareIntDesc);
  LQ.Push(3);
  LQ.Push(1);
  LQ.Push(4);
  LQ.Push(2);
  CheckEqual(Int64(4), Int64(LQ.Pop), 'pop highest');
  CheckEqual(Int64(3), Int64(LQ.Pop), 'pop next');
  CheckEqual(Int64(2), Int64(LQ.Pop), 'pop next');
  CheckEqual(Int64(1), Int64(LQ.Pop), 'pop last');
end;

procedure TestPeek;
var
  LQ: IIntPQ;
  LVal: Integer;
begin
  LQ := specialize MakePriorityQueue<Integer>(@CompareIntDesc);
  LQ.Push(10);
  LQ.Push(20);
  CheckEqual(Int64(20), Int64(LQ.Peek), 'peek highest');
  CheckEqual(Int64(2), Int64(LQ.GetCount), 'peek does not remove');
  Check(LQ.TryPeek(LVal), 'try peek');
  CheckEqual(Int64(20), Int64(LVal), 'try peek value');
end;

procedure TestTryPopEmpty;
var
  LQ: IIntPQ;
  LVal: Integer;
begin
  LQ := specialize MakePriorityQueue<Integer>(@CompareIntDesc);
  Check(not LQ.TryPop(LVal), 'try pop on empty');
  LQ.Push(5);
  Check(LQ.TryPop(LVal), 'try pop on non-empty');
  CheckEqual(Int64(5), Int64(LVal), 'popped value');
end;

procedure TestPopEmptyRaises;
var
  LQ: IIntPQ;
  LRaised: Boolean;
begin
  LQ := specialize MakePriorityQueue<Integer>(@CompareIntDesc);
  LRaised := False;
  try
    LQ.Pop;
  except
    on E: EEmptyCollection do
      LRaised := True;
  end;
  Check(LRaised, 'pop on empty raises');
end;

procedure TestClear;
var
  LQ: IIntPQ;
begin
  LQ := specialize MakePriorityQueue<Integer>(@CompareIntDesc);
  LQ.Push(1);
  LQ.Push(2);
  LQ.Clear;
  Check(LQ.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LQ.GetCount), 'count 0');
end;

procedure TestIsEmpty;
var
  LQ: IIntPQ;
begin
  LQ := specialize MakePriorityQueue<Integer>(@CompareIntDesc);
  Check(LQ.IsEmpty, 'initially empty');
  LQ.Push(1);
  Check(not LQ.IsEmpty, 'not empty');
end;

procedure TestManyElements;
var
  LQ: IIntPQ;
  I, LCur, LPrev: Integer;
begin
  LQ := specialize MakePriorityQueue<Integer>(@CompareIntDesc);
  for I := 1 to 100 do
    LQ.Push(I);
  CheckEqual(Int64(100), Int64(LQ.GetCount), 'count 100');
  LPrev := LQ.Pop;
  for I := 2 to 100 do
  begin
    LCur := LQ.Pop;
    Check(LCur <= LPrev, 'descending order');
    LPrev := LCur;
  end;
end;

procedure TestSerializeCountPastEndRaises;
var
  LQ: TInspectableIntPQ;
  LOut: Integer;
  LRaised: Boolean;
begin
  LQ := TInspectableIntPQ.Create(@CompareIntDesc);
  try
    LQ.Push(10);
    LRaised := False;
    try
      LQ.CopyToBuffer(@LOut, 2);
    except
      on E: EOutOfRange do
        LRaised := True;
    end;
    Check(LRaised, 'serialize count past end raises');
  finally
    LQ.Free;
  end;
end;

procedure TestSerializeNilPositiveCountRaises;
var
  LQ: TInspectableIntPQ;
  LRaised: Boolean;
begin
  LQ := TInspectableIntPQ.Create(@CompareIntDesc);
  try
    LQ.Push(10);
    LRaised := False;
    try
      LQ.CopyToBuffer(nil, 1);
    except
      on E: EArgumentNil do
        LRaised := True;
    end;
    Check(LRaised, 'serialize nil destination raises');
  finally
    LQ.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.priorityqueue');
  T.Run('Push and Pop (priority order)', @TestPushAndPop);
  T.Run('Peek', @TestPeek);
  T.Run('TryPop empty', @TestTryPopEmpty);
  T.Run('Pop empty raises', @TestPopEmptyRaises);
  T.Run('Clear', @TestClear);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Run('Many elements (100)', @TestManyElements);
  T.Run('SerializeToArrayBuffer count past end raises', @TestSerializeCountPastEndRaises);
  T.Run('SerializeToArrayBuffer nil positive count raises', @TestSerializeNilPositiveCountRaises);
  T.Summary;
end.

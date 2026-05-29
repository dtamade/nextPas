program test_error_paths;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections.vec,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.stack,
  nextpas.core.collections.deque,
  nextpas.core.collections.list,
  nextpas.core.collections.forward_list,
  nextpas.core.collections.priorityqueue,
  nextpas.core.collections.circularbuffer,
  nextpas.core.collections.tree_set;

type
  TIntVec = specialize TVec<Integer>;
  TIntDeque = specialize TVecDeque<Integer>;
  TIntStack = specialize TStack<Integer>;
  TIntList = specialize TList<Integer>;
  TIntFwdList = specialize TForwardList<Integer>;
  TIntPQ = specialize TPriorityQueue<Integer>;
  TIntCB = specialize TCircularBuffer<Integer>;
  TIntTreeSet = specialize TTreeSet<Integer>;

function CmpInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

var
  T: TTestRunner;

{ Vec }
procedure TestVecPopEmpty;
var LV: TIntVec; LRaised: Boolean;
begin
  LV := TIntVec.Create; LRaised := False;
  try try LV.Pop; except on E: EEmptyCollection do LRaised := True; end;
  finally LV.Free; end;
  Check(LRaised, 'Vec.Pop empty raises');
end;

procedure TestVecGetOutOfRange;
var LV: TIntVec; LRaised: Boolean;
begin
  LV := TIntVec.Create; LRaised := False;
  try try LV.Get(0); except on E: EOutOfRange do LRaised := True; end;
  finally LV.Free; end;
  Check(LRaised, 'Vec.Get(0) on empty raises');
end;

{ VecDeque }
procedure TestDequePopFrontEmpty;
var LD: TIntDeque; LRaised: Boolean;
begin
  LD := TIntDeque.Create; LRaised := False;
  try try LD.PopFront; except on E: EOutOfRange do LRaised := True; end;
  finally LD.Free; end;
  Check(LRaised, 'VecDeque.PopFront empty raises');
end;

procedure TestDequePopBackEmpty;
var LD: TIntDeque; LRaised: Boolean;
begin
  LD := TIntDeque.Create; LRaised := False;
  try try LD.PopBack; except on E: EOutOfRange do LRaised := True; end;
  finally LD.Free; end;
  Check(LRaised, 'VecDeque.PopBack empty raises');
end;

{ Stack }
procedure TestStackPopEmpty;
var LS: TIntStack; LRaised: Boolean;
begin
  LS := TIntStack.Create; LRaised := False;
  try try LS.Pop; except on E: EEmptyCollection do LRaised := True; end;
  finally LS.Free; end;
  Check(LRaised, 'Stack.Pop empty raises');
end;

procedure TestStackPeekEmpty;
var LS: TIntStack; LRaised: Boolean;
begin
  LS := TIntStack.Create; LRaised := False;
  try try LS.Peek; except on E: EEmptyCollection do LRaised := True; end;
  finally LS.Free; end;
  Check(LRaised, 'Stack.Peek empty raises');
end;

{ List }
procedure TestListPopFrontEmpty;
var LL: TIntList; LRaised: Boolean;
begin
  LL := TIntList.Create; LRaised := False;
  try try LL.PopFront; except LRaised := True; end;
  finally LL.Free; end;
  Check(LRaised, 'List.PopFront empty raises');
end;

procedure TestListPopBackEmpty;
var LL: TIntList; LRaised: Boolean;
begin
  LL := TIntList.Create; LRaised := False;
  try try LL.PopBack; except LRaised := True; end;
  finally LL.Free; end;
  Check(LRaised, 'List.PopBack empty raises');
end;

{ ForwardList }
procedure TestFwdListPopFrontEmpty;
var LL: TIntFwdList; LRaised: Boolean;
begin
  LL := TIntFwdList.Create; LRaised := False;
  try try LL.PopFront; except LRaised := True; end;
  finally LL.Free; end;
  Check(LRaised, 'ForwardList.PopFront empty raises');
end;

{ PriorityQueue }
procedure TestPQPopEmpty;
var LPQ: TIntPQ; LRaised: Boolean;
begin
  LPQ := TIntPQ.Create(specialize TPriorityQueue<Integer>.TPQCompareFunc(@CmpInt));
  LRaised := False;
  try try LPQ.Pop; except on E: EEmptyCollection do LRaised := True; end;
  finally LPQ.Free; end;
  Check(LRaised, 'PQ.Pop empty raises');
end;

procedure TestPQPeekEmpty;
var LPQ: TIntPQ; LRaised: Boolean;
begin
  LPQ := TIntPQ.Create(specialize TPriorityQueue<Integer>.TPQCompareFunc(@CmpInt));
  LRaised := False;
  try try LPQ.Peek; except on E: EEmptyCollection do LRaised := True; end;
  finally LPQ.Free; end;
  Check(LRaised, 'PQ.Peek empty raises');
end;

{ CircularBuffer }
procedure TestCBPopEmpty;
var LCB: TIntCB; LRaised: Boolean;
begin
  LCB := TIntCB.Create(4); LRaised := False;
  try try LCB.Pop; except LRaised := True; end;
  finally LCB.Free; end;
  Check(LRaised, 'CircularBuffer.Pop empty raises');
end;

{ TreeSet }
procedure TestTreeSetMinEmpty;
var LS: TIntTreeSet; LVal: Integer;
begin
  LS := TIntTreeSet.Create;
  try
    Check(not LS.Min(LVal), 'TreeSet.Min on empty returns False');
  finally LS.Free; end;
end;

procedure TestTreeSetMaxEmpty;
var LS: TIntTreeSet; LVal: Integer;
begin
  LS := TIntTreeSet.Create;
  try
    Check(not LS.Max(LVal), 'TreeSet.Max on empty returns False');
  finally LS.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.error_paths');
  T.Run('Vec.Pop empty', @TestVecPopEmpty);
  T.Run('Vec.Get out of range', @TestVecGetOutOfRange);
  T.Run('VecDeque.PopFront empty', @TestDequePopFrontEmpty);
  T.Run('VecDeque.PopBack empty', @TestDequePopBackEmpty);
  T.Run('Stack.Pop empty', @TestStackPopEmpty);
  T.Run('Stack.Peek empty', @TestStackPeekEmpty);
  T.Run('List.PopFront empty', @TestListPopFrontEmpty);
  T.Run('List.PopBack empty', @TestListPopBackEmpty);
  T.Run('ForwardList.PopFront empty', @TestFwdListPopFrontEmpty);
  T.Run('PQ.Pop empty', @TestPQPopEmpty);
  T.Run('PQ.Peek empty', @TestPQPeekEmpty);
  T.Run('CircularBuffer.Pop empty', @TestCBPopEmpty);
  T.Run('TreeSet.Min empty', @TestTreeSetMinEmpty);
  T.Run('TreeSet.Max empty', @TestTreeSetMaxEmpty);
  T.Summary;
end.
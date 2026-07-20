program test_error_paths;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
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
  T: TTestSuite;

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

{ VecDeque — empty state uses EEmptyCollection (ERRORS.md) }
procedure TestDequePopFrontEmpty;
var LD: TIntDeque; LRaised: Boolean;
begin
  LD := TIntDeque.Create; LRaised := False;
  try try LD.PopFront; except on E: EEmptyCollection do LRaised := True; end;
  finally LD.Free; end;
  Check(LRaised, 'VecDeque.PopFront empty raises EEmptyCollection');
end;

procedure TestDequePopBackEmpty;
var LD: TIntDeque; LRaised: Boolean;
begin
  LD := TIntDeque.Create; LRaised := False;
  try try LD.PopBack; except on E: EEmptyCollection do LRaised := True; end;
  finally LD.Free; end;
  Check(LRaised, 'VecDeque.PopBack empty raises EEmptyCollection');
end;

procedure TestDequeFirstEmpty;
var LD: TIntDeque; LRaised: Boolean;
begin
  LD := TIntDeque.Create; LRaised := False;
  try try LD.First; except on E: EEmptyCollection do LRaised := True; end;
  finally LD.Free; end;
  Check(LRaised, 'VecDeque.First empty raises EEmptyCollection');
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
  try try LL.PopFront; except on E: EEmptyCollection do LRaised := True; end;
  finally LL.Free; end;
  Check(LRaised, 'List.PopFront empty raises EEmptyCollection');
end;

procedure TestListPopBackEmpty;
var LL: TIntList; LRaised: Boolean;
begin
  LL := TIntList.Create; LRaised := False;
  try try LL.PopBack; except on E: EEmptyCollection do LRaised := True; end;
  finally LL.Free; end;
  Check(LRaised, 'List.PopBack empty raises EEmptyCollection');
end;

{ ForwardList }
procedure TestFwdListPopFrontEmpty;
var LL: TIntFwdList; LRaised: Boolean;
begin
  LL := TIntFwdList.Create; LRaised := False;
  try try LL.PopFront; except on E: EEmptyCollection do LRaised := True; end;
  finally LL.Free; end;
  Check(LRaised, 'ForwardList.PopFront empty raises EEmptyCollection');
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
  try try LCB.Pop; except on E: EEmptyCollection do LRaised := True; end;
  finally LCB.Free; end;
  Check(LRaised, 'CircularBuffer.Pop empty raises EEmptyCollection');
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
  T := TTestSuite.Create('nextpas.core.collections.error_paths');
  T.Test('Vec.Pop empty', @TestVecPopEmpty);
  T.Test('Vec.Get out of range', @TestVecGetOutOfRange);
  T.Test('VecDeque.PopFront empty', @TestDequePopFrontEmpty);
  T.Test('VecDeque.PopBack empty', @TestDequePopBackEmpty);
  T.Test('VecDeque.First empty', @TestDequeFirstEmpty);
  T.Test('Stack.Pop empty', @TestStackPopEmpty);
  T.Test('Stack.Peek empty', @TestStackPeekEmpty);
  T.Test('List.PopFront empty', @TestListPopFrontEmpty);
  T.Test('List.PopBack empty', @TestListPopBackEmpty);
  T.Test('ForwardList.PopFront empty', @TestFwdListPopFrontEmpty);
  T.Test('PQ.Pop empty', @TestPQPopEmpty);
  T.Test('PQ.Peek empty', @TestPQPeekEmpty);
  T.Test('CircularBuffer.Pop empty', @TestCBPopEmpty);
  T.Test('TreeSet.Min empty', @TestTreeSetMinEmpty);
  T.Test('TreeSet.Max empty', @TestTreeSetMaxEmpty);
  if not T.Run then Halt(1);
end.
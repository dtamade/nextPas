program test_contracts;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.collections.base,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.node,
  nextpas.core.collections.slice,
  nextpas.core.collections.vec,
  leak_tracker;

type
  TIntManager = specialize TElementManager<Integer>;
  TStringManager = specialize TElementManager<string>;
  TTrackedManager = specialize TElementManager<ITracked>;
  TManagedRecord = record
    Initialized: Boolean;
    Id: Int32;
    class operator Initialize(var ARecord: TManagedRecord);
    class operator Finalize(var ARecord: TManagedRecord);
  end;
  TManagedRecordManager = specialize TElementManager<TManagedRecord>;
  TIntVec = specialize TVec<Integer>;
  TIntSpan = specialize TReadOnlySpan<Integer>;
  TIntSpan2 = specialize TReadOnlySpan2<Integer>;
  TTrackedSingleNode = specialize TSingleLinkedNode<ITracked>;
  TTrackedDoubleNode = specialize TDoubleLinkedNode<ITracked>;
  TTrackedTreeNode = specialize TTreeNode<ITracked>;

  TGrowthRecorder = class
  public
    Calls: Integer;
    LastCurrentSize: SizeUInt;
    LastRequiredSize: SizeUInt;
    ReturnValue: SizeUInt;
    function Grow(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
  end;

  TRandomRecorder = class
  public
    Calls: Integer;
    LastData: Pointer;
    Ranges: array[0..7] of Int64;
    function Next(aRange: Int64; aData: Pointer): Int64;
  end;

var
  T: TTestRunner;
  GGrowFuncCalls: Integer = 0;
  GGrowFuncLastCurrentSize: SizeUInt = 0;
  GGrowFuncLastRequiredSize: SizeUInt = 0;
  GGrowFuncLastData: Pointer = nil;
  GRandomFuncCalls: Integer = 0;
  GRandomFuncLastData: Pointer = nil;
  GRandomFuncRanges: array[0..7] of Int64;
  GManagedRecordAlive: Int32 = 0;
  GManagedRecordBadFinalize: Int32 = 0;

class operator TManagedRecord.Initialize(var ARecord: TManagedRecord);
begin
  ARecord.Initialized := True;
  ARecord.Id := 0;
  Inc(GManagedRecordAlive);
end;

class operator TManagedRecord.Finalize(var ARecord: TManagedRecord);
begin
  if not ARecord.Initialized then
    Inc(GManagedRecordBadFinalize)
  else
  begin
    ARecord.Initialized := False;
    Dec(GManagedRecordAlive);
  end;
end;

function TGrowthRecorder.Grow(aCurrentSize, aRequiredSize: SizeUInt): SizeUInt;
begin
  Inc(Calls);
  LastCurrentSize := aCurrentSize;
  LastRequiredSize := aRequiredSize;
  Result := ReturnValue;
end;

function TRandomRecorder.Next(aRange: Int64; aData: Pointer): Int64;
begin
  Ranges[Calls] := aRange;
  Inc(Calls);
  LastData := aData;
  Result := 0;
end;

procedure ResetRandomFuncRecorder;
var
  I: Integer;
begin
  GRandomFuncCalls := 0;
  GRandomFuncLastData := nil;
  for I := Low(GRandomFuncRanges) to High(GRandomFuncRanges) do
    GRandomFuncRanges[I] := -1;
end;

procedure ResetGrowFuncRecorder;
begin
  GGrowFuncCalls := 0;
  GGrowFuncLastCurrentSize := 0;
  GGrowFuncLastRequiredSize := 0;
  GGrowFuncLastData := nil;
end;

function GrowByOffset(aCurrentSize, aRequiredSize: SizeUInt; aData: Pointer): SizeUInt;
begin
  Inc(GGrowFuncCalls);
  GGrowFuncLastCurrentSize := aCurrentSize;
  GGrowFuncLastRequiredSize := aRequiredSize;
  GGrowFuncLastData := aData;
  Result := aRequiredSize + PSizeUInt(aData)^;
end;

function RandomFromStart(aRange: Int64; aData: Pointer): Int64;
begin
  GRandomFuncRanges[GRandomFuncCalls] := aRange;
  Inc(GRandomFuncCalls);
  GRandomFuncLastData := aData;
  Result := 0;
end;

procedure CheckTrackedElement(AElements: TTrackedManager.PElement; AIndex: SizeInt; AExpected: Int32; const AContext: string);
begin
  Check(AElements[AIndex] <> nil, AContext + ' should not be nil');
  CheckEqual(Int64(AExpected), Int64(AElements[AIndex].GetId), AContext);
end;

procedure TestElementManagerUnmanagedCopyFillZeroAndOverlap;
var
  LManager: TIntManager;
  LValue: Integer;
  LBuffer: array[0..5] of Integer;
begin
  LManager := TIntManager.Create(DefaultAllocator);
  try
    CheckEqual(Int64(SizeOf(Integer)), Int64(LManager.ElementSize), 'integer element size');
    CheckEqual(False, LManager.IsManagedType, 'integer should be unmanaged');
    Check(LManager.AllocElements(0) = nil, 'AllocElements(0) should return nil');

    LValue := 7;
    LManager.FillElements(@LBuffer[0], LValue, Length(LBuffer));
    CheckEqual(Int64(7), Int64(LBuffer[0]), 'FillElements should write the first value');
    CheckEqual(Int64(7), Int64(LBuffer[5]), 'FillElements should write the last value');

    LBuffer[0] := 1;
    LBuffer[1] := 2;
    LBuffer[2] := 3;
    LBuffer[3] := 4;
    LBuffer[4] := 5;
    LBuffer[5] := 6;
    Check(LManager.IsOverlap(@LBuffer[0], @LBuffer[1], 4), 'element ranges should overlap');

    LManager.CopyElements(TIntManager.PElement(@LBuffer[0]), TIntManager.PElement(@LBuffer[1]), 4);
    CheckEqual(Int64(1), Int64(LBuffer[0]), 'overlap copy index 0');
    CheckEqual(Int64(1), Int64(LBuffer[1]), 'overlap copy index 1');
    CheckEqual(Int64(2), Int64(LBuffer[2]), 'overlap copy index 2');
    CheckEqual(Int64(3), Int64(LBuffer[3]), 'overlap copy index 3');
    CheckEqual(Int64(4), Int64(LBuffer[4]), 'overlap copy index 4');

    LManager.ZeroElements(@LBuffer[0], Length(LBuffer));
    CheckEqual(Int64(0), Int64(LBuffer[0]), 'ZeroElements should clear the first integer');
    CheckEqual(Int64(0), Int64(LBuffer[5]), 'ZeroElements should clear the last integer');
  finally
    LManager.Free;
  end;
end;

procedure TestElementManagerManagedReallocAndOverlapCopy;
var
  LManager: TStringManager;
  LElements: TStringManager.PElement;
  LSecond: TStringManager.PElement;
  LRaised: Boolean;
begin
  LManager := TStringManager.Create(DefaultAllocator);
  try
    CheckEqual(True, LManager.IsManagedType, 'string should be a managed type');

    LRaised := False;
    try
      LElements := LManager.ReallocElements(nil, 1, 2);
      if LElements <> nil then
        LManager.FreeElements(LElements, 2);
    except
      on E: EInvalidOperation do
        LRaised := True;
    end;
    Check(LRaised, 'ReallocElements should reject nil pointer with nonzero old count');

    LElements := LManager.AllocElements(3);
    Check(LElements <> nil, 'AllocElements should allocate managed storage');
    try
      CheckEqual('', LElements[0], 'managed slots should initialize to empty string');
      CheckEqual('', LElements[1], 'managed slots should initialize to empty string');

      LElements[0] := 'A';
      LElements[1] := 'B';
      LElements[2] := 'C';

      LElements := LManager.ReallocElements(LElements, 3, 5);
      CheckEqual('A', LElements[0], 'ReallocElements should preserve prefix item 0');
      CheckEqual('B', LElements[1], 'ReallocElements should preserve prefix item 1');
      CheckEqual('C', LElements[2], 'ReallocElements should preserve prefix item 2');
      CheckEqual('', LElements[3], 'ReallocElements should initialize the first expanded slot');
      CheckEqual('', LElements[4], 'ReallocElements should initialize the second expanded slot');

      LSecond := LElements + 1;
      LManager.CopyElements(LElements, LSecond, 4);
      CheckEqual('A', LElements[0], 'managed overlap copy index 0');
      CheckEqual('A', LElements[1], 'managed overlap copy index 1');
      CheckEqual('B', LElements[2], 'managed overlap copy index 2');
      CheckEqual('C', LElements[3], 'managed overlap copy index 3');
      CheckEqual('', LElements[4], 'managed overlap copy index 4');

      LElements[0] := 'A';
      LElements[1] := 'B';
      LElements[2] := 'C';
      LElements[3] := 'D';
      LElements[4] := 'E';
      LManager.CopyElements(LElements + 1, LElements, 4);
      CheckEqual('B', LElements[0], 'managed reverse overlap copy index 0');
      CheckEqual('C', LElements[1], 'managed reverse overlap copy index 1');
      CheckEqual('D', LElements[2], 'managed reverse overlap copy index 2');
      CheckEqual('E', LElements[3], 'managed reverse overlap copy index 3');
      CheckEqual('E', LElements[4], 'managed reverse overlap copy index 4');

      LManager.ZeroElements(LElements, 5);
      CheckEqual('', LElements[0], 'ZeroElements should clear managed slot 0');
      CheckEqual('', LElements[4], 'ZeroElements should clear managed slot 4');

      LElements := LManager.ReallocElements(LElements, 5, 2);
      CheckEqual('', LElements[0], 'shrink should preserve remaining slot 0');
      CheckEqual('', LElements[1], 'shrink should preserve remaining slot 1');
    finally
      LManager.FreeElements(LElements, 2);
    end;
  finally
    LManager.Free;
  end;
end;

procedure RunElementManagerManagedCopyArrayPathOwnsRefs;
const
  CCount = 12;
var
  LManager: TTrackedManager;
  LSource: TTrackedManager.PElement;
  LDest: TTrackedManager.PElement;
  I: SizeInt;
begin
  LManager := TTrackedManager.Create(DefaultAllocator);
  LSource := nil;
  LDest := nil;
  try
    LSource := LManager.AllocElements(CCount);
    LDest := LManager.AllocElements(CCount);
    for I := 0 to CCount - 1 do
    begin
      LSource[I] := MakeTracked(100 + I);
      LDest[I] := MakeTracked(200 + I);
    end;

    LManager.CopyElementsNonOverlap(LSource, LDest, CCount);

    for I := 0 to CCount - 1 do
      CheckTrackedElement(LDest, I, 100 + I, 'CopyArray path should retain destination refs');

    LManager.FreeElements(LSource, CCount);
    LSource := nil;

    for I := 0 to CCount - 1 do
      CheckTrackedElement(LDest, I, 100 + I, 'destination refs should outlive source free');
  finally
    if LSource <> nil then
      LManager.FreeElements(LSource, CCount);
    if LDest <> nil then
      LManager.FreeElements(LDest, CCount);
    LManager.Free;
  end;
end;

procedure TestElementManagerManagedCopyArrayPathOwnsRefs;
var
  LSnap: TLeakSnapshot;
begin
  LSnap := SnapTake;
  RunElementManagerManagedCopyArrayPathOwnsRefs;
  SnapAssert(LSnap, 'element manager managed CopyArray path owns refs');
end;

procedure RunElementManagerManagedZeroElementsReinitializesReusableSlots;
var
  LManager: TTrackedManager;
  LElements: TTrackedManager.PElement;
begin
  LManager := TTrackedManager.Create(DefaultAllocator);
  LElements := nil;
  try
    LElements := LManager.AllocElements(2);
    LElements[0] := MakeTracked(1);
    LElements[1] := MakeTracked(2);

    LManager.ZeroElements(LElements, 2);

    Check(LElements[0] = nil, 'ZeroElements should leave managed slot 0 reusable');
    Check(LElements[1] = nil, 'ZeroElements should leave managed slot 1 reusable');
    LElements[0] := MakeTracked(3);
    LElements[1] := MakeTracked(4);
    CheckTrackedElement(LElements, 0, 3, 'reused slot 0 should hold the new ref');
    CheckTrackedElement(LElements, 1, 4, 'reused slot 1 should hold the new ref');
  finally
    if LElements <> nil then
      LManager.FreeElements(LElements, 2);
    LManager.Free;
  end;
end;

procedure TestElementManagerManagedZeroElementsReinitializesReusableSlots;
var
  LSnap: TLeakSnapshot;
begin
  LSnap := SnapTake;
  RunElementManagerManagedZeroElementsReinitializesReusableSlots;
  SnapAssert(LSnap, 'element manager managed ZeroElements reusable slots');
end;

procedure TestElementManagerManagedRecordZeroElementsReinitializesBeforeFree;
var
  LManager: TManagedRecordManager;
  LElements: TManagedRecordManager.PElement;
begin
  GManagedRecordAlive := 0;
  GManagedRecordBadFinalize := 0;
  LManager := TManagedRecordManager.Create(DefaultAllocator);
  LElements := nil;
  try
    LElements := LManager.AllocElements(2);
    CheckEqual(Int64(2), Int64(GManagedRecordAlive), 'managed record alloc should initialize slots');
    LElements[0].Id := 10;
    LElements[1].Id := 20;

    LManager.ZeroElements(LElements, 2);

    CheckEqual(Int64(2), Int64(GManagedRecordAlive), 'ZeroElements should reinitialize managed record slots');
    CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'ZeroElements should not finalize uninitialized slots');
  finally
    if LElements <> nil then
      LManager.FreeElements(LElements, 2);
    LManager.Free;
  end;

  CheckEqual(Int64(0), Int64(GManagedRecordAlive), 'FreeElements should finalize reinitialized managed record slots');
  CheckEqual(Int64(0), Int64(GManagedRecordBadFinalize), 'FreeElements should not double-finalize managed record slots');
end;

procedure TestNodeClearReleasesManagedDataAndLinks;
var
  LSnap: TLeakSnapshot;
  LSingle: TTrackedSingleNode;
  LDouble: TTrackedDoubleNode;
  LTree: TTrackedTreeNode;
  LTracked: ITracked;
begin
  LSnap := SnapTake;

  LSingle := Default(TTrackedSingleNode);
  LTracked := MakeTracked(1001);
  LSingle.Init(LTracked, Pointer(PtrUInt(1)));
  LTracked := nil;
  CheckEqual(Int64(1), Int64(GTrackedAlive - LSnap), 'single node should own one tracked ref before clear');
  LSingle.Clear;
  Check(LSingle.Data = nil, 'single node Clear should nil managed data');
  Check(LSingle.Next = nil, 'single node Clear should nil next link');
  SnapAssert(LSnap, 'single node Clear releases managed data');

  LDouble := Default(TTrackedDoubleNode);
  LTracked := MakeTracked(1002);
  LDouble.Init(LTracked, Pointer(PtrUInt(2)), Pointer(PtrUInt(3)));
  LTracked := nil;
  CheckEqual(Int64(1), Int64(GTrackedAlive - LSnap), 'double node should own one tracked ref before clear');
  LDouble.Clear;
  Check(LDouble.Data = nil, 'double node Clear should nil managed data');
  Check(LDouble.Prev = nil, 'double node Clear should nil prev link');
  Check(LDouble.Next = nil, 'double node Clear should nil next link');
  SnapAssert(LSnap, 'double node Clear releases managed data');

  LTree := Default(TTrackedTreeNode);
  LTracked := MakeTracked(1003);
  LTree.Init(LTracked, Pointer(PtrUInt(4)));
  LTree.FirstChild := Pointer(PtrUInt(5));
  LTree.NextSibling := Pointer(PtrUInt(6));
  LTracked := nil;
  CheckEqual(Int64(1), Int64(GTrackedAlive - LSnap), 'tree node should own one tracked ref before clear');
  LTree.Clear;
  Check(LTree.Data = nil, 'tree node Clear should nil managed data');
  Check(LTree.Parent = nil, 'tree node Clear should nil parent link');
  Check(LTree.FirstChild = nil, 'tree node Clear should nil first child link');
  Check(LTree.NextSibling = nil, 'tree node Clear should nil next sibling link');
  SnapAssert(LSnap, 'tree node Clear releases managed data');
end;

procedure TestGrowthStrategiesHonorBoundsAndAlignment;
var
  LStrategy: IGrowthStrategy;
  LAligned: TAlignedWrapperStrategy;
begin
  LStrategy := FixedGrow(3);
  CheckEqual(Int64(10), Int64(LStrategy.GetGrowSize(4, 8)), 'FixedGrow should advance in fixed steps');

  LStrategy := FactorGrow(1.5);
  CheckEqual(Int64(12), Int64(LStrategy.GetGrowSize(8, 12)), 'FactorGrow should honor the requested lower bound');

  LStrategy := DoublingGrow;
  CheckEqual(Int64(8), Int64(LStrategy.GetGrowSize(4, 5)), 'DoublingGrow should double existing capacity');

  LStrategy := ExactGrow;
  CheckEqual(Int64(11), Int64(LStrategy.GetGrowSize(8, 11)), 'ExactGrow should return the requested size');

  LStrategy := GoldenRatioGrow;
  Check(LStrategy.GetGrowSize(8, 9) >= 9, 'GoldenRatioGrow should satisfy the requested lower bound');

  LAligned := TAlignedWrapperStrategy.Create(ExactGrow, 8);
  try
    CheckEqual(Int64(16), Int64(LAligned.GetGrowSize(0, 9)), 'aligned wrapper should round the result up to alignment');
  finally
    LAligned.Free;
  end;

  try
    TAlignedWrapperStrategy.Create(ExactGrow, 3).Free;
    Fail('non-power-of-two alignment should raise EInvalidArgument');
  except
    on E: EInvalidArgument do
      ;
  end;
end;

procedure TestCustomGrowthStrategyFunctionAndMethodCallbacks;
var
  LStrategy: IGrowthStrategy;
  LRecorder: TGrowthRecorder;
  LOffset: SizeUInt;
  LGrowFunc: TGrowFunc;
  LGrowMethod: TGrowMethod;
begin
  ResetGrowFuncRecorder;
  LOffset := 3;
  LGrowFunc := @GrowByOffset;
  LStrategy := TCustomGrowthStrategy.Create(LGrowFunc, @LOffset);
  CheckEqual(Int64(13), Int64(LStrategy.GetGrowSize(4, 10)), 'function growth callback should contribute its offset');
  CheckEqual(Int64(1), Int64(GGrowFuncCalls), 'function growth callback should be invoked once');
  CheckEqual(Int64(4), Int64(GGrowFuncLastCurrentSize), 'function growth callback should receive current size');
  CheckEqual(Int64(10), Int64(GGrowFuncLastRequiredSize), 'function growth callback should receive required size');
  Check(GGrowFuncLastData = @LOffset, 'function growth callback should receive the data pointer');

  LRecorder := TGrowthRecorder.Create;
  try
    LRecorder.ReturnValue := 6;
    LGrowMethod := @LRecorder.Grow;
    LStrategy := TCustomGrowthStrategy.Create(LGrowMethod, Pointer(PtrUInt(1234)));
    CheckEqual(Int64(10), Int64(LStrategy.GetGrowSize(4, 10)), 'method growth callback should still honor the required lower bound');
    CheckEqual(Int64(1), Int64(LRecorder.Calls), 'method growth callback should be invoked once');
    CheckEqual(Int64(4), Int64(LRecorder.LastCurrentSize), 'method growth callback should receive current size');
    CheckEqual(Int64(10), Int64(LRecorder.LastRequiredSize), 'method growth callback should receive required size');
  finally
    LRecorder.Free;
  end;
end;

procedure TestShuffleRandomGeneratorFunctionAndMethodCallbacks;
var
  LVec: TIntVec;
  LRecorder: TRandomRecorder;
  LTag: SizeUInt;
begin
  ResetRandomFuncRecorder;
  LTag := 99;
  LVec := TIntVec.Create([1, 2, 3, 4]);
  try
    LVec.Shuffle(@RandomFromStart, @LTag);
    CheckEqual(Int64(3), Int64(GRandomFuncCalls), 'shuffle function callback should run once per swap');
    Check(GRandomFuncLastData = @LTag, 'shuffle function callback should receive the data pointer');
    CheckEqual(Int64(4), GRandomFuncRanges[0], 'shuffle function callback first range');
    CheckEqual(Int64(3), GRandomFuncRanges[1], 'shuffle function callback second range');
    CheckEqual(Int64(2), GRandomFuncRanges[2], 'shuffle function callback third range');
    CheckEqual(Int64(2), Int64(LVec[0]), 'shuffle function callback resulting order index 0');
    CheckEqual(Int64(3), Int64(LVec[1]), 'shuffle function callback resulting order index 1');
    CheckEqual(Int64(4), Int64(LVec[2]), 'shuffle function callback resulting order index 2');
    CheckEqual(Int64(1), Int64(LVec[3]), 'shuffle function callback resulting order index 3');
  finally
    LVec.Free;
  end;

  LRecorder := TRandomRecorder.Create;
  LVec := TIntVec.Create([1, 2, 3, 4]);
  try
    LVec.Shuffle(@LRecorder.Next, @LTag);
    CheckEqual(Int64(3), Int64(LRecorder.Calls), 'shuffle method callback should run once per swap');
    Check(LRecorder.LastData = @LTag, 'shuffle method callback should receive the data pointer');
    CheckEqual(Int64(4), LRecorder.Ranges[0], 'shuffle method callback first range');
    CheckEqual(Int64(3), LRecorder.Ranges[1], 'shuffle method callback second range');
    CheckEqual(Int64(2), LRecorder.Ranges[2], 'shuffle method callback third range');
  finally
    LVec.Free;
    LRecorder.Free;
  end;
end;

procedure TestSpanSubSpanRejectsOverflowingCount;
var
  LValues: array[0..3] of Integer;
  LSpan: TIntSpan;
  LSpan2: TIntSpan2;
  LHugeCount: SizeUInt;
  LRaised: Boolean;
begin
  LValues[0] := 10;
  LValues[1] := 20;
  LValues[2] := 30;
  LValues[3] := 40;
  LSpan := TIntSpan.FromPointer(@LValues[0], Length(LValues), SizeOf(Integer));
  LHugeCount := High(SizeUInt);

  LRaised := False;
  try
    LSpan.SubSpan(1, LHugeCount);
  except
    on E: EOutOfRange do
      LRaised := True;
  end;
  Check(LRaised, 'Span.SubSpan should reject overflowing ranges');

  LSpan2 := TIntSpan2.FromTwo(
    TIntSpan.FromPointer(@LValues[0], 2, SizeOf(Integer)),
    TIntSpan.FromPointer(@LValues[2], 2, SizeOf(Integer)));

  LRaised := False;
  try
    LSpan2.SubSpan(1, LHugeCount);
  except
    on E: EOutOfRange do
      LRaised := True;
  end;
  Check(LRaised, 'Span2.SubSpan should reject overflowing ranges');
end;

procedure TestSpan2FromTwoRejectsOverflowingCount;
var
  LValue: Integer;
  LSpanA: TIntSpan;
  LSpanB: TIntSpan;
  LRaised: Boolean;
begin
  LValue := 7;
  LSpanA := TIntSpan.FromPointer(@LValue, High(SizeUInt), SizeOf(Integer));
  LSpanB := TIntSpan.FromPointer(@LValue, 1, SizeOf(Integer));

  LRaised := False;
  try
    TIntSpan2.FromTwo(LSpanA, LSpanB);
  except
    on E: EOutOfRange do
      LRaised := True;
  end;
  Check(LRaised, 'Span2.FromTwo should reject overflowing aggregate count');
end;

procedure TestSpanFromPointerValidatesPositiveCountInvariants;
var
  LValues: array[0..1] of Integer;
  LSpan: TIntSpan;
  LRaised: Boolean;
begin
  LValues[0] := 11;
  LValues[1] := 22;

  LSpan := TIntSpan.FromPointer(nil, 0, 0);
  CheckEqual(Int64(0), Int64(LSpan.Count), 'empty nil span count');
  Check(LSpan.IsEmpty, 'empty nil span should be allowed');

  LSpan := TIntSpan.FromPointer(@LValues[0], 0, 0);
  CheckEqual(Int64(0), Int64(LSpan.Count), 'empty non-nil span count');
  Check(LSpan.IsEmpty, 'empty non-nil span should be allowed');

  LRaised := False;
  try
    LSpan := TIntSpan.FromPointer(nil, 1, SizeOf(Integer));
  except
    on E: EArgumentNil do
      LRaised := True;
  end;
  Check(LRaised, 'Span.FromPointer should reject nil pointer for positive count');

  LRaised := False;
  try
    LSpan := TIntSpan.FromPointer(@LValues[0], 1, 0);
  except
    on E: EInvalidArgument do
      LRaised := True;
  end;
  Check(LRaised, 'Span.FromPointer should reject zero element size for positive count');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.contracts');
  T.Run('element manager unmanaged copy fill zero and overlap', @TestElementManagerUnmanagedCopyFillZeroAndOverlap);
  T.Run('element manager managed realloc and overlap copy', @TestElementManagerManagedReallocAndOverlapCopy);
  T.Run('element manager managed CopyArray path owns refs', @TestElementManagerManagedCopyArrayPathOwnsRefs);
  T.Run('element manager managed ZeroElements reinitializes reusable slots', @TestElementManagerManagedZeroElementsReinitializesReusableSlots);
  T.Run('element manager managed record ZeroElements reinitializes before free', @TestElementManagerManagedRecordZeroElementsReinitializesBeforeFree);
  T.Run('node Clear releases managed data and links', @TestNodeClearReleasesManagedDataAndLinks);
  T.Run('growth strategies honor bounds and alignment', @TestGrowthStrategiesHonorBoundsAndAlignment);
  T.Run('custom growth strategy function and method callbacks', @TestCustomGrowthStrategyFunctionAndMethodCallbacks);
  T.Run('shuffle random generator function and method callbacks', @TestShuffleRandomGeneratorFunctionAndMethodCallbacks);
  T.Run('span subspan rejects overflowing count', @TestSpanSubSpanRejectsOverflowingCount);
  T.Run('span2 from two rejects overflowing count', @TestSpan2FromTwoRejectsOverflowingCount);
  T.Run('span from pointer validates positive count invariants', @TestSpanFromPointerValidatesPositiveCountInvariants);
  T.Summary;
end.

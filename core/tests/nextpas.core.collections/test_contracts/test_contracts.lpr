program test_contracts;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.element_manager,
  nextpas.core.collections.vec;

type
  TIntManager = specialize TElementManager<Integer>;
  TStringManager = specialize TElementManager<string>;
  TIntVec = specialize TVec<Integer>;

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

procedure TestElementManagerUnmanagedCopyFillZeroAndOverlap;
var
  LManager: TIntManager;
  LValue: Integer;
  LBuffer: array[0..5] of Integer;
begin
  LManager := TIntManager.Create(GetRtlAllocator);
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
begin
  LManager := TStringManager.Create(GetRtlAllocator);
  try
    CheckEqual(True, LManager.IsManagedType, 'string should be a managed type');
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

begin
  T := TTestRunner.Create('nextpas.core.collections.contracts');
  T.Run('element manager unmanaged copy fill zero and overlap', @TestElementManagerUnmanagedCopyFillZeroAndOverlap);
  T.Run('element manager managed realloc and overlap copy', @TestElementManagerManagedReallocAndOverlapCopy);
  T.Run('growth strategies honor bounds and alignment', @TestGrowthStrategiesHonorBoundsAndAlignment);
  T.Run('custom growth strategy function and method callbacks', @TestCustomGrowthStrategyFunctionAndMethodCallbacks);
  T.Run('shuffle random generator function and method callbacks', @TestShuffleRandomGeneratorFunctionAndMethodCallbacks);
  T.Summary;
end.

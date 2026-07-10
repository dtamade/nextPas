program test_pool_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.allocator;

type
  TExceptionProc = procedure;

  TRecordingFallback = class(TInterfacedObject, IAllocator)
  private
    FPtrs: array of Pointer;
    function IndexOf(APtr: Pointer): Integer;
    procedure Track(APtr: Pointer);
    function Untrack(APtr: Pointer): Boolean;
  public
    GetCalls: Integer;
    AllocCalls: Integer;
    ReallocCalls: Integer;
    FreeCalls: Integer;
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function Traits: TAllocatorTraits;
  end;

var
  T: TTestSuite;
  LRunPassed: Boolean;
  GAllocator: IAllocator = nil;
  GPoolAllocator: TPoolAllocator = nil;
  GFallback: TRecordingFallback = nil;
  GPtr: Pointer = nil;
  GForeignByte: Byte = 0;

function TRecordingFallback.IndexOf(APtr: Pointer): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FPtrs) do
    if FPtrs[LIndex] = APtr then
      Exit(LIndex);
  Result := -1;
end;

procedure TRecordingFallback.Track(APtr: Pointer);
var
  LCount: Integer;
begin
  if APtr = nil then
    Exit;
  LCount := Length(FPtrs);
  SetLength(FPtrs, LCount + 1);
  FPtrs[LCount] := APtr;
end;

function TRecordingFallback.Untrack(APtr: Pointer): Boolean;
var
  LIndex: Integer;
  LLast: Integer;
begin
  LIndex := IndexOf(APtr);
  Result := LIndex >= 0;
  if not Result then
    Exit;
  LLast := High(FPtrs);
  FPtrs[LIndex] := FPtrs[LLast];
  SetLength(FPtrs, LLast);
end;

function TRecordingFallback.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Inc(GetCalls);
  Result := System.GetMem(ASize);
  Track(Result);
end;

function TRecordingFallback.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then Exit(nil);
  Inc(AllocCalls);
  Result := System.AllocMem(ASize);
  Track(Result);
end;

function TRecordingFallback.ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
var
  LIndex: Integer;
begin
  if ASize = 0 then begin FreeMem(ADst); Exit(nil); end;
  if ADst = nil then Exit(GetMem(ASize));
  Inc(ReallocCalls);
  LIndex := IndexOf(ADst);
  if LIndex < 0 then
    Exit(nil);
  Result := System.ReallocMem(ADst, ASize);
  FPtrs[LIndex] := Result;
end;

procedure TRecordingFallback.FreeMem(ADst: Pointer);
begin
  if ADst = nil then Exit;
  Inc(FreeCalls);
  if Untrack(ADst) then
    System.FreeMem(ADst);
end;

function TRecordingFallback.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.SupportsRealloc := True;
end;

procedure CheckRaisesAllocError(AProc: TExceptionProc; AExpected: TAllocError; const AName: string);
begin
  try
    AProc;
    Fail(AName + ': expected allocation error');
  except
    on E: EAllocError do
      Check(Int64(Ord(AExpected)) = Int64(Ord(E.Error)), AName + ': error code');
  end;
end;

procedure FreeForeignPointer;
begin
  GAllocator.FreeMem(@GForeignByte);
end;

procedure ReallocForeignPointer;
begin
  GAllocator.ReallocMem(@GForeignByte, 128);
end;

procedure ReallocInteriorPoolPointer;
var
  LNewPtr: Pointer;
begin
  LNewPtr := GAllocator.ReallocMem(PByte(GPtr) + 1, 48);
  if LNewPtr <> nil then
    GAllocator.FreeMem(LNewPtr);
end;

procedure FreeFallbackPointerAgain;
begin
  GAllocator.FreeMem(GPtr);
end;

procedure FreeReleasedPoolPointerAgain;
begin
  GAllocator.FreeMem(GPtr);
end;

procedure TestZeroSizeAndTraits;
var
  LBaselineAvailable: Integer;
begin
  GFallback := TRecordingFallback.Create;
  GPoolAllocator := TPoolAllocator.Create(32, 1, GFallback);
  GAllocator := GPoolAllocator as IAllocator;
  try
    LBaselineAvailable := GPoolAllocator.Available;
    Check(GAllocator.GetMem(0) = nil, 'GetMem(0) should return nil');
    Check(GAllocator.AllocMem(0) = nil, 'AllocMem(0) should return nil');
    Check(GAllocator.ReallocMem(nil, 0) = nil, 'ReallocMem(nil, 0) should return nil');
    Check(Int64(LBaselineAvailable) = Int64(GPoolAllocator.Available), 'zero-size operations must not consume pool capacity');
  finally
    GAllocator := nil;
    GPoolAllocator := nil;
    GFallback := nil;
  end;
end;

procedure TestReallocZeroFreesPoolPointer;
var
  LResult: Pointer;
begin
  GFallback := TRecordingFallback.Create;
  GPoolAllocator := TPoolAllocator.Create(32, 1, GFallback);
  GAllocator := GPoolAllocator as IAllocator;
  try
    GPtr := GAllocator.GetMem(16);
    Check(GPtr <> nil, 'pool allocation should succeed');
    Check(Int64(1) = Int64(GPoolAllocator.AllocatedCount), 'one pool block should be live');

    LResult := GAllocator.ReallocMem(GPtr, 0);
    Check(LResult = nil, 'ReallocMem(pool ptr, 0) should return nil');
    Check(Int64(0) = Int64(GPoolAllocator.AllocatedCount), 'ReallocMem(pool ptr, 0) should release the pool block');
    CheckRaisesAllocError(@FreeReleasedPoolPointerAgain, aeInvalidPointer, 'pool pointer after ReallocMem zero');
    GPtr := nil;
  finally
    if GPtr <> nil then
      GAllocator.FreeMem(GPtr);
    GAllocator := nil;
    GPoolAllocator := nil;
    GFallback := nil;
  end;
end;

procedure TestForeignPointersFailClosed;
begin
  GFallback := TRecordingFallback.Create;
  GAllocator := TPoolAllocator.Create(32, 1, GFallback);
  try
    CheckRaisesAllocError(@FreeForeignPointer, aeInvalidPointer, 'foreign FreeMem');
    CheckRaisesAllocError(@ReallocForeignPointer, aeInvalidPointer, 'foreign ReallocMem');
    Check(Int64(0) = Int64(GFallback.FreeCalls), 'foreign pointer must not be forwarded to fallback FreeMem');
    Check(Int64(0) = Int64(GFallback.ReallocCalls), 'foreign pointer must not be forwarded to fallback ReallocMem');
  finally
    GAllocator := nil;
    GFallback := nil;
  end;
end;

procedure TestInteriorPoolReallocFailsWithoutLeaking;
begin
  GFallback := TRecordingFallback.Create;
  GPoolAllocator := TPoolAllocator.Create(32, 2, GFallback);
  GAllocator := GPoolAllocator as IAllocator;
  try
    GPtr := GAllocator.GetMem(16);
    Check(GPtr <> nil, 'pool allocation should succeed');
    Check(Int64(1) = Int64(GPoolAllocator.AllocatedCount), 'one pool block should be live');

    CheckRaisesAllocError(@ReallocInteriorPoolPointer, aeInvalidPointer, 'interior ReallocMem');
    Check(Int64(1) = Int64(GPoolAllocator.AllocatedCount), 'interior ReallocMem must not leak a new pool block');
    Check(Int64(1) = Int64(GFallback.GetCalls), 'interior ReallocMem must not allocate fallback memory');

    GAllocator.FreeMem(GPtr);
    GPtr := nil;
  finally
    if GPtr <> nil then
      GAllocator.FreeMem(GPtr);
    GAllocator := nil;
    GPoolAllocator := nil;
    GFallback := nil;
  end;
end;

procedure TestFallbackAllocationsAreTracked;
var
  LPoolPtr: Pointer;
  LBaselineGetCalls: Integer;
  LBaselineFreeCalls: Integer;
begin
  GFallback := TRecordingFallback.Create;
  GPoolAllocator := TPoolAllocator.Create(32, 1, GFallback);
  GAllocator := GPoolAllocator as IAllocator;
  try
    LBaselineGetCalls := GFallback.GetCalls;
    LBaselineFreeCalls := GFallback.FreeCalls;

    LPoolPtr := GAllocator.GetMem(16);
    try
      Check(Int64(16) = Int64(GPoolAllocator.GetMemSize(LPoolPtr)), 'pool pointer requested size');

      GPtr := GAllocator.GetMem(16);
      Check(GPtr <> nil, 'pool exhaustion should allocate via fallback');
      Check(Int64(LBaselineGetCalls + 1) = Int64(GFallback.GetCalls), 'fallback should allocate exhausted request once');
      Check(Int64(16) = Int64(GPoolAllocator.GetMemSize(GPtr)), 'fallback pointer requested size');

      GAllocator.FreeMem(GPtr);
      Check(Int64(0) = Int64(GPoolAllocator.GetMemSize(GPtr)), 'freed fallback pointer size is unknown');
      Check(Int64(LBaselineFreeCalls + 1) = Int64(GFallback.FreeCalls), 'tracked fallback pointer should free once');
      CheckRaisesAllocError(@FreeFallbackPointerAgain, aeInvalidPointer, 'fallback double FreeMem');
      Check(Int64(LBaselineFreeCalls + 1) = Int64(GFallback.FreeCalls), 'fallback double free must not be forwarded');
      GPtr := nil;
    finally
      if GPtr <> nil then
        GAllocator.FreeMem(GPtr);
      GAllocator.FreeMem(LPoolPtr);
    end;
  finally
    GAllocator := nil;
    GPoolAllocator := nil;
    GFallback := nil;
  end;
end;

procedure TestStressManyAllocsAndFrees;
const
  COUNT = 50;
var
  LAllocator: IAllocator;
  LFallback: TRecordingFallback;
  LPtrs: array[0..COUNT - 1] of Pointer;
  LLiveCount: Integer;
  I: Integer;
begin
  LFallback := TRecordingFallback.Create;
  LAllocator := TPoolAllocator.Create(64, COUNT, LFallback) as IAllocator;
  { LFallback is now owned by the pool — do not free it separately. }

  { Allocate all pointers — all fit in pool (sizes <= block size). }
  for I := 0 to COUNT - 1 do
  begin
    LPtrs[I] := LAllocator.GetMem(32);
    Check(LPtrs[I] <> nil, 'stress: alloc should succeed');
    PByte(LPtrs[I])^ := Byte(I and $FF);
  end;

  { Free every other pointer. }
  for I := 0 to COUNT - 1 do
  begin
    if I mod 2 = 0 then
    begin
      LAllocator.FreeMem(LPtrs[I]);
      LPtrs[I] := nil;
    end;
  end;

  { Re-allocate freed slots. }
  for I := 0 to COUNT - 1 do
  begin
    if LPtrs[I] = nil then
    begin
      LPtrs[I] := LAllocator.GetMem(32);
      Check(LPtrs[I] <> nil, 'stress: realloc should succeed');
      PByte(LPtrs[I])^ := Byte(I and $FF);
    end;
  end;

  { Verify data integrity. }
  LLiveCount := 0;
  for I := 0 to COUNT - 1 do
  begin
    if LPtrs[I] <> nil then
    begin
      Check(Int64(Byte(I and $FF)) = Int64(PByte(LPtrs[I])^),
        'stress: data integrity');
      Inc(LLiveCount);
    end;
  end;
  Check(LLiveCount = COUNT, 'stress: all slots should be live after realloc');

  { Final cleanup. }
  for I := 0 to COUNT - 1 do
    LAllocator.FreeMem(LPtrs[I]);

  LAllocator := nil;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.pool_allocator');
  T.Test('zero-size and traits', @TestZeroSizeAndTraits);
  T.Test('realloc zero frees pool pointer', @TestReallocZeroFreesPoolPointer);
  T.Test('foreign pointers fail closed', @TestForeignPointersFailClosed);
  T.Test('interior pool realloc fails without leaking', @TestInteriorPoolReallocFailsWithoutLeaking);
  T.Test('fallback allocations are tracked', @TestFallbackAllocationsAreTracked);
  T.Test('stress many allocs and frees', @TestStressManyAllocsAndFrees);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.

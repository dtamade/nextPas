program test_pool_allocator;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.allocator;

type
  TExceptionProc = procedure;

  TRecordingFallback = class(TAllocator)
  private
    FPtrs: array of Pointer;
    function IndexOf(aPtr: Pointer): Integer;
    procedure Track(aPtr: Pointer);
    function Untrack(aPtr: Pointer): Boolean;
  public
    GetCalls: Integer;
    AllocCalls: Integer;
    ReallocCalls: Integer;
    FreeCalls: Integer;
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  end;

var
  T: TTestRunner;
  GAllocator: IAllocator = nil;
  GPoolAllocator: TPoolAllocator = nil;
  GFallback: TRecordingFallback = nil;
  GPtr: Pointer = nil;
  GForeignByte: Byte = 0;

function TRecordingFallback.IndexOf(aPtr: Pointer): Integer;
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(FPtrs) do
    if FPtrs[LIndex] = aPtr then
      Exit(LIndex);
  Result := -1;
end;

procedure TRecordingFallback.Track(aPtr: Pointer);
var
  LCount: Integer;
begin
  if aPtr = nil then
    Exit;
  LCount := Length(FPtrs);
  SetLength(FPtrs, LCount + 1);
  FPtrs[LCount] := aPtr;
end;

function TRecordingFallback.Untrack(aPtr: Pointer): Boolean;
var
  LIndex: Integer;
  LLast: Integer;
begin
  LIndex := IndexOf(aPtr);
  Result := LIndex >= 0;
  if not Result then
    Exit;
  LLast := High(FPtrs);
  FPtrs[LIndex] := FPtrs[LLast];
  SetLength(FPtrs, LLast);
end;

function TRecordingFallback.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Inc(GetCalls);
  Result := System.GetMem(aSize);
  Track(Result);
end;

function TRecordingFallback.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Inc(AllocCalls);
  Result := System.AllocMem(aSize);
  Track(Result);
end;

function TRecordingFallback.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  LIndex: Integer;
begin
  Inc(ReallocCalls);
  if aDst = nil then
    Exit(DoGetMem(aSize));

  LIndex := IndexOf(aDst);
  if LIndex < 0 then
    Exit(nil);

  Result := System.ReallocMem(aDst, aSize);
  FPtrs[LIndex] := Result;
end;

procedure TRecordingFallback.DoFreeMem(aDst: Pointer);
begin
  Inc(FreeCalls);
  if Untrack(aDst) then
    System.FreeMem(aDst);
end;

procedure CheckRaisesAllocError(AProc: TExceptionProc; AExpected: TAllocError; const AName: string);
begin
  try
    AProc;
    Fail(AName + ': expected allocation error');
  except
    on E: EAllocError do
      CheckEqual(Int64(Ord(AExpected)), Int64(Ord(E.Error)), AName + ': error code');
  end;
end;

procedure FreeForeignPointer;
begin
  GAllocator.FreeMem(@GForeignByte);
end;

procedure FreeAlignedForeignPointer;
begin
  GAllocator.FreeAligned(@GForeignByte);
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

procedure AllocAlignedWithInvalidAlignment;
begin
  GAllocator.AllocAligned(16, 3);
end;

procedure FreeReleasedPoolPointerAgain;
begin
  GAllocator.FreeMem(GPtr);
end;

procedure TestZeroSizeAndTraits;
var
  LTraits: TAllocatorTraits;
  LBaselineAvailable: Integer;
begin
  GFallback := TRecordingFallback.Create;
  GPoolAllocator := TPoolAllocator.Create(32, 1, GFallback);
  GAllocator := GPoolAllocator as IAllocator;
  try
    LBaselineAvailable := GPoolAllocator.Available;
    Check(GAllocator.GetMem(0) = nil, 'GetMem(0) should return nil');
    Check(GAllocator.AllocMem(0) = nil, 'AllocMem(0) should return nil');
    Check(GAllocator.AllocAligned(0, 16) = nil, 'AllocAligned(0) should return nil');
    Check(GAllocator.ReallocMem(nil, 0) = nil, 'ReallocMem(nil, 0) should return nil');
    CheckEqual(Int64(LBaselineAvailable), Int64(GPoolAllocator.Available),
      'zero-size operations must not consume pool capacity');

    LTraits := GAllocator.Traits;
    CheckEqual(False, LTraits.HasMemSize, 'pool allocator should not claim complete mem-size support');
    CheckEqual(False, LTraits.SupportsAligned, 'pool allocator should not claim native generic aligned support');
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
    CheckEqual(Int64(1), Int64(GPoolAllocator.AllocatedCount), 'one pool block should be live');

    LResult := GAllocator.ReallocMem(GPtr, 0);
    Check(LResult = nil, 'ReallocMem(pool ptr, 0) should return nil');
    CheckEqual(Int64(0), Int64(GPoolAllocator.AllocatedCount), 'ReallocMem(pool ptr, 0) should release the pool block');
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

procedure TestInvalidAlignmentFailsClosed;
var
  LBaselineGetCalls: Integer;
  LBaselineAllocCalls: Integer;
begin
  GFallback := TRecordingFallback.Create;
  GAllocator := TPoolAllocator.Create(32, 1, GFallback);
  try
    LBaselineGetCalls := GFallback.GetCalls;
    LBaselineAllocCalls := GFallback.AllocCalls;

    CheckRaisesAllocError(@AllocAlignedWithInvalidAlignment, aeAlignmentNotSupported, 'invalid alignment');
    CheckEqual(Int64(LBaselineGetCalls), Int64(GFallback.GetCalls),
      'invalid alignment must not allocate fallback memory');
    CheckEqual(Int64(LBaselineAllocCalls), Int64(GFallback.AllocCalls),
      'invalid alignment must not call fallback AllocMem');
  finally
    GAllocator := nil;
    GFallback := nil;
  end;
end;

procedure TestForeignPointersFailClosed;
begin
  GFallback := TRecordingFallback.Create;
  GAllocator := TPoolAllocator.Create(32, 1, GFallback);
  try
    CheckRaisesAllocError(@FreeForeignPointer, aeInvalidPointer, 'foreign FreeMem');
    CheckRaisesAllocError(@FreeAlignedForeignPointer, aeInvalidPointer, 'foreign FreeAligned');
    CheckRaisesAllocError(@ReallocForeignPointer, aeInvalidPointer, 'foreign ReallocMem');
    CheckEqual(Int64(0), Int64(GFallback.FreeCalls), 'foreign pointer must not be forwarded to fallback FreeMem');
    CheckEqual(Int64(0), Int64(GFallback.ReallocCalls), 'foreign pointer must not be forwarded to fallback ReallocMem');
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
    CheckEqual(Int64(1), Int64(GPoolAllocator.AllocatedCount), 'one pool block should be live');

    CheckRaisesAllocError(@ReallocInteriorPoolPointer, aeInvalidPointer, 'interior ReallocMem');
    CheckEqual(Int64(1), Int64(GPoolAllocator.AllocatedCount), 'interior ReallocMem must not leak a new pool block');
    CheckEqual(Int64(1), Int64(GFallback.GetCalls), 'interior ReallocMem must not allocate fallback memory');

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
      CheckEqual(Int64(16), Int64(GPoolAllocator.GetMemSize(LPoolPtr)), 'pool pointer requested size');

      GPtr := GAllocator.GetMem(16);
      Check(GPtr <> nil, 'pool exhaustion should allocate via fallback');
      CheckEqual(Int64(LBaselineGetCalls + 1), Int64(GFallback.GetCalls),
        'fallback should allocate exhausted request once');
      CheckEqual(Int64(16), Int64(GPoolAllocator.GetMemSize(GPtr)), 'fallback pointer requested size');

      GAllocator.FreeMem(GPtr);
      CheckEqual(Int64(0), Int64(GPoolAllocator.GetMemSize(GPtr)), 'freed fallback pointer size is unknown');
      CheckEqual(Int64(LBaselineFreeCalls + 1), Int64(GFallback.FreeCalls),
        'tracked fallback pointer should free once');
      CheckRaisesAllocError(@FreeFallbackPointerAgain, aeInvalidPointer, 'fallback double FreeMem');
      CheckEqual(Int64(LBaselineFreeCalls + 1), Int64(GFallback.FreeCalls),
        'fallback double free must not be forwarded');
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

begin
  T := TTestRunner.Create('nextpas.core.mem.pool_allocator');
  T.Run('zero-size and traits', @TestZeroSizeAndTraits);
  T.Run('realloc zero frees pool pointer', @TestReallocZeroFreesPoolPointer);
  T.Run('invalid alignment fails closed', @TestInvalidAlignmentFailsClosed);
  T.Run('foreign pointers fail closed', @TestForeignPointersFailClosed);
  T.Run('interior pool realloc fails without leaking', @TestInteriorPoolReallocFailsWithoutLeaking);
  T.Run('fallback allocations are tracked', @TestFallbackAllocationsAreTracked);
  T.Summary;
end.

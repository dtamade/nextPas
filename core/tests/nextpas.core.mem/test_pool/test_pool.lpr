program test_pool;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool.object_pool;

type
  TExceptionProc = procedure;
  TBatchObject = class
  end;
  TFixedPoolRecordingAllocator = class(TInterfacedObject, IAllocator)
  public
    GetCalls: Integer;
    FreeCalls: Integer;
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    function Traits: TAllocatorTraits;
  end;

var
  T: TTestRunner;
  GPool: TLocalBlockPool;
  GPtr: Pointer = nil;
  GExternalByte: Byte = 0;

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

function TFixedPoolRecordingAllocator.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TFixedPoolRecordingAllocator.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TFixedPoolRecordingAllocator.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

function TFixedPoolRecordingAllocator.GetMem(aSize: SizeUInt): Pointer;
begin
  Inc(GetCalls);
  Result := nil;
end;

function TFixedPoolRecordingAllocator.AllocMem(aSize: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
end;

function TFixedPoolRecordingAllocator.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := nil;
end;

procedure TFixedPoolRecordingAllocator.FreeMem(aDst: Pointer);
begin
  Inc(FreeCalls);
end;

function TFixedPoolRecordingAllocator.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
begin
  Result := GetMem(aSize);
end;

procedure TFixedPoolRecordingAllocator.FreeAligned(aPtr: Pointer);
begin
  Inc(FreeCalls);
end;

function TFixedPoolRecordingAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe := False;
  Result.HasMemSize := False;
  Result.SupportsAligned := False;
end;

procedure ReleaseExternalPointer;
begin
  GPool.Release(@GExternalByte);
end;

procedure ReleaseInteriorPointer;
begin
  GPool.Release(PByte(GPtr) + 1);
end;

procedure ReleaseDoubleFreePointer;
begin
  GPool.Release(GPtr);
end;

procedure TestPoolInit;
var
  LP: TLocalBlockPool;
begin
  LP.Init(64, 10);
  CheckEqual(Int64(10), Int64(LP.BlockCount), 'block count');
  Check(LP.BlockSize >= 64, 'block size');
  CheckEqual(Int64(0), Int64(LP.AcquiredCount), 'acquired');
  CheckEqual(Int64(10), Int64(LP.AvailableCount), 'available');
  Check(not LP.IsFull);
  Check(LP.IsEmpty);
  LP.Done;
end;

procedure TestPoolAcquireRelease;
var
  LP: TLocalBlockPool;
  LPtr: Pointer;
begin
  LP.Init(32, 5);
  LPtr := LP.Acquire;
  Check(LPtr <> nil, 'acquire');
  CheckEqual(Int64(1), Int64(LP.AcquiredCount));
  CheckEqual(Int64(4), Int64(LP.AvailableCount));

  LP.Release(LPtr);
  CheckEqual(Int64(0), Int64(LP.AcquiredCount));
  CheckEqual(Int64(5), Int64(LP.AvailableCount));
  LP.Done;
end;

procedure TestPoolExhaust;
var
  LP: TLocalBlockPool;
  LPtrs: array[0..2] of Pointer;
  LI: Integer;
begin
  LP.Init(16, 3);
  for LI := 0 to 2 do
    LPtrs[LI] := LP.Acquire;

  Check(LP.IsFull, 'should be full');
  Check(LP.Acquire = nil, 'should return nil when full');

  LP.Release(LPtrs[1]);
  Check(not LP.IsFull, 'not full after release');
  Check(LP.Acquire <> nil, 'can acquire after release');
  LP.Done;
end;

procedure TestPoolReset;
var
  LP: TLocalBlockPool;
  LI: Integer;
begin
  LP.Init(32, 10);
  for LI := 0 to 9 do
    LP.Acquire;
  Check(LP.IsFull);

  LP.Reset;
  Check(LP.IsEmpty, 'reset makes empty');
  CheckEqual(Int64(10), Int64(LP.AvailableCount));

  for LI := 0 to 9 do
    Check(LP.Acquire <> nil, 'can acquire after reset');
  LP.Done;
end;

procedure TestPoolOwns;
var
  LP: TLocalBlockPool;
  LPtr: Pointer;
  LExternal: Integer;
begin
  LP.Init(64, 5);
  LPtr := LP.Acquire;
  Check(LP.Owns(LPtr), 'should own acquired pointer');
  Check(not LP.Owns(@LExternal), 'should not own external pointer');
  LP.Release(LPtr);
  LP.Done;
end;

procedure TestPoolRejectsInvalidReleasePointers;
begin
  GPool.Init(32, 2);
  try
    GPtr := GPool.Acquire;
    Check(GPtr <> nil, 'acquire for invalid release');
    CheckRaisesAllocError(@ReleaseExternalPointer, aeInvalidPointer, 'external pointer');
    CheckRaisesAllocError(@ReleaseInteriorPointer, aeInvalidPointer, 'interior pointer');
    CheckEqual(Int64(1), Int64(GPool.AcquiredCount), 'invalid releases do not mutate acquired count');
    GPool.Release(GPtr);
  finally
    GPool.Done;
    GPtr := nil;
  end;
end;

procedure TestPoolRejectsDoubleFree;
begin
  GPool.Init(32, 1);
  try
    GPtr := GPool.Acquire;
    Check(GPtr <> nil, 'acquire for double free');
    GPool.Release(GPtr);
    CheckRaisesAllocError(@ReleaseDoubleFreePointer, aeDoubleFree, 'double free');
    CheckEqual(Int64(0), Int64(GPool.AcquiredCount), 'double free does not underflow acquired count');
    CheckEqual(Int64(1), Int64(GPool.AvailableCount), 'double free does not duplicate free stack entries');
  finally
    GPool.Done;
    GPtr := nil;
  end;
end;

procedure TestPoolWriteRead;
var
  LP: TLocalBlockPool;
  LPtr: PInteger;
begin
  LP.Init(SizeOf(Integer), 10);
  LPtr := PInteger(LP.Acquire);
  Check(LPtr <> nil);
  LPtr^ := 99999;
  Check(LPtr^ = 99999, 'write/read through pool block');
  LP.Release(LPtr);
  LP.Done;
end;

procedure TestPoolMultipleBlocks;
var
  LP: TLocalBlockPool;
  LPtrs: array[0..99] of Pointer;
  LI: Integer;
begin
  LP.Init(128, 100);
  for LI := 0 to 99 do
  begin
    LPtrs[LI] := LP.Acquire;
    Check(LPtrs[LI] <> nil, 'acquire ' + IntToStr(LI));
  end;
  Check(LP.IsFull);

  for LI := 0 to 99 do
    LP.Release(LPtrs[LI]);
  Check(LP.IsEmpty);
  LP.Done;
end;

procedure TestPoolDone;
var
  LP: TLocalBlockPool;
begin
  LP.Init(64, 10);
  LP.Acquire;
  LP.Acquire;
  LP.Done;
  CheckEqual(Int64(0), Int64(LP.AcquiredCount), 'done clears');
  CheckEqual(Int64(0), Int64(LP.BlockCount));
end;

procedure TestPoolSmallBlockSize;
var
  LP: TLocalBlockPool;
  LPtr: Pointer;
begin
  LP.Init(1, 5);
  Check(LP.BlockSize >= SizeOf(Pointer), 'block size at least pointer size');
  LPtr := LP.Acquire;
  Check(LPtr <> nil);
  LP.Release(LPtr);
  LP.Done;
end;

procedure TestPoolLegacyAlias;
var
  LP: TPool;
  LPtr: Pointer;
begin
  LP.Init(16, 1);
  try
    LPtr := LP.Acquire;
    Check(LPtr <> nil, 'legacy TPool alias remains usable');
    LP.Release(LPtr);
  finally
    LP.Done;
  end;
end;

procedure TestFixedPoolBatchClampsToOpenArrayLength;
var
  LPool: TFixedPool;
  LPtrs: array[0..0] of Pointer;
  LAcquired: Integer;
begin
  LPool := TFixedPool.Create(32, 2);
  try
    LPtrs[0] := nil;
    LAcquired := LPool.AcquireN(LPtrs, 2);
    CheckEqual(Int64(1), Int64(LAcquired), 'AcquireN should clamp to open-array length');
    CheckEqual(Int64(1), Int64(LPool.AllocatedCount), 'AcquireN should acquire only one block');

    LPool.ReleaseN(LPtrs, 2);
    CheckEqual(Int64(0), Int64(LPool.AllocatedCount), 'ReleaseN should release only the provided slot');
    CheckEqual(Int64(2), Int64(LPool.Available), 'ReleaseN should restore one acquired block');
  finally
    LPool.Free;
  end;
end;

procedure TestFixedPoolRejectsTotalSizeOverflowBeforeAlloc;
var
  LPool: TFixedPool;
  LAllocator: TFixedPoolRecordingAllocator;
  LAllocatorRef: IAllocator;
  LBlockSize: SizeUInt;
  LRaised: Boolean;
begin
  LAllocator := TFixedPoolRecordingAllocator.Create;
  LAllocatorRef := LAllocator;
  LBlockSize := High(SizeUInt) - (High(SizeUInt) mod 16);
  LRaised := False;
  LPool := nil;
  try
    try
      LPool := TFixedPool.Create(LBlockSize, 2, 16, LAllocatorRef);
    except
      on E: EAllocError do
      begin
        LRaised := True;
        CheckEqual(Int64(Ord(aeInvalidLayout)), Int64(Ord(E.Error)),
          'fixed pool total-size overflow error');
      end;
      on E: nextpas.core.mem.error.EOutOfMemory do
      begin
        LRaised := True;
        CheckEqual(Int64(Ord(aeInvalidLayout)), Int64(Ord(E.Error)),
          'fixed pool total-size overflow error');
      end;
    end;
    Check(LRaised, 'fixed pool total-size overflow must fail closed');
    CheckEqual(Int64(0), Int64(LAllocator.GetCalls),
      'fixed pool total-size overflow must not call backing allocator');
  finally
    LPool.Free;
    LAllocatorRef := nil;
  end;
end;

procedure TestObjectPoolBatchClampsToOpenArrayLength;
type
  TBatchPool = specialize TObjectPool<TBatchObject>;
var
  LPool: TBatchPool;
  LPtrs: array[0..0] of Pointer;
  LAcquired: Integer;
begin
  LPool := TBatchPool.Create(10, function: TBatchObject
    begin
      Result := TBatchObject.Create;
    end);
  try
    LPtrs[0] := nil;
    LAcquired := LPool.AcquireN(LPtrs, 2);
    CheckEqual(Int64(1), Int64(LAcquired), 'object AcquireN should clamp to open-array length');
    CheckEqual(Int64(1), Int64(LPool.TotalCreated), 'object AcquireN should create only one object');

    LPool.ReleaseN(LPtrs, 2);
    CheckEqual(Int64(1), Int64(LPool.InPoolCount), 'object ReleaseN should release only the provided slot');
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.pool');
  T.Run('Init', @TestPoolInit);
  T.Run('Acquire/Release', @TestPoolAcquireRelease);
  T.Run('Exhaust', @TestPoolExhaust);
  T.Run('Reset', @TestPoolReset);
  T.Run('Owns', @TestPoolOwns);
  T.Run('rejects invalid release pointers', @TestPoolRejectsInvalidReleasePointers);
  T.Run('rejects double free', @TestPoolRejectsDoubleFree);
  T.Run('Write/Read', @TestPoolWriteRead);
  T.Run('Multiple blocks (100)', @TestPoolMultipleBlocks);
  T.Run('Done', @TestPoolDone);
  T.Run('Small block size', @TestPoolSmallBlockSize);
  T.Run('legacy TPool alias', @TestPoolLegacyAlias);
  T.Run('fixed pool batch clamps to open-array length', @TestFixedPoolBatchClampsToOpenArrayLength);
  T.Run('fixed pool rejects total-size overflow before alloc', @TestFixedPoolRejectsTotalSizeOverflowBeforeAlloc);
  T.Run('object pool batch clamps to open-array length', @TestObjectPoolBatchClampsToOpenArrayLength);
  T.Summary;
end.

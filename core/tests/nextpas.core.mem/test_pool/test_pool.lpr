program test_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
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
    function GetMem(ASize: SizeUInt): Pointer;
    function AllocMem(ASize: SizeUInt): Pointer;
    function ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
    procedure FreeMem(ADst: Pointer);
    function MemSize(APtr: Pointer): SizeUInt;
    function AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
    procedure FreeAligned(APtr: Pointer);
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

function TFixedPoolRecordingAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  Inc(GetCalls);
  Result := nil;
end;

function TFixedPoolRecordingAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TFixedPoolRecordingAllocator.ReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := nil;
end;

procedure TFixedPoolRecordingAllocator.FreeMem(ADst: Pointer);
begin
  Inc(FreeCalls);
end;

function TFixedPoolRecordingAllocator.MemSize(APtr: Pointer): SizeUInt;
begin
  Result := 0;
end;

function TFixedPoolRecordingAllocator.AllocAligned(ASize, AAlignment: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

procedure TFixedPoolRecordingAllocator.FreeAligned(APtr: Pointer);
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

procedure TestPoolCreate;
var
  LP: TLocalBlockPool;
begin
  LP := TLocalBlockPool.Create(64, 10);
  try
    CheckEqual(Int64(10), Int64(LP.Capacity), 'capacity');
    Check(LP.BlockSize >= 64, 'block size');
    CheckEqual(Int64(0), Int64(LP.InUse), 'in use');
    CheckEqual(Int64(10), Int64(LP.Available), 'available');
    Check(not LP.IsFull);
    Check(LP.IsEmpty);
  finally
    LP.Free;
  end;
end;

procedure TestPoolAcquireRelease;
var
  LP: TLocalBlockPool;
  LPtr: Pointer;
begin
  LP := TLocalBlockPool.Create(32, 5);
  try
    LPtr := LP.Acquire;
    Check(LPtr <> nil, 'acquire');
    CheckEqual(Int64(1), Int64(LP.InUse));
    CheckEqual(Int64(4), Int64(LP.Available));

    LP.Release(LPtr);
    CheckEqual(Int64(0), Int64(LP.InUse));
    CheckEqual(Int64(5), Int64(LP.Available));
  finally
    LP.Free;
  end;
end;

procedure TestPoolExhaust;
var
  LP: TLocalBlockPool;
  LPtrs: array[0..2] of Pointer;
  LI: Integer;
begin
  LP := TLocalBlockPool.Create(16, 3);
  try
    for LI := 0 to 2 do
      LPtrs[LI] := LP.Acquire;

    Check(LP.IsFull, 'should be full');
    Check(LP.Acquire = nil, 'should return nil when full');

    LP.Release(LPtrs[1]);
    Check(not LP.IsFull, 'not full after release');
    Check(LP.Acquire <> nil, 'can acquire after release');
  finally
    LP.Free;
  end;
end;

procedure TestPoolReset;
var
  LP: TLocalBlockPool;
  LI: Integer;
begin
  LP := TLocalBlockPool.Create(32, 10);
  try
    for LI := 0 to 9 do
      LP.Acquire;
    Check(LP.IsFull);

    LP.Reset;
    Check(LP.IsEmpty, 'reset makes empty');
    CheckEqual(Int64(10), Int64(LP.Available));

    for LI := 0 to 9 do
      Check(LP.Acquire <> nil, 'can acquire after reset');
  finally
    LP.Free;
  end;
end;

procedure TestPoolOwns;
var
  LP: TLocalBlockPool;
  LPtr: Pointer;
  LExternal: Integer;
begin
  LP := TLocalBlockPool.Create(64, 5);
  try
    LPtr := LP.Acquire;
    Check(LP.Owns(LPtr), 'should own acquired pointer');
    Check(not LP.Owns(@LExternal), 'should not own external pointer');
    LP.Release(LPtr);
  finally
    LP.Free;
  end;
end;

procedure TestPoolRejectsInvalidReleasePointers;
begin
  GPool := TLocalBlockPool.Create(32, 2);
  try
    GPtr := GPool.Acquire;
    Check(GPtr <> nil, 'acquire for invalid release');
    CheckRaisesAllocError(@ReleaseExternalPointer, aeInvalidPointer, 'external pointer');
    CheckRaisesAllocError(@ReleaseInteriorPointer, aeInvalidPointer, 'interior pointer');
    CheckEqual(Int64(1), Int64(GPool.InUse), 'invalid releases do not mutate in-use count');
    GPool.Release(GPtr);
  finally
    GPool.Free;
    GPool := nil;
    GPtr := nil;
  end;
end;

procedure TestPoolRejectsDoubleFree;
begin
  GPool := TLocalBlockPool.Create(32, 1);
  try
    GPtr := GPool.Acquire;
    Check(GPtr <> nil, 'acquire for double free');
    GPool.Release(GPtr);
    CheckRaisesAllocError(@ReleaseDoubleFreePointer, aeDoubleFree, 'double free');
    CheckEqual(Int64(0), Int64(GPool.InUse), 'double free does not underflow in-use count');
    CheckEqual(Int64(1), Int64(GPool.Available), 'double free does not duplicate free stack entries');
  finally
    GPool.Free;
    GPool := nil;
    GPtr := nil;
  end;
end;

procedure TestPoolWriteRead;
var
  LP: TLocalBlockPool;
  LPtr: PInteger;
begin
  LP := TLocalBlockPool.Create(SizeOf(Integer), 10);
  try
    LPtr := PInteger(LP.Acquire);
    Check(LPtr <> nil);
    LPtr^ := 99999;
    Check(LPtr^ = 99999, 'write/read through pool block');
    LP.Release(LPtr);
  finally
    LP.Free;
  end;
end;

procedure TestPoolMultipleBlocks;
var
  LP: TLocalBlockPool;
  LPtrs: array[0..99] of Pointer;
  LI: Integer;
begin
  LP := TLocalBlockPool.Create(128, 100);
  try
    for LI := 0 to 99 do
    begin
      LPtrs[LI] := LP.Acquire;
      Check(LPtrs[LI] <> nil, 'acquire ' + IntToStr(LI));
    end;
    Check(LP.IsFull);

    for LI := 0 to 99 do
      LP.Release(LPtrs[LI]);
    Check(LP.IsEmpty);
  finally
    LP.Free;
  end;
end;

procedure TestPoolTryAcquire;
var
  LP: TLocalBlockPool;
  LPtr: Pointer;
begin
  LP := TLocalBlockPool.Create(32, 2);
  try
    Check(LP.TryAcquire(LPtr), 'first try acquire');
    Check(LPtr <> nil);
    Check(LP.TryAcquire(LPtr), 'second try acquire');
    Check(not LP.TryAcquire(LPtr), 'third try acquire should fail when full');
    Check(LPtr = nil, 'failed try acquire returns nil');
  finally
    LP.Free;
  end;
end;

procedure TestPoolSmallBlockSize;
var
  LP: TLocalBlockPool;
  LPtr: Pointer;
begin
  LP := TLocalBlockPool.Create(1, 5);
  try
    Check(LP.BlockSize >= SizeOf(Pointer), 'block size at least pointer size');
    LPtr := LP.Acquire;
    Check(LPtr <> nil);
    LP.Release(LPtr);
  finally
    LP.Free;
  end;
end;

procedure TestPoolLegacyAlias;
var
  LP: TPool;
  LPtr: Pointer;
begin
  LP := TPool.Create(16, 1);
  try
    LPtr := LP.Acquire;
    Check(LPtr <> nil, 'legacy TPool alias remains usable');
    LP.Release(LPtr);
  finally
    LP.Free;
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
  T.Run('Create', @TestPoolCreate);
  T.Run('Acquire/Release', @TestPoolAcquireRelease);
  T.Run('Exhaust', @TestPoolExhaust);
  T.Run('Reset', @TestPoolReset);
  T.Run('Owns', @TestPoolOwns);
  T.Run('TryAcquire', @TestPoolTryAcquire);
  T.Run('rejects invalid release pointers', @TestPoolRejectsInvalidReleasePointers);
  T.Run('rejects double free', @TestPoolRejectsDoubleFree);
  T.Run('Write/Read', @TestPoolWriteRead);
  T.Run('Multiple blocks (100)', @TestPoolMultipleBlocks);
  T.Run('Small block size', @TestPoolSmallBlockSize);
  T.Run('legacy TPool alias', @TestPoolLegacyAlias);
  T.Run('fixed pool batch clamps to open-array length', @TestFixedPoolBatchClampsToOpenArrayLength);
  T.Run('fixed pool rejects total-size overflow before alloc', @TestFixedPoolRejectsTotalSizeOverflowBeforeAlloc);
  T.Run('object pool batch clamps to open-array length', @TestObjectPoolBatchClampsToOpenArrayLength);
  T.Summary;
end.

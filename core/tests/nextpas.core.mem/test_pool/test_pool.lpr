program test_pool;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.pool;

type
  TExceptionProc = procedure;

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
  T.Summary;
end.

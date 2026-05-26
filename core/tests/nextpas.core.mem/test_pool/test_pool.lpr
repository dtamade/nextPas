program test_pool;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.pool;

var
  T: TTestRunner;

procedure TestPoolInit;
var
  LP: TPool;
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
  LP: TPool;
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
  LP: TPool;
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
  LP: TPool;
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
  LP: TPool;
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

procedure TestPoolWriteRead;
var
  LP: TPool;
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
  LP: TPool;
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
  LP: TPool;
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
  LP: TPool;
  LPtr: Pointer;
begin
  LP.Init(1, 5);
  Check(LP.BlockSize >= SizeOf(Pointer), 'block size at least pointer size');
  LPtr := LP.Acquire;
  Check(LPtr <> nil);
  LP.Release(LPtr);
  LP.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.pool');
  T.Run('Init', @TestPoolInit);
  T.Run('Acquire/Release', @TestPoolAcquireRelease);
  T.Run('Exhaust', @TestPoolExhaust);
  T.Run('Reset', @TestPoolReset);
  T.Run('Owns', @TestPoolOwns);
  T.Run('Write/Read', @TestPoolWriteRead);
  T.Run('Multiple blocks (100)', @TestPoolMultipleBlocks);
  T.Run('Done', @TestPoolDone);
  T.Run('Small block size', @TestPoolSmallBlockSize);
  T.Summary;
end.

program test_uring_audit;

{$I nextpas.core.settings.inc}

uses
  SysUtils, BaseUnix,
  nextpas.core.testing,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern,
  nextpas.core.io.uring,
  nextpas.core.io.reactor;

var
  T: TTestRunner;
  GCallbackCount: Int32;
  GLastResult: Int32;

procedure OnComplete(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  Inc(GCallbackCount);
  GLastResult := AResult;
end;

{ === Ring Lifecycle Tests === }

procedure TestCreateCloseMultiple;
var
  LRing: TIoUring;
  LI: Int32;
begin
  for LI := 1 to 10 do
  begin
    LRing := TIoUring.Create(8);
    Check(LRing.IsValid, 'create ' + IntToStr(LI));
    LRing.Close;
    Check(not LRing.IsValid, 'close ' + IntToStr(LI));
  end;
end;

procedure TestDoubleClose;
var
  LRing: TIoUring;
begin
  LRing := TIoUring.Create(8);
  LRing.Close;
  LRing.Close; // should not crash
  Check(True, 'double close safe');
end;

procedure TestSubmitEmpty;
var
  LRing: TIoUring;
  LRet: Int32;
begin
  LRing := TIoUring.Create(8);
  LRet := LRing.Submit; // nothing to submit
  Check(LRet = 0, 'submit empty returns 0');
  LRing.Close;
end;

{ === Pool Recycling Stress === }

procedure TestPoolRecycling50;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LI: Int32;
begin
  LRing := TIoUring.Create(16);
  Check(LRing.IsValid, 'valid');
  for LI := 1 to 50 do
  begin
    LSqe := LRing.GetSqe;
    if LSqe = nil then
    begin
      Check(False, 'nil sqe at ' + IntToStr(LI));
      Break;
    end;
    IoUringPrepNop(LSqe);
    LRing.SubmitAndWait(1);
    if not LRing.PeekCqe(LCqe) then
    begin
      Check(False, 'no cqe at ' + IntToStr(LI));
      Break;
    end;
    LRing.CqeSeen(LCqe);
  end;
  Check(True, '50 sequential NOPs ok');
  LRing.Close;
end;

{ === Read/Write Boundary Tests === }

procedure TestReadWriteZeroBytes;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LFd: Int32;
  LBuf: Byte;
begin
  LRing := TIoUring.Create(8);
  LFd := memfd_create('zero', MFD_CLOEXEC);
  // Write 0 bytes
  LSqe := LRing.GetSqe;
  IoUringPrepWrite(LSqe, LFd, @LBuf, 0, 0);
  LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe);
  Check(LCqe^.res >= 0, 'write 0 bytes ok');
  LRing.CqeSeen(LCqe);
  // Read 0 bytes
  LSqe := LRing.GetSqe;
  IoUringPrepRead(LSqe, LFd, @LBuf, 0, 0);
  LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe);
  Check(LCqe^.res >= 0, 'read 0 bytes ok');
  LRing.CqeSeen(LCqe);
  FpClose(LFd);
  LRing.Close;
end;

procedure TestReadWriteLargeBlock;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LFd: Int32;
  LBuf: array of Byte;
  LI: Int32;
begin
  LRing := TIoUring.Create(8);
  LFd := memfd_create('large', MFD_CLOEXEC);
  SetLength(LBuf, 65536);
  for LI := 0 to 65535 do LBuf[LI] := Byte(LI mod 251);
  // Write 64KB
  LSqe := LRing.GetSqe;
  IoUringPrepWrite(LSqe, LFd, @LBuf[0], 65536, 0);
  LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe);
  CheckEqual(Int64(65536), Int64(LCqe^.res), 'wrote 64KB');
  LRing.CqeSeen(LCqe);
  // Read back
  FillChar(LBuf[0], 65536, 0);
  LSqe := LRing.GetSqe;
  IoUringPrepRead(LSqe, LFd, @LBuf[0], 65536, 0);
  LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe);
  CheckEqual(Int64(65536), Int64(LCqe^.res), 'read 64KB');
  LRing.CqeSeen(LCqe);
  Check((LBuf[0] = 0) and (LBuf[65535] = Byte(65535 mod 251)), '64KB content');
  FpClose(LFd);
  LRing.Close;
end;

procedure TestReadBadFd;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LBuf: array[0..7] of Byte;
begin
  LRing := TIoUring.Create(8);
  LSqe := LRing.GetSqe;
  IoUringPrepRead(LSqe, -1, @LBuf[0], 8, 0); // invalid fd
  LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe);
  Check(LCqe^.res < 0, 'bad fd returns error');
  LRing.CqeSeen(LCqe);
  LRing.Close;
end;

{ === Reactor Stress Tests === }

procedure TestReactorStress100;
var
  LR: TIoReactor;
  LI: Int32;
begin
  GCallbackCount := 0;
  LR := TIoReactor.Create(32);
  for LI := 1 to 100 do
  begin
    Check(LR.AsyncNop(@OnComplete, nil), 'nop ' + IntToStr(LI));
    LR.Flush;
    while not LR.PollOne do ;
  end;
  CheckEqual(Int64(100), Int64(GCallbackCount), '100 reactor callbacks');
  LR.Close;
end;

procedure TestReactorBatchSubmit;
var
  LR: TIoReactor;
  LI: Int32;
begin
  GCallbackCount := 0;
  LR := TIoReactor.Create(64);
  // Submit 32 at once
  for LI := 1 to 32 do
    Check(LR.AsyncNop(@OnComplete, nil), 'batch ' + IntToStr(LI));
  LR.Flush;
  // Drain all
  while GCallbackCount < 32 do
    LR.PollOne;
  CheckEqual(Int64(32), Int64(GCallbackCount), '32 batch callbacks');
  LR.Close;
end;

procedure TestReactorFreeListReuse;
var
  LR: TIoReactor;
  LI: Int32;
begin
  GCallbackCount := 0;
  LR := TIoReactor.Create(16);
  // Do 200 operations — free-list must recycle slots
  for LI := 1 to 200 do
  begin
    LR.AsyncNop(@OnComplete, nil);
    LR.Flush;
    while not LR.PollOne do ;
  end;
  CheckEqual(Int64(200), Int64(GCallbackCount), '200 with recycling');
  LR.Close;
end;

procedure TestReactorContextPreserved;
var
  LR: TIoReactor;
  LCtx: Int32;
begin
  LCtx := 0;
  LR := TIoReactor.Create(8);
  LR.AsyncNop(procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer)
  begin
    PInt32(AContext)^ := 99;
  end, @LCtx);
  LR.Flush;
  while LCtx = 0 do LR.PollOne;
  CheckEqual(Int64(99), Int64(LCtx), 'context preserved through free-list');
  LR.Close;
end;

{ === Error Handling === }

procedure TestReactorClosedNoLeak;
var
  LR: TIoReactor;
begin
  LR := TIoReactor.Create(8);
  LR.AsyncNop(@OnComplete, nil);
  // Close without flushing — should not leak
  LR.Close;
  Check(True, 'close without flush no crash');
end;

procedure TestRingInvalidSize;
var
  LRing: TIoUring;
begin
  // Size 0 — kernel should reject
  LRing := TIoUring.Create(0);
  Check(not LRing.IsValid, 'size 0 invalid');
end;

{ === User Data Boundary === }

procedure TestUserDataMaxValue;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
begin
  LRing := TIoUring.Create(8);
  LSqe := LRing.GetSqe;
  IoUringPrepNop(LSqe);
  IoUringSqeSetData(LSqe, $FFFFFFFFFFFFFFFF); // max UInt64
  LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe);
  CheckEqual(Int64(-1), Int64(IoUringCqeGetData(LCqe)), 'max user_data preserved');
  LRing.CqeSeen(LCqe);
  LRing.Close;
end;

begin
  T := TTestRunner.Create('nextpas.core.io.uring.audit');
  T.Run('Create/Close multiple', @TestCreateCloseMultiple);
  T.Run('Double close', @TestDoubleClose);
  T.Run('Submit empty', @TestSubmitEmpty);
  T.Run('Pool recycling 50', @TestPoolRecycling50);
  T.Run('Read/Write zero bytes', @TestReadWriteZeroBytes);
  T.Run('Read/Write 64KB', @TestReadWriteLargeBlock);
  T.Run('Read bad fd', @TestReadBadFd);
  T.Run('Reactor stress 100', @TestReactorStress100);
  T.Run('Reactor batch 32', @TestReactorBatchSubmit);
  T.Run('Reactor free-list 200', @TestReactorFreeListReuse);
  T.Run('Reactor context preserved', @TestReactorContextPreserved);
  T.Run('Reactor close no leak', @TestReactorClosedNoLeak);
  T.Run('Ring invalid size', @TestRingInvalidSize);
  T.Run('User data max value', @TestUserDataMaxValue);
  T.Summary;
end.

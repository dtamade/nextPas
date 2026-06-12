program test_io_uring;

{$I nextpas.core.settings.inc}

uses
  SysUtils, BaseUnix,
  nextpas.core.testing,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern,
  nextpas.core.io.uring;

var
  T: TTestRunner;

procedure TestCreateClose;
var
  LRing: TIoUring;
begin
  LRing := TIoUring.Create(8);
  Check(LRing.IsValid, 'ring created');
  LRing.Close;
  Check(not LRing.IsValid, 'ring closed');
end;

procedure TestNopSubmit;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LRet: Int32;
begin
  LRing := TIoUring.Create(8);
  Check(LRing.IsValid, 'ring valid');

  LSqe := LRing.GetSqe;
  Check(LSqe <> nil, 'got sqe');
  IoUringPrepNop(LSqe);

  LRet := LRing.Submit;
  Check(LRet >= 0, 'submit ok: ' + IntToStr(LRet));

  LRet := LRing.WaitCqe(LCqe);
  Check(LRet >= 0, 'wait ok');
  Check(LCqe <> nil, 'got cqe');
  Check(LCqe^.res >= 0, 'nop result >= 0');
  LRing.CqeSeen(LCqe);

  LRing.Close;
end;

procedure TestReadWrite;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LFd: Int32;
  LWriteBuf: array[0..15] of Byte;
  LReadBuf: array[0..15] of Byte;
  LRet: Int32;
begin
  LRing := TIoUring.Create(8);
  Check(LRing.IsValid, 'ring valid');

  // Create temp file
  LFd := memfd_create('test_rw', MFD_CLOEXEC);
  Check(LFd >= 0, 'memfd created');

  // Write via io_uring
  LWriteBuf[0] := $DE; LWriteBuf[1] := $AD; LWriteBuf[2] := $BE; LWriteBuf[3] := $EF;
  LSqe := LRing.GetSqe;
  IoUringPrepWrite(LSqe, LFd, @LWriteBuf[0], 4, 0);
  LRet := LRing.SubmitAndWait(1);
  Check(LRet >= 0, 'write submit');
  Check(LRing.PeekCqe(LCqe), 'write cqe');
  Check(LCqe^.res = 4, 'wrote 4 bytes');
  LRing.CqeSeen(LCqe);

  // Read via io_uring
  FillChar(LReadBuf, SizeOf(LReadBuf), 0);
  LSqe := LRing.GetSqe;
  IoUringPrepRead(LSqe, LFd, @LReadBuf[0], 4, 0);
  LRet := LRing.SubmitAndWait(1);
  Check(LRet >= 0, 'read submit');
  Check(LRing.PeekCqe(LCqe), 'read cqe');
  Check(LCqe^.res = 4, 'read 4 bytes');
  LRing.CqeSeen(LCqe);

  Check((LReadBuf[0] = $DE) and (LReadBuf[1] = $AD) and
        (LReadBuf[2] = $BE) and (LReadBuf[3] = $EF), 'data matches');

  FpClose(LFd);
  LRing.Close;
end;

procedure TestMultipleOps;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
  LI, LRet: Int32;
  LCount: Int32;
begin
  LRing := TIoUring.Create(32);
  Check(LRing.IsValid, 'ring valid');

  // Submit 8 NOPs
  for LI := 0 to 7 do
  begin
    LSqe := LRing.GetSqe;
    Check(LSqe <> nil, 'sqe ' + IntToStr(LI));
    IoUringPrepNop(LSqe);
  end;

  LRet := LRing.SubmitAndWait(8);
  Check(LRet >= 0, 'submit 8');

  // Drain all completions
  LCount := 0;
  while LRing.PeekCqe(LCqe) do
  begin
    Check(LCqe^.res >= 0, 'cqe res ok');
    LRing.CqeSeen(LCqe);
    Inc(LCount);
  end;
  CheckEqual(Int64(8), Int64(LCount), '8 completions');

  LRing.Close;
end;

procedure TestCqeReady;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
begin
  LRing := TIoUring.Create(8);
  CheckEqual(Int64(0), Int64(LRing.CqeReady), 'initially 0');

  LSqe := LRing.GetSqe;
  IoUringPrepNop(LSqe);
  LRing.SubmitAndWait(1);

  Check(LRing.CqeReady >= 1, 'at least 1 ready');
  LRing.PeekCqe(LCqe);
  LRing.CqeSeen(LCqe);
  CheckEqual(Int64(0), Int64(LRing.CqeReady), 'back to 0');

  LRing.Close;
end;

procedure TestSqeFull;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LI: Int32;
begin
  LRing := TIoUring.Create(4);
  // Fill all SQEs
  for LI := 0 to 3 do
  begin
    LSqe := LRing.GetSqe;
    Check(LSqe <> nil, 'sqe ' + IntToStr(LI));
    IoUringPrepNop(LSqe);
  end;
  // Next should return nil (full)
  LSqe := LRing.GetSqe;
  Check(LSqe = nil, 'sqe full returns nil');
  LRing.Submit;
  LRing.Close;
end;

procedure TestUserData;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
begin
  LRing := TIoUring.Create(8);

  LSqe := LRing.GetSqe;
  IoUringPrepNop(LSqe);
  IoUringSqeSetData(LSqe, 12345);

  LRing.SubmitAndWait(1);
  LRing.PeekCqe(LCqe);
  CheckEqual(Int64(12345), Int64(IoUringCqeGetData(LCqe)), 'user_data preserved');
  LRing.CqeSeen(LCqe);

  LRing.Close;
end;

procedure TestPostCloseAccessors;
var
  LRing: TIoUring;
  LSqe: PIoUringSqe;
  LCqe: PIoUringCqe;
begin
  LRing := TIoUring.Create(8);
  Check(LRing.IsValid, 'ring valid');
  LRing.Close;

  LSqe := LRing.GetSqe;
  Check(LSqe = nil, 'closed ring returns nil sqe');
  CheckEqual(Int64(-1), Int64(LRing.Submit), 'closed ring submit rejected');
  CheckEqual(Int64(-1), Int64(LRing.SubmitAndWait(1)),
    'closed ring submit-and-wait rejected');
  Check(not LRing.PeekCqe(LCqe), 'closed ring has no cqe');
  CheckEqual(Int64(-1), Int64(LRing.WaitCqe(LCqe)),
    'closed ring wait rejected');
  Check(LCqe = nil, 'closed ring wait clears cqe');
  CheckEqual(Int64(0), Int64(LRing.CqeReady), 'closed ring has no ready cqe');
  LRing.CqeSeen(nil);
end;

begin
  T := TTestRunner.Create('nextpas.core.io.uring');
  T.Run('Create/Close', @TestCreateClose);
  T.Run('NOP submit', @TestNopSubmit);
  T.Run('Read/Write', @TestReadWrite);
  T.Run('Multiple ops', @TestMultipleOps);
  T.Run('CqeReady', @TestCqeReady);
  T.Run('SQE full', @TestSqeFull);
  T.Run('User data', @TestUserData);
  T.Run('Post-close accessors', @TestPostCloseAccessors);
  T.Summary;
end.

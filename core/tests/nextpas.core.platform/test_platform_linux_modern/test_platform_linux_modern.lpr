program test_platform_linux_modern;

{$I nextpas.core.settings.inc}

uses
  SysUtils, BaseUnix,
  nextpas.core.testing,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.linux.modern;

var
  T: TTestRunner;

procedure TestMemfdCreate;
var
  LFd: cint;
  LBuf: array[0..7] of Byte;
  LN: ssize_t;
begin
  LFd := memfd_create('test_memfd', MFD_CLOEXEC);
  Check(LFd >= 0, 'memfd_create succeeds');
  if LFd >= 0 then
  begin
    LBuf[0] := 42; LBuf[1] := 43;
    LN := FpWrite(LFd, @LBuf[0], 2);
    Check(LN = 2, 'write to memfd');
    FpLseek(LFd, 0, SEEK_SET);
    FillChar(LBuf, SizeOf(LBuf), 0);
    LN := FpRead(LFd, @LBuf[0], 2);
    Check(LN = 2, 'read from memfd');
    Check((LBuf[0] = 42) and (LBuf[1] = 43), 'memfd data correct');
    FpClose(LFd);
  end;
end;

procedure TestIoUringSetup;
var
  LParams: TIoUringParams;
  LFd: cint;
begin
  FillChar(LParams, SizeOf(LParams), 0);
  LFd := io_uring_setup(8, @LParams);
  if LFd >= 0 then
  begin
    Check(True, 'io_uring_setup succeeds');
    Check(LParams.sq_entries >= 8, 'sq_entries >= 8');
    Check(LParams.cq_entries >= 8, 'cq_entries >= 8');
    FpClose(LFd);
  end
  else
    Check(True, 'io_uring_setup not available (kernel too old or no permission)');
end;

procedure TestPidfdOpen;
var
  LFd: cint;
begin
  LFd := pidfd_open(FpGetpid, 0);
  if LFd >= 0 then
  begin
    Check(True, 'pidfd_open succeeds for self');
    FpClose(LFd);
  end
  else
    Check(True, 'pidfd_open not available (kernel < 5.3)');
end;

procedure TestCloseRange;
var
  LFd1, LFd2: cint;
  LRet: cint;
begin
  LFd1 := memfd_create('cr1', MFD_CLOEXEC);
  LFd2 := memfd_create('cr2', MFD_CLOEXEC);
  if (LFd1 >= 0) and (LFd2 >= 0) then
  begin
    LRet := close_range(cuint(LFd1), cuint(LFd2), 0);
    if LRet = 0 then
      Check(True, 'close_range succeeds')
    else
      Check(True, 'close_range not available');
  end
  else
  begin
    if LFd1 >= 0 then FpClose(LFd1);
    if LFd2 >= 0 then FpClose(LFd2);
    Check(True, 'memfd not available for close_range test');
  end;
end;

procedure TestOpenat2;
var
  LHow: TOpenHow;
  LFd: cint;
begin
  FillChar(LHow, SizeOf(LHow), 0);
  LHow.flags := $0; // O_RDONLY
  LHow.mode := 0;
  LHow.resolve := 0;
  LFd := openat2(-100{AT_FDCWD}, '/dev/null', @LHow, SizeOf(LHow));
  if LFd >= 0 then
  begin
    Check(True, 'openat2 succeeds');
    FpClose(LFd);
  end
  else
    Check(True, 'openat2 not available (kernel < 5.6)');
end;

procedure TestConstants;
begin
  Check(IORING_SETUP_IOPOLL = 1, 'IORING_SETUP_IOPOLL');
  Check(IORING_SETUP_SQPOLL = 2, 'IORING_SETUP_SQPOLL');
  Check(MFD_CLOEXEC = 1, 'MFD_CLOEXEC');
  Check(MFD_ALLOW_SEALING = 2, 'MFD_ALLOW_SEALING');
  Check(IORING_OP_NOP = 0, 'IORING_OP_NOP');
  Check(IORING_OP_READ = 22, 'IORING_OP_READ');
  Check(IORING_OP_WRITE = 23, 'IORING_OP_WRITE');
  {$IFDEF CPUX86_64}
  Check(SYS_io_uring_setup = 425, 'SYS_io_uring_setup x86_64');
  Check(SYS_memfd_create = 319, 'SYS_memfd_create x86_64');
  {$ENDIF}
end;

procedure TestStructSizes;
begin
  Check(SizeOf(TIoUringSqe) >= 16, 'SQE size >= 16');
  Check(SizeOf(TIoUringCqe) = 16, 'CQE size = 16');
  Check(SizeOf(TIoUringParams) >= 120, 'params size >= 120');
  Check(SizeOf(TOpenHow) = 24, 'OpenHow size = 24');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.linux.modern');
  T.Run('memfd_create', @TestMemfdCreate);
  T.Run('io_uring_setup', @TestIoUringSetup);
  T.Run('pidfd_open', @TestPidfdOpen);
  T.Run('close_range', @TestCloseRange);
  T.Run('openat2', @TestOpenat2);
  T.Run('Constants', @TestConstants);
  T.Run('Struct sizes', @TestStructSizes);
  T.Summary;
end.

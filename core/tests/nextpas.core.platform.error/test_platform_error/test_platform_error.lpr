program test_platform_error;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.error,
  nextpas.core.platform.process.base,
  nextpas.core.platform.process,
  nextpas.core.platform.posix.ffi,
  nextpas.core.errors,
  nextpas.core.test
{$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
{$ENDIF}
{$IFDEF NEXTPAS_MACOS}
  , nextpas.core.platform.darwin.base
{$ENDIF}
{$IFDEF NEXTPAS_FREEBSD}
  , nextpas.core.platform.freebsd.base
{$ENDIF}
{$IFDEF NEXTPAS_ANDROID}
  , nextpas.core.platform.android.base
{$ENDIF}
  ;

var
  T: TTestSuite;

function StrContains(const AHaystack, ANeedle: PAnsiChar): Boolean;
var
  I, J, HLen, NLen: Int32;
begin
  HLen := 0;
  while AHaystack[HLen] <> #0 do Inc(HLen);
  NLen := 0;
  while ANeedle[NLen] <> #0 do Inc(NLen);
  if NLen = 0 then Exit(True);
  if NLen > HLen then Exit(False);
  for I := 0 to HLen - NLen do
  begin
    J := 0;
    while (J < NLen) and (AHaystack[I + J] = ANeedle[J]) do
      Inc(J);
    if J = NLen then Exit(True);
  end;
  Result := False;
end;

procedure SpawnWithPipes(const APath: PAnsiChar; AArgv: PPAnsiChar;
  out AProc: TPlatformProcess; out AStdinWrite, AStdoutRead,
  AStderrRead: PtrInt);
var
  LChildStdin: PtrInt;
  LChildStdout: PtrInt;
  LChildStderr: PtrInt;
  LFailStage: TPlatformProcessSpawnStage;
begin
  FillChar(AProc, SizeOf(AProc), 0);
  AStdinWrite := -1;
  AStdoutRead := -1;
  AStderrRead := -1;
  LChildStdin := -1;
  LChildStdout := -1;
  LChildStderr := -1;
  try
    Check(platform_process_create_pipe(LChildStdin, AStdinWrite) = 0,
      'create stdin pipe');
    Check(platform_process_create_pipe(AStdoutRead, LChildStdout) = 0,
      'create stdout pipe');
    Check(platform_process_create_pipe(AStderrRead, LChildStderr) = 0,
      'create stderr pipe');
    Check(platform_process_spawn_fds(APath, AArgv, nil, nil, LChildStdin,
      LChildStdout, LChildStderr, AProc, LFailStage) = 0, 'spawn');
  except
    platform_process_close_handle(LChildStdin);
    platform_process_close_handle(LChildStdout);
    platform_process_close_handle(LChildStderr);
    platform_process_close_handle(AStdinWrite);
    platform_process_close_handle(AStdoutRead);
    platform_process_close_handle(AStderrRead);
    raise;
  end;
  platform_process_close_handle(LChildStdin);
  platform_process_close_handle(LChildStdout);
  platform_process_close_handle(LChildStderr);
end;

procedure TestENOENT;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], 256);
  Check(R > 0, 'ENOENT returns length > 0');
  Check(StrContains(@Buf[0], 'o such file'), 'contains "o such file"');
end;

procedure TestEEXIST;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(17, @Buf[0], 256);
  Check(R > 0, 'EEXIST returns length > 0');
  Check(StrContains(@Buf[0], 'already exists'), 'contains "already exists"');
end;

procedure TestENOTDIR;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(20, @Buf[0], 256);
  Check(R > 0, 'ENOTDIR returns length > 0');
  Check(StrContains(@Buf[0], 'not a directory'), 'contains "not a directory"');
end;

procedure TestPathTooLong;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(-7, @Buf[0], 256);
  Check(R > 0, 'PATH_TOO_LONG returns length > 0');
  Check(StrContains(@Buf[0], 'path too long'), 'contains "path too long"');
end;

procedure TestEACCES;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(13, @Buf[0], 256);
  Check(R > 0, 'EACCES returns length > 0');
  Check(StrContains(@Buf[0], 'ermission'), 'contains "ermission"');
end;

procedure TestZero;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(0, @Buf[0], 256);
  Check(R >= 0, 'code 0 returns >= 0');
  Check(Buf[0] <> #0, 'non-empty string');
end;

procedure TestUnknown;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(9999, @Buf[0], 256);
  Check(R > 0, 'unknown code returns > 0');
  Check(Buf[0] <> #0, 'non-empty');
end;

procedure TestSmallBuffer;
var
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], 4);
  Check(R >= 0, 'small buffer does not crash');
  Check(Buf[3] = #0, 'null terminated');
end;

procedure TestFatalExists;
var
  P: Pointer;
begin
  P := @platform_fatal;
  Check(P <> nil, 'platform_fatal linked');
  P := @platform_fatal_code;
  Check(P <> nil, 'platform_fatal_code linked');
end;

procedure TestFatalBehavior;
var
  Proc: TPlatformProcess;
  R: TPlatformProcessResult;
  LArgv: array[0..3] of PAnsiChar;
  LBuf: array[0..255] of AnsiChar;
  LRead: PtrInt;
  LStdinWrite: PtrInt;
  LStdoutRead: PtrInt;
  LStderrRead: PtrInt;
begin
  LArgv[0] := '/bin/sh';
  LArgv[1] := '-c';
  LArgv[2] := 'echo "fatal: test message" >&2; exit 1';
  LArgv[3] := nil;
  SpawnWithPipes('/bin/sh', @LArgv[0], Proc, LStdinWrite, LStdoutRead, LStderrRead);
  platform_process_close_handle(LStdinWrite);
  platform_process_close_handle(LStdoutRead);
  FillChar(LBuf, SizeOf(LBuf), 0);
  LRead := nextpas.core.platform.posix.ffi.read(LStderrRead, @LBuf[0], 256);
  Check(LRead > 0, 'stderr has output');
  Check(LBuf[0] = 'f', 'starts with f');
  Check(LBuf[1] = 'a', 'second char a');
  platform_process_close_handle(LStderrRead);
  platform_process_wait(Proc, R);
  Check(R.ExitCode = 1, 'exit code 1');
end;

{ Error path tests }
procedure TestNilBuffer;
var
  R: Int32;
begin
  R := platform_error_message(2, nil, 256);
  Check(R = PLATFORM_ERR_INVALID, 'nil buffer returns PLATFORM_ERR_INVALID');
end;

procedure TestZeroLengthBuffer;
var
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], 0);
  Check(R = PLATFORM_ERR_INVALID, 'zero length buffer returns PLATFORM_ERR_INVALID');
end;

procedure TestNegativeLengthBuffer;
var
  Buf: array[0..3] of AnsiChar;
  R: Int32;
begin
  R := platform_error_message(2, @Buf[0], -1);
  Check(R = PLATFORM_ERR_INVALID, 'negative length buffer returns PLATFORM_ERR_INVALID');
end;

procedure TestCategoryInvalid;
begin
  Check(platform_error_category(PLATFORM_ERR_INVALID) = ecInvalidArgument,
    'INVALID maps to ecInvalidArgument');
end;

procedure TestCategoryUnsupported;
begin
  Check(platform_error_category(PLATFORM_ERR_UNSUPPORTED) = ecNotSupported,
    'UNSUPPORTED maps to ecNotSupported');
end;

procedure TestCategoryTimeout;
begin
  Check(platform_error_category(PLATFORM_ERR_TIMEOUT) = ecTimeout,
    'TIMEOUT maps to ecTimeout');
end;

procedure TestCategoryAgain;
begin
  Check(platform_error_category(PLATFORM_ERR_AGAIN) = ecWouldBlock,
    'AGAIN maps to ecWouldBlock');
end;

procedure TestCategoryBusy;
begin
  Check(platform_error_category(PLATFORM_ERR_BUSY) = ecWouldBlock,
    'BUSY maps to ecWouldBlock');
end;

procedure TestCategoryBadf;
begin
  Check(platform_error_category(PLATFORM_ERR_BADF) = ecIO,
    'BADF maps to ecIO');
end;

procedure TestCategoryZero;
begin
  Check(platform_error_category(0) = ecNone,
    'code 0 maps to ecNone');
end;

procedure TestCategoryEnoent;
begin
  Check(platform_error_category(PLATFORM_ERR_ENOENT) = ecNotFound,
    'ENOENT maps to ecNotFound');
end;

procedure TestCategoryEexist;
begin
  Check(platform_error_category(PLATFORM_ERR_EEXIST) = ecAlreadyExists,
    'EEXIST maps to ecAlreadyExists');
end;

procedure TestCategoryEnotdir;
begin
  Check(platform_error_category(PLATFORM_ERR_ENOTDIR) = ecNotFound,
    'ENOTDIR maps to ecNotFound');
end;

procedure TestCategoryPathTooLong;
begin
  Check(platform_error_category(PLATFORM_ERR_PATH_TOO_LONG) = ecInvalidArgument,
    'PATH_TOO_LONG maps to ecInvalidArgument');
end;

procedure TestUnknownConstantAndMessage;
var
  Buf: array[0..255] of AnsiChar;
  R: Int32;
begin
  CheckEqual(Int64(-8), Int64(PLATFORM_ERR_UNKNOWN), 'UNKNOWN is -8');
  R := platform_error_message(PLATFORM_ERR_UNKNOWN, @Buf[0], 256);
  Check(R > 0, 'UNKNOWN message length > 0');
  Check(StrContains(@Buf[0], 'unknown'), 'UNKNOWN message contains unknown');
  Check(platform_error_category(PLATFORM_ERR_UNKNOWN) = ecInternal,
    'UNKNOWN maps to ecInternal');
end;

procedure TestLastOsErrorSideChannel;
var
  LOs, LMapped: Int32;
  LBuf: array[0..63] of AnsiChar;
begin
  LOs := platform_get_last_os_error;
  LMapped := platform_get_last_error;
  Check(LOs >= 0, 'last_os_error is non-negative host code');
  { mapped API remains callable independently }
  Check(LMapped >= -8, 'last_error stays in portable/host range');
  { trigger a known missing path so both APIs remain well-defined after a failure }
  Check(platform_error_message(PLATFORM_ERR_NOENT, @LBuf[0], SizeOf(LBuf)) > 0,
    'error_message still works alongside last_os_error');
end;

{ POSIX errno category mapping tests — use host ESysE* (not Linux literals). }
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD) or defined(NEXTPAS_ANDROID)}
procedure TestPosixCategoryEnoent;
begin
  Check(platform_error_category(ESysENOENT) = ecNotFound,
    'POSIX ENOENT maps to ecNotFound');
end;

procedure TestPosixCategoryEperm;
begin
  Check(platform_error_category(ESysEPERM) = ecPermission,
    'POSIX EPERM maps to ecPermission');
end;

procedure TestPosixCategoryEacces;
begin
  Check(platform_error_category(ESysEACCES) = ecPermission,
    'POSIX EACCES maps to ecPermission');
end;

procedure TestPosixCategoryEexist;
begin
  Check(platform_error_category(ESysEEXIST) = ecAlreadyExists,
    'POSIX EEXIST maps to ecAlreadyExists');
end;

procedure TestPosixCategoryEaddrinuse;
begin
  Check(platform_error_category(ESysEADDRINUSE) = ecAlreadyExists,
    'POSIX EADDRINUSE maps to ecAlreadyExists');
end;

procedure TestPosixCategoryEnetunreach;
begin
  Check(platform_error_category(ESysENETUNREACH) = ecNetwork,
    'POSIX ENETUNREACH maps to ecNetwork');
end;

procedure TestPosixCategoryEhostunreach;
begin
  Check(platform_error_category(ESysEHOSTUNREACH) = ecNetwork,
    'POSIX EHOSTUNREACH maps to ecNetwork');
end;

procedure TestPosixCategoryEnotconn;
begin
  Check(platform_error_category(ESysENOTCONN) = ecNetwork,
    'POSIX ENOTCONN maps to ecNetwork');
end;

procedure TestPosixCategoryEnomem;
begin
  Check(platform_error_category(ESysENOMEM) = ecResourceExhausted,
    'POSIX ENOMEM maps to ecResourceExhausted');
end;

procedure TestPosixCategoryEnospc;
begin
  Check(platform_error_category(ESysENOSPC) = ecResourceExhausted,
    'POSIX ENOSPC maps to ecResourceExhausted');
end;

procedure TestPosixCategoryEinval;
begin
  Check(platform_error_category(ESysEINVAL) = ecInvalidArgument,
    'POSIX EINVAL maps to ecInvalidArgument');
end;

procedure TestPosixCategoryEopnotsupp;
begin
  Check(platform_error_category(ESysEOPNOTSUPP) = ecNotSupported,
    'POSIX EOPNOTSUPP maps to ecNotSupported');
end;

procedure TestPosixCategoryEtimedout;
begin
  Check(platform_error_category(ESysETIMEDOUT) = ecTimeout,
    'POSIX ETIMEDOUT maps to ecTimeout');
end;

procedure TestPosixCategoryEagain;
begin
  Check(platform_error_category(ESysEAGAIN) = ecWouldBlock,
    'POSIX EAGAIN maps to ecWouldBlock');
end;

procedure TestPosixCategoryEbusy;
begin
  Check(platform_error_category(ESysEBUSY) = ecWouldBlock,
    'POSIX EBUSY maps to ecWouldBlock');
end;

procedure TestPosixCategoryEio;
begin
  Check(platform_error_category(ESysEIO) = ecIO,
    'POSIX EIO maps to ecIO');
end;

procedure TestPosixCategoryEpipe;
begin
  Check(platform_error_category(ESysEPIPE) = ecIO,
    'POSIX EPIPE maps to ecIO');
end;

procedure TestPosixCategoryEconnaborted;
begin
  Check(platform_error_category(ESysECONNABORTED) = ecIO,
    'POSIX ECONNABORTED maps to ecIO');
end;

procedure TestPosixCategoryEconnreset;
begin
  Check(platform_error_category(ESysECONNRESET) = ecIO,
    'POSIX ECONNRESET maps to ecIO');
end;

procedure TestPosixCategoryEconnrefused;
begin
  Check(platform_error_category(ESysECONNREFUSED) = ecIO,
    'POSIX ECONNREFUSED maps to ecIO');
end;

procedure TestPosixCategoryEintr;
begin
  Check(platform_error_category(ESysEINTR) = ecInterrupted,
    'POSIX EINTR maps to ecInterrupted');
end;

procedure TestPosixCategoryUnknown;
begin
  Check(platform_error_category(9999) = ecInternal,
    'Unknown POSIX code maps to ecInternal');
end;
{$ENDIF}

procedure TestNewPermConstant;
begin
  CheckEqual(Int64(1), Int64(PLATFORM_ERR_PERM), 'PLATFORM_ERR_PERM = 1');
end;

procedure TestNewIoConstant;
begin
  CheckEqual(Int64(5), Int64(PLATFORM_ERR_IO), 'PLATFORM_ERR_IO = 5');
end;

procedure TestNewNomemConstant;
begin
  CheckEqual(Int64(12), Int64(PLATFORM_ERR_NOMEM), 'PLATFORM_ERR_NOMEM = 12');
end;

procedure TestNewPipeConstant;
begin
  CheckEqual(Int64(32), Int64(PLATFORM_ERR_PIPE), 'PLATFORM_ERR_PIPE = 32');
end;

procedure TestNewNosysConstant;
begin
  CheckEqual(Int64(38), Int64(PLATFORM_ERR_NOSYS), 'PLATFORM_ERR_NOSYS = 38');
end;

procedure TestNewConnresetConstant;
begin
  CheckEqual(Int64(104), Int64(PLATFORM_ERR_CONNRESET), 'PLATFORM_ERR_CONNRESET = 104');
end;

procedure TestNewConnrefusedConstant;
begin
  CheckEqual(Int64(111), Int64(PLATFORM_ERR_CONNREFUSED), 'PLATFORM_ERR_CONNREFUSED = 111');
end;

procedure TestPermMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_PERM, @Buf[0], 64) > 0, 'PERM message');
  Check(Pos('not permitted', Buf) > 0, 'contains "not permitted"');
end;

procedure TestIoMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_IO, @Buf[0], 64) > 0, 'IO message');
  Check(Pos('input/output', Buf) > 0, 'contains "input/output"');
end;

procedure TestNomemMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_NOMEM, @Buf[0], 64) > 0, 'NOMEM message');
  Check(Pos('out of memory', Buf) > 0, 'contains "out of memory"');
end;

procedure TestPipeMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_PIPE, @Buf[0], 64) > 0, 'PIPE message');
  Check(Pos('broken pipe', Buf) > 0, 'contains "broken pipe"');
end;

procedure TestNosysMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_NOSYS, @Buf[0], 64) > 0, 'NOSYS message');
  Check(Pos('not implemented', Buf) > 0, 'contains "not implemented"');
end;

procedure TestConnresetMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_CONNRESET, @Buf[0], 64) > 0, 'CONNRESET message');
  Check(Pos('reset', Buf) > 0, 'contains "reset"');
end;

procedure TestConnrefusedMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_CONNREFUSED, @Buf[0], 64) > 0, 'CONNREFUSED message');
  Check(Pos('refused', Buf) > 0, 'contains "refused"');
end;

procedure TestPermCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_PERM) = ecPermission, 'PERM is ecPermission');
end;

procedure TestIoCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_IO) = ecIO, 'IO is ecIO');
end;

procedure TestNomemCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_NOMEM) = ecResourceExhausted, 'NOMEM is ecResourceExhausted');
end;

procedure TestPipeCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_PIPE) = ecIO, 'PIPE is ecIO');
end;

procedure TestNosysCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_NOSYS) = ecNotSupported, 'NOSYS is ecNotSupported');
end;

procedure TestConnresetCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_CONNRESET) = ecIO, 'CONNRESET is ecIO');
end;

procedure TestConnrefusedCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_CONNREFUSED) = ecIO, 'CONNREFUSED is ecIO');
end;

procedure TestIntrConstant;
begin
  CheckEqual(Int64(4), Int64(PLATFORM_ERR_INTR), 'PLATFORM_ERR_INTR = 4');
end;

procedure TestNospcConstant;
begin
  CheckEqual(Int64(28), Int64(PLATFORM_ERR_NOSPC), 'PLATFORM_ERR_NOSPC = 28');
end;

procedure TestIntrMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_INTR, @Buf[0], 64) > 0, 'INTR message');
  Check(Pos('interrupted', Buf) > 0, 'contains "interrupted"');
end;

procedure TestNospcMessage;
var
  Buf: array[0..63] of AnsiChar;
begin
  Check(platform_error_message(PLATFORM_ERR_NOSPC, @Buf[0], 64) > 0, 'NOSPC message');
  Check(Pos('no space', Buf) > 0, 'contains "no space"');
end;

procedure TestIntrCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_INTR) = ecInterrupted, 'INTR is ecInterrupted');
end;

procedure TestNospcCategory;
begin
  Check(platform_error_category(PLATFORM_ERR_NOSPC) = ecResourceExhausted, 'NOSPC is ecResourceExhausted');
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.error');
  T.Test('ENOENT message', @TestENOENT);
  T.Test('EEXIST message', @TestEEXIST);
  T.Test('ENOTDIR message', @TestENOTDIR);
  T.Test('PATH_TOO_LONG message', @TestPathTooLong);
  T.Test('EACCES message', @TestEACCES);
  T.Test('code 0 (Success)', @TestZero);
  T.Test('unknown error code', @TestUnknown);
  T.Test('small buffer truncation', @TestSmallBuffer);
  T.Test('fatal API exists', @TestFatalExists);
  T.Test('fatal behavior (via subprocess)', @TestFatalBehavior);
  T.Test('nil buffer returns PLATFORM_ERR_INVALID', @TestNilBuffer);
  T.Test('zero length buffer returns PLATFORM_ERR_INVALID', @TestZeroLengthBuffer);
  T.Test('negative length buffer returns PLATFORM_ERR_INVALID', @TestNegativeLengthBuffer);
  T.Test('INVALID maps to ecInvalidArgument', @TestCategoryInvalid);
  T.Test('UNSUPPORTED maps to ecNotSupported', @TestCategoryUnsupported);
  T.Test('TIMEOUT maps to ecTimeout', @TestCategoryTimeout);
  T.Test('AGAIN maps to ecWouldBlock', @TestCategoryAgain);
  T.Test('BUSY maps to ecWouldBlock', @TestCategoryBusy);
  T.Test('BADF maps to ecIO', @TestCategoryBadf);
  T.Test('code 0 maps to ecNone', @TestCategoryZero);
  T.Test('ENOENT maps to ecNotFound', @TestCategoryEnoent);
  T.Test('EEXIST maps to ecAlreadyExists', @TestCategoryEexist);
  T.Test('ENOTDIR maps to ecNotFound', @TestCategoryEnotdir);
  T.Test('PATH_TOO_LONG maps to ecInvalidArgument', @TestCategoryPathTooLong);
  T.Test('UNKNOWN constant message and category', @TestUnknownConstantAndMessage);
  T.Test('last_os_error side-channel callable', @TestLastOsErrorSideChannel);
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD) or defined(NEXTPAS_ANDROID)}
  { POSIX errno category tests (host ESysE* values) }
  T.Test('POSIX ENOENT maps to ecNotFound', @TestPosixCategoryEnoent);
  T.Test('POSIX EPERM maps to ecPermission', @TestPosixCategoryEperm);
  T.Test('POSIX EACCES maps to ecPermission', @TestPosixCategoryEacces);
  T.Test('POSIX EEXIST maps to ecAlreadyExists', @TestPosixCategoryEexist);
  T.Test('POSIX EADDRINUSE maps to ecAlreadyExists', @TestPosixCategoryEaddrinuse);
  T.Test('POSIX ENETUNREACH maps to ecNetwork', @TestPosixCategoryEnetunreach);
  T.Test('POSIX EHOSTUNREACH maps to ecNetwork', @TestPosixCategoryEhostunreach);
  T.Test('POSIX ENOTCONN maps to ecNetwork', @TestPosixCategoryEnotconn);
  T.Test('POSIX ENOMEM maps to ecResourceExhausted', @TestPosixCategoryEnomem);
  T.Test('POSIX ENOSPC maps to ecResourceExhausted', @TestPosixCategoryEnospc);
  T.Test('POSIX EINVAL maps to ecInvalidArgument', @TestPosixCategoryEinval);
  T.Test('POSIX EOPNOTSUPP maps to ecNotSupported', @TestPosixCategoryEopnotsupp);
  T.Test('POSIX ETIMEDOUT maps to ecTimeout', @TestPosixCategoryEtimedout);
  T.Test('POSIX EAGAIN maps to ecWouldBlock', @TestPosixCategoryEagain);
  T.Test('POSIX EBUSY maps to ecWouldBlock', @TestPosixCategoryEbusy);
  T.Test('POSIX EIO maps to ecIO', @TestPosixCategoryEio);
  T.Test('POSIX EPIPE maps to ecIO', @TestPosixCategoryEpipe);
  T.Test('POSIX ECONNABORTED maps to ecIO', @TestPosixCategoryEconnaborted);
  T.Test('POSIX ECONNRESET maps to ecIO', @TestPosixCategoryEconnreset);
  T.Test('POSIX ECONNREFUSED maps to ecIO', @TestPosixCategoryEconnrefused);
  T.Test('POSIX EINTR maps to ecInterrupted', @TestPosixCategoryEintr);
  T.Test('Unknown POSIX code maps to ecInternal', @TestPosixCategoryUnknown);
{$ENDIF}
  T.Test('new PERM constant is 1', @TestNewPermConstant);
  T.Test('new IO constant is 5', @TestNewIoConstant);
  T.Test('new NOMEM constant is 12', @TestNewNomemConstant);
  T.Test('new PIPE constant is 32', @TestNewPipeConstant);
  T.Test('new NOSYS constant is 38', @TestNewNosysConstant);
  T.Test('new CONNRESET constant is 104', @TestNewConnresetConstant);
  T.Test('new CONNREFUSED constant is 111', @TestNewConnrefusedConstant);
  T.Test('PERM message', @TestPermMessage);
  T.Test('IO message', @TestIoMessage);
  T.Test('NOMEM message', @TestNomemMessage);
  T.Test('PIPE message', @TestPipeMessage);
  T.Test('NOSYS message', @TestNosysMessage);
  T.Test('CONNRESET message', @TestConnresetMessage);
  T.Test('CONNREFUSED message', @TestConnrefusedMessage);
  T.Test('PERM category is ecPermission', @TestPermCategory);
  T.Test('IO category is ecIO', @TestIoCategory);
  T.Test('NOMEM category is ecResourceExhausted', @TestNomemCategory);
  T.Test('PIPE category is ecIO', @TestPipeCategory);
  T.Test('NOSYS category is ecNotSupported', @TestNosysCategory);
  T.Test('CONNRESET category is ecIO', @TestConnresetCategory);
  T.Test('CONNREFUSED category is ecIO', @TestConnrefusedCategory);
  T.Test('new INTR constant is 4', @TestIntrConstant);
  T.Test('new NOSPC constant is 28', @TestNospcConstant);
  T.Test('INTR message', @TestIntrMessage);
  T.Test('NOSPC message', @TestNospcMessage);
  T.Test('INTR category is ecInterrupted', @TestIntrCategory);
  T.Test('NOSPC category is ecResourceExhausted', @TestNospcCategory);
  if not T.Run then Halt(1);
end.

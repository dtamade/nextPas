program test_platform_io;

{$I nextpas.core.settings.inc}

uses

  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.platform.io.base,
  nextpas.core.platform.io,
  nextpas.core.platform.posix.ffi,
  nextpas.core.test;

var
  T: TTestSuite;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := '../../../' + ARelativePath;
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  Result := LowerCase(FsReadFileText(LSourcePath));
end;

function ExtractFunctionSource(const ASource, AName: string): string;
var
  LLines: TStringArray;
  LLine: string;
  LFound: Boolean;
  LHasBody: Boolean;
  LIndex: Integer;
  LDeleteLen: Integer;
begin
  Result := '';
  LLines := StringsSplit(ASource, #10);
  LFound := False;
  LHasBody := False;
  for LIndex := 0 to High(LLines) do
  begin
    LLine := TrimLeft(LLines[LIndex]);
    if not LFound then
    begin
      if Pos('function ' + AName + '(', LowerCase(LLine)) = 1 then
      begin
        Result := LLines[LIndex];
        LFound := True;
      end;
      Continue;
    end;

    if Result <> '' then
      Result := Result + LineEnding;
    Result := Result + LLines[LIndex];

    if Pos('begin', LowerCase(LLine)) > 0 then
      LHasBody := True
    else if LHasBody and
      ((Pos('function ', LowerCase(LLine)) = 1) or
       (Pos('procedure ', LowerCase(LLine)) = 1)) then
    begin
      LDeleteLen := Length(LLines[LIndex]);
      if Result <> '' then
        Inc(LDeleteLen, Length(LineEnding));
      Delete(Result, Length(Result) - LDeleteLen + 1, LDeleteLen);
      Break;
    end;
  end;
  Check(LFound, 'function source should exist: ' + AName);
end;

function ExtractKqueueRegion(const ASource: string): string;
const
  StartMarker = '{$if defined(nextpas_macos) or defined(nextpas_freebsd)}';
  EndMarker = '{$ifdef nextpas_windows}';
var
  LStartPos: SizeInt;
  LEndPos: SizeInt;
begin
  LStartPos := Pos(StartMarker, ASource);
  Check(LStartPos > 0, 'kqueue source region should exist');
  LEndPos := Pos(EndMarker, ASource);
  Check(LEndPos > LStartPos, 'windows source region should follow kqueue region');
  Result := Copy(ASource, LStartPos, LEndPos - LStartPos);
end;

function ExtractWindowsRegion(const ASource: string): string;
const
  StartMarker = '{$ifdef nextpas_windows}';
  EndMarker = '{$if not defined(nextpas_linux) and not defined(nextpas_macos) and not defined(nextpas_freebsd) and not defined(nextpas_windows)}';
var
  LStartPos: SizeInt;
  LEndPos: SizeInt;
begin
  LStartPos := Pos(StartMarker, ASource);
  Check(LStartPos > 0, 'windows source region should exist');
  LEndPos := Pos(EndMarker, ASource);
  Check(LEndPos > LStartPos, 'unsupported source region should follow windows region');
  Result := Copy(ASource, LStartPos, LEndPos - LStartPos);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(AToken, ASource) = 0, AMessage + ': ' + AToken);
end;

procedure TestCreateClose;
var
  P: TPlatformPoller;
begin
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_close(P) = 0, 'close');
end;

procedure TestDoubleClose;
var
  P: TPlatformPoller;
begin
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_close(P) = 0, 'close first');
  Check(platform_poller_close(P) <> 0, 'close second returns error');
end;

procedure TestPipeReadable;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
  LWritten: PtrInt;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], nil) = 0, 'add read end');

  LBuf := 42;
  LWritten := write(LPipeFd[1], @LBuf, 1);
  Check(LWritten = 1, 'write to pipe');

  Check(platform_poller_wait(P, @LEntries[0], 4, 1000, LCount) = 0, 'wait');
  Check(LCount = 1, 'got 1 event');
  Check(LEntries[0].Fd = PtrUInt(LPipeFd[0]), 'event fd preserved');
  Check(peReadable in LEntries[0].REvents, 'event is readable');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  Check(platform_poller_close(P) = 0, 'close poller');
end;

procedure TestTimeoutZero;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], nil) = 0, 'add');

  Check(platform_poller_wait(P, @LEntries[0], 4, 0, LCount) = 0, 'wait timeout=0');
  Check(LCount = 0, 'no events ready');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestRemove;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], nil) = 0, 'add');
  Check(platform_poller_remove(P, LPipeFd[0]) = 0, 'remove');

  LBuf := 1;
  write(LPipeFd[1], @LBuf, 1);

  Check(platform_poller_wait(P, @LEntries[0], 4, 0, LCount) = 0, 'wait after remove');
  Check(LCount = 0, 'no events after remove');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestModify;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  // Add write end watching for writable
  Check(platform_poller_add(P, LPipeFd[1], [peWritable], nil) = 0, 'add writable');

  // Modify to watch for readable instead
  Check(platform_poller_modify(P, LPipeFd[1], [peReadable], nil) = 0, 'modify to readable');

  // Write end has no data to read, so with 100ms timeout we should get timeout
  Check(platform_poller_wait(P, @LEntries[0], 4, 100, LCount) = 0, 'wait after modify');
  Check(LCount = 0, 'no readable events on write end');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;
{$ENDIF}

procedure TestUserData;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
  LTag: PtrUInt;
begin
  LTag := $DEADBEEF;
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], Pointer(LTag)) = 0, 'add with userdata');

  LBuf := 7;
  write(LPipeFd[1], @LBuf, 1);

  Check(platform_poller_wait(P, @LEntries[0], 4, 1000, LCount) = 0, 'wait');
  Check(LCount = 1, 'got event');
  Check(LEntries[0].Fd = PtrUInt(LPipeFd[0]), 'userdata event fd preserved');
  Check(PtrUInt(LEntries[0].UserData) = LTag, 'userdata preserved');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestMultipleFds;
var
  P: TPlatformPoller;
  LPipe1, LPipe2: array[0..1] of Int32;
  LEntries: array[0..7] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
begin
  Check(pipe(@LPipe1[0]) = 0, 'pipe1');
  Check(pipe(@LPipe2[0]) = 0, 'pipe2');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipe1[0], [peReadable], Pointer(PtrUInt(1))) = 0, 'add pipe1');
  Check(platform_poller_add(P, LPipe2[0], [peReadable], Pointer(PtrUInt(2))) = 0, 'add pipe2');

  LBuf := 1;
  write(LPipe1[1], @LBuf, 1);
  write(LPipe2[1], @LBuf, 1);

  Check(platform_poller_wait(P, @LEntries[0], 8, 1000, LCount) = 0, 'wait');
  Check(LCount = 2, 'got 2 events');

  close(LPipe1[0]); close(LPipe1[1]);
  close(LPipe2[0]); close(LPipe2[1]);
  platform_poller_close(P);
end;

procedure TestWaitCapacityBeyondLegacy64;
const
  FD_COUNT = 70;
var
  P: TPlatformPoller;
  LPipes: array[0..FD_COUNT - 1, 0..1] of Int32;
  LEntries: array[0..FD_COUNT - 1] of TPlatformPollEntry;
  LCount: Int32;
  LI: Int32;
  LBuf: Byte;
begin
  FillChar(LPipes, SizeOf(LPipes), $FF);
  Check(platform_poller_create(P) = 0, 'create');
  try
    LBuf := 1;
    for LI := 0 to FD_COUNT - 1 do
    begin
      Check(pipe(@LPipes[LI, 0]) = 0, 'pipe ' + IntToStr(LI));
      Check(platform_poller_add(P, LPipes[LI, 0], [peReadable],
        Pointer(PtrUInt(LI + 1))) = 0, 'add ' + IntToStr(LI));
      Check(write(LPipes[LI, 1], @LBuf, 1) = 1, 'write ' + IntToStr(LI));
    end;

    Check(platform_poller_wait(P, @LEntries[0], FD_COUNT, 1000, LCount) = 0,
      'wait beyond legacy 64');
    Check(LCount = FD_COUNT,
      'wait should honor AMaxEntries beyond the legacy fixed 64 buffer');
  finally
    platform_poller_close(P);
    for LI := 0 to FD_COUNT - 1 do
    begin
      if LPipes[LI, 0] >= 0 then
        close(LPipes[LI, 0]);
      if LPipes[LI, 1] >= 0 then
        close(LPipes[LI, 1]);
    end;
  end;
end;

procedure TestKqueueWakeSourceContract;
var
  LBaseSource: string;
  LIoSource: string;
  LKqueueSource: string;
  LCloseSource: string;
  LNonBlockingSource: string;
  LCloseOnExecSource: string;
  LEnableWakeSource: string;
  LWakeSource: string;
  LDrainWakeSource: string;
begin
  LBaseSource := LoadSourceText('src/nextpas.core.platform.io.base.pas');
  Check(Pos('wakereadfd: int32;', LBaseSource) > 0,
    'bsd/macOS poller should track wake read fd');
  Check(Pos('wakewritefd: int32;', LBaseSource) > 0,
    'bsd/macOS poller should track wake write fd');

  LIoSource := LoadSourceText('src/nextpas.core.platform.io.pas');
  LKqueueSource := ExtractKqueueRegion(LIoSource);

  LCloseSource := ExtractFunctionSource(LKqueueSource, 'platform_poller_close');
  Check(Pos('wakereadfd', LCloseSource) > 0,
    'kqueue close should release wake read fd');
  Check(Pos('wakewritefd', LCloseSource) > 0,
    'kqueue close should release wake write fd');

  LNonBlockingSource := ExtractFunctionSource(LKqueueSource, 'setfdnonblocking');
  Check(Pos('f_setfl', LNonBlockingSource) > 0,
    'kqueue wake helper should set nonblocking mode');
  Check(Pos('o_nonblock', LNonBlockingSource) > 0,
    'kqueue wake helper should use O_NONBLOCK');

  LCloseOnExecSource := ExtractFunctionSource(LKqueueSource, 'setfdcloseonexec');
  Check(Pos('f_setfd', LCloseOnExecSource) > 0,
    'kqueue wake helper should set close-on-exec');
  Check(Pos('fd_cloexec', LCloseOnExecSource) > 0,
    'kqueue wake helper should use FD_CLOEXEC');

  LEnableWakeSource := ExtractFunctionSource(LKqueueSource,
    'platform_poller_enable_wake');
  Check(Pos('result := -1;', LEnableWakeSource) = 0,
    'kqueue enable wake should not remain a stub');
  Check(Pos('pipe(@', LEnableWakeSource) > 0,
    'kqueue enable wake should create a self-pipe');
  Check(Pos('setfdnonblocking', LEnableWakeSource) > 0,
    'kqueue enable wake should call the nonblocking helper');
  Check(Pos('setfdcloseonexec', LEnableWakeSource) > 0,
    'kqueue enable wake should call the close-on-exec helper');
  Check(Pos('platform_poller_add', LEnableWakeSource) > 0,
    'kqueue enable wake should register the read end');

  LWakeSource := ExtractFunctionSource(LKqueueSource, 'platform_poller_wake');
  Check(Pos('result := -1;', LWakeSource) = 0,
    'kqueue wake should not remain a stub');
  Check(Pos('write(', LWakeSource) > 0,
    'kqueue wake should signal through write');
  Check(Pos('wakewritefd', LWakeSource) > 0,
    'kqueue wake should use the write end');

  LDrainWakeSource := ExtractFunctionSource(LKqueueSource,
    'platform_poller_drain_wake');
  Check(Pos('result := -1;', LDrainWakeSource) = 0,
    'kqueue drain wake should not remain a stub');
  Check(Pos('read(', LDrainWakeSource) > 0,
    'kqueue drain wake should read until empty');
  Check(Pos('esyseagain', LDrainWakeSource) > 0,
    'kqueue drain wake should tolerate EAGAIN');
end;

procedure TestPollerWaitCapacitySourceContract;
var
  LIoSource: string;
  LWaitSource: string;
  LKqueueSource: string;
  LKqueueWaitSource: string;
begin
  LIoSource := LoadSourceText('src/nextpas.core.platform.io.pas');

  LWaitSource := ExtractFunctionSource(LIoSource, 'platform_poller_wait');
  CheckAbsent(LWaitSource, 'array[0..63]',
    'linux wait must not use a fixed 64-event buffer');
  CheckAbsent(LWaitSource, 'if lmax > 64',
    'linux wait must not silently clamp AMaxEntries to 64');
  CheckContains(LWaitSource, 'amaxentries',
    'linux wait should size native event storage from AMaxEntries');

  LKqueueSource := ExtractKqueueRegion(LIoSource);
  LKqueueWaitSource := ExtractFunctionSource(LKqueueSource,
    'platform_poller_wait');
  CheckAbsent(LKqueueWaitSource, 'array[0..63]',
    'kqueue wait must not use a fixed 64-event buffer');
  CheckAbsent(LKqueueWaitSource, 'if lmax > 64',
    'kqueue wait must not silently clamp AMaxEntries to 64');
  CheckContains(LKqueueWaitSource, 'amaxentries',
    'kqueue wait should size native event storage from AMaxEntries');
end;

procedure TestWindowsPollerSourceContract;
var
  LBaseSource: string;
  LIoSource: string;
  LWindowsSource: string;
  LFfiSource: string;
  LCreateSource: string;
  LAddSource: string;
  LEnableWakeSource: string;
  LWakeSource: string;
  LDrainWakeSource: string;
  LWaitSource: string;
begin
  LBaseSource := LoadSourceText('src/nextpas.core.platform.io.base.pas');
  CheckContains(LBaseSource, 'fd: ptruint;',
    'poll entries must preserve full native socket handle width');
  CheckContains(LBaseSource, 'wakereadsocket: ptruint;',
    'windows poller should track wake read socket');
  CheckContains(LBaseSource, 'wakewritesocket: ptruint;',
    'windows poller should track wake write socket');

  LFfiSource := LoadSourceText(
    'src/nextpas.core.platform.windows.ffi.winsock2.inc');
  CheckContains(LFfiSource, 'function wsapoll',
    'windows readiness fallback should import WSAPoll through nextPas FFI');

  LIoSource := LoadSourceText('src/nextpas.core.platform.io.pas');
  CheckContains(LIoSource, 'afd: ptruint',
    'poller add/modify/remove signatures should accept native-width handles');

  LWindowsSource := ExtractWindowsRegion(LIoSource);
  LCreateSource := ExtractFunctionSource(LWindowsSource,
    'platform_poller_create');
  CheckAbsent(LCreateSource, 'result := -1',
    'windows poller create must not remain a stub');
  CheckContains(LWindowsSource, 'wsastartup',
    'windows poller implementation should initialize Winsock');
  CheckContains(LCreateSource, 'ensurewinsockready',
    'windows poller create should go through the Winsock init helper');

  LAddSource := ExtractFunctionSource(LWindowsSource, 'platform_poller_add');
  CheckAbsent(LAddSource, 'result := -1',
    'windows poller add must not remain a stub');

  LEnableWakeSource := ExtractFunctionSource(LWindowsSource,
    'platform_poller_enable_wake');
  CheckAbsent(LEnableWakeSource, 'result := -1',
    'windows enable wake must not remain a stub');
  CheckContains(LWindowsSource, 'winsock_socket',
    'windows wake should create sockets through Winsock FFI');
  CheckContains(LWindowsSource, 'winsock_connect',
    'windows wake should connect a loopback wake pair');
  CheckContains(LWindowsSource, 'winsock_accept',
    'windows wake should accept a loopback wake pair');
  CheckContains(LEnableWakeSource, 'windowscreatewakepair',
    'windows enable wake should delegate to the wake-pair helper');
  CheckContains(LEnableWakeSource, 'platform_poller_add',
    'windows wake should register the read socket');

  LWakeSource := ExtractFunctionSource(LWindowsSource, 'platform_poller_wake');
  CheckAbsent(LWakeSource, 'result := -1',
    'windows wake must not remain a stub');
  CheckContains(LWakeSource, 'winsock_send',
    'windows wake should signal with send');

  LDrainWakeSource := ExtractFunctionSource(LWindowsSource,
    'platform_poller_drain_wake');
  CheckAbsent(LDrainWakeSource, 'result := -1',
    'windows drain wake must not remain a stub');
  CheckContains(LDrainWakeSource, 'winsock_recv',
    'windows drain wake should drain with recv');

  LWaitSource := ExtractFunctionSource(LWindowsSource, 'platform_poller_wait');
  CheckAbsent(LWaitSource, 'result := -1',
    'windows wait must not remain a stub');
  CheckContains(LWaitSource, 'wsapoll',
    'windows wait should use a real readiness API');
  CheckContains(LWaitSource, 'amaxentries',
    'windows wait should honor caller-provided max entries');
end;

procedure TestReadinessServerPollerSourceContract;
var
  LReadinessSource: string;
  LRuntimeSource: string;
begin
  LReadinessSource := LoadSourceText('src/nextpas.core.net.server.readiness.pas');
  CheckAbsent(LReadinessSource, 'sizeof(lentries)',
    'readiness server must pass entry count, not byte size, to poller wait');
  CheckContains(LReadinessSource, 'length(lentries)',
    'readiness server should pass the static array entry count');
  CheckAbsent(LReadinessSource, 'int32(flistenersocketruntime.nativesockethandle)',
    'readiness server must not truncate listener socket handles');

  LRuntimeSource := LoadSourceText('src/nextpas.core.net.server.runtime.pas');
  CheckContains(LRuntimeSource, 'function sockethandle: ptruint',
    'poll session target socket handle should be native-width');
  CheckAbsent(LRuntimeSource, 'result := int32(fsocketruntime.nativesockethandle)',
    'poll session target socket handle must not truncate native handles');
end;

procedure TestAsyncLoopWakeSourceContract;
var
  LAsyncLoopSource: string;
begin
  LAsyncLoopSource := LoadSourceText('src/nextpas.core.async.loop.pas');

  CheckAbsent(LAsyncLoopSource, 'nextpas.core.platform.linux.base',
    'async loop must not directly depend on Linux wake constants');
  CheckAbsent(LAsyncLoopSource, 'nextpas.core.platform.linux.ffi',
    'async loop must not directly depend on Linux wake ffi');
  CheckAbsent(LAsyncLoopSource, 'eventfd(',
    'async loop wake creation must live behind platform.io');
  CheckAbsent(LAsyncLoopSource, 'poll(@lpfd',
    'async loop sleep must use platform poller wake wait');
  CheckAbsent(LAsyncLoopSource, 'fwakefd',
    'async loop must not own a raw Linux wake fd');
  CheckContains(LAsyncLoopSource, 'nextpas.core.platform.io',
    'async loop should consume the unified platform.io wake seam');
  CheckContains(LAsyncLoopSource, 'platform_poller_enable_wake',
    'async loop should enable wake through platform.io');
  CheckContains(LAsyncLoopSource, 'platform_poller_wake',
    'async loop should wake through platform.io');
  CheckContains(LAsyncLoopSource, 'platform_poller_wait',
    'async loop should sleep through platform.io');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestWakeDrain;
var
  P: TPlatformPoller;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LWakeTag: PtrUInt;
begin
  LWakeTag := $A11CE;
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_enable_wake(P, Pointer(LWakeTag)) = 0,
    'enable wake');
  Check(platform_poller_wake(P) = 0, 'wake');

  Check(platform_poller_wait(P, @LEntries[0], 4, 1000, LCount) = 0, 'wait');
  Check(LCount = 1, 'got 1 wake event');
  Check(LEntries[0].Fd = PtrUInt(P.WakeFd), 'wake fd preserved');
  Check(peReadable in LEntries[0].REvents, 'wake event is readable');
  Check(PtrUInt(LEntries[0].UserData) = LWakeTag, 'wake userdata preserved');

  Check(platform_poller_drain_wake(P) = 0, 'drain wake');
  Check(platform_poller_wait(P, @LEntries[0], 4, 0, LCount) = 0,
    'wait after drain');
  Check(LCount = 0, 'wake drain clears readiness');

  platform_poller_close(P);
end;
{$ENDIF}

{ Error path tests }
{$IFDEF NEXTPAS_LINUX}
procedure TestRemoveNonExistentFd;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LRet: Int32;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');

  { Remove fd that was never added should return error }
  LRet := platform_poller_remove(P, LPipeFd[0]);
  Check(LRet <> 0, 'remove non-existent fd returns error');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestModifyNonExistentFd;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LRet: Int32;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');

  { Modify fd that was never added should return error }
  LRet := platform_poller_modify(P, LPipeFd[0], [peReadable], nil);
  Check(LRet <> 0, 'modify non-existent fd returns error');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestWaitZeroMaxEntries;
var
  P: TPlatformPoller;
  LPipeFd: array[0..1] of Int32;
  LEntries: array[0..3] of TPlatformPollEntry;
  LCount: Int32;
  LBuf: Byte;
begin
  Check(pipe(@LPipeFd[0]) = 0, 'pipe');
  Check(platform_poller_create(P) = 0, 'create');
  Check(platform_poller_add(P, LPipeFd[0], [peReadable], nil) = 0, 'add');

  LBuf := 1;
  write(LPipeFd[1], @LBuf, 1);

  { Wait with 1 max entry and 0 timeout should return 1 event }
  Check(platform_poller_wait(P, @LEntries[0], 1, 0, LCount) = 0, 'wait one max');
  Check(LCount = 1, 'got 1 event with one max entries');

  close(LPipeFd[0]);
  close(LPipeFd[1]);
  platform_poller_close(P);
end;

procedure TestWakeWithoutEnable;
var
  P: TPlatformPoller;
  LRet: Int32;
begin
  Check(platform_poller_create(P) = 0, 'create');

  { Wake without enable should return error }
  LRet := platform_poller_wake(P);
  Check(LRet <> 0, 'wake without enable returns error');

  platform_poller_close(P);
end;

procedure TestDrainWakeWithoutEnable;
var
  P: TPlatformPoller;
  LRet: Int32;
begin
  Check(platform_poller_create(P) = 0, 'create');

  { Drain wake without enable should return error }
  LRet := platform_poller_drain_wake(P);
  Check(LRet <> 0, 'drain wake without enable returns error');

  platform_poller_close(P);
end;
{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.platform.io');
  T.Test('create/close', @TestCreateClose);
  T.Test('double close', @TestDoubleClose);
  T.Test('pipe readable', @TestPipeReadable);
  T.Test('timeout zero', @TestTimeoutZero);
  T.Test('remove stops events', @TestRemove);
  {$IFDEF NEXTPAS_LINUX}
  T.Test('modify events', @TestModify);
  {$ENDIF}
  T.Test('userdata preserved', @TestUserData);
  T.Test('multiple fds', @TestMultipleFds);
  T.Test('wait capacity beyond 64', @TestWaitCapacityBeyondLegacy64);
  T.Test('kqueue wake source contract', @TestKqueueWakeSourceContract);
  T.Test('poller wait capacity source contract', @TestPollerWaitCapacitySourceContract);
  T.Test('windows poller source contract', @TestWindowsPollerSourceContract);
  T.Test('readiness server poller source contract', @TestReadinessServerPollerSourceContract);
  T.Test('async loop wake source contract', @TestAsyncLoopWakeSourceContract);
  {$IFDEF NEXTPAS_LINUX}
  T.Test('wake drain', @TestWakeDrain);
  T.Test('remove non-existent fd', @TestRemoveNonExistentFd);
  T.Test('modify non-existent fd', @TestModifyNonExistentFd);
  T.Test('wait zero max entries', @TestWaitZeroMaxEntries);
  T.Test('wake without enable', @TestWakeWithoutEnable);
  T.Test('drain wake without enable', @TestDrainWakeWithoutEnable);
  {$ENDIF}
  if not T.Run then Halt(1);
end.

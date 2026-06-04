program test_platform_io;

{$I nextpas.core.settings.inc}

uses
  Classes,
  SysUtils,
  nextpas.core.platform.io.base,
  nextpas.core.platform.io,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

function ExpandRepoPath(const ARelativePath: string): string;
begin
  Result := ExpandFileName('../../../' + ARelativePath);
end;

function LoadSourceText(const ARelativePath: string): string;
var
  LSourcePath: string;
  LLines: TStringList;
begin
  LSourcePath := ExpandRepoPath(ARelativePath);
  Check(FileExists(LSourcePath), 'source file should exist: ' + LSourcePath);
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LSourcePath);
    Result := LowerCase(LLines.Text);
  finally
    LLines.Free;
  end;
end;

function ExtractFunctionSource(const ASource, AName: string): string;
var
  LLines: TStringList;
  LLine: string;
  LFound: Boolean;
  LHasBody: Boolean;
  LIndex: Integer;
  LDeleteLen: Integer;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := ASource;
    LFound := False;
    LHasBody := False;
    for LIndex := 0 to LLines.Count - 1 do
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
  finally
    LLines.Free;
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
  Check(peReadable in LEntries[0].REvents, 'wake event is readable');
  Check(PtrUInt(LEntries[0].UserData) = LWakeTag, 'wake userdata preserved');

  Check(platform_poller_drain_wake(P) = 0, 'drain wake');
  Check(platform_poller_wait(P, @LEntries[0], 4, 0, LCount) = 0,
    'wait after drain');
  Check(LCount = 0, 'wake drain clears readiness');

  platform_poller_close(P);
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.io');
  T.Run('create/close', @TestCreateClose);
  T.Run('double close', @TestDoubleClose);
  T.Run('pipe readable', @TestPipeReadable);
  T.Run('timeout zero', @TestTimeoutZero);
  T.Run('remove stops events', @TestRemove);
  T.Run('userdata preserved', @TestUserData);
  T.Run('multiple fds', @TestMultipleFds);
  T.Run('kqueue wake source contract', @TestKqueueWakeSourceContract);
  {$IFDEF NEXTPAS_LINUX}
  T.Run('wake drain', @TestWakeDrain);
  {$ENDIF}
  T.Summary;
end.

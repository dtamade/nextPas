program test_ssh_e2e_async;
{$mode ObjFPC}{$H+}
{
  live-sshd E2E Async (opt-in) — 对真实 OpenSSH 服务器的 Async 互操作验证。
  与 test_ssh_e2e.lpr 同输入 (环境变量), 走 TAsyncLoop + SshAsync* 全事件化路径。
}
uses
  cthreads, Classes, SysUtils,
  nextpas.core.async.loop,
  nextpas.core.ssh,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.sftp.async,
  nextpas.core.ssh.session.async;

const
  MARKER = 'np-e2e-async-9c4a-marker';

var
  GFail: Integer = 0;
  GJumpRan: Boolean = False;

procedure Fail(const AMsg: string);
begin
  Writeln('[e2e-async]   FAIL: ', AMsg);
  Inc(GFail);
end;

function EnvOr(const AName, ADef: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result = '' then Result := ADef;
end;

type
  PAsyncConn = ^TAsyncConn;
  TAsyncConn = record
    Session: ISshAsyncSession;
    Err: ESSHError;
    Done: Boolean;
    Event: PRTLEvent;
  end;

  PAsyncExec = ^TAsyncExec;
  TAsyncExec = record
    Result: TSshExecResult;
    Err: ESSHError;
    Done: Boolean;
    Event: PRTLEvent;
  end;

  PAsyncSftp = ^TAsyncSftp;
  TAsyncSftp = record
    Fs: ISshAsyncFileSystem;
    Err: ESSHError;
    Done: Boolean;
    Event: PRTLEvent;
  end;

  PSftpReal = ^TSftpReal;
  TSftpReal = record
    Path: string;
    Err: ESSHError;
    Done: Boolean;
    Event: PRTLEvent;
  end;

procedure AsyncConnCb(ASession: ISshAsyncSession; AErr: ESSHError; AContext: Pointer);
var P: PAsyncConn;
begin
  P := PAsyncConn(AContext);
  P^.Session := ASession;
  P^.Err := AErr;
  P^.Done := True;
  if P^.Event <> nil then RTLeventSetEvent(P^.Event);
end;

procedure AsyncExecCb(const ARes: TSshExecResult; AErr: ESSHError; AContext: Pointer);
var P: PAsyncExec;
begin
  P := PAsyncExec(AContext);
  P^.Result := ARes;
  P^.Err := AErr;
  P^.Done := True;
  if P^.Event <> nil then RTLeventSetEvent(P^.Event);
end;

procedure AsyncSftpCb(AFs: ISshAsyncFileSystem; AErr: ESSHError; AContext: Pointer);
var P: PAsyncSftp;
begin
  P := PAsyncSftp(AContext);
  P^.Fs := AFs;
  P^.Err := AErr;
  P^.Done := True;
  if P^.Event <> nil then RTLeventSetEvent(P^.Event);
end;

procedure AsyncRealCb(const APath: string; AErr: ESSHError; AContext: Pointer);
var P: PSftpReal;
begin
  P := PSftpReal(AContext);
  P^.Path := APath;
  P^.Err := AErr;
  P^.Done := True;
  if P^.Event <> nil then RTLeventSetEvent(P^.Event);
end;

function WaitFlag(var ADone: Boolean; AEvent: PRTLEvent; ATimeoutMs: Integer): Boolean;
var LStart: QWord;
begin
  LStart := GetTickCount64;
  while not ADone do
  begin
    if GetTickCount64 - LStart > UInt64(ATimeoutMs) then Exit(False);
    RTLeventWaitFor(AEvent, 20);
  end;
  Result := True;
end;

function BuildOpts(const AHost, AUser, AKeyFile, APassphrase, AKnownHosts: string): TSshConnectOptions;
var LKey: TStringList;
begin
  Result := DefaultSshConnectOptions(AHost);
  Result.Host := AHost;
  Result.Port := Word(StrToIntDef(EnvOr('NEXTPAS_SSH_E2E_PORT', '22'), 22));
  Result.User := AUser;
  Result.KnownHostsFile := AKnownHosts;
  Result.StrictHostKeyChecking := AKnownHosts <> '';
  Result.ExecTimeoutMs := 30000;
  Result.ConnectTimeoutMs := 10000;
  if AKeyFile <> '' then
  begin
    LKey := TStringList.Create;
    try
      LKey.LoadFromFile(AKeyFile);
      Result.PrivateKeyData := LKey.Text;
    finally LKey.Free; end;
  end;
  if APassphrase <> '' then Result.PrivateKeyPassphrase := APassphrase;
end;

type
  TLoopThread = class(TThread)
  private
    FLoop: TAsyncLoop;
  protected
    procedure Execute; override;
  public
    constructor Create(ALoop: TAsyncLoop);
  end;

constructor TLoopThread.Create(ALoop: TAsyncLoop);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLoop := ALoop;
end;

procedure TLoopThread.Execute;
begin
  FLoop.Run;
end;

var
  GLoop: TAsyncLoop;
  GLoopThread: TLoopThread;

procedure EnsureLoop;
begin
  if GLoop = nil then
  begin
    GLoop := TAsyncLoop.Create(128);
    GLoopThread := TLoopThread.Create(GLoop);
    GLoopThread.Start;
  end;
end;

procedure ShutdownLoop;
begin
  if GLoop <> nil then
  begin
    GLoop.Stop;
    GLoopThread.WaitFor;
    GLoopThread.Free;
    GLoop.Free;
    GLoop := nil;
    GLoopThread := nil;
  end;
end;

function AsyncConnectWithLoop(const AKnownHosts, AKeyFile, APassphrase: string; out ASession: ISshAsyncSession): Boolean;
var Ctx: TAsyncConn; Opts: TSshConnectOptions;
begin
  EnsureLoop;
  Ctx.Session := nil; Ctx.Err := nil; Ctx.Done := False; Ctx.Event := RTLeventCreate;
  Opts := BuildOpts(EnvOr('NEXTPAS_SSH_E2E_HOST', '127.0.0.1'), EnvOr('NEXTPAS_SSH_E2E_USER', 'root'), AKeyFile, APassphrase, AKnownHosts);
  Result := False; ASession := nil;
  if not SshAsyncConnect(GLoop, Opts, @AsyncConnCb, @Ctx) then begin RTLeventDestroy(Ctx.Event); Exit; end;
  if not WaitFlag(Ctx.Done, Ctx.Event, 15000) then begin RTLeventDestroy(Ctx.Event); if Ctx.Err <> nil then Ctx.Err.Free; Exit; end;
  RTLeventDestroy(Ctx.Event);
  if Ctx.Err <> nil then begin Ctx.Err.Free; Exit; end;
  ASession := Ctx.Session;
  Result := ASession <> nil;
end;

function AsyncExec(const ASession: ISshAsyncSession; const ACmd: string; out ARes: TSshExecResult; out AErr: ESSHError): Boolean;
var Ctx: TAsyncExec;
begin
  Ctx.Done := False; Ctx.Event := RTLeventCreate; Ctx.Err := nil;
  if not ASession.ExecAsync(ACmd, @AsyncExecCb, @Ctx) then begin RTLeventDestroy(Ctx.Event); Exit(False); end;
  if not WaitFlag(Ctx.Done, Ctx.Event, 30000) then begin RTLeventDestroy(Ctx.Event); Exit(False); end;
  RTLeventDestroy(Ctx.Event);
  ARes := Ctx.Result; AErr := Ctx.Err; Result := True;
end;

procedure ScenarioAsyncExecTwice;
var Sess: ISshAsyncSession; Res1, Res2: TSshExecResult; Err: ESSHError;
begin
  Writeln('[e2e-async] scenario: exec marker + second exec on same session');
  if not AsyncConnectWithLoop(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''), EnvOr('NEXTPAS_SSH_E2E_KEYFILE', ''), '', Sess) then begin Fail('async connect failed'); Exit; end;
  try
    if not AsyncExec(Sess, 'echo ' + MARKER, Res1, Err) then begin Fail('exec#1 submit failed'); Exit; end;
    if Err <> nil then begin Fail(SshErrorKindName(Err.Kind) + ': ' + Err.Message); Err.Free; Exit; end;
    if Pos(MARKER, Res1.StdOutText) = 0 then Fail('stdout missing marker, got "' + Trim(Res1.StdOutText) + '"')
    else if Res1.ExitCode <> 0 then Fail('expected exit 0, got ' + IntToStr(Res1.ExitCode))
    else Writeln('[e2e-async]   ok: exec#1 stdout=', Trim(Res1.StdOutText));
    if not AsyncExec(Sess, 'printf %s two', Res2, Err) then begin Fail('exec#2 submit failed'); Exit; end;
    if Err <> nil then begin Fail(SshErrorKindName(Err.Kind) + ': ' + Err.Message); Err.Free; Exit; end;
    if Trim(Res2.StdOutText) <> 'two' then Fail('exec#2 stdout got "' + Trim(Res2.StdOutText) + '"')
    else Writeln('[e2e-async]   ok: exec#2 stdout=', Trim(Res2.StdOutText));
  finally Sess.Close; end;
end;

procedure ScenarioAsyncSftpMinimal;
var Sess: ISshAsyncSession; Sftp: ISshAsyncFileSystem; Ctx: TAsyncSftp; Real: TSftpReal;
begin
  Writeln('[e2e-async] scenario: sftp realpath via async');
  if not AsyncConnectWithLoop(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''), EnvOr('NEXTPAS_SSH_E2E_KEYFILE', ''), '', Sess) then begin Fail('async connect failed'); Exit; end;
  try
    Ctx.Done := False; Ctx.Event := RTLeventCreate; Ctx.Fs := nil; Ctx.Err := nil;
    if not SshAsyncOpenSftp(Sess, @AsyncSftpCb, @Ctx) then begin RTLeventDestroy(Ctx.Event); Fail('sftp open submit failed'); Exit; end;
    if not WaitFlag(Ctx.Done, Ctx.Event, 15000) then begin RTLeventDestroy(Ctx.Event); Fail('sftp open timeout'); Exit; end;
    RTLeventDestroy(Ctx.Event);
    if Ctx.Err <> nil then begin Fail(SshErrorKindName(Ctx.Err.Kind) + ': ' + Ctx.Err.Message); Ctx.Err.Free; Exit; end;
    Sftp := Ctx.Fs;
    try
      Real.Done := False; Real.Event := RTLeventCreate; Real.Err := nil;
      if not Sftp.RealPathAsync('.', @AsyncRealCb, @Real) then begin RTLeventDestroy(Real.Event); Fail('realpath submit failed'); Exit; end;
      if not WaitFlag(Real.Done, Real.Event, 15000) then begin RTLeventDestroy(Real.Event); Fail('realpath timeout'); Exit; end;
      RTLeventDestroy(Real.Event);
      if Real.Err <> nil then begin Fail(SshErrorKindName(Real.Err.Kind) + ': ' + Real.Err.Message); Real.Err.Free; Exit; end;
      if Real.Path = '' then Fail('realpath empty') else Writeln('[e2e-async]   ok: realpath=', Real.Path);
    finally Sftp.Close; end;
  finally Sess.Close; end;
end;

procedure ScenarioAsyncExitCode;
var Sess: ISshAsyncSession; Res: TSshExecResult; Err: ESSHError;
begin
  Writeln('[e2e-async] scenario: remote exit code passthrough');
  if not AsyncConnectWithLoop(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''), EnvOr('NEXTPAS_SSH_E2E_KEYFILE', ''), '', Sess) then begin Fail('async connect failed'); Exit; end;
  try
    if not AsyncExec(Sess, 'exit 7', Res, Err) then begin Fail('exec submit failed'); Exit; end;
    if Err <> nil then begin Fail(SshErrorKindName(Err.Kind) + ': ' + Err.Message); Err.Free; Exit; end;
    if Res.ExitCode <> 7 then Fail('expected exit 7, got ' + IntToStr(Res.ExitCode)) else Writeln('[e2e-async]   ok: exit=', Res.ExitCode);
  finally Sess.Close; end;
end;

procedure ScenarioAsyncWrongHostKey;
var LBogus: TStringList; Ctx: TAsyncConn; Opts: TSshConnectOptions; LKey: TStringList; TmpFile: string;
begin
  Writeln('[e2e-async] scenario: mismatched known_hosts rejected (pre-auth)');
  TmpFile := GetEnvironmentVariable('TMPDIR');
  if TmpFile = '' then TmpFile := '/tmp';
  TmpFile := TmpFile + '/np_e2e_async_bogus_known_hosts';
  LBogus := TStringList.Create;
  try LBogus.Add(EnvOr('NEXTPAS_SSH_E2E_HOST', '127.0.0.1') + ' ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoGx7j9VbXJb3vBhXqOaEfDcT5wK2mZyUd8nQ4pLxE'); LBogus.SaveToFile(TmpFile); finally LBogus.Free; end;
  EnsureLoop;
  Ctx.Session := nil; Ctx.Err := nil; Ctx.Done := False; Ctx.Event := RTLeventCreate;
  Opts := DefaultSshConnectOptions(EnvOr('NEXTPAS_SSH_E2E_HOST', '127.0.0.1'));
  Opts.Host := EnvOr('NEXTPAS_SSH_E2E_HOST', '127.0.0.1'); Opts.Port := Word(StrToIntDef(EnvOr('NEXTPAS_SSH_E2E_PORT', '22'), 22));
  Opts.User := EnvOr('NEXTPAS_SSH_E2E_USER', 'root'); Opts.KnownHostsFile := TmpFile; Opts.StrictHostKeyChecking := True; Opts.ExecTimeoutMs := 30000;
  LKey := TStringList.Create; try LKey.LoadFromFile(EnvOr('NEXTPAS_SSH_E2E_KEYFILE', '')); Opts.PrivateKeyData := LKey.Text; finally LKey.Free; end;
  if not SshAsyncConnect(GLoop, Opts, @AsyncConnCb, @Ctx) then begin RTLeventDestroy(Ctx.Event); Fail('async connect submit failed'); Exit; end;
  if not WaitFlag(Ctx.Done, Ctx.Event, 15000) then begin RTLeventDestroy(Ctx.Event); Fail('timeout'); if Ctx.Err <> nil then Ctx.Err.Free; Exit; end;
  RTLeventDestroy(Ctx.Event);
  if Ctx.Err = nil then begin Fail('connect succeeded with wrong host key'); if Ctx.Session <> nil then Ctx.Session.Close; end
  else if Ctx.Err.Kind = sekHostKey then begin Writeln('[e2e-async]   ok: rejected with ', SshErrorKindName(Ctx.Err.Kind)); Ctx.Err.Free; end
  else begin Fail('wrong error kind: ' + SshErrorKindName(Ctx.Err.Kind)); Ctx.Err.Free; end;
end;

procedure ScenarioAsyncViaJump;
var JumpHost, JumpUser, JumpKey, TargetHost, TargetUser, TargetKey: string;
    JumpOpts, TargetOpts: TSshConnectOptions; Sess: ISshAsyncSession; Ctx: TAsyncConn; Res: TSshExecResult; Err: ESSHError;
begin
  JumpHost := EnvOr('NEXTPAS_SSH_E2E_JUMP_HOST', ''); if JumpHost = '' then begin Writeln('[e2e-async] scenario: via jump — SKIP (no JUMP_HOST)'); Exit; end;
  GJumpRan := True;
  Writeln('[e2e-async] scenario: async via jump exec');
  JumpUser := EnvOr('NEXTPAS_SSH_E2E_JUMP_USER', 'root');
  JumpKey := EnvOr('NEXTPAS_SSH_E2E_JUMP_KEYFILE', EnvOr('NEXTPAS_SSH_E2E_KEYFILE', ''));
  TargetHost := EnvOr('NEXTPAS_SSH_E2E_HOST', '127.0.0.1');
  TargetUser := EnvOr('NEXTPAS_SSH_E2E_USER', 'root');
  TargetKey := EnvOr('NEXTPAS_SSH_E2E_KEYFILE', '');
  JumpOpts := BuildOpts(JumpHost, JumpUser, JumpKey, '', EnvOr('NEXTPAS_SSH_E2E_JUMP_KNOWN_HOSTS', EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', '')));
  TargetOpts := BuildOpts(TargetHost, TargetUser, TargetKey, '', EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''));
  JumpOpts.Port := Word(StrToIntDef(EnvOr('NEXTPAS_SSH_E2E_JUMP_PORT', '22'), 22));
  TargetOpts.Port := Word(StrToIntDef(EnvOr('NEXTPAS_SSH_E2E_PORT', '22'), 22));
  EnsureLoop;
  Ctx.Session := nil; Ctx.Err := nil; Ctx.Done := False; Ctx.Event := RTLeventCreate;
  if not SshAsyncConnectViaJump(GLoop, JumpOpts, TargetOpts, @AsyncConnCb, @Ctx) then begin RTLeventDestroy(Ctx.Event); Fail('via jump submit failed'); Exit; end;
  if not WaitFlag(Ctx.Done, Ctx.Event, 20000) then begin RTLeventDestroy(Ctx.Event); Fail('via jump timeout'); if Ctx.Err <> nil then Ctx.Err.Free; Exit; end;
  RTLeventDestroy(Ctx.Event);
  if Ctx.Err <> nil then begin Fail(SshErrorKindName(Ctx.Err.Kind) + ': ' + Ctx.Err.Message); Ctx.Err.Free; Exit; end;
  Sess := Ctx.Session;
  try
    if not AsyncExec(Sess, 'echo ' + MARKER, Res, Err) then begin Fail('exec submit failed'); Exit; end;
    if Err <> nil then begin Fail(SshErrorKindName(Err.Kind) + ': ' + Err.Message); Err.Free; Exit; end;
    if Pos(MARKER, Res.StdOutText) = 0 then Fail('via jump stdout missing marker, got "' + Trim(Res.StdOutText) + '"') else Writeln('[e2e-async]   ok: via jump exec marker');
  finally Sess.Close; end;
end;

begin
  try
    Writeln('[e2e-async] live target: ', EnvOr('NEXTPAS_SSH_E2E_USER', 'root'), '@', EnvOr('NEXTPAS_SSH_E2E_HOST', ''), ':', EnvOr('NEXTPAS_SSH_E2E_PORT', '22'));
    ScenarioAsyncExecTwice;
    ScenarioAsyncExitCode;
    ScenarioAsyncWrongHostKey;
    ScenarioAsyncSftpMinimal;
    ScenarioAsyncViaJump;
    ShutdownLoop;
    if GFail = 0 then Writeln('[e2e-async] PASS (', 4 + Ord(GJumpRan), ' scenarios)')
    else Writeln('[e2e-async] FAILED: ', GFail, ' failure(s)');
    ExitCode := Ord(GFail > 0);
  except on E: Exception do begin Writeln('[e2e-async] FATAL: ', E.ClassName, ': ', E.Message); ExitCode := 1; end; end;
end.

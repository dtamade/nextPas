program test_ssh_e2e;
{$mode ObjFPC}{$H+}
{
  live-sshd E2E（opt-in，环境变量门控）——对真实 OpenSSH 服务器的互操作验证。

  必需环境变量：
    NEXTPAS_SSH_E2E_HOST       主机名 / IP
    NEXTPAS_SSH_E2E_USER       登录用户
    NEXTPAS_SSH_E2E_KEYFILE    未加密 OpenSSH ed25519 私钥文件路径
  可选：
    NEXTPAS_SSH_E2E_PORT       默认 22
    NEXTPAS_SSH_E2E_KNOWN_HOSTS  known_hosts 文件（缺省则不做严格校验）

  场景：exec stdout/exit 码、stderr 分流、同会话多次 exec、
        错误 known_hosts 必须被 sekHostKey 拒绝。
  由 run_e2e.sh 编排（remote 直连 / local sshd fixture）；本程序不做门控。
}
uses
  nextpas.core.system.sysutils, Classes,
  nextpas.core.ssh,
  nextpas.core.ssh.errors;

const
  MARKER = 'np-e2e-7f3d-marker';

var
  GFail: Integer = 0;

procedure Fail(const AMsg: string);
begin
  Writeln('[e2e]   FAIL: ', AMsg);
  Inc(GFail);
end;

function EnvOr(const AName, ADef: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result = '' then
    Result := ADef;
end;

function ConnectE2E(const AKnownHosts: string): ISshSession;
var
  LBuilder: ISshClientBuilder;
  LKey: TStringList;
begin
  LBuilder := SshClient
    .Host(EnvOr('NEXTPAS_SSH_E2E_HOST', '127.0.0.1'))
    .Port(Word(StrToIntDef(EnvOr('NEXTPAS_SSH_E2E_PORT', '22'), 22)))
    .User(EnvOr('NEXTPAS_SSH_E2E_USER', 'root'))
    .KnownHostsFile(AKnownHosts)
    .StrictHostKey(AKnownHosts <> '')
    .ExecTimeoutMs(30000);
  LKey := TStringList.Create;
  try
    LKey.LoadFromFile(EnvOr('NEXTPAS_SSH_E2E_KEYFILE', ''));
    LBuilder := LBuilder.PrivateKeyData(LKey.Text);
  finally
    LKey.Free;
  end;
  Result := LBuilder.Connect;
end;

{ 场景 1：exec 收 stdout、exit=0，且同一会话连续两次 exec }
procedure ScenarioExecTwice;
var
  LSess: ISshSession;
  LR1, LR2: TSshExecResult;
begin
  Writeln('[e2e] scenario: exec marker + second exec on same session');
  try
    LSess := ConnectE2E(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''));
    try
      LR1 := LSess.Exec('echo ' + MARKER);
      if Pos(MARKER, LR1.StdOutText) = 0 then
        Fail('stdout missing marker, got "' + Trim(LR1.StdOutText) + '"')
      else if LR1.ExitCode <> 0 then
        Fail('expected exit 0, got ' + IntToStr(LR1.ExitCode))
      else
        Writeln('[e2e]   ok: exec#1 stdout=', Trim(LR1.StdOutText),
          ' exit=', LR1.ExitCode);

      LR2 := LSess.Exec('printf %s two');
      if Trim(LR2.StdOutText) <> 'two' then
        Fail('exec#2 stdout got "' + Trim(LR2.StdOutText) + '"')
      else if LR2.ExitCode <> 0 then
        Fail('exec#2 expected exit 0, got ' + IntToStr(LR2.ExitCode))
      else
        Writeln('[e2e]   ok: exec#2 stdout=', Trim(LR2.StdOutText));
    finally
      LSess.Close;
    end;
  except
    on E: ESSHError do Fail(SshErrorKindName(E.Kind) + ': ' + E.Message);
    on E: Exception do Fail(E.ClassName + ': ' + E.Message);
  end;
end;

{ 场景 2：远端命令退出码透传 }
procedure ScenarioExitCode;
var
  LSess: ISshSession;
  LR: TSshExecResult;
begin
  Writeln('[e2e] scenario: remote exit code passthrough');
  try
    LSess := ConnectE2E(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''));
    try
      LR := LSess.Exec('exit 7');
      if LR.ExitCode <> 7 then
        Fail('expected exit 7, got ' + IntToStr(LR.ExitCode))
      else
        Writeln('[e2e]   ok: exit=', LR.ExitCode);
    finally
      LSess.Close;
    end;
  except
    on E: ESSHError do Fail(SshErrorKindName(E.Kind) + ': ' + E.Message);
    on E: Exception do Fail(E.ClassName + ': ' + E.Message);
  end;
end;

{ 场景 3：stdout / stderr 分流不串台 }
procedure ScenarioStderrSplit;
var
  LSess: ISshSession;
  LR: TSshExecResult;
begin
  Writeln('[e2e] scenario: stderr separated from stdout');
  try
    LSess := ConnectE2E(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''));
    try
      LR := LSess.Exec('echo out-line; echo err-line 1>&2');
      if Pos('out-line', LR.StdOutText) = 0 then
        Fail('stdout missing "out-line", got "' + LR.StdOutText + '"')
      else if Pos('err-line', LR.StdErrText) = 0 then
        Fail('stderr missing "err-line", got "' + LR.StdErrText + '"')
      else if Pos('err-line', LR.StdOutText) > 0 then
        Fail('stderr leaked into stdout')
      else
        Writeln('[e2e]   ok: stdout/stderr split clean');
    finally
      LSess.Close;
    end;
  except
    on E: ESSHError do Fail(SshErrorKindName(E.Kind) + ': ' + E.Message);
    on E: Exception do Fail(E.ClassName + ': ' + E.Message);
  end;
end;

{ 场景 4：known_hosts 与服务器主机密钥不符必须拒绝（sekHostKey），
  且发生在认证之前——不会产生失败登录记录 }
procedure ScenarioWrongHostKey;
var
  LBogus: TStringList;
begin
  Writeln('[e2e] scenario: mismatched known_hosts rejected (pre-auth)');
  LBogus := TStringList.Create;
  try
    { 一把确定不匹配的 ed25519 假钥 }
    LBogus.Add(EnvOr('NEXTPAS_SSH_E2E_HOST', '127.0.0.1') +
      ' ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBoGx7j9VbXJb3vBhXqOaEfDcT5wK2mZyUd8nQ4pLxE');
    LBogus.SaveToFile(EnvOr('TMPDIR', '/tmp') + '/np_e2e_bogus_known_hosts');
  finally
    LBogus.Free;
  end;
  try
    ConnectE2E(EnvOr('TMPDIR', '/tmp') + '/np_e2e_bogus_known_hosts').Close;
    Fail('connect succeeded with wrong host key');
  except
    on E: ESSHError do
      if E.Kind = sekHostKey then
        Writeln('[e2e]   ok: rejected with ', SshErrorKindName(E.Kind))
      else
        Fail('wrong error kind: ' + SshErrorKindName(E.Kind));
    on E: Exception do Fail(E.ClassName + ': ' + E.Message);
  end;
end;

begin
  try
    Writeln('[e2e] live target: ', EnvOr('NEXTPAS_SSH_E2E_USER', 'root'), '@',
      EnvOr('NEXTPAS_SSH_E2E_HOST', ''), ':',
      EnvOr('NEXTPAS_SSH_E2E_PORT', '22'));
    ScenarioExecTwice;
    ScenarioExitCode;
    ScenarioStderrSplit;
    ScenarioWrongHostKey;

    if GFail = 0 then
      Writeln('[e2e] PASS (4 scenarios)')
    else
      Writeln('[e2e] FAILED: ', GFail, ' failure(s)');
    ExitCode := Ord(GFail > 0);
  except
    on E: Exception do
    begin
      Writeln('[e2e] FATAL: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.

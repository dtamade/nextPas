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
    NEXTPAS_SSH_E2E_RSA_KEYFILE  未加密 OpenSSH RSA 私钥（缺省则跳过 RSA 场景）
    NEXTPAS_SSH_E2E_ENC_KEYFILE  加密 OpenSSH ed25519 私钥（缺省则跳过加密场景）
    NEXTPAS_SSH_E2E_ENC_PASSPHRASE 加密私钥口令

  场景：exec stdout/exit 码、stderr 分流、同会话多次 exec、
        错误 known_hosts 必须被 sekHostKey 拒绝、RSA/加密私钥认证。
  由 run_e2e.sh 编排（remote 直连 / local sshd fixture）；本程序不做门控。
}
uses
  nextpas.core.system.sysutils, Classes,
  nextpas.core.ssh,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.sftp;

const
  MARKER = 'np-e2e-7f3d-marker';

var
  GFail: Integer = 0;
  GRsaRan: Boolean = False;
  GEncRan: Boolean = False;

procedure Fail(const AMsg: string);
begin
  Writeln('[e2e]   FAIL: ', AMsg);
  Inc(GFail);
end;

{ 帧级追踪（NEXTPAS_SSH_E2E_TRACE=1 时由库回调）}
procedure TraceLine(const ALine: string);
begin
  Writeln('[trace] ', ALine);
end;

function HexDump(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
  begin
    if I > 0 then
      Result += ' ';
    Result += IntToHex(AData[I], 2);
  end;
end;

{ 动态数组 = 是引用比较，内容相等须逐字节 }
function SameBytes(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(A) = Length(B);
  if not Result then
    Exit;
  for I := 0 to High(A) do
    if A[I] <> B[I] then
      Exit(False);
end;

{ 明文包转储（NEXTPAS_SSH_E2E_DUMP=1 时逐包写 /tmp/np_ssh_dump.txt）}
var
  GDumpInit: Boolean = False;
  GDumpFile: Text;

procedure DumpPacket(const ATag: string; const APkt: TBytes);
var
  I: Integer;
begin
  if not GDumpInit then
  begin
    Assign(GDumpFile, '/tmp/np_ssh_dump.txt');
    Rewrite(GDumpFile);
    GDumpInit := True;
  end;
  Write(GDumpFile, ATag, ' ', Length(APkt), ':');
  for I := 0 to High(APkt) do
    Write(GDumpFile, ' ', IntToHex(APkt[I], 2));
  Writeln(GDumpFile);
  Flush(GDumpFile);
end;

function EnvOr(const AName, ADef: string): string;
begin
  Result := GetEnvironmentVariable(AName);
  if Result = '' then
    Result := ADef;
end;

function ConnectE2EWithKey(const AKnownHosts, AKeyFile: string): ISshSession;
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
    LKey.LoadFromFile(AKeyFile);
    LBuilder := LBuilder.PrivateKeyData(LKey.Text);
  finally
    LKey.Free;
  end;
  Result := LBuilder.Connect;
end;

function ConnectE2E(const AKnownHosts: string): ISshSession;
begin
  Result := ConnectE2EWithKey(AKnownHosts,
    EnvOr('NEXTPAS_SSH_E2E_KEYFILE', ''));
end;

function ConnectE2EWithEncKey(const AKnownHosts: string): ISshSession;
var
  LBuilder: ISshClientBuilder;
  LKey: TStringList;
  LPass: string;
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
    LKey.LoadFromFile(EnvOr('NEXTPAS_SSH_E2E_ENC_KEYFILE', ''));
    LBuilder := LBuilder.PrivateKeyData(LKey.Text);
  finally
    LKey.Free;
  end;
  LPass := EnvOr('NEXTPAS_SSH_E2E_ENC_PASSPHRASE', '');
  if LPass <> '' then
    LBuilder := LBuilder.PrivateKeyPassphrase(LPass);
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
        Fail('exec#2 stdout got "' + Trim(LR2.StdOutText) + '" (exit=' +
          IntToStr(LR2.ExitCode) + ')')
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

{ 场景 5：同会话连续多次 exec 压力（通道复用路径的回归放大器）}
procedure ScenarioExecStress;
const
  N = 16;
var
  LSess: ISshSession;
  LR: TSshExecResult;
  I, LBad: Integer;
begin
  Writeln('[e2e] scenario: ', N, ' sequential execs on one session');
  try
    LSess := ConnectE2E(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''));
    try
      LBad := 0;
      for I := 1 to N do
      begin
        LR := LSess.Exec('printf %s two');
        if (Trim(LR.StdOutText) <> 'two') or (LR.ExitCode <> 0) then
        begin
          Fail('exec#' + IntToStr(I) + ' stdout="' + Trim(LR.StdOutText) +
            '" len=' + IntToStr(Length(LR.StdOut)) +
            ' hex=' + HexDump(LR.StdOut) +
            ' stderr_len=' + IntToStr(Length(LR.StdErr)) +
            ' (exit=' + IntToStr(LR.ExitCode) + ')');
          Inc(LBad);
          if LBad >= 3 then
            Break; { 现场已足够，避免刷屏 }
        end;
      end;
      if LBad = 0 then
        Writeln('[e2e]   ok: ', N, '/', N, ' execs clean');
    finally
      LSess.Close;
    end;
  except
    on E: ESSHError do Fail(SshErrorKindName(E.Kind) + ': ' + E.Message);
    on E: Exception do Fail(E.ClassName + ': ' + E.Message);
  end;
end;

{ 场景 6：SFTP 文件操作全回路（internal-sftp）——写→读回→列目→stat→删除 }
procedure ScenarioSftpRoundtrip;
var
  LSess: ISshSession;
  LFfs: ISshFileSystem;
  LRoot, LPath: string;
  LData, LGot: TBytes;
  LDir: TSftpDirEntryArray;
  LFound: Boolean;
  I: Integer;
begin
  Writeln('[e2e] scenario: sftp write/read/list/stat/remove roundtrip');
  try
    LSess := ConnectE2E(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''));
    try
      LFfs := LSess.OpenFileSystem;
      LRoot := LFfs.RealPath('.');
      LPath := LRoot + '/np-e2e-sftp-marker.txt';
      LData := BytesOf('sftp-roundtrip-' + MARKER);
      LFfs.WriteFile(LPath, LData);
      try
        LGot := LFfs.ReadFile(LPath);
        if SameBytes(LGot, LData) then
          Writeln('[e2e]   ok: write+read ', Length(LGot), ' bytes')
        else
          Fail('sftp readback mismatch');
        LFound := False;
        LDir := LFfs.ListDir(LRoot);
        for I := 0 to High(LDir) do
          if LDir[I].Name = 'np-e2e-sftp-marker.txt' then
          begin
            LFound := True;
            if LDir[I].Attrs.Size <> UInt64(Length(LData)) then
              Fail('readdir size mismatch');
          end;
        if LFound then
          Writeln('[e2e]   ok: readdir lists marker with size')
        else
          Fail('marker missing from readdir');
      finally
        LFfs.Remove(LPath);
      end;
      LFound := False;
      LDir := LFfs.ListDir(LRoot);
      for I := 0 to High(LDir) do
        if LDir[I].Name = 'np-e2e-sftp-marker.txt' then
          LFound := True;
      if not LFound then
        Writeln('[e2e]   ok: remove confirmed via readdir')
      else
        Fail('marker still present after remove');
    finally
      LSess.Close;
    end;
  except
    on LE: ESSHError do Fail(SshErrorKindName(LE.Kind) + ': ' + LE.Message);
    on LE: Exception do Fail(LE.ClassName + ': ' + LE.Message);
  end;
end;

{ 场景 7：RSA 私钥 publickey 认证（rsa-sha2-512）+ exec。
  密钥由编排器 ssh-keygen -t rsa 现场生成并注入 authorized_keys；
  未提供环境变量时显式 SKIP，不计入场景数。}
procedure ScenarioRsaAuth;
var
  LSess: ISshSession;
  LR: TSshExecResult;
  LKeyFile: string;
begin
  LKeyFile := EnvOr('NEXTPAS_SSH_E2E_RSA_KEYFILE', '');
  if LKeyFile = '' then
  begin
    Writeln('[e2e] scenario: rsa publickey auth — SKIP (no NEXTPAS_SSH_E2E_RSA_KEYFILE)');
    Exit;
  end;
  GRsaRan := True;
  Writeln('[e2e] scenario: rsa publickey auth exec');
  try
    LSess := ConnectE2EWithKey(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''), LKeyFile);
    try
      LR := LSess.Exec('echo ' + MARKER);
      if Pos(MARKER, LR.StdOutText) = 0 then
        Fail('rsa auth stdout missing marker, got "' + Trim(LR.StdOutText) + '"')
      else if LR.ExitCode <> 0 then
        Fail('expected exit 0, got ' + IntToStr(LR.ExitCode))
      else
        Writeln('[e2e]   ok: rsa key exec marker, exit=0');
    finally
      LSess.Close;
    end;
  except
    on LE: ESSHError do Fail(SshErrorKindName(LE.Kind) + ': ' + LE.Message);
    on LE: Exception do Fail(LE.ClassName + ': ' + LE.Message);
  end;
end;

{ 场景 8：加密私钥（aes256-ctr+bcrypt）publickey 认证 + exec。
  Docker 夹具现场生成 ssh-keygen -t ed25519 -N 'enc-pass-88'，口令经环境变量传递；
  未提供时 SKIP。}
procedure ScenarioEncAuth;
var
  LSess: ISshSession;
  LR: TSshExecResult;
  LKeyFile: string;
begin
  LKeyFile := EnvOr('NEXTPAS_SSH_E2E_ENC_KEYFILE', '');
  if LKeyFile = '' then
  begin
    Writeln('[e2e] scenario: encrypted key auth — SKIP (no NEXTPAS_SSH_E2E_ENC_KEYFILE)');
    Exit;
  end;
  GEncRan := True;
  Writeln('[e2e] scenario: encrypted ed25519 key auth exec');
  try
    LSess := ConnectE2EWithEncKey(EnvOr('NEXTPAS_SSH_E2E_KNOWN_HOSTS', ''));
    try
      LR := LSess.Exec('echo ' + MARKER);
      if Pos(MARKER, LR.StdOutText) = 0 then
        Fail('enc auth stdout missing marker, got "' + Trim(LR.StdOutText) + '"')
      else if LR.ExitCode <> 0 then
        Fail('expected exit 0, got ' + IntToStr(LR.ExitCode))
      else
        Writeln('[e2e]   ok: encrypted key exec marker, exit=0');
    finally
      LSess.Close;
    end;
  except
    on LE: ESSHError do Fail(SshErrorKindName(LE.Kind) + ': ' + LE.Message);
    on LE: Exception do Fail(LE.ClassName + ': ' + LE.Message);
  end;
end;

begin
  try
    if GetEnvironmentVariable('NEXTPAS_SSH_E2E_TRACE') = '1' then
      SshChannelTrace := @TraceLine;
    if GetEnvironmentVariable('NEXTPAS_SSH_E2E_DUMP') = '1' then
      SshTransportDump := @DumpPacket;
    Writeln('[e2e] live target: ', EnvOr('NEXTPAS_SSH_E2E_USER', 'root'), '@',
      EnvOr('NEXTPAS_SSH_E2E_HOST', ''), ':',
      EnvOr('NEXTPAS_SSH_E2E_PORT', '22'));
    ScenarioExecTwice;
    ScenarioExitCode;
    ScenarioStderrSplit;
    ScenarioWrongHostKey;
    ScenarioExecStress;
    ScenarioSftpRoundtrip;
    ScenarioRsaAuth;
    ScenarioEncAuth;

    if GFail = 0 then
      Writeln('[e2e] PASS (', 6 + Ord(GRsaRan) + Ord(GEncRan), ' scenarios)')
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

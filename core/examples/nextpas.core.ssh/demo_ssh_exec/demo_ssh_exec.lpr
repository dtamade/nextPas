program demo_ssh_exec;
{$mode ObjFPC}{$H+}
{
  demo_ssh_exec —— argv 驱动的 SSH exec 演示（opt-in，手工运行，不进默认 gate）。

  用法：
    demo_ssh_exec <host> <port> <user> <password|@keyfile> [command] [known_hosts]

  示例：
    demo_ssh_exec 192.168.1.10 22 root secret 'uname -a'
    demo_ssh_exec 192.168.1.10 22 root @/home/me/.ssh/id_ed25519 'ls -l' ~/.ssh/known_hosts

  需要一台真实可达的 SSH 服务器；本程序不做任何内建缺省连接。
}
uses
  nextpas.core.text.conv,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.ssh;

var
  LBuilder: ISshClientBuilder;
  LSession: ISshSession;
  LResult: TSshExecResult;
  LHost, LUser, LSecret, LCommand, LKnownHosts: string;
  LPort: Word;
begin
  if ParamCount < 5 then
  begin
    WriteLn('usage: demo_ssh_exec <host> <port> <user> <password|@keyfile> [command] [known_hosts]');
    Halt(2);
  end;
  LHost := ParamStr(1);
  LPort := Word(StrToIntDef(ParamStr(2), 22));
  LUser := ParamStr(3);
  LSecret := ParamStr(4);
  LCommand := ParamStr(5);
  if ParamCount >= 6 then
    LKnownHosts := ParamStr(6);

  try
    LBuilder := SshClient
      .Host(LHost)
      .Port(LPort)
      .User(LUser)
      .KnownHostsFile(LKnownHosts)
      .StrictHostKey(LKnownHosts <> '');

    { @path 表示私钥文件；否则按密码认证 }
    if (Length(LSecret) > 1) and (LSecret[1] = '@') then
      LBuilder := LBuilder.PrivateKeyData(ReadFileText(Copy(LSecret, 2, MaxInt)))
    else
      LBuilder := LBuilder.Password(LSecret);

    LSession := LBuilder.Connect;
    try
      WriteLn('== exec: ', LCommand);
      LResult := LSession.Exec(LCommand);
      WriteLn('-- stdout --');
      WriteLn(LResult.StdOutText);
      if Length(LResult.StdErrText) > 0 then
      begin
        WriteLn('-- stderr --');
        WriteLn(LResult.StdErrText);
      end;
      WriteLn('-- exit=', LResult.ExitCode);
    finally
      LSession.Close;
    end;
  except
    on E: Exception do
    begin
      WriteLn('ssh error: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.

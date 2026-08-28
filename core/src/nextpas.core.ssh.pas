unit nextpas.core.ssh;

{** nextpas.core.ssh - 门面：纯 re-export + 便捷入口。
 *
 * 消费方一般只需 uses 本单元：
 *   SshClient.Host(..).User(..).Password(..).Connect  → ISshSession
 *   SshExec(host, port, user, pass, cmd)              → TSshExecResult
 *   LSess.OpenFileSystem                              → ISshFileSystem (SFTP v3)
 *
 * 需要底层构件（wire buffer、cipher codec、kex、known_hosts）做二次开发时，
 * 直接引用对应子单元。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.kex.curve25519,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.sftp,
  nextpas.core.ssh.agent,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.rekey,
  nextpas.core.ssh.keepalive,
  nextpas.core.ssh.window,
  nextpas.core.ssh.session;

type
  { 基础类型 re-export }
  TSshAuthMethod = nextpas.core.ssh.base.TSshAuthMethod;
  TSshHostKeyAlg = nextpas.core.ssh.base.TSshHostKeyAlg;
  TSshConnectOptions = nextpas.core.ssh.base.TSshConnectOptions;

  TSshErrorKind = nextpas.core.ssh.errors.TSshErrorKind;
  ESSHError = nextpas.core.ssh.errors.ESSHError;

  { 会话与结果 }
  ISshSession = nextpas.core.ssh.session.ISshSession;
  ISshClientBuilder = nextpas.core.ssh.session.ISshClientBuilder;
  TSshExecResult = nextpas.core.ssh.channel.TSshExecResult;

  { SFTP 文件操作面 }
  ISshFileSystem = nextpas.core.ssh.sftp.ISshFileSystem;
  TSftpAttrs = nextpas.core.ssh.sftp.TSftpAttrs;
  TSftpDirEntry = nextpas.core.ssh.sftp.TSftpDirEntry;

  { 底层构件 re-export（二次开发/测试用）}
  ISshPacketSender = nextpas.core.ssh.cipher.ISshPacketSender;
  ISshPacketReceiver = nextpas.core.ssh.cipher.ISshPacketReceiver;
  ISshKeyExchange = nextpas.core.ssh.kex.curve25519.ISshKeyExchange;
  TSshClientTransport = nextpas.core.ssh.transport.TSshClientTransport;
  TSshKnownHosts = nextpas.core.ssh.hostkey.TSshKnownHosts;
  TSshAgentClient = nextpas.core.ssh.agent.TSshAgentClient;
  TSshAgentIdentity = nextpas.core.ssh.agent.TSshAgentIdentity;
  ISshCompressor = nextpas.core.ssh.compress.ISshCompressor;
  TsshWriter = nextpas.core.ssh.buffer.TsshWriter;
  TsshReader = nextpas.core.ssh.buffer.TsshReader;

{ 默认选项（inline 转发）}
function DefaultSshOptions(const AHost: string): TSshConnectOptions; inline;

{ Fluent 构造器：SshClient.Host('h').Port(22).User('u').Password('p').Connect }
function SshClient: ISshClientBuilder; inline;

{ 一步到位连接 }
function SshConnect(const AOptions: TSshConnectOptions): ISshSession; inline;
function SshConnectViaJump(const ATargetOpts, AJumpOpts: TSshConnectOptions): ISshSession; inline;
function SshConnectViaJumpOn(const AJumpSession: ISshSession; const ATargetOpts: TSshConnectOptions): ISshSession; inline;

{ 一次性执行便捷函数（密码认证路径）}
function SshExec(const AHost: string; APort: Word;
  const AUser, APassword, ACommand: string): TSshExecResult;

implementation

function DefaultSshOptions(const AHost: string): TSshConnectOptions;
begin
  Result := DefaultSshConnectOptions(AHost);
end;

function SshClient: ISshClientBuilder;
begin
  Result := nextpas.core.ssh.session.SshClient;
end;

function SshConnect(const AOptions: TSshConnectOptions): ISshSession;
begin
  Result := nextpas.core.ssh.session.SshConnect(AOptions);
end;

function SshConnectViaJump(const ATargetOpts, AJumpOpts: TSshConnectOptions): ISshSession;
begin
  Result := nextpas.core.ssh.session.SshConnectViaJump(ATargetOpts, AJumpOpts);
end;

function SshConnectViaJumpOn(const AJumpSession: ISshSession; const ATargetOpts: TSshConnectOptions): ISshSession;
begin
  Result := nextpas.core.ssh.session.SshConnectViaJumpOn(AJumpSession, ATargetOpts);
end;

function SshExec(const AHost: string; APort: Word;
  const AUser, APassword, ACommand: string): TSshExecResult;
var
  LOpts: TSshConnectOptions;
  LSession: ISshSession;
begin
  LOpts := DefaultSshConnectOptions(AHost);
  LOpts.Port := APort;
  LOpts.User := AUser;
  LOpts.Password := APassword;
  LSession := SshConnect(LOpts);
  try
    Result := LSession.Exec(ACommand);
  finally
    LSession.Close;
  end;
end;

end.

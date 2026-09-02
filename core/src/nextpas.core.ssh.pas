unit nextpas.core.ssh;

{** nextpas.core.ssh - 门面：纯 re-export + 便捷入口。
 *
 * 消费方一般只需 uses 本单元：
 *   SshClient.Host(..).User(..).Password(..).Connect  → ISshSession
 *   SshExec(host, port, user, pass, cmd)              → TSshExecResult
 *   LSess.OpenFileSystem                              → ISshFileSystem (SFTP v3)
 *
 * 需要底层构件（wire buffer、cipher codec、kex、known_hosts）做二次开发时，
 * 直接引用对应子单元；门面仅保留关键别名，零拷贝与 bytes.ops 单源由子模块保证。
 * 薄转发：所有便捷函数均为 inline 委托，无额外分配；资源释放由 try-finally 保证。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.hostkey,
  nextpas.core.ssh.keys,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.transport,
  nextpas.core.ssh.transport.async,
  nextpas.core.ssh.sftp,
  nextpas.core.ssh.sftp.async,
  nextpas.core.ssh.agent,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.window,
  nextpas.core.ssh.session,
  nextpas.core.ssh.session.builder,
  nextpas.core.ssh.session.async;

type
  { 基础类型 }
  TSshAuthMethod = nextpas.core.ssh.base.TSshAuthMethod;
  TSshHostKeyAlg = nextpas.core.ssh.base.TSshHostKeyAlg;
  TSshConnectOptions = nextpas.core.ssh.base.TSshConnectOptions;

  TSshErrorKind = nextpas.core.ssh.errors.TSshErrorKind;
  ESSHError = nextpas.core.ssh.errors.ESSHError;

  { 会话与执行 }
  ISshSession = nextpas.core.ssh.session.ISshSession;
  ISshClientBuilder = nextpas.core.ssh.session.builder.ISshClientBuilder;
  TSshExecResult = nextpas.core.ssh.channel.TSshExecResult;

  { SFTP 文件操作面 }
  ISshFileSystem = nextpas.core.ssh.sftp.ISshFileSystem;
  TSftpAttrs = nextpas.core.ssh.sftp.TSftpAttrs;
  TSftpDirEntry = nextpas.core.ssh.sftp.TSftpDirEntry;

  { 传输与底层构件（二次开发按需直接引用子单元，门面仅保留关键别名）}
  ISshPacketSender = nextpas.core.ssh.cipher.ISshPacketSender;
  ISshPacketReceiver = nextpas.core.ssh.cipher.ISshPacketReceiver;
  TSshClientTransport = nextpas.core.ssh.transport.TSshClientTransport;
  TAsyncSshTransport = nextpas.core.ssh.transport.async.TAsyncSshTransport;
  TSshKnownHosts = nextpas.core.ssh.hostkey.TSshKnownHosts;
  TSshAgentClient = nextpas.core.ssh.agent.TSshAgentClient;
  ISshCompressor = nextpas.core.ssh.compress.ISshCompressor;
  TChannelWindow = nextpas.core.ssh.window.TChannelWindow;
  TSshWriter = nextpas.core.ssh.buffer.TSshWriter;
  TSshReader = nextpas.core.ssh.buffer.TSshReader;

  { 密钥与异步扩展 }
  TSshPrivateKey = nextpas.core.ssh.keys.TSshPrivateKey;
  ISshAsyncSession = nextpas.core.ssh.session.async.ISshAsyncSession;
  ISshAsyncFileSystem = nextpas.core.ssh.sftp.async.ISshAsyncFileSystem;

{ 默认选项（inline 薄转发，零拷贝）}
function DefaultSshOptions(const AHost: string): TSshConnectOptions; inline;

{ Fluent 构造器：SshClient.Host('h').Port(22).User('u').Password('p').Connect }
function SshClient: ISshClientBuilder; inline;

{ 一步到位连接（inline 薄转发，委托 session/proxyjump 单源）}
function SshConnect(const AOptions: TSshConnectOptions): ISshSession; inline;
function SshConnectViaJump(const ATargetOpts, AJumpOpts: TSshConnectOptions): ISshSession; inline;
function SshConnectViaJumpOn(const AJumpSession: ISshSession; const ATargetOpts: TSshConnectOptions): ISshSession; inline;

{ 一次性执行便捷函数（密码认证路径，try-finally 保证 Close 不丢）}
function SshExec(const AHost: string; APort: Word;
  const AUser, APassword, ACommand: string): TSshExecResult;

implementation

uses
  nextpas.core.mem.secure,
  nextpas.core.ssh.proxyjump;

function DefaultSshOptions(const AHost: string): TSshConnectOptions;
begin
  Result := nextpas.core.ssh.base.DefaultSshConnectOptions(AHost);
end;

function SshClient: ISshClientBuilder;
begin
  Result := nextpas.core.ssh.session.builder.SshClient;
end;

function SshConnect(const AOptions: TSshConnectOptions): ISshSession;
begin
  Result := nextpas.core.ssh.session.SshConnect(AOptions);
end;

function SshConnectViaJump(const ATargetOpts, AJumpOpts: TSshConnectOptions): ISshSession;
begin
  Result := nextpas.core.ssh.proxyjump.SshConnectViaJump(ATargetOpts, AJumpOpts);
end;

function SshConnectViaJumpOn(const AJumpSession: ISshSession; const ATargetOpts: TSshConnectOptions): ISshSession;
begin
  Result := nextpas.core.ssh.proxyjump.SshConnectViaJumpOn(AJumpSession, ATargetOpts);
end;

function SshExec(const AHost: string; APort: Word;
  const AUser, APassword, ACommand: string): TSshExecResult;
var
  LOpts: TSshConnectOptions;
  LSession: ISshSession;
begin
  LOpts := nextpas.core.ssh.base.DefaultSshConnectOptions(AHost);
  LOpts.Port := APort;
  LOpts.User := AUser;
  LOpts.Password := APassword;
  try
    LSession := nextpas.core.ssh.session.SshConnect(LOpts);
    try
      Result := LSession.Exec(ACommand);
    finally
      LSession.Close;
    end;
  finally
    SecureZeroString(LOpts.Password);
    LOpts.Password := '';
    SecureZeroString(LOpts.PrivateKeyPassphrase);
    LOpts.PrivateKeyPassphrase := '';
  end;
end;

end.

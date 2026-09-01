unit nextpas.core.ssh.sftp;

{** nextpas.core.ssh - SFTP v3 文件操作面门面（四件套 facade）。
 *
 * 纯 re-export：聚合 base 常量/类型、intf 接口与 fs/conn/wire 实现
 * 的公共 API，不含业务逻辑；所有逻辑委托子模块。
 * 性能/稳定性语义由子模块保证（IBytesBuilder 倍增、零拷贝偏移）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer,
  nextpas.core.ssh.channel,
  nextpas.core.ssh.sftp.base,
  nextpas.core.ssh.sftp.intf,
  nextpas.core.ssh.transport;

const
  SSH_FXP_INIT = nextpas.core.ssh.sftp.base.SSH_FXP_INIT;
  SSH_FXP_VERSION = nextpas.core.ssh.sftp.base.SSH_FXP_VERSION;
  SSH_FXP_OPEN = nextpas.core.ssh.sftp.base.SSH_FXP_OPEN;
  SSH_FXP_CLOSE = nextpas.core.ssh.sftp.base.SSH_FXP_CLOSE;
  SSH_FXP_READ = nextpas.core.ssh.sftp.base.SSH_FXP_READ;
  SSH_FXP_WRITE = nextpas.core.ssh.sftp.base.SSH_FXP_WRITE;
  SSH_FXP_LSTAT = nextpas.core.ssh.sftp.base.SSH_FXP_LSTAT;
  SSH_FXP_OPENDIR = nextpas.core.ssh.sftp.base.SSH_FXP_OPENDIR;
  SSH_FXP_READDIR = nextpas.core.ssh.sftp.base.SSH_FXP_READDIR;
  SSH_FXP_REMOVE = nextpas.core.ssh.sftp.base.SSH_FXP_REMOVE;
  SSH_FXP_MKDIR = nextpas.core.ssh.sftp.base.SSH_FXP_MKDIR;
  SSH_FXP_RMDIR = nextpas.core.ssh.sftp.base.SSH_FXP_RMDIR;
  SSH_FXP_REALPATH = nextpas.core.ssh.sftp.base.SSH_FXP_REALPATH;
  SSH_FXP_STAT = nextpas.core.ssh.sftp.base.SSH_FXP_STAT;
  SSH_FXP_RENAME = nextpas.core.ssh.sftp.base.SSH_FXP_RENAME;
  SSH_FXP_STATUS = nextpas.core.ssh.sftp.base.SSH_FXP_STATUS;
  SSH_FXP_HANDLE = nextpas.core.ssh.sftp.base.SSH_FXP_HANDLE;
  SSH_FXP_DATA = nextpas.core.ssh.sftp.base.SSH_FXP_DATA;
  SSH_FXP_NAME = nextpas.core.ssh.sftp.base.SSH_FXP_NAME;
  SSH_FXP_ATTRS = nextpas.core.ssh.sftp.base.SSH_FXP_ATTRS;
  SSH_FX_OK = nextpas.core.ssh.sftp.base.SSH_FX_OK;
  SSH_FX_EOF = nextpas.core.ssh.sftp.base.SSH_FX_EOF;
  SSH_FX_NO_SUCH_FILE = nextpas.core.ssh.sftp.base.SSH_FX_NO_SUCH_FILE;
  SSH_FX_PERMISSION_DENIED = nextpas.core.ssh.sftp.base.SSH_FX_PERMISSION_DENIED;
  SSH_FX_FAILURE = nextpas.core.ssh.sftp.base.SSH_FX_FAILURE;
  SSH_FX_BAD_MESSAGE = nextpas.core.ssh.sftp.base.SSH_FX_BAD_MESSAGE;
  SSH_FX_OP_UNSUPPORTED = nextpas.core.ssh.sftp.base.SSH_FX_OP_UNSUPPORTED;
  SSH_FXF_READ = nextpas.core.ssh.sftp.base.SSH_FXF_READ;
  SSH_FXF_WRITE = nextpas.core.ssh.sftp.base.SSH_FXF_WRITE;
  SSH_FXF_CREAT = nextpas.core.ssh.sftp.base.SSH_FXF_CREAT;
  SSH_FXF_TRUNC = nextpas.core.ssh.sftp.base.SSH_FXF_TRUNC;
  SSH_FILEXFER_ATTR_SIZE = nextpas.core.ssh.sftp.base.SSH_FILEXFER_ATTR_SIZE;
  SSH_FILEXFER_ATTR_UIDGID = nextpas.core.ssh.sftp.base.SSH_FILEXFER_ATTR_UIDGID;
  SSH_FILEXFER_ATTR_PERMISSIONS = nextpas.core.ssh.sftp.base.SSH_FILEXFER_ATTR_PERMISSIONS;
  SSH_FILEXFER_ATTR_ACMODTIME = nextpas.core.ssh.sftp.base.SSH_FILEXFER_ATTR_ACMODTIME;
  SSH_FILEXFER_ATTR_EXTENDED = nextpas.core.ssh.sftp.base.SSH_FILEXFER_ATTR_EXTENDED;
  SFTP_CHUNK_SIZE = nextpas.core.ssh.sftp.base.SFTP_CHUNK_SIZE;

type
  TSftpAttrs = nextpas.core.ssh.sftp.base.TSftpAttrs;
  TSftpDirEntry = nextpas.core.ssh.sftp.base.TSftpDirEntry;
  TSftpDirEntryArray = nextpas.core.ssh.sftp.base.TSftpDirEntryArray;
  ISftpWire = nextpas.core.ssh.sftp.intf.ISftpWire;
  ISshFileSystem = nextpas.core.ssh.sftp.intf.ISshFileSystem;

procedure PutAttrs(var AW: TsshWriter; const AAttrs: TSftpAttrs); inline;
function ReadAttrs(var AR: TsshReader): TSftpAttrs; inline;
function SftpStatusName(ACode: UInt32): string; inline;

function SftpOpenOnChannel(AChannel: TSshChannel;
  ATimeoutMs: Integer): ISshFileSystem;
function SftpOpenOnWire(AWire: ISftpWire;
  ATimeoutMs: Integer): ISshFileSystem;
function SftpOpenOnTransport(ATransport: TSshClientTransport;
  AInitialWindow, AMaxPacket, ATimeoutMs: Integer): ISshFileSystem;

implementation

uses
  nextpas.core.ssh.sftp.conn,
  nextpas.core.ssh.sftp.fs;

procedure PutAttrs(var AW: TsshWriter; const AAttrs: TSftpAttrs); inline;
begin
  nextpas.core.ssh.sftp.conn.PutAttrs(AW, AAttrs);
end;

function ReadAttrs(var AR: TsshReader): TSftpAttrs; inline;
begin
  Result := nextpas.core.ssh.sftp.conn.ReadAttrs(AR);
end;

function SftpStatusName(ACode: UInt32): string; inline;
begin
  Result := nextpas.core.ssh.sftp.base.SftpStatusName(ACode);
end;

function SftpOpenOnChannel(AChannel: TSshChannel;
  ATimeoutMs: Integer): ISshFileSystem;
begin
  if AChannel = nil then
    raise ESSHError.Create(sekProtocol, 'sftp: nil channel');
  AChannel.RequestSubsystem('sftp');
  Result := TSshFileSystem.Create(AChannel, ATimeoutMs);
end;

function SftpOpenOnWire(AWire: ISftpWire;
  ATimeoutMs: Integer): ISshFileSystem;
begin
  if AWire = nil then
    raise ESSHError.Create(sekProtocol, 'sftp: nil wire');
  Result := TSshFileSystem.CreateWithWire(AWire, ATimeoutMs) as ISshFileSystem;
end;

function SftpOpenOnTransport(ATransport: TSshClientTransport;
  AInitialWindow, AMaxPacket, ATimeoutMs: Integer): ISshFileSystem;
var
  LChan: TSshChannel;
begin
  LChan := TSshChannel.Create(ATransport, AInitialWindow, AMaxPacket, ATimeoutMs);
  try
    LChan.OpenSession;
    Result := SftpOpenOnChannel(LChan, ATimeoutMs);
    LChan := nil;
  finally
    if LChan <> nil then
      LChan.Free;
  end;
end;

end.

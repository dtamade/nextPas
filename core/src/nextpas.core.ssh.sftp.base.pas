unit nextpas.core.ssh.sftp.base;

{** nextpas.core.ssh.sftp.base - SFTP 共享基座（四件套 base）。
 *
 * 拥有 SFTP v3 协议常量、文件属性载体与 STATUS 命名单源；
 * 供 intf/实现子模块共同依赖，不触通道/连接逻辑。
 * 单源复用 bytes 语义仅文本映射，SftpStatusName inline 无堆分配热路径。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv;

const
  { SFTP 包类型 }
  SSH_FXP_INIT = 1;
  SSH_FXP_VERSION = 2;
  SSH_FXP_OPEN = 3;
  SSH_FXP_CLOSE = 4;
  SSH_FXP_READ = 5;
  SSH_FXP_WRITE = 6;
  SSH_FXP_LSTAT = 7;
  SSH_FXP_OPENDIR = 11;
  SSH_FXP_READDIR = 12;
  SSH_FXP_REMOVE = 13;
  SSH_FXP_MKDIR = 14;
  SSH_FXP_RMDIR = 15;
  SSH_FXP_REALPATH = 16;
  SSH_FXP_STAT = 17;
  SSH_FXP_RENAME = 18;
  SSH_FXP_STATUS = 101;
  SSH_FXP_HANDLE = 102;
  SSH_FXP_DATA = 103;
  SSH_FXP_NAME = 104;
  SSH_FXP_ATTRS = 105;

  { STATUS 码 }
  SSH_FX_OK = 0;
  SSH_FX_EOF = 1;
  SSH_FX_NO_SUCH_FILE = 2;
  SSH_FX_PERMISSION_DENIED = 3;
  SSH_FX_FAILURE = 4;
  SSH_FX_BAD_MESSAGE = 5;
  SSH_FX_OP_UNSUPPORTED = 8;

  { OPEN pflags }
  SSH_FXF_READ = $00000001;
  SSH_FXF_WRITE = $00000002;
  SSH_FXF_CREAT = $00000008;
  SSH_FXF_TRUNC = $00000010;

  { ATTRS 标志位 }
  SSH_FILEXFER_ATTR_SIZE = $00000001;
  SSH_FILEXFER_ATTR_UIDGID = $00000002;
  SSH_FILEXFER_ATTR_PERMISSIONS = $00000004;
  SSH_FILEXFER_ATTR_ACMODTIME = $00000008;
  SSH_FILEXFER_ATTR_EXTENDED = $80000000;

  { 单次 READ/WRITE 数据分片上限 }
  SFTP_CHUNK_SIZE = 32760;
  SFTP_PROTOCOL_VERSION = 3;
  SFTP_MAX_PACKET_SIZE = 256 * 1024;

type
  { 文件属性（v3 掩码子集）}
  TSftpAttrs = record
    Flags: UInt32;
    Size: UInt64;
    Uid: UInt32;
    Gid: UInt32;
    Permissions: UInt32;
    ATime: UInt32;
    MTime: UInt32;
    function IsDir: Boolean;
    function IsRegular: Boolean;
  end;

  { 目录项 }
  TSftpDirEntry = record
    Name: string;
    LongName: string;
    Attrs: TSftpAttrs;
  end;
  TSftpDirEntryArray = array of TSftpDirEntry;

function SftpStatusName(ACode: UInt32): string; inline;

implementation

function TSftpAttrs.IsDir: Boolean;
begin
  Result := False;
  if (Flags and SSH_FILEXFER_ATTR_PERMISSIONS) = 0 then
    Exit;
  Result := (Permissions and $F000) = $4000;
end;

function TSftpAttrs.IsRegular: Boolean;
begin
  Result := False;
  if (Flags and SSH_FILEXFER_ATTR_PERMISSIONS) = 0 then
    Exit;
  Result := (Permissions and $F000) = $8000;
end;

function SftpStatusName(ACode: UInt32): string; inline;
begin
  case ACode of
    0: Result := 'ok';
    1: Result := 'eof';
    2: Result := 'no-such-file';
    3: Result := 'permission-denied';
    4: Result := 'failure';
    5: Result := 'bad-message';
    8: Result := 'op-unsupported';
  else
    Result := 'status-' + IntToStr(ACode);
  end;
end;

end.

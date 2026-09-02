unit nextpas.core.ssh.sftp.base;

{** nextpas.core.ssh.sftp.base - SFTP 共享基座（四件套 base）。
 *
 * 拥有 SFTP v3 协议常量、文件属性载体与 STATUS 命名单源；
 * 供 intf/实现子模块共同依赖，不触通道/连接逻辑。
 * 类型化集合：SFTP: TSftpConstants 单源 record const 聚合 30+ 协议常量，
 * 逐项别名收口为 SFTP 单缝隙，门面仅 re-export SFTP。
 * Base 纯度：SftpStatusName 经 nextpas.core.text.conv.IntToStr 单源（零 SysUtils 直连），inline 薄转发。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv;

type
  TSftpPacketTypes = record
    Init: Byte;
    Version: Byte;
    Open: Byte;
    Close: Byte;
    Read: Byte;
    Write: Byte;
    Lstat: Byte;
    OpenDir: Byte;
    ReadDir: Byte;
    Remove: Byte;
    Mkdir: Byte;
    Rmdir: Byte;
    RealPath: Byte;
    Stat: Byte;
    Rename: Byte;
    Status: Byte;
    Handle: Byte;
    Data: Byte;
    Name: Byte;
    Attrs: Byte;
  end;

  TSftpStatusCodes = record
    Ok: UInt32;
    Eof: UInt32;
    NoSuchFile: UInt32;
    PermissionDenied: UInt32;
    Failure: UInt32;
    BadMessage: UInt32;
    OpUnsupported: UInt32;
  end;

  TSftpOpenFlags = record
    Read: UInt32;
    Write: UInt32;
    Creat: UInt32;
    Trunc: UInt32;
  end;

  TSftpAttrFlags = record
    Size: UInt32;
    UidGid: UInt32;
    Permissions: UInt32;
    AcModTime: UInt32;
    Extended: UInt32;
  end;

  TSftpLimits = record
    ChunkSize: Integer;
    ProtocolVersion: Integer;
    MaxPacketSize: Integer;
    PipelineWindow: Integer;
  end;

  TSftpConstants = record
    Packet: TSftpPacketTypes;
    Status: TSftpStatusCodes;
    OpenFlag: TSftpOpenFlags;
    AttrFlag: TSftpAttrFlags;
    Limits: TSftpLimits;
  end;

const
  { SFTP 包类型（真常量，单源聚合于 SFTP）}
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

  SSH_FX_OK = 0;
  SSH_FX_EOF = 1;
  SSH_FX_NO_SUCH_FILE = 2;
  SSH_FX_PERMISSION_DENIED = 3;
  SSH_FX_FAILURE = 4;
  SSH_FX_BAD_MESSAGE = 5;
  SSH_FX_OP_UNSUPPORTED = 8;

  SSH_FXF_READ = $00000001;
  SSH_FXF_WRITE = $00000002;
  SSH_FXF_CREAT = $00000008;
  SSH_FXF_TRUNC = $00000010;

  SSH_FILEXFER_ATTR_SIZE = $00000001;
  SSH_FILEXFER_ATTR_UIDGID = $00000002;
  SSH_FILEXFER_ATTR_PERMISSIONS = $00000004;
  SSH_FILEXFER_ATTR_ACMODTIME = $00000008;
  SSH_FILEXFER_ATTR_EXTENDED = $80000000;

  SFTP_CHUNK_SIZE = 32760;
  SFTP_PROTOCOL_VERSION = 3;
  SFTP_MAX_PACKET_SIZE = 256 * 1024;
  SFTP_PIPELINE_WINDOW = 16;

  { 类型化集合：单源聚合 30+ 常量，门面仅 re-export 此单点 }
  SFTP: TSftpConstants = (
    Packet: (Init:SSH_FXP_INIT; Version:SSH_FXP_VERSION; Open:SSH_FXP_OPEN; Close:SSH_FXP_CLOSE; Read:SSH_FXP_READ; Write:SSH_FXP_WRITE; Lstat:SSH_FXP_LSTAT; OpenDir:SSH_FXP_OPENDIR; ReadDir:SSH_FXP_READDIR; Remove:SSH_FXP_REMOVE; Mkdir:SSH_FXP_MKDIR; Rmdir:SSH_FXP_RMDIR; RealPath:SSH_FXP_REALPATH; Stat:SSH_FXP_STAT; Rename:SSH_FXP_RENAME; Status:SSH_FXP_STATUS; Handle:SSH_FXP_HANDLE; Data:SSH_FXP_DATA; Name:SSH_FXP_NAME; Attrs:SSH_FXP_ATTRS);
    Status: (Ok:SSH_FX_OK; Eof:SSH_FX_EOF; NoSuchFile:SSH_FX_NO_SUCH_FILE; PermissionDenied:SSH_FX_PERMISSION_DENIED; Failure:SSH_FX_FAILURE; BadMessage:SSH_FX_BAD_MESSAGE; OpUnsupported:SSH_FX_OP_UNSUPPORTED);
    OpenFlag: (Read:SSH_FXF_READ; Write:SSH_FXF_WRITE; Creat:SSH_FXF_CREAT; Trunc:SSH_FXF_TRUNC);
    AttrFlag: (Size:SSH_FILEXFER_ATTR_SIZE; UidGid:SSH_FILEXFER_ATTR_UIDGID; Permissions:SSH_FILEXFER_ATTR_PERMISSIONS; AcModTime:SSH_FILEXFER_ATTR_ACMODTIME; Extended:SSH_FILEXFER_ATTR_EXTENDED);
    Limits: (ChunkSize:SFTP_CHUNK_SIZE; ProtocolVersion:SFTP_PROTOCOL_VERSION; MaxPacketSize:SFTP_MAX_PACKET_SIZE; PipelineWindow:SFTP_PIPELINE_WINDOW)
  );

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
    Result := 'status-' + nextpas.core.text.conv.IntToStr(Int64(ACode));
  end;
end;

end.

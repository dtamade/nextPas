unit nextpas.core.tar.base;
{**
 * @desc Tar 基座：类型、常量与名安全谓词，L2 单点。
 * 仅依赖 nextpas.core.base / exception，无 FPC RTL 直引。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception;

type
  TTarEntryKind = (
    tekRegular,
    tekHardLink,
    tekSymlink,
    tekCharDevice,
    tekBlockDevice,
    tekDirectory,
    tekFifo
  );

  {** @desc 单条目头元数据（ustar/pax 归一后） *}
  TTarHeader = record
    Name: string;
    LinkName: string;
    Kind: TTarEntryKind;
    Mode: Cardinal;
    UID: Cardinal;
    GID: Cardinal;
    Size: Int64;
    MTimeUnix: Int64;
    UName: string;
    GName: string;
  end;

  {** @desc 写入选项（按条目覆盖 header 字段） *}
  TTarAddOptions = record
    Mode: Cardinal;
    UID: Cardinal;
    GID: Cardinal;
    MTimeUnix: Int64;
    UName: string;
    GName: string;
  end;

  {** @desc 读取选项：单条目与总量 bomb 守卫 *}
  TTarReadOptions = record
    MaxEntrySize: SizeUInt;
    MaxTotalSize: UInt64;
  end;

  {** @desc 落盘选项 *}
  TTarExtractOptions = record
    RestoreMode: Boolean;
    SkipSpecial: Boolean;
    MaxEntrySize: SizeUInt;
    MaxTotalSize: UInt64;
  end;

const
  C_TAR_BLOCK_SIZE = 512;
  C_TAR_NAME_FIELD = 100;
  C_TAR_PREFIX_FIELD = 155;
  C_TAR_MAX_NAME_BYTES = 512;

  { ustar 固定 }
  C_TAR_MAGIC_USTAR = 'ustar';
  C_TAR_VERSION_00 = '00';
  C_TAR_PAX_HEADER_NAME = 'pax_header';

  { ustar 头部布局（单点复用，读写一致） }
  C_TAR_OFF_NAME = 0;
  C_TAR_LEN_NAME = 100;
  C_TAR_OFF_MODE = 100;
  C_TAR_LEN_MODE = 8;
  C_TAR_OFF_UID = 108;
  C_TAR_LEN_UID = 8;
  C_TAR_OFF_GID = 116;
  C_TAR_LEN_GID = 8;
  C_TAR_OFF_SIZE = 124;
  C_TAR_LEN_SIZE = 12;
  C_TAR_OFF_MTIME = 136;
  C_TAR_LEN_MTIME = 12;
  C_TAR_OFF_CHKSUM = 148;
  C_TAR_LEN_CHKSUM = 8;
  C_TAR_OFF_TYPEFLAG = 156;
  C_TAR_OFF_LINKNAME = 157;
  C_TAR_LEN_LINKNAME = 100;
  C_TAR_OFF_MAGIC = 257;
  C_TAR_LEN_MAGIC = 6;
  C_TAR_OFF_VERSION = 263;
  C_TAR_LEN_VERSION = 2;
  C_TAR_OFF_UNAME = 265;
  C_TAR_LEN_UNAME = 32;
  C_TAR_OFF_GNAME = 297;
  C_TAR_LEN_GNAME = 32;
  C_TAR_OFF_PREFIX = 345;
  C_TAR_LEN_PREFIX = 155;

  { base-256 哨兵与默认权限（0644/0755） }
  C_TAR_BASE256_SENTINEL = $80;
  C_TAR_DEFAULT_FILE_MODE = $1A4;
  C_TAR_DEFAULT_DIR_MODE = $1ED;

  { 默认 bomb 上限（复用 compress GZIP_MAX 1GiB 级别，保持 zip 对齐） }
  C_TAR_DEFAULT_MAX_ENTRY = SizeUInt(1) shl 30;
  C_TAR_DEFAULT_MAX_TOTAL: UInt64 = 0;

  { unix 模式位语义常量（S_IFMT 子集，与 zip.base 命名手感对齐） }
  C_TAR_UNIX_IFREG    = $8000; // S_IFREG
  C_TAR_UNIX_IFDIR    = $4000; // S_IFDIR
  C_TAR_UNIX_IFLNK    = $A000; // S_IFLNK
  C_TAR_UNIX_PERM_MASK = $0FFF; // 低 12 位权限位

function IsSafeTarEntryName(const AName: string): Boolean; inline;
procedure ValidateTarEntryName(const AName: string);

function DefaultTarAddOptions: TTarAddOptions; inline;
function DefaultTarReadOptions: TTarReadOptions; inline;
function DefaultTarExtractOptions: TTarExtractOptions; inline;

{** posix 权限位助手（与 zip 对称，保持调用方手感一致） *}
function TarRegularMode(APermissionBits: Word): Word; inline;
function TarDirectoryMode(APermissionBits: Word): Word; inline;

implementation

uses
  nextpas.core.bytes.pathvalid;

function IsSafeTarEntryName(const AName: string): Boolean; inline;
begin
  Result := nextpas.core.bytes.pathvalid.IsSafeArchiveEntryName(AName, C_TAR_MAX_NAME_BYTES);
end;

procedure ValidateTarEntryName(const AName: string);
begin
  if not IsSafeTarEntryName(AName) then
    raise EArgumentError.Create('tar entry name is not safe: ' + AName);
end;

function DefaultTarAddOptions: TTarAddOptions; inline;
begin
  Result.Mode := 0;
  Result.UID := 0;
  Result.GID := 0;
  Result.MTimeUnix := 0;
  Result.UName := '';
  Result.GName := '';
end;

function DefaultTarReadOptions: TTarReadOptions; inline;
begin
  Result.MaxEntrySize := C_TAR_DEFAULT_MAX_ENTRY;
  Result.MaxTotalSize := C_TAR_DEFAULT_MAX_TOTAL;
end;

function DefaultTarExtractOptions: TTarExtractOptions; inline;
begin
  Result.RestoreMode := True;
  Result.SkipSpecial := True;
  Result.MaxEntrySize := 0;
  Result.MaxTotalSize := 0;
end;

function TarRegularMode(APermissionBits: Word): Word; inline;
begin
  Result := C_TAR_UNIX_IFREG or (APermissionBits and C_TAR_UNIX_PERM_MASK);
end;

function TarDirectoryMode(APermissionBits: Word): Word; inline;
begin
  Result := C_TAR_UNIX_IFDIR or (APermissionBits and C_TAR_UNIX_PERM_MASK);
end;

end.

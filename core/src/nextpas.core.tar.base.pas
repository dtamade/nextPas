unit nextpas.core.tar.base;
{**
 * @desc Tar 基座：类型、常量与名安全谓词，L2 单点。
 * 依赖 nextpas.core.base / exception + nextpas.core.bytes.pathvalid（复用 bytes.ops 单源、inline/零拷贝原串索引，无 FPC RTL 直引）。
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
    DevMajor: Int64;
    DevMinor: Int64;
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

type
  {** @desc ustar 字段描述：Off/Len 合一，单点零拷贝 *}
  TTarField = record Off: SizeUInt; Len: SizeUInt; end;
  {** @desc ustar 头部布局记录表：16字段单源收敛（含 devmajor/devminor），生成器校验连续性，读写一致零错位 *}
  TTarUstarLayout = record
    Name: TTarField;
    Mode: TTarField;
    UID: TTarField;
    GID: TTarField;
    Size: TTarField;
    MTime: TTarField;
    Chksum: TTarField;
    TypeFlag: TTarField;
    LinkName: TTarField;
    Magic: TTarField;
    Version: TTarField;
    UName: TTarField;
    GName: TTarField;
    DevMajor: TTarField;
    DevMinor: TTarField;
    Prefix: TTarField;
  end;

const
  {** @desc ustar 单源记录表：声明噪声归一，由生成器派生散列常量，防手动错位；inline 薄转发零拷贝 *}
  C_TAR_LAYOUT: TTarUstarLayout = (
    Name: (Off: 0; Len: 100);
    Mode: (Off: 100; Len: 8);
    UID: (Off: 108; Len: 8);
    GID: (Off: 116; Len: 8);
    Size: (Off: 124; Len: 12);
    MTime: (Off: 136; Len: 12);
    Chksum: (Off: 148; Len: 8);
    TypeFlag: (Off: 156; Len: 1);
    LinkName: (Off: 157; Len: 100);
    Magic: (Off: 257; Len: 6);
    Version: (Off: 263; Len: 2);
    UName: (Off: 265; Len: 32);
    GName: (Off: 297; Len: 32);
    DevMajor: (Off: 329; Len: 8);
    DevMinor: (Off: 337; Len: 8);
    Prefix: (Off: 345; Len: 155)
  );

  { 兼容别名（生成器收敛）：散列常量由算术生成器派生，相对 C_TAR_LAYOUT 单源保持数值一致（FPC const 不支持记录字段常量表达式），声明噪声归一，防手动错位 }
  C_TAR_OFF_NAME = 0; C_TAR_LEN_NAME = 100;
  C_TAR_OFF_MODE = C_TAR_OFF_NAME + C_TAR_LEN_NAME; C_TAR_LEN_MODE = 8;
  C_TAR_OFF_UID = C_TAR_OFF_MODE + C_TAR_LEN_MODE; C_TAR_LEN_UID = 8;
  C_TAR_OFF_GID = C_TAR_OFF_UID + C_TAR_LEN_UID; C_TAR_LEN_GID = 8;
  C_TAR_OFF_SIZE = C_TAR_OFF_GID + C_TAR_LEN_GID; C_TAR_LEN_SIZE = 12;
  C_TAR_OFF_MTIME = C_TAR_OFF_SIZE + C_TAR_LEN_SIZE; C_TAR_LEN_MTIME = 12;
  C_TAR_OFF_CHKSUM = C_TAR_OFF_MTIME + C_TAR_LEN_MTIME; C_TAR_LEN_CHKSUM = 8;
  C_TAR_OFF_TYPEFLAG = C_TAR_OFF_CHKSUM + C_TAR_LEN_CHKSUM; C_TAR_LEN_TYPEFLAG = 1;
  C_TAR_OFF_LINKNAME = C_TAR_OFF_TYPEFLAG + C_TAR_LEN_TYPEFLAG; C_TAR_LEN_LINKNAME = 100;
  C_TAR_OFF_MAGIC = C_TAR_OFF_LINKNAME + C_TAR_LEN_LINKNAME; C_TAR_LEN_MAGIC = 6;
  C_TAR_OFF_VERSION = C_TAR_OFF_MAGIC + C_TAR_LEN_MAGIC; C_TAR_LEN_VERSION = 2;
  C_TAR_OFF_UNAME = C_TAR_OFF_VERSION + C_TAR_LEN_VERSION; C_TAR_LEN_UNAME = 32;
  C_TAR_OFF_GNAME = C_TAR_OFF_UNAME + C_TAR_LEN_UNAME; C_TAR_LEN_GNAME = 32;
  C_TAR_OFF_DEVMAJOR = C_TAR_OFF_GNAME + C_TAR_LEN_GNAME; C_TAR_LEN_DEVMAJOR = 8;
  C_TAR_OFF_DEVMINOR = C_TAR_OFF_DEVMAJOR + C_TAR_LEN_DEVMAJOR; C_TAR_LEN_DEVMINOR = 8;
  C_TAR_OFF_PREFIX = C_TAR_OFF_DEVMINOR + C_TAR_LEN_DEVMINOR; C_TAR_LEN_PREFIX = 155;

  { base-256 哨兵与默认权限（0644/0755） }
  C_TAR_BASE256_SENTINEL = $80;
  C_TAR_DEFAULT_FILE_MODE = $1A4;
  C_TAR_DEFAULT_DIR_MODE = $1ED;

  { 默认 bomb 上限（复用 compress GZIP_MAX 1GiB 级别，保持 zip 对齐；总量 4GiB 防 100k×1MiB 稀疏 bomb，单条仍 1GiB） }
  C_TAR_DEFAULT_MAX_ENTRY = SizeUInt(1) shl 30;
  C_TAR_DEFAULT_MAX_TOTAL: UInt64 = UInt64(4) * 1024 * 1024 * 1024;

  { unix 模式位语义常量（S_IFMT 子集，与 zip.base 命名手感对齐） }
  C_TAR_UNIX_IFREG    = $8000; // S_IFREG
  C_TAR_UNIX_IFDIR    = $4000; // S_IFDIR
  C_TAR_UNIX_IFLNK    = $A000; // S_IFLNK
  C_TAR_UNIX_PERM_MASK = $0FFF; // 低 12 位权限位

  { builder 初始容量：4K 一页对齐，几何扩容单源，避免大写多次重分配，调优单点 }
  C_TAR_BUILDER_INITIAL_CAPACITY = 4096;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;

function IsSafeTarEntryName(const AName: string): Boolean; inline;
procedure ValidateTarEntryName(const AName: string);

function DefaultTarAddOptions: TTarAddOptions; inline;
function DefaultTarReadOptions: TTarReadOptions; inline;
function DefaultTarExtractOptions: TTarExtractOptions; inline;

{** posix 权限位助手（与 zip 对称，保持调用方手感一致） *}
function TarRegularMode(APermissionBits: Word): Word; inline;
function TarDirectoryMode(APermissionBits: Word): Word; inline;

{** ustar 布局访问器：inline 薄转发零拷贝，复用 C_TAR_LAYOUT 单源 *}
function TarFieldOff(const AField: TTarField): SizeUInt; inline;
function TarFieldLen(const AField: TTarField): SizeUInt; inline;
function TarLayout: TTarUstarLayout; inline;

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
  Result.MaxEntrySize := C_TAR_DEFAULT_MAX_ENTRY;
  Result.MaxTotalSize := C_TAR_DEFAULT_MAX_TOTAL;
end;

function TarRegularMode(APermissionBits: Word): Word; inline;
begin
  Result := C_TAR_UNIX_IFREG or (APermissionBits and C_TAR_UNIX_PERM_MASK);
end;

function TarDirectoryMode(APermissionBits: Word): Word; inline;
begin
  Result := C_TAR_UNIX_IFDIR or (APermissionBits and C_TAR_UNIX_PERM_MASK);
end;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
begin
  // perf: 预扩容按预估总量单点对齐 4K 页，避免大归档多次 2× 几何扩容与重分配；inline 薄转发，复用 C_TAR_BUILDER_INITIAL_CAPACITY 单源，含两零块尾
  if AEstimatedTotal = 0 then
    Exit(C_TAR_BUILDER_INITIAL_CAPACITY);
  // 预留两零块 + 头开销，按 4K 对齐向上取整，消除大写抖动
  Result := AEstimatedTotal + 2 * C_TAR_BLOCK_SIZE;
  if Result < C_TAR_BUILDER_INITIAL_CAPACITY then
    Result := C_TAR_BUILDER_INITIAL_CAPACITY;
  // 4K 对齐
  Result := (Result + 4095) and not SizeUInt(4095);
end;

function TarFieldOff(const AField: TTarField): SizeUInt; inline;
begin
  Result := AField.Off;
end;

function TarFieldLen(const AField: TTarField): SizeUInt; inline;
begin
  Result := AField.Len;
end;

function TarLayout: TTarUstarLayout; inline;
begin
  Result := C_TAR_LAYOUT;
end;

end.

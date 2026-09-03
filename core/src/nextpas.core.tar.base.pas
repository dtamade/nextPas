unit nextpas.core.tar.base;
{**
 * @desc Tar 基座：类型、常量与名安全谓词，L2 单点。
 * 依赖 nextpas.core.base / exception + nextpas.core.bytes.ops (AlignUp4K 单源) + nextpas.core.bytes.pathvalid。零依赖同模块，守四件套 base 纯度。
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
  C_TAR_MAX_LINK_BYTES = 4096;

  { ustar 固定 }
  C_TAR_MAGIC_USTAR = 'ustar';
  C_TAR_VERSION_00 = '00';
  C_TAR_PAX_HEADER_NAME = 'pax_header';

type
  {** @desc ustar 字段描述：Off/Len 合一，单点零拷贝 *}
  TTarField = record Off: SizeUInt; Len: SizeUInt; end;
  {** @desc ustar 头部布局记录表：16字段单点收敛（含 devmajor/devminor），读写经 C_TAR_LAYOUT 单源 inline 零拷贝访问零错位 *}
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
  {** @desc ustar 字段 Off/Len 单源常量：16 字段 ordinal 常量，布局与 reader case 跳表单源零漂移，见 CONTRACT §2 INV-7 *}
  C_TAR_OFF_NAME     = 0;   C_TAR_LEN_NAME     = 100;
  C_TAR_OFF_MODE     = 100; C_TAR_LEN_MODE     = 8;
  C_TAR_OFF_UID      = 108; C_TAR_LEN_UID      = 8;
  C_TAR_OFF_GID      = 116; C_TAR_LEN_GID      = 8;
  C_TAR_OFF_SIZE     = 124; C_TAR_LEN_SIZE     = 12;
  C_TAR_OFF_MTIME    = 136; C_TAR_LEN_MTIME    = 12;
  C_TAR_OFF_CHKSUM   = 148; C_TAR_LEN_CHKSUM   = 8;
  C_TAR_OFF_TYPEFLAG = 156; C_TAR_LEN_TYPEFLAG = 1;
  C_TAR_OFF_LINKNAME = 157; C_TAR_LEN_LINKNAME = 100;
  C_TAR_OFF_MAGIC    = 257; C_TAR_LEN_MAGIC    = 6;
  C_TAR_OFF_VERSION  = 263; C_TAR_LEN_VERSION  = 2;
  C_TAR_OFF_UNAME    = 265; C_TAR_LEN_UNAME    = 32;
  C_TAR_OFF_GNAME    = 297; C_TAR_LEN_GNAME    = 32;
  C_TAR_OFF_DEVMAJOR = 329; C_TAR_LEN_DEVMAJOR = 8;
  C_TAR_OFF_DEVMINOR = 337; C_TAR_LEN_DEVMINOR = 8;
  C_TAR_OFF_PREFIX   = 345; C_TAR_LEN_PREFIX   = 155;

const
  {** @desc ustar 布局单源表：16 字段 Off/Len，读写经 C_TAR_LAYOUT inline 零拷贝访问，见 CONTRACT §2 INV-7 *}
  C_TAR_LAYOUT: TTarUstarLayout = (
    Name: (Off: C_TAR_OFF_NAME; Len: C_TAR_LEN_NAME);
    Mode: (Off: C_TAR_OFF_MODE; Len: C_TAR_LEN_MODE);
    UID: (Off: C_TAR_OFF_UID; Len: C_TAR_LEN_UID);
    GID: (Off: C_TAR_OFF_GID; Len: C_TAR_LEN_GID);
    Size: (Off: C_TAR_OFF_SIZE; Len: C_TAR_LEN_SIZE);
    MTime: (Off: C_TAR_OFF_MTIME; Len: C_TAR_LEN_MTIME);
    Chksum: (Off: C_TAR_OFF_CHKSUM; Len: C_TAR_LEN_CHKSUM);
    TypeFlag: (Off: C_TAR_OFF_TYPEFLAG; Len: C_TAR_LEN_TYPEFLAG);
    LinkName: (Off: C_TAR_OFF_LINKNAME; Len: C_TAR_LEN_LINKNAME);
    Magic: (Off: C_TAR_OFF_MAGIC; Len: C_TAR_LEN_MAGIC);
    Version: (Off: C_TAR_OFF_VERSION; Len: C_TAR_LEN_VERSION);
    UName: (Off: C_TAR_OFF_UNAME; Len: C_TAR_LEN_UNAME);
    GName: (Off: C_TAR_OFF_GNAME; Len: C_TAR_LEN_GNAME);
    DevMajor: (Off: C_TAR_OFF_DEVMAJOR; Len: C_TAR_LEN_DEVMAJOR);
    DevMinor: (Off: C_TAR_OFF_DEVMINOR; Len: C_TAR_LEN_DEVMINOR);
    Prefix: (Off: C_TAR_OFF_PREFIX; Len: C_TAR_LEN_PREFIX)
  );

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

  { 容量阈值固化于本 base 常量，对齐经 bytes.ops.AlignUp4K 单源 }
  C_TAR_BUILDER_INITIAL_CAPACITY = 4096; // 4K floor
  C_TAR_IOBUF_INIT = 4096;
  C_TAR_IOBUF_MAX = 1048576; // 1M clamp，单分发 high-water，消除 1M 拆 16次 WriteChecked 抖动
  C_TAR_CAP_ALIGN = 4096;

{ 容量策略：对齐经 bytes.ops.AlignUp4K 单源，阈值见上方常量 }
function TarCapacityAlign4K(const AValue: SizeUInt): SizeUInt; inline;
function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
function TarIOBufCapacityFor(const ASize: Int64): SizeUInt; inline;

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
  nextpas.core.bytes.ops,
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

function TarCapacityAlign4K(const AValue: SizeUInt): SizeUInt; inline;
begin
  // 单源 4K 对齐经 bytes.ops.AlignUp4K 位掩码零除法 inline 零拷贝，无截断，32/64位安全，base 纯度零依赖 capacity
  Result := AlignUp4K(AValue);
end;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
begin
  // 单源容量策略：预估+两零块 1024，floor 4K，4K 对齐经 AlignUp4K inline 零拷贝（阈值分叉固化于本 base 常量），修复 64K 小包 128倍驻留
  if AEstimatedTotal = 0 then
    Exit(C_TAR_BUILDER_INITIAL_CAPACITY);
  if AEstimatedTotal > High(SizeUInt) - 2 * 512 then
    Exit(High(SizeUInt));
  Result := AEstimatedTotal + 2 * 512;
  if Result < C_TAR_BUILDER_INITIAL_CAPACITY then
    Result := C_TAR_BUILDER_INITIAL_CAPACITY;
  Result := TarCapacityAlign4K(Result);
end;

function TarIOBufCapacityFor(const ASize: Int64): SizeUInt; inline;
begin
  // 单源 I/O 缓冲策略：4K~1M clamp + AlignUp4K inline 零拷贝，高水位 1M 单分发，消除 1M 拆 16次抖动，base 纯度
  if ASize <= Int64(C_TAR_IOBUF_INIT) then
    Exit(C_TAR_IOBUF_INIT);
  if ASize <= Int64(C_TAR_IOBUF_MAX) then
    Exit(TarCapacityAlign4K(SizeUInt(ASize)));
  Result := C_TAR_IOBUF_MAX;
end;

end.

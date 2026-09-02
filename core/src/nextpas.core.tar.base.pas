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
  {** @desc ustar 布局单源表：16 字段 Off/Len，读写经 C_TAR_LAYOUT inline 零拷贝访问，见 CONTRACT §2 INV-7 *}
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

  { 初始容量：单源 64K }
  C_TAR_BUILDER_INITIAL_CAPACITY = 65536;
  C_TAR_IOBUF_INIT = 4096;

  { 全局 pax 可观测 Warn 文案单源（reader 日志复用，防硬编码分散） }
  C_TAR_WARN_GLOBAL_PAX_AUTO_CLEAR = 'tar: global pax auto-cleared after single use (no guard held; hold AcquireGlobalPaxGuard IInterface to persist across Next/image, or call ClearGlobalPax explicitly)';
  C_TAR_WARN_GLOBAL_PAX_REJECTED_PREFIX = 'tar: global pax rejected unsafe name: ';
  C_TAR_WARN_GLOBAL_PAX_REJECTED_SUFFIX = ' (filtered, not persisted)';

{ 统一容量策略单源：4K 对齐经 bytes.ops.AlignUp4K 位掩码零除法 inline 零拷贝，阈值分叉由调用方域语义决定（builder floor 64K / IOBuf 4K~64K clamp），候选下沉 nextpas.core.tar.capacity 专用模块 }
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
  // 统一容量策略单源：4K 对齐经 bytes.ops.AlignUp4K 位掩码零除法 inline 零拷贝，阈值分叉保留域语义，候选下沉 nextpas.core.tar.capacity 专用模块
  Result := AlignUp4K(AValue);
end;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
begin
  // 统一容量策略：预估+两零块，floor 64K，4K 对齐经 TarCapacityAlign4K→bytes.ops.AlignUp4K 单源 inline 零拷贝（阈值分叉：builder floor 64K/IOBuf clamp 4K~64K 同复用对齐单源）
  if AEstimatedTotal = 0 then
    Exit(C_TAR_BUILDER_INITIAL_CAPACITY);
  if AEstimatedTotal > High(SizeUInt) - 2 * C_TAR_BLOCK_SIZE then
    Exit(High(SizeUInt) and not SizeUInt(4095));
  Result := AEstimatedTotal + 2 * C_TAR_BLOCK_SIZE;
  if Result < C_TAR_BUILDER_INITIAL_CAPACITY then
    Result := C_TAR_BUILDER_INITIAL_CAPACITY;
  Result := TarCapacityAlign4K(Result);
end;

function TarIOBufCapacityFor(const ASize: Int64): SizeUInt; inline;
begin
  // perf: 统一容量策略阈值分叉+对齐单源 TarCapacityAlign4K→bytes.ops.AlignUp4K inline零拷贝；>64K直达AlignUp4K消除1MB拆16次WriteChecked抖动，1M封顶单分发high-water池化，候选tar.capacity模块
  if ASize <= Int64(C_TAR_IOBUF_INIT) then
    Exit(C_TAR_IOBUF_INIT);
  if ASize <= Int64(C_TAR_BUILDER_INITIAL_CAPACITY) * 16 then
    Exit(TarCapacityAlign4K(SizeUInt(ASize)));
  Result := SizeUInt(C_TAR_BUILDER_INITIAL_CAPACITY) * 16;
end;

end.

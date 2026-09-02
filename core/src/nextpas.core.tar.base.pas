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
  {** @desc ustar 单源记录表：16 字段 Off/Len 单点收敛，生成器单点派生，零拷贝 inline 访问；散列常量已归一消除，读写经 C_TAR_LAYOUT 单源 inline 访问零错位 *}
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

  { builder 初始容量：64K（16×4K 页）对齐，几何扩容单源；小归档覆盖 ~60×(512 header+512 data) 无扩容，200×512B 仅需 2 次 2× 扩容 vs 旧 4K 的 6 次重分配；大归档必须用 TarBuilderWithCapacity 显式预估（TarBuilderCapacityFor 单点 4K 对齐），调优单点 }
  C_TAR_BUILDER_INITIAL_CAPACITY = 65536;

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;

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

function TarBuilderCapacityFor(const AEstimatedTotal: SizeUInt): SizeUInt; inline;
begin
  // perf: 预扩容按预估总量单点对齐 4K 页，避免大归档多次 2× 几何扩容与重分配；inline 薄转发，复用 C_TAR_BUILDER_INITIAL_CAPACITY(64K)单源，含两零块尾；复用 bytes.ops AlignUp4K 常量 4096 位掩码单源零除法，无 and not SizeUInt 截断，32/64 位安全；大归档请用 TarBuilderWithCapacity 显式预估，避免默认 64K 仍需 2 次扩容（200×512B≈205K：64K→128K→256K），旧 4K 需 6 次
  if AEstimatedTotal = 0 then
    Exit(C_TAR_BUILDER_INITIAL_CAPACITY);
  // 预留两零块 + 头开销，按 4K 对齐向上取整，消除大写抖动
  Result := AEstimatedTotal + 2 * C_TAR_BLOCK_SIZE;
  if Result < C_TAR_BUILDER_INITIAL_CAPACITY then
    Result := C_TAR_BUILDER_INITIAL_CAPACITY;
  // 4K 对齐：复用 bytes.ops AlignUp4K 常量 4096 位掩码单源零除法，无截断，32/64 位安全
  Result := AlignUp4K(Result);
end;

end.

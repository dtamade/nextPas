unit nextpas.core.respack.base;

{** @desc respack 线格式 v1 基座：常量、record、LE 编解码、路径语法、FNV-1a、错误。
  权威格式定义见 core/docs/respack/FORMAT.md；实现与文档冲突时先修文档。
  双编译器：FPC 编译时 uses SysUtils 等经 FPC 自带 RTL 自然解析，nextPas 编译时经
  units/<target>/SysUtils.pas stub 名称桥接（非兼容层）；本单元零直引 SysUtils
  (uses 仅 L0/L1 单源 bytes.binary/bytes.pathvalid/checksum.fnv32/text.number/mem)，
  证据链见 core/docs/respack/README.md 与 CLAUDE.md 双编译器架构。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception;

const
  { 线格式常量（FORMAT.md） }
  RESPACK_MAGIC: array[0..3] of AnsiChar = ('N', 'P', 'R', 'S');
  RESPACK_VERSION              = 1;
  RESPACK_HEADER_SIZE          = 40;
  RESPACK_ENTRY_SIZE           = 40;
  RESPACK_DATA_ALIGN           = 16;
  RESPACK_DIGEST_SIZE          = 32;

  { header flags；bit0/bit1 已定义，bit2-4 digest 算法 ID（FORMAT.md） }
  RESPACK_FLAG_HASHED   = $00000001;  { 全部条目 hash 有效（汇总提示） }
  RESPACK_FLAG_DIGESTED = $00000002;  { digest 区存在 }
  RESPACK_FLAG_ALGO_MASK  = $0000001C;  { bit2-4 digest 算法 ID 掩码 }
  RESPACK_FLAG_ALGO_SHIFT = 2;
  RESPACK_DIGEST_ALGO_SHA256 = 0;       { 0 = SHA-256（v1 唯一合法值） }
  RESPACK_FLAG_KNOWN    = RESPACK_FLAG_HASHED or RESPACK_FLAG_DIGESTED
    or RESPACK_FLAG_ALGO_MASK;

  { entry flags }
  RESPACK_EFLAG_HASHED = $0001;      { 本条目 hash 有效（权威判定） }
  RESPACK_EFLAG_KNOWN  = RESPACK_EFLAG_HASHED;

  { codecId 登记表（FORMAT.md）；未知值 reader 整包拒绝 }
  RESPACK_CODEC_STORE = 0;

  { writer 输入上限（CONTRACT INV-R10）：超出显式 raise，绝不静默产出坏包 }
  RESPACK_MAX_INPUT_BYTES = SizeUInt(512) * 1024 * 1024;
  { reader 熔断：entryCount 上界（INV-R10 防御深度，512M/40≈12.8M），SetLength 前硬熔断防恶意包 OOM }
  RESPACK_MAX_ENTRY_COUNT = RESPACK_MAX_INPUT_BYTES div RESPACK_ENTRY_SIZE;

type
  { host-order API record；线上布局一律经 LE helper 编解码（BE 平台安全） }
  TResPackHeader = record
    Version: UInt32;
    Flags: UInt32;
    EntryCount: UInt32;
    IndexOffset: UInt64;
    DigestOffset: UInt64;  { 0 = 无 digest 区 }
    BlobTotal: UInt64;
  end;

  TResPackEntry = record
    PathOffset: UInt32;    { 相对 string table 基址 }
    PathLen: Word;
    Flags: Word;
    DataOffset: UInt64;    { blob 内绝对偏移 }
    Size: UInt64;
    ModTime: Int64;        { Unix 秒；0 = 未知 }
    Hash: UInt32;          { FNV-1a 32；Flags 含 HASHED 时有效 }
    CodecId: Byte;
  end;

  TResPackDigest = array[0..RESPACK_DIGEST_SIZE - 1] of Byte;

  { writer 输入条目：内容由调用方持有，Build 过程内只读 }
  TResPackInputEntry = record
    Path: string;          { 必须通过 ResPackValidPath；'.' 根不是文件路径 }
    Data: PByte;
    DataSize: SizeUInt;
    ModTime: Int64;
  end;

  TResPackInputArray = array of TResPackInputEntry;

  TResPackDigestFunc = reference to procedure(const AData: PByte;
    const ASize: SizeUInt; const ADigestOut: PByte);

  TResPackBuildOptions = record
    Deduplicate: Boolean;         { fnv 候选 + 字节回验后复用槽位 }
    Hashes: Boolean;              { 计算并写入条目 FNV-1a }
    CodecId: Byte;                { 编解码；默认 STORE=0 }
    DigestFunc: TResPackDigestFunc; { nil = 无 digest 区 }
    MaxTotalInputBytes: SizeUInt; { 输入总量上限；超限 EResPackTooLarge }
  end;

  { Build 产物：Owned=True 时 Data 为堆缓冲，须 ResPackFreeBlob 归还 }
  TResPackBlob = record
    Data: PByte;
    Size: SizeUInt;
    Owned: Boolean;
  end;

  { 错误层级：全部挂在 exception 根上，不触碰 SysUtils。
    对齐 vfs EVfsError(Op/Path) 范式：Op/Path 结构化定位，message 保留
    详情后缀 (op=…, path=…) 质感；CreateStep 补充 Op/Path 重载。 }
  EResPackError = class(Exception)
  private
    FOp: string;
    FPath: string;
  public
    constructor Create(const AMsg: string); overload;
    constructor CreateCtx(const AOp, APath, AMsg: string); overload;
    property Op: string read FOp;
    property Path: string read FPath;
  end;
  EResPackCorrupted = class(EResPackError)
  private
    FStep: Integer;
  public
    constructor Create(const AMsg: string); overload;
    constructor CreateStep(const AStep: Integer; const ADetail: string); overload;
    constructor CreateStep(const AStep: Integer; const AOp, APath, ADetail: string); overload;
    constructor CreateCtx(const AOp, APath, AMsg: string); overload;
    property Step: Integer read FStep;
  end;
  EResPackDuplicatePath = class(EResPackError);
  EResPackInvalidPath = class(EResPackError);
  EResPackNotFound = class(EResPackError);
  EResPackTooLarge = class(EResPackError);
  EResPackDirSourceFailed = class(EResPackError);

{ LE 编解码 — 单源于 bytes.binary.Read/WriteUInt*LE (host-endian 无关), inline 零拷贝转发 }
function RdU16LE(AData: PByte): Word; inline;
function RdU32LE(AData: PByte): UInt32; inline;
function RdU64LE(AData: PByte): UInt64; inline;
procedure WrU16LE(AData: PByte; const AValue: Word); inline;
procedure WrU32LE(AData: PByte; const AValue: UInt32); inline;
procedure WrU64LE(AData: PByte; const AValue: UInt64); inline;

{ FNV-1a 32 — 单源于 L1 checksum.fnv32.Fnv1a32Update (批量 8 字节展开, 零拷贝 PByte+SizeUInt 视图), inline 转发; LE 单源于 bytes.binary }
function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32; inline;

{ Go io/fs.ValidPath 语义（FORMAT.md 路径规范）：UTF-8、unrooted、'/'
  分隔、段非空非'.'非'..'、反斜杠为普通字符；特例 '.' 表根。
  文件条目场景 AFileEntry=True 时拒绝根。
  perf: 热路径（writer/reader 批量校验 10k 条目）inline 消除调用开销，对齐
  ResPackFnv1a32 单源转发，零拷贝视图经 bytes.pathvalid。 }
function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean; inline;

{ 路径字节比较单源：writer/reader 共用，零拷贝 SpanCompare 转发，inline 零开销，owner bytes.ops }
function ResPackCmpPath(const PA: PByte; const LA: SizeUInt; const PB: PByte; const LB: SizeUInt): Integer; inline;

{ 默认构建选项 }
function ResPackDefaultOptions: TResPackBuildOptions; inline;

procedure ResPackFreeBlob(var ABlob: TResPackBlob); inline;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.pathvalid,
  nextpas.core.checksum.fnv32,
  nextpas.core.mem,
  nextpas.core.text.number;

function RdU16LE(AData: PByte): Word; inline;
begin
  Result := Word(ReadUInt16LE(AData));
end;

function RdU32LE(AData: PByte): UInt32; inline;
begin
  Result := ReadUInt32LE(AData);
end;

function RdU64LE(AData: PByte): UInt64; inline;
begin
  Result := ReadUInt64LE(AData);
end;

procedure WrU16LE(AData: PByte; const AValue: Word); inline;
begin
  WriteUInt16LE(AData, AValue);
end;

procedure WrU32LE(AData: PByte; const AValue: UInt32); inline;
begin
  WriteUInt32LE(AData, AValue);
end;

procedure WrU64LE(AData: PByte; const AValue: UInt64); inline;
begin
  WriteUInt64LE(AData, AValue);
end;

function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32; inline;
begin
  { 零拷贝视图直接转 checksum 单源批量路径 (8 字节展开), 不分配, inline 消除调用开销 }
  Result := UInt32(Fnv1a32Update(FNV1A32_OFFSET, Pointer(AData), ASize));
end;

function ResPackCmpPath(const PA: PByte; const LA: SizeUInt; const PB: PByte; const LB: SizeUInt): Integer; inline;
begin
  Result := SpanCompare(TByteSpan.Create(PA, LA), TByteSpan.Create(PB, LB));
end;

function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean; inline;
begin
  Result := BytesValidPath(APath, not AFileEntry);
end;

function ResPackDefaultOptions: TResPackBuildOptions;
begin
  Result.Deduplicate := False;
  Result.Hashes := True;
  Result.CodecId := RESPACK_CODEC_STORE;
  Result.DigestFunc := nil;
  Result.MaxTotalInputBytes := RESPACK_MAX_INPUT_BYTES;
end;

procedure ResPackFreeBlob(var ABlob: TResPackBlob); inline;
begin
  if ABlob.Owned and (ABlob.Data <> nil) then
    FreeMem(ABlob.Data, ABlob.Size);
  ABlob.Data := nil;
  ABlob.Size := 0;
  ABlob.Owned := False;
end;

{ 十进制整数转字符串 — 单源于 L1 text.number.UIntToBuffer (DIGIT_PAIRS 批量),
  仅 EResPackCorrupted.CreateStep 报错路径使用；冷路径外联避免 I-Cache 膨胀，
  零拷贝单源 bytes.ops.BytesCopy inline 单 Move，禁止直调 Move 破坏单源纪律。 }
function ResPackUIntToStr(AValue: UInt32): string;
var
  LBuf: array[0..15] of AnsiChar;
  LLen: Int32;
begin
  LLen := UIntToBuffer(UInt64(AValue), @LBuf[0]);
  SetLength(Result, LLen);
  if LLen > 0 then
    BytesCopy(PAnsiChar(Result), @LBuf[0], SizeUInt(LLen));
end;

constructor EResPackError.Create(const AMsg: string);
begin
  inherited Create(AMsg);
  FOp := '';
  FPath := '';
end;

constructor EResPackError.CreateCtx(const AOp, APath, AMsg: string);
begin
  inherited Create(AMsg + ' (op=' + AOp + ', path=' + APath + ')');
  FOp := AOp;
  FPath := APath;
end;

constructor EResPackCorrupted.Create(const AMsg: string);
begin
  inherited Create(AMsg);
  FStep := 0;
end;

constructor EResPackCorrupted.CreateStep(const AStep: Integer; const ADetail: string);
begin
  CreateStep(AStep, 'open', '', ADetail);
end;

constructor EResPackCorrupted.CreateStep(const AStep: Integer; const AOp,
  APath, ADetail: string);
begin
  FStep := AStep;
  inherited CreateCtx(AOp, APath, 'respack: validation step '
    + ResPackUIntToStr(UInt32(AStep)) + ' failed: ' + ADetail);
  FStep := AStep;
end;

constructor EResPackCorrupted.CreateCtx(const AOp, APath, AMsg: string);
begin
  FStep := 0;
  inherited CreateCtx(AOp, APath, AMsg);
end;

end.

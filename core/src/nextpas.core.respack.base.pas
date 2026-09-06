unit nextpas.core.respack.base;

{** @desc respack 线格式 v1 基座：常量/record/LE/路径/FNV/错误，见 FORMAT.md。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.mem.arena.local;

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

  { 输入上限 INV-R10：超限显式 raise }
  RESPACK_MAX_INPUT_BYTES = SizeUInt(512) * 1024 * 1024;
  { 小包便捷 ≤64MiB（INV-R10 家族，流式 ~1×+头） }
  RESPACK_DIRSOURCE_LEGACY_LIMIT = SizeUInt(64) * 1024 * 1024;
  { 熔断：entryCount ≤12.8M（512M/40） }
  RESPACK_MAX_ENTRY_COUNT = RESPACK_MAX_INPUT_BYTES div RESPACK_ENTRY_SIZE;
  { 头块 64K 分片 }
  RESPACK_WRITER_HEAD_CHUNK = SizeUInt(64) * 1024;

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

  { 流式写回调单源：writer.stream/intf/门面均转发此声明，零分叉。 }
  TResPackWriteProc = reference to procedure(const AData: PByte;
    const ASize: SizeUInt);

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

  { 错误：挂 ENextPasError 框架根(Op/Path 结构化；CreateStep 重载)，
    类目见各 DefaultCategory，catch ENextPasError 统一收敛 }
  EResPackError = class(ENextPasError)
  private
    FOp: string;
    FPath: string;
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMsg: string); overload;
    constructor CreateCtx(const AOp, APath, AMsg: string); overload;
    property Op: string read FOp;
    property Path: string read FPath;
  end;
  EResPackCorrupted = class(EResPackError)
  private
    FStep: Integer;
  protected
    class function DefaultCategory: TErrorCategory; override;
  public
    constructor Create(const AMsg: string); overload;
    constructor CreateStep(const AStep: Integer; const ADetail: string); overload;
    constructor CreateStep(const AStep: Integer; const AOp, APath, ADetail: string); overload;
    constructor CreateCtx(const AOp, APath, AMsg: string); overload;
    property Step: Integer read FStep;
  end;
  EResPackDuplicatePath = class(EResPackError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;
  EResPackInvalidPath = class(EResPackError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;
  EResPackNotFound = class(EResPackError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;
  EResPackTooLarge = class(EResPackError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;
  EResPackDirSourceFailed = class(EResPackError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

{ Dedup/overlap arena：base 统一拥有，writer.layout/reader 共享，单 slab。 }
type
  PSizeInt = ^SizeInt;
  TResPackDistinct = record Off: UInt64; Size: UInt64; end;
  PResPackDistinct = ^TResPackDistinct;

  // MIN=256 为哈希分散下限(CONTRACT 锁定)；writer.layout N<=4 已走线性免 arena，
  // reader overlap tiny(N=2..4)仍 MIN 256 单 slab(256*8=2K)Open 期一次性、try..finally 释放，相对 Total 可忽略，保留 MIN。
  TResPackDedupBuckets = record
    const MIN = 256; // MIN 256 保障哈希分散，tiny pack 2K slab 可忽略
    const MAX = 65536;
    class function BucketCountFor(const ANeeded: SizeUInt): SizeUInt; static; inline;
  end;

procedure ResPackDedupInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ABucketCount: SizeUInt);
procedure ResPackOverlapInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ADistinct: PResPackDistinct; out ABucketCount: SizeUInt);
procedure ResPackDedupDone(var AArena: TLocalArena); inline;

{ LE：转发 bytes.binary，inline }
function RdU16LE(AData: PByte): Word; inline;
function RdU32LE(AData: PByte): UInt32; inline;
function RdU64LE(AData: PByte): UInt64; inline;
procedure WrU16LE(AData: PByte; const AValue: Word); inline;
procedure WrU32LE(AData: PByte; const AValue: UInt32); inline;
procedure WrU64LE(AData: PByte; const AValue: UInt64); inline;

{ FNV-1a：转发 checksum.fnv32，inline }
function ResPackFnv1a32(const AData: PByte; const ASize: SizeUInt): UInt32; inline;

{ ValidPath：Go io/fs 语义，热路径 inline，零拷贝 bytes.pathvalid }
function ResPackValidPath(const APath: string;
  const AFileEntry: Boolean): Boolean; inline;
function ResPackValidSpan(const ASpan: TByteSpan;
  const AFileEntry: Boolean): Boolean; inline;

{ CmpPath：SpanCompare 转发，inline，owner bytes.ops }
function ResPackCmpPath(const PA: PByte; const LA: SizeUInt; const PB: PByte; const LB: SizeUInt): Integer; inline;

{ 默认构建选项 }
function ResPackDefaultOptions: TResPackBuildOptions; inline;

procedure ResPackFreeBlob(var ABlob: TResPackBlob); inline;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.pathvalid,
  nextpas.core.checksum.fnv32,
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

function ResPackValidSpan(const ASpan: TByteSpan;
  const AFileEntry: Boolean): Boolean; inline;
begin
  Result := BytesValidSpan(ASpan, not AFileEntry);
end;

function ResPackDefaultOptions: TResPackBuildOptions;
begin
  { 去重默认开：同内容零代价共享槽位（fnv 候选+逐字节回验），50%重复实测更快、
    全 miss +4%内；CONTRACT/FORMAT 已同步，BENCH 门限守护。 }
  Result.Deduplicate := True;
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

{ Dedup/overlap arena 单源实现：base 统一拥有，writer.layout/reader 共享，bytes.ops.BytesNextCapacity 单源，TLocalArena 单 slab }

class function TResPackDedupBuckets.BucketCountFor(const ANeeded: SizeUInt): SizeUInt; inline;
var
  Target: SizeUInt;
begin
  if ANeeded <= MIN then Exit(MIN);
  if ANeeded >= MAX then Exit(MAX);
  Target := ANeeded;
  Result := BytesNextCapacity(MIN, Target);
  if Result > MAX then Result := MAX;
  if Result < MIN then Result := MIN;
end;

procedure ResPackDedupInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ABucketCount: SizeUInt);
var
  NeedArena: SizeUInt;
  Target: SizeUInt;
  I: SizeUInt;
begin
  AArena := nil;
  ABucketsHead := nil;
  ASlotNext := nil;
  ABucketCount := 0;
  if AN = 0 then Exit;
  Target := 0;
  if not TryMulSizeUInt(AN, 2, Target) then
    Target := High(SizeUInt);
  ABucketCount := TResPackDedupBuckets.BucketCountFor(Target);
  if not TryMulSizeUInt(ABucketCount + AN, SizeUInt(SizeOf(SizeInt)), NeedArena) then
    raise EResPackTooLarge.Create('respack: dedup arena size overflow');
  try
    AArena := TLocalArena.Create(NeedArena);
  except
    on E: EOutOfMemoryError do
      raise EResPackTooLarge.Create('respack: dedup arena too large');
  end;
  ABucketsHead := PSizeInt(AArena.Alloc(ABucketCount * SizeUInt(SizeOf(SizeInt))));
  ASlotNext := PSizeInt(AArena.Alloc(AN * SizeUInt(SizeOf(SizeInt))));
  if (ABucketsHead = nil) or (ASlotNext = nil) then
    raise EResPackTooLarge.Create('respack: dedup arena alloc failed');
  FillChar(ABucketsHead^, ABucketCount * SizeUInt(SizeOf(SizeInt)), $FF);
  FillChar(ASlotNext^, AN * SizeUInt(SizeOf(SizeInt)), $FF);
end;

procedure ResPackOverlapInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ADistinct: PResPackDistinct; out ABucketCount: SizeUInt);
var
  NeedBuckets, NeedDistinct, Total: SizeUInt;
  Target: SizeUInt;
begin
  AArena := nil;
  ABucketsHead := nil;
  ASlotNext := nil;
  ADistinct := nil;
  ABucketCount := 0;
  if AN <= 1 then Exit;
  Target := 0;
  if not TryMulSizeUInt(AN, 2, Target) then Target := High(SizeUInt);
  ABucketCount := TResPackDedupBuckets.BucketCountFor(Target);
  if not TryMulSizeUInt(ABucketCount + AN, SizeUInt(SizeOf(SizeInt)), NeedBuckets) then
    raise EResPackTooLarge.Create('respack: overlap arena size overflow');
  if not TryMulSizeUInt(AN, SizeUInt(SizeOf(TResPackDistinct)), NeedDistinct) then
    raise EResPackTooLarge.Create('respack: overlap distinct size overflow');
  if not TryAddSizeUInt(NeedBuckets, NeedDistinct, Total) then
    raise EResPackTooLarge.Create('respack: overlap arena size overflow');
  try
    AArena := TLocalArena.Create(Total);
  except
    on E: EOutOfMemoryError do
      raise EResPackTooLarge.Create('respack: overlap arena too large');
  end;
  ABucketsHead := PSizeInt(AArena.Alloc(ABucketCount * SizeUInt(SizeOf(SizeInt))));
  ASlotNext := PSizeInt(AArena.Alloc(AN * SizeUInt(SizeOf(SizeInt))));
  ADistinct := PResPackDistinct(AArena.Alloc(AN * SizeUInt(SizeOf(TResPackDistinct))));
  if (ABucketsHead = nil) or (ASlotNext = nil) or (ADistinct = nil) then
    raise EResPackTooLarge.Create('respack: overlap arena alloc failed');
  FillChar(ABucketsHead^, ABucketCount * SizeUInt(SizeOf(SizeInt)), $FF);
  FillChar(ASlotNext^, AN * SizeUInt(SizeOf(SizeInt)), $FF);
end;

procedure ResPackDedupDone(var AArena: TLocalArena); inline;
begin
  if AArena <> nil then
  begin
    AArena.Free;
    AArena := nil;
  end;
end;

{ 十进制转字符串单源于 text.number }
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

class function EResPackError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function EResPackCorrupted.DefaultCategory: TErrorCategory;
begin
  Result := ecParse;
end;

class function EResPackDuplicatePath.DefaultCategory: TErrorCategory;
begin
  Result := ecAlreadyExists;
end;

class function EResPackInvalidPath.DefaultCategory: TErrorCategory;
begin
  Result := ecInvalidArgument;
end;

class function EResPackNotFound.DefaultCategory: TErrorCategory;
begin
  Result := ecNotFound;
end;

class function EResPackTooLarge.DefaultCategory: TErrorCategory;
begin
  Result := ecResourceExhausted;
end;

class function EResPackDirSourceFailed.DefaultCategory: TErrorCategory;
begin
  Result := ecIO;
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

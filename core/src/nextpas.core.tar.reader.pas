unit nextpas.core.tar.reader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf,
  nextpas.core.log.intf;

type
  TTarReader = class;

  {** @desc pax 数值/文本覆盖集（x 单条目与 g 全局各一份；Extra 保序透传未知键） *}
  TPaxExtSet = record
    HasSize, HasMTime, HasUID, HasGID, HasUName, HasGName: Boolean;
    Size, MTimeUnix: Int64;
    UID, GID: Cardinal;
    UName, GName: string;
    Extra: TPaxRecordArray;
  end;

  {** @desc 稀疏段（文件内偏移/长度，均为真实字节） *}
  TSparseSeg = record Off, Len: Int64; end;
  TSparseSegArray = array of TSparseSeg;

  {** @desc RAII guard for global pax: clears global pax on scope exit. *}
  TTarGlobalPaxGuard = class(TInterfacedObject)
  private
    FReader: TTarReader;
    FNext: TTarGlobalPaxGuard;
    procedure Invalidate;
  public
    constructor Create(AReader: TTarReader);
    destructor Destroy; override;
  end;

  {** @desc Tar 读器：迭代内存镜像中的条目，零拷贝视图 + bomb 守卫。
   *  @note 生命周期：TrySlice/EntryDataSlice 为零拷贝 TByteSpan/PByte 视图（inline 单一规范，生命周期绑 Reader）；OpenEntryStream 为零拷贝持有视图（FBuf 时 CreateWithHold 零拷贝持有镜像、Reader 释放后仍可读；外部 PByte 时构造期单次 SpanClone 高水位持有 FBuf（200 条目批量 1 次 vs 200 次），OpenEntryStream 零拷贝持有 FBuf、Reader/外部缓冲释放后仍可读，单次 Move bytes.ops 单源，防 UAF/高频 allocs，Next 迭代已不悬垂）。 *}
  TTarReader = class
  private
    FBuf: TBytes;
    FData: PByte;
    FCount: SizeUInt;
    FPos: SizeUInt;
    FEntryDataOfs: SizeUInt;
    FEntrySize: Int64;
    FPendingLongName: string;
    FPendingLongLink: string;
    FPaxPath: string;
    FPaxLinkPath: string;
    // g pax: guard-scoped persistence, else single-use auto-clear, IsSafe filtered
    FGlobalPaxPath: string;
    FGlobalPaxLinkPath: string;
    // pax typed overrides: per-entry x wins, else guard-scoped g, else single-use g
    FPaxExt: TPaxExtSet;
    FGlobalPaxExt: TPaxExtSet;
    // sparse: x(GNU.sparse.*) sets pending, placeholder data entry consumes; S parses inline
    FSparsePending: Boolean;
    FSparseRealName: string;
    FSparseRealSize: Int64;
    FSparseBuf: TBytes;
    FSparseValid: Boolean;
    // hot-path gate: per-entry ext state cleared only when dirtied
    FExtDirty: Boolean;
    FMaxEntry: SizeUInt;
    FMaxTotal: UInt64;
    FCumTotal: UInt64;
    FLastUName: string;
    FLastGName: string;
    FLastLinkName: string;
    // header cache: opaque single 512B ScanNulFieldTruncations, generic 7-field array (interface 不暴露七字段命名字段，复用 bytes.ops 单源，inline 零拷贝)
    FScanValid: Boolean;
    FScanPos: SizeUInt;
    FScanLens: array[0..6] of SizeUInt; // opaque generic cache: 0:Name 1:LinkName 2:Magic 3:Version 4:UName 5:GName 6:Prefix
    FGuardHead: TTarGlobalPaxGuard; // guard chain
    FGuardCount: SizeUInt;
    FLogger: ILogger; // warn on auto-clear/reject
    function HasGuards: Boolean; inline;
    procedure LogGlobalPaxAutoClear;
    procedure LogGlobalPaxRejected(const AName: string);
    procedure RegisterGuard(AGuard: TTarGlobalPaxGuard);
    procedure UnregisterGuard(AGuard: TTarGlobalPaxGuard);
    procedure InvalidateGuards;
    function ByteAt(AOfs: SizeUInt): Byte;
    function SliceUntilNul(ABase: PByte; ALen: SizeUInt): TByteSpan; // single source NUL truncation, bytes.ops SpanIndexOf, zero-copy, out-of-line per design-conventions red line 2
    function FieldSlice(AOfs, ALen: SizeUInt): TByteSpan; // zero-copy view, case jump table on Off (offset-direct index), cached lens, single source C_TAR_LAYOUT
    function TrimmedSlice(ABase: PByte; ALen: SizeUInt): TByteSpan; // trailing zero trim via bytes.ops IsZeroBytes single source (IsZeroMem SWAR block), zero-copy, out-of-line per design-conventions red line 2
    function MaterializeSpan(const ASpan: TByteSpan): string; // single source SpanToString, empty guard, out-of-line per design-conventions red line 1 (Move Result[1])
    function StringField(AOfs, ALen: SizeUInt): string; // out-of-line via MaterializeSpan
    function NumericField(AOfs, ALen: SizeUInt): Int64;
    function MagicHasUStar: Boolean; inline;
    procedure VerifyChecksum;
    function HeaderIsZeroOrValid(APos: SizeUInt): Boolean;
    function ParsePaxRecordsSlice(ABase: PByte; ALen: SizeUInt): Boolean;
    function ParsePaxRecords(const AData: TBytes): Boolean;
    function GetExtendedPayload(ASize: Int64; out APtr: PByte; out ALen: SizeUInt): Boolean;
    function SliceToString(ABase: PByte; ALen: SizeUInt): string; // out-of-line via MaterializeSpan
    function CombinePrefixName(const APrefix, AName: TByteSpan): string; // out-of-line
    function CachedField(AOfs, ALen: SizeUInt; var ACached: string): string; // out-of-line, SpanEqual reuse via MaterializeSpan
    procedure ParsePaxExtValue(const AKey, AValue: TByteSpan); // out-of-line: SpanToString 物化 + decimal 解析 + EIOError 路径
    procedure MovePaxExtToGlobal; // out-of-line: map-merge 语义 + Extra 追加循环
    procedure ClearPaxExt; inline;
    procedure ClearGlobalPaxExt; inline;
    function UstarEntryName: string; // out-of-line: prefix/name 归一
    procedure FillHeaderScalars(var AHeader: TTarHeader); // out-of-line: mode/uid/gid/mtime/uname/gname/devmajor/devminor
    function FindPaxValue(const AKey: string; out AValue: string): Boolean; // out-of-line: Extra 线性 last-wins
    procedure NoteSparsePending; // out-of-line: x 中 GNU.sparse.* 建 pending，畸形即 EIOError
    procedure ParseSparseOldHeader(out ASegs: TSparseSegArray; out AReal: Int64; out AExtBlocks: Integer); // out-of-line: S 头 map+扩展链
    procedure ParseSparseMapText(AStored: PByte; AStoredLen: SizeUInt; AReal: Int64; out ASegs: TSparseSegArray; out AMapLen: SizeUInt); // out-of-line: 1.0 文本 map
    procedure ReconstructSparse(const ASegs: TSparseSegArray; AReal: Int64; ABase: PByte; ADataOff, AStoredLen: SizeUInt); // out-of-line: bomb 后分配+回填
  public
    procedure ClearGlobalPax; inline;
    {** @desc Acquires guard that clears global pax on scope exit. *}
    function AcquireGlobalPaxGuard: IInterface; inline;
    procedure SetLogger(const ALogger: ILogger); inline;
    destructor Destroy; override;
    constructor Create(const AData: TBytes); overload;
    constructor Create(AData: PByte; ACount: SizeUInt); overload;
    constructor CreateWithOptions(const AData: TBytes; const AOptions: TTarReadOptions); overload;
    constructor CreateWithOptions(AData: PByte; ACount: SizeUInt; const AOptions: TTarReadOptions); overload;
    function Next(out AHeader: TTarHeader): Boolean;
    function EntryDataOfs: SizeUInt;
    { — 零拷贝薄转发：复用 TrySlice 单一规范，PByte 视图生命周期绑 Reader — }
    function EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
    { — 零拷贝单一规范：TByteSpan 视图零分配，inline 薄转发，生命周期绑 Reader；OpenEntryStream 零拷贝持有（FBuf 时持有型、外部 PByte 时按需 SpanClone 持有）— }
    function TrySlice(out ASlice: TByteSpan): Boolean; inline;
    { — 零拷贝流：FBuf 非空时 CreateWithHold 零拷贝持有镜像（Reader 释放后仍可读）；外部 PByte 时按需 SpanClone 自包含持有（单次 Move bytes.ops 单源，防 UAF，Reader/外部缓冲释放后仍可读）— }
    function OpenEntryStream: IReader; inline;
    function EntrySize: Int64; inline;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.io.slice,
  nextpas.core.tar.common,
  nextpas.core.tar.log,
  nextpas.core.text.number;

type
  PPaxFullCtx = ^TPaxFullCtx;
  TPaxFullCtx = record R: TTarReader; end;

procedure TarPaxFullHandler(const AKey, AValue: TByteSpan; AUserData: Pointer);
begin
  // plain procedural + UserData，无闭包；数值畸形即抛 EIOError，调用栈直达 x/g 归属
  PPaxFullCtx(AUserData)^.R.ParsePaxExtValue(AKey, AValue);
end;

procedure AppendPaxRecords(var ADst: TPaxRecordArray; const ASrc: TPaxRecordArray);
var
  I, Old: Integer;
begin
  // 外联：真实循环体禁 inline，保序追加
  if Length(ASrc) = 0 then
    Exit;
  Old := Length(ADst);
  SetLength(ADst, Old + Length(ASrc));
  for I := 0 to High(ASrc) do
    ADst[Old + I] := ASrc[I];
end;

function IsGnuSparseDataName(const AName: string): Boolean;
begin
  // 1.0 占位名 ./GNUSparseFile.PID/name：前缀匹配，PID 无关；普通名必含 flow 斜杠语义由 IsSafe 另行保障
  Result := (Length(AName) > 16) and (Copy(AName, 1, 16) = './GNUSparseFile.');
end;

function TypeFlagToKind(AFlag: Byte): TTarEntryKind;
begin
  case AFlag of
    0, Ord('0'), Ord('7'): Result := tekRegular;
    Ord('1'): Result := tekHardLink;
    Ord('2'): Result := tekSymlink;
    Ord('3'): Result := tekCharDevice;
    Ord('4'): Result := tekBlockDevice;
    Ord('5'): Result := tekDirectory;
    Ord('6'): Result := tekFifo;
  else
    raise EIOError.CreateFmt('tar: unsupported type flag "%c"', [Chr(AFlag)]);
  end;
end;

{ TTarReader }

constructor TTarReader.Create(const AData: TBytes);
begin
  CreateWithOptions(AData, DefaultTarReadOptions);
end;

constructor TTarReader.Create(AData: PByte; ACount: SizeUInt);
begin
  CreateWithOptions(AData, ACount, DefaultTarReadOptions);
end;

constructor TTarReader.CreateWithOptions(const AData: TBytes; const AOptions: TTarReadOptions);
begin
  inherited Create;
  FBuf := AData;
  if Length(AData) > 0 then
    FData := @AData[0]
  else
    FData := nil;
  FCount := SizeUInt(Length(AData));
  FPos := 0;
  FScanValid := False;
  FScanPos := 0;
  FGuardHead := nil;
  FGuardCount := 0;
  FLogger := NullLogger;
  if AOptions.MaxEntrySize = 0 then
    FMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    FMaxEntry := AOptions.MaxEntrySize;
  if AOptions.MaxTotalSize = 0 then
    FMaxTotal := C_TAR_DEFAULT_MAX_TOTAL
  else
    FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
end;

constructor TTarReader.CreateWithOptions(AData: PByte; ACount: SizeUInt; const AOptions: TTarReadOptions);
begin
  inherited Create;
  // UAF 修复 + 高水位复用：外部 PByte 按需单次 SpanClone bytes.ops 单源持有，生命周期绑 Reader 防提前释放悬垂；单次 FBuf 高水位分配复用零拷贝持有路径（200 条目批量 1 次 vs 200 次），OpenEntryStream 零拷贝证据见 FBuf 持有型 CreateSliceReaderWithHold inline
  if (AData <> nil) and (ACount > 0) then
  begin
    FBuf := SpanClone(TByteSpan.Create(AData, ACount)); // bytes.ops 单源单次 Move，高水位 1 次
    FData := @FBuf[0];
    FCount := ACount;
  end
  else
  begin
    FBuf := nil;
    FData := nil;
    FCount := ACount;
  end;
  FPos := 0;
  FScanValid := False;
  FScanPos := 0;
  FGuardHead := nil;
  FGuardCount := 0;
  FLogger := NullLogger;
  if AOptions.MaxEntrySize = 0 then
    FMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    FMaxEntry := AOptions.MaxEntrySize;
  if AOptions.MaxTotalSize = 0 then
    FMaxTotal := C_TAR_DEFAULT_MAX_TOTAL
  else
    FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
end;

// single source 7-field cache table: symbolic bind to C_TAR_LAYOUT single source, bytes.ops single 512B pass — opaque generic, interface不暴露七字段命名; single table driven via C_TAR_HEADER_CACHE_MAP loop, case jump table in FieldSlice, CONTRACT §2 INV-7; 零薄别名双维护 — 直接复用 C_TAR_OFF_*/LEN_* ordinal 常量作 case label 与 map 单源零漂移
const
  C_TAR_HEADER_CACHE_MAP: array[0..6] of TFieldRange = (
    (Off: C_TAR_OFF_NAME;     Len: C_TAR_LEN_NAME),
    (Off: C_TAR_OFF_LINKNAME; Len: C_TAR_LEN_LINKNAME),
    (Off: C_TAR_OFF_MAGIC;    Len: C_TAR_LEN_MAGIC),
    (Off: C_TAR_OFF_VERSION;  Len: C_TAR_LEN_VERSION),
    (Off: C_TAR_OFF_UNAME;    Len: C_TAR_LEN_UNAME),
    (Off: C_TAR_OFF_GNAME;    Len: C_TAR_LEN_GNAME),
    (Off: C_TAR_OFF_PREFIX;   Len: C_TAR_LEN_PREFIX)
  );

procedure CacheHeader(ASelf: TTarReader);
var
  LLens: array[0..6] of SizeUInt;
  LBlock: TByteSpan;
  LFields: array[0..6] of TFieldRange;
  I: SizeInt;
begin
  if ASelf.FScanValid and (ASelf.FScanPos = ASelf.FPos) then Exit;
  if ASelf.FPos + C_TAR_BLOCK_SIZE > ASelf.FCount then
  begin
    // bulk lens from single source map loop (no literal drift, zero-copy single source)
    for I := 0 to 6 do
      ASelf.FScanLens[I] := C_TAR_HEADER_CACHE_MAP[I].Len;
    ASelf.FScanPos := ASelf.FPos;
    ASelf.FScanValid := True;
    Exit;
  end;
  LBlock := TByteSpan.Create(@ASelf.FData[ASelf.FPos], C_TAR_BLOCK_SIZE);
  // build scan table from single source map loop (zero drift, single table driven)
  for I := 0 to 6 do
    LFields[I] := C_TAR_HEADER_CACHE_MAP[I];
  ScanNulFieldTruncations(LBlock, LFields, @LLens[0]);
  ASelf.FScanLens := LLens;
  ASelf.FScanPos := ASelf.FPos;
  ASelf.FScanValid := True;
end;

function TTarReader.ByteAt(AOfs: SizeUInt): Byte;
begin
  if AOfs >= FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (need %d, have %d)', [AOfs, AOfs + 1, FCount]);
  Result := FData[AOfs];
end;

function TTarReader.SliceUntilNul(ABase: PByte; ALen: SizeUInt): TByteSpan;
var
  LSpan: TByteSpan;
  LIdx: SizeInt;
  LLen: SizeUInt;
begin
  // single source NUL truncation: bytes.ops SpanIndexOf single source, zero-copy, out-of-line per design-conventions red line 2
  if ALen = 0 then Exit(TByteSpan.Empty);
  LSpan := TByteSpan.Create(ABase, ALen);
  LIdx := SpanIndexOf(LSpan, 0);
  if LIdx < 0 then LLen := ALen else LLen := SizeUInt(LIdx);
  if LLen = 0 then Exit(TByteSpan.Empty);
  Result := TByteSpan.Create(ABase, LLen);
end;

function TTarReader.FieldSlice(AOfs, ALen: SizeUInt): TByteSpan;
var
  EndOfs: SizeUInt;
  LFieldOff: SizeUInt;
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (field %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  // header: cached 7 fields, single 512B ScanNulFieldTruncations via bytes.ops — case jump table on Off, single source C_TAR_HEADER_CACHE_MAP
  if (AOfs >= FPos) and (EndOfs <= FPos + C_TAR_BLOCK_SIZE) then
  begin
    if not (FScanValid and (FScanPos = FPos)) then
      CacheHeader(Self);
    LFieldOff := AOfs - FPos;
    // offset-direct case jump table (branch prediction friendly, 2000-entry), Len check inside single branch, zero-copy cached lens; 直接复用 C_TAR_OFF_*/LEN_* 单源 ordinal 常量作 case label 零漂移，零薄别名
    case LFieldOff of
      C_TAR_OFF_NAME:
        if ALen = C_TAR_LEN_NAME then
        begin
          if FScanLens[0] = 0 then Exit(TByteSpan.Empty);
          Exit(TByteSpan.Create(@FData[AOfs], FScanLens[0]));
        end;
      C_TAR_OFF_LINKNAME:
        if ALen = C_TAR_LEN_LINKNAME then
        begin
          if FScanLens[1] = 0 then Exit(TByteSpan.Empty);
          Exit(TByteSpan.Create(@FData[AOfs], FScanLens[1]));
        end;
      C_TAR_OFF_MAGIC:
        if ALen = C_TAR_LEN_MAGIC then
        begin
          if FScanLens[2] = 0 then Exit(TByteSpan.Empty);
          Exit(TByteSpan.Create(@FData[AOfs], FScanLens[2]));
        end;
      C_TAR_OFF_VERSION:
        if ALen = C_TAR_LEN_VERSION then
        begin
          if FScanLens[3] = 0 then Exit(TByteSpan.Empty);
          Exit(TByteSpan.Create(@FData[AOfs], FScanLens[3]));
        end;
      C_TAR_OFF_UNAME:
        if ALen = C_TAR_LEN_UNAME then
        begin
          if FScanLens[4] = 0 then Exit(TByteSpan.Empty);
          Exit(TByteSpan.Create(@FData[AOfs], FScanLens[4]));
        end;
      C_TAR_OFF_GNAME:
        if ALen = C_TAR_LEN_GNAME then
        begin
          if FScanLens[5] = 0 then Exit(TByteSpan.Empty);
          Exit(TByteSpan.Create(@FData[AOfs], FScanLens[5]));
        end;
      C_TAR_OFF_PREFIX:
        if ALen = C_TAR_LEN_PREFIX then
        begin
          if FScanLens[6] = 0 then Exit(TByteSpan.Empty);
          Exit(TByteSpan.Create(@FData[AOfs], FScanLens[6]));
        end;
    end;
    // fallback: non-cached header field or Len mismatch — single source SliceUntilNul (bytes.ops SpanIndexOf, zero-copy, out-of-line)
    Exit(SliceUntilNul(@FData[AOfs], ALen));
  end;
  // non-header: single source SliceUntilNul (bytes.ops SpanIndexOf, zero-copy view, out-of-line)
  Result := SliceUntilNul(@FData[AOfs], ALen);
end;

function TTarReader.TrimmedSlice(ABase: PByte; ALen: SizeUInt): TByteSpan;
var
  Trim: SizeUInt;
begin
  if (ABase = nil) or (ALen = 0) then
    Exit(TByteSpan.Empty);
  Trim := ALen;
  // block-level trailing zero trim via bytes.ops IsZeroBytes single source (IsZeroMem SWAR chunked via GZeroBuf4K/MemEqual, zero-copy TByteSpan view, out-of-line), avoids scalar per-byte for 512B header repeated scan
  while Trim >= 32 do
  begin
    if IsZeroBytes(TByteSpan.Create(ABase + Trim - 32, 32)) then
      Dec(Trim, 32)
    else
      Break;
  end;
  while (Trim > 0) and (ABase[Trim - 1] = 0) do
    Dec(Trim);
  if Trim = 0 then
    Exit(TByteSpan.Empty);
  Result := TByteSpan.Create(ABase, Trim);
end;

function TTarReader.MaterializeSpan(const ASpan: TByteSpan): string;
begin
  // single source: zero-copy view -> string materialization, empty guard, SpanToString single source (bytes.ops inline)
  // out-of-line per design-conventions red line 1: Move(Result[1]) inline triggers FPC constant propagation defect, must stay out-of-line
  if ASpan.Len = 0 then
    Exit('');
  Result := SpanToString(ASpan);
end;

function TTarReader.StringField(AOfs, ALen: SizeUInt): string;
var
  LSpan: TByteSpan;
begin
  // out-of-line: FieldSlice zero-copy then MaterializeSpan single source (avoids SpanToString duplicate)
  LSpan := FieldSlice(AOfs, ALen);
  Result := MaterializeSpan(LSpan);
end;

function TTarReader.NumericField(AOfs, ALen: SizeUInt): Int64;
begin
  if AOfs + ALen > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (numeric %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  Result := TarParseNumericField(@FData[AOfs], ALen, AOfs);
end;

function TTarReader.MagicHasUStar: Boolean; inline;
begin
  Result := (FPos + C_TAR_LAYOUT.Magic.Off + 5 < FCount)
    and (FData[FPos + C_TAR_LAYOUT.Magic.Off] = Ord('u'))
    and (FData[FPos + C_TAR_LAYOUT.Magic.Off + 1] = Ord('s'))
    and (FData[FPos + C_TAR_LAYOUT.Magic.Off + 2] = Ord('t'))
    and (FData[FPos + C_TAR_LAYOUT.Magic.Off + 3] = Ord('a'))
    and (FData[FPos + C_TAR_LAYOUT.Magic.Off + 4] = Ord('r'));
end;

procedure TTarReader.VerifyChecksum;
begin
  if FPos + C_TAR_BLOCK_SIZE > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (need %d, have %d)', [FPos, C_TAR_BLOCK_SIZE, FCount - FPos]);
  TarVerifyBlockChecksum(@FData[FPos], FPos);
end;

function TTarReader.HeaderIsZeroOrValid(APos: SizeUInt): Boolean;
begin
  if APos + C_TAR_BLOCK_SIZE > FCount then
    Exit(False);
  Result := TarHeaderIsZeroOrValid(@FData[APos], APos);
end;

function TTarReader.SliceToString(ABase: PByte; ALen: SizeUInt): string;
var
  LSpan: TByteSpan;
begin
  // out-of-line: TrimmedSlice zero-copy then MaterializeSpan single source
  LSpan := TrimmedSlice(ABase, ALen);
  Result := MaterializeSpan(LSpan);
end;

function TTarReader.CombinePrefixName(const APrefix, AName: TByteSpan): string;
begin
  Result := SpanJoinWithSeparator(APrefix, AName, '/');
end;

function TTarReader.CachedField(AOfs, ALen: SizeUInt; var ACached: string): string;
var
  LSpan: TByteSpan;
  LCachedSpan: TByteSpan;
  LCachedLen: SizeUInt;
begin
  // zero-copy FieldSlice then SpanEqual reuse, fast first-byte filter, MaterializeSpan single source; StringAsSpan 单源零拷贝视图 inline 零漂移
  LSpan := FieldSlice(AOfs, ALen);
  if LSpan.Len = 0 then
    Exit('');
  LCachedLen := SizeUInt(Length(ACached));
  if LCachedLen = LSpan.Len then
  begin
    if LCachedLen = 0 then
      Exit(ACached);
    // fast first-byte filter before SpanEqual:不等即跳过，无空块占位，inline零拷贝；bytes.ops StringAsSpan 单源 PAnsiChar 视图
    LCachedSpan := StringAsSpan(ACached);
    if (LCachedSpan.Data^ = LSpan.Data^) and SpanEqual(LCachedSpan, LSpan) then
      Exit(ACached);
  end;
  Result := MaterializeSpan(LSpan);
  ACached := Result;
end;

procedure TTarReader.ClearGlobalPax; inline;
begin
  FGlobalPaxPath := '';
  FGlobalPaxLinkPath := '';
  ClearGlobalPaxExt;
end;

procedure TTarReader.SetLogger(const ALogger: ILogger); inline;
begin
  if ALogger <> nil then
    FLogger := ALogger
  else
    FLogger := NullLogger;
end;

function TTarReader.HasGuards: Boolean; inline;
begin
  Result := FGuardCount <> 0;
end;

procedure TTarReader.RegisterGuard(AGuard: TTarGlobalPaxGuard);
begin
  if AGuard = nil then Exit;
  AGuard.FNext := FGuardHead;
  FGuardHead := AGuard;
  Inc(FGuardCount);
end;

procedure TTarReader.UnregisterGuard(AGuard: TTarGlobalPaxGuard);
var
  LPrev, LCur: TTarGlobalPaxGuard;
begin
  LPrev := nil;
  LCur := FGuardHead;
  while LCur <> nil do
  begin
    if LCur = AGuard then
    begin
      if LPrev = nil then
        FGuardHead := LCur.FNext
      else
        LPrev.FNext := LCur.FNext;
      Dec(FGuardCount);
      Exit;
    end;
    LPrev := LCur;
    LCur := LCur.FNext;
  end;
end;

procedure TTarReader.InvalidateGuards;
var
  LCur, LNext: TTarGlobalPaxGuard;
begin
  LCur := FGuardHead;
  while LCur <> nil do
  begin
    LNext := LCur.FNext;
    LCur.Invalidate;
    LCur := LNext;
  end;
  FGuardHead := nil;
  FGuardCount := 0;
end;

procedure TTarReader.LogGlobalPaxAutoClear;
begin
  // INV-3 observability: 默认可观测 — NullLogger 静默丢弃已修复，fallback StdErr 可观测，显式 SetLogger 仍优先 — 文案单源 base 常量
  if (FLogger <> nil) and (FLogger <> NullLogger) then
    FLogger.Warn(C_TAR_WARN_GLOBAL_PAX_AUTO_CLEAR)
  else
    WriteLn(StdErr, C_TAR_WARN_GLOBAL_PAX_AUTO_CLEAR);
end;

procedure TTarReader.LogGlobalPaxRejected(const AName: string);
begin
  // INV-3 observability: global pax unsafe filter must Warn (consistent with auto-clear), 默认 fallback StdErr 可观测，防静默篡改 — 文案单源 base 常量
  if (FLogger <> nil) and (FLogger <> NullLogger) then
    FLogger.Warn(C_TAR_WARN_GLOBAL_PAX_REJECTED_PREFIX + AName + C_TAR_WARN_GLOBAL_PAX_REJECTED_SUFFIX)
  else
    WriteLn(StdErr, C_TAR_WARN_GLOBAL_PAX_REJECTED_PREFIX + AName + C_TAR_WARN_GLOBAL_PAX_REJECTED_SUFFIX);
end;

function TTarReader.AcquireGlobalPaxGuard: IInterface; inline;
begin
  Result := TTarGlobalPaxGuard.Create(Self);
end;

constructor TTarGlobalPaxGuard.Create(AReader: TTarReader);
begin
  inherited Create;
  FReader := AReader;
  if FReader <> nil then
    FReader.RegisterGuard(Self);
end;

procedure TTarGlobalPaxGuard.Invalidate;
begin
  FReader := nil;
end;

destructor TTarGlobalPaxGuard.Destroy;
var
  LReader: TTarReader;
begin
  LReader := FReader;
  FReader := nil;
  if LReader <> nil then
  begin
    LReader.UnregisterGuard(Self);
    LReader.ClearGlobalPax;
  end;
  inherited Destroy;
end;

destructor TTarReader.Destroy;
begin
  // stability: invalidate guards before releasing state
  InvalidateGuards;
  FGlobalPaxPath := '';
  FGlobalPaxLinkPath := '';
  inherited Destroy;
end;

function TTarReader.GetExtendedPayload(ASize: Int64; out APtr: PByte; out ALen: SizeUInt): Boolean;
begin
  APtr := nil;
  ALen := 0;
  if ASize < 0 then
    raise EIOError.CreateFmt('tar: negative entry size %d at offset %d', [ASize, FPos]);
  if ASize = 0 then
    Exit(True);
  if UInt64(ASize) > UInt64(FMaxEntry) then
    raise EIOError.CreateFmt('tar: entry size %d exceeds limit %d at offset %d', [ASize, Int64(FMaxEntry), FPos]);
  if FPos + C_TAR_BLOCK_SIZE + SizeUInt(ASize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FPos + C_TAR_BLOCK_SIZE, ASize, Int64(FCount) - Int64(FPos + C_TAR_BLOCK_SIZE)]);
  APtr := @FData[FPos + C_TAR_BLOCK_SIZE];
  ALen := SizeUInt(ASize);
  Result := True;
end;

procedure TTarReader.ParsePaxExtValue(const AKey, AValue: TByteSpan);
var
  LUInt: UInt64;
  LInt: Int64;
  LDot: SizeInt;
  LIntLen: SizeUInt;
  LRec: TPaxRecord;
begin
  // 全记录原文先保序透传（含已应用的类型化键），再按关键字应用
  LRec.Key := MaterializeSpan(AKey);
  LRec.Value := MaterializeSpan(AValue);
  AppendPaxRecords(FPaxExt.Extra, [LRec]);
  if (AKey.Len = 4) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('path')), 4)) then
  begin
    if AValue.Len > 0 then FPaxPath := SpanToString(AValue) else FPaxPath := '';
  end
  else if (AKey.Len = 8) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('linkpath')), 8)) then
  begin
    if AValue.Len > 0 then FPaxLinkPath := SpanToString(AValue) else FPaxLinkPath := '';
  end
  else if (AKey.Len = 4) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('size')), 4)) then
  begin
    if (AValue.Len = 0) or not ParseUInt64(PAnsiChar(AValue.Data), AValue.Len, LUInt) then
      raise EIOError.Create('pax: bad size value');
    if LUInt > UInt64(High(Int64)) then
      raise EIOError.Create('pax: size out of range');
    FPaxExt.Size := Int64(LUInt);
    FPaxExt.HasSize := True;
  end
  else if (AKey.Len = 5) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('mtime')), 5)) then
  begin
    if AValue.Len = 0 then
      raise EIOError.Create('pax: bad mtime value');
    LDot := SpanIndexOf(AValue, Ord('.'));
    if LDot < 0 then
      LIntLen := AValue.Len
    else
      LIntLen := SizeUInt(LDot);
    if (LIntLen = 0) or not ParseInt64(PAnsiChar(AValue.Data), LIntLen, LInt) then
      raise EIOError.Create('pax: bad mtime value');
    FPaxExt.MTimeUnix := LInt;
    FPaxExt.HasMTime := True;
  end
  else if (AKey.Len = 3) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('uid')), 3)) then
  begin
    if (AValue.Len = 0) or not ParseUInt64(PAnsiChar(AValue.Data), AValue.Len, LUInt) then
      raise EIOError.Create('pax: bad uid value');
    if LUInt > UInt64(High(Cardinal)) then
      raise EIOError.Create('pax: uid out of range');
    FPaxExt.UID := Cardinal(LUInt);
    FPaxExt.HasUID := True;
  end
  else if (AKey.Len = 3) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('gid')), 3)) then
  begin
    if (AValue.Len = 0) or not ParseUInt64(PAnsiChar(AValue.Data), AValue.Len, LUInt) then
      raise EIOError.Create('pax: bad gid value');
    if LUInt > UInt64(High(Cardinal)) then
      raise EIOError.Create('pax: gid out of range');
    FPaxExt.GID := Cardinal(LUInt);
    FPaxExt.HasGID := True;
  end
  else if (AKey.Len = 5) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('uname')), 5)) then
  begin
    FPaxExt.UName := MaterializeSpan(AValue);
    FPaxExt.HasUName := True;
  end
  else if (AKey.Len = 5) and SpanEqual(AKey, TByteSpan.Create(PByte(PAnsiChar('gname')), 5)) then
  begin
    FPaxExt.GName := MaterializeSpan(AValue);
    FPaxExt.HasGName := True;
  end;
end;

procedure TTarReader.MovePaxExtToGlobal;
begin
  // g 语义即 KV map 合并：仅搬运 Has 字段，Extra 追加，调用后清单条目侧
  if FPaxExt.HasSize then
  begin FGlobalPaxExt.HasSize := True; FGlobalPaxExt.Size := FPaxExt.Size; end;
  if FPaxExt.HasMTime then
  begin FGlobalPaxExt.HasMTime := True; FGlobalPaxExt.MTimeUnix := FPaxExt.MTimeUnix; end;
  if FPaxExt.HasUID then
  begin FGlobalPaxExt.HasUID := True; FGlobalPaxExt.UID := FPaxExt.UID; end;
  if FPaxExt.HasGID then
  begin FGlobalPaxExt.HasGID := True; FGlobalPaxExt.GID := FPaxExt.GID; end;
  if FPaxExt.HasUName then
  begin FGlobalPaxExt.HasUName := True; FGlobalPaxExt.UName := FPaxExt.UName; end;
  if FPaxExt.HasGName then
  begin FGlobalPaxExt.HasGName := True; FGlobalPaxExt.GName := FPaxExt.GName; end;
  AppendPaxRecords(FGlobalPaxExt.Extra, FPaxExt.Extra);
  FPaxExt := Default(TPaxExtSet);
end;

procedure TTarReader.ClearPaxExt; inline;
begin
  FPaxExt := Default(TPaxExtSet);
end;

procedure TTarReader.ClearGlobalPaxExt; inline;
begin
  FGlobalPaxExt := Default(TPaxExtSet);
end;

function TTarReader.UstarEntryName: string;
var
  LNameSpan, LPrefixSpan: TByteSpan;
begin
  // ustar 名归一单源：prefix/name 合并，无 magic 回退裸名
  if MagicHasUStar then
  begin
    LNameSpan := FieldSlice(FPos + C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len);
    LPrefixSpan := FieldSlice(FPos + C_TAR_LAYOUT.Prefix.Off, C_TAR_LAYOUT.Prefix.Len);
    if (LPrefixSpan.Len > 0) and (LNameSpan.Len > 0) then
      Result := CombinePrefixName(LPrefixSpan, LNameSpan)
    else if LPrefixSpan.Len > 0 then
      Result := SpanToString(LPrefixSpan)
    else if LNameSpan.Len > 0 then
      Result := SpanToString(LNameSpan)
    else
      Result := '';
  end
  else
    Result := StringField(FPos + C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len);
end;

procedure TTarReader.FillHeaderScalars(var AHeader: TTarHeader);
begin
  // 数值/用户字段读取单源：final-else 与稀疏 S 共用，pax 覆盖由调用方后续应用
  AHeader.Mode := Cardinal(NumericField(FPos + C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len)) and $FFFF;
  AHeader.UID := Cardinal(NumericField(FPos + C_TAR_LAYOUT.UID.Off, C_TAR_LAYOUT.UID.Len));
  AHeader.GID := Cardinal(NumericField(FPos + C_TAR_LAYOUT.GID.Off, C_TAR_LAYOUT.GID.Len));
  AHeader.MTimeUnix := NumericField(FPos + C_TAR_LAYOUT.MTime.Off, C_TAR_LAYOUT.MTime.Len);
  AHeader.UName := CachedField(FPos + C_TAR_LAYOUT.UName.Off, C_TAR_LAYOUT.UName.Len, FLastUName);
  AHeader.GName := CachedField(FPos + C_TAR_LAYOUT.GName.Off, C_TAR_LAYOUT.GName.Len, FLastGName);
  AHeader.DevMajor := NumericField(FPos + C_TAR_LAYOUT.DevMajor.Off, C_TAR_LAYOUT.DevMajor.Len);
  AHeader.DevMinor := NumericField(FPos + C_TAR_LAYOUT.DevMinor.Off, C_TAR_LAYOUT.DevMinor.Len);
end;

function TTarReader.FindPaxValue(const AKey: string; out AValue: string): Boolean;
var
  I: Integer;
begin
  // Extra 内线性 last-wins；调用方限定小记录集，外联
  Result := False;
  AValue := '';
  for I := 0 to High(FPaxExt.Extra) do
    if FPaxExt.Extra[I].Key = AKey then
    begin
      AValue := FPaxExt.Extra[I].Value;
      Result := True;
    end;
end;

procedure TTarReader.NoteSparsePending;
var
  LMajor, LMinor, LReal, LName: string;
  LUInt: UInt64;
begin
  // 仅 x 分支调用：GNU.sparse.* 成组出现才建 pending，缺项/错版即 EIOError
  FSparsePending := False;
  if not FindPaxValue('GNU.sparse.major', LMajor) then
    Exit;
  if not FindPaxValue('GNU.sparse.minor', LMinor) then
    raise EIOError.Create('tar: sparse minor missing');
  if (LMajor <> '1') or (LMinor <> '0') then
    raise EIOError.Create('tar: unsupported sparse version ' + LMajor + '.' + LMinor);
  if not FindPaxValue('GNU.sparse.realsize', LReal) then
    raise EIOError.Create('tar: sparse realsize missing');
  if (LReal = '') or not ParseUInt64(PAnsiChar(LReal), SizeUInt(Length(LReal)), LUInt) then
    raise EIOError.Create('tar: bad sparse realsize');
  if LUInt > UInt64(High(Int64)) then
    raise EIOError.Create('tar: sparse realsize out of range');
  if not FindPaxValue('GNU.sparse.name', LName) then
    raise EIOError.Create('tar: sparse name missing');
  if LName = '' then
    raise EIOError.Create('tar: sparse name missing');
  FSparseRealName := LName;
  FSparseRealSize := Int64(LUInt);
  FSparsePending := True;
end;

function ParseDecLine(var P: PByte; AEnd: PByte; out AValue: Int64): Boolean;
var
  V: UInt64;
  LStart: PByte;
begin
  // 1.0 map 文本行：digits + LF，溢出/缺换行即 False，外联
  Result := False;
  AValue := 0;
  if (P = nil) or (P >= AEnd) then
    Exit;
  LStart := P;
  V := 0;
  while (P < AEnd) and (P^ >= Ord('0')) and (P^ <= Ord('9')) do
  begin
    if V > (UInt64(High(Int64)) - UInt64(P^ - Ord('0'))) div 10 then
      Exit;
    V := V * 10 + UInt64(P^ - Ord('0'));
    Inc(P);
  end;
  if P = LStart then
    Exit;
  if (P >= AEnd) or (P^ <> 10) then
    Exit;
  Inc(P);
  AValue := Int64(V);
  Result := True;
end;

procedure TTarReader.ParseSparseOldHeader(out ASegs: TSparseSegArray; out AReal: Int64; out AExtBlocks: Integer);
var
  I: Integer;
  LOff, LLen: Int64;
  LExtPos: SizeUInt;
  LMore, LDone: Boolean;
  LMaxEnd: Int64;

  procedure TakeSeg(AOff, ALen: Int64);
  begin
    if ALen = 0 then
      Exit;
    if (AOff < 0) or (ALen < 0) then
      raise EIOError.Create('tar: negative sparse segment');
    SetLength(ASegs, Length(ASegs) + 1);
    ASegs[High(ASegs)].Off := AOff;
    ASegs[High(ASegs)].Len := ALen;
    if ALen > High(Int64) - AOff then
      raise EIOError.Create('tar: sparse segment out of range');
    if AOff + ALen > LMaxEnd then
      LMaxEnd := AOff + ALen;
  end;

begin
  // 调用方已保证 FPos+512 落镜像内；扩展块逐块守总量，终结符 (任意 off, 0) 停
  ASegs := nil;
  AReal := 0;
  AExtBlocks := 0;
  LMaxEnd := 0;
  for I := 0 to 3 do
  begin
    LOff := TarParseNumericField(@FData[FPos + 386 + SizeUInt(I) * 24], 12, FPos + 386 + SizeUInt(I) * 24);
    LLen := TarParseNumericField(@FData[FPos + 386 + SizeUInt(I) * 24 + 12], 12, FPos + 386 + SizeUInt(I) * 24 + 12);
    if LLen = 0 then
      Break;
    TakeSeg(LOff, LLen);
  end;
  LMore := (Length(ASegs) = 4) and (FData[FPos + 482] <> 0);
  LDone := Length(ASegs) < 4;
  while LMore and not LDone do
  begin
    Inc(AExtBlocks);
    LExtPos := FPos + SizeUInt(AExtBlocks) * SizeUInt(C_TAR_BLOCK_SIZE);
    if LExtPos + SizeUInt(C_TAR_BLOCK_SIZE) > FCount then
      raise EIOError.CreateFmt('tar: truncated sparse extension at offset %d', [LExtPos]);
    GuardTarTotalSize(FCumTotal, 512, FMaxTotal);
    FCumTotal := FCumTotal + 512;
    for I := 0 to 20 do
    begin
      LOff := TarParseNumericField(@FData[LExtPos + SizeUInt(I) * 24], 12, LExtPos + SizeUInt(I) * 24);
      LLen := TarParseNumericField(@FData[LExtPos + SizeUInt(I) * 24 + 12], 12, LExtPos + SizeUInt(I) * 24 + 12);
      if LLen = 0 then
      begin
        LDone := True;
        Break;
      end;
      TakeSeg(LOff, LLen);
    end;
    if not LDone then
      LMore := FData[LExtPos + 504] <> 0
    else
      LMore := False;
  end;
  AReal := TarParseNumericField(@FData[FPos + 483], 12, FPos + 483);
  if AReal < 0 then
    raise EIOError.Create('tar: negative sparse realsize');
  if AReal = 0 then
    AReal := LMaxEnd
  else
  begin
    if LMaxEnd > AReal then
      raise EIOError.Create('tar: sparse segment out of range');
    if (Length(ASegs) = 0) and (AReal > 0) then
    begin
      // 全洞文件：零段 + 非零 realsize 合法（零填充即可），空 map + 零 realsize 视为退化拒绝由调用方守卫覆盖
    end;
  end;
  if (Length(ASegs) = 0) and (AReal = 0) then
    raise EIOError.Create('tar: empty sparse map');
end;

procedure TTarReader.ParseSparseMapText(AStored: PByte; AStoredLen: SizeUInt; AReal: Int64; out ASegs: TSparseSegArray; out AMapLen: SizeUInt);
var
  P, LEnd: PByte;
  N, I: Int64;
  LOff, LLen: Int64;
begin
  // 1.0 map：count + 2N 十进制行，终结符必须为 (realsize, 0)；段数受 stored/real 双界
  ASegs := nil;
  AMapLen := 0;
  if (AStoredLen > 0) and (AStored = nil) then
    raise EIOError.Create('tar: sparse map unreadable');
  P := AStored;
  LEnd := AStored + AStoredLen;
  if not ParseDecLine(P, LEnd, N) then
    raise EIOError.Create('tar: bad sparse map count');
  if (N < 1) or (N > Int64(AStoredLen) div 4) or (N > AReal + 1) then
    raise EIOError.Create('tar: bad sparse map count');
  SetLength(ASegs, N);
  for I := 0 to N - 1 do
  begin
    if not ParseDecLine(P, LEnd, LOff) then
      raise EIOError.Create('tar: bad sparse map offset');
    if not ParseDecLine(P, LEnd, LLen) then
      raise EIOError.Create('tar: bad sparse map length');
    if (LOff < 0) or (LLen < 0) then
      raise EIOError.Create('tar: negative sparse segment');
    if (LLen > 0) and ((LOff > AReal) or (LLen > AReal - LOff)) then
      raise EIOError.Create('tar: sparse segment out of range');
    ASegs[I].Off := LOff;
    ASegs[I].Len := LLen;
  end;
  if (ASegs[N - 1].Off <> AReal) or (ASegs[N - 1].Len <> 0) then
    raise EIOError.Create('tar: sparse map missing terminator');
  AMapLen := SizeUInt(PtrUInt(P) - PtrUInt(AStored));
end;

procedure TTarReader.ReconstructSparse(const ASegs: TSparseSegArray; AReal: Int64; ABase: PByte; ADataOff, AStoredLen: SizeUInt);
var
  LBuf: TBytes;
  I: Integer;
  LRun: UInt64;
begin
  // 调用方已对 stored 与 real 做 entry/total 双守卫；此处精确装配，run 对账不平即 EIOError
  SetLength(LBuf, AReal);
  LRun := 0;
  for I := 0 to High(ASegs) do
  begin
    if ASegs[I].Len = 0 then
      Continue;
    if LRun + UInt64(ASegs[I].Len) > UInt64(AStoredLen) - UInt64(ADataOff) then
      raise EIOError.Create('tar: sparse data overrun');
    CopyMemory(ABase + ADataOff + SizeUInt(LRun), @LBuf[SizeInt(ASegs[I].Off)], SizeUInt(ASegs[I].Len));
    LRun := LRun + UInt64(ASegs[I].Len);
  end;
  if LRun + UInt64(ADataOff) <> UInt64(AStoredLen) then
    raise EIOError.Create('tar: sparse stored size mismatch');
  FSparseBuf := LBuf;
  FSparseValid := True;
end;

function TTarReader.ParsePaxRecordsSlice(ABase: PByte; ALen: SizeUInt): Boolean;
var
  LCtx: TPaxFullCtx;
begin
  // 单点：pax 解析经 archive.pax 零拷贝 KV 分发，全关键字应用 + 原文透传由 handler 完成
  LCtx.R := Self;
  Result := TarParsePaxKVRecords(ABase, ALen, @TarPaxFullHandler, @LCtx);
end;

function TTarReader.ParsePaxRecords(const AData: TBytes): Boolean;
begin
  if Length(AData) = 0 then
    Exit(False);
  Result := ParsePaxRecordsSlice(@AData[0], SizeUInt(Length(AData)));
end;

function TTarReader.Next(out AHeader: TTarHeader): Boolean;
var
  Flag: Byte;
  Size: Int64;
  Pad: Int64;
  PayloadPtr: PByte;
  PayloadLen: SizeUInt;
  LUsedGlobalNums: Boolean;
  LUsedGlobalPath: Boolean;
  LIsSparse: Boolean;
  LUstarName: string;
  LSegs: TSparseSegArray;
  LMapLen: SizeUInt;
  LReal: Int64;
  LExtBlocks: Integer;
  LHdr: TTarHeader;
begin
  Result := False;
  LUsedGlobalNums := False;
  LUsedGlobalPath := False;
  LIsSparse := False;
  LSegs := nil;
  // clean dense entries skip managed resets; class zero-init covers first call
  if FExtDirty then
  begin
    FPendingLongName := '';
    FPendingLongLink := '';
    FPaxPath := '';
    FPaxLinkPath := '';
    FPaxExt := Default(TPaxExtSet);
    FSparsePending := False;
    FSparseValid := False;
    FSparseBuf := nil;
    FSparseRealName := '';
    FSparseRealSize := 0;
    FExtDirty := False;
  end;
  while True do
  begin
    if FPos >= FCount then
      Exit(False);
    if FCount - FPos < C_TAR_BLOCK_SIZE then
      raise EIOError.CreateFmt('tar: trailing partial block at offset %d (need %d, have %d)', [FPos, C_TAR_BLOCK_SIZE, FCount - FPos]);
    if HeaderIsZeroOrValid(FPos) then
    begin
      if FPos + C_TAR_BLOCK_SIZE = FCount then
        Exit(False);
      if FPos + 2 * C_TAR_BLOCK_SIZE > FCount then
        raise EIOError.CreateFmt('tar: truncated stream at offset %d (single zero block, need two)', [FPos]);
      if not TarHeaderIsZeroBlock(@FData[FPos + C_TAR_BLOCK_SIZE]) then
        raise EIOError.CreateFmt('tar: truncated stream at offset %d (single zero block followed by non-zero data)', [FPos]);
      Exit(False);
    end;
    Size := NumericField(FPos + C_TAR_LAYOUT.Size.Off, C_TAR_LAYOUT.Size.Len);
    // pax size 覆盖 ustar（x 单条目优先，无则 guard 内 g，否则单次 g）
    if FPaxExt.HasSize then
      Size := FPaxExt.Size
    else if FGlobalPaxExt.HasSize then
    begin
      Size := FGlobalPaxExt.Size;
      LUsedGlobalNums := True;
    end;
    if Size < 0 then
      raise EIOError.CreateFmt('tar: negative entry size %d at offset %d', [Size, FPos]);
    Flag := ByteAt(FPos + C_TAR_LAYOUT.TypeFlag.Off);
    if Flag = Ord('L') then
    begin
      FSparsePending := False;
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      // bomb: extended payload counted toward total (prevents large L/K/x/g DoS), single source GuardTarTotalSize
      if PayloadLen > 0 then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(PayloadLen), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(PayloadLen);
      end;
      if PayloadLen > 0 then
        FPendingLongName := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongName := '';
      FExtDirty := True;
    end
    else if Flag = Ord('K') then
    begin
      FSparsePending := False;
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      // bomb: extended payload counted toward total
      if PayloadLen > 0 then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(PayloadLen), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(PayloadLen);
      end;
      if PayloadLen > 0 then
        FPendingLongLink := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongLink := '';
      FExtDirty := True;
    end
    else if (Flag = Ord('x')) or (Flag = Ord('g')) then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      // bomb: pax payload counted toward total (prevents 100k × large pax DoS), single source GuardTarTotalSize
      if PayloadLen > 0 then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(PayloadLen), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(PayloadLen);
      end;
      if PayloadLen > 0 then
      begin
        FExtDirty := True;
        if ParsePaxRecordsSlice(PayloadPtr, PayloadLen) then
        begin
          if Flag = Ord('x') then
            NoteSparsePending;
          if Flag = Ord('g') then
          begin
            FSparsePending := False;
            MovePaxExtToGlobal;
            if FPaxPath <> '' then
            begin
              // IsSafe filter before storing global, Warn on reject (observability parity with auto-clear)
              if IsSafeTarEntryName(FPaxPath) then
                FGlobalPaxPath := FPaxPath
              else
              begin
                LogGlobalPaxRejected(FPaxPath);
                FGlobalPaxPath := '';
              end;
              FPaxPath := '';
            end;
            if FPaxLinkPath <> '' then
            begin
              if IsSafeTarEntryName(FPaxLinkPath) then
                FGlobalPaxLinkPath := FPaxLinkPath
              else
              begin
                LogGlobalPaxRejected(FPaxLinkPath);
                FGlobalPaxLinkPath := '';
              end;
              FPaxLinkPath := '';
            end;
          end;
        end;
      end
      else
      begin
      end;
    end
    else if Flag = Ord('S') then
    begin
      // oldgnu 稀疏：map 在头扩展区（+ 扩展链），数据段 dense 拼接，x/pax 不参与
      FSparsePending := False;
      if FPos + C_TAR_BLOCK_SIZE > FCount then
        raise EIOError.CreateFmt('tar: truncated stream at offset %d (need %d, have %d)', [FPos, C_TAR_BLOCK_SIZE, FCount - FPos]);
      ParseSparseOldHeader(LSegs, LReal, LExtBlocks);
      if UInt64(Size) > UInt64(FMaxEntry) then
        raise EIOError.CreateFmt('tar: entry size %d exceeds limit %d at offset %d', [Size, Int64(FMaxEntry), FPos]);
      if FPos + (SizeUInt(1 + LExtBlocks) * SizeUInt(C_TAR_BLOCK_SIZE)) + SizeUInt(Size) > FCount then
        raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FPos + C_TAR_BLOCK_SIZE, Size, Int64(FCount) - Int64(FPos + C_TAR_BLOCK_SIZE)]);
      LHdr := Default(TTarHeader);
      LHdr.Name := UstarEntryName;
      GuardTarNameForRead(LHdr.Name);
      LHdr.Kind := tekRegular;
      LHdr.LinkName := '';
      FillHeaderScalars(LHdr);
      LHdr.Size := LReal;
      GuardTarEntrySize(LHdr, FMaxEntry);
      GuardTarTotalSize(FCumTotal, UInt64(Size), FMaxTotal);
      FCumTotal := FCumTotal + UInt64(Size);
      GuardTarTotalSize(FCumTotal, UInt64(LReal), FMaxTotal);
      FCumTotal := FCumTotal + UInt64(LReal);
      LHdr.PaxRecords := nil;
      ReconstructSparse(LSegs, LReal, @FData[FPos + (SizeUInt(1 + LExtBlocks) * SizeUInt(C_TAR_BLOCK_SIZE))], 0, SizeUInt(Size));
      FExtDirty := True;
      FEntrySize := LReal;
      FEntryDataOfs := FPos + (SizeUInt(1 + LExtBlocks) * SizeUInt(C_TAR_BLOCK_SIZE));
      FPos := FPos + (SizeUInt(1 + LExtBlocks) * SizeUInt(C_TAR_BLOCK_SIZE)) + SizeUInt(Size) + SizeUInt(TarPadToBlock(Size));
      AHeader := LHdr;
      Result := True;
      Exit;
    end
    else
    begin
      AHeader := Default(TTarHeader);
      // 1.0 稀疏：pending 占位名配对才消费，否则配对腐坏即 EIOError，当次消费；
      // dense 热路径跳过名物化，回退分支内按需物化
      if FSparsePending then
      begin
        LUstarName := UstarEntryName;
        LIsSparse := IsGnuSparseDataName(LUstarName);
        if not LIsSparse then
          raise EIOError.Create('tar: sparse map without sparse data');
        FSparsePending := False;
      end
      else
        LIsSparse := False;
      // re-check IsSafe, Warn on reject (parity with auto-clear), auto-clear single-use if no guard
      if (FGlobalPaxPath <> '') and not IsSafeTarEntryName(FGlobalPaxPath) then
      begin
        LogGlobalPaxRejected(FGlobalPaxPath);
        FGlobalPaxPath := '';
      end;
      if (FGlobalPaxLinkPath <> '') and not IsSafeTarEntryName(FGlobalPaxLinkPath) then
      begin
        LogGlobalPaxRejected(FGlobalPaxLinkPath);
        FGlobalPaxLinkPath := '';
      end;
      if FPendingLongName <> '' then
        AHeader.Name := FPendingLongName
      else if LIsSparse then
        AHeader.Name := FSparseRealName
      else if FPaxPath <> '' then
        AHeader.Name := FPaxPath
      else if FGlobalPaxPath <> '' then
      begin
        AHeader.Name := FGlobalPaxPath;
        LUsedGlobalPath := True;
        if not HasGuards then
        begin
          LogGlobalPaxAutoClear;
          FGlobalPaxPath := '';
        end;
      end
      else
        AHeader.Name := UstarEntryName;
      GuardTarNameForRead(AHeader.Name);
      if FPendingLongLink <> '' then
        AHeader.LinkName := FPendingLongLink
      else if FPaxLinkPath <> '' then
        AHeader.LinkName := FPaxLinkPath
      else if FGlobalPaxLinkPath <> '' then
      begin
        AHeader.LinkName := FGlobalPaxLinkPath;
        LUsedGlobalPath := True;
        if not HasGuards then
        begin
          LogGlobalPaxAutoClear;
          FGlobalPaxLinkPath := '';
        end;
      end
      else
        AHeader.LinkName := CachedField(FPos + C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, FLastLinkName);
      AHeader.Kind := TypeFlagToKind(Flag);
      FillHeaderScalars(AHeader);
      if AHeader.Kind = tekDirectory then
        AHeader.Size := 0
      else if LIsSparse then
        AHeader.Size := FSparseRealSize
      else
        AHeader.Size := Size;
      // pax typed overrides: x wins, else guard-scoped g, else single-use g
      if FPaxExt.HasMTime then
        AHeader.MTimeUnix := FPaxExt.MTimeUnix
      else if FGlobalPaxExt.HasMTime then
      begin AHeader.MTimeUnix := FGlobalPaxExt.MTimeUnix; LUsedGlobalNums := True; end;
      if FPaxExt.HasUID then
        AHeader.UID := FPaxExt.UID
      else if FGlobalPaxExt.HasUID then
      begin AHeader.UID := FGlobalPaxExt.UID; LUsedGlobalNums := True; end;
      if FPaxExt.HasGID then
        AHeader.GID := FPaxExt.GID
      else if FGlobalPaxExt.HasGID then
      begin AHeader.GID := FGlobalPaxExt.GID; LUsedGlobalNums := True; end;
      if FPaxExt.HasUName then
        AHeader.UName := FPaxExt.UName
      else if FGlobalPaxExt.HasUName then
      begin AHeader.UName := FGlobalPaxExt.UName; LUsedGlobalNums := True; end;
      if FPaxExt.HasGName then
        AHeader.GName := FPaxExt.GName
      else if FGlobalPaxExt.HasGName then
      begin AHeader.GName := FGlobalPaxExt.GName; LUsedGlobalNums := True; end;
      // passthrough: consumed globals first, then per-entry x, both encounter order
      AHeader.PaxRecords := nil;
      if LUsedGlobalPath or LUsedGlobalNums then
        AppendPaxRecords(AHeader.PaxRecords, FGlobalPaxExt.Extra);
      AppendPaxRecords(AHeader.PaxRecords, FPaxExt.Extra);
      if LUsedGlobalNums and not HasGuards then
      begin
        LogGlobalPaxAutoClear;
        ClearGlobalPaxExt;
      end;
      GuardTarEntrySize(AHeader, FMaxEntry);
      if LIsSparse then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(Size), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(Size);
      end;
      if AHeader.Kind = tekRegular then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(AHeader.Size), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(AHeader.Size);
        FEntrySize := AHeader.Size;
      end
      else
        FEntrySize := 0;
      FEntryDataOfs := FPos + C_TAR_BLOCK_SIZE;
      if FEntryDataOfs + SizeUInt(Size) > FCount then
        raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, Size, Int64(FCount) - Int64(FEntryDataOfs)]);
      if LIsSparse then
      begin
        ParseSparseMapText(@FData[FEntryDataOfs], SizeUInt(Size), FSparseRealSize, LSegs, LMapLen);
        ReconstructSparse(LSegs, FSparseRealSize, @FData[FEntryDataOfs], SizeUInt(AlignUp(LMapLen, SizeUInt(C_TAR_BLOCK_SIZE))), SizeUInt(Size));
        FExtDirty := True;
      end;
      FPos := FPos + C_TAR_BLOCK_SIZE + SizeUInt(Size) + SizeUInt(TarPadToBlock(Size));
      Result := True;
      Exit;
    end;
    Pad := TarPadToBlock(Size);
    FPos := FPos + C_TAR_BLOCK_SIZE + SizeUInt(Size) + SizeUInt(Pad);
  end;
end;

function TTarReader.EntryDataOfs: SizeUInt;
begin
  Result := FEntryDataOfs;
end;

function TTarReader.TrySlice(out ASlice: TByteSpan): Boolean; inline;
begin
  // 稀疏重建缓冲优先：生命周期同条目视图，Next 后失效
  if FSparseValid then
  begin
    if Length(FSparseBuf) = 0 then
    begin
      ASlice := TByteSpan.Empty;
      Exit(False);
    end;
    ASlice := TByteSpan.Create(@FSparseBuf[0], SizeUInt(Length(FSparseBuf)));
    Exit(True);
  end;
  if (FEntryDataOfs = 0) or (FEntrySize <= 0) then
  begin
    ASlice := TByteSpan.Empty;
    Exit(False);
  end;
  if FEntryDataOfs + SizeUInt(FEntrySize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, FEntrySize, Int64(FCount) - Int64(FEntryDataOfs)]);
  ASlice := TByteSpan.Create(@FData[FEntryDataOfs], SizeUInt(FEntrySize));
  Result := True;
end;

function TTarReader.EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
var
  LS: TByteSpan;
begin
  Result := TrySlice(LS);
  if Result then
  begin
    AData := LS.Data;
    ACount := LS.Len;
  end
  else
  begin
    AData := nil;
    ACount := 0;
  end;
end;

function TTarReader.OpenEntryStream: IReader; inline;
var
  P: PByte;
  C: SizeUInt;
  LHold: TBytes;
begin
  // 单源零拷贝流：复用 nextpas.core.io.slice TIOSliceReader 单源，tar/zip 统一，bytes.ops.CopyMemory/SpanClone 单源，FHold 防悬垂；inline 薄转发（证据：inline 单一规范零拷贝视图 TrySlice + CreateSliceReaderWithHold 持有，bytes.ops SpanClone 单次 Move）
  // 性能：FBuf 路径 CreateSliceReaderWithHold 零拷贝持有镜像（Reader 释放后仍可读，inline/零拷贝，零分配）；外部 PByte 已在 CreateWithOptions 单次 SpanClone 高水位持有 FBuf（200 条目批量 1 次 vs 200 次，单次 Move bytes.ops 单源，防 UAF/高频 allocs，高水位池复用零每条目堆分配，FBuf 快路径零额外分配）
  // 稳定：FBuf 零拷贝持有 try..finally 必释；外部 PByte 已持有 FBuf 防悬垂 UAF（Next/FieldSlice 直读已安全），fallback 分支仍按需 SpanClone 自包含持有防 nil/空悬垂；inline 薄转发避 I-Cache 膨胀
  // 稀疏持有流：重建缓冲自包含，Reader 释放后仍可读，与 FBuf 路径同语义
  if FSparseValid then
    Exit(CreateSliceReaderWithHold(FSparseBuf, 0, SizeUInt(Length(FSparseBuf))));
  if not EntryDataSlice(P, C) then
  begin
    P := nil;
    C := 0;
  end;
  if Length(FBuf) > 0 then
    Result := CreateSliceReaderWithHold(FBuf, FEntryDataOfs, C)
  else
  begin
    if (P = nil) or (C = 0) then
      Exit(CreateSliceReader(nil, 0));
    // fallback：无 FBuf 时按需持有，SpanClone 单次 Move bytes.ops 单源，防 UAF；常见路径已由 CreateWithOptions 高水位 FBuf 持有覆盖零分配
    LHold := SpanClone(TByteSpan.Create(P, C)); // bytes.ops 单源，单次 Move，零拷贝视图物化
    Result := CreateSliceReaderWithHold(LHold, 0, SizeUInt(Length(LHold)));
  end;
end;

function TTarReader.EntrySize: Int64;
begin
  Result := FEntrySize;
end;

end.

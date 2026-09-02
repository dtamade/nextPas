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
   *  @note 生命周期：TrySlice/EntryDataSlice 为零拷贝 TByteSpan/PByte 视图（inline 单一规范，生命周期绑 Reader）；OpenEntryStream 为持有型 IReader（FBuf 时 CreateWithHold 零拷贝持有镜像、Reader 释放后仍可读；外部 PByte 时固化拷贝自包含 via SpanClone 单源 FHold 持有副本防 UAF、Reader 释放后仍可读，单次 Move）。 *}
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
    function FieldSlice(AOfs, ALen: SizeUInt): TByteSpan; // zero-copy view
    function TrimmedSlice(ABase: PByte; ALen: SizeUInt): TByteSpan;
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
    { — 零拷贝单一规范：TByteSpan 视图零分配，inline 薄转发，生命周期绑 Reader；OpenEntryStream 为持有型（FBuf 时零拷贝持有镜像、外部 PByte 时固化拷贝自包含防 UAF） — }
    function TrySlice(out ASlice: TByteSpan): Boolean; inline;
    { — 持有型流：FBuf 非空时 CreateWithHold 零拷贝持有镜像（Reader 释放后仍可读）；外部 PByte 时 SpanClone 固化拷贝自包含 via CreateSliceReaderWithHold（FHold 防悬垂、Reader 释放后仍可读） — }
    function OpenEntryStream: IReader;
    function EntrySize: Int64; inline;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.io.slice,
  nextpas.core.tar.common,
  nextpas.core.text.conv;

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
  FData := AData;
  FCount := ACount;
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

// single source 7-field cache table: order = FScanLens index (0:Name 1:LinkName 2:Magic 3:Version 4:UName 5:GName 6:Prefix), values derived from C_TAR_LAYOUT single source, bytes.ops single 512B pass — opaque generic, interface不暴露七字段命名
const
  C_TAR_SCAN_FIELDS: array[0..6] of TFieldRange = (
    (Off: 0; Len: 100),
    (Off: 157; Len: 100),
    (Off: 257; Len: 6),
    (Off: 263; Len: 2),
    (Off: 265; Len: 32),
    (Off: 297; Len: 32),
    (Off: 345; Len: 155)
  );
  // batch lens: values derived from C_TAR_SCAN_FIELDS.Len single source, bulk record copy avoids 7 repeated stores (I-Cache)
  C_TAR_SCAN_LENS: array[0..6] of SizeUInt = (100, 100, 6, 2, 32, 32, 155);

// single 512B ScanNulFieldTruncations, 7-field lens — single source C_TAR_SCAN_FIELDS, bytes.ops单源单次扫描
procedure CacheHeader(ASelf: TTarReader);
var
  LLens: array[0..6] of SizeUInt;
  LBlock: TByteSpan;
begin
  if ASelf.FScanValid and (ASelf.FScanPos = ASelf.FPos) then Exit;
  if ASelf.FPos + C_TAR_BLOCK_SIZE > ASelf.FCount then
  begin
    // bulk record copy: single array assign via C_TAR_SCAN_LENS, avoids 7 repeated stores
    ASelf.FScanLens := C_TAR_SCAN_LENS;
    ASelf.FScanPos := ASelf.FPos;
    ASelf.FScanValid := True;
    Exit;
  end;
  LBlock := TByteSpan.Create(@ASelf.FData[ASelf.FPos], C_TAR_BLOCK_SIZE);
  ScanNulFieldTruncations(LBlock, C_TAR_SCAN_FIELDS, @LLens[0]);
  ASelf.FScanLens := LLens; // array assign, zero loop
  ASelf.FScanPos := ASelf.FPos;
  ASelf.FScanValid := True;
end;

function TTarReader.ByteAt(AOfs: SizeUInt): Byte;
begin
  if AOfs >= FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (need %d, have %d)', [AOfs, AOfs + 1, FCount]);
  Result := FData[AOfs];
end;

function TTarReader.FieldSlice(AOfs, ALen: SizeUInt): TByteSpan;
var
  EndOfs: SizeUInt;
  LLen: SizeUInt;
  LIdx: SizeInt;
  LSpan: TByteSpan;
  LFieldOff: SizeUInt;
  I: SizeInt; // table-driven index
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (field %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  // header: cached 7 fields, single 512B ScanNulFieldTruncations via bytes.ops — declarative table-driven, no magic Off/Len dup, zero-copy
  if (AOfs >= FPos) and (EndOfs <= FPos + C_TAR_BLOCK_SIZE) then
  begin
    if not (FScanValid and (FScanPos = FPos)) then
      CacheHeader(Self);
    LFieldOff := AOfs - FPos;
    // offset direct index: jump table via case, eliminates 7-branch linear scan (hot path ~7x branch reduction, single dispatch)
    case LFieldOff of
      0:   if ALen = 100 then begin LLen := FScanLens[0]; if LLen = 0 then Exit(TByteSpan.Empty); Exit(TByteSpan.Create(@FData[AOfs], LLen)); end;
      157: if ALen = 100 then begin LLen := FScanLens[1]; if LLen = 0 then Exit(TByteSpan.Empty); Exit(TByteSpan.Create(@FData[AOfs], LLen)); end;
      257: if ALen = 6   then begin LLen := FScanLens[2]; if LLen = 0 then Exit(TByteSpan.Empty); Exit(TByteSpan.Create(@FData[AOfs], LLen)); end;
      263: if ALen = 2   then begin LLen := FScanLens[3]; if LLen = 0 then Exit(TByteSpan.Empty); Exit(TByteSpan.Create(@FData[AOfs], LLen)); end;
      265: if ALen = 32  then begin LLen := FScanLens[4]; if LLen = 0 then Exit(TByteSpan.Empty); Exit(TByteSpan.Create(@FData[AOfs], LLen)); end;
      297: if ALen = 32  then begin LLen := FScanLens[5]; if LLen = 0 then Exit(TByteSpan.Empty); Exit(TByteSpan.Create(@FData[AOfs], LLen)); end;
      345: if ALen = 155 then begin LLen := FScanLens[6]; if LLen = 0 then Exit(TByteSpan.Empty); Exit(TByteSpan.Create(@FData[AOfs], LLen)); end;
    end;
    // fallback: non-7 header field — bytes.ops single source SpanIndexOf/MemFindByte SIMD zero-copy, no scalar loop
    LSpan := TByteSpan.Create(@FData[AOfs], ALen);
    LIdx := SpanIndexOf(LSpan, 0);
    if LIdx < 0 then LLen := ALen else LLen := SizeUInt(LIdx);
    if LLen = 0 then Exit(TByteSpan.Empty);
    Result := TByteSpan.Create(@FData[AOfs], LLen);
    Exit;
  end;
  // non-header: single SpanIndexOf zero-copy, bytes.ops single source, zero-copy view
  LSpan := TByteSpan.Create(@FData[AOfs], ALen);
  LIdx := SpanIndexOf(LSpan, 0);
  if LIdx < 0 then LLen := ALen else LLen := SizeUInt(LIdx);
  if LLen = 0 then Exit(TByteSpan.Empty);
  Result := TByteSpan.Create(@FData[AOfs], LLen);
end;

function TTarReader.TrimmedSlice(ABase: PByte; ALen: SizeUInt): TByteSpan;
var
  Trim: SizeUInt;
begin
  Trim := ALen;
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
  // zero-copy FieldSlice then SpanEqual reuse, fast first-byte filter, MaterializeSpan single source
  LSpan := FieldSlice(AOfs, ALen);
  if LSpan.Len = 0 then
    Exit('');
  LCachedLen := SizeUInt(Length(ACached));
  if LCachedLen = LSpan.Len then
  begin
    if LCachedLen = 0 then
      Exit(ACached);
    // fast first-byte filter before SpanEqual:不等即跳过，无空块占位，inline零拷贝
    LCachedSpan := TByteSpan.Create(PByte(PAnsiChar(ACached)), LCachedLen);
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
  // INV-3 observability: warn whenever logger assigned, no NullLogger identity gate — 文案单源 base 常量
  if FLogger = nil then Exit;
  FLogger.Warn(C_TAR_WARN_GLOBAL_PAX_AUTO_CLEAR);
end;

procedure TTarReader.LogGlobalPaxRejected(const AName: string);
begin
  // INV-3 observability: global pax unsafe filter must Warn (consistent with auto-clear), prevents silent tamper — 文案单源 base 常量
  if FLogger = nil then Exit;
  FLogger.Warn(C_TAR_WARN_GLOBAL_PAX_REJECTED_PREFIX + AName + C_TAR_WARN_GLOBAL_PAX_REJECTED_SUFFIX);
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

function TTarReader.ParsePaxRecordsSlice(ABase: PByte; ALen: SizeUInt): Boolean;
var
  LPath, LLink: string;
begin
  // 单点：pax 解析委托 common，零拷贝 PByte 切片，复用 bytes.ops 视图语义
  Result := TarParsePaxRecords(ABase, ALen, LPath, LLink);
  if LPath <> '' then
  begin
    FPaxPath := LPath;
    Result := True;
  end;
  if LLink <> '' then
  begin
    FPaxLinkPath := LLink;
    Result := True;
  end;
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
  LNameSpan, LPrefixSpan: TByteSpan;
begin
  Result := False;
  FPendingLongName := '';
  FPendingLongLink := '';
  FPaxPath := '';
  FPaxLinkPath := '';
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
    if Size < 0 then
      raise EIOError.CreateFmt('tar: negative entry size %d at offset %d', [Size, FPos]);
    Flag := ByteAt(FPos + C_TAR_LAYOUT.TypeFlag.Off);
    if Flag = Ord('L') then
    begin
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
    end
    else if Flag = Ord('K') then
    begin
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
        if ParsePaxRecordsSlice(PayloadPtr, PayloadLen) then
        begin
          if Flag = Ord('g') then
          begin
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
    else
    begin
      AHeader := Default(TTarHeader);
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
      else if FPaxPath <> '' then
        AHeader.Name := FPaxPath
      else if FGlobalPaxPath <> '' then
      begin
        AHeader.Name := FGlobalPaxPath;
        if not HasGuards then
        begin
          LogGlobalPaxAutoClear;
          FGlobalPaxPath := '';
        end;
      end
      else
      begin
        if MagicHasUStar then
        begin
          LNameSpan := FieldSlice(FPos + C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len);
          LPrefixSpan := FieldSlice(FPos + C_TAR_LAYOUT.Prefix.Off, C_TAR_LAYOUT.Prefix.Len);
          if (LPrefixSpan.Len > 0) and (LNameSpan.Len > 0) then
            AHeader.Name := CombinePrefixName(LPrefixSpan, LNameSpan)
          else if LPrefixSpan.Len > 0 then
            AHeader.Name := SpanToString(LPrefixSpan)
          else if LNameSpan.Len > 0 then
            AHeader.Name := SpanToString(LNameSpan)
          else
            AHeader.Name := '';
        end
        else
          AHeader.Name := StringField(FPos + C_TAR_LAYOUT.Name.Off, C_TAR_LAYOUT.Name.Len);
      end;
      GuardTarNameForRead(AHeader.Name);
      if FPendingLongLink <> '' then
        AHeader.LinkName := FPendingLongLink
      else if FPaxLinkPath <> '' then
        AHeader.LinkName := FPaxLinkPath
      else if FGlobalPaxLinkPath <> '' then
      begin
        AHeader.LinkName := FGlobalPaxLinkPath;
        if not HasGuards then
        begin
          LogGlobalPaxAutoClear;
          FGlobalPaxLinkPath := '';
        end;
      end
      else
        AHeader.LinkName := CachedField(FPos + C_TAR_LAYOUT.LinkName.Off, C_TAR_LAYOUT.LinkName.Len, FLastLinkName);
      AHeader.Kind := TypeFlagToKind(Flag);
      AHeader.Mode := Cardinal(NumericField(FPos + C_TAR_LAYOUT.Mode.Off, C_TAR_LAYOUT.Mode.Len)) and $FFFF;
      AHeader.UID := Cardinal(NumericField(FPos + C_TAR_LAYOUT.UID.Off, C_TAR_LAYOUT.UID.Len));
      AHeader.GID := Cardinal(NumericField(FPos + C_TAR_LAYOUT.GID.Off, C_TAR_LAYOUT.GID.Len));
      if AHeader.Kind = tekDirectory then
        AHeader.Size := 0
      else
        AHeader.Size := Size;
      AHeader.MTimeUnix := NumericField(FPos + C_TAR_LAYOUT.MTime.Off, C_TAR_LAYOUT.MTime.Len);
      AHeader.UName := CachedField(FPos + C_TAR_LAYOUT.UName.Off, C_TAR_LAYOUT.UName.Len, FLastUName);
      AHeader.GName := CachedField(FPos + C_TAR_LAYOUT.GName.Off, C_TAR_LAYOUT.GName.Len, FLastGName);
      AHeader.DevMajor := NumericField(FPos + C_TAR_LAYOUT.DevMajor.Off, C_TAR_LAYOUT.DevMajor.Len);
      AHeader.DevMinor := NumericField(FPos + C_TAR_LAYOUT.DevMinor.Off, C_TAR_LAYOUT.DevMinor.Len);
      GuardTarEntrySize(AHeader, FMaxEntry);
      if AHeader.Kind = tekRegular then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(AHeader.Size), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(AHeader.Size);
        FEntrySize := Size;
      end
      else
        FEntrySize := 0;
      FEntryDataOfs := FPos + C_TAR_BLOCK_SIZE;
      if FEntryDataOfs + SizeUInt(Size) > FCount then
        raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, Size, Int64(FCount) - Int64(FEntryDataOfs)]);
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

function TTarReader.OpenEntryStream: IReader;
var
  P: PByte;
  C: SizeUInt;
  LCopy: TBytes;
begin
  // 单源持有型流：复用 nextpas.core.io.slice TIOSliceReader 单源，tar/zip 统一，bytes.ops.CopyMemory/SpanClone 单源，FHold 防悬垂
  // 性能+稳定：FBuf 路径 CreateSliceReaderWithHold 零拷贝持有镜像（Reader 释放后仍可读，inline/零拷贝）；外部 PByte 路径固化拷贝自包含 via SpanClone 单源（FHold 持有副本防 UAF，Reader 释放后仍可读，单次 Move，避免外部 TBytes 释放后悬垂）
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
    // stability: clone external slice to self-contained hold, eliminates UAF when caller frees external buffer
    LCopy := SpanClone(TByteSpan.Create(P, C));
    Result := CreateSliceReaderWithHold(LCopy, 0, C);
  end;
end;

function TTarReader.EntrySize: Int64;
begin
  Result := FEntrySize;
end;

end.

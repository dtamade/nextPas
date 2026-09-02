unit nextpas.core.tar.reader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf,
  nextpas.core.log.intf;

type
  { header scan lens: named 7-field NUL truncation (replaces generic array[0..6] flatten, semantic explicit) }
  TTarScanLens = record
    Name: SizeUInt;
    LinkName: SizeUInt;
    Magic: SizeUInt;
    Version: SizeUInt;
    UName: SizeUInt;
    GName: SizeUInt;
    Prefix: SizeUInt;
  end;

  TTarReader = class;

  {** @desc RAII guard for global g pax: weak ref to Reader, clears FGlobalPax on scope exit.
   *  @note Zero alloc until AcquireGlobalPaxGuard called; IInterface bound to caller scope. Weak ref avoids prolonging Reader/FBuf large mirror (batch peak safe); Reader.Destroy invalidates guard, no double free. *}
  TTarGlobalPaxGuard = class(TInterfacedObject)
  private
    FReader: TTarReader; // weak: not prolong Reader/FBuf, nilled on Reader.Destroy / Destroy
    FNext: TTarGlobalPaxGuard; // linked list next, weak
    procedure Invalidate;
  public
    constructor Create(AReader: TTarReader);
    destructor Destroy; override;
  end;

  {** @desc Tar 读器：迭代内存镜像中的条目，零拷贝视图 + bomb 守卫。
   *  @note 生命周期：TrySlice/EntryDataSlice 为零拷贝 TByteSpan/PByte 视图（inline 单一规范，生命周期绑 Reader）；OpenEntryStream 为持有型 IReader（FBuf 时 CreateWithHold 持有镜像，外部 PByte 时 SpanClone 固化拷贝自包含，Reader 释放后仍可读）。 *}
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
    // header cache: 7-field NUL lens, single 512B scan
    FScanValid: Boolean;
    FScanPos: SizeUInt;
    FScanLens: TTarScanLens;
    FGuardHead: TTarGlobalPaxGuard; // weak linked list head, no array, no geometric
    FGuardCount: SizeUInt; // simple counter without capacity
    FLogger: ILogger; // warn on auto-clear
    function HasGuards: Boolean; inline;
    procedure LogGlobalPaxAutoClear;
    procedure RegisterGuard(AGuard: TTarGlobalPaxGuard);
    procedure UnregisterGuard(AGuard: TTarGlobalPaxGuard);
    procedure InvalidateGuards;
    function ByteAt(AOfs: SizeUInt): Byte;
    function FieldSlice(AOfs, ALen: SizeUInt): TByteSpan; // zero-copy view
    function TrimmedSlice(ABase: PByte; ALen: SizeUInt): TByteSpan;
    function MaterializeSpan(const ASpan: TByteSpan): string; inline; // single source SpanToString, empty guard
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
    {** @desc RAII guard: acquire IInterface that clears global g pax on scope exit; use `var G := Reader.AcquireGlobalPaxGuard;` to auto-isolate. Inline thin forward, zero alloc until called. *}
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
    { — 零拷贝单一规范：TByteSpan 视图零分配，inline 薄转发，生命周期绑 Reader；OpenEntryStream 为持有型，外部 PByte 时固化拷贝自包含 — }
    function TrySlice(out ASlice: TByteSpan): Boolean; inline;
    { — 持有型流：FBuf 非空时 CreateWithHold 持有镜像，外部 PByte 时 SpanClone 固化拷贝自包含，Reader 释放后仍可读 — }
    function OpenEntryStream: IReader;
    function EntrySize: Int64; inline;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
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
  FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
end;

// single 512B ScanNulFieldTruncations, 7-field lens
procedure CacheHeader(ASelf: TTarReader);
var
  LFields: array[0..6] of TFieldRange;
  LLens: array[0..6] of SizeUInt;
  LBlock: TByteSpan;
begin
  if ASelf.FScanValid and (ASelf.FScanPos = ASelf.FPos) then Exit;
  if ASelf.FPos + C_TAR_BLOCK_SIZE > ASelf.FCount then
  begin
    ASelf.FScanLens.Name := C_TAR_LAYOUT.Name.Len;
    ASelf.FScanLens.Prefix := C_TAR_LAYOUT.Prefix.Len;
    ASelf.FScanLens.LinkName := C_TAR_LAYOUT.LinkName.Len;
    ASelf.FScanLens.UName := C_TAR_LAYOUT.UName.Len;
    ASelf.FScanLens.GName := C_TAR_LAYOUT.GName.Len;
    ASelf.FScanLens.Magic := C_TAR_LAYOUT.Magic.Len;
    ASelf.FScanLens.Version := C_TAR_LAYOUT.Version.Len;
    ASelf.FScanPos := ASelf.FPos;
    ASelf.FScanValid := True;
    Exit;
  end;
  LFields[0].Off := C_TAR_LAYOUT.Name.Off;     LFields[0].Len := C_TAR_LAYOUT.Name.Len;
  LFields[1].Off := C_TAR_LAYOUT.LinkName.Off; LFields[1].Len := C_TAR_LAYOUT.LinkName.Len;
  LFields[2].Off := C_TAR_LAYOUT.Magic.Off;    LFields[2].Len := C_TAR_LAYOUT.Magic.Len;
  LFields[3].Off := C_TAR_LAYOUT.Version.Off;  LFields[3].Len := C_TAR_LAYOUT.Version.Len;
  LFields[4].Off := C_TAR_LAYOUT.UName.Off;    LFields[4].Len := C_TAR_LAYOUT.UName.Len;
  LFields[5].Off := C_TAR_LAYOUT.GName.Off;    LFields[5].Len := C_TAR_LAYOUT.GName.Len;
  LFields[6].Off := C_TAR_LAYOUT.Prefix.Off;   LFields[6].Len := C_TAR_LAYOUT.Prefix.Len;
  LBlock := TByteSpan.Create(@ASelf.FData[ASelf.FPos], C_TAR_BLOCK_SIZE);
  ScanNulFieldTruncations(LBlock, LFields, @LLens[0]);
  ASelf.FScanLens.Name := LLens[0];
  ASelf.FScanLens.LinkName := LLens[1];
  ASelf.FScanLens.Magic := LLens[2];
  ASelf.FScanLens.Version := LLens[3];
  ASelf.FScanLens.UName := LLens[4];
  ASelf.FScanLens.GName := LLens[5];
  ASelf.FScanLens.Prefix := LLens[6];
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
  LOneField: array[0..0] of TFieldRange;
  LOneLen: array[0..0] of SizeUInt;
  LBlockTmp: TByteSpan;
  IsHeaderField: Boolean;
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (field %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  // header: cached 7 fields, single 512B ScanNulFieldTruncations via bytes.ops
  if (AOfs >= FPos) and (EndOfs <= FPos + C_TAR_BLOCK_SIZE) then
  begin
    if not (FScanValid and (FScanPos = FPos)) then
      CacheHeader(Self);
    // explicit 7-field dispatch, readable, no table loop
    IsHeaderField := True;
    if (AOfs = FPos + C_TAR_LAYOUT.Name.Off) and (ALen = C_TAR_LAYOUT.Name.Len) then
      LLen := FScanLens.Name
    else if (AOfs = FPos + C_TAR_LAYOUT.LinkName.Off) and (ALen = C_TAR_LAYOUT.LinkName.Len) then
      LLen := FScanLens.LinkName
    else if (AOfs = FPos + C_TAR_LAYOUT.Magic.Off) and (ALen = C_TAR_LAYOUT.Magic.Len) then
      LLen := FScanLens.Magic
    else if (AOfs = FPos + C_TAR_LAYOUT.Version.Off) and (ALen = C_TAR_LAYOUT.Version.Len) then
      LLen := FScanLens.Version
    else if (AOfs = FPos + C_TAR_LAYOUT.UName.Off) and (ALen = C_TAR_LAYOUT.UName.Len) then
      LLen := FScanLens.UName
    else if (AOfs = FPos + C_TAR_LAYOUT.GName.Off) and (ALen = C_TAR_LAYOUT.GName.Len) then
      LLen := FScanLens.GName
    else if (AOfs = FPos + C_TAR_LAYOUT.Prefix.Off) and (ALen = C_TAR_LAYOUT.Prefix.Len) then
      LLen := FScanLens.Prefix
    else
      IsHeaderField := False;
    if not IsHeaderField then
    begin
      // fallback: non-cached header field via single-field scan
      LOneField[0].Off := AOfs - FPos;
      LOneField[0].Len := ALen;
      LBlockTmp := TByteSpan.Create(@FData[FPos], C_TAR_BLOCK_SIZE);
      ScanNulFieldTruncations(LBlockTmp, LOneField, @LOneLen[0]);
      LLen := LOneLen[0];
      if LLen = 0 then Exit(TByteSpan.Empty);
      Result := TByteSpan.Create(@FData[AOfs], LLen);
      Exit;
    end;
    if LLen = 0 then Exit(TByteSpan.Empty);
    Result := TByteSpan.Create(@FData[AOfs], LLen);
    Exit;
  end;
  // non-header: single SpanIndexOf
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

function TTarReader.MaterializeSpan(const ASpan: TByteSpan): string; inline;
begin
  // single source: zero-copy view -> string materialization, empty guard, SpanToString single source (bytes.ops inline)
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
    // fast first-byte filter before SpanEqual
    LCachedSpan := TByteSpan.Create(PByte(PAnsiChar(ACached)), LCachedLen);
    if LCachedSpan.Data^ <> LSpan.Data^ then
    begin
    end
    else if SpanEqual(LCachedSpan, LSpan) then
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
  // simple linked list, no geometric array, zero alloc per guard beyond object
  AGuard.FNext := FGuardHead;
  FGuardHead := AGuard;
  Inc(FGuardCount);
end;

procedure TTarReader.UnregisterGuard(AGuard: TTarGlobalPaxGuard);
var
  Prev, Cur: TTarGlobalPaxGuard;
begin
  Prev := nil;
  Cur := FGuardHead;
  while Cur <> nil do
  begin
    if Cur = AGuard then
    begin
      if Prev = nil then
        FGuardHead := Cur.FNext
      else
        Prev.FNext := Cur.FNext;
      Cur.FNext := nil;
      if FGuardCount > 0 then Dec(FGuardCount);
      Exit;
    end;
    Prev := Cur;
    Cur := Cur.FNext;
  end;
end;

procedure TTarReader.InvalidateGuards;
var
  Cur, LNext: TTarGlobalPaxGuard;
begin
  Cur := FGuardHead;
  while Cur <> nil do
  begin
    LNext := Cur.FNext;
    Cur.Invalidate;
    Cur.FNext := nil;
    Cur := LNext;
  end;
  FGuardHead := nil;
  FGuardCount := 0;
end;

procedure TTarReader.LogGlobalPaxAutoClear;
begin
  // INV-3 observability: warn whenever logger assigned, no NullLogger identity gate
  if FLogger = nil then Exit;
  FLogger.Warn('tar: global pax auto-cleared after single use (no guard held; hold AcquireGlobalPaxGuard IInterface to persist across Next/image, or call ClearGlobalPax explicitly)');
end;

function TTarReader.AcquireGlobalPaxGuard: IInterface; inline;
begin
  Result := TTarGlobalPaxGuard.Create(Self);
end;

constructor TTarGlobalPaxGuard.Create(AReader: TTarReader);
begin
  inherited Create;
  FReader := AReader; // weak: no FBuf retention, batch peak safe
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
  // stability: invalidate weak guards first to avoid use-after-free and release FBuf peak even if guard held
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
      // L: not counted in total
      if PayloadLen > 0 then
        FPendingLongName := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongName := '';
    end
    else if Flag = Ord('K') then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      // K: not counted in total
      if PayloadLen > 0 then
        FPendingLongLink := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongLink := '';
    end
    else if (Flag = Ord('x')) or (Flag = Ord('g')) then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      // x/g: not counted in total
      if PayloadLen > 0 then
      begin
        if ParsePaxRecordsSlice(PayloadPtr, PayloadLen) then
        begin
          if Flag = Ord('g') then
          begin
            if FPaxPath <> '' then
            begin
              // IsSafe filter before storing global
              if IsSafeTarEntryName(FPaxPath) then
                FGlobalPaxPath := FPaxPath
              else
                FGlobalPaxPath := '';
              FPaxPath := '';
            end;
            if FPaxLinkPath <> '' then
            begin
              if IsSafeTarEntryName(FPaxLinkPath) then
                FGlobalPaxLinkPath := FPaxLinkPath
              else
                FGlobalPaxLinkPath := '';
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
      // re-check IsSafe, auto-clear single-use if no guard
      if (FGlobalPaxPath <> '') and not IsSafeTarEntryName(FGlobalPaxPath) then
        FGlobalPaxPath := '';
      if (FGlobalPaxLinkPath <> '') and not IsSafeTarEntryName(FGlobalPaxLinkPath) then
        FGlobalPaxLinkPath := '';
      if FPendingLongName <> '' then
        AHeader.Name := FPendingLongName
      else if FPaxPath <> '' then
        AHeader.Name := FPaxPath
      else if FGlobalPaxPath <> '' then
      begin
        AHeader.Name := FGlobalPaxPath;
        if FGuardCount = 0 then
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
        if FGuardCount = 0 then
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

{ — TTarSliceReader：零拷贝切片 IReader — }
type
  TTarSliceReader = class(TInterfacedObject, IReader)
  private
    FBase: PByte;
    FSize: SizeUInt;
    FPos: SizeUInt;
    FHold: TBytes;
  public
    constructor Create(ABase: PByte; ASize: SizeUInt); overload;
    constructor CreateWithHold(const AHold: TBytes; AOfs: SizeUInt; ASize: SizeUInt); overload;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TTarSliceReader.Create(ABase: PByte; ASize: SizeUInt);
begin
  inherited Create;
  FBase := ABase;
  FSize := ASize;
  FPos := 0;
  FHold := nil;
end;

constructor TTarSliceReader.CreateWithHold(const AHold: TBytes; AOfs: SizeUInt; ASize: SizeUInt);
var
  LAvail: SizeUInt;
begin
  inherited Create;
  FHold := AHold;
  FSize := ASize;
  FPos := 0;
  if Length(AHold) > 0 then
  begin
    LAvail := SizeUInt(Length(AHold));
    if AOfs > LAvail then
      FBase := nil
    else
    begin
      if AOfs + ASize > LAvail then
        FSize := LAvail - AOfs;
      if FSize > 0 then
        FBase := @AHold[AOfs]
      else
        FBase := nil;
    end;
  end
  else
    FBase := nil;
end;

function TTarSliceReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  Avail: SizeUInt;
  LCount: SizeUInt;
begin
  if FPos >= FSize then
    Exit(0);
  Avail := FSize - FPos;
  LCount := ACount;
  if LCount > Avail then
    LCount := Avail;
  if LCount > 0 then
  begin
    CopyMemory(@FBase[FPos], PByte(@ABuf), LCount);
    Inc(FPos, LCount);
  end;
  Result := LCount;
end;

function TTarReader.OpenEntryStream: IReader;
var
  P: PByte;
  C: SizeUInt;
  LCopy: TBytes;
begin
  if not EntryDataSlice(P, C) then
  begin
    P := nil;
    C := 0;
  end;
  if Length(FBuf) > 0 then
    Result := TTarSliceReader.CreateWithHold(FBuf, FEntryDataOfs, C)
  else if C > 0 then
  begin
    LCopy := SpanClone(TByteSpan.Create(P, C));
    Result := TTarSliceReader.CreateWithHold(LCopy, 0, C);
  end
  else
    Result := TTarSliceReader.Create(P, C);
end;

function TTarReader.EntrySize: Int64;
begin
  Result := FEntrySize;
end;

end.

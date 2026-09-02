unit nextpas.core.tar.reader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf;

type
  { — 头扫描记录表：8字段NUL截断缓存收敛为记录，单遍512循环表驱动（bytes.ops 单源、零拷贝 SIMD）— }
  TTarScanCache = record
    Pos: SizeUInt;
    Valid: Boolean;
    NameLen: SizeUInt;
    PrefixLen: SizeUInt;
    LinkLen: SizeUInt;
    UNameLen: SizeUInt;
    GNameLen: SizeUInt;
    MagicLen: SizeUInt;
    VersionLen: SizeUInt;
  end;

  {** @desc Tar 读器：迭代内存镜像中的条目，零拷贝视图 + bomb 守卫。 *}
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
    FGlobalPaxPath: string;
    FGlobalPaxLinkPath: string;
    FMaxEntry: SizeUInt;
    FMaxTotal: UInt64;
    FCumTotal: UInt64;
    FLastUName: string;
    FLastGName: string;
    FLastLinkName: string;
    { — 记录表收敛：单遍512头扫描8字段缓存，表驱动解耦扁平变量与循环（bytes.ops 单源）— }
    FScan: TTarScanCache;
    procedure EnsureHeaderScanned;
    { — 热路径外联禁 inline，薄转发可 inline；Move 单源 bytes.ops — }
    function ByteAt(AOfs: SizeUInt): Byte;
    { — 零拷贝视图：字段切片不分配，按需 SpanToString 单次 Move（bytes.ops 单源）— }
    function FieldSlice(AOfs, ALen: SizeUInt): TByteSpan;
    function TrimmedSlice(ABase: PByte; ALen: SizeUInt): TByteSpan;
    { — 零拷贝薄转发：外联避 Move(Result[1]) inline 膨胀（design-conventions 红线1），单源 SpanToString — }
    function StringField(AOfs, ALen: SizeUInt): string;
    function NumericField(AOfs, ALen: SizeUInt): Int64;
    function MagicHasUStar: Boolean; inline;
    procedure VerifyChecksum;
    function HeaderIsZeroOrValid(APos: SizeUInt): Boolean;
    { — pax/扩展：零拷贝 slice 解析，消除每记录 Copy+BytesToText 分配 — }
    function ParsePaxRecordsSlice(ABase: PByte; ALen: SizeUInt): Boolean;
    function ParsePaxRecords(const AData: TBytes): Boolean;
    { — 扩展载荷：去重 GNU L/K 与 pax 三分支的单源拷贝 — }
    function GetExtendedPayload(ASize: Int64; out APtr: PByte; out ALen: SizeUInt): Boolean;
    { — 零拷贝薄转发：外联避 Move(Result[1]) inline 膨胀（红线1），单源 SpanToString — }
    function SliceToString(ABase: PByte; ALen: SizeUInt): string;
    { — 合并：prefix/name 单次SetLength+两Move零拷贝（bytes.ops单源Move语义），禁inline避免Result[1]双喂膨胀 — }
    function CombinePrefixName(const APrefix, AName: TByteSpan): string;
    { — 非热点字段缓存：零拷贝 slice + SpanEqual/MemEqual 复用已分配串（bytes.ops 单源 SIMD），万级遍历降分配；外联禁 inline（@ACached[1] 喂 SpanEqual 违反 design-conventions 红线1，FPC 3.3.1 常量传播拷栈垃圾）— }
    function CachedField(AOfs, ALen: SizeUInt; var ACached: string): string;
  public
    procedure ClearGlobalPax; inline;
    constructor Create(const AData: TBytes); overload;
    constructor Create(AData: PByte; ACount: SizeUInt); overload;
    constructor CreateWithOptions(const AData: TBytes; const AOptions: TTarReadOptions); overload;
    constructor CreateWithOptions(AData: PByte; ACount: SizeUInt; const AOptions: TTarReadOptions); overload;
    function Next(out AHeader: TTarHeader): Boolean;
    function EntryData: TBytes;
    function EntryDataOfs: SizeUInt;
    function EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
    function TrySlice(out ASlice: TByteSpan): Boolean; inline;
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

const
  CBlockSize = C_TAR_BLOCK_SIZE;

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
  FScan.Valid := False;
  FScan.Pos := 0;
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
  FScan.Valid := False;
  FScan.Pos := 0;
  if AOptions.MaxEntrySize = 0 then
    FMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    FMaxEntry := AOptions.MaxEntrySize;
  FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
end;

procedure TTarReader.EnsureHeaderScanned;
var
  B: PByte;
  I, J: SizeUInt;
  // 记录表驱动：Off/Len/缓存指针三元组，解耦7字段扁平if-else与单遍512循环，可维护性+质感
  LTable: array[0..6] of record Off, Len: SizeUInt; PLen: ^SizeUInt; end;
begin
  if FScan.Valid and (FScan.Pos = FPos) then
    Exit;
  // 融合：单遍512块扫描求7字段NUL截断（Name/LinkName/Magic/Version/UName/GName/Prefix），零拷贝视图，单源 bytes.ops
  FScan.NameLen := C_TAR_LAYOUT.Name.Len;
  FScan.PrefixLen := C_TAR_LAYOUT.Prefix.Len;
  FScan.LinkLen := C_TAR_LAYOUT.LinkName.Len;
  FScan.UNameLen := C_TAR_LAYOUT.UName.Len;
  FScan.GNameLen := C_TAR_LAYOUT.GName.Len;
  FScan.MagicLen := C_TAR_LAYOUT.Magic.Len;
  FScan.VersionLen := C_TAR_LAYOUT.Version.Len;
  if FPos + CBlockSize > FCount then
  begin
    FScan.Pos := FPos;
    FScan.Valid := True;
    Exit;
  end;
  // 记录表：字段描述与缓存指针一一映射，表驱动消除扁平if-else耦合
  LTable[0].Off := C_TAR_LAYOUT.Name.Off;     LTable[0].Len := C_TAR_LAYOUT.Name.Len;     LTable[0].PLen := @FScan.NameLen;
  LTable[1].Off := C_TAR_LAYOUT.LinkName.Off; LTable[1].Len := C_TAR_LAYOUT.LinkName.Len; LTable[1].PLen := @FScan.LinkLen;
  LTable[2].Off := C_TAR_LAYOUT.Magic.Off;    LTable[2].Len := C_TAR_LAYOUT.Magic.Len;    LTable[2].PLen := @FScan.MagicLen;
  LTable[3].Off := C_TAR_LAYOUT.Version.Off;  LTable[3].Len := C_TAR_LAYOUT.Version.Len;  LTable[3].PLen := @FScan.VersionLen;
  LTable[4].Off := C_TAR_LAYOUT.UName.Off;    LTable[4].Len := C_TAR_LAYOUT.UName.Len;    LTable[4].PLen := @FScan.UNameLen;
  LTable[5].Off := C_TAR_LAYOUT.GName.Off;    LTable[5].Len := C_TAR_LAYOUT.GName.Len;    LTable[5].PLen := @FScan.GNameLen;
  LTable[6].Off := C_TAR_LAYOUT.Prefix.Off;   LTable[6].Len := C_TAR_LAYOUT.Prefix.Len;   LTable[6].PLen := @FScan.PrefixLen;
  B := @FData[FPos];
  for I := 0 to CBlockSize - 1 do
  begin
    if B[I] <> 0 then
      Continue;
    for J := 0 to High(LTable) do
      if (I >= LTable[J].Off) and (I < LTable[J].Off + LTable[J].Len) then
      begin
        if LTable[J].PLen^ = LTable[J].Len then
          LTable[J].PLen^ := I - LTable[J].Off;
        Break;
      end;
  end;
  FScan.Pos := FPos;
  FScan.Valid := True;
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
  LCached: Boolean;
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (field %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  // 融合：头块内字段复用单遍512扫描缓存，避免每字段 SpanIndexOf SIMD；非头块 fallback 单次 SpanIndexOf（bytes.ops 单源）
  if (AOfs >= FPos) and (EndOfs <= FPos + CBlockSize) then
  begin
    EnsureHeaderScanned;
    LCached := False;
    if (AOfs = FPos + C_TAR_LAYOUT.Name.Off) and (ALen = C_TAR_LAYOUT.Name.Len) then
    begin LLen := FScan.NameLen; LCached := True; end
    else if (AOfs = FPos + C_TAR_LAYOUT.Prefix.Off) and (ALen = C_TAR_LAYOUT.Prefix.Len) then
    begin LLen := FScan.PrefixLen; LCached := True; end
    else if (AOfs = FPos + C_TAR_LAYOUT.LinkName.Off) and (ALen = C_TAR_LAYOUT.LinkName.Len) then
    begin LLen := FScan.LinkLen; LCached := True; end
    else if (AOfs = FPos + C_TAR_LAYOUT.UName.Off) and (ALen = C_TAR_LAYOUT.UName.Len) then
    begin LLen := FScan.UNameLen; LCached := True; end
    else if (AOfs = FPos + C_TAR_LAYOUT.GName.Off) and (ALen = C_TAR_LAYOUT.GName.Len) then
    begin LLen := FScan.GNameLen; LCached := True; end
    else if (AOfs = FPos + C_TAR_LAYOUT.Magic.Off) and (ALen = C_TAR_LAYOUT.Magic.Len) then
    begin LLen := FScan.MagicLen; LCached := True; end
    else if (AOfs = FPos + C_TAR_LAYOUT.Version.Off) and (ALen = C_TAR_LAYOUT.Version.Len) then
    begin LLen := FScan.VersionLen; LCached := True; end;
    if LCached then
    begin
      if LLen = 0 then
        Exit(TByteSpan.Empty);
      Result := TByteSpan.Create(@FData[AOfs], LLen);
      Exit;
    end;
  end;
  // 非头块或未缓存字段：零拷贝视图单次 SpanIndexOf（bytes.ops 单源 SIMD）
  LSpan := TByteSpan.Create(@FData[AOfs], ALen);
  LIdx := SpanIndexOf(LSpan, 0);
  if LIdx < 0 then
    LLen := ALen
  else
    LLen := SizeUInt(LIdx);
  if LLen = 0 then
    Exit(TByteSpan.Empty);
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

function TTarReader.StringField(AOfs, ALen: SizeUInt): string;
var
  LSpan: TByteSpan;
begin
  // 外联：避 Move(Result[1]) inline 膨胀（红线1），零拷贝 SpanToString 单源 Move
  LSpan := FieldSlice(AOfs, ALen);
  if LSpan.Len = 0 then
    Exit('');
  Result := SpanToString(LSpan);
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
  if FPos + CBlockSize > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (need %d, have %d)', [FPos, CBlockSize, FCount - FPos]);
  TarVerifyBlockChecksum(@FData[FPos], FPos);
end;

function TTarReader.HeaderIsZeroOrValid(APos: SizeUInt): Boolean;
begin
  if APos + CBlockSize > FCount then
    Exit(False);
  Result := TarHeaderIsZeroOrValid(@FData[APos], APos);
end;

function TTarReader.SliceToString(ABase: PByte; ALen: SizeUInt): string;
var
  LSpan: TByteSpan;
begin
  // 外联：避 Move(Result[1]) inline 膨胀（红线1），零拷贝 TrimmedSlice+SpanToString 单源
  LSpan := TrimmedSlice(ABase, ALen);
  if LSpan.Len = 0 then
    Exit('');
  Result := SpanToString(LSpan);
end;

function TTarReader.CombinePrefixName(const APrefix, AName: TByteSpan): string;
begin
  Result := SpanJoinWithSeparator(APrefix, AName, '/');
end;

function TTarReader.CachedField(AOfs, ALen: SizeUInt; var ACached: string): string;
var
  LSpan: TByteSpan;
  LCachedLen: SizeUInt;
  LCachedSpan: TByteSpan;
begin
  // 单源收敛：SpanEqual（bytes.ops SIMD MemEqual）替代 System.CompareMem，零拷贝视图单次 Move，inline 热路径
  LCachedLen := SizeUInt(Length(ACached));
  if (LCachedLen > 0) and (LCachedLen <= ALen) then
  begin
    LCachedSpan := TByteSpan.Create(PByte(PAnsiChar(ACached)), LCachedLen);
    if SpanEqual(LCachedSpan, TByteSpan.Create(@FData[AOfs], LCachedLen)) then
      if (LCachedLen = ALen) or (FData[AOfs + LCachedLen] = 0) then
        Exit(ACached);
  end;
  LSpan := FieldSlice(AOfs, ALen);
  if LSpan.Len = 0 then
    Exit('');
  if LCachedLen = LSpan.Len then
  begin
    if LCachedLen > 0 then
    begin
      LCachedSpan := TByteSpan.Create(PByte(PAnsiChar(ACached)), LCachedLen);
      if SpanEqual(LCachedSpan, LSpan) then
        Exit(ACached);
    end
    else
      Exit(ACached);
  end;
  Result := SpanToString(LSpan);
  ACached := Result;
end;

procedure TTarReader.ClearGlobalPax; inline;
begin
  FGlobalPaxPath := '';
  FGlobalPaxLinkPath := '';
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
  if FPos + CBlockSize + SizeUInt(ASize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FPos + CBlockSize, ASize, Int64(FCount) - Int64(FPos + CBlockSize)]);
  APtr := @FData[FPos + CBlockSize];
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
    if FCount - FPos < CBlockSize then
      raise EIOError.CreateFmt('tar: trailing partial block at offset %d (need %d, have %d)', [FPos, CBlockSize, FCount - FPos]);
    if HeaderIsZeroOrValid(FPos) then
    begin
      if FPos + CBlockSize = FCount then
        Exit(False);
      if FPos + 2 * CBlockSize > FCount then
        raise EIOError.CreateFmt('tar: truncated stream at offset %d (single zero block, need two)', [FPos]);
      if not TarHeaderIsZeroBlock(@FData[FPos + CBlockSize]) then
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
      if Size > 0 then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(Size), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(Size);
      end;
      if PayloadLen > 0 then
        FPendingLongName := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongName := '';
    end
    else if Flag = Ord('K') then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      if Size > 0 then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(Size), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(Size);
      end;
      if PayloadLen > 0 then
        FPendingLongLink := SliceToString(PayloadPtr, PayloadLen)
      else
        FPendingLongLink := '';
    end
    else if (Flag = Ord('x')) or (Flag = Ord('g')) then
    begin
      GetExtendedPayload(Size, PayloadPtr, PayloadLen);
      if Size > 0 then
      begin
        GuardTarTotalSize(FCumTotal, UInt64(Size), FMaxTotal);
        FCumTotal := FCumTotal + UInt64(Size);
      end;
      if PayloadLen > 0 then
      begin
        if ParsePaxRecordsSlice(PayloadPtr, PayloadLen) then
        begin
          if Flag = Ord('g') then
          begin
            if FPaxPath <> '' then
            begin
              FGlobalPaxPath := FPaxPath;
              FPaxPath := '';
            end;
            if FPaxLinkPath <> '' then
            begin
              FGlobalPaxLinkPath := FPaxLinkPath;
              FPaxLinkPath := '';
            end;
          end;
        end;
      end
      else
      begin
        // 空 pax 块，无记录
      end;
    end
    else
    begin
      AHeader := Default(TTarHeader);
      if FPendingLongName <> '' then
        AHeader.Name := FPendingLongName
      else if FPaxPath <> '' then
        AHeader.Name := FPaxPath
      else if FGlobalPaxPath <> '' then
        AHeader.Name := FGlobalPaxPath
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
      if FPendingLongLink <> '' then
        AHeader.LinkName := FPendingLongLink
      else if FPaxLinkPath <> '' then
        AHeader.LinkName := FPaxLinkPath
      else if FGlobalPaxLinkPath <> '' then
        AHeader.LinkName := FGlobalPaxLinkPath
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
      FEntryDataOfs := FPos + CBlockSize;
      if FEntryDataOfs + SizeUInt(Size) > FCount then
        raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, Size, Int64(FCount) - Int64(FEntryDataOfs)]);
      FPos := FPos + CBlockSize + SizeUInt(Size) + SizeUInt(TarPadToBlock(Size));
      Result := True;
      Exit;
    end;
    Pad := TarPadToBlock(Size);
    FPos := FPos + CBlockSize + SizeUInt(Size) + SizeUInt(Pad);
  end;
end;

function TTarReader.EntryData: TBytes;
var
  LS: TByteSpan;
begin
  Result := nil;
  if not TrySlice(LS) then
    Exit;
  if UInt64(LS.Len) > UInt64(FMaxEntry) then
    raise EIOError.CreateFmt('tar: entry size %d exceeds limit %d at offset %d', [Int64(LS.Len), Int64(FMaxEntry), FEntryDataOfs]);
  Result := SpanClone(LS);
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

unit nextpas.core.tar.reader;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.io.intf;

type
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
    { — 热路径：循环/SIMD 体外联禁 inline，薄转发与小访问器可 inline；Move 单源 bytes.ops — }
    function ByteAt(AOfs: SizeUInt): Byte;
    { — 零拷贝视图：字段切片不分配，按需 SpanToString 单次 Move（bytes.ops 单源）— }
    function FieldSlice(AOfs, ALen: SizeUInt): TByteSpan;
    function TrimmedSlice(ABase: PByte; ALen: SizeUInt): TByteSpan;
    function StringField(AOfs, ALen: SizeUInt): string; inline;
    function NumericField(AOfs, ALen: SizeUInt): Int64;
    function MagicHasUStar: Boolean; inline;
    procedure VerifyChecksum;
    function HeaderIsZeroOrValid(APos: SizeUInt): Boolean;
    { — pax/扩展：零拷贝 slice 解析，消除每记录 Copy+BytesToText 分配 — }
    function ParsePaxRecordsSlice(ABase: PByte; ALen: SizeUInt): Boolean;
    function ParsePaxRecords(const AData: TBytes): Boolean;
    { — 扩展载荷：去重 GNU L/K 与 pax 三分支的单源拷贝 — }
    function GetExtendedPayload(ASize: Int64; out APtr: PByte; out ALen: SizeUInt): Boolean;
    function SliceToString(ABase: PByte; ALen: SizeUInt): string; inline;
    { — 合并：prefix/name 单次SetLength+两Move零拷贝（bytes.ops单源Move语义），禁inline避免Result[1]双喂膨胀 — }
    function CombinePrefixName(const APrefix, AName: TByteSpan): string;
    { — 非热点字段缓存：零拷贝 slice + MemEqual 复用已分配串，万级遍历降分配；inline 薄转发 — }
    function CachedField(AOfs, ALen: SizeUInt; var ACached: string): string; inline;
    { — 全局 pax 清理：消费后单次清除，防恶意 g 记录污染后续条目 — }
    procedure ClearGlobalPax; inline;
  public
    constructor Create(const AData: TBytes); overload;
    constructor Create(AData: PByte; ACount: SizeUInt); overload;
    constructor CreateWithOptions(const AData: TBytes; const AOptions: TTarReadOptions); overload;
    constructor CreateWithOptions(AData: PByte; ACount: SizeUInt; const AOptions: TTarReadOptions); overload;
    function Next(out AHeader: TTarHeader): Boolean;
    function EntryData: TBytes;
    function EntryDataOfs: SizeUInt;
    { 零拷贝视图：返回当前条目载荷在原镜像中的区间（未拷贝） }
    function EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
    { 拉式零拷贝流：基于切片的 IReader（随 reader 生命周期，不拥有镜像）}
    function OpenEntryStream: IReader;
    function EntrySize: Int64; inline;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.exception,
  nextpas.core.simd,
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
  if AOptions.MaxEntrySize = 0 then
    FMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    FMaxEntry := AOptions.MaxEntrySize;
  FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
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
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (field %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  // 单源：复用 bytes.ops SpanIndexOf → simd MemFindByte，零拷贝 NUL 截断，512 热路径单遍 SIMD
  LSpan := TByteSpan.Create(@FData[AOfs], ALen);
  LIdx := SpanIndexOf(LSpan, 0);
  if LIdx < 0 then
    LLen := ALen
  else
    LLen := SizeUInt(LIdx);
  if LLen = 0 then
    Exit(TByteSpan.Empty);
  // 零拷贝视图：不分配，生命周期绑 FData
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
  // 零拷贝视图：去尾零后视图（循环体外联，禁 inline 避免 I-Cache 复制膨胀）
  Result := TByteSpan.Create(ABase, Trim);
end;

function TTarReader.StringField(AOfs, ALen: SizeUInt): string; inline;
var
  LSpan: TByteSpan;
begin
  // 按需物化：FieldSlice 零拷贝 + bytes.ops SpanToString 单次 Move（inline 薄转发）
  LSpan := FieldSlice(AOfs, ALen);
  if LSpan.Len = 0 then
    Exit('');
  Result := SpanToString(LSpan);
end;

function TTarReader.NumericField(AOfs, ALen: SizeUInt): Int64;
begin
  if AOfs + ALen > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (numeric %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  // 单点：八进制/base-256 双路径解析委托 common，inline 零拷贝 PByte 切片
  Result := TarParseNumericField(@FData[AOfs], ALen, AOfs);
end;

function TTarReader.MagicHasUStar: Boolean; inline;
begin
  Result := (FPos + C_TAR_OFF_MAGIC + 5 < FCount)
    and (FData[FPos + C_TAR_OFF_MAGIC] = Ord('u'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 1] = Ord('s'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 2] = Ord('t'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 3] = Ord('a'))
    and (FData[FPos + C_TAR_OFF_MAGIC + 4] = Ord('r'));
end;

procedure TTarReader.VerifyChecksum;
begin
  // 单点：校验和验证委托 common，单遍 512 零拷贝 inline，双算 unsigned/signed
  if FPos + CBlockSize > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (need %d, have %d)', [FPos, CBlockSize, FCount - FPos]);
  TarVerifyBlockChecksum(@FData[FPos], FPos);
end;

{ — 融合零块检测与校验和：单遍 512 扫描消除双遍遍历，单点 common — }
function TTarReader.HeaderIsZeroOrValid(APos: SizeUInt): Boolean;
begin
  if APos + CBlockSize > FCount then
    Exit(False);
  // 单点：零块与校验和融合验证委托 common，零拷贝 inline 单遍
  Result := TarHeaderIsZeroOrValid(@FData[APos], APos);
end;

function TTarReader.SliceToString(ABase: PByte; ALen: SizeUInt): string; inline;
var
  LSpan: TByteSpan;
begin
  // 按需物化：TrimmedSlice 零拷贝 + bytes.ops SpanToString 单次 Move（inline 薄转发）
  LSpan := TrimmedSlice(ABase, ALen);
  if LSpan.Len = 0 then
    Exit('');
  Result := SpanToString(LSpan);
end;

function TTarReader.CombinePrefixName(const APrefix, AName: TByteSpan): string;
var
  LTotal: SizeUInt;
begin
  if APrefix.Len = 0 then
  begin
    if AName.Len = 0 then Exit('');
    Exit(SpanToString(AName));
  end;
  if AName.Len = 0 then
    Exit(SpanToString(APrefix));
  // 单源/零拷贝：单次 SetLength + 两次 Move（APrefix + '/' + AName），消除 SpanConcatMany(TBytes分配+Move)+BytesToString(二次分配)双分配；外联禁inline避免Result[1]双喂膨胀，复用bytes.ops单源Move语义
  LTotal := APrefix.Len + 1 + AName.Len;
  SetLength(Result, LTotal);
  if APrefix.Len > 0 then
    Move(APrefix.Data^, Result[1], APrefix.Len);
  Result[APrefix.Len + 1] := '/';
  if AName.Len > 0 then
    Move(AName.Data^, Result[APrefix.Len + 2], AName.Len);
end;

function TTarReader.CachedField(AOfs, ALen: SizeUInt; var ACached: string): string; inline;
var
  LSpan: TByteSpan;
  LCachedLen: SizeUInt;
begin
  // 零拷贝快路径：命中则免FieldSlice的SpanIndexOf/SIMD扫描（ALen非512全块）；万级小文件UName/GName/LinkName常重复，降1次扫描+1次SpanToString分配/条（inline薄转发，bytes.ops/MemEqual单源，零拷贝视图）
  LCachedLen := SizeUInt(Length(ACached));
  if (LCachedLen > 0) and (LCachedLen <= ALen) and MemEqual(@ACached[1], @FData[AOfs], LCachedLen) then
    if (LCachedLen = ALen) or (FData[AOfs + LCachedLen] = 0) then
      Exit(ACached);
  // 零拷贝视图后按需物化：FieldSlice已用bytes.ops单源（仅扫描ALen非512）；空则零分配，重复值经MemEqual(SIMD单源)复用缓存串（inline热路径）
  LSpan := FieldSlice(AOfs, ALen);
  if LSpan.Len = 0 then
    Exit('');
  if (LCachedLen = LSpan.Len) and MemEqual(@ACached[1], LSpan.Data, LSpan.Len) then
    Exit(ACached);
  Result := SpanToString(LSpan);
  ACached := Result;
end;

procedure TTarReader.ClearGlobalPax; inline;
begin
  // 消费后清理：g 记录为全局但 path/linkpath 若持续继承则恶意档案可污染后续所有正常条目；单次消费后清零，fail-closed；如需多条目全局语义由调用方显式重建
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
      Exit(False);
    Size := NumericField(FPos + C_TAR_OFF_SIZE, C_TAR_LEN_SIZE);
    if Size < 0 then
      raise EIOError.CreateFmt('tar: negative entry size %d at offset %d', [Size, FPos]);
    Flag := ByteAt(FPos + C_TAR_OFF_TYPEFLAG);
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
      // 零拷贝按需物化：长名/pax 优先生效时跳过 Name/Prefix 的 SpanToString 分配，万级小文件遍历降 2 次分配
      if FPendingLongName <> '' then
        AHeader.Name := FPendingLongName
      else if FPaxPath <> '' then
        AHeader.Name := FPaxPath
      else if FGlobalPaxPath <> '' then
        AHeader.Name := FGlobalPaxPath
      else
      begin
        // 零拷贝切片后单次分配；prefix+name 合并一次 Move（原 2 次 SpanToString + 1 次 concat → 1 次）
        if MagicHasUStar then
        begin
          LNameSpan := FieldSlice(FPos + C_TAR_OFF_NAME, C_TAR_LEN_NAME);
          LPrefixSpan := FieldSlice(FPos + C_TAR_OFF_PREFIX, C_TAR_LEN_PREFIX);
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
          AHeader.Name := StringField(FPos + C_TAR_OFF_NAME, C_TAR_LEN_NAME);
      end;
      // LinkName 按需物化：长链优先生效时跳过字段分配；非热点缓存降分配
      if FPendingLongLink <> '' then
        AHeader.LinkName := FPendingLongLink
      else if FPaxLinkPath <> '' then
        AHeader.LinkName := FPaxLinkPath
      else if FGlobalPaxLinkPath <> '' then
        AHeader.LinkName := FGlobalPaxLinkPath
      else
        AHeader.LinkName := CachedField(FPos + C_TAR_OFF_LINKNAME, C_TAR_LEN_LINKNAME, FLastLinkName);
      AHeader.Kind := TypeFlagToKind(Flag);
      AHeader.Mode := Cardinal(NumericField(FPos + C_TAR_OFF_MODE, C_TAR_LEN_MODE)) and $FFFF;
      AHeader.UID := Cardinal(NumericField(FPos + C_TAR_OFF_UID, C_TAR_LEN_UID));
      AHeader.GID := Cardinal(NumericField(FPos + C_TAR_OFF_GID, C_TAR_LEN_GID));
      if AHeader.Kind = tekDirectory then
        AHeader.Size := 0
      else
        AHeader.Size := Size;
      AHeader.MTimeUnix := NumericField(FPos + C_TAR_OFF_MTIME, C_TAR_LEN_MTIME);
      AHeader.UName := CachedField(FPos + C_TAR_OFF_UNAME, C_TAR_LEN_UNAME, FLastUName);
      AHeader.GName := CachedField(FPos + C_TAR_OFF_GNAME, C_TAR_LEN_GNAME, FLastGName);
      // 全局 pax 单次消费清理：防恶意 g 记录污染后续条目（per-entry 优于 global，消费后清零 fail-closed）
      if (FGlobalPaxPath <> '') and (FPendingLongName = '') and (FPaxPath = '') and (AHeader.Name = FGlobalPaxPath) then
        FGlobalPaxPath := '';
      if (FGlobalPaxLinkPath <> '') and (FPendingLongLink = '') and (FPaxLinkPath = '') and (AHeader.LinkName = FGlobalPaxLinkPath) then
        FGlobalPaxLinkPath := '';
      { bomb 守卫：单条目与总量单点 }
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
  N: SizeInt;
begin
  Result := nil;
  if (FEntryDataOfs = 0) or (FEntrySize <= 0) then
    Exit;
  if FEntryDataOfs + SizeUInt(FEntrySize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, FEntrySize, Int64(FCount) - Int64(FEntryDataOfs)]);
  if UInt64(FEntrySize) > UInt64(FMaxEntry) then
    raise EIOError.CreateFmt('tar: entry size %d exceeds limit %d at offset %d', [FEntrySize, Int64(FMaxEntry), FEntryDataOfs]);
  N := SizeInt(FEntrySize);
  // 单源：bytes.ops SpanClone 单次 Move 审计入口，替代手写 Move
  Result := SpanClone(TByteSpan.Create(@FData[FEntryDataOfs], SizeUInt(N)));
end;

function TTarReader.EntryDataOfs: SizeUInt;
begin
  Result := FEntryDataOfs;
end;

function TTarReader.EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
begin
  if (FEntryDataOfs = 0) or (FEntrySize <= 0) then
  begin
    AData := nil;
    ACount := 0;
    Exit(False);
  end;
  if FEntryDataOfs + SizeUInt(FEntrySize) > FCount then
    raise EIOError.CreateFmt('tar: truncated entry data at offset %d (need %d, have %d)', [FEntryDataOfs, FEntrySize, Int64(FCount) - Int64(FEntryDataOfs)]);
  AData := @FData[FEntryDataOfs];
  ACount := SizeUInt(FEntrySize);
  Result := True;
end;

{ — TTarSliceReader：零拷贝切片的拉式 IReader（职责解耦：流不与块解析混杂） — }
type
  TTarSliceReader = class(TInterfacedObject, IReader)
  private
    FBase: PByte;
    FSize: SizeUInt;
    FPos: SizeUInt;
  public
    constructor Create(ABase: PByte; ASize: SizeUInt);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

constructor TTarSliceReader.Create(ABase: PByte; ASize: SizeUInt);
begin
  inherited Create;
  FBase := ABase;
  FSize := ASize;
  FPos := 0;
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
    // 单源：base.utils.CopyMem 为 raw Move 唯一审计入口（常量时间、nil 守卫、零拷贝视图）
    CopyMem(@ABuf, @FBase[FPos], LCount);
    Inc(FPos, LCount);
  end;
  Result := LCount;
end;

function TTarReader.OpenEntryStream: IReader;
var
  P: PByte;
  C: SizeUInt;
begin
  if not EntryDataSlice(P, C) then
  begin
    P := nil;
    C := 0;
  end;
  Result := TTarSliceReader.Create(P, C);
end;

function TTarReader.EntrySize: Int64;
begin
  Result := FEntrySize;
end;

end.

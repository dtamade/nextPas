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
    FHeaderCachePos: SizeUInt;
    FHeaderCacheValid: Boolean;
    FHeaderNulNext: array[0..511] of SizeUInt;
    procedure EnsureHeaderNulCache;
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
    { — 非热点字段缓存：零拷贝 slice + MemEqual 复用已分配串，万级遍历降分配；外联禁 inline（@ACached[1] 喂 CompareMem/MemEqual 违反 design-conventions 红线1，FPC 3.3.1 常量传播拷栈垃圾）— }
    function CachedField(AOfs, ALen: SizeUInt; var ACached: string): string;
    { — 全局 pax 清理：消费后单次清除，防恶意 g 记录污染后续条目 — }
    procedure ClearGlobalPax; inline;
  public
    constructor Create(const AData: TBytes); overload;
    constructor Create(AData: PByte; ACount: SizeUInt); overload;
    constructor CreateWithOptions(const AData: TBytes; const AOptions: TTarReadOptions); overload;
    constructor CreateWithOptions(AData: PByte; ACount: SizeUInt; const AOptions: TTarReadOptions); overload;
    function Next(out AHeader: TTarHeader): Boolean;
    { 拷贝分流：单次 SetLength+Move（bytes.ops SpanClone 单源），峰值 2× TrySlice/切片视图；热路径/大载荷必须优先 TrySlice/EntryDataSlice/OpenEntryStream 零拷贝（extract-all 320µs vs extract-slice 236µs，约 -26%）— 显式 TrySlice(TByteSpan) 引导避免误用拷贝 }
    function EntryData: TBytes;
    function EntryDataOfs: SizeUInt;
    { 零拷贝视图：返回当前条目载荷在原镜像中的区间（未拷贝，生命周期默认绑定 Reader） }
    function EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
    { 显式零拷贝分流：TrySlice 为单一规范入口，返回 TByteSpan 视图（零拷贝/零分配，inline 薄转发，生命周期绑 Reader）；热路径/大载荷优先于 EntryData（EntryData 峰值 2× 切片），失败返 False 不抛（空条目或未 Next），成功得切片后按需 SpanClone 单次 Move（bytes.ops 单源） }
    function TrySlice(out ASlice: TByteSpan): Boolean; inline;
    function TryEntryDataSlice(out ASlice: TByteSpan): Boolean; inline; deprecated 'Use TrySlice';
    { 拉式零拷贝流：基于切片的 IReader；若 Reader 拥有 TBytes 镜像则流持有镜像拷贝（所有权转移防悬垂），外部 PByte 镜像则流固化拷贝自包含；Reader 释放后流仍可读 }
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
  FHeaderCacheValid := False;
  FHeaderCachePos := 0;
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
  FHeaderCacheValid := False;
  FHeaderCachePos := 0;
  if AOptions.MaxEntrySize = 0 then
    FMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    FMaxEntry := AOptions.MaxEntrySize;
  FMaxTotal := AOptions.MaxTotalSize;
  FCumTotal := 0;
end;

procedure TTarReader.EnsureHeaderNulCache;
var
  I: SizeInt;
begin
  // 块级 NUL 索引：单次 512 逆向扫描构建 next-NUL 表，5 字段 O(1) 查表，消除 5 次 SpanIndexOf/SIMD 扫描，万级小文件遍历降开销；外联禁 inline 避免循环体 I-Cache 膨胀
  if FHeaderCacheValid and (FHeaderCachePos = FPos) then
    Exit;
  if FPos + CBlockSize > FCount then
    Exit;
  for I := CBlockSize - 1 downto 0 do
  begin
    if FData[FPos + SizeUInt(I)] = 0 then
      FHeaderNulNext[I] := SizeUInt(I)
    else if I + 1 < CBlockSize then
      FHeaderNulNext[I] := FHeaderNulNext[I + 1]
    else
      FHeaderNulNext[I] := CBlockSize;
  end;
  FHeaderCachePos := FPos;
  FHeaderCacheValid := True;
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
  BlockOff: SizeUInt;
  FirstNul: SizeUInt;
  LIdx: SizeInt;
  LSpan: TByteSpan;
begin
  EndOfs := AOfs + ALen;
  if EndOfs > FCount then
    raise EIOError.CreateFmt('tar: truncated stream at offset %d (field %d+%d > %d)', [AOfs, AOfs, ALen, FCount]);
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  // 块级 NUL 索引复用：命中头部块则 O(1) 查表，单次 512 扫描摊薄 5 次 SpanIndexOf/SIMD（512 热路径单遍，外联循环禁 inline），万级小文件遍历降 4 次扫描开销，零拷贝视图不分配
  if (AOfs >= FPos) and (AOfs < FPos + CBlockSize) and (EndOfs <= FPos + CBlockSize) then
  begin
    EnsureHeaderNulCache;
    BlockOff := AOfs - FPos;
    FirstNul := FHeaderNulNext[BlockOff];
    if FirstNul >= CBlockSize then
      LLen := ALen
    else if FirstNul - BlockOff >= ALen then
      LLen := ALen
    else
      LLen := FirstNul - BlockOff;
    if LLen = 0 then
      Exit(TByteSpan.Empty);
    Result := TByteSpan.Create(@FData[AOfs], LLen);
    Exit;
  end;
  // 非头块回退：单次 SpanIndexOf → simd MemFindByte（bytes.ops 单源），零拷贝 NUL 截断
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
begin
  // 单源：复用 bytes.ops SpanJoinWithSeparator 单次 SetLength + 两 CopyMemory（bytes.ops 单源 Move），与 archive.fs ArchiveJoinPath 同构收敛至同一 helper，零拷贝 PByte 视图单源，外联禁 inline 避免 Result[1] 双喂膨胀
  Result := SpanJoinWithSeparator(APrefix, AName, '/');
end;

function TTarReader.CachedField(AOfs, ALen: SizeUInt; var ACached: string): string;
var
  LSpan: TByteSpan;
  LCachedLen: SizeUInt;
begin
  // 零拷贝快路径：命中则免FieldSlice的SpanIndexOf/SIMD扫描（ALen非512全块）；万级小文件UName/GName/LinkName常重复，降1次扫描+1次SpanToString分配/条（外联禁 inline：@ACached[1] 喂 MemEqual 为 design-conventions 红线1，FPC 3.3.1 常量传播下 inline 拷栈垃圾，改 PAnsiChar 单源规避；bytes.ops/MemEqual 单源，零拷贝视图）
  LCachedLen := SizeUInt(Length(ACached));
  if (LCachedLen > 0) and (LCachedLen <= ALen) and MemEqual(Pointer(PAnsiChar(ACached)), @FData[AOfs], LCachedLen) then
    if (LCachedLen = ALen) or (FData[AOfs + LCachedLen] = 0) then
      Exit(ACached);
  // 零拷贝视图后按需物化：FieldSlice已用bytes.ops单源（仅扫描ALen非512）；空则零分配，重复值经MemEqual(SIMD单源)复用缓存串（外联，零拷贝视图）
  LSpan := FieldSlice(AOfs, ALen);
  if LSpan.Len = 0 then
    Exit('');
  if (LCachedLen = LSpan.Len) and MemEqual(Pointer(PAnsiChar(ACached)), LSpan.Data, LSpan.Len) then
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
  LS: TByteSpan;
begin
  Result := nil;
  if not TrySlice(LS) then
    Exit;
  if UInt64(LS.Len) > UInt64(FMaxEntry) then
    raise EIOError.CreateFmt('tar: entry size %d exceeds limit %d at offset %d', [Int64(LS.Len), Int64(FMaxEntry), FEntryDataOfs]);
  // 单源：bytes.ops SpanClone 单次 Move 审计入口；显式经 TrySlice 零拷贝视图分流—拷贝仅按需，峰值 2× 切片（LS 无分配），热路径优先 TrySlice/OpenEntryStream；inline/零拷贝证据见 TrySlice
  Result := SpanClone(LS);
end;

function TTarReader.EntryDataOfs: SizeUInt;
begin
  Result := FEntryDataOfs;
end;

function TTarReader.TrySlice(out ASlice: TByteSpan): Boolean; inline;
begin
  // 显式零拷贝分流：TrySlice 单源 TByteSpan 视图（零拷贝/零分配，生命周期绑 Reader），失败返 False 不抛（空条目/未 Next），截断抛 EIOError；inline 薄转发供 EntryDataSlice/EntryData 复用，峰值对比 2× 证据见 EntryData
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

function TTarReader.TryEntryDataSlice(out ASlice: TByteSpan): Boolean; inline;
begin
  // 收敛别名：已 deprecated，单一规范入口为 TrySlice，保留薄转发兼容旧调用，inline 零拷贝单源
  Result := TrySlice(ASlice);
end;

function TTarReader.EntryDataSlice(out AData: PByte; out ACount: SizeUInt): Boolean;
var
  LS: TByteSpan;
begin
  // 薄转发：复用 TrySlice 单源 TByteSpan 视图，避免 PByte/Count 分流重复分支与截断校验分叉
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

{ — TTarSliceReader：零拷贝切片的拉式 IReader（职责解耦：流不与块解析混杂；单源 bytes.ops CopyMemory + 所有权守卫） — }
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
    // 单源：bytes.ops.CopyMemory 为 raw Move 唯一审计入口（常量时间、nil 守卫、零拷贝视图），收敛 base.utils.CopyMem 分散
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
  // 所有权守卫：Reader 拥有 TBytes 镜像则流持有镜像引用（防 Reader 释放后悬垂）；外部 PByte 镜像无拥有则流拷贝固化实现自包含，空载荷走借用空视图
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

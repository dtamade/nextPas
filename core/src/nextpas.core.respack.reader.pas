unit nextpas.core.respack.reader;

{** @desc respack 解析器：八步校验清单 + 索引二分查找。
  校验步骤号对应 FORMAT.md「Reader 校验清单」；不变量见 CONTRACT INV-R2/R3/R4/R7。
  string table 边界为推导值：基址 = IndexOffset+Count×40，上界 = min(DataOffset)。
  零拷贝视图：FData/FDigests 为外部 blob 零拷贝指针，不拥有所有权；
  调用方须保证 blob 生命期覆盖 TResPack (至 Close)，堆场景以 TBytes 持有或转交
  vfs.embedded AOwnsBlob，见 CONTRACT §5；提前释放导致悬垂访问属调用方违规。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.bytes.ops;

type
  { 零拷贝只读视图：FData 为外部 blob 零拷贝指针（非拥有），调用方保活至 Close；
    悬垂防护见 CONTRACT §5。 }
  TResPack = record
  private
    FData: PByte;
    FSize: SizeUInt;
    FOpen: Boolean;
    FHdr: TResPackHeader;
    FStrTabBase: UInt64;
    FDigests: PByte;

    function GetCount: SizeUInt; inline;
    { 40 字节 index 项 → host-order TResPackEntry。
      不用无类型参数 + absolute 叠加：FPC trunk 对该组合生成错误代码（实测）。 }
    procedure DecodeWire(const AIdx: SizeUInt; out ADest: TResPackEntry);
    function CompareStoredToBuf(const AIdx: SizeUInt;
      const ABuf: PByte; const ALen: SizeUInt): Integer;
    function CompareStoredToStored(const AA, AB: SizeUInt): Integer;
    function CompareCachedEntries(const AA, AB: TResPackEntry): Integer;
    function Search(const APath: string; out AIdx: SizeUInt): Boolean;
    { 零拷贝视图单源 helper：LE 解码已在上层完成，此处仅做 PByte+Len 零拷贝构造；
      StoredPathSpan/StoredPathSpanOf 唯一收敛点，inline 零分配，复用 bytes.ops 单源。 }
    function PathSpanRaw(const AOff: UInt32; const ALen: Word): TByteSpan; inline;

  public
    { 八步校验后可用；任一失败 raise EResPackCorrupted }
    class function Open(const AData: PByte; const ASize: SizeUInt): TResPack; static;
    procedure Close;

    { 探测式查找：未命中 False；命中时 Result.Path 构造一次 }
    function Find(const APath: string; out AEntry: TResPackEntry): Boolean;
    { 断言式查找：未命中 raise EResPackNotFound }
    function Stat(const APath: string): TResPackEntry;

    function EntryAt(const AIdx: SizeUInt): TResPackEntry;
    function PathOf(const AEntry: TResPackEntry): string; inline;
    function StoredPathSpanOf(const AEntry: TResPackEntry): TByteSpan; inline;

    property Count: SizeUInt read GetCount;
    property Header: TResPackHeader read FHdr;
    property Data: PByte read FData;
    function ContentPtr(const AEntry: TResPackEntry): PByte; inline;
    function DigestPtr(const AIdx: SizeUInt): PByte;
    function HasDigests: Boolean; inline;
    { 零拷贝路径视图单源：TByteSpan 唯一视图（PByte+Len 零拷贝），复用 bytes.ops.SpanCompare/SpanToString 单源；
      二分缓存查询视图，单次 LE 解码+视图构造（StoredPathSpan 单源 DRY via PathSpanRaw），inline 零拷贝零分配；供 embedded 零分配二分/前缀复用
      LowerBound 含 while 二分循环，守 design-conventions 红线 2 禁 inline，避 I-Cache 复制膨胀 }
    function StoredPathSpan(const AIdx: SizeUInt): TByteSpan; inline;
    function LowerBound(const APath: string): SizeUInt;
    function ComparePathAt(const AIdx: SizeUInt; const APath: string): Integer;
  end;

implementation

uses
  nextpas.core.collections.algorithms;

type
  TResPackEntryArr = array[0..(High(SizeInt) div SizeOf(TResPackEntry)) - 1] of TResPackEntry;
  PResPackEntryArr = ^TResPackEntryArr;

type
  TIdxSortCtx = record
    Entries: PResPackEntryArr;
  end;
  PIdxSortCtx = ^TIdxSortCtx;

function CompareIdxByOffset(const A, B: SizeUInt; Data: Pointer): SizeInt;
var
  Ctx: PIdxSortCtx;
  EA, EB: TResPackEntry;
begin
  Ctx := PIdxSortCtx(Data);
  EA := Ctx^.Entries^[A];
  EB := Ctx^.Entries^[B];
  if EA.DataOffset < EB.DataOffset then Exit(-1);
  if EA.DataOffset > EB.DataOffset then Exit(1);
  if EA.Size < EB.Size then Exit(-1);
  if EA.Size > EB.Size then Exit(1);
  Result := 0;
end;

procedure SortIdxByOffset(var AIdx: array of SizeUInt; const AEntries: array of TResPackEntry);
var
  Ctx: TIdxSortCtx;
begin
  if Length(AIdx) <= 1 then Exit;
  if Length(AEntries) = 0 then Exit;
  Ctx.Entries := PResPackEntryArr(@AEntries[0]);
  specialize Sort<SizeUInt>(AIdx, @CompareIdxByOffset, @Ctx);
end;

function TResPack.GetCount: SizeUInt;
begin
  Result := SizeUInt(FHdr.EntryCount);
end;

function TResPack.HasDigests: Boolean;
begin
  Result := FDigests <> nil;
end;

function TResPack.ContentPtr(const AEntry: TResPackEntry): PByte;
begin
  Result := FData + SizeUInt(AEntry.DataOffset);
end;

function TResPack.DigestPtr(const AIdx: SizeUInt): PByte;
begin
  if FDigests = nil then
    raise EResPackCorrupted.CreateCtx('digest', '', 'respack: pack has no digest section');
  Result := FDigests + AIdx * RESPACK_DIGEST_SIZE;
end;

procedure TResPack.DecodeWire(const AIdx: SizeUInt; out ADest: TResPackEntry);
var
  P: PByte;
begin
  P := FData + SizeUInt(FHdr.IndexOffset) + AIdx * RESPACK_ENTRY_SIZE;
  ADest.PathOffset := RdU32LE(P);
  ADest.PathLen := RdU16LE(P + 4);
  ADest.Flags := RdU16LE(P + 6);
  ADest.DataOffset := RdU64LE(P + 8);
  ADest.Size := RdU64LE(P + 16);
  ADest.ModTime := Int64(RdU64LE(P + 24));
  ADest.Hash := RdU32LE(P + 32);
  ADest.CodecId := P[36];
end;

function TResPack.PathSpanRaw(const AOff: UInt32; const ALen: Word): TByteSpan; inline;
begin
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  Result := TByteSpan.Create(FData + SizeUInt(FStrTabBase) + SizeUInt(AOff), SizeUInt(ALen));
end;

function TResPack.StoredPathSpan(const AIdx: SizeUInt): TByteSpan; inline;
var
  Base: PByte;
begin
  Base := FData + SizeUInt(FHdr.IndexOffset) + AIdx * RESPACK_ENTRY_SIZE;
  Result := PathSpanRaw(RdU32LE(Base), RdU16LE(Base + 4));
end;

function TResPack.StoredPathSpanOf(const AEntry: TResPackEntry): TByteSpan; inline;
begin
  Result := PathSpanRaw(AEntry.PathOffset, AEntry.PathLen);
end;

function TResPack.CompareStoredToBuf(const AIdx: SizeUInt;
  const ABuf: PByte; const ALen: SizeUInt): Integer; inline;
var
  S: TByteSpan;
begin
  S := StoredPathSpan(AIdx);
  Result := SpanCompare(S, TByteSpan.Create(ABuf, ALen));
end;

function TResPack.CompareStoredToStored(const AA, AB: SizeUInt): Integer; inline;
var
  SA, SB: TByteSpan;
begin
  SA := StoredPathSpan(AA);
  SB := StoredPathSpan(AB);
  Result := SpanCompare(SA, SB);
end;

function TResPack.CompareCachedEntries(const AA, AB: TResPackEntry): Integer; inline;
var
  SA, SB: TByteSpan;
begin
  SA := StoredPathSpanOf(AA);
  SB := StoredPathSpanOf(AB);
  Result := SpanCompare(SA, SB);
end;

class function TResPack.Open(const AData: PByte; const ASize: SizeUInt): TResPack;
var
  I: SizeUInt;
  E: TResPackEntry;
  MinData, MaxDataEnd, StrTabEnd, DigEnd, StrLen, AlignedStrEnd, PathEnd: UInt64;
  HdrFlags: UInt32;
  IdxBase: PByte;
  Cached: array of TResPackEntry;
  SortedIdx: array of SizeUInt;

begin
  Result.Close;

  { 步骤 1：长度与 magic }
  if (AData = nil) or (ASize < RESPACK_HEADER_SIZE) then
    raise EResPackCorrupted.CreateStep(1, 'buffer smaller than header');
  if (AData[0] <> Byte(AnsiChar('N'))) or (AData[1] <> Byte(AnsiChar('P')))
    or (AData[2] <> Byte(AnsiChar('R'))) or (AData[3] <> Byte(AnsiChar('S'))) then
    raise EResPackCorrupted.CreateStep(1, 'bad magic');

  { 步骤 2：版本与 header flags }
  Result.FHdr.Version := RdU32LE(AData + 4);
  if Result.FHdr.Version <> RESPACK_VERSION then
    raise EResPackCorrupted.CreateStep(2, 'unsupported version');
  HdrFlags := RdU32LE(AData + 8);
  if (HdrFlags and not UInt32(RESPACK_FLAG_KNOWN)) <> 0 then
    raise EResPackCorrupted.CreateStep(2, 'unknown header flags');
  Result.FHdr.Flags := HdrFlags;
  Result.FHdr.EntryCount := RdU32LE(AData + 12);
  Result.FHdr.IndexOffset := RdU64LE(AData + 16);
  Result.FHdr.DigestOffset := RdU64LE(AData + 24);
  Result.FHdr.BlobTotal := RdU64LE(AData + 32);
  if ((HdrFlags and RESPACK_FLAG_DIGESTED) <> 0)
    and (Result.FHdr.DigestOffset = 0) then
    raise EResPackCorrupted.CreateStep(2, 'digest flag set but offset zero');
  if ((HdrFlags and RESPACK_FLAG_ALGO_MASK) shr RESPACK_FLAG_ALGO_SHIFT)
    <> UInt32(RESPACK_DIGEST_ALGO_SHA256) then
    raise EResPackCorrupted.CreateStep(2, 'unknown digest algorithm');

  { 步骤 3：index 范围（v1 恒 40，无间隙；u32×40 在 u64 内无溢出） }
  if (Result.FHdr.IndexOffset <> RESPACK_HEADER_SIZE)
    or (Result.FHdr.IndexOffset
      + UInt64(Result.FHdr.EntryCount) * RESPACK_ENTRY_SIZE
      > Result.FHdr.BlobTotal) then
    raise EResPackCorrupted.CreateStep(3, 'index out of range');
  { INV-R10 熔断：entryCount 硬上界，防恶意包 SetLength OOM（复用 RESPACK_MAX_ENTRY_COUNT 单源，对齐防御深度） }
  if UInt64(Result.FHdr.EntryCount) > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackCorrupted.CreateStep(3, 'entry count exceeds limit');

  { 步骤 4：缓冲覆盖 blobTotal（允许尾部多余字节） }
  if ASize < Result.FHdr.BlobTotal then
    raise EResPackCorrupted.CreateStep(4, 'buffer truncated versus blobTotal');

  { FData 必须在步骤 5 前就位：后续 DecodeWire/StoredPathSpan 全部经由 Self.FData 寻址
    零拷贝不拥有：FData 仅为外部 blob 视图，调用方须保活至 Close（见 CONTRACT §5）。 }
  Result.FData := AData;
  Result.FSize := ASize;

  Result.FStrTabBase := Result.FHdr.IndexOffset
    + UInt64(Result.FHdr.EntryCount) * RESPACK_ENTRY_SIZE;
  IdxBase := AData + SizeUInt(Result.FHdr.IndexOffset);

  { 步骤 5：entry 结构、codec、data 对齐与范围；同时推导 strtab 上界
    （Count 为 SizeUInt，0-1 回绕 ⇒ 每个循环都必须以 Count>0 为前提）
    单次 DecodeWire + 缓存：第二遍校验复用缓存零 Decode，10k 规模省 50% 解析 }
  MinData := Result.FHdr.BlobTotal;
  MaxDataEnd := 0;
  StrLen := 0;
  Cached := nil;
  SortedIdx := nil;
  try
    if Result.Count > 0 then
  begin
    // 熔断已在 Step3 硬上界（RESPACK_MAX_ENTRY_COUNT, INV-R10），此处仍显式校验防 bypass；缓存零二次 DecodeWire，10k 级 <400KB 可控
    if UInt64(Result.Count) > RESPACK_MAX_ENTRY_COUNT then
      raise EResPackCorrupted.CreateStep(3, 'entry count exceeds limit');
    SetLength(Cached, Result.Count);
    for I := 0 to Result.Count - 1 do
    begin
      Result.DecodeWire(I, E);
      if (E.Flags and not Word(RESPACK_EFLAG_KNOWN)) <> 0 then
        raise EResPackCorrupted.CreateStep(5, 'unknown entry flags');
      if (IdxBase[I * RESPACK_ENTRY_SIZE + 37] <> 0)
        or (IdxBase[I * RESPACK_ENTRY_SIZE + 38] <> 0)
        or (IdxBase[I * RESPACK_ENTRY_SIZE + 39] <> 0) then
        raise EResPackCorrupted.CreateStep(5, 'reserved bytes nonzero');
      if E.CodecId <> RESPACK_CODEC_STORE then
        raise EResPackCorrupted.CreateStep(5, 'unknown codecId');
      if E.PathLen = 0 then
        raise EResPackCorrupted.CreateStep(5, 'empty path');
      if (E.DataOffset mod RESPACK_DATA_ALIGN) <> 0 then
        raise EResPackCorrupted.CreateStep(5, 'data slot not aligned');
      { F-HIGH-02 wrap-safe: avoid UInt64 wrap on DataOffset+Size }
      if (E.Size > Result.FHdr.BlobTotal)
        or (E.DataOffset > Result.FHdr.BlobTotal - E.Size) then
        raise EResPackCorrupted.CreateStep(5, 'data range beyond blobTotal');
      if StrLen > High(UInt64) - UInt64(E.PathLen) then
        raise EResPackCorrupted.CreateStep(5, 'string table length overflow');
      StrLen := StrLen + UInt64(E.PathLen);
      if E.DataOffset < MinData then
        MinData := E.DataOffset;
      if E.Size > 0 then
      begin
        if E.DataOffset > High(UInt64) - E.Size then
          raise EResPackCorrupted.CreateStep(5, 'data range overflow');
        if E.DataOffset + E.Size > MaxDataEnd then
          MaxDataEnd := E.DataOffset + E.Size;
      end;
      Cached[I] := E;
    end;
    { F-HIGH-03 header HASHED is summary, entry HASHED is authoritative }
    if (HdrFlags and RESPACK_FLAG_HASHED) <> 0 then
      for I := 0 to Result.Count - 1 do
        if (Cached[I].Flags and RESPACK_EFLAG_HASHED) = 0 then
          raise EResPackCorrupted.CreateStep(5, 'header hash flag inconsistent');
    { 推导 string table 终点：AlignUp(FStrTabBase+StrLen,16) }
    if Result.FStrTabBase > High(UInt64) - StrLen then
      raise EResPackCorrupted.CreateStep(5, 'string table overflow');
    StrTabEnd := Result.FStrTabBase + StrLen;
    if StrTabEnd > High(UInt64) - (RESPACK_DATA_ALIGN - 1) then
      raise EResPackCorrupted.CreateStep(5, 'string table alignment overflow');
    StrTabEnd := (StrTabEnd + (RESPACK_DATA_ALIGN - 1)) and not UInt64(RESPACK_DATA_ALIGN - 1);
    { 消除无符号下溢：MinData < FStrTabBase 必须先于 MinData-FStrTabBase }
    if MinData < Result.FStrTabBase then
      raise EResPackCorrupted.CreateStep(5, 'data overlaps strtab');
    for I := 0 to Result.Count - 1 do
    begin
      E := Cached[I];
      if E.DataOffset < StrTabEnd then
        raise EResPackCorrupted.CreateStep(5, 'data overlaps header/index/strtab');
    end;
    { data 区间互不重叠 — 复用 L1 collections.algorithms.Sort 单源（IntroSort，与 writer.layout 单源收敛）
      索引排序后线性相邻检查替代 O(n²) 双重循环，10k 条目 O(n log n) 排序+单遍扫描，SortedIdx 单缓冲零双份维护 }
    if Result.Count > 1 then
    begin
      SetLength(SortedIdx, Result.Count);
      for I := 0 to Result.Count - 1 do
        SortedIdx[I] := I;
      SortIdxByOffset(SortedIdx, Cached);
      for I := 1 to Result.Count - 1 do
      begin
        if (Cached[SortedIdx[I - 1]].Size = 0) or (Cached[SortedIdx[I]].Size = 0) then Continue;
        if (Cached[SortedIdx[I - 1]].DataOffset = Cached[SortedIdx[I]].DataOffset)
          and (Cached[SortedIdx[I - 1]].Size = Cached[SortedIdx[I]].Size) then Continue;
        if Cached[SortedIdx[I]].DataOffset < Cached[SortedIdx[I - 1]].DataOffset + Cached[SortedIdx[I - 1]].Size then
          raise EResPackCorrupted.CreateStep(5, 'data sections overlap');
      end;
      SetLength(SortedIdx, 0);
    end;
  end
  else
  begin
    StrTabEnd := Result.FStrTabBase;
    MaxDataEnd := 0;
  end;

  { 步骤 6+7：路径范围 + 有序性 + 规范语法 — 复用缓存零 Decode
    （MinData 已在步骤 5 推导完成；步骤 6 优先于 7，错误码保持与分步一致）
    FORMAT step6: FStrTabBase+PathOffset+PathLen <= MinData；推导边界需防 MinData<FStrTabBase 下溢 }
  if Result.Count > 0 then
  begin
    for I := 0 to Result.Count - 1 do
    begin
      E := Cached[I];
      { F-CRIT-01/F-HIGH-02: 路径上界显式用 BlobTotal + CheckedAdd 防回绕 }
      PathEnd := UInt64(E.PathOffset) + UInt64(E.PathLen);
      if PathEnd < UInt64(E.PathOffset) then
        raise EResPackCorrupted.CreateStep(6, 'path range overflow');
      if PathEnd > MinData - Result.FStrTabBase then
        raise EResPackCorrupted.CreateStep(6, 'path beyond string table bound');
      { 显式 BlobTotal 上界（复用 base 溢出思想：BlobTotal - FStrTabBase 安全差值） }
      if PathEnd > Result.FHdr.BlobTotal - Result.FStrTabBase then
        raise EResPackCorrupted.CreateStep(6, 'path beyond blobTotal');
      if I > 0 then
        if Result.CompareCachedEntries(Cached[I - 1], Cached[I]) >= 0 then
          raise EResPackCorrupted.CreateStep(7,
            'index not strictly sorted or duplicate path');
      { 零堆分配校验：TByteSpan 直接零拷贝校验（bytes.pathvalid.BytesValidSpan→UTF8IsValid 单源），
        替代 PathOf→SpanToString 每条目 string 分配，10k 条目 O(n) 堆分配归零，inline 薄转发零额外拷贝 }
      if not ResPackValidSpan(Result.StoredPathSpanOf(E), True) then
        raise EResPackCorrupted.CreateStep(7, 'non-canonical path stored');
    end;
  end;

  { 步骤 8：digest 区范围 — FORMAT step8: digest 必须位于 string table 对齐后且不与数据区间相交 }
  if (Result.FHdr.Flags and RESPACK_FLAG_DIGESTED) <> 0 then
  begin
    { F-CRIT-01: AlignUp(FStrTabBase+StrLen,4) <= DigestOffset }
    if Result.FStrTabBase > High(UInt64) - StrLen then
      raise EResPackCorrupted.CreateStep(8, 'digest string table overflow');
    AlignedStrEnd := Result.FStrTabBase + StrLen;
    if AlignedStrEnd > High(UInt64) - 3 then
      raise EResPackCorrupted.CreateStep(8, 'digest alignment overflow');
    AlignedStrEnd := (AlignedStrEnd + 3) and not UInt64(3);
    if AlignedStrEnd > Result.FHdr.DigestOffset then
      raise EResPackCorrupted.CreateStep(8, 'digest overlaps string table');
    { digest 区尾端： CheckedAdd 思想防回绕，显式 BlobTotal 上界 }
    if UInt64(Result.FHdr.EntryCount) > High(UInt64) div RESPACK_DIGEST_SIZE then
      raise EResPackCorrupted.CreateStep(8, 'digest size overflow');
    DigEnd := Result.FHdr.DigestOffset + UInt64(Result.FHdr.EntryCount) * RESPACK_DIGEST_SIZE;
    if DigEnd < Result.FHdr.DigestOffset then
      raise EResPackCorrupted.CreateStep(8, 'digest range overflow');
    if DigEnd > Result.FHdr.BlobTotal then
      raise EResPackCorrupted.CreateStep(8, 'digest out of range');
    if MaxDataEnd > High(UInt64) - 3 then
      raise EResPackCorrupted.CreateStep(8, 'digest alignment overflow');
    if Result.FHdr.DigestOffset < ((MaxDataEnd + 3) and not UInt64(3)) then
      raise EResPackCorrupted.CreateStep(8, 'digest overlaps data');
    Result.FDigests := AData + SizeUInt(Result.FHdr.DigestOffset);
  end;
  finally
    SetLength(Cached, 0);
    SetLength(SortedIdx, 0);
  end;

  Result.FOpen := True;
end;

procedure TResPack.Close;
begin
  FData := nil;
  FSize := 0;
  FDigests := nil;
  FOpen := False;
  FHdr.EntryCount := 0;
  FHdr.IndexOffset := 0;
  FHdr.DigestOffset := 0;
  FHdr.BlobTotal := 0;
  FHdr.Flags := 0;
  FHdr.Version := 0;
  FStrTabBase := 0;
end;

function TResPack.Search(const APath: string; out AIdx: SizeUInt): Boolean;
var
  Idx: SizeUInt;
begin
  Idx := LowerBound(APath);
  if (Idx < Count) and (ComparePathAt(Idx, APath) = 0) then
  begin
    AIdx := Idx;
    Exit(True);
  end;
  Result := False;
end;

function TResPack.Find(const APath: string; out AEntry: TResPackEntry): Boolean;
var
  Idx: SizeUInt;
begin
  if (not FOpen) or (not ResPackValidPath(APath, True)) then
    Exit(False);
  if not Search(APath, Idx) then
    Exit(False);
  DecodeWire(Idx, AEntry);
  Result := True;
end;

function TResPack.Stat(const APath: string): TResPackEntry;
begin
  if not ResPackValidPath(APath, True) then
    raise EResPackInvalidPath.CreateCtx('stat', APath, 'respack: invalid path "' + APath + '"');
  if not Find(APath, Result) then
    raise EResPackNotFound.CreateCtx('stat', APath, 'respack: path not found "' + APath + '"');
end;

function TResPack.EntryAt(const AIdx: SizeUInt): TResPackEntry;
begin
  if (not FOpen) or (AIdx >= Count) then
    raise EResPackError.CreateCtx('entry', '', 'respack: entry index out of range');
  DecodeWire(AIdx, Result);
end;

function TResPack.PathOf(const AEntry: TResPackEntry): string; inline;
begin
  Result := SpanToString(StoredPathSpanOf(AEntry));
end;

function TResPack.LowerBound(const APath: string): SizeUInt;
var
  Lo, Hi, Mid: SizeUInt;
  C: Integer;
  Query: TByteSpan;
begin
  Lo := 0;
  Hi := Count;
  if Hi = 0 then Exit(0);
  if Length(APath) > 0 then
    Query := TByteSpan.Create(PByte(@APath[1]), SizeUInt(Length(APath)))
  else
    Query := TByteSpan.Empty;
  { 零拷贝单源 DRY：复用 StoredPathSpan 唯一视图（PByte+Len，单次 LE 解码+Span 构造 via PathSpanRaw，零分配），
    复用 bytes.ops.SpanCompare 单源；二分 14 次比较≈14 次视图构造；外联守红线 2（while 二分循环禁 inline，避 I-Cache 膨胀） }
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    C := SpanCompare(StoredPathSpan(Mid), Query);
    if C < 0 then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

function TResPack.ComparePathAt(const AIdx: SizeUInt; const APath: string): Integer;
var
  Query: TByteSpan;
  S: TByteSpan;
begin
  Query := TByteSpan.FromStr(APath);
  S := StoredPathSpan(AIdx);
  Result := SpanCompare(S, Query);
end;

end.

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

type
  TResPackEntries = array of TResPackEntry;

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

{ ── Stage guards: Open 八步校验拆为 guard 函数，单函数 <80 行，阅读质感轻量 ── }

procedure GuardStep1(const AData: PByte; const ASize: SizeUInt); inline;
begin
  if (AData = nil) or (ASize < RESPACK_HEADER_SIZE) then
    raise EResPackCorrupted.CreateStep(1, 'buffer smaller than header');
  if (AData[0] <> Byte(AnsiChar('N'))) or (AData[1] <> Byte(AnsiChar('P')))
    or (AData[2] <> Byte(AnsiChar('R'))) or (AData[3] <> Byte(AnsiChar('S'))) then
    raise EResPackCorrupted.CreateStep(1, 'bad magic');
end;

procedure GuardStep2(const AData: PByte; var AFHdr: TResPackHeader; out AHdrFlags: UInt32); inline;
begin
  AFHdr.Version := RdU32LE(AData + 4);
  if AFHdr.Version <> RESPACK_VERSION then
    raise EResPackCorrupted.CreateStep(2, 'unsupported version');
  AHdrFlags := RdU32LE(AData + 8);
  if (AHdrFlags and not UInt32(RESPACK_FLAG_KNOWN)) <> 0 then
    raise EResPackCorrupted.CreateStep(2, 'unknown header flags');
  AFHdr.Flags := AHdrFlags;
  AFHdr.EntryCount := RdU32LE(AData + 12);
  AFHdr.IndexOffset := RdU64LE(AData + 16);
  AFHdr.DigestOffset := RdU64LE(AData + 24);
  AFHdr.BlobTotal := RdU64LE(AData + 32);
  if ((AHdrFlags and RESPACK_FLAG_DIGESTED) <> 0)
    and (AFHdr.DigestOffset = 0) then
    raise EResPackCorrupted.CreateStep(2, 'digest flag set but offset zero');
  if ((AHdrFlags and RESPACK_FLAG_ALGO_MASK) shr RESPACK_FLAG_ALGO_SHIFT)
    <> UInt32(RESPACK_DIGEST_ALGO_SHA256) then
    raise EResPackCorrupted.CreateStep(2, 'unknown digest algorithm');
end;

procedure GuardStep3(const AFHdr: TResPackHeader); inline;
begin
  if (AFHdr.IndexOffset <> RESPACK_HEADER_SIZE)
    or (AFHdr.IndexOffset
      + UInt64(AFHdr.EntryCount) * RESPACK_ENTRY_SIZE
      > AFHdr.BlobTotal) then
    raise EResPackCorrupted.CreateStep(3, 'index out of range');
  if UInt64(AFHdr.EntryCount) > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackCorrupted.CreateStep(3, 'entry count exceeds limit');
end;

procedure GuardStep4(const ASize: SizeUInt; const AFHdr: TResPackHeader); inline;
begin
  if ASize < AFHdr.BlobTotal then
    raise EResPackCorrupted.CreateStep(4, 'buffer truncated versus blobTotal');
end;

{ O(n) data 区间重叠校验：单遍扫描，零排序，CONTRACT §6 O(n) 兑现。
  writer 布局按 path 排序顺序分配槽位，distinct 区间按首次出现单调递增；
  dedup 共享槽位（同 offset+size）经哈希去重免检，零拷贝 TByteSpan 单源不变。
  10k 条目省 IntroSort O(n log n) 比较与 SortedIdx 分配，单次线性零额外拷贝。 }
procedure CheckDataOverlapON(const ACached: array of TResPackEntry;
  const AStrTabEnd: UInt64);
var
  I: SizeUInt;
  BucketCount: SizeUInt;
  BucketsHead: array of SizeInt;
  SlotNext: array of SizeInt;
  DistinctOff: array of UInt64;
  DistinctSize: array of UInt64;
  DistinctCount: SizeUInt;
  LastEnd: UInt64;
  BucketIdx: SizeUInt;
  Probe: SizeInt;
  IsDup: Boolean;
  E: TResPackEntry;
begin
  if Length(ACached) <= 1 then Exit;
  { 桶容量：2×N 幂次，复用 bytes.ops.BytesNextCapacity 单源，封顶 64K 控 256KB 头 }
  BucketCount := 256;
  if SizeUInt(Length(ACached)) * 2 > BucketCount then
    BucketCount := BytesNextCapacity(BucketCount, SizeUInt(Length(ACached)) * 2);
  if BucketCount > 65536 then BucketCount := 65536;
  SetLength(BucketsHead, BucketCount);
  SetLength(SlotNext, Length(ACached));
  SetLength(DistinctOff, Length(ACached));
  SetLength(DistinctSize, Length(ACached));
  for I := 0 to BucketCount - 1 do BucketsHead[I] := -1;
  for I := 0 to SizeUInt(High(SlotNext)) do SlotNext[I] := -1;
  DistinctCount := 0;
  LastEnd := AStrTabEnd;
  for I := 0 to SizeUInt(High(ACached)) do
  begin
    E := ACached[I];
    if E.Size = 0 then Continue;
    BucketIdx := (SizeUInt(E.DataOffset) xor SizeUInt(E.DataOffset shr 32) xor SizeUInt(E.Size)) and (BucketCount - 1);
    Probe := BucketsHead[BucketIdx];
    IsDup := False;
    while Probe <> -1 do
    begin
      if (DistinctOff[SizeUInt(Probe)] = E.DataOffset) and (DistinctSize[SizeUInt(Probe)] = E.Size) then
      begin IsDup := True; Break; end;
      Probe := SlotNext[SizeUInt(Probe)];
    end;
    if IsDup then Continue;
    if E.DataOffset < LastEnd then
      raise EResPackCorrupted.CreateStep(5, 'data sections overlap');
    DistinctOff[DistinctCount] := E.DataOffset;
    DistinctSize[DistinctCount] := E.Size;
    SlotNext[DistinctCount] := BucketsHead[BucketIdx];
    BucketsHead[BucketIdx] := SizeInt(DistinctCount);
    Inc(DistinctCount);
    LastEnd := E.DataOffset + E.Size;
  end;
end;

procedure GuardStep5Entries(var ARes: TResPack; var ACached: TResPackEntries;
  const AIdxBase: PByte; out AMinData: UInt64; out AMaxDataEnd: UInt64;
  out AStrLen: UInt64; const AHdrFlags: UInt32; out AStrTabEnd: UInt64);
var
  I: SizeUInt;
  E: TResPackEntry;
begin
  AMinData := ARes.FHdr.BlobTotal;
  AMaxDataEnd := 0;
  AStrLen := 0;
  if ARes.Count = 0 then
  begin
    AStrTabEnd := ARes.FStrTabBase;
    Exit;
  end;
  if UInt64(ARes.Count) > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackCorrupted.CreateStep(3, 'entry count exceeds limit');
  SetLength(ACached, ARes.Count);
  for I := 0 to ARes.Count - 1 do
  begin
    ARes.DecodeWire(I, E);
    if (E.Flags and not Word(RESPACK_EFLAG_KNOWN)) <> 0 then
      raise EResPackCorrupted.CreateStep(5, 'unknown entry flags');
    if (AIdxBase[I * RESPACK_ENTRY_SIZE + 37] <> 0)
      or (AIdxBase[I * RESPACK_ENTRY_SIZE + 38] <> 0)
      or (AIdxBase[I * RESPACK_ENTRY_SIZE + 39] <> 0) then
      raise EResPackCorrupted.CreateStep(5, 'reserved bytes nonzero');
    if E.CodecId <> RESPACK_CODEC_STORE then
      raise EResPackCorrupted.CreateStep(5, 'unknown codecId');
    if E.PathLen = 0 then
      raise EResPackCorrupted.CreateStep(5, 'empty path');
    if (E.DataOffset mod RESPACK_DATA_ALIGN) <> 0 then
      raise EResPackCorrupted.CreateStep(5, 'data slot not aligned');
    if (E.Size > ARes.FHdr.BlobTotal)
      or (E.DataOffset > ARes.FHdr.BlobTotal - E.Size) then
      raise EResPackCorrupted.CreateStep(5, 'data range beyond blobTotal');
    if AStrLen > High(UInt64) - UInt64(E.PathLen) then
      raise EResPackCorrupted.CreateStep(5, 'string table length overflow');
    AStrLen := AStrLen + UInt64(E.PathLen);
    if E.DataOffset < AMinData then AMinData := E.DataOffset;
    if E.Size > 0 then
    begin
      if E.DataOffset > High(UInt64) - E.Size then
        raise EResPackCorrupted.CreateStep(5, 'data range overflow');
      if E.DataOffset + E.Size > AMaxDataEnd then AMaxDataEnd := E.DataOffset + E.Size;
    end;
    ACached[I] := E;
  end;
  if (AHdrFlags and RESPACK_FLAG_HASHED) <> 0 then
    for I := 0 to ARes.Count - 1 do
      if (ACached[I].Flags and RESPACK_EFLAG_HASHED) = 0 then
        raise EResPackCorrupted.CreateStep(5, 'header hash flag inconsistent');
  if ARes.FStrTabBase > High(UInt64) - AStrLen then
    raise EResPackCorrupted.CreateStep(5, 'string table overflow');
  AStrTabEnd := ARes.FStrTabBase + AStrLen;
  if AStrTabEnd > High(UInt64) - (RESPACK_DATA_ALIGN - 1) then
    raise EResPackCorrupted.CreateStep(5, 'string table alignment overflow');
  AStrTabEnd := (AStrTabEnd + (RESPACK_DATA_ALIGN - 1)) and not UInt64(RESPACK_DATA_ALIGN - 1);
  if AMinData < ARes.FStrTabBase then
    raise EResPackCorrupted.CreateStep(5, 'data overlaps strtab');
  for I := 0 to ARes.Count - 1 do
    if ACached[I].DataOffset < AStrTabEnd then
      raise EResPackCorrupted.CreateStep(5, 'data overlaps header/index/strtab');
  CheckDataOverlapON(ACached, AStrTabEnd);
end;

procedure GuardStep6Path(const ARes: TResPack; const ACached: array of TResPackEntry;
  const AMinData: UInt64);
var
  I: SizeUInt;
  PathEnd: UInt64;
begin
  if ARes.Count = 0 then Exit;
  for I := 0 to ARes.Count - 1 do
  begin
    PathEnd := UInt64(ACached[I].PathOffset) + UInt64(ACached[I].PathLen);
    if PathEnd < UInt64(ACached[I].PathOffset) then
      raise EResPackCorrupted.CreateStep(6, 'path range overflow');
    if PathEnd > AMinData - ARes.FStrTabBase then
      raise EResPackCorrupted.CreateStep(6, 'path beyond string table bound');
    if PathEnd > ARes.FHdr.BlobTotal - ARes.FStrTabBase then
      raise EResPackCorrupted.CreateStep(6, 'path beyond blobTotal');
  end;
end;

procedure GuardStep7Order(const ARes: TResPack; const ACached: array of TResPackEntry);
var
  I: SizeUInt;
begin
  if ARes.Count = 0 then Exit;
  for I := 0 to ARes.Count - 1 do
  begin
    if (I > 0) and (ARes.CompareCachedEntries(ACached[I - 1], ACached[I]) >= 0) then
      raise EResPackCorrupted.CreateStep(7, 'index not strictly sorted or duplicate path');
    if not ResPackValidSpan(ARes.StoredPathSpanOf(ACached[I]), True) then
      raise EResPackCorrupted.CreateStep(7, 'non-canonical path stored');
  end;
end;

procedure GuardStep8Digest(const ARes: TResPack; const AStrLen: UInt64;
  const AMaxDataEnd: UInt64);
var
  AlignedStrEnd, DigEnd: UInt64;
begin
  if (ARes.FHdr.Flags and RESPACK_FLAG_DIGESTED) = 0 then Exit;
  if ARes.FStrTabBase > High(UInt64) - AStrLen then
    raise EResPackCorrupted.CreateStep(8, 'digest string table overflow');
  AlignedStrEnd := ARes.FStrTabBase + AStrLen;
  if AlignedStrEnd > High(UInt64) - 3 then
    raise EResPackCorrupted.CreateStep(8, 'digest alignment overflow');
  AlignedStrEnd := (AlignedStrEnd + 3) and not UInt64(3);
  if AlignedStrEnd > ARes.FHdr.DigestOffset then
    raise EResPackCorrupted.CreateStep(8, 'digest overlaps string table');
  if UInt64(ARes.FHdr.EntryCount) > High(UInt64) div RESPACK_DIGEST_SIZE then
    raise EResPackCorrupted.CreateStep(8, 'digest size overflow');
  DigEnd := ARes.FHdr.DigestOffset + UInt64(ARes.FHdr.EntryCount) * RESPACK_DIGEST_SIZE;
  if DigEnd < ARes.FHdr.DigestOffset then
    raise EResPackCorrupted.CreateStep(8, 'digest range overflow');
  if DigEnd > ARes.FHdr.BlobTotal then
    raise EResPackCorrupted.CreateStep(8, 'digest out of range');
  if AMaxDataEnd > High(UInt64) - 3 then
    raise EResPackCorrupted.CreateStep(8, 'digest alignment overflow');
  if ARes.FHdr.DigestOffset < ((AMaxDataEnd + 3) and not UInt64(3)) then
    raise EResPackCorrupted.CreateStep(8, 'digest overlaps data');
end;

class function TResPack.Open(const AData: PByte; const ASize: SizeUInt): TResPack;
var
  MinData, MaxDataEnd, StrTabEnd, StrLen: UInt64;
  HdrFlags: UInt32;
  IdxBase: PByte;
  Cached: TResPackEntries;
begin
  Result.Close;
  GuardStep1(AData, ASize);
  GuardStep2(AData, Result.FHdr, HdrFlags);
  GuardStep3(Result.FHdr);
  GuardStep4(ASize, Result.FHdr);
  Result.FData := AData;
  Result.FSize := ASize;
  Result.FStrTabBase := Result.FHdr.IndexOffset + UInt64(Result.FHdr.EntryCount) * RESPACK_ENTRY_SIZE;
  IdxBase := AData + SizeUInt(Result.FHdr.IndexOffset);
  MinData := Result.FHdr.BlobTotal;
  MaxDataEnd := 0;
  StrLen := 0;
  StrTabEnd := Result.FStrTabBase;
  Cached := nil;
  try
    GuardStep5Entries(Result, Cached, IdxBase, MinData, MaxDataEnd, StrLen, HdrFlags, StrTabEnd);
    GuardStep6Path(Result, Cached, MinData);
    GuardStep7Order(Result, Cached);
    GuardStep8Digest(Result, StrLen, MaxDataEnd);
    if (Result.FHdr.Flags and RESPACK_FLAG_DIGESTED) <> 0 then
      Result.FDigests := AData + SizeUInt(Result.FHdr.DigestOffset)
    else
      Result.FDigests := nil;
  finally
    SetLength(Cached, 0);
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
  Query := TByteSpan.FromStr(APath);
  { 零拷贝单源 DRY：复用 StoredPathSpan 唯一视图（PByte+Len，单次 LE 解码+Span 构造 via PathSpanRaw，零分配），
    复用 bytes.ops.SpanCompare 单源与 TByteSpan.FromStr 单源（零拷贝视图工厂 inline 零分配）；二分 14 次比较≈14 次视图构造；外联守红线 2（while 二分循环禁 inline，避 I-Cache 膨胀） }
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

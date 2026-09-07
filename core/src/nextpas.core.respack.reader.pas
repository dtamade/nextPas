unit nextpas.core.respack.reader;

{** @desc respack reader: 8-step validation + binary search.
  Steps per FORMAT.md reader checklist; invariants CONTRACT INV-R2/R3/R4/R7.
  String table: base = IndexOffset+Count*40, upper = min(DataOffset).
  Non-owning view: see CONTRACT §5. }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.bytes.ops;

type
  { Non-owning view — caller keeps blob alive until Close (CONTRACT §5). }
  TResPack = record
  private
    FData: PByte; // non-owning; do not free
    FSize: SizeUInt;
    FOpen: Boolean;
    FHdr: TResPackHeader;
    FStrTabBase: UInt64;
    FDigests: PByte;
    { 哈希段视图（bit5 置位时非 nil；开放寻址，桶→(fnv32,index)，空桶 index=$FFFFFFFF） }
    FHashIdx: PByte;
    FHashBuckets: SizeUInt;

    function GetCount: SizeUInt; inline;
    { 40 字节 index 项 → host-order TResPackEntry。
      不用无类型参数 + absolute 叠加：FPC trunk 对该组合生成错误代码（实测）。 }
    procedure DecodeWire(const AIdx: SizeUInt; out ADest: TResPackEntry);
    function CompareStoredToBuf(const AIdx: SizeUInt;
      const ABuf: PByte; const ALen: SizeUInt): Integer;
    function CompareStoredToStored(const AA, AB: SizeUInt): Integer;
    function Search(const APath: string; out AIdx: SizeUInt): Boolean;
    { Path view helper via bytes.ops (inline, zero-copy). }
    function PathSpanRaw(const AOff: UInt32; const ALen: Word): TByteSpan; inline;
    { Range-checked path view single source: RequireOpen + overflow/BlobTotal/strtab
      guards (inline, zero-copy via PathSpanRaw); StoredPathSpan(Of) 共用。 }
    function CheckedPathSpan(const AOff: UInt32; const ALen: Word): TByteSpan; inline;
    { Span-based search single source: Query 视图一次构造，多处复用
      (FromStr inline 零拷贝)；string 重载为薄转发。LowerBoundSpan/SearchSpan
      含循环不 inline (I-Cache)，ComparePathAtSpan 小体量 inline。 }
    function LowerBoundSpan(const AQuery: TByteSpan): SizeUInt;
    function ComparePathAtSpan(const AIdx: SizeUInt; const AQuery: TByteSpan): Integer; inline;
    function SearchSpan(const AQuery: TByteSpan; out AIdx: SizeUInt): Boolean;
    { 哈希先查：fnv+开放寻址（探针上限内），命中回验字节；失配/超限返回 False 由
      调用方回退二分（正确性不依赖表完整，表损坏只降速不断错）。not inline。 }
    function FindHash(const AQuery: TByteSpan; out AEntry: TResPackEntry): Boolean;
    procedure RequireOpen; inline;

  public
    { 九步校验后可用；任一失败 raise EResPackCorrupted }
    class function Open(const AData: PByte; const ASize: SizeUInt): TResPack; static;
    procedure Close;

    { 探测式查找：未命中 False；命中时 Result.Path 构造一次 }
    function Find(const APath: string; out AEntry: TResPackEntry): Boolean;
    { 断言式查找：未命中 raise EResPackNotFound }
    function Stat(const APath: string): TResPackEntry;

    function EntryAt(const AIdx: SizeUInt): TResPackEntry;
    { PathOf 每次 SpanToString 分配；仅在需要 string 时调用，热路径用 StoredPathSpanOf 零拷贝视图 }
    function PathOf(const AEntry: TResPackEntry): string; inline; // 热路径请用 StoredPathSpanOf 零拷贝
    function StoredPathSpanOf(const AEntry: TResPackEntry): TByteSpan; inline; // 零拷贝视图：10k 枚举零分配

    property Count: SizeUInt read GetCount;
    property Header: TResPackHeader read FHdr;
    property Data: PByte read FData;
    function ContentPtr(const AEntry: TResPackEntry): PByte; inline;
    function DigestPtr(const AIdx: SizeUInt): PByte; inline;
    function HasDigests: Boolean; inline;
    function HasHashIndex: Boolean; inline;
    { Path span view via bytes.ops; LowerBound not inline (loop). }
    function StoredPathSpan(const AIdx: SizeUInt): TByteSpan; inline;
    function LowerBound(const APath: string): SizeUInt;
    function ComparePathAt(const AIdx: SizeUInt; const APath: string): Integer;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.base,
  nextpas.core.respack.hasharena;

function TResPack.GetCount: SizeUInt;
begin
  Result := SizeUInt(FHdr.EntryCount);
end;

function TResPack.HasDigests: Boolean;
begin
  Result := FDigests <> nil;
end;

function TResPack.HasHashIndex: Boolean;
begin
  Result := FHashIdx <> nil;
end;

procedure TResPack.RequireOpen; inline;
begin
  if not FOpen or (FData = nil) then
    raise EResPackCorrupted.CreateCtx('open', '', 'respack: not open or blob released (CONTRACT §5)');
end;

function TResPack.ContentPtr(const AEntry: TResPackEntry): PByte; inline;
begin
  RequireOpen;
  { 减法判界：加法回绕会绕过检查；以 BlobTotal（逻辑包长）而非 FSize（实际缓冲）为界，
    尾部多余字节不属于任何条目，伪造记录不得借此窥探。 }
  if (AEntry.Size > UInt64(FHdr.BlobTotal)) or (AEntry.DataOffset > UInt64(FHdr.BlobTotal) - UInt64(AEntry.Size)) then
    raise EResPackCorrupted.CreateCtx('content', '', 'respack: data range beyond blob');
  Result := FData + SizeUInt(AEntry.DataOffset);
end;

function TResPack.DigestPtr(const AIdx: SizeUInt): PByte; inline;
begin
  RequireOpen;
  if FDigests = nil then
    raise EResPackCorrupted.CreateCtx('digest', '', 'respack: pack has no digest section');
  if AIdx >= Count then
    raise EResPackCorrupted.CreateCtx('digest', '', 'respack: digest index out of range');
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
  RequireOpen;
  if AIdx >= Count then
    raise EResPackCorrupted.CreateCtx('path', '', 'respack: index out of range');
  Base := FData + SizeUInt(FHdr.IndexOffset) + AIdx * RESPACK_ENTRY_SIZE;
  { 全量守卫与 StoredPathSpanOf 一致：CheckedPathSpan 内含 RequireOpen +
    PathEnd 回绕/BlobTotal/strtab 越界校验，杜绝越界视图。 }
  Result := CheckedPathSpan(RdU32LE(Base), RdU16LE(Base + 4));
end;

function TResPack.CheckedPathSpan(const AOff: UInt32; const ALen: Word): TByteSpan; inline;
var
  PathEnd: UInt64;
begin
  RequireOpen;
  { 减法判界：伪造 PathOffset/PathLen 加总回绕或超逻辑包长不得建视图 }
  if ALen = 0 then
    Exit(TByteSpan.Empty);
  PathEnd := UInt64(AOff) + UInt64(ALen);
  if PathEnd < UInt64(AOff) then
    raise EResPackCorrupted.CreateCtx('path', '', 'respack: path range overflow');
  if PathEnd > UInt64(FHdr.BlobTotal) then
    raise EResPackCorrupted.CreateCtx('path', '', 'respack: path range beyond blob');
  if FStrTabBase > UInt64(FHdr.BlobTotal) - PathEnd then
    raise EResPackCorrupted.CreateCtx('path', '', 'respack: path range beyond blob');
  Result := PathSpanRaw(AOff, ALen);
end;

function TResPack.StoredPathSpanOf(const AEntry: TResPackEntry): TByteSpan; inline;
begin
  { 单源：守卫收口 CheckedPathSpan，与 StoredPathSpan 全量一致。 }
  Result := CheckedPathSpan(AEntry.PathOffset, AEntry.PathLen);
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

{ ── Stage guards: Open 九步校验拆为 guard 函数，单函数 <80 行，阅读质感轻量；非 inline 守 I-Cache（分支体积） ── }

procedure GuardStep1(const AData: PByte; const ASize: SizeUInt);
begin
  if (AData = nil) or (ASize < RESPACK_HEADER_SIZE) then
    raise EResPackCorrupted.CreateStep(1, 'buffer smaller than header');
  if (AData[0] <> Byte(AnsiChar('N'))) or (AData[1] <> Byte(AnsiChar('P')))
    or (AData[2] <> Byte(AnsiChar('R'))) or (AData[3] <> Byte(AnsiChar('S'))) then
    raise EResPackCorrupted.CreateStep(1, 'bad magic');
end;

procedure GuardStep2(const AData: PByte; var AFHdr: TResPackHeader; out AHdrFlags: UInt32);
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

procedure GuardStep3(const AFHdr: TResPackHeader);
begin
  if (AFHdr.IndexOffset <> RESPACK_HEADER_SIZE)
    or (AFHdr.IndexOffset
      + UInt64(AFHdr.EntryCount) * RESPACK_ENTRY_SIZE
      > AFHdr.BlobTotal) then
    raise EResPackCorrupted.CreateStep(3, 'index out of range');
  if UInt64(AFHdr.EntryCount) > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackCorrupted.CreateStep(3, 'entry count exceeds limit');
end;

procedure GuardStep4(const ASize: SizeUInt; const AFHdr: TResPackHeader);
begin
  if ASize < AFHdr.BlobTotal then
    raise EResPackCorrupted.CreateStep(4, 'buffer truncated versus blobTotal');
end;

{ Step5 首遍流式：逐项 DecodeWire 直验，无整表 arena；LE 经 bytes.ops inline 零拷贝，零额外分配。 }
procedure GuardStep5Fields(var ARes: TResPack; const AIdxBase: PByte;
  out AMinData: UInt64; out AMaxDataEnd: UInt64; out AStrLen: UInt64;
  const AHdrFlags: UInt32; out AStrTabEnd: UInt64; out AMaxEndAll: UInt64);
var
  I, ACount: SizeUInt;
  E: TResPackEntry;
begin
  AMinData := ARes.FHdr.BlobTotal;
  AMaxDataEnd := 0;
  AMaxEndAll := 0;
  AStrLen := 0;
  ACount := ARes.Count;
  if ACount = 0 then
  begin
    AStrTabEnd := ARes.FStrTabBase;
    Exit;
  end;
  if UInt64(ACount) > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackCorrupted.CreateStep(3, 'entry count exceeds limit');
  for I := 0 to ACount - 1 do
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
    if (AHdrFlags and RESPACK_FLAG_HASHED) <> 0 then
      if (E.Flags and RESPACK_EFLAG_HASHED) = 0 then
        raise EResPackCorrupted.CreateStep(5, 'header hash flag inconsistent');
    if AStrLen > High(UInt64) - UInt64(E.PathLen) then
      raise EResPackCorrupted.CreateStep(5, 'string table length overflow');
    AStrLen := AStrLen + UInt64(E.PathLen);
    if E.DataOffset < AMinData then AMinData := E.DataOffset;
    { 全槽上界（含空文件槽）：writer EndData == max(offset+size)（单调槽位+对齐，
      共享槽不推进），step9 哈希基址派生单源于此。step5 已验 DataOffset+Size 界内，
      此处减法判界不回绕。 }
    if E.DataOffset > ARes.FHdr.BlobTotal - E.Size then
      raise EResPackCorrupted.CreateStep(5, 'data range overflow');
    if E.DataOffset + E.Size > AMaxEndAll then AMaxEndAll := E.DataOffset + E.Size;
    if E.Size > 0 then
    begin
      if E.DataOffset + E.Size > AMaxDataEnd then AMaxDataEnd := E.DataOffset + E.Size;
    end;
  end;
  if ARes.FStrTabBase > High(UInt64) - AStrLen then
    raise EResPackCorrupted.CreateStep(5, 'string table overflow');
  AStrTabEnd := ARes.FStrTabBase + AStrLen;
  if AStrTabEnd > High(UInt64) - (RESPACK_DATA_ALIGN - 1) then
    raise EResPackCorrupted.CreateStep(5, 'string table alignment overflow');
  AStrTabEnd := (AStrTabEnd + (RESPACK_DATA_ALIGN - 1)) and not UInt64(RESPACK_DATA_ALIGN - 1);
  if AMinData < ARes.FStrTabBase then
    raise EResPackCorrupted.CreateStep(5, 'data overlaps strtab');
end;

{ 融合第二遍：strtab 下界 + Step6 路径界 + Step7 有序/规范 + Step5 overlap
  增量哈希；仅读本遍所需的 PathOff/PathLen/DataOff/Size 四字段
  (RdUxx bytes.ops inline 单源)，完整 DecodeWire 只在首遍出现一次——
  流式两遍无整表常驻 (零 transient 分配)，安全换吞吐的显式取舍。
  SpanCompare/ValidSpan 经 bytes.ops 零拷贝 inline。 }
procedure GuardStep67Overlap(var ARes: TResPack; const AIdxBase: PByte;
  const ACount: SizeUInt; const AMinData: UInt64; const AStrTabEnd: UInt64);
var
  I: SizeUInt;
  PathOff: UInt32;
  PathLen: Word;
  DataOff, DataSize: UInt64;
  PathEnd: UInt64;
  CurSpan, PrevSpan: TByteSpan;
  HasPrev: Boolean;
  BucketCount, DistinctCount, BucketIdx: SizeUInt;
  BucketsHead, SlotNext: PSizeInt;
  Distinct: PResPackDistinct;
  OverlapArena: TLocalArena;
  LastEnd: UInt64;
  Probe: SizeInt;
  IsDup: Boolean;
  TinySeen: array[0..3] of TResPackDistinct;
  J: SizeUInt;
begin
  if ACount = 0 then Exit;
  OverlapArena := nil;
  BucketsHead := nil;
  SlotNext := nil;
  Distinct := nil;
  BucketCount := 0;
  { tiny N<=4 栈上线性判重，免 overlap arena 一次性分配；等价键比较 (Off,Size)。 }
  if ACount > 4 then
    ResPackOverlapInit(ACount, OverlapArena, BucketsHead, SlotNext, Distinct, BucketCount);
  try
    DistinctCount := 0;
    LastEnd := AStrTabEnd;
    HasPrev := False;
    PrevSpan := TByteSpan.Empty;
    for I := 0 to ACount - 1 do
    begin
      PathOff := RdU32LE(AIdxBase + I * RESPACK_ENTRY_SIZE);
      PathLen := RdU16LE(AIdxBase + I * RESPACK_ENTRY_SIZE + 4);
      DataOff := RdU64LE(AIdxBase + I * RESPACK_ENTRY_SIZE + 8);
      DataSize := RdU64LE(AIdxBase + I * RESPACK_ENTRY_SIZE + 16);
      if DataOff < AStrTabEnd then
        raise EResPackCorrupted.CreateStep(5, 'data overlaps header/index/strtab');
      PathEnd := UInt64(PathOff) + UInt64(PathLen);
      if PathEnd < UInt64(PathOff) then
        raise EResPackCorrupted.CreateStep(6, 'path range overflow');
      if PathEnd > AMinData - ARes.FStrTabBase then
        raise EResPackCorrupted.CreateStep(6, 'path beyond string table bound');
      if PathEnd > ARes.FHdr.BlobTotal - ARes.FStrTabBase then
        raise EResPackCorrupted.CreateStep(6, 'path beyond blobTotal');
      if PathLen = 0 then
        CurSpan := TByteSpan.Empty
      else
        CurSpan := TByteSpan.Create(ARes.FData + SizeUInt(ARes.FStrTabBase) + SizeUInt(PathOff), SizeUInt(PathLen));
      if HasPrev and (SpanCompare(PrevSpan, CurSpan) >= 0) then
        raise EResPackCorrupted.CreateStep(7, 'index not strictly sorted or duplicate path');
      if not ResPackValidSpan(CurSpan, True) then
        raise EResPackCorrupted.CreateStep(7, 'non-canonical path stored');
      if DataSize > 0 then
      begin
        IsDup := False;
        if BucketsHead <> nil then
        begin
          BucketIdx := (SizeUInt(DataOff) xor SizeUInt(DataOff shr 32) xor SizeUInt(DataSize)) and (BucketCount - 1);
          Probe := BucketsHead[BucketIdx];
          while Probe <> -1 do
          begin
            if (Distinct[SizeUInt(Probe)].Off = DataOff) and (Distinct[SizeUInt(Probe)].Size = DataSize) then
            begin IsDup := True; Break; end;
            Probe := SlotNext[SizeUInt(Probe)];
          end;
        end
        else if ACount <= 4 then
        begin
          if DistinctCount > 0 then
            for J := 0 to DistinctCount - 1 do
              if (TinySeen[J].Off = DataOff) and (TinySeen[J].Size = DataSize) then
              begin IsDup := True; Break; end;
        end;
        if not IsDup then
        begin
          if DataOff < LastEnd then
            raise EResPackCorrupted.CreateStep(5, 'data sections overlap');
          LastEnd := DataOff + DataSize;
          if BucketsHead <> nil then
          begin
            Distinct[DistinctCount].Off := DataOff;
            Distinct[DistinctCount].Size := DataSize;
            SlotNext[DistinctCount] := BucketsHead[BucketIdx];
            BucketsHead[BucketIdx] := SizeInt(DistinctCount);
            Inc(DistinctCount);
          end
          else if ACount <= 4 then
          begin
            TinySeen[DistinctCount].Off := DataOff;
            TinySeen[DistinctCount].Size := DataSize;
            Inc(DistinctCount);
          end;
        end;
      end;
      PrevSpan := CurSpan;
      HasPrev := True;
    end;
  finally
    ResPackDedupDone(OverlapArena);
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

{ 第 9 步（bit5 置位时）：哈希段基址派生（digest 尾或全槽上界，8 对齐）+
  界内断言 + 数据区不交叠 + 逐桶回验（fnv 重算、index 界内、非空数=N）。
  Open 期全量验证不抽验：损坏整包拒绝是 INV-R2 无半信任承诺的一部分，
  不以 Open 提速为由削弱；路径 FNV 量级远小于八步校验本身体量。
  重复/缺失 index 只降速（查找回退二分），不断错；探针天然终止于空桶。 }
procedure GuardStep9Hash(var ARes: TResPack; const AMaxEndAll: UInt64);
var
  N: SizeUInt;
  Buckets: SizeUInt;
  SegEnd: UInt64;
  Base: UInt64;
  B: SizeUInt;
  SlotFnv: UInt32;
  SlotIdx: UInt32;
  E: TResPackEntry;
  Span: TByteSpan;
  NonEmpty: SizeUInt;
begin
  N := ARes.Count;
  if N = 0 then
    raise EResPackCorrupted.CreateStep(9, 'hash index without entries');
  Buckets := ResPackHashBucketCount(N);
  if Buckets < RESPACK_HASH_MIN_BUCKETS then
    raise EResPackCorrupted.CreateStep(9, 'hash bucket count too small');
  if Buckets > High(UInt64) div RESPACK_HASH_ENTRY_SIZE then
    raise EResPackCorrupted.CreateStep(9, 'hash section size overflow');
  if (ARes.FHdr.Flags and RESPACK_FLAG_DIGESTED) <> 0 then
  begin
    if ARes.FHdr.DigestOffset > High(UInt64) - UInt64(N) * RESPACK_DIGEST_SIZE then
      raise EResPackCorrupted.CreateStep(9, 'hash digest end overflow');
    SegEnd := ARes.FHdr.DigestOffset + UInt64(N) * RESPACK_DIGEST_SIZE;
  end
  else
    SegEnd := AMaxEndAll;
  if SegEnd > High(UInt64) - (RESPACK_HASH_ALIGN - 1) then
    raise EResPackCorrupted.CreateStep(9, 'hash alignment overflow');
  Base := nextpas.core.mem.base.AlignUp64(SegEnd, RESPACK_HASH_ALIGN);
  if Base > ARes.FHdr.BlobTotal then
    raise EResPackCorrupted.CreateStep(9, 'hash section beyond blobTotal');
  if UInt64(Buckets) * RESPACK_HASH_ENTRY_SIZE > ARes.FHdr.BlobTotal - Base then
    raise EResPackCorrupted.CreateStep(9, 'hash section beyond blobTotal');
  if AMaxEndAll > Base then
    raise EResPackCorrupted.CreateStep(9, 'data overlaps hash section');
  NonEmpty := 0;
  for B := 0 to Buckets - 1 do
  begin
    SlotFnv := RdU32LE(ARes.FData + SizeUInt(Base) + B * RESPACK_HASH_ENTRY_SIZE);
    SlotIdx := RdU32LE(ARes.FData + SizeUInt(Base) + B * RESPACK_HASH_ENTRY_SIZE + 4);
    if SlotIdx = RESPACK_HASH_EMPTY_INDEX then
      Continue;
    Inc(NonEmpty);
    if SizeUInt(SlotIdx) >= N then
      raise EResPackCorrupted.CreateStep(9, 'hash slot index out of range');
    ARes.DecodeWire(SizeUInt(SlotIdx), E);
    { PathSpanRaw 直取：二遍已验全条目路径界（step6），同遍式信任基；
      CheckedPathSpan 含 RequireOpen，Open 期不可用。 }
    Span := ARes.PathSpanRaw(E.PathOffset, E.PathLen);
    if ResPackFnv1a32(Span.Data, Span.Len) <> SlotFnv then
      raise EResPackCorrupted.CreateStep(9, 'hash slot fingerprint mismatch');
  end;
  if NonEmpty <> SizeUInt(N) then
    raise EResPackCorrupted.CreateStep(9, 'hash slot count mismatch');
  ARes.FHashIdx := ARes.FData + SizeUInt(Base);
  ARes.FHashBuckets := Buckets;
end;

class function TResPack.Open(const AData: PByte; const ASize: SizeUInt): TResPack;
var
  MinData, MaxDataEnd, StrTabEnd, StrLen, MaxEndAll: UInt64;
  HdrFlags: UInt32;
  IdxBase: PByte;
  EntryCount: SizeUInt;
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
  MaxEndAll := 0;
  StrLen := 0;
  StrTabEnd := Result.FStrTabBase;
  { 流式两遍无整表常驻：首遍 DecodeWire 全字段直验，次遍仅读四字段
    (PathOff/PathLen/DataOff/DataSize) 完成 strtab/Step6/Step7/overlap；
    完整解码单点，零 transient 拷贝。 }
  GuardStep5Fields(Result, IdxBase, MinData, MaxDataEnd, StrLen, HdrFlags, StrTabEnd, MaxEndAll);
  EntryCount := Result.Count;
  GuardStep67Overlap(Result, IdxBase, EntryCount, MinData, StrTabEnd);
  GuardStep8Digest(Result, StrLen, MaxDataEnd);
  if (Result.FHdr.Flags and RESPACK_FLAG_DIGESTED) <> 0 then
    Result.FDigests := AData + SizeUInt(Result.FHdr.DigestOffset)
  else
    Result.FDigests := nil;
  Result.FHashIdx := nil;
  Result.FHashBuckets := 0;
  if (HdrFlags and RESPACK_FLAG_HASHINDEX) <> 0 then
    GuardStep9Hash(Result, MaxEndAll);
  Result.FOpen := True;
end;

procedure TResPack.Close;
begin
  FData := nil;
  FSize := 0;
  FDigests := nil;
  FHashIdx := nil;
  FHashBuckets := 0;
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
  Query: TByteSpan;
begin
  { 单次零拷贝视图构造，复用于 LowerBoundSpan + ComparePathAtSpan。 }
  Query := TByteSpan.FromStr(APath);
  Result := SearchSpan(Query, AIdx);
end;

function TResPack.SearchSpan(const AQuery: TByteSpan; out AIdx: SizeUInt): Boolean;
var
  Idx: SizeUInt;
begin
  Idx := LowerBoundSpan(AQuery);
  if (Idx < Count) and (ComparePathAtSpan(Idx, AQuery) = 0) then
  begin
    AIdx := Idx;
    Exit(True);
  end;
  Result := False;
end;

function TResPack.FindHash(const AQuery: TByteSpan; out AEntry: TResPackEntry): Boolean;
{ 探针上限：校验期表装载≤0.5（期望链~2），超限回退二分——正确性不依赖表分布，
  恶意聚簇只降速不断错；空桶即真未命中。tiny 表（桶数<上限）全覆盖才停。 }
const
  MAX_PROBES = 64;
var
  H: UInt32;
  Mask: SizeUInt;
  I: SizeUInt;
  B: SizeUInt;
  Limit: SizeUInt;
  SlotFnv: UInt32;
  SlotIdx: UInt32;
  E: TResPackEntry;
begin
  Result := False;
  if (FHashIdx = nil) or (FHashBuckets < RESPACK_HASH_MIN_BUCKETS) then
    Exit;
  if not IsPowerOfTwo(FHashBuckets) then
    Exit;
  H := ResPackFnv1a32(AQuery.Data, AQuery.Len);
  Mask := FHashBuckets - 1;
  B := SizeUInt(H) and Mask;
  Limit := MAX_PROBES;
  if Limit > FHashBuckets then
    Limit := FHashBuckets;
  for I := 0 to Limit - 1 do
  begin
    SlotFnv := RdU32LE(FHashIdx + B * RESPACK_HASH_ENTRY_SIZE);
    SlotIdx := RdU32LE(FHashIdx + B * RESPACK_HASH_ENTRY_SIZE + 4);
    if SlotIdx = RESPACK_HASH_EMPTY_INDEX then
      Exit;
    if (SlotFnv = H) and (SizeUInt(SlotIdx) < Count) then
    begin
      DecodeWire(SizeUInt(SlotIdx), E);
      { 有界视图：Open 后缓冲可被改写，无界视图会越界读；Checked 经 BlobTotal/strtab
        判界越界即抛 EResPackCorrupted (inline 零拷贝 via bytes.ops)。 }
      if SpanCompare(CheckedPathSpan(E.PathOffset, E.PathLen), AQuery) = 0 then
      begin
        AEntry := E;
        Exit(True);
      end;
    end;
    B := (B + 1) and Mask;
  end;
end;

function TResPack.Find(const APath: string; out AEntry: TResPackEntry): Boolean;
var
  Idx: SizeUInt;
  Query: TByteSpan;
begin
  if not FOpen then
    Exit(False);
  { Query 视图一次构造：合法性扫描走 span 单源，与二分比较复用同一视图。 }
  Query := TByteSpan.FromStr(APath);
  if not ResPackValidSpan(Query, True) then
    Exit(False);
  { 哈希先查：命中直接返回；失配/超限/无段回退二分（SearchSpan），行为与无段一致。 }
  if (FHashIdx <> nil) and FindHash(Query, AEntry) then
    Exit(True);
  if not SearchSpan(Query, Idx) then
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

function TResPack.PathOf(const AEntry: TResPackEntry): string; inline; // 热路径请用 StoredPathSpanOf 零拷贝
begin
  RequireOpen;
  Result := SpanToString(StoredPathSpanOf(AEntry)); // 分配：热路径请用 StoredPathSpanOf 零拷贝
end;

function TResPack.LowerBound(const APath: string): SizeUInt;
begin
  { 薄转发：单次 FromStr 零拷贝视图后走 span 单源。 }
  Result := LowerBoundSpan(TByteSpan.FromStr(APath));
end;

function TResPack.LowerBoundSpan(const AQuery: TByteSpan): SizeUInt;
var
  Lo, Hi, Mid: SizeUInt;
  C: Integer;
begin
  RequireOpen;
  Lo := 0;
  Hi := Count;
  if Hi = 0 then Exit(0);
  { Binary search via StoredPathSpan (checked) + SpanCompare (bytes.ops inline 零拷贝);
    not inline (loop 守 I-Cache). RequireOpen hoisted once; per-step 路径界仍逐项校验：
    Open 后缓冲可被改写，无界视图会越界读而非抛错。 }
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    C := SpanCompare(StoredPathSpan(Mid), AQuery);
    if C < 0 then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := Lo;
end;

function TResPack.ComparePathAt(const AIdx: SizeUInt; const APath: string): Integer;
begin
  { 薄转发：单次 FromStr 零拷贝视图后走 span 单源。 }
  Result := ComparePathAtSpan(AIdx, TByteSpan.FromStr(APath));
end;

function TResPack.ComparePathAtSpan(const AIdx: SizeUInt; const AQuery: TByteSpan): Integer; inline;
var
  S: TByteSpan;
begin
  RequireOpen;
  if AIdx >= Count then
    raise EResPackCorrupted.CreateCtx('path', '', 'respack: index out of range');
  S := StoredPathSpan(AIdx);
  Result := SpanCompare(S, AQuery);
end;
end.

unit nextpas.core.respack.writer.layout;

{** @desc respack 布局单源：排序/去重/对齐/槽位计算，供 writer/stream 共用。
  单源于 base/hasharena/bytes.ops/collections.algorithms/mem.base。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.mem.arena.local;

type
  TResPackSlot = record
    Offset: UInt64;
    SrcIdx: SizeUInt;
    Fnv: UInt32;
  end;

  TResPackLayout = record
    N: SizeUInt;
    PathLens: array of Word;
    Order: array of SizeUInt;
    FnvBuf: array of UInt32;
    EntrySlots: array of SizeUInt;
    Slots: array of TResPackSlot;
    SlotCount: SizeUInt;
    StrLen: UInt64;
    StrTabBase: UInt64;
    DataStart: UInt64;
    DigOff: UInt64;
    Total: UInt64;
    { 哈希段（opt-in）：桶数 0 = 无段；HashSlotIdx 为桶→index（$FFFFFFFF 空），
      Emit 经此直排，reader 侧按同规则派生（ResPackHashBucketCount 单源）。 }
    HashBuckets: SizeUInt;
    HashBase: UInt64;
    HashSlotIdx: array of UInt32;
  end;

procedure ResPackLayoutClear(var ALayout: TResPackLayout);
procedure ResPackComputeLayout(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; out ALayout: TResPackLayout);
{ 尾段总数单源：digest 对齐/哈希对齐/上界钳制，供 writer.layout 与 dirsource 有界布局共用；
  仅算数（DigOff/HashBase/Total/Buckets），灌桶分配由调用方负责；冷路径不 inline 守 I-Cache。 }
procedure ResPackFinishLayoutTail(const AEndData: UInt64; const AN: SizeUInt;
  const AHasDigest, AHashIndex: Boolean; out ADigOff, AHashBase, ATotal: UInt64;
  out AHashBuckets: SizeUInt);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.collections.algorithms,
  nextpas.core.mem.base,
  nextpas.core.respack.hasharena;

type
  TWordArr = array[0..(High(SizeInt) div SizeOf(Word)) - 1] of Word;
  PWordArr = ^TWordArr;
  TEntryArr = array[0..(High(SizeInt) div SizeOf(TResPackInputEntry)) - 1] of TResPackInputEntry;
  PEntryArr = ^TEntryArr;
  TOrderSortData = record
    Entries: PEntryArr;
    Lens: PWordArr;
  end;
  POrderSortData = ^TOrderSortData;

{ 路径字节序比较单源：排序与重复判定共用，经 bytes.ops inline 零拷贝。 }
function CompareOrder(const A, B: SizeUInt; Data: Pointer): SizeInt;
var
  D: POrderSortData;
  PA, PB: PByte;
  LA, LB: SizeUInt;
begin
  D := POrderSortData(Data);
  LA := SizeUInt(D^.Lens^[A]);
  LB := SizeUInt(D^.Lens^[B]);
  if LA = 0 then PA := nil else PA := PByte(@D^.Entries^[A].Path[1]);
  if LB = 0 then PB := nil else PB := PByte(@D^.Entries^[B].Path[1]);
  Result := ResPackCmpPath(PA, LA, PB, LB);
end;

function AlignUpU64(const AValue, AAlign: UInt64): UInt64; inline;
begin
  Result := nextpas.core.mem.base.AlignUp64(AValue, AAlign);
end;

{ 槽位命中判定单源：fnv 候选 + 长度 + 字节回验，tiny 线性/哈希主循环共用。 }
function SlotContentEqual(const AEntries: array of TResPackInputEntry;
  const ASlots: array of TResPackSlot; const AFnvBuf: array of UInt32;
  const AJ, AK: SizeUInt): Boolean; inline;
begin
  Result := (ASlots[AK].Fnv = AFnvBuf[AJ])
    and (AEntries[AJ].DataSize = AEntries[ASlots[AK].SrcIdx].DataSize)
    and ((AEntries[AJ].DataSize = 0)
      or nextpas.core.bytes.ops.SpanEqual(TByteSpan.Create(AEntries[AJ].Data, AEntries[AJ].DataSize),
        TByteSpan.Create(AEntries[ASlots[AK].SrcIdx].Data, AEntries[AJ].DataSize)));
end;

{ 槽位分配单源：对齐经 mem.base，tiny/哈希/直排三处共用。 }
procedure LayoutAddSlot(var ALayout: TResPackLayout; var ACur: UInt64;
  var ASlotCount: SizeUInt; const AEntries: array of TResPackInputEntry;
  const AFnvBuf: array of UInt32; const AJ: SizeUInt; const ANeedFnv: Boolean); inline;
begin
  ACur := AlignUpU64(ACur, RESPACK_DATA_ALIGN);
  ALayout.Slots[ASlotCount].Offset := ACur;
  ALayout.Slots[ASlotCount].SrcIdx := AJ;
  if ANeedFnv then
    ALayout.Slots[ASlotCount].Fnv := AFnvBuf[AJ]
  else
    ALayout.Slots[ASlotCount].Fnv := 0;
  ALayout.EntrySlots[AJ] := ASlotCount;
  ACur := ACur + UInt64(AEntries[AJ].DataSize);
  Inc(ASlotCount);
end;

procedure ResPackLayoutClear(var ALayout: TResPackLayout);
begin
  ALayout.PathLens := nil;
  ALayout.Order := nil;
  ALayout.FnvBuf := nil;
  ALayout.EntrySlots := nil;
  ALayout.Slots := nil;
  ALayout.SlotCount := 0;
  ALayout.N := 0;
  ALayout.StrLen := 0;
  ALayout.StrTabBase := 0;
  ALayout.DataStart := 0;
  ALayout.DigOff := 0;
  ALayout.Total := 0;
  ALayout.HashBuckets := 0;
  ALayout.HashBase := 0;
  ALayout.HashSlotIdx := nil;
end;

{ 尾段总数单源实现：digest 4 对齐 + 哈希 8 对齐 + 三处上界钳制；writer/dirsource 共用消镜像。 }
procedure ResPackFinishLayoutTail(const AEndData: UInt64; const AN: SizeUInt;
  const AHasDigest, AHashIndex: Boolean; out ADigOff, AHashBase, ATotal: UInt64;
  out AHashBuckets: SizeUInt);
var
  LDigOff, LTotal, LHashBase: UInt64;
  LBuckets: SizeUInt;
begin
  if AHasDigest then
  begin
    LDigOff := AlignUpU64(AEndData, 4);
    if (LDigOff = 0) and (AEndData <> 0) then
      raise EResPackError.Create('respack: digest offset overflow');
    if AN > High(UInt64) div RESPACK_DIGEST_SIZE then
      raise EResPackTooLarge.Create('respack: digest size overflow');
    if LDigOff > High(UInt64) - UInt64(AN) * RESPACK_DIGEST_SIZE then
      raise EResPackTooLarge.Create('respack: total size overflow');
    LTotal := LDigOff + UInt64(AN) * RESPACK_DIGEST_SIZE;
  end
  else
  begin
    LDigOff := 0;
    LTotal := AEndData;
  end;
  LBuckets := 0;
  LHashBase := 0;
  if AHashIndex and (AN > 0) then
  begin
    LBuckets := ResPackHashBucketCount(AN);
    if LBuckets < RESPACK_HASH_MIN_BUCKETS then
      raise EResPackError.Create('respack: hash bucket count too small');
    if LBuckets > High(UInt64) div SizeUInt(RESPACK_HASH_ENTRY_SIZE) then
      raise EResPackTooLarge.Create('respack: hash section too large');
    if LTotal > High(UInt64) - (RESPACK_HASH_ALIGN - 1) then
      raise EResPackTooLarge.Create('respack: hash alignment overflow');
    LHashBase := AlignUpU64(LTotal, RESPACK_HASH_ALIGN);
    if LHashBase > High(UInt64) - UInt64(LBuckets) * RESPACK_HASH_ENTRY_SIZE then
      raise EResPackTooLarge.Create('respack: total size overflow');
    LTotal := LHashBase + UInt64(LBuckets) * RESPACK_HASH_ENTRY_SIZE;
  end;
  if LTotal > High(SizeUInt) then
    raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
  ADigOff := LDigOff;
  AHashBase := LHashBase;
  ATotal := LTotal;
  AHashBuckets := LBuckets;
end;

procedure ResPackComputeLayout(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; out ALayout: TResPackLayout);
var
  N, I, J: SizeUInt;
  K: SizeUInt;
  BucketIdx, BucketCount: SizeUInt;
  BucketsHead: nextpas.core.respack.base.PSizeInt;
  SlotNext: nextpas.core.respack.base.PSizeInt;
  Probe: SizeInt;
  DedupArena: TLocalArena;
  TotalInput: SizeUInt;
  StrLen: UInt64;
  StrTabBase, DataStart, Cur, EndData: UInt64;
  SlotCount: SizeUInt;
  NeedFnv: Boolean;
  DigOff: UInt64;
  Total: UInt64;
  HashBase: UInt64;
  Hi, Hb, Hp2: SizeUInt;
  HFnv: UInt32;
  Hp: PByte;
  SortData: TOrderSortData;
begin
  ResPackLayoutClear(ALayout);
  N := SizeUInt(Length(AEntries));
  ALayout.N := N;
  if N > RESPACK_MAX_ENTRY_COUNT then
    raise EResPackTooLarge.Create('respack: entry count exceeds limit');

  { ── 校验 + 上限 ── }
  TotalInput := 0;
  try
    SetLength(ALayout.PathLens, N);
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: entry count too large for host');
  end;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      if not ResPackValidPath(AEntries[I].Path, True) then
        raise EResPackInvalidPath.Create('respack: invalid pack path "'
          + AEntries[I].Path + '"');
      if Length(AEntries[I].Path) > High(Word) then
        raise EResPackInvalidPath.Create('respack: path too long "'
          + AEntries[I].Path + '"');
      if (AEntries[I].DataSize > 0) and (AEntries[I].Data = nil) then
        raise EResPackError.Create('respack: entry has nil data with nonzero size "'
          + AEntries[I].Path + '"');
      ALayout.PathLens[I] := Word(Length(AEntries[I].Path));
      if not TryAddSizeUInt(TotalInput, SizeUInt(AEntries[I].DataSize), TotalInput) then
        raise EResPackTooLarge.Create('respack: total input overflow (wrap) exceeds limit');
    end;
  if TotalInput > AOpts.MaxTotalInputBytes then
    raise EResPackTooLarge.Create('respack: total input exceeds limit');
  if AOpts.CodecId <> RESPACK_CODEC_STORE then
    raise EResPackError.Create('respack: unsupported CodecId, v1 only store(0)');

  { ── 排序 ── }
  try
    SetLength(ALayout.Order, N);
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: entry count too large for host');
  end;
  if N > 0 then
  begin
    for I := 0 to N - 1 do
      ALayout.Order[I] := I;
    SortData.Entries := PEntryArr(@AEntries[0]);
    SortData.Lens := PWordArr(@ALayout.PathLens[0]);
    if N > 1 then
      specialize Sort<SizeUInt>(ALayout.Order, @CompareOrder, @SortData);
    for I := 1 to N - 1 do
      if CompareOrder(ALayout.Order[I], ALayout.Order[I-1], @SortData) = 0 then
        raise EResPackDuplicatePath.Create('respack: duplicate path "'
          + AEntries[ALayout.Order[I]].Path + '"');
  end;

  { ── fnv：仅 Hashes/Deduplicate 时分配填充，否则 FnvBuf 留 nil 零分配 ── }
  NeedFnv := AOpts.Hashes or AOpts.Deduplicate;
  if NeedFnv then
  begin
    try
      SetLength(ALayout.FnvBuf, N);
    except
      on E: EOutOfMemory do
        raise EResPackTooLarge.Create('respack: entry count too large for host');
    end;
    if N > 0 then
      for I := 0 to N - 1 do
        ALayout.FnvBuf[I] := ResPackFnv1a32(AEntries[I].Data, AEntries[I].DataSize);
  end;

  { ── 布局：StrLen UInt64 回绕守卫（近 64K 路径极端）+ pathOffset u32 上界 ── }
  StrLen := 0;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      if StrLen > High(UInt64) - UInt64(ALayout.PathLens[I]) then
        raise EResPackTooLarge.Create('respack: string table length overflow');
      StrLen := StrLen + UInt64(ALayout.PathLens[I]);
    end;
  { pathOffset 线上 u32：路径字节不计入 MaxTotalInputBytes，超 4GiB 时 writer 必须前置拒绝，
    绝不产出 reader 必拒的截断包（builder 的 UInt32 转换至此恒安全）。 }
  if StrLen > High(UInt32) then
    raise EResPackTooLarge.Create('respack: string table exceeds pathOffset u32 range');
  ALayout.StrLen := StrLen;
  StrTabBase := UInt64(RESPACK_HEADER_SIZE) + UInt64(N) * RESPACK_ENTRY_SIZE;
  ALayout.StrTabBase := StrTabBase;
  if N > 0 then
    DataStart := AlignUpU64(StrTabBase + StrLen, RESPACK_DATA_ALIGN)
  else
    DataStart := StrTabBase;
  ALayout.DataStart := DataStart;
  { 槽位累加单点上界：Cur ≤ DataStart + TotalInput + 16*N；MaxTotalInputBytes 可由调用方调高，
    此处一次性钳住 UInt64 回绕，后续三处槽位循环无需逐站检查。 }
  if TotalInput > High(UInt64) - (DataStart + UInt64(N) * 16 + RESPACK_DATA_ALIGN) then
    raise EResPackTooLarge.Create('respack: layout size overflow');

  try
    SetLength(ALayout.EntrySlots, N);
    SetLength(ALayout.Slots, N);
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: entry count too large for host');
  end;
  SlotCount := 0;
  Cur := DataStart;
  if AOpts.Deduplicate then
  begin
    // tiny N<=4 线性免 arena
    if N <= 4 then
    begin
      if N > 0 then
        for I := 0 to N - 1 do
        begin
          J := ALayout.Order[I];
          ALayout.EntrySlots[J] := SizeUInt(-1);
          if SlotCount > 0 then
            for K := 0 to SlotCount - 1 do
              if SlotContentEqual(AEntries, ALayout.Slots, ALayout.FnvBuf, J, K) then
              begin
                ALayout.EntrySlots[J] := K;
                Break;
              end;
          if ALayout.EntrySlots[J] = SizeUInt(-1) then
            LayoutAddSlot(ALayout, Cur, SlotCount, AEntries, ALayout.FnvBuf, J, NeedFnv);
        end;
    end
    else
    begin
      BucketsHead := nil;
      SlotNext := nil;
      DedupArena := nil;
      nextpas.core.respack.hasharena.ResPackDedupInit(N, DedupArena, BucketsHead, SlotNext, BucketCount);
      try
        if N > 0 then
          for I := 0 to N - 1 do
          begin
            J := ALayout.Order[I];
            ALayout.EntrySlots[J] := SizeUInt(-1);
            BucketIdx := SizeUInt(ALayout.FnvBuf[J]) and (BucketCount - 1);
            Probe := BucketsHead[BucketIdx];
            while Probe <> -1 do
            begin
              K := SizeUInt(Probe);
              if SlotContentEqual(AEntries, ALayout.Slots, ALayout.FnvBuf, J, K) then
              begin
                ALayout.EntrySlots[J] := K;
                Break;
              end;
              Probe := SlotNext[K];
            end;
            if ALayout.EntrySlots[J] = SizeUInt(-1) then
            begin
              LayoutAddSlot(ALayout, Cur, SlotCount, AEntries, ALayout.FnvBuf, J, NeedFnv);
              SlotNext[ALayout.EntrySlots[J]] := BucketsHead[BucketIdx];
              BucketsHead[BucketIdx] := SizeInt(ALayout.EntrySlots[J]);
            end;
          end;
        finally
          nextpas.core.respack.hasharena.ResPackDedupDone(DedupArena);
        end;
    end;
  end
  else if N > 0 then
    for I := 0 to N - 1 do
    begin
      J := ALayout.Order[I];
      LayoutAddSlot(ALayout, Cur, SlotCount, AEntries, ALayout.FnvBuf, J, NeedFnv);
    end;
  ALayout.SlotCount := SlotCount;
  EndData := Cur;
  { 尾段总数单源于 ResPackFinishLayoutTail（digest/哈希对齐+上界，writer/dirsource 共用）。 }
  ResPackFinishLayoutTail(EndData, N, AOpts.DigestFunc <> nil, AOpts.HashIndex,
    DigOff, HashBase, Total, BucketCount);
  ALayout.DigOff := DigOff;
  ALayout.Total := Total;
  ALayout.HashBuckets := 0;
  ALayout.HashBase := 0;
  { 哈希段灌桶（opt-in）：总数已由单源算出，此处仅分配 HashSlotIdx 并按 index 序灌桶
    （确定性，INV-R5），fnv 候选+开放寻址，装载≤0.5 恒有空槽（探针傻瓜式上界兜底）。 }
  if BucketCount > 0 then
  begin
    ALayout.HashBase := HashBase;
    try
      SetLength(ALayout.HashSlotIdx, BucketCount);
    except
      on E: EOutOfMemory do
        raise EResPackTooLarge.Create('respack: hash table too large for host');
    end;
    for Hi := 0 to BucketCount - 1 do
      ALayout.HashSlotIdx[Hi] := RESPACK_HASH_EMPTY_INDEX;
    { 按 index 序灌桶：存 index 位（reader DecodeWire 同义），fnv 取该位之源路径；
      输入序直排则 SrcIdx/位错位（6 条目乱序即现形，2 条目恰有序掩盖）。 }
    for I := 0 to N - 1 do
    begin
      J := ALayout.Order[I];
      if Length(AEntries[J].Path) > 0 then
        Hp := PByte(@AEntries[J].Path[1])
      else
        Hp := nil;
      HFnv := ResPackFnv1a32(Hp, SizeUInt(ALayout.PathLens[J]));
      Hb := SizeUInt(HFnv) and (BucketCount - 1);
      Hp2 := 0;
      while ALayout.HashSlotIdx[Hb] <> RESPACK_HASH_EMPTY_INDEX do
      begin
        Inc(Hp2);
        if Hp2 > BucketCount then
          raise EResPackError.Create('respack: hash table full');
        Hb := (Hb + 1) and (BucketCount - 1);
      end;
      ALayout.HashSlotIdx[Hb] := UInt32(I);
    end;
    ALayout.HashBuckets := BucketCount;
  end;
end;

end.

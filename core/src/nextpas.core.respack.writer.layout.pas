unit nextpas.core.respack.writer.layout;

{** @desc respack 布局单源：排序/去重/对齐/槽位/总量计算。
  由 writer 与 writer.stream 共用，消除双驻留假流式不可复用；
  零拷贝字节比较单源 respack.base.ResPackCmpPath（→bytes.ops）、
  排序单源 collections.algorithms、对齐单源 mem.base.AlignUp64。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base;

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
  end;

type
  TResPackDedupBuckets = record
    const MIN = 256;
    const MAX = 65536;
    class function BucketCountFor(const ANeeded: SizeUInt): SizeUInt; static; inline;
  end;

procedure ResPackLayoutClear(var ALayout: TResPackLayout);
procedure ResPackComputeLayout(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; out ALayout: TResPackLayout);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.collections.algorithms,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.base;

const
  BUCKET_MIN = TResPackDedupBuckets.MIN;
  BUCKET_MAX = TResPackDedupBuckets.MAX; { 去重桶上限 64K：BucketsHead 64K*SizeInt≈256KB + SlotNext N*SizeInt，峰值受控；原 4M 桶双数组最高 32MB(4M*8)，大去重集热点 SpanEqual 逐字节回验叠加 O(n) 期望外最坏拷贝开销，收敛至 64K 控热点 }

class function TResPackDedupBuckets.BucketCountFor(const ANeeded: SizeUInt): SizeUInt; inline;
var
  Target: SizeUInt;
begin
  if ANeeded <= MIN then Exit(MIN);
  if ANeeded >= MAX then Exit(MAX);
  Target := ANeeded;
  Result := BytesNextCapacity(MIN, Target);
  if Result > MAX then Result := MAX;
  if Result < MIN then Result := MIN;
end;

function CmpPath(const AEntries: array of TResPackInputEntry;
  const ALens: array of Word; AI, AJ: SizeUInt): Integer; inline;
begin
  // 单源视图: TByteSpan.FromStr 零拷贝工厂 inline 零分配, 复用 bytes.ops.SpanCompare 单源, 消 PByte(@Str[1]) 裸指针重复
  Result := SpanCompare(TByteSpan.FromStr(AEntries[AI].Path), TByteSpan.FromStr(AEntries[AJ].Path));
end;

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
  PSizeInt = ^SizeInt;

function CompareOrder(const A, B: SizeUInt; Data: Pointer): SizeInt;
var
  D: POrderSortData;
begin
  D := POrderSortData(Data);
  // 单源视图: TByteSpan.FromStr 零拷贝 inline, 复用 bytes.ops.SpanCompare, 消裸指针算术
  Result := SpanCompare(TByteSpan.FromStr(D^.Entries^[A].Path), TByteSpan.FromStr(D^.Entries^[B].Path));
end;

function AlignUpU64(const AValue, AAlign: UInt64): UInt64; inline;
begin
  Result := nextpas.core.mem.base.AlignUp64(AValue, AAlign);
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
end;

procedure ResPackComputeLayout(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; out ALayout: TResPackLayout);
var
  N, I, J: SizeUInt;
  K: SizeUInt;
  BucketIdx, BucketCount: SizeUInt;
  BucketsHead: PSizeInt;
  SlotNext: PSizeInt;
  Probe: SizeInt;
  DedupArena: TLocalArena;
  NeedArena: SizeUInt;
  TotalInput: SizeUInt;
  StrLen: UInt64;
  StrTabBase, DataStart, Cur, EndData: UInt64;
  SlotCount: SizeUInt;
  NeedFnv: Boolean;
  DigOff: UInt64;
  Total: UInt64;
  Target: SizeUInt;
  SortData: TOrderSortData;
begin
  ResPackLayoutClear(ALayout);
  N := SizeUInt(Length(AEntries));
  ALayout.N := N;

  { ── 校验 + 上限 ── }
  TotalInput := 0;
  SetLength(ALayout.PathLens, N);
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      if not ResPackValidPath(AEntries[I].Path, True) then
        raise EResPackInvalidPath.Create('respack: invalid pack path "'
          + AEntries[I].Path + '"');
      if Length(AEntries[I].Path) > High(Word) then
        raise EResPackInvalidPath.Create('respack: path too long "'
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
  SetLength(ALayout.Order, N);
  if N > 0 then
  begin
    for I := 0 to N - 1 do
      ALayout.Order[I] := I;
    if N > 1 then
    begin
      SortData.Entries := PEntryArr(@AEntries[0]);
      SortData.Lens := PWordArr(@ALayout.PathLens[0]);
      specialize Sort<SizeUInt>(ALayout.Order, @CompareOrder, @SortData);
    end;
    for I := 1 to N - 1 do
      if CmpPath(AEntries, ALayout.PathLens, ALayout.Order[I], ALayout.Order[I-1]) = 0 then
        raise EResPackDuplicatePath.Create('respack: duplicate path "'
          + AEntries[ALayout.Order[I]].Path + '"');
  end;

  { ── fnv ── }
  NeedFnv := AOpts.Hashes or AOpts.Deduplicate;
  SetLength(ALayout.FnvBuf, N);
  if NeedFnv and (N > 0) then
    for I := 0 to N - 1 do
      ALayout.FnvBuf[I] := ResPackFnv1a32(AEntries[I].Data, AEntries[I].DataSize);

  { ── 布局：StrLen UInt64 回绕守卫（近 64K 路径极端） ── }
  StrLen := 0;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      if StrLen > High(UInt64) - UInt64(ALayout.PathLens[I]) then
        raise EResPackTooLarge.Create('respack: string table length overflow');
      StrLen := StrLen + UInt64(ALayout.PathLens[I]);
    end;
  ALayout.StrLen := StrLen;
  StrTabBase := UInt64(RESPACK_HEADER_SIZE) + UInt64(N) * RESPACK_ENTRY_SIZE;
  ALayout.StrTabBase := StrTabBase;
  if N > 0 then
    DataStart := AlignUpU64(StrTabBase + StrLen, RESPACK_DATA_ALIGN)
  else
    DataStart := StrTabBase;
  ALayout.DataStart := DataStart;

  SetLength(ALayout.EntrySlots, N);
  SetLength(ALayout.Slots, N);
  SlotCount := 0;
  Cur := DataStart;
  if AOpts.Deduplicate then
  begin
    Target := 0;
    if not TryMulSizeUInt(N, 2, Target) then
      Target := High(SizeUInt);
    { 容量策略单源：TResPackDedupBuckets.BucketCountFor via BytesNextCapacity inline 零拷贝，MIN256 MAX65536 控热点，单源防漂移 }
    BucketCount := TResPackDedupBuckets.BucketCountFor(Target);
    { 去重分桶：arena 单 slab 双数组复用，零双堆分配(原 BucketsHead 256KB+SlotNext N*8 双 SetLength 重复堆 churn)，
      单次 TLocalArena 分配(BucketCount+N)*SizeOf(SizeInt)，两视图零拷贝 inline 索引，平均 0.5 槽/桶 O(1)期望，
      10k 条目峰值 256KB+80KB 合一 336KB 单块，复用 arena 免重复堆分配，try..finally 稳定释放不丢资源。 }
    BucketsHead := nil;
    SlotNext := nil;
    DedupArena := nil;
    if N > 0 then
    begin
      if not TryMulSizeUInt(BucketCount + N, SizeUInt(SizeOf(SizeInt)), NeedArena) then
        raise EResPackTooLarge.Create('respack: dedup arena size overflow');
      DedupArena := TLocalArena.Create(NeedArena);
      try
        BucketsHead := PSizeInt(DedupArena.Alloc(BucketCount * SizeUInt(SizeOf(SizeInt))));
        SlotNext := PSizeInt(DedupArena.Alloc(N * SizeUInt(SizeOf(SizeInt))));
        if (BucketsHead = nil) or (SlotNext = nil) then
          raise EResPackTooLarge.Create('respack: dedup arena alloc failed');
        for I := 0 to BucketCount - 1 do BucketsHead[I] := -1;
        for I := 0 to N - 1 do SlotNext[I] := -1;
        for I := 0 to N - 1 do
        begin
          J := ALayout.Order[I];
          ALayout.EntrySlots[J] := SizeUInt(-1);
          BucketIdx := SizeUInt(ALayout.FnvBuf[J]) and (BucketCount - 1);
          Probe := BucketsHead[BucketIdx];
          while Probe <> -1 do
          begin
            K := SizeUInt(Probe);
            { 去重回验：bytes.ops.SpanEqual inline 零拷贝 TByteSpan 视图→MemEqual SIMD 单源，fnv+size 双重预滤后才逐字节比对，O(1) 期望；零堆拷贝，无最坏 O(n) 拷贝开销 }
            if (ALayout.Slots[K].Fnv = ALayout.FnvBuf[J])
              and (AEntries[J].DataSize = AEntries[ALayout.Slots[K].SrcIdx].DataSize)
              and ((AEntries[J].DataSize = 0)
                or nextpas.core.bytes.ops.SpanEqual(TByteSpan.Create(AEntries[J].Data, AEntries[J].DataSize),
                  TByteSpan.Create(AEntries[ALayout.Slots[K].SrcIdx].Data, AEntries[J].DataSize))) then
            begin
              ALayout.EntrySlots[J] := K;
              Break;
            end;
            Probe := SlotNext[K];
          end;
          if ALayout.EntrySlots[J] = SizeUInt(-1) then
          begin
            Cur := AlignUpU64(Cur, RESPACK_DATA_ALIGN);
            ALayout.Slots[SlotCount].Offset := Cur;
            ALayout.Slots[SlotCount].SrcIdx := J;
            if NeedFnv then
              ALayout.Slots[SlotCount].Fnv := ALayout.FnvBuf[J]
            else
              ALayout.Slots[SlotCount].Fnv := 0;
            SlotNext[SlotCount] := BucketsHead[BucketIdx];
            BucketsHead[BucketIdx] := SizeInt(SlotCount);
            ALayout.EntrySlots[J] := SlotCount;
            Cur := Cur + UInt64(AEntries[J].DataSize);
            Inc(SlotCount);
          end;
        end;
      finally
        DedupArena.Free;
      end;
    end;
  end
  else if N > 0 then
    for I := 0 to N - 1 do
    begin
      J := ALayout.Order[I];
      Cur := AlignUpU64(Cur, RESPACK_DATA_ALIGN);
      ALayout.Slots[SlotCount].Offset := Cur;
      ALayout.Slots[SlotCount].SrcIdx := J;
      if NeedFnv then
        ALayout.Slots[SlotCount].Fnv := ALayout.FnvBuf[J]
      else
        ALayout.Slots[SlotCount].Fnv := 0;
      ALayout.EntrySlots[J] := SlotCount;
      Cur := Cur + UInt64(AEntries[J].DataSize);
      Inc(SlotCount);
    end;
  ALayout.SlotCount := SlotCount;
  EndData := Cur;
  if AOpts.DigestFunc <> nil then
  begin
    DigOff := AlignUpU64(EndData, 4);
    if (DigOff = 0) and (EndData <> 0) then
      raise EResPackError.Create('respack: digest offset overflow');
    if N > High(UInt64) div RESPACK_DIGEST_SIZE then
      raise EResPackTooLarge.Create('respack: digest size overflow');
    if DigOff > High(UInt64) - UInt64(N) * RESPACK_DIGEST_SIZE then
      raise EResPackTooLarge.Create('respack: total size overflow');
    Total := DigOff + UInt64(N) * RESPACK_DIGEST_SIZE;
  end
  else
  begin
    DigOff := 0;
    Total := EndData;
  end;
  if Total > High(SizeUInt) then
    raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
  ALayout.DigOff := DigOff;
  ALayout.Total := Total;
end;

end.

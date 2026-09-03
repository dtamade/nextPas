unit nextpas.core.respack.writer.layout;

{** @desc respack 布局单源：排序/去重/对齐/槽位计算，供 writer/stream 共用。
  单源于 base/bytes.ops/collections.algorithms/mem.base。 }

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
  end;

type
  TResPackDedupBuckets = nextpas.core.respack.base.TResPackDedupBuckets; // 别名：四件套薄转发
  PSizeInt = nextpas.core.respack.base.PSizeInt; // 别名：四件套薄转发
  TResPackDistinct = nextpas.core.respack.base.TResPackDistinct; // 别名：四件套薄转发
  PResPackDistinct = nextpas.core.respack.base.PResPackDistinct; // 别名：四件套薄转发

{ Dedup arena 薄转发至 respack.base 共享底座，单源收敛。 }
procedure ResPackDedupInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ABucketCount: SizeUInt); inline;
procedure ResPackOverlapInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ADistinct: PResPackDistinct; out ABucketCount: SizeUInt); inline;
procedure ResPackDedupDone(var AArena: TLocalArena); inline;

procedure ResPackLayoutClear(var ALayout: TResPackLayout);
procedure ResPackComputeLayout(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; out ALayout: TResPackLayout);

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.collections.algorithms,
  nextpas.core.mem.base;

function CmpPath(const AEntries: array of TResPackInputEntry;
  const ALens: array of Word; AI, AJ: SizeUInt): Integer; inline;
var
  PA, PB: PByte;
  LA, LB: SizeUInt;
begin
  LA := SizeUInt(ALens[AI]);
  LB := SizeUInt(ALens[AJ]);
  if LA = 0 then PA := nil else PA := PByte(@AEntries[AI].Path[1]);
  if LB = 0 then PB := nil else PB := PByte(@AEntries[AJ].Path[1]);
  Result := ResPackCmpPath(PA, LA, PB, LB);
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

procedure ResPackDedupInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ABucketCount: SizeUInt); inline;
begin
  nextpas.core.respack.base.ResPackDedupInit(AN, AArena, ABucketsHead, ASlotNext, ABucketCount);
end;

procedure ResPackOverlapInit(const AN: SizeUInt; out AArena: TLocalArena; out ABucketsHead: PSizeInt; out ASlotNext: PSizeInt; out ADistinct: PResPackDistinct; out ABucketCount: SizeUInt); inline;
begin
  nextpas.core.respack.base.ResPackOverlapInit(AN, AArena, ABucketsHead, ASlotNext, ADistinct, ABucketCount);
end;

procedure ResPackDedupDone(var AArena: TLocalArena); inline;
begin
  nextpas.core.respack.base.ResPackDedupDone(AArena);
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
  TotalInput: SizeUInt;
  StrLen: UInt64;
  StrTabBase, DataStart, Cur, EndData: UInt64;
  SlotCount: SizeUInt;
  NeedFnv: Boolean;
  DigOff: UInt64;
  Total: UInt64;
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
  try
    SetLength(ALayout.FnvBuf, N);
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: entry count too large for host');
  end;
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
              if (ALayout.Slots[K].Fnv = ALayout.FnvBuf[J])
                and (AEntries[J].DataSize = AEntries[ALayout.Slots[K].SrcIdx].DataSize)
                and ((AEntries[J].DataSize = 0)
                  or nextpas.core.bytes.ops.SpanEqual(TByteSpan.Create(AEntries[J].Data, AEntries[J].DataSize),
                    TByteSpan.Create(AEntries[ALayout.Slots[K].SrcIdx].Data, AEntries[J].DataSize))) then
              begin
                ALayout.EntrySlots[J] := K;
                Break;
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
            ALayout.EntrySlots[J] := SlotCount;
            Cur := Cur + UInt64(AEntries[J].DataSize);
            Inc(SlotCount);
          end;
        end;
    end
    else
    begin
      BucketsHead := nil;
      SlotNext := nil;
      DedupArena := nil;
      ResPackDedupInit(N, DedupArena, BucketsHead, SlotNext, BucketCount);
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
          ResPackDedupDone(DedupArena);
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

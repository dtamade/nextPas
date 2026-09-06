unit nextpas.core.respack.writer.stream;

{** @desc respack 流式构造：两遍分段零双驻留，峰值 ~1×+64K。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base,
  nextpas.core.respack.writer.layout;

type
  { 单源于 base，兼容别名，零分叉。 }
  TResPackWriteProc = nextpas.core.respack.base.TResPackWriteProc;

{ 零填分段单源：BYTES_ZERO_PAGE 单源，≤4K 快道 inline，>4K 外联 Loop；
  writer/dirsource 双 Emit 共用，消两套 WriteZeros 镜像。 }
procedure ResPackWriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64); inline;
{ 头区分片直写单源：≤64K 单次 FillHead 快道，>64K 走 64K chunk（header/index/string 逐段灌 chunk），
  writer 内存背与 dirsource 文件背共用，峰值 64K 封顶；BytesCopy 单源 inline 零拷贝。 }
procedure ResPackEmitHead(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AWrite: TResPackWriteProc);
{ 哈希段分片直写单源：HashBase 间隙零填 + FillHashRange 8192 桶/片分片，峰值 64K 封顶，
  无桶数×8 全量具化；writer/dirsource 双 Emit 共用，INV-R5 单源。 }
procedure ResPackEmitHashSegment(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AWrite: TResPackWriteProc; var ACur: UInt64);
{ 流式两遍构造：与 ResPackBuild 同确定性（INV-R5），分段经 AWrite 回调输出，
  不一次性持有 Total 输出缓冲。 }
procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
{ 已算布局直排：复用调用方持有的 Layout，零重复排序/fnv/去重，供内存版单布局复用。 }
procedure ResPackEmitLayout(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AWrite: TResPackWriteProc);
{ 内存 Sink 单源 Emit 封装：已算布局直写堆 blob，GetMem 单次+BytesCopy 单源
  inline 零拷贝直填+Off 校验，异常 FreeMem 不丢；writer/dirsource 双 Build 共用，
  消三处复制。 }
function ResPackBuildLayoutBlob(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout): TResPackBlob;
{ 内存组装单源：ComputeLayout 1×（排序/fnv/去重）+ BuildLayoutBlob 直排堆 blob；
  writer/dirsource 双 Build 共用，禁 Size+BuildStream 双算；布局经 try..finally
  Clear 释放不丢，峰值 ~1×+头；冷路径不 inline，零拷贝经 BytesCopy 单源。 }
function ResPackBuildBlobFromEntries(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
{ 纯预取总长：独立 Compute 1×；需随后输出时请 Compute 1× + ResPackLayoutTotal/Emit/BuildLayoutBlob 直排，勿 Size + BuildStream 连调致 2× 排序/去重。 }
function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64;
{ 已算布局零成本总长：读 ALayout.Total，无排序/fnv/去重，供 Compute 1× 后预取复用，inline。 }
function ResPackLayoutTotal(const ALayout: TResPackLayout): UInt64; inline;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.respack.writer.builder;

const
  RESPACK_WRITER_HEAD_CHUNK = nextpas.core.respack.base.RESPACK_WRITER_HEAD_CHUNK;

{ 零填分段：BYTES_ZERO_PAGE 单源，≤4K 快道 inline，>4K 外联 Loop }
procedure WriteZerosLoop(const AWrite: TResPackWriteProc; ACount: UInt64);
var
  N: UInt64;
  L: SizeUInt;
begin
  N := ACount;
  while N > 0 do
  begin
    if N >= BYTES_ZERO_PAGE_SIZE then L := BYTES_ZERO_PAGE_SIZE else L := SizeUInt(N);
    AWrite(@BYTES_ZERO_PAGE[0], L);
    Dec(N, L);
  end;
end;

procedure ResPackWriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64); inline;
begin
  if ACount = 0 then Exit;
  if ACount <= BYTES_ZERO_PAGE_SIZE then
  begin
    AWrite(@BYTES_ZERO_PAGE[0], SizeUInt(ACount));
    Exit;
  end;
  WriteZerosLoop(AWrite, ACount);
end;

{ 内部别名：历史 WriteZeros 调用收敛至 ResPackWriteZeros 单源，inline 零开销。 }
procedure WriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64); inline;
begin
  ResPackWriteZeros(AWrite, ACount);
end;

function ResPackLayoutTotal(const ALayout: TResPackLayout): UInt64; inline;
begin
  Result := ALayout.Total;
end;

procedure ResPackEmitHead(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AWrite: TResPackWriteProc);
var
  N, II, JJ: SizeUInt;
  HeadBuf: TBytes;
  Head: PByte;
  HeadSize: UInt64;
  CurOff: UInt64;
  Pad: UInt64;
  ChunkCap: SizeUInt;
  ChunkPos: SizeUInt;
  procedure FlushHead; inline;
  begin
    if ChunkPos > 0 then
    begin
      AWrite(@HeadBuf[0], ChunkPos);
      ChunkPos := 0;
    end;
  end;
  procedure WriteHeadBytes(const ASrc: Pointer; ALen: SizeUInt);
  var
    Src: PByte;
    Rem, CopyNow: SizeUInt;
  begin
    if (ASrc = nil) or (ALen = 0) then Exit;
    if ALen <= ChunkCap - ChunkPos then
    begin
      BytesCopy(@HeadBuf[ChunkPos], ASrc, ALen);
      Inc(ChunkPos, ALen);
      if ChunkPos = ChunkCap then FlushHead;
      Exit;
    end;
    Src := PByte(ASrc);
    Rem := ALen;
    while Rem > 0 do
    begin
      if ChunkPos = ChunkCap then FlushHead;
      CopyNow := Rem;
      if CopyNow > ChunkCap - ChunkPos then CopyNow := ChunkCap - ChunkPos;
      BytesCopy(@HeadBuf[ChunkPos], Src, CopyNow);
      Inc(ChunkPos, CopyNow);
      Inc(Src, CopyNow);
      Dec(Rem, CopyNow);
      if ChunkPos = ChunkCap then FlushHead;
    end;
  end;
begin
  HeadSize := ALayout.DataStart;
  if HeadSize = 0 then Exit;
  { 头块大小 = DataStart；≤64K 单次 SetLength+FillHead 快道，>64K 走 64K chunk
    直写，内存版与流式版逐字节一致由 roundtrip 门禁锁定；峰值 64K 封顶。 }
  if HeadSize <= UInt64(RESPACK_WRITER_HEAD_CHUNK) then
  begin
    SetLength(HeadBuf, SizeUInt(HeadSize));
    try
      Head := @HeadBuf[0];
      ResPackWriterFillHead(Head, AEntries, AOpts, ALayout);
      AWrite(Head, SizeUInt(HeadSize));
    finally
      HeadBuf := nil;
    end;
    Exit;
  end;
  ChunkCap := RESPACK_WRITER_HEAD_CHUNK;
  SetLength(HeadBuf, ChunkCap);
  try
    ChunkPos := 0;
    N := ALayout.N;
    ResPackWriterFillHeader40(@HeadBuf[ChunkPos], AOpts, ALayout);
    Inc(ChunkPos, RESPACK_HEADER_SIZE);
    CurOff := ALayout.StrTabBase;
    if N > 0 then
      for II := 0 to N - 1 do
      begin
        if ChunkCap - ChunkPos < RESPACK_ENTRY_SIZE then FlushHead;
        JJ := ALayout.Order[II];
        ResPackWriterFillEntry40(@HeadBuf[ChunkPos], AEntries, AOpts, ALayout, JJ, CurOff);
        Inc(ChunkPos, RESPACK_ENTRY_SIZE);
        Inc(CurOff, ALayout.PathLens[JJ]);
        if ChunkPos = ChunkCap then FlushHead;
      end;
    if N > 0 then
      for II := 0 to N - 1 do
      begin
        JJ := ALayout.Order[II];
        if ALayout.PathLens[JJ] > 0 then
          WriteHeadBytes(PByte(@AEntries[JJ].Path[1]), ALayout.PathLens[JJ]);
      end;
    FlushHead;
    Pad := 0;
    if ALayout.DataStart > ALayout.StrTabBase + ALayout.StrLen then
      Pad := ALayout.DataStart - (ALayout.StrTabBase + ALayout.StrLen);
    if Pad > 0 then
      ResPackWriteZeros(AWrite, Pad);
  finally
    HeadBuf := nil;
  end;
end;

procedure ResPackEmitHashSegment(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AWrite: TResPackWriteProc; var ACur: UInt64);
var
  HashChunk: TBytes;
  HStart, HCount, HCapBuckets: SizeUInt;
begin
  if ALayout.HashBuckets = 0 then Exit;
  if ALayout.HashBase > ACur then
    ResPackWriteZeros(AWrite, ALayout.HashBase - ACur);
  if ALayout.HashBuckets > High(SizeUInt) div SizeUInt(RESPACK_HASH_ENTRY_SIZE) then
    raise EResPackTooLarge.Create('respack: hash segment too large for host');
  HCapBuckets := RESPACK_WRITER_HEAD_CHUNK div SizeUInt(RESPACK_HASH_ENTRY_SIZE);
  if HCapBuckets = 0 then HCapBuckets := 1;
  try
    if ALayout.HashBuckets < HCapBuckets then
      SetLength(HashChunk, ALayout.HashBuckets * SizeUInt(RESPACK_HASH_ENTRY_SIZE))
    else
      SetLength(HashChunk, HCapBuckets * SizeUInt(RESPACK_HASH_ENTRY_SIZE));
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: hash segment too large for host');
  end;
  try
    HStart := 0;
    while HStart < ALayout.HashBuckets do
    begin
      HCount := ALayout.HashBuckets - HStart;
      if HCount > HCapBuckets then HCount := HCapBuckets;
      ResPackWriterFillHashRange(@HashChunk[0], AEntries, AOpts, ALayout, HStart, HCount);
      AWrite(@HashChunk[0], HCount * SizeUInt(RESPACK_HASH_ENTRY_SIZE));
      Inc(HStart, HCount);
    end;
  finally
    HashChunk := nil;
  end;
  ACur := ALayout.Total;
end;

{ 外部 Layout 校验：槽位单调/索引越界/回绕前置拒绝，逆序 Gap 下溢不再落入 UInt64 相减；含循环禁 inline。 }
procedure ValidateEmitLayout(const AEntries: array of TResPackInputEntry;
  const ALayout: TResPackLayout; const AHasDigest: Boolean);
var
  N: SizeUInt;
  I, J, S, K: SizeUInt;
  Cur, EndCur: UInt64;
begin
  N := SizeUInt(Length(AEntries));
  if ALayout.N <> N then
    raise EResPackError.Create('respack.stream: layout entry count mismatch');
  if SizeUInt(Length(ALayout.Order)) <> N then
    raise EResPackError.Create('respack.stream: layout order length mismatch');
  if SizeUInt(Length(ALayout.PathLens)) <> N then
    raise EResPackError.Create('respack.stream: layout path lens mismatch');
  if SizeUInt(Length(ALayout.EntrySlots)) <> N then
    raise EResPackError.Create('respack.stream: layout entry-slot mismatch');
  if ALayout.SlotCount > SizeUInt(Length(ALayout.Slots)) then
    raise EResPackError.Create('respack.stream: layout slot count exceeds slots');
  if ALayout.DataStart > ALayout.Total then
    raise EResPackError.Create('respack.stream: layout data start exceeds total');
  if ALayout.StrTabBase > ALayout.DataStart then
    raise EResPackError.Create('respack.stream: layout string base exceeds data start');
  if ALayout.HashBuckets > 0 then
  begin
    if SizeUInt(Length(ALayout.HashSlotIdx)) <> ALayout.HashBuckets then
      raise EResPackError.Create('respack.stream: layout hash slots mismatch');
    if ALayout.HashBase > ALayout.Total then
      raise EResPackError.Create('respack.stream: layout hash base exceeds total');
    if ALayout.HashBuckets > High(SizeUInt) div SizeUInt(RESPACK_HASH_ENTRY_SIZE) then
      raise EResPackTooLarge.Create('respack.stream: hash segment too large');
    if ALayout.HashBase + UInt64(ALayout.HashBuckets) * RESPACK_HASH_ENTRY_SIZE <> ALayout.Total then
      raise EResPackError.Create('respack.stream: layout hash end mismatch');
  end
  else if ALayout.HashBase <> 0 then
    raise EResPackError.Create('respack.stream: layout hash base without buckets');
  if (N = 0) and (ALayout.SlotCount <> 0) then
    raise EResPackError.Create('respack.stream: layout slots without entries');
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      if ALayout.Order[I] >= N then
        raise EResPackError.Create('respack.stream: layout order index out of range');
      J := ALayout.Order[I];
      S := ALayout.EntrySlots[J];
      if S >= ALayout.SlotCount then
        raise EResPackError.Create('respack.stream: layout entry-slot out of range');
    end;
  Cur := ALayout.DataStart;
  if ALayout.SlotCount > 0 then
    for K := 0 to ALayout.SlotCount - 1 do
    begin
      J := ALayout.Slots[K].SrcIdx;
      if J >= N then
        raise EResPackError.Create('respack.stream: layout slot source out of range');
      if ALayout.Slots[K].Offset < Cur then
        raise EResPackError.Create('respack.stream: layout slot offsets not monotonic');
      if ALayout.Slots[K].Offset > ALayout.Total then
        raise EResPackError.Create('respack.stream: layout slot offset exceeds total');
      if UInt64(AEntries[J].DataSize) > High(UInt64) - ALayout.Slots[K].Offset then
        raise EResPackError.Create('respack.stream: layout slot end overflow');
      EndCur := ALayout.Slots[K].Offset + UInt64(AEntries[J].DataSize);
      if EndCur > ALayout.Total then
        raise EResPackError.Create('respack.stream: layout slot end exceeds total');
      Cur := EndCur;
    end;
  if AHasDigest then
  begin
    if ALayout.DigOff > ALayout.Total then
      raise EResPackError.Create('respack.stream: layout digest offset exceeds total');
    if (ALayout.Total - ALayout.DigOff) div UInt64(RESPACK_DIGEST_SIZE) < UInt64(N) then
      raise EResPackError.Create('respack.stream: layout digest range too small');
  end;
end;

procedure ResPackEmitLayout(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AWrite: TResPackWriteProc);
var
  N, I, J, K, S: SizeUInt;
  Cur: UInt64;
  Gap: UInt64;
  DigestTmp: TResPackDigest;
  SlotDigests: array of TResPackDigest;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.stream: Write proc is nil');
  ValidateEmitLayout(AEntries, ALayout, Assigned(AOpts.DigestFunc));
  N := ALayout.N;
  { 头区分片单源于 ResPackEmitHead（≤64K 快道/>64K chunk，峰值 64K 封顶）。 }
  ResPackEmitHead(AEntries, AOpts, ALayout, AWrite);

  { data 槽位：按 Offset 顺序分段零拷贝直写，槽间隙零填 }
  Cur := ALayout.DataStart;
  if ALayout.SlotCount > 0 then
    for K := 0 to ALayout.SlotCount - 1 do
    begin
      Gap := ALayout.Slots[K].Offset - Cur;
      if Gap > 0 then
        ResPackWriteZeros(AWrite, Gap);
      J := ALayout.Slots[K].SrcIdx;
      if AEntries[J].DataSize > 0 then
        AWrite(AEntries[J].Data, AEntries[J].DataSize);
      Cur := ALayout.Slots[K].Offset + UInt64(AEntries[J].DataSize);
    end;

  { digest 对齐间隙 }
  if AOpts.DigestFunc <> nil then
  begin
    if ALayout.DigOff > Cur then
      ResPackWriteZeros(AWrite, ALayout.DigOff - Cur);
    Cur := ALayout.DigOff;
    { 摘要与 index 同序（FORMAT.md）：重复包按槽单算经 EntrySlots 直排复用，
      无重复零堆快道；BytesZero 单源 inline，槽摘要指针零拷贝直写，INV-R5 一致。 }
    if N > 0 then
      if (ALayout.SlotCount > 0) and (ALayout.SlotCount < N) then
      begin
        try
          SetLength(SlotDigests, ALayout.SlotCount);
        except
          on E: EOutOfMemory do
            raise EResPackTooLarge.Create('respack: digest cache too large for host');
        end;
        try
          for K := 0 to ALayout.SlotCount - 1 do
          begin
            J := ALayout.Slots[K].SrcIdx;
            BytesZero(@SlotDigests[K][0], RESPACK_DIGEST_SIZE);
            AOpts.DigestFunc(AEntries[J].Data, AEntries[J].DataSize, @SlotDigests[K][0]);
          end;
          for I := 0 to N - 1 do
          begin
            J := ALayout.Order[I];
            S := ALayout.EntrySlots[J];
            AWrite(@SlotDigests[S][0], RESPACK_DIGEST_SIZE);
          end;
        finally
          SlotDigests := nil;
        end;
      end
      else
        for I := 0 to N - 1 do
        begin
          J := ALayout.Order[I];
          BytesZero(@DigestTmp[0], RESPACK_DIGEST_SIZE);
          AOpts.DigestFunc(AEntries[J].Data, AEntries[J].DataSize, @DigestTmp[0]);
          AWrite(@DigestTmp[0], RESPACK_DIGEST_SIZE);
        end;
    if N > 0 then
      Cur := ALayout.DigOff + UInt64(N) * RESPACK_DIGEST_SIZE;
  end;

  { 哈希段分片单源于 ResPackEmitHashSegment（8192 桶/片，峰值 64K 封顶）。 }
  ResPackEmitHashSegment(AEntries, AOpts, ALayout, AWrite, Cur);
end;

procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
var
  L: TResPackLayout;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.stream: Write proc is nil');
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    ResPackEmitLayout(AEntries, AOpts, L, AWrite);
  finally
    ResPackLayoutClear(L);
  end;
end;

function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64;
var
  L: TResPackLayout;
begin
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    Result := ResPackLayoutTotal(L);
  finally
    ResPackLayoutClear(L);
  end;
end;

function ResPackBuildLayoutBlob(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout): TResPackBlob;
var
  Total: UInt64;
  Buf: PByte;
  Off: SizeUInt;
  Sink: TResPackWriteProc;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  Total := ALayout.Total;
  if Total = 0 then Exit;
  if Total > High(SizeUInt) then
    raise EResPackTooLarge.Create('respack: blob too large for host SizeUInt');
  Buf := nil;
  try
    GetMem(Buf, SizeUInt(Total));
  except
    on E: EOutOfMemory do
      raise EResPackTooLarge.Create('respack: blob too large for host');
  end;
  Off := 0;
  Sink :=
    procedure(const AData: PByte; const ASize: SizeUInt)
    var
      Rem: SizeUInt;
    begin
      if ASize = 0 then Exit;
      if AData = nil then
        raise EResPackError.Create('respack: stream chunk has nil data');
      if Off > SizeUInt(Total) then
        raise EResPackError.Create('respack: stream size mismatch');
      Rem := SizeUInt(Total) - Off;
      if ASize > Rem then
        raise EResPackError.Create('respack: stream size mismatch');
      BytesCopy(Buf + Off, AData, ASize);
      Inc(Off, ASize);
    end; { 越界前置 guard，布局/发射分叉即拒，零堆越界写；BytesCopy inline 快道 }
  try
    ResPackEmitLayout(AEntries, AOpts, ALayout, Sink);
    if Off <> SizeUInt(Total) then
      raise EResPackError.Create('respack: stream size mismatch');
    Result.Data := Buf;
    Result.Size := SizeUInt(Total);
    Result.Owned := True;
    Buf := nil;
  except
    if Buf <> nil then
      FreeMem(Buf);
    raise;
  end;
end;

function ResPackBuildBlobFromEntries(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
var
  L: TResPackLayout;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    Result := ResPackBuildLayoutBlob(AEntries, AOpts, L);
  finally
    ResPackLayoutClear(L);
  end;
end;

end.

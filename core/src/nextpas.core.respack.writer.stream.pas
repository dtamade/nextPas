unit nextpas.core.respack.writer.stream;

{** @desc respack 流式构造：两遍分段零双驻留，512MB 峰值 ~1×+64K（chunk 分片直写）。
  首遍复用 writer.layout 单源计算 Total/槽位/去重（INV-R5 确定性同 ResPackBuild），
  次遍分段经 AWrite 回调：头分片直写（≤64K CHUNK 增量切片，≤8MiB 家族阈值自动分段；header/index/string+对齐零填经 TBytes RAII 托管 chunk 缓冲，超 8MiB 自动头分段，不再阈值拒绝；BYTES_ZERO_PAGE 单源零拷贝）→ 槽间隙零填(WriteZeros 小间隙 inline 快道/4K零页零拷贝 + 大间隙外联 Loop) → data 零拷贝 Move 分段 → digest，
  零额外 Total 缓冲；ResPackBuildStreamSize 仅首遍取 Total 零分配；超大规模头分段能力反哺 mem.memory_map/io.mapped owner，不私自引入 FS/mmap。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base;

type
  TResPackWriteProc = reference to procedure(const AData: PByte; const ASize: SizeUInt);

{ 流式两遍构造：与 ResPackBuild 同确定性（INV-R5），分段经 AWrite 回调输出，
  不一次性持有 Total 输出缓冲；调用方提供流/文件句柄的写入闭包即可。 }
procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.respack.writer.builder,
  nextpas.core.respack.writer.layout;

const
  { 头峰值守卫：复用 RESPACK_MAX_INPUT_BYTES 家族内聚（512MiB/64=8MiB），12.8M 条目时 HeadSize=40+N*40+StrLen 可达数百 MB；
    分片阈值与增量切片：HEAD_CHUNK=64K 增量切片零拷贝直写，峰值 ~1×+64K；超 8MiB 自动头分段，不再阈值拒绝；
    超大规模头分段能力反哺 mem.memory_map/io.mapped owner，不私自引入 FS/mmap。 }
  RESPACK_STREAM_MAX_HEAD: SizeUInt = RESPACK_MAX_INPUT_BYTES div 64;
  RESPACK_STREAM_HEAD_CHUNK: SizeUInt = 64 * 1024;

{ 零填充分段写入：复用 bytes.ops 全局零页单源(.bss 4K)，无栈分配/无重复 FillChar，零拷贝分段直写；inline 热路径 + 小间隙单回调快道(≤4K)，大间隙4K切片控单次syscall尺寸；外联守 design-conventions §2 红线2 }
function HasDigestOpt(const AOpts: TResPackBuildOptions): Boolean; inline;
begin
  Result := Assigned(AOpts.DigestFunc);
end;

{ 大间隙零填外联体：含 while 循环，禁 inline 守 §2 红线2，控 I-Cache 复制膨胀；由 inline 快道 delegat }
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

{ 小间隙快道 inline：≤4K 单次 AWrite 零拷贝，热点对齐 16/4 典型≤15 消除调用开销；>4K 外联 Loop 守红线2 }
procedure WriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64); inline;
begin
  if ACount = 0 then Exit;
  { perf: inline消除调用开销 + 零拷贝 BYTES_ZERO_PAGE 单源；小间隙单回调快道避免while开销，大间隙委托外联 Loop 复用同页零拷贝 }
  if ACount <= BYTES_ZERO_PAGE_SIZE then
  begin
    AWrite(@BYTES_ZERO_PAGE[0], SizeUInt(ACount));
    Exit;
  end;
  WriteZerosLoop(AWrite, ACount);
end;

procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
var
  L: TResPackLayout;
  N, I, J, K: SizeUInt;
  Cur: UInt64;
  HeadBuf: TBytes;
  Head: PByte;
  HeadSize: UInt64;
  Gap: UInt64;
  DigestTmp: TResPackDigest;
  ChunkCap: SizeUInt;
  ChunkPos: SizeUInt;
  { head chunked helpers — inline 零拷贝经 bytes.ops 单源，chunk 复用 TBytes RAII，不私自引入 FS/mmap }
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
  procedure WriteHeadChunked;
  var
    II, JJ: SizeUInt;
    CurOff: UInt64;
    HdrFlags: UInt32;
    EntFlags: Word;
    TmpHdr: array[0..39] of Byte;
    TmpEnt: array[0..39] of Byte;
    Pad: UInt64;
  begin
    ChunkCap := RESPACK_STREAM_HEAD_CHUNK;
    SetLength(HeadBuf, ChunkCap);
    ChunkPos := 0;
    N := L.N;
    { header 40B — WrU*LE 单源 via respack.base inline 零拷贝，BytesZero 单源清零 }
    BytesZero(@TmpHdr[0], 40);
    TmpHdr[0] := Ord('N'); TmpHdr[1] := Ord('P'); TmpHdr[2] := Ord('R'); TmpHdr[3] := Ord('S');
    WrU32LE(@TmpHdr[4], RESPACK_VERSION);
    HdrFlags := 0;
    if AOpts.Hashes then HdrFlags := HdrFlags or RESPACK_FLAG_HASHED;
    if AOpts.DigestFunc <> nil then HdrFlags := HdrFlags or RESPACK_FLAG_DIGESTED;
    WrU32LE(@TmpHdr[8], HdrFlags);
    WrU32LE(@TmpHdr[12], UInt32(N));
    WrU64LE(@TmpHdr[16], UInt64(RESPACK_HEADER_SIZE));
    WrU64LE(@TmpHdr[24], L.DigOff);
    WrU64LE(@TmpHdr[32], L.Total);
    WriteHeadBytes(@TmpHdr[0], 40);
    { index 段：N*40 零拷贝分片直写，WrU*LE/BytesCopy 单源 inline }
    CurOff := L.StrTabBase;
    if N > 0 then
      for II := 0 to N - 1 do
      begin
        JJ := L.Order[II];
        BytesZero(@TmpEnt[0], 40);
        WrU32LE(@TmpEnt[0], UInt32(CurOff - L.StrTabBase));
        WrU16LE(@TmpEnt[4], L.PathLens[JJ]);
        EntFlags := 0;
        if AOpts.Hashes then EntFlags := RESPACK_EFLAG_HASHED;
        WrU16LE(@TmpEnt[6], EntFlags);
        WrU64LE(@TmpEnt[8], L.Slots[L.EntrySlots[JJ]].Offset);
        WrU64LE(@TmpEnt[16], UInt64(AEntries[JJ].DataSize));
        WrU64LE(@TmpEnt[24], UInt64(AEntries[JJ].ModTime));
        if AOpts.Hashes then WrU32LE(@TmpEnt[32], L.FnvBuf[JJ]);
        TmpEnt[36] := Byte(RESPACK_CODEC_STORE);
        WriteHeadBytes(@TmpEnt[0], 40);
        Inc(CurOff, L.PathLens[JJ]);
      end;
    { string table 段：路径按 Order 顺序零拷贝分片直写，BytesCopy 单源 }
    if N > 0 then
      for II := 0 to N - 1 do
      begin
        JJ := L.Order[II];
        if L.PathLens[JJ] > 0 then
          WriteHeadBytes(Pointer(AEntries[JJ].Path), L.PathLens[JJ]);
      end;
    FlushHead;
    { 对齐填充：StrTabBase+StrLen → DataStart，零页单源 WriteZeros 零拷贝分段 }
    Pad := 0;
    if L.DataStart > L.StrTabBase + L.StrLen then
      Pad := L.DataStart - (L.StrTabBase + L.StrLen);
    if Pad > 0 then
      WriteZeros(AWrite, Pad);
  end;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.stream: Write proc is nil');
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    N := L.N;
    HeadSize := L.DataStart;
    { 头块：header + index + string table（含对齐填充），大小 = DataStart（空包 40），
      峰值 ~1×+64K（CHUNK 分片直写，≤8MiB 家族阈值自动分段，不再阈值拒绝；超大规模头分段能力反哺 mem.memory_map/io.mapped owner），不含 Total；
      TBytes RAII 托管自动释放，异常安全无 GetMem/FreeMem手动路径；inline零拷贝证据见bytes.ops/builder。
      分片策略：≤64K 单次 SetLength+ResPackWriterFillHead 单批零拷贝快道；>64K 走 64K CHUNK 增量切片直写（BytesCopy/WrU*LE/BYTES_ZERO_PAGE 单源），单次 AWrite 控 syscall，峰值稳定。 }
    if HeadSize = 0 then
    begin
      { 空包 header 仍为 40，已在 L.DataStart=40 覆盖，不会进此分支；防御性保留 }
    end
    else if HeadSize <= UInt64(RESPACK_STREAM_HEAD_CHUNK) then
    begin
      SetLength(HeadBuf, SizeUInt(HeadSize));
      if HeadSize > 0 then Head := @HeadBuf[0] else Head := nil;
      ResPackWriterFillHead(Head, AEntries, AOpts, L);
      if HeadSize > 0 then AWrite(Head, SizeUInt(HeadSize));
    end
    else
    begin
      { 头分段直写：64K CHUNK 增量切片，零拷贝分段经 AWrite；峰值 ~1×+64K，支持数百 MB 头超大规模；能力反哺 mem.memory_map/io.mapped，不私自引入 FS/mmap }
      WriteHeadChunked;
    end;

    { data 槽位：按 Offset 顺序分段零拷贝直写，槽间隙零填；峰值 1×+64K，无 Total 双驻留。 }
    Cur := HeadSize;
    if L.SlotCount > 0 then
      for K := 0 to L.SlotCount - 1 do
      begin
        Gap := L.Slots[K].Offset - Cur;
        if Gap > 0 then
          WriteZeros(AWrite, Gap);
        J := L.Slots[K].SrcIdx;
        if AEntries[J].DataSize > 0 then
          AWrite(AEntries[J].Data, AEntries[J].DataSize);
        Cur := L.Slots[K].Offset + UInt64(AEntries[J].DataSize);
      end;

    { digest 对齐间隙 }
    if AOpts.DigestFunc <> nil then
    begin
      if L.DigOff > Cur then
        WriteZeros(AWrite, L.DigOff - Cur);
      if N > 0 then
        for I := 0 to N - 1 do
        begin
          BytesZero(@DigestTmp[0], RESPACK_DIGEST_SIZE);
          AOpts.DigestFunc(AEntries[I].Data, AEntries[I].DataSize, @DigestTmp[0]);
          AWrite(@DigestTmp[0], RESPACK_DIGEST_SIZE);
        end;
    end;
  finally
    ResPackLayoutClear(L);
  end;
end;

function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64;
var
  L: TResPackLayout;
begin
  { 预计算 Total 零分配：复用布局单源首遍，不 GetMem 全量 blob。 }
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    Result := L.Total;
  finally
    ResPackLayoutClear(L);
  end;
end;

end.

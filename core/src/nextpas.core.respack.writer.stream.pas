unit nextpas.core.respack.writer.stream;

{** @desc respack 流式构造：两遍分段零双驻留，峰值 ~1×+64K。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base;

type
  TResPackWriteProc = reference to procedure(const AData: PByte; const ASize: SizeUInt);

{ 流式两遍构造：与 ResPackBuild 同确定性（INV-R5），分段经 AWrite 回调输出，
  不一次性持有 Total 输出缓冲。 }
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
  RESPACK_STREAM_HEAD_CHUNK: SizeUInt = 64 * 1024;

{ 零填分段：BYTES_ZERO_PAGE 单源，≤4K 快道 inline，>4K 外联 Loop }
function HasDigestOpt(const AOpts: TResPackBuildOptions): Boolean; inline;
begin
  Result := Assigned(AOpts.DigestFunc);
end;

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

procedure WriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64); inline;
begin
  if ACount = 0 then Exit;
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
    Pad: UInt64;
  begin
    ChunkCap := RESPACK_STREAM_HEAD_CHUNK;
    SetLength(HeadBuf, ChunkCap);
    ChunkPos := 0;
    N := L.N;
    { header/index 直写至 chunk，复用 builder 单源，无中间 40B Tmp 拷贝 }
    ResPackWriterFillHeader40(@HeadBuf[ChunkPos], AOpts, L);
    Inc(ChunkPos, RESPACK_HEADER_SIZE);
    CurOff := L.StrTabBase;
    if N > 0 then
      for II := 0 to N - 1 do
      begin
        if ChunkCap - ChunkPos < RESPACK_ENTRY_SIZE then FlushHead;
        JJ := L.Order[II];
        ResPackWriterFillEntry40(@HeadBuf[ChunkPos], AEntries, AOpts, L, JJ, CurOff);
        Inc(ChunkPos, RESPACK_ENTRY_SIZE);
        Inc(CurOff, L.PathLens[JJ]);
        if ChunkPos = ChunkCap then FlushHead;
      end;
    { string table：路径按 Order 顺序零拷贝分片直写，BytesCopy 单源 }
    if N > 0 then
      for II := 0 to N - 1 do
      begin
        JJ := L.Order[II];
        if L.PathLens[JJ] > 0 then
          WriteHeadBytes(Pointer(AEntries[JJ].Path), L.PathLens[JJ]);
      end;
    FlushHead;
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
    { 头块大小 = DataStart；≤64K 单次 SetLength+ResPackWriterFillHead 快道，>64K 走 64K chunk 直写 }
    if HeadSize = 0 then
    begin
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
      WriteHeadChunked;
    end;

    { data 槽位：按 Offset 顺序分段零拷贝直写，槽间隙零填 }
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
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    Result := L.Total;
  finally
    ResPackLayoutClear(L);
  end;
end;

end.

unit nextpas.core.respack.writer.builder;

{** @desc respack writer 头/index/string 单源 builder：消除 writer/stream 重复。
  布局单源于 writer.layout；BytesCopy/BytesZero/WrU*LE 单源。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base,
  nextpas.core.respack.writer.layout;

{ header 40B 单源：BytesZero/WrU*LE inline 零拷贝，供 writer/stream 复用 }
procedure ResPackWriterFillHeader40(const ADst: PByte;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout); inline;
{ entry 40B 单源：BytesZero/WrU*LE/Codec 单源，供 stream 64K 直写复用，无中间 40B 拷贝 }
procedure ResPackWriterFillEntry40(const ADst: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const ASrcIdx: SizeUInt; const ACurStrOff: UInt64); inline;

{ 哈希段单源：桶→(fnv32, index) 8B LE 直排，空桶 fnv=0/idx=$FFFFFFFF；
  fnv 取布局灌桶缓存（同字节单掃，发射零重算），布局只定桶位+fnv。
  memory/stream 双 Emit 共用，INV-R5 确定性单点。调用方保证 ADst ≥ 桶数×8 可写。 }
procedure ResPackWriterFillHash(const ADst: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout);
{ 哈希段分片单源：[AStartBucket,AStartBucket+ABucketCount) 区间直排，供 stream 64K 分片复用；
  fnv 取布局灌桶缓存 HashFnv（同字节单掃，发射零重算；手造布局缺缓存时回退重算）；
  全量 FillHash 经此单点，INV-R5 单源。调用方保证 ADst ≥ ABucketCount×8 可写。 }
procedure ResPackWriterFillHashRange(const ADst: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AStartBucket, ABucketCount: SizeUInt);

{ 单源填充 Head 区域：header(40) + index(N*40) + string table + 对齐填充 = DataStart。
  header/entry 各自 40B 内 BytesZero 自含（FillHeader40/FillEntry40 单源 inline），
  串表逐字节全覆盖拷贝，故仅尾部对齐 Pad 需 BytesZero，无全量 DataStart memset。
  调用方保证 AHead 指向至少 DataStart 字节可写。 }
procedure ResPackWriterFillHead(const AHead: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions;
  const ALayout: TResPackLayout);

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops;

procedure ResPackWriterFillHeader40(const ADst: PByte;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout); inline;
var
  HdrFlags: UInt32;
begin
  BytesZero(ADst, RESPACK_HEADER_SIZE);
  ADst[0] := Ord('N'); ADst[1] := Ord('P'); ADst[2] := Ord('R'); ADst[3] := Ord('S');
  WrU32LE(ADst + 4, RESPACK_VERSION);
  HdrFlags := 0;
  if AOpts.Hashes then HdrFlags := HdrFlags or RESPACK_FLAG_HASHED;
  if AOpts.DigestFunc <> nil then HdrFlags := HdrFlags or RESPACK_FLAG_DIGESTED;
  if AOpts.HashIndex and (ALayout.HashBuckets > 0) then
    HdrFlags := HdrFlags or RESPACK_FLAG_HASHINDEX;
  WrU32LE(ADst + 8, HdrFlags);
  WrU32LE(ADst + 12, UInt32(ALayout.N));
  WrU64LE(ADst + 16, UInt64(RESPACK_HEADER_SIZE));
  WrU64LE(ADst + 24, ALayout.DigOff);
  WrU64LE(ADst + 32, ALayout.Total);
end;

procedure ResPackWriterFillEntry40(const ADst: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const ASrcIdx: SizeUInt; const ACurStrOff: UInt64); inline;
var
  EntFlags: Word;
begin
  BytesZero(ADst, RESPACK_ENTRY_SIZE);
  WrU32LE(ADst + 0, UInt32(ACurStrOff - ALayout.StrTabBase));
  WrU16LE(ADst + 4, ALayout.PathLens[ASrcIdx]);
  EntFlags := 0;
  if AOpts.Hashes then EntFlags := RESPACK_EFLAG_HASHED;
  WrU16LE(ADst + 6, EntFlags);
  WrU64LE(ADst + 8, ALayout.Slots[ALayout.EntrySlots[ASrcIdx]].Offset);
  WrU64LE(ADst + 16, UInt64(AEntries[ASrcIdx].DataSize));
  WrU64LE(ADst + 24, UInt64(AEntries[ASrcIdx].ModTime));
  if AOpts.Hashes then WrU32LE(ADst + 32, ALayout.FnvBuf[ASrcIdx]);
  ADst[36] := Byte(RESPACK_CODEC_STORE);
end;

procedure ResPackWriterFillHead(const AHead: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions;
  const ALayout: TResPackLayout);
var
  N, I, J: SizeUInt;
  Cur: UInt64;
  Pad: UInt64;
begin
  ResPackWriterFillHeader40(AHead, AOpts, ALayout);
  Cur := ALayout.StrTabBase;
  N := ALayout.N;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      J := ALayout.Order[I];
      ResPackWriterFillEntry40(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE,
        AEntries, AOpts, ALayout, J, Cur);
      if ALayout.PathLens[J] > 0 then
        BytesCopy(AHead + Cur, Pointer(AEntries[J].Path), ALayout.PathLens[J]);
      Inc(Cur, ALayout.PathLens[J]);
    end;
  { 尾部对齐 Pad 单点零填：header/entry/串表已全覆盖，无全量 memset 快道开销；
    BytesZero 单源 inline。 }
  if ALayout.DataStart > ALayout.StrTabBase + ALayout.StrLen then
  begin
    Pad := ALayout.DataStart - (ALayout.StrTabBase + ALayout.StrLen);
    BytesZero(AHead + SizeUInt(ALayout.StrTabBase + ALayout.StrLen), SizeUInt(Pad));
  end;
end;

procedure ResPackWriterFillHashRange(const ADst: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout;
  const AStartBucket, ABucketCount: SizeUInt);
var
  B, Bucket, Idx, Src: SizeUInt;
  P: PByte;
  Fnv: UInt32;
  UseCache: Boolean;
begin
  if ABucketCount = 0 then Exit;
  if ALayout.HashBuckets = 0 then Exit;
  if (AStartBucket > ALayout.HashBuckets) or
     (ABucketCount > ALayout.HashBuckets - AStartBucket) then
    raise EResPackError.Create('respack: hash range out of bounds');
  if SizeUInt(Length(ALayout.HashSlotIdx)) <> ALayout.HashBuckets then
    raise EResPackError.Create('respack: hash slot table mismatch');
  { 灌桶缓存对齐即复用（布局单掃落盘，发射零重算）；手造布局缺缓存回退重算保兼容。 }
  UseCache := SizeUInt(Length(ALayout.HashFnv)) = ALayout.HashBuckets;
  for B := 0 to ABucketCount - 1 do
  begin
    Bucket := AStartBucket + B;
    Idx := SizeUInt(ALayout.HashSlotIdx[Bucket]);
    if (ALayout.HashSlotIdx[Bucket] = RESPACK_HASH_EMPTY_INDEX) or (Idx >= ALayout.N) then
    begin
      WrU32LE(ADst + B * RESPACK_HASH_ENTRY_SIZE, 0);
      WrU32LE(ADst + B * RESPACK_HASH_ENTRY_SIZE + 4, RESPACK_HASH_EMPTY_INDEX);
    end
    else
    begin
      Src := ALayout.Order[Idx];
      if UseCache then
        Fnv := ALayout.HashFnv[Bucket]
      else
      begin
        if ALayout.PathLens[Src] > 0 then
          P := PByte(@AEntries[Src].Path[1])
        else
          P := nil;
        Fnv := ResPackFnv1a32(P, SizeUInt(ALayout.PathLens[Src]));
      end;
      WrU32LE(ADst + B * RESPACK_HASH_ENTRY_SIZE, Fnv);
      WrU32LE(ADst + B * RESPACK_HASH_ENTRY_SIZE + 4, UInt32(Idx));
    end;
  end;
end;

procedure ResPackWriterFillHash(const ADst: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const ALayout: TResPackLayout);
begin
  if ALayout.HashBuckets = 0 then Exit;
  ResPackWriterFillHashRange(ADst, AEntries, AOpts, ALayout, 0, ALayout.HashBuckets);
end;

end.

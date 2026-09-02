unit nextpas.core.respack.writer.builder;

{** @desc respack writer 头/index/string 单源 builder：消除 writer/stream 30 行重复（WrU*LE/Move）。
  由 writer（纯内存 GetMem）与 writer.stream（分段 Head）共用；布局单源于 writer.layout。
  零拷贝与性能：路径/内容搬运经 bytes.ops.BytesCopy inline 单 Move，零填经 BytesZero inline FillChar 单源，无额外分配；
  循环体外联守设计红线2，热点 Move/LE 编解码保持 inline。 registry 明示 + source-contract 门禁（内部单源模块，同 writer.layout 范式）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base,
  nextpas.core.respack.writer.layout;

{ 单源填充 Head 区域：header(40) + index(N*40) + string table + 对齐填充 = DataStart。
  调用方保证 AHead 指向至少 DataStart 字节可写；本过程先零化整段 Head（BytesZero 单源 FillChar），
  再写入确定性头/index/string，间隙保持零，无条件分支避免 64MiB 双路径漂移。 }
procedure ResPackWriterFillHead(const AHead: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions;
  const ALayout: TResPackLayout);

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops;

procedure ResPackWriterFillHead(const AHead: PByte;
  const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions;
  const ALayout: TResPackLayout);
var
  N, I, J: SizeUInt;
  Cur: UInt64;
  HdrFlags: UInt32;
  EntFlags: Word;
begin
  if ALayout.DataStart > 0 then
    BytesZero(AHead, SizeUInt(ALayout.DataStart));
  AHead[0] := Ord('N'); AHead[1] := Ord('P');
  AHead[2] := Ord('R'); AHead[3] := Ord('S');
  WrU32LE(AHead + 4, RESPACK_VERSION);
  HdrFlags := 0;
  if AOpts.Hashes then
    HdrFlags := HdrFlags or RESPACK_FLAG_HASHED;
  if AOpts.DigestFunc <> nil then
    HdrFlags := HdrFlags or RESPACK_FLAG_DIGESTED;
  WrU32LE(AHead + 8, HdrFlags);
  N := ALayout.N;
  WrU32LE(AHead + 12, UInt32(N));
  WrU64LE(AHead + 16, UInt64(RESPACK_HEADER_SIZE));
  WrU64LE(AHead + 24, ALayout.DigOff);
  WrU64LE(AHead + 32, ALayout.Total);
  Cur := ALayout.StrTabBase;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      J := ALayout.Order[I];
      EntFlags := 0;
      if AOpts.Hashes then
        EntFlags := RESPACK_EFLAG_HASHED;
      WrU32LE(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE,
        UInt32(Cur - ALayout.StrTabBase));
      WrU16LE(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 4,
        ALayout.PathLens[J]);
      WrU16LE(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 6, EntFlags);
      WrU64LE(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 8,
        ALayout.Slots[ALayout.EntrySlots[J]].Offset);
      WrU64LE(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 16,
        UInt64(AEntries[J].DataSize));
      WrU64LE(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 24,
        UInt64(AEntries[J].ModTime));
      if AOpts.Hashes then
        WrU32LE(AHead + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 32,
          ALayout.FnvBuf[J]);
      AHead[RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 36] := Byte(RESPACK_CODEC_STORE);
      if ALayout.PathLens[J] > 0 then
        BytesCopy(AHead + Cur, Pointer(AEntries[J].Path), ALayout.PathLens[J]);
      Inc(Cur, ALayout.PathLens[J]);
    end;
end;

end.

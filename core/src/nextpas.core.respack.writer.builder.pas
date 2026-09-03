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

{ 单源填充 Head 区域：header(40) + index(N*40) + string table + 对齐填充 = DataStart。
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
begin
  if ALayout.DataStart > 0 then
    BytesZero(AHead, SizeUInt(ALayout.DataStart));
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
end;

end.

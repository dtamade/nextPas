program bench_zip;
{**
 * @desc ZIP 基准套件：以 nextpas.core.bench 规矩形态承载，替代手工 TInstant 循环。
 *       覆盖小文件容器开销 (2000×512B deflate) 与大文件吞吐 (1MB) 两面，包含
 *       builder 链式、stream-out、open/extract、AES、descriptor、sequential 全路径，
 *       parity 预检后经 TBenchSuite 控制迭代与样本统计，吞吐经 ACtx.SetBytes 换算，
 *       输出经 PrintToConsole + benchstat/json 归档。
 *}

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.compress.intf,
  nextpas.core.bytes.builder,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.checksum.crc32,
  nextpas.core.fs,
  nextpas.core.exception;

const
  FILE_COUNT = 2000;
  FILE_SIZE = 512;
  BIG_SIZE = 1024 * 1024;
  BENCH_PACK_COUNT = 200; // suite 轻量化：原 2000 太重致校准 100 次迭代 20 秒，领头羊需可重复门限

var
  GFiles: array of TBytes;
  GBlob: TBytes;
  GArchive: TBytes;
  GBigArchive: TBytes;

procedure GenerateData;
var
  LI, LJ: Integer;
begin
  SetLength(GFiles, FILE_COUNT);
  for LI := 0 to FILE_COUNT - 1 do
  begin
    SetLength(GFiles[LI], FILE_SIZE);
    for LJ := 0 to FILE_SIZE - 1 do
      GFiles[LI][LJ] := Byte((LJ * 7 + LI) mod 251);
  end;
  SetLength(GBlob, BIG_SIZE);
  for LI := 0 to BIG_SIZE - 1 do
    GBlob[LI] := Byte((LI * 7 + LI div 256) mod 251);
end;

function EntryName(AIndex: Integer): string;
var
  LS: string;
  LJ: Integer;
begin
  Str(AIndex:4, LS);
  for LJ := 1 to Length(LS) do
    if LS[LJ] = ' ' then
      LS[LJ] := '0';
  Result := 'f/' + LS + '.bin';
end;

function BuildManyArchive: TBytes;
var
  LW: IZipWriter;
  LI: Integer;
begin
  LW := NewZipWriter;
  for LI := 0 to FILE_COUNT - 1 do
    LW.AddEntryDeflate(EntryName(LI), GFiles[LI]);
  Result := LW.Finish;
end;

function BuildManyArchiveBench: TBytes;
var
  LW: IZipWriter;
  LI: Integer;
begin
  LW := NewZipWriter;
  for LI := 0 to BENCH_PACK_COUNT - 1 do
    LW.AddEntryDeflate(EntryName(LI), GFiles[LI]);
  Result := LW.Finish;
end;

type
  TNullWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

function TNullWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

type
  TCollectBench = class(TInterfacedObject, IWriter)
  private
    FBuf: IBytesBuilder;
  public
    constructor Create;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Bytes: TBytes;
  end;

constructor TCollectBench.Create;
begin
  inherited Create;
  FBuf := CreateBytesBuilder(65536);
end;

function TCollectBench.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount > 0 then
    FBuf.AppendBytes(PByte(@ABuf), ACount);
  Result := ACount;
end;

function TCollectBench.Bytes: TBytes;
begin
  Result := FBuf.ToBytes;
end;

procedure BuildManyEntriesInto(const AW: IZipWriter);
var
  LI: Integer;
begin
  for LI := 0 to FILE_COUNT - 1 do
    AW.AddEntryDeflate(EntryName(LI), GFiles[LI]);
end;

procedure BuildManyEntriesIntoBench(const AW: IZipWriter);
var
  LI: Integer;
begin
  for LI := 0 to BENCH_PACK_COUNT - 1 do
    AW.AddEntryDeflate(EntryName(LI), GFiles[LI]);
end;

function StrBytes(const AStr: string): TBytes;
var
  LJ: Integer;
begin
  SetLength(Result, Length(AStr));
  for LJ := 1 to Length(AStr) do
    Result[LJ - 1] := Ord(AStr[LJ]);
end;

procedure CheckBytesEqual(const AExpected, AActual: TBytes; const ALabel: string);
var
  LI: Integer;
begin
  if Length(AExpected) <> Length(AActual) then
    raise EInvalidOperationError.Create(ALabel + ': length mismatch');
  for LI := 0 to High(AExpected) do
    if AExpected[LI] <> AActual[LI] then
      raise EInvalidOperationError.Create(ALabel + ': byte mismatch at ' + IntToStr(LI));
end;

// ---- bench funcs (single op per call, suite controls iterations) ----

procedure BenchPackManyDeflate(const ACtx: IBenchContext);
var
  LArc: TBytes;
begin
  LArc := BuildManyArchiveBench;
  BenchBlackBoxBytes(LArc[0], Length(LArc));
  ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchPackWithReserve(const ACtx: IBenchContext);
var
  LW: IZipWriter;
  LI: Integer;
  LArc: TBytes;
begin
  LW := NewZipWriter;
  LW.Reserve(BENCH_PACK_COUNT);
  for LI := 0 to BENCH_PACK_COUNT - 1 do
    LW.AddEntryDeflate(EntryName(LI), GFiles[LI]);
  LArc := LW.Finish;
  BenchBlackBoxBytes(LArc[0], Length(LArc));
  ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchBuilderPack(const ACtx: IBenchContext);
var
  LB: IZipBuilder;
  LI: Integer;
  LArc: TBytes;
begin
  LB := ZipBuilder;
  LB.Reserve(BENCH_PACK_COUNT);
  for LI := 0 to BENCH_PACK_COUNT - 1 do
    LB.AddDeflate(EntryName(LI), GFiles[LI]);
  LArc := LB.Finish;
  BenchBlackBoxBytes(LArc[0], Length(LArc));
  ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchStreamOut(const ACtx: IBenchContext);
var
  LW: IZipWriter;
  LNull: IWriter;
begin
  LNull := TNullWriter.Create;
  LW := NewZipWriter;
  LW.StreamOutputTo(LNull);
  BuildManyEntriesIntoBench(LW);
  LW.FinishTo(LNull);
  ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchOpenParse(const ACtx: IBenchContext);
var
  LR: IZipReader;
begin
  LR := NewZipReader(GArchive);
  BenchBlackBoxPtr(Pointer(LR));
  ACtx.SetBytes(0);
end;

var GArchiveBench: TBytes;

procedure BenchExtractAll(const ACtx: IBenchContext);
var
  LJ: Integer;
  LR: IZipReader;
  LGot: TBytes;
begin
  LR := NewZipReader(GArchiveBench);
  for LJ := 0 to BENCH_PACK_COUNT - 1 do
    LGot := LR.ExtractToBytes(LJ);
  BenchBlackBoxBytes(LGot[0], Length(LGot));
  ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchWrite1MB(const ACtx: IBenchContext);
var
  LW: IZipWriter;
  LArc: TBytes;
begin
  LW := NewZipWriter;
  LW.AddEntryDeflate('big.bin', GBlob);
  LArc := LW.Finish;
  BenchBlackBoxBytes(LArc[0], Length(LArc));
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchRead1MB(const ACtx: IBenchContext);
var
  LR: IZipReader;
  LGot: TBytes;
begin
  LR := NewZipReader(GBigArchive);
  LGot := LR.ExtractToBytes(0);
  BenchBlackBoxBytes(LGot[0], Length(LGot));
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchAesPack(const ACtx: IBenchContext);
var
  LW: IZipWriter;
  LOpts: TZipAddOptions;
  LEnc: TBytes;
begin
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.Password := StrBytes('bench-password');
  LOpts.AesStrength := 3;
  LW := NewZipWriter;
  LW.AddEntryWithOptions('big.bin', GBlob, LOpts);
  LEnc := LW.Finish;
  BenchBlackBoxBytes(LEnc[0], Length(LEnc));
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchAesExtract(const ACtx: IBenchContext);
var
  LR: IZipReader;
  LROpts: TZipReadOptions;
  LGot: TBytes;
  LEnc: TBytes;
  LW: IZipWriter;
  LOpts: TZipAddOptions;
begin
  LOpts := DefaultZipAddOptions;
  LOpts.Method := zmDeflate;
  LOpts.Password := StrBytes('bench-password');
  LOpts.AesStrength := 3;
  LW := NewZipWriter;
  LW.AddEntryWithOptions('big.bin', GBlob, LOpts);
  LEnc := LW.Finish;
  LROpts := DefaultZipReadOptions;
  LROpts.Password := StrBytes('bench-password');
  LR := NewZipReaderWithOptions(LEnc, LROpts);
  LGot := LR.ExtractToBytesByName('big.bin');
  BenchBlackBoxBytes(LGot[0], Length(LGot));
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchDescriptorPack(const ACtx: IBenchContext);
var
  LW: IZipWriter;
  LS: ICompressWriter;
  LO: TZipAddOptions;
  LZip: TBytes;
begin
  LO := DefaultZipAddOptions;
  LO.Method := zmDeflate;
  LO.DataDescriptor := True;
  LW := NewZipWriter;
  LS := LW.AddEntryStream('big.bin', LO);
  LS.Write(GBlob[0], Length(GBlob));
  LS.Close;
  LZip := LW.Finish;
  BenchBlackBoxBytes(LZip[0], Length(LZip));
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchStagedPack(const ACtx: IBenchContext);
var
  LW: IZipWriter;
  LS: ICompressWriter;
  LO: TZipAddOptions;
  LZip: TBytes;
begin
  LO := DefaultZipAddOptions;
  LO.Method := zmDeflate;
  LO.DataDescriptor := False;
  LW := NewZipWriter;
  LS := LW.AddEntryStream('big.bin', LO);
  LS.Write(GBlob[0], Length(GBlob));
  LS.Close;
  LZip := LW.Finish;
  BenchBlackBoxBytes(LZip[0], Length(LZip));
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchSeqExtractAll(const ACtx: IBenchContext);
var
  LSeq: ISequentialZipReader;
  LInfo: TZipEntryInfo;
  LStream: IDecompressReader;
  LBuf: array[0..8191] of Byte;
  LJ: SizeUInt;
begin
  LSeq := NewZipSequentialReader(CreateBytesStreamFrom(GArchiveBench) as IReader);
  while LSeq.Next(LInfo) do
  begin
    LStream := LSeq.Open;
    repeat LJ := LStream.Read(LBuf[0], SizeOf(LBuf)); until LJ = 0;
    LStream.Close;
  end;
  ACtx.SetBytes(Int64(BENCH_PACK_COUNT) * FILE_SIZE);
end;

procedure BenchSeqRead1MB(const ACtx: IBenchContext);
var
  LSeq: ISequentialZipReader;
  LInfo: TZipEntryInfo;
  LStream: IDecompressReader;
  LBuf: array[0..8191] of Byte;
  LJ: SizeUInt;
begin
  LSeq := NewZipSequentialReader(CreateBytesStreamFrom(GBigArchive) as IReader);
  LSeq.Next(LInfo);
  LStream := LSeq.Open;
  repeat LJ := LStream.Read(LBuf[0], SizeOf(LBuf)); until LJ = 0;
  LStream.Close;
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchExtractPByte1MB(const ACtx: IBenchContext);
var
  LR: IZipReader;
  LBuf: array of Byte;
  LN: SizeUInt;
begin
  LR := NewZipReader(GBigArchive);
  SetLength(LBuf, BIG_SIZE);
  LN := LR.ExtractToBuffer(0, @LBuf[0], Length(LBuf));
  BenchBlackBoxBytes(LBuf[0], LN);
  ACtx.SetBytes(BIG_SIZE);
end;

procedure BenchCopyTo1MB(const ACtx: IBenchContext);
var
  LR: IZipReader;
  LNull: IWriter;
  LN: SizeUInt;
begin
  LR := NewZipReader(GBigArchive);
  LNull := TNullWriter.Create;
  LN := LR.CopyEntryTo(0, LNull);
  BenchBlackBoxBytes(LNull, SizeOf(LNull));
  if LN = 0 then BenchBlackBoxBytes(LNull, 0);
  ACtx.SetBytes(BIG_SIZE);
end;

var
  LResults: IBenchResults;
  LW: IZipWriter;
  LCol: TCollectBench;
  LPiped: TBytes;
  LR: IZipReader;
  LGot: TBytes;
  LO: TZipAddOptions;
  LS: ICompressWriter;
  LZip: TBytes;
  LSeq: ISequentialZipReader;
  LInfo: TZipEntryInfo;
  LStream: IDecompressReader;
  LBuf: array[0..8191] of Byte;
  LJ: SizeUInt;
begin
  GenerateData;
  GArchive := BuildManyArchive;
  GArchiveBench := BuildManyArchiveBench;
  LW := NewZipWriter;
  LW.AddEntryDeflate('big.bin', GBlob);
  GBigArchive := LW.Finish;

  // parity 预检（不计时，fail-fast）
  LCol := TCollectBench.Create;
  LW := NewZipWriter;
  LW.StreamOutputTo(LCol);
  BuildManyEntriesInto(LW);
  LW.FinishTo(LCol);
  LPiped := LCol.Bytes;
  CheckBytesEqual(GArchive, LPiped, 'stream-out parity');
  LR := NewZipReader(GBigArchive);
  LGot := LR.ExtractToBytesByName('big.bin');
  CheckBytesEqual(GBlob, LGot, 'big roundtrip verify');
  LO := DefaultZipAddOptions;
  LO.Method := zmDeflate;
  LO.DataDescriptor := True;
  LW := NewZipWriter;
  LS := LW.AddEntryStream('big.bin', LO);
  LS.Write(GBlob[0], Length(GBlob));
  LS.Close;
  LZip := LW.Finish;
  LGot := NewZipReader(LZip).ExtractToBytesByName('big.bin');
  CheckBytesEqual(GBlob, LGot, 'descriptor parity');
  LSeq := NewZipSequentialReader(CreateBytesStreamFrom(GBigArchive) as IReader);
  LSeq.Next(LInfo);
  LStream := LSeq.Open;
  SetLength(LGot, 0);
  repeat
    LJ := LStream.Read(LBuf[0], SizeOf(LBuf));
    if LJ > 0 then
    begin
      SetLength(LGot, Length(LGot) + Integer(LJ));
      Move(LBuf[0], LGot[Length(LGot)-Integer(LJ)], LJ);
    end;
  until LJ = 0;
  LStream.Close;
  CheckBytesEqual(LR.ExtractToBytes(0), LGot, 'sequential 1MB verify');

  LResults := TBenchSuite.Create('zip')
    .SetMinDuration(TDuration.FromMilliseconds(300))
    .SetMinSamples(7)
    .SetWarmupIters(1)
    .SetMaxIterations(25)
    .Add('zip/pack/200x512B', @BenchPackManyDeflate)
    .Add('zip/pack-reserve/200x512B', @BenchPackWithReserve)
    .Add('zip/builder-pack/200x512B', @BenchBuilderPack)
    .Add('zip/stream-out/200x512B', @BenchStreamOut)
    .Add('zip/open/parse-CD', @BenchOpenParse)
    .Add('zip/extract-all/200x512B', @BenchExtractAll)
    .Add('zip/write/1MB', @BenchWrite1MB)
    .Add('zip/read/1MB', @BenchRead1MB)
    .Add('zip/aes-pack/1MB', @BenchAesPack)
    .Add('zip/aes-extract/1MB', @BenchAesExtract)
    .Add('zip/descriptor-pack/1MB', @BenchDescriptorPack)
    .Add('zip/staged-pack/1MB', @BenchStagedPack)
    .Add('zip/seq-extract-all/200x512B', @BenchSeqExtractAll)
    .Add('zip/seq-read/1MB', @BenchSeqRead1MB)
    .Add('zip/extract-pbyte/1MB', @BenchExtractPByte1MB)
    .Add('zip/copy-to/1MB', @BenchCopyTo1MB)
    .Run;
  WriteLn(LResults.PrintToConsole);
  WriteLn('benchstat: ', LResults.ToBenchstat);
  try
    ForceDirectories('build');
    ForceDirectories('../../../build');
    LResults.SaveToJSON('build/bench-zip.json');
    LResults.SaveToJSON('../../../build/bench-zip.json');
  except
    on E: Exception do
      WriteLn('save json skipped: ', E.Message);
  end;
end.

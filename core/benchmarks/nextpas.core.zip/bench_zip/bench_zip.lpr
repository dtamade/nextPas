program bench_zip;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  nextpas.core.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.zip,
  nextpas.core.zip.base,
  nextpas.core.checksum.crc32,
  nextpas.core.text.format,
  nextpas.core.exception;

const
  { 小文件面：容器开销（每条目头/central/解析）为主 }
  FILE_COUNT = 2000;
  FILE_SIZE = 512;
  SMALL_ITERS = 5;
  { 大单文件面：deflate 载荷吞吐为主 }
  BIG_SIZE = 1024 * 1024;
  BIG_ITERS = 20;

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

{ 全部小文件打成一个 deflate 归档 }
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

procedure BenchPackManyDeflate;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LTotal, LRatio: Double;
begin
  GArchive := BuildManyArchive;
  LTotal := Int64(FILE_COUNT) * FILE_SIZE;
  LRatio := Length(GArchive) / LTotal * 100;

  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS do
    GArchive := BuildManyArchive;
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(TextFormat('zip pack %4d files   %8.0f entries/s  %6.1f MB/s  ratio=%.1f%%', [
    FILE_COUNT,
    (Int64(FILE_COUNT) * SMALL_ITERS) / LElapsed,
    (LTotal * SMALL_ITERS / 1048576.0) / LElapsed,
    LRatio]));
end;

procedure BenchOpenParse;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LR: IZipReader;
begin
  LR := NewZipReader(GArchive);
  if LR.EntryCount <> FILE_COUNT then
    raise EInvalidOperationError.Create('parse benchmark: entry count mismatch');

  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS * 10 do
    LR := NewZipReader(GArchive);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(TextFormat('zip open (parse CD) %8.0f opens/s  %9.0f entries/s', [
    (SMALL_ITERS * 10) / LElapsed,
    (Int64(FILE_COUNT) * SMALL_ITERS * 10) / LElapsed]));
end;

procedure BenchExtractAll;
var
  LI, LJ: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LR: IZipReader;
  LGot: TBytes;
  LCrc: LongWord;
  LTotal: Double;
begin
  LR := NewZipReader(GArchive);
  LCrc := 0;
  for LJ := 0 to FILE_COUNT - 1 do
  begin
    LGot := LR.ExtractToBytes(LJ);
    CheckBytesEqual(GFiles[LJ], LGot, 'extract-all verify');
    LCrc := Crc32OfBytes(LGot);  { 末条目 CRC，防剔除 }
  end;
  if LCrc = 0 then
    raise EInvalidOperationError.Create('unreachable');
  LTotal := Int64(FILE_COUNT) * FILE_SIZE;

  LStart := TInstant.Now;
  for LI := 1 to SMALL_ITERS * 10 do
    for LJ := 0 to FILE_COUNT - 1 do
      LGot := LR.ExtractToBytes(LJ);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(TextFormat('zip extract all     %8.0f entries/s  %6.1f MB/s', [
    (Int64(FILE_COUNT) * SMALL_ITERS * 10) / LElapsed,
    (LTotal * SMALL_ITERS * 10 / 1048576.0) / LElapsed]));
end;

procedure BenchBigRoundtrip;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LW: IZipWriter;
  LR: IZipReader;
  LGot: TBytes;
  LRatio: Double;
begin
  LW := NewZipWriter;
  LW.AddEntryDeflate('big.bin', GBlob);
  GBigArchive := LW.Finish;
  LRatio := Length(GBigArchive) / Length(GBlob) * 100;
  LR := NewZipReader(GBigArchive);
  LGot := LR.ExtractToBytesByName('big.bin');
  CheckBytesEqual(GBlob, LGot, 'big roundtrip verify');

  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LW := NewZipWriter;
    LW.AddEntryDeflate('big.bin', GBlob);
    GBigArchive := LW.Finish;
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip write 1MB entry %6.1f MB/s  ratio=%.1f%%', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed, LRatio]));

  LStart := TInstant.Now;
  for LI := 1 to BIG_ITERS do
  begin
    LR := NewZipReader(GBigArchive);
    LGot := LR.ExtractToBytes(0);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(TextFormat('zip read 1MB entry  %6.1f MB/s', [
    (BIG_SIZE * BIG_ITERS / 1048576.0) / LElapsed]));
end;

begin
  GenerateData;
  WriteLn(TextFormat('=== Pascal zip benchmark (%d files x %dB + 1MB blob) ===',
    [FILE_COUNT, FILE_SIZE]));
  WriteLn;
  BenchPackManyDeflate;
  BenchOpenParse;
  BenchExtractAll;
  WriteLn;
  BenchBigRoundtrip;
  WriteLn;
  WriteLn('done.');
end.

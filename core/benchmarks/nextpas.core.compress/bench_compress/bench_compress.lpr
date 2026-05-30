program bench_compress;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.compress;

const
  DATA_SIZE = 1024 * 1024;
  ITERATIONS = 20;

var
  GData: TBytes;

procedure GenerateData;
var
  LI: Integer;
begin
  SetLength(GData, DATA_SIZE);
  for LI := 0 to DATA_SIZE - 1 do
    GData[LI] := Byte((LI * 7 + LI div 256) mod 251);
end;

procedure BenchDeflateCompress;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LCompressed: TBytes;
  LRatio: Double;
begin
  LCompressed := DeflateCompress(GData);
  LRatio := Length(LCompressed) / Length(GData) * 100;

  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    LCompressed := DeflateCompress(GData);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(Format('Deflate compress   %6.1f MB/s  ratio=%.1f%%', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed, LRatio]));
end;

procedure BenchDeflateDecompress;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LCompressed, LDecompressed: TBytes;
begin
  LCompressed := DeflateCompress(GData);

  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    LDecompressed := DeflateDecompress(LCompressed);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(Format('Deflate decompress %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

procedure BenchGzipCompress;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LCompressed: TBytes;
  LRatio: Double;
begin
  LCompressed := GzipCompress(GData);
  LRatio := Length(LCompressed) / Length(GData) * 100;

  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    LCompressed := GzipCompress(GData);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(Format('Gzip compress      %6.1f MB/s  ratio=%.1f%%', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed, LRatio]));
end;

procedure BenchGzipDecompress;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LCompressed, LDecompressed: TBytes;
begin
  LCompressed := GzipCompress(GData);

  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    LDecompressed := GzipDecompress(LCompressed);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(Format('Gzip decompress    %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

procedure BenchLz4Compress;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LCompressed: TBytes;
  LRatio: Double;
begin
  LCompressed := Lz4Compress(GData);
  LRatio := Length(LCompressed) / Length(GData) * 100;

  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    LCompressed := Lz4Compress(GData);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(Format('LZ4 compress       %6.1f MB/s  ratio=%.1f%%', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed, LRatio]));
end;

procedure BenchLz4Decompress;
var
  LI: Integer;
  LStart: TInstant;
  LElapsed: Double;
  LCompressed, LDecompressed: TBytes;
begin
  LCompressed := Lz4Compress(GData);

  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    LDecompressed := Lz4Decompress(LCompressed, DATA_SIZE);
  LElapsed := LStart.Elapsed.AsSecondsF;

  WriteLn(Format('LZ4 decompress     %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

begin
  GenerateData;
  WriteLn('=== nextpas.core.compress benchmark (1MB x ', ITERATIONS, ' iterations) ===');
  WriteLn;
  BenchDeflateCompress;
  BenchDeflateDecompress;
  WriteLn;
  BenchGzipCompress;
  BenchGzipDecompress;
  WriteLn;
  BenchLz4Compress;
  BenchLz4Decompress;
  WriteLn;
  WriteLn('done.');
end.

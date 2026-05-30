program bench_hash;
{$I nextpas.core.settings.inc}
{$Q-}{$R-}
uses
  SysUtils,
  nextpas.core.time.base,
  nextpas.core.hash;
const
  DATA_SIZE = 1024 * 1024;
  ITERATIONS = 50;
var
  GData: array of Byte;

procedure BenchSHA256;
var
  LI: Int32;
  LStart: TInstant;
  LElapsed: Double;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    SHA256(@GData[0], DATA_SIZE);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(Format('  SHA-256 1MB:   %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

procedure BenchMD5;
var
  LI: Int32;
  LStart: TInstant;
  LElapsed: Double;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    MD5(@GData[0], DATA_SIZE);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(Format('  MD5 1MB:       %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

procedure BenchCRC32;
var
  LI: Int32;
  LStart: TInstant;
  LElapsed: Double;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
    CRC32(@GData[0], DATA_SIZE);
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(Format('  CRC32 1MB:     %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

var LI: Int32;
begin
  SetLength(GData, DATA_SIZE);
  for LI := 0 to DATA_SIZE - 1 do
    GData[LI] := Byte((LI * 7 + 13) mod 256);
  WriteLn('=== nextpas.core.hash benchmarks (1MB x ', ITERATIONS, ') ===');
  WriteLn;
  BenchSHA256;
  BenchMD5;
  BenchCRC32;
  WriteLn;
  WriteLn('--- Reference ---');
  WriteLn('  Go crypto/sha256:  ~300-400 MB/s (with SHA-NI)');
  WriteLn('  Go crypto/md5:     ~500-700 MB/s');
  WriteLn('  Rust sha2 crate:   ~300-500 MB/s (with SHA-NI)');
  WriteLn('  Note: our impl is pure Pascal, no SIMD yet');
  WriteLn;
  WriteLn('done.');
end.

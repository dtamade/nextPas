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
  LH: IHasher;
  LDigest: TSHA256Digest;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
  begin
    LH := NewSHA256;
    LH.Write(GData[0], DATA_SIZE);
    LH.Sum(LDigest, SHA256_DIGEST_SIZE);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(Format('  SHA-256 1MB:   %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

procedure BenchMD5;
var
  LI: Int32;
  LStart: TInstant;
  LElapsed: Double;
  LH: IHasher;
  LDigest: TMD5Digest;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
  begin
    LH := NewMD5;
    LH.Write(GData[0], DATA_SIZE);
    LH.Sum(LDigest, MD5_DIGEST_SIZE);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(Format('  MD5 1MB:       %6.1f MB/s', [
    (DATA_SIZE * ITERATIONS / 1048576.0) / LElapsed]));
end;

procedure BenchSHA1;
var
  LI: Int32;
  LStart: TInstant;
  LElapsed: Double;
  LH: IHasher;
  LDigest: TSHA1Digest;
begin
  LStart := TInstant.Now;
  for LI := 1 to ITERATIONS do
  begin
    LH := NewSHA1;
    LH.Write(GData[0], DATA_SIZE);
    LH.Sum(LDigest, SHA1_DIGEST_SIZE);
  end;
  LElapsed := LStart.Elapsed.AsSecondsF;
  WriteLn(Format('  SHA-1 1MB:     %6.1f MB/s', [
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
  BenchSHA1;
  WriteLn;
  WriteLn('--- Reference ---');
  WriteLn('  Go crypto/sha256:  ~300-400 MB/s (with SHA-NI)');
  WriteLn('  Go crypto/md5:     ~500-700 MB/s');
  WriteLn('  Rust sha2 crate:   ~300-500 MB/s (with SHA-NI)');
  WriteLn('  Note: our impl is pure Pascal, no SIMD yet');
  WriteLn;
  WriteLn('done.');
end.

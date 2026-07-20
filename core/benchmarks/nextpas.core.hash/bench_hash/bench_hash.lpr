{
  bench_hash.lpr — nextpas.core.hash Benchmark
  Migrated to TBenchSuite fluent API.
}
program bench_hash;

{$I nextpas.core.settings.inc}
{$Q-}{$R-}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.hash;

const
  DATA_SIZE = 1024 * 1024;

var
  GData: TBytes;

procedure InitData;
var
  LI: Integer;
begin
  SetLength(GData, DATA_SIZE);
  for LI := 0 to DATA_SIZE - 1 do
    GData[LI] := Byte((LI * 7 + 13) mod 256);
end;

procedure BenchSHA256(const ACtx: IBenchContext);
var
  LH: IHasher;
  LDigest: TSHA256Digest;
begin
  LH := NewSHA256;
  LH.Write(GData[0], DATA_SIZE);
  LH.Sum(LDigest, SHA256_DIGEST_SIZE);
  ACtx.SetBytes(DATA_SIZE);
end;

procedure BenchMD5(const ACtx: IBenchContext);
var
  LH: IHasher;
  LDigest: TMD5Digest;
begin
  LH := NewMD5;
  LH.Write(GData[0], DATA_SIZE);
  LH.Sum(LDigest, MD5_DIGEST_SIZE);
  ACtx.SetBytes(DATA_SIZE);
end;

procedure BenchSHA1(const ACtx: IBenchContext);
var
  LH: IHasher;
  LDigest: TSHA1Digest;
begin
  LH := NewSHA1;
  LH.Write(GData[0], DATA_SIZE);
  LH.Sum(LDigest, SHA1_DIGEST_SIZE);
  ACtx.SetBytes(DATA_SIZE);
end;

var
  LResults: IBenchResults;
begin
  InitData;
  LResults := TBenchSuite.Create('hash')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .Add('SHA256/1MB', @BenchSHA256)
    .Add('MD5/1MB', @BenchMD5)
    .Add('SHA1/1MB', @BenchSHA1)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-hash.json');
end.

program crypto_bench;
{$mode objfpc}{$H+}

{
  Crypto Hash Micro-Benchmark: Pascal vs Go vs Rust

  测试 MD5 / SHA-256 / SHA-512 纯哈希性能。
  预创建 context 避免分配噪音（Go/Rust 用栈分配）。
  使用 nextpas.core.bench 框架。
}

uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.crypto.hash;

const
  HASH_SMALL_N    = 10000;
  HASH_SMALL_SIZE = 1;
  HASH_LARGE_N    = 1000;
  HASH_LARGE_SIZE = 1024;

var
  GSmallPayload, GLargePayload: TBytes;
  GMD5Ctx: TMD5Context;
  GSHA256Ctx: TSHA256Context;
  GSHA512Ctx: TSHA512Context;

procedure InitPayload;
var I: Integer;
begin
  SetLength(GSmallPayload, HASH_SMALL_SIZE);
  GSmallPayload[0] := $42;

  SetLength(GLargePayload, HASH_LARGE_SIZE);
  for I := 0 to HASH_LARGE_SIZE - 1 do
    GLargePayload[I] := Byte(I and $FF);

  GMD5Ctx := TMD5Context.Create;
  GSHA256Ctx := TSHA256Context.Create;
  GSHA512Ctx := TSHA512Context.Create;
end;

function CalcChecksum(const AData: TBytes): Byte;
var I: Integer;
begin
  Result := 0;
  for I := 0 to High(AData) do
    Result := Result xor AData[I];
end;

{ === MD5 Small (1 byte × 10000) — context reuse === }

procedure BenchMD5Small(const ACtx: IBenchContext);
var Iter: Integer;
    Dummy: Byte;
begin
  Dummy := 0;
  for Iter := 1 to HASH_SMALL_N do
  begin
    GMD5Ctx.Reset;
    GMD5Ctx.Update(GSmallPayload);
    Dummy := Dummy xor GMD5Ctx.Final[0];
  end;
  ACtx.SetBytes(HASH_SMALL_N * HASH_SMALL_SIZE);
end;

{ === SHA-256 Small (1 byte × 10000) — context reuse === }

procedure BenchSHA256Small(const ACtx: IBenchContext);
var Iter: Integer;
    Dummy: Byte;
begin
  Dummy := 0;
  for Iter := 1 to HASH_SMALL_N do
  begin
    GSHA256Ctx.Reset;
    GSHA256Ctx.Update(GSmallPayload);
    Dummy := Dummy xor GSHA256Ctx.Final[0];
  end;
  ACtx.SetBytes(HASH_SMALL_N * HASH_SMALL_SIZE);
end;

{ === SHA-512 Small (1 byte × 10000) — context reuse === }

procedure BenchSHA512Small(const ACtx: IBenchContext);
var Iter: Integer;
    Dummy: Byte;
begin
  Dummy := 0;
  for Iter := 1 to HASH_SMALL_N do
  begin
    GSHA512Ctx.Reset;
    GSHA512Ctx.Update(GSmallPayload);
    Dummy := Dummy xor GSHA512Ctx.Final[0];
  end;
  ACtx.SetBytes(HASH_SMALL_N * HASH_SMALL_SIZE);
end;

{ === MD5 Large (1 KB × 1000) — context reuse === }

procedure BenchMD5Large(const ACtx: IBenchContext);
var Iter: Integer;
    Dummy: Byte;
begin
  Dummy := 0;
  for Iter := 1 to HASH_LARGE_N do
  begin
    GMD5Ctx.Reset;
    GMD5Ctx.Update(GLargePayload);
    Dummy := Dummy xor GMD5Ctx.Final[0];
  end;
  ACtx.SetBytes(HASH_LARGE_N * HASH_LARGE_SIZE);
end;

{ === SHA-256 Large (1 KB × 1000) — context reuse === }

procedure BenchSHA256Large(const ACtx: IBenchContext);
var Iter: Integer;
    Dummy: Byte;
begin
  Dummy := 0;
  for Iter := 1 to HASH_LARGE_N do
  begin
    GSHA256Ctx.Reset;
    GSHA256Ctx.Update(GLargePayload);
    Dummy := Dummy xor GSHA256Ctx.Final[0];
  end;
  ACtx.SetBytes(HASH_LARGE_N * HASH_LARGE_SIZE);
end;

{ === SHA-512 Large (1 KB × 1000) — context reuse === }

procedure BenchSHA512Large(const ACtx: IBenchContext);
var Iter: Integer;
    Dummy: Byte;
begin
  Dummy := 0;
  for Iter := 1 to HASH_LARGE_N do
  begin
    GSHA512Ctx.Reset;
    GSHA512Ctx.Update(GLargePayload);
    Dummy := Dummy xor GSHA512Ctx.Final[0];
  end;
  ACtx.SetBytes(HASH_LARGE_N * HASH_LARGE_SIZE);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  WriteLn('=== nextPas Crypto Benchmark ===');
  WriteLn('MD5/SHA-256/SHA-512 throughput (context reuse)');
  WriteLn('Small: ', HASH_SMALL_SIZE, 'B × ', HASH_SMALL_N);
  WriteLn('Large: ', HASH_LARGE_SIZE, 'B × ', HASH_LARGE_N);
  WriteLn;

  InitPayload;

  LSuite := TBenchSuite.Create('crypto')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('MD5/Small', @BenchMD5Small);
  LSuite.Add('SHA256/Small', @BenchSHA256Small);
  LSuite.Add('SHA512/Small', @BenchSHA512Small);
  LSuite.Add('MD5/Large', @BenchMD5Large);
  LSuite.Add('SHA256/Large', @BenchSHA256Large);
  LSuite.Add('SHA512/Large', @BenchSHA512Large);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);

  GMD5Ctx.Free;
  GSHA256Ctx.Free;
  GSHA512Ctx.Free;
end.

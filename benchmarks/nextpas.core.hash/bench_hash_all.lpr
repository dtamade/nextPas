program bench_hash_all;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash,
  nextpas.core.hash.wyhash,
  nextpas.core.crypto.hmac;

const
  WARMUP_ITERS = 50;

{$IFDEF LINUX}
function ClockGetTimeNs: Int64;
var
  LBuf: array[0..1] of Int64;
  LPtr: Pointer;
begin
  LBuf[0] := 0; LBuf[1] := 0;
  LPtr := @LBuf[0];
  asm
    movq $1, %rdi
    movq LPtr, %rsi
    movq $228, %rax
    syscall
  end ['rax', 'rdi', 'rsi', 'rdx', 'rcx', 'r11'];
  Result := LBuf[0] * 1000000000 + LBuf[1];
end;
{$ELSE}
function ClockGetTimeNs: Int64;
var ts: TTimeStamp;
begin
  ts := DateTimeToTimeStamp(Now);
  Result := (Int64(ts.Date) * 86400000 + ts.Time) * 1000000;
end;
{$ENDIF}

procedure BenchHash(const AName: string; AHasher: IHasher; ASize: SizeUInt; ADurationMs: Integer);
var
  LData: array of Byte;
  LDigest: array[0..63] of Byte;
  LStart, LEnd, LElapsedNs: Int64;
  LBytes, LIters: UInt64;
  I: Integer;
begin
  SetLength(LData, ASize);
  for I := 0 to ASize - 1 do LData[I] := Byte(I and $FF);

  for I := 0 to WARMUP_ITERS - 1 do
  begin
    AHasher.Reset;
    AHasher.Write(LData[0], ASize);
    AHasher.Sum(LDigest[0], AHasher.DigestSize);
  end;

  LBytes := 0; LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    AHasher.Reset;
    AHasher.Write(LData[0], ASize);
    AHasher.Sum(LDigest[0], AHasher.DigestSize);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  WriteLn(Format('  %-20s %6d B: %8.1f MB/s  (%d iters)',
    [AName, ASize, (LBytes / 1048576.0) / (LElapsedNs / 1e9), LIters]));
end;

procedure BenchWyHash(ASize: SizeUInt; ADurationMs: Integer);
var
  LData: array of Byte;
  LStart, LEnd, LElapsedNs: Int64;
  LBytes, LIters: UInt64;
  I: Integer;
  LDummy: UInt64;
begin
  SetLength(LData, ASize);
  for I := 0 to ASize - 1 do LData[I] := Byte(I and $FF);

  for I := 0 to WARMUP_ITERS - 1 do
    LDummy := WyHash(@LData[0], ASize, 0);

  LBytes := 0; LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    LDummy := WyHash(@LData[0], ASize, LDummy);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  WriteLn(Format('  %-20s %6d B: %8.1f MB/s  (%d iters)',
    ['WyHash', ASize, (LBytes / 1048576.0) / (LElapsedNs / 1e9), LIters]));
  if LDummy = 0 then; // prevent optimization
end;

var
  LKey: TBytes;
  I: Integer;
const
  SIZES: array[0..4] of SizeUInt = (64, 256, 1024, 8192, 1048576);
  DURATION = 1000;
begin
  WriteLn('=== Hash Benchmark (all algorithms) ===');
  WriteLn;

  WriteLn('--- SHA-256 ---');
  for I := 0 to High(SIZES) do
    BenchHash('SHA-256', NewSHA256, SIZES[I], DURATION);

  WriteLn;
  WriteLn('--- SHA-512 ---');
  for I := 0 to High(SIZES) do
    BenchHash('SHA-512', NewSHA512, SIZES[I], DURATION);

  WriteLn;
  WriteLn('--- SHA-384 ---');
  BenchHash('SHA-384', NewSHA384, 1024, DURATION);
  BenchHash('SHA-384', NewSHA384, 1048576, DURATION);

  WriteLn;
  WriteLn('--- SHA-1 ---');
  for I := 0 to High(SIZES) do
    BenchHash('SHA-1', NewSHA1, SIZES[I], DURATION);

  WriteLn;
  WriteLn('--- MD5 ---');
  BenchHash('MD5', NewMD5, 1024, DURATION);
  BenchHash('MD5', NewMD5, 1048576, DURATION);

  WriteLn;
  WriteLn('--- HMAC-SHA-256 ---');
  SetLength(LKey, 32);
  FillChar(LKey[0], 32, $AB);
  BenchHash('HMAC-SHA256', NewHMAC(haSHA256, LKey[0], 32), 64, DURATION);
  BenchHash('HMAC-SHA256', NewHMAC(haSHA256, LKey[0], 32), 1024, DURATION);
  BenchHash('HMAC-SHA256', NewHMAC(haSHA256, LKey[0], 32), 8192, DURATION);

  WriteLn;
  WriteLn('--- WyHash (non-crypto) ---');
  for I := 0 to High(SIZES) do
    BenchWyHash(SIZES[I], DURATION);

  WriteLn;
  WriteLn('=== Reference (run compare_go.go / compare_rust for comparison) ===');
end.

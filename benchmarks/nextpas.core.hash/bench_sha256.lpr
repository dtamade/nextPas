program bench_sha256;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256;

const
  WARMUP_ITERS = 50;
  BLOCK_SIZE = 8192;

function GetMonotonicNs: Int64;
var
  ts: TTimeStamp;
begin
  ts := DateTimeToTimeStamp(Now);
  Result := Int64(ts.Date) * 86400000 + ts.Time;
  Result := Result * 1000000;
end;

{$IFDEF LINUX}
function ClockGetTimeNs: Int64;
var
  LBuf: array[0..1] of Int64;
  LPtr: Pointer;
begin
  LBuf[0] := 0;
  LBuf[1] := 0;
  LPtr := @LBuf[0];
  asm
    movq $1, %rdi
    movq LPtr, %rsi
    movq $228, %rax
    syscall
  end ['rax', 'rdi', 'rsi', 'rdx', 'rcx', 'r11'];
  Result := LBuf[0] * 1000000000 + LBuf[1];
end;
{$ENDIF}

function NowNs: Int64;
begin
  {$IFDEF LINUX}
  Result := ClockGetTimeNs;
  {$ELSE}
  Result := GetMonotonicNs;
  {$ENDIF}
end;

procedure BenchSHA256(ASize: SizeUInt; ADurationMs: Integer);
var
  LData: array of Byte;
  LHasher: IHasher;
  LDigest: array[0..31] of Byte;
  LStart, LEnd: Int64;
  LElapsedNs: Int64;
  LBytes: UInt64;
  LIters: UInt64;
  LMBps: Double;
  I: Integer;
begin
  SetLength(LData, ASize);
  for I := 0 to ASize - 1 do
    LData[I] := Byte(I and $FF);

  LHasher := NewSHA256;
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    LHasher.Reset;
    LHasher.Write(LData[0], ASize);
    LHasher.Sum(LDigest[0], 32);
  end;

  LBytes := 0;
  LIters := 0;
  LStart := NowNs;
  repeat
    LHasher.Reset;
    LHasher.Write(LData[0], ASize);
    LHasher.Sum(LDigest[0], 32);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := NowNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  LMBps := (LBytes / 1048576.0) / (LElapsedNs / 1000000000.0);
  WriteLn(Format('  SHA-256 %6d bytes: %8.1f MB/s  (%d iters, %d ms)',
    [ASize, LMBps, LIters, LElapsedNs div 1000000]));
end;

var
  LEax, LEbx, LEcx, LEdx: DWord;
  LHasSHANI: Boolean;
begin
  WriteLn('=== SHA-256 Benchmark ===');

  {$IFDEF CPUX86_64}
  LEax := 0; LEbx := 0; LEcx := 0; LEdx := 0;
  asm
    movl $7, %eax
    xorl %ecx, %ecx
    cpuid
    movl %ebx, LEbx
  end ['eax', 'ebx', 'ecx', 'edx'];
  LHasSHANI := (LEbx and (1 shl 29)) <> 0;
  if LHasSHANI then
    WriteLn('  Backend: SHA-NI (hardware)')
  else
    WriteLn('  Backend: x86_64 scalar assembly');
  {$ELSE}
  LHasSHANI := False;
  WriteLn('  Backend: pure Pascal');
  {$ENDIF}
  WriteLn;

  BenchSHA256(64, 2000);
  BenchSHA256(256, 2000);
  BenchSHA256(1024, 2000);
  BenchSHA256(4096, 2000);
  BenchSHA256(8192, 2000);
  BenchSHA256(16384, 2000);
  BenchSHA256(65536, 2000);
  BenchSHA256(1048576, 2000);

  WriteLn;
  WriteLn('Done.');
end.

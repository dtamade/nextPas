program bench_aesgcm;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.aesgcm;

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

procedure BenchAESGCM(ASize: Integer; ADurationMs: Integer);
var
  LKey, LIV, LPlain, LAAD, LCipher, LTag: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LBytes, LIters: UInt64;
  LMBps: Double;
  I: Integer;
begin
  SetLength(LKey, 16);
  SetLength(LIV, 12);
  SetLength(LPlain, ASize);
  SetLength(LAAD, 13);
  for I := 0 to 15 do LKey[I] := Byte(I);
  for I := 0 to 11 do LIV[I] := Byte(I + $CA);
  for I := 0 to ASize - 1 do LPlain[I] := Byte(I and $FF);
  for I := 0 to 12 do LAAD[I] := Byte(I + $FE);

  // warmup
  for I := 0 to 20 do
    PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);

  LBytes := 0;
  LIters := 0;
  LStart := ClockGetTimeNs;
  repeat
    PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
    Inc(LBytes, ASize);
    Inc(LIters);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  LMBps := (LBytes / 1048576.0) / (LElapsedNs / 1000000000.0);
  WriteLn(Format('  AES-128-GCM %6d bytes: %8.1f MB/s  (%d iters)', [ASize, LMBps, LIters]));
end;

begin
  WriteLn('=== AES-128-GCM Benchmark ===');
  WriteLn;
  BenchAESGCM(64, 2000);
  BenchAESGCM(256, 2000);
  BenchAESGCM(1024, 2000);
  BenchAESGCM(4096, 2000);
  BenchAESGCM(8192, 2000);
  BenchAESGCM(16384, 2000);
  WriteLn;
  WriteLn('Done.');
end.

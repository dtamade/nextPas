program bench_crypto;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.ecdsa,
  nextpas.core.crypto.pbkdf2,
  nextpas.core.hash.base;

const
  WARMUP = 20;

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

procedure BenchAESGCM(AKeyLen, ADataLen: Integer; ADurationMs: Integer);
var
  LKey, LNonce, LPlain, LAAD, LCT, LTag: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LOps: UInt64;
  I: Integer;
begin
  SetLength(LKey, AKeyLen);
  SetLength(LNonce, 12);
  SetLength(LPlain, ADataLen);
  SetLength(LAAD, 0);
  for I := 0 to AKeyLen - 1 do LKey[I] := Byte(I);
  for I := 0 to 11 do LNonce[I] := Byte(I + $A0);
  for I := 0 to ADataLen - 1 do LPlain[I] := Byte(I and $FF);

  for I := 0 to WARMUP - 1 do
    PurePascalAESGCMEncrypt(LKey, LNonce, LPlain, LAAD, LCT, LTag);

  LOps := 0;
  LStart := ClockGetTimeNs;
  repeat
    PurePascalAESGCMEncrypt(LKey, LNonce, LPlain, LAAD, LCT, LTag);
    Inc(LOps);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  WriteLn(Format('  AES-%d-GCM %5dB: %8.1f MB/s  (%d ops, %.1f us/op)',
    [AKeyLen * 8, ADataLen,
     (UInt64(ADataLen) * LOps / 1048576.0) / (LElapsedNs / 1e9),
     LOps, LElapsedNs / LOps / 1000.0]));
end;

procedure BenchX25519(ADurationMs: Integer);
var
  LPriv, LPub, LShared: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LOps: UInt64;
  I: Integer;
begin
  GenerateX25519KeyPair(LPriv, LPub);

  for I := 0 to WARMUP - 1 do
    LShared := X25519ComputeSharedSecret(LPriv, LPub);

  LOps := 0;
  LStart := ClockGetTimeNs;
  repeat
    LShared := X25519ComputeSharedSecret(LPriv, LPub);
    Inc(LOps);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  WriteLn(Format('  X25519 ECDH:       %8d ops/s  (%.1f us/op)',
    [LOps * 1000000000 div UInt64(LElapsedNs), LElapsedNs / LOps / 1000.0]));
  if Length(LShared) = 0 then;
end;

procedure BenchEd25519Sign(ADurationMs: Integer);
var
  LPriv, LMsg, LSig: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LOps: UInt64;
  I: Integer;
begin
  SetLength(LPriv, 32);
  for I := 0 to 31 do LPriv[I] := Byte(I + $10);
  LMsg := TEncoding.UTF8.GetBytes(UnicodeString('benchmark message for ed25519'));

  for I := 0 to WARMUP - 1 do
    Ed25519Sign(LPriv, LMsg, LSig);

  LOps := 0;
  LStart := ClockGetTimeNs;
  repeat
    Ed25519Sign(LPriv, LMsg, LSig);
    Inc(LOps);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  WriteLn(Format('  Ed25519 Sign:      %8d ops/s  (%.1f us/op)',
    [LOps * 1000000000 div UInt64(LElapsedNs), LElapsedNs / LOps / 1000.0]));
end;

procedure BenchEd25519Verify(ADurationMs: Integer);
var
  LPriv, LPub, LMsg, LSig: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LOps: UInt64;
  I: Integer;
begin
  SetLength(LPriv, 32);
  for I := 0 to 31 do LPriv[I] := Byte(I + $10);
  LPub := Ed25519PublicKeyFromPrivate(LPriv);
  LMsg := TEncoding.UTF8.GetBytes(UnicodeString('benchmark message for ed25519'));
  Ed25519Sign(LPriv, LMsg, LSig);

  for I := 0 to WARMUP - 1 do
    Ed25519Verify(LPub, LMsg, LSig);

  LOps := 0;
  LStart := ClockGetTimeNs;
  repeat
    Ed25519Verify(LPub, LMsg, LSig);
    Inc(LOps);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  WriteLn(Format('  Ed25519 Verify:    %8d ops/s  (%.1f us/op)',
    [LOps * 1000000000 div UInt64(LElapsedNs), LElapsedNs / LOps / 1000.0]));
end;

procedure BenchPBKDF2(AIterations: Integer; ADurationMs: Integer);
var
  LPwd, LSalt, LKey: TBytes;
  LStart, LEnd, LElapsedNs: Int64;
  LOps: UInt64;
  I: Integer;
begin
  LPwd := TEncoding.UTF8.GetBytes(UnicodeString('password'));
  LSalt := TEncoding.UTF8.GetBytes(UnicodeString('salt'));

  for I := 0 to 2 do
    LKey := PBKDF2_SHA256(LPwd, LSalt, AIterations, 32);

  LOps := 0;
  LStart := ClockGetTimeNs;
  repeat
    LKey := PBKDF2_SHA256(LPwd, LSalt, AIterations, 32);
    Inc(LOps);
    LEnd := ClockGetTimeNs;
    LElapsedNs := LEnd - LStart;
  until LElapsedNs >= Int64(ADurationMs) * 1000000;

  WriteLn(Format('  PBKDF2-SHA256 i=%d: %6d ops/s  (%.1f ms/op)',
    [AIterations, LOps * 1000000000 div UInt64(LElapsedNs), LElapsedNs / LOps / 1e6]));
  if Length(LKey) = 0 then;
end;

const
  DUR = 2000;
begin
  WriteLn('=== Crypto Benchmark ===');
  WriteLn;

  WriteLn('--- AES-GCM ---');
  BenchAESGCM(16, 64, DUR);
  BenchAESGCM(16, 1024, DUR);
  BenchAESGCM(16, 8192, DUR);
  BenchAESGCM(32, 1024, DUR);
  BenchAESGCM(32, 8192, DUR);

  WriteLn;
  WriteLn('--- X25519 ---');
  BenchX25519(DUR);

  WriteLn;
  WriteLn('--- Ed25519 ---');
  BenchEd25519Sign(DUR);
  BenchEd25519Verify(DUR);

  WriteLn;
  WriteLn('--- PBKDF2-SHA256 ---');
  BenchPBKDF2(1000, DUR);
  BenchPBKDF2(10000, DUR);
  BenchPBKDF2(100000, DUR);

  WriteLn;
  WriteLn('=== Done ===');
end.

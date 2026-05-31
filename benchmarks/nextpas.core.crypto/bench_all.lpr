program bench_crypto_all;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aescbc,
  nextpas.core.tls.tls13.chacha20poly1305,
  nextpas.core.crypto.hkdf,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.hash;

{$IFDEF LINUX}
function ClockGetTimeNs: Int64;
var
  LBuf: array[0..1] of Int64;
  LPtr: Pointer;
begin
  LBuf[0] := 0; LBuf[1] := 0; LPtr := @LBuf[0];
  asm
    movq $1, %rdi
    movq LPtr, %rsi
    movq $228, %rax
    syscall
  end ['rax', 'rdi', 'rsi', 'rdx', 'rcx', 'r11'];
  Result := LBuf[0] * 1000000000 + LBuf[1];
end;
{$ENDIF}

procedure BenchX25519(N: Integer);
var
  LPriv, LPub, LShared: TBytes;
  LStart, LEnd: Int64;
  I: Integer;
begin
  GenerateX25519KeyPair(LPriv, LPub);
  LStart := ClockGetTimeNs;
  for I := 1 to N do
    LShared := X25519ComputeSharedSecret(LPriv, LPub);
  LEnd := ClockGetTimeNs;
  WriteLn(Format('  X25519 ScalarMult:      %8.1f us/op', [(LEnd-LStart)/1000.0/N]));
end;

procedure BenchEd25519Sign(N: Integer);
var
  LPriv, LMsg, LSig: TBytes;
  LStart, LEnd: Int64;
  I: Integer;
begin
  LPriv := GenerateX25519PrivateKey;
  SetLength(LMsg, 64);
  for I := 0 to 63 do LMsg[I] := Byte(I);
  LStart := ClockGetTimeNs;
  for I := 1 to N do
    Ed25519Sign(LPriv, LMsg, LSig);
  LEnd := ClockGetTimeNs;
  WriteLn(Format('  Ed25519 Sign:           %8.1f us/op', [(LEnd-LStart)/1000.0/N]));
end;

procedure BenchAESGCM(ASize, N: Integer);
var
  LKey, LIV, LPlain, LAAD, LCipher, LTag: TBytes;
  LStart, LEnd: Int64;
  LMBps: Double;
  I: Integer;
begin
  SetLength(LKey, 16);
  SetLength(LIV, 12);
  SetLength(LPlain, ASize);
  SetLength(LAAD, 13);
  for I := 0 to 15 do LKey[I] := Byte(I);
  for I := 0 to 11 do LIV[I] := Byte(I);
  for I := 0 to ASize-1 do LPlain[I] := Byte(I and $FF);

  LStart := ClockGetTimeNs;
  for I := 1 to N do
    PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
  LEnd := ClockGetTimeNs;
  LMBps := (Int64(ASize) * N / 1048576.0) / ((LEnd-LStart) / 1000000000.0);
  WriteLn(Format('  AES-128-GCM %5dB:     %8.1f MB/s', [ASize, LMBps]));
end;

procedure BenchChaCha20(ASize, N: Integer);
var
  LKey, LNonce, LAAD, LPlain, LCipher, LTag: TBytes;
  LStart, LEnd: Int64;
  LMBps: Double;
  I: Integer;
begin
  SetLength(LKey, 32);
  SetLength(LNonce, 12);
  SetLength(LAAD, 13);
  SetLength(LPlain, ASize);
  for I := 0 to 31 do LKey[I] := Byte(I);
  for I := 0 to 11 do LNonce[I] := Byte(I);
  for I := 0 to ASize-1 do LPlain[I] := Byte(I and $FF);

  LStart := ClockGetTimeNs;
  for I := 1 to N do
    TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
  LEnd := ClockGetTimeNs;
  LMBps := (Int64(ASize) * N / 1048576.0) / ((LEnd-LStart) / 1000000000.0);
  WriteLn(Format('  ChaCha20-Poly1305 %4dB: %8.1f MB/s', [ASize, LMBps]));
end;

procedure BenchSHA256(ASize, N: Integer);
var
  LData, LHash: TBytes;
  LStart, LEnd: Int64;
  LMBps: Double;
  I: Integer;
begin
  SetLength(LData, ASize);
  for I := 0 to ASize-1 do LData[I] := Byte(I and $FF);

  LStart := ClockGetTimeNs;
  for I := 1 to N do
    LHash := SHA256(LData);
  LEnd := ClockGetTimeNs;
  LMBps := (Int64(ASize) * N / 1048576.0) / ((LEnd-LStart) / 1000000000.0);
  WriteLn(Format('  SHA-256 %5dB:          %8.1f MB/s', [ASize, LMBps]));
end;

procedure BenchHMACSHA256(N: Integer);
var
  LKey, LData, LResult: TBytes;
  LStart, LEnd: Int64;
  I: Integer;
begin
  SetLength(LKey, 32);
  SetLength(LData, 64);
  for I := 0 to 31 do LKey[I] := Byte(I);
  for I := 0 to 63 do LData[I] := Byte(I);

  LStart := ClockGetTimeNs;
  for I := 1 to N do
    LResult := HKDF_Extract_SHA256(LKey, LData);
  LEnd := ClockGetTimeNs;
  WriteLn(Format('  HKDF-Extract-SHA256:    %8.1f us/op', [(LEnd-LStart)/1000.0/N]));
end;

begin
  WriteLn('=== nextpas.core.crypto Comprehensive Benchmark ===');
  WriteLn(Format('    Platform: %s', [{$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%}]));
  WriteLn;

  WriteLn('--- Asymmetric (us/op, lower is better) ---');
  BenchX25519(500);
  BenchEd25519Sign(200);
  WriteLn;

  WriteLn('--- AEAD (MB/s, higher is better) ---');
  BenchAESGCM(1024, 5000);
  BenchAESGCM(8192, 1000);
  BenchChaCha20(1024, 5000);
  BenchChaCha20(8192, 1000);
  WriteLn;

  WriteLn('--- Hash (MB/s, higher is better) ---');
  BenchSHA256(1024, 10000);
  BenchSHA256(8192, 2000);
  WriteLn;

  WriteLn('--- KDF (us/op, lower is better) ---');
  BenchHMACSHA256(10000);
  WriteLn;

  WriteLn('Done.');
end.

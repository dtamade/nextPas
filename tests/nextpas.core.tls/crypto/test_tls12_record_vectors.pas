program test_tls12_record_vectors;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls12.recordcrypto,
  nextpas.core.tls.tls12.chacha20record,
  nextpas.core.tls.crypto.tls12record,
  nextpas.core.tls.tls12.handshakecrypto,
  nextpas.core.tls.crypto.tls12prf;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then Inc(GPass)
  else begin Inc(GFail); WriteLn('  FAIL: ', AMsg); end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
    Result := Result + IntToHex(AData[I], 2);
end;

procedure TestGCMNonceConstruction;
var
  LKey, LIV, LPlain, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
begin
  WriteLn('Test: GCM nonce = implicit_iv(4) || seq_num(8)');
  // RFC 5288: nonce = salt(4) || nonce_explicit(8)
  // nonce_explicit = sequence number
  LKey := HexToBytes('00112233445566778899AABBCCDDEEFF');
  LIV := HexToBytes('DEADBEEF'); // 4-byte implicit nonce

  LPlain := HexToBytes('48656C6C6F'); // "Hello"

  // Encrypt with seq=0
  LOk := TLS12GCMEncryptRecord(LKey, LIV, 0, 23, LPlain, LEnc, LErr);
  Check(LOk, 'Encrypt seq=0 succeeds');
  // First 8 bytes of encrypted record = explicit nonce = seq_num big-endian
  Check(LEnc[0] = 0, 'Explicit nonce byte 0 = 0');
  Check(LEnc[7] = 0, 'Explicit nonce byte 7 = 0 (seq=0)');

  // Encrypt with seq=256
  LOk := TLS12GCMEncryptRecord(LKey, LIV, 256, 23, LPlain, LEnc, LErr);
  Check(LOk, 'Encrypt seq=256 succeeds');
  Check(LEnc[6] = 1, 'Explicit nonce: seq=256 → byte[6]=1');
  Check(LEnc[7] = 0, 'Explicit nonce: seq=256 → byte[7]=0');

  // Decrypt roundtrip
  LOk := TLS12GCMDecryptRecord(LKey, LIV, 256, 23, LEnc, LDec, LErr);
  Check(LOk, 'Decrypt seq=256 succeeds');
  Check(BytesToHex(LDec) = '48656C6C6F', 'Decrypted matches original');
end;

procedure TestGCMAADFormat;
var
  LKey, LIV, LPlain, LEnc1, LEnc2: TBytes;
  LErr: string;
begin
  WriteLn('Test: GCM AAD = seq(8) + type(1) + version(2) + length(2)');
  LKey := HexToBytes('AABBCCDDAABBCCDDAABBCCDDAABBCCDD');
  LIV := HexToBytes('11223344');
  LPlain := HexToBytes('0102030405');

  // Same plaintext, same key, same seq, but different content type → different ciphertext
  TLS12GCMEncryptRecord(LKey, LIV, 0, 23, LPlain, LEnc1, LErr); // app data
  TLS12GCMEncryptRecord(LKey, LIV, 0, 22, LPlain, LEnc2, LErr); // handshake

  // Tags must differ (AAD includes content type, affects authentication)
  Check(not CompareMem(@LEnc1[8 + Length(LPlain)], @LEnc2[8 + Length(LPlain)], 16),
    'Different content type → different GCM tag');
end;

procedure TestGCMOutputFormat;
var
  LKey, LIV, LPlain, LEnc: TBytes;
  LErr: string;
begin
  WriteLn('Test: GCM output = explicit_nonce(8) + ciphertext(N) + tag(16)');
  LKey := HexToBytes('00000000000000000000000000000000');
  LIV := HexToBytes('00000000');
  SetLength(LPlain, 100);
  FillChar(LPlain[0], 100, $42);

  TLS12GCMEncryptRecord(LKey, LIV, 0, 23, LPlain, LEnc, LErr);
  Check(Length(LEnc) = 8 + 100 + 16, 'Output = 8 + plaintext_len + 16');
end;

procedure TestChaCha20NonceXOR;
var
  LKey, LIV, LPlain, LEnc1, LEnc2: TBytes;
  LErr: string;
begin
  WriteLn('Test: ChaCha20 nonce = IV XOR padded_seq (RFC 7905)');
  SetLength(LKey, 32); FillChar(LKey[0], 32, $AA);
  SetLength(LIV, 12); FillChar(LIV[0], 12, $BB);
  LPlain := HexToBytes('48454C4C4F');

  // Different seq numbers must produce different ciphertexts
  TLS12ChaCha20Poly1305EncryptRecord(LKey, LIV, 0, 23, LPlain, LEnc1, LErr);
  TLS12ChaCha20Poly1305EncryptRecord(LKey, LIV, 1, 23, LPlain, LEnc2, LErr);

  Check(Length(LEnc1) = Length(LPlain) + 16, 'ChaCha20 output = plaintext + tag(16)');
  Check(not CompareMem(@LEnc1[0], @LEnc2[0], Length(LEnc1)),
    'Different seq → different ciphertext');
end;

procedure TestChaCha20NoExplicitNonce;
var
  LKey, LIV, LPlain, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
begin
  WriteLn('Test: ChaCha20 has no explicit nonce (unlike GCM)');
  SetLength(LKey, 32); FillChar(LKey[0], 32, $CC);
  SetLength(LIV, 12); FillChar(LIV[0], 12, $DD);
  LPlain := HexToBytes('DEADBEEF');

  TLS12ChaCha20Poly1305EncryptRecord(LKey, LIV, 5, 23, LPlain, LEnc, LErr);
  // ChaCha20: output = ciphertext(4) + tag(16) = 20 bytes (no 8-byte nonce prefix)
  Check(Length(LEnc) = 4 + 16, 'No explicit nonce in ChaCha20 record');

  LOk := TLS12ChaCha20Poly1305DecryptRecord(LKey, LIV, 5, 23, LEnc, LDec, LErr);
  Check(LOk, 'Decrypt succeeds');
  Check(BytesToHex(LDec) = 'DEADBEEF', 'Roundtrip correct');
end;

procedure TestPRFOutputLength;
var
  LSecret, LSeed, LOut: TBytes;
begin
  WriteLn('Test: PRF produces exact requested length');
  LSecret := HexToBytes('0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B0B');
  LSeed := HexToBytes('0102030405060708');

  LOut := TLS12PRF_SHA256(LSecret, 'test', LSeed, 1);
  Check(Length(LOut) = 1, 'PRF length=1');

  LOut := TLS12PRF_SHA256(LSecret, 'test', LSeed, 48);
  Check(Length(LOut) = 48, 'PRF length=48');

  LOut := TLS12PRF_SHA256(LSecret, 'test', LSeed, 128);
  Check(Length(LOut) = 128, 'PRF length=128');

  LOut := TLS12PRF_SHA256(LSecret, 'test', LSeed, 256);
  Check(Length(LOut) = 256, 'PRF length=256');
end;

procedure TestKeyBlockOrder;
var
  LMaster, LSR, LCR: TBytes;
  LKB: TTLS12KeyBlock;
begin
  WriteLn('Test: Key block order per RFC 5246 §6.3');
  // RFC 5246: client_write_MAC_key, server_write_MAC_key,
  //           client_write_key, server_write_key,
  //           client_write_IV, server_write_IV
  SetLength(LMaster, 48); FillChar(LMaster[0], 48, $11);
  SetLength(LSR, 32); FillChar(LSR[0], 32, $22);
  SetLength(LCR, 32); FillChar(LCR[0], 32, $33);

  LKB := TLS12DeriveKeyBlockFull_SHA256(LMaster, LSR, LCR, 32, 16, 4);

  // All keys must be different (derived from sequential PRF output)
  Check(not CompareMem(@LKB.ClientWriteMACKey[0], @LKB.ServerWriteMACKey[0], 32),
    'Client MAC ≠ Server MAC');
  Check(not CompareMem(@LKB.ClientWriteKey[0], @LKB.ServerWriteKey[0], 16),
    'Client key ≠ Server key');
  Check(not CompareMem(@LKB.ClientWriteIV[0], @LKB.ServerWriteIV[0], 4),
    'Client IV ≠ Server IV');
end;

begin
  WriteLn('=== TLS 1.2 Record & KDF Vector Tests ===');
  WriteLn('');

  TestGCMNonceConstruction;
  TestGCMAADFormat;
  TestGCMOutputFormat;
  TestChaCha20NonceXOR;
  TestChaCha20NoExplicitNonce;
  TestPRFOutputLength;
  TestKeyBlockOrder;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.

program test_tls12_negative;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls12.parser,
  nextpas.core.tls.tls12.recordcrypto;

var
  GPass: Integer = 0;
  GFail: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then Inc(GPass)
  else begin Inc(GFail); WriteLn('  FAIL: ', AMsg); end;
end;

procedure TestTruncatedServerHello;
var
  LData: TBytes;
  LSH: TTLS12ServerHello;
  LErr: string;
begin
  WriteLn('Test: Truncated ServerHello');
  SetLength(LData, 5);
  Check(not TryParseTLS12ServerHello(LData, 0, LSH, LErr), 'too short should fail');

  SetLength(LData, 0);
  Check(not TryParseTLS12ServerHello(LData, 0, LSH, LErr), 'empty should fail');
end;

procedure TestInvalidSessionIDLength;
var
  LData: TBytes;
  LSH: TTLS12ServerHello;
  LErr: string;
begin
  WriteLn('Test: Invalid session ID length');
  SetLength(LData, 38);
  LData[0] := 3; LData[1] := 3;
  LData[34] := 255; // session ID length = 255 (overflows)
  Check(not TryParseTLS12ServerHello(LData, 0, LSH, LErr), 'oversized session ID should fail');
end;

procedure TestTruncatedCertificate;
var
  LData: TBytes;
  LCert: TTLS12CertificateMessage;
  LErr: string;
begin
  WriteLn('Test: Truncated Certificate message');
  SetLength(LData, 2);
  Check(not TryParseTLS12Certificate(LData, 0, LCert, LErr), 'too short should fail');

  SetLength(LData, 3);
  LData[0] := 0; LData[1] := 0; LData[2] := 100; // claims 100 bytes but only 3
  Check(not TryParseTLS12Certificate(LData, 0, LCert, LErr), 'truncated should fail');
end;

procedure TestTruncatedSKE;
var
  LData: TBytes;
  LSKE: TTLS12ServerKeyExchange;
  LErr: string;
begin
  WriteLn('Test: Truncated ServerKeyExchange');
  SetLength(LData, 3);
  Check(not TryParseTLS12ServerKeyExchange(LData, 0, LSKE, LErr), 'too short should fail');

  SetLength(LData, 4);
  LData[0] := 3; // named_curve
  LData[1] := 0; LData[2] := 29; // X25519
  LData[3] := 100; // claims 100 byte pubkey but only 4 bytes total
  Check(not TryParseTLS12ServerKeyExchange(LData, 0, LSKE, LErr), 'truncated pubkey should fail');
end;

procedure TestInvalidCurveType;
var
  LData: TBytes;
  LSKE: TTLS12ServerKeyExchange;
  LErr: string;
begin
  WriteLn('Test: Invalid curve type in SKE');
  SetLength(LData, 40);
  LData[0] := 1; // explicit_prime (not named_curve=3)
  Check(not TryParseTLS12ServerKeyExchange(LData, 0, LSKE, LErr), 'non-named_curve should fail');
end;

procedure TestGCMBadTag;
var
  LKey, LIV, LPlain, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
begin
  WriteLn('Test: GCM record with corrupted tag');
  SetLength(LKey, 16); FillChar(LKey[0], 16, $AA);
  SetLength(LIV, 4); FillChar(LIV[0], 4, $BB);
  LPlain := TEncoding.ASCII.GetBytes('test data');

  TLS12GCMEncryptRecord(LKey, LIV, 0, 23, LPlain, LEnc, LErr);
  // Corrupt last byte of tag
  LEnc[Length(LEnc) - 1] := LEnc[Length(LEnc) - 1] xor $FF;

  LOk := TLS12GCMDecryptRecord(LKey, LIV, 0, 23, LEnc, LDec, LErr);
  Check(not LOk, 'corrupted tag should fail');
  Check(LErr = 'bad_record_mac', 'error should be bad_record_mac');
end;

procedure TestGCMWrongSeqNum;
var
  LKey, LIV, LPlain, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
begin
  WriteLn('Test: GCM record with wrong sequence number');
  SetLength(LKey, 16); FillChar(LKey[0], 16, $CC);
  SetLength(LIV, 4); FillChar(LIV[0], 4, $DD);
  LPlain := TEncoding.ASCII.GetBytes('hello');

  TLS12GCMEncryptRecord(LKey, LIV, 5, 23, LPlain, LEnc, LErr);
  LOk := TLS12GCMDecryptRecord(LKey, LIV, 6, 23, LEnc, LDec, LErr); // wrong seq
  Check(not LOk, 'wrong seq num should fail');
end;

procedure TestGCMTooShort;
var
  LKey, LIV, LEnc, LDec: TBytes;
  LOk: Boolean;
  LErr: string;
begin
  WriteLn('Test: GCM record too short (< nonce + tag)');
  SetLength(LKey, 16); FillChar(LKey[0], 16, $EE);
  SetLength(LIV, 4); FillChar(LIV[0], 4, $FF);
  SetLength(LEnc, 10); // too short for 8-byte nonce + 16-byte tag
  LOk := TLS12GCMDecryptRecord(LKey, LIV, 0, 23, LEnc, LDec, LErr);
  Check(not LOk, 'too short record should fail');
end;

begin
  WriteLn('=== TLS 1.2 Negative Tests (Malformed Input) ===');
  WriteLn('');

  TestTruncatedServerHello;
  TestInvalidSessionIDLength;
  TestTruncatedCertificate;
  TestTruncatedSKE;
  TestInvalidCurveType;
  TestGCMBadTag;
  TestGCMWrongSeqNum;
  TestGCMTooShort;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.

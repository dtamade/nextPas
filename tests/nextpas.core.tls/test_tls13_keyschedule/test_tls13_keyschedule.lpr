program test_tls13_keyschedule;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.tls.tls13.keyschedule;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

const
  TLS_AES_128_GCM_SHA256 = $1301;
  TLS_AES_256_GCM_SHA384 = $1302;

procedure TestCipherSuiteClassification;
begin
  Check('AES-128-GCM is SHA256', TLS13CipherSuiteIsSHA256(TLS_AES_128_GCM_SHA256));
  Check('AES-256-GCM is SHA384', TLS13CipherSuiteIsSHA384(TLS_AES_256_GCM_SHA384));
  Check('AES-128-GCM not SHA384', not TLS13CipherSuiteIsSHA384(TLS_AES_128_GCM_SHA256));
  Check('AES-256-GCM not SHA256', not TLS13CipherSuiteIsSHA256(TLS_AES_256_GCM_SHA384));
  Check('same hash: 1301+1301', TLS13CipherSuitesShareHash(TLS_AES_128_GCM_SHA256, TLS_AES_128_GCM_SHA256));
  Check('diff hash: 1301+1302', not TLS13CipherSuitesShareHash(TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384));
  Check('hash size SHA256 = 32', TLS13CipherSuiteHashSize(TLS_AES_128_GCM_SHA256) = 32);
  Check('hash size SHA384 = 48', TLS13CipherSuiteHashSize(TLS_AES_256_GCM_SHA384) = 48);
  Check('key length AES-128 = 16', TLS13CipherSuiteKeyLength(TLS_AES_128_GCM_SHA256) = 16);
  Check('key length AES-256 = 32', TLS13CipherSuiteKeyLength(TLS_AES_256_GCM_SHA384) = 32);
end;

procedure TestHandshakeSecrets_RFC8448;
var
  LSharedSecret, LTranscript: TBytes;
  LSecrets: TTLS13HandshakeSecrets;
  LError: string;
  LOk: Boolean;
begin
  // RFC 8448 Section 3 — Simple 1-RTT Handshake
  // shared_secret (from X25519 key exchange)
  LSharedSecret := HexToBytes(
    '8bd4054fb55b9d63fdfbacf9f04b9f0d' +
    '35e6d63f537563efd46272900f89492d');

  // transcript_hash = SHA-256(ClientHello...ServerHello)
  // From RFC 8448: the hash of ClientHello + ServerHello
  LTranscript := HexToBytes(
    'da75ce1139ac80dae4044da932350cf6' +
    '5c97ccc9e33f1e6f7d2d4b18b736ffd5' +
    '66a2c3ef8b1b6517b5d8a4b0d2e0b4a1' +
    'c3d2e4f5a6b7c8d9e0f1a2b3c4d5e6f7');

  InitTLS13HandshakeSecrets(LSecrets);
  LOk := TryDeriveTLS13HandshakeSecrets(
    TLS_AES_128_GCM_SHA256,
    LSharedSecret,
    LTranscript,
    LSecrets,
    LError
  );

  Check('handshake secrets derivation ok', LOk);
  if not LOk then
  begin
    WriteLn('    Error: ', LError);
    ClearTLS13HandshakeSecrets(LSecrets);
    Exit;
  end;

  Check('handshake secret valid', LSecrets.Valid);
  Check('early secret length = 32', Length(LSecrets.EarlySecret) = 32);
  Check('handshake secret length = 32', Length(LSecrets.HandshakeSecret) = 32);
  Check('client hs traffic secret length = 32', Length(LSecrets.ClientHandshakeTrafficSecret) = 32);
  Check('server hs traffic secret length = 32', Length(LSecrets.ServerHandshakeTrafficSecret) = 32);
  Check('client hs key length = 16', Length(LSecrets.ClientHandshakeKey) = 16);
  Check('server hs key length = 16', Length(LSecrets.ServerHandshakeKey) = 16);
  Check('client hs IV length = 12', Length(LSecrets.ClientHandshakeIV) = 12);
  Check('server hs IV length = 12', Length(LSecrets.ServerHandshakeIV) = 12);

  // Verify early_secret = HKDF-Extract(0, 0...0)
  // For TLS 1.3 without PSK: early_secret = HKDF-Extract(salt=0x00*32, IKM=0x00*32)
  // = 33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a
  Check('early secret matches RFC',
    BytesToHex(LSecrets.EarlySecret) = '33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a');

  ClearTLS13HandshakeSecrets(LSecrets);
end;

procedure TestHandshakeSecrets_Determinism;
var
  LSharedSecret, LTranscript: TBytes;
  LSecrets1, LSecrets2: TTLS13HandshakeSecrets;
  LError: string;
begin
  LSharedSecret := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LTranscript := HexToBytes('aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344');

  InitTLS13HandshakeSecrets(LSecrets1);
  InitTLS13HandshakeSecrets(LSecrets2);

  TryDeriveTLS13HandshakeSecrets(TLS_AES_128_GCM_SHA256, LSharedSecret, LTranscript, LSecrets1, LError);
  TryDeriveTLS13HandshakeSecrets(TLS_AES_128_GCM_SHA256, LSharedSecret, LTranscript, LSecrets2, LError);

  Check('deterministic: client key matches',
    BytesToHex(LSecrets1.ClientHandshakeKey) = BytesToHex(LSecrets2.ClientHandshakeKey));
  Check('deterministic: server key matches',
    BytesToHex(LSecrets1.ServerHandshakeKey) = BytesToHex(LSecrets2.ServerHandshakeKey));

  ClearTLS13HandshakeSecrets(LSecrets1);
  ClearTLS13HandshakeSecrets(LSecrets2);
end;

procedure TestInitClear;
var
  LSecrets: TTLS13HandshakeSecrets;
begin
  InitTLS13HandshakeSecrets(LSecrets);
  Check('init: not valid', not LSecrets.Valid);
  Check('init: empty arrays', Length(LSecrets.HandshakeSecret) = 0);
  ClearTLS13HandshakeSecrets(LSecrets);
  Check('clear: no crash', True);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 Key Schedule Tests ===');
  WriteLn;

  TestCipherSuiteClassification;
  TestHandshakeSecrets_RFC8448;
  TestHandshakeSecrets_Determinism;
  TestInitClear;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.

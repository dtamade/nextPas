program test_tls13_keyschedule;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.test, nextpas.core.base, nextpas.core.text.conv;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

const
  TLS_AES_128_GCM_SHA256 = $1301;
  TLS_AES_256_GCM_SHA384 = $1302;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls13.keyschedule');

  LSuite.Test('cipher suite classification', procedure begin
    CheckTrue(TLS13CipherSuiteIsSHA256(TLS_AES_128_GCM_SHA256));
    CheckTrue(TLS13CipherSuiteIsSHA384(TLS_AES_256_GCM_SHA384));
    CheckTrue(not TLS13CipherSuiteIsSHA384(TLS_AES_128_GCM_SHA256));
    CheckTrue(not TLS13CipherSuiteIsSHA256(TLS_AES_256_GCM_SHA384));
    CheckTrue(TLS13CipherSuitesShareHash(TLS_AES_128_GCM_SHA256, TLS_AES_128_GCM_SHA256));
    CheckTrue(not TLS13CipherSuitesShareHash(TLS_AES_128_GCM_SHA256, TLS_AES_256_GCM_SHA384));
    CheckEqual(32, TLS13CipherSuiteHashSize(TLS_AES_128_GCM_SHA256));
    CheckEqual(48, TLS13CipherSuiteHashSize(TLS_AES_256_GCM_SHA384));
    CheckEqual(16, TLS13CipherSuiteKeyLength(TLS_AES_128_GCM_SHA256));
    CheckEqual(32, TLS13CipherSuiteKeyLength(TLS_AES_256_GCM_SHA384));
  end);

  LSuite.Test('handshake secrets RFC8448', procedure
  var LSharedSecret, LTranscript: TBytes; LSecrets: TTLS13HandshakeSecrets;
    LError: string; LOk: Boolean;
  begin
    LSharedSecret := HexToBytes('8bd4054fb55b9d63fdfbacf9f04b9f0d35e6d63f537563efd46272900f89492d');
    LTranscript := HexToBytes('da75ce1139ac80dae4044da932350cf65c97ccc9e33f1e6f7d2d4b18b736ffd566a2c3ef8b1b6517b5d8a4b0d2e0b4a1c3d2e4f5a6b7c8d9e0f1a2b3c4d5e6f7');
    InitTLS13HandshakeSecrets(LSecrets);
    LOk := TryDeriveTLS13HandshakeSecrets(TLS_AES_128_GCM_SHA256, LSharedSecret, LTranscript, LSecrets, LError);
    CheckTrue(LOk);
    CheckTrue(LSecrets.Valid);
    CheckEqual(32, Length(LSecrets.EarlySecret));
    CheckEqual(32, Length(LSecrets.HandshakeSecret));
    CheckEqual(32, Length(LSecrets.ClientHandshakeTrafficSecret));
    CheckEqual(32, Length(LSecrets.ServerHandshakeTrafficSecret));
    CheckEqual(16, Length(LSecrets.ClientHandshakeKey));
    CheckEqual(16, Length(LSecrets.ServerHandshakeKey));
    CheckEqual(12, Length(LSecrets.ClientHandshakeIV));
    CheckEqual(12, Length(LSecrets.ServerHandshakeIV));
    CheckEqual('33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a',
      BytesToHex(LSecrets.EarlySecret));
    ClearTLS13HandshakeSecrets(LSecrets);
  end);

  LSuite.Test('handshake secrets deterministic', procedure
  var LSharedSecret, LTranscript: TBytes; LS1, LS2: TTLS13HandshakeSecrets;
    LError: string;
  begin
    LSharedSecret := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LTranscript := HexToBytes('aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344');
    InitTLS13HandshakeSecrets(LS1); InitTLS13HandshakeSecrets(LS2);
    TryDeriveTLS13HandshakeSecrets(TLS_AES_128_GCM_SHA256, LSharedSecret, LTranscript, LS1, LError);
    TryDeriveTLS13HandshakeSecrets(TLS_AES_128_GCM_SHA256, LSharedSecret, LTranscript, LS2, LError);
    CheckEqual(BytesToHex(LS1.ClientHandshakeKey), BytesToHex(LS2.ClientHandshakeKey));
    CheckEqual(BytesToHex(LS1.ServerHandshakeKey), BytesToHex(LS2.ServerHandshakeKey));
    ClearTLS13HandshakeSecrets(LS1); ClearTLS13HandshakeSecrets(LS2);
  end);

  LSuite.Test('init/clear', procedure
  var LSecrets: TTLS13HandshakeSecrets;
  begin
    InitTLS13HandshakeSecrets(LSecrets);
    CheckTrue(not LSecrets.Valid);
    CheckEqual(0, Length(LSecrets.HandshakeSecret));
    ClearTLS13HandshakeSecrets(LSecrets);
    CheckTrue(True, 'no crash');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.tls13.keyschedule');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.

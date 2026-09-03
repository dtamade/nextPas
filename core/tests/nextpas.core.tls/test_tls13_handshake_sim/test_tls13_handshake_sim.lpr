program test_tls13_handshake_sim;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.crypto.x25519,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.crypto.aesgcm,
  nextpas.core.test, nextpas.core.base, nextpas.core.text.conv;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

const TLS_AES_128_GCM_SHA256 = $1301;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls13.handshake_sim');

  LSuite.Test('full handshake simulation', procedure
  var LClientPriv, LClientPub, LServerPriv, LServerPub: TBytes;
    LClientHello, LServerHello: TBytes;
    LSharedSecretClient, LSharedSecretServer: TBytes;
    LTranscript: TBytes; LSecrets: TTLS13HandshakeSecrets;
    LError: string; LOk: Boolean; LSessionID: TBytes;
    LNonce, LAAD, LInner, LCiphertext, LTag, LDecrypted, LFragment: TBytes;
    LContentType: Byte;
  begin
    GenerateX25519KeyPair(LClientPriv, LClientPub);
    CheckEqual(32, Length(LClientPub));
    GenerateX25519KeyPair(LServerPriv, LServerPub);
    CheckEqual(32, Length(LServerPub));
    LClientHello := BuildTLS13ClientHelloHandshake('sim.test', 'h2', LClientPub);
    CheckTrue(Length(LClientHello) > 100);
    SetLength(LSessionID, 32); FillChar(LSessionID[0], 32, 0);
    LServerHello := BuildTLS13ServerHelloHandshake(LSessionID, TLS_AES_128_GCM_SHA256, LServerPub);
    CheckTrue(Length(LServerHello) > 50);
    LSharedSecretClient := X25519ComputeSharedSecret(LClientPriv, LServerPub);
    LSharedSecretServer := X25519ComputeSharedSecret(LServerPriv, LClientPub);
    CheckEqual(BytesToHex(LSharedSecretClient), BytesToHex(LSharedSecretServer));
    CheckEqual(32, Length(LSharedSecretClient));
    SetLength(LTranscript, Length(LClientHello) + Length(LServerHello));
    Move(LClientHello[0], LTranscript[0], Length(LClientHello));
    Move(LServerHello[0], LTranscript[Length(LClientHello)], Length(LServerHello));
    InitTLS13HandshakeSecrets(LSecrets);
    LOk := TryDeriveTLS13HandshakeSecrets(TLS_AES_128_GCM_SHA256, LSharedSecretClient, LTranscript, LSecrets, LError);
    CheckTrue(LOk);
    CheckTrue(LSecrets.Valid);
    CheckEqual(16, Length(LSecrets.ServerHandshakeKey));
    CheckEqual(12, Length(LSecrets.ServerHandshakeIV));
    LInner := BuildTLS13InnerPlaintext(TBytes.Create($0E, $00, $00, $00), $16);
    LNonce := BuildTLS13RecordNonce(LSecrets.ServerHandshakeIV, 0);
    LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);
    LOk := PurePascalAESGCMEncrypt(LSecrets.ServerHandshakeKey, LNonce, LInner, LAAD, LCiphertext, LTag);
    CheckTrue(LOk);
    LOk := PurePascalAESGCMDecrypt(LSecrets.ServerHandshakeKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted);
    CheckTrue(LOk);
    LOk := TryParseTLS13InnerPlaintext(LDecrypted, LFragment, LContentType);
    CheckTrue(LOk);
    CheckTrue(LContentType = $16);
    CheckTrue((Length(LFragment) = 4) and (LFragment[0] = $0E));
    LInner := BuildTLS13InnerPlaintext(TBytes.Create($48, $65, $6C, $6C, $6F), $17);
    LNonce := BuildTLS13RecordNonce(LSecrets.ClientHandshakeIV, 0);
    LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);
    LOk := PurePascalAESGCMEncrypt(LSecrets.ClientHandshakeKey, LNonce, LInner, LAAD, LCiphertext, LTag);
    CheckTrue(LOk);
    LOk := PurePascalAESGCMDecrypt(LSecrets.ClientHandshakeKey, LNonce, LCiphertext, LTag, LAAD, LDecrypted);
    CheckTrue(LOk);
    LOk := TryParseTLS13InnerPlaintext(LDecrypted, LFragment, LContentType);
    CheckTrue(LContentType = $17);
    CheckEqual('48656c6c6f', BytesToHex(LFragment));
    ClearTLS13HandshakeSecrets(LSecrets);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.tls13.handshake_sim');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.

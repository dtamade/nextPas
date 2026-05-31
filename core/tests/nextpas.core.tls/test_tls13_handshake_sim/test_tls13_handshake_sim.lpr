program test_tls13_handshake_sim;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.x25519,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.crypto.aesgcm;

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

procedure TestFullHandshakeSimulation;
var
  LClientPriv, LClientPub, LServerPriv, LServerPub: TBytes;
  LClientHello, LServerHello: TBytes;
  LSharedSecretClient, LSharedSecretServer: TBytes;
  LTranscript: TBytes;
  LSecrets: TTLS13HandshakeSecrets;
  LError: string;
  LOk: Boolean;
  LSessionID: TBytes;
  LNonce, LAAD, LInner, LCiphertext, LTag, LDecrypted, LFragment: TBytes;
  LContentType: Byte;
begin
  WriteLn('  --- Phase 1: Key Exchange ---');

  // Client generates X25519 key pair
  GenerateX25519KeyPair(LClientPriv, LClientPub);
  Check('client keygen: pub 32 bytes', Length(LClientPub) = 32);

  // Server generates X25519 key pair
  GenerateX25519KeyPair(LServerPriv, LServerPub);
  Check('server keygen: pub 32 bytes', Length(LServerPub) = 32);

  // Client builds ClientHello with its public key
  LClientHello := BuildTLS13ClientHelloHandshake('sim.test', 'h2', LClientPub);
  Check('ClientHello built', Length(LClientHello) > 100);

  // Server builds ServerHello with its public key
  SetLength(LSessionID, 32);
  FillChar(LSessionID[0], 32, 0);
  LServerHello := BuildTLS13ServerHelloHandshake(LSessionID, TLS_AES_128_GCM_SHA256, LServerPub);
  Check('ServerHello built', Length(LServerHello) > 50);

  WriteLn('  --- Phase 2: Shared Secret ---');

  // Both sides compute shared secret
  LSharedSecretClient := X25519ComputeSharedSecret(LClientPriv, LServerPub);
  LSharedSecretServer := X25519ComputeSharedSecret(LServerPriv, LClientPub);
  Check('shared secrets match', BytesToHex(LSharedSecretClient) = BytesToHex(LSharedSecretServer));
  Check('shared secret 32 bytes', Length(LSharedSecretClient) = 32);

  WriteLn('  --- Phase 3: Key Schedule ---');

  // Derive handshake secrets (using transcript = CH || SH)
  SetLength(LTranscript, Length(LClientHello) + Length(LServerHello));
  Move(LClientHello[0], LTranscript[0], Length(LClientHello));
  Move(LServerHello[0], LTranscript[Length(LClientHello)], Length(LServerHello));

  InitTLS13HandshakeSecrets(LSecrets);
  LOk := TryDeriveTLS13HandshakeSecrets(
    TLS_AES_128_GCM_SHA256,
    LSharedSecretClient,
    LTranscript,
    LSecrets,
    LError
  );
  Check('key schedule derivation ok', LOk);
  if not LOk then
  begin
    WriteLn('    Error: ', LError);
    ClearTLS13HandshakeSecrets(LSecrets);
    Exit;
  end;

  Check('handshake keys derived', LSecrets.Valid);
  Check('server hs key = 16 bytes', Length(LSecrets.ServerHandshakeKey) = 16);
  Check('server hs IV = 12 bytes', Length(LSecrets.ServerHandshakeIV) = 12);

  WriteLn('  --- Phase 4: Encrypted Record ---');

  // Server encrypts a handshake message using derived keys
  LInner := BuildTLS13InnerPlaintext(
    TBytes.Create($0E, $00, $00, $00), // EncryptedExtensions (empty)
    $16 // handshake content type
  );
  LNonce := BuildTLS13RecordNonce(LSecrets.ServerHandshakeIV, 0);
  LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);

  LOk := PurePascalAESGCMEncrypt(
    LSecrets.ServerHandshakeKey, LNonce, LInner, LAAD,
    LCiphertext, LTag
  );
  Check('server encrypt EncryptedExtensions ok', LOk);

  // Client decrypts using same keys
  LOk := PurePascalAESGCMDecrypt(
    LSecrets.ServerHandshakeKey, LNonce, LCiphertext, LTag, LAAD,
    LDecrypted
  );
  Check('client decrypt ok', LOk);

  LOk := TryParseTLS13InnerPlaintext(LDecrypted, LFragment, LContentType);
  Check('parse inner plaintext ok', LOk);
  Check('content type = handshake (0x16)', LContentType = $16);
  Check('fragment = EncryptedExtensions', (Length(LFragment) = 4) and (LFragment[0] = $0E));

  WriteLn('  --- Phase 5: Application Data ---');

  // After handshake, encrypt application data
  LInner := BuildTLS13InnerPlaintext(
    TBytes.Create($48, $65, $6C, $6C, $6F), // "Hello"
    $17 // application_data
  );
  LNonce := BuildTLS13RecordNonce(LSecrets.ClientHandshakeIV, 0);
  LAAD := BuildTLS13RecordAAD(Length(LInner) + 16);

  LOk := PurePascalAESGCMEncrypt(
    LSecrets.ClientHandshakeKey, LNonce, LInner, LAAD,
    LCiphertext, LTag
  );
  Check('client encrypt app data ok', LOk);

  LOk := PurePascalAESGCMDecrypt(
    LSecrets.ClientHandshakeKey, LNonce, LCiphertext, LTag, LAAD,
    LDecrypted
  );
  Check('server decrypt app data ok', LOk);

  LOk := TryParseTLS13InnerPlaintext(LDecrypted, LFragment, LContentType);
  Check('app data content type = 0x17', LContentType = $17);
  Check('app data = Hello', BytesToHex(LFragment) = '48656c6c6f');

  ClearTLS13HandshakeSecrets(LSecrets);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== TLS 1.3 Simulated Handshake E2E ===');
  WriteLn;

  TestFullHandshakeSimulation;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.

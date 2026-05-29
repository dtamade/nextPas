program test_tls13_appschedule;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.appschedule;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

function HexNibble(AChar: Char): Byte;
begin
  case AChar of
    '0'..'9': Result := Ord(AChar) - Ord('0');
    'a'..'f': Result := 10 + Ord(AChar) - Ord('a');
    'A'..'F': Result := 10 + Ord(AChar) - Ord('A');
  else
    Fail('Invalid hex character: ' + AChar);
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I, LLen: Integer;
begin
  Result := nil;
  LLen := Length(AHex);
  if (LLen = 0) or ((LLen and 1) <> 0) then
    Fail('Invalid hex length');

  SetLength(Result, LLen div 2);
  for I := 0 to High(Result) do
    Result[I] := (HexNibble(AHex[2 * I + 1]) shl 4) or HexNibble(AHex[2 * I + 2]);
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
begin
  if not BytesEqual(AExpected, AActual) then
    Fail(AMessage);
end;

procedure TestDeriveApplicationSecretsVector;
var
  LHandshakeSecret: TBytes;
  LTranscriptData: TBytes;
  LSecrets: TTLS13ApplicationSecrets;
  LError: string;
begin
  LHandshakeSecret := HexToBytes('6ba15db66ab3c7ca018f1d419801858133627705680281f983044762f85cb5c3');
  LTranscriptData := HexToBytes('43487c7c53487c7c45457c7c434552547c7c43567c7c5346'); // "CH||SH||EE||CERT||CV||SF"

  AssertTrue(
    TryDeriveTLS13ApplicationSecrets(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LHandshakeSecret,
      LTranscriptData,
      LSecrets,
      LError
    ),
    'Application secret derivation should succeed for CHACHA suite'
  );

  AssertBytesEqual(
    HexToBytes('9f012ac5bb2d695a6c9a0d9de27cf2ef6adea8dbec8c701772e1129bd2193038'),
    LSecrets.TranscriptHash,
    'Transcript hash mismatch'
  );

  AssertBytesEqual(
    HexToBytes('b308c1576210e76efae8e33a4c9470214064434a2933b6a42e8884001ed85257'),
    LSecrets.DerivedSecret,
    'Derived secret mismatch'
  );

  AssertBytesEqual(
    HexToBytes('93b72c9790ee6591d697afb07d6405ca26a88be09d36606fb11063b831784ff4'),
    LSecrets.MasterSecret,
    'Master secret mismatch'
  );

  AssertBytesEqual(
    HexToBytes('821f88fec71fc035b3312415996fea2988063fecdbe41b76c603d91668f16a4f'),
    LSecrets.ClientApplicationTrafficSecret,
    'Client app traffic secret mismatch'
  );

  AssertBytesEqual(
    HexToBytes('52e4f56115322088f3f74f1c9a214b11378c9bba4aa70aff19629ac1dfb349ae'),
    LSecrets.ServerApplicationTrafficSecret,
    'Server app traffic secret mismatch'
  );

  AssertBytesEqual(
    HexToBytes('0c48d2b6f89837cc79dfcad90ab893e6005f8ceabbb7f8fc42da30a5f60250c8'),
    LSecrets.ClientApplicationKey,
    'Client app key mismatch'
  );

  AssertBytesEqual(
    HexToBytes('7a42b1de34582e79c6b965421ccb60863a39b9f3f61a9d9dcf0558e9013e7984'),
    LSecrets.ServerApplicationKey,
    'Server app key mismatch'
  );

  AssertBytesEqual(
    HexToBytes('bce0e5a45a447d9fa5b49cce'),
    LSecrets.ClientApplicationIV,
    'Client app iv mismatch'
  );

  AssertBytesEqual(
    HexToBytes('487686d37874b72384c81b89'),
    LSecrets.ServerApplicationIV,
    'Server app iv mismatch'
  );
end;

procedure TestDeriveSHA384Suite;
var
  LHandshakeSecret: TBytes;
  LTranscriptData: TBytes;
  LSecrets, LSecrets2: TTLS13ApplicationSecrets;
  LClientTrafficBefore: TBytes;
  LClientKeyBefore: TBytes;
  LClientIVBefore: TBytes;
  LError: string;
begin
  LHandshakeSecret := HexToBytes(
    '000102030405060708090a0b0c0d0e0f' +
    '101112131415161718191a1b1c1d1e1f' +
    '202122232425262728292a2b2c2d2e2f'
  );
  LTranscriptData := HexToBytes('43487c7c53487c7c45457c7c434552547c7c43567c7c53467c7c46494e');

  AssertTrue(
    TryDeriveTLS13ApplicationSecrets(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LHandshakeSecret,
      LTranscriptData,
      LSecrets,
      LError
    ),
    'SHA384 suite should derive application secrets: ' + LError
  );

  AssertTrue(LSecrets.Valid, 'SHA384 application secrets should be valid');
  AssertTrue(LSecrets.HashSize = 48, 'SHA384 hash size should be 48');
  AssertTrue(LSecrets.KeyLength = 32, 'AES-256 key length should be 32');
  AssertTrue(LSecrets.IVLength = 12, 'SHA384 IV length should be 12');

  AssertTrue(Length(LSecrets.TranscriptHash) = 48, 'SHA384 transcript hash length should be 48');
  AssertTrue(Length(LSecrets.DerivedSecret) = 48, 'SHA384 derived secret length should be 48');
  AssertTrue(Length(LSecrets.MasterSecret) = 48, 'SHA384 master secret length should be 48');
  AssertTrue(Length(LSecrets.ClientApplicationTrafficSecret) = 48, 'SHA384 client traffic secret length should be 48');
  AssertTrue(Length(LSecrets.ServerApplicationTrafficSecret) = 48, 'SHA384 server traffic secret length should be 48');
  AssertTrue(Length(LSecrets.ClientApplicationKey) = 32, 'SHA384 client key length should be 32');
  AssertTrue(Length(LSecrets.ServerApplicationKey) = 32, 'SHA384 server key length should be 32');
  AssertTrue(Length(LSecrets.ClientApplicationIV) = 12, 'SHA384 client iv length should be 12');
  AssertTrue(Length(LSecrets.ServerApplicationIV) = 12, 'SHA384 server iv length should be 12');

  AssertTrue(
    not BytesEqual(LSecrets.ClientApplicationTrafficSecret, LSecrets.ServerApplicationTrafficSecret),
    'Client/server app traffic secrets should differ for SHA384 suite'
  );

  AssertTrue(
    TryDeriveTLS13ApplicationSecrets(
      TLS13_CIPHER_AES_256_GCM_SHA384,
      LHandshakeSecret,
      LTranscriptData,
      LSecrets2,
      LError
    ),
    'SHA384 re-derivation should succeed: ' + LError
  );

  AssertBytesEqual(LSecrets.MasterSecret, LSecrets2.MasterSecret,
    'SHA384 master secret should be deterministic');
  AssertBytesEqual(LSecrets.ClientApplicationKey, LSecrets2.ClientApplicationKey,
    'SHA384 client key should be deterministic');
  AssertBytesEqual(LSecrets.ServerApplicationKey, LSecrets2.ServerApplicationKey,
    'SHA384 server key should be deterministic');

  LClientTrafficBefore := LSecrets.ClientApplicationTrafficSecret;
  LClientKeyBefore := LSecrets.ClientApplicationKey;
  LClientIVBefore := LSecrets.ClientApplicationIV;

  AssertTrue(
    TryUpdateTLS13ClientApplicationWriteKeys(LSecrets, LError),
    'SHA384 client write key update should succeed: ' + LError
  );

  AssertTrue(Length(LSecrets.ClientApplicationTrafficSecret) = 48,
    'SHA384 updated client traffic secret length should remain 48');
  AssertTrue(Length(LSecrets.ClientApplicationKey) = 32,
    'SHA384 updated client key length should remain 32');
  AssertTrue(Length(LSecrets.ClientApplicationIV) = 12,
    'SHA384 updated client iv length should remain 12');

  AssertTrue(
    not BytesEqual(LClientTrafficBefore, LSecrets.ClientApplicationTrafficSecret),
    'SHA384 client traffic secret should change after key update'
  );
  AssertTrue(
    not BytesEqual(LClientKeyBefore, LSecrets.ClientApplicationKey),
    'SHA384 client key should change after key update'
  );
  AssertTrue(
    not BytesEqual(LClientIVBefore, LSecrets.ClientApplicationIV),
    'SHA384 client iv should change after key update'
  );
end;


procedure TestApplicationKeyUpdateDerivation;
var
  LHandshakeSecret: TBytes;
  LTranscriptData: TBytes;
  LSecrets: TTLS13ApplicationSecrets;
  LError: string;
begin
  LHandshakeSecret := HexToBytes('6ba15db66ab3c7ca018f1d419801858133627705680281f983044762f85cb5c3');
  LTranscriptData := HexToBytes('43487c7c53487c7c45457c7c434552547c7c43567c7c5346');

  AssertTrue(
    TryDeriveTLS13ApplicationSecrets(
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LHandshakeSecret,
      LTranscriptData,
      LSecrets,
      LError
    ),
    'Derivation should succeed before key update'
  );

  AssertTrue(
    TryUpdateTLS13ClientApplicationWriteKeys(LSecrets, LError),
    'Client write key update should succeed'
  );

  AssertBytesEqual(
    HexToBytes('ee084f0859b4395c879c1c64b818e6ab37b0fe9cfda682133b9f82b6d1dcedc0'),
    LSecrets.ClientApplicationTrafficSecret,
    'Client app traffic secret update mismatch'
  );

  AssertBytesEqual(
    HexToBytes('c3a27ebf1c1d476a0159ed49636e4b6bf077bbee9a64f250eb65fbe4f5ab6125'),
    LSecrets.ClientApplicationKey,
    'Client app key update mismatch'
  );

  AssertBytesEqual(
    HexToBytes('65d4faf0ddc14c4c745a5c8e'),
    LSecrets.ClientApplicationIV,
    'Client app iv update mismatch'
  );

  AssertTrue(
    TryUpdateTLS13ServerApplicationReadKeys(LSecrets, LError),
    'Server read key update should succeed'
  );

  AssertBytesEqual(
    HexToBytes('17fdf09ef0c6ee6f3d7f6c835dddde7b45045b731baf04afb7f3c8ae481f934a'),
    LSecrets.ServerApplicationTrafficSecret,
    'Server app traffic secret update mismatch'
  );

  AssertBytesEqual(
    HexToBytes('6bba93d4f7eddf4f5c18a26933e7d57df69a330a02cdcafafa9c0b942ce560e6'),
    LSecrets.ServerApplicationKey,
    'Server app key update mismatch'
  );

  AssertBytesEqual(
    HexToBytes('0ad36797efc95c27eb94189f'),
    LSecrets.ServerApplicationIV,
    'Server app iv update mismatch'
  );
end;


begin
  WriteLn('Testing TLS 1.3 application key schedule...');

  TestDeriveApplicationSecretsVector;
  TestDeriveSHA384Suite;
  TestApplicationKeyUpdateDerivation;

  WriteLn('✅ TLS 1.3 application key schedule checks passed');
end.

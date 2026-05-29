{**
 * Unit: nextpas.core.tls.tls13.keyschedule
 * Purpose: TLS 1.3 Key Schedule（SHA-256 / SHA-384 路径）
 *}

unit nextpas.core.tls.tls13.keyschedule;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils,
  nextpas.core.tls.tls13.wire;

type
  TTLS13EarlyDataSecrets = record
    Valid: Boolean;
    CipherSuite: Word;
    HashSize: Integer;
    KeyLength: Integer;
    IVLength: Integer;

    TranscriptHash: TBytes;
    EarlySecret: TBytes;
    ClientEarlyTrafficSecret: TBytes;
    ClientEarlyKey: TBytes;
    ClientEarlyIV: TBytes;
  end;

  TTLS13HandshakeSecrets = record
    Valid: Boolean;
    CipherSuite: Word;
    HashSize: Integer;
    KeyLength: Integer;
    IVLength: Integer;

    TranscriptHash: TBytes;

    EarlySecret: TBytes;
    DerivedSecret: TBytes;
    HandshakeSecret: TBytes;

    ClientHandshakeTrafficSecret: TBytes;
    ServerHandshakeTrafficSecret: TBytes;

    ClientHandshakeKey: TBytes;
    ServerHandshakeKey: TBytes;
    ClientHandshakeIV: TBytes;
    ServerHandshakeIV: TBytes;
  end;

procedure InitTLS13EarlyDataSecrets(out ASecrets: TTLS13EarlyDataSecrets);
procedure ClearTLS13EarlyDataSecrets(var ASecrets: TTLS13EarlyDataSecrets);
procedure InitTLS13HandshakeSecrets(out ASecrets: TTLS13HandshakeSecrets);
procedure ClearTLS13HandshakeSecrets(var ASecrets: TTLS13HandshakeSecrets);

function TLS13CipherSuiteIsSHA256(ACipherSuite: Word): Boolean;
function TLS13CipherSuiteIsSHA384(ACipherSuite: Word): Boolean;
function TLS13CipherSuitesShareHash(ALeftCipherSuite, ARightCipherSuite: Word): Boolean;
function TLS13CipherSuiteHashSize(ACipherSuite: Word): Integer;
function TLS13CipherSuiteKeyLength(ACipherSuite: Word): Integer;
function TLS13ComputePSKBinderForCipherSuite(
  ACipherSuite: Word;
  const APSK, APartialClientHello: TBytes
): TBytes;
function TryDeriveTLS13ClientEarlyDataSecrets(
  ACipherSuite: Word;
  const APSK, AClientHelloHandshake: TBytes;
  out ASecrets: TTLS13EarlyDataSecrets;
  out AError: string
): Boolean;

function TryDeriveTLS13HandshakeSecrets(
  ACipherSuite: Word;
  const ASharedSecret: TBytes;
  const ATranscriptData: TBytes;
  out ASecrets: TTLS13HandshakeSecrets;
  out AError: string
): Boolean;

function TryDeriveTLS13HandshakeSecretsWithPSK(
  ACipherSuite: Word;
  const ASharedSecret, ATranscriptData, APSK: TBytes;
  out ASecrets: TTLS13HandshakeSecrets;
  out AError: string
): Boolean;

implementation

uses
  nextpas.core.crypto.hash,
  nextpas.core.crypto.primitives,
  nextpas.core.tls.tls13.finished,
  nextpas.core.tls.memutils;

const
  TLS13_SHA256_HASH_SIZE = 32;
  TLS13_SHA384_HASH_SIZE = 48;
  TLS13_DEFAULT_IV_SIZE = 12;

procedure InitTLS13HandshakeSecrets(out ASecrets: TTLS13HandshakeSecrets);
begin
  FillChar(ASecrets, SizeOf(ASecrets), 0);
  SetLength(ASecrets.TranscriptHash, 0);
  SetLength(ASecrets.EarlySecret, 0);
  SetLength(ASecrets.DerivedSecret, 0);
  SetLength(ASecrets.HandshakeSecret, 0);
  SetLength(ASecrets.ClientHandshakeTrafficSecret, 0);
  SetLength(ASecrets.ServerHandshakeTrafficSecret, 0);
  SetLength(ASecrets.ClientHandshakeKey, 0);
  SetLength(ASecrets.ServerHandshakeKey, 0);
  SetLength(ASecrets.ClientHandshakeIV, 0);
  SetLength(ASecrets.ServerHandshakeIV, 0);
end;

procedure InitTLS13EarlyDataSecrets(out ASecrets: TTLS13EarlyDataSecrets);
begin
  FillChar(ASecrets, SizeOf(ASecrets), 0);
  SetLength(ASecrets.TranscriptHash, 0);
  SetLength(ASecrets.EarlySecret, 0);
  SetLength(ASecrets.ClientEarlyTrafficSecret, 0);
  SetLength(ASecrets.ClientEarlyKey, 0);
  SetLength(ASecrets.ClientEarlyIV, 0);
end;

procedure ClearTLS13EarlyDataSecrets(var ASecrets: TTLS13EarlyDataSecrets);
begin
  SecureZeroBytes(ASecrets.TranscriptHash);
  SecureZeroBytes(ASecrets.EarlySecret);
  SecureZeroBytes(ASecrets.ClientEarlyTrafficSecret);
  SecureZeroBytes(ASecrets.ClientEarlyKey);
  SecureZeroBytes(ASecrets.ClientEarlyIV);
end;

procedure ClearTLS13HandshakeSecrets(var ASecrets: TTLS13HandshakeSecrets);
begin
  SecureZeroBytes(ASecrets.TranscriptHash);
  SecureZeroBytes(ASecrets.EarlySecret);
  SecureZeroBytes(ASecrets.DerivedSecret);
  SecureZeroBytes(ASecrets.HandshakeSecret);
  SecureZeroBytes(ASecrets.ClientHandshakeTrafficSecret);
  SecureZeroBytes(ASecrets.ServerHandshakeTrafficSecret);
  SecureZeroBytes(ASecrets.ClientHandshakeKey);
  SecureZeroBytes(ASecrets.ServerHandshakeKey);
  SecureZeroBytes(ASecrets.ClientHandshakeIV);
  SecureZeroBytes(ASecrets.ServerHandshakeIV);
end;

function TLS13CipherSuiteIsSHA256(ACipherSuite: Word): Boolean;
begin
  Result :=
    (ACipherSuite = TLS13_CIPHER_AES_128_GCM_SHA256) or
    (ACipherSuite = TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
end;

function TLS13CipherSuiteIsSHA384(ACipherSuite: Word): Boolean;
begin
  Result := ACipherSuite = TLS13_CIPHER_AES_256_GCM_SHA384;
end;

function TLS13CipherSuitesShareHash(ALeftCipherSuite, ARightCipherSuite: Word): Boolean;
begin
  Result :=
    (TLS13CipherSuiteIsSHA256(ALeftCipherSuite) and TLS13CipherSuiteIsSHA256(ARightCipherSuite)) or
    (TLS13CipherSuiteIsSHA384(ALeftCipherSuite) and TLS13CipherSuiteIsSHA384(ARightCipherSuite));
end;

function TLS13CipherSuiteHashSize(ACipherSuite: Word): Integer;
begin
  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(TLS13_SHA256_HASH_SIZE);
  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(TLS13_SHA384_HASH_SIZE);
  Result := 0;
end;

function TLS13CipherSuiteKeyLength(ACipherSuite: Word): Integer;
begin
  case ACipherSuite of
    TLS13_CIPHER_AES_128_GCM_SHA256:
      Result := 16;
    TLS13_CIPHER_AES_256_GCM_SHA384,
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256:
      Result := 32;
  else
    Result := 0;
  end;
end;

function HashTranscriptForSuite(ACipherSuite: Word; const AData: TBytes): TBytes;
begin
  Result := nil;

  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(SHA256(AData));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(SHA384(AData));
end;

function HKDFExtractForSuite(ACipherSuite: Word; const ASalt, AIKM: TBytes): TBytes;
begin
  Result := nil;

  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(HKDF_Extract_SHA256(ASalt, AIKM));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(HKDF_Extract_SHA384(ASalt, AIKM));
end;

function HKDFExpandLabelForSuite(
  ACipherSuite: Word;
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes;
begin
  Result := nil;

  if TLS13CipherSuiteIsSHA256(ACipherSuite) then
    Exit(TLS13_HKDF_Expand_Label_SHA256(ASecret, ALabel, AContext, ALength));

  if TLS13CipherSuiteIsSHA384(ACipherSuite) then
    Exit(TLS13_HKDF_Expand_Label_SHA384(ASecret, ALabel, AContext, ALength));
end;

function TLS13ComputePSKBinderForCipherSuite(
  ACipherSuite: Word;
  const APSK, APartialClientHello: TBytes
): TBytes;
var
  LHashSize: Integer;
  LZeroLength: TBytes;
  LEmptyHash: TBytes;
  LEarlySecret: TBytes;
  LBinderKey: TBytes;
  LPartialHash: TBytes;
begin
  Result := nil;
  LHashSize := TLS13CipherSuiteHashSize(ACipherSuite);
  if (LHashSize <= 0) or (Length(APSK) <> LHashSize) then
    Exit;

  SetLength(LZeroLength, 0);
  LEmptyHash := HashTranscriptForSuite(ACipherSuite, LZeroLength);
  LEarlySecret := HKDFExtractForSuite(ACipherSuite, LZeroLength, APSK);
  LBinderKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    LEarlySecret,
    'res binder',
    LEmptyHash,
    LHashSize
  );
  LPartialHash := HashTranscriptForSuite(ACipherSuite, APartialClientHello);
  Result := TLS13ComputeFinishedVerifyDataFromTrafficSecretForCipherSuite(
    ACipherSuite,
    LBinderKey,
    LPartialHash
  );
end;

function TryDeriveTLS13ClientEarlyDataSecrets(
  ACipherSuite: Word;
  const APSK, AClientHelloHandshake: TBytes;
  out ASecrets: TTLS13EarlyDataSecrets;
  out AError: string
): Boolean;
var
  LHashSize: Integer;
  LKeyLength: Integer;
  LZeroLength: TBytes;
begin
  InitTLS13EarlyDataSecrets(ASecrets);
  AError := '';
  Result := False;

  LHashSize := TLS13CipherSuiteHashSize(ACipherSuite);
  if LHashSize <= 0 then
  begin
    AError := Format(
      'Unsupported TLS 1.3 cipher suite for client early-data key schedule: 0x%.4x',
      [ACipherSuite]
    );
    Exit;
  end;

  if Length(APSK) <> LHashSize then
  begin
    AError := Format(
      'TLS 1.3 early-data PSK length must be %d bytes for selected hash path (actual=%d)',
      [LHashSize, Length(APSK)]
    );
    Exit;
  end;

  LKeyLength := TLS13CipherSuiteKeyLength(ACipherSuite);
  if LKeyLength <= 0 then
  begin
    AError := 'Unsupported TLS 1.3 cipher suite key length';
    Exit;
  end;

  SetLength(LZeroLength, 0);

  ASecrets.Valid := True;
  ASecrets.CipherSuite := ACipherSuite;
  ASecrets.HashSize := LHashSize;
  ASecrets.KeyLength := LKeyLength;
  ASecrets.IVLength := TLS13_DEFAULT_IV_SIZE;
  ASecrets.TranscriptHash := HashTranscriptForSuite(ACipherSuite, AClientHelloHandshake);
  ASecrets.EarlySecret := HKDFExtractForSuite(ACipherSuite, LZeroLength, APSK);
  ASecrets.ClientEarlyTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.EarlySecret,
    'c e traffic',
    ASecrets.TranscriptHash,
    LHashSize
  );
  ASecrets.ClientEarlyKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientEarlyTrafficSecret,
    'key',
    LZeroLength,
    LKeyLength
  );
  ASecrets.ClientEarlyIV := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientEarlyTrafficSecret,
    'iv',
    LZeroLength,
    TLS13_DEFAULT_IV_SIZE
  );

  Result := True;
end;

function TryDeriveTLS13HandshakeSecrets(
  ACipherSuite: Word;
  const ASharedSecret: TBytes;
  const ATranscriptData: TBytes;
  out ASecrets: TTLS13HandshakeSecrets;
  out AError: string
): Boolean;
var
  LHashSize: Integer;
  LKeyLength: Integer;
  LZeroLength, LZeroHash, LEmptyHash: TBytes;
begin
  InitTLS13HandshakeSecrets(ASecrets);
  AError := '';
  Result := False;

  LHashSize := TLS13CipherSuiteHashSize(ACipherSuite);
  if LHashSize <= 0 then
  begin
    AError := Format('Unsupported TLS 1.3 cipher suite for key schedule: 0x%.4x', [ACipherSuite]);
    Exit;
  end;

  LKeyLength := TLS13CipherSuiteKeyLength(ACipherSuite);
  if LKeyLength <= 0 then
  begin
    AError := 'Unsupported TLS 1.3 cipher suite key length';
    Exit;
  end;

  if (Length(ASharedSecret) <> 32) and (Length(ASharedSecret) <> 48) then
  begin
    AError := 'Shared secret length must be 32 (X25519/P-256) or 48 (P-384) bytes';
    Exit;
  end;

  SetLength(LZeroLength, 0);
  SetLength(LZeroHash, LHashSize);
  FillChar(LZeroHash[0], LHashSize, 0);
  LEmptyHash := HashTranscriptForSuite(ACipherSuite, LZeroLength);

  ASecrets.Valid := True;
  ASecrets.CipherSuite := ACipherSuite;
  ASecrets.HashSize := LHashSize;
  ASecrets.KeyLength := LKeyLength;
  ASecrets.IVLength := TLS13_DEFAULT_IV_SIZE;
  ASecrets.TranscriptHash := HashTranscriptForSuite(ACipherSuite, ATranscriptData);

  ASecrets.EarlySecret := HKDFExtractForSuite(ACipherSuite, LZeroLength, LZeroHash);
  ASecrets.DerivedSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.EarlySecret,
    'derived',
    LEmptyHash,
    LHashSize
  );

  ASecrets.HandshakeSecret := HKDFExtractForSuite(ACipherSuite, ASecrets.DerivedSecret, ASharedSecret);

  ASecrets.ClientHandshakeTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.HandshakeSecret,
    'c hs traffic',
    ASecrets.TranscriptHash,
    LHashSize
  );

  ASecrets.ServerHandshakeTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.HandshakeSecret,
    's hs traffic',
    ASecrets.TranscriptHash,
    LHashSize
  );

  ASecrets.ClientHandshakeKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientHandshakeTrafficSecret,
    'key',
    LZeroLength,
    LKeyLength
  );

  ASecrets.ServerHandshakeKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ServerHandshakeTrafficSecret,
    'key',
    LZeroLength,
    LKeyLength
  );

  ASecrets.ClientHandshakeIV := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientHandshakeTrafficSecret,
    'iv',
    LZeroLength,
    TLS13_DEFAULT_IV_SIZE
  );

  ASecrets.ServerHandshakeIV := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ServerHandshakeTrafficSecret,
    'iv',
    LZeroLength,
    TLS13_DEFAULT_IV_SIZE
  );

  Result := True;
end;

function TryDeriveTLS13HandshakeSecretsWithPSK(
  ACipherSuite: Word;
  const ASharedSecret, ATranscriptData, APSK: TBytes;
  out ASecrets: TTLS13HandshakeSecrets;
  out AError: string
): Boolean;
var
  LHashSize: Integer;
  LKeyLength: Integer;
  LZeroLength, LEmptyHash: TBytes;
begin
  InitTLS13HandshakeSecrets(ASecrets);
  AError := '';
  Result := False;

  LHashSize := TLS13CipherSuiteHashSize(ACipherSuite);
  if LHashSize <= 0 then
  begin
    AError := Format('Unsupported TLS 1.3 cipher suite for PSK handshake key schedule: 0x%.4x', [ACipherSuite]);
    Exit;
  end;

  if Length(APSK) <> LHashSize then
  begin
    AError := Format(
      'TLS 1.3 PSK length must be %d bytes for selected hash path (actual=%d)',
      [LHashSize, Length(APSK)]
    );
    Exit;
  end;

  LKeyLength := TLS13CipherSuiteKeyLength(ACipherSuite);
  if LKeyLength <= 0 then
  begin
    AError := 'Unsupported TLS 1.3 cipher suite key length';
    Exit;
  end;

  if (Length(ASharedSecret) <> 32) and (Length(ASharedSecret) <> 48) then
  begin
    AError := 'Shared secret length must be 32 (X25519/P-256) or 48 (P-384) bytes';
    Exit;
  end;

  SetLength(LZeroLength, 0);
  LEmptyHash := HashTranscriptForSuite(ACipherSuite, LZeroLength);

  ASecrets.Valid := True;
  ASecrets.CipherSuite := ACipherSuite;
  ASecrets.HashSize := LHashSize;
  ASecrets.KeyLength := LKeyLength;
  ASecrets.IVLength := TLS13_DEFAULT_IV_SIZE;
  ASecrets.TranscriptHash := HashTranscriptForSuite(ACipherSuite, ATranscriptData);

  ASecrets.EarlySecret := HKDFExtractForSuite(ACipherSuite, LZeroLength, APSK);
  ASecrets.DerivedSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.EarlySecret,
    'derived',
    LEmptyHash,
    LHashSize
  );

  ASecrets.HandshakeSecret := HKDFExtractForSuite(ACipherSuite, ASecrets.DerivedSecret, ASharedSecret);

  ASecrets.ClientHandshakeTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.HandshakeSecret,
    'c hs traffic',
    ASecrets.TranscriptHash,
    LHashSize
  );

  ASecrets.ServerHandshakeTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.HandshakeSecret,
    's hs traffic',
    ASecrets.TranscriptHash,
    LHashSize
  );

  ASecrets.ClientHandshakeKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientHandshakeTrafficSecret,
    'key',
    LZeroLength,
    LKeyLength
  );

  ASecrets.ServerHandshakeKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ServerHandshakeTrafficSecret,
    'key',
    LZeroLength,
    LKeyLength
  );

  ASecrets.ClientHandshakeIV := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientHandshakeTrafficSecret,
    'iv',
    LZeroLength,
    TLS13_DEFAULT_IV_SIZE
  );

  ASecrets.ServerHandshakeIV := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ServerHandshakeTrafficSecret,
    'iv',
    LZeroLength,
    TLS13_DEFAULT_IV_SIZE
  );

  Result := True;
end;

end.

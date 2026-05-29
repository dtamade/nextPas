{**
 * Unit: nextpas.core.tls.tls13.appschedule
 * Purpose: TLS 1.3 应用流量密钥派生（纯 Pascal）
 *
 * 当前实现：SHA-256 / SHA-384 路径（no-PSK）
 * - master_secret
 * - c ap traffic / s ap traffic
 * - application write/read key + iv
 * - traffic update
 *}

unit nextpas.core.tls.tls13.appschedule;

{$mode ObjFPC}{$H+}

interface

uses
  SysUtils;

type
  TTLS13ApplicationSecrets = record
    Valid: Boolean;
    CipherSuite: Word;
    HashSize: Integer;
    KeyLength: Integer;
    IVLength: Integer;

    TranscriptHash: TBytes;
    ResumptionTranscriptHash: TBytes;  { Hash(CH..CF) for resumption_master_secret }
    DerivedSecret: TBytes;
    MasterSecret: TBytes;

    ClientApplicationTrafficSecret: TBytes;
    ServerApplicationTrafficSecret: TBytes;

    ClientApplicationKey: TBytes;
    ServerApplicationKey: TBytes;

    ClientApplicationIV: TBytes;
    ServerApplicationIV: TBytes;
  end;

procedure InitTLS13ApplicationSecrets(out ASecrets: TTLS13ApplicationSecrets);
procedure ClearTLS13ApplicationSecrets(var ASecrets: TTLS13ApplicationSecrets);
function TLS13ComputeResumptionMasterSecretFromTranscriptHash(
  ACipherSuite: Word;
  const AMasterSecret, AHandshakeTranscriptHash: TBytes
): TBytes;
function TLS13DeriveResumptionPSKFromTranscriptHash(
  ACipherSuite: Word;
  const AMasterSecret, AHandshakeTranscriptHash, ATicketNonce: TBytes
): TBytes;
function TLS13DeriveResumptionPSK(
  ACipherSuite: Word;
  const AMasterSecret, AHandshakeTranscript, ATicketNonce: TBytes
): TBytes;

function TryDeriveTLS13ApplicationSecrets(
  ACipherSuite: Word;
  const AHandshakeSecret: TBytes;
  const ATranscriptData: TBytes;
  out ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;

function TryUpdateTLS13ClientApplicationWriteKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;

function TryUpdateTLS13ServerApplicationReadKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;

function TryUpdateTLS13ServerApplicationWriteKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;

function TryUpdateTLS13ClientApplicationReadKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;

implementation

uses
  nextpas.core.tls.crypto.hash,
  nextpas.core.tls.crypto.primitives,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.memutils;

const
  TLS13_SHA256_HASH_SIZE = 32;
  TLS13_SHA384_HASH_SIZE = 48;
  TLS13_DEFAULT_IV_SIZE = 12;

procedure InitTLS13ApplicationSecrets(out ASecrets: TTLS13ApplicationSecrets);
begin
  FillChar(ASecrets, SizeOf(ASecrets), 0);
  SetLength(ASecrets.TranscriptHash, 0);
  SetLength(ASecrets.ResumptionTranscriptHash, 0);
  SetLength(ASecrets.DerivedSecret, 0);
  SetLength(ASecrets.MasterSecret, 0);
  SetLength(ASecrets.ClientApplicationTrafficSecret, 0);
  SetLength(ASecrets.ServerApplicationTrafficSecret, 0);
  SetLength(ASecrets.ClientApplicationKey, 0);
  SetLength(ASecrets.ServerApplicationKey, 0);
  SetLength(ASecrets.ClientApplicationIV, 0);
  SetLength(ASecrets.ServerApplicationIV, 0);
end;

procedure ClearTLS13ApplicationSecrets(var ASecrets: TTLS13ApplicationSecrets);
begin
  SecureZeroBytes(ASecrets.TranscriptHash);
  SecureZeroBytes(ASecrets.ResumptionTranscriptHash);
  SecureZeroBytes(ASecrets.DerivedSecret);
  SecureZeroBytes(ASecrets.MasterSecret);
  SecureZeroBytes(ASecrets.ClientApplicationTrafficSecret);
  SecureZeroBytes(ASecrets.ServerApplicationTrafficSecret);
  SecureZeroBytes(ASecrets.ClientApplicationKey);
  SecureZeroBytes(ASecrets.ServerApplicationKey);
  SecureZeroBytes(ASecrets.ClientApplicationIV);
  SecureZeroBytes(ASecrets.ServerApplicationIV);
end;

function HashTranscriptForSuite(ACipherSuite: Word; const AData: TBytes): TBytes; forward;
function HKDFExpandLabelForSuite(
  ACipherSuite: Word;
  const ASecret: TBytes;
  const ALabel: string;
  const AContext: TBytes;
  ALength: Integer
): TBytes; forward;

function TLS13ComputeResumptionMasterSecretFromTranscriptHash(
  ACipherSuite: Word;
  const AMasterSecret, AHandshakeTranscriptHash: TBytes
): TBytes;
var
  LHashSize: Integer;
begin
  Result := nil;
  LHashSize := TLS13CipherSuiteHashSize(ACipherSuite);
  if (LHashSize <= 0) or (Length(AMasterSecret) <> LHashSize) or
    (Length(AHandshakeTranscriptHash) <> LHashSize) then
    Exit;

  Result := HKDFExpandLabelForSuite(
    ACipherSuite,
    AMasterSecret,
    'res master',
    AHandshakeTranscriptHash,
    LHashSize
  );
end;

function TLS13DeriveResumptionPSKFromTranscriptHash(
  ACipherSuite: Word;
  const AMasterSecret, AHandshakeTranscriptHash, ATicketNonce: TBytes
): TBytes;
var
  LHashSize: Integer;
  LResumptionMasterSecret: TBytes;
begin
  Result := nil;
  LHashSize := TLS13CipherSuiteHashSize(ACipherSuite);
  if LHashSize <= 0 then
    Exit;

  LResumptionMasterSecret := TLS13ComputeResumptionMasterSecretFromTranscriptHash(
    ACipherSuite,
    AMasterSecret,
    AHandshakeTranscriptHash
  );
  if Length(LResumptionMasterSecret) <> LHashSize then
    Exit;

  Result := HKDFExpandLabelForSuite(
    ACipherSuite,
    LResumptionMasterSecret,
    'resumption',
    ATicketNonce,
    LHashSize
  );
end;

function TLS13DeriveResumptionPSK(
  ACipherSuite: Word;
  const AMasterSecret, AHandshakeTranscript, ATicketNonce: TBytes
): TBytes;
begin
  Result := TLS13DeriveResumptionPSKFromTranscriptHash(
    ACipherSuite,
    AMasterSecret,
    HashTranscriptForSuite(ACipherSuite, AHandshakeTranscript),
    ATicketNonce
  );
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

function TryDeriveTLS13ApplicationSecrets(
  ACipherSuite: Word;
  const AHandshakeSecret: TBytes;
  const ATranscriptData: TBytes;
  out ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;
var
  LHashSize: Integer;
  LKeyLength: Integer;
  LZeroLength: TBytes;
  LZeroHash: TBytes;
  LEmptyHash: TBytes;
begin
  InitTLS13ApplicationSecrets(ASecrets);
  AError := '';
  Result := False;

  LHashSize := TLS13CipherSuiteHashSize(ACipherSuite);
  if LHashSize <= 0 then
  begin
    AError := Format('Unsupported TLS 1.3 cipher suite for application key schedule: 0x%.4x', [ACipherSuite]);
    Exit;
  end;

  LKeyLength := TLS13CipherSuiteKeyLength(ACipherSuite);
  if LKeyLength <= 0 then
  begin
    AError := 'Unsupported TLS 1.3 cipher suite key length';
    Exit;
  end;

  if Length(AHandshakeSecret) <> LHashSize then
  begin
    AError := Format(
      'TLS 1.3 handshake secret length must be %d bytes for selected hash path (actual=%d)',
      [LHashSize, Length(AHandshakeSecret)]
    );
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

  ASecrets.DerivedSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    AHandshakeSecret,
    'derived',
    LEmptyHash,
    LHashSize
  );
  ASecrets.MasterSecret := HKDFExtractForSuite(ACipherSuite, ASecrets.DerivedSecret, LZeroHash);

  ASecrets.ClientApplicationTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.MasterSecret,
    'c ap traffic',
    ASecrets.TranscriptHash,
    LHashSize
  );

  ASecrets.ServerApplicationTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.MasterSecret,
    's ap traffic',
    ASecrets.TranscriptHash,
    LHashSize
  );

  ASecrets.ClientApplicationKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientApplicationTrafficSecret,
    'key',
    LZeroLength,
    LKeyLength
  );

  ASecrets.ServerApplicationKey := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ServerApplicationTrafficSecret,
    'key',
    LZeroLength,
    LKeyLength
  );

  ASecrets.ClientApplicationIV := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ClientApplicationTrafficSecret,
    'iv',
    LZeroLength,
    TLS13_DEFAULT_IV_SIZE
  );

  ASecrets.ServerApplicationIV := HKDFExpandLabelForSuite(
    ACipherSuite,
    ASecrets.ServerApplicationTrafficSecret,
    'iv',
    LZeroLength,
    TLS13_DEFAULT_IV_SIZE
  );

  Result := True;
end;

function TryNextTLS13ApplicationTrafficSecret(
  ACipherSuite: Word;
  const ACurrentTrafficSecret: TBytes;
  AHashSize: Integer;
  out ANextTrafficSecret: TBytes;
  out AError: string
): Boolean;
var
  LZeroLength: TBytes;
begin
  SetLength(ANextTrafficSecret, 0);
  AError := '';
  Result := False;

  if Length(ACurrentTrafficSecret) <> AHashSize then
  begin
    AError := Format('Invalid traffic secret length for key update (expected=%d actual=%d)',
      [AHashSize, Length(ACurrentTrafficSecret)]);
    Exit;
  end;

  SetLength(LZeroLength, 0);
  ANextTrafficSecret := HKDFExpandLabelForSuite(
    ACipherSuite,
    ACurrentTrafficSecret,
    'traffic upd',
    LZeroLength,
    AHashSize
  );

  Result := True;
end;

function TryDeriveTLS13ApplicationKeyMaterial(
  ACipherSuite: Word;
  const ATrafficSecret: TBytes;
  AHashSize: Integer;
  AKeyLength, AIVLength: Integer;
  out AKey, AIV: TBytes;
  out AError: string
): Boolean;
var
  LZeroLength: TBytes;
begin
  SetLength(AKey, 0);
  SetLength(AIV, 0);
  AError := '';
  Result := False;

  if Length(ATrafficSecret) <> AHashSize then
  begin
    AError := Format('Invalid traffic secret length for key derivation (expected=%d actual=%d)',
      [AHashSize, Length(ATrafficSecret)]);
    Exit;
  end;

  if AKeyLength <= 0 then
  begin
    AError := 'Invalid key length for application key derivation';
    Exit;
  end;

  if AIVLength <= 0 then
  begin
    AError := 'Invalid IV length for application key derivation';
    Exit;
  end;

  SetLength(LZeroLength, 0);
  AKey := HKDFExpandLabelForSuite(ACipherSuite, ATrafficSecret, 'key', LZeroLength, AKeyLength);
  AIV := HKDFExpandLabelForSuite(ACipherSuite, ATrafficSecret, 'iv', LZeroLength, AIVLength);

  Result := True;
end;

function TryUpdateTLS13ApplicationDirection(
  var ASecrets: TTLS13ApplicationSecrets;
  var ATrafficSecret, AKey, AIV: TBytes;
  out AError: string
): Boolean;
var
  LHashSize: Integer;
  LNextTrafficSecret: TBytes;
  LNextKey: TBytes;
  LNextIV: TBytes;
begin
  AError := '';
  Result := False;

  if not ASecrets.Valid then
  begin
    AError := 'Application secrets are not initialized';
    Exit;
  end;

  LHashSize := TLS13CipherSuiteHashSize(ASecrets.CipherSuite);
  if LHashSize <= 0 then
  begin
    AError := Format('Cipher suite 0x%.4x does not support application key update path yet', [ASecrets.CipherSuite]);
    Exit;
  end;

  if ASecrets.HashSize <= 0 then
    ASecrets.HashSize := LHashSize;

  if ASecrets.HashSize <> LHashSize then
  begin
    AError := Format('Application secret hash size mismatch (expected=%d actual=%d)',
      [LHashSize, ASecrets.HashSize]);
    Exit;
  end;

  if not TryNextTLS13ApplicationTrafficSecret(
    ASecrets.CipherSuite,
    ATrafficSecret,
    ASecrets.HashSize,
    LNextTrafficSecret,
    AError
  ) then
    Exit;

  if not TryDeriveTLS13ApplicationKeyMaterial(
    ASecrets.CipherSuite,
    LNextTrafficSecret,
    ASecrets.HashSize,
    ASecrets.KeyLength,
    ASecrets.IVLength,
    LNextKey,
    LNextIV,
    AError
  ) then
    Exit;

  SecureZeroBytes(ATrafficSecret);
  SecureZeroBytes(AKey);
  SecureZeroBytes(AIV);
  ATrafficSecret := LNextTrafficSecret;
  AKey := LNextKey;
  AIV := LNextIV;

  Result := True;
end;

function TryUpdateTLS13ClientApplicationWriteKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;
begin
  Result := TryUpdateTLS13ApplicationDirection(
    ASecrets,
    ASecrets.ClientApplicationTrafficSecret,
    ASecrets.ClientApplicationKey,
    ASecrets.ClientApplicationIV,
    AError
  );
end;

function TryUpdateTLS13ServerApplicationReadKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;
begin
  Result := TryUpdateTLS13ApplicationDirection(
    ASecrets,
    ASecrets.ServerApplicationTrafficSecret,
    ASecrets.ServerApplicationKey,
    ASecrets.ServerApplicationIV,
    AError
  );
end;

function TryUpdateTLS13ServerApplicationWriteKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;
begin
  Result := TryUpdateTLS13ApplicationDirection(
    ASecrets,
    ASecrets.ServerApplicationTrafficSecret,
    ASecrets.ServerApplicationKey,
    ASecrets.ServerApplicationIV,
    AError
  );
end;

function TryUpdateTLS13ClientApplicationReadKeys(
  var ASecrets: TTLS13ApplicationSecrets;
  out AError: string
): Boolean;
begin
  Result := TryUpdateTLS13ApplicationDirection(
    ASecrets,
    ASecrets.ClientApplicationTrafficSecret,
    ASecrets.ClientApplicationKey,
    ASecrets.ClientApplicationIV,
    AError
  );
end;

end.

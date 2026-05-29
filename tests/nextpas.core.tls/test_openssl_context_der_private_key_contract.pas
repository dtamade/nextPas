program test_openssl_context_der_private_key_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.pem,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pkcs,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.rsa;

type
  TPKCSD2IPKCS8PrivKeyInfo = nextpas.core.tls.openssl.api.pkcs.Td2i_PKCS8_PRIV_KEY_INFO;
  TPKCSD2IX509Sig = nextpas.core.tls.openssl.api.pkcs.Td2i_X509_SIG;
  TPKCSEVPPKCS82PKEY = nextpas.core.tls.openssl.api.pkcs.TEVP_PKCS82PKEY;
  TPKCS8Decrypt = nextpas.core.tls.openssl.api.pkcs12.TPKCS8_decrypt;
  TRSAD2IPrivateKey = nextpas.core.tls.openssl.api.rsa.Td2i_RSAPrivateKey;

const
  KEY_FIXTURE_PATH = 'tests/certificate/test_certs/signer_key.pem';
  EC_KEY_FIXTURE_PATH = 'tests/certificate/test_certs/signer_ecdsa_key.pem';
  ENCRYPTED_DER_PASSWORD = 'wave9-der-private-key';

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GPKCS8DER: TBytes = nil;
  GPKCS1DER: TBytes = nil;
  GEncryptedPKCS8DER: TBytes = nil;
  GECSEC1DER: TBytes = nil;
  GECPKCS8DER: TBytes = nil;
  GEncryptedECPKCS8DER: TBytes = nil;
  GEd25519PKCS8DER: TBytes = nil;
  GEncryptedEd25519PKCS8DER: TBytes = nil;
  GPKCS8DERFile: string = '';
  GPKCS1DERFile: string = '';
  GEncryptedPKCS8DERFile: string = '';
  GECSEC1DERFile: string = '';
  GECPKCS8DERFile: string = '';
  GEncryptedECPKCS8DERFile: string = '';
  GEd25519PEMFile: string = '';
  GEd25519PKCS8DERFile: string = '';
  GEncryptedEd25519PKCS8DERFile: string = '';

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

function LoadFileBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[0], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function WriteTempBytesFile(const AFileName: string; const AData: TBytes): Boolean;
var
  LStream: TFileStream;
begin
  Result := False;
  ForceDirectories(ExtractFileDir(AFileName));
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AData) > 0 then
      LStream.WriteBuffer(AData[0], Length(AData));
    Result := True;
  finally
    LStream.Free;
  end;
end;

function WriteTempTextFile(const AFileName, AText: string): Boolean;
var
  LData: TBytes;
begin
  LData := TEncoding.ANSI.GetBytes(AText);
  Result := WriteTempBytesFile(AFileName, LData);
end;

function CreateMemoryStream(const AData: TBytes): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  if Length(AData) > 0 then
    Result.WriteBuffer(AData[0], Length(AData));
  Result.Position := 0;
end;

function CreateServerContext: ISSLContext;
begin
  Result := GLib.CreateContext(sslCtxServer);
  if Result = nil then
    raise Exception.Create('failed to create OpenSSL server context');
end;

function TryReadDERLength(const AData: TBytes; var AOffset: Integer; out ALength: Integer): Boolean;
var
  LFirst: Byte;
  LCount: Integer;
  I: Integer;
begin
  ALength := 0;
  Result := False;

  if (AOffset < 0) or (AOffset >= Length(AData)) then
    Exit;

  LFirst := AData[AOffset];
  Inc(AOffset);

  if (LFirst and $80) = 0 then
  begin
    ALength := LFirst;
    Exit(True);
  end;

  LCount := LFirst and $7F;
  if (LCount <= 0) or (LCount > 4) or (AOffset + LCount > Length(AData)) then
    Exit;

  ALength := 0;
  for I := 1 to LCount do
  begin
    ALength := (ALength shl 8) or AData[AOffset];
    Inc(AOffset);
  end;

  Result := True;
end;

function TryLocatePKCS8PrivateKeyOctetStringValue(
  const ADER: TBytes;
  out AValueOffset: Integer;
  out AValueLength: Integer
): Boolean;
var
  LOffset: Integer;
  LSeqLength: Integer;
  LChildLength: Integer;
begin
  AValueOffset := -1;
  AValueLength := 0;
  Result := False;

  if Length(ADER) < 8 then
    Exit;

  LOffset := 0;
  if ADER[LOffset] <> $30 then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LSeqLength) then
    Exit;
  if LOffset + LSeqLength > Length(ADER) then
    Exit;

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $02) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $30) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, LChildLength) then
    Exit;
  Inc(LOffset, LChildLength);

  if (LOffset >= Length(ADER)) or (ADER[LOffset] <> $04) then
    Exit;
  Inc(LOffset);
  if not TryReadDERLength(ADER, LOffset, AValueLength) then
    Exit;
  if LOffset + AValueLength > Length(ADER) then
    Exit;

  AValueOffset := LOffset;
  Result := True;
end;

function TryExtractPKCS1FromPKCS8DER(const ADER: TBytes; out APKCS1DER: TBytes): Boolean;
var
  LOffset: Integer;
  LLength: Integer;
begin
  SetLength(APKCS1DER, 0);
  Result := False;

  if not TryLocatePKCS8PrivateKeyOctetStringValue(ADER, LOffset, LLength) then
    Exit;
  if (LLength <= 0) or (LOffset + LLength > Length(ADER)) then
    Exit;

  APKCS1DER := Copy(ADER, LOffset, LLength);
  Result := Length(APKCS1DER) > 0;
end;

function TryExtractFirstPrivateKeyDER(
  const APEMBlob: TBytes;
  out ADER: TBytes;
  out AType: TPEMType
): Boolean;
var
  LReader: TPEMReader;
  LBlocks: TPEMBlockArray;
  LText: string;
  I: Integer;
begin
  SetLength(ADER, 0);
  AType := pemUnknown;
  Result := False;

  LReader := TPEMReader.Create;
  try
    LText := TEncoding.ANSI.GetString(APEMBlob);
    LReader.LoadFromString(LText);
    LBlocks := LReader.GetPrivateKeys;
    for I := 0 to High(LBlocks) do
    begin
      if LBlocks[I].IsEncrypted then
        Continue;
      if not (LBlocks[I].BlockType in [pemPrivateKey, pemRSAPrivateKey, pemECPrivateKey]) then
        Continue;

      ADER := Copy(LBlocks[I].Data, 0, Length(LBlocks[I].Data));
      AType := LBlocks[I].BlockType;
      Exit(Length(ADER) > 0);
    end;
  finally
    LReader.Free;
  end;
end;

function BuildPKCS8DERFromPEM(
  const AFileName: string;
  out ADER: TBytes
): Boolean;
var
  LPKey: PEVP_PKEY;
  LP8Info: nextpas.core.tls.openssl.api.pkcs.PPKCS8_PRIV_KEY_INFO;
  LEncodedLength: Integer;
  LEncodedPtr: PByte;
begin
  SetLength(ADER, 0);
  Result := False;
  LPKey := nil;
  LP8Info := nil;

  LPKey := LoadPrivateKeyFromPEM(AFileName, '');
  if LPKey = nil then
    Exit;

  try
    if (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKEY2PKCS8)) or
       (not Assigned(nextpas.core.tls.openssl.api.pkcs.i2d_PKCS8_PRIV_KEY_INFO)) or
       (not Assigned(nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free)) then
      Exit;

    LP8Info := nextpas.core.tls.openssl.api.pkcs.EVP_PKEY2PKCS8(LPKey);
    if LP8Info = nil then
      Exit;

    LEncodedLength := nextpas.core.tls.openssl.api.pkcs.i2d_PKCS8_PRIV_KEY_INFO(LP8Info, nil);
    if LEncodedLength <= 0 then
      Exit;

    SetLength(ADER, LEncodedLength);
    LEncodedPtr := @ADER[0];
    if nextpas.core.tls.openssl.api.pkcs.i2d_PKCS8_PRIV_KEY_INFO(LP8Info, @LEncodedPtr) <> LEncodedLength then
    begin
      SetLength(ADER, 0);
      Exit;
    end;

    Result := Length(ADER) > 0;
  finally
    if LP8Info <> nil then
      nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free(LP8Info);
    if LPKey <> nil then
      EVP_PKEY_free(LPKey);
  end;
end;

function BuildEncryptedPKCS8DERFromPEM(
  const AFileName, APassword: string;
  out ADER: TBytes
): Boolean;
var
  LPKey: PEVP_PKEY;
  LP8Info: nextpas.core.tls.openssl.api.pkcs.PPKCS8_PRIV_KEY_INFO;
  LEncrypted: nextpas.core.tls.openssl.api.pkcs.PX509_SIG;
  LPassA: AnsiString;
  LEncodedLength: Integer;
  LEncodedPtr: PByte;
begin
  SetLength(ADER, 0);
  Result := False;
  LPKey := nil;
  LP8Info := nil;
  LEncrypted := nil;

  LPKey := LoadPrivateKeyFromPEM(AFileName, '');
  if LPKey = nil then
    Exit;

  try
    if (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKEY2PKCS8)) or
       (not Assigned(nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free)) or
       (not Assigned(nextpas.core.tls.openssl.api.pkcs.i2d_X509_SIG)) or
       (not Assigned(nextpas.core.tls.openssl.api.pkcs.X509_SIG_free)) or
       (not Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS8_encrypt)) then
      Exit;

    LP8Info := nextpas.core.tls.openssl.api.pkcs.EVP_PKEY2PKCS8(LPKey);
    if LP8Info = nil then
      Exit;

    LPassA := AnsiString(APassword);
    LEncrypted := nextpas.core.tls.openssl.api.pkcs12.PKCS8_encrypt(
      NID_pbe_WithSHA1And3_Key_TripleDES_CBC,
      nil,
      PAnsiChar(LPassA),
      Length(LPassA),
      nil,
      0,
      PKCS12_DEFAULT_ITER,
      LP8Info
    );
    if LEncrypted = nil then
      Exit;

    LEncodedLength := nextpas.core.tls.openssl.api.pkcs.i2d_X509_SIG(LEncrypted, nil);
    if LEncodedLength <= 0 then
      Exit;

    SetLength(ADER, LEncodedLength);
    LEncodedPtr := @ADER[0];
    if nextpas.core.tls.openssl.api.pkcs.i2d_X509_SIG(LEncrypted, @LEncodedPtr) <> LEncodedLength then
    begin
      SetLength(ADER, 0);
      Exit;
    end;

    Result := Length(ADER) > 0;
  finally
    if LEncrypted <> nil then
      nextpas.core.tls.openssl.api.pkcs.X509_SIG_free(LEncrypted);
    if LP8Info <> nil then
      nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free(LP8Info);
    if LPKey <> nil then
      EVP_PKEY_free(LPKey);
  end;
end;

function GenerateEd25519PrivateKeyPEMFile(out AFileName: string): Boolean;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
begin
  AFileName := '';
  Result := False;

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.KeyType := ktEd25519;
  LOptions.CommonName := 'wave10-ed25519-der-fixture.local';

  if not TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM) then
    Exit;

  if Pos('BEGIN PRIVATE KEY', LKeyPEM) = 0 then
    Exit;

  AFileName := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_ed25519.pem';
  Result := WriteTempTextFile(AFileName, LKeyPEM);
end;

procedure PrepareDERFixtures;
var
  LPEMBlob: TBytes;
  LType: TPEMType;
begin
  LPEMBlob := LoadFileBytes(KEY_FIXTURE_PATH);
  if not TryExtractFirstPrivateKeyDER(LPEMBlob, GPKCS8DER, LType) then
    raise Exception.Create('failed to extract PKCS#8 DER from signer_key.pem');
  if LType <> pemPrivateKey then
    raise Exception.Create('signer_key.pem is not an unencrypted PKCS#8 PEM fixture');
  if not TryExtractPKCS1FromPKCS8DER(GPKCS8DER, GPKCS1DER) then
    raise Exception.Create('failed to extract PKCS#1 RSA DER from PKCS#8 fixture');
  if not BuildEncryptedPKCS8DERFromPEM(KEY_FIXTURE_PATH, ENCRYPTED_DER_PASSWORD, GEncryptedPKCS8DER) then
    raise Exception.Create('failed to generate encrypted PKCS#8 DER fixture');

  LPEMBlob := LoadFileBytes(EC_KEY_FIXTURE_PATH);
  if not TryExtractFirstPrivateKeyDER(LPEMBlob, GECSEC1DER, LType) then
    raise Exception.Create('failed to extract EC SEC1 DER from signer_ecdsa_key.pem');
  if LType <> pemECPrivateKey then
    raise Exception.Create('signer_ecdsa_key.pem is not an EC PRIVATE KEY PEM fixture');
  if not BuildPKCS8DERFromPEM(EC_KEY_FIXTURE_PATH, GECPKCS8DER) then
    raise Exception.Create('failed to generate EC PKCS#8 DER fixture');
  if not BuildEncryptedPKCS8DERFromPEM(EC_KEY_FIXTURE_PATH, ENCRYPTED_DER_PASSWORD, GEncryptedECPKCS8DER) then
    raise Exception.Create('failed to generate encrypted EC PKCS#8 DER fixture');

  if not GenerateEd25519PrivateKeyPEMFile(GEd25519PEMFile) then
    raise Exception.Create('failed to generate Ed25519 PEM fixture');
  if not BuildPKCS8DERFromPEM(GEd25519PEMFile, GEd25519PKCS8DER) then
    raise Exception.Create('failed to generate Ed25519 PKCS#8 DER fixture');
  if not BuildEncryptedPKCS8DERFromPEM(GEd25519PEMFile, ENCRYPTED_DER_PASSWORD, GEncryptedEd25519PKCS8DER) then
    raise Exception.Create('failed to generate encrypted Ed25519 PKCS#8 DER fixture');

  GPKCS8DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_pkcs8.der';
  GPKCS1DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_pkcs1.der';
  GEncryptedPKCS8DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_encrypted_pkcs8.der';
  GECSEC1DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_ec_sec1.der';
  GECPKCS8DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_ec_pkcs8.der';
  GEncryptedECPKCS8DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_encrypted_ec_pkcs8.der';
  GEd25519PKCS8DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_ed25519_pkcs8.der';
  GEncryptedEd25519PKCS8DERFile := GetTempDir(False) + 'fafafa_openssl_context_der_private_key_encrypted_ed25519_pkcs8.der';

  if not WriteTempBytesFile(GPKCS8DERFile, GPKCS8DER) then
    raise Exception.Create('failed to create PKCS#8 DER temp file');
  if not WriteTempBytesFile(GPKCS1DERFile, GPKCS1DER) then
    raise Exception.Create('failed to create PKCS#1 DER temp file');
  if not WriteTempBytesFile(GEncryptedPKCS8DERFile, GEncryptedPKCS8DER) then
    raise Exception.Create('failed to create encrypted PKCS#8 DER temp file');
  if not WriteTempBytesFile(GECSEC1DERFile, GECSEC1DER) then
    raise Exception.Create('failed to create EC SEC1 DER temp file');
  if not WriteTempBytesFile(GECPKCS8DERFile, GECPKCS8DER) then
    raise Exception.Create('failed to create EC PKCS#8 DER temp file');
  if not WriteTempBytesFile(GEncryptedECPKCS8DERFile, GEncryptedECPKCS8DER) then
    raise Exception.Create('failed to create encrypted EC PKCS#8 DER temp file');
  if not WriteTempBytesFile(GEd25519PKCS8DERFile, GEd25519PKCS8DER) then
    raise Exception.Create('failed to create Ed25519 PKCS#8 DER temp file');
  if not WriteTempBytesFile(GEncryptedEd25519PKCS8DERFile, GEncryptedEd25519PKCS8DER) then
    raise Exception.Create('failed to create encrypted Ed25519 PKCS#8 DER temp file');
end;

procedure CleanupDERFixtureFiles;
begin
  if (GPKCS8DERFile <> '') and FileExists(GPKCS8DERFile) then
    DeleteFile(GPKCS8DERFile);
  if (GPKCS1DERFile <> '') and FileExists(GPKCS1DERFile) then
    DeleteFile(GPKCS1DERFile);
  if (GEncryptedPKCS8DERFile <> '') and FileExists(GEncryptedPKCS8DERFile) then
    DeleteFile(GEncryptedPKCS8DERFile);
  if (GECSEC1DERFile <> '') and FileExists(GECSEC1DERFile) then
    DeleteFile(GECSEC1DERFile);
  if (GECPKCS8DERFile <> '') and FileExists(GECPKCS8DERFile) then
    DeleteFile(GECPKCS8DERFile);
  if (GEncryptedECPKCS8DERFile <> '') and FileExists(GEncryptedECPKCS8DERFile) then
    DeleteFile(GEncryptedECPKCS8DERFile);
  if (GEd25519PEMFile <> '') and FileExists(GEd25519PEMFile) then
    DeleteFile(GEd25519PEMFile);
  if (GEd25519PKCS8DERFile <> '') and FileExists(GEd25519PKCS8DERFile) then
    DeleteFile(GEd25519PKCS8DERFile);
  if (GEncryptedEd25519PKCS8DERFile <> '') and FileExists(GEncryptedEd25519PKCS8DERFile) then
    DeleteFile(GEncryptedEd25519PKCS8DERFile);
end;

procedure AssertLoadPrivateKeyFileSucceeds(
  const AName, AFileName, APassword: string
);
var
  LCtx: ISSLContext;
  LRaised: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LRaised := False;
  LDetail := '';
  try
    LCtx.LoadPrivateKey(AFileName, APassword);
  except
    on E: Exception do
    begin
      LRaised := True;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should not raise', not LRaised, LDetail);
end;

procedure AssertLoadPrivateKeyStreamSucceeds(
  const AName, APassword: string;
  const AData: TBytes
);
var
  LCtx: ISSLContext;
  LStream: TMemoryStream;
  LRaised: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LStream := CreateMemoryStream(AData);
  try
    LRaised := False;
    LDetail := '';
    try
      LCtx.LoadPrivateKey(LStream, APassword);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should not raise', not LRaised, LDetail);
  finally
    LStream.Free;
  end;
end;

procedure AssertLoadPrivateKeyFileControlledFailure(
  const AName, AFileName, APassword: string;
  AExpectKeyException: Boolean
);
var
  LCtx: ISSLContext;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LRaised := False;
  LControlled := False;
  LDetail := '';
  try
    LCtx.LoadPrivateKey(AFileName, APassword);
  except
    on E: Exception do
    begin
      LRaised := True;
      if AExpectKeyException then
        LControlled := E is ESSLKeyException
      else
        LControlled := E is ESSLException;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected LoadPrivateKey(file) to fail');
  AssertTrue(AName + ' should raise controlled exception', LControlled, LDetail);
end;

procedure AssertLoadPrivateKeyStreamControlledFailure(
  const AName, APassword: string;
  const AData: TBytes;
  AExpectKeyException: Boolean
);
var
  LCtx: ISSLContext;
  LStream: TMemoryStream;
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
begin
  LCtx := CreateServerContext;
  LStream := CreateMemoryStream(AData);
  try
    LRaised := False;
    LControlled := False;
    LDetail := '';
    try
      LCtx.LoadPrivateKey(LStream, APassword);
    except
      on E: Exception do
      begin
        LRaised := True;
        if AExpectKeyException then
          LControlled := E is ESSLKeyException
        else
          LControlled := E is ESSLException;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AName + ' should raise', LRaised,
      'expected LoadPrivateKey(stream) to fail');
    AssertTrue(AName + ' should raise controlled exception', LControlled, LDetail);
  finally
    LStream.Free;
  end;
end;

procedure TestDERPrivateKeyLoadContract;
begin
  WriteLn;
  WriteLn('=== OpenSSL context DER private-key load contract ===');

  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file) with DER PKCS#8',
    GPKCS8DERFile,
    ''
  );
  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file) with DER PKCS#1 RSA',
    GPKCS1DERFile,
    ''
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream) with DER PKCS#8',
    '',
    GPKCS8DER
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream) with DER PKCS#1 RSA',
    '',
    GPKCS1DER
  );
  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file,password) with encrypted DER PKCS#8',
    GEncryptedPKCS8DERFile,
    ENCRYPTED_DER_PASSWORD
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream,password) with encrypted DER PKCS#8',
    ENCRYPTED_DER_PASSWORD,
    GEncryptedPKCS8DER
  );
  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file) with EC DER PKCS#8',
    GECPKCS8DERFile,
    ''
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream) with EC DER PKCS#8',
    '',
    GECPKCS8DER
  );
  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file) with EC DER SEC1',
    GECSEC1DERFile,
    ''
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream) with EC DER SEC1',
    '',
    GECSEC1DER
  );
  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file) with Ed25519 DER PKCS#8',
    GEd25519PKCS8DERFile,
    ''
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream) with Ed25519 DER PKCS#8',
    '',
    GEd25519PKCS8DER
  );
  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file,password) with encrypted EC DER PKCS#8',
    GEncryptedECPKCS8DERFile,
    ENCRYPTED_DER_PASSWORD
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream,password) with encrypted EC DER PKCS#8',
    ENCRYPTED_DER_PASSWORD,
    GEncryptedECPKCS8DER
  );
  AssertLoadPrivateKeyFileSucceeds(
    'LoadPrivateKey(file,password) with encrypted Ed25519 DER PKCS#8',
    GEncryptedEd25519PKCS8DERFile,
    ENCRYPTED_DER_PASSWORD
  );
  AssertLoadPrivateKeyStreamSucceeds(
    'LoadPrivateKey(stream,password) with encrypted Ed25519 DER PKCS#8',
    ENCRYPTED_DER_PASSWORD,
    GEncryptedEd25519PKCS8DER
  );
end;

procedure TestEncryptedDERPasswordFailures;
begin
  WriteLn;
  WriteLn('=== OpenSSL context encrypted DER password contract ===');

  AssertLoadPrivateKeyFileControlledFailure(
    'LoadPrivateKey(file) with encrypted DER PKCS#8 and missing password',
    GEncryptedPKCS8DERFile,
    '',
    True
  );
  AssertLoadPrivateKeyFileControlledFailure(
    'LoadPrivateKey(file) with encrypted DER PKCS#8 and wrong password',
    GEncryptedPKCS8DERFile,
    'wrong-wave9-password',
    True
  );
  AssertLoadPrivateKeyStreamControlledFailure(
    'LoadPrivateKey(stream) with encrypted DER PKCS#8 and missing password',
    '',
    GEncryptedPKCS8DER,
    True
  );
  AssertLoadPrivateKeyStreamControlledFailure(
    'LoadPrivateKey(stream) with encrypted DER PKCS#8 and wrong password',
    'wrong-wave9-password',
    GEncryptedPKCS8DER,
    True
  );
  AssertLoadPrivateKeyFileControlledFailure(
    'LoadPrivateKey(file) with encrypted EC DER PKCS#8 and missing password',
    GEncryptedECPKCS8DERFile,
    '',
    True
  );
  AssertLoadPrivateKeyFileControlledFailure(
    'LoadPrivateKey(file) with encrypted EC DER PKCS#8 and wrong password',
    GEncryptedECPKCS8DERFile,
    'wrong-wave10-password',
    True
  );
  AssertLoadPrivateKeyStreamControlledFailure(
    'LoadPrivateKey(stream) with encrypted EC DER PKCS#8 and missing password',
    '',
    GEncryptedECPKCS8DER,
    True
  );
  AssertLoadPrivateKeyStreamControlledFailure(
    'LoadPrivateKey(stream) with encrypted EC DER PKCS#8 and wrong password',
    'wrong-wave10-password',
    GEncryptedECPKCS8DER,
    True
  );
  AssertLoadPrivateKeyFileControlledFailure(
    'LoadPrivateKey(file) with encrypted Ed25519 DER PKCS#8 and missing password',
    GEncryptedEd25519PKCS8DERFile,
    '',
    True
  );
  AssertLoadPrivateKeyFileControlledFailure(
    'LoadPrivateKey(file) with encrypted Ed25519 DER PKCS#8 and wrong password',
    GEncryptedEd25519PKCS8DERFile,
    'wrong-wave10-password',
    True
  );
  AssertLoadPrivateKeyStreamControlledFailure(
    'LoadPrivateKey(stream) with encrypted Ed25519 DER PKCS#8 and missing password',
    '',
    GEncryptedEd25519PKCS8DER,
    True
  );
  AssertLoadPrivateKeyStreamControlledFailure(
    'LoadPrivateKey(stream) with encrypted Ed25519 DER PKCS#8 and wrong password',
    'wrong-wave10-password',
    GEncryptedEd25519PKCS8DER,
    True
  );
end;

procedure TestDERHelperSurfaceGuards;
var
  LOriginalD2IX509Sig: TPKCSD2IX509Sig;
  LOriginalPKCS8Decrypt: TPKCS8Decrypt;
  LOriginalEVPPKCS82PKEY: TPKCSEVPPKCS82PKEY;
  LOriginalD2IPKCS8PrivKeyInfo: TPKCSD2IPKCS8PrivKeyInfo;
  LOriginalD2IRSAPrivateKey: TRSAD2IPrivateKey;
  LOriginalECKeyFree: TEC_KEY_free;
  LOriginalEVPPKeyNew: TEVP_PKEY_new;
  LOriginalEVPPKeySet1RSA: TEVP_PKEY_set1_RSA;
begin
  WriteLn;
  WriteLn('=== OpenSSL context DER helper guard contract ===');

  LOriginalD2IX509Sig := nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG;
  if not Assigned(LOriginalD2IX509Sig) then
    MarkSkip('LoadPrivateKey(file,password) when d2i_X509_SIG is unavailable',
      'd2i_X509_SIG baseline helper is unavailable')
  else
  begin
    nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := nil;
    try
      AssertLoadPrivateKeyFileControlledFailure(
        'LoadPrivateKey(file,password) when d2i_X509_SIG is unavailable',
        GEncryptedPKCS8DERFile,
        ENCRYPTED_DER_PASSWORD,
        False
      );
    finally
      nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG := LOriginalD2IX509Sig;
    end;
  end;

  LOriginalPKCS8Decrypt := nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt;
  if not Assigned(LOriginalPKCS8Decrypt) then
    MarkSkip('LoadPrivateKey(stream,password) when PKCS8_decrypt is unavailable',
      'PKCS8_decrypt baseline helper is unavailable')
  else
  begin
    nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := nil;
    try
      AssertLoadPrivateKeyStreamControlledFailure(
        'LoadPrivateKey(stream,password) when PKCS8_decrypt is unavailable',
        ENCRYPTED_DER_PASSWORD,
        GEncryptedPKCS8DER,
        False
      );
    finally
      nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt := LOriginalPKCS8Decrypt;
    end;
  end;

  LOriginalEVPPKCS82PKEY := nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY;
  if not Assigned(LOriginalEVPPKCS82PKEY) then
    MarkSkip('LoadPrivateKey(file) when EVP_PKCS82PKEY is unavailable',
      'EVP_PKCS82PKEY baseline helper is unavailable')
  else
  begin
    nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY := nil;
    try
      AssertLoadPrivateKeyFileControlledFailure(
        'LoadPrivateKey(file) when EVP_PKCS82PKEY is unavailable',
        GPKCS8DERFile,
        '',
        False
      );
    finally
      nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY := LOriginalEVPPKCS82PKEY;
    end;
  end;

  LOriginalD2IPKCS8PrivKeyInfo := nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO;
  if not Assigned(LOriginalD2IPKCS8PrivKeyInfo) then
    MarkSkip('LoadPrivateKey(stream) when d2i_PKCS8_PRIV_KEY_INFO is unavailable',
      'd2i_PKCS8_PRIV_KEY_INFO baseline helper is unavailable')
  else
  begin
    nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := nil;
    try
      AssertLoadPrivateKeyStreamControlledFailure(
        'LoadPrivateKey(stream) when d2i_PKCS8_PRIV_KEY_INFO is unavailable',
        '',
        GPKCS8DER,
        False
      );
    finally
      nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO := LOriginalD2IPKCS8PrivKeyInfo;
    end;
  end;

  LOriginalD2IRSAPrivateKey := nextpas.core.tls.openssl.api.rsa.d2i_RSAPrivateKey;
  if not Assigned(LOriginalD2IRSAPrivateKey) then
    MarkSkip('LoadPrivateKey(file) when d2i_RSAPrivateKey is unavailable',
      'd2i_RSAPrivateKey baseline helper is unavailable')
  else
  begin
    nextpas.core.tls.openssl.api.rsa.d2i_RSAPrivateKey := nil;
    try
      AssertLoadPrivateKeyFileControlledFailure(
        'LoadPrivateKey(file) when d2i_RSAPrivateKey is unavailable',
        GPKCS1DERFile,
        '',
        False
      );
    finally
      nextpas.core.tls.openssl.api.rsa.d2i_RSAPrivateKey := LOriginalD2IRSAPrivateKey;
    end;
  end;

  LOriginalEVPPKeyNew := EVP_PKEY_new;
  if not Assigned(LOriginalEVPPKeyNew) then
    MarkSkip('LoadPrivateKey(stream) when EVP_PKEY_new is unavailable',
      'EVP_PKEY_new baseline helper is unavailable')
  else
  begin
    EVP_PKEY_new := nil;
    try
      AssertLoadPrivateKeyStreamControlledFailure(
        'LoadPrivateKey(stream) when EVP_PKEY_new is unavailable',
        '',
        GPKCS1DER,
        False
      );
    finally
      EVP_PKEY_new := LOriginalEVPPKeyNew;
    end;
  end;

  LOriginalEVPPKeySet1RSA := EVP_PKEY_set1_RSA;
  if not Assigned(LOriginalEVPPKeySet1RSA) then
    MarkSkip('LoadPrivateKey(file) when EVP_PKEY_set1_RSA is unavailable',
      'EVP_PKEY_set1_RSA baseline helper is unavailable')
  else
  begin
    EVP_PKEY_set1_RSA := nil;
    try
      AssertLoadPrivateKeyFileControlledFailure(
        'LoadPrivateKey(file) when EVP_PKEY_set1_RSA is unavailable',
        GPKCS1DERFile,
        '',
        False
      );
    finally
      EVP_PKEY_set1_RSA := LOriginalEVPPKeySet1RSA;
    end;
  end;

  LOriginalECKeyFree := EC_KEY_free;
  if not Assigned(LOriginalECKeyFree) then
    MarkSkip('LoadPrivateKey(file) with EC DER SEC1 when EC_KEY_free is unavailable',
      'EC_KEY_free baseline helper is unavailable')
  else
  begin
    EC_KEY_free := nil;
    try
      AssertLoadPrivateKeyFileControlledFailure(
        'LoadPrivateKey(file) with EC DER SEC1 when EC_KEY_free is unavailable',
        GECSEC1DERFile,
        '',
        False
      );
    finally
      EC_KEY_free := LOriginalECKeyFree;
    end;
  end;

  LOriginalEVPPKeyNew := EVP_PKEY_new;
  if not Assigned(LOriginalEVPPKeyNew) then
    MarkSkip('LoadPrivateKey(stream) with EC DER SEC1 when EVP_PKEY_new is unavailable',
      'EVP_PKEY_new baseline helper is unavailable')
  else
  begin
    EVP_PKEY_new := nil;
    try
      AssertLoadPrivateKeyStreamControlledFailure(
        'LoadPrivateKey(stream) with EC DER SEC1 when EVP_PKEY_new is unavailable',
        '',
        GECSEC1DER,
        False
      );
    finally
      EVP_PKEY_new := LOriginalEVPPKeyNew;
    end;
  end;
end;

begin
  WriteLn('====================================================');
  WriteLn('OpenSSL Context DER Private-Key Contract Test');
  WriteLn('====================================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('openssl context der private key contract', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadOpenSSLBIO;
      LoadEVP(GetCryptoLibHandle);
      LoadOpenSSLRSA;
      LoadECFunctions(GetCryptoLibHandle);
      if not Assigned(BIO_new_file) or
         not Assigned(BIO_new_mem_buf) or
         not Assigned(BIO_free) or
         not Assigned(EVP_PKEY_free) then
      begin
        MarkSkip('openssl context der private key contract',
          'baseline BIO/EVP helpers are unavailable');
      end
      else if not LoadOpenSSLPEM(GetCryptoLibHandle) then
      begin
        MarkSkip('openssl context der private key contract', 'PEM module unavailable');
      end
      else if not LoadOpenSSLPKCS(GetCryptoLibHandle) then
      begin
        MarkSkip('openssl context der private key contract', 'PKCS module unavailable');
      end
      else
      begin
        LoadPKCS12Module(GetCryptoLibHandle);

        GLib := TSSLFactory.GetLibrary(sslOpenSSL);
        if (GLib = nil) or (not GLib.Initialize) then
          raise Exception.Create('failed to initialize OpenSSL library through factory');

        PrepareDERFixtures;
        try
          TestDERPrivateKeyLoadContract;
          TestEncryptedDERPasswordFailures;
          TestDERHelperSurfaceGuards;
        finally
          CleanupDERFixtureFiles;
        end;
      end;
    end;

    WriteLn;
    WriteLn('====================================================');
    WriteLn('Summary');
    WriteLn('====================================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      CleanupDERFixtureFiles;
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.

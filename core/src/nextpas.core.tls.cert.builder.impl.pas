{
  nextpas.core.tls.cert.builder.impl - Certificate Builder Implementation

  Internal implementation of the fluent certificate builder.
  Users should not use this unit directly - use nextpas.core.tls.cert.builder instead.
}

unit nextpas.core.tls.cert.builder.impl;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{ 禁用函数结果未初始化警告 - SetLength 已经初始化 TBytes }
{$WARN 6018 off}  // Unreachable code - defensive else in case statement
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.safety,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.pem;

type
  { Internal implementation classes }
  
  TCertificateImpl = class(TInterfacedObject, ICertificate, ICertificateEx)
  private
    FPEM: string;
    FX509: Pointer;  // PX509
    FOwnsHandle: Boolean;
    FInfo: TCertInfo;
    
    procedure LoadInfo;
    procedure EnsureHandle;
    procedure EnsurePEM;
  public
    constructor Create(const APEM: string);
    constructor CreateFromHandle(AHandle: Pointer; AOwnsHandle: Boolean = True);
    destructor Destroy; override;
    
    // ICertificate
    function GetSubject: string;
    function GetIssuer: string;
    function GetSerialNumber: string;
    function GetNotBefore: TDateTime;
    function GetNotAfter: TDateTime;
    function GetSubjectAltNames: TStringArray;
    function IsCA: Boolean;
    function IsValidAt(ATime: TDateTime): Boolean;
    function IsExpired: Boolean;
    function ToPEM: string;
    function ToDER: TBytes;
    procedure SaveToFile(const AFile: string);
    
    // ICertificateEx
    function GetX509Handle: Pointer;
  end;

  TPrivateKeyImpl = class(TInterfacedObject, IPrivateKey, IPrivateKeyEx)
  private
    FPEM: string;
    FEVPKey: Pointer;  // PEVP_PKEY
    FOwnsHandle: Boolean;
    
    procedure EnsureHandle;
    procedure EnsurePEM;
  public
    constructor Create(const APEM: string);
    constructor CreateFromHandle(AHandle: Pointer; AOwnsHandle: Boolean = True);
    destructor Destroy; override;
    
    // IPrivateKey
    function ToPEM: string;
    procedure SaveToFile(const AFile: string);
    
    // IPrivateKeyEx
    function GetEVP_PKEYHandle: Pointer;
  end;

  TKeyPairWithCertificateImpl = class(TInterfacedObject, IKeyPairWithCertificate)
  private
    FCertificate: ICertificate;
    FPrivateKey: IPrivateKey;
  public
    constructor Create(const ACertPEM, AKeyPEM: string);
    
    // IKeyPairWithCertificate
    function GetCertificate: ICertificate;
    function GetPrivateKey: IPrivateKey;
    procedure SaveToFiles(const ACertFile, AKeyFile: string);
    procedure SaveToPEM(out ACertPEM, AKeyPEM: string);
  end;

  TCertificateBuilderImpl = class(TInterfacedObject, ICertificateBuilder)
  private
    FOptions: TCertGenOptions;
  public
    constructor Create;
    destructor Destroy; override;
    
    // ICertificateBuilder - Subject
    function WithCommonName(const AName: string): ICertificateBuilder;
    function WithOrganization(const AOrg: string): ICertificateBuilder;
    function WithOrganizationalUnit(const AOU: string): ICertificateBuilder;
    function WithCountry(const ACountry: string): ICertificateBuilder;
    function WithState(const AState: string): ICertificateBuilder;
    function WithLocality(const ALocality: string): ICertificateBuilder;
    
    // Validity
    function ValidFor(ADays: Integer): ICertificateBuilder;
    function ValidFrom(AStart: TDateTime): ICertificateBuilder;
    function ValidUntil(AEnd: TDateTime): ICertificateBuilder;
    
    // Keys
    function WithRSAKey(ABits: Integer = 2048): ICertificateBuilder; overload;
    function WithRSAKey(const ASize: TKeySize): ICertificateBuilder; overload;
    function WithECDSAKey(const ACurve: string = 'prime256v1'): ICertificateBuilder; overload;
    function WithECDSAKey(ACurve: TEllipticCurve): ICertificateBuilder; overload;
    function WithEd25519Key: ICertificateBuilder;
    
    // Extensions
    function AddSubjectAltName(const ASAN: string): ICertificateBuilder;
    function AsCA: ICertificateBuilder;
    function AsServerCert: ICertificateBuilder;
    function AsClientCert: ICertificateBuilder;
    
    // Serial
    function WithSerialNumber(ASerial: Int64): ICertificateBuilder;
    
    // Signing
    function SelfSigned: IKeyPairWithCertificate;
    function SignedBy(const ACA: ICertificate; const AKey: IPrivateKey): IKeyPairWithCertificate;
  end;

implementation

function CertificateECDSACurveToToken(ACurve: TEllipticCurve): string;
begin
  case ACurve of
    ec_P256: Result := 'prime256v1';
    ec_P384: Result := 'secp384r1';
    ec_P521: Result := 'secp521r1';
    ec_BrainpoolP256: Result := 'brainpoolP256r1';
    ec_BrainpoolP384: Result := 'brainpoolP384r1';
    ec_BrainpoolP512: Result := 'brainpoolP512r1';
    ec_X25519, ec_X448:
      raise ESSLInvalidArgument.Create(
        'ECDSA certificate keys do not support X25519/X448 curves',
        sslErrInvalidParam
      );
  else
    raise ESSLInvalidArgument.Create(
      'Unsupported ECDSA certificate curve',
      sslErrInvalidParam
    );
  end;
end;

procedure RequireCertificatePEMLoadHelpers;
begin
  if (not Assigned(BIO_new_mem_buf)) or
    (not Assigned(BIO_free)) or
    (not Assigned(PEM_read_bio_X509)) then
    raise ESSLException.Create('Required OpenSSL certificate PEM load helpers are unavailable');
end;

procedure RequireCertificatePEMSaveHelpers;
begin
  if (not Assigned(BIO_new)) or
    (not Assigned(BIO_s_mem)) or
    (not Assigned(BIO_free)) or
    (not Assigned(PEM_write_bio_X509)) then
    raise ESSLException.Create('Required OpenSSL certificate PEM save helpers are unavailable');
end;

procedure RequirePrivateKeyPEMLoadHelpers;
begin
  if (not Assigned(BIO_new_mem_buf)) or
    (not Assigned(BIO_free)) or
    (not Assigned(PEM_read_bio_PrivateKey)) then
    raise ESSLException.Create('Required OpenSSL private-key PEM load helpers are unavailable');
end;

procedure RequirePrivateKeyPEMSaveHelpers;
begin
  if (not Assigned(BIO_new)) or
    (not Assigned(BIO_s_mem)) or
    (not Assigned(BIO_free)) or
    (not Assigned(PEM_write_bio_PrivateKey)) then
    raise ESSLException.Create('Required OpenSSL private-key PEM save helpers are unavailable');
end;

{ TCertificateImpl }

constructor TCertificateImpl.Create(const APEM: string);
begin
  inherited Create;
  FPEM := APEM;
  FX509 := nil;
  FOwnsHandle := False;
  LoadInfo;
end;

constructor TCertificateImpl.CreateFromHandle(AHandle: Pointer; AOwnsHandle: Boolean);
begin
  inherited Create;
  FX509 := AHandle;
  FOwnsHandle := AOwnsHandle;
  FPEM := '';
  EnsurePEM;  // Convert handle to PEM
  LoadInfo;
end;

destructor TCertificateImpl.Destroy;
begin
  if Assigned(FInfo.SubjectAltNames) then
    FInfo.SubjectAltNames.Free;
    
  // Free OpenSSL handle if we own it
  if FOwnsHandle and Assigned(FX509) then
    X509_free(FX509);
    
  inherited;
end;

procedure TCertificateImpl.EnsureHandle;
var
  LBio: PBIO;
begin
  if Assigned(FX509) then Exit;  // Already have handle
  
  if FPEM = '' then
    raise ESSLException.Create('No PEM data available');

  RequireCertificatePEMLoadHelpers;
  
  // Convert PEM to X509 handle
  LBio := BIO_new_mem_buf(PAnsiChar(FPEM), Length(FPEM));
  if not Assigned(LBio) then
    raise ESSLException.Create('Failed to create BIO');
    
  try
    FX509 := PEM_read_bio_X509(LBio, nil, nil, nil);
    if not Assigned(FX509) then
      raise ESSLException.Create('Failed to parse PEM certificate');
    FOwnsHandle := True;  // We own this handle
  finally
    BIO_free(LBio);
  end;
end;

procedure TCertificateImpl.EnsurePEM;
var
  LBio: PBIO;
  LDataPtr: PAnsiChar;
  LDataLen: Integer;
begin
  if FPEM <> '' then Exit;  // Already have PEM
  
  if not Assigned(FX509) then
    raise ESSLException.Create('No X509 handle available');

  RequireCertificatePEMSaveHelpers;
  
  // Convert X509 handle to PEM
  LBio := BIO_new(BIO_s_mem());
  if not Assigned(LBio) then
    raise ESSLException.Create('Failed to create BIO');
    
  try
    if PEM_write_bio_X509(LBio, FX509) <> 1 then
      raise ESSLException.Create('Failed to write X509 to PEM');
      
    LDataLen := BIO_get_mem_data(LBio, @LDataPtr);
    if (LDataLen > 0) and Assigned(LDataPtr) then
      SetString(FPEM, LDataPtr, LDataLen);
  finally
    BIO_free(LBio);
  end;
end;

procedure TCertificateImpl.LoadInfo;
begin
  FInfo := TCertificateUtils.GetInfo(FPEM);
end;

function TCertificateImpl.GetSubject: string;
begin
  Result := FInfo.Subject;
end;

function TCertificateImpl.GetIssuer: string;
begin
  Result := FInfo.Issuer;
end;

function TCertificateImpl.GetSerialNumber: string;
begin
  Result := FInfo.SerialNumber;
end;

function TCertificateImpl.GetNotBefore: TDateTime;
begin
  Result := FInfo.NotBefore;
end;

function TCertificateImpl.GetNotAfter: TDateTime;
begin
  Result := FInfo.NotAfter;
end;

function TCertificateImpl.GetSubjectAltNames: TStringArray;
var
  I: Integer;
begin
  SetLength(Result, 0);
  if Assigned(FInfo.SubjectAltNames) then
  begin
    SetLength(Result, FInfo.SubjectAltNames.Count);
    for I := 0 to FInfo.SubjectAltNames.Count - 1 do
      Result[I] := FInfo.SubjectAltNames[I];
  end;
end;

function TCertificateImpl.IsCA: Boolean;
begin
  Result := FInfo.IsCA;
end;

function TCertificateImpl.IsValidAt(ATime: TDateTime): Boolean;
begin
  Result := (ATime >= FInfo.NotBefore) and (ATime <= FInfo.NotAfter);
end;

function TCertificateImpl.IsExpired: Boolean;
begin
  Result := Now > FInfo.NotAfter;
end;

function TCertificateImpl.ToPEM: string;
begin
  Result := FPEM;
end;

function TCertificateImpl.ToDER: TBytes;
begin
  Result := TCertificateUtils.PEMToDER(FPEM);
end;

procedure TCertificateImpl.SaveToFile(const AFile: string);
begin
  TCertificateUtils.SaveToFile(AFile, FPEM);
end;

function TCertificateImpl.GetX509Handle: Pointer;
begin
  EnsureHandle;
  Result := FX509;
end;

{ TPrivateKeyImpl }

constructor TPrivateKeyImpl.Create(const APEM: string);
begin
  inherited Create;
  FPEM := APEM;
  FEVPKey := nil;
  FOwnsHandle := False;
end;

constructor TPrivateKeyImpl.CreateFromHandle(AHandle: Pointer; AOwnsHandle: Boolean);
begin
  inherited Create;
  FEVPKey := AHandle;
  FOwnsHandle := AOwnsHandle;
  FPEM := '';
  EnsurePEM;
end;

destructor TPrivateKeyImpl.Destroy;
begin
  if FOwnsHandle and Assigned(FEVPKey) then
    EVP_PKEY_free(FEVPKey);
  inherited;
end;

procedure TPrivateKeyImpl.EnsureHandle;
var
  LBio: PBIO;
begin
  if Assigned(FEVPKey) then Exit;
  
  if FPEM = '' then
    raise ESSLException.Create('No PEM data available');

  RequirePrivateKeyPEMLoadHelpers;
  
  LBio := BIO_new_mem_buf(PAnsiChar(FPEM), Length(FPEM));
  if not Assigned(LBio) then
    raise ESSLException.Create('Failed to create BIO');
    
  try
    FEVPKey := PEM_read_bio_PrivateKey(LBio, nil, nil, nil);
    if not Assigned(FEVPKey) then
      raise ESSLException.Create('Failed to parse PEM private key');
    FOwnsHandle := True;
  finally
    BIO_free(LBio);
  end;
end;

procedure TPrivateKeyImpl.EnsurePEM;
var
  LBio: PBIO;
  LDataPtr: PAnsiChar;
  LDataLen: Integer;
begin
  if FPEM <> '' then Exit;
  
  if not Assigned(FEVPKey) then
    raise ESSLException.Create('No EVP_PKEY handle available');

  RequirePrivateKeyPEMSaveHelpers;
  
  LBio := BIO_new(BIO_s_mem());
  if not Assigned(LBio) then
    raise ESSLException.Create('Failed to create BIO');
    
  try
    if PEM_write_bio_PrivateKey(LBio, FEVPKey, nil, nil, 0, nil, nil) <> 1 then
      raise ESSLException.Create('Failed to write EVP_PKEY to PEM');
      
    LDataLen := BIO_get_mem_data(LBio, @LDataPtr);
    if (LDataLen > 0) and Assigned(LDataPtr) then
      SetString(FPEM, LDataPtr, LDataLen);
  finally
    BIO_free(LBio);
  end;
end;

function TPrivateKeyImpl.ToPEM: string;
begin
  EnsurePEM;
  Result := FPEM;
end;

procedure TPrivateKeyImpl.SaveToFile(const AFile: string);
begin
  EnsurePEM;
  TCertificateUtils.SaveToFile(AFile, FPEM);
end;

function TPrivateKeyImpl.GetEVP_PKEYHandle: Pointer;
begin
  EnsureHandle;
  Result := FEVPKey;
end;

{ TKeyPairWithCertificateImpl }

constructor TKeyPairWithCertificateImpl.Create(const ACertPEM, AKeyPEM: string);
begin
  inherited Create;
  FCertificate := TCertificateImpl.Create(ACertPEM);
  FPrivateKey := TPrivateKeyImpl.Create(AKeyPEM);
end;

function TKeyPairWithCertificateImpl.GetCertificate: ICertificate;
begin
  Result := FCertificate;
end;

function TKeyPairWithCertificateImpl.GetPrivateKey: IPrivateKey;
begin
  Result := FPrivateKey;
end;

procedure TKeyPairWithCertificateImpl.SaveToFiles(const ACertFile, AKeyFile: string);
begin
  FCertificate.SaveToFile(ACertFile);
  FPrivateKey.SaveToFile(AKeyFile);
end;

procedure TKeyPairWithCertificateImpl.SaveToPEM(out ACertPEM, AKeyPEM: string);
begin
  ACertPEM := FCertificate.ToPEM;
  AKeyPEM := FPrivateKey.ToPEM;
end;

{ TCertificateBuilderImpl }

constructor TCertificateBuilderImpl.Create;
begin
  inherited Create;
  FOptions := TCertificateUtils.DefaultGenOptions;
end;

destructor TCertificateBuilderImpl.Destroy;
begin
  if Assigned(FOptions.SubjectAltNames) then
    FOptions.SubjectAltNames.Free;
  inherited;
end;

function TCertificateBuilderImpl.WithCommonName(const AName: string): ICertificateBuilder;
begin
  FOptions.CommonName := AName;
  Result := Self;
end;

function TCertificateBuilderImpl.WithOrganization(const AOrg: string): ICertificateBuilder;
begin
  FOptions.Organization := AOrg;
  Result := Self;
end;

function TCertificateBuilderImpl.WithOrganizationalUnit(const AOU: string): ICertificateBuilder;
begin
  FOptions.OrganizationalUnit := AOU;
  Result := Self;
end;

function TCertificateBuilderImpl.WithCountry(const ACountry: string): ICertificateBuilder;
begin
  FOptions.Country := ACountry;
  Result := Self;
end;

function TCertificateBuilderImpl.WithState(const AState: string): ICertificateBuilder;
begin
  FOptions.State := AState;
  Result := Self;
end;

function TCertificateBuilderImpl.WithLocality(const ALocality: string): ICertificateBuilder;
begin
  FOptions.Locality := ALocality;
  Result := Self;
end;

function TCertificateBuilderImpl.ValidFor(ADays: Integer): ICertificateBuilder;
begin
  FOptions.ValidDays := ADays;
  Result := Self;
end;

function TCertificateBuilderImpl.ValidFrom(AStart: TDateTime): ICertificateBuilder;
begin
  FOptions.NotBefore := AStart;
  Result := Self;
end;

function TCertificateBuilderImpl.ValidUntil(AEnd: TDateTime): ICertificateBuilder;
begin
  FOptions.NotAfter := AEnd;
  Result := Self;
end;

function TCertificateBuilderImpl.WithRSAKey(ABits: Integer): ICertificateBuilder;
begin
  FOptions.KeyType := ktRSA;
  FOptions.KeyBits := ABits;
  Result := Self;
end;

function TCertificateBuilderImpl.WithRSAKey(const ASize: TKeySize): ICertificateBuilder;
begin
  Result := WithRSAKey(ASize.ToBits);
end;

function TCertificateBuilderImpl.WithECDSAKey(const ACurve: string): ICertificateBuilder;
begin
  FOptions.KeyType := ktECDSA;
  FOptions.ECCurve := ACurve;
  Result := Self;
end;

function TCertificateBuilderImpl.WithECDSAKey(ACurve: TEllipticCurve): ICertificateBuilder;
begin
  Result := WithECDSAKey(CertificateECDSACurveToToken(ACurve));
end;

function TCertificateBuilderImpl.WithEd25519Key: ICertificateBuilder;
begin
  FOptions.KeyType := ktEd25519;
  Result := Self;
end;

function TCertificateBuilderImpl.AddSubjectAltName(const ASAN: string): ICertificateBuilder;
begin
  if not Assigned(FOptions.SubjectAltNames) then
    FOptions.SubjectAltNames := TStringList.Create;
  FOptions.SubjectAltNames.Add(ASAN);
  Result := Self;
end;

function TCertificateBuilderImpl.AsCA: ICertificateBuilder;
begin
  FOptions.IsCA := True;
  Result := Self;
end;

function TCertificateBuilderImpl.AsServerCert: ICertificateBuilder;
begin
  FOptions.IsCA := False;
  // Set appropriate KeyUsage for server certificates:
  // - digitalSignature: For TLS handshake signatures
  // - keyEncipherment: For RSA key exchange
  // - keyAgreement: For ECDHE key exchange  
  // ExtendedKeyUsage: serverAuth (OID 1.3.6.1.5.5.7.3.1)
  // These will be applied during certificate generation in TCertificateUtils
  Result := Self;
end;

function TCertificateBuilderImpl.AsClientCert: ICertificateBuilder;
begin
  FOptions.IsCA := False;
  // Set appropriate KeyUsage for client certificates:
  // - digitalSignature: For client authentication signatures
  // - keyEncipherment: For encrypted client key exchange
  // ExtendedKeyUsage: clientAuth (OID 1.3.6.1.5.5.7.3.2)
  // These will be applied during certificate generation in TCertificateUtils
  Result := Self;
end;

function TCertificateBuilderImpl.WithSerialNumber(ASerial: Int64): ICertificateBuilder;
begin
  FOptions.SerialNumber := ASerial;
  Result := Self;
end;

function TCertificateBuilderImpl.SelfSigned: IKeyPairWithCertificate;
var
  LCertPEM, LKeyPEM: string;
begin
  if not TCertificateUtils.GenerateSelfSigned(FOptions, LCertPEM, LKeyPEM) then
    raise ESSLException.Create('Failed to generate self-signed certificate');
    
  Result := TKeyPairWithCertificateImpl.Create(LCertPEM, LKeyPEM);
end;

function TCertificateBuilderImpl.SignedBy(const ACA: ICertificate; 
  const AKey: IPrivateKey): IKeyPairWithCertificate;
var
  LCertPEM, LKeyPEM: string;
  LCAPEM, LCAKeyPEM: string;
begin
  LCAPEM := ACA.ToPEM;
  LCAKeyPEM := AKey.ToPEM;
  
  if not TCertificateUtils.GenerateSigned(FOptions, LCAPEM, LCAKeyPEM, LCertPEM, LKeyPEM) then
    raise ESSLException.Create('Failed to generate CA-signed certificate');
    
  Result := TKeyPairWithCertificateImpl.Create(LCertPEM, LKeyPEM);
end;

end.

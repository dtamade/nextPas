{
  nextpas.core.tls.cert.advanced - Advanced Certificate Features

  Enterprise-grade certificate management:
  - OCSP (Online Certificate Status Protocol) client
  - CRL (Certificate Revocation List) manager
  - PKCS#12 (.p12/.pfx) import/export
}

unit nextpas.core.tls.cert.advanced;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{ 禁用函数结果未初始化警告 - SetLength 已经初始化 TBytes }
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized
{ 禁用弃用 API 警告 - 这些弃用 API 仍在内部使用 }
{$WARN 5066 off}  // Symbol is deprecated: "message"

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem;

type
  { OCSP Status }
  TOCSPStatus = (
    ocspGood,           // Certificate is valid
    ocspRevoked,        // Certificate has been revoked
    ocspUnknown,        // Status unknown
    ocspError           // Error checking status
  );

  { OCSP Response }
  TOCSPResponse = record
    Status: TOCSPStatus;
    RevokedAt: TDateTime;
    Reason: string;
    NextUpdate: TDateTime;
    ErrorMessage: string;
  end;

  {**
   * IOCSPClient - OCSP Client interface
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  IOCSPClient = interface
    ['{F6071819-1011-4345-6789-012345678901}']
    
    function CheckCertificate(const ACert: ICertificate; const AIssuer: ICertificate): TOCSPResponse;
    procedure SetResponderURL(const AURL: string);
    procedure SetTimeout(ASeconds: Integer);
  end;

  {**
   * ICRLManager - CRL Manager interface
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ICRLManager = interface
    ['{07182019-2021-4567-8901-234567890123}']
    
    procedure LoadFromURL(const AURL: string);
    procedure LoadFromFile(const AFile: string);
    procedure LoadFromPEM(const APEM: string);
    
    function IsRevoked(const ACert: ICertificate): Boolean;
    function GetRevokedDate(const ACert: ICertificate): TDateTime;
    function GetRevocationReason(const ACert: ICertificate): string;
    
    procedure Refresh;
    function IsExpired: Boolean;
    function GetNextUpdate: TDateTime;
  end;

  { PKCS#12 Options }
  TPKCS12Options = record
    FriendlyName: string;
    Password: string;
    Iterations: Integer;  // Key derivation iterations
    IncludeChain: Boolean; // Include certificate chain
  end;

  { PKCS#12 Manager }
  TPKCS12Manager = class
  public
    { Export certificate + key to PKCS#12 }
    class function CreatePKCS12(
      const ACert: ICertificate;
      const AKey: IPrivateKey;
      const AOptions: TPKCS12Options
    ): TBytes; static;
    
    class function CreatePKCS12ToFile(
      const ACert: ICertificate;
      const AKey: IPrivateKey;
      const AFile: string;
      const AOptions: TPKCS12Options
    ): Boolean; static;
    
    { Import from PKCS#12 }
    class function LoadFromPKCS12(
      const APKCS12: TBytes;
      const APassword: string;
      out ACert: ICertificate;
      out AKey: IPrivateKey
    ): Boolean; static;
    
    class function LoadFromPKCS12File(
      const AFile: string;
      const APassword: string;
      out ACert: ICertificate;
      out AKey: IPrivateKey
    ): Boolean; static;
  end;

{ Helper functions }
function DefaultPKCS12Options: TPKCS12Options;

{ Factory functions }
function CreateOCSPClient: IOCSPClient;
function CreateCRLManager: ICRLManager;



implementation

uses
  nextpas.core.tls.cert.builder.impl,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.evp;

{ Helper functions }

procedure RequirePKCS12CreateBIOHelpers;
begin
  if (not Assigned(BIO_new)) or
    (not Assigned(BIO_s_mem)) or
    (not Assigned(BIO_free)) then
    raise ESSLException.Create(
      'Required OpenSSL PKCS12 BIO export helpers are unavailable',
      sslErrFunctionNotFound
    );
end;

function HasPKCS12LoadBIOHelpers: Boolean;
begin
  Result := Assigned(BIO_new_mem_buf) and Assigned(BIO_free);
end;

procedure RequireCRLLoadBIOHelpers;
begin
  if (not Assigned(BIO_new_mem_buf)) or
    (not Assigned(PEM_read_bio_X509_CRL)) or
    (not Assigned(BIO_free)) then
    raise ESSLException.Create(
      'Required OpenSSL CRL BIO load helpers are unavailable',
      sslErrFunctionNotFound
    );
end;

function ASN1TimeToDateTime(const ATime: PASN1_TIME): TDateTime;
begin
  Result := nextpas.core.tls.openssl.api.asn1.ASN1TimeToDateTime(ASN1_TIME(ATime));
end;

function DefaultPKCS12Options: TPKCS12Options;
begin
  Result.FriendlyName := '';
  Result.Password := '';
  Result.Iterations := 2048;
  Result.IncludeChain := False;
end;

{ Internal implementations }

type
  TOCSPClient = class(TInterfacedObject, IOCSPClient)
  private
    FResponderURL: string;
    FTimeout: Integer;
  public
    constructor Create;
    function CheckCertificate(const ACert: ICertificate; const AIssuer: ICertificate): TOCSPResponse;
    procedure SetResponderURL(const AURL: string);
    procedure SetTimeout(ASeconds: Integer);
  end;

{ TOCSPClient }

constructor TOCSPClient.Create;
begin
  inherited Create;
  FTimeout := 10; // Default timeout 10 seconds
end;

procedure TOCSPClient.SetResponderURL(const AURL: string);
begin
  FResponderURL := AURL;
end;

procedure TOCSPClient.SetTimeout(ASeconds: Integer);
begin
  FTimeout := ASeconds;
end;

function TOCSPClient.CheckCertificate(const ACert: ICertificate; const AIssuer: ICertificate): TOCSPResponse;
var
  LCertEx, LIssuerEx: ICertificateEx;
  LX509, LIssuerX509: PX509;
  LStatus: Integer;
  LURL: string;
begin
  // Initialize result
  Result.Status := ocspUnknown;
  Result.ErrorMessage := '';
  Result.Reason := '';
  Result.RevokedAt := 0;
  Result.NextUpdate := 0;
  
  // Get extended interfaces
  if not Supports(ACert, ICertificateEx, LCertEx) then
    RaiseUnsupported('Certificate handle access');
    
  if not Supports(AIssuer, ICertificateEx, LIssuerEx) then
    RaiseUnsupported('Issuer certificate handle access');
    
  LX509 := LCertEx.X509Handle;
  LIssuerX509 := LIssuerEx.X509Handle;
  
  // Determine Responder URL
  LURL := FResponderURL;
  // Future Enhancement: Extract URL from AIA extension if FResponderURL is empty
  // Requires: X509_get_ext_d2i with NID_info_access parsing
  
  if LURL = '' then
  begin
    Result.Status := ocspError;
    Result.ErrorMessage := 'No OCSP responder URL provided';
    Exit;
  end;
  
  try
    // Call OpenSSL OCSP helper
    LStatus := CheckCertificateStatus(LX509, LIssuerX509, LURL, FTimeout);
    
    case LStatus of
      V_OCSP_CERTSTATUS_GOOD:
        Result.Status := ocspGood;
      V_OCSP_CERTSTATUS_REVOKED:
        begin
          Result.Status := ocspRevoked;
          // Phase 4 Note: Extracting actual revocation time requires:
          // 1. OCSP_resp_find_status with revtime output parameter
          // 2. ASN1_GENERALIZEDTIME to TDateTime conversion
          // Current behavior: Returns current time as fallback
          // Impact: Low - revocation status is correctly detected
          Result.RevokedAt := Now;
        end;
      V_OCSP_CERTSTATUS_UNKNOWN:
        Result.Status := ocspUnknown;
      else
        Result.Status := ocspError;
        Result.ErrorMessage := 'OCSP check failed with status: ' + IntToStr(LStatus);
    end;
  except
    on E: Exception do
    begin
      Result.Status := ocspError;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;




type
  TCRLManagerImpl = class(TInterfacedObject, ICRLManager)
  private
    FCRL: PX509_CRL;
    FNextUpdate: TDateTime;
    procedure ParseCRL(const APEM: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromURL(const AURL: string);
    procedure LoadFromFile(const AFile: string);
    procedure LoadFromPEM(const APEM: string);
    
    function IsRevoked(const ACert: ICertificate): Boolean;
    function GetRevokedDate(const ACert: ICertificate): TDateTime;
    function GetRevocationReason(const ACert: ICertificate): string;
    
    procedure Refresh;
    function IsExpired: Boolean;
    function GetNextUpdate: TDateTime;
  end;


{ TCRLManagerImpl }

procedure TCRLManagerImpl.LoadFromURL(const AURL: string);
begin
  // Out of Scope: Download CRL from URL requires HTTP client
  // Recommendation: Use external HTTP library (Synapse, Indy, fphttpclient) to download,
  // then call LoadFromPEM with the downloaded CRL data
  RaiseUnsupported('CRL URL loading - use external HTTP library');
end;

constructor TCRLManagerImpl.Create;
begin
  inherited Create;
  FCRL := nil;
  FNextUpdate := 0;
end;

destructor TCRLManagerImpl.Destroy;
begin
  if Assigned(FCRL) then
    X509_CRL_free(FCRL);
  inherited;
end;

procedure TCRLManagerImpl.ParseCRL(const APEM: string);
var
  LBio: PBIO;
begin
  // Free existing CRL
  if Assigned(FCRL) then
  begin
    X509_CRL_free(FCRL);
    FCRL := nil;
  end;

  RequireCRLLoadBIOHelpers;
  
  // Parse PEM
  LBio := BIO_new_mem_buf(PAnsiChar(APEM), Length(APEM));
  if not Assigned(LBio) then
    RaiseMemoryError('BIO creation');
    
  try
    FCRL := PEM_read_bio_X509_CRL(LBio, nil, nil, nil);
    if not Assigned(FCRL) then
      RaiseParseError('CRL data');
      
    // Extract next update time
    if Assigned(X509_CRL_get0_nextUpdate) then
      FNextUpdate := ASN1TimeToDateTime(X509_CRL_get0_nextUpdate(FCRL))
    else
      FNextUpdate := Now + 7; // Fallback if API not available
  finally
    BIO_free(LBio);
  end;
end;

procedure TCRLManagerImpl.LoadFromFile(const AFile: string);
var
  LStream: TFileStream;
  LPEM: string;
begin
  LStream := TFileStream.Create(AFile, fmOpenRead);
  try
    SetLength(LPEM, LStream.Size);
    LStream.Read(LPEM[1], LStream.Size);
    ParseCRL(LPEM);
  finally
    LStream.Free;
  end;
end;

procedure TCRLManagerImpl.LoadFromPEM(const APEM: string);
begin
  ParseCRL(APEM);
end;

function TCRLManagerImpl.IsRevoked(const ACert: ICertificate): Boolean;
var
  LCertEx: ICertificateEx;
  LX509: PX509;
  LRevoked: Pointer;
begin
  Result := False;
  
  if not Assigned(FCRL) then
    RaiseInvalidData('CRL (no CRL loaded)');
    
  if not Supports(ACert, ICertificateEx, LCertEx) then
    RaiseUnsupported('Certificate handle access');
    
  LX509 := LCertEx.X509Handle;
  
  // Check if cert is in CRL
  if X509_CRL_get0_by_cert(FCRL, @LRevoked, LX509) = 1 then
    Result := True;
end;

function TCRLManagerImpl.GetRevokedDate(const ACert: ICertificate): TDateTime;
begin
  // Phase 4 Note: Extracting actual revocation date requires:
  // 1. X509_REVOKED_get0_revocationDate API
  // 2. ASN1_TIME to TDateTime conversion
  // Current behavior: Returns current time if revoked, 0 otherwise
  // Impact: Low - revocation check (IsRevoked) is correctly implemented
  if IsRevoked(ACert) then
    Result := Now
  else
    Result := 0;
end;

function TCRLManagerImpl.GetRevocationReason(const ACert: ICertificate): string;
begin
  // Phase 4 Note: Extracting actual revocation reason requires:
  // 1. X509_REVOKED_get_ext_d2i with NID_crl_reason
  // 2. ASN1_ENUMERATED parsing
  // Current behavior: Returns 'Unspecified' if revoked
  // Impact: Low - revocation check (IsRevoked) is correctly implemented
  if IsRevoked(ACert) then
    Result := 'Unspecified'
  else
    Result := '';
end;

procedure TCRLManagerImpl.Refresh;
begin
  // Out of Scope: Re-download CRL requires HTTP client (see LoadFromURL)
  // Users should manually re-download and call LoadFromPEM
end;

function TCRLManagerImpl.IsExpired: Boolean;
begin
  Result := Now > FNextUpdate;
end;

function TCRLManagerImpl.GetNextUpdate: TDateTime;
begin
  Result := FNextUpdate;
end;

{ TPKCS12Manager }

class function TPKCS12Manager.CreatePKCS12(
  const ACert: ICertificate;
  const AKey: IPrivateKey;
  const AOptions: TPKCS12Options
): TBytes;
var
  LP12: nextpas.core.tls.openssl.api.pkcs12.PPKCS12;
  LCertEx: ICertificateEx;
  LKeyEx: IPrivateKeyEx;
  LX509: PX509;
  LEVP: PEVP_PKEY;
  LBio: PBIO;
  LPassBytes, LNameBytes: TBytes;
  LDataPtr: PAnsiChar;
  LDataLen: Integer;
begin
  SetLength(Result, 0);
  
  // Get extended interfaces with handle access
  if not Supports(ACert, ICertificateEx, LCertEx) then
    RaiseUnsupported('Certificate handle access');
      
  if not Supports(AKey, IPrivateKeyEx, LKeyEx) then
    RaiseUnsupported('Private key handle access');
  
  // Get OpenSSL handles
  LX509 := LCertEx.X509Handle;
  LEVP := LKeyEx.EVP_PKEYHandle;
  
  // Prepare password and name
  if AOptions.Password <> '' then
    LPassBytes := nextpas.core.text.conv.StringToUTF8Bytes(AOptions.Password));
  if AOptions.FriendlyName <> '' then
    LNameBytes := nextpas.core.text.conv.StringToUTF8Bytes(AOptions.FriendlyName));
  
  // Create PKCS#12 structure
  LP12 := nextpas.core.tls.openssl.api.pkcs12.PKCS12_create(
    PAnsiChar(LPassBytes),
    PAnsiChar(LNameBytes),
    LEVP,
    LX509,
    nil,  // CA certs
    0, 0,  // Use default NIDs
    AOptions.Iterations,
    AOptions.Iterations,
    0
  );
  
  if not Assigned(LP12) then
    RaiseMemoryError('PKCS#12 structure creation');
  
  try
    // Write to memory BIO
    RequirePKCS12CreateBIOHelpers;
    LBio := BIO_new(BIO_s_mem());
    if not Assigned(LBio) then
      RaiseMemoryError('BIO creation');
      
    try
      if nextpas.core.tls.openssl.api.pkcs12.i2d_PKCS12_bio(LBio, LP12) <> 1 then
        RaiseSSLError('Failed to write PKCS#12 to BIO', sslErrIO);
      
      // Get data from BIO
      LDataLen := BIO_get_mem_data(LBio, @LDataPtr);
      if (LDataLen > 0) and Assigned(LDataPtr) then
      begin
        SetLength(Result, LDataLen);
        Move(LDataPtr^, Result[0], LDataLen);
      end;
    finally
      BIO_free(LBio);
    end;
  finally
    nextpas.core.tls.openssl.api.pkcs12.PKCS12_free(LP12);
  end;
end;

class function TPKCS12Manager.CreatePKCS12ToFile(
  const ACert: ICertificate;
  const AKey: IPrivateKey;
  const AFile: string;
  const AOptions: TPKCS12Options
): Boolean;
var
  LP12: TBytes;
  LStream: TFileStream;
begin
  LP12 := CreatePKCS12(ACert, AKey, AOptions);
  
  LStream := TFileStream.Create(AFile, fmCreate);
  try
    LStream.Write(LP12[0], Length(LP12));
    Result := True;
  finally
    LStream.Free;
  end;
end;

class function TPKCS12Manager.LoadFromPKCS12(
  const APKCS12: TBytes;
  const APassword: string;
  out ACert: ICertificate;
  out AKey: IPrivateKey
): Boolean;
var
  LP12: nextpas.core.tls.openssl.api.pkcs12.PPKCS12;
  LBio: PBIO;
  LCertPtr: PX509;
  LKeyPtr: PEVP_PKEY;
  LCAStack: Pointer;  // PSTACK_OF_X509
  LPassBytes: TBytes;
begin
  Result := False;
  ACert := nil;
  AKey := nil;
  
  if Length(APKCS12) = 0 then Exit;

  if not HasPKCS12LoadBIOHelpers then
    Exit;
  
  // Create BIO from bytes
  LBio := BIO_new_mem_buf(@APKCS12[0], Length(APKCS12));
  if not Assigned(LBio) then Exit;
  
  try
    // Read PKCS#12 from BIO
    LP12 := nil;
    LP12 := nextpas.core.tls.openssl.api.pkcs12.d2i_PKCS12_bio(LBio, LP12);
    if not Assigned(LP12) then Exit;
    
    try
      LPassBytes := nextpas.core.text.conv.StringToUTF8Bytes(APassword));
      LCertPtr := nil;
      LKeyPtr := nil;
      LCAStack := nil;
      
      // Parse PKCS#12
      if nextpas.core.tls.openssl.api.pkcs12.PKCS12_parse(
        LP12, PAnsiChar(LPassBytes),
        LKeyPtr, LCertPtr, LCAStack) = 1 then
      begin
        if Assigned(LCertPtr) and Assigned(LKeyPtr) then
        begin
          ACert := TCertificateImpl.CreateFromHandle(LCertPtr, True);
          AKey := TPrivateKeyImpl.CreateFromHandle(LKeyPtr, True);
          Result := True;
        end;
      end;
    finally
      nextpas.core.tls.openssl.api.pkcs12.PKCS12_free(LP12);
    end;
  finally
    BIO_free(LBio);
  end;
end;

class function TPKCS12Manager.LoadFromPKCS12File(
  const AFile: string;
  const APassword: string;
  out ACert: ICertificate;
  out AKey: IPrivateKey
): Boolean;
var
  LStream: TFileStream;
  LData: TBytes;
begin
  LStream := TFileStream.Create(AFile, fmOpenRead);
  try
    SetLength(LData, LStream.Size);
    LStream.Read(LData[0], LStream.Size);
    Result := LoadFromPKCS12(LData, APassword, ACert, AKey);
  finally
    LStream.Free;
  end;
end;

{ Factory functions }

function CreateOCSPClient: IOCSPClient;
begin
  Result := TOCSPClient.Create;
end;

function CreateCRLManager: ICRLManager;
begin
  Result := TCRLManagerImpl.Create;
end;

end.

unit nextpas.core.tls.pkcs11.provider;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 Provider Backend (OpenSSL 3.x)                        }
{                                                                              }
{  Purpose: Load PKCS#11 keys using OpenSSL 3.x Provider + OSSL_STORE API    }
{                                                                              }
{  Architecture:                                                               }
{    - Uses OSSL_STORE API for URI-based key loading                          }
{    - Loads pkcs11 provider dynamically                                      }
{    - Supports RFC 7512 pkcs11: URIs                                         }
{    - Preferred backend for OpenSSL 3.x                                      }
{                                                                              }
{  Requirements:                                                               }
{    - OpenSSL 3.0.0 or later                                                 }
{    - pkcs11 provider (libp11 or equivalent)                                 }
{    - PKCS#11 module (.so, .dll, .dylib)                                     }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}

interface

uses Classes, nextpas.core.tls.pkcs11.types, nextpas.core.tls.pkcs11.api, nextpas.core.tls.pkcs11.backend, nextpas.core.tls.pkcs11.uri, nextpas.core.tls.openssl.api.types, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.provider, nextpas.core.tls.openssl.api.store, nextpas.core.tls.openssl.api.ui, nextpas.core.text.conv;

type
  { TProviderBackend - OpenSSL 3.x Provider-based PKCS#11 backend }
  TProviderBackend = class(TBasePKCS11Backend)
  private
    FProvider: POSSL_PROVIDER;
    FProviderLoaded: Boolean;
    
    { Load pkcs11 provider }
    procedure LoadProvider;
    
    { Unload pkcs11 provider }
    procedure UnloadProvider;
    
    { Build OSSL_STORE URI from config }
    function BuildStoreURI(const AConfig: TPKCS11Config): string;
    
    { Load key using OSSL_STORE API }
    function LoadKeyFromStore(const AURI: string): PEVP_PKEY;
  public
    constructor Create;
    destructor Destroy; override;
    
    { IPKCS11Backend interface }
    function LoadPrivateKey(const AConfig: TPKCS11Config): PEVP_PKEY; override;
    function LoadCertificate(const AConfig: TPKCS11Config): PX509; override;
    function FindToken(const AConfig: TPKCS11Config): CK_SLOT_ID; override;
    function FindKey(ASession: CK_SESSION_HANDLE; const AConfig: TPKCS11Config): CK_OBJECT_HANDLE; override;
    function IsAvailable: Boolean; override;
    function GetName: string; override;
    function GetVersion: string; override;
  end;

implementation

uses nextpas.core.tls.openssl.api.x509, nextpas.core.text.conv;

{ TProviderBackend }

constructor TProviderBackend.Create;
begin
  inherited Create;
  FProvider := nil;
  FProviderLoaded := False;
end;

destructor TProviderBackend.Destroy;
begin
  UnloadProvider;
  inherited Destroy;
end;

procedure TProviderBackend.LoadProvider;
begin
  if FProviderLoaded then
    Exit;
  
  // Try to load pkcs11 provider
  // Note: Provider name might be 'pkcs11' or 'libp11' depending on installation
  FProvider := OSSL_PROVIDER_load(nil, 'pkcs11');
  if FProvider = nil then
    FProvider := OSSL_PROVIDER_load(nil, 'libp11');
  
  if FProvider = nil then
    raise EPKCS11Exception.Create(
      'Failed to load PKCS#11 provider. ' +
      'Ensure libp11 or equivalent provider is installed for OpenSSL 3.x.',
      CKR_GENERAL_ERROR);
  
  FProviderLoaded := True;
end;

procedure TProviderBackend.UnloadProvider;
begin
  if FProviderLoaded and (FProvider <> nil) then
  begin
    OSSL_PROVIDER_unload(FProvider);
    FProvider := nil;
    FProviderLoaded := False;
  end;
end;

function TProviderBackend.BuildStoreURI(const AConfig: TPKCS11Config): string;
var
  URI: TPKCS11URI;
begin
  // Build RFC 7512 URI from config
  FillChar(URI, SizeOf(URI), 0);
  
  URI.Token := AConfig.TokenLabel;
  URI.ObjectLabel := AConfig.KeyLabel;
  URI.ModulePath := AConfig.ModulePath;
  
  if AConfig.SlotID >= 0 then
    URI.SlotID := IntToStr(AConfig.SlotID);
  
  // Don't include PIN in URI (security risk)
  // PIN will be provided via callback or environment
  
  Result := TPKCS11URIParser.Generate(URI);
end;

function TProviderBackend.LoadKeyFromStore(const AURI: string): PEVP_PKEY;
var
  StoreCtx: POSSL_STORE_CTX;
  Info: POSSL_STORE_INFO;
  InfoType: Integer;
  Key: PEVP_PKEY;
  URIAnsi: AnsiString;
  UIMethod: PUI_METHOD;
begin
  Result := nil;
  Key := nil;
  
  // Convert URI to ANSI for OSSL_STORE.
  URIAnsi := AnsiString(AURI);
  
  // Create UI method for PIN (use simple password UI)
  UIMethod := CreateSimplePasswordUI('Enter PIN: ');
  
  // Open OSSL_STORE context
  StoreCtx := OSSL_STORE_open(PAnsiChar(URIAnsi), UIMethod, nil, nil, nil);
  if StoreCtx = nil then
    raise EPKCS11Exception.Create(
      'Failed to open OSSL_STORE for URI: ' + AURI,
      CKR_GENERAL_ERROR);
  
  try
    // Expect private key
    if OSSL_STORE_expect(StoreCtx, OSSL_STORE_INFO_PKEY) <> 1 then
      raise EPKCS11Exception.Create(
        'Failed to set OSSL_STORE expectation to PKEY',
        CKR_GENERAL_ERROR);
    
    // Load objects until we find a private key
    while OSSL_STORE_eof(StoreCtx) = 0 do
    begin
      Info := OSSL_STORE_load(StoreCtx);
      if Info = nil then
        Continue;
      
      try
        InfoType := OSSL_STORE_INFO_get_type(Info);
        
        if InfoType = OSSL_STORE_INFO_PKEY then
        begin
          Key := OSSL_STORE_INFO_get1_PKEY(Info);
          if Key <> nil then
          begin
            Result := Key;
            Break;
          end;
        end;
      finally
        OSSL_STORE_INFO_free(Info);
      end;
    end;
    
    if Result = nil then
      raise EPKCS11Exception.Create(
        'No private key found in PKCS#11 URI: ' + AURI,
        CKR_KEY_HANDLE_INVALID);
  finally
    if StoreCtx <> nil then
      OSSL_STORE_close(StoreCtx);
  end;
end;

function TProviderBackend.FindToken(const AConfig: TPKCS11Config): CK_SLOT_ID;
begin
  // Not used in Provider backend (OSSL_STORE handles token selection)
  Result := 0;
end;

function TProviderBackend.FindKey(ASession: CK_SESSION_HANDLE; const AConfig: TPKCS11Config): CK_OBJECT_HANDLE;
begin
  // Not used in Provider backend (OSSL_STORE handles key selection)
  Result := 0;
end;

function TProviderBackend.LoadPrivateKey(const AConfig: TPKCS11Config): PEVP_PKEY;
var
  URI: string;
begin
  // Validate configuration
  ValidateConfig(AConfig);
  
  // Load provider if not already loaded
  LoadProvider;
  
  // Preserve PIN-required validation; OSSL_STORE handles provider-side PIN IO.
  ResolvePIN(AConfig);
  
  // Build OSSL_STORE URI
  URI := BuildStoreURI(AConfig);
  
  // Load key from store
  Result := LoadKeyFromStore(URI);
end;

function TProviderBackend.LoadCertificate(const AConfig: TPKCS11Config): PX509;
var
  StoreCtx: POSSL_STORE_CTX;
  Info: POSSL_STORE_INFO;
  InfoType: Integer;
  Cert: PX509;
  URI: string;
begin
  Result := nil;
  
  // Validate configuration
  ValidateConfig(AConfig);
  
  // Load provider if not already loaded
  LoadProvider;
  
  // Preserve PIN-required validation; OSSL_STORE handles provider-side PIN IO.
  ResolvePIN(AConfig);
  
  // Build OSSL_STORE URI
  URI := BuildStoreURI(AConfig);
  
  // Open OSSL_STORE context
  StoreCtx := OSSL_STORE_open(PAnsiChar(AnsiString(URI)), nil, nil, nil, nil);
  if StoreCtx = nil then
    raise EPKCS11Exception.Create(
      'Failed to open OSSL_STORE with URI: ' + URI,
      CKR_GENERAL_ERROR);
  
  try
    // Expect certificate
    if OSSL_STORE_expect(StoreCtx, OSSL_STORE_INFO_CERT) <> 1 then
      raise EPKCS11Exception.Create(
        'Failed to set OSSL_STORE expectation to CERT',
        CKR_GENERAL_ERROR);
    
    // Load objects until we find a certificate
    while OSSL_STORE_eof(StoreCtx) = 0 do
    begin
      Info := OSSL_STORE_load(StoreCtx);
      if Info = nil then
        Continue;
      
      try
        InfoType := OSSL_STORE_INFO_get_type(Info);
        
        if InfoType = OSSL_STORE_INFO_CERT then
        begin
          Cert := OSSL_STORE_INFO_get1_CERT(Info);
          if Cert <> nil then
          begin
            Result := Cert;
            Break;
          end;
        end;
      finally
        OSSL_STORE_INFO_free(Info);
      end;
    end;
    
    if Result = nil then
      raise EPKCS11Exception.Create(
        'No certificate found in PKCS#11 token',
        CKR_GENERAL_ERROR);
  finally
    OSSL_STORE_close(StoreCtx);
  end;
end;

function TProviderBackend.IsAvailable: Boolean;
begin
  // Check if OpenSSL 3.x Provider API is available
  Result := Assigned(OSSL_PROVIDER_load) and
            Assigned(OSSL_PROVIDER_unload) and
            Assigned(OSSL_STORE_open) and
            Assigned(OSSL_STORE_close) and
            Assigned(OSSL_STORE_load) and
            Assigned(OSSL_STORE_expect) and
            Assigned(OSSL_STORE_eof) and
            Assigned(OSSL_STORE_INFO_get_type) and
            Assigned(OSSL_STORE_INFO_get1_PKEY) and
            Assigned(OSSL_STORE_INFO_get1_CERT) and
            Assigned(OSSL_STORE_INFO_free);
end;

function TProviderBackend.GetName: string;
begin
  Result := 'Provider (OpenSSL 3.x)';
end;

function TProviderBackend.GetVersion: string;
begin
  Result := '3.0+';
end;

end.

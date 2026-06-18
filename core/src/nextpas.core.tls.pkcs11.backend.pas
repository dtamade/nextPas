unit nextpas.core.tls.pkcs11.backend;

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 Backend Abstraction                                   }
{                                                                              }
{  Purpose: Abstract interface for PKCS#11 key loading backends               }
{                                                                              }
{  Architecture:                                                               }
{    - IPKCS11Backend: Abstract interface for all backends                    }
{    - Backend implementations:                                               }
{      * TProviderBackend: OpenSSL 3.x OSSL_STORE + Provider (recommended)   }
{      * TEngineBackend: OpenSSL 1.1.1 ENGINE API (legacy fallback)          }
{    - Factory pattern for backend selection                                  }
{                                                                              }
{  Design Pattern: Strategy Pattern                                           }
{    - Different backends implement same interface                            }
{    - Runtime selection based on OpenSSL version                             }
{    - Graceful fallback from Provider → ENGINE                              }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.exception,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.pkcs11.api,
  nextpas.core.tls.openssl.api.types,
  nextpas.core.tls.openssl.api.evp;

type
  { IPKCS11Backend - Abstract interface for PKCS#11 key loading }
  IPKCS11Backend = interface
    ['{8F3A2B1C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    
    { Load private key from PKCS#11 token
      
      Parameters:
        AConfig: PKCS#11 configuration (token, key, PIN, etc.)
        
      Returns:
        EVP_PKEY handle (caller must free with EVP_PKEY_free)
        
      Raises:
        EPKCS11Exception on failure
    }
    function LoadPrivateKey(const AConfig: TPKCS11Config): PEVP_PKEY;
    
    { Load certificate from PKCS#11 token
      
      Parameters:
        AConfig: PKCS#11 configuration
        
      Returns:
        X509 certificate handle (caller must free with X509_free)
        
      Raises:
        EPKCS11Exception on failure
    }
    function LoadCertificate(const AConfig: TPKCS11Config): PX509;
    
    { Check if backend is available/supported
      
      Returns:
        True if backend can be used in current environment
    }
    function IsAvailable: Boolean;
    
    { Get backend name for logging/debugging }
    function GetName: string;
    
    { Get backend version info }
    function GetVersion: string;
  end;

  { TPKCS11BackendType - Available backend types }
  TPKCS11BackendType = (
    btAuto,       // Auto-detect best available backend
    btProvider,   // OpenSSL 3.x Provider (OSSL_STORE)
    btEngine      // OpenSSL 1.1.1 ENGINE
  );

  { TPKCS11BackendFactory - Factory for creating backends }
  TPKCS11BackendFactory = class
  private
    class var FDefaultBackendType: TPKCS11BackendType;
  public
    { Create backend instance
      
      Parameters:
        ABackendType: Requested backend type (btAuto = auto-detect)
        
      Returns:
        Backend instance (caller must free)
        
      Raises:
        Exception if no suitable backend available
    }
    class function CreateBackend(ABackendType: TPKCS11BackendType = btAuto): IPKCS11Backend;
    
    { Check if specific backend type is available }
    class function IsBackendAvailable(ABackendType: TPKCS11BackendType): Boolean;
    
    { Get/Set default backend type for auto-detection }
    class property DefaultBackendType: TPKCS11BackendType read FDefaultBackendType write FDefaultBackendType;
  end;

  { TBasePKCS11Backend - Base class with common functionality }
  TBasePKCS11Backend = class(TInterfacedObject, IPKCS11Backend)
  protected
    { Validate configuration before loading }
    procedure ValidateConfig(const AConfig: TPKCS11Config);
    
    { Resolve PIN from configuration }
    function ResolvePIN(const AConfig: TPKCS11Config): string;
    
    { Find token by label or slot ID }
    function FindToken(const AConfig: TPKCS11Config): CK_SLOT_ID; virtual; abstract;
    
    { Find key object in token }
    function FindKey(ASession: CK_SESSION_HANDLE; const AConfig: TPKCS11Config): CK_OBJECT_HANDLE; virtual; abstract;
  public
    { IPKCS11Backend interface }
    function LoadPrivateKey(const AConfig: TPKCS11Config): PEVP_PKEY; virtual; abstract;
    function LoadCertificate(const AConfig: TPKCS11Config): PX509; virtual; abstract;
    function IsAvailable: Boolean; virtual; abstract;
    function GetName: string; virtual; abstract;
    function GetVersion: string; virtual; abstract;
  end;

implementation

uses SysUtils, nextpas.core.tls.openssl.api.provider, nextpas.core.tls.openssl.api.engine, nextpas.core.tls.openssl.api.store, nextpas.core.tls.pkcs11.provider, nextpas.core.tls.pkcs11.engine;

{ TPKCS11BackendFactory }

class function TPKCS11BackendFactory.CreateBackend(ABackendType: TPKCS11BackendType): IPKCS11Backend;
var
  BackendType: TPKCS11BackendType;
begin
  Result := nil;
  BackendType := ABackendType;
  
  // Auto-detect if requested
  if BackendType = btAuto then
    BackendType := FDefaultBackendType;
  
  // Try requested backend type
  case BackendType of
    btProvider:
      if IsBackendAvailable(btProvider) then
        Result := TProviderBackend.Create as IPKCS11Backend;

    btEngine:
      if IsBackendAvailable(btEngine) then
        Result := TEngineBackend.Create as IPKCS11Backend;

    btAuto:
      begin
        // Try Provider first (OpenSSL 3.x)
        if IsBackendAvailable(btProvider) then
          Result := TProviderBackend.Create as IPKCS11Backend
        // Fallback to ENGINE (OpenSSL 1.1.1)
        else if IsBackendAvailable(btEngine) then
          Result := TEngineBackend.Create as IPKCS11Backend;
      end;
  end;
  
  if Result = nil then
    raise Exception.Create('No suitable PKCS#11 backend available. ' +
      'Ensure OpenSSL 3.x (with Provider support) or OpenSSL 1.1.1 (with ENGINE support) is installed.');
end;

{$WARN 6018 OFF}
class function TPKCS11BackendFactory.IsBackendAvailable(ABackendType: TPKCS11BackendType): Boolean;
begin
  case ABackendType of
    btProvider:
      // Check if OpenSSL 3.x Provider API is available
      Result := Assigned(OSSL_PROVIDER_load) and 
                Assigned(OSSL_STORE_open) and
                Assigned(OSSL_STORE_expect);
                
    btEngine:
      // Check if OpenSSL 1.1.1 ENGINE API is available
      Result := Assigned(ENGINE_by_id) and
                Assigned(ENGINE_init) and
                Assigned(ENGINE_load_private_key);
                
    btAuto:
      Result := IsBackendAvailable(btProvider) or IsBackendAvailable(btEngine);
  else
    Result := False;
  end;
end;
{$WARN 6018 ON}

{ TBasePKCS11Backend }

procedure TBasePKCS11Backend.ValidateConfig(const AConfig: TPKCS11Config);
begin
  if not AConfig.IsValid then
    raise EPKCS11Exception.Create('Invalid PKCS#11 configuration', CKR_ARGUMENTS_BAD);
  
  if AConfig.ModulePath = '' then
    raise EPKCS11Exception.Create('PKCS#11 module path not specified', CKR_ARGUMENTS_BAD);
  
  if not FileExists(AConfig.ModulePath) then
    raise EPKCS11Exception.Create('PKCS#11 module not found: ' + AConfig.ModulePath, CKR_GENERAL_ERROR);
  
  if (AConfig.TokenLabel = '') and (AConfig.SlotID < 0) then
    raise EPKCS11Exception.Create('Either token label or slot ID must be specified', CKR_ARGUMENTS_BAD);
  
  if (AConfig.KeyLabel = '') and (Length(AConfig.KeyID) = 0) then
    raise EPKCS11Exception.Create('Either key label or key ID must be specified', CKR_ARGUMENTS_BAD);
end;

function TBasePKCS11Backend.ResolvePIN(const AConfig: TPKCS11Config): string;
begin
  Result := AConfig.GetPIN;
  
  if (Result = '') and AConfig.LoginRequired then
    raise EPKCS11Exception.Create('PIN required but not provided', CKR_PIN_INCORRECT);
end;

initialization
  // Default to auto-detection (Provider preferred, ENGINE fallback)
  TPKCS11BackendFactory.FDefaultBackendType := btAuto;

end.

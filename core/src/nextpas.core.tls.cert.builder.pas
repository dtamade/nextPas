{
  nextpas.core.tls.cert.builder - Fluent Certificate Builder Interface
  
  Provides a modern, fluent API for certificate generation with:
  - Method chaining for readable code
  - Automatic resource management via interfaces
  - Type-safe configuration
  - Scenario-based convenience methods
}

unit nextpas.core.tls.cert.builder;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses nextpas.core.tls.base, nextpas.core.tls.safety; type ICertificate = interface;
  IPrivateKey = interface;
  IKeyPairWithCertificate = interface;
  ICertificateBuilder = interface;
  ICertificateEx = interface; // Added forward declaration
  IPrivateKeyEx = interface; // Added forward declaration

  {**
   * ICertificate - Certificate interface for builder-generated certificates
   *
   * This interface is specifically for certificates created by ICertificateBuilder.
   * It provides read-only access to certificate properties and export capabilities.
   *
   * @note This is DIFFERENT from ISSLCertificate in nextpas.core.tls.base:
   *   - ICertificate: Lightweight, for builder output, read-only
   *   - ISSLCertificate: Full-featured, for SSL operations (load, verify, chains)
   *
   * To convert ICertificate to ISSLCertificate, use:
   *   LSSLCert := TSSLFactory.CreateCertificate;
   *   LSSLCert.LoadFromPEM(LCert.ToPEM);
   *
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ICertificate = interface
    ['{A1B2C3D4-E5F6-4789-0123-456789ABCDEF}']
    
    // Basic information
    function GetSubject: string;
    function GetIssuer: string;
    function GetSerialNumber: string;
    function GetNotBefore: TDateTime;
    function GetNotAfter: TDateTime;
    
    // Extensions
    function GetSubjectAltNames: TStringArray;
    function IsCA: Boolean;
    
    // Validation
    function IsValidAt(ATime: TDateTime): Boolean;
    function IsExpired: Boolean;
    
    // Export
    function ToPEM: string;
    function ToDER: TBytes;
    procedure SaveToFile(const AFile: string);
    
    // Properties
    property Subject: string read GetSubject;
    property Issuer: string read GetIssuer;
    property SerialNumber: string read GetSerialNumber;
    property NotBefore: TDateTime read GetNotBefore;
    property NotAfter: TDateTime read GetNotAfter;
    property SubjectAltNames: TStringArray read GetSubjectAltNames; // Added property
  end;

  {**
   * ICertificateEx - Extended certificate interface with OpenSSL handle access
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ICertificateEx = interface(ICertificate)
    ['{B2C3D4E5-F607-4890-1234-567890ABCDEF}']
    
    function GetX509Handle: Pointer;  // Returns PX509
    property X509Handle: Pointer read GetX509Handle;
  end deprecated 'OpenSSL-only; use nextpas.core.tls.openssl.cert.builder';

  {**
   * IPrivateKey - Private key interface
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  IPrivateKey = interface
    ['{C3D4E5F6-0718-4901-2345-67890ABCDEF1}']
    
    function ToPEM: string;
    procedure SaveToFile(const AFile: string);
  end;

  {**
   * IPrivateKeyEx - Extended private key interface with OpenSSL handle access
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  IPrivateKeyEx = interface(IPrivateKey)
    ['{D4E5F607-1819-4012-3456-7890ABCDEF12}']
    
    function GetEVP_PKEYHandle: Pointer; // Returns PEVP_PKEY
    property EVP_PKEYHandle: Pointer read GetEVP_PKEYHandle;
  end deprecated 'OpenSSL-only; use nextpas.core.tls.openssl.cert.builder';

  {**
   * IKeyPairWithCertificate - Certificate + Private Key pair
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  IKeyPairWithCertificate = interface
    ['{C3D4E5F6-0708-4012-CDEF-123456789012}']
    
    function GetCertificate: ICertificate;
    function GetPrivateKey: IPrivateKey;
    
    // Quick save methods
    procedure SaveToFiles(const ACertFile, AKeyFile: string);
    procedure SaveToPEM(out ACertPEM, AKeyPEM: string);
    
    property Certificate: ICertificate read GetCertificate;
    property PrivateKey: IPrivateKey read GetPrivateKey;
  end;

  {**
   * ICertificateBuilder - Fluent certificate builder
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ICertificateBuilder = interface
    ['{D4E5F607-0809-4123-0234-567890123456}']
    
    // Subject configuration
    function WithCommonName(const AName: string): ICertificateBuilder;
    function WithOrganization(const AOrg: string): ICertificateBuilder;
    function WithOrganizationalUnit(const AOU: string): ICertificateBuilder;
    function WithCountry(const ACountry: string): ICertificateBuilder;
    function WithState(const AState: string): ICertificateBuilder;
    function WithLocality(const ALocality: string): ICertificateBuilder;
    
    // Validity period
    function ValidFor(ADays: Integer): ICertificateBuilder;
    function ValidFrom(AStart: TDateTime): ICertificateBuilder;
    function ValidUntil(AEnd: TDateTime): ICertificateBuilder;
    
    // Key configuration
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
    
    // Serial number
    function WithSerialNumber(ASerial: Int64): ICertificateBuilder;
    
    // Signing
    function SelfSigned: IKeyPairWithCertificate;
    function SignedBy(const ACA: ICertificate; const AKey: IPrivateKey): IKeyPairWithCertificate;
  end;

  { Factory class for creating builders }
  TCertificateBuilder = class
  public
    class function Create: ICertificateBuilder; static;
  end;

implementation

uses nextpas.core.tls.cert.builder.impl; class function TCertificateBuilder.Create: ICertificateBuilder;
begin
  Result := TCertificateBuilderImpl.Create;
end;

end.

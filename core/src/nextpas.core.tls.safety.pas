unit nextpas.core.tls.safety;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

{**
 * Unit: nextpas.core.tls.safety
 * Purpose: Type-safe enumerations, generics, and unit types for SSL/TLS operations
 *
 * Phase 2.4 - Type Safety Improvements
 *
 * Features:
 * - Strong enumerations replacing magic numbers
 * - Generic wrappers for type-safe APIs
 * - Unit types to prevent parameter confusion
 * - Rust-inspired type safety patterns
 *
 * @author fafafa.ssl team
 * @version 2.4.0
 * @since 2025-01-19
 *}

interface

uses
  SysUtils, Classes;

type
  { ==================== Enumerations (Phase 2.4.1) ==================== }

  {**
   * SSL/TLS Protocol Versions
   * Strong typing for protocol version selection
   *}
  TSSLVersion = (
    sslv_TLS10 = 10,      // TLS 1.0 (deprecated, insecure)
    sslv_TLS11 = 11,      // TLS 1.1 (deprecated)
    sslv_TLS12 = 12,      // TLS 1.2 (widely supported)
    sslv_TLS13 = 13       // TLS 1.3 (modern, recommended)
  );
  TSSLVersions = set of TSSLVersion;

  {**
   * Key Types for asymmetric cryptography
   *}
  TKeyType = (
    kt_RSA,               // RSA keys
    kt_EC,                // Elliptic Curve keys
    kt_DSA,               // DSA keys (legacy)
    kt_Ed25519,           // Ed25519 keys (modern)
    kt_Ed448,             // Ed448 keys
    kt_X25519,            // X25519 keys (ECDH)
    kt_X448               // X448 keys (ECDH)
  );

  {**
   * Certificate formats for import/export
   *}
  TCertificateFormat = (
    cf_PEM,               // PEM text format (Base64)
    cf_DER,               // DER binary format
    cf_PKCS12,            // PKCS#12 container (.p12, .pfx)
    cf_PKCS7              // PKCS#7 container
  );

  {**
   * Cipher modes for symmetric encryption
   *}
  TCipherMode = (
    cm_GCM,               // Galois/Counter Mode (AEAD)
    cm_CBC,               // Cipher Block Chaining
    cm_CTR,               // Counter mode
    cm_CCM,               // Counter with CBC-MAC (AEAD)
    cm_OCB                // Offset Codebook Mode (AEAD)
  );

  {**
   * Verification modes for certificate validation
   *}
  TVerificationMode = (
    vm_None,              // No verification (insecure, for testing only)
    vm_Peer,              // Verify peer certificate
    vm_FailIfNoPeerCert,  // Fail if no peer certificate provided
    vm_ClientOnce,        // Request client cert only once
    vm_PostHandshake      // TLS 1.3 post-handshake authentication
  );

  {**
   * Session cache modes
   *}
  TSessionCacheMode = (
    scm_Off,              // No session caching
    scm_Client,           // Client-side caching only
    scm_Server,           // Server-side caching only
    scm_Both              // Both client and server caching
  );

  {**
   * Certificate purpose/usage
   *}
  TCertificatePurpose = (
    cp_Any,               // Any purpose
    cp_ServerAuth,        // TLS server authentication
    cp_ClientAuth,        // TLS client authentication
    cp_CodeSigning,       // Code signing
    cp_EmailProtection,   // S/MIME email
    cp_TimeStamping,      // Timestamp signing
    cp_OCSPSigning        // OCSP response signing
  );

  {**
   * Signature algorithms
   *}
  TSignatureAlgorithm = (
    sa_RSA_PKCS1_SHA1,    // RSA with SHA-1 (legacy)
    sa_RSA_PKCS1_SHA256,  // RSA with SHA-256
    sa_RSA_PKCS1_SHA384,  // RSA with SHA-384
    sa_RSA_PKCS1_SHA512,  // RSA with SHA-512
    sa_RSA_PSS_SHA256,    // RSA-PSS with SHA-256
    sa_RSA_PSS_SHA384,    // RSA-PSS with SHA-384
    sa_RSA_PSS_SHA512,    // RSA-PSS with SHA-512
    sa_ECDSA_SHA256,      // ECDSA with SHA-256
    sa_ECDSA_SHA384,      // ECDSA with SHA-384
    sa_ECDSA_SHA512,      // ECDSA with SHA-512
    sa_Ed25519,           // Ed25519 signature
    sa_Ed448              // Ed448 signature
  );

  {**
   * Elliptic curve names
   *}
  TEllipticCurve = (
    ec_P256,              // NIST P-256 (secp256r1)
    ec_P384,              // NIST P-384 (secp384r1)
    ec_P521,              // NIST P-521 (secp521r1)
    ec_X25519,            // Curve25519 (ECDH)
    ec_X448,              // Curve448 (ECDH)
    ec_BrainpoolP256,     // Brainpool P-256
    ec_BrainpoolP384,     // Brainpool P-384
    ec_BrainpoolP512      // Brainpool P-512
  );

  { ==================== Unit Types (Phase 2.4.3) ==================== }

  {**
   * Type-safe key size representation
   * Prevents confusion between bits and bytes
   *}
  TKeySize = record
  private
    FBits: Integer;
  public
    class function Bits(ABits: Integer): TKeySize; static;
    class function Bytes(ABytes: Integer): TKeySize; static;

    function ToBits: Integer;
    function ToBytes: Integer;
    function IsValid: Boolean;
    function Compare(const AOther: TKeySize): Integer;
    function IsEqual(const AOther: TKeySize): Boolean;
  end;

  {**
   * Type-safe timeout duration
   * Explicit time units (milliseconds, seconds, minutes)
   *}
  TTimeoutDuration = record
  private
    FMilliseconds: Int64;
  public
    class function Milliseconds(AMS: Int64): TTimeoutDuration; static;
    class function Seconds(ASeconds: Int64): TTimeoutDuration; static;
    class function Minutes(AMinutes: Int64): TTimeoutDuration; static;
    class function Infinite: TTimeoutDuration; static;

    function ToMilliseconds: Int64;
    function ToSeconds: Double;
    function IsInfinite: Boolean;
    function Compare(const AOther: TTimeoutDuration): Integer;
    function IsEqual(const AOther: TTimeoutDuration): Boolean;
  end;

  {**
   * Type-safe buffer size
   * Prevents integer overflow and negative values
   *}
  TBufferSize = record
  private
    FBytes: NativeUInt;
  public
    class function Bytes(ABytes: NativeUInt): TBufferSize; static;
    class function KB(AKilobytes: NativeUInt): TBufferSize; static;
    class function MB(AMegabytes: NativeUInt): TBufferSize; static;

    function ToBytes: NativeUInt;
    function ToKB: NativeUInt;
    function ToMB: NativeUInt;
    function Compare(const AOther: TBufferSize): Integer;
    function IsEqual(const AOther: TBufferSize): Boolean;
  end;

  { ==================== Generic Wrappers (Phase 2.4.2) ==================== }

  {**
   * Generic secure data wrapper
   * Provides type-safe access with validity checking
   *
   * Inspired by Rust's Option<T> and Result<T, E>
   *}
  generic TSecureData<T> = record
  private
    FData: T;
    FValid: Boolean;
    FError: string;
  public
    class function Some(const AData: T): TSecureData; static;
    class function None(const AError: string = ''): TSecureData; static;

    function IsValid: Boolean;
    function IsSome: Boolean;
    function IsNone: Boolean;
    function Unwrap: T;
    function UnwrapOr(const ADefault: T): T;
    function ErrorMessage: string;
  end;

  {**
   * Result type for operations that can fail
   * Rust-inspired Result<T, E> pattern
   *}
  generic TResult<T, E> = record
  private
    FSuccess: Boolean;
    FValue: T;
    FError: E;
  public
    class function Ok(const AValue: T): TResult; static;
    class function Err(const AError: E): TResult; static;

    function IsOk: Boolean;
    function IsErr: Boolean;
    function Unwrap: T;
    function UnwrapErr: E;
    function UnwrapOr(const ADefault: T): T;
  end;

  { ==================== Helper Functions ==================== }

  {** Convert SSL version enum to string *}
  function SSLVersionToString(AVersion: TSSLVersion): string;

  {** Convert string to SSL version enum *}
  function StringToSSLVersion(const AStr: string): TSSLVersion;

  {** Convert key type enum to string *}
  function KeyTypeToString(AType: TKeyType): string;

  {** Convert certificate format enum to string *}
  function CertificateFormatToString(AFormat: TCertificateFormat): string;

  {** Convert cipher mode enum to string *}
  function CipherModeToString(AMode: TCipherMode): string;

  {** Convert elliptic curve enum to OpenSSL NID *}
  function EllipticCurveToNID(ACurve: TEllipticCurve): Integer;

  {** Convert elliptic curve enum to string *}
  function EllipticCurveToString(ACurve: TEllipticCurve): string;

implementation

{ TKeySize }

class function TKeySize.Bits(ABits: Integer): TKeySize;
begin
  if ABits <= 0 then
    raise Exception.Create('Key size must be positive');
  if (ABits mod 8) <> 0 then
    raise Exception.Create('Key size must be multiple of 8 bits');
  Result.FBits := ABits;
end;

class function TKeySize.Bytes(ABytes: Integer): TKeySize;
begin
  if ABytes <= 0 then
    raise Exception.Create('Key size must be positive');
  Result.FBits := ABytes * 8;
end;

function TKeySize.ToBits: Integer;
begin
  Result := FBits;
end;

function TKeySize.ToBytes: Integer;
begin
  Result := FBits div 8;
end;

function TKeySize.IsValid: Boolean;
begin
  Result := (FBits > 0) and ((FBits mod 8) = 0);
end;

function TKeySize.Compare(const AOther: TKeySize): Integer;
begin
  if FBits < AOther.FBits then
    Result := -1
  else if FBits > AOther.FBits then
    Result := 1
  else
    Result := 0;
end;

function TKeySize.IsEqual(const AOther: TKeySize): Boolean;
begin
  Result := FBits = AOther.FBits;
end;

{ TTimeoutDuration }

class function TTimeoutDuration.Milliseconds(AMS: Int64): TTimeoutDuration;
begin
  if AMS < 0 then
    raise Exception.Create('Timeout must be non-negative');
  Result.FMilliseconds := AMS;
end;

class function TTimeoutDuration.Seconds(ASeconds: Int64): TTimeoutDuration;
begin
  if ASeconds < 0 then
    raise Exception.Create('Timeout must be non-negative');
  Result.FMilliseconds := ASeconds * 1000;
end;

class function TTimeoutDuration.Minutes(AMinutes: Int64): TTimeoutDuration;
begin
  if AMinutes < 0 then
    raise Exception.Create('Timeout must be non-negative');
  Result.FMilliseconds := AMinutes * 60 * 1000;
end;

class function TTimeoutDuration.Infinite: TTimeoutDuration;
begin
  Result.FMilliseconds := -1;
end;

function TTimeoutDuration.ToMilliseconds: Int64;
begin
  Result := FMilliseconds;
end;

function TTimeoutDuration.ToSeconds: Double;
begin
  if FMilliseconds < 0 then
    Result := -1.0
  else
    Result := FMilliseconds / 1000.0;
end;

function TTimeoutDuration.IsInfinite: Boolean;
begin
  Result := FMilliseconds < 0;
end;

function TTimeoutDuration.Compare(const AOther: TTimeoutDuration): Integer;
begin
  if FMilliseconds < AOther.FMilliseconds then
    Result := -1
  else if FMilliseconds > AOther.FMilliseconds then
    Result := 1
  else
    Result := 0;
end;

function TTimeoutDuration.IsEqual(const AOther: TTimeoutDuration): Boolean;
begin
  Result := FMilliseconds = AOther.FMilliseconds;
end;

{ TBufferSize }

class function TBufferSize.Bytes(ABytes: NativeUInt): TBufferSize;
begin
  Result.FBytes := ABytes;
end;

class function TBufferSize.KB(AKilobytes: NativeUInt): TBufferSize;
begin
  Result.FBytes := AKilobytes * 1024;
end;

class function TBufferSize.MB(AMegabytes: NativeUInt): TBufferSize;
begin
  Result.FBytes := AMegabytes * 1024 * 1024;
end;

function TBufferSize.ToBytes: NativeUInt;
begin
  Result := FBytes;
end;

function TBufferSize.ToKB: NativeUInt;
begin
  Result := FBytes div 1024;
end;

function TBufferSize.ToMB: NativeUInt;
begin
  Result := FBytes div (1024 * 1024);
end;

function TBufferSize.Compare(const AOther: TBufferSize): Integer;
begin
  if FBytes < AOther.FBytes then
    Result := -1
  else if FBytes > AOther.FBytes then
    Result := 1
  else
    Result := 0;
end;

function TBufferSize.IsEqual(const AOther: TBufferSize): Boolean;
begin
  Result := FBytes = AOther.FBytes;
end;

{ TSecureData<T> }

class function TSecureData.Some(const AData: T): TSecureData;
begin
  Result.FData := AData;
  Result.FValid := True;
  Result.FError := '';
end;

class function TSecureData.None(const AError: string): TSecureData;
begin
  Result.FValid := False;
  Result.FError := AError;
end;

function TSecureData.IsValid: Boolean;
begin
  Result := FValid;
end;

function TSecureData.IsSome: Boolean;
begin
  Result := FValid;
end;

function TSecureData.IsNone: Boolean;
begin
  Result := not FValid;
end;

function TSecureData.Unwrap: T;
begin
  if not FValid then
    raise Exception.Create('Cannot unwrap None value: ' + FError);
  Result := FData;
end;

function TSecureData.UnwrapOr(const ADefault: T): T;
begin
  if FValid then
    Result := FData
  else
    Result := ADefault;
end;

function TSecureData.ErrorMessage: string;
begin
  Result := FError;
end;

{ TResult<T, E> }

class function TResult.Ok(const AValue: T): TResult;
begin
  Result.FSuccess := True;
  Result.FValue := AValue;
end;

class function TResult.Err(const AError: E): TResult;
begin
  Result.FSuccess := False;
  Result.FError := AError;
end;

function TResult.IsOk: Boolean;
begin
  Result := FSuccess;
end;

function TResult.IsErr: Boolean;
begin
  Result := not FSuccess;
end;

function TResult.Unwrap: T;
begin
  if not FSuccess then
    raise Exception.Create('Cannot unwrap Err value');
  Result := FValue;
end;

function TResult.UnwrapErr: E;
begin
  if FSuccess then
    raise Exception.Create('Cannot unwrap Ok value');
  Result := FError;
end;

function TResult.UnwrapOr(const ADefault: T): T;
begin
  if FSuccess then
    Result := FValue
  else
    Result := ADefault;
end;

{ Helper Functions }

{$WARN 6018 OFF}
function SSLVersionToString(AVersion: TSSLVersion): string;
begin
  case AVersion of
    sslv_TLS10: Result := 'TLS 1.0';
    sslv_TLS11: Result := 'TLS 1.1';
    sslv_TLS12: Result := 'TLS 1.2';
    sslv_TLS13: Result := 'TLS 1.3';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

function StringToSSLVersion(const AStr: string): TSSLVersion;
var
  LStr: string;
begin
  LStr := UpperCase(Trim(AStr));
  if (LStr = 'TLS1.0') or (LStr = 'TLSV10') or (LStr = 'TLS 1.0') then
    Result := sslv_TLS10
  else if (LStr = 'TLS1.1') or (LStr = 'TLSV11') or (LStr = 'TLS 1.1') then
    Result := sslv_TLS11
  else if (LStr = 'TLS1.2') or (LStr = 'TLSV12') or (LStr = 'TLS 1.2') then
    Result := sslv_TLS12
  else if (LStr = 'TLS1.3') or (LStr = 'TLSV13') or (LStr = 'TLS 1.3') then
    Result := sslv_TLS13
  else
    raise Exception.CreateFmt('Unknown SSL version: %s', [AStr]);
end;

{$WARN 6018 OFF}
function KeyTypeToString(AType: TKeyType): string;
begin
  case AType of
    kt_RSA: Result := 'RSA';
    kt_EC: Result := 'EC';
    kt_DSA: Result := 'DSA';
    kt_Ed25519: Result := 'Ed25519';
    kt_Ed448: Result := 'Ed448';
    kt_X25519: Result := 'X25519';
    kt_X448: Result := 'X448';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

{$WARN 6018 OFF}
function CertificateFormatToString(AFormat: TCertificateFormat): string;
begin
  case AFormat of
    cf_PEM: Result := 'PEM';
    cf_DER: Result := 'DER';
    cf_PKCS12: Result := 'PKCS12';
    cf_PKCS7: Result := 'PKCS7';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

{$WARN 6018 OFF}
function CipherModeToString(AMode: TCipherMode): string;
begin
  case AMode of
    cm_GCM: Result := 'GCM';
    cm_CBC: Result := 'CBC';
    cm_CTR: Result := 'CTR';
    cm_CCM: Result := 'CCM';
    cm_OCB: Result := 'OCB';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

{$WARN 6018 OFF}
function EllipticCurveToNID(ACurve: TEllipticCurve): Integer;
begin
  case ACurve of
    ec_P256: Result := 415;  // NID_X9_62_prime256v1
    ec_P384: Result := 715;  // NID_secp384r1
    ec_P521: Result := 716;  // NID_secp521r1
    ec_X25519: Result := 1034; // NID_X25519
    ec_X448: Result := 1035;   // NID_X448
    ec_BrainpoolP256: Result := 927; // NID_brainpoolP256r1
    ec_BrainpoolP384: Result := 931; // NID_brainpoolP384r1
    ec_BrainpoolP512: Result := 933; // NID_brainpoolP512r1
  else
    Result := 0;
  end;
end;
{$WARN 6018 ON}

{$WARN 6018 OFF}
function EllipticCurveToString(ACurve: TEllipticCurve): string;
begin
  case ACurve of
    ec_P256: Result := 'P-256';
    ec_P384: Result := 'P-384';
    ec_P521: Result := 'P-521';
    ec_X25519: Result := 'X25519';
    ec_X448: Result := 'X448';
    ec_BrainpoolP256: Result := 'Brainpool P-256';
    ec_BrainpoolP384: Result := 'Brainpool P-384';
    ec_BrainpoolP512: Result := 'Brainpool P-512';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

end.

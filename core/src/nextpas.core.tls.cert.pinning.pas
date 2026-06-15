{**
 * nextpas.core.tls.cert.pinning - Certificate Pinning Implementation
 *
 * Implements OWASP-compliant certificate pinning for enhanced security.
 * Supports both certificate pinning and public key pinning (SPKI).
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-31
 *
 * References:
 * - OWASP Certificate Pinning Cheat Sheet
 * - RFC 7469 (Public Key Pinning Extension for HTTP) - Note: HPKP deprecated
 * - Application-level pinning for native clients
 *
 * Security Best Practices:
 * - Use public key pinning (not certificate pinning) for operational flexibility
 * - Always include minimum 2 pins (primary + backup)
 * - Pin intermediate CA as backup
 * - Validate pins AFTER standard X.509 validation
 * - Use SHA-256 for hashing
 * - Store pins in compiled code (not config files)
 *}
unit nextpas.core.tls.cert.pinning;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.errors, nextpas.core.tls.exceptions, nextpas.core.tls.logging;

type
  {**
   * Pin type - certificate vs public key pinning
   *
   * OWASP Recommendation: Use ptPublicKey for better operational flexibility
   *}
  TPinType = (
    ptCertificate,  // Pin entire X.509 certificate (must update on renewal)
    ptPublicKey     // Pin Subject Public Key Info (SPKI) - survives renewal
  );

  {**
   * Certificate pin record
   *
   * Stores a single pin with metadata for validation and management
   *}
  TCertificatePin = record
    PinType: TPinType;                    // Certificate or public key pin
    Hash: array[0..31] of Byte;           // SHA-256 hash (32 bytes)
    Description: string;                  // Human-readable description
    IsBackup: Boolean;                    // Whether this is a backup pin
    AddedDate: TDateTime;                 // When pin was added
    ExpiryDate: TDateTime;                // Optional: when to stop trusting (0 = never)

    {** Create pin from Base64-encoded hash *}
    class function FromBase64(const ABase64Hash: string; AType: TPinType;
      const ADescription: string; AIsBackup: Boolean = False): TCertificatePin; static;

    {** Get Base64-encoded hash for display *}
    function ToBase64: string;

    {** Check if pin is currently valid (not expired) *}
    function IsValid: Boolean;
  end;

  {**
   * Certificate pin validator
   *
   * Validates certificates against a set of pinned hashes.
   * Implements OWASP best practices for certificate pinning.
   *}
  TPinValidator = class
  private
    FPins: array of TCertificatePin;
    FRequireValidPin: Boolean;
    FMinimumPins: Integer;

    {** Extract SHA-256 hash of entire certificate *}
    function ExtractCertificateHash(ACert: PX509): TBytes;

    {** Extract SHA-256 hash of public key (SPKI) *}
    function ExtractPublicKeyHash(ACert: PX509): TBytes;

    {** Compare two byte arrays in constant time (timing attack prevention) *}
    function ConstantTimeCompare(const A, B: array of Byte): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    {**
     * Add a pin to the validator
     *
     * @param AHash Raw SHA-256 hash bytes (32 bytes)
     * @param AType Pin type (certificate or public key)
     * @param ADescription Human-readable description
     * @param AIsBackup Whether this is a backup pin
     *}
    procedure AddPin(const AHash: TBytes; AType: TPinType;
      const ADescription: string; AIsBackup: Boolean = False);

    {**
     * Add a pin from Base64-encoded hash
     *
     * @param ABase64Hash Base64-encoded SHA-256 hash
     * @param AType Pin type (certificate or public key)
     * @param ADescription Human-readable description
     * @param AIsBackup Whether this is a backup pin
     *}
    procedure AddPinBase64(const ABase64Hash: string; AType: TPinType;
      const ADescription: string; AIsBackup: Boolean = False);

    {**
     * Validate certificate against pinned hashes
     *
     * @param ACert X.509 certificate to validate
     * @returns True if certificate matches any pin, False otherwise
     *
     * Note: This should be called AFTER standard X.509 validation
     *}
    function ValidateCertificate(ACert: PX509): Boolean;

    {**
     * Validate certificate chain against pinned hashes
     *
     * Checks if ANY certificate in the chain matches a pin.
     * This allows pinning intermediate or root CAs.
     *
     * @param AChain Certificate chain (array of X.509 certificates)
     * @returns True if any certificate in chain matches a pin
     *}
    function ValidateCertificateChain(const AChain: array of PX509): Boolean;

    {**
     * Get count of valid (non-expired) pins
     *}
    function GetValidPinCount: Integer;

    {**
     * Check if validator configuration is secure
     *
     * OWASP requires minimum 2 pins (primary + backup)
     *}
    function IsSecureConfiguration: Boolean;

    {**
     * Clear all pins
     *}
    procedure ClearPins;

    {**
     * Get pin information for logging/debugging
     *}
    function GetPinInfo: string;

    {**
     * Whether to require a valid pin match
     *
     * If True: Certificate MUST match a pin to be accepted
     * If False: Pinning is advisory only (logs but doesn't reject)
     *
     * Default: True (enforce pinning)
     *}
    property RequireValidPin: Boolean read FRequireValidPin write FRequireValidPin;

    {**
     * Minimum number of pins required for secure configuration
     *
     * OWASP recommends minimum 2 pins (primary + backup)
     * Default: 2
     *}
    property MinimumPins: Integer read FMinimumPins write FMinimumPins;
  end;

  {**
   * Pin validation result
   *
   * Detailed result of pin validation for logging and debugging
   *}
  TPinValidationResult = record
    Success: Boolean;
    MatchedPinIndex: Integer;  // Index of matched pin (-1 if no match)
    MatchedPinDescription: string;
    CertificateFingerprint: string;  // SHA-256 fingerprint of certificate
    PublicKeyFingerprint: string;    // SHA-256 fingerprint of public key
    ErrorMessage: string;
  end;

  {**
   * Extended pin validator with detailed results
   *}
  TPinValidatorEx = class(TPinValidator)
  public
    {**
     * Validate certificate with detailed result
     *
     * @param ACert X.509 certificate to validate
     * @param AResult Detailed validation result
     * @returns True if certificate matches any pin
     *}
    function ValidateCertificateEx(ACert: PX509;
      out AResult: TPinValidationResult): Boolean;
  end;

implementation

uses
  nextpas.core.encoding.base64,
  nextpas.core.tls.utils,
  nextpas.core.tls.encoding;

{ TCertificatePin }

class function TCertificatePin.FromBase64(const ABase64Hash: string;
  AType: TPinType; const ADescription: string; AIsBackup: Boolean): TCertificatePin;
var
  DecodedBytes: TBytes;
begin
  Result.PinType := AType;
  Result.Description := ADescription;
  Result.IsBackup := AIsBackup;
  Result.AddedDate := Now;
  Result.ExpiryDate := 0;  // Never expires by default

  DecodedBytes := nextpas.core.encoding.base64.Base64Decode(ABase64Hash);
  if Length(DecodedBytes) <> SizeOf(Result.Hash) then
    raise ESSLInvalidArgument.Create(
      nextpas.core.text.conv.Format('Pin hash must decode to %d bytes, got %d',
        [SizeOf(Result.Hash), Length(DecodedBytes)])
    );

  Move(DecodedBytes[0], Result.Hash[0], SizeOf(Result.Hash));
end;

function TCertificatePin.ToBase64: string;
var
  LBytes: TBytes;
begin
  SetLength(LBytes, SizeOf(Hash));
  Move(Hash[0], LBytes[0], SizeOf(Hash));
  Result := nextpas.core.encoding.base64.Base64Encode(LBytes);
end;

function TCertificatePin.IsValid: Boolean;
begin
  Result := (ExpiryDate = 0) or (Now < ExpiryDate);
end;

{ TPinValidator }

constructor TPinValidator.Create;
begin
  inherited Create;
  SetLength(FPins, 0);
  FRequireValidPin := True;  // Enforce pinning by default
  FMinimumPins := 2;         // OWASP recommendation
end;

destructor TPinValidator.Destroy;
begin
  SetLength(FPins, 0);
  inherited Destroy;
end;

function TPinValidator.ExtractCertificateHash(ACert: PX509): TBytes;
var
  Digest: array[0..EVP_MAX_MD_SIZE-1] of Byte;
  DigestLen: Cardinal;
begin
  if ACert = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  if X509_digest(ACert, EVP_sha256(), @Digest[0], @DigestLen) <> 1 then
  begin
    TSecurityLog.Error('CertPinning', 'Failed to compute certificate digest');
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, DigestLen);
  Move(Digest[0], Result[0], DigestLen);
end;

function TPinValidator.ExtractPublicKeyHash(ACert: PX509): TBytes;
var
  PubKey: PEVP_PKEY;
  SPKIData: TBytes;
  Digest: array[0..31] of Byte;
  Ctx: PEVP_MD_CTX;
  SPKILen: Integer;
  P: PByte;
  DigestLen: Cardinal;
begin
  SetLength(Result, 0);

  if ACert = nil then
    Exit;

  // Extract public key
  PubKey := X509_get_pubkey(ACert);
  if PubKey = nil then
  begin
    TSecurityLog.Error('CertPinning', 'Failed to extract public key');
    Exit;
  end;

  try
    // Encode SPKI to DER format directly; no BIO buffering is required here.
    SPKILen := i2d_PUBKEY(PubKey, nil);
    if SPKILen <= 0 then
    begin
      TSecurityLog.Error('CertPinning', 'Failed to get public key length');
      Exit;
    end;

    SetLength(SPKIData, SPKILen);
    P := @SPKIData[0];
    if i2d_PUBKEY(PubKey, @P) <= 0 then
    begin
      TSecurityLog.Error('CertPinning', 'Failed to encode public key');
      Exit;
    end;

    // Hash the SPKI
    Ctx := EVP_MD_CTX_new();
    if Ctx = nil then
    begin
      TSecurityLog.Error('CertPinning', 'Failed to create digest context');
      Exit;
    end;

    try
      if EVP_DigestInit_ex(Ctx, EVP_sha256(), nil) <= 0 then
      begin
        TSecurityLog.Error('CertPinning', 'Failed to initialize digest');
        Exit;
      end;

      if EVP_DigestUpdate(Ctx, @SPKIData[0], Length(SPKIData)) <= 0 then
      begin
        TSecurityLog.Error('CertPinning', 'Failed to update digest');
        Exit;
      end;

      DigestLen := 32;
      if EVP_DigestFinal_ex(Ctx, @Digest[0], DigestLen) <= 0 then
      begin
        TSecurityLog.Error('CertPinning', 'Failed to finalize digest');
        Exit;
      end;

      SetLength(Result, 32);
      Move(Digest[0], Result[0], 32);
    finally
      EVP_MD_CTX_free(Ctx);
    end;
  finally
    EVP_PKEY_free(PubKey);
  end;
end;

function TPinValidator.ConstantTimeCompare(const A, B: array of Byte): Boolean;
var
  i: Integer;
  Diff: Byte;
begin
  // Constant-time comparison to prevent timing attacks
  Diff := 0;

  if Length(A) <> Length(B) then
  begin
    Result := False;
    Exit;
  end;

  for i := 0 to High(A) do
    Diff := Diff or (A[i] xor B[i]);

  Result := (Diff = 0);
end;

procedure TPinValidator.AddPin(const AHash: TBytes; AType: TPinType;
  const ADescription: string; AIsBackup: Boolean);
var
  Pin: TCertificatePin;
  PinTypeStr, BackupStr: string;
begin
  if Length(AHash) <> 32 then
    raise ESSLException.CreateWithContext(
      'Invalid pin hash length (expected 32 bytes for SHA-256)',
      sslErrInvalidParam,
      'TPinValidator.AddPin'
    );

  Pin.PinType := AType;
  Move(AHash[0], Pin.Hash[0], 32);
  Pin.Description := ADescription;
  Pin.IsBackup := AIsBackup;
  Pin.AddedDate := Now;
  Pin.ExpiryDate := 0;

  SetLength(FPins, Length(FPins) + 1);
  FPins[High(FPins)] := Pin;

  if AType = ptPublicKey then
    PinTypeStr := 'public key'
  else
    PinTypeStr := 'certificate';
  
  if AIsBackup then
    BackupStr := 'yes'
  else
    BackupStr := 'no';
  
  TSecurityLog.Info('CertPinning',
    nextpas.core.text.conv.Format('Added %s pin: %s (backup: %s)',
      [PinTypeStr, ADescription, BackupStr]));
end;

procedure TPinValidator.AddPinBase64(const ABase64Hash: string; AType: TPinType;
  const ADescription: string; AIsBackup: Boolean);
var
  HashBytes: TBytes;
begin
  SetLength(HashBytes, 32);
  with TCertificatePin.FromBase64(ABase64Hash, AType, ADescription, AIsBackup) do
    Move(Hash[0], HashBytes[0], 32);
  AddPin(HashBytes, AType, ADescription, AIsBackup);
end;

function TPinValidator.ValidateCertificate(ACert: PX509): Boolean;
var
  CertHash, PubKeyHash: TBytes;
  Pin: TCertificatePin;
  i: Integer;
begin
  Result := False;

  if ACert = nil then
  begin
    TSecurityLog.Error('CertPinning', 'Certificate is nil');
    Exit;
  end;

  if Length(FPins) = 0 then
  begin
    Result := not FRequireValidPin;
    if not Result then
      TSecurityLog.Warning('CertPinning', 'No pins configured but pinning is required');
    Exit;
  end;

  // Extract hashes
  CertHash := ExtractCertificateHash(ACert);
  PubKeyHash := ExtractPublicKeyHash(ACert);

  if (Length(CertHash) = 0) and (Length(PubKeyHash) = 0) then
  begin
    TSecurityLog.Error('CertPinning', 'Failed to extract certificate hashes');
    Exit;
  end;

  // Check against all pins
  for i := 0 to High(FPins) do
  begin
    Pin := FPins[i];

    // Skip expired pins
    if not Pin.IsValid then
      Continue;

    case Pin.PinType of
      ptCertificate:
        if (Length(CertHash) > 0) and (Length(CertHash) = 32) and
          ConstantTimeCompare(CertHash, Slice(Pin.Hash, 32)) then
        begin
          TSecurityLog.Info('CertPinning',
            nextpas.core.text.conv.Format('Certificate matched pin: %s', [Pin.Description]));
          Result := True;
          Exit;
        end;

      ptPublicKey:
        if (Length(PubKeyHash) > 0) and (Length(PubKeyHash) = 32) and
          ConstantTimeCompare(PubKeyHash, Slice(Pin.Hash, 32)) then
        begin
          TSecurityLog.Info('CertPinning',
            nextpas.core.text.conv.Format('Public key matched pin: %s', [Pin.Description]));
          Result := True;
          Exit;
        end;
    end;
  end;

  // No match found
  TSecurityLog.Warning('CertPinning',
    'Certificate does not match any configured pins');
end;

function TPinValidator.ValidateCertificateChain(const AChain: array of PX509): Boolean;
var
  i: Integer;
begin
  Result := False;

  if Length(AChain) = 0 then
  begin
    TSecurityLog.Warning('CertPinning', 'Empty certificate chain');
    Exit;
  end;

  // Check each certificate in the chain
  for i := 0 to High(AChain) do
  begin
    if ValidateCertificate(AChain[i]) then
    begin
      Result := True;
      Exit;
    end;
  end;

  TSecurityLog.Warning('CertPinning',
    nextpas.core.text.conv.Format('No certificate in chain (length %d) matched any pin', [Length(AChain)]));
end;

function TPinValidator.GetValidPinCount: Integer;
var
  Pin: TCertificatePin;
begin
  Result := 0;
  for Pin in FPins do
    if Pin.IsValid then
      Inc(Result);
end;

function TPinValidator.IsSecureConfiguration: Boolean;
begin
  Result := GetValidPinCount >= FMinimumPins;

  if not Result then
    TSecurityLog.Warning('CertPinning',
      nextpas.core.text.conv.Format('Insecure pin configuration: %d valid pins (minimum: %d)',
        [GetValidPinCount, FMinimumPins]));
end;

procedure TPinValidator.ClearPins;
begin
  SetLength(FPins, 0);
  TSecurityLog.Info('CertPinning', 'Cleared all pins');
end;

function TPinValidator.GetPinInfo: string;
var
  i: Integer;
  Pin: TCertificatePin;
  PinTypeStr, BackupStr, ValidStr: string;
begin
  Result := nextpas.core.text.conv.Format('Pin Validator: %d pins configured, %d valid' + LineEnding,
    [Length(FPins), GetValidPinCount]);

  for i := 0 to High(FPins) do
  begin
    Pin := FPins[i];
    
    if Pin.PinType = ptPublicKey then
      PinTypeStr := 'public key'
    else
      PinTypeStr := 'certificate';
    
    if Pin.IsBackup then
      BackupStr := 'yes'
    else
      BackupStr := 'no';
    
    if Pin.IsValid then
      ValidStr := 'yes'
    else
      ValidStr := 'no';
    
    Result := Result + nextpas.core.text.conv.Format('  [%d] %s: %s (type: %s, backup: %s, valid: %s)' + LineEnding,
      [i, Pin.Description, Pin.ToBase64, PinTypeStr, BackupStr, ValidStr]);
  end;
end;

{ TPinValidatorEx }

function TPinValidatorEx.ValidateCertificateEx(ACert: PX509;
  out AResult: TPinValidationResult): Boolean;
var
  CertHash, PubKeyHash: TBytes;
  Pin: TCertificatePin;
  i: Integer;
begin
  FillChar(AResult, SizeOf(AResult), 0);
  AResult.MatchedPinIndex := -1;
  Result := False;

  if ACert = nil then
  begin
    AResult.ErrorMessage := 'Certificate is nil';
    Exit;
  end;

  // Extract hashes
  CertHash := ExtractCertificateHash(ACert);
  PubKeyHash := ExtractPublicKeyHash(ACert);

  if Length(CertHash) > 0 then
    AResult.CertificateFingerprint := TEncodingUtils.BytesToHex(CertHash, True);
  if Length(PubKeyHash) > 0 then
    AResult.PublicKeyFingerprint := TEncodingUtils.BytesToHex(PubKeyHash, True);

  if (Length(CertHash) = 0) and (Length(PubKeyHash) = 0) then
  begin
    AResult.ErrorMessage := 'Failed to extract certificate hashes';
    Exit;
  end;

  if Length(FPins) = 0 then
  begin
    AResult.ErrorMessage := 'No pins configured';
    Result := not FRequireValidPin;
    AResult.Success := Result;
    Exit;
  end;

  // Check against all pins
  for i := 0 to High(FPins) do
  begin
    Pin := FPins[i];

    if not Pin.IsValid then
      Continue;

    case Pin.PinType of
      ptCertificate:
        if (Length(CertHash) > 0) and (Length(CertHash) = 32) and
          ConstantTimeCompare(CertHash, Slice(Pin.Hash, 32)) then
        begin
          AResult.Success := True;
          AResult.MatchedPinIndex := i;
          AResult.MatchedPinDescription := Pin.Description;
          Result := True;
          Exit;
        end;

      ptPublicKey:
        if (Length(PubKeyHash) > 0) and (Length(PubKeyHash) = 32) and
          ConstantTimeCompare(PubKeyHash, Slice(Pin.Hash, 32)) then
        begin
          AResult.Success := True;
          AResult.MatchedPinIndex := i;
          AResult.MatchedPinDescription := Pin.Description;
          Result := True;
          Exit;
        end;
    end;
  end;

  AResult.ErrorMessage := 'Certificate does not match any configured pins';
end;

end.

unit nextpas.core.tls.pkcs11.types;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized
{$modeswitch advancedrecords}

{******************************************************************************}
{                                                                              }
{  fafafa.ssl - PKCS#11 Type Definitions                                      }
{                                                                              }
{  Purpose: High-level type definitions for PKCS#11 integration               }
{                                                                              }
{  Architecture:                                                               }
{    - TPKCS11URI: RFC 7512 URI representation                                }
{    - TPKCS11Config: Configuration for PKCS#11 operations                    }
{    - TPKCS11KeyInfo: Key metadata from tokens                               }
{    - TPKCS11TokenInfo: Token information                                    }
{                                                                              }
{******************************************************************************}

interface

uses
  SysUtils, Classes, Generics.Collections,
  nextpas.core.tls.pkcs11.api;

type
  { TPKCS11URI - RFC 7512 PKCS#11 URI representation
    
    Format: pkcs11:token=MyToken;object=MyKey?pin-value=1234
    
    Path attributes (identify the object):
      - token: Token label
      - manufacturer: Token manufacturer
      - serial: Token serial number
      - model: Token model
      - library-manufacturer: Library manufacturer
      - library-description: Library description
      - library-version: Library version
      - object: Object label
      - type: Object type (public, private, cert, secret-key, data)
      - id: Object ID (hex-encoded)
      - slot-manufacturer: Slot manufacturer
      - slot-description: Slot description
      - slot-id: Slot ID
    
    Query attributes (provide additional info):
      - pin-value: PIN value (INSECURE - avoid in production)
      - pin-source: PIN source (file:, env:, etc.)
      - module-name: PKCS#11 module name
      - module-path: PKCS#11 module path
  }
  TPKCS11URI = record
    // Path attributes (RFC 7512 Section 2.3)
    Token: string;              // Token label
    Manufacturer: string;       // Token manufacturer
    Serial: string;             // Token serial number
    Model: string;              // Token model
    LibraryManufacturer: string;
    LibraryDescription: string;
    LibraryVersion: string;
    ObjectLabel: string;        // Object label (key/cert name)
    ObjectType: string;         // public, private, cert, secret-key, data
    ObjectID: string;           // Hex-encoded object ID
    SlotManufacturer: string;
    SlotDescription: string;
    SlotID: string;             // Slot ID (decimal)
    
    // Query attributes (RFC 7512 Section 2.4)
    PINValue: string;           // PIN value (INSECURE - use PINSource instead)
    PINSource: string;          // PIN source (file:, env:, etc.)
    ModuleName: string;         // PKCS#11 module name
    ModulePath: string;         // PKCS#11 module path
    
    // Helper methods
    function ToString: string;
    function IsValid: Boolean;
    function HasPIN: Boolean;
    function GetPIN: string;
  end;

  { TPKCS11PINMethod - PIN acquisition methods }
  TPKCS11PINMethod = (
    pmNone,           // No PIN required
    pmValue,          // PIN provided directly (INSECURE)
    pmEnvironment,    // PIN from environment variable
    pmFile,           // PIN from file
    pmCallback,       // PIN from callback function
    pmInteractive     // PIN from user prompt
  );

  { TPKCS11PINCallback - Callback function for PIN acquisition }
  TPKCS11PINCallback = function(const ATokenLabel: string; out APIN: string): Boolean of object;

  { TPKCS11Config - Configuration for PKCS#11 operations }
  TPKCS11Config = record
    // Module configuration
    ModulePath: string;         // Path to PKCS#11 library (.so, .dll, .dylib)
    ModuleName: string;         // Module name (for lookup)
    
    // Token/Slot selection
    TokenLabel: string;         // Token label to use
    SlotID: Integer;            // Slot ID (-1 = auto-detect)
    
    // Key selection
    KeyLabel: string;           // Key label
    KeyID: TBytes;              // Key ID (CKA_ID attribute)
    
    // PIN configuration
    PINMethod: TPKCS11PINMethod;
    PINValue: string;           // Direct PIN value (INSECURE)
    PINEnvVar: string;          // Environment variable name
    PINFile: string;            // Path to PIN file
    PINCallback: TPKCS11PINCallback;
    
    // Session configuration
    ReadOnly: Boolean;          // Open read-only session
    LoginRequired: Boolean;     // Require login
    
    // Helper methods
    function IsValid: Boolean;
    function GetPIN: string;    // Resolve PIN based on PINMethod
  end;

  { TPKCS11KeyType - Key types }
  TPKCS11KeyType = (
    ktUnknown,
    ktRSA,
    ktDSA,
    ktDH,
    ktEC,
    ktAES
  );

  { TPKCS11KeyInfo - Key metadata from token }
  TPKCS11KeyInfo = record
    Handle: CK_OBJECT_HANDLE;   // Object handle
    KeyType: TPKCS11KeyType;    // Key type
    KeyLabel: string;           // Key label (CKA_LABEL)
    KeyID: TBytes;              // Key ID (CKA_ID)
    KeySize: Integer;           // Key size in bits
    CanSign: Boolean;           // CKA_SIGN
    CanDecrypt: Boolean;        // CKA_DECRYPT
    IsPrivate: Boolean;         // CKA_PRIVATE
    IsSensitive: Boolean;       // CKA_SENSITIVE
    IsExtractable: Boolean;     // CKA_EXTRACTABLE
    
    // Helper methods
    function ToString: string;
  end;

  { TPKCS11TokenInfo - Token information }
  TPKCS11TokenInfo = record
    SlotID: CK_SLOT_ID;
    TokenLabel: string;         // Token label (32 chars, space-padded)
    Manufacturer: string;       // Manufacturer ID (32 chars)
    Model: string;              // Model (16 chars)
    SerialNumber: string;       // Serial number (16 chars)
    Flags: CK_FLAGS;
    MaxSessionCount: Cardinal;
    SessionCount: Cardinal;
    MaxRwSessionCount: Cardinal;
    RwSessionCount: Cardinal;
    MaxPinLen: Cardinal;
    MinPinLen: Cardinal;
    HardwareVersion: string;    // Major.Minor
    FirmwareVersion: string;    // Major.Minor
    
    // Flag helpers
    function HasRNG: Boolean;
    function IsWriteProtected: Boolean;
    function RequiresLogin: Boolean;
    function IsPINInitialized: Boolean;
    function IsInitialized: Boolean;
    
    // Helper methods
    class function FromCK(const AInfo: CK_TOKEN_INFO; ASlotID: CK_SLOT_ID): TPKCS11TokenInfo; static;
    function ToString: string;
  end;

  { TPKCS11SlotInfo - Slot information }
  TPKCS11SlotInfo = record
    SlotID: CK_SLOT_ID;
    Description: string;        // Slot description (64 chars)
    Manufacturer: string;       // Manufacturer ID (32 chars)
    Flags: CK_FLAGS;
    HardwareVersion: string;    // Major.Minor
    FirmwareVersion: string;    // Major.Minor
    
    // Flag helpers
    function IsTokenPresent: Boolean;
    function IsRemovableDevice: Boolean;
    function IsHardwareSlot: Boolean;
    
    // Helper methods
    class function FromCK(const AInfo: CK_SLOT_INFO; ASlotID: CK_SLOT_ID): TPKCS11SlotInfo; static;
    function ToString: string;
  end;

  { TPKCS11Exception - PKCS#11 specific exception }
  EPKCS11Exception = class(Exception)
  private
    FReturnValue: CK_RV;
  public
    constructor Create(const AMessage: string; AReturnValue: CK_RV);
    property ReturnValue: CK_RV read FReturnValue;
  end;

  { Helper functions }
  function PKCS11KeyTypeToString(AKeyType: TPKCS11KeyType): string;
  function PKCS11KeyTypeFromCK(ACKKeyType: CK_ULONG): TPKCS11KeyType;
  function PKCS11ReturnValueToString(ARV: CK_RV): string;
  function TrimPKCS11String(const AStr: array of AnsiChar): string;
  
  { TPKCS11Config helper functions }
  function TPKCS11ConfigDefault: TPKCS11Config;
  function TPKCS11ConfigFromURI(const AURI: TPKCS11URI): TPKCS11Config;

implementation

uses
  StrUtils;

function HexCharToNibble(AChar: Char; out ANibble: Byte): Boolean;
begin
  case AChar of
    '0'..'9':
      begin
        ANibble := Ord(AChar) - Ord('0');
        Result := True;
      end;
    'a'..'f':
      begin
        ANibble := Ord(AChar) - Ord('a') + 10;
        Result := True;
      end;
    'A'..'F':
      begin
        ANibble := Ord(AChar) - Ord('A') + 10;
        Result := True;
      end;
  else
    ANibble := 0;
    Result := False;
  end;
end;

function HexToBytesStrict(const AHex: string): TBytes;
var
  I, LIndex: Integer;
  LNibbleHigh, LNibbleLow: Byte;
  LNormalized: string;
begin
  LNormalized := '';
  for I := 1 to Length(AHex) do
  begin
    case AHex[I] of
      '0'..'9', 'a'..'f', 'A'..'F':
        LNormalized := LNormalized + AHex[I];
      ':', '-', ' ', #9:
        ;
    else
      raise EPKCS11Exception.Create('Invalid PKCS#11 object id hex character: ' + AHex[I], CKR_ARGUMENTS_BAD);
    end;
  end;

  if LNormalized = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  if (Length(LNormalized) mod 2) <> 0 then
    raise EPKCS11Exception.Create('Invalid PKCS#11 object id hex length', CKR_ARGUMENTS_BAD);

  SetLength(Result, Length(LNormalized) div 2);
  LIndex := 0;
  I := 1;
  while I <= Length(LNormalized) do
  begin
    if (not HexCharToNibble(LNormalized[I], LNibbleHigh)) or
      (not HexCharToNibble(LNormalized[I + 1], LNibbleLow)) then
      raise EPKCS11Exception.Create('Invalid PKCS#11 object id hex encoding', CKR_ARGUMENTS_BAD);

    Result[LIndex] := (LNibbleHigh shl 4) or LNibbleLow;
    Inc(LIndex);
    Inc(I, 2);
  end;
end;

function ReadPINFromFileStrict(const AFilePath: string): string;
var
  F: TextFile;
  LLine: string;
begin
  if AFilePath = '' then
    raise EPKCS11Exception.Create('PIN file path is empty', CKR_ARGUMENTS_BAD);

  if not FileExists(AFilePath) then
    raise EPKCS11Exception.Create('PIN file not found: ' + AFilePath, CKR_GENERAL_ERROR);

  AssignFile(F, AFilePath);
  Reset(F);
  try
    if not Eof(F) then
    begin
      ReadLn(F, LLine);
      Result := Trim(LLine);
    end
    else
      Result := '';
  finally
    CloseFile(F);
  end;

  if Result = '' then
    raise EPKCS11Exception.Create('PIN file is empty: ' + AFilePath, CKR_PIN_INVALID);
end;

function ResolvePINSource(const APINSource: string): string;
var
  LVarName: string;
begin
  if StartsStr('env:', APINSource) then
  begin
    LVarName := Copy(APINSource, 5, MaxInt);
    if LVarName = '' then
      raise EPKCS11Exception.Create('PIN source env variable name is empty', CKR_ARGUMENTS_BAD);

    Result := GetEnvironmentVariable(LVarName);
    if Result = '' then
      raise EPKCS11Exception.Create('PIN source environment variable not set or empty: ' + LVarName, CKR_PIN_INVALID);
    Exit;
  end;

  if StartsStr('file:', APINSource) then
  begin
    Result := ReadPINFromFileStrict(Copy(APINSource, 6, MaxInt));
    Exit;
  end;

  raise EPKCS11Exception.Create('Unsupported PKCS#11 PIN source: ' + APINSource, CKR_ARGUMENTS_BAD);
end;

{ TPKCS11URI }

function TPKCS11URI.ToString: string;
begin
  // Will be implemented in nextpas.core.tls.pkcs11.uri.pas
  Result := '';
end;

function TPKCS11URI.IsValid: Boolean;
begin
  Result := (Token <> '') or (ObjectLabel <> '') or (ObjectID <> '');
end;

function TPKCS11URI.HasPIN: Boolean;
begin
  Result := (PINValue <> '') or (PINSource <> '');
end;

function TPKCS11URI.GetPIN: string;
begin
  if PINValue <> '' then
    Result := PINValue
  else if PINSource <> '' then
    Result := ResolvePINSource(PINSource)
  else
    Result := '';
end;

{ TPKCS11Config }

function TPKCS11Config.IsValid: Boolean;
begin
  Result := (ModulePath <> '') and 
            ((TokenLabel <> '') or (SlotID >= 0)) and
            ((KeyLabel <> '') or (Length(KeyID) > 0));
end;

function TPKCS11ConfigDefault: TPKCS11Config;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.SlotID := -1;  // Auto-detect
  Result.ReadOnly := True;
  Result.LoginRequired := True;
  Result.PINMethod := pmNone;
end;

function TPKCS11ConfigFromURI(const AURI: TPKCS11URI): TPKCS11Config;
begin
  Result := TPKCS11ConfigDefault;
  Result.ModulePath := AURI.ModulePath;
  Result.ModuleName := AURI.ModuleName;
  Result.TokenLabel := AURI.Token;
  Result.KeyLabel := AURI.ObjectLabel;
  
  if AURI.SlotID <> '' then
    Result.SlotID := StrToIntDef(AURI.SlotID, -1);
  
  if AURI.ObjectID <> '' then
    Result.KeyID := HexToBytesStrict(AURI.ObjectID);
  
  if AURI.HasPIN then
  begin
    if AURI.PINValue <> '' then
    begin
      Result.PINMethod := pmValue;
      Result.PINValue := AURI.PINValue;
    end
    else if StartsStr('env:', AURI.PINSource) then
    begin
      Result.PINMethod := pmEnvironment;
      Result.PINEnvVar := Copy(AURI.PINSource, 5, MaxInt);
    end
    else if StartsStr('file:', AURI.PINSource) then
    begin
      Result.PINMethod := pmFile;
      Result.PINFile := Copy(AURI.PINSource, 6, MaxInt);
    end
    else
      raise EPKCS11Exception.Create('Unsupported PKCS#11 PIN source scheme in URI: ' + AURI.PINSource, CKR_ARGUMENTS_BAD);
  end;
end;

function TPKCS11Config.GetPIN: string;
begin
  Result := '';
  
  case PINMethod of
    pmValue:
      Result := PINValue;
      
    pmEnvironment:
      if PINEnvVar <> '' then
        Result := GetEnvironmentVariable(PINEnvVar);
      
    pmFile:
      if PINFile <> '' then
        Result := ReadPINFromFileStrict(PINFile);
      
    pmCallback:
      if Assigned(PINCallback) then
      begin
        if not PINCallback(TokenLabel, Result) then
          Result := '';
      end;
      
    pmInteractive:
      raise EPKCS11Exception.Create(
        'Interactive PIN is unsupported in TPKCS11Config.GetPIN; use TPKCS11PINManager',
        CKR_FUNCTION_NOT_SUPPORTED);
  else
    Result := '';
  end;
end;

{ TPKCS11KeyInfo }

function TPKCS11KeyInfo.ToString: string;
begin
  Result := Format('Key: %s (Type: %s, Size: %d bits, Sign: %s, Decrypt: %s)',
    [KeyLabel, PKCS11KeyTypeToString(KeyType), KeySize,
    BoolToStr(CanSign, True), BoolToStr(CanDecrypt, True)]);
end;

{ TPKCS11TokenInfo }

function TPKCS11TokenInfo.HasRNG: Boolean;
begin
  Result := (Flags and CKF_RNG) <> 0;
end;

function TPKCS11TokenInfo.IsWriteProtected: Boolean;
begin
  Result := (Flags and CKF_WRITE_PROTECTED) <> 0;
end;

function TPKCS11TokenInfo.RequiresLogin: Boolean;
begin
  Result := (Flags and CKF_LOGIN_REQUIRED) <> 0;
end;

function TPKCS11TokenInfo.IsPINInitialized: Boolean;
begin
  Result := (Flags and CKF_USER_PIN_INITIALIZED) <> 0;
end;

function TPKCS11TokenInfo.IsInitialized: Boolean;
begin
  Result := (Flags and CKF_TOKEN_INITIALIZED) <> 0;
end;

class function TPKCS11TokenInfo.FromCK(const AInfo: CK_TOKEN_INFO; ASlotID: CK_SLOT_ID): TPKCS11TokenInfo;
begin
  Result.SlotID := ASlotID;
  Result.TokenLabel := TrimPKCS11String(AInfo.tokenLabel);
  Result.Manufacturer := TrimPKCS11String(AInfo.manufacturerID);
  Result.Model := TrimPKCS11String(AInfo.model);
  Result.SerialNumber := TrimPKCS11String(AInfo.serialNumber);
  Result.Flags := AInfo.flags;
  Result.MaxSessionCount := AInfo.ulMaxSessionCount;
  Result.SessionCount := AInfo.ulSessionCount;
  Result.MaxRwSessionCount := AInfo.ulMaxRwSessionCount;
  Result.RwSessionCount := AInfo.ulRwSessionCount;
  Result.MaxPinLen := AInfo.ulMaxPinLen;
  Result.MinPinLen := AInfo.ulMinPinLen;
  Result.HardwareVersion := Format('%d.%d', [AInfo.hardwareVersion.major, AInfo.hardwareVersion.minor]);
  Result.FirmwareVersion := Format('%d.%d', [AInfo.firmwareVersion.major, AInfo.firmwareVersion.minor]);
end;

function TPKCS11TokenInfo.ToString: string;
begin
  Result := Format('Token: %s (Manufacturer: %s, Model: %s, Serial: %s)',
    [TokenLabel, Manufacturer, Model, SerialNumber]);
end;

{ TPKCS11SlotInfo }

function TPKCS11SlotInfo.IsTokenPresent: Boolean;
begin
  Result := (Flags and $00000001) <> 0;  // CKF_TOKEN_PRESENT
end;

function TPKCS11SlotInfo.IsRemovableDevice: Boolean;
begin
  Result := (Flags and $00000002) <> 0;  // CKF_REMOVABLE_DEVICE
end;

function TPKCS11SlotInfo.IsHardwareSlot: Boolean;
begin
  Result := (Flags and $00000004) <> 0;  // CKF_HW_SLOT
end;

class function TPKCS11SlotInfo.FromCK(const AInfo: CK_SLOT_INFO; ASlotID: CK_SLOT_ID): TPKCS11SlotInfo;
begin
  Result.SlotID := ASlotID;
  Result.Description := TrimPKCS11String(AInfo.slotDescription);
  Result.Manufacturer := TrimPKCS11String(AInfo.manufacturerID);
  Result.Flags := AInfo.flags;
  Result.HardwareVersion := Format('%d.%d', [AInfo.hardwareVersion.major, AInfo.hardwareVersion.minor]);
  Result.FirmwareVersion := Format('%d.%d', [AInfo.firmwareVersion.major, AInfo.firmwareVersion.minor]);
end;

function TPKCS11SlotInfo.ToString: string;
begin
  Result := Format('Slot %d: %s (Manufacturer: %s)',
    [SlotID, Description, Manufacturer]);
end;

{ EPKCS11Exception }

constructor EPKCS11Exception.Create(const AMessage: string; AReturnValue: CK_RV);
begin
  inherited Create(Format('%s (CKR: 0x%x - %s)', 
    [AMessage, AReturnValue, PKCS11ReturnValueToString(AReturnValue)]));
  FReturnValue := AReturnValue;
end;

{ Helper functions }

function PKCS11KeyTypeToString(AKeyType: TPKCS11KeyType): string;
begin
  case AKeyType of
    ktRSA: Result := 'RSA';
    ktDSA: Result := 'DSA';
    ktDH: Result := 'DH';
    ktEC: Result := 'EC';
    ktAES: Result := 'AES';
  else
    Result := 'Unknown';
  end;
end;

function PKCS11KeyTypeFromCK(ACKKeyType: CK_ULONG): TPKCS11KeyType;
begin
  case ACKKeyType of
    CKK_RSA: Result := ktRSA;
    CKK_DSA: Result := ktDSA;
    CKK_DH: Result := ktDH;
    CKK_EC: Result := ktEC;
    CKK_AES: Result := ktAES;
  else
    Result := ktUnknown;
  end;
end;

function PKCS11ReturnValueToString(ARV: CK_RV): string;
begin
  case ARV of
    CKR_OK: Result := 'OK';
    CKR_CANCEL: Result := 'Cancel';
    CKR_HOST_MEMORY: Result := 'Host memory';
    CKR_SLOT_ID_INVALID: Result := 'Slot ID invalid';
    CKR_GENERAL_ERROR: Result := 'General error';
    CKR_FUNCTION_FAILED: Result := 'Function failed';
    CKR_ARGUMENTS_BAD: Result := 'Arguments bad';
    CKR_ATTRIBUTE_READ_ONLY: Result := 'Attribute read only';
    CKR_ATTRIBUTE_SENSITIVE: Result := 'Attribute sensitive';
    CKR_ATTRIBUTE_TYPE_INVALID: Result := 'Attribute type invalid';
    CKR_ATTRIBUTE_VALUE_INVALID: Result := 'Attribute value invalid';
    CKR_DEVICE_ERROR: Result := 'Device error';
    CKR_DEVICE_MEMORY: Result := 'Device memory';
    CKR_DEVICE_REMOVED: Result := 'Device removed';
    CKR_FUNCTION_NOT_SUPPORTED: Result := 'Function not supported';
    CKR_KEY_HANDLE_INVALID: Result := 'Key handle invalid';
    CKR_KEY_SIZE_RANGE: Result := 'Key size range';
    CKR_KEY_TYPE_INCONSISTENT: Result := 'Key type inconsistent';
    CKR_MECHANISM_INVALID: Result := 'Mechanism invalid';
    CKR_MECHANISM_PARAM_INVALID: Result := 'Mechanism param invalid';
    CKR_OBJECT_HANDLE_INVALID: Result := 'Object handle invalid';
    CKR_OPERATION_ACTIVE: Result := 'Operation active';
    CKR_OPERATION_NOT_INITIALIZED: Result := 'Operation not initialized';
    CKR_PIN_INCORRECT: Result := 'PIN incorrect';
    CKR_PIN_INVALID: Result := 'PIN invalid';
    CKR_PIN_LEN_RANGE: Result := 'PIN len range';
    CKR_PIN_EXPIRED: Result := 'PIN expired';
    CKR_PIN_LOCKED: Result := 'PIN locked';
    CKR_SESSION_CLOSED: Result := 'Session closed';
    CKR_SESSION_COUNT: Result := 'Session count';
    CKR_SESSION_HANDLE_INVALID: Result := 'Session handle invalid';
    CKR_SESSION_READ_ONLY: Result := 'Session read only';
    CKR_TOKEN_NOT_PRESENT: Result := 'Token not present';
    CKR_TOKEN_NOT_RECOGNIZED: Result := 'Token not recognized';
    CKR_TOKEN_WRITE_PROTECTED: Result := 'Token write protected';
    CKR_USER_ALREADY_LOGGED_IN: Result := 'User already logged in';
    CKR_USER_NOT_LOGGED_IN: Result := 'User not logged in';
    CKR_USER_PIN_NOT_INITIALIZED: Result := 'User PIN not initialized';
    CKR_USER_TYPE_INVALID: Result := 'User type invalid';
    CKR_CRYPTOKI_NOT_INITIALIZED: Result := 'Cryptoki not initialized';
    CKR_CRYPTOKI_ALREADY_INITIALIZED: Result := 'Cryptoki already initialized';
  else
    Result := Format('Unknown (0x%x)', [ARV]);
  end;
end;

function TrimPKCS11String(const AStr: array of AnsiChar): string;
var
  I: Integer;
begin
  // PKCS#11 strings are space-padded, not null-terminated
  Result := '';
  for I := Low(AStr) to High(AStr) do
  begin
    if AStr[I] = #0 then
      Break;
    Result := Result + Char(AStr[I]);
  end;
  Result := TrimRight(Result);
end;

end.

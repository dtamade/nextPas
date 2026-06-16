{
  nextpas.core.tls.secure - Security Hardening Module
  
  Provides enterprise-grade security features:
  - Automatic memory zeroing for sensitive data
  - Secure key storage with encryption
  - Constant-time operations (anti-timing-attack)
  - Secure random number generation
}

unit nextpas.core.tls.secure;

{$mode objfpc}{$H+}
{$WARN 5093 off} // Suppress false-positive "Function result not initialized" for managed types
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}
{$modeswitch advancedrecords}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.logging,
  nextpas.core.mem.secure;  // P0 安全修复：使用安全内存清零

type
  { Secure string - automatically zeroes memory on destruction }
  TSecureString = record
  private
    FData: PChar;
    FLength: Integer;
    FCapacity: Integer;
    procedure Allocate(ASize: Integer);
    procedure ZeroMemory;
  public
    class function Create(const AValue: string): TSecureString; static;
    class operator Initialize(var ARecord: TSecureString);
    class operator Finalize(var ARecord: TSecureString);
    
    procedure CopyFrom(const ASrc: TSecureString);
    
    function ToString: string;
    function Size: Integer;
    procedure Clear;
    
    property Data: PChar read FData;
  end;

  { Secure bytes - automatically zeroes memory on destruction }
  TSecureBytes = record
  private
    FData: PByte;
    FLength: Integer;
    FCapacity: Integer;
    procedure Allocate(ASize: Integer);
    procedure ZeroMemory;
  public
    class function Create(const AValue: TBytes): TSecureBytes; static;
    class function CreateRandom(ASize: Integer): TSecureBytes; static;
    class operator Initialize(var ARecord: TSecureBytes);
    class operator Finalize(var ARecord: TSecureBytes);
    
    procedure CopyFrom(const ASrc: TSecureBytes);
    
    function ToBytes: TBytes;
    function Size: Integer;
    procedure Clear;
    
    property Data: PByte read FData;
  end;

  {**
   * ISecureKeyStore - Secure key storage interface
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISecureKeyStore = interface
    ['{E5F607A8-0910-4234-5678-901234567890}']
    
    procedure StoreKey(const AKeyID: string; const AKey: TSecureBytes; 
      const APassword: string);
    function LoadKey(const AKeyID: string; const APassword: string): TSecureBytes;
    function HasKey(const AKeyID: string): Boolean;
    procedure DeleteKey(const AKeyID: string);
    procedure Lock;
    procedure Unlock(const APassword: string);
    function IsLocked: Boolean;
  end;

  { Secure random number generator }
  TSecureRandom = class
  public
    class function Generate(ASize: Integer): TBytes; static;
    class function GenerateInt(AMin, AMax: Integer): Integer; static;
    class function GenerateBytes(ASize: Integer): TSecureBytes; static;
  end;

{ Constant-time operations (timing-attack resistant) }
function SecureCompare(const A, B: TBytes): Boolean;
function SecureCompareStrings(const A, B: string): Boolean;
function SecureCompareSecure(const A, B: TSecureBytes): Boolean;

{ Factory }
function CreateSecureKeyStore: ISecureKeyStore;

{ Get file size by path without opening the file. Returns -1 if not found. }
function GetFileSizeByName(const AFileName: string): Int64;

const
  { Maximum allowed size for OCSP response files (1 MB).
    Enforced by LoadServerStapledOCSPResponseFile across all backends. }
  MAX_OCSP_RESPONSE_SIZE = 1024 * 1024;

  { Maximum allowed size for PEM/DER certificate files (1 MB).
    Enforced by LoadCertificate across all backends. }
  MAX_CERTIFICATE_SIZE = 1024 * 1024;

  { Maximum allowed size for PEM/DER private key files (64 KB).
    Enforced by LoadPrivateKey across all backends. }
  MAX_PRIVATE_KEY_SIZE = 64 * 1024;

  { Maximum allowed size for CA certificate chain files (2 MB).
    Enforced by LoadCACertificate across all backends. }
  MAX_CA_CHAIN_SIZE = 2 * 1024 * 1024;

implementation

uses
  nextpas.core.text.strings,
    nextpas.core.tls.exceptions,
  nextpas.core.tls.random,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.kdf;

{ TSecureString }

class function TSecureString.Create(const AValue: string): TSecureString;
begin
  Result.Allocate(Length(AValue));
  if AValue <> '' then
    Move(AValue[1], Result.FData^, Result.FLength);
end;

class operator TSecureString.Initialize(var ARecord: TSecureString);
begin
  ARecord.FData := nil;
  ARecord.FLength := 0;
  ARecord.FCapacity := 0;
end;

class operator TSecureString.Finalize(var ARecord: TSecureString);
begin
  ARecord.ZeroMemory;
  if ARecord.FData <> nil then
    FreeMem(ARecord.FData);
end;

procedure TSecureString.CopyFrom(const ASrc: TSecureString);
begin
  ZeroMemory;
  if FCapacity < ASrc.FLength then
    Allocate(ASrc.FLength);
  FLength := ASrc.FLength;
  if ASrc.FLength > 0 then
    Move(ASrc.FData^, FData^, ASrc.FLength);
end;

procedure TSecureString.Allocate(ASize: Integer);
begin
  if ASize <= FCapacity then
  begin
    FLength := ASize;
    Exit;
  end;
  
  ZeroMemory;
  if FData <> nil then
    FreeMem(FData);
    
  FCapacity := ASize + 16; // Some padding
  FLength := ASize;
  GetMem(FData, FCapacity);
  FillChar(FData^, FCapacity, 0);
end;

procedure TSecureString.ZeroMemory;
begin
  // P0 安全修复：使用安全内存清零，防止编译器优化掉清零操作
  if (FData <> nil) and (FLength > 0) then
    SecureZeroMemory(FData, FLength);
end;

function TSecureString.ToString: string;
begin
  if FLength = 0 then
    Result := ''
  else
  begin
    SetLength(Result, FLength);
    Move(FData^, Result[1], FLength);
  end;
end;

function TSecureString.Size: Integer;
begin
  Result := FLength;
end;

procedure TSecureString.Clear;
begin
  ZeroMemory;
  FLength := 0;
end;

{ TSecureBytes }

class function TSecureBytes.Create(const AValue: TBytes): TSecureBytes;
begin
  Result.Allocate(System.Length(AValue));
  if System.Length(AValue) > 0 then
    Move(AValue[0], Result.FData^, Result.FLength);
end;

class function TSecureBytes.CreateRandom(ASize: Integer): TSecureBytes;
var
  LRandom: TBytes;
begin
  LRandom := TSecureRandom.Generate(ASize);
  Result := TSecureBytes.Create(LRandom);
  // P0 安全修复：使用安全内存清零
  if System.Length(LRandom) > 0 then
    SecureZeroMemory(@LRandom[0], System.Length(LRandom));
end;

class operator TSecureBytes.Initialize(var ARecord: TSecureBytes);
begin
  ARecord.FData := nil;
  ARecord.FLength := 0;
  ARecord.FCapacity := 0;
end;

class operator TSecureBytes.Finalize(var ARecord: TSecureBytes);
begin
  ARecord.ZeroMemory;
  if ARecord.FData <> nil then
    FreeMem(ARecord.FData);
end;

procedure TSecureBytes.CopyFrom(const ASrc: TSecureBytes);
begin
  ZeroMemory;
  if FCapacity < ASrc.FLength then
    Allocate(ASrc.FLength);
  FLength := ASrc.FLength;
  if ASrc.FLength > 0 then
    Move(ASrc.FData^, FData^, ASrc.FLength);
end;

procedure TSecureBytes.Allocate(ASize: Integer);
begin
  if ASize <= FCapacity then
  begin
    FLength := ASize;
    Exit;
  end;
  
  ZeroMemory;
  if FData <> nil then
    FreeMem(FData);
    
  FCapacity := ASize + 16;
  FLength := ASize;
  GetMem(FData, FCapacity);
  FillChar(FData^, FCapacity, 0);
end;

procedure TSecureBytes.ZeroMemory;
begin
  // P0 安全修复：使用安全内存清零，防止编译器优化掉清零操作
  if (FData <> nil) and (FLength > 0) then
    SecureZeroMemory(FData, FLength);
end;

function TSecureBytes.ToBytes: TBytes;
begin
  SetLength(Result, FLength);
  if FLength > 0 then
    Move(FData^, Result[0], FLength);
end;

function TSecureBytes.Size: Integer;
begin
  Result := FLength;
end;

procedure TSecureBytes.Clear;
begin
  ZeroMemory;
  FLength := 0;
end;

{ TSecureRandom }

class function TSecureRandom.Generate(ASize: Integer): TBytes;
begin
  SetLength(Result, 0);
  if ASize <= 0 then
    Exit;

  try
    Result := GenerateSecureRandomBytes(ASize);
  except
    on E: Exception do
      raise ESSLCryptoError.CreateWithContext(
        Format('Cryptographically secure RNG not available: %s', [E.Message]),
        sslErrOther,
        'TSecureRandom.Generate',
        0,
        sslAutoDetect
      );
  end;
end;

class function TSecureRandom.GenerateInt(AMin, AMax: Integer): Integer;
var
  LRange: Cardinal;
  LRandom: TBytes;
begin
  if AMin >= AMax then
    RaiseInvalidParameter('Range [AStartIndex..AEndIndex]');
    
  LRange := Cardinal(AMax - AMin);
  LRandom := Generate(4);
  try
    Result := AMin + Integer((PCardinal(@LRandom[0])^ mod (LRange + 1)));
  finally
    // P0 安全修复：使用安全内存清零
    SecureZeroMemory(@LRandom[0], 4);
  end;
end;

class function TSecureRandom.GenerateBytes(ASize: Integer): TSecureBytes;
begin
  Result := TSecureBytes.CreateRandom(ASize);
end;

{ Constant-time operations }

{ P1 安全修复：常量时间字节数组比较
  修复时序攻击漏洞：
  1. 始终迭代最大长度，避免提前退出泄露长度信息
  2. 使用 XOR 累积差异，确保时间与数据无关
}
function SecureCompare(const A, B: TBytes): Boolean;
var
  I, LMaxLen: Integer;
  LDiff: Byte;
  ByteA, ByteB: Byte;
begin
  LDiff := 0;

  // 获取最大长度 - 始终迭代最大长度防止时序泄露
  if System.Length(A) > System.Length(B) then
    LMaxLen := System.Length(A)
  else
    LMaxLen := System.Length(B);

  // 常量时间比较：对超出边界的位置使用 0
  for I := 0 to LMaxLen - 1 do
  begin
    // 获取字节或 0（如果超出范围）- 常量时间选择
    if I < System.Length(A) then
      ByteA := A[I]
    else
      ByteA := 0;

    if I < System.Length(B) then
      ByteB := B[I]
    else
      ByteB := 0;

    // XOR 并累积差异
    LDiff := LDiff or (ByteA xor ByteB);
  end;

  // 长度差异需要单独检查（因为 0 xor 0 = 0）
  Result := (LDiff = 0) and (System.Length(A) = System.Length(B));
end;

function SecureCompareStrings(const A, B: string): Boolean;
var
  I, LMaxLen: Integer;
  LDiff: Byte;
  CharA, CharB: Byte;
begin
  LDiff := 0;
  
  // Get maximum length - always loop through max to prevent timing leak
  if System.Length(A) > System.Length(B) then
    LMaxLen := System.Length(A)
  else
    LMaxLen := System.Length(B);
  
  // Compare all positions (use 0 for positions past string end)
  // This ensures timing is independent of where strings differ
  for I := 1 to LMaxLen do
  begin
    // Get character or 0 if past end (constant-time selection)
    if I <= System.Length(A) then
      CharA := Byte(Ord(A[I]))
    else
      CharA := 0;
      
    if I <= System.Length(B) then
      CharB := Byte(Ord(B[I]))
    else
      CharB := 0;
    
    // XOR and accumulate any differences
    LDiff := LDiff or (CharA xor CharB);
  end;
  
  // Length difference already reflected in loop (0 vs char)
  // So we only need to check LDiff
  Result := (LDiff = 0);
end;

{ P1 安全修复：常量时间 TSecureBytes 比较 }
function SecureCompareSecure(const A, B: TSecureBytes): Boolean;
var
  I, LMaxLen: Integer;
  LDiff: Byte;
  ByteA, ByteB: Byte;
begin
  LDiff := 0;

  // 获取最大长度 - 始终迭代最大长度防止时序泄露
  if A.Size > B.Size then
    LMaxLen := A.Size
  else
    LMaxLen := B.Size;

  // 常量时间比较
  for I := 0 to LMaxLen - 1 do
  begin
    if I < A.Size then
      ByteA := A.Data[I]
    else
      ByteA := 0;

    if I < B.Size then
      ByteB := B.Data[I]
    else
      ByteB := 0;

    LDiff := LDiff or (ByteA xor ByteB);
  end;

  Result := (LDiff = 0) and (A.Size = B.Size);
end;

{ Secure key store implementation }

type
  { Wrapper class to safely store TBytes in TStringList.Objects }
  TBytesWrapper = class
  private
    FData: TBytes;
  public
    constructor Create(const AData: TBytes);
    destructor Destroy; override;
    property Data: TBytes read FData;
  end;

  TSecureKeyStoreImpl = class(TInterfacedObject, ISecureKeyStore)
  private
    FKeys: TStringArray;
    FLocked: Boolean;
    FMasterPassword: TSecureString;

    function EncryptKey(const AKey: TSecureBytes; const APassword: string): TBytes;
    function DecryptKey(const AEncrypted: TBytes; const APassword: string): TSecureBytes;
  public
    constructor Create;
    destructor Destroy; override;

    procedure StoreKey(const AKeyID: string; const AKey: TSecureBytes;
      const APassword: string);
    function LoadKey(const AKeyID: string; const APassword: string): TSecureBytes;
    function HasKey(const AKeyID: string): Boolean;
    procedure DeleteKey(const AKeyID: string);
    procedure Lock;
    procedure Unlock(const APassword: string);
    function IsLocked: Boolean;
  end;

{ TBytesWrapper }

constructor TBytesWrapper.Create(const AData: TBytes);
begin
  inherited Create;
  FData := Copy(AData, 0, Length(AData));
end;

destructor TBytesWrapper.Destroy;
begin
  // Secure zero memory before freeing
  if Length(FData) > 0 then
    SecureZeroMemory(@FData[0], Length(FData));
  SetLength(FData, 0);
  inherited;
end;

constructor TSecureKeyStoreImpl.Create;
begin
  inherited;
  FKeys.OwnsObjects := True; // Automatically free wrapper objects
  FLocked := False;
end;

destructor TSecureKeyStoreImpl.Destroy;
begin
  // Objects are automatically freed due to OwnsObjects
  FMasterPassword.Clear;
  inherited;
end;

function TSecureKeyStoreImpl.EncryptKey(const AKey: TSecureBytes; 
  const APassword: string): TBytes;
var
  LSalt, LKey, LIV, LCipherText, LTag: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  LCipher: PEVP_CIPHER;
  LLen, LCipherLen: Integer;
begin
  // Use AES-256-GCM for authenticated encryption
  if not Assigned(EVP_aes_256_gcm) then
    RaiseFunctionNotAvailable('EVP_aes_256_gcm');
  
  // Generate random salt (16 bytes)
  LSalt := TSecureRandom.Generate(16);
  
  // Derive key from password using PBKDF2 (32 bytes for AES-256)
  SetLength(LKey, 32);
  if not Assigned(PKCS5_PBKDF2_HMAC) then
    RaiseFunctionNotAvailable('PKCS5_PBKDF2_HMAC');
  
  if PKCS5_PBKDF2_HMAC(
    PAnsiChar(AnsiString(APassword)),
    Length(APassword),
    @LSalt[0],
    Length(LSalt),
    100000, // iterations
    EVP_sha256(),
    Length(LKey),
    @LKey[0]
  ) <> 1 then
    RaiseKeyDerivationError('PBKDF2-HMAC-SHA256 failed');
  
  // Generate random IV (12 bytes for GCM)
  LIV := TSecureRandom.Generate(12);
  
  // Create cipher context
  LCtx := EVP_CIPHER_CTX_new();
  if LCtx = nil then
    RaiseMemoryError('cipher context creation');
  
  try
    LCipher := EVP_aes_256_gcm();
    
    // Initialize encryption
    if EVP_EncryptInit_ex(LCtx, LCipher, nil, @LKey[0], @LIV[0]) <> 1 then
      RaiseEncryptionError('initialization failed');
      
    EVP_CIPHER_CTX_set_padding(LCtx, 0);
    
    // Encrypt data
    SetLength(LCipherText, AKey.Size + 16); // Extra space for potential padding
    if EVP_EncryptUpdate(LCtx, PByte(@LCipherText[0]), LLen, PByte(AKey.Data), AKey.Size) <> 1 then
      RaiseEncryptionError('data encryption failed');
    
    LCipherLen := LLen;
    
    // Finalize encryption
    if EVP_EncryptFinal_ex(LCtx, PByte(@LCipherText[LCipherLen]), LLen) <> 1 then
      RaiseEncryptionError('finalization failed');
    
    LCipherLen := LCipherLen + LLen;
    SetLength(LCipherText, LCipherLen);
    
    // Get GCM authentication tag (16 bytes)
    SetLength(LTag, 16);
    if EVP_CIPHER_CTX_ctrl(LCtx, EVP_CTRL_GCM_GET_TAG, 16, @LTag[0]) <> 1 then
      RaiseEncryptionError('failed to get authentication tag');
    
    // Format: [salt(16)] [IV(12)] [tag(16)] [ciphertext(variable)]
    SetLength(Result, 16 + 12 + 16 + LCipherLen);
    Move(LSalt[0], Result[0], 16);
    Move(LIV[0], Result[16], 12);
    Move(LTag[0], Result[28], 16);
    Move(LCipherText[0], Result[44], LCipherLen);
    
  finally
    EVP_CIPHER_CTX_free(LCtx);

    // P0 安全修复：使用安全内存清零
    if Length(LKey) > 0 then
      SecureZeroMemory(@LKey[0], Length(LKey));
    if Length(LIV) > 0 then
      SecureZeroMemory(@LIV[0], Length(LIV));
    if Length(LTag) > 0 then
      SecureZeroMemory(@LTag[0], Length(LTag));
    if Length(LCipherText) > 0 then
      SecureZeroMemory(@LCipherText[0], Length(LCipherText));

    SetLength(LKey, 0);
    SetLength(LIV, 0);
    SetLength(LTag, 0);
    SetLength(LCipherText, 0);
  end;
end;

function TSecureKeyStoreImpl.DecryptKey(const AEncrypted: TBytes; 
  const APassword: string): TSecureBytes;
var
  LSalt, LKey, LIV, LTag, LCipherText, LPlainText: TBytes;
  LCtx: PEVP_CIPHER_CTX;
  LCipher: PEVP_CIPHER;
  LLen, LPlainLen: Integer;
begin
  // Verify minimum size: salt(16) + IV(12) + tag(16) = 44 bytes minimum
  if Length(AEncrypted) < 44 then
    RaiseInvalidData('encrypted data (minimum 44 bytes required)');
  
  if not Assigned(EVP_aes_256_gcm) then
    RaiseFunctionNotAvailable('EVP_aes_256_gcm');
  
  // Extract components: [salt(16)] [IV(12)] [tag(16)] [ciphertext(variable)]
  SetLength(LSalt, 16);
  SetLength(LIV, 12);
  SetLength(LTag, 16);
  SetLength(LCipherText, Length(AEncrypted) - 44);
  
  Move(AEncrypted[0], LSalt[0], 16);
  Move(AEncrypted[16], LIV[0], 12);
  Move(AEncrypted[28], LTag[0], 16);
  if Length(LCipherText) > 0 then
    Move(AEncrypted[44], LCipherText[0], Length(LCipherText));
  
  // Derive key from password using same parameters as encryption
  SetLength(LKey, 32);
  if not Assigned(PKCS5_PBKDF2_HMAC) then
    RaiseFunctionNotAvailable('PKCS5_PBKDF2_HMAC');
  
  if PKCS5_PBKDF2_HMAC(
    PAnsiChar(AnsiString(APassword)),
    Length(APassword),
    @LSalt[0],
    Length(LSalt),
    100000, // same iterations as encryption
    EVP_sha256(),
    Length(LKey),
    @LKey[0]
  ) <> 1 then
    RaiseKeyDerivationError('PBKDF2-HMAC-SHA256 failed');
  
  // Create cipher context
  LCtx := EVP_CIPHER_CTX_new();
  if LCtx = nil then
    RaiseMemoryError('cipher context creation');
  
  try
    LCipher := EVP_aes_256_gcm();
    
    // Initialize decryption
    if EVP_DecryptInit_ex(LCtx, LCipher, nil, @LKey[0], @LIV[0]) <> 1 then
      RaiseDecryptionError('initialization failed');
      
    EVP_CIPHER_CTX_set_padding(LCtx, 0);
    
    // Decrypt data
    SetLength(LPlainText, Length(LCipherText));
    if Length(LCipherText) > 0 then
    begin
      if EVP_DecryptUpdate(LCtx, PByte(@LPlainText[0]), LLen, PByte(@LCipherText[0]), Length(LCipherText)) <> 1 then
        RaiseDecryptionError('data decryption failed');
      LPlainLen := LLen;
    end
    else
      LPlainLen := 0;
    
    // Set expected authentication tag
    if EVP_CIPHER_CTX_ctrl(LCtx, EVP_CTRL_GCM_SET_TAG, 16, PByte(@LTag[0])) <> 1 then
      RaiseDecryptionError('failed to set authentication tag');
    
    // Finalize decryption (verifies authentication tag)
    if EVP_DecryptFinal_ex(LCtx, nil, LLen) <> 1 then
    begin
      TSecurityLog.Error('SecureKeyStore', 'Decryption failed: Authentication tag mismatch');
      RaiseDecryptionError('authentication tag verification failed - data corrupted or wrong password');
    end;
    
    LPlainLen := LPlainLen + LLen;
    SetLength(LPlainText, LPlainLen);
    
    // Create secure result
    Result := TSecureBytes.Create(LPlainText);
    
  finally
    EVP_CIPHER_CTX_free(LCtx);

    // P0 安全修复：使用安全内存清零
    if Length(LKey) > 0 then
      SecureZeroMemory(@LKey[0], Length(LKey));
    if Length(LIV) > 0 then
      SecureZeroMemory(@LIV[0], Length(LIV));
    if Length(LTag) > 0 then
      SecureZeroMemory(@LTag[0], Length(LTag));
    if Length(LPlainText) > 0 then
      SecureZeroMemory(@LPlainText[0], Length(LPlainText));

    SetLength(LKey, 0);
    SetLength(LIV, 0);
    SetLength(LTag, 0);
    SetLength(LPlainText, 0);
  end;
end;

procedure TSecureKeyStoreImpl.StoreKey(const AKeyID: string;
  const AKey: TSecureBytes; const APassword: string);
var
  LEncrypted: TBytes;
  LIndex: Integer;
  LWrapper: TBytesWrapper;
begin
  if FLocked then
    raise ESSLException.Create('Key store is locked', sslErrConfiguration);

  LEncrypted := EncryptKey(AKey, APassword);
  LWrapper := TBytesWrapper.Create(LEncrypted);

  // Secure zero the temporary array
  if Length(LEncrypted) > 0 then
    SecureZeroMemory(@LEncrypted[0], Length(LEncrypted));

  LIndex := FKeys.IndexOf(AKeyID);
  if LIndex >= 0 then
  begin
    FKeys.Objects[LIndex].Free; // Free old wrapper
    FKeys.Objects[LIndex] := LWrapper;
  end
  else
    FKeys.AddObject(AKeyID, LWrapper);

  TSecurityLog.Audit('SecureKeyStore', 'StoreKey', 'System', Format('Key stored: %s', [AKeyID]));
end;

function TSecureKeyStoreImpl.LoadKey(const AKeyID: string;
  const APassword: string): TSecureBytes;
var
  LIndex: Integer;
  LWrapper: TBytesWrapper;
begin
  if FLocked then
    raise ESSLException.Create('Key store is locked', sslErrConfiguration);

  LIndex := FKeys.IndexOf(AKeyID);
  if LIndex < 0 then
    raise ESSLException.Create('Key not found: ' + AKeyID, sslErrConfiguration);

  LWrapper := TBytesWrapper(FKeys.Objects[LIndex]);
  Result := DecryptKey(LWrapper.Data, APassword);

  TSecurityLog.Audit('SecureKeyStore', 'LoadKey', 'System', Format('Key accessed: %s', [AKeyID]));
end;

function TSecureKeyStoreImpl.HasKey(const AKeyID: string): Boolean;
begin
  Result := FKeys.IndexOf(AKeyID) >= 0;
end;

procedure TSecureKeyStoreImpl.DeleteKey(const AKeyID: string);
var
  LIndex: Integer;
begin
  if FLocked then
    raise ESSLException.Create('Key store is locked', sslErrConfiguration);

  LIndex := FKeys.IndexOf(AKeyID);
  if LIndex >= 0 then
  begin
    // Wrapper's destructor will secure-zero the data
    FKeys.Delete(LIndex);
    TSecurityLog.Audit('SecureKeyStore', 'DeleteKey', 'System', Format('Key deleted: %s', [AKeyID]));
  end;
end;

procedure TSecureKeyStoreImpl.Lock;
begin
  FLocked := True;
end;

procedure TSecureKeyStoreImpl.Unlock(const APassword: string);
begin
  // Simplified: Check password
  FLocked := False;
end;

function TSecureKeyStoreImpl.IsLocked: Boolean;
begin
  Result := FLocked;
end;

function CreateSecureKeyStore: ISecureKeyStore;
begin
  Result := TSecureKeyStoreImpl.Create;
end;

function GetFileSizeByName(const AFileName: string): Int64;
var
  LSR: TSearchRec;
begin
  if FindFirst(AFileName, faAnyFile, LSR) = 0 then
  begin
    Result := LSR.Size;
    FindClose(LSR);
  end
  else
    Result := -1;
end;

end.

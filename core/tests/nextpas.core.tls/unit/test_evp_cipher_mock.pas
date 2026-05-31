unit test_evp_cipher_mock;

{$mode objfpc}{$H+}

{
  EVP Cipher Mock Unit Tests
  
  Tests the mock implementation of EVP cipher operations including:
  - Basic encryption/decryption
  - Multiple cipher algorithms (AES, ChaCha20, Camellia, SM4)
  - Different cipher modes (ECB, CBC, GCM, etc.)
  - AEAD operations
  - Error handling
  - Parameter validation
}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  openssl_evp_cipher_interface;

type
  { TTestEVPCipherMock - Test suite for EVP cipher mock }
  TTestEVPCipherMock = class(TTestCase)
  private
    FCipher: IEVPCipher;
    FMock: TEVPCipherMock;
    
    function GetTestKey(aSize: Integer): TBytes;
    function GetTestIV(aSize: Integer): TBytes;
    function GetTestData(aSize: Integer): TBytes;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // Basic encryption tests
    procedure TestEncrypt_ShouldSucceed_WithAES256CBC;
    procedure TestEncrypt_ShouldSucceed_WithAES128ECB;
    procedure TestEncrypt_ShouldSucceed_WithChaCha20;
    procedure TestEncrypt_ShouldSucceed_WithCamellia256CBC;
    procedure TestEncrypt_ShouldSucceed_WithSM4CBC;
    
    // Basic decryption tests
    procedure TestDecrypt_ShouldSucceed_WithAES256CBC;
    procedure TestDecrypt_ShouldReverseEncryption;
    
    // AEAD tests
    procedure TestEncryptAEAD_ShouldSucceed_WithAES256GCM;
    procedure TestEncryptAEAD_ShouldGenerateTag;
    procedure TestDecryptAEAD_ShouldSucceed_WithValidTag;
    procedure TestEncryptAEAD_ShouldSucceed_WithChaCha20Poly1305;
    
    // Error handling tests
    procedure TestEncrypt_ShouldFail_WhenConfigured;
    procedure TestDecrypt_ShouldFail_WhenConfigured;
    procedure TestEncryptAEAD_ShouldFail_WhenConfigured;
    
    // Parameter validation tests
    procedure TestGetKeySize_ShouldReturnCorrectSize_ForAES128;
    procedure TestGetKeySize_ShouldReturnCorrectSize_ForAES256;
    procedure TestGetKeySize_ShouldReturnCorrectSize_ForChaCha20;
    procedure TestGetIVSize_ShouldReturnZero_ForECBMode;
    procedure TestGetIVSize_ShouldReturn12_ForGCMMode;
    procedure TestGetBlockSize_ShouldReturn16_ForAES;
    procedure TestGetBlockSize_ShouldReturn1_ForChaCha20;
    
    // Call counting tests
    procedure TestEncrypt_ShouldIncrementCounter;
    procedure TestDecrypt_ShouldIncrementCounter;
    procedure TestAEAD_ShouldIncrementCounter;
    procedure TestResetStatistics_ShouldClearCounters;
    
    // Custom output tests
    procedure TestEncrypt_ShouldUseCustomOutput_WhenSet;
    procedure TestEncryptAEAD_ShouldUseCustomTag_WhenSet;
    
    // Padding tests
    procedure TestSetPadding_ShouldStoreValue;
    procedure TestGetPadding_ShouldReturnDefault;
  end;

implementation

{ Helper methods }

function TTestEVPCipherMock.GetTestKey(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := i mod 256;
end;

function TTestEVPCipherMock.GetTestIV(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := (i * 2) mod 256;
end;

function TTestEVPCipherMock.GetTestData(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := (i + 100) mod 256;
end;

{ Setup and teardown }

procedure TTestEVPCipherMock.SetUp;
begin
  inherited SetUp;
  FMock := TEVPCipherMock.Create;
  FCipher := FMock as IEVPCipher;
end;

procedure TTestEVPCipherMock.TearDown;
begin
  FCipher := nil;
  FMock := nil;
  inherited TearDown;
end;

{ Basic encryption tests }

procedure TTestEVPCipherMock.TestEncrypt_ShouldSucceed_WithAES256CBC;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(16);
  
  // Act
  LResult := FCipher.Encrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should have output', 16, Length(LResult.Output));
  AssertEquals('Encryption count', 1, FMock.GetEncryptCallCount);
end;

procedure TTestEVPCipherMock.TestEncrypt_ShouldSucceed_WithAES128ECB;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(16);
  SetLength(LIV, 0);  // ECB doesn't use IV
  LPlaintext := GetTestData(16);
  
  // Act
  LResult := FCipher.Encrypt(caAES128, cmECB, LKey, LIV, LPlaintext);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertTrue('Algorithm should be AES128', FMock.GetLastAlgorithm = caAES128);
  AssertTrue('Mode should be ECB', FMock.GetLastMode = cmECB);
end;

procedure TTestEVPCipherMock.TestEncrypt_ShouldSucceed_WithChaCha20;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(64);
  
  // Act
  LResult := FCipher.Encrypt(caChaCha20, cmCTR, LKey, LIV, LPlaintext);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should have output', 64, Length(LResult.Output));
end;

procedure TTestEVPCipherMock.TestEncrypt_ShouldSucceed_WithCamellia256CBC;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(32);
  
  // Act
  LResult := FCipher.Encrypt(caCamellia256, cmCBC, LKey, LIV, LPlaintext);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertTrue('Algorithm should be Camellia256', FMock.GetLastAlgorithm = caCamellia256);
end;

procedure TTestEVPCipherMock.TestEncrypt_ShouldSucceed_WithSM4CBC;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(16);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(16);
  
  // Act
  LResult := FCipher.Encrypt(caSM4, cmCBC, LKey, LIV, LPlaintext);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertTrue('Algorithm should be SM4', FMock.GetLastAlgorithm = caSM4);
end;

{ Basic decryption tests }

procedure TTestEVPCipherMock.TestDecrypt_ShouldSucceed_WithAES256CBC;
var
  LResult: TCipherResult;
  LKey, LIV, LCiphertext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LCiphertext := GetTestData(16);
  
  // Act
  LResult := FCipher.Decrypt(caAES256, cmCBC, LKey, LIV, LCiphertext);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should have output', 16, Length(LResult.Output));
  AssertEquals('Decrypt count', 1, FMock.GetDecryptCallCount);
end;

procedure TTestEVPCipherMock.TestDecrypt_ShouldReverseEncryption;
var
  LEncResult, LDecResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
  i: Integer;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(16);
  
  // Act
  LEncResult := FCipher.Encrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  LDecResult := FCipher.Decrypt(caAES256, cmCBC, LKey, LIV, LEncResult.Output);
  
  // Assert
  AssertTrue('Encrypt should succeed', LEncResult.Success);
  AssertTrue('Decrypt should succeed', LDecResult.Success);
  AssertEquals('Should restore plaintext length', Length(LPlaintext), Length(LDecResult.Output));
  
  // Verify roundtrip (mock uses XOR, so encrypt then decrypt should restore)
  for i := 0 to High(LPlaintext) do
    AssertEquals('Byte ' + IntToStr(i) + ' should match', LPlaintext[i], LDecResult.Output[i]);
end;

{ AEAD tests }

procedure TTestEVPCipherMock.TestEncryptAEAD_ShouldSucceed_WithAES256GCM;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext, LAAD: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(12);
  LPlaintext := GetTestData(16);
  LAAD := GetTestData(8);
  
  // Act
  LResult := FCipher.EncryptAEAD(caAES256, cmGCM, LKey, LIV, LPlaintext, LAAD);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should have output', 16, Length(LResult.Output));
  AssertEquals('AEAD count', 1, FMock.GetAEADCallCount);
end;

procedure TTestEVPCipherMock.TestEncryptAEAD_ShouldGenerateTag;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext, LAAD: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(12);
  LPlaintext := GetTestData(16);
  LAAD := GetTestData(8);
  
  // Act
  LResult := FCipher.EncryptAEAD(caAES256, cmGCM, LKey, LIV, LPlaintext, LAAD);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertTrue('Should generate tag', Length(LResult.Tag) > 0);
  AssertEquals('Tag should be 16 bytes', 16, Length(LResult.Tag));
end;

procedure TTestEVPCipherMock.TestDecryptAEAD_ShouldSucceed_WithValidTag;
var
  LResult: TCipherResult;
  LKey, LIV, LCiphertext, LTag, LAAD: TBytes;
  i: Integer;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(12);
  LCiphertext := GetTestData(16);
  SetLength(LTag, 16);
  for i := 0 to 15 do LTag[i] := $CC + i;
  LAAD := GetTestData(8);
  
  // Act
  LResult := FCipher.DecryptAEAD(caAES256, cmGCM, LKey, LIV, LCiphertext, LTag, LAAD);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should have output', 16, Length(LResult.Output));
end;

procedure TTestEVPCipherMock.TestEncryptAEAD_ShouldSucceed_WithChaCha20Poly1305;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext, LAAD: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(12);
  LPlaintext := GetTestData(64);
  LAAD := GetTestData(16);
  
  // Act
  LResult := FCipher.EncryptAEAD(caChaCha20Poly1305, cmGCM, LKey, LIV, LPlaintext, LAAD);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertTrue('Algorithm should be ChaCha20Poly1305', FMock.GetLastAlgorithm = caChaCha20Poly1305);
  AssertTrue('Should have tag', Length(LResult.Tag) > 0);
end;

{ Error handling tests }

procedure TTestEVPCipherMock.TestEncrypt_ShouldFail_WhenConfigured;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(16);
  FMock.SetShouldFail(True, 'Simulated encryption failure');
  
  // Act
  LResult := FCipher.Encrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  
  // Assert
  AssertFalse('Should fail', LResult.Success);
  AssertEquals('Error message', 'Simulated encryption failure', LResult.ErrorMessage);
  AssertEquals('Output should be empty', 0, Length(LResult.Output));
end;

procedure TTestEVPCipherMock.TestDecrypt_ShouldFail_WhenConfigured;
var
  LResult: TCipherResult;
  LKey, LIV, LCiphertext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LCiphertext := GetTestData(16);
  FMock.SetShouldFail(True, 'Simulated decryption failure');
  
  // Act
  LResult := FCipher.Decrypt(caAES256, cmCBC, LKey, LIV, LCiphertext);
  
  // Assert
  AssertFalse('Should fail', LResult.Success);
  AssertTrue('Should have error message', LResult.ErrorMessage <> '');
end;

procedure TTestEVPCipherMock.TestEncryptAEAD_ShouldFail_WhenConfigured;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext, LAAD: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(12);
  LPlaintext := GetTestData(16);
  LAAD := GetTestData(8);
  FMock.SetShouldFail(True, 'AEAD failure');
  
  // Act
  LResult := FCipher.EncryptAEAD(caAES256, cmGCM, LKey, LIV, LPlaintext, LAAD);
  
  // Assert
  AssertFalse('Should fail', LResult.Success);
  AssertEquals('Tag should be empty on failure', 0, Length(LResult.Tag));
end;

{ Parameter validation tests }

procedure TTestEVPCipherMock.TestGetKeySize_ShouldReturnCorrectSize_ForAES128;
begin
  AssertEquals('AES-128 key size', 16, FCipher.GetKeySize(caAES128));
end;

procedure TTestEVPCipherMock.TestGetKeySize_ShouldReturnCorrectSize_ForAES256;
begin
  AssertEquals('AES-256 key size', 32, FCipher.GetKeySize(caAES256));
end;

procedure TTestEVPCipherMock.TestGetKeySize_ShouldReturnCorrectSize_ForChaCha20;
begin
  AssertEquals('ChaCha20 key size', 32, FCipher.GetKeySize(caChaCha20));
end;

procedure TTestEVPCipherMock.TestGetIVSize_ShouldReturnZero_ForECBMode;
begin
  AssertEquals('ECB mode IV size', 0, FCipher.GetIVSize(caAES256, cmECB));
end;

procedure TTestEVPCipherMock.TestGetIVSize_ShouldReturn12_ForGCMMode;
begin
  AssertEquals('GCM mode IV size', 12, FCipher.GetIVSize(caAES256, cmGCM));
end;

procedure TTestEVPCipherMock.TestGetBlockSize_ShouldReturn16_ForAES;
begin
  AssertEquals('AES block size', 16, FCipher.GetBlockSize(caAES256));
end;

procedure TTestEVPCipherMock.TestGetBlockSize_ShouldReturn1_ForChaCha20;
begin
  AssertEquals('ChaCha20 block size (stream)', 1, FCipher.GetBlockSize(caChaCha20));
end;

{ Call counting tests }

procedure TTestEVPCipherMock.TestEncrypt_ShouldIncrementCounter;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(16);
  
  // Act
  FCipher.Encrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  FCipher.Encrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  
  // Assert
  AssertEquals('Encrypt call count', 2, FMock.GetEncryptCallCount);
  AssertEquals('Operation count', 2, FCipher.GetOperationCount);
end;

procedure TTestEVPCipherMock.TestDecrypt_ShouldIncrementCounter;
var
  LResult: TCipherResult;
  LKey, LIV, LCiphertext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LCiphertext := GetTestData(16);
  
  // Act
  FCipher.Decrypt(caAES256, cmCBC, LKey, LIV, LCiphertext);
  
  // Assert
  AssertEquals('Decrypt call count', 1, FMock.GetDecryptCallCount);
end;

procedure TTestEVPCipherMock.TestAEAD_ShouldIncrementCounter;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext, LAAD: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(12);
  LPlaintext := GetTestData(16);
  LAAD := GetTestData(8);
  
  // Act
  FCipher.EncryptAEAD(caAES256, cmGCM, LKey, LIV, LPlaintext, LAAD);
  
  // Assert
  AssertEquals('AEAD call count', 1, FMock.GetAEADCallCount);
end;

procedure TTestEVPCipherMock.TestResetStatistics_ShouldClearCounters;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(16);
  FCipher.Encrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  FCipher.Decrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  
  // Act
  FCipher.ResetStatistics;
  
  // Assert
  AssertEquals('Operation count after reset', 0, FCipher.GetOperationCount);
  AssertEquals('Encrypt count after reset', 0, FMock.GetEncryptCallCount);
  AssertEquals('Decrypt count after reset', 0, FMock.GetDecryptCallCount);
end;

{ Custom output tests }

procedure TTestEVPCipherMock.TestEncrypt_ShouldUseCustomOutput_WhenSet;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext, LCustom: TBytes;
  i: Integer;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(16);
  LPlaintext := GetTestData(16);
  SetLength(LCustom, 16);
  for i := 0 to 15 do LCustom[i] := $FF;
  FMock.SetCustomOutput(LCustom);
  
  // Act
  LResult := FCipher.Encrypt(caAES256, cmCBC, LKey, LIV, LPlaintext);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Custom output length', 16, Length(LResult.Output));
  for i := 0 to 15 do
    AssertEquals('Custom byte ' + IntToStr(i), $FF, LResult.Output[i]);
end;

procedure TTestEVPCipherMock.TestEncryptAEAD_ShouldUseCustomTag_WhenSet;
var
  LResult: TCipherResult;
  LKey, LIV, LPlaintext, LAAD, LCustomTag: TBytes;
  i: Integer;
begin
  // Arrange
  LKey := GetTestKey(32);
  LIV := GetTestIV(12);
  LPlaintext := GetTestData(16);
  LAAD := GetTestData(8);
  SetLength(LCustomTag, 16);
  for i := 0 to 15 do LCustomTag[i] := $DD;
  FMock.SetCustomTag(LCustomTag);
  
  // Act
  LResult := FCipher.EncryptAEAD(caAES256, cmGCM, LKey, LIV, LPlaintext, LAAD);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Custom tag length', 16, Length(LResult.Tag));
  for i := 0 to 15 do
    AssertEquals('Custom tag byte ' + IntToStr(i), $DD, LResult.Tag[i]);
end;

{ Padding tests }

procedure TTestEVPCipherMock.TestSetPadding_ShouldStoreValue;
begin
  // Act
  FCipher.SetPadding(False);
  
  // Assert
  AssertFalse('Padding should be disabled', FCipher.GetPadding);
end;

procedure TTestEVPCipherMock.TestGetPadding_ShouldReturnDefault;
begin
  // Assert (default is True)
  AssertTrue('Default padding should be enabled', FCipher.GetPadding);
end;

initialization
  RegisterTest(TTestEVPCipherMock);

end.

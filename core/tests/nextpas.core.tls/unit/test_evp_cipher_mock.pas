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
  nextpas.core.test,
  openssl_evp_cipher_interface, nextpas.core.base, nextpas.core.text.conv;

type
  { TTestEVPCipherMock - Test suite for EVP cipher mock }
  TTestEVPCipherMock = class(TTestFixture)
  private
    FCipher: IEVPCipher;
    FMock: TEVPCipherMock;

    function GetTestKey(aSize: Integer): TBytes;
    function GetTestIV(aSize: Integer): TBytes;
    function GetTestData(aSize: Integer): TBytes;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
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

procedure TTestEVPCipherMock.BeforeEach;
begin
  inherited BeforeEach;
  FMock := TEVPCipherMock.Create;
  FCipher := FMock as IEVPCipher;
end;

procedure TTestEVPCipherMock.AfterEach;
begin
  FCipher := nil;
  FMock := nil;
  inherited AfterEach;
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Output), 'Should have output');
  CheckEqual(1, FMock.GetEncryptCallCount, 'Encryption count');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckTrue(FMock.GetLastAlgorithm = caAES128, 'Algorithm should be AES128');
  CheckTrue(FMock.GetLastMode = cmECB, 'Mode should be ECB');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(64, Length(LResult.Output), 'Should have output');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckTrue(FMock.GetLastAlgorithm = caCamellia256, 'Algorithm should be Camellia256');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckTrue(FMock.GetLastAlgorithm = caSM4, 'Algorithm should be SM4');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Output), 'Should have output');
  CheckEqual(1, FMock.GetDecryptCallCount, 'Decrypt count');
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
  CheckTrue(LEncResult.Success, 'Encrypt should succeed');
  CheckTrue(LDecResult.Success, 'Decrypt should succeed');
  CheckEqual(Length(LPlaintext), Length(LDecResult.Output), 'Should restore plaintext length');

  // Verify roundtrip (mock uses XOR, so encrypt then decrypt should restore)
  for i := 0 to High(LPlaintext) do
    CheckEqual(LPlaintext[i], LDecResult.Output[i], 'Byte ' + IntToStr(i) + ' should match');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Output), 'Should have output');
  CheckEqual(1, FMock.GetAEADCallCount, 'AEAD count');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckTrue(Length(LResult.Tag) > 0, 'Should generate tag');
  CheckEqual(16, Length(LResult.Tag), 'Tag should be 16 bytes');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Output), 'Should have output');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckTrue(FMock.GetLastAlgorithm = caChaCha20Poly1305, 'Algorithm should be ChaCha20Poly1305');
  CheckTrue(Length(LResult.Tag) > 0, 'Should have tag');
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
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Simulated encryption failure', LResult.ErrorMessage, 'Error message');
  CheckEqual(0, Length(LResult.Output), 'Output should be empty');
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
  CheckFalse(LResult.Success, 'Should fail');
  CheckTrue(LResult.ErrorMessage <> '', 'Should have error message');
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
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual(0, Length(LResult.Tag), 'Tag should be empty on failure');
end;

{ Parameter validation tests }

procedure TTestEVPCipherMock.TestGetKeySize_ShouldReturnCorrectSize_ForAES128;
begin
  CheckEqual(16, FCipher.GetKeySize(caAES128), 'AES-128 key size');
end;

procedure TTestEVPCipherMock.TestGetKeySize_ShouldReturnCorrectSize_ForAES256;
begin
  CheckEqual(32, FCipher.GetKeySize(caAES256), 'AES-256 key size');
end;

procedure TTestEVPCipherMock.TestGetKeySize_ShouldReturnCorrectSize_ForChaCha20;
begin
  CheckEqual(32, FCipher.GetKeySize(caChaCha20), 'ChaCha20 key size');
end;

procedure TTestEVPCipherMock.TestGetIVSize_ShouldReturnZero_ForECBMode;
begin
  CheckEqual(0, FCipher.GetIVSize(caAES256, cmECB), 'ECB mode IV size');
end;

procedure TTestEVPCipherMock.TestGetIVSize_ShouldReturn12_ForGCMMode;
begin
  CheckEqual(12, FCipher.GetIVSize(caAES256, cmGCM), 'GCM mode IV size');
end;

procedure TTestEVPCipherMock.TestGetBlockSize_ShouldReturn16_ForAES;
begin
  CheckEqual(16, FCipher.GetBlockSize(caAES256), 'AES block size');
end;

procedure TTestEVPCipherMock.TestGetBlockSize_ShouldReturn1_ForChaCha20;
begin
  CheckEqual(1, FCipher.GetBlockSize(caChaCha20), 'ChaCha20 block size (stream)');
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
  CheckEqual(2, FMock.GetEncryptCallCount, 'Encrypt call count');
  CheckEqual(2, FCipher.GetOperationCount, 'Operation count');
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
  CheckEqual(1, FMock.GetDecryptCallCount, 'Decrypt call count');
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
  CheckEqual(1, FMock.GetAEADCallCount, 'AEAD call count');
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
  CheckEqual(0, FCipher.GetOperationCount, 'Operation count after reset');
  CheckEqual(0, FMock.GetEncryptCallCount, 'Encrypt count after reset');
  CheckEqual(0, FMock.GetDecryptCallCount, 'Decrypt count after reset');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Output), 'Custom output length');
  for i := 0 to 15 do
    CheckEqual($FF, LResult.Output[i], 'Custom byte ' + IntToStr(i));
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Tag), 'Custom tag length');
  for i := 0 to 15 do
    CheckEqual($DD, LResult.Tag[i], 'Custom tag byte ' + IntToStr(i));
end;

{ Padding tests }

procedure TTestEVPCipherMock.TestSetPadding_ShouldStoreValue;
begin
  // Act
  FCipher.SetPadding(False);

  // Assert
  CheckFalse(FCipher.GetPadding, 'Padding should be disabled');
end;

procedure TTestEVPCipherMock.TestGetPadding_ShouldReturnDefault;
begin
  // Assert (default is True)
  CheckTrue(FCipher.GetPadding, 'Default padding should be enabled');
end;

end.

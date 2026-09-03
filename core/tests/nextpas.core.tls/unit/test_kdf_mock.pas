unit test_kdf_mock;

{$mode objfpc}{$H+}

{
  KDF Mock Unit Tests

  Tests the mock implementation of Key Derivation Functions including:
  - PBKDF2 (Password-Based Key Derivation Function 2)
  - HKDF (HMAC-based Key Derivation Function)
  - Scrypt (Memory-hard KDF)
}

interface

uses
  nextpas.core.test,
  openssl_kdf_interface, nextpas.core.base, nextpas.core.text.conv;

type
  { TTestKDFMock - Test suite for KDF mock }
  TTestKDFMock = class(TTestFixture)
  private
    FKDF: IKDF;
    FMock: TKDFMock;

    function GetTestPassword(aSize: Integer): TBytes;
    function GetTestSalt(aSize: Integer): TBytes;
    function GetTestInfo(aSize: Integer): TBytes;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    // PBKDF2 tests
    procedure TestPBKDF2_ShouldSucceed_WithSHA256;
    procedure TestPBKDF2_ShouldSucceed_WithSHA512;
    procedure TestPBKDF2_ShouldSucceed_WithSHA1;
    procedure TestPBKDF2_ShouldReturnCorrectLength;
    procedure TestPBKDF2_ShouldFail_WithEmptyPassword;
    procedure TestPBKDF2_ShouldFail_WithZeroIterations;
    procedure TestPBKDF2_ShouldFail_WithNegativeKeyLength;
    procedure TestPBKDF2_ShouldBeDeterministic;

    // HKDF tests
    procedure TestHKDF_ShouldSucceed_WithSHA256;
    procedure TestHKDF_ShouldSucceed_WithSHA512;
    procedure TestHKDF_ShouldReturnCorrectLength;
    procedure TestHKDF_ShouldFail_WithEmptyInputKey;
    procedure TestHKDFExtract_ShouldReturnHashSize;
    procedure TestHKDFExpand_ShouldExpandPRK;

    // Scrypt tests
    procedure TestScrypt_ShouldSucceed_WithDefaultParams;
    procedure TestScrypt_ShouldSucceed_WithCustomParams;
    procedure TestScrypt_ShouldFail_WithZeroN;
    procedure TestScrypt_ShouldFail_WithZeroR;
    procedure TestScrypt_ShouldFail_WithZeroP;

    // Algorithm info tests
    procedure TestGetAlgorithmName_ShouldReturnCorrectName;
    procedure TestGetOutputSize_ShouldReturnCorrectSize;
    procedure TestIsAlgorithmSupported_ShouldReturnTrue;

    // Error handling tests
    procedure TestPBKDF2_ShouldFail_WhenConfigured;
    procedure TestHKDF_ShouldFail_WhenConfigured;
    procedure TestScrypt_ShouldFail_WhenConfigured;

    // Custom key tests
    procedure TestPBKDF2_ShouldUseCustomKey_WhenSet;
    procedure TestHKDF_ShouldUseCustomKey_WhenSet;

    // Statistics tests
    procedure TestStatistics_ShouldTrackCalls;
    procedure TestResetStatistics_ShouldClearCounters;
  end;

implementation

{ Helper methods }

function TTestKDFMock.GetTestPassword(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := Byte((i * 17 + 71) mod 256);
end;

function TTestKDFMock.GetTestSalt(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := Byte((i * 23 + 131) mod 256);
end;

function TTestKDFMock.GetTestInfo(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := Byte((i * 19 + 97) mod 256);
end;

{ Setup and teardown }

procedure TTestKDFMock.BeforeEach;
begin
  inherited BeforeEach;
  FMock := TKDFMock.Create;
  FKDF := FMock as IKDF;
end;

procedure TTestKDFMock.AfterEach;
begin
  FKDF := nil;
  FMock := nil;
  inherited AfterEach;
end;

{ PBKDF2 tests }

procedure TTestKDFMock.TestPBKDF2_ShouldSucceed_WithSHA256;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 32);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.DerivedKey), 'Should return 32 bytes');
  CheckEqual('', LResult.ErrorMessage, 'Error message should be empty');
end;

procedure TTestKDFMock.TestPBKDF2_ShouldSucceed_WithSHA512;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(20);
  LSalt := GetTestSalt(20);

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA512, LPassword, LSalt, 2000, 64);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(64, Length(LResult.DerivedKey), 'Should return 64 bytes');
end;

procedure TTestKDFMock.TestPBKDF2_ShouldSucceed_WithSHA1;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(10);
  LSalt := GetTestSalt(8);

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA1, LPassword, LSalt, 1000, 20);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(20, Length(LResult.DerivedKey), 'Should return 20 bytes');
end;

procedure TTestKDFMock.TestPBKDF2_ShouldReturnCorrectLength;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act - 请求48字节
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 48);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(48, Length(LResult.DerivedKey), 'Should return exactly 48 bytes');
end;

procedure TTestKDFMock.TestPBKDF2_ShouldFail_WithEmptyPassword;
var
  LResult: TKDFResult;
  LSalt: TBytes;
begin
  // Arrange
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA256, nil, LSalt, 1000, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Password cannot be empty', LResult.ErrorMessage, 'Should have error message');
end;

procedure TTestKDFMock.TestPBKDF2_ShouldFail_WithZeroIterations;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 0, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Iterations must be positive', LResult.ErrorMessage, 'Should have error message');
end;

procedure TTestKDFMock.TestPBKDF2_ShouldFail_WithNegativeKeyLength;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, -1);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Key length must be positive', LResult.ErrorMessage, 'Should have error message');
end;

procedure TTestKDFMock.TestPBKDF2_ShouldBeDeterministic;
var
  LResult1, LResult2: TKDFResult;
  LPassword, LSalt: TBytes;
  i: Integer;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult1 := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 32);
  LResult2 := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 32);

  // Assert
  CheckTrue(LResult1.Success, 'First call should succeed');
  CheckTrue(LResult2.Success, 'Second call should succeed');
  CheckEqual(Length(LResult1.DerivedKey), Length(LResult2.DerivedKey), 'Lengths should match');

  for i := 0 to High(LResult1.DerivedKey) do
    CheckEqual(LResult1.DerivedKey[i], LResult2.DerivedKey[i], 'Byte ' + IntToStr(i) + ' should match');
end;

{ HKDF tests }

procedure TTestKDFMock.TestHKDF_ShouldSucceed_WithSHA256;
var
  LResult: TKDFResult;
  LInputKey, LSalt, LInfo: TBytes;
begin
  // Arrange
  LInputKey := GetTestPassword(32);
  LSalt := GetTestSalt(16);
  LInfo := GetTestInfo(20);

  // Act
  LResult := FKDF.HKDF(kdHKDF_SHA256, LInputKey, LSalt, LInfo, 48);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(48, Length(LResult.DerivedKey), 'Should return 48 bytes');
end;

procedure TTestKDFMock.TestHKDF_ShouldSucceed_WithSHA512;
var
  LResult: TKDFResult;
  LInputKey, LSalt, LInfo: TBytes;
begin
  // Arrange
  LInputKey := GetTestPassword(64);
  LSalt := GetTestSalt(32);
  LInfo := GetTestInfo(30);

  // Act
  LResult := FKDF.HKDF(kdHKDF_SHA512, LInputKey, LSalt, LInfo, 64);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(64, Length(LResult.DerivedKey), 'Should return 64 bytes');
end;

procedure TTestKDFMock.TestHKDF_ShouldReturnCorrectLength;
var
  LResult: TKDFResult;
  LInputKey, LSalt, LInfo: TBytes;
begin
  // Arrange
  LInputKey := GetTestPassword(32);
  LSalt := GetTestSalt(16);
  LInfo := GetTestInfo(10);

  // Act - 请求128字节
  LResult := FKDF.HKDF(kdHKDF_SHA256, LInputKey, LSalt, LInfo, 128);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(128, Length(LResult.DerivedKey), 'Should return exactly 128 bytes');
end;

procedure TTestKDFMock.TestHKDF_ShouldFail_WithEmptyInputKey;
var
  LResult: TKDFResult;
  LSalt, LInfo: TBytes;
begin
  // Arrange
  LSalt := GetTestSalt(16);
  LInfo := GetTestInfo(20);

  // Act
  LResult := FKDF.HKDF(kdHKDF_SHA256, nil, LSalt, LInfo, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Input key cannot be empty', LResult.ErrorMessage, 'Should have error message');
end;

procedure TTestKDFMock.TestHKDFExtract_ShouldReturnHashSize;
var
  LResult: TKDFResult;
  LInputKey, LSalt: TBytes;
begin
  // Arrange
  LInputKey := GetTestPassword(32);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.HKDFExtract(kdHKDF_SHA256, LInputKey, LSalt);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.DerivedKey), 'Should return 32 bytes (SHA256 hash size)');
end;

procedure TTestKDFMock.TestHKDFExpand_ShouldExpandPRK;
var
  LExtractResult, LExpandResult: TKDFResult;
  LInputKey, LSalt, LInfo: TBytes;
begin
  // Arrange
  LInputKey := GetTestPassword(32);
  LSalt := GetTestSalt(16);
  LInfo := GetTestInfo(20);

  // Act - Extract phase
  LExtractResult := FKDF.HKDFExtract(kdHKDF_SHA256, LInputKey, LSalt);

  // Act - Expand phase
  LExpandResult := FKDF.HKDFExpand(kdHKDF_SHA256, LExtractResult.DerivedKey, LInfo, 64);

  // Assert
  CheckTrue(LExtractResult.Success, 'Extract should succeed');
  CheckTrue(LExpandResult.Success, 'Expand should succeed');
  CheckEqual(64, Length(LExpandResult.DerivedKey), 'Expand should return 64 bytes');
end;

{ Scrypt tests }

procedure TTestKDFMock.TestScrypt_ShouldSucceed_WithDefaultParams;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.Scrypt(LPassword, LSalt, 16384, 8, 1, 32);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.DerivedKey), 'Should return 32 bytes');
end;

procedure TTestKDFMock.TestScrypt_ShouldSucceed_WithCustomParams;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(20);
  LSalt := GetTestSalt(20);

  // Act - 使用较小的N值用于测试
  LResult := FKDF.Scrypt(LPassword, LSalt, 1024, 4, 2, 64);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(64, Length(LResult.DerivedKey), 'Should return 64 bytes');
end;

procedure TTestKDFMock.TestScrypt_ShouldFail_WithZeroN;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.Scrypt(LPassword, LSalt, 0, 8, 1, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('N parameter must be non-zero', LResult.ErrorMessage, 'Should have error message');
end;

procedure TTestKDFMock.TestScrypt_ShouldFail_WithZeroR;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.Scrypt(LPassword, LSalt, 1024, 0, 1, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('R parameter must be non-zero', LResult.ErrorMessage, 'Should have error message');
end;

procedure TTestKDFMock.TestScrypt_ShouldFail_WithZeroP;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);

  // Act
  LResult := FKDF.Scrypt(LPassword, LSalt, 1024, 8, 0, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('P parameter must be non-zero', LResult.ErrorMessage, 'Should have error message');
end;

{ Algorithm info tests }

procedure TTestKDFMock.TestGetAlgorithmName_ShouldReturnCorrectName;
begin
  CheckEqual('PBKDF2-SHA256', FKDF.GetAlgorithmName(kdPBKDF2_SHA256), 'PBKDF2-SHA256 name');
  CheckEqual('HKDF-SHA512', FKDF.GetAlgorithmName(kdHKDF_SHA512), 'HKDF-SHA512 name');
  CheckEqual('Scrypt', FKDF.GetAlgorithmName(kdScrypt), 'Scrypt name');
end;

procedure TTestKDFMock.TestGetOutputSize_ShouldReturnCorrectSize;
begin
  CheckEqual(20, FKDF.GetOutputSize(kdPBKDF2_SHA1), 'PBKDF2-SHA1 size');
  CheckEqual(32, FKDF.GetOutputSize(kdPBKDF2_SHA256), 'PBKDF2-SHA256 size');
  CheckEqual(64, FKDF.GetOutputSize(kdPBKDF2_SHA512), 'PBKDF2-SHA512 size');
  CheckEqual(32, FKDF.GetOutputSize(kdHKDF_SHA256), 'HKDF-SHA256 size');
  CheckEqual(64, FKDF.GetOutputSize(kdHKDF_SHA512), 'HKDF-SHA512 size');
  CheckEqual(32, FKDF.GetOutputSize(kdScrypt), 'Scrypt default size');
end;

procedure TTestKDFMock.TestIsAlgorithmSupported_ShouldReturnTrue;
begin
  CheckTrue(FKDF.IsAlgorithmSupported(kdPBKDF2_SHA256), 'PBKDF2-SHA256 should be supported');
  CheckTrue(FKDF.IsAlgorithmSupported(kdHKDF_SHA512), 'HKDF-SHA512 should be supported');
  CheckTrue(FKDF.IsAlgorithmSupported(kdScrypt), 'Scrypt should be supported');
end;

{ Error handling tests }

procedure TTestKDFMock.TestPBKDF2_ShouldFail_WhenConfigured;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);
  FMock.SetShouldFail(True, 'Simulated PBKDF2 failure');

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Simulated PBKDF2 failure', LResult.ErrorMessage, 'Error message');
  CheckEqual(0, Length(LResult.DerivedKey), 'Key should be empty');
end;

procedure TTestKDFMock.TestHKDF_ShouldFail_WhenConfigured;
var
  LResult: TKDFResult;
  LInputKey, LSalt, LInfo: TBytes;
begin
  // Arrange
  LInputKey := GetTestPassword(32);
  LSalt := GetTestSalt(16);
  LInfo := GetTestInfo(20);
  FMock.SetShouldFail(True, 'Simulated HKDF failure');

  // Act
  LResult := FKDF.HKDF(kdHKDF_SHA256, LInputKey, LSalt, LInfo, 48);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Simulated HKDF failure', LResult.ErrorMessage, 'Error message');
end;

procedure TTestKDFMock.TestScrypt_ShouldFail_WhenConfigured;
var
  LResult: TKDFResult;
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);
  FMock.SetShouldFail(True, 'Simulated Scrypt failure');

  // Act
  LResult := FKDF.Scrypt(LPassword, LSalt, 1024, 8, 1, 32);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Simulated Scrypt failure', LResult.ErrorMessage, 'Error message');
end;

{ Custom key tests }

procedure TTestKDFMock.TestPBKDF2_ShouldUseCustomKey_WhenSet;
var
  LResult: TKDFResult;
  LPassword, LSalt, LCustomKey: TBytes;
  i: Integer;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);
  SetLength(LCustomKey, 32);
  for i := 0 to 31 do
    LCustomKey[i] := $AA;
  FMock.SetCustomKey(LCustomKey);

  // Act
  LResult := FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 32);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  for i := 0 to 31 do
    CheckEqual($AA, LResult.DerivedKey[i], 'Byte ' + IntToStr(i) + ' should be $AA');
end;

procedure TTestKDFMock.TestHKDF_ShouldUseCustomKey_WhenSet;
var
  LResult: TKDFResult;
  LInputKey, LSalt, LInfo, LCustomKey: TBytes;
  i: Integer;
begin
  // Arrange
  LInputKey := GetTestPassword(32);
  LSalt := GetTestSalt(16);
  LInfo := GetTestInfo(20);
  SetLength(LCustomKey, 48);
  for i := 0 to 47 do
    LCustomKey[i] := $BB;
  FMock.SetCustomKey(LCustomKey);

  // Act
  LResult := FKDF.HKDF(kdHKDF_SHA256, LInputKey, LSalt, LInfo, 48);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  for i := 0 to 47 do
    CheckEqual($BB, LResult.DerivedKey[i], 'Byte ' + IntToStr(i) + ' should be $BB');
end;

{ Statistics tests }

procedure TTestKDFMock.TestStatistics_ShouldTrackCalls;
var
  LPassword, LSalt: TBytes;
  LInputKey, LInfo: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);
  LInputKey := GetTestPassword(32);
  LInfo := GetTestInfo(20);

  // Act
  FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 32);
  FKDF.PBKDF2(kdPBKDF2_SHA512, LPassword, LSalt, 2000, 64);
  FKDF.HKDF(kdHKDF_SHA256, LInputKey, LSalt, LInfo, 48);
  FKDF.Scrypt(LPassword, LSalt, 1024, 8, 1, 32);

  // Assert
  CheckEqual(4, FKDF.GetOperationCount, 'Operation count');
  CheckEqual(2, FKDF.GetPBKDF2CallCount, 'PBKDF2 call count');
  CheckEqual(1, FKDF.GetHKDFCallCount, 'HKDF call count');
  CheckEqual(1, FKDF.GetScryptCallCount, 'Scrypt call count');
end;

procedure TTestKDFMock.TestResetStatistics_ShouldClearCounters;
var
  LPassword, LSalt: TBytes;
begin
  // Arrange
  LPassword := GetTestPassword(16);
  LSalt := GetTestSalt(16);
  FKDF.PBKDF2(kdPBKDF2_SHA256, LPassword, LSalt, 1000, 32);
  FKDF.Scrypt(LPassword, LSalt, 1024, 8, 1, 32);

  // Act
  FKDF.ResetStatistics;

  // Assert
  CheckEqual(0, FKDF.GetOperationCount, 'Operation count after reset');
  CheckEqual(0, FKDF.GetPBKDF2CallCount, 'PBKDF2 call count after reset');
  CheckEqual(0, FKDF.GetHKDFCallCount, 'HKDF call count after reset');
  CheckEqual(0, FKDF.GetScryptCallCount, 'Scrypt call count after reset');
end;

end.

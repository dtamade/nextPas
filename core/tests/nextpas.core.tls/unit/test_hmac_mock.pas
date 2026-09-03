unit test_hmac_mock;

{$mode objfpc}{$H+}

{
  HMAC Mock Unit Tests

  Tests the mock implementation of HMAC operations including:
  - Single-shot HMAC computation
  - Incremental HMAC (Init/Update/Final)
  - MAC verification
  - Key management
  - Multiple hash algorithm combinations
}

interface

uses
  nextpas.core.test,
  openssl_hmac_interface, nextpas.core.base, nextpas.core.text.conv;

type
  { TTestHMACMock - Test suite for HMAC mock }
  TTestHMACMock = class(TTestFixture)
  private
    FHMAC: IHMAC;
    FMock: THMACMock;

    function GetTestKey(aSize: Integer): TBytes;
    function GetTestData(aSize: Integer): TBytes;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    // Single-shot HMAC tests
    procedure TestCompute_ShouldSucceed_WithSHA256;
    procedure TestCompute_ShouldSucceed_WithSHA512;
    procedure TestCompute_ShouldSucceed_WithSHA1;
    procedure TestCompute_ShouldSucceed_WithSM3;
    procedure TestCompute_ShouldReturnCorrectSize_ForAllAlgorithms;

    // Incremental HMAC tests
    procedure TestInit_ShouldReturnTrue_WhenSuccessful;
    procedure TestInit_ShouldStoreKey;
    procedure TestUpdate_ShouldReturnFalse_WhenNotInitialized;
    procedure TestUpdate_ShouldAccumulateData;
    procedure TestFinal_ShouldComputeMAC_FromAccumulatedData;
    procedure TestIncrementalEqualsOneShot;

    // Key management tests
    procedure TestSetKey_ShouldStoreKey;
    procedure TestGetKeySize_ShouldReturnCorrectSize;

    // Verification tests
    procedure TestVerify_ShouldReturnTrue_WithCorrectMAC;
    procedure TestVerify_ShouldReturnFalse_WithIncorrectMAC;

    // Error handling tests
    procedure TestCompute_ShouldFail_WhenConfigured;
    procedure TestInit_ShouldFail_WhenConfigured;

    // Algorithm queries
    procedure TestGetMACSize_ShouldReturnCorrectSize;
    procedure TestGetAlgorithmName_ShouldReturnCorrectName;

    // Statistics tracking
    procedure TestResetStatistics_ShouldClearCounters;
  end;

implementation

{ Helper methods }

function TTestHMACMock.GetTestKey(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := Byte((i * 11 + 73) mod 256);
end;

function TTestHMACMock.GetTestData(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := Byte((i * 13 + 97) mod 256);
end;

{ Setup and teardown }

procedure TTestHMACMock.BeforeEach;
begin
  inherited BeforeEach;
  FMock := THMACMock.Create;
  FHMAC := FMock as IHMAC;
end;

procedure TTestHMACMock.AfterEach;
begin
  FHMAC := nil;
  FMock := nil;
  inherited AfterEach;
end;

{ Single-shot HMAC tests }

procedure TTestHMACMock.TestCompute_ShouldSucceed_WithSHA256;
var
  LResult: THMACResult;
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);

  // Act
  LResult := FHMAC.Compute(haSHA256, LKey, LData);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.MAC), 'Should return 32 bytes');
  CheckEqual(1, FMock.GetComputeCallCount, 'Compute call count');
end;

procedure TTestHMACMock.TestCompute_ShouldSucceed_WithSHA512;
var
  LResult: THMACResult;
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(64);
  LData := GetTestData(128);

  // Act
  LResult := FHMAC.Compute(haSHA512, LKey, LData);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(64, Length(LResult.MAC), 'Should return 64 bytes');
end;

procedure TTestHMACMock.TestCompute_ShouldSucceed_WithSHA1;
var
  LResult: THMACResult;
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(20);
  LData := GetTestData(100);

  // Act
  LResult := FHMAC.Compute(haSHA1, LKey, LData);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(20, Length(LResult.MAC), 'Should return 20 bytes');
end;

procedure TTestHMACMock.TestCompute_ShouldSucceed_WithSM3;
var
  LResult: THMACResult;
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);

  // Act
  LResult := FHMAC.Compute(haSM3, LKey, LData);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.MAC), 'Should return 32 bytes (SM3)');
end;

procedure TTestHMACMock.TestCompute_ShouldReturnCorrectSize_ForAllAlgorithms;
var
  LResult: THMACResult;
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);

  // Act & Assert
  LResult := FHMAC.Compute(haMD5, LKey, LData);
  CheckEqual(16, Length(LResult.MAC), 'MD5 size');

  LResult := FHMAC.Compute(haSHA1, LKey, LData);
  CheckEqual(20, Length(LResult.MAC), 'SHA1 size');

  LResult := FHMAC.Compute(haSHA256, LKey, LData);
  CheckEqual(32, Length(LResult.MAC), 'SHA256 size');

  LResult := FHMAC.Compute(haSHA512, LKey, LData);
  CheckEqual(64, Length(LResult.MAC), 'SHA512 size');
end;

{ Incremental HMAC tests }

procedure TTestHMACMock.TestInit_ShouldReturnTrue_WhenSuccessful;
var
  LResult: Boolean;
  LKey: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);

  // Act
  LResult := FHMAC.Init(haSHA256, LKey);

  // Assert
  CheckTrue(LResult, 'Should return true');
  CheckTrue(FMock.IsInitialized, 'Should be initialized');
  CheckEqual(1, FMock.GetInitCallCount, 'Init call count');
end;

procedure TTestHMACMock.TestInit_ShouldStoreKey;
var
  LKey: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);

  // Act
  FHMAC.Init(haSHA256, LKey);

  // Assert
  CheckEqual(32, FHMAC.GetKeySize, 'Key size should be stored');
end;

procedure TTestHMACMock.TestUpdate_ShouldReturnFalse_WhenNotInitialized;
var
  LResult: Boolean;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);

  // Act (without Init)
  LResult := FHMAC.Update(LData);

  // Assert
  CheckFalse(LResult, 'Should return false when not initialized');
end;

procedure TTestHMACMock.TestUpdate_ShouldAccumulateData;
var
  LKey, LData1, LData2: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData1 := GetTestData(32);
  LData2 := GetTestData(48);
  FHMAC.Init(haSHA256, LKey);

  // Act
  FHMAC.Update(LData1);
  FHMAC.Update(LData2);

  // Assert
  CheckEqual(80, FMock.GetAccumulatedDataSize, 'Should accumulate data');
  CheckEqual(2, FHMAC.GetUpdateCount, 'Update count');
end;

procedure TTestHMACMock.TestFinal_ShouldComputeMAC_FromAccumulatedData;
var
  LResult: THMACResult;
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);
  FHMAC.Init(haSHA256, LKey);
  FHMAC.Update(LData);

  // Act
  LResult := FHMAC.Final;

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.MAC), 'Should return MAC');
  CheckEqual(1, FMock.GetFinalCallCount, 'Final call count');
  CheckFalse(FMock.IsInitialized, 'Should clear initialized state');
end;

procedure TTestHMACMock.TestIncrementalEqualsOneShot;
var
  LOneShotResult, LIncrementalResult: THMACResult;
  LKey, LData, LPart1, LPart2: TBytes;
  i: Integer;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(100);
  SetLength(LPart1, 50);
  SetLength(LPart2, 50);
  for i := 0 to 49 do
  begin
    LPart1[i] := LData[i];
    LPart2[i] := LData[50 + i];
  end;

  // Act - One-shot
  LOneShotResult := FHMAC.Compute(haSHA256, LKey, LData);

  // Act - Incremental
  FHMAC.Init(haSHA256, LKey);
  FHMAC.Update(LPart1);
  FHMAC.Update(LPart2);
  LIncrementalResult := FHMAC.Final;

  // Assert
  CheckTrue(LOneShotResult.Success, 'One-shot should succeed');
  CheckTrue(LIncrementalResult.Success, 'Incremental should succeed');
  CheckEqual(Length(LOneShotResult.MAC), Length(LIncrementalResult.MAC), 'MAC sizes should match');

  // Compare MACs byte by byte
  for i := 0 to High(LOneShotResult.MAC) do
    CheckEqual(LOneShotResult.MAC[i], LIncrementalResult.MAC[i], 'MAC byte ' + IntToStr(i) + ' should match');
end;

{ Key management tests }

procedure TTestHMACMock.TestSetKey_ShouldStoreKey;
var
  LKey: TBytes;
begin
  // Arrange
  LKey := GetTestKey(64);

  // Act
  FHMAC.SetKey(haSHA512, LKey);

  // Assert
  CheckEqual(64, FHMAC.GetKeySize, 'Key size should be stored');
end;

procedure TTestHMACMock.TestGetKeySize_ShouldReturnCorrectSize;
var
  LKey: TBytes;
begin
  // Arrange
  LKey := GetTestKey(48);
  FHMAC.SetKey(haSHA384, LKey);

  // Act & Assert
  CheckEqual(48, FHMAC.GetKeySize, 'Should return key size');
end;

{ Verification tests }

procedure TTestHMACMock.TestVerify_ShouldReturnTrue_WithCorrectMAC;
var
  LKey, LData: TBytes;
  LComputedMAC: THMACResult;
  LVerified: Boolean;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);
  LComputedMAC := FHMAC.Compute(haSHA256, LKey, LData);

  // Act
  LVerified := FHMAC.Verify(haSHA256, LKey, LData, LComputedMAC.MAC);

  // Assert
  CheckTrue(LVerified, 'Should verify correct MAC');
  CheckEqual(1, FMock.GetVerifyCallCount, 'Verify call count');
end;

procedure TTestHMACMock.TestVerify_ShouldReturnFalse_WithIncorrectMAC;
var
  LKey, LData, LWrongMAC: TBytes;
  LVerified: Boolean;
  i: Integer;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);
  SetLength(LWrongMAC, 32);
  for i := 0 to 31 do
    LWrongMAC[i] := $FF;

  // Act
  LVerified := FHMAC.Verify(haSHA256, LKey, LData, LWrongMAC);

  // Assert
  CheckFalse(LVerified, 'Should fail with incorrect MAC');
end;

{ Error handling tests }

procedure TTestHMACMock.TestCompute_ShouldFail_WhenConfigured;
var
  LResult: THMACResult;
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);
  FMock.SetShouldFail(True, 'Simulated HMAC failure');

  // Act
  LResult := FHMAC.Compute(haSHA256, LKey, LData);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Simulated HMAC failure', LResult.ErrorMessage, 'Error message');
  CheckEqual(0, Length(LResult.MAC), 'MAC should be empty');
end;

procedure TTestHMACMock.TestInit_ShouldFail_WhenConfigured;
var
  LResult: Boolean;
  LKey: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  FMock.SetShouldFail(True, 'Init failure');

  // Act
  LResult := FHMAC.Init(haSHA256, LKey);

  // Assert
  CheckFalse(LResult, 'Should fail');
  CheckFalse(FMock.IsInitialized, 'Should not be initialized');
end;

{ Algorithm queries }

procedure TTestHMACMock.TestGetMACSize_ShouldReturnCorrectSize;
begin
  CheckEqual(16, FHMAC.GetMACSize(haMD5), 'HMAC-MD5 size');
  CheckEqual(20, FHMAC.GetMACSize(haSHA1), 'HMAC-SHA1 size');
  CheckEqual(32, FHMAC.GetMACSize(haSHA256), 'HMAC-SHA256 size');
  CheckEqual(64, FHMAC.GetMACSize(haSHA512), 'HMAC-SHA512 size');
  CheckEqual(32, FHMAC.GetMACSize(haSM3), 'HMAC-SM3 size');
end;

procedure TTestHMACMock.TestGetAlgorithmName_ShouldReturnCorrectName;
begin
  CheckEqual('HMAC-SHA256', FHMAC.GetAlgorithmName(haSHA256), 'SHA256 name');
  CheckEqual('HMAC-SHA512', FHMAC.GetAlgorithmName(haSHA512), 'SHA512 name');
  CheckEqual('HMAC-SM3', FHMAC.GetAlgorithmName(haSM3), 'SM3 name');
end;

{ Statistics tracking }

procedure TTestHMACMock.TestResetStatistics_ShouldClearCounters;
var
  LKey, LData: TBytes;
begin
  // Arrange
  LKey := GetTestKey(32);
  LData := GetTestData(64);
  FHMAC.Compute(haSHA256, LKey, LData);
  FHMAC.Init(haSHA512, LKey);
  FHMAC.Update(LData);

  // Act
  FHMAC.ResetStatistics;

  // Assert
  CheckEqual(0, FHMAC.GetOperationCount, 'Operation count after reset');
  CheckEqual(0, FHMAC.GetUpdateCount, 'Update count after reset');
  CheckEqual(0, FMock.GetComputeCallCount, 'Compute call count after reset');
  CheckEqual(0, FMock.GetInitCallCount, 'Init call count after reset');
end;

end.

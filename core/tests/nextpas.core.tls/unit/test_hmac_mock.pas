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
  Classes, SysUtils, fpcunit, testregistry,
  openssl_hmac_interface;

type
  { TTestHMACMock - Test suite for HMAC mock }
  TTestHMACMock = class(TTestCase)
  private
    FHMAC: IHMAC;
    FMock: THMACMock;
    
    function GetTestKey(aSize: Integer): TBytes;
    function GetTestData(aSize: Integer): TBytes;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
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

procedure TTestHMACMock.SetUp;
begin
  inherited SetUp;
  FMock := THMACMock.Create;
  FHMAC := FMock as IHMAC;
end;

procedure TTestHMACMock.TearDown;
begin
  FHMAC := nil;
  FMock := nil;
  inherited TearDown;
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
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 32 bytes', 32, Length(LResult.MAC));
  AssertEquals('Compute call count', 1, FMock.GetComputeCallCount);
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
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 64 bytes', 64, Length(LResult.MAC));
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
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 20 bytes', 20, Length(LResult.MAC));
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
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 32 bytes (SM3)', 32, Length(LResult.MAC));
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
  AssertEquals('MD5 size', 16, Length(LResult.MAC));
  
  LResult := FHMAC.Compute(haSHA1, LKey, LData);
  AssertEquals('SHA1 size', 20, Length(LResult.MAC));
  
  LResult := FHMAC.Compute(haSHA256, LKey, LData);
  AssertEquals('SHA256 size', 32, Length(LResult.MAC));
  
  LResult := FHMAC.Compute(haSHA512, LKey, LData);
  AssertEquals('SHA512 size', 64, Length(LResult.MAC));
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
  AssertTrue('Should return true', LResult);
  AssertTrue('Should be initialized', FMock.IsInitialized);
  AssertEquals('Init call count', 1, FMock.GetInitCallCount);
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
  AssertEquals('Key size should be stored', 32, FHMAC.GetKeySize);
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
  AssertFalse('Should return false when not initialized', LResult);
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
  AssertEquals('Should accumulate data', 80, FMock.GetAccumulatedDataSize);
  AssertEquals('Update count', 2, FHMAC.GetUpdateCount);
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
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return MAC', 32, Length(LResult.MAC));
  AssertEquals('Final call count', 1, FMock.GetFinalCallCount);
  AssertFalse('Should clear initialized state', FMock.IsInitialized);
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
  AssertTrue('One-shot should succeed', LOneShotResult.Success);
  AssertTrue('Incremental should succeed', LIncrementalResult.Success);
  AssertEquals('MAC sizes should match', Length(LOneShotResult.MAC), Length(LIncrementalResult.MAC));
  
  // Compare MACs byte by byte
  for i := 0 to High(LOneShotResult.MAC) do
    AssertEquals('MAC byte ' + IntToStr(i) + ' should match',
                 LOneShotResult.MAC[i], LIncrementalResult.MAC[i]);
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
  AssertEquals('Key size should be stored', 64, FHMAC.GetKeySize);
end;

procedure TTestHMACMock.TestGetKeySize_ShouldReturnCorrectSize;
var
  LKey: TBytes;
begin
  // Arrange
  LKey := GetTestKey(48);
  FHMAC.SetKey(haSHA384, LKey);
  
  // Act & Assert
  AssertEquals('Should return key size', 48, FHMAC.GetKeySize);
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
  AssertTrue('Should verify correct MAC', LVerified);
  AssertEquals('Verify call count', 1, FMock.GetVerifyCallCount);
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
  AssertFalse('Should fail with incorrect MAC', LVerified);
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
  AssertFalse('Should fail', LResult.Success);
  AssertEquals('Error message', 'Simulated HMAC failure', LResult.ErrorMessage);
  AssertEquals('MAC should be empty', 0, Length(LResult.MAC));
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
  AssertFalse('Should fail', LResult);
  AssertFalse('Should not be initialized', FMock.IsInitialized);
end;

{ Algorithm queries }

procedure TTestHMACMock.TestGetMACSize_ShouldReturnCorrectSize;
begin
  AssertEquals('HMAC-MD5 size', 16, FHMAC.GetMACSize(haMD5));
  AssertEquals('HMAC-SHA1 size', 20, FHMAC.GetMACSize(haSHA1));
  AssertEquals('HMAC-SHA256 size', 32, FHMAC.GetMACSize(haSHA256));
  AssertEquals('HMAC-SHA512 size', 64, FHMAC.GetMACSize(haSHA512));
  AssertEquals('HMAC-SM3 size', 32, FHMAC.GetMACSize(haSM3));
end;

procedure TTestHMACMock.TestGetAlgorithmName_ShouldReturnCorrectName;
begin
  AssertEquals('SHA256 name', 'HMAC-SHA256', FHMAC.GetAlgorithmName(haSHA256));
  AssertEquals('SHA512 name', 'HMAC-SHA512', FHMAC.GetAlgorithmName(haSHA512));
  AssertEquals('SM3 name', 'HMAC-SM3', FHMAC.GetAlgorithmName(haSM3));
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
  AssertEquals('Operation count after reset', 0, FHMAC.GetOperationCount);
  AssertEquals('Update count after reset', 0, FHMAC.GetUpdateCount);
  AssertEquals('Compute call count after reset', 0, FMock.GetComputeCallCount);
  AssertEquals('Init call count after reset', 0, FMock.GetInitCallCount);
end;

initialization
  RegisterTest(TTestHMACMock);

end.

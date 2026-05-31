unit test_evp_digest_mock;

{$mode objfpc}{$H+}

{
  EVP Digest Mock Unit Tests
  
  Tests the mock implementation of EVP digest operations including:
  - Single-shot hashing for multiple algorithms
  - Incremental hashing (Init/Update/Final)
  - Parameter validation
  - Error handling
  - Statistics tracking
}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  openssl_evp_digest_interface;

type
  { TTestEVPDigestMock - Test suite for EVP digest mock }
  TTestEVPDigestMock = class(TTestCase)
  private
    FDigest: IEVPDigest;
    FMock: TEVPDigestMock;
    
    function GetTestData(aSize: Integer): TBytes;
    function BytesToHex(const aBytes: TBytes): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // Single-shot digest tests
    procedure TestDigest_ShouldSucceed_WithSHA256;
    procedure TestDigest_ShouldSucceed_WithSHA512;
    procedure TestDigest_ShouldSucceed_WithMD5;
    procedure TestDigest_ShouldSucceed_WithBLAKE2b512;
    procedure TestDigest_ShouldSucceed_WithSM3;
    procedure TestDigest_ShouldSucceed_WithSHA3_256;
    procedure TestDigest_ShouldReturnCorrectSize_ForAllAlgorithms;
    
    // Empty data tests
    procedure TestDigest_ShouldSucceed_WithEmptyData;
    
    // Incremental digest tests
    procedure TestDigestInit_ShouldReturnTrue_WhenSuccessful;
    procedure TestDigestInit_ShouldSetInitializedState;
    procedure TestDigestUpdate_ShouldReturnFalse_WhenNotInitialized;
    procedure TestDigestUpdate_ShouldReturnTrue_WhenInitialized;
    procedure TestDigestUpdate_ShouldAccumulateData;
    procedure TestDigestFinal_ShouldReturnFalse_WhenNotInitialized;
    procedure TestDigestFinal_ShouldComputeHash_FromAccumulatedData;
    procedure TestDigestIncrementalEqualsOneShot;
    
    // Error handling tests
    procedure TestDigest_ShouldFail_WhenConfigured;
    procedure TestDigestInit_ShouldFail_WhenConfigured;
    procedure TestDigestUpdate_ShouldFail_WhenConfigured;
    
    // Algorithm queries
    procedure TestGetDigestSize_ShouldReturnCorrectSize_ForSHA256;
    procedure TestGetDigestSize_ShouldReturnCorrectSize_ForSHA512;
    procedure TestGetBlockSize_ShouldReturnCorrectSize_ForSHA256;
    procedure TestGetAlgorithmName_ShouldReturnCorrectName;
    
    // Statistics tracking
    procedure TestDigest_ShouldIncrementOperationCount;
    procedure TestDigestUpdate_ShouldIncrementUpdateCount;
    procedure TestResetStatistics_ShouldClearCounters;
    
    // Custom hash injection
    procedure TestDigest_ShouldUseCustomHash_WhenSet;
  end;

implementation

{ Helper methods }

function TTestEVPDigestMock.GetTestData(aSize: Integer): TBytes;
var
  i: Integer;
begin
  SetLength(Result, aSize);
  for i := 0 to aSize - 1 do
    Result[i] := Byte((i * 7 + 42) mod 256);
end;

function TTestEVPDigestMock.BytesToHex(const aBytes: TBytes): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(aBytes) do
    Result := Result + IntToHex(aBytes[i], 2);
end;

{ Setup and teardown }

procedure TTestEVPDigestMock.SetUp;
begin
  inherited SetUp;
  FMock := TEVPDigestMock.Create;
  FDigest := FMock as IEVPDigest;
end;

procedure TTestEVPDigestMock.TearDown;
begin
  FDigest := nil;
  FMock := nil;
  inherited TearDown;
end;

{ Single-shot digest tests }

procedure TTestEVPDigestMock.TestDigest_ShouldSucceed_WithSHA256;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  
  // Act
  LResult := FDigest.Digest(daSHA256, LData);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 32 bytes', 32, Length(LResult.Hash));
  AssertEquals('Digest call count', 1, FMock.GetDigestCallCount);
  AssertTrue('Last algorithm should be SHA256', FMock.GetLastAlgorithm = daSHA256);
end;

procedure TTestEVPDigestMock.TestDigest_ShouldSucceed_WithSHA512;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(128);
  
  // Act
  LResult := FDigest.Digest(daSHA512, LData);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 64 bytes', 64, Length(LResult.Hash));
end;

procedure TTestEVPDigestMock.TestDigest_ShouldSucceed_WithMD5;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(32);
  
  // Act
  LResult := FDigest.Digest(daMD5, LData);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 16 bytes', 16, Length(LResult.Hash));
end;

procedure TTestEVPDigestMock.TestDigest_ShouldSucceed_WithBLAKE2b512;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(100);
  
  // Act
  LResult := FDigest.Digest(daBLAKE2b512, LData);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 64 bytes', 64, Length(LResult.Hash));
end;

procedure TTestEVPDigestMock.TestDigest_ShouldSucceed_WithSM3;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  
  // Act
  LResult := FDigest.Digest(daSM3, LData);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 32 bytes (SM3)', 32, Length(LResult.Hash));
end;

procedure TTestEVPDigestMock.TestDigest_ShouldSucceed_WithSHA3_256;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  
  // Act
  LResult := FDigest.Digest(daSHA3_256, LData);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 32 bytes (SHA3-256)', 32, Length(LResult.Hash));
end;

procedure TTestEVPDigestMock.TestDigest_ShouldReturnCorrectSize_ForAllAlgorithms;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  
  // Act & Assert - Test multiple algorithms
  LResult := FDigest.Digest(daMD5, LData);
  AssertEquals('MD5 size', 16, Length(LResult.Hash));
  
  LResult := FDigest.Digest(daSHA1, LData);
  AssertEquals('SHA1 size', 20, Length(LResult.Hash));
  
  LResult := FDigest.Digest(daSHA224, LData);
  AssertEquals('SHA224 size', 28, Length(LResult.Hash));
  
  LResult := FDigest.Digest(daSHA256, LData);
  AssertEquals('SHA256 size', 32, Length(LResult.Hash));
  
  LResult := FDigest.Digest(daSHA384, LData);
  AssertEquals('SHA384 size', 48, Length(LResult.Hash));
  
  LResult := FDigest.Digest(daSHA512, LData);
  AssertEquals('SHA512 size', 64, Length(LResult.Hash));
end;

{ Empty data tests }

procedure TTestEVPDigestMock.TestDigest_ShouldSucceed_WithEmptyData;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  SetLength(LData, 0);
  
  // Act
  LResult := FDigest.Digest(daSHA256, LData);
  
  // Assert
  AssertTrue('Should succeed with empty data', LResult.Success);
  AssertEquals('Should still return hash', 32, Length(LResult.Hash));
  AssertEquals('Last data size should be 0', 0, FMock.GetLastDataSize);
end;

{ Incremental digest tests }

procedure TTestEVPDigestMock.TestDigestInit_ShouldReturnTrue_WhenSuccessful;
var
  LResult: Boolean;
begin
  // Act
  LResult := FDigest.DigestInit(daSHA256);
  
  // Assert
  AssertTrue('Should return true', LResult);
  AssertEquals('Init call count', 1, FMock.GetInitCallCount);
end;

procedure TTestEVPDigestMock.TestDigestInit_ShouldSetInitializedState;
begin
  // Act
  FDigest.DigestInit(daSHA256);
  
  // Assert
  AssertTrue('Should be initialized', FMock.IsInitialized);
end;

procedure TTestEVPDigestMock.TestDigestUpdate_ShouldReturnFalse_WhenNotInitialized;
var
  LResult: Boolean;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(32);
  
  // Act (without Init)
  LResult := FDigest.DigestUpdate(LData);
  
  // Assert
  AssertFalse('Should return false when not initialized', LResult);
end;

procedure TTestEVPDigestMock.TestDigestUpdate_ShouldReturnTrue_WhenInitialized;
var
  LResult: Boolean;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(32);
  FDigest.DigestInit(daSHA256);
  
  // Act
  LResult := FDigest.DigestUpdate(LData);
  
  // Assert
  AssertTrue('Should return true when initialized', LResult);
  AssertEquals('Update count', 1, FDigest.GetUpdateCount);
end;

procedure TTestEVPDigestMock.TestDigestUpdate_ShouldAccumulateData;
var
  LData1, LData2: TBytes;
begin
  // Arrange
  LData1 := GetTestData(32);
  LData2 := GetTestData(48);
  FDigest.DigestInit(daSHA256);
  
  // Act
  FDigest.DigestUpdate(LData1);
  FDigest.DigestUpdate(LData2);
  
  // Assert
  AssertEquals('Should accumulate data', 80, FMock.GetAccumulatedDataSize);
  AssertEquals('Update count', 2, FDigest.GetUpdateCount);
end;

procedure TTestEVPDigestMock.TestDigestFinal_ShouldReturnFalse_WhenNotInitialized;
var
  LResult: TDigestResult;
begin
  // Act (without Init)
  LResult := FDigest.DigestFinal;
  
  // Assert
  AssertFalse('Should return false when not initialized', LResult.Success);
end;

procedure TTestEVPDigestMock.TestDigestFinal_ShouldComputeHash_FromAccumulatedData;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  FDigest.DigestInit(daSHA256);
  FDigest.DigestUpdate(LData);
  
  // Act
  LResult := FDigest.DigestFinal;
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return hash', 32, Length(LResult.Hash));
  AssertEquals('Final call count', 1, FMock.GetFinalCallCount);
  AssertFalse('Should clear initialized state', FMock.IsInitialized);
end;

procedure TTestEVPDigestMock.TestDigestIncrementalEqualsOneShot;
var
  LOneShotResult, LIncrementalResult: TDigestResult;
  LData, LPart1, LPart2: TBytes;
  i: Integer;
begin
  // Arrange
  LData := GetTestData(100);
  SetLength(LPart1, 50);
  SetLength(LPart2, 50);
  for i := 0 to 49 do
  begin
    LPart1[i] := LData[i];
    LPart2[i] := LData[50 + i];
  end;
  
  // Act - One-shot
  LOneShotResult := FDigest.Digest(daSHA256, LData);
  
  // Act - Incremental
  FDigest.DigestInit(daSHA256);
  FDigest.DigestUpdate(LPart1);
  FDigest.DigestUpdate(LPart2);
  LIncrementalResult := FDigest.DigestFinal;
  
  // Assert - Both should produce same hash
  AssertTrue('One-shot should succeed', LOneShotResult.Success);
  AssertTrue('Incremental should succeed', LIncrementalResult.Success);
  AssertEquals('Hash sizes should match', Length(LOneShotResult.Hash), Length(LIncrementalResult.Hash));
  
  // Compare hashes byte by byte
  for i := 0 to High(LOneShotResult.Hash) do
    AssertEquals('Hash byte ' + IntToStr(i) + ' should match', 
                 LOneShotResult.Hash[i], LIncrementalResult.Hash[i]);
end;

{ Error handling tests }

procedure TTestEVPDigestMock.TestDigest_ShouldFail_WhenConfigured;
var
  LResult: TDigestResult;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  FMock.SetShouldFail(True, 'Simulated digest failure');
  
  // Act
  LResult := FDigest.Digest(daSHA256, LData);
  
  // Assert
  AssertFalse('Should fail', LResult.Success);
  AssertEquals('Error message', 'Simulated digest failure', LResult.ErrorMessage);
  AssertEquals('Hash should be empty', 0, Length(LResult.Hash));
end;

procedure TTestEVPDigestMock.TestDigestInit_ShouldFail_WhenConfigured;
var
  LResult: Boolean;
begin
  // Arrange
  FMock.SetShouldFail(True, 'Init failure');
  
  // Act
  LResult := FDigest.DigestInit(daSHA256);
  
  // Assert
  AssertFalse('Should fail', LResult);
  AssertFalse('Should not be initialized', FMock.IsInitialized);
end;

procedure TTestEVPDigestMock.TestDigestUpdate_ShouldFail_WhenConfigured;
var
  LResult: Boolean;
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(32);
  FDigest.DigestInit(daSHA256);
  FMock.SetShouldFail(True, 'Update failure');
  
  // Act
  LResult := FDigest.DigestUpdate(LData);
  
  // Assert
  AssertFalse('Should fail', LResult);
end;

{ Algorithm queries }

procedure TTestEVPDigestMock.TestGetDigestSize_ShouldReturnCorrectSize_ForSHA256;
begin
  AssertEquals('SHA-256 digest size', 32, FDigest.GetDigestSize(daSHA256));
end;

procedure TTestEVPDigestMock.TestGetDigestSize_ShouldReturnCorrectSize_ForSHA512;
begin
  AssertEquals('SHA-512 digest size', 64, FDigest.GetDigestSize(daSHA512));
end;

procedure TTestEVPDigestMock.TestGetBlockSize_ShouldReturnCorrectSize_ForSHA256;
begin
  AssertEquals('SHA-256 block size', 64, FDigest.GetBlockSize(daSHA256));
end;

procedure TTestEVPDigestMock.TestGetAlgorithmName_ShouldReturnCorrectName;
begin
  AssertEquals('SHA-256 name', 'SHA-256', FDigest.GetAlgorithmName(daSHA256));
  AssertEquals('SHA-512 name', 'SHA-512', FDigest.GetAlgorithmName(daSHA512));
  AssertEquals('MD5 name', 'MD5', FDigest.GetAlgorithmName(daMD5));
  AssertEquals('BLAKE2b-512 name', 'BLAKE2b-512', FDigest.GetAlgorithmName(daBLAKE2b512));
  AssertEquals('SM3 name', 'SM3', FDigest.GetAlgorithmName(daSM3));
end;

{ Statistics tracking }

procedure TTestEVPDigestMock.TestDigest_ShouldIncrementOperationCount;
var
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  
  // Act
  FDigest.Digest(daSHA256, LData);
  FDigest.Digest(daSHA512, LData);
  
  // Assert
  AssertEquals('Operation count', 2, FDigest.GetOperationCount);
  AssertEquals('Digest call count', 2, FMock.GetDigestCallCount);
end;

procedure TTestEVPDigestMock.TestDigestUpdate_ShouldIncrementUpdateCount;
var
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(32);
  FDigest.DigestInit(daSHA256);
  
  // Act
  FDigest.DigestUpdate(LData);
  FDigest.DigestUpdate(LData);
  FDigest.DigestUpdate(LData);
  
  // Assert
  AssertEquals('Update count', 3, FDigest.GetUpdateCount);
end;

procedure TTestEVPDigestMock.TestResetStatistics_ShouldClearCounters;
var
  LData: TBytes;
begin
  // Arrange
  LData := GetTestData(64);
  FDigest.Digest(daSHA256, LData);
  FDigest.DigestInit(daSHA512);
  FDigest.DigestUpdate(LData);
  
  // Act
  FDigest.ResetStatistics;
  
  // Assert
  AssertEquals('Operation count after reset', 0, FDigest.GetOperationCount);
  AssertEquals('Update count after reset', 0, FDigest.GetUpdateCount);
  AssertEquals('Digest call count after reset', 0, FMock.GetDigestCallCount);
  AssertEquals('Init call count after reset', 0, FMock.GetInitCallCount);
end;

{ Custom hash injection }

procedure TTestEVPDigestMock.TestDigest_ShouldUseCustomHash_WhenSet;
var
  LResult: TDigestResult;
  LData, LCustomHash: TBytes;
  i: Integer;
begin
  // Arrange
  LData := GetTestData(64);
  SetLength(LCustomHash, 32);
  for i := 0 to 31 do
    LCustomHash[i] := $FF;
  FMock.SetCustomHash(LCustomHash);
  
  // Act
  LResult := FDigest.Digest(daSHA256, LData);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Custom hash length', 32, Length(LResult.Hash));
  for i := 0 to 31 do
    AssertEquals('Custom hash byte ' + IntToStr(i), $FF, LResult.Hash[i]);
end;

initialization
  RegisterTest(TTestEVPDigestMock);

end.

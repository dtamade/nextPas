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
  nextpas.core.test,
  openssl_evp_digest_interface, nextpas.core.base, nextpas.core.text.conv;

type
  { TTestEVPDigestMock - Test suite for EVP digest mock }
  TTestEVPDigestMock = class(TTestFixture)
  private
    FDigest: IEVPDigest;
    FMock: TEVPDigestMock;

    function GetTestData(aSize: Integer): TBytes;
    function BytesToHex(const aBytes: TBytes): string;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
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

procedure TTestEVPDigestMock.BeforeEach;
begin
  inherited BeforeEach;
  FMock := TEVPDigestMock.Create;
  FDigest := FMock as IEVPDigest;
end;

procedure TTestEVPDigestMock.AfterEach;
begin
  FDigest := nil;
  FMock := nil;
  inherited AfterEach;
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.Hash), 'Should return 32 bytes');
  CheckEqual(1, FMock.GetDigestCallCount, 'Digest call count');
  CheckTrue(FMock.GetLastAlgorithm = daSHA256, 'Last algorithm should be SHA256');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(64, Length(LResult.Hash), 'Should return 64 bytes');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Hash), 'Should return 16 bytes');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(64, Length(LResult.Hash), 'Should return 64 bytes');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.Hash), 'Should return 32 bytes (SM3)');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.Hash), 'Should return 32 bytes (SHA3-256)');
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
  CheckEqual(16, Length(LResult.Hash), 'MD5 size');

  LResult := FDigest.Digest(daSHA1, LData);
  CheckEqual(20, Length(LResult.Hash), 'SHA1 size');

  LResult := FDigest.Digest(daSHA224, LData);
  CheckEqual(28, Length(LResult.Hash), 'SHA224 size');

  LResult := FDigest.Digest(daSHA256, LData);
  CheckEqual(32, Length(LResult.Hash), 'SHA256 size');

  LResult := FDigest.Digest(daSHA384, LData);
  CheckEqual(48, Length(LResult.Hash), 'SHA384 size');

  LResult := FDigest.Digest(daSHA512, LData);
  CheckEqual(64, Length(LResult.Hash), 'SHA512 size');
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
  CheckTrue(LResult.Success, 'Should succeed with empty data');
  CheckEqual(32, Length(LResult.Hash), 'Should still return hash');
  CheckEqual(0, FMock.GetLastDataSize, 'Last data size should be 0');
end;

{ Incremental digest tests }

procedure TTestEVPDigestMock.TestDigestInit_ShouldReturnTrue_WhenSuccessful;
var
  LResult: Boolean;
begin
  // Act
  LResult := FDigest.DigestInit(daSHA256);

  // Assert
  CheckTrue(LResult, 'Should return true');
  CheckEqual(1, FMock.GetInitCallCount, 'Init call count');
end;

procedure TTestEVPDigestMock.TestDigestInit_ShouldSetInitializedState;
begin
  // Act
  FDigest.DigestInit(daSHA256);

  // Assert
  CheckTrue(FMock.IsInitialized, 'Should be initialized');
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
  CheckFalse(LResult, 'Should return false when not initialized');
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
  CheckTrue(LResult, 'Should return true when initialized');
  CheckEqual(1, FDigest.GetUpdateCount, 'Update count');
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
  CheckEqual(80, FMock.GetAccumulatedDataSize, 'Should accumulate data');
  CheckEqual(2, FDigest.GetUpdateCount, 'Update count');
end;

procedure TTestEVPDigestMock.TestDigestFinal_ShouldReturnFalse_WhenNotInitialized;
var
  LResult: TDigestResult;
begin
  // Act (without Init)
  LResult := FDigest.DigestFinal;

  // Assert
  CheckFalse(LResult.Success, 'Should return false when not initialized');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.Hash), 'Should return hash');
  CheckEqual(1, FMock.GetFinalCallCount, 'Final call count');
  CheckFalse(FMock.IsInitialized, 'Should clear initialized state');
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
  CheckTrue(LOneShotResult.Success, 'One-shot should succeed');
  CheckTrue(LIncrementalResult.Success, 'Incremental should succeed');
  CheckEqual(Length(LOneShotResult.Hash), Length(LIncrementalResult.Hash), 'Hash sizes should match');

  // Compare hashes byte by byte
  for i := 0 to High(LOneShotResult.Hash) do
    CheckEqual(LOneShotResult.Hash[i], LIncrementalResult.Hash[i], 'Hash byte ' + IntToStr(i) + ' should match');
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
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Simulated digest failure', LResult.ErrorMessage, 'Error message');
  CheckEqual(0, Length(LResult.Hash), 'Hash should be empty');
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
  CheckFalse(LResult, 'Should fail');
  CheckFalse(FMock.IsInitialized, 'Should not be initialized');
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
  CheckFalse(LResult, 'Should fail');
end;

{ Algorithm queries }

procedure TTestEVPDigestMock.TestGetDigestSize_ShouldReturnCorrectSize_ForSHA256;
begin
  CheckEqual(32, FDigest.GetDigestSize(daSHA256), 'SHA-256 digest size');
end;

procedure TTestEVPDigestMock.TestGetDigestSize_ShouldReturnCorrectSize_ForSHA512;
begin
  CheckEqual(64, FDigest.GetDigestSize(daSHA512), 'SHA-512 digest size');
end;

procedure TTestEVPDigestMock.TestGetBlockSize_ShouldReturnCorrectSize_ForSHA256;
begin
  CheckEqual(64, FDigest.GetBlockSize(daSHA256), 'SHA-256 block size');
end;

procedure TTestEVPDigestMock.TestGetAlgorithmName_ShouldReturnCorrectName;
begin
  CheckEqual('SHA-256', FDigest.GetAlgorithmName(daSHA256), 'SHA-256 name');
  CheckEqual('SHA-512', FDigest.GetAlgorithmName(daSHA512), 'SHA-512 name');
  CheckEqual('MD5', FDigest.GetAlgorithmName(daMD5), 'MD5 name');
  CheckEqual('BLAKE2b-512', FDigest.GetAlgorithmName(daBLAKE2b512), 'BLAKE2b-512 name');
  CheckEqual('SM3', FDigest.GetAlgorithmName(daSM3), 'SM3 name');
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
  CheckEqual(2, FDigest.GetOperationCount, 'Operation count');
  CheckEqual(2, FMock.GetDigestCallCount, 'Digest call count');
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
  CheckEqual(3, FDigest.GetUpdateCount, 'Update count');
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
  CheckEqual(0, FDigest.GetOperationCount, 'Operation count after reset');
  CheckEqual(0, FDigest.GetUpdateCount, 'Update count after reset');
  CheckEqual(0, FMock.GetDigestCallCount, 'Digest call count after reset');
  CheckEqual(0, FMock.GetInitCallCount, 'Init call count after reset');
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
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(32, Length(LResult.Hash), 'Custom hash length');
  for i := 0 to 31 do
    CheckEqual($FF, LResult.Hash[i], 'Custom hash byte ' + IntToStr(i));
end;

end.

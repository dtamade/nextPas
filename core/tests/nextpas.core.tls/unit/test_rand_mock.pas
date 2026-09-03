unit test_rand_mock;

{$mode objfpc}{$H+}

{
  Random Number Generator Mock Unit Tests

  Tests the mock implementation of random number generation including:
  - Byte generation (deterministic and pseudo-random)
  - Integer and float generation
  - Seeding control
  - Mode switching
}

interface

uses
  nextpas.core.test,
  openssl_rand_interface, nextpas.core.base, nextpas.core.text, nextpas.core.text.conv, nextpas.core.time;

type
  { TTestRandomMock - Test suite for Random mock }
  TTestRandomMock = class(TTestFixture)
  private
    FRandom: IRandom;
    FMock: TRandomMock;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
  published
    // Basic generation tests
    procedure TestGenerateBytes_ShouldSucceed_WithValidLength;
    procedure TestGenerateBytes_ShouldReturnEmptyArray_WithZeroLength;
    procedure TestGenerateBytes_ShouldFail_WithNegativeLength;
    procedure TestGenerateBytes_ShouldIncrementStatistics;

    // Deterministic mode tests
    procedure TestDeterministicMode_ShouldProduceSameSequence;
    procedure TestDeterministicMode_ShouldUseCustomSequence;
    procedure TestDeterministicMode_ShouldWrapAroundSequence;

    // Pseudo-random mode tests
    procedure TestPseudoRandomMode_ShouldProduceDifferentBytes;
    procedure TestPseudoRandomMode_WithSameSeed_ShouldProduceSameSequence;
    procedure TestPseudoRandomMode_WithDifferentSeed_ShouldProduceDifferentSequence;

    // Integer generation tests
    procedure TestGenerateInteger_ShouldReturnValueInRange;
    procedure TestGenerateInteger_ShouldReturnZero_WithZeroMax;
    procedure TestGenerateInteger_ShouldBeDeterministic_WithSameSeed;

    // Float generation tests
    procedure TestGenerateFloat_ShouldReturnValueBetweenZeroAndOne;
    procedure TestGenerateFloat_ShouldBeDeterministic_WithSameSeed;

    // Seeding tests
    procedure TestSetSeed_ShouldChangeSequence;
    procedure TestGetSeed_ShouldReturnSetSeed;
    procedure TestReseed_ShouldChangeSequence;
    procedure TestIsSeeded_ShouldReturnTrue_AfterSetSeed;

    // Mode tests
    procedure TestSetMode_ShouldSwitchMode;
    procedure TestGetMode_ShouldReturnCurrentMode;
    procedure TestSetDeterministicSequence_ShouldSwitchToDeterministicMode;

    // Status tests
    procedure TestGetStatus_ShouldReturnCorrectStatus;

    // Error handling tests
    procedure TestGenerateBytes_ShouldFail_WhenConfigured;

    // Statistics tests
    procedure TestStatistics_ShouldTrackBytesGenerated;
    procedure TestStatistics_ShouldTrackCallCount;
    procedure TestResetStatistics_ShouldClearCounters;
  end;

implementation

{ Setup and teardown }

procedure TTestRandomMock.BeforeEach;
begin
  inherited BeforeEach;
  FMock := TRandomMock.Create;
  FRandom := FMock as IRandom;
end;

procedure TTestRandomMock.AfterEach;
begin
  FRandom := nil;
  FMock := nil;
  inherited AfterEach;
end;

{ Basic generation tests }

procedure TTestRandomMock.TestGenerateBytes_ShouldSucceed_WithValidLength;
var
  LResult: TRandomResult;
begin
  // Act
  LResult := FRandom.GenerateBytes(16);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(16, Length(LResult.Data), 'Should return 16 bytes');
  CheckEqual('', LResult.ErrorMessage, 'Error message should be empty');
end;

procedure TTestRandomMock.TestGenerateBytes_ShouldReturnEmptyArray_WithZeroLength;
var
  LResult: TRandomResult;
begin
  // Act
  LResult := FRandom.GenerateBytes(0);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual(0, Length(LResult.Data), 'Should return empty array');
end;

procedure TTestRandomMock.TestGenerateBytes_ShouldFail_WithNegativeLength;
var
  LResult: TRandomResult;
begin
  // Act
  LResult := FRandom.GenerateBytes(-1);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Length cannot be negative', LResult.ErrorMessage, 'Should have error message');
end;

procedure TTestRandomMock.TestGenerateBytes_ShouldIncrementStatistics;
var
  LInitialCallCount: Integer;
begin
  // Arrange
  LInitialCallCount := FRandom.GetGenerateCallCount;

  // Act
  FRandom.GenerateBytes(10);
  FRandom.GenerateBytes(20);

  // Assert
  CheckEqual(LInitialCallCount + 2, FRandom.GetGenerateCallCount, 'Call count should increase');
  CheckEqual(30, FRandom.GetBytesGeneratedCount, 'Bytes generated should be 30');
end;

{ Deterministic mode tests }

procedure TTestRandomMock.TestDeterministicMode_ShouldProduceSameSequence;
var
  LResult1, LResult2: TRandomResult;
  i: Integer;
begin
  // Arrange
  FRandom.SetMode(rmDeterministic);
  FRandom.SetSeed(12345);

  // Act
  LResult1 := FRandom.GenerateBytes(32);

  // Reset and generate again with same seed
  FRandom.SetSeed(12345);
  LResult2 := FRandom.GenerateBytes(32);

  // Assert
  CheckTrue(LResult1.Success, 'First generation should succeed');
  CheckTrue(LResult2.Success, 'Second generation should succeed');

  for i := 0 to 31 do
    CheckEqual(LResult1.Data[i], LResult2.Data[i], 'Byte ' + IntToStr(i) + ' should match');
end;

procedure TTestRandomMock.TestDeterministicMode_ShouldUseCustomSequence;
var
  LSequence: TBytes;
  LResult: TRandomResult;
  i: Integer;
begin
  // Arrange
  SetLength(LSequence, 8);
  for i := 0 to 7 do
    LSequence[i] := $AA + i;

  FRandom.SetDeterministicSequence(LSequence);

  // Act
  LResult := FRandom.GenerateBytes(8);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  for i := 0 to 7 do
    CheckEqual($AA + i, LResult.Data[i], 'Byte ' + IntToStr(i));
end;

procedure TTestRandomMock.TestDeterministicMode_ShouldWrapAroundSequence;
var
  LSequence: TBytes;
  LResult: TRandomResult;
begin
  // Arrange
  SetLength(LSequence, 4);
  LSequence[0] := $11;
  LSequence[1] := $22;
  LSequence[2] := $33;
  LSequence[3] := $44;

  FRandom.SetDeterministicSequence(LSequence);

  // Act - 请求超过序列长度的字节
  LResult := FRandom.GenerateBytes(8);

  // Assert
  CheckTrue(LResult.Success, 'Should succeed');
  CheckEqual($11, LResult.Data[0], 'Byte 0');
  CheckEqual($22, LResult.Data[1], 'Byte 1');
  CheckEqual($33, LResult.Data[2], 'Byte 2');
  CheckEqual($44, LResult.Data[3], 'Byte 3');
  CheckEqual($11, LResult.Data[4], 'Byte 4 (wrapped)');
  CheckEqual($22, LResult.Data[5], 'Byte 5 (wrapped)');
  CheckEqual($33, LResult.Data[6], 'Byte 6 (wrapped)');
  CheckEqual($44, LResult.Data[7], 'Byte 7 (wrapped)');
end;

{ Pseudo-random mode tests }

procedure TTestRandomMock.TestPseudoRandomMode_ShouldProduceDifferentBytes;
var
  LResult: TRandomResult;
  LAllSame: Boolean;
  i: Integer;
begin
  // Arrange
  FRandom.SetMode(rmPseudoRandom);
  FRandom.SetSeed(54321);

  // Act
  LResult := FRandom.GenerateBytes(100);

  // Assert - 检查不是所有字节都相同
  CheckTrue(LResult.Success, 'Should succeed');
  LAllSame := True;
  for i := 1 to 99 do
  begin
    if LResult.Data[i] <> LResult.Data[0] then
    begin
      LAllSame := False;
      Break;
    end;
  end;

  CheckFalse(LAllSame, 'Not all bytes should be the same');
end;

procedure TTestRandomMock.TestPseudoRandomMode_WithSameSeed_ShouldProduceSameSequence;
var
  LResult1, LResult2: TRandomResult;
  i: Integer;
begin
  // Arrange
  FRandom.SetMode(rmPseudoRandom);

  // Act - 第一次生成
  FRandom.SetSeed(99999);
  LResult1 := FRandom.GenerateBytes(32);

  // Act - 使用相同种子再次生成
  FRandom.SetSeed(99999);
  LResult2 := FRandom.GenerateBytes(32);

  // Assert
  CheckTrue(LResult1.Success, 'First should succeed');
  CheckTrue(LResult2.Success, 'Second should succeed');

  for i := 0 to 31 do
    CheckEqual(LResult1.Data[i], LResult2.Data[i], 'Byte ' + IntToStr(i) + ' should match');
end;

procedure TTestRandomMock.TestPseudoRandomMode_WithDifferentSeed_ShouldProduceDifferentSequence;
var
  LResult1, LResult2: TRandomResult;
  LAllMatch: Boolean;
  i: Integer;
begin
  // Arrange
  FRandom.SetMode(rmPseudoRandom);

  // Act
  FRandom.SetSeed(11111);
  LResult1 := FRandom.GenerateBytes(32);

  FRandom.SetSeed(22222);
  LResult2 := FRandom.GenerateBytes(32);

  // Assert - 至少有一些字节应该不同
  LAllMatch := True;
  for i := 0 to 31 do
  begin
    if LResult1.Data[i] <> LResult2.Data[i] then
    begin
      LAllMatch := False;
      Break;
    end;
  end;

  CheckFalse(LAllMatch, 'Sequences with different seeds should differ');
end;

{ Integer generation tests }

procedure TTestRandomMock.TestGenerateInteger_ShouldReturnValueInRange;
var
  LValue: Cardinal;
  i: Integer;
begin
  // Arrange
  FRandom.SetSeed(12345);

  // Act & Assert - 生成多个值并检查范围
  for i := 1 to 20 do
  begin
    LValue := FRandom.GenerateInteger(100);
    CheckTrue(LValue < 100, 'Value ' + IntToStr(i) + ' should be < 100');
  end;
end;

procedure TTestRandomMock.TestGenerateInteger_ShouldReturnZero_WithZeroMax;
var
  LValue: Cardinal;
begin
  // Act
  LValue := FRandom.GenerateInteger(0);

  // Assert
  CheckEqual(0, LValue, 'Should return 0');
end;

procedure TTestRandomMock.TestGenerateInteger_ShouldBeDeterministic_WithSameSeed;
var
  LValue1, LValue2: Cardinal;
begin
  // Act
  FRandom.SetSeed(55555);
  LValue1 := FRandom.GenerateInteger(1000);

  FRandom.SetSeed(55555);
  LValue2 := FRandom.GenerateInteger(1000);

  // Assert
  CheckEqual(LValue1, LValue2, 'Values should match');
end;

{ Float generation tests }

procedure TTestRandomMock.TestGenerateFloat_ShouldReturnValueBetweenZeroAndOne;
var
  LValue: Double;
  i: Integer;
begin
  // Arrange
  FRandom.SetSeed(77777);

  // Act & Assert
  for i := 1 to 20 do
  begin
    LValue := FRandom.GenerateFloat;
    CheckTrue(LValue >= 0.0, 'Value ' + IntToStr(i) + ' should be >= 0.0');
    CheckTrue(LValue <= 1.0, 'Value ' + IntToStr(i) + ' should be <= 1.0');
  end;
end;

procedure TTestRandomMock.TestGenerateFloat_ShouldBeDeterministic_WithSameSeed;
var
  LValue1, LValue2: Double;
begin
  // Act
  FRandom.SetSeed(88888);
  LValue1 := FRandom.GenerateFloat;

  FRandom.SetSeed(88888);
  LValue2 := FRandom.GenerateFloat;

  // Assert
  CheckNear(LValue1, LValue2, 0.0001, 'Values should match');
end;

{ Seeding tests }

procedure TTestRandomMock.TestSetSeed_ShouldChangeSequence;
var
  LResult1, LResult2: TRandomResult;
  LDifferent: Boolean;
  i: Integer;
begin
  // Act
  FRandom.SetSeed(111);
  LResult1 := FRandom.GenerateBytes(16);

  FRandom.SetSeed(222);
  LResult2 := FRandom.GenerateBytes(16);

  // Assert - 序列应该不同
  LDifferent := False;
  for i := 0 to 15 do
  begin
    if LResult1.Data[i] <> LResult2.Data[i] then
    begin
      LDifferent := True;
      Break;
    end;
  end;

  CheckTrue(LDifferent, 'Sequences should be different');
end;

procedure TTestRandomMock.TestGetSeed_ShouldReturnSetSeed;
const
  CTestSeed = 123456;
begin
  // Act
  FRandom.SetSeed(CTestSeed);

  // Assert
  CheckEqual(CTestSeed, FRandom.GetSeed, 'Should return set seed');
end;

procedure TTestRandomMock.TestReseed_ShouldChangeSequence;
var
  LResult1, LResult2: TRandomResult;
  LSeed1, LSeed2: Cardinal;
begin
  // Act
  FRandom.Reseed;
  LSeed1 := FRandom.GetSeed;
  LResult1 := FRandom.GenerateBytes(16);

  MsSleep(10);  // 确保时间戳变化

  FRandom.Reseed;
  LSeed2 := FRandom.GetSeed;
  LResult2 := FRandom.GenerateBytes(16);

  // Assert - 种子应该不同（基于时间戳）
  // 注意：这个测试有小概率失败，如果两次Reseed在同一毫秒内
  CheckTrue(LSeed1 <> LSeed2, 'Seeds should likely be different');
end;

procedure TTestRandomMock.TestIsSeeded_ShouldReturnTrue_AfterSetSeed;
begin
  // Act
  FRandom.SetSeed(12345);

  // Assert
  CheckTrue(FRandom.IsSeeded, 'Should be seeded');
end;

{ Mode tests }

procedure TTestRandomMock.TestSetMode_ShouldSwitchMode;
begin
  // Act
  FRandom.SetMode(rmDeterministic);

  // Assert
  CheckEqual(Ord(rmDeterministic), Ord(FRandom.GetMode), 'Should be in deterministic mode');

  // Act
  FRandom.SetMode(rmPseudoRandom);

  // Assert
  CheckEqual(Ord(rmPseudoRandom), Ord(FRandom.GetMode), 'Should be in pseudo-random mode');
end;

procedure TTestRandomMock.TestGetMode_ShouldReturnCurrentMode;
begin
  // Arrange - Mock默认是伪随机模式
  // Assert
  CheckEqual(Ord(rmPseudoRandom), Ord(FRandom.GetMode), 'Default should be pseudo-random');
end;

procedure TTestRandomMock.TestSetDeterministicSequence_ShouldSwitchToDeterministicMode;
var
  LSequence: TBytes;
begin
  // Arrange
  SetLength(LSequence, 4);

  // Act
  FRandom.SetDeterministicSequence(LSequence);

  // Assert
  CheckEqual(Ord(rmDeterministic), Ord(FRandom.GetMode), 'Should switch to deterministic mode');
end;

{ Status tests }

procedure TTestRandomMock.TestGetStatus_ShouldReturnCorrectStatus;
var
  LStatus: string;
begin
  // Test deterministic mode
  FRandom.SetMode(rmDeterministic);
  LStatus := FRandom.GetStatus;
  CheckTrue(Pos('Deterministic', LStatus) > 0, 'Status should contain "Deterministic"');

  // Test pseudo-random mode
  FRandom.SetMode(rmPseudoRandom);
  LStatus := FRandom.GetStatus;
  CheckTrue(Pos('Pseudo-random', LStatus) > 0, 'Status should contain "Pseudo-random"');

  // Test with seed
  FRandom.SetSeed(11111);
  LStatus := FRandom.GetStatus;
  CheckTrue(Pos('11111', LStatus) > 0, 'Status should contain seed info');
end;

{ Error handling tests }

procedure TTestRandomMock.TestGenerateBytes_ShouldFail_WhenConfigured;
var
  LResult: TRandomResult;
begin
  // Arrange
  FMock.SetShouldFail(True, 'Simulated failure');

  // Act
  LResult := FRandom.GenerateBytes(16);

  // Assert
  CheckFalse(LResult.Success, 'Should fail');
  CheckEqual('Simulated failure', LResult.ErrorMessage, 'Error message');
  CheckEqual(0, Length(LResult.Data), 'Data should be empty');
end;

{ Statistics tests }

procedure TTestRandomMock.TestStatistics_ShouldTrackBytesGenerated;
begin
  // Act
  FRandom.GenerateBytes(10);
  FRandom.GenerateBytes(20);
  FRandom.GenerateBytes(30);

  // Assert
  CheckEqual(60, FRandom.GetBytesGeneratedCount, 'Should track total bytes');
end;

procedure TTestRandomMock.TestStatistics_ShouldTrackCallCount;
begin
  // Act
  FRandom.GenerateBytes(10);
  FRandom.GenerateBytes(20);
  FRandom.GenerateInteger(100);  // 内部调用GenerateBytes
  FRandom.GenerateFloat;         // 内部调用GenerateBytes

  // Assert
  CheckEqual(4, FRandom.GetGenerateCallCount, 'Should track call count');
end;

procedure TTestRandomMock.TestResetStatistics_ShouldClearCounters;
begin
  // Arrange
  FRandom.GenerateBytes(50);
  FRandom.GenerateInteger(100);

  // Act
  FRandom.ResetStatistics;

  // Assert
  CheckEqual(0, FRandom.GetBytesGeneratedCount, 'Bytes count should be 0');
  CheckEqual(0, FRandom.GetGenerateCallCount, 'Call count should be 0');
end;

end.

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
  Classes, SysUtils, fpcunit, testregistry,
  openssl_rand_interface;

type
  { TTestRandomMock - Test suite for Random mock }
  TTestRandomMock = class(TTestCase)
  private
    FRandom: IRandom;
    FMock: TRandomMock;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
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

procedure TTestRandomMock.SetUp;
begin
  inherited SetUp;
  FMock := TRandomMock.Create;
  FRandom := FMock as IRandom;
end;

procedure TTestRandomMock.TearDown;
begin
  FRandom := nil;
  FMock := nil;
  inherited TearDown;
end;

{ Basic generation tests }

procedure TTestRandomMock.TestGenerateBytes_ShouldSucceed_WithValidLength;
var
  LResult: TRandomResult;
begin
  // Act
  LResult := FRandom.GenerateBytes(16);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return 16 bytes', 16, Length(LResult.Data));
  AssertEquals('Error message should be empty', '', LResult.ErrorMessage);
end;

procedure TTestRandomMock.TestGenerateBytes_ShouldReturnEmptyArray_WithZeroLength;
var
  LResult: TRandomResult;
begin
  // Act
  LResult := FRandom.GenerateBytes(0);
  
  // Assert
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Should return empty array', 0, Length(LResult.Data));
end;

procedure TTestRandomMock.TestGenerateBytes_ShouldFail_WithNegativeLength;
var
  LResult: TRandomResult;
begin
  // Act
  LResult := FRandom.GenerateBytes(-1);
  
  // Assert
  AssertFalse('Should fail', LResult.Success);
  AssertEquals('Should have error message', 'Length cannot be negative', LResult.ErrorMessage);
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
  AssertEquals('Call count should increase', LInitialCallCount + 2, FRandom.GetGenerateCallCount);
  AssertEquals('Bytes generated should be 30', 30, FRandom.GetBytesGeneratedCount);
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
  AssertTrue('First generation should succeed', LResult1.Success);
  AssertTrue('Second generation should succeed', LResult2.Success);
  
  for i := 0 to 31 do
    AssertEquals('Byte ' + IntToStr(i) + ' should match',
                 LResult1.Data[i], LResult2.Data[i]);
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
  AssertTrue('Should succeed', LResult.Success);
  for i := 0 to 7 do
    AssertEquals('Byte ' + IntToStr(i), $AA + i, LResult.Data[i]);
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
  AssertTrue('Should succeed', LResult.Success);
  AssertEquals('Byte 0', $11, LResult.Data[0]);
  AssertEquals('Byte 1', $22, LResult.Data[1]);
  AssertEquals('Byte 2', $33, LResult.Data[2]);
  AssertEquals('Byte 3', $44, LResult.Data[3]);
  AssertEquals('Byte 4 (wrapped)', $11, LResult.Data[4]);
  AssertEquals('Byte 5 (wrapped)', $22, LResult.Data[5]);
  AssertEquals('Byte 6 (wrapped)', $33, LResult.Data[6]);
  AssertEquals('Byte 7 (wrapped)', $44, LResult.Data[7]);
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
  AssertTrue('Should succeed', LResult.Success);
  LAllSame := True;
  for i := 1 to 99 do
  begin
    if LResult.Data[i] <> LResult.Data[0] then
    begin
      LAllSame := False;
      Break;
    end;
  end;
  
  AssertFalse('Not all bytes should be the same', LAllSame);
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
  AssertTrue('First should succeed', LResult1.Success);
  AssertTrue('Second should succeed', LResult2.Success);
  
  for i := 0 to 31 do
    AssertEquals('Byte ' + IntToStr(i) + ' should match',
                 LResult1.Data[i], LResult2.Data[i]);
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
  
  AssertFalse('Sequences with different seeds should differ', LAllMatch);
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
    AssertTrue('Value ' + IntToStr(i) + ' should be < 100', LValue < 100);
  end;
end;

procedure TTestRandomMock.TestGenerateInteger_ShouldReturnZero_WithZeroMax;
var
  LValue: Cardinal;
begin
  // Act
  LValue := FRandom.GenerateInteger(0);
  
  // Assert
  AssertEquals('Should return 0', 0, LValue);
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
  AssertEquals('Values should match', LValue1, LValue2);
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
    AssertTrue('Value ' + IntToStr(i) + ' should be >= 0.0', LValue >= 0.0);
    AssertTrue('Value ' + IntToStr(i) + ' should be <= 1.0', LValue <= 1.0);
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
  AssertEquals('Values should match', LValue1, LValue2, 0.0001);
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
  
  AssertTrue('Sequences should be different', LDifferent);
end;

procedure TTestRandomMock.TestGetSeed_ShouldReturnSetSeed;
const
  CTestSeed = 123456;
begin
  // Act
  FRandom.SetSeed(CTestSeed);
  
  // Assert
  AssertEquals('Should return set seed', CTestSeed, FRandom.GetSeed);
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
  
  Sleep(10);  // 确保时间戳变化
  
  FRandom.Reseed;
  LSeed2 := FRandom.GetSeed;
  LResult2 := FRandom.GenerateBytes(16);
  
  // Assert - 种子应该不同（基于时间戳）
  // 注意：这个测试有小概率失败，如果两次Reseed在同一毫秒内
  AssertTrue('Seeds should likely be different', LSeed1 <> LSeed2);
end;

procedure TTestRandomMock.TestIsSeeded_ShouldReturnTrue_AfterSetSeed;
begin
  // Act
  FRandom.SetSeed(12345);
  
  // Assert
  AssertTrue('Should be seeded', FRandom.IsSeeded);
end;

{ Mode tests }

procedure TTestRandomMock.TestSetMode_ShouldSwitchMode;
begin
  // Act
  FRandom.SetMode(rmDeterministic);
  
  // Assert
  AssertEquals('Should be in deterministic mode', Ord(rmDeterministic), Ord(FRandom.GetMode));
  
  // Act
  FRandom.SetMode(rmPseudoRandom);
  
  // Assert
  AssertEquals('Should be in pseudo-random mode', Ord(rmPseudoRandom), Ord(FRandom.GetMode));
end;

procedure TTestRandomMock.TestGetMode_ShouldReturnCurrentMode;
begin
  // Arrange - Mock默认是伪随机模式
  // Assert
  AssertEquals('Default should be pseudo-random', Ord(rmPseudoRandom), Ord(FRandom.GetMode));
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
  AssertEquals('Should switch to deterministic mode', Ord(rmDeterministic), Ord(FRandom.GetMode));
end;

{ Status tests }

procedure TTestRandomMock.TestGetStatus_ShouldReturnCorrectStatus;
var
  LStatus: string;
begin
  // Test deterministic mode
  FRandom.SetMode(rmDeterministic);
  LStatus := FRandom.GetStatus;
  AssertTrue('Status should contain "Deterministic"', Pos('Deterministic', LStatus) > 0);
  
  // Test pseudo-random mode
  FRandom.SetMode(rmPseudoRandom);
  LStatus := FRandom.GetStatus;
  AssertTrue('Status should contain "Pseudo-random"', Pos('Pseudo-random', LStatus) > 0);
  
  // Test with seed
  FRandom.SetSeed(11111);
  LStatus := FRandom.GetStatus;
  AssertTrue('Status should contain seed info', Pos('11111', LStatus) > 0);
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
  AssertFalse('Should fail', LResult.Success);
  AssertEquals('Error message', 'Simulated failure', LResult.ErrorMessage);
  AssertEquals('Data should be empty', 0, Length(LResult.Data));
end;

{ Statistics tests }

procedure TTestRandomMock.TestStatistics_ShouldTrackBytesGenerated;
begin
  // Act
  FRandom.GenerateBytes(10);
  FRandom.GenerateBytes(20);
  FRandom.GenerateBytes(30);
  
  // Assert
  AssertEquals('Should track total bytes', 60, FRandom.GetBytesGeneratedCount);
end;

procedure TTestRandomMock.TestStatistics_ShouldTrackCallCount;
begin
  // Act
  FRandom.GenerateBytes(10);
  FRandom.GenerateBytes(20);
  FRandom.GenerateInteger(100);  // 内部调用GenerateBytes
  FRandom.GenerateFloat;         // 内部调用GenerateBytes
  
  // Assert
  AssertEquals('Should track call count', 4, FRandom.GetGenerateCallCount);
end;

procedure TTestRandomMock.TestResetStatistics_ShouldClearCounters;
begin
  // Arrange
  FRandom.GenerateBytes(50);
  FRandom.GenerateInteger(100);
  
  // Act
  FRandom.ResetStatistics;
  
  // Assert
  AssertEquals('Bytes count should be 0', 0, FRandom.GetBytesGeneratedCount);
  AssertEquals('Call count should be 0', 0, FRandom.GetGenerateCallCount);
end;

initialization
  RegisterTest(TTestRandomMock);

end.

unit openssl_rand_interface;

{$mode objfpc}{$H+}

{
  Random Number Generator Mock Interface
  
  Provides mock implementations for random number generation including:
  - RAND_bytes: Cryptographic random bytes
  - Deterministic mode: For reproducible testing
  - Seeding control: Custom seed management
  
  This mock allows testing random-number-dependent code without requiring OpenSSL.
}

interface

uses
  Classes, SysUtils;

type
  // 随机数生成模式
  TRandomMode = (
    rmDeterministic,  // 确定性模式 - 用于测试
    rmPseudoRandom    // 伪随机模式 - 模拟真实随机
  );

  // 随机数生成结果
  TRandomResult = record
    Success: Boolean;
    Data: TBytes;
    ErrorMessage: string;
  end;

  { IRandom - Random Number Generator接口 }
  IRandom = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    
    // 生成随机字节
    function GenerateBytes(aLength: Integer): TRandomResult;
    
    // 生成随机整数（范围：0 到 aMax-1）
    function GenerateInteger(aMax: Cardinal): Cardinal;
    
    // 生成随机浮点数（范围：0.0 到 1.0）
    function GenerateFloat: Double;
    
    // 种子管理
    procedure SetSeed(aSeed: Cardinal);
    function GetSeed: Cardinal;
    procedure Reseed;
    
    // 模式控制
    procedure SetMode(aMode: TRandomMode);
    function GetMode: TRandomMode;
    
    // 确定性序列（用于测试）
    procedure SetDeterministicSequence(const aSequence: TBytes);
    procedure ClearDeterministicSequence;
    
    // 状态查询
    function IsSeeded: Boolean;
    function GetStatus: string;
    
    // 统计信息
    function GetBytesGeneratedCount: Int64;
    function GetGenerateCallCount: Integer;
    procedure ResetStatistics;
  end;

  { TRandomMock - Random Mock实现 }
  TRandomMock = class(TInterfacedObject, IRandom)
  private
    FMode: TRandomMode;
    FSeed: Cardinal;
    FIsSeeded: Boolean;
    FShouldFail: Boolean;
    FErrorMessage: string;
    FDeterministicSequence: TBytes;
    FDeterministicIndex: Integer;
    FBytesGeneratedCount: Int64;
    FGenerateCallCount: Integer;
    FLCGState: Cardinal;  // Linear Congruential Generator状态
    
    function GeneratePseudoRandomByte: Byte;
    function GetDeterministicByte: Byte;
  public
    constructor Create;
    
    // IRandom接口实现
    function GenerateBytes(aLength: Integer): TRandomResult;
    function GenerateInteger(aMax: Cardinal): Cardinal;
    function GenerateFloat: Double;
    
    procedure SetSeed(aSeed: Cardinal);
    function GetSeed: Cardinal;
    procedure Reseed;
    
    procedure SetMode(aMode: TRandomMode);
    function GetMode: TRandomMode;
    
    procedure SetDeterministicSequence(const aSequence: TBytes);
    procedure ClearDeterministicSequence;
    
    function IsSeeded: Boolean;
    function GetStatus: string;
    
    function GetBytesGeneratedCount: Int64;
    function GetGenerateCallCount: Integer;
    procedure ResetStatistics;
    
    // 测试辅助方法
    procedure SetShouldFail(aValue: Boolean; const aErrorMessage: string = '');
  end;

implementation

{ TRandomMock }

constructor TRandomMock.Create;
begin
  inherited Create;
  FMode := rmPseudoRandom;
  FSeed := 0;
  FIsSeeded := False;
  FShouldFail := False;
  FErrorMessage := '';
  SetLength(FDeterministicSequence, 0);
  FDeterministicIndex := 0;
  FBytesGeneratedCount := 0;
  FGenerateCallCount := 0;
  FLCGState := 0;
  
  // 使用时间戳作为初始种子
  Reseed;
end;

function TRandomMock.GeneratePseudoRandomByte: Byte;
const
  // LCG参数 (来自 Numerical Recipes)
  LCG_A = 1664525;
  LCG_C = 1013904223;
begin
  // Linear Congruential Generator
  FLCGState := (LCG_A * FLCGState + LCG_C);
  Result := Byte((FLCGState shr 16) and $FF);
end;

function TRandomMock.GetDeterministicByte: Byte;
begin
  if Length(FDeterministicSequence) = 0 then
  begin
    // 如果没有序列，生成简单的确定性字节
    Result := Byte(FDeterministicIndex mod 256);
    Inc(FDeterministicIndex);
  end
  else
  begin
    // 使用预设序列
    Result := FDeterministicSequence[FDeterministicIndex mod Length(FDeterministicSequence)];
    Inc(FDeterministicIndex);
  end;
end;

function TRandomMock.GenerateBytes(aLength: Integer): TRandomResult;
var
  i: Integer;
begin
  Inc(FGenerateCallCount);
  
  Result.Success := False;
  SetLength(Result.Data, 0);
  Result.ErrorMessage := '';
  
  if FShouldFail then
  begin
    Result.ErrorMessage := FErrorMessage;
    Exit;
  end;
  
  if aLength < 0 then
  begin
    Result.ErrorMessage := 'Length cannot be negative';
    Exit;
  end;
  
  if aLength = 0 then
  begin
    Result.Success := True;
    Exit;
  end;
  
  SetLength(Result.Data, aLength);
  
  case FMode of
    rmDeterministic:
      begin
        for i := 0 to aLength - 1 do
          Result.Data[i] := GetDeterministicByte;
      end;
      
    rmPseudoRandom:
      begin
        for i := 0 to aLength - 1 do
          Result.Data[i] := GeneratePseudoRandomByte;
      end;
  end;
  
  Inc(FBytesGeneratedCount, aLength);
  Result.Success := True;
end;

function TRandomMock.GenerateInteger(aMax: Cardinal): Cardinal;
var
  LBytes: TRandomResult;
  LValue: Cardinal;
begin
  Result := 0;
  
  if aMax = 0 then
    Exit;
  
  // 生成4个字节并转换为Cardinal
  LBytes := GenerateBytes(4);
  if not LBytes.Success then
    Exit;
  
  Move(LBytes.Data[0], LValue, 4);
  Result := LValue mod aMax;
end;

function TRandomMock.GenerateFloat: Double;
var
  LBytes: TRandomResult;
  LValue: Cardinal;
begin
  // 生成4个字节
  LBytes := GenerateBytes(4);
  if not LBytes.Success then
  begin
    Result := 0.0;
    Exit;
  end;
  
  Move(LBytes.Data[0], LValue, 4);
  // 转换为0.0到1.0之间的值
  Result := LValue / High(Cardinal);
end;

procedure TRandomMock.SetSeed(aSeed: Cardinal);
begin
  FSeed := aSeed;
  FLCGState := aSeed;
  FIsSeeded := True;
  FDeterministicIndex := 0;
end;

function TRandomMock.GetSeed: Cardinal;
begin
  Result := FSeed;
end;

procedure TRandomMock.Reseed;
begin
  // 使用当前时间作为种子
  SetSeed(Cardinal(GetTickCount64 and $FFFFFFFF));
end;

procedure TRandomMock.SetMode(aMode: TRandomMode);
begin
  FMode := aMode;
  FDeterministicIndex := 0;
end;

function TRandomMock.GetMode: TRandomMode;
begin
  Result := FMode;
end;

procedure TRandomMock.SetDeterministicSequence(const aSequence: TBytes);
begin
  FDeterministicSequence := Copy(aSequence);
  FDeterministicIndex := 0;
  FMode := rmDeterministic;
end;

procedure TRandomMock.ClearDeterministicSequence;
begin
  SetLength(FDeterministicSequence, 0);
  FDeterministicIndex := 0;
end;

function TRandomMock.IsSeeded: Boolean;
begin
  Result := FIsSeeded;
end;

function TRandomMock.GetStatus: string;
begin
  case FMode of
    rmDeterministic:
      Result := 'Deterministic mode';
    rmPseudoRandom:
      Result := 'Pseudo-random mode';
  else
    Result := 'Unknown mode';
  end;
  
  if FIsSeeded then
    Result := Result + ' (seeded: ' + IntToStr(FSeed) + ')'
  else
    Result := Result + ' (not seeded)';
end;

function TRandomMock.GetBytesGeneratedCount: Int64;
begin
  Result := FBytesGeneratedCount;
end;

function TRandomMock.GetGenerateCallCount: Integer;
begin
  Result := FGenerateCallCount;
end;

procedure TRandomMock.ResetStatistics;
begin
  FBytesGeneratedCount := 0;
  FGenerateCallCount := 0;
end;

procedure TRandomMock.SetShouldFail(aValue: Boolean; const aErrorMessage: string);
begin
  FShouldFail := aValue;
  FErrorMessage := aErrorMessage;
end;

end.

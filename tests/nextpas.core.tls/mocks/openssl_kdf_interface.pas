unit openssl_kdf_interface;

{$mode objfpc}{$H+}

{
  KDF (Key Derivation Function) Mock Interface
  
  Provides mock implementations for key derivation functions including:
  - PBKDF2 (Password-Based Key Derivation Function 2)
  - HKDF (HMAC-based Key Derivation Function)
  - Scrypt (Memory-hard KDF)
  
  This mock allows testing KDF-dependent code without requiring OpenSSL.
}

interface

uses
  Classes, SysUtils;

type
  // KDF算法类型
  TKDFAlgorithm = (
    kdPBKDF2_SHA1,
    kdPBKDF2_SHA256,
    kdPBKDF2_SHA512,
    kdHKDF_SHA256,
    kdHKDF_SHA512,
    kdScrypt
  );

  // KDF结果记录
  TKDFResult = record
    Success: Boolean;
    DerivedKey: TBytes;
    ErrorMessage: string;
  end;

  { IKDF - Key Derivation Function接口 }
  IKDF = interface
    ['{8F9A3B2C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    
    // PBKDF2 - Password-Based Key Derivation Function 2
    function PBKDF2(aAlgorithm: TKDFAlgorithm; const aPassword: TBytes;
                    const aSalt: TBytes; aIterations: Integer;
                    aKeyLength: Integer): TKDFResult;
    
    // HKDF - HMAC-based Key Derivation Function
    function HKDF(aAlgorithm: TKDFAlgorithm; const aInputKey: TBytes;
                  const aSalt: TBytes; const aInfo: TBytes;
                  aKeyLength: Integer): TKDFResult;
    
    // HKDF Extract - 提取阶段
    function HKDFExtract(aAlgorithm: TKDFAlgorithm; const aInputKey: TBytes;
                        const aSalt: TBytes): TKDFResult;
    
    // HKDF Expand - 扩展阶段
    function HKDFExpand(aAlgorithm: TKDFAlgorithm; const aPRK: TBytes;
                       const aInfo: TBytes; aKeyLength: Integer): TKDFResult;
    
    // Scrypt - Memory-hard key derivation function
    function Scrypt(const aPassword: TBytes; const aSalt: TBytes;
                   aN: Cardinal; aR: Cardinal; aP: Cardinal;
                   aKeyLength: Integer): TKDFResult;
    
    // 算法信息查询
    function GetAlgorithmName(aAlgorithm: TKDFAlgorithm): string;
    function GetOutputSize(aAlgorithm: TKDFAlgorithm): Integer;
    function IsAlgorithmSupported(aAlgorithm: TKDFAlgorithm): Boolean;
    
    // 统计信息
    function GetOperationCount: Integer;
    function GetPBKDF2CallCount: Integer;
    function GetHKDFCallCount: Integer;
    function GetScryptCallCount: Integer;
    procedure ResetStatistics;
  end;

  { TKDFMock - KDF Mock实现 }
  TKDFMock = class(TInterfacedObject, IKDF)
  private
    FShouldFail: Boolean;
    FErrorMessage: string;
    FCustomKey: TBytes;
    FOperationCount: Integer;
    FPBKDF2CallCount: Integer;
    FHKDFCallCount: Integer;
    FScryptCallCount: Integer;
    
    function SimulatePBKDF2(const aPassword, aSalt: TBytes;
                           aIterations, aKeyLength: Integer;
                           aSeed: Byte): TBytes;
    function SimulateHKDF(const aInputKey, aSalt, aInfo: TBytes;
                         aKeyLength: Integer; aSeed: Byte): TBytes;
    function SimulateScrypt(const aPassword, aSalt: TBytes;
                           aN, aR, aP: Cardinal; aKeyLength: Integer): TBytes;
  public
    constructor Create;
    
    // IKDF接口实现
    function PBKDF2(aAlgorithm: TKDFAlgorithm; const aPassword: TBytes;
                    const aSalt: TBytes; aIterations: Integer;
                    aKeyLength: Integer): TKDFResult;
    function HKDF(aAlgorithm: TKDFAlgorithm; const aInputKey: TBytes;
                  const aSalt: TBytes; const aInfo: TBytes;
                  aKeyLength: Integer): TKDFResult;
    function HKDFExtract(aAlgorithm: TKDFAlgorithm; const aInputKey: TBytes;
                        const aSalt: TBytes): TKDFResult;
    function HKDFExpand(aAlgorithm: TKDFAlgorithm; const aPRK: TBytes;
                       const aInfo: TBytes; aKeyLength: Integer): TKDFResult;
    function Scrypt(const aPassword: TBytes; const aSalt: TBytes;
                   aN: Cardinal; aR: Cardinal; aP: Cardinal;
                   aKeyLength: Integer): TKDFResult;
    
    function GetAlgorithmName(aAlgorithm: TKDFAlgorithm): string;
    function GetOutputSize(aAlgorithm: TKDFAlgorithm): Integer;
    function IsAlgorithmSupported(aAlgorithm: TKDFAlgorithm): Boolean;
    
    function GetOperationCount: Integer;
    function GetPBKDF2CallCount: Integer;
    function GetHKDFCallCount: Integer;
    function GetScryptCallCount: Integer;
    procedure ResetStatistics;
    
    // 测试辅助方法
    procedure SetShouldFail(aValue: Boolean; const aErrorMessage: string = '');
    procedure SetCustomKey(const aKey: TBytes);
    procedure ClearCustomKey;
  end;

implementation

{ TKDFMock }

constructor TKDFMock.Create;
begin
  inherited Create;
  FShouldFail := False;
  FErrorMessage := '';
  SetLength(FCustomKey, 0);
  FOperationCount := 0;
  FPBKDF2CallCount := 0;
  FHKDFCallCount := 0;
  FScryptCallCount := 0;
end;

function TKDFMock.SimulatePBKDF2(const aPassword, aSalt: TBytes;
  aIterations, aKeyLength: Integer; aSeed: Byte): TBytes;
var
  i, j: Integer;
  LHash: Byte;
begin
  SetLength(Result, aKeyLength);
  
  // 简单的确定性派生算法（不是真实的PBKDF2）
  for i := 0 to aKeyLength - 1 do
  begin
    LHash := aSeed xor Byte(i);
    
    // 混入密码
    for j := 0 to High(aPassword) do
      LHash := LHash xor aPassword[j];
    
    // 混入盐值
    for j := 0 to High(aSalt) do
      LHash := LHash xor aSalt[j];
    
    // 模拟迭代（简化版）
    for j := 0 to (aIterations mod 256) - 1 do
      LHash := ((LHash shl 1) or (LHash shr 7)) xor Byte(j);
    
    Result[i] := LHash;
  end;
end;

function TKDFMock.SimulateHKDF(const aInputKey, aSalt, aInfo: TBytes;
  aKeyLength: Integer; aSeed: Byte): TBytes;
var
  i, j: Integer;
  LHash: Byte;
begin
  SetLength(Result, aKeyLength);
  
  // 简单的确定性派生算法（不是真实的HKDF）
  for i := 0 to aKeyLength - 1 do
  begin
    LHash := aSeed xor Byte(i * 3);
    
    // 混入输入密钥
    for j := 0 to High(aInputKey) do
      LHash := LHash xor aInputKey[j];
    
    // 混入盐值
    for j := 0 to High(aSalt) do
      LHash := LHash xor aSalt[j];
    
    // 混入Info
    for j := 0 to High(aInfo) do
      LHash := LHash xor aInfo[j];
    
    Result[i] := LHash;
  end;
end;

function TKDFMock.SimulateScrypt(const aPassword, aSalt: TBytes;
  aN, aR, aP: Cardinal; aKeyLength: Integer): TBytes;
var
  i, j: Integer;
  LHash: Byte;
begin
  SetLength(Result, aKeyLength);
  
  // 简单的确定性派生算法（不是真实的Scrypt）
  for i := 0 to aKeyLength - 1 do
  begin
    LHash := Byte(i * 7);
    
    // 混入密码
    for j := 0 to High(aPassword) do
      LHash := LHash xor aPassword[j];
    
    // 混入盐值
    for j := 0 to High(aSalt) do
      LHash := LHash xor aSalt[j];
    
    // 模拟Scrypt参数的影响
    LHash := LHash xor Byte(aN mod 256) xor Byte(aR mod 256) xor Byte(aP mod 256);
    
    Result[i] := LHash;
  end;
end;

function TKDFMock.PBKDF2(aAlgorithm: TKDFAlgorithm; const aPassword: TBytes;
  const aSalt: TBytes; aIterations: Integer; aKeyLength: Integer): TKDFResult;
var
  LSeed: Byte;
begin
  Inc(FOperationCount);
  Inc(FPBKDF2CallCount);
  
  Result.Success := False;
  SetLength(Result.DerivedKey, 0);
  Result.ErrorMessage := '';
  
  if FShouldFail then
  begin
    Result.ErrorMessage := FErrorMessage;
    Exit;
  end;
  
  // 验证参数
  if Length(aPassword) = 0 then
  begin
    Result.ErrorMessage := 'Password cannot be empty';
    Exit;
  end;
  
  if aIterations <= 0 then
  begin
    Result.ErrorMessage := 'Iterations must be positive';
    Exit;
  end;
  
  if aKeyLength <= 0 then
  begin
    Result.ErrorMessage := 'Key length must be positive';
    Exit;
  end;
  
  // 如果设置了自定义密钥，使用它
  if Length(FCustomKey) > 0 then
  begin
    if Length(FCustomKey) <> aKeyLength then
    begin
      Result.ErrorMessage := 'Custom key length mismatch';
      Exit;
    end;
    Result.DerivedKey := Copy(FCustomKey);
    Result.Success := True;
    Exit;
  end;
  
  // 根据算法选择种子
  case aAlgorithm of
    kdPBKDF2_SHA1: LSeed := $A1;
    kdPBKDF2_SHA256: LSeed := $A2;
    kdPBKDF2_SHA512: LSeed := $A3;
  else
    Result.ErrorMessage := 'Unsupported algorithm for PBKDF2';
    Exit;
  end;
  
  // 生成派生密钥
  Result.DerivedKey := SimulatePBKDF2(aPassword, aSalt, aIterations, aKeyLength, LSeed);
  Result.Success := True;
end;

function TKDFMock.HKDF(aAlgorithm: TKDFAlgorithm; const aInputKey: TBytes;
  const aSalt: TBytes; const aInfo: TBytes; aKeyLength: Integer): TKDFResult;
var
  LSeed: Byte;
begin
  Inc(FOperationCount);
  Inc(FHKDFCallCount);
  
  Result.Success := False;
  SetLength(Result.DerivedKey, 0);
  Result.ErrorMessage := '';
  
  if FShouldFail then
  begin
    Result.ErrorMessage := FErrorMessage;
    Exit;
  end;
  
  // 验证参数
  if Length(aInputKey) = 0 then
  begin
    Result.ErrorMessage := 'Input key cannot be empty';
    Exit;
  end;
  
  if aKeyLength <= 0 then
  begin
    Result.ErrorMessage := 'Key length must be positive';
    Exit;
  end;
  
  // 如果设置了自定义密钥，使用它
  if Length(FCustomKey) > 0 then
  begin
    if Length(FCustomKey) <> aKeyLength then
    begin
      Result.ErrorMessage := 'Custom key length mismatch';
      Exit;
    end;
    Result.DerivedKey := Copy(FCustomKey);
    Result.Success := True;
    Exit;
  end;
  
  // 根据算法选择种子
  case aAlgorithm of
    kdHKDF_SHA256: LSeed := $B2;
    kdHKDF_SHA512: LSeed := $B3;
  else
    Result.ErrorMessage := 'Unsupported algorithm for HKDF';
    Exit;
  end;
  
  // 生成派生密钥
  Result.DerivedKey := SimulateHKDF(aInputKey, aSalt, aInfo, aKeyLength, LSeed);
  Result.Success := True;
end;

function TKDFMock.HKDFExtract(aAlgorithm: TKDFAlgorithm;
  const aInputKey: TBytes; const aSalt: TBytes): TKDFResult;
var
  LOutputSize: Integer;
begin
  Inc(FOperationCount);
  Inc(FHKDFCallCount);
  
  Result.Success := False;
  SetLength(Result.DerivedKey, 0);
  Result.ErrorMessage := '';
  
  if FShouldFail then
  begin
    Result.ErrorMessage := FErrorMessage;
    Exit;
  end;
  
  // Extract阶段输出PRK，长度等于hash输出大小
  LOutputSize := GetOutputSize(aAlgorithm);
  if LOutputSize <= 0 then
  begin
    Result.ErrorMessage := 'Unsupported algorithm for HKDF Extract';
    Exit;
  end;
  
  // 使用空Info进行HKDF
  Result := HKDF(aAlgorithm, aInputKey, aSalt, nil, LOutputSize);
end;

function TKDFMock.HKDFExpand(aAlgorithm: TKDFAlgorithm; const aPRK: TBytes;
  const aInfo: TBytes; aKeyLength: Integer): TKDFResult;
begin
  Inc(FOperationCount);
  Inc(FHKDFCallCount);
  
  Result.Success := False;
  SetLength(Result.DerivedKey, 0);
  Result.ErrorMessage := '';
  
  if FShouldFail then
  begin
    Result.ErrorMessage := FErrorMessage;
    Exit;
  end;
  
  // Expand阶段使用PRK作为输入密钥，空盐
  Result := HKDF(aAlgorithm, aPRK, nil, aInfo, aKeyLength);
end;

function TKDFMock.Scrypt(const aPassword: TBytes; const aSalt: TBytes;
  aN: Cardinal; aR: Cardinal; aP: Cardinal; aKeyLength: Integer): TKDFResult;
begin
  Inc(FOperationCount);
  Inc(FScryptCallCount);
  
  Result.Success := False;
  SetLength(Result.DerivedKey, 0);
  Result.ErrorMessage := '';
  
  if FShouldFail then
  begin
    Result.ErrorMessage := FErrorMessage;
    Exit;
  end;
  
  // 验证参数
  if Length(aPassword) = 0 then
  begin
    Result.ErrorMessage := 'Password cannot be empty';
    Exit;
  end;
  
  if aN = 0 then
  begin
    Result.ErrorMessage := 'N parameter must be non-zero';
    Exit;
  end;
  
  if aR = 0 then
  begin
    Result.ErrorMessage := 'R parameter must be non-zero';
    Exit;
  end;
  
  if aP = 0 then
  begin
    Result.ErrorMessage := 'P parameter must be non-zero';
    Exit;
  end;
  
  if aKeyLength <= 0 then
  begin
    Result.ErrorMessage := 'Key length must be positive';
    Exit;
  end;
  
  // 如果设置了自定义密钥，使用它
  if Length(FCustomKey) > 0 then
  begin
    if Length(FCustomKey) <> aKeyLength then
    begin
      Result.ErrorMessage := 'Custom key length mismatch';
      Exit;
    end;
    Result.DerivedKey := Copy(FCustomKey);
    Result.Success := True;
    Exit;
  end;
  
  // 生成派生密钥
  Result.DerivedKey := SimulateScrypt(aPassword, aSalt, aN, aR, aP, aKeyLength);
  Result.Success := True;
end;

function TKDFMock.GetAlgorithmName(aAlgorithm: TKDFAlgorithm): string;
begin
  case aAlgorithm of
    kdPBKDF2_SHA1: Result := 'PBKDF2-SHA1';
    kdPBKDF2_SHA256: Result := 'PBKDF2-SHA256';
    kdPBKDF2_SHA512: Result := 'PBKDF2-SHA512';
    kdHKDF_SHA256: Result := 'HKDF-SHA256';
    kdHKDF_SHA512: Result := 'HKDF-SHA512';
    kdScrypt: Result := 'Scrypt';
  else
    Result := 'Unknown';
  end;
end;

function TKDFMock.GetOutputSize(aAlgorithm: TKDFAlgorithm): Integer;
begin
  case aAlgorithm of
    kdPBKDF2_SHA1: Result := 20;     // SHA1输出20字节
    kdPBKDF2_SHA256,
    kdHKDF_SHA256: Result := 32;     // SHA256输出32字节
    kdPBKDF2_SHA512,
    kdHKDF_SHA512: Result := 64;     // SHA512输出64字节
    kdScrypt: Result := 32;          // Scrypt通常输出32字节（可变）
  else
    Result := 0;
  end;
end;

function TKDFMock.IsAlgorithmSupported(aAlgorithm: TKDFAlgorithm): Boolean;
begin
  Result := aAlgorithm in [kdPBKDF2_SHA1, kdPBKDF2_SHA256, kdPBKDF2_SHA512,
                           kdHKDF_SHA256, kdHKDF_SHA512, kdScrypt];
end;

function TKDFMock.GetOperationCount: Integer;
begin
  Result := FOperationCount;
end;

function TKDFMock.GetPBKDF2CallCount: Integer;
begin
  Result := FPBKDF2CallCount;
end;

function TKDFMock.GetHKDFCallCount: Integer;
begin
  Result := FHKDFCallCount;
end;

function TKDFMock.GetScryptCallCount: Integer;
begin
  Result := FScryptCallCount;
end;

procedure TKDFMock.ResetStatistics;
begin
  FOperationCount := 0;
  FPBKDF2CallCount := 0;
  FHKDFCallCount := 0;
  FScryptCallCount := 0;
end;

procedure TKDFMock.SetShouldFail(aValue: Boolean; const aErrorMessage: string);
begin
  FShouldFail := aValue;
  FErrorMessage := aErrorMessage;
end;

procedure TKDFMock.SetCustomKey(const aKey: TBytes);
begin
  FCustomKey := Copy(aKey);
end;

procedure TKDFMock.ClearCustomKey;
begin
  SetLength(FCustomKey, 0);
end;

end.

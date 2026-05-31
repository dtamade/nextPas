unit openssl_hmac_interface;

{$mode objfpc}{$H+}

{
  HMAC Interface Abstraction
  
  Purpose: Provide interface for HMAC (Hash-based Message Authentication Code) operations
  Allows: Real OpenSSL implementation OR Mock implementation
  Benefits: True unit testing, fast execution, isolated tests
}

interface

uses
  Classes, SysUtils;

type
  THMACAlgorithm = (haMD5, haSHA1, haSHA224, haSHA256, haSHA384, haSHA512,
                    haSHA3_224, haSHA3_256, haSHA3_384, haSHA3_512,
                    haBLAKE2b512, haBLAKE2s256, haSM3);

  { HMAC result record }
  THMACResult = record
    Success: Boolean;
    MAC: TBytes;
    ErrorMessage: string;
  end;

  { IHMAC - Interface for HMAC operations }
  IHMAC = interface
    ['{C1D2E3F4-A5B6-7C8D-9E0F-1A2B3C4D5E6F}']
    
    // Single-shot HMAC
    function Compute(const aAlgorithm: THMACAlgorithm;
                     const aKey: TBytes;
                     const aData: TBytes): THMACResult;
    
    // Incremental HMAC (for large data)
    function Init(const aAlgorithm: THMACAlgorithm;
                  const aKey: TBytes): Boolean;
    function Update(const aData: TBytes): Boolean;
    function Final: THMACResult;
    
    // Key management
    function SetKey(const aAlgorithm: THMACAlgorithm;
                    const aKey: TBytes): Boolean;
    function GetKeySize: Integer;
    
    // Algorithm queries
    function GetMACSize(const aAlgorithm: THMACAlgorithm): Integer;
    function GetAlgorithmName(const aAlgorithm: THMACAlgorithm): string;
    
    // Verification
    function Verify(const aAlgorithm: THMACAlgorithm;
                    const aKey: TBytes;
                    const aData: TBytes;
                    const aExpectedMAC: TBytes): Boolean;
    
    // Statistics
    function GetOperationCount: Integer;
    function GetUpdateCount: Integer;
    procedure ResetStatistics;
  end;

  { THMACReal - Real implementation using actual OpenSSL }
  THMACReal = class(TInterfacedObject, IHMAC)
  private
    FOperationCount: Integer;
    FUpdateCount: Integer;
    FCurrentAlgorithm: THMACAlgorithm;
    FCurrentKey: TBytes;
    FInitialized: Boolean;
  public
    constructor Create;
    
    // IHMAC implementation
    function Compute(const aAlgorithm: THMACAlgorithm;
                     const aKey: TBytes;
                     const aData: TBytes): THMACResult;
    function Init(const aAlgorithm: THMACAlgorithm;
                  const aKey: TBytes): Boolean;
    function Update(const aData: TBytes): Boolean;
    function Final: THMACResult;
    function SetKey(const aAlgorithm: THMACAlgorithm;
                    const aKey: TBytes): Boolean;
    function GetKeySize: Integer;
    function GetMACSize(const aAlgorithm: THMACAlgorithm): Integer;
    function GetAlgorithmName(const aAlgorithm: THMACAlgorithm): string;
    function Verify(const aAlgorithm: THMACAlgorithm;
                    const aKey: TBytes;
                    const aData: TBytes;
                    const aExpectedMAC: TBytes): Boolean;
    function GetOperationCount: Integer;
    function GetUpdateCount: Integer;
    procedure ResetStatistics;
  end;

  { THMACMock - Mock implementation for testing }
  THMACMock = class(TInterfacedObject, IHMAC)
  private
    FOperationCount: Integer;
    FUpdateCount: Integer;
    FCurrentAlgorithm: THMACAlgorithm;
    FCurrentKey: TBytes;
    FInitialized: Boolean;
    FShouldFail: Boolean;
    FFailureMessage: string;
    FCustomMAC: TBytes;
    FAccumulatedData: TBytes;
    
    // Last call parameters for verification
    FLastAlgorithm: THMACAlgorithm;
    FLastKeySize: Integer;
    FLastDataSize: Integer;
    FComputeCallCount: Integer;
    FInitCallCount: Integer;
    FFinalCallCount: Integer;
    FVerifyCallCount: Integer;
  public
    constructor Create;
    
    // IHMAC implementation
    function Compute(const aAlgorithm: THMACAlgorithm;
                     const aKey: TBytes;
                     const aData: TBytes): THMACResult;
    function Init(const aAlgorithm: THMACAlgorithm;
                  const aKey: TBytes): Boolean;
    function Update(const aData: TBytes): Boolean;
    function Final: THMACResult;
    function SetKey(const aAlgorithm: THMACAlgorithm;
                    const aKey: TBytes): Boolean;
    function GetKeySize: Integer;
    function GetMACSize(const aAlgorithm: THMACAlgorithm): Integer;
    function GetAlgorithmName(const aAlgorithm: THMACAlgorithm): string;
    function Verify(const aAlgorithm: THMACAlgorithm;
                    const aKey: TBytes;
                    const aData: TBytes;
                    const aExpectedMAC: TBytes): Boolean;
    function GetOperationCount: Integer;
    function GetUpdateCount: Integer;
    procedure ResetStatistics;
    
    // Mock control methods
    procedure SetShouldFail(aValue: Boolean; const aMessage: string = '');
    procedure SetCustomMAC(const aMAC: TBytes);
    function GetLastAlgorithm: THMACAlgorithm;
    function GetLastKeySize: Integer;
    function GetLastDataSize: Integer;
    function GetComputeCallCount: Integer;
    function GetInitCallCount: Integer;
    function GetFinalCallCount: Integer;
    function GetVerifyCallCount: Integer;
    function GetAccumulatedDataSize: Integer;
    function IsInitialized: Boolean;
    procedure Reset;
  end;

implementation

{ THMACReal }

constructor THMACReal.Create;
begin
  inherited Create;
  FOperationCount := 0;
  FUpdateCount := 0;
  FInitialized := False;
end;

function THMACReal.Compute(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes; const aData: TBytes): THMACResult;
begin
  Inc(FOperationCount);
  // Real implementation would use OpenSSL HMAC()
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.MAC, 0);
end;

function THMACReal.Init(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes): Boolean;
begin
  FCurrentAlgorithm := aAlgorithm;
  FCurrentKey := Copy(aKey);
  FInitialized := True;
  Result := True;
end;

function THMACReal.Update(const aData: TBytes): Boolean;
begin
  if not FInitialized then
  begin
    Result := False;
    Exit;
  end;
  Inc(FUpdateCount);
  Result := True;
end;

function THMACReal.Final: THMACResult;
begin
  Inc(FOperationCount);
  FInitialized := False;
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.MAC, 0);
end;

function THMACReal.SetKey(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes): Boolean;
begin
  FCurrentAlgorithm := aAlgorithm;
  FCurrentKey := Copy(aKey);
  Result := True;
end;

function THMACReal.GetKeySize: Integer;
begin
  Result := Length(FCurrentKey);
end;

function THMACReal.GetMACSize(const aAlgorithm: THMACAlgorithm): Integer;
begin
  case aAlgorithm of
    haMD5: Result := 16;
    haSHA1: Result := 20;
    haSHA224, haSHA3_224: Result := 28;
    haSHA256, haSHA3_256, haBLAKE2s256, haSM3: Result := 32;
    haSHA384, haSHA3_384: Result := 48;
    haSHA512, haSHA3_512, haBLAKE2b512: Result := 64;
  else
    Result := 0;
  end;
end;

function THMACReal.GetAlgorithmName(const aAlgorithm: THMACAlgorithm): string;
begin
  case aAlgorithm of
    haMD5: Result := 'HMAC-MD5';
    haSHA1: Result := 'HMAC-SHA1';
    haSHA224: Result := 'HMAC-SHA224';
    haSHA256: Result := 'HMAC-SHA256';
    haSHA384: Result := 'HMAC-SHA384';
    haSHA512: Result := 'HMAC-SHA512';
    haSHA3_224: Result := 'HMAC-SHA3-224';
    haSHA3_256: Result := 'HMAC-SHA3-256';
    haSHA3_384: Result := 'HMAC-SHA3-384';
    haSHA3_512: Result := 'HMAC-SHA3-512';
    haBLAKE2b512: Result := 'HMAC-BLAKE2b-512';
    haBLAKE2s256: Result := 'HMAC-BLAKE2s-256';
    haSM3: Result := 'HMAC-SM3';
  else
    Result := 'unknown';
  end;
end;

function THMACReal.Verify(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes; const aData: TBytes;
  const aExpectedMAC: TBytes): Boolean;
var
  LComputed: THMACResult;
  i: Integer;
begin
  LComputed := Compute(aAlgorithm, aKey, aData);
  if not LComputed.Success then
  begin
    Result := False;
    Exit;
  end;
  
  if Length(LComputed.MAC) <> Length(aExpectedMAC) then
  begin
    Result := False;
    Exit;
  end;
  
  Result := True;
  for i := 0 to High(LComputed.MAC) do
    if LComputed.MAC[i] <> aExpectedMAC[i] then
    begin
      Result := False;
      Exit;
    end;
end;

function THMACReal.GetOperationCount: Integer;
begin
  Result := FOperationCount;
end;

function THMACReal.GetUpdateCount: Integer;
begin
  Result := FUpdateCount;
end;

procedure THMACReal.ResetStatistics;
begin
  FOperationCount := 0;
  FUpdateCount := 0;
end;

{ THMACMock }

constructor THMACMock.Create;
begin
  inherited Create;
  Reset;
end;

function THMACMock.Compute(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes; const aData: TBytes): THMACResult;
var
  i: Integer;
  LMACSize: Integer;
begin
  Inc(FComputeCallCount);
  Inc(FOperationCount);
  
  FLastAlgorithm := aAlgorithm;
  FLastKeySize := Length(aKey);
  FLastDataSize := Length(aData);
  
  if FShouldFail then
  begin
    Result.Success := False;
    Result.ErrorMessage := FFailureMessage;
    SetLength(Result.MAC, 0);
  end
  else
  begin
    Result.Success := True;
    Result.ErrorMessage := '';
    
    if Length(FCustomMAC) > 0 then
      Result.MAC := Copy(FCustomMAC)
    else
    begin
      // Mock: generate predictable HMAC based on key and data
      LMACSize := GetMACSize(aAlgorithm);
      SetLength(Result.MAC, LMACSize);
      
      // Simple mock: combine key and data with pattern
      for i := 0 to LMACSize - 1 do
      begin
        if (Length(aKey) > 0) and (Length(aData) > 0) then
          Result.MAC[i] := Byte((i * 23 + aKey[i mod Length(aKey)] + 
                                aData[i mod Length(aData)]) mod 256)
        else if Length(aKey) > 0 then
          Result.MAC[i] := Byte((i * 23 + aKey[i mod Length(aKey)]) mod 256)
        else
          Result.MAC[i] := Byte(i * 19 mod 256);
      end;
    end;
  end;
end;

function THMACMock.Init(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes): Boolean;
begin
  Inc(FInitCallCount);
  
  if FShouldFail then
  begin
    Result := False;
    FInitialized := False;
  end
  else
  begin
    FCurrentAlgorithm := aAlgorithm;
    FCurrentKey := Copy(aKey);
    FInitialized := True;
    SetLength(FAccumulatedData, 0);
    Result := True;
  end;
end;

function THMACMock.Update(const aData: TBytes): Boolean;
var
  LOldLen: Integer;
  i: Integer;
begin
  Inc(FUpdateCount);
  
  if not FInitialized then
  begin
    Result := False;
    Exit;
  end;
  
  if FShouldFail then
  begin
    Result := False;
    Exit;
  end;
  
  // Accumulate data
  LOldLen := Length(FAccumulatedData);
  SetLength(FAccumulatedData, LOldLen + Length(aData));
  for i := 0 to Length(aData) - 1 do
    FAccumulatedData[LOldLen + i] := aData[i];
  
  Result := True;
end;

function THMACMock.Final: THMACResult;
begin
  Inc(FFinalCallCount);
  Inc(FOperationCount);
  
  if not FInitialized then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Not initialized';
    SetLength(Result.MAC, 0);
    Exit;
  end;
  
  // Use accumulated data to compute final MAC
  Result := Compute(FCurrentAlgorithm, FCurrentKey, FAccumulatedData);
  
  FInitialized := False;
  SetLength(FAccumulatedData, 0);
end;

function THMACMock.SetKey(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes): Boolean;
begin
  if FShouldFail then
  begin
    Result := False;
    Exit;
  end;
  
  FCurrentAlgorithm := aAlgorithm;
  FCurrentKey := Copy(aKey);
  Result := True;
end;

function THMACMock.GetKeySize: Integer;
begin
  Result := Length(FCurrentKey);
end;

function THMACMock.GetMACSize(const aAlgorithm: THMACAlgorithm): Integer;
begin
  case aAlgorithm of
    haMD5: Result := 16;
    haSHA1: Result := 20;
    haSHA224, haSHA3_224: Result := 28;
    haSHA256, haSHA3_256, haBLAKE2s256, haSM3: Result := 32;
    haSHA384, haSHA3_384: Result := 48;
    haSHA512, haSHA3_512, haBLAKE2b512: Result := 64;
  else
    Result := 0;
  end;
end;

function THMACMock.GetAlgorithmName(const aAlgorithm: THMACAlgorithm): string;
begin
  case aAlgorithm of
    haMD5: Result := 'HMAC-MD5';
    haSHA1: Result := 'HMAC-SHA1';
    haSHA224: Result := 'HMAC-SHA224';
    haSHA256: Result := 'HMAC-SHA256';
    haSHA384: Result := 'HMAC-SHA384';
    haSHA512: Result := 'HMAC-SHA512';
    haSHA3_224: Result := 'HMAC-SHA3-224';
    haSHA3_256: Result := 'HMAC-SHA3-256';
    haSHA3_384: Result := 'HMAC-SHA3-384';
    haSHA3_512: Result := 'HMAC-SHA3-512';
    haBLAKE2b512: Result := 'HMAC-BLAKE2b-512';
    haBLAKE2s256: Result := 'HMAC-BLAKE2s-256';
    haSM3: Result := 'HMAC-SM3';
  else
    Result := 'unknown';
  end;
end;

function THMACMock.Verify(const aAlgorithm: THMACAlgorithm;
  const aKey: TBytes; const aData: TBytes;
  const aExpectedMAC: TBytes): Boolean;
var
  LComputed: THMACResult;
  i: Integer;
begin
  Inc(FVerifyCallCount);
  
  if FShouldFail then
  begin
    Result := False;
    Exit;
  end;
  
  LComputed := Compute(aAlgorithm, aKey, aData);
  if not LComputed.Success then
  begin
    Result := False;
    Exit;
  end;
  
  if Length(LComputed.MAC) <> Length(aExpectedMAC) then
  begin
    Result := False;
    Exit;
  end;
  
  // Constant-time comparison (simulated)
  Result := True;
  for i := 0 to High(LComputed.MAC) do
    if LComputed.MAC[i] <> aExpectedMAC[i] then
    begin
      Result := False;
      // Don't exit early to simulate constant-time
    end;
end;

function THMACMock.GetOperationCount: Integer;
begin
  Result := FOperationCount;
end;

function THMACMock.GetUpdateCount: Integer;
begin
  Result := FUpdateCount;
end;

procedure THMACMock.ResetStatistics;
begin
  FOperationCount := 0;
  FUpdateCount := 0;
  FComputeCallCount := 0;
  FInitCallCount := 0;
  FFinalCallCount := 0;
  FVerifyCallCount := 0;
end;

{ Mock control methods }

procedure THMACMock.SetShouldFail(aValue: Boolean; const aMessage: string);
begin
  FShouldFail := aValue;
  FFailureMessage := aMessage;
end;

procedure THMACMock.SetCustomMAC(const aMAC: TBytes);
begin
  FCustomMAC := Copy(aMAC);
end;

function THMACMock.GetLastAlgorithm: THMACAlgorithm;
begin
  Result := FLastAlgorithm;
end;

function THMACMock.GetLastKeySize: Integer;
begin
  Result := FLastKeySize;
end;

function THMACMock.GetLastDataSize: Integer;
begin
  Result := FLastDataSize;
end;

function THMACMock.GetComputeCallCount: Integer;
begin
  Result := FComputeCallCount;
end;

function THMACMock.GetInitCallCount: Integer;
begin
  Result := FInitCallCount;
end;

function THMACMock.GetFinalCallCount: Integer;
begin
  Result := FFinalCallCount;
end;

function THMACMock.GetVerifyCallCount: Integer;
begin
  Result := FVerifyCallCount;
end;

function THMACMock.GetAccumulatedDataSize: Integer;
begin
  Result := Length(FAccumulatedData);
end;

function THMACMock.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

procedure THMACMock.Reset;
begin
  FOperationCount := 0;
  FUpdateCount := 0;
  FCurrentAlgorithm := haSHA256;
  SetLength(FCurrentKey, 0);
  FInitialized := False;
  FShouldFail := False;
  FFailureMessage := '';
  SetLength(FCustomMAC, 0);
  SetLength(FAccumulatedData, 0);
  FLastAlgorithm := haSHA256;
  FLastKeySize := 0;
  FLastDataSize := 0;
  FComputeCallCount := 0;
  FInitCallCount := 0;
  FFinalCallCount := 0;
  FVerifyCallCount := 0;
end;

end.

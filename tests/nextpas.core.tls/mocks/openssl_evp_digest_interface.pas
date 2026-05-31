unit openssl_evp_digest_interface;

{$mode objfpc}{$H+}

{
  EVP Digest (Hash) Interface Abstraction
  
  Purpose: Provide interface for EVP digest operations
  Allows: Real OpenSSL implementation OR Mock implementation
  Benefits: True unit testing, fast execution, isolated tests
}

interface

uses
  Classes, SysUtils;

type
  TDigestAlgorithm = (daNull, daMD5, daSHA1, daSHA224, daSHA256, daSHA384, daSHA512,
                      daSHA512_224, daSHA512_256, daSHA3_224, daSHA3_256, daSHA3_384, 
                      daSHA3_512, daBLAKE2b512, daBLAKE2s256, daSM3, daRIPEMD160);

  { Digest result record }
  TDigestResult = record
    Success: Boolean;
    Hash: TBytes;
    ErrorMessage: string;
  end;

  { IEVPDigest - Interface for EVP digest operations }
  IEVPDigest = interface
    ['{B1C2D3E4-F5A6-7B8C-9D0E-1F2A3B4C5D6E}']
    
    // Single-shot digest
    function Digest(const aAlgorithm: TDigestAlgorithm; 
                    const aData: TBytes): TDigestResult;
    
    // Incremental digest (for large data)
    function DigestInit(const aAlgorithm: TDigestAlgorithm): Boolean;
    function DigestUpdate(const aData: TBytes): Boolean;
    function DigestFinal: TDigestResult;
    
    // Algorithm queries
    function GetDigestSize(const aAlgorithm: TDigestAlgorithm): Integer;
    function GetBlockSize(const aAlgorithm: TDigestAlgorithm): Integer;
    function GetAlgorithmName(const aAlgorithm: TDigestAlgorithm): string;
    
    // Statistics
    function GetOperationCount: Integer;
    function GetUpdateCount: Integer;
    procedure ResetStatistics;
  end;

  { TEVPDigestReal - Real implementation using actual OpenSSL }
  TEVPDigestReal = class(TInterfacedObject, IEVPDigest)
  private
    FOperationCount: Integer;
    FUpdateCount: Integer;
    FCurrentAlgorithm: TDigestAlgorithm;
    FInitialized: Boolean;
  public
    constructor Create;
    
    // IEVPDigest implementation
    function Digest(const aAlgorithm: TDigestAlgorithm; 
                    const aData: TBytes): TDigestResult;
    function DigestInit(const aAlgorithm: TDigestAlgorithm): Boolean;
    function DigestUpdate(const aData: TBytes): Boolean;
    function DigestFinal: TDigestResult;
    function GetDigestSize(const aAlgorithm: TDigestAlgorithm): Integer;
    function GetBlockSize(const aAlgorithm: TDigestAlgorithm): Integer;
    function GetAlgorithmName(const aAlgorithm: TDigestAlgorithm): string;
    function GetOperationCount: Integer;
    function GetUpdateCount: Integer;
    procedure ResetStatistics;
  end;

  { TEVPDigestMock - Mock implementation for testing }
  TEVPDigestMock = class(TInterfacedObject, IEVPDigest)
  private
    FOperationCount: Integer;
    FUpdateCount: Integer;
    FCurrentAlgorithm: TDigestAlgorithm;
    FInitialized: Boolean;
    FShouldFail: Boolean;
    FFailureMessage: string;
    FCustomHash: TBytes;
    FAccumulatedData: TBytes;
    
    // Last call parameters for verification
    FLastAlgorithm: TDigestAlgorithm;
    FLastDataSize: Integer;
    FDigestCallCount: Integer;
    FInitCallCount: Integer;
    FFinalCallCount: Integer;
  public
    constructor Create;
    
    // IEVPDigest implementation
    function Digest(const aAlgorithm: TDigestAlgorithm; 
                    const aData: TBytes): TDigestResult;
    function DigestInit(const aAlgorithm: TDigestAlgorithm): Boolean;
    function DigestUpdate(const aData: TBytes): Boolean;
    function DigestFinal: TDigestResult;
    function GetDigestSize(const aAlgorithm: TDigestAlgorithm): Integer;
    function GetBlockSize(const aAlgorithm: TDigestAlgorithm): Integer;
    function GetAlgorithmName(const aAlgorithm: TDigestAlgorithm): string;
    function GetOperationCount: Integer;
    function GetUpdateCount: Integer;
    procedure ResetStatistics;
    
    // Mock control methods
    procedure SetShouldFail(aValue: Boolean; const aMessage: string = '');
    procedure SetCustomHash(const aHash: TBytes);
    function GetLastAlgorithm: TDigestAlgorithm;
    function GetLastDataSize: Integer;
    function GetDigestCallCount: Integer;
    function GetInitCallCount: Integer;
    function GetFinalCallCount: Integer;
    function GetAccumulatedDataSize: Integer;
    function IsInitialized: Boolean;
    procedure Reset;
  end;

implementation

{ TEVPDigestReal }

constructor TEVPDigestReal.Create;
begin
  inherited Create;
  FOperationCount := 0;
  FUpdateCount := 0;
  FInitialized := False;
end;

function TEVPDigestReal.Digest(const aAlgorithm: TDigestAlgorithm;
  const aData: TBytes): TDigestResult;
begin
  Inc(FOperationCount);
  // Real implementation would use OpenSSL EVP_Digest()
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.Hash, 0);
end;

function TEVPDigestReal.DigestInit(const aAlgorithm: TDigestAlgorithm): Boolean;
begin
  FCurrentAlgorithm := aAlgorithm;
  FInitialized := True;
  Result := True;
end;

function TEVPDigestReal.DigestUpdate(const aData: TBytes): Boolean;
begin
  if not FInitialized then
  begin
    Result := False;
    Exit;
  end;
  Inc(FUpdateCount);
  Result := True;
end;

function TEVPDigestReal.DigestFinal: TDigestResult;
begin
  Inc(FOperationCount);
  FInitialized := False;
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.Hash, 0);
end;

function TEVPDigestReal.GetDigestSize(const aAlgorithm: TDigestAlgorithm): Integer;
begin
  case aAlgorithm of
    daNull: Result := 0;
    daMD5: Result := 16;
    daSHA1: Result := 20;
    daSHA224, daSHA512_224, daSHA3_224: Result := 28;
    daSHA256, daSHA512_256, daSHA3_256, daBLAKE2s256, daSM3: Result := 32;
    daSHA384, daSHA3_384: Result := 48;
    daSHA512, daSHA3_512, daBLAKE2b512: Result := 64;
    daRIPEMD160: Result := 20;
  else
    Result := 0;
  end;
end;

function TEVPDigestReal.GetBlockSize(const aAlgorithm: TDigestAlgorithm): Integer;
begin
  case aAlgorithm of
    daNull: Result := 0;
    daMD5, daSHA1, daSHA224, daSHA256, daSM3, daRIPEMD160: Result := 64;
    daSHA384, daSHA512, daSHA512_224, daSHA512_256: Result := 128;
    daSHA3_224: Result := 144;
    daSHA3_256: Result := 136;
    daSHA3_384: Result := 104;
    daSHA3_512: Result := 72;
    daBLAKE2b512: Result := 128;
    daBLAKE2s256: Result := 64;
  else
    Result := 0;
  end;
end;

function TEVPDigestReal.GetAlgorithmName(const aAlgorithm: TDigestAlgorithm): string;
begin
  case aAlgorithm of
    daNull: Result := 'null';
    daMD5: Result := 'MD5';
    daSHA1: Result := 'SHA-1';
    daSHA224: Result := 'SHA-224';
    daSHA256: Result := 'SHA-256';
    daSHA384: Result := 'SHA-384';
    daSHA512: Result := 'SHA-512';
    daSHA512_224: Result := 'SHA-512/224';
    daSHA512_256: Result := 'SHA-512/256';
    daSHA3_224: Result := 'SHA3-224';
    daSHA3_256: Result := 'SHA3-256';
    daSHA3_384: Result := 'SHA3-384';
    daSHA3_512: Result := 'SHA3-512';
    daBLAKE2b512: Result := 'BLAKE2b-512';
    daBLAKE2s256: Result := 'BLAKE2s-256';
    daSM3: Result := 'SM3';
    daRIPEMD160: Result := 'RIPEMD-160';
  else
    Result := 'unknown';
  end;
end;

function TEVPDigestReal.GetOperationCount: Integer;
begin
  Result := FOperationCount;
end;

function TEVPDigestReal.GetUpdateCount: Integer;
begin
  Result := FUpdateCount;
end;

procedure TEVPDigestReal.ResetStatistics;
begin
  FOperationCount := 0;
  FUpdateCount := 0;
end;

{ TEVPDigestMock }

constructor TEVPDigestMock.Create;
begin
  inherited Create;
  Reset;
end;

function TEVPDigestMock.Digest(const aAlgorithm: TDigestAlgorithm;
  const aData: TBytes): TDigestResult;
var
  i: Integer;
  LHashSize: Integer;
begin
  Inc(FDigestCallCount);
  Inc(FOperationCount);
  
  FLastAlgorithm := aAlgorithm;
  FLastDataSize := Length(aData);
  
  if FShouldFail then
  begin
    Result.Success := False;
    Result.ErrorMessage := FFailureMessage;
    SetLength(Result.Hash, 0);
  end
  else
  begin
    Result.Success := True;
    Result.ErrorMessage := '';
    
    if Length(FCustomHash) > 0 then
      Result.Hash := Copy(FCustomHash)
    else
    begin
      // Mock: generate predictable hash based on data
      LHashSize := GetDigestSize(aAlgorithm);
      SetLength(Result.Hash, LHashSize);
      
      // Simple mock: XOR all input bytes, spread across hash
      for i := 0 to LHashSize - 1 do
      begin
        if Length(aData) > 0 then
          Result.Hash[i] := Byte((i * 17 + aData[i mod Length(aData)]) mod 256)
        else
          Result.Hash[i] := Byte(i * 13 mod 256);
      end;
    end;
  end;
end;

function TEVPDigestMock.DigestInit(const aAlgorithm: TDigestAlgorithm): Boolean;
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
    FInitialized := True;
    SetLength(FAccumulatedData, 0);
    Result := True;
  end;
end;

function TEVPDigestMock.DigestUpdate(const aData: TBytes): Boolean;
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

function TEVPDigestMock.DigestFinal: TDigestResult;
begin
  Inc(FFinalCallCount);
  Inc(FOperationCount);
  
  if not FInitialized then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Not initialized';
    SetLength(Result.Hash, 0);
    Exit;
  end;
  
  // Use accumulated data to compute final hash
  Result := Digest(FCurrentAlgorithm, FAccumulatedData);
  
  FInitialized := False;
  SetLength(FAccumulatedData, 0);
end;

function TEVPDigestMock.GetDigestSize(const aAlgorithm: TDigestAlgorithm): Integer;
begin
  case aAlgorithm of
    daNull: Result := 0;
    daMD5: Result := 16;
    daSHA1: Result := 20;
    daSHA224, daSHA512_224, daSHA3_224: Result := 28;
    daSHA256, daSHA512_256, daSHA3_256, daBLAKE2s256, daSM3: Result := 32;
    daSHA384, daSHA3_384: Result := 48;
    daSHA512, daSHA3_512, daBLAKE2b512: Result := 64;
    daRIPEMD160: Result := 20;
  else
    Result := 0;
  end;
end;

function TEVPDigestMock.GetBlockSize(const aAlgorithm: TDigestAlgorithm): Integer;
begin
  case aAlgorithm of
    daNull: Result := 0;
    daMD5, daSHA1, daSHA224, daSHA256, daSM3, daRIPEMD160: Result := 64;
    daSHA384, daSHA512, daSHA512_224, daSHA512_256: Result := 128;
    daSHA3_224: Result := 144;
    daSHA3_256: Result := 136;
    daSHA3_384: Result := 104;
    daSHA3_512: Result := 72;
    daBLAKE2b512: Result := 128;
    daBLAKE2s256: Result := 64;
  else
    Result := 0;
  end;
end;

function TEVPDigestMock.GetAlgorithmName(const aAlgorithm: TDigestAlgorithm): string;
begin
  case aAlgorithm of
    daNull: Result := 'null';
    daMD5: Result := 'MD5';
    daSHA1: Result := 'SHA-1';
    daSHA224: Result := 'SHA-224';
    daSHA256: Result := 'SHA-256';
    daSHA384: Result := 'SHA-384';
    daSHA512: Result := 'SHA-512';
    daSHA512_224: Result := 'SHA-512/224';
    daSHA512_256: Result := 'SHA-512/256';
    daSHA3_224: Result := 'SHA3-224';
    daSHA3_256: Result := 'SHA3-256';
    daSHA3_384: Result := 'SHA3-384';
    daSHA3_512: Result := 'SHA3-512';
    daBLAKE2b512: Result := 'BLAKE2b-512';
    daBLAKE2s256: Result := 'BLAKE2s-256';
    daSM3: Result := 'SM3';
    daRIPEMD160: Result := 'RIPEMD-160';
  else
    Result := 'unknown';
  end;
end;

function TEVPDigestMock.GetOperationCount: Integer;
begin
  Result := FOperationCount;
end;

function TEVPDigestMock.GetUpdateCount: Integer;
begin
  Result := FUpdateCount;
end;

procedure TEVPDigestMock.ResetStatistics;
begin
  FOperationCount := 0;
  FUpdateCount := 0;
  FDigestCallCount := 0;
  FInitCallCount := 0;
  FFinalCallCount := 0;
end;

{ Mock control methods }

procedure TEVPDigestMock.SetShouldFail(aValue: Boolean; const aMessage: string);
begin
  FShouldFail := aValue;
  FFailureMessage := aMessage;
end;

procedure TEVPDigestMock.SetCustomHash(const aHash: TBytes);
begin
  FCustomHash := Copy(aHash);
end;

function TEVPDigestMock.GetLastAlgorithm: TDigestAlgorithm;
begin
  Result := FLastAlgorithm;
end;

function TEVPDigestMock.GetLastDataSize: Integer;
begin
  Result := FLastDataSize;
end;

function TEVPDigestMock.GetDigestCallCount: Integer;
begin
  Result := FDigestCallCount;
end;

function TEVPDigestMock.GetInitCallCount: Integer;
begin
  Result := FInitCallCount;
end;

function TEVPDigestMock.GetFinalCallCount: Integer;
begin
  Result := FFinalCallCount;
end;

function TEVPDigestMock.GetAccumulatedDataSize: Integer;
begin
  Result := Length(FAccumulatedData);
end;

function TEVPDigestMock.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

procedure TEVPDigestMock.Reset;
begin
  FOperationCount := 0;
  FUpdateCount := 0;
  FCurrentAlgorithm := daNull;
  FInitialized := False;
  FShouldFail := False;
  FFailureMessage := '';
  SetLength(FCustomHash, 0);
  SetLength(FAccumulatedData, 0);
  FLastAlgorithm := daNull;
  FLastDataSize := 0;
  FDigestCallCount := 0;
  FInitCallCount := 0;
  FFinalCallCount := 0;
end;

end.

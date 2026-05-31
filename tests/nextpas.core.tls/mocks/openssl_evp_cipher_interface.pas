unit openssl_evp_cipher_interface;

{$mode objfpc}{$H+}

{
  EVP Cipher Interface Abstraction
  
  Purpose: Provide interface for EVP cipher operations
  Allows: Real OpenSSL implementation OR Mock implementation
  Benefits: True unit testing, fast execution, isolated tests
}

interface

uses
  Classes, SysUtils;

type
  TCipherMode = (cmECB, cmCBC, cmCFB, cmOFB, cmCTR, cmGCM, cmCCM, cmXTS, cmOCB);
  TCipherAlgorithm = (caAES128, caAES192, caAES256, caChaCha20, caChaCha20Poly1305, 
                      caCamellia128, caCamellia192, caCamellia256, caSM4);
  TCipherOperation = (coEncrypt, coDecrypt);

  { Cipher result record }
  TCipherResult = record
    Success: Boolean;
    Output: TBytes;
    Tag: TBytes;          // For AEAD modes (GCM, CCM, Poly1305)
    ErrorMessage: string;
  end;

  { IEVPCipher - Interface for EVP cipher operations }
  IEVPCipher = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    
    // Basic encryption/decryption
    function Encrypt(const aAlgorithm: TCipherAlgorithm; 
                     const aMode: TCipherMode;
                     const aKey: TBytes; 
                     const aIV: TBytes;
                     const aPlaintext: TBytes): TCipherResult;
                     
    function Decrypt(const aAlgorithm: TCipherAlgorithm;
                     const aMode: TCipherMode; 
                     const aKey: TBytes;
                     const aIV: TBytes; 
                     const aCiphertext: TBytes): TCipherResult;
    
    // AEAD mode operations with authenticated encryption
    function EncryptAEAD(const aAlgorithm: TCipherAlgorithm;
                         const aMode: TCipherMode;
                         const aKey: TBytes;
                         const aIV: TBytes;
                         const aPlaintext: TBytes;
                         const aAAD: TBytes): TCipherResult;
                         
    function DecryptAEAD(const aAlgorithm: TCipherAlgorithm;
                         const aMode: TCipherMode;
                         const aKey: TBytes;
                         const aIV: TBytes;
                         const aCiphertext: TBytes;
                         const aTag: TBytes;
                         const aAAD: TBytes): TCipherResult;
    
    // Padding control
    procedure SetPadding(aPadding: Boolean);
    function GetPadding: Boolean;
    
    // Key and IV size queries
    function GetKeySize(const aAlgorithm: TCipherAlgorithm): Integer;
    function GetIVSize(const aAlgorithm: TCipherAlgorithm; const aMode: TCipherMode): Integer;
    function GetBlockSize(const aAlgorithm: TCipherAlgorithm): Integer;
    
    // Statistics
    function GetOperationCount: Integer;
    procedure ResetStatistics;
  end;

  { TEVPCipherReal - Real implementation using actual OpenSSL }
  TEVPCipherReal = class(TInterfacedObject, IEVPCipher)
  private
    FPadding: Boolean;
    FOperationCount: Integer;
    function GetEVPCipher(const aAlgorithm: TCipherAlgorithm; const aMode: TCipherMode): Pointer;
  public
    constructor Create;
    
    // IEVPCipher implementation
    function Encrypt(const aAlgorithm: TCipherAlgorithm; 
                     const aMode: TCipherMode;
                     const aKey: TBytes; 
                     const aIV: TBytes;
                     const aPlaintext: TBytes): TCipherResult;
                     
    function Decrypt(const aAlgorithm: TCipherAlgorithm;
                     const aMode: TCipherMode; 
                     const aKey: TBytes;
                     const aIV: TBytes; 
                     const aCiphertext: TBytes): TCipherResult;
                     
    function EncryptAEAD(const aAlgorithm: TCipherAlgorithm;
                         const aMode: TCipherMode;
                         const aKey: TBytes;
                         const aIV: TBytes;
                         const aPlaintext: TBytes;
                         const aAAD: TBytes): TCipherResult;
                         
    function DecryptAEAD(const aAlgorithm: TCipherAlgorithm;
                         const aMode: TCipherMode;
                         const aKey: TBytes;
                         const aIV: TBytes;
                         const aCiphertext: TBytes;
                         const aTag: TBytes;
                         const aAAD: TBytes): TCipherResult;
                         
    procedure SetPadding(aPadding: Boolean);
    function GetPadding: Boolean;
    function GetKeySize(const aAlgorithm: TCipherAlgorithm): Integer;
    function GetIVSize(const aAlgorithm: TCipherAlgorithm; const aMode: TCipherMode): Integer;
    function GetBlockSize(const aAlgorithm: TCipherAlgorithm): Integer;
    function GetOperationCount: Integer;
    procedure ResetStatistics;
  end;

  { TEVPCipherMock - Mock implementation for testing }
  TEVPCipherMock = class(TInterfacedObject, IEVPCipher)
  private
    FPadding: Boolean;
    FOperationCount: Integer;
    FShouldFail: Boolean;
    FFailureMessage: string;
    FCustomOutput: TBytes;
    FCustomTag: TBytes;
    FEncryptCallCount: Integer;
    FDecryptCallCount: Integer;
    FAEADCallCount: Integer;
    
    // Store last call parameters for verification
    FLastAlgorithm: TCipherAlgorithm;
    FLastMode: TCipherMode;
    FLastOperation: TCipherOperation;
    FLastKeySize: Integer;
    FLastIVSize: Integer;
    FLastInputSize: Integer;
  public
    constructor Create;
    
    // IEVPCipher implementation
    function Encrypt(const aAlgorithm: TCipherAlgorithm; 
                     const aMode: TCipherMode;
                     const aKey: TBytes; 
                     const aIV: TBytes;
                     const aPlaintext: TBytes): TCipherResult;
                     
    function Decrypt(const aAlgorithm: TCipherAlgorithm;
                     const aMode: TCipherMode; 
                     const aKey: TBytes;
                     const aIV: TBytes; 
                     const aCiphertext: TBytes): TCipherResult;
                     
    function EncryptAEAD(const aAlgorithm: TCipherAlgorithm;
                         const aMode: TCipherMode;
                         const aKey: TBytes;
                         const aIV: TBytes;
                         const aPlaintext: TBytes;
                         const aAAD: TBytes): TCipherResult;
                         
    function DecryptAEAD(const aAlgorithm: TCipherAlgorithm;
                         const aMode: TCipherMode;
                         const aKey: TBytes;
                         const aIV: TBytes;
                         const aCiphertext: TBytes;
                         const aTag: TBytes;
                         const aAAD: TBytes): TCipherResult;
                         
    procedure SetPadding(aPadding: Boolean);
    function GetPadding: Boolean;
    function GetKeySize(const aAlgorithm: TCipherAlgorithm): Integer;
    function GetIVSize(const aAlgorithm: TCipherAlgorithm; const aMode: TCipherMode): Integer;
    function GetBlockSize(const aAlgorithm: TCipherAlgorithm): Integer;
    function GetOperationCount: Integer;
    procedure ResetStatistics;
    
    // Mock control methods
    procedure SetShouldFail(aValue: Boolean; const aMessage: string = '');
    procedure SetCustomOutput(const aOutput: TBytes);
    procedure SetCustomTag(const aTag: TBytes);
    function GetEncryptCallCount: Integer;
    function GetDecryptCallCount: Integer;
    function GetAEADCallCount: Integer;
    function GetLastAlgorithm: TCipherAlgorithm;
    function GetLastMode: TCipherMode;
    function GetLastOperation: TCipherOperation;
    function GetLastKeySize: Integer;
    function GetLastIVSize: Integer;
    function GetLastInputSize: Integer;
    procedure Reset;
  end;

implementation

{ TEVPCipherReal }

constructor TEVPCipherReal.Create;
begin
  inherited Create;
  FPadding := True;
  FOperationCount := 0;
end;

function TEVPCipherReal.GetEVPCipher(const aAlgorithm: TCipherAlgorithm; const aMode: TCipherMode): Pointer;
begin
  // This would call actual OpenSSL EVP_aes_256_cbc() etc.
  // Not implemented here - would require linking to real OpenSSL
  Result := nil;
end;

function TEVPCipherReal.Encrypt(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aPlaintext: TBytes): TCipherResult;
begin
  Inc(FOperationCount);
  // Real implementation would use OpenSSL EVP API
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.Output, 0);
  SetLength(Result.Tag, 0);
end;

function TEVPCipherReal.Decrypt(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aCiphertext: TBytes): TCipherResult;
begin
  Inc(FOperationCount);
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.Output, 0);
  SetLength(Result.Tag, 0);
end;

function TEVPCipherReal.EncryptAEAD(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aPlaintext: TBytes; const aAAD: TBytes): TCipherResult;
begin
  Inc(FOperationCount);
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.Output, 0);
  SetLength(Result.Tag, 0);
end;

function TEVPCipherReal.DecryptAEAD(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aCiphertext: TBytes; const aTag: TBytes; const aAAD: TBytes): TCipherResult;
begin
  Inc(FOperationCount);
  Result.Success := False;
  Result.ErrorMessage := 'Real implementation requires OpenSSL';
  SetLength(Result.Output, 0);
  SetLength(Result.Tag, 0);
end;

procedure TEVPCipherReal.SetPadding(aPadding: Boolean);
begin
  FPadding := aPadding;
end;

function TEVPCipherReal.GetPadding: Boolean;
begin
  Result := FPadding;
end;

function TEVPCipherReal.GetKeySize(const aAlgorithm: TCipherAlgorithm): Integer;
begin
  case aAlgorithm of
    caAES128, caCamellia128: Result := 16;
    caAES192, caCamellia192: Result := 24;
    caAES256, caCamellia256, caChaCha20, caChaCha20Poly1305: Result := 32;
    caSM4: Result := 16;
  else
    Result := 0;
  end;
end;

function TEVPCipherReal.GetIVSize(const aAlgorithm: TCipherAlgorithm; const aMode: TCipherMode): Integer;
begin
  if aMode = cmECB then
    Result := 0
  else if aMode in [cmGCM, cmCCM] then
    Result := 12  // Typical for GCM/CCM
  else if aAlgorithm = caChaCha20Poly1305 then
    Result := 12
  else
    Result := 16; // Standard block size
end;

function TEVPCipherReal.GetBlockSize(const aAlgorithm: TCipherAlgorithm): Integer;
begin
  if aAlgorithm in [caChaCha20, caChaCha20Poly1305] then
    Result := 1  // Stream cipher
  else
    Result := 16; // All others are 128-bit block ciphers
end;

function TEVPCipherReal.GetOperationCount: Integer;
begin
  Result := FOperationCount;
end;

procedure TEVPCipherReal.ResetStatistics;
begin
  FOperationCount := 0;
end;

{ TEVPCipherMock }

constructor TEVPCipherMock.Create;
begin
  inherited Create;
  Reset;
end;

function TEVPCipherMock.Encrypt(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aPlaintext: TBytes): TCipherResult;
var
  i: Integer;
begin
  Inc(FEncryptCallCount);
  Inc(FOperationCount);
  
  // Store call parameters
  FLastAlgorithm := aAlgorithm;
  FLastMode := aMode;
  FLastOperation := coEncrypt;
  FLastKeySize := Length(aKey);
  FLastIVSize := Length(aIV);
  FLastInputSize := Length(aPlaintext);
  
  if FShouldFail then
  begin
    Result.Success := False;
    Result.ErrorMessage := FFailureMessage;
    SetLength(Result.Output, 0);
    SetLength(Result.Tag, 0);
  end
  else
  begin
    Result.Success := True;
    Result.ErrorMessage := '';
    
    // Return custom output if set, otherwise simulate encryption
    if Length(FCustomOutput) > 0 then
      Result.Output := Copy(FCustomOutput)
    else
    begin
      // Mock: return input XOR with $AA pattern
      SetLength(Result.Output, Length(aPlaintext));
      Move(aPlaintext[0], Result.Output[0], Length(aPlaintext));
      // Simple XOR for mock
      for i := 0 to High(Result.Output) do
        Result.Output[i] := Result.Output[i] xor $AA;
    end;
    
    SetLength(Result.Tag, 0);
  end;
end;

function TEVPCipherMock.Decrypt(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aCiphertext: TBytes): TCipherResult;
var
  i: Integer;
begin
  Inc(FDecryptCallCount);
  Inc(FOperationCount);
  
  FLastAlgorithm := aAlgorithm;
  FLastMode := aMode;
  FLastOperation := coDecrypt;
  FLastKeySize := Length(aKey);
  FLastIVSize := Length(aIV);
  FLastInputSize := Length(aCiphertext);
  
  if FShouldFail then
  begin
    Result.Success := False;
    Result.ErrorMessage := FFailureMessage;
    SetLength(Result.Output, 0);
    SetLength(Result.Tag, 0);
  end
  else
  begin
    Result.Success := True;
    Result.ErrorMessage := '';
    
    if Length(FCustomOutput) > 0 then
      Result.Output := Copy(FCustomOutput)
    else
    begin
      // Mock: reverse of encrypt (XOR with $AA)
      SetLength(Result.Output, Length(aCiphertext));
      Move(aCiphertext[0], Result.Output[0], Length(aCiphertext));
      for i := 0 to High(Result.Output) do
        Result.Output[i] := Result.Output[i] xor $AA;
    end;
    
    SetLength(Result.Tag, 0);
  end;
end;

function TEVPCipherMock.EncryptAEAD(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aPlaintext: TBytes; const aAAD: TBytes): TCipherResult;
var
  i: Integer;
begin
  Inc(FAEADCallCount);
  Inc(FOperationCount);
  
  FLastAlgorithm := aAlgorithm;
  FLastMode := aMode;
  FLastOperation := coEncrypt;
  FLastKeySize := Length(aKey);
  FLastIVSize := Length(aIV);
  FLastInputSize := Length(aPlaintext);
  
  if FShouldFail then
  begin
    Result.Success := False;
    Result.ErrorMessage := FFailureMessage;
    SetLength(Result.Output, 0);
    SetLength(Result.Tag, 0);
  end
  else
  begin
    Result.Success := True;
    Result.ErrorMessage := '';
    
    if Length(FCustomOutput) > 0 then
      Result.Output := Copy(FCustomOutput)
    else
    begin
      SetLength(Result.Output, Length(aPlaintext));
      Move(aPlaintext[0], Result.Output[0], Length(aPlaintext));
      for i := 0 to High(Result.Output) do
        Result.Output[i] := Result.Output[i] xor $BB;
    end;
    
    // Generate mock tag
    if Length(FCustomTag) > 0 then
      Result.Tag := Copy(FCustomTag)
    else
    begin
      SetLength(Result.Tag, 16);
      for i := 0 to 15 do
        Result.Tag[i] := $CC + i;
    end;
  end;
end;

function TEVPCipherMock.DecryptAEAD(const aAlgorithm: TCipherAlgorithm;
  const aMode: TCipherMode; const aKey: TBytes; const aIV: TBytes;
  const aCiphertext: TBytes; const aTag: TBytes; const aAAD: TBytes): TCipherResult;
var
  i: Integer;
begin
  Inc(FAEADCallCount);
  Inc(FOperationCount);
  
  FLastAlgorithm := aAlgorithm;
  FLastMode := aMode;
  FLastOperation := coDecrypt;
  FLastKeySize := Length(aKey);
  FLastIVSize := Length(aIV);
  FLastInputSize := Length(aCiphertext);
  
  if FShouldFail then
  begin
    Result.Success := False;
    Result.ErrorMessage := FFailureMessage;
    SetLength(Result.Output, 0);
    SetLength(Result.Tag, 0);
  end
  else
  begin
    Result.Success := True;
    Result.ErrorMessage := '';
    
    if Length(FCustomOutput) > 0 then
      Result.Output := Copy(FCustomOutput)
    else
    begin
      SetLength(Result.Output, Length(aCiphertext));
      Move(aCiphertext[0], Result.Output[0], Length(aCiphertext));
      for i := 0 to High(Result.Output) do
        Result.Output[i] := Result.Output[i] xor $BB;
    end;
    
    SetLength(Result.Tag, 0);
  end;
end;

procedure TEVPCipherMock.SetPadding(aPadding: Boolean);
begin
  FPadding := aPadding;
end;

function TEVPCipherMock.GetPadding: Boolean;
begin
  Result := FPadding;
end;

function TEVPCipherMock.GetKeySize(const aAlgorithm: TCipherAlgorithm): Integer;
begin
  case aAlgorithm of
    caAES128, caCamellia128: Result := 16;
    caAES192, caCamellia192: Result := 24;
    caAES256, caCamellia256, caChaCha20, caChaCha20Poly1305: Result := 32;
    caSM4: Result := 16;
  else
    Result := 0;
  end;
end;

function TEVPCipherMock.GetIVSize(const aAlgorithm: TCipherAlgorithm; const aMode: TCipherMode): Integer;
begin
  if aMode = cmECB then
    Result := 0
  else if aMode in [cmGCM, cmCCM] then
    Result := 12
  else if aAlgorithm = caChaCha20Poly1305 then
    Result := 12
  else
    Result := 16;
end;

function TEVPCipherMock.GetBlockSize(const aAlgorithm: TCipherAlgorithm): Integer;
begin
  if aAlgorithm in [caChaCha20, caChaCha20Poly1305] then
    Result := 1
  else
    Result := 16;
end;

function TEVPCipherMock.GetOperationCount: Integer;
begin
  Result := FOperationCount;
end;

procedure TEVPCipherMock.ResetStatistics;
begin
  FOperationCount := 0;
  FEncryptCallCount := 0;
  FDecryptCallCount := 0;
  FAEADCallCount := 0;
end;

{ Mock control methods }

procedure TEVPCipherMock.SetShouldFail(aValue: Boolean; const aMessage: string);
begin
  FShouldFail := aValue;
  FFailureMessage := aMessage;
end;

procedure TEVPCipherMock.SetCustomOutput(const aOutput: TBytes);
begin
  FCustomOutput := Copy(aOutput);
end;

procedure TEVPCipherMock.SetCustomTag(const aTag: TBytes);
begin
  FCustomTag := Copy(aTag);
end;

function TEVPCipherMock.GetEncryptCallCount: Integer;
begin
  Result := FEncryptCallCount;
end;

function TEVPCipherMock.GetDecryptCallCount: Integer;
begin
  Result := FDecryptCallCount;
end;

function TEVPCipherMock.GetAEADCallCount: Integer;
begin
  Result := FAEADCallCount;
end;

function TEVPCipherMock.GetLastAlgorithm: TCipherAlgorithm;
begin
  Result := FLastAlgorithm;
end;

function TEVPCipherMock.GetLastMode: TCipherMode;
begin
  Result := FLastMode;
end;

function TEVPCipherMock.GetLastOperation: TCipherOperation;
begin
  Result := FLastOperation;
end;

function TEVPCipherMock.GetLastKeySize: Integer;
begin
  Result := FLastKeySize;
end;

function TEVPCipherMock.GetLastIVSize: Integer;
begin
  Result := FLastIVSize;
end;

function TEVPCipherMock.GetLastInputSize: Integer;
begin
  Result := FLastInputSize;
end;

procedure TEVPCipherMock.Reset;
begin
  FPadding := True;
  FOperationCount := 0;
  FShouldFail := False;
  FFailureMessage := '';
  SetLength(FCustomOutput, 0);
  SetLength(FCustomTag, 0);
  FEncryptCallCount := 0;
  FDecryptCallCount := 0;
  FAEADCallCount := 0;
  FLastAlgorithm := caAES256;
  FLastMode := cmCBC;
  FLastOperation := coEncrypt;
  FLastKeySize := 0;
  FLastIVSize := 0;
  FLastInputSize := 0;
end;

end.

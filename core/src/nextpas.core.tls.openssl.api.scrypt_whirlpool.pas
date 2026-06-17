unit nextpas.core.tls.openssl.api.scrypt_whirlpool;

{$mode ObjFPC}{$H+}
// {$I nextpas.core.tls.openssl.inc}  // Include file not found, commented out

interface

uses nextpas.core.base, nextpas.core.text.conv, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader;

type
  // WHIRLPOOL types
  WHIRLPOOL_CTX = packed record
    H: array[0..7] of UInt64;
    data: array[0..63] of Byte;
    bitoff: Cardinal;
    bitlen: array[0..31] of Byte;
  end;
  PWHIRLPOOL_CTX = ^WHIRLPOOL_CTX;

const
  // WHIRLPOOL constants
  WHIRLPOOL_DIGEST_LENGTH = 64;
  WHIRLPOOL_DATA_SIZE = 64;
  
  // SCRYPT constants
  SCRYPT_DEFAULT_N = 32768;  // 2^15
  SCRYPT_DEFAULT_R = 8;
  SCRYPT_DEFAULT_P = 1;

var
  // SCRYPT functions
  EVP_PBE_scrypt: function(const pass: PAnsiChar; passlen: NativeUInt;
    const salt: PByte; saltlen: NativeUInt;
    N: UInt64; r: UInt64; p: UInt64; maxmem: UInt64;
    key: PByte; keylen: NativeUInt): Integer; cdecl = nil;
  
  PKCS5_PBKDF2_HMAC: function(const pass: PAnsiChar; passlen: Integer;
    const salt: PByte; saltlen: Integer;
    iter: Integer; const digest: PEVP_MD;
    keylen: Integer; output: PByte): Integer; cdecl = nil;
  
  // WHIRLPOOL functions
  WHIRLPOOL_Init: function(c: PWHIRLPOOL_CTX): Integer; cdecl = nil;
  WHIRLPOOL_Update: function(c: PWHIRLPOOL_CTX; const data: Pointer; 
    len: NativeUInt): Integer; cdecl = nil;
  WHIRLPOOL_Final: function(md: PByte; c: PWHIRLPOOL_CTX): Integer; cdecl = nil;
  WHIRLPOOL: function(const data: PByte; count: NativeUInt; 
    md: PByte): PByte; cdecl = nil;
  WHIRLPOOL_BitUpdate: procedure(c: PWHIRLPOOL_CTX; const data: Pointer; 
    len: NativeUInt); cdecl = nil;
  
  // EVP functions
  EVP_whirlpool: function(): PEVP_MD; cdecl = nil;

procedure LoadScryptWhirlpoolFunctions(AHandle: TPlatformLibrary);
procedure UnloadScryptWhirlpoolFunctions;

// Helper functions
function ScryptHashPassword(const Password, Salt: string; 
  N: UInt64 = SCRYPT_DEFAULT_N; r: UInt64 = SCRYPT_DEFAULT_R; 
  p: UInt64 = SCRYPT_DEFAULT_P; KeyLen: Integer = 32): TBytes;
function WhirlpoolHash(const Data: TBytes): TBytes;
function WhirlpoolHashString(const S: string): string;

implementation


procedure LoadScryptWhirlpoolFunctions(AHandle: TPlatformLibrary);
type
  TEVP_PBE_scrypt = function(const pass: PAnsiChar; passlen: NativeUInt;
    const salt: PByte; saltlen: NativeUInt;
    N: UInt64; r: UInt64; p: UInt64; maxmem: UInt64;
    key: PByte; keylen: NativeUInt): Integer; cdecl;
  TPKCS5_PBKDF2_HMAC = function(const pass: PAnsiChar; passlen: Integer;
    const salt: PByte; saltlen: Integer;
    iter: Integer; const digest: PEVP_MD;
    keylen: Integer; output: PByte): Integer; cdecl;
  TWHIRLPOOL_Init = function(c: PWHIRLPOOL_CTX): Integer; cdecl;
  TWHIRLPOOL_Update = function(c: PWHIRLPOOL_CTX; const data: Pointer; 
    len: NativeUInt): Integer; cdecl;
  TWHIRLPOOL_Final = function(md: PByte; c: PWHIRLPOOL_CTX): Integer; cdecl;
  TWHIRLPOOL = function(const data: PByte; count: NativeUInt; 
    md: PByte): PByte; cdecl;
  TWHIRLPOOL_BitUpdate = procedure(c: PWHIRLPOOL_CTX; const data: Pointer; 
    len: NativeUInt); cdecl;
  TEVP_whirlpool = function(): PEVP_MD; cdecl;
begin
  if not LibLoaded(AHandle) then Exit;
  
  // SCRYPT functions
  EVP_PBE_scrypt := TEVP_PBE_scrypt(GetProcSymbol(AHandle, 'EVP_PBE_scrypt'));
  PKCS5_PBKDF2_HMAC := TPKCS5_PBKDF2_HMAC(GetProcSymbol(AHandle, 'PKCS5_PBKDF2_HMAC'));
  
  // WHIRLPOOL functions
  WHIRLPOOL_Init := TWHIRLPOOL_Init(GetProcSymbol(AHandle, 'WHIRLPOOL_Init'));
  WHIRLPOOL_Update := TWHIRLPOOL_Update(GetProcSymbol(AHandle, 'WHIRLPOOL_Update'));
  WHIRLPOOL_Final := TWHIRLPOOL_Final(GetProcSymbol(AHandle, 'WHIRLPOOL_Final'));
  WHIRLPOOL := TWHIRLPOOL(GetProcSymbol(AHandle, 'WHIRLPOOL'));
  WHIRLPOOL_BitUpdate := TWHIRLPOOL_BitUpdate(GetProcSymbol(AHandle, 'WHIRLPOOL_BitUpdate'));
  
  // EVP functions
  EVP_whirlpool := TEVP_whirlpool(GetProcSymbol(AHandle, 'EVP_whirlpool'));
end;

procedure UnloadScryptWhirlpoolFunctions;
begin
  EVP_PBE_scrypt := nil;
  PKCS5_PBKDF2_HMAC := nil;
  WHIRLPOOL_Init := nil;
  WHIRLPOOL_Update := nil;
  WHIRLPOOL_Final := nil;
  WHIRLPOOL := nil;
  WHIRLPOOL_BitUpdate := nil;
  EVP_whirlpool := nil;
end;

function ScryptHashPassword(const Password, Salt: string; 
  N: UInt64; r: UInt64; p: UInt64; KeyLen: Integer): TBytes;
begin
  Result := nil;
  SetLength(Result, KeyLen);
  if Assigned(EVP_PBE_scrypt) then
  begin
    if EVP_PBE_scrypt(PAnsiChar(AnsiString(Password)), Length(Password),
                      PByte(PAnsiChar(AnsiString(Salt))), Length(Salt),
                      N, r, p, 0, @Result[0], KeyLen) <> 1 then
    begin
      SetLength(Result, 0);
    end;
  end;
end;

function WhirlpoolHash(const Data: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, WHIRLPOOL_DIGEST_LENGTH);
  if Assigned(WHIRLPOOL) and (Length(Data) > 0) then
    WHIRLPOOL(@Data[0], Length(Data), @Result[0])
  else
    FillChar(Result[0], WHIRLPOOL_DIGEST_LENGTH, 0);
end;

function WhirlpoolHashString(const S: string): string;
var
  Data: TBytes;
  Hash: TBytes;
  I: Integer;
  HexStr: AnsiString;
  UStr: UnicodeString;
begin
  UStr := UnicodeString(S);
  Data := nextpas.core.text.conv.StringToUTF8Bytes(UStr);
  Hash := WhirlpoolHash(Data);
  HexStr := '';
  for I := 0 to High(Hash) do
    HexStr := HexStr + AnsiString(IntToHex(Hash[I], 2));
  Result := string(HexStr);
end;

end.

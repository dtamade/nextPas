{**
 * Unit: nextpas.core.tls.random
 * Purpose: 平台无关的加密安全随机数生成
 *
 * 此模块提供跨平台的加密安全随机数生成功能，
 * 不依赖于任何特定的 SSL 后端（OpenSSL 或 WinSSL）。
 *
 * 实现:
 * - Windows: 使用 CryptGenRandom (CryptoAPI) 或 BCryptGenRandom (CNG)
 * - Linux/macOS: 使用 /dev/urandom 或 getrandom() 系统调用
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-06
 *}

unit nextpas.core.tls.random;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils, Classes, nextpas.core.fs
  {$IFDEF USE_RANDOM_POOL}
  , nextpas.core.tls.random.pool
  {$ENDIF}
;

type
  {**
   * 安全随机数生成异常
   *}
  ESecureRandomError = class(Exception);

{**
 * 生成加密安全的随机字节
 *
 * @param ABuffer 输出缓冲区指针
 * @param ACount 要生成的字节数
 * @return True 成功，False 失败
 *}
function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;

{**
 * 生成加密安全的随机字节数组
 *
 * @param ACount 要生成的字节数
 * @return 随机字节数组
 * @raises ESecureRandomError 生成失败时
 *}
function GenerateSecureRandomBytes(ACount: Integer): TBytes;

{**
 * 生成加密安全的随机十六进制字符串
 *
 * @param ALength 输出字符串长度（每2个字符对应1个字节）
 * @return 十六进制字符串
 * @raises ESecureRandomError 生成失败时
 *}
function GenerateSecureRandomHex(ALength: Integer): string;

{**
 * 检查安全随机数生成器是否可用
 *
 * @return True 可用，False 不可用
 *}
function IsSecureRandomAvailable: Boolean;

implementation

{$IFDEF WINDOWS}
uses
  Windows;

const
  PROV_RSA_FULL = 1;
  CRYPT_VERIFYCONTEXT = $F0000000;
  CRYPT_SILENT = $00000040;

type
  HCRYPTPROV = NativeUInt;

function CryptAcquireContextW(
  var phProv: HCRYPTPROV;
  pszContainer: PWideChar;
  pszProvider: PWideChar;
  dwProvType: DWORD;
  dwFlags: DWORD
): BOOL; stdcall; external 'advapi32.dll';

function CryptReleaseContext(
  hProv: HCRYPTPROV;
  dwFlags: DWORD
): BOOL; stdcall; external 'advapi32.dll';

function CryptGenRandom(
  hProv: HCRYPTPROV;
  dwLen: DWORD;
  pbBuffer: PByte
): BOOL; stdcall; external 'advapi32.dll';

var
  GCryptProv: HCRYPTPROV = 0;
  GCryptProvInitialized: Boolean = False;
  GCryptProvLock: TRTLCriticalSection;

procedure InitializeCryptProvider;
begin
  EnterCriticalSection(GCryptProvLock);
  try
    if not GCryptProvInitialized then
    begin
      if CryptAcquireContextW(GCryptProv, nil, nil, PROV_RSA_FULL,
        CRYPT_VERIFYCONTEXT or CRYPT_SILENT) then
        GCryptProvInitialized := True;
    end;
  finally
    LeaveCriticalSection(GCryptProvLock);
  end;
end;

procedure FinalizeCryptProvider;
begin
  EnterCriticalSection(GCryptProvLock);
  try
    if GCryptProvInitialized and (GCryptProv <> 0) then
    begin
      CryptReleaseContext(GCryptProv, 0);
      GCryptProv := 0;
      GCryptProvInitialized := False;
    end;
  finally
    LeaveCriticalSection(GCryptProvLock);
  end;
  DoneCriticalSection(GCryptProvLock);
end;

function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;
begin
  Result := False;
  if (ABuffer = nil) or (ACount <= 0) then
    Exit;

  InitializeCryptProvider;

  if GCryptProvInitialized then
    Result := CryptGenRandom(GCryptProv, DWORD(ACount), ABuffer);
end;

function IsSecureRandomAvailable: Boolean;
begin
  InitializeCryptProvider;
  Result := GCryptProvInitialized;
end;

{$ELSE}
// Linux/macOS implementation using /dev/urandom

function SecureRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;
var
  LFile: TFileStream;
  LBytesRead: Integer;
begin
  Result := False;
  if (ABuffer = nil) or (ACount <= 0) then
    Exit;

  try
    LFile := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyWrite);
    try
      LBytesRead := LFile.Read(ABuffer^, ACount);
      Result := (LBytesRead = ACount);
    finally
      LFile.Free;
    end;
  except
    Result := False;
  end;
end;

function IsSecureRandomAvailable: Boolean;
begin
  Result := nextpas.core.fs.IsFile('/dev/urandom');
end;

{$ENDIF}

function GenerateSecureRandomBytes(ACount: Integer): TBytes;
begin
  Result := nil;
  if ACount <= 0 then
    raise ESecureRandomError.CreateFmt('Invalid byte count: %d', [ACount]);

  SetLength(Result, ACount);

  // Phase B 优化：优先使用缓存池（如果启用）
  // 缓存池会自动判断是否使用池化，大请求会直接调用底层生成器
  {$IFDEF USE_RANDOM_POOL}
  if not PooledRandomBytes(@Result[0], ACount) then
  {$ELSE}
  if not SecureRandomBytes(@Result[0], ACount) then
  {$ENDIF}
  begin
    // 清零失败的缓冲区
    FillChar(Result[0], ACount, 0);
    SetLength(Result, 0);
    raise ESecureRandomError.Create('Failed to generate secure random bytes');
  end;
end;

function GenerateSecureRandomHex(ALength: Integer): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  LBytes: TBytes;
  LByteCount: Integer;
  I: Integer;
begin
  Result := '';
  if ALength <= 0 then
    Exit;

  // 每2个十六进制字符对应1个字节
  LByteCount := (ALength + 1) div 2;
  LBytes := GenerateSecureRandomBytes(LByteCount);

  try
    SetLength(Result, ALength);
    for I := 0 to LByteCount - 1 do
    begin
      if (I * 2 + 1) <= ALength then
        Result[I * 2 + 1] := HexChars[LBytes[I] shr 4];
      if (I * 2 + 2) <= ALength then
        Result[I * 2 + 2] := HexChars[LBytes[I] and $0F];
    end;
  finally
    // 清零敏感数据
    if Length(LBytes) > 0 then
      FillChar(LBytes[0], Length(LBytes), 0);
  end;
end;

{$IFDEF WINDOWS}
initialization
  InitCriticalSection(GCryptProvLock);

finalization
  FinalizeCryptProvider;
{$ENDIF}

end.

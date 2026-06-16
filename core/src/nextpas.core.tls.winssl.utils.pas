{
  nextpas.core.tls.winssl.utils - Windows Schannel 辅助工具函数
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-10-06
  
  描述:
    提供 WinSSL 后端所需的辅助工具函数，包括：
    - 错误码转换和错误消息获取
    - 协议版本映射
    - 缓冲区管理工具
    - 调试和日志辅助函数
}

unit nextpas.core.tls.winssl.utils;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  Windows, nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.base;

// ============================================================================
// 错误码处理
// ============================================================================

{ 将 Schannel 错误码映射为可读的错误类别 }
type
  TSchannelErrorCategory = (
    secSuccess,           // 成功
    secContinue,          // 需要继续
    secIncomplete,        // 消息不完整
    secCertificateError,  // 证书错误
    secAuthError,         // 认证错误
    secConnectionError,   // 连接错误
    secInternalError,     // 内部错误
    secUnknownError       // 未知错误
  );

{ 获取错误码的类别 }
function GetSchannelErrorCategory(dwError: SECURITY_STATUS): TSchannelErrorCategory;

{ 将 Schannel 错误码转换为可读的错误消息 }
function GetSchannelErrorString(dwError: SECURITY_STATUS): string;

{ WinSSL 服务端支持 - 任务 4.1: 将 Schannel 错误映射到 SSL 错误类型 }
function MapSchannelErrorToSSLError(dwError: SECURITY_STATUS): TSSLErrorCode;

{ 将 Schannel 错误码转换为系统错误消息（通过 FormatMessage）}
function GetSystemErrorMessage(dwError: DWORD): string;

{ 检查错误码是否表示需要继续握手 }
function IsHandshakeContinue(dwError: SECURITY_STATUS): Boolean; inline;

{ 检查错误码是否表示消息不完整 }
function IsIncompleteMessage(dwError: SECURITY_STATUS): Boolean; inline;

{ 检查错误码是否表示成功 }
function IsSuccess(dwError: SECURITY_STATUS): Boolean; inline;

// ============================================================================
// 协议版本映射
// ============================================================================
// Note: Using TSSLProtocolVersion and TSSLProtocolVersions from nextpas.core.tls.base

{ 将协议版本集合转换为 Schannel 协议标志（客户端）}
function ProtocolVersionsToSchannelFlags(aVersions: TSSLProtocolVersions; 
                                        aIsServer: Boolean = False): DWORD;

{ 从 Schannel 协议标志解析版本集合 }
function SchannelFlagsToProtocolVersions(dwFlags: DWORD; 
                                        aIsServer: Boolean = False): TSSLProtocolVersions;

{ 获取协议版本的可读名称 }
function GetProtocolVersionName(aVersion: TSSLProtocolVersion): string;

{ 检查协议版本是否已废弃 }
function IsProtocolDeprecated(aVersion: TSSLProtocolVersion): Boolean; inline;

// ============================================================================
// 缓冲区管理
// ============================================================================

{ 分配 SecBuffer }
function AllocSecBuffer(aSize: ULONG; aType: ULONG): PSecBuffer;

{ 释放 SecBuffer }
procedure FreeSecBuffer(pBuffer: PSecBuffer);

{ 分配 SecBufferDesc }
function AllocSecBufferDesc(aBufferCount: ULONG): PSecBufferDesc;

{ 释放 SecBufferDesc（包括其中的所有 SecBuffer）}
procedure FreeSecBufferDesc(pBufferDesc: PSecBufferDesc);

{ 初始化 Security Handle }
procedure InitSecHandle(var Handle: TSecHandle); inline;

{ 检查 Security Handle 是否有效 }
function IsValidSecHandle(const Handle: TSecHandle): Boolean; inline;

{ 清空 Security Handle }
procedure ClearSecHandle(var Handle: TSecHandle); inline;

// ============================================================================
// 字符串转换辅助
// ============================================================================

{ 将 string 转换为 PWideChar（内部分配内存）}
function StringToPWideChar(const S: string): PWideChar;

{ 释放 StringToPWideChar 分配的内存 }
procedure FreePWideCharString(P: PWideChar);

{ 将 ANSI string 转换为 UTF-16 }
function AnsiToWide(const S: AnsiString): WideString;

{ 将 UTF-16 转换为 UTF-8 string }
function WideToUTF8(const S: WideString): string;

// ============================================================================
// 调试和日志辅助
// ============================================================================

{$IFDEF DEBUG}
{ 输出调试信息（仅在 DEBUG 模式下）}
procedure DebugLog(const Msg: string);

{ 输出 SecBuffer 的调试信息 }
procedure DebugDumpSecBuffer(const Buffer: TSecBuffer; const Prefix: string = '');

{ 输出 SecBufferDesc 的调试信息 }
procedure DebugDumpSecBufferDesc(const BufferDesc: TSecBufferDesc; const Prefix: string = '');
{$ENDIF}

// ============================================================================
// 实现部分
// ============================================================================

implementation

// ============================================================================
// 错误码处理实现
// ============================================================================

function GetSchannelErrorCategory(dwError: SECURITY_STATUS): TSchannelErrorCategory;
begin
  // 成功状态
  if dwError = SEC_E_OK then
    Exit(secSuccess);
    
  // 需要继续
  if (dwError = SEC_I_CONTINUE_NEEDED) or 
    (dwError = SEC_I_COMPLETE_NEEDED) or
    (dwError = SEC_I_COMPLETE_AND_CONTINUE) then
    Exit(secContinue);
    
  // 消息不完整
  if dwError = SEC_E_INCOMPLETE_MESSAGE then
    Exit(secIncomplete);
    
  // 证书错误
  if (dwError = SEC_E_CERT_EXPIRED) or 
    (dwError = SEC_E_CERT_UNKNOWN) or
    (dwError = SEC_E_UNTRUSTED_ROOT) or
    (dwError = SEC_E_WRONG_PRINCIPAL) then
    Exit(secCertificateError);
    
  // 认证错误
  if (dwError = SEC_E_LOGON_DENIED) or
    (dwError = SEC_E_NO_CREDENTIALS) or
    (dwError = SEC_E_UNKNOWN_CREDENTIALS) then
    Exit(secAuthError);
    
  // 连接错误
  if (dwError = SEC_E_ILLEGAL_MESSAGE) or
    (dwError = SEC_E_MESSAGE_ALTERED) or
    (dwError = SEC_E_OUT_OF_SEQUENCE) or
    (dwError = SEC_E_DECRYPT_FAILURE) then
    Exit(secConnectionError);
    
  // 内部错误
  if (dwError = SEC_E_INTERNAL_ERROR) or
    (dwError = SEC_E_INSUFFICIENT_MEMORY) then
    Exit(secInternalError);
    
  Result := secUnknownError;
end;

function GetSchannelErrorString(dwError: SECURITY_STATUS): string;
begin
  case dwError of
    // 成功状态
    SEC_E_OK: 
      Result := 'Success';
      
    // 信息状态
    SEC_I_CONTINUE_NEEDED: 
      Result := 'Continue needed';
    SEC_I_COMPLETE_NEEDED: 
      Result := 'Complete needed';
    SEC_I_COMPLETE_AND_CONTINUE: 
      Result := 'Complete and continue';
    SEC_I_CONTEXT_EXPIRED: 
      Result := 'Context expired';
    SEC_I_RENEGOTIATE: 
      Result := 'Renegotiate';
      
    // 证书错误
    SEC_E_CERT_EXPIRED: 
      Result := 'Certificate expired';
    SEC_E_CERT_UNKNOWN: 
      Result := 'Unknown certificate';
    SEC_E_UNTRUSTED_ROOT: 
      Result := 'Untrusted root certificate';
    SEC_E_WRONG_PRINCIPAL: 
      Result := 'Wrong principal';
      
    // 认证错误
    SEC_E_LOGON_DENIED: 
      Result := 'Logon denied';
    SEC_E_NO_CREDENTIALS: 
      Result := 'No credentials available';
    SEC_E_UNKNOWN_CREDENTIALS: 
      Result := 'Unknown credentials';
      
    // 消息错误
    SEC_E_INCOMPLETE_MESSAGE: 
      Result := 'Incomplete message';
    SEC_E_ILLEGAL_MESSAGE: 
      Result := 'Illegal message';
    SEC_E_MESSAGE_ALTERED: 
      Result := 'Message altered';
    SEC_E_OUT_OF_SEQUENCE: 
      Result := 'Out of sequence';
      
    // 加密错误
    SEC_E_ENCRYPT_FAILURE: 
      Result := 'Encryption failed';
    SEC_E_DECRYPT_FAILURE: 
      Result := 'Decryption failed';
    SEC_E_ALGORITHM_MISMATCH: 
      Result := 'Algorithm mismatch';
      
    // 句柄错误
    SEC_E_INVALID_HANDLE: 
      Result := 'Invalid handle';
    SEC_E_INVALID_TOKEN: 
      Result := 'Invalid token';
      
    // 内部错误
    SEC_E_INTERNAL_ERROR: 
      Result := 'Internal error';
    SEC_E_INSUFFICIENT_MEMORY: 
      Result := 'Insufficient memory';
    SEC_E_BUFFER_TOO_SMALL: 
      Result := 'Buffer too small';
      
    // 其他
    SEC_E_TARGET_UNKNOWN: 
      Result := 'Target unknown';
    SEC_E_UNSUPPORTED_FUNCTION: 
      Result := 'Unsupported function';
    SEC_E_SECPKG_NOT_FOUND: 
      Result := 'Security package not found';
      
  else
    Result := Format('Unknown error (0x%x)', [DWORD(dwError)]);
  end;
  
  // 添加错误码的十六进制表示
  Result := Result + Format(' [0x%x]', [DWORD(dwError)]);
end;

function GetSystemErrorMessage(dwError: DWORD): string;
var
  Buffer: array[0..1023] of Char;
  Len: DWORD;
begin
  Len := FormatMessage(
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    nil,
    dwError,
    MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    @Buffer[0],
    SizeOf(Buffer) div SizeOf(Char),
    nil
  );
  
  if Len > 0 then
  begin
    SetString(Result, Buffer, Len);
    Result := Trim(Result); // 去除尾部的换行符
  end
  else
    Result := Format('System error %d (0x%x)', [dwError, dwError]);
end;

function IsHandshakeContinue(dwError: SECURITY_STATUS): Boolean;
begin
  Result := (dwError = SEC_I_CONTINUE_NEEDED) or
            (dwError = SEC_I_COMPLETE_NEEDED) or
            (dwError = SEC_I_COMPLETE_AND_CONTINUE);
end;

function IsIncompleteMessage(dwError: SECURITY_STATUS): Boolean;
begin
  Result := (dwError = SEC_E_INCOMPLETE_MESSAGE);
end;

function IsSuccess(dwError: SECURITY_STATUS): Boolean;
begin
  Result := (dwError = SEC_E_OK);
end;

{ WinSSL 服务端支持 - 任务 4.1: 将 Schannel 错误映射到 SSL 错误类型
  根据设计文档中的错误码映射表实现 }
function MapSchannelErrorToSSLError(dwError: SECURITY_STATUS): TSSLErrorCode;
begin
  case dwError of
    // 成功
    SEC_E_OK:
      Result := sslErrNone;
      
    // 需要更多数据/操作
    SEC_E_INCOMPLETE_MESSAGE:
      Result := sslErrWantRead;
    SEC_I_CONTINUE_NEEDED,
    SEC_I_COMPLETE_NEEDED,
    SEC_I_COMPLETE_AND_CONTINUE:
      Result := sslErrWantWrite;
      
    // 证书错误
    SEC_E_CERT_EXPIRED,
    SEC_E_CERT_UNKNOWN,
    SEC_E_UNTRUSTED_ROOT,
    SEC_E_WRONG_PRINCIPAL:
      Result := sslErrCertificate;
      
    // 握手/协议错误
    SEC_E_ALGORITHM_MISMATCH,
    SEC_E_ILLEGAL_MESSAGE,
    SEC_E_UNSUPPORTED_FUNCTION:
      Result := sslErrHandshake;
      
    // 加密/解密错误
    SEC_E_DECRYPT_FAILURE:
      Result := sslErrDecryptionFailed;
    SEC_E_ENCRYPT_FAILURE:
      Result := sslErrEncryptionFailed;
    SEC_E_MESSAGE_ALTERED:
      Result := sslErrProtocol;
      
    // 配置错误
    SEC_E_NO_CREDENTIALS,
    SEC_E_UNKNOWN_CREDENTIALS,
    SEC_E_INVALID_HANDLE,
    SEC_E_INVALID_TOKEN:
      Result := sslErrConfiguration;
      
    // 内存/资源错误
    SEC_E_INSUFFICIENT_MEMORY,
    SEC_E_BUFFER_TOO_SMALL:
      Result := sslErrMemory;
      
  else
    // 其他未知错误
    Result := sslErrOther;
  end;
end;

// ============================================================================
// 协议版本映射实现
// ============================================================================

function ProtocolVersionsToSchannelFlags(aVersions: TSSLProtocolVersions; 
                                        aIsServer: Boolean): DWORD;
begin
  Result := 0;
  
  if aIsServer then
  begin
    // 服务器端标志
    if sslProtocolSSL2 in aVersions then
      Result := Result or SP_PROT_SSL2_SERVER;
    if sslProtocolSSL3 in aVersions then
      Result := Result or SP_PROT_SSL3_SERVER;
    if sslProtocolTLS10 in aVersions then
      Result := Result or SP_PROT_TLS1_0_SERVER;
    if sslProtocolTLS11 in aVersions then
      Result := Result or SP_PROT_TLS1_1_SERVER;
    if sslProtocolTLS12 in aVersions then
      Result := Result or SP_PROT_TLS1_2_SERVER;
    if sslProtocolTLS13 in aVersions then
      Result := Result or SP_PROT_TLS1_3_SERVER;
    if sslProtocolDTLS10 in aVersions then
      Result := Result or SP_PROT_DTLS1_0_SERVER;
    if sslProtocolDTLS12 in aVersions then
      Result := Result or SP_PROT_DTLS1_2_SERVER;
  end
  else
  begin
    // 客户端标志
    if sslProtocolSSL2 in aVersions then
      Result := Result or SP_PROT_SSL2_CLIENT;
    if sslProtocolSSL3 in aVersions then
      Result := Result or SP_PROT_SSL3_CLIENT;
    if sslProtocolTLS10 in aVersions then
      Result := Result or SP_PROT_TLS1_0_CLIENT;
    if sslProtocolTLS11 in aVersions then
      Result := Result or SP_PROT_TLS1_1_CLIENT;
    if sslProtocolTLS12 in aVersions then
      Result := Result or SP_PROT_TLS1_2_CLIENT;
    if sslProtocolTLS13 in aVersions then
      Result := Result or SP_PROT_TLS1_3_CLIENT;
    if sslProtocolDTLS10 in aVersions then
      Result := Result or SP_PROT_DTLS1_0_CLIENT;
    if sslProtocolDTLS12 in aVersions then
      Result := Result or SP_PROT_DTLS1_2_CLIENT;
  end;
end;

function SchannelFlagsToProtocolVersions(dwFlags: DWORD; 
                                        aIsServer: Boolean): TSSLProtocolVersions;
begin
  Result := [];
  
  if aIsServer then
  begin
    // 服务器端标志
    if (dwFlags and SP_PROT_SSL2_SERVER) <> 0 then
      Include(Result, sslProtocolSSL2);
    if (dwFlags and SP_PROT_SSL3_SERVER) <> 0 then
      Include(Result, sslProtocolSSL3);
    if (dwFlags and SP_PROT_TLS1_0_SERVER) <> 0 then
      Include(Result, sslProtocolTLS10);
    if (dwFlags and SP_PROT_TLS1_1_SERVER) <> 0 then
      Include(Result, sslProtocolTLS11);
    if (dwFlags and SP_PROT_TLS1_2_SERVER) <> 0 then
      Include(Result, sslProtocolTLS12);
    if (dwFlags and SP_PROT_TLS1_3_SERVER) <> 0 then
      Include(Result, sslProtocolTLS13);
    if (dwFlags and SP_PROT_DTLS1_0_SERVER) <> 0 then
      Include(Result, sslProtocolDTLS10);
    if (dwFlags and SP_PROT_DTLS1_2_SERVER) <> 0 then
      Include(Result, sslProtocolDTLS12);
  end
  else
  begin
    // 客户端标志
    if (dwFlags and SP_PROT_SSL2_CLIENT) <> 0 then
      Include(Result, sslProtocolSSL2);
    if (dwFlags and SP_PROT_SSL3_CLIENT) <> 0 then
      Include(Result, sslProtocolSSL3);
    if (dwFlags and SP_PROT_TLS1_0_CLIENT) <> 0 then
      Include(Result, sslProtocolTLS10);
    if (dwFlags and SP_PROT_TLS1_1_CLIENT) <> 0 then
      Include(Result, sslProtocolTLS11);
    if (dwFlags and SP_PROT_TLS1_2_CLIENT) <> 0 then
      Include(Result, sslProtocolTLS12);
    if (dwFlags and SP_PROT_TLS1_3_CLIENT) <> 0 then
      Include(Result, sslProtocolTLS13);
    if (dwFlags and SP_PROT_DTLS1_0_CLIENT) <> 0 then
      Include(Result, sslProtocolDTLS10);
    if (dwFlags and SP_PROT_DTLS1_2_CLIENT) <> 0 then
      Include(Result, sslProtocolDTLS12);
  end;
end;

function GetProtocolVersionName(aVersion: TSSLProtocolVersion): string;
begin
  case aVersion of
    sslProtocolSSL2: Result := 'SSL 2.0';
    sslProtocolSSL3: Result := 'SSL 3.0';
    sslProtocolTLS10: Result := 'TLS 1.0';
    sslProtocolTLS11: Result := 'TLS 1.1';
    sslProtocolTLS12: Result := 'TLS 1.2';
    sslProtocolTLS13: Result := 'TLS 1.3';
    sslProtocolDTLS10: Result := 'DTLS 1.0';
    sslProtocolDTLS12: Result := 'DTLS 1.2';
  else
    Result := 'Unknown';
  end;
end;

function IsProtocolDeprecated(aVersion: TSSLProtocolVersion): Boolean;
begin
  Result := (aVersion = sslProtocolSSL2) or (aVersion = sslProtocolSSL3);
end;

// ============================================================================
// 缓冲区管理实现
// ============================================================================

function AllocSecBuffer(aSize: ULONG; aType: ULONG): PSecBuffer;
begin
  New(Result);
  Result^.cbBuffer := aSize;
  Result^.BufferType := aType;
  
  if aSize > 0 then
    GetMem(Result^.pvBuffer, aSize)
  else
    Result^.pvBuffer := nil;
end;

procedure FreeSecBuffer(pBuffer: PSecBuffer);
begin
  if pBuffer = nil then
    Exit;
    
  if pBuffer^.pvBuffer <> nil then
    FreeMem(pBuffer^.pvBuffer);
    
  Dispose(pBuffer);
end;

function AllocSecBufferDesc(aBufferCount: ULONG): PSecBufferDesc;
begin
  New(Result);
  Result^.ulVersion := SECBUFFER_VERSION;
  Result^.cBuffers := aBufferCount;
  
  if aBufferCount > 0 then
    GetMem(Result^.pBuffers, SizeOf(TSecBuffer) * aBufferCount)
  else
    Result^.pBuffers := nil;
end;

procedure FreeSecBufferDesc(pBufferDesc: PSecBufferDesc);
var
  I: Integer;
  pBuffer: PSecBuffer;
begin
  if pBufferDesc = nil then
    Exit;
    
  // 释放所有缓冲区
  if (pBufferDesc^.pBuffers <> nil) and (pBufferDesc^.cBuffers > 0) then
  begin
    pBuffer := pBufferDesc^.pBuffers;
    for I := 0 to Integer(pBufferDesc^.cBuffers) - 1 do
    begin
      if pBuffer^.pvBuffer <> nil then
        FreeMem(pBuffer^.pvBuffer);
      Inc(pBuffer);
    end;
    FreeMem(pBufferDesc^.pBuffers);
  end;
  
  Dispose(pBufferDesc);
end;

procedure InitSecHandle(var Handle: TSecHandle);
begin
  Handle.dwLower := 0;
  Handle.dwUpper := 0;
end;

function IsValidSecHandle(const Handle: TSecHandle): Boolean;
begin
  Result := (Handle.dwLower <> 0) or (Handle.dwUpper <> 0);
end;

procedure ClearSecHandle(var Handle: TSecHandle);
begin
  Handle.dwLower := 0;
  Handle.dwUpper := 0;
end;

// ============================================================================
// 字符串转换辅助实现
// ============================================================================

function StringToPWideChar(const S: string): PWideChar;
var
  WS: WideString;
  Len: Integer;
begin
  if S = '' then
    Exit(nil);
    
  WS := UTF8Decode(S);
  Len := Length(WS);
  GetMem(Result, (Len + 1) * SizeOf(WideChar));
  Move(WS[1], Result^, Len * SizeOf(WideChar));
  Result[Len] := #0;
end;

procedure FreePWideCharString(P: PWideChar);
begin
  if P <> nil then
    FreeMem(P);
end;

function AnsiToWide(const S: AnsiString): WideString;
begin
  Result := UTF8Decode(S);
end;

function WideToUTF8(const S: WideString): string;
begin
  Result := UTF8Encode(S);
end;

// ============================================================================
// 调试和日志辅助实现
// ============================================================================

{$IFDEF DEBUG}
procedure DebugLog(const Msg: string);
begin
  WriteLn('[WinSSL Debug] ', Msg);
end;

procedure DebugDumpSecBuffer(const Buffer: TSecBuffer; const Prefix: string);
begin
  WriteLn(Prefix, 'SecBuffer:');
  WriteLn(Prefix, '  cbBuffer: ', Buffer.cbBuffer);
  WriteLn(Prefix, '  BufferType: ', Buffer.BufferType);
  WriteLn(Prefix, '  pvBuffer: ', HexStr(Buffer.pvBuffer));
end;

procedure DebugDumpSecBufferDesc(const BufferDesc: TSecBufferDesc; const Prefix: string);
var
  I: Integer;
  pBuffer: PSecBuffer;
begin
  WriteLn(Prefix, 'SecBufferDesc:');
  WriteLn(Prefix, '  ulVersion: ', BufferDesc.ulVersion);
  WriteLn(Prefix, '  cBuffers: ', BufferDesc.cBuffers);
  
  if (BufferDesc.pBuffers <> nil) and (BufferDesc.cBuffers > 0) then
  begin
    pBuffer := BufferDesc.pBuffers;
    for I := 0 to Integer(BufferDesc.cBuffers) - 1 do
    begin
      WriteLn(Prefix, '  Buffer[', I, ']:');
      DebugDumpSecBuffer(pBuffer^, Prefix + '    ');
      Inc(pBuffer);
    end;
  end;
end;
{$ENDIF}

end.

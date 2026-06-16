{
  nextpas.core.tls.openssl.errors - OpenSSL Error Handling

  Purpose:
    Provides OpenSSL-specific error handling functions.
    Mirrors nextpas.core.tls.winssl.errors for platform symmetry.

  Note:
    This module was extracted from nextpas.core.tls.exceptions to resolve
    circular dependency (exceptions -> openssl.api -> exceptions).

  Version: 2.0
  Phase: 3.1 - Architecture Improvements
}

unit nextpas.core.tls.openssl.errors;

{$mode ObjFPC}{$H+}
{$IFDEF UNIX}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.logging;

{**
 * Get error message from OpenSSL error queue
 * @return Formatted error message string (all queued errors)
 *}
function GetOpenSSLErrorString: string;

{**
 * Get the last OpenSSL error code (without clearing the queue)
 * @return OpenSSL error code (0 if none)
 *}
function GetLastOpenSSLError: Cardinal;

{**
 * Check OpenSSL operation result and raise exception on failure
 * @param AResult OpenSSL function return value (usually 1 = success)
 * @param AOperation Operation name for error message
 * @raises ESSLCryptoError if operation failed
 *}
procedure CheckOpenSSLResult(AResult: Integer; const AOperation: string);

{**
 * Convenience exception raising functions (auto-fetch OpenSSL errors)
 *}
procedure RaiseSSLInitError(const AMessage: string; const AContext: string = '');
procedure RaiseSSLCertError(const AMessage: string; const AContext: string = '');
procedure RaiseSSLConnectionError(const AMessage: string; const AContext: string = '');
procedure RaiseSSLCryptoError(const AMessage: string; const AContext: string = '');
procedure RaiseSSLConfigError(const AMessage: string; const AContext: string = '');

{**
 * Get friendly error message for OpenSSL error code (Chinese)
 *}
function GetOpenSSLFriendlyErrorMessageCN(AErrorCode: Cardinal): string;

{**
 * Get friendly error message for OpenSSL error code (English)
 *}
function GetOpenSSLFriendlyErrorMessageEN(AErrorCode: Cardinal): string;

implementation

uses
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.loader;

procedure EnsureOpenSSLErrorAPI;
begin
  // IMPORTANT: Do not implicitly initialize OpenSSL here.
  // Error helpers must be side-effect free (contract tests rely on this).
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Exit;

  if not TOpenSSLLoader.IsModuleLoaded(osmERR) then
    LoadOpenSSLERR;
end;

function GetOpenSSLErrorString: string;
var
  LErrorCode: Cardinal;
  LErrorBuf: array[0..255] of AnsiChar;
begin
  Result := '';

  EnsureOpenSSLErrorAPI;

  if not Assigned(ERR_get_error) or not Assigned(ERR_error_string_n) then
  begin
    Result := 'Unknown OpenSSL error';
    Exit;
  end;

  LErrorCode := ERR_get_error();

  while LErrorCode <> 0 do
  begin
    ERR_error_string_n(LErrorCode, @LErrorBuf[0], SizeOf(LErrorBuf));
    if Result <> '' then
      Result := Result + '; ';
    Result := Result + string(LErrorBuf);
    LErrorCode := ERR_get_error();
  end;

  if Result = '' then
    Result := 'Unknown OpenSSL error';
end;

function GetLastOpenSSLError: Cardinal;
begin
  Result := 0;

  EnsureOpenSSLErrorAPI;

  if Assigned(ERR_peek_error) then
    Result := ERR_peek_error();  // Peek without clearing

  if (Result = 0) and Assigned(ERR_get_error) then
    Result := ERR_get_error();  // Get and clear if peek failed
end;

procedure CheckOpenSSLResult(AResult: Integer; const AOperation: string);
var
  LErrorMsg: string;
  LErrorCode: Cardinal;
begin
  if AResult <> 1 then
  begin
    LErrorCode := GetLastOpenSSLError;
    LErrorMsg := GetOpenSSLErrorString;
    raise ESSLCryptoError.CreateWithContext(
      Format('%s failed: %s', [AOperation, LErrorMsg]),
      sslErrOther,
      AOperation,
      Integer(LErrorCode),
      sslOpenSSL
    );
  end;
end;

{ Convenience exception raising functions }

procedure RaiseSSLInitError(const AMessage: string; const AContext: string);
var
  LNativeError: Cardinal;
begin
  LNativeError := GetLastOpenSSLError;
  raise ESSLInitializationException.CreateWithContext(
    AMessage,
    sslErrNotInitialized,
    AContext,
    Integer(LNativeError),
    sslOpenSSL
  );
end;

procedure RaiseSSLCertError(const AMessage: string; const AContext: string);
var
  LNativeError: Cardinal;
begin
  LNativeError := GetLastOpenSSLError;
  raise ESSLCertificateLoadException.CreateWithContext(
    AMessage,
    sslErrLoadFailed,
    AContext,
    Integer(LNativeError),
    sslOpenSSL
  );
end;

procedure RaiseSSLConnectionError(const AMessage: string; const AContext: string);
var
  LNativeError: Cardinal;
begin
  LNativeError := GetLastOpenSSLError;
  raise ESSLConnectionException.CreateWithContext(
    AMessage,
    sslErrConnection,
    AContext,
    Integer(LNativeError),
    sslOpenSSL
  );
end;

procedure RaiseSSLCryptoError(const AMessage: string; const AContext: string);
var
  LNativeError: Cardinal;
begin
  LNativeError := GetLastOpenSSLError;
  raise ESSLCryptoError.CreateWithContext(
    AMessage,
    sslErrOther,
    AContext,
    Integer(LNativeError),
    sslOpenSSL
  );
end;

procedure RaiseSSLConfigError(const AMessage: string; const AContext: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    AMessage,
    sslErrConfiguration,
    AContext,
    0,
    sslAutoDetect
  );
end;

{ Friendly error messages }

function GetOpenSSLFriendlyErrorMessageCN(AErrorCode: Cardinal): string;
begin
  // Common OpenSSL error codes
  case AErrorCode of
    0:
      Result := '没有错误';
    // SSL errors (from ssl/ssl.h)
    $14090086:
      Result := '证书验证失败';
    $14094418:
      Result := '自签名证书';
    $14094419:
      Result := '证书链中的自签名证书';
    $14094410:
      Result := '证书已过期';
    $1407E086:
      Result := '证书CN不匹配';
    $14094411:
      Result := '证书尚未生效';
    $1408F10B:
      Result := '握手失败';
    $140943E8:
      Result := '无共同支持的密码套件';
    $1417D102:
      Result := '解密失败或MAC校验失败';
  else
    Result := Format('OpenSSL 错误 (0x%x)', [AErrorCode]);
  end;
end;

function GetOpenSSLFriendlyErrorMessageEN(AErrorCode: Cardinal): string;
begin
  case AErrorCode of
    0:
      Result := 'No error';
    $14090086:
      Result := 'Certificate verification failed';
    $14094418:
      Result := 'Self-signed certificate';
    $14094419:
      Result := 'Self-signed certificate in certificate chain';
    $14094410:
      Result := 'Certificate has expired';
    $1407E086:
      Result := 'Certificate CN mismatch';
    $14094411:
      Result := 'Certificate is not yet valid';
    $1408F10B:
      Result := 'Handshake failure';
    $140943E8:
      Result := 'No common cipher suites';
    $1417D102:
      Result := 'Decryption failed or bad record MAC';
  else
    Result := Format('OpenSSL error (0x%x)', [AErrorCode]);
  end;
end;

end.

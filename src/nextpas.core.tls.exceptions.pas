unit nextpas.core.tls.exceptions;

{$mode objfpc}{$H+}

{**
 * SSL/TLS异常类定义
 * 
 * 提供统一的异常层次结构，用于fafafa.ssl库的错误处理
 * 
 * Version: 2.0
 * 改进: 添加调用上下文支持、TSSLErrorCode集成、细粒度异常类型
 *}

interface

uses
  SysUtils,
  nextpas.core.tls.base;  // 引入 TSSLErrorCode 等类型定义

type
  {**
   * SSL/TLS异常基类（增强版）
   * 
   * 所有fafafa.ssl相关异常都继承自此类
   * 提供错误码、调用上下文、原生错误等详细信息
   *}
  ESSLException = class(Exception)
  private
    FErrorCode: TSSLErrorCode;
    FLibraryType: TSSLLibraryType;
    FNativeError: Integer;
    FContext: string;
    FComponent: string;  // 保留向后兼容
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage: string; AErrorCode: TSSLErrorCode); overload;  // Phase 3.3 P0 - 向后兼容 base.pas
    constructor Create(const AMessage: string; AErrorCode: TSSLErrorCode; const AContext: string); overload;  // Phase 3.3 P0 - 向后兼容
    constructor CreateWithCode(const AMessage: string; AErrorCode: Cardinal); overload;  // 向后兼容 OpenSSL 错误码
    constructor CreateFmt(const AMessage: string; const AArgs: array of const); overload;

    {** 新的构造函数 - 提供完整上下文 *}
    constructor CreateWithContext(
      const AMessage: string;
      AErrorCode: TSSLErrorCode;
      const AContext: string;
      ANativeError: Integer = 0;
      ALibraryType: TSSLLibraryType = sslAutoDetect
    );
    
    { 标准化错误码（fafafa.ssl 定义） }
    property ErrorCode: TSSLErrorCode read FErrorCode;
    
    { 原生库错误码（OpenSSL ERR_get_error()、WinSSL GetLastError() 等） }
    property NativeError: Integer read FNativeError;
    
    { 调用上下文（例如: 'TOpenSSLContext.LoadCertificate'） }
    property Context: string read FContext;
    
    { 库类型（OpenSSL、WinSSL 等） }
    property LibraryType: TSSLLibraryType read FLibraryType;
    
    { 发生错误的组件名称（向后兼容） }
    property Component: string read FComponent write FComponent;
  end;

  {**
   * 初始化和配置相关异常
   *}
  ESSLInitError = class(ESSLException);
  ESSLInitializationException = class(ESSLInitError);  // 新增别名
  ESSLConfigurationException = class(ESSLException);
  ESSLPlatformNotSupportedException = class(ESSLConfigurationException);

  {**
   * 加密操作错误
   *}
  ESSLCryptoError = class(ESSLException);
  ESSLKeyException = class(ESSLCryptoError);
  ESSLKeyDerivationException = class(ESSLCryptoError);
  ESSLEncryptionException = class(ESSLCryptoError);
  ESSLDecryptionException = class(ESSLCryptoError);

  {**
   * 证书相关错误（细分）
   *}
  ESSLCertError = class(ESSLException);
  ESSLCertificateException = class(ESSLCertError);  // 新增别名
  ESSLCertificateLoadException = class(ESSLCertError);
  ESSLCertificateParseException = class(ESSLCertError);
  ESSLCertificateVerificationException = class(ESSLCertError);
  ESSLCertificateExpiredException = class(ESSLCertificateVerificationException);

  {**
   * 连接和网络相关错误
   *}
  ESSLNetworkError = class(ESSLException);
  ESSLConnectionException = class(ESSLNetworkError);  // 新增别名
  ESSLHandshakeException = class(ESSLConnectionException);
  ESSLProtocolException = class(ESSLConnectionException);
  ESSLTimeoutException = class(ESSLConnectionException);

  {**
   * 底层库相关错误
   *}
  ESSLLibraryException = class(ESSLException);

  {**
   * 参数和资源错误
   *}
  ESSLInvalidArgument = class(ESSLException);
  ESSLResourceException = class(ESSLException);
  ESSLOutOfMemoryException = class(ESSLResourceException);
  ESSLFileNotFoundException = class(ESSLException);

  {**
   * 操作系统错误
   *}
  ESSLSystemError = class(ESSLException)
  private
    FSystemErrorCode: Integer;
  public
    constructor CreateWithSysCode(const AMessage: string; ASystemErrorCode: Integer);
    
    { 操作系统错误码 }
    property SystemErrorCode: Integer read FSystemErrorCode;
  end;

{**
 * OpenSSL-specific error functions have been moved to nextpas.core.tls.openssl.errors
 * to resolve circular dependency (Phase 3.1).
 *
 * For OpenSSL error handling, use:
 *   - GetOpenSSLErrorString
 *   - GetLastOpenSSLError
 *   - CheckOpenSSLResult
 *   - RaiseSSLInitError, RaiseSSLCertError, etc.
 * from nextpas.core.tls.openssl.errors unit.
 *}

implementation

{ ESSLException }

constructor ESSLException.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := sslErrNone;
  FNativeError := 0;
  FContext := '';
  FComponent := '';
  FLibraryType := sslAutoDetect;
end;

constructor ESSLException.Create(const AMessage: string; AErrorCode: TSSLErrorCode);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FNativeError := 0;
  FContext := '';
  FComponent := '';
  FLibraryType := sslAutoDetect;
end;

constructor ESSLException.Create(const AMessage: string; AErrorCode: TSSLErrorCode; const AContext: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FNativeError := 0;
  FContext := AContext;
  FComponent := '';
  FLibraryType := sslAutoDetect;
end;

constructor ESSLException.CreateWithCode(const AMessage: string; AErrorCode: Cardinal);
var
  LFullMessage: string;
begin
  LFullMessage := AMessage;
  if AErrorCode <> 0 then
    LFullMessage := Format('%s (OpenSSL error: 0x%x)', [AMessage, AErrorCode]);
  inherited Create(LFullMessage);
  FErrorCode := sslErrOther;  // 旧版本不区分具体类型
  FNativeError := Integer(AErrorCode);
  FContext := '';
  FComponent := '';
  FLibraryType := sslOpenSSL;
end;

constructor ESSLException.CreateFmt(const AMessage: string; const AArgs: array of const);
begin
  inherited CreateFmt(AMessage, AArgs);
  FErrorCode := sslErrNone;
  FNativeError := 0;
  FContext := '';
  FComponent := '';
  FLibraryType := sslAutoDetect;
end;

constructor ESSLException.CreateWithContext(
  const AMessage: string;
  AErrorCode: TSSLErrorCode;
  const AContext: string;
  ANativeError: Integer;
  ALibraryType: TSSLLibraryType
);
var
  LFullMessage: string;
begin
  LFullMessage := AMessage;
  
  // 添加上下文信息
  if AContext <> '' then
    LFullMessage := Format('[%s] %s', [AContext, LFullMessage]);
    
  // 添加原生错误码（如果有）
  if ANativeError <> 0 then
  begin
    case ALibraryType of
      sslOpenSSL:
        LFullMessage := Format('%s (OpenSSL error: 0x%x)', [LFullMessage, ANativeError]);
      sslWinSSL:
        LFullMessage := Format('%s (WinSSL error: %d)', [LFullMessage, ANativeError]);
    else
      LFullMessage := Format('%s (Native error: %d)', [LFullMessage, ANativeError]);
    end;
  end;
  
  inherited Create(LFullMessage);
  FErrorCode := AErrorCode;
  FNativeError := ANativeError;
  FContext := AContext;
  FComponent := '';  // 可以从 Context 解析
  FLibraryType := ALibraryType;
end;

{ ESSLSystemError }

constructor ESSLSystemError.CreateWithSysCode(const AMessage: string; ASystemErrorCode: Integer);
begin
  inherited CreateFmt('%s (System error: %d)', [AMessage, ASystemErrorCode]);
  FSystemErrorCode := ASystemErrorCode;
end;

end.

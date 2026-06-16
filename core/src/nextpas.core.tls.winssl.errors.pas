unit nextpas.core.tls.winssl.errors;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses SysUtils, Windows, nextpas.core.tls.base, // P2: TSSLErrorCode 统一错误码 nextpas.core.tls.winssl.base;

type
  { 错误级别 }
  TSSLErrorLevel = (
    sslErrorDebug,      // 调试信息
    sslErrorInfo,       // 一般信息
    sslErrorWarning,    // 警告
    sslErrorError,      // 错误
    sslErrorFatal       // 致命错误
  );
  
  { 错误记录 }
  TSSLErrorInfo = record
    Level: TSSLErrorLevel;
    Code: DWORD;
    Message: string;
    Context: string;
    Timestamp: TDateTime;
  end;
  
  {**
   * ISSLErrorHandler - 错误处理器接口
   * @stable 1.0
   * @locked 2025-12-24
   * @breaking-change-policy Requires major version bump
   *}
  ISSLErrorHandler = interface
    ['{F4B2C8E6-9A3D-4F2E-8B5C-1E7F9D4A6B2C}']
    procedure HandleError(const AErrorInfo: TSSLErrorInfo);
  end;
  
  { 默认错误处理器 - 输出到日志文件 }
  TSSLFileErrorHandler = class(TInterfacedObject, ISSLErrorHandler)
  private
    FLogFile: TextFile;
    FLogFileName: string;
    FEnabled: Boolean;
    
  public
    constructor Create(const ALogFileName: string);
    destructor Destroy; override;
    
    procedure HandleError(const AErrorInfo: TSSLErrorInfo);
    procedure SetEnabled(AEnabled: Boolean);
  end;
  
  { 控制台错误处理器 }
  TSSLConsoleErrorHandler = class(TInterfacedObject, ISSLErrorHandler)
  public
    procedure HandleError(const AErrorInfo: TSSLErrorInfo);
  end;

{ 错误码映射函数 }

{ 任务 4.1: 映射 Schannel 错误码到 SSL 错误类型 }
function MapSchannelError(AErrorCode: DWORD): TSSLErrorCode;

{ 任务 4.1: 获取 Schannel 错误的用户友好消息 (中文) }
function GetSchannelErrorMessageCN(AErrorCode: DWORD): string;

{ 任务 4.1: 获取 Schannel 错误的用户友好消息 (英文) }
function GetSchannelErrorMessageEN(AErrorCode: DWORD): string;

{ 获取友好的错误消息 (中文) }
function GetFriendlyErrorMessageCN(AErrorCode: DWORD): string;

{ 获取友好的错误消息 (英文) }
function GetFriendlyErrorMessageEN(AErrorCode: DWORD): string;

{ 获取系统错误消息 }
function GetSystemErrorMessage(AErrorCode: DWORD): string;

{ 格式化错误信息 }
function FormatErrorInfo(const AErrorInfo: TSSLErrorInfo): string;

{ 全局错误日志函数 }

{ 记录错误 }
procedure LogError(ALevel: TSSLErrorLevel; ACode: DWORD; 
  const AMessage, AContext: string);

{ 设置全局错误处理器 }
procedure SetGlobalErrorHandler(AHandler: ISSLErrorHandler);

{ 启用/禁用错误日志 }
procedure EnableErrorLogging(AEnabled: Boolean);

{ P2: WinSSL 错误码到 TSSLErrorCode 的映射 }
function ClassifyWinSSLError(AErrorCode: DWORD): TSSLErrorCode;

{ P2: 获取 WinSSL 错误分类名称 }
function GetWinSSLErrorCategory(AErrorCode: DWORD): string;

implementation

var
  GErrorHandler: ISSLErrorHandler = nil;
  GErrorLoggingEnabled: Boolean = False;

{ TSSLFileErrorHandler }

constructor TSSLFileErrorHandler.Create(const ALogFileName: string);
begin
  inherited Create;
  FLogFileName := ALogFileName;
  FEnabled := True;
  
  try
    AssignFile(FLogFile, FLogFileName);
    if FileExists(FLogFileName) then
      Append(FLogFile)
    else
      Rewrite(FLogFile);
  except
    FEnabled := False;
  end;
end;

destructor TSSLFileErrorHandler.Destroy;
begin
  if FEnabled then
  begin
    try
      CloseFile(FLogFile);
    except
      on E: Exception do
      begin
        // P1-2.4: CloseFile failure is non-critical; OS will close on process exit
        {$IFDEF DEBUG}
        WriteLn('[DEBUG] nextpas.core.tls.winssl.errors: CloseFile failed: ', E.Message);
        {$ENDIF}
      end;
    end;
  end;
  inherited Destroy;
end;

procedure TSSLFileErrorHandler.HandleError(const AErrorInfo: TSSLErrorInfo);
begin
  if not FEnabled then
    Exit;
    
  try
    WriteLn(FLogFile, FormatErrorInfo(AErrorInfo));
    Flush(FLogFile);
  except
    FEnabled := False;
  end;
end;

procedure TSSLFileErrorHandler.SetEnabled(AEnabled: Boolean);
begin
  FEnabled := AEnabled;
end;

{ TSSLConsoleErrorHandler }

procedure TSSLConsoleErrorHandler.HandleError(const AErrorInfo: TSSLErrorInfo);
begin
  WriteLn(ErrOutput, FormatErrorInfo(AErrorInfo));
end;

{ 错误码映射函数 }

{ 任务 4.1: 映射 Schannel 错误码到 SSL 错误类型
  将 Windows Schannel API 返回的错误码映射到统一的 TSSLErrorCode
  需求: 2.4, 7.1, 7.2, 7.6 }
function MapSchannelError(AErrorCode: DWORD): TSSLErrorCode;
begin
  case LONG(AErrorCode) of
    // 成功状态
    LONG(SEC_E_OK):
      Result := sslErrNone;

    // 握手继续状态 (不是错误)
    LONG(SEC_I_CONTINUE_NEEDED),
    LONG(SEC_I_COMPLETE_NEEDED),
    LONG(SEC_I_COMPLETE_AND_CONTINUE):
      Result := sslErrNone;

    // 需要更多数据
    LONG(SEC_E_INCOMPLETE_MESSAGE):
      Result := sslErrWantRead;

    // 协议/握手错误
    LONG(SEC_E_INVALID_TOKEN),
    LONG(SEC_E_MESSAGE_ALTERED),
    LONG(SEC_E_OUT_OF_SEQUENCE):
      Result := sslErrProtocol;

    // 算法不匹配
    LONG(SEC_E_ALGORITHM_MISMATCH):
      Result := sslErrHandshake;

    // 不支持的功能
    LONG(SEC_E_UNSUPPORTED_FUNCTION):
      Result := sslErrUnsupported;

    // 证书错误 - 不受信任的根
    LONG(SEC_E_UNTRUSTED_ROOT),
    LONG(CERT_E_UNTRUSTEDROOT):
      Result := sslErrCertificateUntrusted;

    // 证书错误 - 过期
    LONG(SEC_E_CERT_EXPIRED),
    LONG(CERT_E_EXPIRED):
      Result := sslErrCertificateExpired;

    // 证书错误 - 吊销
    LONG(CERT_E_REVOKED):
      Result := sslErrCertificateRevoked;

    // 证书错误 - 吊销检查失败
    LONG(CERT_E_REVOCATION_FAILURE):
      Result := sslErrVerificationFailed;

    // 证书错误 - 主机名不匹配
    LONG(CERT_E_CN_NO_MATCH),
    LONG(CERT_E_INVALID_NAME):
      Result := sslErrHostnameMismatch;

    // 证书错误 - 用途错误
    LONG(CERT_E_WRONG_USAGE):
      Result := sslErrCertificate;

    // 证书错误 - 签名无效
    LONG(TRUST_E_CERT_SIGNATURE):
      Result := sslErrVerificationFailed;

    // 证书错误 - 未知证书
    LONG(SEC_E_CERT_UNKNOWN),
    LONG(SEC_E_WRONG_PRINCIPAL):
      Result := sslErrCertificate;

    // 句柄/参数错误
    LONG(SEC_E_INVALID_HANDLE),
    LONG(ERROR_INVALID_HANDLE):
      Result := sslErrInvalidParam;

    LONG(ERROR_INVALID_PARAMETER),
    LONG(SEC_E_INVALID_PARAMETER):
      Result := sslErrInvalidParam;

    // 内存错误
    LONG(ERROR_NOT_ENOUGH_MEMORY),
    LONG(SEC_E_INSUFFICIENT_MEMORY):
      Result := sslErrMemory;

    // 初始化错误
    LONG(SEC_E_SECPKG_NOT_FOUND),
    LONG(SEC_E_NOT_OWNER):
      Result := sslErrNotInitialized;

    // 连接错误
    LONG(SEC_E_CONTEXT_EXPIRED):
      Result := sslErrConnection;

    // 访问/配置错误
    LONG(ERROR_ACCESS_DENIED),
    LONG(SEC_E_LOGON_DENIED):
      Result := sslErrConfiguration;

    // 不支持
    LONG(ERROR_NOT_SUPPORTED):
      Result := sslErrUnsupported;

    // 加密/解密错误
    LONG(SEC_E_DECRYPT_FAILURE):
      Result := sslErrDecryptionFailed;

  else
    // 未知错误映射到通用错误
    Result := sslErrOther;
  end;
end;

{ 任务 4.1: 获取 Schannel 错误的用户友好消息 (中文)
  为每个错误类型生成用户友好的消息
  需求: 7.1, 7.2, 7.6 }
function GetSchannelErrorMessageCN(AErrorCode: DWORD): string;
begin
  case LONG(AErrorCode) of
    // 成功状态
    LONG(SEC_E_OK):
      Result := '操作成功';

    // 握手继续状态
    LONG(SEC_I_CONTINUE_NEEDED):
      Result := '握手需要继续';
    LONG(SEC_I_COMPLETE_NEEDED):
      Result := '握手需要完成';
    LONG(SEC_I_COMPLETE_AND_CONTINUE):
      Result := '握手需要完成并继续';

    // 需要更多数据
    LONG(SEC_E_INCOMPLETE_MESSAGE):
      Result := 'TLS 消息不完整,需要接收更多数据';

    // 协议/握手错误
    LONG(SEC_E_INVALID_TOKEN):
      Result := '收到无效的 TLS 令牌,可能是协议不匹配';
    LONG(SEC_E_MESSAGE_ALTERED):
      Result := 'TLS 消息被篡改,连接不安全';
    LONG(SEC_E_OUT_OF_SEQUENCE):
      Result := 'TLS 消息顺序错误';

    // 算法不匹配
    LONG(SEC_E_ALGORITHM_MISMATCH):
      Result := '客户端和服务端没有共同支持的加密算法';

    // 不支持的功能
    LONG(SEC_E_UNSUPPORTED_FUNCTION):
      Result := '此 Windows 版本不支持请求的 TLS 功能';

    // 证书错误 - 不受信任的根
    LONG(SEC_E_UNTRUSTED_ROOT),
    LONG(CERT_E_UNTRUSTEDROOT):
      Result := '证书链到不受信任的根证书颁发机构';

    // 证书错误 - 过期
    LONG(SEC_E_CERT_EXPIRED),
    LONG(CERT_E_EXPIRED):
      Result := '证书已过期';

    // 证书错误 - 吊销
    LONG(CERT_E_REVOKED):
      Result := '证书已被吊销';

    // 证书错误 - 吊销检查失败
    LONG(CERT_E_REVOCATION_FAILURE):
      Result := '无法检查证书吊销状态';

    // 证书错误 - 主机名不匹配
    LONG(CERT_E_CN_NO_MATCH):
      Result := '证书的通用名称与服务器名称不匹配';
    LONG(CERT_E_INVALID_NAME):
      Result := '证书名称无效';

    // 证书错误 - 用途错误
    LONG(CERT_E_WRONG_USAGE):
      Result := '证书用途不正确';

    // 证书错误 - 签名无效
    LONG(TRUST_E_CERT_SIGNATURE):
      Result := '证书签名无效';

    // 证书错误 - 未知证书
    LONG(SEC_E_CERT_UNKNOWN):
      Result := '证书未知或不受信任';
    LONG(SEC_E_WRONG_PRINCIPAL):
      Result := '证书主体不正确';

    // 句柄/参数错误
    LONG(SEC_E_INVALID_HANDLE),
    LONG(ERROR_INVALID_HANDLE):
      Result := '无效的安全句柄';
    LONG(ERROR_INVALID_PARAMETER),
    LONG(SEC_E_INVALID_PARAMETER):
      Result := '参数无效';

    // 内存错误
    LONG(ERROR_NOT_ENOUGH_MEMORY),
    LONG(SEC_E_INSUFFICIENT_MEMORY):
      Result := '内存不足';

    // 初始化错误
    LONG(SEC_E_SECPKG_NOT_FOUND):
      Result := '找不到安全包';
    LONG(SEC_E_NOT_OWNER):
      Result := '没有权限访问安全上下文';

    // 连接错误
    LONG(SEC_E_CONTEXT_EXPIRED):
      Result := 'TLS 连接已过期或关闭';

    // 访问/配置错误
    LONG(ERROR_ACCESS_DENIED):
      Result := '访问被拒绝';
    LONG(SEC_E_LOGON_DENIED):
      Result := '登录被拒绝';

    // 不支持
    LONG(ERROR_NOT_SUPPORTED):
      Result := '不支持的操作';

    // 加密/解密错误
    LONG(SEC_E_DECRYPT_FAILURE):
      Result := '数据解密失败';

  else
    Result := Format('未知错误 (0x%x)', [AErrorCode]);
  end;
end;

{ 任务 4.1: 获取 Schannel 错误的用户友好消息 (英文)
  为每个错误类型生成用户友好的消息
  需求: 7.1, 7.2, 7.6 }
function GetSchannelErrorMessageEN(AErrorCode: DWORD): string;
begin
  case LONG(AErrorCode) of
    // 成功状态
    LONG(SEC_E_OK):
      Result := 'Operation successful';

    // 握手继续状态
    LONG(SEC_I_CONTINUE_NEEDED):
      Result := 'Handshake continues';
    LONG(SEC_I_COMPLETE_NEEDED):
      Result := 'Handshake needs completion';
    LONG(SEC_I_COMPLETE_AND_CONTINUE):
      Result := 'Handshake needs completion and continuation';

    // 需要更多数据
    LONG(SEC_E_INCOMPLETE_MESSAGE):
      Result := 'TLS message incomplete, need more data';

    // 协议/握手错误
    LONG(SEC_E_INVALID_TOKEN):
      Result := 'Invalid TLS token received, possible protocol mismatch';
    LONG(SEC_E_MESSAGE_ALTERED):
      Result := 'TLS message has been tampered with, connection is not secure';
    LONG(SEC_E_OUT_OF_SEQUENCE):
      Result := 'TLS message sequence error';

    // 算法不匹配
    LONG(SEC_E_ALGORITHM_MISMATCH):
      Result := 'No common encryption algorithm between client and server';

    // 不支持的功能
    LONG(SEC_E_UNSUPPORTED_FUNCTION):
      Result := 'Requested TLS feature not supported on this Windows version';

    // 证书错误 - 不受信任的根
    LONG(SEC_E_UNTRUSTED_ROOT),
    LONG(CERT_E_UNTRUSTEDROOT):
      Result := 'Certificate chain to untrusted root authority';

    // 证书错误 - 过期
    LONG(SEC_E_CERT_EXPIRED),
    LONG(CERT_E_EXPIRED):
      Result := 'Certificate has expired';

    // 证书错误 - 吊销
    LONG(CERT_E_REVOKED):
      Result := 'Certificate has been revoked';

    // 证书错误 - 吊销检查失败
    LONG(CERT_E_REVOCATION_FAILURE):
      Result := 'Unable to check certificate revocation status';

    // 证书错误 - 主机名不匹配
    LONG(CERT_E_CN_NO_MATCH):
      Result := 'Certificate common name does not match server name';
    LONG(CERT_E_INVALID_NAME):
      Result := 'Certificate name is invalid';

    // 证书错误 - 用途错误
    LONG(CERT_E_WRONG_USAGE):
      Result := 'Certificate has wrong usage';

    // 证书错误 - 签名无效
    LONG(TRUST_E_CERT_SIGNATURE):
      Result := 'Certificate signature is invalid';

    // 证书错误 - 未知证书
    LONG(SEC_E_CERT_UNKNOWN):
      Result := 'Certificate is unknown or untrusted';
    LONG(SEC_E_WRONG_PRINCIPAL):
      Result := 'Certificate principal is incorrect';

    // 句柄/参数错误
    LONG(SEC_E_INVALID_HANDLE),
    LONG(ERROR_INVALID_HANDLE):
      Result := 'Invalid security handle';
    LONG(ERROR_INVALID_PARAMETER),
    LONG(SEC_E_INVALID_PARAMETER):
      Result := 'Invalid parameter';

    // 内存错误
    LONG(ERROR_NOT_ENOUGH_MEMORY),
    LONG(SEC_E_INSUFFICIENT_MEMORY):
      Result := 'Not enough memory';

    // 初始化错误
    LONG(SEC_E_SECPKG_NOT_FOUND):
      Result := 'Security package not found';
    LONG(SEC_E_NOT_OWNER):
      Result := 'No permission to access security context';

    // 连接错误
    LONG(SEC_E_CONTEXT_EXPIRED):
      Result := 'TLS connection has expired or closed';

    // 访问/配置错误
    LONG(ERROR_ACCESS_DENIED):
      Result := 'Access denied';
    LONG(SEC_E_LOGON_DENIED):
      Result := 'Logon denied';

    // 不支持
    LONG(ERROR_NOT_SUPPORTED):
      Result := 'Operation not supported';

    // 加密/解密错误
    LONG(SEC_E_DECRYPT_FAILURE):
      Result := 'Data decryption failed';

  else
    Result := Format('Unknown error (0x%x)', [AErrorCode]);
  end;
end;

function GetFriendlyErrorMessageCN(AErrorCode: DWORD): string;
begin
  // 任务 4.1: 优先使用 Schannel 专用错误消息
  Result := GetSchannelErrorMessageCN(AErrorCode);
  
  // 如果是未知错误,尝试获取系统错误消息
  if Pos('未知错误', Result) > 0 then
  begin
    case LONG(AErrorCode) of
      // Windows 错误
      LONG(ERROR_INVALID_PARAMETER):
        Result := '参数无效';
      LONG(ERROR_NOT_ENOUGH_MEMORY):
        Result := '内存不足';
      LONG(ERROR_INVALID_HANDLE):
        Result := '句柄无效';
      LONG(ERROR_NOT_SUPPORTED):
        Result := '不支持的操作';
      LONG(ERROR_ACCESS_DENIED):
        Result := '访问被拒绝';
    else
      // 使用系统错误消息
      Result := GetSystemErrorMessage(AErrorCode);
    end;
  end;
end;

function GetFriendlyErrorMessageEN(AErrorCode: DWORD): string;
begin
  // 任务 4.1: 优先使用 Schannel 专用错误消息
  Result := GetSchannelErrorMessageEN(AErrorCode);
  
  // 如果是未知错误,尝试获取系统错误消息
  if Pos('Unknown error', Result) > 0 then
  begin
    case LONG(AErrorCode) of
      // Windows 错误
      LONG(ERROR_INVALID_PARAMETER):
        Result := 'Invalid parameter';
      LONG(ERROR_NOT_ENOUGH_MEMORY):
        Result := 'Not enough memory';
      LONG(ERROR_INVALID_HANDLE):
        Result := 'Invalid handle';
      LONG(ERROR_NOT_SUPPORTED):
        Result := 'Operation not supported';
      LONG(ERROR_ACCESS_DENIED):
        Result := 'Access denied';
    else
      // 使用系统错误消息
      Result := GetSystemErrorMessage(AErrorCode);
    end;
  end;
end;

function GetSystemErrorMessage(AErrorCode: DWORD): string;
var
  LBuffer: array[0..1023] of Char;
  LSize: DWORD;
begin
  LSize := FormatMessage(
    FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    nil,
    AErrorCode,
    0,
    @LBuffer[0],
    SizeOf(LBuffer),
    nil
  );
  
  if LSize > 0 then
  begin
    SetString(Result, PChar(@LBuffer[0]), LSize);
    Result := Trim(Result);
  end
  else
    Result := Format('Error code: 0x%x', [AErrorCode]);
end;

function FormatErrorInfo(const AErrorInfo: TSSLErrorInfo): string;
const
  LEVEL_STR: array[TSSLErrorLevel] of string = (
    'DEBUG', 'INFO', 'WARNING', 'ERROR', 'FATAL'
  );
begin
  Result := Format('[%s] %s | %s | Code: 0x%x | %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', AErrorInfo.Timestamp),
    LEVEL_STR[AErrorInfo.Level],
    AErrorInfo.Context,
    AErrorInfo.Code,
    AErrorInfo.Message]);
end;

{ 全局错误日志函数 }

procedure LogError(ALevel: TSSLErrorLevel; ACode: DWORD; 
  const AMessage, AContext: string);
var
  LErrorInfo: TSSLErrorInfo;
begin
  if not GErrorLoggingEnabled then
    Exit;
    
  if GErrorHandler = nil then
    Exit;
    
  LErrorInfo.Level := ALevel;
  LErrorInfo.Code := ACode;
  LErrorInfo.Message := AMessage;
  LErrorInfo.Context := AContext;
  LErrorInfo.Timestamp := Now;
  
  GErrorHandler.HandleError(LErrorInfo);
end;

procedure SetGlobalErrorHandler(AHandler: ISSLErrorHandler);
begin
  GErrorHandler := AHandler;
end;

procedure EnableErrorLogging(AEnabled: Boolean);
begin
  GErrorLoggingEnabled := AEnabled;
end;

{ P2: WinSSL 错误码到 TSSLErrorCode 的映射
  与 OpenSSL ClassifyOpenSSLError 保持一致的分类逻辑 }
function ClassifyWinSSLError(AErrorCode: DWORD): TSSLErrorCode;
begin
  case LONG(AErrorCode) of
    // 成功状态
    LONG(SEC_E_OK):
      Result := sslErrNone;

    // 握手/协议错误
    LONG(SEC_I_CONTINUE_NEEDED),
    LONG(SEC_I_COMPLETE_NEEDED),
    LONG(SEC_I_COMPLETE_AND_CONTINUE):
      Result := sslErrNone;  // 这些是正常的握手状态

    LONG(SEC_E_INCOMPLETE_MESSAGE):
      Result := sslErrWouldBlock;

    LONG(SEC_E_INVALID_TOKEN),
    LONG(SEC_E_MESSAGE_ALTERED),
    LONG(SEC_E_OUT_OF_SEQUENCE):
      Result := sslErrProtocol;

    LONG(SEC_E_ALGORITHM_MISMATCH),
    LONG(SEC_E_UNSUPPORTED_FUNCTION):
      Result := sslErrUnsupported;

    // 证书错误
    LONG(SEC_E_UNTRUSTED_ROOT),
    LONG(CERT_E_UNTRUSTEDROOT):
      Result := sslErrCertificateUntrusted;

    LONG(SEC_E_CERT_EXPIRED),
    LONG(CERT_E_EXPIRED):
      Result := sslErrCertificateExpired;

    LONG(CERT_E_REVOKED):
      Result := sslErrCertificateRevoked;

    LONG(CERT_E_REVOCATION_FAILURE):
      Result := sslErrVerificationFailed;

    LONG(CERT_E_CN_NO_MATCH),
    LONG(CERT_E_INVALID_NAME):
      Result := sslErrHostnameMismatch;

    LONG(CERT_E_WRONG_USAGE):
      Result := sslErrCertificate;

    LONG(TRUST_E_CERT_SIGNATURE):
      Result := sslErrVerificationFailed;

    LONG(SEC_E_CERT_UNKNOWN),
    LONG(SEC_E_WRONG_PRINCIPAL):
      Result := sslErrCertificate;

    // 句柄/参数错误
    LONG(SEC_E_INVALID_HANDLE),
    LONG(ERROR_INVALID_HANDLE):
      Result := sslErrInvalidParam;

    LONG(ERROR_INVALID_PARAMETER),
    LONG(SEC_E_INVALID_PARAMETER):
      Result := sslErrInvalidParam;

    // 内存错误
    LONG(ERROR_NOT_ENOUGH_MEMORY),
    LONG(SEC_E_INSUFFICIENT_MEMORY):
      Result := sslErrMemory;

    // 初始化错误
    LONG(SEC_E_SECPKG_NOT_FOUND),
    LONG(SEC_E_NOT_OWNER):
      Result := sslErrNotInitialized;

    // I/O 错误
    LONG(SEC_E_CONTEXT_EXPIRED):
      Result := sslErrConnection;

    // 访问错误
    LONG(ERROR_ACCESS_DENIED),
    LONG(SEC_E_LOGON_DENIED):
      Result := sslErrConfiguration;

    // 不支持
    LONG(ERROR_NOT_SUPPORTED):
      Result := sslErrUnsupported;

  else
    // 未知错误映射到通用错误
    Result := sslErrOther;
  end;
end;

{ P2: 获取 WinSSL 错误分类名称 }
function GetWinSSLErrorCategory(AErrorCode: DWORD): string;
begin
  // 根据错误码范围判断分类
  case LONG(AErrorCode) of
    // SEC_E_* 和 SEC_I_* 错误 (0x80090000 - 0x8009FFFF)
    LONG($80090000)..LONG($8009FFFF):
      Result := 'SSPI';

    // CERT_E_* 错误 (0x800B0100 - 0x800B01FF)
    LONG($800B0100)..LONG($800B01FF):
      Result := 'CERT';

    // TRUST_E_* 错误 (0x800B0000 - 0x800B00FF)
    LONG($800B0000)..LONG($800B00FF):
      Result := 'TRUST';

    // Windows 系统错误
    0..65535:
      Result := 'WIN32';

  else
    Result := 'UNKNOWN';
  end;
end;

initialization
  GErrorLoggingEnabled := False;

finalization
  GErrorHandler := nil;

end.

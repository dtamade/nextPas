unit nextpas.core.tls.connection.base;

{$mode objfpc}{$H+}

{**
 * Unit: nextpas.core.tls.connection.base
 * Purpose: SSL 连接的抽象基类，提供所有后端的共享实现
 *
 * 设计原则:
 * - 抽象方法：后端特定的底层操作（Read/Write/Connect/Handshake）
 * - 通用实现：基于抽象方法的高层封装（ReadString/WriteString等）
 * - 状态管理：统一的连接状态和错误跟踪
 * - 性能监控：共享的性能指标收集
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-02-04
 *}

interface

uses
  SysUtils, Classes,
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions;

const
  { 字符串缓冲区大小 }
  SSL_STRING_BUFFER_SIZE = 8192;

function ContextTypeSupportsClientConnectionRole(
  AContextType: TSSLContextType): Boolean; inline;
function ContextTypeSupportsServerConnectionRole(
  AContextType: TSSLContextType): Boolean; inline;
function ContextTypeRequiresExplicitHandshakeRole(
  AContextType: TSSLContextType): Boolean; inline;
function RolelessHandshakeAmbiguityMessage(
  const AEntryPoint: string): string; inline;

type
  {**
   * TBaseSSLConnection - SSL 连接抽象基类
   *
   * 为所有 SSL 后端提供共享的连接实现基础。
   * 后端只需实现抽象方法即可获得完整功能。
   *
   * 实现的接口：
   * - ISSLConnection: 核心连接功能
   * - ISSLConnectionControl: timeout / blocking runtime control owner
   * - ISSLDiagnostics: 诊断功能
   * - ISSLSessionResumption: 会话复用
   * - ISSLCertificateVerification: 证书验证
   * - ISSLConnectionInfo: 连接信息 / compatibility-core mirrors
   *
   * 说明:
   * - `GetConnectionInfo` / `GetContext` / `GetSelectedALPNProtocol` / `GetStateString`
   *   当前同时存在于 `ISSLConnection` 与 `ISSLConnectionInfo`，属于 v1.x compatibility-core
   *   duplicates；Stage-A demotion target 已固定为 `ISSLConnectionInfo`。
   * - `GetConnectionInfo` 当前通过一条共享基类实现同时服务于 core mirror 和
   *   `ISSLConnectionInfo` owner；active docs/tests 已转向
   *   `ISSLConnectionInfo.GetConnectionInfo`，direct core
   *   `GetConnectionInfo` 当前只剩 contract mirror proof 和 backend-specific runtime/contract residuals。
   * - `GetStateString` 当前共享同一条基类实现；ordinary docs/tests 已转向
   *   `ISSLConnectionInfo.GetStateString`，direct core `GetStateString` 当前只剩
   *   contract mirror proof 和 backend-specific runtime residuals。
   * - `GetSelectedALPNProtocol` 当前通过一条共享基类实现同时服务于 core mirror 和
 *   `ISSLConnectionInfo` owner；active docs/tests 已转向
 *   `ISSLConnectionInfo.GetSelectedALPNProtocol`，direct core
 *   `GetSelectedALPNProtocol` 当前只剩 contract mirror proof 和 backend-specific runtime residuals。
 * - `GetContext` 当前通过一条共享基类实现同时服务于 core mirror 和
 *   `ISSLConnectionInfo` owner；active docs 已转向 `ISSLConnectionInfo.GetContext`，
 *   direct core `GetContext` 只剩 contract mirror proof。
 * - `SetTimeout` / `GetTimeout` / `SetBlocking` / `GetBlocking`
 *   当前共享同一组 connection-control 基类实现；builder / connector / acceptor
 *   已开始优先通过 `ISSLConnectionControl` owner path 访问，direct core control
 *   当前保留为 v1.x convenience mirror / fallback path。
 * - `GetHealthStatus` / `IsHealthy` / `GetDiagnosticInfo` / `GetPerformanceMetrics`
 *   当前共享同一组 diagnostics 基类实现；ordinary docs/tests 已转向 `ISSLDiagnostics` owner path，
 *   direct core diagnostics 当前只剩 contract mirror proof。
 * - `GetSession` / `SetSession` / `IsSessionReused` 当前共享同一组会话复用基类实现；
 *   ordinary docs/tests 已转向 `ISSLSessionResumption` owner path，direct core session-resumption 当前只剩 contract mirror proof。
 * - `GetOCSPStaplingEnabled` / `GetOCSPResponse` / `IsOCSPResponseVerified` /
 *   `GetOCSPResponseStatus` 当前共享同一组基类 bridge/stub 实现；ordinary guidance
 *   已转向 `ISSLOCSPStapling` owner path，direct core `GetOCSP*` 当前只剩
 *   `MbedTLS` capability/runtime residual、`OpenSSL` runtime/contract residual
 *   与 `WolfSSL` runtime residual。
 * - OCSP / CT / CT validation getter/stub 仍保留在基类里，供显式支持这些可选接口
 *   的后端连接类复用；但基类本身不再无条件暴露对应 interface。
 * - `ISSLConnectionInfo` / `ISSLDiagnostics` / `ISSLSessionResumption` /
 *   `ISSLCertificateVerification` / `ISSLOCSPStapling` 都是对应 compatibility
 *   mirrors 的推荐 owner path；core 侧继续保留 v1.x mirrors 以维持兼容。
 *}
  TBaseSSLConnection = class(TInterfacedObject,
    ISSLConnection,
    ISSLConnectionTextIO,
    ISSLConnectionControl,
    ISSLDiagnostics,
    ISSLSessionResumption,
    ISSLCertificateVerification,
    ISSLConnectionInfo)
  protected
    { 状态字段 }
    FConnected: Boolean;
    FHandshakeComplete: Boolean;
    FBlocking: Boolean;
    FTimeout: Integer;
    FContext: ISSLContext;

    { 错误跟踪 }
    FLastErrorCode: TSSLErrorCode;
    FLastErrorString: string;

    { 性能指标 }
    FConnectTime: TDateTime;
    FHandshakeStartTime: TDateTime;
    FHandshakeDuration: Double;
    FBytesRead: Int64;
    FBytesWritten: Int64;
    FReadOperations: Int64;
    FWriteOperations: Int64;
    FFirstByteTime: Double;
    FFirstByteRecorded: Boolean;
    FLatencySum: Double;
    FLatencyCount: Int64;

    { 错误历史 }
    FErrorHistory: array of TSSLErrorRecord;
    FMaxErrorHistory: Integer;

    { ========== 抽象方法 - 后端必须实现 ========== }

    {** 底层读取操作 *}
    function DoRead(var ABuffer; ACount: Integer): Integer; virtual; abstract;

    {** 底层写入操作 *}
    function DoWrite(const ABuffer; ACount: Integer): Integer; virtual; abstract;

    {** 底层连接操作 *}
    function DoConnect: Boolean; virtual; abstract;

    {** 底层接受连接操作 *}
    function DoAccept: Boolean; virtual; abstract;

    {** 底层握手操作 *}
    function DoHandshakeInternal: TSSLHandshakeState; virtual; abstract;

    {** 底层关闭操作 *}
    function DoShutdown: Boolean; virtual; abstract;

    {** 底层强制关闭 *}
    procedure DoClose; virtual; abstract;

    {** 底层重协商 *}
    function DoRenegotiate: Boolean; virtual; abstract;

    {** 获取底层错误码 *}
    function DoGetError(ARet: Integer): TSSLErrorCode; virtual; abstract;

    {** 检查底层是否需要读取 *}
    function DoWantRead: Boolean; virtual; abstract;

    {** 检查底层是否需要写入 *}
    function DoWantWrite: Boolean; virtual; abstract;

    {** 获取协商的协议版本 *}
    function DoGetProtocolVersion: TSSLProtocolVersion; virtual; abstract;

    {** 获取协商的密码套件 *}
    function DoGetCipherName: string; virtual; abstract;

    {** 获取对端证书 *}
    function DoGetPeerCertificate: ISSLCertificate; virtual; abstract;

    {** 获取对端证书链 *}
    function DoGetPeerCertificateChain: TSSLCertificateArray; virtual; abstract;

    {** 获取证书验证结果 *}
    function DoGetVerifyResult: Integer; virtual; abstract;

    {** 获取证书验证结果字符串 *}
    function DoGetVerifyResultString: string; virtual; abstract;

    {** 获取会话 *}
    function DoGetSession: ISSLSession; virtual; abstract;

    {** 设置会话 *}
    procedure DoSetSession(ASession: ISSLSession); virtual; abstract;

    {** 检查会话是否复用 *}
    function DoIsSessionReused: Boolean; virtual; abstract;

    {** 获取可折叠进 ConnectionInfo 的 server name metadata *}
    function DoGetConnectionInfoServerName: string; virtual;

    {** 获取 ALPN 协商结果 *}
    function DoGetSelectedALPNProtocol: string; virtual; abstract;

    {** 获取内部状态 *}
    function DoGetState: string; virtual; abstract;

    {** 获取原生句柄 *}
    function DoGetNativeHandle: Pointer; virtual; abstract;

    {** 获取 OCSP Stapling 状态 *}
    function DoGetOCSPStaplingEnabled: Boolean; virtual;

    {** 获取 OCSP 响应 *}
    function DoGetOCSPResponse: TBytes; virtual;

    {** 检查 OCSP 响应是否已验证 *}
    function DoIsOCSPResponseVerified: Boolean; virtual;

    {** 获取 OCSP 响应状态 *}
    function DoGetOCSPResponseStatus: string; virtual;

    {** 获取 CT/SCT surface 状态 *}
    function DoGetCertificateTransparencyEnabled: Boolean; virtual;

    {** 获取原始 SCT list *}
    function DoGetSignedCertificateTimestampList: TBytes; virtual;

    {** 获取 SCT 数量 *}
    function DoGetSignedCertificateTimestampCount: Integer; virtual;

    {** 获取 CT/SCT 状态描述 *}
    function DoGetCertificateTransparencyStatus: string; virtual;

    {** 是否有 CT validation 结果 *}
    function DoHasCertificateTransparencyValidationResult: Boolean; virtual;

    {** 默认 CT policy 是否满足 *}
    function DoIsCertificateTransparencyPolicySatisfied: Boolean; virtual;

    {** 获取 CT validation 状态描述 *}
    function DoGetCertificateTransparencyValidationStatus: string; virtual;

    { ========== 辅助方法 ========== }

    {** 记录错误到历史 *}
    procedure RecordError(ACode: TSSLErrorCode; const AMessage: string);

    {** 更新读取统计 *}
    procedure UpdateReadStats(ABytesRead: Integer);

    {** 更新写入统计 *}
    procedure UpdateWriteStats(ABytesWritten: Integer);

  public
    constructor Create(AContext: ISSLContext); virtual;
    destructor Destroy; override;

    { ========== ISSLConnection 实现 ========== }

    { 连接操作 }
    function Connect: Boolean;
    function Accept: Boolean;
    function Shutdown: Boolean;
    procedure Close;
    function DoHandshake: TSSLHandshakeState;
    function IsHandshakeComplete: Boolean;
    function Renegotiate: Boolean;

    { 数据传输 }
    function Read(var ABuffer; ACount: Integer): Integer;
    function Write(const ABuffer; ACount: Integer): Integer;
    function ReadString(out AStr: string): Boolean; virtual;
    function WriteString(const AStr: string): Boolean; virtual;

    { 非阻塞状态 }
    function WantRead: Boolean;
    function WantWrite: Boolean;

    { 错误处理 }
    function GetError(ARet: Integer): TSSLErrorCode;

    { 连接信息 }
    function GetConnectionInfo: TSSLConnectionInfo; virtual;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;

    { 证书 }
    function GetPeerCertificate: ISSLCertificate;
    function GetPeerCertificateChain: TSSLCertificateArray;
    function GetVerifyResult: Integer;
    function GetVerifyResultString: string;

    { 会话 }
    function GetSession: ISSLSession;
    procedure SetSession(ASession: ISSLSession);
    function IsSessionReused: Boolean;

    { ALPN }
    function GetSelectedALPNProtocol: string;

    { 状态 }
    function IsConnected: Boolean;
    function GetState: string;
    function GetStateString: string; virtual;

    { 超时和阻塞 }
    procedure SetTimeout(ATimeout: Integer); virtual;
    function GetTimeout: Integer;
    procedure SetBlocking(ABlocking: Boolean); virtual;
    function GetBlocking: Boolean;

    { 上下文 }
    function GetNativeHandle: Pointer;
    function GetContext: ISSLContext;

    { 监控和诊断 }
    function GetHealthStatus: TSSLHealthStatus; virtual;
    function IsHealthy: Boolean; virtual;
    function GetDiagnosticInfo: TSSLDiagnosticInfo; virtual;
    function GetPerformanceMetrics: TSSLPerformanceMetrics; virtual;

    { OCSP Stapling }
    function GetOCSPStaplingEnabled: Boolean;
    function GetOCSPResponse: TBytes;
    function IsOCSPResponseVerified: Boolean;
    function GetOCSPResponseStatus: string;

    { CT / SCT surface }
    function GetCertificateTransparencyEnabled: Boolean;
    function GetSignedCertificateTimestampList: TBytes;
    function GetSignedCertificateTimestampCount: Integer;
    function GetCertificateTransparencyStatus: string;
    function HasCertificateTransparencyValidationResult: Boolean;
    function IsCertificateTransparencyPolicySatisfied: Boolean;
    function GetCertificateTransparencyValidationStatus: string;
  end;

implementation

uses
  nextpas.core.tls.tls13.wire;

function ContextTypeSupportsClientConnectionRole(
  AContextType: TSSLContextType): Boolean; inline;
begin
  Result := AContextType in [sslCtxClient, sslCtxBoth];
end;

function ContextTypeSupportsServerConnectionRole(
  AContextType: TSSLContextType): Boolean; inline;
begin
  Result := AContextType in [sslCtxServer, sslCtxBoth];
end;

function ContextTypeRequiresExplicitHandshakeRole(
  AContextType: TSSLContextType): Boolean; inline;
begin
  Result := AContextType = sslCtxBoth;
end;

function RolelessHandshakeAmbiguityMessage(
  const AEntryPoint: string): string; inline;
begin
  Result := Format(
    '%s is ambiguous for sslCtxBoth. Use Connect or Accept to choose a role explicitly.',
    [AEntryPoint]
  );
end;

{ TBaseSSLConnection }

constructor TBaseSSLConnection.Create(AContext: ISSLContext);
begin
  inherited Create;
  FContext := AContext;
  FConnected := False;
  FHandshakeComplete := False;
  FBlocking := True;
  FTimeout := 30000; // 默认 30 秒
  FLastErrorCode := sslErrNone;
  FLastErrorString := '';

  // 初始化性能指标
  FConnectTime := 0;
  FHandshakeStartTime := 0;
  FHandshakeDuration := 0;
  FBytesRead := 0;
  FBytesWritten := 0;
  FReadOperations := 0;
  FWriteOperations := 0;
  FFirstByteTime := 0;
  FFirstByteRecorded := False;
  FLatencySum := 0;
  FLatencyCount := 0;

  // 错误历史
  SetLength(FErrorHistory, 0);
  FMaxErrorHistory := 100;
end;

destructor TBaseSSLConnection.Destroy;
begin
  if FConnected then
    Close;
  SetLength(FErrorHistory, 0);
  FContext := nil;
  inherited Destroy;
end;

procedure TBaseSSLConnection.RecordError(ACode: TSSLErrorCode; const AMessage: string);
var
  LEntry: TSSLErrorRecord;
begin
  FLastErrorCode := ACode;
  FLastErrorString := AMessage;

  // 添加到历史
  LEntry.Timestamp := DateTimeNow;
  LEntry.ErrorCode := ACode;
  LEntry.ErrorMessage := AMessage;

  if Length(FErrorHistory) >= FMaxErrorHistory then
  begin
    // 移除最旧的条目
    Move(FErrorHistory[1], FErrorHistory[0],
        (Length(FErrorHistory) - 1) * SizeOf(TSSLErrorRecord));
    SetLength(FErrorHistory, Length(FErrorHistory));
    FErrorHistory[High(FErrorHistory)] := LEntry;
  end
  else
  begin
    SetLength(FErrorHistory, Length(FErrorHistory) + 1);
    FErrorHistory[High(FErrorHistory)] := LEntry;
  end;
end;

procedure TBaseSSLConnection.UpdateReadStats(ABytesRead: Integer);
begin
  if ABytesRead > 0 then
  begin
    Inc(FBytesRead, ABytesRead);
    Inc(FReadOperations);

    if not FFirstByteRecorded then
    begin
      FFirstByteTime := DateTimeMillisecondsBetween(DateTimeNow, FConnectTime);
      FFirstByteRecorded := True;
    end;
  end;
end;

procedure TBaseSSLConnection.UpdateWriteStats(ABytesWritten: Integer);
begin
  if ABytesWritten > 0 then
  begin
    Inc(FBytesWritten, ABytesWritten);
    Inc(FWriteOperations);
  end;
end;

{ 连接操作 }

function TBaseSSLConnection.Connect: Boolean;
begin
  FConnectTime := DateTimeNow;
  FHandshakeStartTime := DateTimeNow;

  Result := DoConnect;

  if Result then
  begin
    FConnected := True;
    FHandshakeComplete := True;
    FHandshakeDuration := DateTimeMillisecondsBetween(DateTimeNow, FHandshakeStartTime);
  end;
end;

function TBaseSSLConnection.Accept: Boolean;
begin
  FConnectTime := DateTimeNow;
  FHandshakeStartTime := DateTimeNow;

  Result := DoAccept;

  if Result then
  begin
    FConnected := True;
    FHandshakeComplete := True;
    FHandshakeDuration := DateTimeMillisecondsBetween(DateTimeNow, FHandshakeStartTime);
  end;
end;

function TBaseSSLConnection.Shutdown: Boolean;
begin
  Result := DoShutdown;
  if Result then
    FConnected := False;
end;

procedure TBaseSSLConnection.Close;
begin
  DoClose;
  FConnected := False;
  FHandshakeComplete := False;
end;

function TBaseSSLConnection.DoHandshake: TSSLHandshakeState;
begin
  if (not FHandshakeComplete) and (FContext <> nil) and
    ContextTypeRequiresExplicitHandshakeRole(FContext.GetContextType) then
  begin
    RecordError(
      sslErrConfiguration,
      RolelessHandshakeAmbiguityMessage('DoHandshake')
    );
    Exit(sslHsFailed);
  end;

  if not FHandshakeComplete then
    FHandshakeStartTime := DateTimeNow;

  Result := DoHandshakeInternal;

  if Result = sslHsCompleted then
  begin
    FHandshakeComplete := True;
    FHandshakeDuration := DateTimeMillisecondsBetween(DateTimeNow, FHandshakeStartTime);
  end;
end;

function TBaseSSLConnection.IsHandshakeComplete: Boolean;
begin
  Result := FHandshakeComplete;
end;

function TBaseSSLConnection.Renegotiate: Boolean;
begin
  Result := DoRenegotiate;
end;

{ 数据传输 }

function TBaseSSLConnection.Read(var ABuffer; ACount: Integer): Integer;
begin
  Result := DoRead(ABuffer, ACount);
  UpdateReadStats(Result);
end;

function TBaseSSLConnection.Write(const ABuffer; ACount: Integer): Integer;
begin
  Result := DoWrite(ABuffer, ACount);
  UpdateWriteStats(Result);
end;

function TBaseSSLConnection.ReadString(out AStr: string): Boolean;
var
  LBuffer: array[0..SSL_STRING_BUFFER_SIZE - 1] of Byte;
  LBytesRead: Integer;
begin
  Result := False;
  AStr := '';

  LBytesRead := Read(LBuffer, SizeOf(LBuffer));
  if LBytesRead > 0 then
  begin
    SetString(AStr, PAnsiChar(@LBuffer[0]), LBytesRead);
    Result := True;
  end;
end;

function TBaseSSLConnection.WriteString(const AStr: string): Boolean;
begin
  Result := False;
  if AStr = '' then
    Exit(True);
  Result := Write(AStr[1], Length(AStr)) = Length(AStr);
end;

{ 非阻塞状态 }

function TBaseSSLConnection.WantRead: Boolean;
begin
  Result := DoWantRead;
end;

function TBaseSSLConnection.WantWrite: Boolean;
begin
  Result := DoWantWrite;
end;

{ 错误处理 }

function TBaseSSLConnection.GetError(ARet: Integer): TSSLErrorCode;
begin
  Result := DoGetError(ARet);
  FLastErrorCode := Result;
end;

procedure TryDeriveConnectionInfoFromCipherSuiteName(const ACipherSuite: string;
  var AInfo: TSSLConnectionInfo);
var
  LName: string;
begin
  if ACipherSuite = '' then
    Exit;

  LName := UpperCase(ACipherSuite);

  if Pos('ECDHE-ECDSA', LName) > 0 then
    AInfo.KeyExchange := sslKexECDHE_ECDSA
  else if Pos('ECDHE-RSA', LName) > 0 then
    AInfo.KeyExchange := sslKexECDHE_RSA
  else if Pos('DHE-RSA', LName) > 0 then
    AInfo.KeyExchange := sslKexDHE_RSA
  else if Pos('DHE-DSS', LName) > 0 then
    AInfo.KeyExchange := sslKexDHE_DSS
  else if Pos('RSA-PSK', LName) > 0 then
    AInfo.KeyExchange := sslKexRSA_PSK
  else if Pos('DHE-PSK', LName) > 0 then
    AInfo.KeyExchange := sslKexDHE_PSK
  else if Pos('-PSK', LName) > 0 then
    AInfo.KeyExchange := sslKexPSK
  else if (Pos('TLS_RSA_', LName) = 1) or (Pos('TLS-RSA-', LName) = 1) or
          (Pos('RSA-', LName) = 1) then
    AInfo.KeyExchange := sslKexRSA;

  if Pos('CHACHA20', LName) > 0 then
  begin
    AInfo.Cipher := sslCipherCHACHA20_POLY1305;
    if AInfo.KeySize = 0 then
      AInfo.KeySize := 256;
  end
  else if (Pos('AES_256_GCM', LName) > 0) or
          (Pos('AES-256-GCM', LName) > 0) or
          (Pos('AES256-GCM', LName) > 0) or
          (Pos('AES256GCM', LName) > 0) then
  begin
    AInfo.Cipher := sslCipherAES256GCM;
    if AInfo.KeySize = 0 then
      AInfo.KeySize := 256;
  end
  else if (Pos('AES_128_GCM', LName) > 0) or
          (Pos('AES-128-GCM', LName) > 0) or
          (Pos('AES128-GCM', LName) > 0) or
          (Pos('AES128GCM', LName) > 0) then
  begin
    AInfo.Cipher := sslCipherAES128GCM;
    if AInfo.KeySize = 0 then
      AInfo.KeySize := 128;
  end
  else if (Pos('AES_256', LName) > 0) or (Pos('AES-256', LName) > 0) or
          (Pos('AES256', LName) > 0) then
  begin
    AInfo.Cipher := sslCipherAES256;
    if AInfo.KeySize = 0 then
      AInfo.KeySize := 256;
  end
  else if (Pos('AES_128', LName) > 0) or (Pos('AES-128', LName) > 0) or
          (Pos('AES128', LName) > 0) then
  begin
    AInfo.Cipher := sslCipherAES128;
    if AInfo.KeySize = 0 then
      AInfo.KeySize := 128;
  end
  else if Pos('3DES', LName) > 0 then
    AInfo.Cipher := sslCipher3DES
  else if Pos('RC4', LName) > 0 then
    AInfo.Cipher := sslCipherRC4
  else if Pos('DES', LName) > 0 then
    AInfo.Cipher := sslCipherDES;

  if (Pos('SHA3_512', LName) > 0) or (Pos('SHA3-512', LName) > 0) then
    AInfo.Hash := sslHashSHA3_512
  else if (Pos('SHA3_256', LName) > 0) or (Pos('SHA3-256', LName) > 0) then
    AInfo.Hash := sslHashSHA3_256
  else if Pos('SHA512', LName) > 0 then
    AInfo.Hash := sslHashSHA512
  else if Pos('SHA384', LName) > 0 then
    AInfo.Hash := sslHashSHA384
  else if Pos('SHA256', LName) > 0 then
    AInfo.Hash := sslHashSHA256
  else if Pos('SHA224', LName) > 0 then
    AInfo.Hash := sslHashSHA224
  else if Pos('SHA1', LName) > 0 then
    AInfo.Hash := sslHashSHA1
  else if Pos('MD5', LName) > 0 then
    AInfo.Hash := sslHashMD5
  else if Pos('SHA', LName) > 0 then
    AInfo.Hash := sslHashSHA1;

  if AInfo.MacSize = 0 then
  begin
    // AEAD suites can safely expose their auth-tag length from the suite name;
    // legacy HMAC suites remain backend-specific best-effort.
    if (Pos('CCM_8', LName) > 0) or (Pos('CCM8', LName) > 0) then
      AInfo.MacSize := 8
    else if (Pos('GCM', LName) > 0) or
            (Pos('POLY1305', LName) > 0) or
            (Pos('OCB', LName) > 0) or
            ((Pos('CCM', LName) > 0) and (Pos('CCM_8', LName) = 0) and
             (Pos('CCM8', LName) = 0)) then
      AInfo.MacSize := 16;
  end;

  if SameText(ACipherSuite, TLS13CipherSuiteToString(TLS13_CIPHER_AES_128_GCM_SHA256)) then
    AInfo.CipherSuiteId := TLS13_CIPHER_AES_128_GCM_SHA256
  else if SameText(ACipherSuite, TLS13CipherSuiteToString(TLS13_CIPHER_AES_256_GCM_SHA384)) then
    AInfo.CipherSuiteId := TLS13_CIPHER_AES_256_GCM_SHA384
  else if SameText(ACipherSuite, TLS13CipherSuiteToString(TLS13_CIPHER_CHACHA20_POLY1305_SHA256)) then
    AInfo.CipherSuiteId := TLS13_CIPHER_CHACHA20_POLY1305_SHA256;
end;

{ 连接信息 }

function TBaseSSLConnection.GetConnectionInfo: TSSLConnectionInfo;
var
  LSession: ISSLSession;
  LPeerCertificate: ISSLCertificate;
begin
  Result := Default(TSSLConnectionInfo);
  Result.ProtocolVersion := GetProtocolVersion;
  Result.CipherSuite := GetCipherName;
  Result.KeySize := 0; // 后端可覆盖
  Result.CompressionMethod := 'NONE';
  Result.IsResumed := IsSessionReused;
  Result.ALPNProtocol := GetSelectedALPNProtocol;
  Result.ServerName := DoGetConnectionInfoServerName;
  TryDeriveConnectionInfoFromCipherSuiteName(Result.CipherSuite, Result);

  if FConnected or FHandshakeComplete then
  begin
    LSession := GetSession;
    if LSession <> nil then
      Result.SessionId := LSession.GetID;
  end;

  LPeerCertificate := GetPeerCertificate;
  if LPeerCertificate <> nil then
    Result.PeerCertificate := LPeerCertificate.GetInfo;
end;

function TBaseSSLConnection.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := DoGetProtocolVersion;
end;

function TBaseSSLConnection.GetCipherName: string;
begin
  Result := DoGetCipherName;
end;

{ 证书 }

function TBaseSSLConnection.GetPeerCertificate: ISSLCertificate;
begin
  Result := DoGetPeerCertificate;
end;

{ `GetPeerCertificateChain` 当前共享同一条基类 mirror 实现：
  ordinary docs/tests 已转向 `ISSLCertificateVerification` owner path，
  direct core 残余面当前只剩 helper fallback、contract mirror proof 和 backend-specific runtime residuals。 }
function TBaseSSLConnection.GetPeerCertificateChain: TSSLCertificateArray;
begin
  Result := DoGetPeerCertificateChain;
end;

{ `GetVerifyResult` / `GetVerifyResultString` 当前共享同一条基类 mirror 实现：
  ordinary docs/tests 已转向 `ISSLCertificateVerification` owner path，
  direct core 残余面当前只剩 helper fallback、contract mirror proof 和 backend-specific runtime residuals。 }
function TBaseSSLConnection.GetVerifyResult: Integer;
begin
  Result := DoGetVerifyResult;
end;

function TBaseSSLConnection.GetVerifyResultString: string;
begin
  Result := DoGetVerifyResultString;
end;

{ 会话 }

function TBaseSSLConnection.GetSession: ISSLSession;
begin
  Result := DoGetSession;
end;

procedure TBaseSSLConnection.SetSession(ASession: ISSLSession);
begin
  DoSetSession(ASession);
end;

function TBaseSSLConnection.IsSessionReused: Boolean;
begin
  Result := DoIsSessionReused;
end;

function TBaseSSLConnection.DoGetConnectionInfoServerName: string;
begin
  Result := '';
end;

{ ALPN }

function TBaseSSLConnection.GetSelectedALPNProtocol: string;
begin
  Result := DoGetSelectedALPNProtocol;
end;

{ 状态 }

function TBaseSSLConnection.IsConnected: Boolean;
begin
  Result := FConnected;
end;

function TBaseSSLConnection.GetState: string;
begin
  Result := DoGetState;
end;

function TBaseSSLConnection.GetStateString: string;
begin
  if not FConnected then
    Result := 'Disconnected'
  else if not FHandshakeComplete then
    Result := 'Handshaking'
  else
    Result := 'Connected';
end;

{ 超时和阻塞 }

procedure TBaseSSLConnection.SetTimeout(ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

function TBaseSSLConnection.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TBaseSSLConnection.SetBlocking(ABlocking: Boolean);
begin
  FBlocking := ABlocking;
end;

function TBaseSSLConnection.GetBlocking: Boolean;
begin
  Result := FBlocking;
end;

{ 上下文 }

function TBaseSSLConnection.GetNativeHandle: Pointer;
begin
  Result := DoGetNativeHandle;
end;

function TBaseSSLConnection.GetContext: ISSLContext;
begin
  Result := FContext;
end;

{ 监控和诊断 }

function TBaseSSLConnection.GetHealthStatus: TSSLHealthStatus;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.IsConnected := FConnected;
  Result.HandshakeComplete := FHandshakeComplete;
  Result.LastError := FLastErrorCode;
  Result.LastErrorTime := DateTimeNow; // 简化实现
  Result.BytesSent := FBytesWritten;
  Result.BytesReceived := FBytesRead;
  if FConnectTime > 0 then
    Result.ConnectionAge := DateTimeSecondsBetween(DateTimeNow, FConnectTime)
  else
    Result.ConnectionAge := 0;
end;

function TBaseSSLConnection.IsHealthy: Boolean;
begin
  Result := FConnected and FHandshakeComplete and (FLastErrorCode = sslErrNone);
end;

function TBaseSSLConnection.GetDiagnosticInfo: TSSLDiagnosticInfo;
var
  I: Integer;
begin
  Result := Default(TSSLDiagnosticInfo);
  Result.ConnectionInfo := GetConnectionInfo;
  Result.HealthStatus := GetHealthStatus;
  Result.PerformanceMetrics := GetPerformanceMetrics;

  // 复制错误历史
  SetLength(Result.ErrorHistory, Length(FErrorHistory));
  for I := 0 to High(FErrorHistory) do
    Result.ErrorHistory[I] := FErrorHistory[I];
end;

function TBaseSSLConnection.GetPerformanceMetrics: TSSLPerformanceMetrics;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.HandshakeTime := Round(FHandshakeDuration);
  Result.FirstByteTime := Round(FFirstByteTime);
  Result.TotalBytesTransferred := FBytesRead + FBytesWritten;
  Result.SessionReused := IsSessionReused;

  if FLatencyCount > 0 then
    Result.AverageLatency := Round(FLatencySum / FLatencyCount)
  else
    Result.AverageLatency := 0;
end;

{ OCSP Stapling - 默认实现 }

function TBaseSSLConnection.DoGetOCSPStaplingEnabled: Boolean;
begin
  Result := False;
end;

function TBaseSSLConnection.DoGetOCSPResponse: TBytes;
begin
  Result := nil;
end;

function TBaseSSLConnection.DoIsOCSPResponseVerified: Boolean;
begin
  Result := False;
end;

function TBaseSSLConnection.DoGetOCSPResponseStatus: string;
begin
  Result := 'Not Supported';
end;

function TBaseSSLConnection.DoGetCertificateTransparencyEnabled: Boolean;
begin
  Result := False;
end;

function TBaseSSLConnection.DoGetSignedCertificateTimestampList: TBytes;
begin
  Result := nil;
end;

function TBaseSSLConnection.DoGetSignedCertificateTimestampCount: Integer;
begin
  Result := 0;
end;

function TBaseSSLConnection.DoGetCertificateTransparencyStatus: string;
begin
  Result := 'Not Supported';
end;

function TBaseSSLConnection.DoHasCertificateTransparencyValidationResult: Boolean;
begin
  Result := False;
end;

function TBaseSSLConnection.DoIsCertificateTransparencyPolicySatisfied: Boolean;
begin
  Result := False;
end;

function TBaseSSLConnection.DoGetCertificateTransparencyValidationStatus: string;
begin
  Result := 'Not Supported';
end;

function TBaseSSLConnection.GetOCSPStaplingEnabled: Boolean;
begin
  Result := DoGetOCSPStaplingEnabled;
end;

function TBaseSSLConnection.GetOCSPResponse: TBytes;
begin
  Result := DoGetOCSPResponse;
end;

function TBaseSSLConnection.IsOCSPResponseVerified: Boolean;
begin
  Result := DoIsOCSPResponseVerified;
end;

function TBaseSSLConnection.GetOCSPResponseStatus: string;
begin
  Result := DoGetOCSPResponseStatus;
end;

function TBaseSSLConnection.GetCertificateTransparencyEnabled: Boolean;
begin
  Result := DoGetCertificateTransparencyEnabled;
end;

function TBaseSSLConnection.GetSignedCertificateTimestampList: TBytes;
begin
  Result := DoGetSignedCertificateTimestampList;
end;

function TBaseSSLConnection.GetSignedCertificateTimestampCount: Integer;
begin
  Result := DoGetSignedCertificateTimestampCount;
end;

function TBaseSSLConnection.GetCertificateTransparencyStatus: string;
begin
  Result := DoGetCertificateTransparencyStatus;
end;

function TBaseSSLConnection.HasCertificateTransparencyValidationResult: Boolean;
begin
  Result := DoHasCertificateTransparencyValidationResult;
end;

function TBaseSSLConnection.IsCertificateTransparencyPolicySatisfied: Boolean;
begin
  Result := DoIsCertificateTransparencyPolicySatisfied;
end;

function TBaseSSLConnection.GetCertificateTransparencyValidationStatus: string;
begin
  Result := DoGetCertificateTransparencyValidationStatus;
end;

end.

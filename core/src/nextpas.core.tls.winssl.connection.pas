{
  nextpas.core.tls.winssl.connection - WinSSL 连接实现

  版本: 1.1 - 重构为使用 TBaseSSLConnection 基类
  作者: fafafa.ssl 开发团队
  创建: 2025-10-06
  修改: 2026-02-04

  描述:
    实现 ISSLConnection 接口的 WinSSL 后端。
    负责 Schannel TLS 握手和安全数据传输。
    继承自 TBaseSSLConnection 以共享通用实现。
}

unit nextpas.core.tls.winssl.connection;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.base.utils,
  {$IFDEF WINDOWS}
  Windows, winsock2,
  {$ELSE}
  Sockets,
  {$ENDIF}
  nextpas.core.exception, nextpas.core.text.conv, nextpas.core.sync, DateUtils,
  nextpas.core.io.intf,
  nextpas.core.io.stream_adapter,
  nextpas.core.tls.base,
  nextpas.core.tls.connection.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api,
  nextpas.core.tls.winssl.errors,
  nextpas.core.tls.winssl.utils,
  nextpas.core.tls.winssl.native_handle,
  nextpas.core.tls.winssl.certificate,
  nextpas.core.tls.winssl.context;

type
  TSecPkgContext_CipherInfoPrefix = packed record
    dwVersion: DWORD;
    dwProtocol: DWORD;
    dwCipherSuite: DWORD;
    dwBaseCipherSuite: DWORD;
  end;

  { TWinSSLSession - Windows Schannel 会话实现
    P0-4: 安全化重构 - 不再持有 CtxtHandle，改为元数据模式
    Schannel 的会话复用由系统自动管理，此类仅保存会话元数据。
    WinSSL session 不暴露 ISSLNativeHandleAccess，因为没有稳定的独立原生 session 句柄。 }
  TWinSSLSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
    FCreationTime: TDateTime;
    FTimeout: Integer;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
    FSessionData: TBytes;
    FPeerCertificate: ISSLCertificate;
    FIsResumed: Boolean;
    function BuildSerializedSessionData: TBytes;
    function TryLoadSerializedSessionData(const AData: TBytes): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { ISSLSession 实现 }
    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;

    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;

    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;

    function Clone: ISSLSession;

    { 设置对端证书（供 Connection 调用）}
    procedure SetPeerCertificate(ACert: ISSLCertificate);

    { 元数据设置方法（供 Connection 调用）}
    procedure SetSessionMetadata(const AID: string; AProtocol: TSSLProtocolVersion;
      const ACipher: string; AResumed: Boolean);
    function WasResumed: Boolean;
  end;

  { TWinSSLSessionManager - 会话缓存管理器 }
  TWinSSLSessionManager = class
  private
    FSessions: TStringArray;
    FLock: IMutex;
    FMaxSessions: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddSession(const AID: string; ASession: ISSLSession);
    function GetSession(const AID: string): ISSLSession;
    procedure RemoveSession(const AID: string);
    procedure CleanupExpired;
    procedure SetMaxSessions(AMax: Integer);
  end;

  { TWinSSLConnection - WinSSL 连接类，继承自 TBaseSSLConnection }
  TWinSSLConnection = class(TBaseSSLConnection, ISSLClientConnection,
    ISSLNativeHandleAccess)
  private
    FSocket: THandle;
    FStream: IStream;
    FCtxtHandle: CtxtHandle;
    FHandshakeState: TSSLHandshakeState;
    FServerName: string;

    // 缓冲区
    FRecvBuffer: array[0..SSL_DEFAULT_BUFFER_SIZE-1] of Byte;
    FRecvBufferUsed: Integer;
    FDecryptedBuffer: array[0..SSL_DEFAULT_BUFFER_SIZE-1] of Byte;
    FDecryptedBufferUsed: Integer;
    FExtraData: array[0..SSL_DEFAULT_BUFFER_SIZE-1] of Byte;
    FExtraDataSize: Integer;

    // 会话管理
    FCurrentSession: ISSLSession;
    FSessionReused: Boolean;

    // 最后一次操作状态
    FLastError: TSSLErrorCode;
    FPeerValidationRoleKnown: Boolean;
    FPeerValidationRoleIsClient: Boolean;

    // 高精度计时器
    FHandshakeStartCounter: Int64;
    FHandshakeEndCounter: Int64;

    // 内部方法
    function PerformHandshake: TSSLHandshakeState;
    function ClientHandshake: Boolean;
    function ServerHandshake: Boolean;
    function SendData(const ABuffer; ASize: Integer): Integer;
    function RecvData(var ABuffer; ASize: Integer): Integer;

    // 握手辅助方法
    procedure PrepareInputBufferDesc(var AInBuffers: array of TSecBuffer;
      var AInBufferDesc: TSecBufferDesc; AData: Pointer; ADataSize: DWORD);
    procedure PrepareOutputBufferDesc(var AOutBuffers: array of TSecBuffer;
      var AOutBufferDesc: TSecBufferDesc);
    procedure HandleExtraData(var AExtraBuffer: array of TSecBuffer;
      var AIoBuffer: array of Byte; var AIoBufferSize: DWORD; AStatus: SECURITY_STATUS);
    function SendOutputBuffer(const AOutBuffer: TSecBuffer): Boolean;
    procedure RememberPeerValidationRole(AIsClient: Boolean);
    function TryResolvePeerValidationRole(out AIsClient: Boolean): Boolean;

    // 证书验证
    function ValidatePeerCertificate(AIsClient: Boolean;
      out AVerifyError: Integer): Boolean;

    // ALPN 支持
    function BuildALPNBuffer(const AProtocols: string; out ABuffer: TBytes): Boolean;

    // InfoCallback 辅助
    procedure NotifyInfoCallback(AWhere: Integer; ARet: Integer; const AState: string);

    // 会话保存
    procedure SaveSessionAfterHandshake;
    function TryGetCurrentSessionInfo(
      out ASessionInfo: SecPkgContext_SessionInfo): Boolean;
    function SessionIdBytesToHex(
      const ASessionInfo: SecPkgContext_SessionInfo): string;
    procedure UpdateSessionReuseTruthFromContext(out ASessionId: string);

    // WinSSL 内部 access interface helper
    function TryGetContextAccess(out AContextAccess: IWinSSLContextAccess): Boolean;
    function TryGetLibraryStatsAccess(out ALibraryStatsAccess: IWinSSLLibraryStatsAccess): Boolean;
    procedure TryUpdateLibraryStatistics;
    function TryGetCipherInfo(out ACipherSuiteId: Word;
      out ACipherSuiteName: string): Boolean;

  protected
    { TBaseSSLConnection 抽象方法实现 }
    function DoRead(var ABuffer; ACount: Integer): Integer; override;
    function DoWrite(const ABuffer; ACount: Integer): Integer; override;
    function DoConnect: Boolean; override;
    function DoAccept: Boolean; override;
    function DoHandshakeInternal: TSSLHandshakeState; override;
    function DoShutdown: Boolean; override;
    procedure DoClose; override;
    function DoRenegotiate: Boolean; override;
    function DoGetError(ARet: Integer): TSSLErrorCode; override;
    function DoWantRead: Boolean; override;
    function DoWantWrite: Boolean; override;
    function DoGetProtocolVersion: TSSLProtocolVersion; override;
    function DoGetCipherName: string; override;
    function DoGetPeerCertificate: ISSLCertificate; override;
    function DoGetPeerCertificateChain: TSSLCertificateArray; override;
    function DoGetVerifyResult: Integer; override;
    function DoGetVerifyResultString: string; override;
    function DoGetSession: ISSLSession; override;
    procedure DoSetSession(ASession: ISSLSession); override;
    function DoIsSessionReused: Boolean; override;
    function DoGetConnectionInfoServerName: string; override;
    function DoGetSelectedALPNProtocol: string; override;
    function DoGetState: string; override;
    function DoGetNativeHandle: Pointer; override;

  public
    constructor Create(AContext: ISSLContext; ASocket: THandle); overload;
    constructor Create(AContext: ISSLContext; AStream: TStream); overload;
    constructor Create(AContext: ISSLContext; AStream: IStream); overload;
    destructor Destroy; override;

    { ISSLClientConnection }
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;

    { ISSLNativeHandleAccess }
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    { 覆盖基类的 GetConnectionInfo 以提供更详细的信息 }
    function GetConnectionInfo: TSSLConnectionInfo; override;
  end;

implementation

uses
  nextpas.core.text.strings,
    nextpas.core.tls.winssl.lib;

function NormalizeWinSSLCertificateLinkText(const AValue: string): string;
begin
  Result := Trim(UpperCase(AValue));
  Result := StringReplace(Result, ',', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function FindWinSSLIssuerCertificate(const ALeaf: ISSLCertificate;
  const ACertificates: TSSLCertificateArray): ISSLCertificate;
var
  I: Integer;
  LTargetIssuer: string;
  LLeafFingerprint: string;
  LCandidateFingerprint: string;
begin
  Result := nil;
  if ALeaf = nil then
    Exit;

  LTargetIssuer := NormalizeWinSSLCertificateLinkText(ALeaf.GetIssuer);
  if LTargetIssuer = '' then
    Exit;

  LLeafFingerprint := ALeaf.GetFingerprintSHA256;
  for I := 0 to High(ACertificates) do
  begin
    if ACertificates[I] = nil then
      Continue;

    LCandidateFingerprint := ACertificates[I].GetFingerprintSHA256;
    if SameText(LCandidateFingerprint, LLeafFingerprint) then
      Continue;

    if NormalizeWinSSLCertificateLinkText(ACertificates[I].GetSubject) = LTargetIssuer then
    begin
      Result := ACertificates[I];
      Exit;
    end;
  end;
end;

procedure LinkWinSSLPeerCertificateIssuerLinks(
  const ACertificates: TSSLCertificateArray
);
var
  I: Integer;
begin
  for I := 0 to High(ACertificates) do
    if ACertificates[I] <> nil then
      ACertificates[I].SetIssuerCertificate(
        FindWinSSLIssuerCertificate(ACertificates[I], ACertificates));
end;

// ============================================================================
// TWinSSLSession - 会话实现
// ============================================================================

constructor TWinSSLSession.Create;
begin
  inherited Create;
  FID := '';
  FCreationTime := Now;
  FTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FProtocolVersion := sslProtocolTLS12;
  FCipherName := '';
  SetLength(FSessionData, 0);
  FPeerCertificate := nil;
  FIsResumed := False;
end;

function TWinSSLSession.BuildSerializedSessionData: TBytes;
const
  WINSSL_SESSION_SERIALIZATION_MAGIC = 'fafafa-winssl-session-v1';
var
  LData: TStringArray;
begin
  SetLength(Result, 0);
  if FID = '' then
    Exit;
  try
    StringPairsGet(LPairs, 'magic') := WINSSL_SESSION_SERIALIZATION_MAGIC;
    StringPairsGet(LPairs, 'id') := FID;
    StringPairsGet(LPairs, 'created_unix') := IntToStr(DateTimeToUnix(FCreationTime));
    StringPairsGet(LPairs, 'timeout') := IntToStr(FTimeout);
    StringPairsGet(LPairs, 'protocol') := IntToStr(Ord(FProtocolVersion));
    StringPairsGet(LPairs, 'cipher') := FCipherName;
    if FIsResumed then
      StringPairsGet(LPairs, 'resumed') := '1'
    else
      StringPairsGet(LPairs, 'resumed') := '0';
    Result := BytesOf(UTF8String(LData.Text));
  finally
  end;
end;

function TWinSSLSession.TryLoadSerializedSessionData(const AData: TBytes): Boolean;
const
  WINSSL_SESSION_SERIALIZATION_MAGIC = 'fafafa-winssl-session-v1';
var
  LData: TStringArray;
  LText: RawByteString;
  LID: string;
  LCipher: string;
  LCreatedUnix: Int64;
  LTimeout: Integer;
  LProtocolOrdinal: Integer;
  LResumed: string;
begin
  Result := False;
  if Length(AData) = 0 then
    Exit;

  SetString(LText, PAnsiChar(@AData[0]), Length(AData));
  try
    LData.Text := string(UTF8String(LText));
    if StringPairsGet(LPairs, 'magic') <> WINSSL_SESSION_SERIALIZATION_MAGIC then
      Exit;

    LID := StringPairsGet(LPairs, 'id');
    if LID = '' then
      Exit;

    if not TryStrToInt64(StringPairsGet(LPairs, 'created_unix'), LCreatedUnix) then
      Exit;
    if not TryStrToInt(StringPairsGet(LPairs, 'timeout'), LTimeout) then
      Exit;
    if not TryStrToInt(StringPairsGet(LPairs, 'protocol'), LProtocolOrdinal) then
      Exit;
    if (LProtocolOrdinal < Ord(Low(TSSLProtocolVersion))) or
       (LProtocolOrdinal > Ord(High(TSSLProtocolVersion))) then
      Exit;

    LCipher := StringPairsGet(LPairs, 'cipher');
    LResumed := StringPairsGet(LPairs, 'resumed');
    if (LResumed <> '0') and (LResumed <> '1') then
      Exit;

    FID := LID;
    FCreationTime := UnixToDateTime(LCreatedUnix);
    FTimeout := LTimeout;
    FProtocolVersion := TSSLProtocolVersion(LProtocolOrdinal);
    FCipherName := LCipher;
    FIsResumed := LResumed = '1';
    FSessionData := Copy(AData);
    Result := True;
  finally
  end;
end;

destructor TWinSSLSession.Destroy;
begin
  inherited Destroy;
end;

function TWinSSLSession.GetID: string;
begin
  Result := FID;
end;

function TWinSSLSession.GetCreationTime: TDateTime;
begin
  Result := FCreationTime;
end;

function TWinSSLSession.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TWinSSLSession.SetTimeout(ATimeout: Integer);
begin
  FTimeout := ATimeout;
  FSessionData := BuildSerializedSessionData;
end;

function TWinSSLSession.IsValid: Boolean;
begin
  Result := (FID <> '') and ((Now - FCreationTime) * 86400 < FTimeout);
end;

function TWinSSLSession.IsResumable: Boolean;
begin
  Result := IsValid;
end;

function TWinSSLSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := FProtocolVersion;
end;

function TWinSSLSession.GetCipherName: string;
begin
  Result := FCipherName;
end;

function TWinSSLSession.GetPeerCertificate: ISSLCertificate;
begin
  Result := FPeerCertificate;
end;

procedure TWinSSLSession.SetPeerCertificate(ACert: ISSLCertificate);
begin
  FPeerCertificate := ACert;
end;

function TWinSSLSession.Serialize: TBytes;
begin
  if (Length(FSessionData) = 0) and (FID <> '') then
    FSessionData := BuildSerializedSessionData;
  Result := Copy(FSessionData);
end;

function TWinSSLSession.Deserialize(const AData: TBytes): Boolean;
begin
  Result := TryLoadSerializedSessionData(AData);
end;

function TWinSSLSession.Clone: ISSLSession;
var
  LSession: TWinSSLSession;
begin
  LSession := TWinSSLSession.Create;
  LSession.FID := FID;
  LSession.FCreationTime := FCreationTime;
  LSession.FTimeout := FTimeout;
  LSession.FProtocolVersion := FProtocolVersion;
  LSession.FCipherName := FCipherName;
  LSession.FSessionData := FSessionData;
  LSession.FIsResumed := FIsResumed;
  if FPeerCertificate <> nil then
    LSession.FPeerCertificate := FPeerCertificate.Clone
  else
    LSession.FPeerCertificate := nil;
  Result := LSession;
end;

procedure TWinSSLSession.SetSessionMetadata(const AID: string;
  AProtocol: TSSLProtocolVersion; const ACipher: string; AResumed: Boolean);
begin
  FID := AID;
  FProtocolVersion := AProtocol;
  FCipherName := ACipher;
  FIsResumed := AResumed;
  FSessionData := BuildSerializedSessionData;
end;

function TWinSSLSession.WasResumed: Boolean;
begin
  Result := FIsResumed;
end;

// ============================================================================
// TWinSSLSessionManager - 会话缓存管理器
// ============================================================================

constructor TWinSSLSessionManager.Create;
begin
  inherited Create;
  FSessions.Duplicates := dupIgnore;
  FSessions.Sorted := False;
  FLock := Mutex;
  FMaxSessions := 100;
end;

destructor TWinSSLSessionManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to Length(FSessions) - 1 do
  begin
    if FSessions.Objects[i] <> nil then
      ISSLSession(Pointer(FSessions.Objects[i]))._Release;
  end;
  inherited Destroy;
end;

procedure TWinSSLSessionManager.AddSession(const AID: string; ASession: ISSLSession);
var
  LIndex: Integer;
begin
  FLock.Acquire;
  try
    LIndex := FSessions.IndexOf(AID);
    if LIndex >= 0 then
    begin
      if FSessions.Objects[LIndex] <> nil then
        ISSLSession(Pointer(FSessions.Objects[LIndex]))._Release;
      FSessions.Delete(LIndex);
    end;

    if ASession <> nil then
      ASession._AddRef;

    FSessions.AddObject(AID, TObject(Pointer(ASession)));

    while Length(FSessions) > FMaxSessions do
    begin
      if FSessions.Objects[0] <> nil then
        ISSLSession(Pointer(FSessions.Objects[0]))._Release;
      FSessions.Delete(0);
    end;
  finally
    FLock.Release;
  end;
end;

function TWinSSLSessionManager.GetSession(const AID: string): ISSLSession;
var
  LIndex: Integer;
begin
  FLock.Acquire;
  try
    LIndex := FSessions.IndexOf(AID);
    if LIndex >= 0 then
    begin
      Result := ISSLSession(Pointer(FSessions.Objects[LIndex]));
      if not Result.IsValid then
      begin
        if FSessions.Objects[LIndex] <> nil then
          ISSLSession(Pointer(FSessions.Objects[LIndex]))._Release;
        FSessions.Delete(LIndex);
        Result := nil;
      end;
    end
    else
      Result := nil;
  finally
    FLock.Release;
  end;
end;

procedure TWinSSLSessionManager.RemoveSession(const AID: string);
var
  LIndex: Integer;
begin
  FLock.Acquire;
  try
    LIndex := FSessions.IndexOf(AID);
    if LIndex >= 0 then
    begin
      if FSessions.Objects[LIndex] <> nil then
        ISSLSession(Pointer(FSessions.Objects[LIndex]))._Release;
      FSessions.Delete(LIndex);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TWinSSLSessionManager.CleanupExpired;
var
  i: Integer;
begin
  FLock.Acquire;
  try
    for i := Length(FSessions) - 1 downto 0 do
    begin
      if not ISSLSession(Pointer(FSessions.Objects[i])).IsValid then
      begin
        if FSessions.Objects[i] <> nil then
          ISSLSession(Pointer(FSessions.Objects[i]))._Release;
        FSessions.Delete(i);
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TWinSSLSessionManager.SetMaxSessions(AMax: Integer);
begin
  if AMax > 0 then
    FMaxSessions := AMax;
end;

// ============================================================================
// TWinSSLConnection - 构造和析构
// ============================================================================

constructor TWinSSLConnection.Create(AContext: ISSLContext; ASocket: THandle);
begin
  inherited Create(AContext);
  FSocket := ASocket;
  FStream := nil;
  FHandshakeState := sslHsNotStarted;
  FTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;

  FServerName := '';

  FRecvBufferUsed := 0;
  FDecryptedBufferUsed := 0;
  FExtraDataSize := 0;

  FCurrentSession := nil;
  FSessionReused := False;
  FLastError := sslErrNone;

  FHandshakeStartCounter := 0;
  FHandshakeEndCounter := 0;

  InitSecHandle(FCtxtHandle);
end;

constructor TWinSSLConnection.Create(AContext: ISSLContext; AStream: TStream);
begin
  Create(AContext, WrapTStream(AStream, False));
end;

constructor TWinSSLConnection.Create(AContext: ISSLContext; AStream: IStream);
begin
  inherited Create(AContext);
  FSocket := INVALID_HANDLE_VALUE;
  FStream := AStream;
  FHandshakeState := sslHsNotStarted;
  FTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;

  FServerName := '';

  FRecvBufferUsed := 0;
  FDecryptedBufferUsed := 0;
  FExtraDataSize := 0;

  FCurrentSession := nil;
  FSessionReused := False;
  FLastError := sslErrNone;

  FHandshakeStartCounter := 0;
  FHandshakeEndCounter := 0;

  InitSecHandle(FCtxtHandle);
end;

destructor TWinSSLConnection.Destroy;
begin
  if FConnected then
    DoShutdown;
  if IsValidSecHandle(FCtxtHandle) then
    DeleteSecurityContext(@FCtxtHandle);
  inherited Destroy;
end;

// ============================================================================
// ISSLClientConnection
// ============================================================================

procedure TWinSSLConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TWinSSLConnection.GetServerName: string;
begin
  Result := FServerName;
end;

// ============================================================================
// 内部方法 - 数据收发
// ============================================================================

function TWinSSLConnection.SendData(const ABuffer; ASize: Integer): Integer;
begin
  if FStream <> nil then
    Result := FStream.Write(ABuffer, ASize)
  else if FSocket <> INVALID_HANDLE_VALUE then
  begin
    {$IFDEF WINDOWS}
    Result := winsock2.send(FSocket, ABuffer, ASize, 0);
    if Result = SOCKET_ERROR then
      Result := -1;
    {$ELSE}
    Result := fpSend(FSocket, @ABuffer, ASize, 0);
    {$ENDIF}
  end
  else
    Result := -1;
end;

function TWinSSLConnection.RecvData(var ABuffer; ASize: Integer): Integer;
begin
  if FStream <> nil then
    Result := FStream.Read(ABuffer, ASize)
  else if FSocket <> INVALID_HANDLE_VALUE then
  begin
    {$IFDEF WINDOWS}
    Result := winsock2.recv(FSocket, ABuffer, ASize, 0);
    if Result = SOCKET_ERROR then
      Result := -1;
    {$ELSE}
    Result := fpRecv(FSocket, @ABuffer, ASize, 0);
    {$ENDIF}
  end
  else
    Result := -1;
end;

// ============================================================================
// 握手辅助方法
// ============================================================================

procedure TWinSSLConnection.PrepareInputBufferDesc(var AInBuffers: array of TSecBuffer;
  var AInBufferDesc: TSecBufferDesc; AData: Pointer; ADataSize: DWORD);
begin
  AInBuffers[0].pvBuffer := AData;
  AInBuffers[0].cbBuffer := ADataSize;
  AInBuffers[0].BufferType := SECBUFFER_TOKEN;

  if Length(AInBuffers) > 1 then
  begin
    AInBuffers[1].pvBuffer := nil;
    AInBuffers[1].cbBuffer := 0;
    AInBuffers[1].BufferType := SECBUFFER_EMPTY;
  end;

  AInBufferDesc.cBuffers := Length(AInBuffers);
  AInBufferDesc.pBuffers := @AInBuffers[0];
  AInBufferDesc.ulVersion := SECBUFFER_VERSION;
end;

procedure TWinSSLConnection.PrepareOutputBufferDesc(var AOutBuffers: array of TSecBuffer;
  var AOutBufferDesc: TSecBufferDesc);
begin
  AOutBuffers[0].pvBuffer := nil;
  AOutBuffers[0].BufferType := SECBUFFER_TOKEN;
  AOutBuffers[0].cbBuffer := 0;

  AOutBufferDesc.cBuffers := 1;
  AOutBufferDesc.pBuffers := @AOutBuffers[0];
  AOutBufferDesc.ulVersion := SECBUFFER_VERSION;
end;

procedure TWinSSLConnection.HandleExtraData(var AExtraBuffer: array of TSecBuffer;
  var AIoBuffer: array of Byte; var AIoBufferSize: DWORD; AStatus: SECURITY_STATUS);
begin
  if Length(AExtraBuffer) > 1 then
  begin
    if (AExtraBuffer[1].BufferType = SECBUFFER_EXTRA) and (AExtraBuffer[1].cbBuffer > 0) then
    begin
      Move(AIoBuffer[AIoBufferSize - AExtraBuffer[1].cbBuffer], AIoBuffer[0], AExtraBuffer[1].cbBuffer);
      AIoBufferSize := AExtraBuffer[1].cbBuffer;
    end
    else if AStatus <> SEC_E_INCOMPLETE_MESSAGE then
      AIoBufferSize := 0;
  end
  else if AStatus <> SEC_E_INCOMPLETE_MESSAGE then
    AIoBufferSize := 0;
end;

function TWinSSLConnection.SendOutputBuffer(const AOutBuffer: TSecBuffer): Boolean;
var
  cbData: DWORD;
begin
  Result := True;
  if (AOutBuffer.cbBuffer > 0) and (AOutBuffer.pvBuffer <> nil) then
  begin
    cbData := SendData(AOutBuffer.pvBuffer^, AOutBuffer.cbBuffer);
    FreeContextBuffer(AOutBuffer.pvBuffer);
    if cbData <= 0 then
      Result := False;
  end;
end;

function TWinSSLConnection.BuildALPNBuffer(const AProtocols: string; out ABuffer: TBytes): Boolean;
var
  LProtocols: TStringArray;
  LTotalSize, LListSize, LOffset, I: Integer;
  LProtoLen: Byte;
begin
  Result := False;
  SetLength(ABuffer, 0);

  if AProtocols = '' then
    Exit;
  try

    if Length(LProtocols) = 0 then
      Exit;

    LListSize := 0;
    for I := 0 to Length(LProtocols) - 1 do
    begin
      if Length(LProtocols[I]) > 255 then
        Continue;
      Inc(LListSize, 1 + Length(LProtocols[I]));
    end;

    if LListSize = 0 then
      Exit;

    LTotalSize := 4 + 4 + 2 + LListSize;
    SetLength(ABuffer, LTotalSize);
    FillChar(ABuffer[0], LTotalSize, 0);

    LOffset := 0;

    PDWORD(@ABuffer[LOffset])^ := LTotalSize - 4;
    Inc(LOffset, 4);

    PDWORD(@ABuffer[LOffset])^ := SecApplicationProtocolNegotiationExt_ALPN;
    Inc(LOffset, 4);

    PWord(@ABuffer[LOffset])^ := Word(LListSize);
    Inc(LOffset, 2);

    for I := 0 to Length(LProtocols) - 1 do
    begin
      if Length(LProtocols[I]) > 255 then
        Continue;
      LProtoLen := Length(LProtocols[I]);
      ABuffer[LOffset] := LProtoLen;
      Inc(LOffset);
      if LProtoLen > 0 then
      begin
        Move(LProtocols[I][1], ABuffer[LOffset], LProtoLen);
        Inc(LOffset, LProtoLen);
      end;
    end;

    Result := True;
  finally
  end;
end;

procedure TWinSSLConnection.NotifyInfoCallback(AWhere: Integer; ARet: Integer; const AState: string);
var
  LContextAccess: IWinSSLContextAccess;
  LCallback: TSSLInfoCallback;
begin
  LCallback := nil;
  if TryGetContextAccess(LContextAccess) then
    LCallback := LContextAccess.GetWinSSLInfoCallback;
  if Assigned(LCallback) then
    LCallback(AWhere, ARet, AState);
end;

function TWinSSLConnection.TryGetContextAccess(out AContextAccess: IWinSSLContextAccess): Boolean;
begin
  Result := Supports(FContext, IWinSSLContextAccess, AContextAccess);
end;

function TWinSSLConnection.TryGetLibraryStatsAccess(
  out ALibraryStatsAccess: IWinSSLLibraryStatsAccess): Boolean;
var
  LContextAccess: IWinSSLContextAccess;
begin
  ALibraryStatsAccess := nil;
  if not TryGetContextAccess(LContextAccess) then
    Exit(False);
  Result := Supports(LContextAccess.GetWinSSLLibrary, IWinSSLLibraryStatsAccess,
    ALibraryStatsAccess);
end;

procedure TWinSSLConnection.TryUpdateLibraryStatistics;
var
  LLibraryStatsAccess: IWinSSLLibraryStatsAccess;
begin
  try
    if TryGetLibraryStatsAccess(LLibraryStatsAccess) then
    begin
      LLibraryStatsAccess.UpdateHandshakeStatistics(Round(FHandshakeDuration), True);
      LLibraryStatsAccess.UpdateSessionStatistics(FSessionReused);
    end;
  except
    on Exception do
    begin
      // Statistics are observability-only; they must never break a successful handshake path.
    end;
  end;
end;

function TWinSSLConnection.TryGetCurrentSessionInfo(
  out ASessionInfo: SecPkgContext_SessionInfo): Boolean;
begin
  FillChar(ASessionInfo, SizeOf(ASessionInfo), 0);
  try
    Result := IsSuccess(QueryContextAttributesW(@FCtxtHandle,
      SECPKG_ATTR_SESSION_INFO, @ASessionInfo));
  except
    on Exception do
    begin
      Result := False;
    end;
  end;
end;

function TWinSSLConnection.SessionIdBytesToHex(
  const ASessionInfo: SecPkgContext_SessionInfo): string;
const
  HexDigits: array[0..15] of Char = '0123456789ABCDEF';
var
  I: Integer;
  LSessionIdLength: Integer;
begin
  Result := '';

  LSessionIdLength := Integer(ASessionInfo.cbSessionId);
  if LSessionIdLength <= 0 then
    Exit;

  if LSessionIdLength > Length(ASessionInfo.rgbSessionId) then
    LSessionIdLength := Length(ASessionInfo.rgbSessionId);

  SetLength(Result, LSessionIdLength * 2);
  for I := 0 to LSessionIdLength - 1 do
  begin
    Result[I * 2 + 1] := HexDigits[(ASessionInfo.rgbSessionId[I] shr 4) and $0F];
    Result[I * 2 + 2] := HexDigits[ASessionInfo.rgbSessionId[I] and $0F];
  end;
end;

procedure TWinSSLConnection.UpdateSessionReuseTruthFromContext(
  out ASessionId: string);
begin
  ASessionId := '';
  FSessionReused := False;
  // GitHub Windows runtime proof still shows AVs inside/after the
  // SECPKG_ATTR_SESSION_INFO probe on canonical shared handshake paths.
  // Until that binding is reintroduced through a dedicated safe proof lane,
  // shared flows must stay on the conservative truth:
  //   - reused = False
  //   - session_id = ''
  // and rely on the existing fallback session-id generators.
end;

procedure TWinSSLConnection.SaveSessionAfterHandshake;
var
  LSession: TWinSSLSession;
  LSessionID: string;
  LProtocol: TSSLProtocolVersion;
  LCipher: string;
  LPeerCert: ISSLCertificate;
begin
  UpdateSessionReuseTruthFromContext(LSessionID);
  if LSessionID = '' then
    LSessionID := Format('winssl-session-%p', [Pointer(@FCtxtHandle)]);

  LProtocol := DoGetProtocolVersion;
  LCipher := DoGetCipherName;
  LPeerCert := DoGetPeerCertificate;

  LSession := TWinSSLSession.Create;
  try
    LSession.SetSessionMetadata(LSessionID, LProtocol, LCipher, FSessionReused);
    if LPeerCert <> nil then
      LSession.SetPeerCertificate(LPeerCert);
    FCurrentSession := LSession;
  except
    // 保存会话失败不影响连接
  end;
end;

// ============================================================================
// 证书验证
// ============================================================================

procedure TWinSSLConnection.RememberPeerValidationRole(AIsClient: Boolean);
begin
  FPeerValidationRoleKnown := True;
  FPeerValidationRoleIsClient := AIsClient;
end;

function TWinSSLConnection.TryResolvePeerValidationRole(
  out AIsClient: Boolean): Boolean;
begin
  if FPeerValidationRoleKnown then
  begin
    AIsClient := FPeerValidationRoleIsClient;
    Exit(True);
  end;

  if FContext = nil then
    Exit(False);

  case FContext.GetContextType of
    sslCtxClient:
      begin
        AIsClient := True;
        Exit(True);
      end;
    sslCtxServer:
      begin
        AIsClient := False;
        Exit(True);
      end;
  end;

  Result := False;
end;

function TWinSSLConnection.ValidatePeerCertificate(AIsClient: Boolean;
  out AVerifyError: Integer): Boolean;
var
  LContextAccess: IWinSSLContextAccess;
  LVerifyMode: TSSLVerifyModes;
  LVerifyFlags: TSSLCertVerifyFlags;
  LNeedCert: Boolean;
  LCertContext: PCCERT_CONTEXT;
  LChainPara: CERT_CHAIN_PARA;
  LChainContext: PCCERT_CHAIN_CONTEXT;
  LPolicyPara: CERT_CHAIN_POLICY_PARA;
  LPolicyStatus: CERT_CHAIN_POLICY_STATUS;
  LSSLExtra: SSL_EXTRA_CERT_CHAIN_POLICY_PARA;
  LChainFlags: DWORD;
  LHostname: string;
  LServerNameW: PWideChar;
  LStatus: SECURITY_STATUS;
  LVerifyCallback: TSSLVerifyCallback;
  LPeerCert: ISSLCertificate;

  function NormalizeHostForVerify(const S: string): string;
  var
    LHost: string;
    P, PEnd: SizeInt;
    PortPart: string;
    I: Integer;
  begin
    LHost := Trim(S);

    if (LHost <> '') and (LHost[1] = '[') then
    begin
      PEnd := Pos(']', LHost);
      if PEnd > 0 then
        LHost := Copy(LHost, 2, PEnd - 2);
    end;

    P := Pos('%', LHost);
    if P > 0 then
      LHost := Copy(LHost, 1, P - 1);

    if (Pos(':', LHost) > 0) and (Pos(':', LHost) = LastDelimiter(':', LHost)) then
    begin
      P := Pos(':', LHost);
      PortPart := Copy(LHost, P + 1, Length(LHost) - P);
      if PortPart <> '' then
      begin
        for I := 1 to Length(PortPart) do
          if not (PortPart[I] in ['0'..'9']) then
          begin
            PortPart := '';
            Break;
          end;
        if PortPart <> '' then
          LHost := Copy(LHost, 1, P - 1);
      end;
    end;

    Result := LHost;
  end;

begin
  AVerifyError := 0;

  if not IsValidSecHandle(FCtxtHandle) then
  begin
    AVerifyError := -1;
    Result := False;
    Exit;
  end;

  LVerifyMode := FContext.GetVerifyMode;
  if not (sslVerifyPeer in LVerifyMode) then
  begin
    Result := True;
    Exit;
  end;

  LNeedCert := AIsClient or (sslVerifyFailIfNoPeerCert in LVerifyMode);

  LCertContext := nil;
  LStatus := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_REMOTE_CERT_CONTEXT, @LCertContext);
  if (not IsSuccess(LStatus)) or (LCertContext = nil) then
  begin
    if not LNeedCert then
    begin
      Result := True;
      Exit;
    end;
    AVerifyError := -1;
    Result := False;
    Exit;
  end;

  try
    LVerifyFlags := FContext.GetCertVerifyFlags;

    if AIsClient and not (sslCertVerifyIgnoreHostname in LVerifyFlags) then
    begin
      LHostname := NormalizeHostForVerify(FServerName);
      if LHostname = '' then
      begin
        AVerifyError := CERT_E_INVALID_NAME;
        Result := False;
        Exit;
      end;
    end;

    LChainFlags := 0;
    if (sslCertVerifyCheckRevocation in LVerifyFlags) or
      (sslCertVerifyCheckOCSP in LVerifyFlags) then
      LChainFlags := LChainFlags or CERT_CHAIN_REVOCATION_CHECK_CHAIN;

    if sslCertVerifyCheckCRL in LVerifyFlags then
      LChainFlags := LChainFlags or CERT_CHAIN_REVOCATION_CHECK_END_CERT;

    FillChar(LChainPara, SizeOf(LChainPara), 0);
    LChainPara.cbSize := SizeOf(CERT_CHAIN_PARA);

    if not TryGetContextAccess(LContextAccess) then
    begin
      AVerifyError := Integer(SEC_E_INTERNAL_ERROR);
      Result := False;
      Exit;
    end;

    if not CertGetCertificateChain(
      nil,
      LCertContext,
      nil,
      HCERTSTORE(LContextAccess.GetWinSSLCAStoreHandle),
      @LChainPara,
      LChainFlags,
      nil,
      @LChainContext
    ) then
    begin
      AVerifyError := GetLastError;
      Result := False;
      Exit;
    end;

    try
      FillChar(LPolicyPara, SizeOf(LPolicyPara), 0);
      LPolicyPara.cbSize := SizeOf(CERT_CHAIN_POLICY_PARA);
      LPolicyPara.dwFlags := 0;

      if sslCertVerifyIgnoreExpiry in LVerifyFlags then
        LPolicyPara.dwFlags := LPolicyPara.dwFlags or CERT_CHAIN_POLICY_IGNORE_NOT_TIME_VALID_FLAG;

      if sslCertVerifyAllowSelfSigned in LVerifyFlags then
        LPolicyPara.dwFlags := LPolicyPara.dwFlags or CERT_CHAIN_POLICY_ALLOW_UNKNOWN_CA_FLAG;

      if sslCertVerifyIgnoreHostname in LVerifyFlags then
        LPolicyPara.dwFlags := LPolicyPara.dwFlags or CERT_CHAIN_POLICY_IGNORE_INVALID_NAME_FLAG;

      FillChar(LSSLExtra, SizeOf(LSSLExtra), 0);
      LSSLExtra.cbSize := SizeOf(SSL_EXTRA_CERT_CHAIN_POLICY_PARA);

      if AIsClient then
        LSSLExtra.dwAuthType := AUTHTYPE_SERVER
      else
        LSSLExtra.dwAuthType := AUTHTYPE_CLIENT;

      LSSLExtra.fdwChecks := 0;
      LServerNameW := nil;
      try
        if AIsClient and not (sslCertVerifyIgnoreHostname in LVerifyFlags) then
        begin
          LHostname := NormalizeHostForVerify(FServerName);
          if LHostname <> '' then
            LServerNameW := StringToPWideChar(LHostname);
        end;

        LSSLExtra.pwszServerName := LServerNameW;
        LPolicyPara.pvExtraPolicyPara := @LSSLExtra;

        FillChar(LPolicyStatus, SizeOf(LPolicyStatus), 0);
        LPolicyStatus.cbSize := SizeOf(CERT_CHAIN_POLICY_STATUS);

        if not CertVerifyCertificateChainPolicy(
          CERT_CHAIN_POLICY_SSL,
          LChainContext,
          @LPolicyPara,
          @LPolicyStatus
        ) then
        begin
          AVerifyError := GetLastError;
          Result := False;
          Exit;
        end;

        if LPolicyStatus.dwError <> 0 then
        begin
          AVerifyError := Integer(LPolicyStatus.dwError);
          LVerifyCallback := LContextAccess.GetWinSSLVerifyCallback;

          if Assigned(LVerifyCallback) then
          begin
            LPeerCert := DoGetPeerCertificate;
            if (LPeerCert <> nil) and LVerifyCallback(
              LPeerCert.GetInfo,
              AVerifyError,
              DoGetVerifyResultString
            ) then
            begin
              Result := True;
              Exit;
            end;
          end;

          Result := False;
          Exit;
        end;

        Result := True;
      finally
        if LServerNameW <> nil then
          FreePWideCharString(LServerNameW);
      end;
    finally
      CertFreeCertificateChain(LChainContext);
    end;
  finally
    CertFreeCertificateContext(LCertContext);
  end;
end;

// ============================================================================
// TBaseSSLConnection 抽象方法实现
// ============================================================================

function TWinSSLConnection.DoConnect: Boolean;
var
  LVerifyError: Integer;
  LFrequency: Int64;
begin
  NotifyInfoCallback(1, 0, 'handshake_start');
  RememberPeerValidationRole(True);

  Result := ClientHandshake;
  if not Result then
  begin
    FHandshakeState := sslHsFailed;
    NotifyInfoCallback(2, -1, 'handshake_failed');
    Exit;
  end;

  FConnected := True;

  if not ValidatePeerCertificate(True, LVerifyError) then
  begin
    FConnected := False;
    FHandshakeState := sslHsFailed;
    NotifyInfoCallback(2, LVerifyError, 'verify_failed');
    Result := False;
    Exit;
  end;

  FHandshakeState := sslHsCompleted;

  QueryPerformanceCounter(FHandshakeEndCounter);
  QueryPerformanceFrequency(LFrequency);
  if LFrequency > 0 then
    FHandshakeDuration := ((FHandshakeEndCounter - FHandshakeStartCounter) * 1000) / LFrequency;

  SaveSessionAfterHandshake;

  TryUpdateLibraryStatistics;

  NotifyInfoCallback(3, 0, 'handshake_done');
  Result := True;
end;

function TWinSSLConnection.DoAccept: Boolean;
var
  LVerifyError: Integer;
  LFrequency: Int64;
begin
  NotifyInfoCallback(1, 0, 'handshake_start');
  RememberPeerValidationRole(False);

  Result := ServerHandshake;
  if not Result then
  begin
    FHandshakeState := sslHsFailed;
    NotifyInfoCallback(2, -1, 'handshake_failed');
    Exit;
  end;

  FConnected := True;

  if not ValidatePeerCertificate(False, LVerifyError) then
  begin
    FConnected := False;
    FHandshakeState := sslHsFailed;
    NotifyInfoCallback(2, LVerifyError, 'verify_failed');
    Result := False;
    Exit;
  end;

  FHandshakeState := sslHsCompleted;

  QueryPerformanceCounter(FHandshakeEndCounter);
  QueryPerformanceFrequency(LFrequency);
  if LFrequency > 0 then
    FHandshakeDuration := ((FHandshakeEndCounter - FHandshakeStartCounter) * 1000) / LFrequency;

  SaveSessionAfterHandshake;

  TryUpdateLibraryStatistics;

  NotifyInfoCallback(3, 0, 'handshake_done');
  Result := True;
end;

function TWinSSLConnection.DoHandshakeInternal: TSSLHandshakeState;
begin
  Result := PerformHandshake;
end;

function TWinSSLConnection.DoShutdown: Boolean;
var
  OutBuffers: array[0..0] of TSecBuffer;
  OutBufferDesc: TSecBufferDesc;
  dwType, Status: DWORD;
  dwSSPIFlags, dwSSPIOutFlags: DWORD;
  tsExpiry: TTimeStamp;
  LCredHandle: PCredHandle;
  LSent: Integer;
begin
  Result := False;

  if not FConnected then
    Exit;

  dwType := SCHANNEL_SHUTDOWN;

  OutBuffers[0].pvBuffer := @dwType;
  OutBuffers[0].BufferType := SECBUFFER_TOKEN;
  OutBuffers[0].cbBuffer := SizeOf(dwType);

  OutBufferDesc.cBuffers := 1;
  OutBufferDesc.pBuffers := @OutBuffers[0];
  OutBufferDesc.ulVersion := SECBUFFER_VERSION;

  Status := ApplyControlToken(@FCtxtHandle, @OutBufferDesc);

  if not IsSuccess(Status) then
  begin
    DeleteSecurityContext(@FCtxtHandle);
    InitSecHandle(FCtxtHandle);
    FConnected := False;
    Exit;
  end;

  OutBuffers[0].pvBuffer := nil;
  OutBuffers[0].BufferType := SECBUFFER_TOKEN;
  OutBuffers[0].cbBuffer := 0;

  OutBufferDesc.cBuffers := 1;
  OutBufferDesc.pBuffers := @OutBuffers[0];
  OutBufferDesc.ulVersion := SECBUFFER_VERSION;

  LCredHandle := PCredHandle(GetNativeHandleSafe(FContext, 'TWinSSLConnection.PerformHandshake'));

  dwSSPIFlags := ISC_REQ_SEQUENCE_DETECT or ISC_REQ_REPLAY_DETECT or
    ISC_REQ_CONFIDENTIALITY or ISC_RET_EXTENDED_ERROR or
    ISC_REQ_ALLOCATE_MEMORY or ISC_REQ_STREAM;

  if FContext.GetContextType = sslCtxClient then
  begin
    Status := InitializeSecurityContextW(
      LCredHandle,
      @FCtxtHandle,
      nil,
      dwSSPIFlags,
      0,
      SECURITY_NATIVE_DREP,
      nil,
      0,
      @FCtxtHandle,
      @OutBufferDesc,
      @dwSSPIOutFlags,
      @tsExpiry
    );
  end
  else
  begin
    Status := AcceptSecurityContext(
      LCredHandle,
      @FCtxtHandle,
      nil,
      dwSSPIFlags,
      SECURITY_NATIVE_DREP,
      @FCtxtHandle,
      @OutBufferDesc,
      @dwSSPIOutFlags,
      @tsExpiry
    );
  end;

  if (OutBuffers[0].pvBuffer <> nil) and (OutBuffers[0].cbBuffer > 0) then
  begin
    LSent := SendData(OutBuffers[0].pvBuffer^, OutBuffers[0].cbBuffer);
    FreeContextBuffer(OutBuffers[0].pvBuffer);
  end;

  DeleteSecurityContext(@FCtxtHandle);
  InitSecHandle(FCtxtHandle);
  FConnected := False;
  Result := True;
end;

procedure TWinSSLConnection.DoClose;
begin
  if FConnected then
    DoShutdown;
  FConnected := False;
  FHandshakeState := sslHsNotStarted;
end;

function TWinSSLConnection.DoRenegotiate: Boolean;
begin
  raise ESSLPlatformNotSupportedException.CreateWithContext(
    'TLS renegotiation is not supported by Windows Schannel. ' +
    'Close the connection and establish a new one instead.',
    sslErrOther,
    'TWinSSLConnection.DoRenegotiate',
    0,
    sslWinSSL
  );
end;

function TWinSSLConnection.DoRead(var ABuffer; ACount: Integer): Integer;
var
  InBuffers: array[0..3] of TSecBuffer;
  InBufferDesc: TSecBufferDesc;
  Status: SECURITY_STATUS;
  i, cbData: Integer;
begin
  Result := 0;

  if not FConnected then
    Exit;

  // 如果有已解密的数据，直接返回
  if FDecryptedBufferUsed > 0 then
  begin
    Result := Min(ACount, FDecryptedBufferUsed);
    Move(FDecryptedBuffer[0], ABuffer, Result);
    Dec(FDecryptedBufferUsed, Result);
    if FDecryptedBufferUsed > 0 then
      Move(FDecryptedBuffer[Result], FDecryptedBuffer[0], FDecryptedBufferUsed);
    Exit;
  end;

  // 读取加密数据
  if FRecvBufferUsed < SizeOf(FRecvBuffer) then
  begin
    cbData := RecvData(FRecvBuffer[FRecvBufferUsed], SizeOf(FRecvBuffer) - FRecvBufferUsed);
    if cbData <= 0 then
      Exit;
    Inc(FRecvBufferUsed, cbData);
  end;

  // 解密数据
  InBuffers[0].pvBuffer := @FRecvBuffer[0];
  InBuffers[0].cbBuffer := FRecvBufferUsed;
  InBuffers[0].BufferType := SECBUFFER_DATA;

  InBuffers[1].BufferType := SECBUFFER_EMPTY;
  InBuffers[2].BufferType := SECBUFFER_EMPTY;
  InBuffers[3].BufferType := SECBUFFER_EMPTY;

  InBufferDesc.cBuffers := 4;
  InBufferDesc.pBuffers := @InBuffers[0];
  InBufferDesc.ulVersion := SECBUFFER_VERSION;

  Status := DecryptMessage(@FCtxtHandle, @InBufferDesc, 0, nil);

  if Status = SEC_E_INCOMPLETE_MESSAGE then
    Exit;

  if not IsSuccess(Status) then
    Exit;

  // 查找解密的数据
  for i := 0 to 3 do
  begin
    if InBuffers[i].BufferType = SECBUFFER_DATA then
    begin
      Result := Min(ACount, Integer(InBuffers[i].cbBuffer));
      Move(InBuffers[i].pvBuffer^, ABuffer, Result);

      if Integer(InBuffers[i].cbBuffer) > Result then
      begin
        FDecryptedBufferUsed := InBuffers[i].cbBuffer - Result;
        Move(PByte(InBuffers[i].pvBuffer)[Result], FDecryptedBuffer[0], FDecryptedBufferUsed);
      end;
      Break;
    end;
  end;

  // 处理额外数据
  for i := 0 to 3 do
  begin
    if InBuffers[i].BufferType = SECBUFFER_EXTRA then
    begin
      Move(FRecvBuffer[FRecvBufferUsed - InBuffers[i].cbBuffer], FRecvBuffer[0], InBuffers[i].cbBuffer);
      FRecvBufferUsed := InBuffers[i].cbBuffer;
      Exit;
    end;
  end;

  FRecvBufferUsed := 0;
end;

function TWinSSLConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
var
  OutBuffers: array[0..3] of TSecBuffer;
  OutBufferDesc: TSecBufferDesc;
  StreamSizes: TSecPkgContext_StreamSizes;
  Status: SECURITY_STATUS;
  Message: array of Byte;
  cbMessage, cbData: DWORD;
begin
  Result := 0;

  if not FConnected then
    Exit;

  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_STREAM_SIZES, @StreamSizes);
  if not IsSuccess(Status) then
    Exit;

  cbMessage := StreamSizes.cbHeader + ACount + StreamSizes.cbTrailer;
  SetLength(Message, cbMessage);

  OutBuffers[0].pvBuffer := @Message[0];
  OutBuffers[0].cbBuffer := StreamSizes.cbHeader;
  OutBuffers[0].BufferType := SECBUFFER_STREAM_HEADER;

  OutBuffers[1].pvBuffer := @Message[StreamSizes.cbHeader];
  OutBuffers[1].cbBuffer := ACount;
  OutBuffers[1].BufferType := SECBUFFER_DATA;
  Move(ABuffer, OutBuffers[1].pvBuffer^, ACount);

  OutBuffers[2].pvBuffer := @Message[StreamSizes.cbHeader + ACount];
  OutBuffers[2].cbBuffer := StreamSizes.cbTrailer;
  OutBuffers[2].BufferType := SECBUFFER_STREAM_TRAILER;

  OutBuffers[3].BufferType := SECBUFFER_EMPTY;

  OutBufferDesc.cBuffers := 4;
  OutBufferDesc.pBuffers := @OutBuffers[0];
  OutBufferDesc.ulVersion := SECBUFFER_VERSION;

  Status := EncryptMessage(@FCtxtHandle, 0, @OutBufferDesc, 0);
  if not IsSuccess(Status) then
    Exit;

  cbData := SendData(Message[0], OutBuffers[0].cbBuffer + OutBuffers[1].cbBuffer + OutBuffers[2].cbBuffer);
  if cbData > 0 then
    Result := ACount;
end;

function TWinSSLConnection.DoGetError(ARet: Integer): TSSLErrorCode;
var
  LastErr: DWORD;
  {$IFDEF WINDOWS}
  WsaErr: Integer;
  {$ENDIF}
begin
  if ARet >= 0 then
  begin
    FLastError := sslErrNone;
    Result := sslErrNone;
    Exit;
  end;

  {$IFDEF WINDOWS}
  WsaErr := WSAGetLastError;

  case WsaErr of
    WSAEWOULDBLOCK:
    begin
      FLastError := sslErrWantRead;
      Result := sslErrWantRead;
      Exit;
    end;

    WSAENOTCONN,
    WSAECONNRESET,
    WSAECONNABORTED:
    begin
      FLastError := sslErrConnection;
      Result := sslErrConnection;
      Exit;
    end;

    WSAETIMEDOUT:
    begin
      FLastError := sslErrTimeout;
      Result := sslErrTimeout;
      Exit;
    end;
  end;
  {$ENDIF}

  LastErr := GetLastError;

  case LastErr of
    {$IFDEF WINDOWS}
    ERROR_IO_PENDING:
      Result := sslErrWantRead;
    ERROR_NOT_CONNECTED:
      Result := sslErrConnection;
    {$ENDIF}
    SEC_E_INCOMPLETE_MESSAGE:
      Result := sslErrWantRead;
    SEC_I_CONTINUE_NEEDED,
    SEC_I_INCOMPLETE_CREDENTIALS:
      Result := sslErrWantWrite;
    SEC_E_CERT_EXPIRED,
    CERT_E_EXPIRED:
      Result := sslErrCertificate;
    SEC_E_WRONG_PRINCIPAL,
    CERT_E_CN_NO_MATCH:
      Result := sslErrCertificate;
    SEC_E_UNTRUSTED_ROOT,
    CERT_E_UNTRUSTEDROOT:
      Result := sslErrCertificate;
    SEC_E_INVALID_TOKEN:
      Result := sslErrProtocol;
    SEC_E_MESSAGE_ALTERED:
      Result := sslErrProtocol;
    SEC_E_ALGORITHM_MISMATCH:
      Result := sslErrHandshake;
    SEC_E_UNSUPPORTED_FUNCTION:
      Result := sslErrConfiguration;
  else
    Result := sslErrOther;
  end;

  FLastError := Result;
end;

function TWinSSLConnection.DoWantRead: Boolean;
begin
  Result := (FLastError = sslErrWantRead);
end;

function TWinSSLConnection.DoWantWrite: Boolean;
begin
  Result := (FLastError = sslErrWantWrite);
end;

function TWinSSLConnection.DoGetProtocolVersion: TSSLProtocolVersion;
var
  ConnInfo: TSecPkgContext_ConnectionInfo;
  Status: SECURITY_STATUS;
begin
  Result := sslProtocolTLS12;

  if not FConnected then
    Exit;

  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_CONNECTION_INFO, @ConnInfo);
  if not IsSuccess(Status) then
    Exit;

  if (ConnInfo.dwProtocol and SP_PROT_TLS1_3) <> 0 then
    Result := sslProtocolTLS13
  else if (ConnInfo.dwProtocol and SP_PROT_TLS1_2) <> 0 then
    Result := sslProtocolTLS12
  else if (ConnInfo.dwProtocol and SP_PROT_TLS1_1) <> 0 then
    Result := sslProtocolTLS11
  else if (ConnInfo.dwProtocol and SP_PROT_TLS1_0) <> 0 then
    Result := sslProtocolTLS10
  else if (ConnInfo.dwProtocol and SP_PROT_SSL3) <> 0 then
    Result := sslProtocolSSL3
  else if (ConnInfo.dwProtocol and SP_PROT_SSL2) <> 0 then
    Result := sslProtocolSSL2;
end;

function TWinSSLConnection.TryGetCipherInfo(out ACipherSuiteId: Word;
  out ACipherSuiteName: string): Boolean;
const
  WINSSL_CIPHER_INFO_BUFFER_SIZE = 1024;
var
  Status: SECURITY_STATUS;
  CipherInfoBuffer: array[0..WINSSL_CIPHER_INFO_BUFFER_SIZE - 1] of Byte;
  CipherInfo: ^TSecPkgContext_CipherInfoPrefix;
  CipherSuiteName: PWideChar;
begin
  Result := False;
  ACipherSuiteId := 0;
  ACipherSuiteName := '';

  if not FConnected then
    Exit;

  FillChar(CipherInfoBuffer, SizeOf(CipherInfoBuffer), 0);
  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_CIPHER_INFO,
    @CipherInfoBuffer[0]);
  if not IsSuccess(Status) then
    Exit;

  CipherInfo := @CipherInfoBuffer[0];
  ACipherSuiteId := Word(CipherInfo^.dwCipherSuite and $FFFF);

  CipherSuiteName := PWideChar(@CipherInfoBuffer[SizeOf(TSecPkgContext_CipherInfoPrefix)]);
  if (CipherSuiteName <> nil) and (CipherSuiteName^ <> #0) then
    ACipherSuiteName := WideCharToString(CipherSuiteName);

  Result := (ACipherSuiteId <> 0) or (ACipherSuiteName <> '');
end;

function TWinSSLConnection.DoGetCipherName: string;
var
  ConnInfo: TSecPkgContext_ConnectionInfo;
  Status: SECURITY_STATUS;
  CipherName, HashName: string;
  CipherSuiteId: Word;
  CipherSuiteName: string;
begin
  Result := '';

  if not FConnected then
    Exit;

  if TryGetCipherInfo(CipherSuiteId, CipherSuiteName) and
     (CipherSuiteName <> '') then
    Exit(CipherSuiteName);

  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_CONNECTION_INFO, @ConnInfo);
  if not IsSuccess(Status) then
    Exit;

  case ConnInfo.aiCipher of
    CALG_AES_256: CipherName := 'AES_256';
    CALG_AES_192: CipherName := 'AES_192';
    CALG_AES_128: CipherName := 'AES_128';
    CALG_3DES:    CipherName := '3DES';
    CALG_DES:     CipherName := 'DES';
    CALG_RC4:     CipherName := 'RC4';
  else
    CipherName := Format('0x%x', [ConnInfo.aiCipher]);
  end;

  case ConnInfo.aiHash of
    CALG_SHA_512: HashName := 'SHA512';
    CALG_SHA_384: HashName := 'SHA384';
    CALG_SHA_256: HashName := 'SHA256';
    CALG_SHA1:    HashName := 'SHA';
    CALG_MD5:     HashName := 'MD5';
  else
    HashName := '';
  end;

  if HashName <> '' then
    Result := Format('%s_%s (%d bits)', [CipherName, HashName, ConnInfo.dwCipherStrength])
  else
    Result := Format('%s (%d bits)', [CipherName, ConnInfo.dwCipherStrength]);
end;

function TWinSSLConnection.DoGetPeerCertificate: ISSLCertificate;
var
  CertContext: PCCERT_CONTEXT;
  Status: SECURITY_STATUS;
  LChain: TSSLCertificateArray;
  LIssuer: ISSLCertificate;
begin
  Result := nil;

  if not FConnected then
    Exit;

  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_REMOTE_CERT_CONTEXT, @CertContext);

  if IsSuccess(Status) and (CertContext <> nil) then
  begin
    Result := CreateWinSSLCertificateFromContext(CertContext, True);
    if Result = nil then
      Exit;

    LChain := DoGetPeerCertificateChain;
    LIssuer := FindWinSSLIssuerCertificate(Result, LChain);
    if LIssuer <> nil then
      Result.SetIssuerCertificate(LIssuer);
  end;
end;

function TWinSSLConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
var
  CertContext: PCCERT_CONTEXT;
  ChainPara: CERT_CHAIN_PARA;
  ChainContext: PCCERT_CHAIN_CONTEXT;
  Status: SECURITY_STATUS;
  i, j, ChainCount: Integer;
  SimpleChain: PCERT_SIMPLE_CHAIN;
begin
  SetLength(Result, 0);

  if not FConnected then
    Exit;

  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_REMOTE_CERT_CONTEXT, @CertContext);

  if not IsSuccess(Status) or (CertContext = nil) then
    Exit;

  try
    FillChar(ChainPara, SizeOf(ChainPara), 0);
    ChainPara.cbSize := SizeOf(CERT_CHAIN_PARA);

    if CertGetCertificateChain(
      nil,
      CertContext,
      nil,
      nil,
      @ChainPara,
      0,
      nil,
      @ChainContext
    ) then
    begin
      try
        ChainCount := 0;
        for i := 0 to Integer(ChainContext^.cChain) - 1 do
        begin
          SimpleChain := PPCERT_SIMPLE_CHAIN(ChainContext^.rgpChain)[i];
          if SimpleChain <> nil then
            Inc(ChainCount, SimpleChain^.cElement);
        end;

        SetLength(Result, ChainCount);
        ChainCount := 0;

        for i := 0 to Integer(ChainContext^.cChain) - 1 do
        begin
          SimpleChain := PPCERT_SIMPLE_CHAIN(ChainContext^.rgpChain)[i];
          if SimpleChain <> nil then
          begin
            for j := 0 to Integer(SimpleChain^.cElement) - 1 do
            begin
              if PPCERT_CHAIN_ELEMENT(SimpleChain^.rgpElement)[j] <> nil then
              begin
                Result[ChainCount] := CreateWinSSLCertificateFromContext(
                  CertDuplicateCertificateContext(PPCERT_CHAIN_ELEMENT(SimpleChain^.rgpElement)[j]^.pCertContext),
                  True
                );
                Inc(ChainCount);
              end;
            end;
          end;
        end;

        SetLength(Result, ChainCount);
        LinkWinSSLPeerCertificateIssuerLinks(Result);
      finally
        CertFreeCertificateChain(ChainContext);
      end;
    end;
  finally
    CertFreeCertificateContext(CertContext);
  end;
end;

function TWinSSLConnection.DoGetVerifyResult: Integer;
var
  LIsClient: Boolean;
  LVerifyError: Integer;
begin
  if (FHandshakeState = sslHsNotStarted) or (FHandshakeState = sslHsInProgress) then
    Exit(-1);

  if not TryResolvePeerValidationRole(LIsClient) then
    Exit(-1);

  if ValidatePeerCertificate(LIsClient, LVerifyError) then
    Result := 0
  else
    Result := LVerifyError;
end;

function TWinSSLConnection.DoGetVerifyResultString: string;
var
  VerifyResult: Integer;
begin
  if (FHandshakeState = sslHsNotStarted) or (FHandshakeState = sslHsInProgress) then
    Exit('Not verified');

  VerifyResult := DoGetVerifyResult;

  case VerifyResult of
    0: Result := 'OK';
    -1: Result := 'Certificate not available';
    CERT_E_EXPIRED: Result := 'Certificate expired';
    CERT_E_WRONG_USAGE: Result := 'Wrong usage';
    CERT_E_UNTRUSTEDROOT: Result := 'Untrusted root';
    CERT_E_REVOKED: Result := 'Certificate revoked';
    CERT_E_CN_NO_MATCH: Result := 'Common name mismatch';
    CERT_E_INVALID_NAME: Result := 'Invalid name';
    TRUST_E_CERT_SIGNATURE: Result := 'Invalid signature';
  else
    Result := Format('Verification error: 0x%x', [VerifyResult]);
  end;
end;

function TWinSSLConnection.DoGetSession: ISSLSession;
var
  LSession: TWinSSLSession;
  LPeerCert: ISSLCertificate;
  LSessionID: string;
begin
  if FCurrentSession <> nil then
  begin
    Result := FCurrentSession;
    Exit;
  end;

  if not FConnected then
  begin
    Result := nil;
    Exit;
  end;

  LSession := TWinSSLSession.Create;
  UpdateSessionReuseTruthFromContext(LSessionID);
  if LSessionID = '' then
    LSessionID := FormatDateTime('yyyymmddhhnnsszzz', Now);
  LSession.SetSessionMetadata(LSessionID, DoGetProtocolVersion,
    DoGetCipherName, FSessionReused);

  LPeerCert := DoGetPeerCertificate;
  if LPeerCert <> nil then
    LSession.SetPeerCertificate(LPeerCert);

  FCurrentSession := LSession;
  Result := LSession;
end;

procedure TWinSSLConnection.DoSetSession(ASession: ISSLSession);
begin
  // WinSSL currently keeps caller-supplied sessions as compatibility metadata.
  // Shared client reconnects still follow Schannel's automatic cache key
  // (target name + credential handle), not a native session-handle injection path.
  FCurrentSession := ASession;
  FSessionReused := False;
end;

function TWinSSLConnection.DoIsSessionReused: Boolean;
begin
  Result := FSessionReused;
end;

function TWinSSLConnection.DoGetConnectionInfoServerName: string;
begin
  Result := FServerName;
end;

function TWinSSLConnection.DoGetSelectedALPNProtocol: string;
var
  AppProto: TSecPkgContext_ApplicationProtocol;
  Status: SECURITY_STATUS;
begin
  Result := '';

  if not FConnected then
    Exit;

  FillChar(AppProto, SizeOf(AppProto), 0);
  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_APPLICATION_PROTOCOL, @AppProto);

  if IsSuccess(Status) and (AppProto.ProtoNegoStatus = 0) and (AppProto.ProtocolIdSize > 0) then
    SetString(Result, PChar(@AppProto.ProtocolId[0]), AppProto.ProtocolIdSize);
end;

function TWinSSLConnection.DoGetState: string;
begin
  case FHandshakeState of
    sslHsNotStarted: Result := 'not_started';
    sslHsInProgress: Result := 'in_progress';
    sslHsCompleted: Result := 'completed';
    sslHsFailed: Result := 'failed';
    sslHsRenegotiating: Result := 'renegotiating';
  else
    Result := 'unknown';
  end;
end;

function TWinSSLConnection.DoGetNativeHandle: Pointer;
begin
  Result := @FCtxtHandle;
end;

function TWinSSLConnection.GetBackendType: TSSLLibraryType;
begin
  Result := sslWinSSL;
end;

function TWinSSLConnection.IsNativeHandleValid: Boolean;
begin
  Result := (FCtxtHandle.dwLower <> 0) or (FCtxtHandle.dwUpper <> 0);
end;

// ============================================================================
// 握手实现
// ============================================================================

function TWinSSLConnection.PerformHandshake: TSSLHandshakeState;
var
  LIsClient: Boolean;
  LHandshakeOk: Boolean;
  LVerifyError: Integer;
  LFrequency: Int64;
begin
  if FHandshakeState = sslHsCompleted then
    Exit(sslHsCompleted);

  if FHandshakeState = sslHsFailed then
    Exit(sslHsFailed);

  FHandshakeState := sslHsInProgress;
  NotifyInfoCallback(1, 0, 'handshake_start');

  LIsClient := (FContext <> nil) and (FContext.GetContextType = sslCtxClient);
  RememberPeerValidationRole(LIsClient);

  if LIsClient then
    LHandshakeOk := ClientHandshake
  else
    LHandshakeOk := ServerHandshake;

  if not LHandshakeOk then
  begin
    FConnected := False;
    FHandshakeState := sslHsFailed;
    NotifyInfoCallback(2, -1, 'handshake_failed');
    Exit(FHandshakeState);
  end;

  FConnected := True;

  if not ValidatePeerCertificate(LIsClient, LVerifyError) then
  begin
    FConnected := False;
    FHandshakeState := sslHsFailed;
    NotifyInfoCallback(2, LVerifyError, 'verify_failed');
    Exit(FHandshakeState);
  end;

  FHandshakeState := sslHsCompleted;
  QueryPerformanceCounter(FHandshakeEndCounter);
  QueryPerformanceFrequency(LFrequency);
  if LFrequency > 0 then
    FHandshakeDuration := ((FHandshakeEndCounter - FHandshakeStartCounter) * 1000) / LFrequency;
  SaveSessionAfterHandshake;
  TryUpdateLibraryStatistics;
  NotifyInfoCallback(3, 0, 'handshake_done');
  Result := FHandshakeState;
end;

function TWinSSLConnection.ClientHandshake: Boolean;
var
  OutBuffers: array[0..0] of TSecBuffer;
  OutBufferDesc: TSecBufferDesc;
  InBuffers: array[0..1] of TSecBuffer;
  InBufferDesc: TSecBufferDesc;
  Status: SECURITY_STATUS;
  dwSSPIFlags, dwSSPIOutFlags: DWORD;
  ServerName: PWideChar;
  cbData, cbIoBuffer: DWORD;
  IoBuffer: array[0..16384-1] of Byte;
  LALPNBuffer: TBytes;
  LALPNInBuffers: array[0..1] of TSecBuffer;
  LALPNInBufferDesc: TSecBufferDesc;
  LHasALPN: Boolean;
  LFrequency: Int64;
begin
  Result := False;

  QueryPerformanceFrequency(LFrequency);
  QueryPerformanceCounter(FHandshakeStartCounter);

  dwSSPIFlags := ISC_REQ_SEQUENCE_DETECT or
                ISC_REQ_REPLAY_DETECT or
                ISC_REQ_CONFIDENTIALITY or
                ISC_RET_EXTENDED_ERROR or
                ISC_REQ_ALLOCATE_MEMORY or
                ISC_REQ_STREAM;

  ServerName := StringToPWideChar(FServerName);
  try
    LHasALPN := BuildALPNBuffer(FContext.GetALPNProtocols, LALPNBuffer);
    PrepareOutputBufferDesc(OutBuffers, OutBufferDesc);

    if LHasALPN and (Length(LALPNBuffer) > 0) then
    begin
      LALPNInBuffers[0].pvBuffer := @LALPNBuffer[0];
      LALPNInBuffers[0].cbBuffer := Length(LALPNBuffer);
      LALPNInBuffers[0].BufferType := SECBUFFER_APPLICATION_PROTOCOLS;

      LALPNInBuffers[1].pvBuffer := nil;
      LALPNInBuffers[1].cbBuffer := 0;
      LALPNInBuffers[1].BufferType := SECBUFFER_EMPTY;

      LALPNInBufferDesc.cBuffers := 2;
      LALPNInBufferDesc.pBuffers := @LALPNInBuffers[0];
      LALPNInBufferDesc.ulVersion := SECBUFFER_VERSION;

      Status := InitializeSecurityContextW(
        PCredHandle(GetNativeHandleSafe(FContext, 'TWinSSLConnection.ClientHandshake')),
        nil,
        ServerName,
        dwSSPIFlags,
        0,
        0,
        @LALPNInBufferDesc,
        0,
        @FCtxtHandle,
        @OutBufferDesc,
        @dwSSPIOutFlags,
        nil
      );
    end
    else
    begin
      Status := InitializeSecurityContextW(
        PCredHandle(GetNativeHandleSafe(FContext, 'TWinSSLConnection.ClientHandshake')),
        nil,
        ServerName,
        dwSSPIFlags,
        0,
        0,
        nil,
        0,
        @FCtxtHandle,
        @OutBufferDesc,
        @dwSSPIOutFlags,
        nil
      );
    end;

    if not ((Status = SEC_I_CONTINUE_NEEDED) or IsSuccess(Status)) then
    begin
      FLastError := MapSchannelError(Status);
      NotifyInfoCallback(2, Integer(Status),
        Format('Client handshake initialization failed: %s (0x%x)',
          [GetSchannelErrorMessageEN(Status), Status]));

      case Status of
        SEC_E_UNSUPPORTED_FUNCTION:
          raise ESSLConfigurationException.CreateWithContext(
            GetSchannelErrorMessageEN(Status),
            sslErrConfiguration,
            'TWinSSLConnection.ClientHandshake',
            Status,
            sslWinSSL
          );
      else
        raise ESSLHandshakeException.CreateWithContext(
          Format('Client handshake initialization failed: %s', [GetSchannelErrorMessageEN(Status)]),
          sslErrHandshake,
          'TWinSSLConnection.ClientHandshake',
          Status,
          sslWinSSL
        );
      end;
    end;

    if not SendOutputBuffer(OutBuffers[0]) then
      Exit;

    cbIoBuffer := 0;
    while (Status = SEC_I_CONTINUE_NEEDED) or (Status = SEC_E_INCOMPLETE_MESSAGE) do
    begin
      if (cbIoBuffer = 0) or (Status = SEC_E_INCOMPLETE_MESSAGE) then
      begin
        cbData := RecvData(IoBuffer[cbIoBuffer], SizeOf(IoBuffer) - cbIoBuffer);
        if cbData <= 0 then
          Exit;
        Inc(cbIoBuffer, cbData);
      end;

      PrepareInputBufferDesc(InBuffers, InBufferDesc, @IoBuffer[0], cbIoBuffer);
      PrepareOutputBufferDesc(OutBuffers, OutBufferDesc);

      Status := InitializeSecurityContextW(
        PCredHandle(GetNativeHandleSafe(FContext, 'TWinSSLConnection.ClientHandshake')),
        @FCtxtHandle,
        ServerName,
        dwSSPIFlags,
        0,
        0,
        @InBufferDesc,
        0,
        nil,
        @OutBufferDesc,
        @dwSSPIOutFlags,
        nil
      );

      HandleExtraData(InBuffers, IoBuffer, cbIoBuffer, Status);

      if not SendOutputBuffer(OutBuffers[0]) then
        Exit;

      if Status = SEC_E_INCOMPLETE_MESSAGE then
        Continue;
      if not ((Status = SEC_I_CONTINUE_NEEDED) or IsSuccess(Status)) then
      begin
        FLastError := MapSchannelError(Status);
        NotifyInfoCallback(2, Integer(Status),
          Format('Client handshake failed: %s (0x%x)',
            [GetSchannelErrorMessageEN(Status), Status]));

        case Status of
          SEC_E_CERT_EXPIRED,
          CERT_E_EXPIRED:
            raise ESSLCertificateException.CreateWithContext(
              GetSchannelErrorMessageEN(Status),
              sslErrCertificate,
              'TWinSSLConnection.ClientHandshake',
              Status,
              sslWinSSL
            );

          SEC_E_UNTRUSTED_ROOT,
          CERT_E_UNTRUSTEDROOT:
            raise ESSLCertificateException.CreateWithContext(
              GetSchannelErrorMessageEN(Status),
              sslErrCertificateUntrusted,
              'TWinSSLConnection.ClientHandshake',
              Status,
              sslWinSSL
            );

          SEC_E_ALGORITHM_MISMATCH:
            raise ESSLHandshakeException.CreateWithContext(
              GetSchannelErrorMessageEN(Status),
              sslErrHandshake,
              'TWinSSLConnection.ClientHandshake',
              Status,
              sslWinSSL
            );

          SEC_E_INVALID_TOKEN:
            raise ESSLProtocolException.CreateWithContext(
              GetSchannelErrorMessageEN(Status),
              sslErrProtocol,
              'TWinSSLConnection.ClientHandshake',
              Status,
              sslWinSSL
            );

        else
          raise ESSLHandshakeException.CreateWithContext(
            Format('Client handshake failed: %s', [GetSchannelErrorMessageEN(Status)]),
            sslErrHandshake,
            'TWinSSLConnection.ClientHandshake',
            Status,
            sslWinSSL
          );
        end;
      end;
    end;

    Result := IsSuccess(Status);

  finally
    if ServerName <> nil then
      FreePWideCharString(ServerName);
  end;
end;

function TWinSSLConnection.ServerHandshake: Boolean;
var
  OutBuffers: array[0..0] of TSecBuffer;
  OutBufferDesc: TSecBufferDesc;
  InBuffers: array[0..1] of TSecBuffer;
  InBufferDesc: TSecBufferDesc;
  Status: SECURITY_STATUS;
  dwSSPIFlags, dwSSPIOutFlags: DWORD;
  cbData, cbIoBuffer: DWORD;
  IoBuffer: array[0..16384-1] of Byte;
  fDoRead: Boolean;
  phContext: PCtxtHandle;
  LFrequency: Int64;
begin
  Result := False;

  QueryPerformanceFrequency(LFrequency);
  QueryPerformanceCounter(FHandshakeStartCounter);

  dwSSPIFlags := ASC_REQ_SEQUENCE_DETECT or
                ASC_REQ_REPLAY_DETECT or
                ASC_REQ_CONFIDENTIALITY or
                ASC_RET_EXTENDED_ERROR or
                ASC_REQ_ALLOCATE_MEMORY or
                ASC_REQ_STREAM;

  if sslVerifyPeer in FContext.GetVerifyMode then
    dwSSPIFlags := dwSSPIFlags or ASC_REQ_MUTUAL_AUTH;

  FHandshakeState := sslHsInProgress;
  cbIoBuffer := 0;
  fDoRead := True;
  phContext := nil;

  while True do
  begin
    if fDoRead then
    begin
      cbData := RecvData(IoBuffer[cbIoBuffer], SizeOf(IoBuffer) - cbIoBuffer);
      if cbData <= 0 then
      begin
        FLastError := sslErrConnection;
        Exit;
      end;
      Inc(cbIoBuffer, cbData);
    end
    else
      fDoRead := True;

    PrepareInputBufferDesc(InBuffers, InBufferDesc, @IoBuffer[0], cbIoBuffer);
    PrepareOutputBufferDesc(OutBuffers, OutBufferDesc);

    Status := AcceptSecurityContext(
      PCredHandle(GetNativeHandleSafe(FContext, 'TWinSSLConnection.ServerHandshake')),
      phContext,
      @InBufferDesc,
      dwSSPIFlags,
      SECURITY_NATIVE_DREP,
      @FCtxtHandle,
      @OutBufferDesc,
      @dwSSPIOutFlags,
      nil
    );

    if phContext = nil then
      phContext := @FCtxtHandle;

    HandleExtraData(InBuffers, IoBuffer, cbIoBuffer, Status);

    if (OutBuffers[0].cbBuffer > 0) and (OutBuffers[0].pvBuffer <> nil) then
    begin
      if not SendOutputBuffer(OutBuffers[0]) then
      begin
        FLastError := sslErrConnection;
        Exit;
      end;
    end;

    case Status of
      SEC_E_OK:
      begin
        Result := True;
        FHandshakeState := sslHsCompleted;

        QueryPerformanceCounter(FHandshakeEndCounter);
        if LFrequency > 0 then
          FHandshakeDuration := ((FHandshakeEndCounter - FHandshakeStartCounter) * 1000) / LFrequency;

        Break;
      end;

      SEC_I_CONTINUE_NEEDED:
        Continue;

      SEC_E_INCOMPLETE_MESSAGE:
      begin
        fDoRead := True;
        Continue;
      end;

      SEC_I_INCOMPLETE_CREDENTIALS:
        Continue;

    else
      FHandshakeState := sslHsFailed;
      FLastError := MapSchannelError(Status);

      NotifyInfoCallback(2, Integer(Status),
        Format('Server handshake failed: %s (0x%x)',
          [GetSchannelErrorMessageEN(Status), Status]));

      if IsValidSecHandle(FCtxtHandle) then
      begin
        try
          DeleteSecurityContext(@FCtxtHandle);
          InitSecHandle(FCtxtHandle);
        except
        end;
      end;

      case Status of
        SEC_E_UNSUPPORTED_FUNCTION:
          raise ESSLConfigurationException.CreateWithContext(
            GetSchannelErrorMessageEN(Status),
            sslErrConfiguration,
            'TWinSSLConnection.ServerHandshake',
            Status,
            sslWinSSL
          );

        SEC_E_CERT_EXPIRED,
        CERT_E_EXPIRED:
          raise ESSLCertificateException.CreateWithContext(
            GetSchannelErrorMessageEN(Status),
            sslErrCertificate,
            'TWinSSLConnection.ServerHandshake',
            Status,
            sslWinSSL
          );

        SEC_E_UNTRUSTED_ROOT,
        CERT_E_UNTRUSTEDROOT,
        SEC_E_CERT_UNKNOWN:
          raise ESSLCertificateException.CreateWithContext(
            GetSchannelErrorMessageEN(Status),
            sslErrCertificateUntrusted,
            'TWinSSLConnection.ServerHandshake',
            Status,
            sslWinSSL
          );

        SEC_E_ALGORITHM_MISMATCH:
          raise ESSLHandshakeException.CreateWithContext(
            GetSchannelErrorMessageEN(Status),
            sslErrHandshake,
            'TWinSSLConnection.ServerHandshake',
            Status,
            sslWinSSL
          );

        SEC_E_INVALID_TOKEN:
          raise ESSLProtocolException.CreateWithContext(
            GetSchannelErrorMessageEN(Status),
            sslErrProtocol,
            'TWinSSLConnection.ServerHandshake',
            Status,
            sslWinSSL
          );

        SEC_E_MESSAGE_ALTERED:
          raise ESSLProtocolException.CreateWithContext(
            GetSchannelErrorMessageEN(Status),
            sslErrProtocol,
            'TWinSSLConnection.ServerHandshake',
            Status,
            sslWinSSL
          );

      else
        raise ESSLHandshakeException.CreateWithContext(
          Format('Server handshake failed: %s', [GetSchannelErrorMessageEN(Status)]),
          sslErrHandshake,
          'TWinSSLConnection.ServerHandshake',
          Status,
          sslWinSSL
        );
      end;
    end;
  end;
end;

// ============================================================================
// 覆盖基类方法
// ============================================================================

function TWinSSLConnection.GetConnectionInfo: TSSLConnectionInfo;
var
  ConnInfo: TSecPkgContext_ConnectionInfo;
  CipherSuiteId: Word;
  CipherSuiteName: string;
  Status: SECURITY_STATUS;
begin
  Result := inherited GetConnectionInfo;
  Result.CompressionMethod := 'none';

  if not FConnected then
    Exit;

  Status := QueryContextAttributesW(@FCtxtHandle, SECPKG_ATTR_CONNECTION_INFO, @ConnInfo);
  if IsSuccess(Status) then
  begin
    Result.KeySize := ConnInfo.dwCipherStrength;
    if (Result.MacSize = 0) and (ConnInfo.dwHashStrength > 0) then
      Result.MacSize := ConnInfo.dwHashStrength div 8;

    case ConnInfo.aiExch of
      CALG_RSA_KEYX, CALG_RSA_SIGN:
        Result.KeyExchange := sslKexRSA;
      CALG_DH_EPHEM:
        Result.KeyExchange := sslKexDHE_RSA;
    else
      Result.KeyExchange := sslKexRSA;
    end;

    case ConnInfo.aiCipher of
      CALG_AES_128: Result.Cipher := sslCipherAES128;
      CALG_AES_256: Result.Cipher := sslCipherAES256;
      CALG_3DES:    Result.Cipher := sslCipher3DES;
      CALG_DES:     Result.Cipher := sslCipherDES;
      CALG_RC4:     Result.Cipher := sslCipherRC4;
    else
      Result.Cipher := sslCipherNone;
    end;

    case ConnInfo.aiHash of
      CALG_MD5:     Result.Hash := sslHashMD5;
      CALG_SHA1:    Result.Hash := sslHashSHA1;
      CALG_SHA_256: Result.Hash := sslHashSHA256;
      CALG_SHA_384: Result.Hash := sslHashSHA384;
      CALG_SHA_512: Result.Hash := sslHashSHA512;
    else
      Result.Hash := sslHashSHA256;
    end;
  end;

  if TryGetCipherInfo(CipherSuiteId, CipherSuiteName) then
  begin
    if CipherSuiteId <> 0 then
      Result.CipherSuiteId := CipherSuiteId;
    if CipherSuiteName <> '' then
      Result.CipherSuite := CipherSuiteName;
  end;

  Result.IsResumed := FSessionReused;
  Result.CompressionMethod := 'none';
  Result.ServerName := FServerName;
  Result.ALPNProtocol := DoGetSelectedALPNProtocol;
end;

end.

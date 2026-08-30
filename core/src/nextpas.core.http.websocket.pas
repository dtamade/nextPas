unit nextpas.core.http.websocket;
{**
 * @desc WebSocket (RFC 6455) server-side implementation.
 *       Provides upgrade handshake and frame-level read/write.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.ws.session;

type
  { Callback to validate WebSocket Origin header during upgrade.
    Return True to accept, False to reject with 403.
    AOrigin is the raw Origin header value (empty if absent). }
  TWebSocketOriginCheck = function(const AOrigin: string): Boolean;

  { Extra header to send in the client upgrade request (e.g. Cookie for
    session auth). Name/Value must not contain CR/LF. }
  TWebSocketHeader = record
    Name: string;
    Value: string;
  end;

  TWebSocketOptions = record
    MaxFrameSize: Int64;
    MaxMessageSize: Int64;
    { If set, called during upgrade to validate the Origin header.
      When nil, all origins are accepted (no validation). }
    OnCheckOrigin: TWebSocketOriginCheck;
    { OS dial budget in ms (TcpConnect timeout). >0 bounds dial;
      0 = unbounded dial. Default Production discipline: 30000. }
    ConnectTimeout: Int64;
    { Handshake I/O deadline after dial (ms). >0 applies read/write
      deadline for upgrade request/response; 0 = unbounded handshake I/O.
      Default Production discipline: 30000. }
    Timeout: Int64;
    { 服务端阻塞写超时（ms）：>0 时每次写前设写 deadline、写后清除——
      单次写独立超时；慢客户端填满 OS 发送缓冲时写抛超时错（调用方可按
      死连接剔除）。0 = 不超时（默认，向后兼容）。 }
    WriteTimeoutMs: Int64;
    { Optional cooperative cancel for dial/handshake and mid-frame I/O.
      When HasCancelToken, stream SetCancelToken enables waitable cancel wake
      (same residual as HTTP client). Default: unset. }
    CancelToken: IHttpCancelToken;
    HasCancelToken: Boolean;
    { RFC 7692 permessage-deflate. Default False (opt-in). When True, offer/
      accept extension with client_no_context_takeover and
      server_no_context_takeover (no shared LZ77 context across messages). }
    EnablePermessageDeflate: Boolean;
    { Extra headers to send in the client upgrade request (order preserved).
      Default: none. }
    Headers: array of TWebSocketHeader;
    class function Default: TWebSocketOptions; static;
    function WithConnectTimeout(const ATimeoutMs: Int64): TWebSocketOptions;
    function WithTimeout(const ATimeoutMs: Int64): TWebSocketOptions;
    function WithWriteTimeout(const ATimeoutMs: Int64): TWebSocketOptions;
    function WithCancelToken(const AToken: IHttpCancelToken): TWebSocketOptions;
    function WithEnablePermessageDeflate(
      const AEnable: Boolean): TWebSocketOptions;
    { Append an extra header to the upgrade request (e.g. Cookie for auth).
      CR/LF in name or value are rejected by ValidateWebSocketOptions. }
    function WithHeader(const AName, AValue: string): TWebSocketOptions;
    function EffectiveCancelToken: IHttpCancelToken;
  end;

  TWebSocketOpcode = (
    wsOpContinuation = 0,
    wsOpText = 1,
    wsOpBinary = 2,
    wsOpClose = 8,
    wsOpPing = 9,
    wsOpPong = 10
  );

  TWebSocketFrame = record
    Fin: Boolean;
    Opcode: TWebSocketOpcode;
    Payload: TBytes;
  end;

  IWebSocket = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-600000000001}']
    function ReadFrame: TWebSocketFrame;
    { Read a complete message, handling continuation frames automatically.
      Auto-responds to Ping frames with Pong (per RFC 6455).
      Returns the aggregated message (text or binary).
      Raises EHttpError on protocol errors or connection close. }
    function ReadMessage: TWebSocketFrame;
    procedure WriteText(const AData: string);
    procedure WriteBinary(const AData: TBytes);
    procedure Ping(const AData: TBytes);
    procedure Pong(const AData: TBytes);
    procedure Close(const ACode: UInt16; const AReason: string);
    function IsOpen: Boolean;
  end;

const
  WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = Int64(16777216);
  WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = Int64(67108864);

{ Upgrade an HTTP connection to WebSocket.
  Validates Upgrade headers, sends 101 response, returns IWebSocket.
  The response writer must support IHttpHijacker to obtain the raw connection.
  Raises EHttpError if upgrade fails. }
function UpgradeWebSocket(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter): IWebSocket; overload;
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const AOptions: TWebSocketOptions): IWebSocket; overload;

{ 非阻塞 WebSocket 升级（B8 第二片）：完成 HTTP 握手（校验头、发 101），
  把连接交给事件驱动的 TNetWsFrameSession 并接入 net/server 的 poll reactor
  （经 IHttpConnContext.HostSessionContext → HandoffHijackedConn 迁移；
  调用线程可为 worker 或 reactor，迁移在 reactor 线程执行）。
  与阻塞路径的差异（有意为之）：
  - 101 响应不带 permessage-deflate 扩展头：非阻塞路径暂不协商 deflate，
    客户端使用 RSV1 即按协议错误 1002 处理（扩展未被确认不得使用）；
  - 返回 IWebSocketFrameSession（事件驱动）而非阻塞 IWebSocket。
  要求：AW 支持 IHttpHijacker + IHttpConnContext 且服务器为事件驱动
  （prefer-poll）后端，否则 EHttpError。 }
function UpgradeWebSocketHandoff(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const ASink: IWebSocketFrameSink;
  const AOptions: TNetWsFrameSessionOptions): IWebSocketFrameSession;

{ 同上（F-10）：ACheckOrigin 非空时升级握手按回调裁决 Origin（拒绝抛
  EHttpError），替代缺省「必须存在且非 null」检查——服务端 Origin 白名单
  等部署面策略由此在 core 握手层执行；nil 等价四参版本。 }
function UpgradeWebSocketHandoff(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const ASink: IWebSocketFrameSink;
  const AOptions: TNetWsFrameSessionOptions;
  const ACheckOrigin: TWebSocketOriginCheck): IWebSocketFrameSession; overload;

{ Connect to a WebSocket server.
  Establishes TCP connection, performs client handshake, returns IWebSocket.
  Supports ws:// and wss:// schemes.
  Raises EHttpError if connection or handshake fails. }
function ConnectWebSocket(const AUrl: string): IWebSocket; overload;
function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket; overload;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.base.utils,
  nextpas.core.bytes,
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.hash,
  nextpas.core.hash.base,
  nextpas.core.encoding,
  nextpas.core.text.conv,
  nextpas.core.text.utf8,
  nextpas.core.websocket.base,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.io.util,
  nextpas.core.sync,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.http.url,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.client,
  nextpas.core.http.impl.cancel.adapter,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.random,
  nextpas.core.compress.deflate;

{ 公共握手：校验头 → hijack → 101。供 UpgradeWebSocket 与
  UpgradeWebSocketHandoff（非阻塞）共用；见下实现。
  AInstallShutdownNotifier：服务端阻塞路径为 True——在 101 写出前创建并
  登记 shutdown 通知器（注册 happens-before 客户端观察到 101，B7 G1 竞态）；
  非阻塞 handoff 路径为 False（事件驱动会话无人 Detach，不登记）。
  ANotifier 输出已登记的通知器（AInstallShutdownNotifier=False 时为 nil）。 }
procedure PerformUpgradeHandshake(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const AOptions: TWebSocketOptions;
  const AOfferDeflate: Boolean; const AInstallShutdownNotifier: Boolean;
  out AConn: ITcpStream; out ADeflate: Boolean;
  out ANotifier: IWsServerShutdownNotifier); forward;

type
  { 服务端阻塞 WS 会话的 shutdown 通知器（每会话一个，TWebSocketImpl 持有）。
    注册表持强引用；Detach 后摘除登记、释放流引用并唤醒 WaitFinished 等待者。
    NotifyShutdown 用 waitable cancel token 唤醒连接线程（mid-poll 设置读
    deadline 无效——poll 在旧的无限超时上继续阻塞）；close frame 1001 由
    会话 Destroy 收尾路径补发（单写者，无跨线程写竞态）。 }
  TWsServerShutdownNotifier = class(TInterfacedObject,
    IWsServerShutdownNotifier)
  private
    FRegistry: IWsServerShutdownRegistry;
    FStream: ITcpStream;
    FDone: IEvent;
    FCancel: INetCancelController;
    FDetached: LongInt;
  public
    constructor Create(const ARegistry: IWsServerShutdownRegistry;
      const AStream: ITcpStream; const AInstallWake: Boolean);
    destructor Destroy; override;
    procedure Detach;
    procedure NotifyShutdown;
    function WaitFinished(const ATimeoutNs: Int64): Boolean;
    procedure ForceClose;
  end;

  TWebSocketImpl = class(TInterfacedObject, IWebSocket)
  private
    FReader: IReader;
    FWriter: IWriter;
    FStream: ITcpStream;
    FOpen: Boolean;
    FCloseReceived: Boolean;
    FCloseSent: Boolean;
    FFragmentOpen: Boolean;
    FFragmentOpcode: TWebSocketOpcode;
    FFragmentPayloadSize: UInt64;
    FFragmentBinaryPayload: TBytes;
    FFragmentCompressed: Boolean;
    FOptions: TWebSocketOptions;
    FIsClient: Boolean;
    FDeflateEnabled: Boolean;
    FShutdownNotifier: IWsServerShutdownNotifier;
    procedure WriteFrame(AOpcode: TWebSocketOpcode; const APayload: TBytes;
      const ARsv1: Boolean = False);
    procedure WriteFrameRaw(AOpcode: TWebSocketOpcode; const APayload: TBytes;
      const ARsv1: Boolean = False);
    procedure WriteAll(const ABuf; ACount: SizeUInt);
    procedure WriteDataMessage(AOpcode: TWebSocketOpcode; const APayload: TBytes);
    function MaybeDecompressPayload(const ACompressed: Boolean;
      const APayload: TBytes): TBytes;
    procedure ReadExact(var ABuf; ACount: SizeUInt);
    procedure ThrowIfCanceled;
    procedure ClearStreamCancel;
  public
    constructor Create(const AReader: IReader; const AWriter: IWriter;
      const AOptions: TWebSocketOptions; AIsClient: Boolean = False;
      const AStream: ITcpStream = nil;
      const ADeflateEnabled: Boolean = False;
      const AShutdownNotifier: IWsServerShutdownNotifier = nil);
    destructor Destroy; override;
    function ReadFrame: TWebSocketFrame;
    function ReadMessage: TWebSocketFrame;
    procedure WriteText(const AData: string);
    procedure WriteBinary(const AData: TBytes);
    procedure Ping(const AData: TBytes);
    procedure Pong(const AData: TBytes);
    procedure Close(const ACode: UInt16; const AReason: string);
    function IsOpen: Boolean;
  end;

{ Helpers }



class function TWebSocketOptions.Default: TWebSocketOptions;
begin
  Result.MaxFrameSize := WEBSOCKET_DEFAULT_MAX_FRAME_SIZE;
  Result.MaxMessageSize := WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE;
  Result.OnCheckOrigin := nil;
  { Match HTTP client production discipline: bounded dial + handshake. }
  Result.ConnectTimeout := 30000;
  Result.Timeout := 30000;
  Result.WriteTimeoutMs := 0;
  Result.CancelToken := nil;
  Result.HasCancelToken := False;
  Result.EnablePermessageDeflate := False;
end;

function TWebSocketOptions.WithConnectTimeout(
  const ATimeoutMs: Int64): TWebSocketOptions;
begin
  Result := Self;
  Result.ConnectTimeout := ATimeoutMs;
end;

function TWebSocketOptions.WithTimeout(const ATimeoutMs: Int64): TWebSocketOptions;
begin
  Result := Self;
  Result.Timeout := ATimeoutMs;
end;

function TWebSocketOptions.WithWriteTimeout(
  const ATimeoutMs: Int64): TWebSocketOptions;
begin
  Result := Self;
  Result.WriteTimeoutMs := ATimeoutMs;
end;

function TWebSocketOptions.WithCancelToken(
  const AToken: IHttpCancelToken): TWebSocketOptions;
begin
  Result := Self;
  Result.CancelToken := AToken;
  Result.HasCancelToken := True;
end;

function TWebSocketOptions.WithEnablePermessageDeflate(
  const AEnable: Boolean): TWebSocketOptions;
begin
  Result := Self;
  Result.EnablePermessageDeflate := AEnable;
end;

function TWebSocketOptions.WithHeader(const AName, AValue: string): TWebSocketOptions;
var
  N: Integer;
begin
  Result := Self;
  N := Length(Result.Headers);
  SetLength(Result.Headers, N + 1);
  Result.Headers[N].Name := AName;
  Result.Headers[N].Value := AValue;
end;

function TWebSocketOptions.EffectiveCancelToken: IHttpCancelToken;
begin
  if HasCancelToken then
    Result := CancelToken
  else
    Result := nil;
end;

procedure ValidateWebSocketOptions(const AOptions: TWebSocketOptions);
var
  I: Integer;
begin
  if AOptions.MaxFrameSize < 0 then
    raise EHttpError.Create(hekArgument, 'WebSocket max frame size must not be negative');
  if AOptions.MaxMessageSize < 0 then
    raise EHttpError.Create(hekArgument, 'WebSocket max message size must not be negative');
  if AOptions.ConnectTimeout < 0 then
    raise EHttpError.Create(hekArgument,
      'WebSocket ConnectTimeout must not be negative');
  if AOptions.Timeout < 0 then
    raise EHttpError.Create(hekArgument,
      'WebSocket Timeout must not be negative');
  if AOptions.WriteTimeoutMs < 0 then
    raise EHttpError.Create(hekArgument,
      'WebSocket WriteTimeoutMs must not be negative');
  { 额外请求头不得含 CR/LF（防注入升级请求行/头区）。 }
  for I := 0 to High(AOptions.Headers) do
  begin
    if (Pos(#13, AOptions.Headers[I].Name) > 0) or
       (Pos(#10, AOptions.Headers[I].Name) > 0) or
       (Pos(#13, AOptions.Headers[I].Value) > 0) or
       (Pos(#10, AOptions.Headers[I].Value) > 0) then
      raise EHttpError.Create(hekArgument,
        'WebSocket extra header must not contain CR/LF');
    if AOptions.Headers[I].Name = '' then
      raise EHttpError.Create(hekArgument,
        'WebSocket extra header name must not be empty');
  end;
end;

{ ConnectTimeout>0 wins for OS dial; else Timeout; 0 = unbounded. }
function WebSocketEffectiveDialTimeoutMs(
  const AOptions: TWebSocketOptions): Int64;
begin
  if AOptions.ConnectTimeout > 0 then
    Result := AOptions.ConnectTimeout
  else
    Result := AOptions.Timeout;
end;

procedure ApplyWebSocketStreamDeadline(const AConn: ITcpStream;
  const ATimeoutMs: Int64);
var
  LDeadline: TDeadline;
begin
  if (AConn = nil) or (ATimeoutMs <= 0) then
    Exit;
  LDeadline := TDeadline.After(TDuration.FromMilliseconds(ATimeoutMs));
  AConn.SetReadDeadline(LDeadline);
  AConn.SetWriteDeadline(LDeadline);
end;

procedure ClearWebSocketStreamDeadline(const AConn: ITcpStream);
begin
  if AConn = nil then
    Exit;
  AConn.SetReadDeadline(TDeadline.Infinite);
  AConn.SetWriteDeadline(TDeadline.Infinite);
end;

procedure ApplyWebSocketCancelToken(const AConn: ITcpStream;
  const AToken: IHttpCancelToken);
begin
  ApplyHttpCancelToken(AConn, AToken);
end;

procedure ClearWebSocketCancelToken(const AConn: ITcpStream);
begin
  if AConn = nil then
    Exit;
  AConn.SetCancelToken(nil);
end;

procedure RaiseWebSocketTransport(const E: Exception);
var
  LWrapped: Exception;
begin
  LWrapped := HttpWrapTransportException(E);
  if LWrapped <> nil then
    raise LWrapped;
  if E = nil then
    raise EHttpError.CreateOp(hekConnect, 'websocket', 'WebSocket transport failure');
  raise EHttpError.CreateOp(hekConnect, 'websocket', 'WebSocket: ' + E.Message);
end;

function IsOWS(const ACh: Char): Boolean;
begin
  Result := (ACh = ' ') or (ACh = #9);
end;

function TrimOWS(const S: string): string;
var
  LFirst, LLast: Integer;
begin
  LFirst := 1;
  LLast := Length(S);
  while (LFirst <= LLast) and IsOWS(S[LFirst]) do
    Inc(LFirst);
  while (LLast >= LFirst) and IsOWS(S[LLast]) do
    Dec(LLast);
  if LFirst > LLast then
    Exit('');
  Result := Copy(S, LFirst, LLast - LFirst + 1);
end;

function LowerTrimOWS(const S: string): string;
var
  LFirst, LLast: Integer;
begin
  LFirst := 1;
  LLast := Length(S);
  while (LFirst <= LLast) and IsOWS(S[LFirst]) do
    Inc(LFirst);
  while (LLast >= LFirst) and IsOWS(S[LLast]) do
    Dec(LLast);
  if LFirst > LLast then
    Exit('');
  Result := LowerCase(Copy(S, LFirst, LLast - LFirst + 1));
end;

function HeaderValueHasToken(const AValue, AToken: string): Boolean;
var
  LStart, LPos: Integer;
begin
  Result := False;
  LStart := 1;
  while LStart <= Length(AValue) + 1 do
  begin
    LPos := LStart;
    while (LPos <= Length(AValue)) and (AValue[LPos] <> ',') do
      Inc(LPos);
    if LowerTrimOWS(Copy(AValue, LStart, LPos - LStart)) = AToken then
      Exit(True);
    LStart := LPos + 1;
  end;
end;

function HeaderValuesHaveToken(const AValues: TStringArray;
  const AToken: string): Boolean;
var
  LI: SizeInt;
begin
  Result := False;
  for LI := Low(AValues) to High(AValues) do
    if HeaderValueHasToken(AValues[LI], AToken) then
      Exit(True);
end;

const
  { RFC 7692: always negotiate no context takeover (fresh LZ77 per message). }
  WS_PMD_EXTENSION_VALUE =
    'permessage-deflate; client_no_context_takeover; server_no_context_takeover';

function ExtensionOfferIsPermessageDeflate(const AOffer: string): Boolean;
var
  LName: string;
  LSemi: Integer;
begin
  LSemi := Pos(';', AOffer);
  if LSemi > 0 then
    LName := LowerTrimOWS(Copy(AOffer, 1, LSemi - 1))
  else
    LName := LowerTrimOWS(AOffer);
  Result := LName = 'permessage-deflate';
end;

function HeaderOffersPermessageDeflate(const AHeader: string): Boolean;
var
  LStart, LPos: Integer;
begin
  Result := False;
  if AHeader = '' then
    Exit;
  LStart := 1;
  while LStart <= Length(AHeader) + 1 do
  begin
    LPos := LStart;
    while (LPos <= Length(AHeader)) and (AHeader[LPos] <> ',') do
      Inc(LPos);
    if ExtensionOfferIsPermessageDeflate(Copy(AHeader, LStart, LPos - LStart)) then
      Exit(True);
    LStart := LPos + 1;
  end;
end;

function HeadersOfferPermessageDeflate(const AValues: TStringArray): Boolean;
var
  LI: SizeInt;
begin
  Result := False;
  for LI := Low(AValues) to High(AValues) do
    if HeaderOffersPermessageDeflate(AValues[LI]) then
      Exit(True);
end;

function Sha1DigestToBytes(const ADigest: TSHA1Digest): TBytes;
var
  I: SizeInt;
begin
  Result := nil;
  SetLength(Result, Length(ADigest));
  for I := 0 to High(ADigest) do
    Result[I] := ADigest[I];
end;

function ComputeAcceptKey(const AKey: string): string;
var
  LConcat: string;
begin
  LConcat := AKey + WS_GUID;
  Result := Base64Encode(Sha1DigestToBytes(
    SHA1Of(LConcat[1], SizeUInt(Length(LConcat)))));
end;

procedure ValidateHandshakeKey(const AKey: string);
var
  LDecoded: TBytes;
begin
  try
    LDecoded := Base64Decode(AKey);
  except
    on E: EConvertError do
      raise EHttpError.Create(hekUpgrade, 'Invalid Sec-WebSocket-Key header');
  end;

  if Length(LDecoded) <> 16 then
    raise EHttpError.Create(hekUpgrade, 'Invalid Sec-WebSocket-Key header');
end;

function IsValidOpcode(const AOpcode: Byte): Boolean;
begin
  case AOpcode of
    $0, $1, $2, $8, $9, $A:
      Result := True;
  else
    Result := False;
  end;
end;

function IsValidCloseCode(const ACode: UInt16): Boolean;
begin
  Result :=
    (ACode >= 1000) and
    (ACode < 5000) and
    (ACode <> 1004) and
    (ACode <> 1005) and
    (ACode <> 1006) and
    (ACode <> 1015);
end;

procedure ValidateClosePayload(const APayload: TBytes);
var
  LCode: UInt16;
begin
  if Length(APayload) = 0 then
    Exit;
  if Length(APayload) = 1 then
    raise EHttpError.Create(hekProtocol, 'WebSocket: invalid close frame payload');

  LCode := (UInt16(APayload[0]) shl 8) or UInt16(APayload[1]);
  if not IsValidCloseCode(LCode) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: invalid close code');
  if (Length(APayload) > 2) and
     (not UTF8IsValid(@APayload[2], SizeUInt(Length(APayload) - 2))) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: invalid close reason encoding');
end;

procedure ValidateTextPayload(const APayload: string);
begin
  if Length(APayload) = 0 then
    Exit;
  if not UTF8IsValid(PByte(@APayload[1]), SizeUInt(Length(APayload))) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: invalid text payload encoding');
end;

function SizeExceedsLimit(const ASize: UInt64; const ALimit: Int64): Boolean;
begin
  Result := (ALimit > 0) and (ASize > UInt64(ALimit));
end;

function CombinedSizeExceedsLimit(const ACurrent, AAdd: UInt64;
  const ALimit: Int64): Boolean;
begin
  if ALimit <= 0 then
    Exit(False);
  if AAdd > UInt64(ALimit) then
    Exit(True);
  if ACurrent > UInt64(ALimit) - AAdd then
    Exit(True);
  Result := False;
end;

procedure ValidateControlPayloadSize(const APayload: TBytes);
begin
  if Length(APayload) > 125 then
    raise EHttpError.Create(hekProtocol, 'WebSocket: control frame payload too large');
end;

{ UpgradeWebSocket }

function UpgradeWebSocket(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter): IWebSocket;
begin
  Result := UpgradeWebSocket(AReq, AW, TWebSocketOptions.Default);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter;
  const AOptions: TWebSocketOptions): IWebSocket;
var
  LConn: ITcpStream;
  LDeflate: Boolean;
  LNotifier: IWsServerShutdownNotifier;
begin
  LConn := nil;
  LDeflate := False;
  LNotifier := nil;
  { shutdown 通知器在握手路径登记（先于 101 写出，B7 G1 竞态修复）；
    找不到注册表则静默降级（自定义 transport / 非 threaded 后端——
    收尾 close frame 语义仍在 G2，shutdown 唤醒缺失但连接仍会关闭）。 }
  PerformUpgradeHandshake(AReq, AW, AOptions, AOptions.EnablePermessageDeflate,
    True, LConn, LDeflate, LNotifier);
  Result := TWebSocketImpl.Create(LConn as IReader, LConn as IWriter, AOptions,
    False, LConn, LDeflate, LNotifier);
end;

{ 公共握手：校验头 → hijack → 101（AOfferDeflate 决定是否回扩展头）。
  AInstallShutdownNotifier=True 时在 101 写出前登记 shutdown 通知器（注册
  happens-before 客户端观察到 101：客户端看到 101 即可触发 Shutdown，登记
  若在其后完成 ShutdownAll 会看到空注册表——B7 G1 竞态）。
  所有权：成功返回后 AConn 由调用方持有（阻塞路径 → TWebSocketImpl；
  非阻塞路径 → TNetWsFrameSession + poll target）。失败抛 EHttpError。 }
procedure PerformUpgradeHandshake(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const AOptions: TWebSocketOptions;
  const AOfferDeflate: Boolean; const AInstallShutdownNotifier: Boolean;
  out AConn: ITcpStream; out ADeflate: Boolean;
  out ANotifier: IWsServerShutdownNotifier);
var
  LUpgrade, LKey, LVersion, LOrigin: string;
  LConnectionValues, LKeyValues, LExtValues: TStringArray;
  LAccept: string;
  LResp: string;
  LHijacker: IHttpHijacker;
  LConn: ITcpStream;
  LConnCtx: IHttpConnContext;
  LSessionCtx: ITcpServerSessionContext;
  LReg: IWsServerShutdownRegistry;
begin
  ADeflate := False;
  AConn := nil;
  ANotifier := nil;
  if AReq = nil then
    raise EHttpError.Create(hekArgument, 'WebSocket upgrade request is nil');
  if AW = nil then
    raise EHttpError.Create(hekArgument, 'WebSocket upgrade response writer is nil');
  ValidateWebSocketOptions(AOptions);

  LUpgrade := LowerTrimOWS(AReq.Headers.Get('upgrade'));
  LConnectionValues := AReq.Headers.GetAll('connection');
  LKeyValues := AReq.Headers.GetAll('sec-websocket-key');
  if Length(LKeyValues) = 1 then
    LKey := TrimOWS(LKeyValues[0])
  else
    LKey := '';
  LVersion := TrimOWS(AReq.Headers.Get('sec-websocket-version'));

  { RFC 6455 Section 4.1: request must be GET with HTTP/1.1 }
  if AReq.Method <> hmGet then
    raise EHttpError.Create(hekUpgrade, 'WebSocket upgrade requires GET method');
  if AReq.Version <> hvHttp11 then
    raise EHttpError.Create(hekUpgrade, 'WebSocket upgrade requires HTTP/1.1');

  if LUpgrade <> 'websocket' then
    raise EHttpError.Create(hekUpgrade, 'Missing or invalid Upgrade header');
  if not HeaderValuesHaveToken(LConnectionValues, 'upgrade') then
    raise EHttpError.Create(hekUpgrade, 'Missing or invalid Connection header');
  if LKey = '' then
    raise EHttpError.Create(hekUpgrade, 'Missing Sec-WebSocket-Key header');
  ValidateHandshakeKey(LKey);
  if LVersion <> '13' then
    raise EHttpError.Create(hekUpgrade, 'Unsupported Sec-WebSocket-Version');

  { Origin validation }
  LOrigin := AReq.Headers.Get('origin');
  if Assigned(AOptions.OnCheckOrigin) then
  begin
    if not AOptions.OnCheckOrigin(LOrigin) then
      raise EHttpError.Create(hekUpgrade, 'WebSocket: origin not allowed');
  end
  else
  begin
    { Default: reject Origin: null (common non-browser bypass technique).
      Browsers always send a valid Origin; `null` typically indicates
      a sandboxed iframe or a non-browser client trying to evade checks.
      Also reject empty Origin as it indicates a non-browser client. }
    if (LOrigin = 'null') or (LOrigin = '') then
      raise EHttpError.Create(hekUpgrade, 'WebSocket: Origin must be present and non-null');
  end;

  if AOfferDeflate and AOptions.EnablePermessageDeflate then
  begin
    LExtValues := AReq.Headers.GetAll('sec-websocket-extensions');
    ADeflate := HeadersOfferPermessageDeflate(LExtValues);
  end;

  { Hijack the connection }
  if not Supports(AW, IHttpHijacker, LHijacker) then
    raise EHttpError.Create(hekUpgrade, 'Response writer does not support connection hijack');
  LConn := LHijacker.Hijack;

  ApplyWebSocketCancelToken(LConn, AOptions.EffectiveCancelToken);
  { B7 G1：服务端阻塞路径先登记 shutdown 通知器再写 101——注册 happens-before
    客户端观察到 101（客户端看到 101 即可触发 Shutdown，登记若在其后完成，
    ShutdownAll 会看到空注册表）。非阻塞 handoff 不登记：事件驱动会话的收尾
    不经过 TWebSocketImpl.Destroy，无人 Detach，注册表会悬挂引用。 }
  if AInstallShutdownNotifier then
  begin
    if Supports(AW, IHttpConnContext, LConnCtx) then
    begin
      LSessionCtx := LConnCtx.HostSessionContext;
      if LSessionCtx <> nil then
        if Supports(LSessionCtx, IWsServerShutdownRegistry, LReg) then
        begin
          ANotifier := TWsServerShutdownNotifier.Create(LReg, LConn,
            AOptions.EffectiveCancelToken = nil);
          LReg.RegisterShutdownNotifier(ANotifier);
        end;
    end;
  end;

  LAccept := ComputeAcceptKey(LKey);

  LResp := 'HTTP/1.1 101 Switching Protocols'#13#10 +
           'Upgrade: websocket'#13#10 +
           'Connection: Upgrade'#13#10 +
           'Sec-WebSocket-Accept: ' + LAccept + #13#10;
  if ADeflate then
    LResp := LResp + 'Sec-WebSocket-Extensions: ' + WS_PMD_EXTENSION_VALUE + #13#10;
  LResp := LResp + #13#10;
  try
    IoWriteAll(LConn as IWriter, LResp[1], SizeUInt(Length(LResp)));
  except
    LConn.Close;
    raise;
  end;

  { F-7：101 已写出即协议切换完成，I/O 时序归 WS 层所有。h1 在读请求前
    装配的每请求读死线（ReadTimeout，默认 30s 绝对期限）若不清除会原封
    传给升级后的连接——长驻 WS 恰好在握手 30s 后被掐断，心跳无效。
    清读写两向；WS 写路径自带每写 WriteTimeoutMs（B7），读侧存活由应用层
    ping/pong 负责。阻塞与非阻塞 handoff 共用本路径，一处修复两端受益。 }
  ClearWebSocketStreamDeadline(LConn);

  AConn := LConn;
end;

{ 非阻塞升级（B8 第二片）：见 interface 注释。
  F-10：五参重载为真身——ACheckOrigin 经局部 TWebSocketOptions 注入握手
  （此前硬编码 Default 使回调不可达）；四参版本薄委托传 nil。 }
function UpgradeWebSocketHandoff(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const ASink: IWebSocketFrameSink;
  const AOptions: TNetWsFrameSessionOptions;
  const ACheckOrigin: TWebSocketOriginCheck): IWebSocketFrameSession;
var
  LConn: ITcpStream;
  LDeflate: Boolean;
  LConnCtx: IHttpConnContext;
  LSessionCtx: ITcpServerSessionContext;
  LPush: IWebSocketFrameWorkerPush;
  LSession: TNetWsFrameSession;
  LNotifier: IWsServerShutdownNotifier;
  LHandshakeOpts: TWebSocketOptions;
begin
  LConn := nil;
  LNotifier := nil;
  { 非阻塞路径不登记 shutdown 通知器：事件驱动会话收尾不经 TWebSocketImpl.
    Destroy，无人 Detach，注册表会悬挂引用。 }
  LHandshakeOpts := TWebSocketOptions.Default;
  LHandshakeOpts.OnCheckOrigin := ACheckOrigin;
  PerformUpgradeHandshake(AReq, AW, LHandshakeOpts, False, False,
    LConn, LDeflate, LNotifier);
  if not Supports(AW, IHttpConnContext, LConnCtx) then
  begin
    LConn.Close;
    raise EHttpError.Create(hekUpgrade,
      'WebSocket upgrade requires an evented tcp server backend');
  end;
  LSessionCtx := LConnCtx.HostSessionContext;
  if LSessionCtx = nil then
  begin
    LConn.Close;
    raise EHttpError.Create(hekUpgrade,
      'WebSocket upgrade requires an evented tcp server backend');
  end;
  LSession := TNetWsFrameSession.Create(LConn, ASink, AOptions);
  if Supports(LSessionCtx, IWebSocketFrameWorkerPush, LPush) then
    LSession.SetFrameWorkerPush(LPush);
  if not LSessionCtx.HandoffHijackedConn(LConn, LSession) then
  begin
    LSession.Cancel;
    LConn.Close;
    raise EHttpError.Create(hekUpgrade, 'WebSocket upgrade handoff failed');
  end;
  Result := LSession;
end;

function UpgradeWebSocketHandoff(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter; const ASink: IWebSocketFrameSink;
  const AOptions: TNetWsFrameSessionOptions): IWebSocketFrameSession;
begin
  Result := UpgradeWebSocketHandoff(AReq, AW, ASink, AOptions,
    TWebSocketOriginCheck(nil));
end;

{ TWsServerShutdownNotifier }

constructor TWsServerShutdownNotifier.Create(
  const ARegistry: IWsServerShutdownRegistry; const AStream: ITcpStream;
  const AInstallWake: Boolean);
begin
  inherited Create;
  FRegistry := ARegistry;
  FStream := AStream;
  FDone := Event(True);
  FDetached := 0;
  FCancel := nil;
  if AInstallWake then
  begin
    { waitable cancel：NotifyShutdown 时 Cancel 会经 poll 的 wake socket
      立即唤醒阻塞中的读/写（mid-poll 设置读 deadline 无效——poll 在
      旧的无限超时上继续阻塞）。应用自带 cancel token 时不覆盖。 }
    FCancel := NewNetCancelToken;
    FStream.SetCancelToken(FCancel);
  end;
end;

destructor TWsServerShutdownNotifier.Destroy;
begin
  { 异常路径兜底：未 Detach 即销毁（仅发生在注册表自身析构释放引用时）
    只唤醒 WaitFinished 等待者，不再回调摘除——注册表正在析构，
    Unregister 会重入正在释放的数组/锁。注册表析构整体释放登记，
    无悬挂引用。 }
  if atomic_exchange(FDetached, 1, mo_acq_rel) = 0 then
    FDone.SetEvent;
  inherited Destroy;
end;

procedure TWsServerShutdownNotifier.Detach;
begin
  if atomic_exchange(FDetached, 1, mo_acq_rel) <> 0 then
    Exit;
  if FRegistry <> nil then
  begin
    FRegistry.UnregisterShutdownNotifier(Self);
    FRegistry := nil;
  end;
  FStream := nil;
  FCancel := nil;
  FDone.SetEvent;
end;

procedure TWsServerShutdownNotifier.NotifyShutdown;
begin
  if atomic_load(FDetached, mo_acquire) <> 0 then
    Exit;
  { 唤醒连接线程：阻塞中的 poll 因 waitable cancel 立即返回并抛错，
    handler 读循环退出 → Destroy 收尾路径补发 close frame 1001（单写者，
    无跨线程写竞态）。drain 总时长仍由服务器 ShutdownTimeout 约束。 }
  if FCancel <> nil then
    FCancel.Cancel;
end;

function TWsServerShutdownNotifier.WaitFinished(
  const ATimeoutNs: Int64): Boolean;
begin
  if atomic_load(FDetached, mo_acquire) <> 0 then
    Exit(True);
  if ATimeoutNs <= 0 then
  begin
    { 0 = 无限等待（与 HTTP ShutdownTimeout=0 语义一致）。 }
    FDone.Wait;
    Exit(True);
  end;
  Result := FDone.WaitTimeout(ATimeoutNs);
end;

procedure TWsServerShutdownNotifier.ForceClose;
begin
  { 先唤醒再强关：close 不会唤醒阻塞中的 poll（Linux 语义），连接线程会
    悬挂在已关闭的 socket 上；Cancel 幂等（NotifyShutdown 已调用则无操作）。
    应用自带 cancel token 的会话（FCancel=nil）无法强制唤醒——调用方
    超时语义下连接线程悬挂属已知降级（应用拥有取消权）。 }
  if FCancel <> nil then
    FCancel.Cancel;
  if FStream <> nil then
  begin
    try
      FStream.Close;
    except
    end;
  end;
end;

{ TWebSocketImpl }

constructor TWebSocketImpl.Create(const AReader: IReader; const AWriter: IWriter;
  const AOptions: TWebSocketOptions; AIsClient: Boolean;
  const AStream: ITcpStream; const ADeflateEnabled: Boolean;
  const AShutdownNotifier: IWsServerShutdownNotifier);
begin
  inherited Create;
  FReader := AReader;
  FWriter := AWriter;
  FStream := AStream;
  FOptions := AOptions;
  FIsClient := AIsClient;
  FDeflateEnabled := ADeflateEnabled;
  FOpen := True;
  FCloseReceived := False;
  FCloseSent := False;
  FFragmentOpen := False;
  FFragmentOpcode := wsOpContinuation;
  FFragmentPayloadSize := 0;
  FFragmentBinaryPayload := nil;
  FFragmentCompressed := False;
  { 服务端阻塞路径：shutdown 通知器已在握手路径（PerformUpgradeHandshake）
    登记（先于 101 写出，注册 happens-before 客户端观察到 101），流 cancel
    token 也已处理，构造函数不再覆盖。其余路径（客户端）在此应用自带
    cancel token。 }
  if (not FIsClient) and (AShutdownNotifier <> nil) then
    FShutdownNotifier := AShutdownNotifier
  else if FStream <> nil then
    ApplyWebSocketCancelToken(FStream, AOptions.EffectiveCancelToken);
end;

destructor TWebSocketImpl.Destroy;
begin
  { 先解除流 cancel（shutdown 唤醒可能已触发）：使收尾 close frame 的
    写入不被已取消的流拒绝；再补发 close frame（G2）；最后摘除 shutdown
    登记并释放连接引用。 }
  ClearStreamCancel;
  { 收尾补发 close frame（G2）：既未收到对端 close 也未发送 close 时，
    best-effort 补发——已收到对端 close → 回 1000；未收到 → 1001 going
    away（服务器 shutdown / handler 异常退出场景）。写失败吞掉（对端
    可能已断）；随后连接随 FStream 引用释放关闭。 }
  if FOpen and (not FCloseSent) then
  begin
    try
      if FCloseReceived then
        Close(1000, '')
      else
        Close(1001, 'going away');
    except
    end;
  end;
  if FShutdownNotifier <> nil then
  begin
    FShutdownNotifier.Detach;
    FShutdownNotifier := nil;
  end;
  inherited Destroy;
end;

procedure TWebSocketImpl.ThrowIfCanceled;
begin
  HttpThrowIfCanceled(FOptions.EffectiveCancelToken);
end;

procedure TWebSocketImpl.ClearStreamCancel;
begin
  ClearWebSocketCancelToken(FStream);
end;

procedure TWebSocketImpl.ReadExact(var ABuf; ACount: SizeUInt);
var
  LPtr: PByte;
  LRead: SizeUInt;
begin
  LPtr := @ABuf;
  while ACount > 0 do
  begin
    ThrowIfCanceled;
    try
      LRead := FReader.Read(LPtr^, ACount);
    except
      on E: EHttpError do
        raise;
      on E: Exception do
        RaiseWebSocketTransport(E);
    end;
    if LRead = 0 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: unexpected end of stream');
    Inc(LPtr, LRead);
    Dec(ACount, LRead);
  end;
end;

function TWebSocketImpl.ReadFrame: TWebSocketFrame;
var
  LHdr: array[0..1] of Byte;
  LPayloadLen: UInt64;
  LExtLen: array[0..7] of Byte;
  LMaskKey: array[0..3] of Byte;
  LMasked: Boolean;
  LOpcode: Byte;
  LBuf: TBytes;
  LRsv1: Boolean;
  I: SizeUInt;
begin
  Result := Default(TWebSocketFrame);
  if not FOpen then
    raise EHttpError.Create(hekProtocol, 'WebSocket: connection closed');

  ReadExact(LHdr[0], 2);
  Result.Fin := (LHdr[0] and $80) <> 0;
  LRsv1 := (LHdr[0] and $40) <> 0;
  if (LHdr[0] and $30) <> 0 then
    raise EHttpError.Create(hekProtocol, 'WebSocket: reserved bits set');
  if LRsv1 and (not FDeflateEnabled) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: RSV1 without permessage-deflate');
  LOpcode := LHdr[0] and $0F;
  if LRsv1 and (LOpcode >= $08) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: RSV1 on control frame');
  if LRsv1 and (LOpcode = Byte(wsOpContinuation)) then
    raise EHttpError.Create(hekProtocol,
      'WebSocket: RSV1 only allowed on first compressed data frame');
  if not IsValidOpcode(LOpcode) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: reserved or invalid opcode');
  if (LOpcode >= $08) and (not Result.Fin) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: control frames must not be fragmented');
  if (LOpcode = Byte(wsOpContinuation)) and (not FFragmentOpen) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: unexpected continuation frame');
  if (LOpcode in [Byte(wsOpText), Byte(wsOpBinary)]) and FFragmentOpen then
    raise EHttpError.Create(hekProtocol, 'WebSocket: data frame interrupts fragmented message');
  Result.Opcode := TWebSocketOpcode(LOpcode);
  LMasked := (LHdr[1] and $80) <> 0;
  LPayloadLen := LHdr[1] and $7F;

  { RFC 6455 §5.3: Client frames MUST be masked, server frames MUST NOT be masked }
  if FIsClient then
  begin
    if LMasked then
      raise EHttpError.Create(hekProtocol, 'WebSocket: server frames must not be masked');
  end
  else
  begin
    if not LMasked then
      raise EHttpError.Create(hekProtocol, 'WebSocket: client frames must be masked');
  end;

  if LPayloadLen = 126 then
  begin
    ReadExact(LExtLen[0], 2);
    LPayloadLen := (UInt64(LExtLen[0]) shl 8) or UInt64(LExtLen[1]);
    if LPayloadLen < 126 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: non-canonical payload length');
  end
  else if LPayloadLen = 127 then
  begin
    ReadExact(LExtLen[0], 8);
    if (LExtLen[0] and $80) <> 0 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: invalid 64-bit payload length');
    LPayloadLen := 0;
    for I := 0 to 7 do
      LPayloadLen := (LPayloadLen shl 8) or UInt64(LExtLen[I]);
    if LPayloadLen < 65536 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: non-canonical payload length');
  end;

  if (LOpcode >= $08) and (LPayloadLen > 125) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: control frame payload too large');

  if SizeExceedsLimit(LPayloadLen, FOptions.MaxFrameSize) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: frame too large');
  if LPayloadLen > UInt64(High(SizeInt)) then
    raise EHttpError.Create(hekProtocol, 'WebSocket: frame exceeds platform capacity');
  if LOpcode in [Byte(wsOpText), Byte(wsOpBinary)] then
  begin
    if SizeExceedsLimit(LPayloadLen, FOptions.MaxMessageSize) then
      raise EHttpError.Create(hekProtocol, 'WebSocket: message too large');
  end
  else if LOpcode = Byte(wsOpContinuation) then
  begin
    if CombinedSizeExceedsLimit(FFragmentPayloadSize, LPayloadLen,
       FOptions.MaxMessageSize) then
      raise EHttpError.Create(hekProtocol, 'WebSocket: message too large');
  end;

  if LMasked then
    ReadExact(LMaskKey[0], 4);

  SetLength(LBuf, SizeUInt(LPayloadLen));
  if LPayloadLen > 0 then
  begin
    ReadExact(LBuf[0], SizeUInt(LPayloadLen));
    if LMasked then
      for I := 0 to SizeUInt(LPayloadLen) - 1 do
        LBuf[I] := LBuf[I] xor LMaskKey[I mod 4];
  end;

  Result.Payload := LBuf;

  if Result.Opcode = wsOpClose then
  begin
    ValidateClosePayload(Result.Payload);
    FCloseReceived := True;
  end;

  if Result.Opcode = wsOpContinuation then
  begin
    if not FFragmentCompressed then
    begin
      if FFragmentOpcode = wsOpText then
      begin
        FFragmentBinaryPayload := BytesConcat(FFragmentBinaryPayload, Result.Payload);
        if Result.Fin then
          ValidateTextPayload(BytesToString(FFragmentBinaryPayload));
      end
      else
        FFragmentBinaryPayload := BytesConcat(FFragmentBinaryPayload, Result.Payload);
    end
    else
      FFragmentBinaryPayload := BytesConcat(FFragmentBinaryPayload, Result.Payload);
    if Result.Fin then
    begin
      { Final continuation always returns the fully assembled message. }
      if FFragmentCompressed then
      begin
        Result.Payload := MaybeDecompressPayload(True, FFragmentBinaryPayload);
        if FFragmentOpcode = wsOpText then
          ValidateTextPayload(BytesToString(Result.Payload));
      end
      else
      begin
        Result.Payload := FFragmentBinaryPayload;
        if FFragmentOpcode = wsOpText then
          ValidateTextPayload(BytesToString(Result.Payload));
      end;
      FFragmentOpen := False;
      FFragmentOpcode := wsOpContinuation;
      FFragmentPayloadSize := 0;
      FFragmentBinaryPayload := nil;
      FFragmentCompressed := False;
    end
    else
      Inc(FFragmentPayloadSize, LPayloadLen);
  end
  else if Result.Opcode in [wsOpText, wsOpBinary] then
  begin
    if Result.Fin then
    begin
      Result.Payload := MaybeDecompressPayload(LRsv1, Result.Payload);
      if Result.Opcode = wsOpText then
        ValidateTextPayload(BytesToString(Result.Payload));
    end
    else
    begin
      FFragmentOpen := True;
      FFragmentOpcode := Result.Opcode;
      FFragmentPayloadSize := LPayloadLen;
      FFragmentBinaryPayload := Result.Payload;
      FFragmentCompressed := LRsv1;
    end;
  end;
end;

function TWebSocketImpl.ReadMessage: TWebSocketFrame;
var
  LFrame: TWebSocketFrame;
  LMessageOpcode: TWebSocketOpcode;
begin
  Result := Default(TWebSocketFrame);
  { Read frames until we get a complete data message }
  while True do
  begin
    LFrame := ReadFrame;

    case LFrame.Opcode of
      wsOpPing:
      begin
        { RFC 6455 §5.5.2: MUST respond to Ping with Pong }
        Pong(LFrame.Payload);
        { Continue reading for the actual message }
      end;

      wsOpPong:
      begin
        { Unsolicited pong — ignore and continue }
      end;

      wsOpClose:
      begin
        { Close frame — pass it through }
        Result := LFrame;
        Exit;
      end;

      wsOpText, wsOpBinary:
      begin
        if LFrame.Fin then
        begin
          { Single-frame message — return directly }
          Result := LFrame;
          Exit;
        end
        else
        begin
          { First fragment — ReadFrame assembles (and decompresses) on final Fin. }
          LMessageOpcode := LFrame.Opcode;
          while True do
          begin
            LFrame := ReadFrame;
            if LFrame.Opcode = wsOpPing then
            begin
              Pong(LFrame.Payload);
              Continue;
            end;
            if LFrame.Opcode = wsOpPong then
              Continue;
            if LFrame.Opcode = wsOpClose then
            begin
              Result := LFrame;
              Exit;
            end;
            if LFrame.Opcode <> wsOpContinuation then
              raise EHttpError.Create(hekProtocol, 'WebSocket: expected continuation frame');
            if LFrame.Fin then
            begin
              Result.Opcode := LMessageOpcode;
              Result.Fin := True;
              Result.Payload := LFrame.Payload;
              Exit;
            end;
          end;
        end;
      end;

      wsOpContinuation:
        raise EHttpError.Create(hekProtocol, 'WebSocket: unexpected continuation frame');
    else
      { RFC 6455 §5.1: unknown opcode MUST fail the connection. ReadFrame
        already rejects reserved opcodes; this guards future call sites. }
      raise EHttpError.Create(hekProtocol, 'WebSocket: unsupported opcode');
    end;
  end;
end;

procedure TWebSocketImpl.WriteFrameRaw(AOpcode: TWebSocketOpcode; const APayload: TBytes;
  const ARsv1: Boolean);
var
  LHdr: array[0..9] of Byte;
  LHdrLen: Integer;
  LPayloadLen: SizeUInt;
  LMaskKey: array[0..3] of Byte;
  LBuf: TBytes;
  LBufLen: SizeUInt;
  I, J: SizeUInt;
begin
  ThrowIfCanceled;
  LPayloadLen := SizeUInt(Length(APayload));

  LHdr[0] := $80 or Byte(AOpcode); { FIN + opcode }
  if ARsv1 then
    LHdr[0] := LHdr[0] or $40;

  { RFC 6455 §5.3: Client frames MUST be masked }
  if FIsClient then
  begin
    { Generate cryptographically secure random mask key }
    SecureRandomBytes(@LMaskKey[0], 4);

    if LPayloadLen < 126 then
    begin
      LHdr[1] := $80 or Byte(LPayloadLen); { MASK bit set }
      LHdr[2] := LMaskKey[0];
      LHdr[3] := LMaskKey[1];
      LHdr[4] := LMaskKey[2];
      LHdr[5] := LMaskKey[3];
      LHdrLen := 6;
    end
    else if LPayloadLen < 65536 then
    begin
      LHdr[1] := $80 or 126; { MASK bit set }
      LHdr[2] := Byte(LPayloadLen shr 8);
      LHdr[3] := Byte(LPayloadLen);
      LHdr[4] := LMaskKey[0];
      LHdr[5] := LMaskKey[1];
      LHdr[6] := LMaskKey[2];
      LHdr[7] := LMaskKey[3];
      LHdrLen := 8;
    end
    else
    begin
      LHdr[1] := $80 or 127; { MASK bit set }
      LHdr[2] := Byte(UInt64(LPayloadLen) shr 56);
      LHdr[3] := Byte(UInt64(LPayloadLen) shr 48);
      LHdr[4] := Byte(UInt64(LPayloadLen) shr 40);
      LHdr[5] := Byte(UInt64(LPayloadLen) shr 32);
      LHdr[6] := Byte(LPayloadLen shr 24);
      LHdr[7] := Byte(LPayloadLen shr 16);
      LHdr[8] := Byte(LPayloadLen shr 8);
      LHdr[9] := Byte(LPayloadLen);
      LHdrLen := 10;
    end;

    { Build single buffer: header + [mask-key +] masked payload }
    if LPayloadLen >= 65536 then
      LBufLen := SizeUInt(LHdrLen) + 4 + LPayloadLen
    else
      LBufLen := SizeUInt(LHdrLen) + LPayloadLen;
    SetLength(LBuf, LBufLen);
    Move(LHdr[0], LBuf[0], SizeUInt(LHdrLen));
    I := SizeUInt(LHdrLen);
    if LPayloadLen >= 65536 then
    begin
      Move(LMaskKey[0], LBuf[I], 4);
      Inc(I, 4);
    end;
    if LPayloadLen > 0 then
    begin
      for J := 0 to LPayloadLen - 1 do
        LBuf[I + J] := APayload[J] xor LMaskKey[J mod 4];
    end;
    try
      WriteAll(LBuf[0], LBufLen);
    except
      on E: EHttpError do
        raise;
      on E: Exception do
        RaiseWebSocketTransport(E);
    end;
  end
  else
  begin
    { Server frames: no masking — merge header + payload into single write }
    if LPayloadLen < 126 then
    begin
      LHdr[1] := Byte(LPayloadLen);
      LHdrLen := 2;
    end
    else if LPayloadLen < 65536 then
    begin
      LHdr[1] := 126;
      LHdr[2] := Byte(LPayloadLen shr 8);
      LHdr[3] := Byte(LPayloadLen);
      LHdrLen := 4;
    end
    else
    begin
      LHdr[1] := 127;
      LHdr[2] := Byte(UInt64(LPayloadLen) shr 56);
      LHdr[3] := Byte(UInt64(LPayloadLen) shr 48);
      LHdr[4] := Byte(UInt64(LPayloadLen) shr 40);
      LHdr[5] := Byte(UInt64(LPayloadLen) shr 32);
      LHdr[6] := Byte(LPayloadLen shr 24);
      LHdr[7] := Byte(LPayloadLen shr 16);
      LHdr[8] := Byte(LPayloadLen shr 8);
      LHdr[9] := Byte(LPayloadLen);
      LHdrLen := 10;
    end;

    LBufLen := SizeUInt(LHdrLen) + LPayloadLen;
    SetLength(LBuf, LBufLen);
    Move(LHdr[0], LBuf[0], SizeUInt(LHdrLen));
    if LPayloadLen > 0 then
      Move(APayload[0], LBuf[LHdrLen], LPayloadLen);
    try
      WriteAll(LBuf[0], LBufLen);
    except
      on E: EHttpError do
        raise;
      on E: Exception do
        RaiseWebSocketTransport(E);
    end;
  end;
end;

procedure TWebSocketImpl.WriteAll(const ABuf; ACount: SizeUInt);
var
  LArmed: Boolean;
begin
  { G3：单次写独立超时——写前设写 deadline、写后清除（WriteTimeoutMs>0 时）。
    慢客户端填满 OS 发送缓冲时写抛超时错，调用方按死连接剔除。
    并发写路径（room 广播等既有模型）下 set/clear 竞争只影响超时有效性，
    不引入额外安全风险。 }
  LArmed := False;
  if (FOptions.WriteTimeoutMs > 0) and (FStream <> nil) then
  begin
    FStream.SetWriteDeadline(
      TDeadline.After(TDuration.FromMilliseconds(FOptions.WriteTimeoutMs)));
    LArmed := True;
  end;
  try
    IoWriteAll(FWriter, ABuf, ACount);
  finally
    if LArmed then
      FStream.SetWriteDeadline(TDeadline.Infinite);
  end;
end;

procedure TWebSocketImpl.WriteFrame(AOpcode: TWebSocketOpcode; const APayload: TBytes;
  const ARsv1: Boolean);
begin
  if not IsOpen then
    raise EHttpError.Create(hekProtocol, 'WebSocket: connection closed');
  if AOpcode in [wsOpClose, wsOpPing, wsOpPong] then
  begin
    if ARsv1 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: RSV1 on control frame');
    ValidateControlPayloadSize(APayload);
  end;
  WriteFrameRaw(AOpcode, APayload, ARsv1);
end;

function TWebSocketImpl.MaybeDecompressPayload(const ACompressed: Boolean;
  const APayload: TBytes): TBytes;
var
  LMax: SizeUInt;
begin
  if not ACompressed then
    Exit(APayload);
  if not FDeflateEnabled then
    raise EHttpError.Create(hekProtocol,
      'WebSocket: RSV1 without permessage-deflate');
  if FOptions.MaxMessageSize > 0 then
    LMax := SizeUInt(FOptions.MaxMessageSize)
  else
    LMax := SizeUInt(WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE);
  try
    Result := RawDeflateMessageDecompress(APayload, LMax);
  except
    on E: EIOError do
      raise EHttpError.Create(hekProtocol,
        'WebSocket: permessage-deflate decompress failed: ' + E.Message);
  end;
end;

procedure TWebSocketImpl.WriteDataMessage(AOpcode: TWebSocketOpcode;
  const APayload: TBytes);
var
  LOut: TBytes;
  LRsv1: Boolean;
begin
  LRsv1 := False;
  LOut := APayload;
  if FDeflateEnabled then
  begin
    try
      LOut := RawDeflateMessageCompress(APayload);
      { Prefer uncompressed wire size when deflate does not shrink. }
      if Length(LOut) < Length(APayload) then
        LRsv1 := True
      else
        LOut := APayload;
    except
      on E: EIOError do
      begin
        LOut := APayload;
        LRsv1 := False;
      end;
    end;
  end;
  WriteFrame(AOpcode, LOut, LRsv1);
end;

procedure TWebSocketImpl.WriteText(const AData: string);
begin
  ValidateTextPayload(AData);
  WriteDataMessage(wsOpText, StringToBytes(AData));
end;

procedure TWebSocketImpl.WriteBinary(const AData: TBytes);
begin
  WriteDataMessage(wsOpBinary, AData);
end;

procedure TWebSocketImpl.Ping(const AData: TBytes);
begin
  WriteFrame(wsOpPing, AData);
end;

procedure TWebSocketImpl.Pong(const AData: TBytes);
begin
  WriteFrame(wsOpPong, AData);
end;

procedure TWebSocketImpl.Close(const ACode: UInt16; const AReason: string);
var
  LPayload: TBytes;
  LReasonBytes: TBytes;
begin
  if FCloseSent then
    Exit; { Already sent close }
  LReasonBytes := StringToBytes(AReason);
  SetLength(LPayload, 2 + Length(LReasonBytes));
  LPayload[0] := Byte(ACode shr 8);
  LPayload[1] := Byte(ACode and $FF);
  if Length(LReasonBytes) > 0 then
    Move(LReasonBytes[0], LPayload[2], Length(LReasonBytes));
  ValidateControlPayloadSize(LPayload);
  ValidateClosePayload(LPayload);
  FCloseSent := True;
  FOpen := False;
  try
    WriteFrameRaw(wsOpClose, LPayload);
  finally
    ClearStreamCancel;
  end;
end;

function TWebSocketImpl.IsOpen: Boolean;
begin
  Result := FOpen and (not FCloseSent) and (not FCloseReceived);
end;

{ ConnectWebSocket helpers }

function GenerateWebSocketKey: string;
var
  LBytes: TBytes;
begin
  SetLength(LBytes, 16);
  SecureRandomBytes(@LBytes[0], 16);
  Result := Base64Encode(LBytes);
end;

function ValidateAcceptKey(const AKey, AAccept: string): Boolean;
var
  LConcat: string;
begin
  LConcat := AKey + WS_GUID;
  Result := AAccept = Base64Encode(Sha1DigestToBytes(
    SHA1Of(LConcat[1], SizeUInt(Length(LConcat)))));
end;

procedure ReadHttpResponse(const AReader: IReader;
  out AStatusCode: Integer; out AHeaders: TStringArray);
const
  MAX_STATUS_LINE_SIZE = 4096;
  MAX_HEADER_LINE_SIZE = 8192;
  MAX_HEADER_BYTES = 65536;
  MAX_HEADER_COUNT = 256;
var
  LLine: string;
  LCh: Char;
  LLen: Integer;
  LHeaderCount: Integer;
  LHeaderBytes: SizeUInt;
begin
  LCh := #0;
  AStatusCode := 0;
  LHeaderCount := 0;
  LHeaderBytes := 0;
  SetLength(AHeaders, 16);

  { Read status line }
  LLine := '';
  repeat
    LLen := AReader.Read(LCh, 1);
    if LLen = 0 then
      raise EHttpError.Create(hekProtocol, 'WebSocket: unexpected end of stream reading response');
    if LCh <> #10 then
      LLine := LLine + LCh;
  until (LCh = #10) or (Length(LLine) > MAX_STATUS_LINE_SIZE);
  if Length(LLine) > MAX_STATUS_LINE_SIZE then
    raise EHttpError.Create(hekProtocol, 'WebSocket: HTTP status line too large');

  { Remove trailing CR }
  if (Length(LLine) > 0) and (LLine[Length(LLine)] = #13) then
    LLine := Copy(LLine, 1, Length(LLine) - 1);

  { Parse status code }
  if Copy(LLine, 1, 8) <> 'HTTP/1.1' then
    raise EHttpError.Create(hekProtocol, 'WebSocket: invalid HTTP response');
  if Length(LLine) < 12 then
    raise EHttpError.Create(hekProtocol, 'WebSocket: invalid HTTP response');
  AStatusCode := StrToIntDef(Copy(LLine, 10, 3), 0);

  { Read headers }
  repeat
    LLine := '';
    repeat
      LLen := AReader.Read(LCh, 1);
      if LLen = 0 then
        raise EHttpError.Create(hekProtocol, 'WebSocket: unexpected end of stream reading headers');
      if LCh <> #10 then
        LLine := LLine + LCh;
    until (LCh = #10) or (Length(LLine) > MAX_HEADER_LINE_SIZE);
    if Length(LLine) > MAX_HEADER_LINE_SIZE then
      raise EHttpError.Create(hekProtocol, 'WebSocket: HTTP response header line too large');

    { Remove trailing CR }
    if (Length(LLine) > 0) and (LLine[Length(LLine)] = #13) then
      LLine := Copy(LLine, 1, Length(LLine) - 1);

    { Empty line marks end of headers }
    if LLine = '' then
      Break;

    Inc(LHeaderBytes, SizeUInt(Length(LLine)) + 2);
    if LHeaderBytes > MAX_HEADER_BYTES then
      raise EHttpError.Create(hekProtocol, 'WebSocket: HTTP response headers too large');
    if LHeaderCount >= MAX_HEADER_COUNT then
      raise EHttpError.Create(hekProtocol, 'WebSocket: too many HTTP response headers');

    { Store header }
    if LHeaderCount >= Length(AHeaders) then
      SetLength(AHeaders, LHeaderCount + 16);
    AHeaders[LHeaderCount] := LLine;
    Inc(LHeaderCount);
  until False;

  SetLength(AHeaders, LHeaderCount);
end;

function FindHeader(const AHeaders: TStringArray; const AName: string): string;
var
  I: Integer;
  LLine: string;
  LNameLower: string;
begin
  Result := '';
  LNameLower := LowerCase(AName);
  for I := 0 to High(AHeaders) do
  begin
    LLine := AHeaders[I];
    if Length(LLine) > Length(AName) + 1 then
    begin
      if (LowerCase(Copy(LLine, 1, Length(AName) + 1)) = LNameLower + ':') or
         (LowerCase(Copy(LLine, 1, Length(AName) + 2)) = LNameLower + ': ') then
      begin
        if LLine[Length(AName) + 1] = ':' then
          LLine := TrimOWS(Copy(LLine, Length(AName) + 2, MaxInt))
        else
          LLine := TrimOWS(Copy(LLine, Length(AName) + 3, MaxInt));
        if Result = '' then
          Result := LLine
        else
          Result := Result + ', ' + LLine;
      end;
    end;
  end;
end;

{ ConnectWebSocket implementation }

function ConnectWebSocket(const AUrl: string): IWebSocket;
begin
  Result := ConnectWebSocket(AUrl, TWebSocketOptions.Default);
end;

function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
var
  LClient: IHttpClient;
begin
  LClient := NewHttpClient;
  Result := ConnectWebSocket(LClient, AUrl, AOptions);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket;
begin
  Result := ConnectWebSocket(AClient, AUrl, TWebSocketOptions.Default);
end;

function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket;
var
  LParsedUrl: TUrl;
  LScheme, LHost, LPath, LKey: string;
  LPort: UInt16;
  LConn, LTlsConn, LActive: ITcpStream;
  LReader: IReader;
  LWriter: IWriter;
  LRequest: string;
  LStatusCode: Integer;
  LHeaders: TStringArray;
  LUpgrade, LConnection, LAcceptHeader, LExtHeader: string;
  LDialMs: Int64;
  LHandshakeMs: Int64;
  LDeflate: Boolean;
  LI: Integer;
begin
  if AClient = nil then
    raise EHttpError.Create(hekArgument, 'WebSocket client is nil');
  if AUrl = '' then
    raise EHttpError.Create(hekArgument, 'WebSocket URL is empty');
  ValidateWebSocketOptions(AOptions);

  { Parse URL }
  LParsedUrl := TUrl.Parse(AUrl);
  LScheme := LowerCase(LParsedUrl.Scheme);
  LHost := LParsedUrl.Host;
  LPath := LParsedUrl.Path;
  if LPath = '' then
    LPath := '/';

  { Validate scheme }
  if (LScheme <> 'ws') and (LScheme <> 'wss') then
    raise EHttpError.Create(hekUpgrade, 'WebSocket: invalid scheme (expected ws:// or wss://)');

  { Validate host and path for CRLF injection }
  if (Pos(#13, LHost) > 0) or (Pos(#10, LHost) > 0) then
    raise EHttpError.Create(hekUpgrade, 'WebSocket: CRLF in host');
  if (Pos(#13, LPath) > 0) or (Pos(#10, LPath) > 0) then
    raise EHttpError.Create(hekUpgrade, 'WebSocket: CRLF in path');

  { Include query string in request target }
  if LParsedUrl.RawQuery <> '' then
    LPath := LPath + '?' + LParsedUrl.RawQuery;

  { Determine port }
  LPort := LParsedUrl.Port;
  if LPort = 0 then
  begin
    if LScheme = 'wss' then
      LPort := 443
    else
      LPort := 80;
  end;

  { Establish TCP connection with OS dial budget (H1/H2 client parity). }
  LDialMs := WebSocketEffectiveDialTimeoutMs(AOptions);
  try
    if LDialMs > 0 then
      LConn := TcpConnect(LHost, LPort, LDialMs)
    else
      LConn := TcpConnect(LHost, LPort);
  except
    on E: Exception do
      RaiseWebSocketTransport(E);
  end;
  if LConn = nil then
    raise EHttpError.CreateOp(hekConnect, 'websocket',
      'WebSocket: failed to connect to ' + LHost + ':' + IntToStr(LPort));

  LActive := LConn;
  try
    { Handshake I/O budget: Timeout if set, else ConnectTimeout residual. }
    LHandshakeMs := AOptions.Timeout;
    if LHandshakeMs <= 0 then
      LHandshakeMs := AOptions.ConnectTimeout;
    ApplyWebSocketStreamDeadline(LActive, LHandshakeMs);
    ApplyWebSocketCancelToken(LActive, AOptions.EffectiveCancelToken);

    { Wrap with TLS if wss:// }
    if LScheme = 'wss' then
    begin
      try
        LTlsConn := NewTlsClientTcpStream(LConn, nil, LHost, 'http/1.1');
      except
        on E: Exception do
          RaiseWebSocketTransport(E);
      end;
      LActive := LTlsConn;
      ApplyWebSocketStreamDeadline(LActive, LHandshakeMs);
      ApplyWebSocketCancelToken(LActive, AOptions.EffectiveCancelToken);
      LReader := LTlsConn as IReader;
      LWriter := LTlsConn as IWriter;
    end
    else
    begin
      LReader := LConn as IReader;
      LWriter := LConn as IWriter;
    end;

    { Generate Sec-WebSocket-Key }
    LKey := GenerateWebSocketKey;

    { Build upgrade request }
    LRequest := 'GET ' + LPath + ' HTTP/1.1'#13#10 +
                'Host: ' + LHost;
    if (LScheme = 'ws') and (LPort <> 80) then
      LRequest := LRequest + ':' + IntToStr(LPort)
    else if (LScheme = 'wss') and (LPort <> 443) then
      LRequest := LRequest + ':' + IntToStr(LPort);
    LRequest := LRequest + #13#10 +
                'Upgrade: websocket'#13#10 +
                'Connection: Upgrade'#13#10 +
                'Sec-WebSocket-Key: ' + LKey + #13#10 +
                'Sec-WebSocket-Version: 13'#13#10;
    { Origin header: required by server-side default validation (RFC 6455 §4.1) }
    if LScheme = 'wss' then
      LRequest := LRequest + 'Origin: https://' + LHost + #13#10
    else
      LRequest := LRequest + 'Origin: http://' + LHost + #13#10;
    if AOptions.EnablePermessageDeflate then
      LRequest := LRequest + 'Sec-WebSocket-Extensions: ' +
        WS_PMD_EXTENSION_VALUE + #13#10;
    for LI := 0 to High(AOptions.Headers) do
      LRequest := LRequest + AOptions.Headers[LI].Name + ': ' +
        AOptions.Headers[LI].Value + #13#10;
    LRequest := LRequest + #13#10;

    { Send upgrade request + read response under handshake deadline }
    try
      IoWriteAll(LWriter, LRequest[1], SizeUInt(Length(LRequest)));
      ReadHttpResponse(LReader, LStatusCode, LHeaders);
    except
      on E: Exception do
        RaiseWebSocketTransport(E);
    end;

    { Validate response }
    if LStatusCode <> 101 then
      raise EHttpError.Create(hekUpgrade, 'WebSocket: expected 101, got ' + IntToStr(LStatusCode));

    LUpgrade := LowerCase(FindHeader(LHeaders, 'Upgrade'));
    LConnection := LowerCase(FindHeader(LHeaders, 'Connection'));
    LAcceptHeader := FindHeader(LHeaders, 'Sec-WebSocket-Accept');

    if not HeaderValueHasToken(LUpgrade, 'websocket') then
      raise EHttpError.Create(hekUpgrade, 'WebSocket: invalid Upgrade header');
    if not HeaderValueHasToken(LConnection, 'upgrade') then
      raise EHttpError.Create(hekUpgrade, 'WebSocket: invalid Connection header');
    if LAcceptHeader = '' then
      raise EHttpError.Create(hekUpgrade, 'WebSocket: missing Sec-WebSocket-Accept header');

    { Validate Accept key }
    if not ValidateAcceptKey(LKey, LAcceptHeader) then
      raise EHttpError.Create(hekUpgrade, 'WebSocket: invalid Sec-WebSocket-Accept');

    LDeflate := False;
    if AOptions.EnablePermessageDeflate then
    begin
      LExtHeader := FindHeader(LHeaders, 'Sec-WebSocket-Extensions');
      LDeflate := HeaderOffersPermessageDeflate(LExtHeader);
    end;

    { Post-handshake: clear connect/handshake deadlines for long-lived frames.
      Keep CancelToken on the stream for mid-frame cooperative cancel. }
    ClearWebSocketStreamDeadline(LActive);

    { Create WebSocket client; ownership of LActive transferred into IWebSocket. }
    Result := TWebSocketImpl.Create(LReader, LWriter, AOptions, True, LActive,
      LDeflate);
    LActive := nil;
    LConn := nil;
    LTlsConn := nil;
  except
    if LActive <> nil then
    begin
      ClearWebSocketCancelToken(LActive);
      LActive.Close;
    end
    else if LConn <> nil then
    begin
      ClearWebSocketCancelToken(LConn);
      LConn.Close;
    end;
    raise;
  end;
end;

initialization
  Randomize;

end.

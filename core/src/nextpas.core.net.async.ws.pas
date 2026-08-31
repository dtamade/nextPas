unit nextpas.core.net.async.ws;
{**
 * Async WebSocket (RFC 6455) CLIENT session over TAsyncLoop — composes on
 * any IAsyncTcpStream (raw TCP or TLS alike), zero threads, zero blocking
 * syscalls on the loop thread. Frame encode/decode reuses the shared
 * role-aware codec (nextpas.core.net.server.ws.frame) — this unit adds the
 * HTTP/1.1 Upgrade handshake and the always-on session pump.
 *
 * CONTRACT:
 * - AsyncWsUpgrade performs the client handshake on an existing connected
 *   stream. Fail-closed: anything other than «HTTP/1.x 101» with a valid
 *   Sec-WebSocket-Accept (base64(SHA1(key+GUID))) delivers nil + negative
 *   code; nothing half-open escapes. Bytes after the header block are fed
 *   straight into the frame decoder (server may start frames immediately).
 * - Options.Host is REQUIRED (HTTP/1.1); empty host or a Path/Host
 *   containing CR/LF/space (header-injection guards) fails synchronously
 *   with False and no callback. Path must start with '/'.
 * - Data plane: each AsyncWrite emits one or more masked BINARY frames
 *   (chunked at cWsWriteChunk); completion fires when every byte of the op
 *   has been flushed (absolute-offset accounting; control frames injected
 *   behind the op's bytes never delay its completion). Reads deliver
 *   MESSAGE bytes; fragmented messages accumulate and are delivered once,
 *   complete (the shared decoder yields intermediate fragments AND a
 *   terminal aggregate — this unit owns the dedup, consumers see each byte
 *   exactly once).
 * - Control plane is serviced even when the app never reads: the receive
 *   side stays armed after the handshake; ping → auto-pong (payload echoed),
 *   pong → ignored, close → EOF(0) plus one best-effort echo-close.
 *   Underlying EOF/errors surface on whichever direction is pending.
 * - Not supported (fail-closed): permessage-deflate (codec rejects RSV1),
 *   early-data (Sec-WebSocket-Protocol trick), server role.
 *
 * Error codes: 0 ok; ASYNC_WS_ERR_IO underlying stream / submit failure;
 * ASYNC_WS_ERR_HANDSHAKE upgrade protocol failure; ASYNC_WS_ERR_PROTOCOL
 * post-handshake RFC violation (frame sequencing, oversize, UTF-8).
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base, nextpas.core.time.deadline,
  nextpas.core.async.base, nextpas.core.async.loop,
  nextpas.core.async.cancellation,
  nextpas.core.net.base, nextpas.core.net.intf,
  nextpas.core.net.async.tcp;

const
  { 底层流读写/提交失败、对端在挂起期间断开 }
  ASYNC_WS_ERR_IO = -3101;
  { 升级握手失败：非 101、Accept 校验不过、响应畸形 }
  ASYNC_WS_ERR_HANDSHAKE = -3102;
  { 升级后 RFC 违例：帧序、超限、UTF-8 }
  ASYNC_WS_ERR_PROTOCOL = -3103;

type
  { 异步 WS 客户端选项。Host 必填；Path 缺省 '/'。
    HandshakeDeadline 覆盖升级全程；Infinite = 不设超时。 }
  TAsyncWsOptions = record
    Path: string;
    Host: string;
    HandshakeDeadline: TDeadline;
  end;

function DefaultAsyncWsOptions: TAsyncWsOptions;

type
  { 异步升级完成回调：AError=0 时 AStream 为就绪 WS 流；
    失败时 AStream=nil 且 AError<0。事件循环线程回调，一次。 }
  TAsyncWsConnectCallback = procedure(AStream: IAsyncTcpStream;
    AError: Int32; AContext: Pointer);

{ 在既有已连接流上做非阻塞 WS 客户端升级。
  False = 同步校验失败且不回调；True = 结果经回调交付（可能同步）。
  提交成功后 AStream 所有权移交内部状态机，调用方不得再使用。 }
function AsyncWsUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncWsOptions;
  ACallback: TAsyncWsConnectCallback; AContext: Pointer = nil): Boolean;

implementation

uses
  nextpas.core.base,
  nextpas.core.io.base, nextpas.core.io.intf,
  nextpas.core.text.conv,
  nextpas.core.hash.sha1,
  nextpas.core.tls.base64,
  nextpas.core.tls.random,
  nextpas.core.websocket.base,
  nextpas.core.net.server.ws.frame;

const
  { 网络侧单次收发缓冲 }
  cWsNetBufSize = 16384;
  { 单个出站帧载荷上限：relay 写粒度 ~16KB，64KB 摊薄帧头足够，
    且避免单帧巨分配（BuildFrame 会拷贝掩码载荷） }
  cWsWriteChunk = 65536;
  { 升级响应头上限：畸形服务器无限头直接失败 }
  cWsMaxResponseHeader = 16384;

  cWsGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

{ ======== 选项与工具 ======== }

function DefaultAsyncWsOptions: TAsyncWsOptions;
begin
  Result.Path := '/';
  Result.Host := '';
  Result.HandshakeDeadline := TDeadline.Infinite;
end;

{ 头注入守卫：CR/LF/空格一律拒绝（Host 值不含空格；路径含空格同样拒绝） }
function WsHeaderTokenSafe(const AValue: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AValue = '' then
    Exit;
  for I := 1 to Length(AValue) do
    if (AValue[I] = #13) or (AValue[I] = #10) or (AValue[I] = ' ') then
      Exit;
  Result := True;
end;

function WsBuildAcceptKey(const AClientKeyB64: string): string;
var
  LHasher: TSHA1Hasher;
  LKeyPart: AnsiString;
  LGuid: AnsiString;
  LSum: TBytes;
begin
  LHasher := TSHA1Hasher.Create;
  try
    LKeyPart := AnsiString(AClientKeyB64);
    LGuid := AnsiString(cWsGuid);
    if Length(LKeyPart) > 0 then
      LHasher.Write(LKeyPart[1], SizeUInt(Length(LKeyPart)));
    if Length(LGuid) > 0 then
      LHasher.Write(LGuid[1], SizeUInt(Length(LGuid)));
    LSum := LHasher.SumBytes;
  finally
    LHasher.Free;
  end;
  Result := TBase64Utils.Encode(LSum);
end;

{ ======== 握手上下文 ======== }

type
  PWsHsCtx = ^TWsHsCtx;
  TWsHsCtx = record
    Loop: TAsyncLoop;
    Stream: IAsyncTcpStream;
    { 流面收发（内层可为 TLS 变换流：裸 fd 收发会绕过记录层明文走私）；
      握手 deadline 经显式定时器收敛（流面 AsyncReadTimeout 接受不强制） }
    Timer: TAsyncTimerHandle;
    Request: TBytes;
    ReqOff: Integer;
    RspBuf: array[0..cWsMaxResponseHeader - 1] of Byte;
    RspHave: Integer;
    ExpectAccept: string;
    OnReady: TAsyncWsConnectCallback;
    OnReadyCtx: Pointer;
    Deadline: TDeadline;
    SendArmed: Boolean;
    RecvArmed: Boolean;
    Finished: Boolean;
  end;

  TAsyncWsStream = class;

procedure WsHsRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure WsHsFail(ACtx: PWsHsCtx; AErr: Int32); forward;
procedure WsHandshakeStep(ACtx: PWsHsCtx); forward;
procedure WsHandshakeDone(ACtx: PWsHsCtx; const ALeftover: TBytes); forward;

procedure WsHsCancelTimer(ACtx: PWsHsCtx);
begin
  if (ACtx <> nil) and (ACtx^.Loop <> nil) and ACtx^.Timer.IsValid then
  begin
    ACtx^.Loop.CancelTimer(ACtx^.Timer);
    ACtx^.Timer := TAsyncTimerHandle.None;
  end;
end;

procedure WsHsFailSilent(ACtx: PWsHsCtx);
begin
  if ACtx = nil then
    Exit;
  ACtx^.Finished := True;
  WsHsCancelTimer(ACtx);
  ACtx^.Stream := nil;
  ACtx^.Loop := nil;
  Dispose(ACtx);
end;

{ 握手 deadline 定时器：到点未完成 = 超时失败（流面读无原生超时） }
procedure WsHsTimerCb(AContext: Pointer); forward;

procedure WsHsTimerCb(AContext: Pointer);
var
  LCtx: PWsHsCtx;
begin
  LCtx := PWsHsCtx(AContext);
  if (LCtx = nil) or LCtx^.Finished then
    Exit;
  LCtx^.Timer := TAsyncTimerHandle.None;
  WsHsFail(LCtx, ASYNC_WS_ERR_IO);
end;

procedure WsHsFail(ACtx: PWsHsCtx; AErr: Int32);
var
  LCb: TAsyncWsConnectCallback;
  LCbCtx: Pointer;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  if Assigned(LCb) then
    LCb(nil, AErr, LCbCtx);
  WsHsFailSilent(ACtx);
end;

function WsHsArmRecv(ACtx: PWsHsCtx): Boolean;
var
  LSpace: UInt32;
begin
  if ACtx^.RecvArmed then
    Exit(True);
  { 按缓冲剩余空间收，防越界；无空间时由调用方的满溢守卫收敛 }
  LSpace := UInt32(cWsMaxResponseHeader - ACtx^.RspHave);
  if LSpace = 0 then
    Exit(False);
  if LSpace > cWsNetBufSize then
    LSpace := cWsNetBufSize;
  ACtx^.RecvArmed := True;
  Result := ACtx^.Stream.AsyncRead(@ACtx^.RspBuf[ACtx^.RspHave], LSpace,
    @WsHsRecvCb, ACtx);
  if not Result then
    ACtx^.RecvArmed := False;
end;

procedure WsHsRecvCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PWsHsCtx;
begin
  LCtx := PWsHsCtx(AContext);
  if LCtx = nil then
    Exit;
  LCtx^.RecvArmed := False;
  if AResult <= 0 then
  begin
    WsHsFail(LCtx, ASYNC_WS_ERR_IO);
    Exit;
  end;
  Inc(LCtx^.RspHave, AResult);
  WsHandshakeStep(LCtx);
end;

procedure WsHsSendCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LCtx: PWsHsCtx;
begin
  LCtx := PWsHsCtx(AContext);
  if LCtx = nil then
    Exit;
  LCtx^.SendArmed := False;
  if AResult < 0 then
  begin
    WsHsFail(LCtx, ASYNC_WS_ERR_IO);
    Exit;
  end;
  Inc(LCtx^.ReqOff, AResult);
  WsHandshakeStep(LCtx);
end;

{ 字节级找 \r\n\r\n，返回其起始下标；无则 -1 }
function WsFindHeaderEnd(const ABuf: array of Byte; AHave: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if AHave < 4 then
    Exit;
  for I := 0 to AHave - 4 do
    if (ABuf[I] = 13) and (ABuf[I + 1] = 10) and
       (ABuf[I + 2] = 13) and (ABuf[I + 3] = 10) then
      Exit(I);
end;

{ 从响应缓冲解析并校验状态行与 Sec-WebSocket-Accept；
  成功（=101 且 Accept 值与本地期望逐字节一致）时 AAccept 带出头部值。
  失败返回 False。 }
function WsValidateResponse(const ABuf: array of Byte; AHeaderEnd: Integer;
  const AExpectAccept: string; out AAccept: string): Boolean;
var
  I, J, LLineStart, LColon: Integer;
  LB: Byte;
  LNameBuf: array[0..31] of AnsiChar;
  LNameLen: Integer;
const
  CName = 'sec-websocket-accept';
begin
  Result := False;
  AAccept := '';

  { 状态行：「HTTP/1.x 101」（x 任一；码后必须空格或行尾）。
    偏移：版本 "HTTP/1.x" 占 0..7，空格 8，状态码 9..11 }
  if AHeaderEnd < 13 then
    Exit;
  for I := 1 to 7 do
  begin
    LB := ABuf[I - 1];
    if I = 1 then
    begin
      if LB <> Ord('H') then
        Exit;
    end
    else if I = 2 then
    begin
      if LB <> Ord('T') then
        Exit;
    end
    else if I = 3 then
    begin
      if LB <> Ord('T') then
        Exit;
    end
    else if I = 4 then
    begin
      if LB <> Ord('P') then
        Exit;
    end
    else if I = 5 then
    begin
      if LB <> Ord('/') then
        Exit;
    end
    else if I = 6 then
    begin
      if LB <> Ord('1') then
        Exit;
    end
    else if LB <> Ord('.') then
      Exit;
  end;
  { 第 8 字节必须空格；第 9..11 字节（0 基）= 状态码三位 }
  if ABuf[8] <> Ord(' ') then
    Exit;
  if (ABuf[9] <> Ord('1')) or (ABuf[10] <> Ord('0')) or
     (ABuf[11] <> Ord('1')) then
    Exit;
  if (ABuf[12] <> Ord(' ')) and (ABuf[12] <> 13) then
    Exit;

  { 逐头扫描（大小写不敏感），取 sec-websocket-accept 值 }
  LNameLen := Length(CName);
  { 名字段扫描起点：跳过状态行（HTTP/1.x 101 …\r\n），从其 \n 后一行起 }
  I := 12;
  while (I < AHeaderEnd) and (ABuf[I] <> 10) do
    Inc(I);
  Inc(I);
  while I < AHeaderEnd do
  begin
    LLineStart := I;
    { 行尾 }
    while (I < AHeaderEnd) and (ABuf[I] <> 13) do
      Inc(I);
    { 名字段：冒号前 }
    LColon := -1;
    for J := LLineStart to I - 1 do
      if ABuf[J] = Ord(':') then
      begin
        LColon := J;
        Break;
      end;
    if LColon >= 0 then
    begin
      { 名字段等长才可能是目标名（缓冲 32 字节 > 20，恒安全） }
      if LColon - LLineStart = LNameLen then
      begin
        FillChar(LNameBuf, SizeOf(LNameBuf), 0);
        for J := 0 to LColon - LLineStart - 1 do
        begin
          LB := ABuf[LLineStart + J];
          if (LB >= Ord('A')) and (LB <= Ord('Z')) then
            LB := LB + (Ord('a') - Ord('A'));
          LNameBuf[J] := AnsiChar(LB);
        end;
        if string(LNameBuf) = CName then
        begin
          { 值：冒号后跳一个空格，到行尾（去尾随空白） }
          J := LColon + 1;
          if (J < I) and (ABuf[J] = Ord(' ')) then
            Inc(J);
          while (I - 1 >= J) and ((ABuf[I - 1] = Ord(' ')) or
            (ABuf[I - 1] = 9)) do
            Dec(I);
          if I < J then
            Exit;
          SetLength(AAccept, I - J);
          for LLineStart := J to I - 1 do
            AAccept[LLineStart - J + 1] := Chr(ABuf[LLineStart]);
          { RFC 6455 §4.2.2：Accept 必须与本地期望逐字节一致（base64
            大小写敏感），不匹配即握手失败 }
          Exit(AAccept = AExpectAccept);
        end;
      end;
    end;
    I := I + 2; { 跳过 \r\n }
  end;
end;

procedure WsHandshakeStep(ACtx: PWsHsCtx);
var
  LRet: Integer;
  LHeaderEnd: Integer;
  LAccept: string;
  LLeftover: TBytes;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;

  if ACtx^.ReqOff < Length(ACtx^.Request) then
  begin
    if ACtx^.SendArmed then
      Exit;
    ACtx^.SendArmed := True;
    if not ACtx^.Stream.AsyncWrite(@ACtx^.Request[ACtx^.ReqOff],
      UInt32(Length(ACtx^.Request) - ACtx^.ReqOff), @WsHsSendCb, ACtx) then
    begin
      ACtx^.SendArmed := False;
      WsHsFail(ACtx, ASYNC_WS_ERR_IO);
    end;
    Exit;
  end;

  LHeaderEnd := WsFindHeaderEnd(ACtx^.RspBuf, ACtx^.RspHave);
  if LHeaderEnd >= 0 then
  begin
    if not WsValidateResponse(ACtx^.RspBuf, LHeaderEnd, ACtx^.ExpectAccept,
      LAccept) then
    begin
      WsHsFail(ACtx, ASYNC_WS_ERR_HANDSHAKE);
      Exit;
    end;
    LLeftover := nil;
    if ACtx^.RspHave > LHeaderEnd + 4 then
    begin
      SetLength(LLeftover, ACtx^.RspHave - LHeaderEnd - 4);
      Move(ACtx^.RspBuf[LHeaderEnd + 4], LLeftover[0],
        SizeUInt(Length(LLeftover)));
    end;
    { 会话接管：完成回调在 StartPump 之后触发，保证就绪即用 }
    WsHandshakeDone(ACtx, LLeftover);
    Exit;
  end;

  { 头块超出缓冲仍未终结 = 畸形服务器 }
  if ACtx^.RspHave >= cWsMaxResponseHeader then
  begin
    WsHsFail(ACtx, ASYNC_WS_ERR_HANDSHAKE);
    Exit;
  end;
  if not WsHsArmRecv(ACtx) then
    WsHsFail(ACtx, ASYNC_WS_ERR_IO);
end;

function AsyncWsUpgrade(const ALoop: TAsyncLoop;
  const AStream: IAsyncTcpStream; const AOptions: TAsyncWsOptions;
  ACallback: TAsyncWsConnectCallback; AContext: Pointer): Boolean;
var
  LPath, LHost, LKeyB64: string;
  LReq: AnsiString;
  LCtx: PWsHsCtx;

  procedure AppendLine(const ALine: string);
  var
    LL: AnsiString;
    LOld: Integer;
  begin
    LL := AnsiString(ALine) + #13#10;
    LOld := Length(LReq);
    SetLength(LReq, LOld + Length(LL));
    if Length(LL) > 0 then
      Move(LL[1], LReq[LOld + 1], SizeUInt(Length(LL)));
  end;

begin
  Result := False;
  { 同步 fail-closed 面：参数/守卫不过不回调 }
  if (AStream = nil) or not Assigned(ACallback) then
    Exit;
  LPath := Trim(AOptions.Path);
  LHost := Trim(AOptions.Host);
  if LPath = '' then
    LPath := '/';
  if (LHost = '') or (LPath[1] <> '/') then
    Exit;
  { 头注入守卫：CR/LF/空格一律拒绝 }
  if (not WsHeaderTokenSafe(LPath)) or (not WsHeaderTokenSafe(LHost)) then
    Exit;

  LKeyB64 := TBase64Utils.Encode(GenerateSecureRandomBytes(16));

  LReq := '';
  AppendLine('GET ' + LPath + ' HTTP/1.1');
  AppendLine('Host: ' + LHost);
  AppendLine('Upgrade: websocket');
  AppendLine('Connection: Upgrade');
  AppendLine('Sec-WebSocket-Key: ' + LKeyB64);
  AppendLine('Sec-WebSocket-Version: 13');
  AppendLine('');

  LCtx := New(PWsHsCtx);
  LCtx^.Loop := ALoop;
  LCtx^.Stream := AStream;
  LCtx^.Timer := TAsyncTimerHandle.None;
  if not AOptions.HandshakeDeadline.IsInfinite then
    LCtx^.Timer := ALoop.Schedule(AOptions.HandshakeDeadline.Remaining,
      @WsHsTimerCb, LCtx);
  SetLength(LCtx^.Request, Length(LReq));
  if Length(LReq) > 0 then
    Move(LReq[1], LCtx^.Request[0], SizeUInt(Length(LReq)));
  LCtx^.ReqOff := 0;
  LCtx^.RspHave := 0;
  LCtx^.ExpectAccept := WsBuildAcceptKey(LKeyB64);
  LCtx^.OnReady := ACallback;
  LCtx^.OnReadyCtx := AContext;
  LCtx^.Deadline := AOptions.HandshakeDeadline;
  LCtx^.SendArmed := False;
  LCtx^.RecvArmed := False;
  LCtx^.Finished := False;

  { 状态机一旦接手，结果一律经回调交付（含提交即败的同步失败路径，
    见单元头契约——与 AsyncTlsConnect 同款「不双交」语义） }
  WsHandshakeStep(LCtx);
  Result := True;
end;

{ ======== WS 流会话 ======== }

procedure WsRecvCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure WsSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;

type
  PWsPart = ^TWsPart;
  TWsPart = record
    Data: TBytes;
    Next: PWsPart;
  end;

  TAsyncWsStream = class(TInterfacedObject, IReader, IWriter,
    IReadWriteCloser, ITcpStream, ITcpSocketRuntime, ITcpStreamRuntime,
    IAsyncTcpStream)
  private
    FLoop: TAsyncLoop;
    FUnderlying: IAsyncTcpStream;
    FDecoder: TNetWsFrameDecoder;
    FRxBuf: array[0..cWsNetBufSize - 1] of Byte;
    { 出站 FIFO + 绝对偏移记账：写完成 = 冲刷量越过本 op 终点，
      控制帧（pong/close）排在本 op 字节之后永不阻塞其完成 }
    FOutHead: PWsPart;
    FOutTail: PWsPart;
    FHeadOff: Integer;
    FOutEnqueued: Int64;
    FOutFlushed: Int64;
    FOpEndOffset: Int64;
    FWriteTotal: Integer;
    FSendArmed: Boolean;
    FRecvArmed: Boolean;
    FFlushPumping: Boolean;
    FClosedByPeer: Boolean;
    FSentClose: Boolean;
    FEofDelivered: Boolean;
    FDead: Boolean;
    { 会话失败码：死亡后补提交的读按此收敛（0 = 干净关闭 → EOF） }
    FFailCode: Int32;
    { 分片状态：仅作违例判定（聚合由共享编解码器完成，见 HandleFrame） }
    FMsgOpen: Boolean;
    { 入站载荷队列 }
    FInHead: PWsPart;
    FInTail: PWsPart;
    FInHeadOff: Integer;
    FInTotal: SizeUInt;
    { 读/写挂起（单槽） }
    FReadBuf: Pointer;
    FReadLen: UInt32;
    FReadCb: TIoCompletion;
    FReadCbCtx: Pointer;
    FWriteCb: TIoCompletion;
    FWriteCbCtx: Pointer;
    procedure EnqueueWire(const AData: TBytes);
    procedure EnqueuePong(const APingPayload: TBytes);
    procedure EnqueueCloseReply(ACode: UInt16);
    procedure EnqueueIn(const AData: TBytes);
    procedure ArmRecv;
    procedure TryFlush;
    procedure RouteFrames;
    procedure HandleFrame(var AFrame: TNetWsFrame);
    function TryServeRead: Boolean;
    procedure DeliverRead(AResult: Int32);
    procedure DeliverWrite(AResult: Int32);
    procedure FailSession(AErr: Int32);
  public
    constructor Create(const AUnderlying: IAsyncTcpStream; ALoop: TAsyncLoop);
    destructor Destroy; override;
    procedure AdoptDecoderFeed(const ALeftover: TBytes);
    procedure StartPump;
    { IReader }
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    { IWriter }
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    { IReadWriteCloser }
    procedure Close;
    { ITcpStream }
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
    procedure BindCancelToken(const AToken: IAsyncCancellationToken);
    { ITcpSocketRuntime }
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    { ITcpStreamRuntime }
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
    { IAsyncTcpStream }
    function AsyncRead(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncReadRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncWrite(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
      ACallback: TIoCompletionRef; AContext: Pointer = nil): Boolean;
    function AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
    function AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
      const ADeadline: TDeadline; ACallback: TIoCompletion;
      AContext: Pointer = nil): Boolean;
  end;

procedure WsHandshakeDone(ACtx: PWsHsCtx; const ALeftover: TBytes);
var
  LSess: TAsyncWsStream;
  LCb: TAsyncWsConnectCallback;
  LCbCtx: Pointer;
begin
  if (ACtx = nil) or ACtx^.Finished then
    Exit;
  ACtx^.Finished := True;
  LSess := TAsyncWsStream.Create(ACtx^.Stream, ACtx^.Loop);
  LSess.AdoptDecoderFeed(ALeftover);
  ACtx^.Stream := nil;
  LCb := ACtx^.OnReady;
  LCbCtx := ACtx^.OnReadyCtx;
  WsHsFailSilent(ACtx);
  LSess.StartPump;
  if Assigned(LCb) then
    LCb(LSess as IAsyncTcpStream, 0, LCbCtx);
end;

{ ======== TAsyncWsStream ======== }

constructor TAsyncWsStream.Create(const AUnderlying: IAsyncTcpStream;
  ALoop: TAsyncLoop);
begin
  inherited Create;
  FDecoder := TNetWsFrameDecoder.Create(True);
  FUnderlying := AUnderlying;
  FLoop := ALoop;
end;

destructor TAsyncWsStream.Destroy;
var
  LP, LN: PWsPart;
begin
  LP := FOutHead;
  while LP <> nil do
  begin
    LN := LP^.Next;
    Dispose(LP);
    LP := LN;
  end;
  LP := FInHead;
  while LP <> nil do
  begin
    LN := LP^.Next;
    Dispose(LP);
    LP := LN;
  end;
  FUnderlying := nil;
  FLoop := nil;
  inherited Destroy;
end;

procedure TAsyncWsStream.AdoptDecoderFeed(const ALeftover: TBytes);
begin
  if (ALeftover <> nil) and (Length(ALeftover) > 0) then
  begin
    FDecoder.Feed(@ALeftover[0], SizeUInt(Length(ALeftover)));
    RouteFrames;
  end;
end;

procedure TAsyncWsStream.StartPump;
begin
  ArmRecv;
  TryFlush;
end;

{ ---- 出站 ---- }

procedure TAsyncWsStream.EnqueueWire(const AData: TBytes);
var
  LPart: PWsPart;
begin
  New(LPart);
  LPart^.Data := AData;
  LPart^.Next := nil;
  if FOutTail <> nil then
    FOutTail^.Next := LPart
  else
    FOutHead := LPart;
  FOutTail := LPart;
  FOutEnqueued := FOutEnqueued + Length(AData);
end;

procedure TAsyncWsStream.EnqueueIn(const AData: TBytes);
var
  LPart: PWsPart;
begin
  New(LPart);
  LPart^.Data := AData;
  LPart^.Next := nil;
  if FInTail <> nil then
    FInTail^.Next := LPart
  else
    FInHead := LPart;
  FInTail := LPart;
  FInTotal := FInTotal + SizeUInt(Length(AData));
end;

procedure TAsyncWsStream.EnqueuePong(const APingPayload: TBytes);
var
  LWire: TBytes;
begin
  if TNetWsFrameEncoder.BuildFrame(Byte(WS_OPCODE_PONG), True,
    APingPayload, nwsClient, LWire) = nwsEncodeOk then
    EnqueueWire(LWire);
end;

procedure TAsyncWsStream.EnqueueCloseReply(ACode: UInt16);
var
  LWire: TBytes;
begin
  if FSentClose then
    Exit;
  FSentClose := True;
  if TNetWsFrameEncoder.BuildCloseFrame(ACode, '', nwsClient, LWire) =
    nwsEncodeOk then
    EnqueueWire(LWire);
end;

procedure TAsyncWsStream.FailSession(AErr: Int32);
begin
  if FDead then
    Exit;
  FDead := True;
  FFailCode := AErr;
  if Assigned(FReadCb) then
    DeliverRead(AErr);
  if Assigned(FWriteCb) then
    DeliverWrite(AErr);
end;

procedure TAsyncWsStream.TryFlush;
var
  LLeft: UInt32;
begin
  if FFlushPumping then
    Exit;
  FFlushPumping := True;
  try
    while (not FSendArmed) and (not FDead) and (FOutHead <> nil) do
    begin
      LLeft := UInt32(Length(FOutHead^.Data) - FHeadOff);
      FSendArmed := True;
      if not FUnderlying.AsyncWrite(@FOutHead^.Data[FHeadOff], LLeft,
        @WsSendCb, Self) then
      begin
        FSendArmed := False;
        FailSession(ASYNC_WS_ERR_IO);
        Break;
      end;
    end;
  finally
    FFlushPumping := False;
  end;
end;

procedure WsSendCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LS: TAsyncWsStream;
  LDone: PWsPart;
begin
  LS := TAsyncWsStream(AContext);
  if LS = nil then
    Exit;
  LS.FSendArmed := False;
  if AResult <= 0 then
  begin
    { 底层发送失败/断开：会话整体失败，挂起的读写各自收敛 }
    LS.FailSession(ASYNC_WS_ERR_IO);
    Exit;
  end;
  LS.FOutFlushed := LS.FOutFlushed + AResult;
  LS.FHeadOff := LS.FHeadOff + AResult;
  if LS.FOutHead <> nil then
  begin
    while (LS.FOutHead <> nil) and (LS.FHeadOff >= Length(LS.FOutHead^.Data)) do
    begin
      LDone := LS.FOutHead;
      LS.FHeadOff := LS.FHeadOff - Length(LDone^.Data);
      LS.FOutHead := LDone^.Next;
      if LS.FOutHead = nil then
        LS.FOutTail := nil;
      Dispose(LDone);
    end;
  end;
  { 写 op 完成：冲刷越过本 op 终点（控制帧排在其后不构成延迟） }
  if Assigned(LS.FWriteCb) and (LS.FOutFlushed >= LS.FOpEndOffset) then
    LS.DeliverWrite(LS.FWriteTotal);
  LS.TryFlush;
end;

{ ---- 入站 ---- }

procedure TAsyncWsStream.ArmRecv;
begin
  if FRecvArmed or FDead then
    Exit;
  FRecvArmed := True;
  { 流面收（内层可为 TLS 变换流） }
  if not FUnderlying.AsyncRead(@FRxBuf[0], cWsNetBufSize, @WsRecvCb, Self)
  then
    FRecvArmed := False;
end;

procedure WsRecvCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LS: TAsyncWsStream;
begin
  LS := TAsyncWsStream(AContext);
  if LS = nil then
    Exit;
  LS.FRecvArmed := False;
  if LS.FDead then
    Exit;
  if AResult < 0 then
  begin
    LS.FailSession(ASYNC_WS_ERR_IO);
    Exit;
  end;
  if AResult = 0 then
  begin
    { 对端断开：读方向按 EOF 收敛；写挂起按 IO 错误收敛 }
    if not LS.FEofDelivered then
    begin
      LS.FEofDelivered := True;
      if Assigned(LS.FReadCb) then
        LS.DeliverRead(0);
    end;
    if Assigned(LS.FWriteCb) then
      LS.DeliverWrite(ASYNC_WS_ERR_IO);
    LS.FDead := True;
    Exit;
  end;
  LS.FDecoder.Feed(@LS.FRxBuf[0], SizeUInt(AResult));
  LS.RouteFrames;
  LS.ArmRecv;
end;

procedure TAsyncWsStream.RouteFrames;
var
  LFrame: TNetWsFrame;
  LCode: TNetWsDecodeCode;
begin
  while not FDead do
  begin
    LCode := FDecoder.TryDecode(LFrame);
    case LCode of
      nwsDecodeFrame:
        HandleFrame(LFrame);
      nwsDecodeNeedMore:
        Break;
      nwsDecodeClosed:
        begin
          FClosedByPeer := True;
          Break;
        end;
      nwsDecodeProtocolError,
      nwsDecodeTooLarge:
        begin
          FailSession(ASYNC_WS_ERR_PROTOCOL);
          Break;
        end;
    end;
  end;
end;

procedure TAsyncWsStream.HandleFrame(var AFrame: TNetWsFrame);
begin
  if AFrame.Opcode = Byte(WS_OPCODE_PING) then
  begin
    EnqueuePong(AFrame.Payload);
    TryFlush;
    Exit;
  end;
  if AFrame.Opcode = Byte(WS_OPCODE_PONG) then
    Exit;
  if AFrame.Opcode = Byte(WS_OPCODE_CLOSE) then
  begin
    FClosedByPeer := True;
    if AFrame.CloseCode <> 0 then
      EnqueueCloseReply(AFrame.CloseCode)
    else
      EnqueueCloseReply(1000);
    TryFlush;
    { 读方向 EOF 一次；写挂起按 IO 收敛（协议已关闭） }
    if not FEofDelivered then
    begin
      FEofDelivered := True;
      if Assigned(FReadCb) then
        DeliverRead(0);
    end;
    if Assigned(FWriteCb) then
      DeliverWrite(ASYNC_WS_ERR_IO);
    Exit;
  end;

  { 数据帧（TEXT/BINARY/CONTINUATION）。共享编解码器契约：非终片原样
    产出（Fin=False），终片产出聚合后的完整消息（Opcode 复原、Fin=True）
    ——每字节只随终帧到达一次，此处直接交付聚合；分片状态仅用于
    违例判定（无 open 却收到 CONTINUATION 终帧 = 对端违例，fail-closed）。 }
  if AFrame.Fin then
  begin
    if (not FMsgOpen) and
       (AFrame.Opcode = Byte(WS_OPCODE_CONTINUATION)) then
    begin
      FailSession(ASYNC_WS_ERR_PROTOCOL);
      Exit;
    end;
    FMsgOpen := False;
    EnqueueIn(AFrame.Payload);
    TryServeRead;
  end
  else
  begin
    if (AFrame.Opcode <> Byte(WS_OPCODE_TEXT)) and
       (AFrame.Opcode <> Byte(WS_OPCODE_BINARY)) and
       (AFrame.Opcode <> Byte(WS_OPCODE_CONTINUATION)) then
    begin
      FailSession(ASYNC_WS_ERR_PROTOCOL);
      Exit;
    end;
    FMsgOpen := True;
  end;
end;

{ 把入站队列数据搬进取读缓冲；≥1 字节即完成本拍读（短读契约，
  与底层 AsyncRead 一致）。指针推进只在有交付时回写。 }
function TAsyncWsStream.TryServeRead: Boolean;
var
  LN: SizeUInt;
  LDelivered: UInt32;
  LDst: PByte;
  LDonePart: PWsPart;
begin
  Result := False;
  LDelivered := 0;
  if not Assigned(FReadCb) then
    Exit;
  LDst := PByte(FReadBuf);
  while (FInHead <> nil) and (LDelivered < FReadLen) do
  begin
    LN := SizeUInt(Length(FInHead^.Data)) - SizeUInt(FInHeadOff);
    if LN > SizeUInt(FReadLen) - SizeUInt(LDelivered) then
      LN := SizeUInt(FReadLen) - SizeUInt(LDelivered);
    if LN > 0 then
    begin
      Move(FInHead^.Data[FInHeadOff], LDst^, LN);
      LDst := LDst + LN;
      FInHeadOff := FInHeadOff + Integer(LN);
      LDelivered := LDelivered + UInt32(LN);
    end;
    if FInHeadOff >= Length(FInHead^.Data) then
    begin
      LDonePart := FInHead;
      FInHead := LDonePart^.Next;
      if FInHead = nil then
        FInTail := nil;
      FInHeadOff := 0;
      Dispose(LDonePart);
    end;
  end;
  if LDelivered > 0 then
  begin
    FReadBuf := LDst;
    FReadLen := FReadLen - LDelivered;
    FInTotal := FInTotal - LDelivered;
    Result := True;
    DeliverRead(Int32(LDelivered));
  end;
end;

procedure TAsyncWsStream.DeliverRead(AResult: Int32);
var
  LCb: TIoCompletion;
  LCtx: Pointer;
begin
  LCb := FReadCb;
  LCtx := FReadCbCtx;
  FReadCb := nil;
  FReadCbCtx := nil;
  if Assigned(LCb) then
    LCb(0, AResult, LCtx);
end;

procedure TAsyncWsStream.DeliverWrite(AResult: Int32);
var
  LCb: TIoCompletion;
  LCtx: Pointer;
begin
  LCb := FWriteCb;
  LCtx := FWriteCbCtx;
  FWriteCb := nil;
  FWriteCbCtx := nil;
  if Assigned(LCb) then
    LCb(0, AResult, LCtx);
end;

{ ---- ITcpStream 委托底层流 ---- }

function TAsyncWsStream.LocalAddr: TNetAddress;
begin
  if FUnderlying <> nil then
    Result := FUnderlying.LocalAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function TAsyncWsStream.RemoteAddr: TNetAddress;
begin
  if FUnderlying <> nil then
    Result := FUnderlying.RemoteAddr
  else
    FillChar(Result, SizeOf(Result), 0);
end;

procedure TAsyncWsStream.Shutdown;
begin
  EnqueueCloseReply(1000);
  TryFlush;
end;

procedure TAsyncWsStream.SetNoDelay(const AValue: Boolean);
begin
  if FUnderlying <> nil then
    FUnderlying.SetNoDelay(AValue);
end;

procedure TAsyncWsStream.SetKeepAlive(const AValue: Boolean);
begin
  if FUnderlying <> nil then
    FUnderlying.SetKeepAlive(AValue);
end;

procedure TAsyncWsStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  { 数据面 deadline 接受不强制：WS 收泵常驻，读完成由消息边界驱动 }
end;

procedure TAsyncWsStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  { 数据面 deadline 接受不强制（见单元头契约） }
end;

procedure TAsyncWsStream.SetCancelToken(const AToken: INetCancelToken);
begin
  if FUnderlying <> nil then
    FUnderlying.SetCancelToken(AToken);
end;

procedure TAsyncWsStream.BindCancelToken(
  const AToken: IAsyncCancellationToken);
begin
  if FUnderlying <> nil then
    FUnderlying.BindCancelToken(AToken);
end;

function TAsyncWsStream.NativeSocketHandle: PtrUInt;
begin
  if FUnderlying <> nil then
    Result := (FUnderlying as ITcpSocketRuntime).NativeSocketHandle
  else
    Result := 0;
end;

procedure TAsyncWsStream.SetBlocking(const ABlocking: Boolean);
begin
  { 底层流本就非阻塞；no-op }
end;

{ ---- 同步便捷面 ---- }

function TAsyncWsStream.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
var
  LN: SizeUInt;
begin
  { 只从已解码队列取；不解码不等待（同步面无事件循环参与） }
  if (FInHead = nil) or (ACount = 0) or FDead then
  begin
    ARead := 0;
    if FClosedByPeer or FEofDelivered or FDead then
      Result := tsiorClosed
    else
      Result := tsiorWouldBlock;
    Exit;
  end;
  LN := SizeUInt(Length(FInHead^.Data)) - SizeUInt(FInHeadOff);
  if LN > ACount then
    LN := ACount;
  Move(FInHead^.Data[FInHeadOff], ABuf, LN);
  FInHeadOff := FInHeadOff + Integer(LN);
  if FInHeadOff >= Length(FInHead^.Data) then
  begin
    FInHeadOff := 0;
    try
      FInHead := FInHead^.Next;
      if FInHead = nil then
        FInTail := nil;
    except
      FInHead := nil;
      FInTail := nil;
    end;
  end;
  FInTotal := FInTotal - LN;
  ARead := LN;
  Result := tsiorOk;
end;

function TAsyncWsStream.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
begin
  { WS 载荷必须经帧封装走异步路径；同步面不支持直写 }
  AWritten := 0;
  Result := tsiorWouldBlock;
end;

function TAsyncWsStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if TryRead(ABuf, ACount, Result) <> tsiorOk then
    Result := 0;
end;

function TAsyncWsStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  { 同步面不支持帧化写入（见 TryWrite） }
  Result := 0;
end;

procedure TAsyncWsStream.Close;
begin
  EnqueueCloseReply(1000);
  TryFlush;
  if FUnderlying <> nil then
    FUnderlying.Close;
  FDead := True;
  if Assigned(FReadCb) and not FEofDelivered then
  begin
    FEofDelivered := True;
    DeliverRead(0);
  end;
  if Assigned(FWriteCb) then
    DeliverWrite(ASYNC_WS_ERR_IO);
end;

{ ---- IAsyncTcpStream ---- }

function TAsyncWsStream.AsyncRead(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  { 单槽挂起读：二次提交 fail-closed 拒绝，不覆盖丢回调 }
  if Assigned(FReadCb) then
    Exit(False);
  FReadBuf := ABuf;
  FReadLen := ALen;
  FReadCb := ACallback;
  FReadCbCtx := AContext;
  { 队列已有数据 → 立即交付；对端已关且队列空 → EOF；会话失败态
    → 真实错误码；否则等收泵 }
  if not TryServeRead then
  begin
    if (FDead) and (FFailCode <> 0) then
      DeliverRead(FFailCode)
    else if FClosedByPeer or FEofDelivered or FDead then
      DeliverRead(0);
  end;
  ArmRecv;
  Result := True;
end;

function TAsyncWsStream.AsyncReadRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LCtx: Pointer;
begin
  LCtx := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncRead(ABuf, ALen, @IoCompletionRefWrapper, LCtx);
  if not Result then
    Dispose(PIoCompletionRefCtx(LCtx));
end;

function TAsyncWsStream.AsyncWrite(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
var
  LOff: Integer;
  LChunk: Integer;
  LPay, LWire: TBytes;
begin
  { 单槽挂起写：二次提交 fail-closed 拒绝，不覆盖丢回调 }
  if Assigned(FWriteCb) then
    Exit(False);
  FWriteCb := ACallback;
  FWriteCbCtx := AContext;
  FWriteTotal := Integer(ALen);
  if FDead or FClosedByPeer then
  begin
    DeliverWrite(ASYNC_WS_ERR_IO);
    Result := True;
    Exit;
  end;
  LOff := 0;
  while LOff < Integer(ALen) do
  begin
    LChunk := Integer(ALen) - LOff;
    if LChunk > cWsWriteChunk then
      LChunk := cWsWriteChunk;
    SetLength(LPay, LChunk);
    Move(PByte(ABuf)[LOff], LPay[0], SizeUInt(LChunk));
    if TNetWsFrameEncoder.BuildFrame(Byte(WS_OPCODE_BINARY), True, LPay,
      nwsClient, LWire) <> nwsEncodeOk then
    begin
      FailSession(ASYNC_WS_ERR_PROTOCOL);
      Exit(True);
    end;
    EnqueueWire(LWire);
    Inc(LOff, LChunk);
  end;
  FOpEndOffset := FOutEnqueued;
  if ALen = 0 then
  begin
    DeliverWrite(0);
    Exit(True);
  end;
  TryFlush;
  Result := True;
end;

function TAsyncWsStream.AsyncWriteRef(ABuf: Pointer; ALen: UInt32;
  ACallback: TIoCompletionRef; AContext: Pointer): Boolean;
var
  LCtx: Pointer;
begin
  LCtx := WrapIoCompletionRef(ACallback, AContext);
  Result := AsyncWrite(ABuf, ALen, @IoCompletionRefWrapper, LCtx);
  if not Result then
    Dispose(PIoCompletionRefCtx(LCtx));
end;

function TAsyncWsStream.AsyncReadTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  { 数据面读 deadline 接受不强制（收泵常驻，见单元头契约） }
  Result := AsyncRead(ABuf, ALen, ACallback, AContext);
end;

function TAsyncWsStream.AsyncWriteTimeout(ABuf: Pointer; ALen: UInt32;
  const ADeadline: TDeadline; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  { 数据面写 deadline 接受不强制（见单元头契约） }
  Result := AsyncWrite(ABuf, ALen, ACallback, AContext);
end;

end.

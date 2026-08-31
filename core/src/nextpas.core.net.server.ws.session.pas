unit nextpas.core.net.server.ws.session;
{**
 * @desc 事件驱动的 WebSocket 帧会话：把 ws.frame 编解码状态机接入
 *       net/server 的 poll-driven 会话契约
 *       （ITcpServerSession + ITcpServerPollDrivenSession + WithDeadline）。
 *
 *       每条连接一个会话，由事件驱动后端（epoll/kqueue/iocp 的 readiness
 *       路径）逐事件推进：可读就喂解码器、可写就冲刷出站队列；读空闲超时
 *       经 WakeDeadline 由 reactor 按时唤醒。帧语义与
 *       http.websocket.TWebSocketImpl 一致（分片归并、Ping 自动回 Pong、
 *       close 握手由驱动自动完成）。
 *
 *       有界与背压：出站队列字节数受 OutboundQueueLimit 限制，溢出即
 *       失败关闭（事件 nwsEventOverflow）；控帧自动回复不消耗应用配额。
 *
 *       与既有 HTTP WS 服务器的接入点：HTTP 升级握手（
 *       http.websocket.UpgradeWebSocket，阻塞实现）后续批次将提供
 *       hijack 语义的非阻塞变体——其返回值替换为本会话的 I/O 源即可把
 *       IWebSocketImpl 的阻塞帧循环换成此事件驱动会话。本批切片只交付
 *       「握手之后的帧层」；升级集成见 docs/net/README.md。
 *
 *       线程约束：SendXxx/Cancel 必须由会话推进方（reactor 线程，即
 *       Advance 或其回调内）调用；worker 侧推送需经 worker handoff 在
 *       reactor 线程交付（readiness 完成队列语义）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.ws.frame,
  nextpas.core.platform.io.base,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.websocket.base;

const
  NET_WS_OUTBOUND_DEFAULT_LIMIT = 65536;
  { 批量写分段冲刷阈值（上限一半）：SendTexts 拼缓冲累计到阈值即冲刷一次，
    防整批未写出缓冲触顶 64KiB 溢出（那会把快消费者也判成溢出断连）；
    阈值下快消费者 ~32KiB/次冲刷，慢消费者 WouldBlock 停在阈值处、余帧
    入队自然超限断连（与逐帧 SendText 溢出语义一致）。 }
  NET_WS_BATCH_FLUSH_THRESHOLD = 32 * 1024;

type
  TNetWsSessionEvent = (
    nwsEventFrame,     { AFrame 有效：完整数据消息（text/binary，已归并分片）或 close 帧 }
    nwsEventTimeout,   { 读空闲超时；会话随即以 close 1001 收尾 }
    nwsEventOverflow,  { 出站队列溢出（有界背压失败）；会话随即断开 }
    nwsEventClosed     { 传输终止（EOF/取消/握手完成）；不再有后续事件 }
  );

  IWebSocketFrameSink = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000016}']
    procedure OnSessionEvent(const AEvent: TNetWsSessionEvent;
      const AFrame: TNetWsFrame);
  end;

  IWebSocketFrameSession = interface
    ['{6F1D6F1D-4D7C-4E31-9100-410000000017}']
    procedure SendText(const AText: string);
    { 批量发文本帧（reactor/会话推进方）：循环 BuildFrame+EnqueueWire 只拼
      缓冲，尾次统一 FlushOutbound 一次冲刷——省 N-1 次冲刷调用/syscall
      （与 SendText 相同的溢出/非法帧/WouldBlock 语义，仅合并冲刷时机）。 }
    procedure SendTexts(const ATexts: array of string);
    procedure SendBinary(const APayload: TBytes);
    { 发送数据帧（text/binary/raw opcode 0-2）。控帧/close 请用专门入口。 }
    procedure SendFrame(const AOpcode: Byte; const APayload: TBytes);
    { 应用主动优雅关闭：close 帧刷出后即结束会话 }
    procedure SendClose(const ACode: UInt16; const AReason: string);
    { 立即中止（不发 close 帧，不冲刷出站） }
    procedure Cancel;
    { worker 线程可用的异步发送（经 SetFrameWorkerPush 注入的推送通道，
      在 reactor 线程交付；未注入通道时为空操作）。 }
    procedure SendTextFromWorker(const AText: string);
    { 批量发文本帧（worker 线程）：内部一次 SubmitSendTexts（1 completion +
      1 唤醒），reactor 循环投递——大批量推送路径省控制面。 }
    procedure SendTextsFromWorker(const ATexts: array of string);
    procedure SendBinaryFromWorker(const APayload: TBytes);
    procedure SendCloseFromWorker(const ACode: UInt16; const AReason: string);
  end;

  TNetWsFrameSessionOptions = record
    MaxFrameSize: Int64;
    MaxMessageSize: Int64;
    { 读空闲超时；AsNanoseconds <= 0 表示不设超时（默认） }
    IdleTimeout: TDuration;
    { 出站队列字节上限；0 = 默认 64KiB }
    OutboundQueueLimit: SizeUInt;
    class function Default: TNetWsFrameSessionOptions; static;
    function WithIdleTimeout(const ATimeout: TDuration): TNetWsFrameSessionOptions;
    function WithOutboundQueueLimit(
      const ALimit: SizeUInt): TNetWsFrameSessionOptions;
  end;

  { 事件驱动的 WS 帧服务器会话（见单元头注释）。 }
  TNetWsFrameSession = class(TInterfacedObject, ITcpServerSession,
    ITcpServerPollDrivenSession, ITcpServerPollDrivenSessionWithDeadline,
    ITcpServerSessionShutdown, IWebSocketFrameSession)
  private
    type
      TSessState = (
        stClosed,
        stReading,
        stFlushing,
        stClosing
      );
    var
      FConn: ITcpStream;
      FConnRuntime: ITcpStreamRuntime;
      FSink: IWebSocketFrameSink;
      FOptions: TNetWsFrameSessionOptions;
      FDecoder: TNetWsFrameDecoder;
      FState: TSessState;
      FCloseReceived: Boolean;
      FCloseSent: Boolean;
      FClosedNotified: Boolean;
      FDeadline: TDeadline;
      FOutbound: array of TBytes;
      FOutCount: SizeUInt;
      FOutBytes: SizeUInt;
      FHeadPos: SizeUInt;
      FReadBuf: array[0..4095] of Byte;
      FWorkerPush: IWebSocketFrameWorkerPush;
      procedure RefreshIdleDeadline;
      procedure NotifyClosed;
      procedure AbortSession;
      procedure EnqueueWire(const ASeg: TBytes);
      procedure EnqueueClose(const ACode: UInt16; const AReason: string);
      procedure BeginServerClose(const ACode: UInt16; const AReason: string);
      procedure DrainReadable;
      procedure FlushOutbound;
      procedure ProcessFrame(const AFrame: TNetWsFrame);
  public
    constructor Create(const AConn: ITcpStream; const ASink: IWebSocketFrameSink;
      const AOptions: TNetWsFrameSessionOptions);
    destructor Destroy; override;
    { IWebSocketFrameSession }
    procedure SendText(const AText: string);
    procedure SendTexts(const ATexts: array of string);
    procedure SendBinary(const APayload: TBytes);
    procedure SendFrame(const AOpcode: Byte; const APayload: TBytes);
    procedure SendClose(const ACode: UInt16; const AReason: string);
    procedure Cancel;
    procedure SendTextFromWorker(const AText: string);
    procedure SendTextsFromWorker(const ATexts: array of string);
    procedure SendBinaryFromWorker(const APayload: TBytes);
    procedure SendCloseFromWorker(const ACode: UInt16; const AReason: string);
    { 注入 worker→reactor 推送通道（升级函数在握手时设置；nil 则 FromWorker 为空操作） }
    procedure SetFrameWorkerPush(const APush: IWebSocketFrameWorkerPush);
    { ITcpServerSessionShutdown }
    procedure BeginShutdownClose;
    { ITcpServerSession }
    function Run: TTcpServerConnOwnership;
    { ITcpServerPollDrivenSession }
    function PollEvents: TPlatformPollEvents;
    function Advance(const AEvents: TPlatformPollEvents;
      out ANextEvents: TPlatformPollEvents;
      out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
    { ITcpServerPollDrivenSessionWithDeadline }
    function WakeDeadline: TDeadline;
  end;

implementation

uses
  nextpas.core.errors;

class function TNetWsFrameSessionOptions.Default: TNetWsFrameSessionOptions;
begin
  Result.MaxFrameSize := WS_MAX_FRAME_SIZE;
  Result.MaxMessageSize := NET_WS_DEFAULT_MAX_MESSAGE_SIZE;
  Result.IdleTimeout := TDuration.FromMilliseconds(0);
  Result.OutboundQueueLimit := NET_WS_OUTBOUND_DEFAULT_LIMIT;
end;

function TNetWsFrameSessionOptions.WithIdleTimeout(
  const ATimeout: TDuration): TNetWsFrameSessionOptions;
begin
  Result := Self;
  Result.IdleTimeout := ATimeout;
end;

function TNetWsFrameSessionOptions.WithOutboundQueueLimit(
  const ALimit: SizeUInt): TNetWsFrameSessionOptions;
begin
  Result := Self;
  Result.OutboundQueueLimit := ALimit;
end;

constructor TNetWsFrameSession.Create(const AConn: ITcpStream;
  const ASink: IWebSocketFrameSink; const AOptions: TNetWsFrameSessionOptions);
begin
  inherited Create;
  if AConn = nil then
    raise EArgumentError.Create('net ws frame session conn must not be nil');
  if ASink = nil then
    raise EArgumentError.Create('net ws frame session sink must not be nil');
  FConn := AConn;
  if not Supports(AConn, ITcpStreamRuntime, FConnRuntime) then
    raise EArgumentError.Create('net ws frame session requires stream runtime seam');
  FSink := ASink;
  FOptions := AOptions;
  if FOptions.OutboundQueueLimit = 0 then
    FOptions.OutboundQueueLimit := NET_WS_OUTBOUND_DEFAULT_LIMIT;
  FDecoder := TNetWsFrameDecoder.Create(False, FOptions.MaxFrameSize,
    FOptions.MaxMessageSize);
  FState := stReading;
  RefreshIdleDeadline;
end;

destructor TNetWsFrameSession.Destroy;
begin
  { server 关闭/释放 poll target 时经此通知 sink 收尾 }
  NotifyClosed;
  FConnRuntime := nil;
  FConn := nil;
  FSink := nil;
  inherited Destroy;
end;

procedure TNetWsFrameSession.RefreshIdleDeadline;
begin
  if FOptions.IdleTimeout.AsNanoseconds > 0 then
    FDeadline := TDeadline.After(FOptions.IdleTimeout)
  else
    FDeadline := TDeadline.Infinite;
end;

procedure TNetWsFrameSession.NotifyClosed;
begin
  if FClosedNotified then
    Exit;
  FClosedNotified := True;
  if FSink <> nil then
  begin
    FSink.OnSessionEvent(nwsEventClosed, Default(TNetWsFrame));
    { 断开对 sink 的引用，打破 sink↔session 引用环（sink 常持有
      IWebSocketFrameSession 以在回调中推送）：Closed 事件后会话不再
      回调 sink，引用应让渡给 sink 侧。 }
    FSink := nil;
  end;
end;

procedure TNetWsFrameSession.AbortSession;
begin
  if FState = stClosed then
    Exit;
  FState := stClosed;
  FOutbound := nil;
  FOutCount := 0;
  FOutBytes := 0;
  FHeadPos := 0;
  NotifyClosed;
end;

procedure TNetWsFrameSession.EnqueueWire(const ASeg: TBytes);
begin
  if FOutBytes + SizeUInt(Length(ASeg)) > FOptions.OutboundQueueLimit then
  begin
    FSink.OnSessionEvent(nwsEventOverflow, Default(TNetWsFrame));
    AbortSession;
    Exit;
  end;
  SetLength(FOutbound, FOutCount + 1);
  FOutbound[FOutCount] := ASeg;
  Inc(FOutCount);
  Inc(FOutBytes, SizeUInt(Length(ASeg)));
end;

procedure TNetWsFrameSession.EnqueueClose(const ACode: UInt16;
  const AReason: string);
var
  LSeg: TBytes;
  LCode: TNetWsEncodeCode;
begin
  LCode := TNetWsFrameEncoder.BuildCloseFrame(ACode, AReason, nwsServer, LSeg);
  if LCode <> nwsEncodeOk then
  begin
    { 驱动侧 close 参数恒合法；防御性兜底为直接断开 }
    AbortSession;
    Exit;
  end;
  EnqueueWire(LSeg);
end;

procedure TNetWsFrameSession.BeginServerClose(const ACode: UInt16;
  const AReason: string);
begin
  if FState = stClosed then
    Exit;
  if not FCloseSent then
  begin
    FCloseSent := True;
    EnqueueClose(ACode, AReason);
  end;
  { 冲刷中同样判为进入关帧（关帧排在出站队尾，TCP 保序） }
  if FState in [stReading, stFlushing] then
    FState := stClosing;
  FlushOutbound;
end;

{ 服务器 shutdown 钩子（readiness reactor drain 阶段调用，reactor 线程）：
  补发 close frame 1001 going away 并冲刷——与 idle timeout/protocol error
  同一 BeginServerClose 通道（stClosed 幂等、FCloseSent 防重、已互发 close
  不重复补发）；drain 由 reactor 可写事件驱动 Advance/FlushOutbound 完成，
  超 ShutdownTimeout 期限未完成的会话由 server 强关（等价阻塞路径
  ForceClose）。 }
procedure TNetWsFrameSession.BeginShutdownClose;
begin
  BeginServerClose(WS_CLOSE_GOING_AWAY, 'going away');
end;

{ WebSocket 会话专用：控帧 >125 由编码器拒绝（SendFrame 静默丢弃非法帧）。 }
procedure TNetWsFrameSession.SendFrame(const AOpcode: Byte;
  const APayload: TBytes);
var
  LSeg: TBytes;
  LCode: TNetWsEncodeCode;
begin
  if (FState = stClosed) or (FState = stClosing) then
    Exit;
  LCode := TNetWsFrameEncoder.BuildFrame(AOpcode, True, APayload, nwsServer,
    LSeg);
  if LCode <> nwsEncodeOk then
    Exit;
  EnqueueWire(LSeg);
  if FState = stReading then
    FState := stFlushing;
  { SendText 等由 reactor 线程（completion / handler 内）调用，入队后立即
    冲刷：写成功回 stReading；WouldBlock 保持 stFlushing，等下一次可写
    事件（Advance 尾部按 ANextEvents 同步 poller 事件集）。不能只靠状
    态转换等待——事件集更新要一次 Advance 推进，这里直接完成冲刷。 }
  FlushOutbound;
end;

procedure TNetWsFrameSession.SendText(const AText: string);
var
  LBytes: TBytes;
begin
  SetLength(LBytes, Length(AText));
  if Length(AText) > 0 then
    Move(PAnsiChar(AText)^, LBytes[0], SizeUInt(Length(AText)));
  SendFrame(Byte(WS_OPCODE_TEXT), LBytes);
end;

procedure TNetWsFrameSession.SendTexts(const ATexts: array of string);
var
  LI: Integer;
  LBytes: TBytes;
  LSeg: TBytes;
  LCode: TNetWsEncodeCode;
begin
  if (FState = stClosed) or (FState = stClosing) then
    Exit;
  { 逐帧拼缓冲（EnqueueWire 每帧检查出站上限，溢出中止与 SendText 同义），
    累计达阈值分段冲刷、尾次统一收尾——一次冲刷承载 ≥1 帧（省冲 syscall
    调用；WouldBlock 语义不变——缓冲保留待可写事件续写）。 }
  for LI := 0 to High(ATexts) do
  begin
    SetLength(LBytes, Length(ATexts[LI]));
    if Length(ATexts[LI]) > 0 then
      Move(ATexts[LI][1], LBytes[0], SizeUInt(Length(ATexts[LI])));
    LCode := TNetWsFrameEncoder.BuildFrame(Byte(WS_OPCODE_TEXT), True,
      LBytes, nwsServer, LSeg);
    if LCode <> nwsEncodeOk then
      Continue;   { 与 SendFrame 相同：非法帧静默丢弃 }
    EnqueueWire(LSeg);
    if FState = stClosed then
      Break;      { 溢出中止：后续帧不再投递（与逐帧 SendText 语义一致） }
    if FOutBytes >= NET_WS_BATCH_FLUSH_THRESHOLD then
    begin
      if FState = stReading then
        FState := stFlushing;
      FlushOutbound;
    end;
  end;
  if FState = stReading then
    FState := stFlushing;
  FlushOutbound;
end;

procedure TNetWsFrameSession.SendBinary(const APayload: TBytes);
begin
  SendFrame(Byte(WS_OPCODE_BINARY), APayload);
end;

procedure TNetWsFrameSession.SendClose(const ACode: UInt16; const AReason: string);
begin
  if (FState = stClosed) or FCloseSent then
    Exit;
  FCloseSent := True;
  EnqueueClose(ACode, AReason);
  if FState in [stReading, stFlushing] then
    FState := stClosing;
  FlushOutbound;
end;

procedure TNetWsFrameSession.Cancel;
begin
  if FState = stClosed then
    Exit;
  FState := stClosed;
  FOutbound := nil;
  FOutCount := 0;
  FOutBytes := 0;
  FHeadPos := 0;
  NotifyClosed;
end;

procedure TNetWsFrameSession.SetFrameWorkerPush(
  const APush: IWebSocketFrameWorkerPush);
begin
  FWorkerPush := APush;
end;

procedure TNetWsFrameSession.SendTextFromWorker(const AText: string);
begin
  if FWorkerPush <> nil then
    FWorkerPush.SubmitSendText(AText);
end;

procedure TNetWsFrameSession.SendTextsFromWorker(
  const ATexts: array of string);
begin
  if FWorkerPush <> nil then
    FWorkerPush.SubmitSendTexts(ATexts);
end;

procedure TNetWsFrameSession.SendBinaryFromWorker(const APayload: TBytes);
begin
  if FWorkerPush <> nil then
    FWorkerPush.SubmitSendBinary(APayload);
end;

procedure TNetWsFrameSession.SendCloseFromWorker(const ACode: UInt16;
  const AReason: string);
begin
  if FWorkerPush <> nil then
    FWorkerPush.SubmitSendClose(ACode, AReason);
end;

function TNetWsFrameSession.Run: TTcpServerConnOwnership;
begin
  { 事件驱动会话不提供阻塞降级路径：threaded 后端接入属误用，显式 501。 }
  Result := tscoServer;
  raise ENotSupportedError.Create(
    'net ws frame session requires an evented tcp server backend');
end;

function TNetWsFrameSession.PollEvents: TPlatformPollEvents;
begin
  Result := [peReadable];
end;

procedure TNetWsFrameSession.ProcessFrame(const AFrame: TNetWsFrame);
begin
  case AFrame.Opcode of
    Byte(WS_OPCODE_TEXT), Byte(WS_OPCODE_BINARY):
      begin
        if not AFrame.Fin then
          Exit; { 分片中间帧：解码器归并，仅终帧对外可见 }
        FSink.OnSessionEvent(nwsEventFrame, AFrame);
      end;
    Byte(WS_OPCODE_PING):
      begin
        { RFC 6455 §5.5.2: MUST 回 Pong }
        SendFrame(Byte(WS_OPCODE_PONG), AFrame.Payload);
      end;
    Byte(WS_OPCODE_PONG):
      begin
        { 无业务语义，忽略 }
      end;
    Byte(WS_OPCODE_CLOSE):
      begin
        FCloseReceived := True;
        FSink.OnSessionEvent(nwsEventFrame, AFrame);
        if not FCloseSent then
        begin
          FCloseSent := True;
          if AFrame.CloseCode >= 1000 then
            EnqueueClose(AFrame.CloseCode, '')
          else
            EnqueueClose(WS_CLOSE_NORMAL, '');
        end;
        if FState in [stReading, stFlushing] then
          FState := stClosing;
      end;
  end;
end;

procedure TNetWsFrameSession.DrainReadable;
var
  LRead: SizeUInt;
  LRes: TTcpStreamIOResult;
  LFrame: TNetWsFrame;
  LDeferred: array of TNetWsFrame;
  LDeferredCount: Int32;
  LDecodeCode: TNetWsDecodeCode;
  LError: TNetWsDecodeCode;
  LDone: Boolean;
  LI: Int32;
  { 一次读入可能含多帧：先全部解码入本地队列。处理过程会迁移状态
    （echo→Flushing、close→Closing），若边解码边处理会中断剩余
    缓冲帧，而内核已无可读事件——它们将永久滞留。 }
  procedure FeedAndDecode;
  begin
    FDecoder.Feed(PByte(@FReadBuf[0]), LRead);
    LDone := False;
    while not LDone do
    begin
      LDecodeCode := FDecoder.TryDecode(LFrame);
      case LDecodeCode of
        nwsDecodeFrame:
          begin
            SetLength(LDeferred, LDeferredCount + 1);
            LDeferred[LDeferredCount] := LFrame;
            Inc(LDeferredCount);
          end;
        nwsDecodeClosed:
          begin
            LError := nwsDecodeClosed;
            LDone := True;
          end;
        nwsDecodeProtocolError:
          begin
            LError := nwsDecodeProtocolError;
            LDone := True;
          end;
        nwsDecodeTooLarge:
          begin
            LError := nwsDecodeTooLarge;
            LDone := True;
          end;
        nwsDecodeNeedMore:
          LDone := True;
      end;
    end;
  end;
begin
  if FConnRuntime = nil then
    Exit;
  LDeferred := nil;
  LDeferredCount := 0;
  LError := nwsDecodeNeedMore;
  while FState = stReading do
  begin
    LRes := FConnRuntime.TryRead(FReadBuf[0], SizeOf(FReadBuf), LRead);
    case LRes of
      tsiorOk:
        begin
          if LRead = 0 then
          begin
            FState := stClosed;
            NotifyClosed;
            Exit;
          end;
          FeedAndDecode;
        end;
      tsiorWouldBlock:
        begin
          { 兼容部分交付语义（如 prepend 前缀读完、内层 WouldBlock）：
            LRead > 0 时先交付已读字节再停。 }
          if LRead > 0 then
            FeedAndDecode;
          Break;
        end;
      tsiorClosed, tsiorTimeout:
        begin
          FState := stClosed;
          NotifyClosed;
          Exit;
        end;
    end;
  end;

  { 按序处理已解码帧；取消/溢出（stClosed）或已发关帧（stClosing）后
    不再处理后续帧 }
  LI := 0;
  while LI < LDeferredCount do
  begin
    if (FState <> stReading) and (FState <> stFlushing) then
      Break;
    ProcessFrame(LDeferred[LI]);
    Inc(LI);
  end;

  { 解码层失败（协议违规/超限）在已解码帧之后落定，统一驱动关帧 }
  case LError of
    nwsDecodeProtocolError:
      BeginServerClose(WS_CLOSE_PROTOCOL_ERROR, 'protocol error');
    nwsDecodeTooLarge:
      BeginServerClose(WS_CLOSE_TOO_LARGE, 'frame too large');
  else
    { NeedMore / Closed 无需驱动关帧 }
  end;
end;

procedure TNetWsFrameSession.FlushOutbound;
var
  LHead: TBytes;
  LWritten: SizeUInt;
  LRes: TTcpStreamIOResult;
  LI: SizeUInt;
begin
  if FConnRuntime = nil then
    Exit;
  while (FOutCount > 0) and (FState in [stFlushing, stClosing]) do
  begin
    LHead := FOutbound[0];
    while FHeadPos < SizeUInt(Length(LHead)) do
    begin
      LRes := FConnRuntime.TryWrite(LHead[FHeadPos],
        SizeUInt(Length(LHead)) - FHeadPos, LWritten);
      case LRes of
        tsiorOk:
          begin
            if LWritten = 0 then
            begin
              FState := stClosed;
              NotifyClosed;
              Exit;
            end;
            Inc(FHeadPos, LWritten);
          end;
        tsiorWouldBlock:
          Exit;
      else
        FState := stClosed;
        NotifyClosed;
        Exit;
      end;
    end;
    Dec(FOutBytes, SizeUInt(Length(LHead)));
    LHead := nil;
    FOutbound[0] := nil;
    for LI := 1 to FOutCount - 1 do
      FOutbound[LI - 1] := FOutbound[LI];
    SetLength(FOutbound, FOutCount - 1);
    Dec(FOutCount);
    FHeadPos := 0;
  end;
  if FOutCount = 0 then
  begin
    if FState = stClosing then
    begin
      FState := stClosed;
      NotifyClosed;
    end
    else if FState = stFlushing then
    begin
      FState := stReading;
      RefreshIdleDeadline;
    end;
  end;
end;

function TNetWsFrameSession.Advance(const AEvents: TPlatformPollEvents;
  out ANextEvents: TPlatformPollEvents;
  out AOwnership: TTcpServerConnOwnership): TTcpServerPollResult;
begin
  AOwnership := tscoServer;
  ANextEvents := [];
  if FState = stClosed then
    Exit(tsprDone);

  { 有事件（可读/可写/错误/挂断）即推进：TryRead/TryWrite 决定成败 }
  if AEvents <> [] then
  begin
    if FState = stReading then
      DrainReadable;
    if (FState = stFlushing) or (FState = stClosing) then
      FlushOutbound;
  end;

  { 读空闲超时：reactor 以空事件集唤醒超时目标（expired target path） }
  if (FState = stReading) and (AEvents = []) and FDeadline.IsExpired then
  begin
    FSink.OnSessionEvent(nwsEventTimeout, Default(TNetWsFrame));
    BeginServerClose(WS_CLOSE_GOING_AWAY, 'idle timeout');
  end;

  case FState of
    stClosed:
      Exit(tsprDone);
    stReading:
      begin
        RefreshIdleDeadline;
        ANextEvents := [peReadable];
        Exit(tsprWait);
      end;
    stFlushing, stClosing:
      begin
        ANextEvents := [peWritable];
        Exit(tsprWait);
      end;
  end;
end;

function TNetWsFrameSession.WakeDeadline: TDeadline;
begin
  Result := FDeadline;
end;

end.
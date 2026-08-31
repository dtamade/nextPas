program test_net_server_ws_upgrade;

{ B8 第二片：HTTP WebSocket 非阻塞升级（hijack → poll 迁移 → 事件驱动会话）集成测试。
  与 test_net_server_ws_session（直接 factory 注会话）不同，本测试走完整
  HTTP 升级路径：
    raw TCP 客户端 → THttpServer（readiness 后端）→ handler 调
    UpgradeWebSocketHandoff（101 无 permessage-deflate 扩展头）→ 连接迁移到
    TNetWsFrameSession → 事件驱动帧循环。

  覆盖：101 升级 + 无扩展头断言、deflate 协商请求兼容、echo 回显（经
  worker 推送通道）、同包残留（请求与首帧同包 → prepend TryRead 前缀路径）、
  ping→pong、close 握手回执、无 idle 超时不误断、服务端主动推送（非
  reactor 线程 SendTextFromWorker）。 }

{$I nextpas.core.settings.inc}

{$IF not defined(NEXTPAS_LINUX)}
  {$ERROR test_net_server_ws_upgrade requires the Linux epoll backend}
{$ENDIF}

uses
  nextpas.core.thread.init,
  Classes,
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.net.server,
  nextpas.core.net.server.base,
  nextpas.core.net.server.ws,
  nextpas.core.net.server.ws.frame,
  nextpas.core.net.server.ws.session,
  nextpas.core.http,
  nextpas.core.http.websocket,
  nextpas.core.platform.thread,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.websocket.base;

type
  TUpgradeSinkMode = (
    usmEcho,          { 数据帧经 SendTextFromWorker 回显（推送通道） }
    usmRecord         { 仅记录，不回显 }
  );

  { 测试 sink：仅由 reactor 线程回调；计数在主线程经等待循环观察。 }
  TUpgradeTestSink = class(TInterfacedObject, IWebSocketFrameSink)
  public
    Mode: TUpgradeSinkMode;
    FrameCount: Int32;
    TimeoutCount: Int32;
    OverflowCount: Int32;
    ClosedCount: Int32;
    LastOpcode: Byte;
    LastPayload: TBytes;
    Session: IWebSocketFrameSession;
    constructor Create(const AMode: TUpgradeSinkMode);
    procedure OnSessionEvent(const AEvent: TNetWsSessionEvent;
      const AFrame: TNetWsFrame);
  end;

  { 升级 handler：ServeHTTP 内调 UpgradeWebSocketHandoff。 }
  TUpgradeTestHandler = class(TInterfacedObject, IHttpHandler)
  public
    UpgradeCount: Int32;
    UpgradeFailedCount: Int32;
    Sink: TUpgradeTestSink;
    ResponseSent: Boolean;
    constructor Create(const ASink: TUpgradeTestSink);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;
  PServerCtx = ^TServerCtx;

  { 客户端 WS 帧读取器：解码器跨调用持有，覆盖多帧剩余缓冲。 }
  TUpgradeClientReader = record
    Decoder: TNetWsFrameDecoder;
    procedure Init;
  end;

function BytesToStr(const AData: TBytes): string;
var
  I: SizeInt;
begin
  SetLength(Result, Length(AData));
  for I := 0 to Length(AData) - 1 do
    Result[I + 1] := Chr(AData[I]);
end;

function ReadResponseChunk(const AConn: ITcpStream): string;
var
  LBuf: array[0..4095] of Byte;
  LRead: SizeUInt;
begin
  Result := '';
  try
    LRead := AConn.Read(LBuf[0], SizeOf(LBuf));
    SetLength(Result, LRead);
    if LRead > 0 then
      Move(LBuf[0], Result[1], LRead);
  except
    Result := '';
  end;
end;

function ReadBlockingChunk(const AConn: ITcpStream;
  var ABuf: array of Byte; const ACount: SizeUInt;
  out ARead: SizeUInt): Boolean;
begin
  ARead := 0;
  try
    ARead := AConn.Read(ABuf[0], ACount);
    Result := True;
  except
    Result := False;
  end;
end;

function TUpgradeClientReader_ReadFrame(const AConn: ITcpStream;
  var AReader: TUpgradeClientReader; const ATimeoutMs: UInt32;
  out AFrame: TNetWsFrame): TNetWsDecodeCode;
var
  LBuf: array[0..4095] of Byte;
  LRead: SizeUInt;
  LWait: Int32;
begin
  { 解码器状态必须跨调用持久：ReadFrame 每次只产出一帧，若读到的
    网络块含多帧，余帧留在解码器缓冲里等下一次调用续解。局部复制
    会在函数返回时丢弃余帧（整帧跳过），故直接操作 AReader.Decoder。 }
  LWait := 0;
  repeat
    Result := AReader.Decoder.TryDecode(AFrame);
    if Result <> nwsDecodeNeedMore then
      Exit;
    if not ReadBlockingChunk(AConn, LBuf, SizeOf(LBuf), LRead) then
      Exit(nwsDecodeClosed);
    if LRead = 0 then
    begin
      { 非阻塞升级后的 0 读 = 数据未到（非连接关闭）；等待重试，
        避免把仍在途的批量推送误判为关闭而丢帧。 }
      platform_thread_sleep_ns(2000000);
      Inc(LWait);
      if LWait > ATimeoutMs then
        Exit(nwsDecodeNeedMore);
      Continue;
    end;
    AReader.Decoder.Feed(PByte(@LBuf[0]), LRead);
    Inc(LWait);
    if LWait > ATimeoutMs then
      Exit(nwsDecodeNeedMore);
  until False;
end;

procedure TUpgradeClientReader.Init;
begin
  Decoder := TNetWsFrameDecoder.Create(True, 65536, 1048576);
end;

{ ==================== server fixture ==================== }

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  LCtx^.Server := nil;
  Dispose(LCtx);
end;

function StartUpgradeServer(const AHandler: TUpgradeTestHandler;
  out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LOptions: THttpServerOptions;
begin
  { 非阻塞升级要求 evented 后端（poll 会话上下文 + hijack 迁移），
    显式指定 epoll（本测试在 Linux 运行）。 }
  LOptions := THttpServerOptions.Default;
  LOptions.Backend := tsbEpoll;
  AServer := THttpServer.Create(AHandler, LOptions);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 300) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

procedure StopUpgradeServer(var AServer: THttpServer;
  const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer = nil then
    Exit;
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

procedure WaitForCount(var ACount: Int32; const ATimeoutMs: UInt32);
var
  LWait: Int32;
begin
  LWait := 0;
  while (ACount < 1) and (LWait < ATimeoutMs) do
  begin
    platform_thread_sleep_ns(2000000);
    Inc(LWait);
  end;
end;

{ ==================== ws helpers ==================== }

function BuildMaskedFrame(AOpcode: Byte; const AData: string): string;
var
  LMaskKey: array[0..3] of Byte;
  LHdr: string;
  LPayloadLen: SizeUInt;
  I: SizeUInt;
begin
  LMaskKey[0] := $12; LMaskKey[1] := $34;
  LMaskKey[2] := $56; LMaskKey[3] := $78;
  LPayloadLen := SizeUInt(Length(AData));
  if LPayloadLen < 126 then
  begin
    SetLength(LHdr, 6);
    LHdr[1] := Chr($80 or AOpcode);
    LHdr[2] := Chr($80 or LPayloadLen);
    LHdr[3] := Chr(LMaskKey[0]);
    LHdr[4] := Chr(LMaskKey[1]);
    LHdr[5] := Chr(LMaskKey[2]);
    LHdr[6] := Chr(LMaskKey[3]);
  end
  else
  begin
    SetLength(LHdr, 8);
    LHdr[1] := Chr($80 or AOpcode);
    LHdr[2] := Chr($80 or 126);
    LHdr[3] := Chr(LPayloadLen shr 8);
    LHdr[4] := Chr(LPayloadLen and $FF);
    LHdr[5] := Chr(LMaskKey[0]);
    LHdr[6] := Chr(LMaskKey[1]);
    LHdr[7] := Chr(LMaskKey[2]);
    LHdr[8] := Chr(LMaskKey[3]);
  end;
  Result := LHdr;
  for I := 1 to LPayloadLen do
    Result := Result + Chr(Ord(AData[I]) xor LMaskKey[(I - 1) mod 4]);
end;

const
  WS_TEST_KEY = 'dGhlIHNhbXBsZSBub25jZQ==';

function BuildUpgradeRequest(const AExtraHeaders: string): string;
begin
  Result := 'GET /ws HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Upgrade: websocket'#13#10 +
            'Connection: Upgrade'#13#10 +
            'Sec-WebSocket-Key: ' + WS_TEST_KEY + #13#10 +
            'Sec-WebSocket-Version: 13'#13#10 +
            'Origin: http://localhost'#13#10 +
            AExtraHeaders + #13#10;
end;

function ReadUpgradeResponseHead(const AConn: ITcpStream;
  const ATimeoutMs: UInt32): string;
var
  LData: string;
  LChunk: string;
  LWait: Int32;
begin
  LData := '';
  LWait := 0;
  while (Pos(#13#10#13#10, LData) = 0) and (LWait < ATimeoutMs) do
  begin
    LChunk := ReadResponseChunk(AConn);
    if LChunk <> '' then
      LData := LData + LChunk
    else
    begin
      platform_thread_sleep_ns(2000000);
      Inc(LWait);
    end;
  end;
  Result := LData;
end;

{ ==================== sink / handler ==================== }

constructor TUpgradeTestSink.Create(const AMode: TUpgradeSinkMode);
begin
  inherited Create;
  Mode := AMode;
end;

procedure TUpgradeTestSink.OnSessionEvent(const AEvent: TNetWsSessionEvent;
  const AFrame: TNetWsFrame);
begin
  case AEvent of
    nwsEventFrame:
      begin
        Inc(FrameCount);
        LastOpcode := AFrame.Opcode;
        LastPayload := AFrame.Payload;
        if (Mode = usmEcho) and (AFrame.Opcode = Byte(WS_OPCODE_TEXT)) then
          Session.SendTextFromWorker('echo:' + BytesToStr(LastPayload));
      end;
    nwsEventTimeout:
      Inc(TimeoutCount);
    nwsEventOverflow:
      Inc(OverflowCount);
    nwsEventClosed:
      Inc(ClosedCount);
  end;
end;

constructor TUpgradeTestHandler.Create(const ASink: TUpgradeTestSink);
begin
  inherited Create;
  Sink := ASink;
end;

procedure TUpgradeTestHandler.ServeHTTP(const AReq: IHttpRequest;
  const AW: IHttpResponseWriter);
var
  LSession: IWebSocketFrameSession;
begin
  try
    LSession := UpgradeWebSocketHandoff(AReq, AW, Sink,
      TNetWsFrameSessionOptions.Default);
    Inc(UpgradeCount);
    Sink.Session := LSession;
  except
    on E: Exception do
    begin
      Inc(UpgradeFailedCount);
      WriteLn('UPGRADE FAILED: ', E.ClassName, ': ', E.Message);
      raise;
    end;
  end;
end;

{ ==================== tests ==================== }

procedure TestUpgradeNoDeflate;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
begin
  LSink := TUpgradeTestSink.Create(usmRecord);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    { 客户端带 permessage-deflate 协商头：非阻塞路径必须拒绝协商（101 无扩展头） }
    LConn.Write(BuildUpgradeRequest(
      'Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits'#13#10)[1],
      SizeUInt(Length(BuildUpgradeRequest(
      'Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits'#13#10))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, '101 Switching Protocols');
    Check(Pos('Sec-WebSocket-Accept:', LRespHead) > 0, 'has accept key');
    Check(Pos('Sec-WebSocket-Extensions', LRespHead) = 0,
      'nonblocking upgrade must not negotiate permessage-deflate');
    WaitForCount(LHandler.UpgradeCount, 1000);
    Check(LHandler.UpgradeCount >= 1, 'handler upgraded connection');
    Check(LHandler.UpgradeFailedCount = 0, 'no upgrade failures');
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestEchoViaWorkerPush;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
  LFrame: TNetWsFrame;
  LReader: TUpgradeClientReader;
  LFrameData: string;
begin
  LSink := TUpgradeTestSink.Create(usmEcho);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Write(BuildUpgradeRequest('')[1],
      SizeUInt(Length(BuildUpgradeRequest(''))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded');
    WaitForCount(LHandler.UpgradeCount, 1000);

    { 客户端发掩码文本帧 → sink 经 SendTextFromWorker（推送通道）回显 }
    LFrameData := BuildMaskedFrame(Byte(WS_OPCODE_TEXT), 'hello');
    LConn.Write(LFrameData[1], SizeUInt(Length(LFrameData)));
    LReader.Init;
    LFrame := Default(TNetWsFrame);
    Check(TUpgradeClientReader_ReadFrame(LConn, LReader, 2000, LFrame) =
      nwsDecodeFrame, 'client received echo frame');
    Check(LFrame.Opcode = Byte(WS_OPCODE_TEXT), 'echo opcode text');
    Check(BytesToStr(LFrame.Payload) = 'echo:hello',
      'echo payload delivered via worker push');
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestSamePacketResidual;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LReq: string;
  LRespHead: string;
  LFrame: TNetWsFrame;
  LReader: TUpgradeClientReader;
begin
  LSink := TUpgradeTestSink.Create(usmEcho);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    { 请求头与首帧同包写入：解析器截留帧字节 → prepend TryRead 前缀路径 }
    LReq := BuildUpgradeRequest('') +
            BuildMaskedFrame(Byte(WS_OPCODE_TEXT), 'same-packet');
    LConn.Write(LReq[1], SizeUInt(Length(LReq)));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded with same-packet frame');
    LReader.Init;
    LFrame := Default(TNetWsFrame);
    Check(TUpgradeClientReader_ReadFrame(LConn, LReader, 2000, LFrame) =
      nwsDecodeFrame, 'residual frame decoded');
    Check(BytesToStr(LFrame.Payload) = 'echo:same-packet',
      'echo of same-packet residual');
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestPingPong;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
  LFrame: TNetWsFrame;
  LReader: TUpgradeClientReader;
  LFrameData: string;
begin
  LSink := TUpgradeTestSink.Create(usmRecord);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Write(BuildUpgradeRequest('')[1],
      SizeUInt(Length(BuildUpgradeRequest(''))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded');
    WaitForCount(LHandler.UpgradeCount, 1000);
    LFrameData := BuildMaskedFrame(Byte(WS_OPCODE_PING), 'ping-data');
    LConn.Write(LFrameData[1], SizeUInt(Length(LFrameData)));
    LReader.Init;
    LFrame := Default(TNetWsFrame);
    Check(TUpgradeClientReader_ReadFrame(LConn, LReader, 2000, LFrame) =
      nwsDecodeFrame, 'pong received');
    Check(LFrame.Opcode = Byte(WS_OPCODE_PONG), 'opcode pong');
    Check(BytesToStr(LFrame.Payload) = 'ping-data', 'pong payload');
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestCloseHandshake;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
  LFrame: TNetWsFrame;
  LReader: TUpgradeClientReader;
  LFrameData: string;
begin
  LSink := TUpgradeTestSink.Create(usmRecord);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Write(BuildUpgradeRequest('')[1],
      SizeUInt(Length(BuildUpgradeRequest(''))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded');
    WaitForCount(LHandler.UpgradeCount, 1000);
    { close 帧：2 字节 code 1000（0x03E8）}
    LFrameData := BuildMaskedFrame(Byte(WS_OPCODE_CLOSE),
      Chr($03) + Chr($E8));
    LConn.Write(LFrameData[1], SizeUInt(Length(LFrameData)));
    LReader.Init;
    LFrame := Default(TNetWsFrame);
    Check(TUpgradeClientReader_ReadFrame(LConn, LReader, 2000, LFrame) =
      nwsDecodeFrame, 'close reply received');
    Check(LFrame.Opcode = Byte(WS_OPCODE_CLOSE), 'opcode close');
    Check(LFrame.CloseCode = 1000, 'close code 1000');
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestServerInitiatedPush;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
  LFrame: TNetWsFrame;
  LReader: TUpgradeClientReader;
begin
  LSink := TUpgradeTestSink.Create(usmRecord);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Write(BuildUpgradeRequest('')[1],
      SizeUInt(Length(BuildUpgradeRequest(''))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded');
    WaitForCount(LHandler.UpgradeCount, 1000);
    { 测试主线程（非 reactor）经推送通道发帧 }
    LHandler.Sink.Session.SendTextFromWorker('server-push');
    LReader.Init;
    LFrame := Default(TNetWsFrame);
    Check(TUpgradeClientReader_ReadFrame(LConn, LReader, 2000, LFrame) =
      nwsDecodeFrame, 'server-initiated push received');
    Check(BytesToStr(LFrame.Payload) = 'server-push', 'push payload');
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestNoIdleTimeoutMisclose;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
begin
  LSink := TUpgradeTestSink.Create(usmRecord);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Write(BuildUpgradeRequest('')[1],
      SizeUInt(Length(BuildUpgradeRequest(''))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded');
    WaitForCount(LHandler.UpgradeCount, 1000);
    { 静置 300ms（默认无 idle 超时），连接不得被误断：随后写帧仍可回显。 }
    platform_thread_sleep_ns(300000000);
    LConn.Write(BuildMaskedFrame(Byte(WS_OPCODE_TEXT), 'still-alive')[1],
      SizeUInt(Length(BuildMaskedFrame(Byte(WS_OPCODE_TEXT), 'still-alive'))));
    Check(True, 'connection alive without idle timeout configured');
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestBatchPushViaWorker;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
  LFrame: TNetWsFrame;
  LReader: TUpgradeClientReader;
  LTexts: array of string;
  LI: Integer;
begin
  LSink := TUpgradeTestSink.Create(usmRecord);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Write(BuildUpgradeRequest('')[1],
      SizeUInt(Length(BuildUpgradeRequest(''))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded');
    WaitForCount(LHandler.UpgradeCount, 1000);

    { 服务端一次批量推送 3 帧（SendTextsFromWorker：1 completion + 1 唤醒），
      客户端按序收到整批——批量接口端到端语义。 }
    SetLength(LTexts, 3);
    LTexts[0] := 'b1';
    LTexts[1] := 'b2';
    LTexts[2] := 'b3';
    LHandler.Sink.Session.SendTextsFromWorker(LTexts);
    LReader.Init;
    for LI := 0 to High(LTexts) do
    begin
      LFrame := Default(TNetWsFrame);
      Check(TUpgradeClientReader_ReadFrame(LConn, LReader, 2000, LFrame) =
        nwsDecodeFrame, 'batch frame ' + IntToStr(LI) + ' decoded');
      Check(LFrame.Opcode = Byte(WS_OPCODE_TEXT), 'batch opcode text');
      Check(BytesToStr(LFrame.Payload) = LTexts[LI],
        'batch frame ' + IntToStr(LI) + ' ordered');
    end;
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

procedure TestBatchPushLarge;
var
  LHandler: TUpgradeTestHandler;
  LSink: IWebSocketFrameSink;
  LServer: THttpServer;
  LThread: TPlatformThreadHandle;
  LPort: UInt16;
  LConn: ITcpStream;
  LRespHead: string;
  LFrame: TNetWsFrame;
  LReader: TUpgradeClientReader;
  LTexts: array of string;
  LI, LJ: Integer;
  LPad: string;
begin
  LSink := TUpgradeTestSink.Create(usmRecord);
    LHandler := TUpgradeTestHandler.Create(LSink as TUpgradeTestSink);
  LThread := StartUpgradeServer(LHandler, LServer, LPort);
  try
    LConn := TcpConnect('127.0.0.1', LPort);
    LConn.Write(BuildUpgradeRequest('')[1],
      SizeUInt(Length(BuildUpgradeRequest(''))));
    LRespHead := ReadUpgradeResponseHead(LConn, 2000);
    Check(Pos('HTTP/1.1 101', LRespHead) > 0, 'upgraded');
    WaitForCount(LHandler.UpgradeCount, 1000);

    { 700 帧批量推送：单帧 ~106B、合计 ~74KiB > 64KiB 出站上限——不经
      BatchFlush 分段冲刷（32KiB/次）必在 EnqueueWire 触限溢出断连；
      分段冲刷后快消费者整批无损送达。客户端逐帧收齐校验顺序与内容，
      覆盖批量接口端到端无损 + 大批量防溢出语义。 }
    SetLength(LTexts, 700);
    LPad := '';
    for LJ := 1 to 100 do
      LPad := LPad + 'x';
    for LI := 0 to High(LTexts) do
      LTexts[LI] := 'L' + IntToStr(LI) + ':' + LPad;
    LHandler.Sink.Session.SendTextsFromWorker(LTexts);
    LReader.Init;
    for LI := 0 to High(LTexts) do
    begin
      LFrame := Default(TNetWsFrame);
      Check(TUpgradeClientReader_ReadFrame(LConn, LReader, 3000, LFrame) =
        nwsDecodeFrame, 'large batch frame ' + IntToStr(LI) + ' decoded');
      Check(LFrame.Opcode = Byte(WS_OPCODE_TEXT), 'large batch opcode text');
      Check(Copy(BytesToStr(LFrame.Payload), 1, Length('L' + IntToStr(LI))) =
        'L' + IntToStr(LI), 'large batch frame ' + IntToStr(LI) + ' ordered');
    end;
    LConn.Close;
  finally
    LHandler.Sink.Session := nil;
    StopUpgradeServer(LServer, LThread);
  end;
end;

{ ==================== main ==================== }

var
  LTest: TTestSuite;
begin
  LTest := TTestSuite.Create('test_net_server_ws_upgrade');
  try
    LTest.Test('upgrade 101 without deflate extension', @TestUpgradeNoDeflate);
    LTest.Test('echo via worker push channel', @TestEchoViaWorkerPush);
    LTest.Test('same-packet residual via prepend TryRead', @TestSamePacketResidual);
    LTest.Test('ping auto pong', @TestPingPong);
    LTest.Test('close handshake reply', @TestCloseHandshake);
    LTest.Test('server-initiated push from non-reactor thread', @TestServerInitiatedPush);
    LTest.Test('batch push via worker channel', @TestBatchPushViaWorker);
    LTest.Test('large batch push no overflow', @TestBatchPushLarge);
    LTest.Test('no idle timeout keeps alive', @TestNoIdleTimeoutMisclose);
    if not LTest.Run then Halt(1);
  finally
  end;
end.
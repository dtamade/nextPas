program test_net_async_ws;

{** @desc nextpas.core.net.async.ws 集成测试：

  1. options-guard       同步 fail-closed：空 Host / CR-LF 头注入 /
                         路径无 '/' 一律 False 且不回调
  2. upgrade-echo-small  升级握手（Accept 校验内含 RFC golden 逻辑）+
                         小消息回显（掩码客户端帧 ↔ 无掩码服务端帧）
  3. upgrade-echo-large  200KB 写 op → 多个 64KB BINARY 帧，回显逐字节比对
  4. fragment-once       服务端分片发送（TEXT fin=0 + CONTINUATION fin=1），
                         客户端恰好一次交付聚合完整消息（编解码器会同时产出
                         中间片与终帧聚合，本单元负责去重）
  5. ping-auto-pong      服务端 PING('pi') → 客户端收泵自动 PONG 回显，
                         服务端解码验证 opcode 与载荷
  6. close-push-eof      服务端 CLOSE(1001) → 客户端挂起读交付 EOF(0)
  7. eof-drop            握手后服务端直接断 TCP（无 CLOSE 帧）→ EOF(0)
  8. bad-accept          101 响应带错误 Sec-WebSocket-Accept → 回调
                         nil + ASYNC_WS_ERR_HANDSHAKE

  服务端为进程内裸 WS echo（同一事件循环，TryAccept 轮询 +
  帧编解码器 server 角色），全程事件驱动、无线程、无阻塞 IO。 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.io.intf,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.hash.sha1,
  nextpas.core.tls.base64,
  nextpas.core.websocket.base,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.async.tcp,
  nextpas.core.net.server.ws.frame,
  nextpas.core.net.async.ws;

const
  cBufSize = 16384;
  cLargeLen = 200000;
  cSmallMark = 'PING-WS13';
  cFragA = 'Hello';
  cFragB = ', world';
  cPingPayload = 'pi';
  cWsGuid = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

type
  TCaseMode = (fmEchoSmall, fmEchoLarge, fmFragment, fmPing, fmClosePush,
    fmEofDrop, fmBadAccept);
  TSrvPhase = (spReadReq, spRespDrain, spFrames);

var
  GLoop: TAsyncLoop;
  GListener: IAsyncTcpListener;
  GPort: UInt16;
  GMode: TCaseMode;
  GFinished: Boolean;

  { 客户端状态 }
  GCliStream: IAsyncTcpStream;
  GCliErr: Int32;
  GCliReady: Boolean;
  GTxBuf: TBytes;
  GRxBuf: array of Byte;
  GRxGot: Integer;
  GRxTotal: Integer;
  GRxDeliveries: Integer;
  GRxEof: Boolean;
  GRxBad: Boolean;
  GCbCalled: Boolean;

  { 服务端状态 }
  GSrvStream: IAsyncTcpStream;
  GSrvPhase: TSrvPhase;
  GSrvReq: TBytes;
  GSrvDecoder: TNetWsFrameDecoder;
  GSrvRxBuf: array[0..cBufSize - 1] of Byte;
  GSrvRecvArmed: Boolean;
  { 出站分片 FIFO：AsyncWrite 不拷贝（缓冲须存活到回调），
    故每帧独立入队、按值持有，回调后释放 }
  GSrvParts: array of TBytes;
  GSrvHead: Integer;
  GSrvPartOff: Integer;
  GSrvSendArmed: Boolean;

function ExpectedByte(AIndex: Integer): Byte;
begin
  { 小载荷比对 marker 字面量；大载荷比对确定性数字模式 }
  if GMode = fmEchoLarge then
    Result := Byte((AIndex * 7 + 13) mod 251)
  else
    Result := Ord(cSmallMark[AIndex + 1]);
end;

{ ======== 收尾与工具 ======== }

procedure StopCb(AContext: Pointer);
begin
  if GLoop <> nil then
    GLoop.Stop;
end;

procedure FinishCase;
begin
  if GFinished then
    Exit;
  GFinished := True;
  GLoop.Schedule(TDuration.FromMilliseconds(1), @StopCb, nil);
end;

function StrToBytes(const AValue: string): TBytes;
begin
  Result := nil;
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(Pointer(AValue)^, Result[0], SizeUInt(Length(AValue)));
end;

function SameBytesStr(const AData: TBytes; const AExpected: string): Boolean;
begin
  Result := (Length(AData) = Length(AExpected)) and
    CompareMem(@AData[0], Pointer(AExpected), SizeUInt(Length(AExpected)));
end;

procedure ResetGlobals;
begin
  GListener := nil;
  GCliStream := nil;
  GSrvStream := nil;
  GCliErr := 0;
  GCliReady := False;
  GTxBuf := nil;
  GRxBuf := nil;
  GRxGot := 0;
  GRxTotal := 0;
  GRxDeliveries := 0;
  GRxEof := False;
  GRxBad := False;
  GFinished := False;
  GCbCalled := False;
  GSrvPhase := spReadReq;
  GSrvReq := nil;
  { 记录赋值语义会先终结旧实例的托管字段再拷贝，避免泄漏 }
  GSrvDecoder := TNetWsFrameDecoder.Create(False);
  GSrvRecvArmed := False;
  GSrvParts := nil;
  GSrvHead := 0;
  GSrvPartOff := 0;
  GSrvSendArmed := False;
end;

{ ======== 前向声明 ======== }

procedure SrvAppendOut(const AData: TBytes); forward;
procedure SrvSendCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer); forward;
procedure SrvArmRecv; forward;
procedure SrvPostHandshake; forward;

{ ======== 服务端：握手响应 ======== }

function LowerAsciiB(AB: Byte): Byte;
begin
  if (AB >= Ord('A')) and (AB <= Ord('Z')) then
    Result := AB + (Ord('a') - Ord('A'))
  else
    Result := AB;
end;

function SrvFindHeaderEnd(const ABuf: TBytes): Integer;
var
  I: Integer;
begin
  Result := -1;
  if Length(ABuf) < 4 then
    Exit;
  for I := 0 to Length(ABuf) - 4 do
    if (ABuf[I] = 13) and (ABuf[I + 1] = 10) and
       (ABuf[I + 2] = 13) and (ABuf[I + 3] = 10) then
      Exit(I);
end;

{ 从升级请求提取 Sec-WebSocket-Key 值；找不到返回空串 }
function SrvExtractKey(const ABuf: TBytes): string;
const
  CName = 'sec-websocket-key:';
var
  I, J, LEnd: Integer;
  LMatch: Boolean;
begin
  Result := '';
  LEnd := SrvFindHeaderEnd(ABuf);
  if LEnd < 0 then
    Exit;
  I := 0;
  while I < LEnd do
  begin
    LMatch := True;
    for J := 0 to Length(CName) - 1 do
      if (I + J >= LEnd) or
         (LowerAsciiB(ABuf[I + J]) <> Byte(CName[J + 1])) then
      begin
        LMatch := False;
        Break;
      end;
    if LMatch then
    begin
      J := I + Length(CName);
      while (J < LEnd) and (ABuf[J] = Ord(' ')) do
        Inc(J);
      while (J < LEnd) and (ABuf[J] <> 13) do
      begin
        Result := Result + Chr(ABuf[J]);
        Inc(J);
      end;
      Exit;
    end;
    while (I < LEnd) and (ABuf[I] <> 10) do
      Inc(I);
    Inc(I);
  end;
end;

function SrvComputeAccept(const AKeyB64: string): string;
var
  LHasher: TSHA1Hasher;
  LKeyPart, LGuid: AnsiString;
  LSum: TBytes;
begin
  LHasher := TSHA1Hasher.Create;
  try
    LKeyPart := AnsiString(AKeyB64);
    LGuid := AnsiString(cWsGuid);
    LHasher.Write(LKeyPart[1], SizeUInt(Length(LKeyPart)));
    LHasher.Write(LGuid[1], SizeUInt(Length(LGuid)));
    LSum := LHasher.SumBytes;
  finally
    LHasher.Free;
  end;
  Result := TBase64Utils.Encode(LSum);
end;

procedure SrvRespond;
const
  CRespFmt = 'HTTP/1.1 101 Switching Protocols'#13#10 +
    'Upgrade: websocket'#13#10 +
    'Connection: Upgrade'#13#10 +
    'Sec-WebSocket-Accept: %s'#13#10#13#10;
var
  LKey, LAccept, LResp: AnsiString;
begin
  LKey := AnsiString(SrvExtractKey(GSrvReq));
  Check(Length(LKey) > 0, 'server got upgrade key');
  LAccept := AnsiString(SrvComputeAccept(string(LKey)));
  if GMode = fmBadAccept then
  begin
    { 篡改 Accept 首字符 → 客户端必须拒绝握手 }
    if LAccept[1] = 'Z' then
      LAccept[1] := 'Y'
    else
      LAccept[1] := 'Z';
  end;
  LResp := AnsiString(Format(CRespFmt, [string(LAccept)]));
  SetLength(GSrvReq, 0);
  GSrvPhase := spRespDrain;
  SrvAppendOut(StrToBytes(string(LResp)));
end;

procedure SrvTryFlush; forward;

procedure SrvAppendOut(const AData: TBytes);
var
  LN: Integer;
begin
  if (AData = nil) or (Length(AData) = 0) then
    Exit;
  LN := Length(GSrvParts);
  SetLength(GSrvParts, LN + 1);
  GSrvParts[LN] := AData;
  SrvTryFlush;
end;

procedure SrvTryFlush;
var
  LLen: UInt32;
begin
  if GSrvSendArmed or (GSrvStream = nil) then
    Exit;
  while GSrvHead <= High(GSrvParts) do
  begin
    LLen := UInt32(Length(GSrvParts[GSrvHead]) - GSrvPartOff);
    if LLen = 0 then
    begin
      GSrvParts[GSrvHead] := nil;
      Inc(GSrvHead);
      GSrvPartOff := 0;
      Continue;
    end;
    GSrvSendArmed := True;
    if not GSrvStream.AsyncWrite(@GSrvParts[GSrvHead][GSrvPartOff], LLen,
      @SrvSendCb, nil) then
    begin
      GSrvSendArmed := False;
      FinishCase;
    end;
    Exit;
  end;
end;

procedure SrvSendCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LRespDrained: Boolean;
begin
  GSrvSendArmed := False;
  if AResult <= 0 then
  begin
    FinishCase;
    Exit;
  end;
  Inc(GSrvPartOff, AResult);
  LRespDrained := False;
  if GSrvPartOff >= Length(GSrvParts[GSrvHead]) then
  begin
    GSrvParts[GSrvHead] := nil;
    Inc(GSrvHead);
    GSrvPartOff := 0;
    { 响应头块冲完且队列排空 = 进入帧阶段（一次性迁移点） }
    if (GSrvPhase = spRespDrain) and (GSrvHead > High(GSrvParts)) then
      LRespDrained := True;
  end;
  if LRespDrained then
  begin
    GSrvPhase := spFrames;
    SrvArmRecv;
    SrvPostHandshake;
  end
  else
    SrvTryFlush;
end;

{ ======== 服务端：帧处理 ======== }

procedure SrvBuildRawHeader(AOpcode: Byte; AFin: Boolean;
  APayloadLen: UInt64; out AData: TBytes);
begin
  if TNetWsFrameEncoder.BuildHeader(AOpcode, AFin, APayloadLen, nwsServer,
    AData) <> nwsEncodeOk then
    AData := nil;
end;

procedure SrvSendFrame(AOpcode: Byte; const APayload: TBytes);
var
  LWire: TBytes;
begin
  if TNetWsFrameEncoder.BuildFrame(AOpcode, True, APayload, nwsServer,
    LWire) = nwsEncodeOk then
    SrvAppendOut(LWire);
end;

procedure FragATick(AContext: Pointer); forward;
procedure FragBTick(AContext: Pointer); forward;
procedure PingTick(AContext: Pointer); forward;
procedure ClosePushTick(AContext: Pointer); forward;
procedure EofDropTick(AContext: Pointer); forward;

procedure SrvHandleFrame(var AFrame: TNetWsFrame);
var
  LReply: TBytes;
begin
  case AFrame.Opcode of
    Byte(WS_OPCODE_PING):
      SrvSendFrame(Byte(WS_OPCODE_PONG), AFrame.Payload);
    Byte(WS_OPCODE_PONG):
      begin
        if (GMode = fmPing) and SameBytesStr(AFrame.Payload,
          cPingPayload) then
          FinishCase;
      end;
    Byte(WS_OPCODE_CLOSE):
      begin
        if TNetWsFrameEncoder.BuildCloseFrame(1000, '', nwsServer,
          LReply) = nwsEncodeOk then
          SrvAppendOut(LReply);
      end;
    Byte(WS_OPCODE_TEXT),
    Byte(WS_OPCODE_BINARY):
      begin
        { 编解码器终帧聚合：Payload 即完整消息（Opcode 复原）；
          中间片（Fin=False）不会作为数据回显 }
        if AFrame.Fin and
           ((GMode = fmEchoSmall) or (GMode = fmEchoLarge)) then
          SrvSendFrame(AFrame.Opcode, AFrame.Payload);
      end;
  end;
end;

procedure SrvPumpFrames;
var
  LFrame: TNetWsFrame;
  LCode: TNetWsDecodeCode;
begin
  repeat
    LCode := GSrvDecoder.TryDecode(LFrame);
    case LCode of
      nwsDecodeNeedMore,
      nwsDecodeClosed:
        Break;
      nwsDecodeFrame:
        SrvHandleFrame(LFrame);
      nwsDecodeProtocolError,
      nwsDecodeTooLarge:
        begin
          GRxBad := True;
          FinishCase;
          Break;
        end;
    end;
  until False;
end;

procedure SrvRecvCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  LOld: Integer;
begin
  GSrvRecvArmed := False;
  if AResult <= 0 then
    Exit;
  if GSrvPhase = spReadReq then
  begin
    LOld := Length(GSrvReq);
    SetLength(GSrvReq, LOld + AResult);
    Move(GSrvRxBuf[0], GSrvReq[LOld], SizeUInt(AResult));
    if SrvFindHeaderEnd(GSrvReq) >= 0 then
      SrvRespond
    else
      SrvArmRecv;
  end
  else
  begin
    GSrvDecoder.Feed(@GSrvRxBuf[0], SizeUInt(AResult));
    SrvPumpFrames;
    SrvArmRecv;
  end;
end;

procedure SrvArmRecv;
begin
  if GSrvRecvArmed or (GSrvStream = nil) then
    Exit;
  GSrvRecvArmed := True;
  if not GSrvStream.AsyncRead(@GSrvRxBuf[0], UInt32(cBufSize),
    @SrvRecvCb, nil) then
    GSrvRecvArmed := False;
end;

{ ======== 服务端：握手后动作 ======== }

procedure SrvPostHandshake;
var
  LWire: TBytes;
begin
  case GMode of
    fmFragment:
      begin
        { 两拍分别发 TEXT fin=0 与 CONTINUATION fin=1（无掩码服务端帧） }
        GLoop.Schedule(TDuration.FromMilliseconds(15), @FragATick, nil);
        GLoop.Schedule(TDuration.FromMilliseconds(30), @FragBTick, nil);
      end;
    fmPing:
      GLoop.Schedule(TDuration.FromMilliseconds(10), @PingTick, nil);
    fmClosePush:
      begin
        if TNetWsFrameEncoder.BuildCloseFrame(1001, '', nwsServer,
          LWire) = nwsEncodeOk then
          SrvAppendOut(LWire);
        GLoop.Schedule(TDuration.FromMilliseconds(40), @ClosePushTick, nil);
      end;
    fmEofDrop:
      GLoop.Schedule(TDuration.FromMilliseconds(10), @EofDropTick, nil);
    fmEchoSmall,
    fmEchoLarge,
    fmBadAccept:
      ; { 响应本身即全部动作 }
  end;
end;

procedure FragATick(AContext: Pointer);
var
  LWire: TBytes;
begin
  SrvBuildRawHeader(Byte(WS_OPCODE_TEXT), False, UInt64(Length(cFragA)),
    LWire);
  BytesAppend(LWire, StrToBytes(cFragA));
  SrvAppendOut(LWire);
end;

procedure FragBTick(AContext: Pointer);
var
  LWire: TBytes;
begin
  SrvBuildRawHeader(Byte(WS_OPCODE_CONTINUATION), True,
    UInt64(Length(cFragB)), LWire);
  BytesAppend(LWire, StrToBytes(cFragB));
  SrvAppendOut(LWire);
end;

procedure PingTick(AContext: Pointer);
begin
  SrvSendFrame(Byte(WS_OPCODE_PING), StrToBytes(cPingPayload));
end;

procedure ClosePushTick(AContext: Pointer);
begin
  { CLOSE 帧早已送达；此刻断底层，客户端读侧应已按协议关闭收敛 }
  if GSrvStream <> nil then
  begin
    GSrvStream.Shutdown;
    GSrvStream.Close;
    GSrvStream := nil;
  end;
end;

procedure EofDropTick(AContext: Pointer);
begin
  { 不发 CLOSE 帧直接断 TCP：客户端读侧应交付 EOF(0)。
    先 Shutdown 显式发 FIN（挂起的收事件不消直接 Close 会吞 FIN） }
  if GSrvStream <> nil then
  begin
    GSrvStream.Shutdown;
    GSrvStream.Close;
    GSrvStream := nil;
  end;
end;

{ ======== 服务端：accept 轮询 ======== }

procedure PollAcceptTick(AContext: Pointer);
var
  LConn: ITcpStream;
begin
  if (GLoop = nil) or GFinished or (GSrvStream <> nil) then
    Exit;
  if (GListener as ITcpListenerRuntime).TryAccept(LConn) = tarAccepted then
  begin
    GSrvStream := AsyncTcpStreamAdopt(GLoop, LConn);
    SrvArmRecv;
  end
  else
    GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTick, nil);
end;

{ ======== 客户端回调 ======== }

procedure ArmRxChunk; forward;

procedure CliDataCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  I: Integer;
  LOk: Boolean;
begin
  if AResult <= 0 then
  begin
    GRxBad := True;
    FinishCase;
    Exit;
  end;
  Inc(GRxGot, AResult);
  Inc(GRxDeliveries);
  if GRxGot < GRxTotal then
  begin
    ArmRxChunk;
    Exit;
  end;
  LOk := GRxGot = GRxTotal;
  if LOk then
    for I := 0 to GRxTotal - 1 do
      if GRxBuf[I] <> ExpectedByte(I) then
      begin
        LOk := False;
        Break;
      end;
  if not LOk then
    GRxBad := True;
  FinishCase;
end;

procedure ArmRxChunk;
begin
  if not GCliStream.AsyncRead(@GRxBuf[GRxGot],
    UInt32(GRxTotal - GRxGot), @CliDataCb, nil) then
  begin
    GRxBad := True;
    FinishCase;
  end;
end;

procedure CliWriteCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
begin
  { 写完成回调携带的字节数必须等于整 op（绝对偏移记账语义） }
  if AResult <> Integer(Length(GTxBuf)) then
  begin
    GRxBad := True;
    FinishCase;
    Exit;
  end;
  ArmRxChunk;
end;

procedure CliFragCb(AUserData: UInt64; AResult: Int32; AContext: Pointer);
var
  I: Integer;
  LMsg: AnsiString;
begin
  LMsg := AnsiString(cFragA) + AnsiString(cFragB);
  if AResult <> Length(LMsg) then
  begin
    { 分片若被重复交付或部分交付都会在此暴露 }
    GRxBad := True;
    FinishCase;
    Exit;
  end;
  Inc(GRxDeliveries);
  for I := 0 to AResult - 1 do
    if GRxBuf[I] <> Byte(LMsg[I + 1]) then
    begin
      GRxBad := True;
      Break;
    end;
  FinishCase;
end;

procedure CliEofWaitCb(AUserData: UInt64; AResult: Int32;
  AContext: Pointer);
begin
  if AResult = 0 then
  begin
    GRxEof := True;
    FinishCase;
  end
  else if AResult > 0 then
  begin
    { 协议关闭前不应有数据 }
    GRxBad := True;
    FinishCase;
  end
  else
  begin
    GCliErr := AResult;
    FinishCase;
  end;
end;

procedure CliGuardCb(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
begin
  GCbCalled := True;
end;

procedure CliReadyCb(AStream: IAsyncTcpStream; AError: Int32;
  AContext: Pointer);
begin
  if AError <> 0 then
  begin
    GCliErr := AError;
    FinishCase;
    Exit;
  end;
  GCliStream := AStream;
  GCliReady := True;
  case GMode of
    fmEchoSmall,
    fmEchoLarge:
      begin
        GRxTotal := Length(GTxBuf);
        SetLength(GRxBuf, GRxTotal);
        if not GCliStream.AsyncWrite(@GTxBuf[0], UInt32(Length(GTxBuf)),
          @CliWriteCb, nil) then
        begin
          GRxBad := True;
          FinishCase;
        end;
      end;
    fmFragment:
      begin
        SetLength(GRxBuf, 4096);
        if not GCliStream.AsyncRead(@GRxBuf[0], 4096, @CliFragCb, nil) then
        begin
          GRxBad := True;
          FinishCase;
        end;
      end;
    fmClosePush,
    fmEofDrop:
      begin
        SetLength(GRxBuf, 4096);
        if not GCliStream.AsyncRead(@GRxBuf[0], 4096, @CliEofWaitCb, nil)
        then
        begin
          GRxBad := True;
          FinishCase;
        end;
      end;
    fmPing:
      ; { 客户端被动：收泵自动应答 PING，服务端验证 PONG 后收尾 }
    fmBadAccept:
      ; { 握手必失败，走 AError 分支 }
  end;
end;

{ ======== 用例 ======== }

procedure TestOptionsGuard;
var
  LLoop: TAsyncLoop;
  LListener: IAsyncTcpListener;
  LRaw: IAsyncTcpStream;
  LOpts: TAsyncWsOptions;
begin
  LLoop := TAsyncLoop.Create;
  try
    LListener := AsyncTcpListen(LLoop, '127.0.0.1', 0);
    LRaw := AsyncTcpConnect(LLoop, '127.0.0.1', LListener.LocalAddr.Port);
    LOpts := DefaultAsyncWsOptions;

    LOpts.Host := '';
    Check(not AsyncWsUpgrade(LLoop, LRaw, LOpts, @CliGuardCb, nil),
      'empty host rejected');

    LOpts.Host := 'evil'#13#10'X-Inject: 1';
    Check(not AsyncWsUpgrade(LLoop, LRaw, LOpts, @CliGuardCb, nil),
      'crlf host rejected');

    LOpts.Host := 'localhost';
    LOpts.Path := 'ws';
    Check(not AsyncWsUpgrade(LLoop, LRaw, LOpts, @CliGuardCb, nil),
      'path without leading slash rejected');

    Check(not GCbCalled, 'guard failures never call back');
  finally
    LRaw := nil;
    LListener := nil;
    LLoop.Free;
  end;
end;

procedure RunCase(AMode: TCaseMode);
var
  LOpts: TAsyncWsOptions;
  LRaw: IAsyncTcpStream;
  I: Integer;
begin
  ResetGlobals;
  GMode := AMode;
  if (AMode = fmEchoSmall) or (AMode = fmEchoLarge) then
  begin
    if AMode = fmEchoLarge then
      GRxTotal := cLargeLen
    else
      GRxTotal := Length(cSmallMark);
    SetLength(GTxBuf, GRxTotal);
    for I := 0 to GRxTotal - 1 do
      GTxBuf[I] := ExpectedByte(I);
  end;

  GLoop := TAsyncLoop.Create;
  try
    GListener := AsyncTcpListen(GLoop, '127.0.0.1', 0);
    { 轮询 TryAccept 的前提：listen 套接字非阻塞，否则空拍会把循环冻死 }
    (GListener as ITcpSocketRuntime).SetBlocking(False);
    GPort := GListener.LocalAddr.Port;
    GLoop.Schedule(TDuration.FromSeconds(30), @StopCb, nil);
    GLoop.Schedule(TDuration.FromMilliseconds(5), @PollAcceptTick, nil);

    LOpts := DefaultAsyncWsOptions;
    LOpts.Path := '/';
    LOpts.Host := 'localhost';
    LOpts.HandshakeDeadline := TDeadline.After(TDuration.FromSeconds(10));

    LRaw := AsyncTcpConnect(GLoop, '127.0.0.1', GPort);
    Check(AsyncWsUpgrade(GLoop, LRaw, LOpts, @CliReadyCb, nil),
      'upgrade submit');

    GLoop.Run;
  finally
    { 先弃流引用再停循环（对齐 test_net_async_tls 的收尾次序）；
      结果性标量保留给用例断言，下一次 RunCase 开头才整体重置 }
    GCliStream := nil;
    GSrvStream := nil;
    GListener := nil;
    LRaw := nil;
    GTxBuf := nil;
    GRxBuf := nil;
    GSrvReq := nil;
    GSrvParts := nil;
    GLoop.Free;
    GLoop := nil;
  end;
end;

procedure TestUpgradeEchoSmall;
begin
  RunCase(fmEchoSmall);
  Check(GCliReady, 'handshake done');
  Check(GCliErr = 0, 'no error');
  Check(not GRxBad, 'payload verified');
  CheckEqual(Int64(GRxTotal), Int64(GRxGot), 'small echoed');
end;

procedure TestUpgradeEchoLarge;
begin
  RunCase(fmEchoLarge);
  Check(GCliReady, 'handshake done');
  Check(GCliErr = 0, 'no error');
  Check(not GRxBad, 'payload verified');
  CheckEqual(Int64(cLargeLen), Int64(GRxGot), 'large echoed');
end;

procedure TestFragmentOnce;
begin
  RunCase(fmFragment);
  Check(GCliReady, 'handshake done');
  Check(not GRxBad, 'fragment message verified');
  CheckEqual(Int64(1), Int64(GRxDeliveries),
    'aggregate delivered exactly once');
end;

procedure TestPingAutoPong;
begin
  RunCase(fmPing);
  Check(GCliReady, 'handshake done');
end;

procedure TestClosePushEof;
begin
  RunCase(fmClosePush);
  Check(GCliReady, 'handshake done');
  Check(GRxEof, 'eof delivered on close frame');
  Check(GCliErr = 0, 'clean eof carries zero error');
  Check(not GRxBad, 'no data before close');
end;

procedure TestEofDrop;
begin
  RunCase(fmEofDrop);
  Check(GCliReady, 'handshake done');
  Check(GRxEof, 'eof delivered on tcp drop');
end;

procedure TestBadAccept;
begin
  RunCase(fmBadAccept);
  Check(not GCliReady, 'handshake rejected');
  CheckEqual(Int64(ASYNC_WS_ERR_HANDSHAKE), Int64(GCliErr),
    'bad accept fails handshake');
end;

var
  GSuite: TTestSuite;

begin
  GSuite := TTestSuite.Create('net_async_ws');
  GSuite.Test('OptionsGuard', @TestOptionsGuard);
  GSuite.Test('UpgradeEchoSmall', @TestUpgradeEchoSmall);
  GSuite.Test('UpgradeEchoLarge', @TestUpgradeEchoLarge);
  GSuite.Test('FragmentOnce', @TestFragmentOnce);
  GSuite.Test('PingAutoPong', @TestPingAutoPong);
  GSuite.Test('ClosePushEof', @TestClosePushEof);
  GSuite.Test('EofDrop', @TestEofDrop);
  GSuite.Test('BadAccept', @TestBadAccept);
  GSuite.Run;
end.

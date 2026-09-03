program e2e_quic_echo;

{ Q5 多流回显压测取证：QUIC v1 握手闭环之上并发开 8 条双向流，每流
  16KB 图案化载荷（fin 终结），对端 aioquic 回显服务器原样回写；客户端
  校验逐字节往返一致。覆盖：STREAM 分帧多包发送、连接级/流级双向流控
  （128KB > 我方通告窗 ⇒ 升窗闭环）、ACK 结算→拥塞联动、乱序重组。
  用法：e2e_quic_echo [ip] [port]（默认直连 127.0.0.1:14433）。
  单线程事件驱动：RunOnce 主循环 + 常驻 50ms tick + 有界 recv 重挂。
  取证程序不进默认 gate，手工运行。 }
{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.time.base,
  nextpas.core.time.cpu,
  nextpas.core.time.deadline,
  nextpas.core.async.base,
  nextpas.core.async.loop,
  nextpas.core.net.base,
  nextpas.core.net.async.udp,
  nextpas.core.net.quic.conn,
  nextpas.core.net.quic.stream;

{$I ../../fpc_rtl_uses_scan.inc}

const
  CDefaultHost = '127.0.0.1';
  CDefaultPort = 14433;
  CTickMs = 50;
  CRecvTimeoutMs = 200;
  COverallTimeoutMs = 30000;
  CNumStreams = 8;
  CBytesPerStream = 16384;

type
  TEchoStream = record
    Id: UInt64;
    RecvLen: Integer;
    Verified: Boolean;
  end;

  TDrv = class
  public
    Loop: TAsyncLoop;
    Udp: IAsyncUdpSocket;
    Conn: TQuicClientConnection;
    ServerAddr: TNetAddress;
    Started: Boolean;
    RecvArmed: Boolean;
    DoneOk, DoneFail: Boolean;
    FailReason: string;
    StartMs: UInt64;
    EchoStartedMs: UInt64;
    Streams: array[0..CNumStreams - 1] of TEchoStream;
    VerifiedCount: Integer;
    RxTotal: UInt64;
    TxTotal: UInt64;
    TickCount: Integer;
    ArmTries, ArmFails, RcData, RcTimeout, RcZero: Integer;
    Rx: array[0..4095] of Byte;
    procedure ArmRecv;
    procedure SendDgram(const ADgram: TBytes);
    procedure DrainOutbound;
    procedure StartEchoTest;
    class procedure OnSent(AResult: Int32; ABytes: Int32;
      AContext: Pointer); static;
    class procedure OnRecv(AResult: Int32; ABytes: Int32;
      const AFrom: TNetAddress; AContext: Pointer); static;
    procedure OnTick(AContext: Pointer);
    procedure OnEchoData(AStreamId: UInt64; const AData: TBytes;
      AFin: Boolean);
    function ExpectedByte(AStreamIdx, AOfs: Integer): Byte;
    function StreamIdxOf(AStreamId: UInt64): Integer;
    procedure Fail(const AMsg: string);
  end;

function NumStr(AV: Integer): string;
var
  LBuf: array[0..19] of Char;
  LI, LN: Integer;
begin
  if AV <= 0 then
    Exit('0');
  LN := 0;
  while AV > 0 do
  begin
    LBuf[LN] := Chr(Ord('0') + AV mod 10);
    Inc(LN);
    AV := AV div 10;
  end;
  SetLength(Result, LN);
  for LI := 0 to LN - 1 do
    Result[LI + 1] := LBuf[LN - 1 - LI];
end;

procedure TDrv.Fail(const AMsg: string);
begin
  if not DoneFail then
  begin
    DoneFail := True;
    FailReason := AMsg;
  end;
end;

function TDrv.ExpectedByte(AStreamIdx, AOfs: Integer): Byte;
begin
  Result := Byte((AStreamIdx * 31 + AOfs) mod 251);
end;

function TDrv.StreamIdxOf(AStreamId: UInt64): Integer;
begin
  Result := 0;
  while (Result < CNumStreams) and (Streams[Result].Id <> AStreamId) do
    Inc(Result);
end;

class procedure TDrv.OnSent(AResult: Int32; ABytes: Int32;
  AContext: Pointer);
begin
  { 发送失败不致命：OnTimer 重发兜底 }
end;

procedure TDrv.SendDgram(const ADgram: TBytes);
begin
  Inc(TxTotal);
  Udp.AsyncSendTo(@ADgram[0], UInt32(Length(ADgram)), ServerAddr,
    @TDrv.OnSent, nil);
end;

procedure TDrv.DrainOutbound;
var
  LOut: TBytes;
begin
  while Conn.TakeOutbound(LOut) do
    SendDgram(LOut);
end;

procedure TDrv.ArmRecv;
var
  LOk: Boolean;
begin
  if RecvArmed or (Udp = nil) or DoneOk or DoneFail then
    Exit;
  { 先置已挂再提交：reactor 对已就绪数据会在提交调用内同步完成回调
    （清标志），后写 LOk 会把该清除覆盖回 True 造成永久停读 }
  RecvArmed := True;
  LOk := Udp.AsyncRecvFromTimeout(@Rx[0], UInt32(Length(Rx)),
    TDeadline.After(TDuration.FromMilliseconds(CRecvTimeoutMs)),
    @TDrv.OnRecv, Self);
  if not LOk then
  begin
    RecvArmed := False;   { 提交被拒：下一 tick 重试 }
    Inc(ArmFails);
  end;
  Inc(ArmTries);
end;

class procedure TDrv.OnRecv(AResult: Int32; ABytes: Int32;
  const AFrom: TNetAddress; AContext: Pointer);
{ 完成约定（net.async.udp）：AResult ≥ 0 为成功字节数，< 0 为 -errno }
var
  LDrv: TDrv;
  LDgram: TBytes;
  LI, LN: Integer;
begin
  LDrv := TDrv(AContext);
  LDrv.RecvArmed := False;
  if AResult < 0 then
  begin
    Inc(LDrv.RcTimeout);
    Exit;   { 超时/暂错：tick 重新挂收 }
  end;
  LN := AResult;
  if LN <= 0 then
  begin
    Inc(LDrv.RcZero);
    Exit;
  end;
  Inc(LDrv.RcData);
  SetLength(LDgram, LN);
  for LI := 0 to LN - 1 do
    LDgram[LI] := LDrv.Rx[LI];
  Inc(LDrv.RxTotal, UInt64(LN));
  if not LDrv.Conn.OnDatagram(LDgram) then
    LDrv.Fail('on_datagram closed: ' + LDrv.Conn.LastError);
end;

procedure TDrv.OnEchoData(AStreamId: UInt64; const AData: TBytes;
  AFin: Boolean);
var
  LI, LJ, LN: Integer;
begin
  LI := StreamIdxOf(AStreamId);
  if LI >= CNumStreams then
    Exit;
  if DoneOk or DoneFail then
    Exit;
  LN := Length(AData);
  Inc(Streams[LI].RecvLen, LN);
  if AFin then
  begin
    if Streams[LI].RecvLen <> CBytesPerStream then
    begin
      Fail('stream #' + NumStr(LI) + ' len ' +
        NumStr(Streams[LI].RecvLen) + ' != ' + NumStr(CBytesPerStream));
      Exit;
    end;
    { 回显数据已即时校验，FIN 到达即整流通过 }
    Streams[LI].Verified := True;
    Inc(VerifiedCount);
    WriteLn('[e2e] stream #', LI, ' id=', AStreamId, ' verified (',
      VerifiedCount, '/', CNumStreams, ')');
    Flush(Output);
    if VerifiedCount = CNumStreams then
      DoneOk := True;
  end
  else
  begin
    { 数据段即时逐字节校验，不落缓冲 }
    for LJ := 0 to LN - 1 do
      if AData[LJ] <> ExpectedByte(LI, Streams[LI].RecvLen - LN + LJ) then
      begin
        Fail('stream #' + NumStr(LI) + ' byte mismatch @ofs ' +
          NumStr(Streams[LI].RecvLen - LN + LJ));
        Exit;
      end;
  end;
end;

procedure TDrv.StartEchoTest;
var
  LI, LJ: Integer;
  LPayload: TBytes;
  LId: UInt64;
begin
  Started := True;
  EchoStartedMs := GetTickCount64;
  for LI := 0 to CNumStreams - 1 do
  begin
    if not Conn.OpenStream(False, LId) then
    begin
      Fail('open stream #' + NumStr(LI) + ' rejected');
      Exit;
    end;
    Streams[LI].Id := LId;
    SetLength(LPayload, CBytesPerStream);
    for LJ := 0 to CBytesPerStream - 1 do
      LPayload[LJ] := ExpectedByte(LI, LJ);
    if not Conn.StreamWrite(LId, LPayload, True) then
    begin
      Fail('write stream #' + NumStr(LI) + ' rejected');
      Exit;
    end;
  end;
  WriteLn('[e2e] ', CNumStreams, ' streams x ',
    CBytesPerStream, 'B queued; cwnd=',
    Conn.CongestionWindow);
  Flush(Output);
end;

procedure TDrv.OnTick(AContext: Pointer);
begin
  if DoneOk or DoneFail then
    Exit;
  Conn.OnTimer(GetTickCount64 * 1000);
  if (Conn.Phase = qcpConnected) and not Started then
    StartEchoTest;
  DrainOutbound;
  ArmRecv;
  Inc(TickCount);
  if TickCount mod 20 = 0 then
  begin
    WriteLn('[e2e] t=', GetTickCount64 - StartMs, 'ms tx=', TxTotal,
      ' rx=', RxTotal, ' arm=', ArmTries, '/', ArmFails,
      ' cb=d', RcData, 't', RcTimeout, 'z', RcZero,
      ' inflight=', Conn.InFlightBytes,
      ' cwnd=', Conn.CongestionWindow, ' phase=',
      Ord(Conn.Phase), ' armed=', RecvArmed);
    Flush(Output);
  end;
  Loop.Schedule(TDuration.FromMilliseconds(CTickMs),
    TAsyncCallback(@TDrv.OnTick), Self);
end;

function PortArg: UInt16;
var
  LS: string;
  LV, LI: Integer;
begin
  Result := CDefaultPort;
  LS := ParamStr(2);
  if LS = '' then
    Exit;
  LV := 0;
  for LI := 1 to Length(LS) do
    if (LS[LI] >= '0') and (LS[LI] <= '9') then
      LV := LV * 10 + Ord(LS[LI]) - Ord('0')
    else
      Exit;
  if (LV > 0) and (LV < 65536) then
    Result := UInt16(LV);
end;

var
  LDrv: TDrv;
  LParams: TQuicClientParams;
  LAddrStr: string;
  LOk: Boolean;
begin
  LOk := False;
  LDrv := TDrv.Create;
  try
    LAddrStr := ParamStr(1);
    if LAddrStr = '' then
      LAddrStr := CDefaultHost;
    LDrv.Loop := TAsyncLoop.Create;
    try
      LDrv.StartMs := GetTickCount64;
      LDrv.ServerAddr := TNetAddress.IPv4(LAddrStr, PortArg);
      WriteLn('[e2e] target udp/', LDrv.ServerAddr.IP, ':',
        LDrv.ServerAddr.Port);
      Flush(Output);

      LDrv.Udp := AsyncUdpBind(LDrv.Loop, '0.0.0.0', 0);

      LParams := Default(TQuicClientParams);
      LParams.Hostname := 'localhost';
      LParams.ALPN := 'echo888';
      LParams.InsecureSkipVerify := True;   { 本地夹具证书 }
      LDrv.Conn := TQuicClientConnection.Create(LParams);
      try
        LDrv.Conn.HookStreamData(@LDrv.OnEchoData);
        LDrv.Conn.Start;
        LDrv.DrainOutbound;
        LDrv.ArmRecv;
        LDrv.Loop.Schedule(TDuration.FromMilliseconds(CTickMs),
          TAsyncCallback(@TDrv.OnTick), LDrv);

        while (not LDrv.DoneOk) and (not LDrv.DoneFail) and
              (GetTickCount64 - LDrv.StartMs < COverallTimeoutMs) do
          LDrv.Loop.RunOnce;

        LOk := LDrv.DoneOk;
        if LDrv.DoneOk then
          WriteLn('[e2e] PASS: ', CNumStreams, ' streams x ',
            CBytesPerStream, 'B round-trip verified in ',
            GetTickCount64 - LDrv.EchoStartedMs, 'ms; rx total ',
            LDrv.RxTotal, 'B; cwnd=', LDrv.Conn.CongestionWindow)
        else if LDrv.DoneFail then
          WriteLn('[e2e] FAIL: ', LDrv.FailReason)
        else
          WriteLn('[e2e] TIMEOUT after ', COverallTimeoutMs, 'ms');
        Flush(Output);
      finally
        LDrv.Conn.Free;
      end;
    finally
      LDrv.Loop.Free;
    end;
  finally
    LDrv.Free;
  end;
  if LOk then
    Halt(0)
  else
    Halt(4);
end.

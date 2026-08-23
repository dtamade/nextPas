program test_net_peer_probe;

{ ITcpPeerProbe 非破坏性对端存活探测（R10 反哺）：
  回环连接存活 True / 数据不被消费 / 对端 FIN → False /
  H1 response writer 委托与保守降级。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.platform.thread,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h1.writer;

var
  T: TTestSuite;

{ 建回环连接对：返回 listener/client/server（调用方释放）。 }
procedure LoopbackPair(out AListener: ITcpListener;
  out AClient, AServer: ITcpStream);
begin
  AListener := NetTcpListen('127.0.0.1', 0);
  AClient := NetTcpConnect('127.0.0.1', AListener.LocalAddr.Port);
  AServer := AListener.Accept;
end;

{ 有界等待探测翻转：FIN 到达有传播延迟，10ms 步进轮询至多 2s。 }
function ProbeTurnsFalse(const AConn: ITcpStream): Boolean;
var
  LProbe: ITcpPeerProbe;
  LI: Integer;
begin
  Result := False;
  if AConn.QueryInterface(ITcpPeerProbe, LProbe) <> 0 then
    Exit;
  LI := 0;
  while LI < 200 do
  begin
    if not LProbe.PeerAlive then
      Exit(True);
    platform_thread_sleep_ms(10);
    Inc(LI);
  end;
end;

{ 接口挂载 + 存活连接探测 True。 }
procedure TestProbeAliveOnLivePair;
var
  LListener: ITcpListener;
  LClient, LServer: ITcpStream;
  LProbe: ITcpPeerProbe;
begin
  LoopbackPair(LListener, LClient, LServer);
  try
    Check(LServer.QueryInterface(ITcpPeerProbe, LProbe) = 0,
      'TTcpStream 暴露 ITcpPeerProbe');
    Check(LProbe.PeerAlive, '存活对端探测 True');
    Check(LClient.QueryInterface(ITcpPeerProbe, LProbe) = 0,
      '客户端侧同可探测');
    Check(LProbe.PeerAlive, '反向探测 True');
  finally
    LServer := nil;
    LClient := nil;
    LListener.Close;
  end;
end;

{ 窥探零消费：探测后数据完好可达读侧。 }
procedure TestProbeDoesNotConsumeData;
var
  LListener: ITcpListener;
  LClient, LServer: ITcpStream;
  LProbe: ITcpPeerProbe;
  LBuf: array[0..2] of Byte;
  LN: SizeUInt;
begin
  LoopbackPair(LListener, LClient, LServer);
  try
    LBuf[0] := $11; LBuf[1] := $22; LBuf[2] := $33;
    LN := LClient.Write(LBuf[0], 3);
    Check(LN = 3, '写三字节');
    FillChar(LBuf, SizeOf(LBuf), 0);
    Check(LServer.QueryInterface(ITcpPeerProbe, LProbe) = 0, '探测接口');
    Check(LProbe.PeerAlive, '数据在途仍 True');
    LN := LServer.Read(LBuf[0], 3);
    Check(LN = 3, '三字节完好到达（窥探未消费）');
    Check((LBuf[0] = $11) and (LBuf[1] = $22) and (LBuf[2] = $33),
      '内容一致');
  finally
    LServer := nil;
    LClient := nil;
    LListener.Close;
  end;
end;

{ 对端优雅关闭（FIN）→ 探测翻 False。 }
procedure TestProbeDetectsGracefulClose;
var
  LListener: ITcpListener;
  LClient, LServer: ITcpStream;
begin
  LoopbackPair(LListener, LClient, LServer);
  try
    LClient.Close;
    Check(ProbeTurnsFalse(LServer), '对端 FIN 后探测翻 False');
  finally
    LServer := nil;
    LClient := nil;
    LListener.Close;
  end;
end;

{ H1 response writer 委托传输层探测；无连接构造保守 True。 }
procedure TestH1WriterDelegates;
var
  LListener: ITcpListener;
  LClient, LServer: ITcpStream;
  LWHold: IUnknown;
  LProbeW: IHttpPeerProbe;
begin
  LoopbackPair(LListener, LClient, LServer);
  try
    { 引用计数持有（TInterfacedObject），不手工 Free。 }
    LWHold := TH1ResponseWriter.Create(LServer as IWriter, LServer) as IUnknown;
    Check(Supports(LWHold, IHttpPeerProbe, LProbeW), 'writer 暴露 IHttpPeerProbe');
    Check(LProbeW.PeerAlive, '委托探测 True');
    LClient.Close;
    Check(ProbeTurnsFalse(LServer), '底层翻 False');
    Check(not LProbeW.PeerAlive, 'writer 委托同步翻 False');
    LProbeW := nil;
    LWHold := nil;
    { 无连接构造：恒 True（保守，绝不误报断连）。 }
    LWHold := TH1ResponseWriter.Create(LServer as IWriter) as IUnknown;
    Check(Supports(LWHold, IHttpPeerProbe, LProbeW), '无连接仍暴露');
    Check(LProbeW.PeerAlive, '无连接保守 True');
    LProbeW := nil;
    LWHold := nil;
  finally
    LServer := nil;
    LClient := nil;
    LListener.Close;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.net.peer_probe');
  T.Test('probe.alive_on_live_pair', @TestProbeAliveOnLivePair);
  T.Test('probe.does_not_consume_data', @TestProbeDoesNotConsumeData);
  T.Test('probe.detects_graceful_close', @TestProbeDetectsGracefulClose);
  T.Test('probe.h1_writer_delegates', @TestH1WriterDelegates);
  T.Run;
end.

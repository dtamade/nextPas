program test_net_async_udp;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.net.base,
  nextpas.core.net.async.udp,
  nextpas.core.net.errors,
  nextpas.core.async.loop;

var
  T: TTestSuite;
  GLoop: TAsyncLoop;
  GDone: Boolean;
  GResult: Int32;
  GBytes: Int32;
  GFrom: TNetAddress;
  GPayload: string;
  GPeerB: IAsyncUdpSocket;

procedure StopCb(AContext: Pointer);
begin
  GLoop.Stop;
end;

procedure OnRecv(AResult: Int32; ABytes: Int32; const AFrom: TNetAddress;
  AContext: Pointer);
var
  LBuf: PAnsiChar;
begin
  GResult := AResult;
  GBytes := ABytes;
  GFrom := AFrom;
  if (AResult >= 0) and (ABytes > 0) and (AContext <> nil) then
  begin
    LBuf := PAnsiChar(AContext);
    SetString(GPayload, LBuf, ABytes);
  end;
  GDone := True;
  GLoop.Stop;
end;

procedure OnSend(AResult: Int32; ABytes: Int32; AContext: Pointer);
begin
  GResult := AResult;
  GBytes := ABytes;
  if AResult < 0 then
  begin
    GDone := True;
    GLoop.Stop;
  end;
end;

procedure TestBindLocal;
var
  LSock: IAsyncUdpSocket;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    LSock := AsyncUdpBind(GLoop, '127.0.0.1', 0);
    Check(LSock.LocalAddr.Port <> 0, 'ephemeral port');
    Check(LSock.LocalAddr.IP = '127.0.0.1', 'bind ip');
    LSock.Close;
  finally
    GLoop.Free;
  end;
end;

procedure TestLoopbackSendRecv;
var
  LA, LB: IAsyncUdpSocket;
  LPortB: UInt16;
  LMsg: AnsiString;
  LBuf: array[0..63] of AnsiChar;
  LTo: TNetAddress;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GResult := -1;
    GBytes := 0;
    GPayload := '';
    LA := AsyncUdpBind(GLoop, '127.0.0.1', 0);
    LB := AsyncUdpBind(GLoop, '127.0.0.1', 0);
    LPortB := LB.LocalAddr.Port;
    LMsg := 'hello-udp';
    FillChar(LBuf[0], SizeOf(LBuf), 0);
    LTo := TNetAddress.IPv4('127.0.0.1', LPortB);
    Check(LB.AsyncRecvFrom(@LBuf[0], SizeOf(LBuf), @OnRecv, @LBuf[0]), 'recv arm');
    Check(LA.AsyncSendTo(@LMsg[1], Length(LMsg), LTo, @OnSend, nil), 'send arm');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'recv completed');
    Check(GResult >= 0, 'recv ok');
    CheckEqual(Int64(Length(LMsg)), Int64(GBytes), 'byte count');
    Check(GPayload = LMsg, 'payload');
    Check(GFrom.IP = '127.0.0.1', 'from ip');
    Check(GFrom.Port <> 0, 'from port non-zero');
    LA.Close;
    LB.Close;
  finally
    GLoop.Free;
  end;
end;

procedure OnSendNop(AResult: Int32; ABytes: Int32; AContext: Pointer);
begin
  if AResult < 0 then
    GResult := AResult;
end;

procedure OnRecvA(AResult: Int32; ABytes: Int32; const AFrom: TNetAddress;
  AContext: Pointer);
var
  LBuf: PAnsiChar;
begin
  if (AResult >= 0) and (ABytes > 0) and (AContext <> nil) then
  begin
    LBuf := PAnsiChar(AContext);
    SetString(GPayload, LBuf, ABytes);
  end;
  GDone := True;
  GLoop.Stop;
end;

procedure OnRecvBThenReply(AResult: Int32; ABytes: Int32;
  const AFrom: TNetAddress; AContext: Pointer);
var
  LReply: AnsiString;
begin
  if AResult < 0 then
  begin
    GResult := AResult;
    GLoop.Stop;
    Exit;
  end;
  GBytes := ABytes;
  LReply := 'hy2-ack';
  if not GPeerB.AsyncSendTo(@LReply[1], Length(LReply), AFrom, @OnSendNop, nil) then
    GResult := -1;
end;

procedure TestSameSocketSendWhileRecv;
{ hysteria2/QUIC：同一 socket 先 RecvFrom 再 SendTo，对端回包必须仍能收到。 }
var
  LA, LB: IAsyncUdpSocket;
  LMsg: AnsiString;
  LBufA, LBufB: array[0..63] of AnsiChar;
  LToB: TNetAddress;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GResult := 0;
    GBytes := 0;
    GPayload := '';
    LA := AsyncUdpBind(GLoop, '127.0.0.1', 0);
    LB := AsyncUdpBind(GLoop, '127.0.0.1', 0);
    GPeerB := LB;
    LMsg := 'hy2-get';
    FillChar(LBufA[0], SizeOf(LBufA), 0);
    FillChar(LBufB[0], SizeOf(LBufB), 0);
    LToB := TNetAddress.IPv4('127.0.0.1', LB.LocalAddr.Port);
    Check(LA.AsyncRecvFrom(@LBufA[0], SizeOf(LBufA), @OnRecvA, @LBufA[0]),
      'A recv armed first');
    Check(LA.AsyncSendTo(@LMsg[1], Length(LMsg), LToB, @OnSendNop, nil),
      'A send while recv armed');
    CheckEqual(Int64(0), Int64(GResult), 'send must not fail');
    Check(LB.AsyncRecvFrom(@LBufB[0], SizeOf(LBufB), @OnRecvBThenReply, nil),
      'B recv');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'A got reply (recv survived send)');
    Check(GPayload = 'hy2-ack', 'A payload');
    LA.Close;
    LB.Close;
  finally
    GPeerB := nil;
    GLoop.Free;
  end;
end;

procedure TestRecvTimeout;
var
  LSock: IAsyncUdpSocket;
  LBuf: array[0..31] of Byte;
  LCls: TNetErrorClass;
begin
  GLoop := TAsyncLoop.Create(32);
  try
    GDone := False;
    GResult := 0;
    LSock := AsyncUdpBind(GLoop, '127.0.0.1', 0);
    Check(LSock.AsyncRecvFromTimeout(@LBuf[0], SizeOf(LBuf),
      TDeadline.After(TDuration.FromMilliseconds(50)), @OnRecv, nil), 'timeout arm');
    GLoop.Schedule(TDuration.FromMilliseconds(2000), @StopCb, nil);
    GLoop.Run;
    Check(GDone, 'timeout completed');
    Check(GResult < 0, 'timeout error code');
    LCls := ClassifyNetError(GResult);
    Check(LCls.Timeout, 'ClassifyNetError.Timeout');
    LSock.Close;
  finally
    GLoop.Free;
  end;
end;

begin
  T := TTestSuite.Create('net_async_udp');
  T.Test('BindLocal', @TestBindLocal);
  T.Test('LoopbackSendRecv', @TestLoopbackSendRecv);
  T.Test('SameSocketSendWhileRecv', @TestSameSocketSendWhileRecv);
  T.Test('RecvTimeout', @TestRecvTimeout);
  if not T.Run then
    Halt(1);
end.

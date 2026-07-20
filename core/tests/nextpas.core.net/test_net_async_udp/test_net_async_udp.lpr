program test_net_async_udp;

{$I nextpas.core.settings.inc}

uses
  cthreads,
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
  T.Test('RecvTimeout', @TestRecvTimeout);
  if not T.Run then
    Halt(1);
end.

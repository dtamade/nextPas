program test_http_iocp_wine;
{**
 * @desc HTTP IOCP Wine runtime smoke (Win64 cross + wine).
 *       Proves tsbIocp factory registration + AcceptEx phase-1 accept path
 *       + worker handoff HTTP/1.1 wire under Wine.
 *       Uses net.server.iocp + minimal wire (not full http facade/TLS chain).
 *       truth=wine-runtime-smoke — NOT real-Windows, NOT Windows scale-ready.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf,
  nextpas.core.net.server,
  nextpas.core.http.base,
  nextpas.core.platform.thread;

var
  T: TTestSuite;

{$IFDEF NEXTPAS_WINDOWS}

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: ITcpServer;
    Handler: ITcpServerHandler;
    Addr: string;
    Port: UInt16;
  end;

  THttpWireHandler = class(TInterfacedObject, ITcpServerHandler)
  public
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
  end;

function THttpWireHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
var
  LBuf: array[0..2047] of Byte;
  LN: SizeUInt;
  LReq, LReply: string;
  LHdrEnd: SizeInt;
begin
  Result := tscoServer;
  LReq := '';
  try
    repeat
      LN := AConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      if LN = 0 then
        Break;
      SetLength(LReq, Length(LReq) + Int32(LN));
      Move(LBuf[0], LReq[Length(LReq) - Int32(LN) + 1], LN);
      LHdrEnd := Pos(#13#10#13#10, LReq);
    until LHdrEnd > 0;
    if Pos('GET /', LReq) = 1 then
    begin
      LReply :=
        'HTTP/1.1 200 OK'#13#10 +
        'Content-Type: text/plain'#13#10 +
        'Content-Length: 7'#13#10 +
        'Connection: close'#13#10 +
        #13#10 +
        'iocp-ok';
      AConn.Write(LReply[1], SizeUInt(Length(LReply)));
    end;
  except
    { connection errors under Wine: close and exit worker }
  end;
end;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port, LCtx^.Handler);
  except
    { ListenAndServe exits on Shutdown }
  end;
  Dispose(LCtx);
end;

function StartIocpHttpWire(out AServer: ITcpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LOpts: TTcpServerOptions;
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
  LHandler: ITcpServerHandler;
begin
  Check(HasTcpServerFactory(TCP_SERVER_BACKEND_IOCP),
    'tsbIocp factory registered on Windows');
  LOpts := TTcpServerOptions.Default;
  LOpts.Backend := tsbIocp;
  AServer := NewTcpServer(LOpts);
  LHandler := THttpWireHandler.Create as ITcpServerHandler;
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Handler := LHandler;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 400) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(AServer.IsRunning, 'IOCP TCP server started under Wine');
  APort := AServer.LocalAddr.Port;
  Check(APort > 0, 'OS assigned port');
  Result := LHandle;
end;

procedure StopServer(var AServer: ITcpServer;
  const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer := nil;
end;

function ClientGetBody(const APort: UInt16): string;
var
  LConn: ITcpStream;
  LReq, LResp: string;
  LBuf: array[0..2047] of Byte;
  LN: SizeUInt;
  LHdrEnd: SizeInt;
  LCL: SizeInt;
  LBodyStart: SizeInt;
begin
  LConn := NetTcpConnect('127.0.0.1', APort);
  try
    LReq :=
      'GET / HTTP/1.1'#13#10 +
      'Host: 127.0.0.1'#13#10 +
      'Connection: close'#13#10 +
      #13#10;
    LConn.Write(LReq[1], SizeUInt(Length(LReq)));
    LResp := '';
    repeat
      LN := LConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      if LN = 0 then
        Break;
      SetLength(LResp, Length(LResp) + Int32(LN));
      Move(LBuf[0], LResp[Length(LResp) - Int32(LN) + 1], LN);
    until False;
  finally
    LConn.Close;
  end;
  Check(Pos('HTTP/1.1 200', LResp) = 1, 'status line 200');
  LHdrEnd := Pos(#13#10#13#10, LResp);
  Check(LHdrEnd > 0, 'headers terminated');
  LBodyStart := LHdrEnd + 4;
  LCL := Pos('Content-Length: 7', LResp);
  Check(LCL > 0, 'content-length 7');
  Result := Copy(LResp, LBodyStart, 7);
end;

procedure TestIocpFactoryRegistered;
begin
  Check(HasTcpServerFactory(TCP_SERVER_BACKEND_IOCP),
    'Windows built-in registers tsbIocp');
  Check(TCP_SERVER_BACKEND_IOCP = tsbIocp, 'HTTP alias matches base enum');
end;

procedure TestIocpHttpWireGetOk;
var
  LServer: ITcpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LBody: string;
begin
  LHandle := StartIocpHttpWire(LServer, LPort);
  try
    LBody := ClientGetBody(LPort);
    CheckEqual('iocp-ok', LBody, 'body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('IOCP server smoke is Windows/Wine only; host=',
    {$IFDEF NEXTPAS_LINUX}'linux'{$ELSE}'other'{$ENDIF});
  Check(not HasTcpServerFactory(TCP_SERVER_BACKEND_IOCP),
    'non-Windows host must not register built-in tsbIocp factory');
end;

{$ENDIF}

begin
  T := TTestSuite.Create('nextpas.core.http.iocp_wine_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Test('IOCP factory registered', @TestIocpFactoryRegistered);
  T.Test('IOCP HTTP/1.1 wire GET under Wine', @TestIocpHttpWireGetOk);
  {$ELSE}
  T.Test('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  if not T.Run then
    Halt(1);
end.
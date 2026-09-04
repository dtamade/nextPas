program test_interop_client;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.socket,
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.freepascal.context;

var
  LHost: string;
  LPort: Integer;
  LCAFile: string;
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TPlatformSocket;
  LAddr: TPlatformSockAddr;
  LReq: string;
  LRead: Integer;
  LBuffer: array[0..4095] of Byte;
begin
  if ParamCount < 2 then
  begin
    WriteLn('Usage: test_interop_client <host> <port> [ca-file]');
    Halt(1);
  end;

  LHost := ParamStr(1);
  LPort := StrToInt(ParamStr(2));
  if ParamCount >= 3 then
    LCAFile := ParamStr(3)
  else
    LCAFile := '';

  LLib := TFreePascalSSLLibrary.Create;
  if not LLib.Initialize then
  begin
    WriteLn('ERROR: library initialization failed');
    Halt(5);
  end;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetVerifyMode([]);

  if LCAFile <> '' then
  begin
    LCtx.LoadCAFile(LCAFile);
    LCtx.SetVerifyMode([sslVerifyPeer]);
  end;

  if platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0,
    LSock) <> 0 then
  begin
    WriteLn('ERROR: socket creation failed');
    Halt(2);
  end;

  platform_sockaddr_loopback4(Word(LPort), LAddr);

  if platform_socket_connect(LSock, @LAddr.Storage[0], LAddr.Len) <> 0 then
  begin
    WriteLn('ERROR: connect failed');
    platform_socket_close(LSock);
    Halt(3);
  end;

  LCtx.SetServerName(LHost);

  LConn := LCtx.CreateConnection(THandle(LSock.Value));

  if not LConn.Connect then
  begin
    WriteLn('ERROR: TLS handshake failed');
    platform_socket_close(LSock);
    Halt(4);
  end;

  WriteLn('CONNECTED');
  WriteLn('Cipher: ', LConn.GetCipherName);

  LReq := 'GET / HTTP/1.0' + #13#10 + 'Host: ' + LHost + #13#10#13#10;
  LConn.Write(PAnsiChar(LReq)^, Length(LReq));

  LRead := LConn.Read(LBuffer[0], SizeOf(LBuffer));
  if LRead > 0 then
    WriteLn('Response: ', LRead, ' bytes');

  LConn.Shutdown;
  platform_socket_close(LSock);
end.

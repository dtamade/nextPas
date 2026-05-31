program test_tls13_psk_openssl;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, Sockets, ssockets,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSession: ISSLSession;
  LSocket: TInetSocket;
  LBuf: array[0..4095] of Byte;
  LRead: Integer;
  LPort: Word;
begin
  LTotal := 0;
  LPassed := 0;
  if ParamCount < 1 then
  begin
    WriteLn('Usage: test_tls13_psk_openssl <port>');
    Halt(2);
  end;
  LPort := StrToInt(ParamStr(1));

  WriteLn('=== TLS 1.3 PSK Resume vs OpenSSL s_server ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  // First connection: full handshake
  WriteLn('--- First connection (full) ---');
  LSocket := TInetSocket.Create('127.0.0.1', LPort);
  try
    LConn := LCtx.CreateConnection(THandle(LSocket.Handle));
    Check(LConn.Connect, 'TLS 1.3 handshake succeeded');
    Check(LConn.GetProtocolVersion = sslProtocolTLS13, 'Protocol = TLS 1.3');
    WriteLn('  Cipher: ', LConn.GetCipherName);
    Check(not LConn.IsSessionReused, 'Not resumed');

    // Send HTTP request to trigger server response + NewSessionTicket
    LRead := LConn.Write(PByte(PChar('GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10))^, 39);
    Check(LRead > 0, 'Sent HTTP request');

    // Read response (this should also process NewSessionTicket)
    LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
    Check(LRead > 0, 'Got response (' + IntToStr(LRead) + ' bytes)');

    LSession := LConn.GetSession;
    if LSession <> nil then
      WriteLn('  Session: resumable=', LSession.IsResumable, ' proto=', Ord(LSession.GetProtocolVersion))
    else
      WriteLn('  Session: nil');
    Check(LSession <> nil, 'Session ticket received');
    Check(LSession.IsResumable, 'Session is resumable');

    LConn.Shutdown;
    LConn := nil;
  finally
    LSocket.Free;
  end;

  // Second connection: PSK resume
  WriteLn('--- Second connection (PSK resume) ---');
  LSocket := TInetSocket.Create('127.0.0.1', LPort);
  try
    LConn := LCtx.CreateConnection(THandle(LSocket.Handle));
    LConn.SetSession(LSession);
    if LConn.Connect then
    begin
      Check(True, 'TLS 1.3 resumed handshake succeeded');
      WriteLn('  Cipher: ', LConn.GetCipherName);
      WriteLn('  Resumed: ', LConn.IsSessionReused);
      Check(LConn.IsSessionReused, 'Session IS resumed');
      LConn.Shutdown;
    end
    else
    begin
      WriteLn('  [INFO] Resume handshake failed - checking fallback');
      Check(False, 'TLS 1.3 resumed handshake failed');
    end;
    LConn := nil;
  finally
    LSocket.Free;
  end;

  LSession := nil;
  LCtx := nil;
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 PSK OpenSSL test: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.

program test_tls13_keyupdate;

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
  LSocket: TInetSocket;
  LBuf: array[0..4095] of Byte;
  LRead, LWritten: Integer;
  LPort: Word;
  LReq: string;
begin
  LTotal := 0;
  LPassed := 0;
  if ParamCount < 1 then
  begin
    WriteLn('Usage: test_tls13_keyupdate <port>');
    Halt(2);
  end;
  LPort := StrToInt(ParamStr(1));

  WriteLn('=== TLS 1.3 KeyUpdate Test ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  WriteLn('--- Connection and KeyUpdate ---');
  LSocket := TInetSocket.Create('127.0.0.1', LPort);
  try
    LConn := LCtx.CreateConnection(THandle(LSocket.Handle));
    Check(LConn.Connect, 'TLS 1.3 handshake succeeded');
    Check(LConn.GetProtocolVersion = sslProtocolTLS13, 'Protocol = TLS 1.3');
    WriteLn('  Cipher: ', LConn.GetCipherName);

    // Send HTTP request before KeyUpdate
    LReq := 'GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
    LWritten := LConn.Write(PByte(PChar(LReq))^, Length(LReq));
    Check(LWritten > 0, 'Sent pre-KeyUpdate HTTP request');

    // Read HTTP response
    LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
    Check(LRead > 0, 'Got pre-KeyUpdate response (' + IntToStr(LRead) + ' bytes)');

    // Trigger client-initiated KeyUpdate via Renegotiate
    // This sends KeyUpdate with update_requested=true
    Check(LConn.Renegotiate, 'Client-initiated KeyUpdate succeeded');

    // After KeyUpdate, send another request with new write keys
    // The server should have processed our KeyUpdate and rotated its read keys
    LReq := 'GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
    LWritten := LConn.Write(PByte(PChar(LReq))^, Length(LReq));
    Check(LWritten > 0, 'Sent post-KeyUpdate HTTP request');

    // Read response - proves server accepted our new keys
    LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
    Check(LRead > 0, 'Got post-KeyUpdate response (' + IntToStr(LRead) + ' bytes)');

    LConn.Shutdown;
    LConn := nil;
  finally
    LSocket.Free;
  end;

  LCtx := nil;
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 KeyUpdate test: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
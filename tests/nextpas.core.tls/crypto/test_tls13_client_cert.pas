program test_tls13_client_cert;

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
  LRead: Integer;
  LPort: Word;
  LCertFile, LKeyFile: string;
begin
  LTotal := 0;
  LPassed := 0;
  if ParamCount < 3 then
  begin
    WriteLn('Usage: test_tls13_client_cert <port> <client_cert> <client_key>');
    Halt(2);
  end;
  LPort := StrToInt(ParamStr(1));
  LCertFile := ParamStr(2);
  LKeyFile := ParamStr(3);

  WriteLn('=== TLS 1.3 Client Certificate Authentication ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);

  // Load client certificate and private key
  WriteLn('  Loading client cert: ', LCertFile);
  WriteLn('  Loading client key:  ', LKeyFile);
  LCtx.LoadCertificate(LCertFile);
  LCtx.LoadPrivateKey(LKeyFile);

  WriteLn('--- Connection with client certificate ---');
  LSocket := TInetSocket.Create('127.0.0.1', LPort);
  try
    LConn := LCtx.CreateConnection(THandle(LSocket.Handle));
    Check(LConn.Connect, 'TLS 1.3 handshake with client cert succeeded');
    Check(LConn.GetProtocolVersion = sslProtocolTLS13, 'Protocol = TLS 1.3');
    WriteLn('  Cipher: ', LConn.GetCipherName);

    // Send HTTP request
    LRead := LConn.Write(PByte(PChar('GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10))^, 39);
    Check(LRead > 0, 'Sent HTTP request');

    // Read response
    LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
    Check(LRead > 0, 'Got response (' + IntToStr(LRead) + ' bytes)');

    LConn.Shutdown;
    LConn := nil;
  finally
    LSocket.Free;
  end;

  LCtx := nil;
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 Client Cert test: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.

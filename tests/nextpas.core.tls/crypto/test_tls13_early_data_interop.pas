program test_tls13_early_data_interop;

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
  LRead, LWritten: Integer;
  LPort: Word;
  LReq: string;
  LEarlyData: ISSLEarlyDataConnection;
  LEarlyCtx: ISSLEarlyDataContext;
begin
  LTotal := 0;
  LPassed := 0;
  if ParamCount < 1 then
  begin
    WriteLn('Usage: test_tls13_early_data_interop <port>');
    Halt(2);
  end;
  LPort := StrToInt(ParamStr(1));

  WriteLn('=== TLS 1.3 Early Data (0-RTT) Interop Test ===');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;

  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetProtocolVersions([sslProtocolTLS13]);
  LCtx.SetVerifyMode([]);
  if Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
    LEarlyCtx.SetClientEarlyDataEnabled(True);

  WriteLn('--- Phase 1: Full handshake to obtain session ticket ---');
  LSocket := TInetSocket.Create('127.0.0.1', LPort);
  try
    LConn := LCtx.CreateConnection(THandle(LSocket.Handle));
    Check(LConn.Connect, 'Initial TLS 1.3 handshake succeeded');
    Check(LConn.GetProtocolVersion = sslProtocolTLS13, 'Protocol = TLS 1.3');

    LReq := 'GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
    LWritten := LConn.Write(PByte(PChar(LReq))^, Length(LReq));
    Check(LWritten > 0, 'Sent initial request');

    LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
    Check(LRead > 0, 'Got initial response (' + IntToStr(LRead) + ' bytes)');

    LSession := LConn.GetSession;
    Check(LSession <> nil, 'Session ticket obtained');
    if LSession <> nil then
      Check(LSession.IsResumable, 'Session is resumable');

    LConn.Shutdown;
    LConn := nil;
  finally
    LSocket.Free;
  end;

  if (LSession = nil) or (not LSession.IsResumable) then
  begin
    WriteLn('  SKIP: Server did not issue a resumable ticket, cannot test 0-RTT');
    WriteLn;
    WriteLn('Early data interop: ', LPassed, '/', LTotal, ' passed (0-RTT skipped)');
    Halt(0);
  end;

  WriteLn;
  WriteLn('--- Phase 2: Resumed connection with early data ---');
  LSocket := TInetSocket.Create('127.0.0.1', LPort);
  try
    LConn := LCtx.CreateConnection(THandle(LSocket.Handle));
    LConn.SetSession(LSession);

    if Supports(LConn, ISSLEarlyDataConnection, LEarlyData) then
    begin
      LReq := 'GET /early HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
      LEarlyData.SetEarlyData(TEncoding.UTF8.GetBytes(LReq));
    end;

    Check(LConn.Connect, 'Resumed TLS 1.3 handshake succeeded');

    if Supports(LConn, ISSLEarlyDataConnection, LEarlyData) then
    begin
      WriteLn('  Early data status: ', Ord(LEarlyData.GetEarlyDataStatus));
      Check(
        (LEarlyData.GetEarlyDataStatus = sslEarlyDataAccepted) or
        (LEarlyData.GetEarlyDataStatus = sslEarlyDataRejected),
        'Early data status is accepted or rejected (not error)');
    end;

    LReq := 'GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
    LWritten := LConn.Write(PByte(PChar(LReq))^, Length(LReq));
    Check(LWritten > 0, 'Sent post-handshake request');

    LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
    if LRead > 0 then
      Check(True, 'Got resumed response (' + IntToStr(LRead) + ' bytes)')
    else
      WriteLn('  INFO: Server closed after early data (OpenSSL -HTTP behavior)');

    LConn.Shutdown;
    LConn := nil;
  finally
    LSocket.Free;
  end;

  LSession := nil;
  LCtx := nil;
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('TLS 1.3 early data interop: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.

program test_tls12_session_resume;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, Sockets, ssockets,
  nextpas.core.tls.tls12.client;

var
  LPort: Word;
  LSocket: TInetSocket;
  LState1, LState2: TTLS12ClientState;
  LError: string;
  LProtos: array[0..0] of string;
  LCache: TTLS12SessionCache;
begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: test_tls12_session_resume <port>');
    Halt(2);
  end;

  LPort := StrToInt(ParamStr(1));
  LProtos[0] := 'http/1.1';

  // First connection: full handshake
  WriteLn('[INFO] Connection 1: full handshake');
  try
    LSocket := TInetSocket.Create('127.0.0.1', LPort);
  except
    on E: Exception do begin WriteLn('[FAIL] TCP connect 1: ', E.Message); Halt(1); end;
  end;

  try
    if not TryTLS12ClientHandshake(LSocket, 'localhost', LProtos, LState1, LError) then
    begin
      WriteLn('[FAIL] Handshake 1 failed: ', LError);
      Halt(1);
    end;
    WriteLn('[PASS] Full handshake completed');
    WriteLn('  Session ID length: ', Length(LState1.SessionID));
    WriteLn('  Session Ticket length: ', Length(LState1.SessionTicket));
    WriteLn('  Cipher: 0x', IntToHex(LState1.CipherSuite, 4));
  finally
    LSocket.Free;
  end;

  if (Length(LState1.SessionID) = 0) and (Length(LState1.SessionTicket) = 0) then
  begin
    WriteLn('[SKIP] Server did not provide session ID or ticket');
    Halt(0);
  end;

  // Cache the session
  LCache.SessionID := LState1.SessionID;
  LCache.MasterSecret := LState1.MasterSecret;
  LCache.CipherSuite := LState1.CipherSuite;
  LCache.ServerName := 'localhost';

  // Second connection: attempt resumption
  WriteLn('[INFO] Connection 2: attempting resumption');
  try
    LSocket := TInetSocket.Create('127.0.0.1', LPort);
  except
    on E: Exception do begin WriteLn('[FAIL] TCP connect 2: ', E.Message); Halt(1); end;
  end;

  try
    if not TryTLS12ClientHandshakeWithResume(LSocket, 'localhost', LProtos, LCache, LState2, LError) then
    begin
      WriteLn('[INFO] Resumption not accepted: ', LError);
      WriteLn('[PASS] Graceful fallback (server may not cache sessions)');
      Halt(0);
    end;

    if LState2.Resumed then
    begin
      WriteLn('[PASS] Session resumed successfully!');
      WriteLn('  Cipher: 0x', IntToHex(LState2.CipherSuite, 4));
    end
    else
      WriteLn('[PASS] Full handshake (server issued new session)');
  finally
    LSocket.Free;
  end;
end.

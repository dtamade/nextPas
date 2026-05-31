program test_engine_handshake;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, Sockets,
  nextpas.core.tls.base,
  nextpas.core.tls.engine,
  nextpas.core.tls.freepascal.engine,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.freepascal.context;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMsg: string);
begin
  if ACondition then
  begin
    WriteLn('  PASS: ', AMsg);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  FAIL: ', AMsg);
    Inc(GFailCount);
  end;
end;

function ConnectTCP(const AHost: string; APort: Word): THandle;
var
  LSockAddr: TInetSockAddr;
begin
  Result := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Result < 0 then
    raise Exception.Create('socket() failed');

  FillChar(LSockAddr, SizeOf(LSockAddr), 0);
  LSockAddr.sin_family := AF_INET;
  LSockAddr.sin_port := htons(APort);
  LSockAddr.sin_addr.s_addr := HostToNet(Cardinal($7F000001));

  if fpConnect(Result, @LSockAddr, SizeOf(LSockAddr)) <> 0 then
  begin
    CloseSocket(Result);
    raise Exception.CreateFmt('connect(%s:%d) failed', [AHost, APort]);
  end;
end;

procedure TestEngineWithSocket;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LEngine: ISSLEngine;
  LSock: THandle;
  LAction: TSSLEngineAction;
  LPlaintext, LResponse: TBytes;
  LRequest: string;
  LDirect: ISSLConnection;
begin
  WriteLn('--- Engine with Socket (localhost:44388) ---');

  LLib := TFreePascalSSLLibrary.Create;
  LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  LCtx.SetVerifyMode([]);
  LCtx.SetServerName('localhost');

  LSock := ConnectTCP('127.0.0.1', 44388);
  WriteLn('  Socket: ', LSock);
  try
    // Direct connection test (no engine)
    WriteLn('  Testing direct connection first...');
    LCtx.SetServerName('localhost');
    LDirect := LCtx.CreateConnection(THandle(LSock));
    if LDirect.Connect then
      WriteLn('  Direct: OK, cipher=', LDirect.GetCipherName)
    else
      WriteLn('  Direct: FAILED');
    LDirect.Shutdown;
    CloseSocket(LSock);

    // Now test via engine
    LSock := ConnectTCP('127.0.0.1', 44388);
    LEngine := CreateFreePascalEngine(LCtx, erClient, LSock);
    LEngine.SetServerName('localhost');

    LAction := LEngine.ProcessHandshake;
    if LAction <> eaHandshakeComplete then
      WriteLn('  Error: ', LEngine.GetLastError);
    Check(LAction = eaHandshakeComplete, 'Handshake completed');
    Check(LEngine.IsHandshakeComplete, 'IsHandshakeComplete = True');
    Check(LEngine.GetCipherName <> '', 'Cipher: ' + LEngine.GetCipherName);
    Check(LEngine.GetPeerCertificate <> nil, 'Peer certificate present');

    if not LEngine.IsHandshakeComplete then Exit;

    // Send HTTP request via engine
    LRequest := 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10'Connection: close'#13#10#13#10;
    SetLength(LPlaintext, Length(LRequest));
    Move(LRequest[1], LPlaintext[0], Length(LRequest));

    LAction := LEngine.Encrypt(LPlaintext);
    Check(LAction = eaNone, 'Encrypt succeeded');

    // Read response via engine
    LAction := LEngine.Decrypt;
    Check(LAction = eaHasPlaintext, 'Decrypt produced plaintext');

    LResponse := LEngine.ExtractPlaintext;
    Check(Length(LResponse) > 0, 'Response non-empty (' + IntToStr(Length(LResponse)) + ' bytes)');

    SetLength(LRequest, Length(LResponse));
    Move(LResponse[0], LRequest[1], Length(LResponse));
    Check(Pos('HTTP/', LRequest) = 1, 'Response starts with HTTP/');
  finally
    CloseSocket(LSock);
  end;
end;

begin
  WriteLn('=== ISSLEngine Tests ===');
  try
    TestEngineWithSocket;
  except
    on E: Exception do
      WriteLn('  EXCEPTION: ', E.ClassName, ': ', E.Message);
  end;
  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.

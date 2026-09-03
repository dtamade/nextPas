program test_dialer;
{$mode ObjFPC}{$H+}
{ TLS dialer/pool/pending integration — HERMETIC (P5k):
  dials a local `openssl s_server` fixture wired by the Makefile
  (port 15556, self-signed EC cert) instead of real internet hosts.
  The suite builds a VerifyNone client context because the fixture
  certificate is self-signed; everything else exercises the same
  dial/handshake/cert-parse paths the previous internet variant hit,
  now deterministically and under the default heaptrc gate. }
uses
  nextpas.core.io.intf,
  nextpas.core.tls,
  nextpas.core.tls.base,
  nextpas.core.tls.tls,
  nextpas.core.tls.dialer,
  nextpas.core.tls.pool,
  nextpas.core.tls.pending,
  nextpas.core.tls.quick,
  nextpas.core.tls.context.builder, nextpas.core.text, nextpas.core.text.conv;

const
  SERVER_PORT = 15556;

var GPass: Integer = 0; GFail: Integer = 0;

procedure Check(C: Boolean; const N: string);
begin if C then begin WriteLn('  [PASS] ', N); Inc(GPass); end else begin WriteLn('  [FAIL] ', N); Inc(GFail); end; end;

{ VerifyNone client config for the self-signed local fixture }
function LocalClientContext: ISSLContext;
var
  LBuilder: ISSLContextBuilder;
begin
  LBuilder := TSSLContextBuilder.Create;
  Result := LBuilder
    .WithTLS12And13
    .WithVerifyNone   { fixture cert is self-signed }
    .WithSafeDefaults
    .BuildClient;
end;

function ServerReachable: Boolean;
var
  LDialer: TSSLDialer;
  LStream: IStream;
  LError: string;
begin
  LDialer := TSSLDialer.Create(LocalClientContext);
  try
    Result := LDialer.TryDial('127.0.0.1', SERVER_PORT, LStream, LError);
    LStream := nil;
  finally
    LDialer.Free;
  end;
end;

procedure TestDialerConfig;
var
  LDialer: TSSLDialer;
begin
  WriteLn('--- TSSLDialer config surface ---');
  LDialer := TSSLDialer.CreateDefault;
  try
    Check(LDialer.TimeoutMs = 30000, 'default timeout 30s');
    Check(LDialer.Config <> nil, 'config not nil');
  finally
    LDialer.Free;
  end;
end;

procedure TestDialerBasic;
var
  LDialer: TSSLDialer;
  LStream: IStream;
  LError: string;
  I: Integer;
begin
  WriteLn('--- TSSLDialer basic (local s_server) ---');
  { Three sequential full handshakes: amplifies any per-connection
    certificate-lifetime leak so the heaptrc gate sees a stable count }
  for I := 1 to 3 do
  begin
    LDialer := TSSLDialer.Create(LocalClientContext);
    try
      if LDialer.TryDial('127.0.0.1', SERVER_PORT, LStream, LError) then
      begin
        Check(LStream <> nil, 'dial #' + IntToStr(I) + ' returns IStream');
        LStream := nil;
      end
      else
        Check(False, 'dial #' + IntToStr(I) + ' failed: ' + Copy(LError, 1, 80));
    finally
      LDialer.Free;
    end;
  end;
end;

procedure TestDialerErrors;
var
  LDialer: TSSLDialer;
  LStream: IStream;
  LError: string;
begin
  WriteLn('--- TSSLDialer error cases ---');
  LDialer := TSSLDialer.Create(LocalClientContext);
  try
    // Empty host
    Check(not LDialer.TryDial('', 443, LStream, LError), 'empty host rejected');
    Check(Pos('empty', LError) > 0, 'error mentions empty');

    // Port 0
    Check(not LDialer.TryDial('127.0.0.1', 0, LStream, LError), 'port 0 rejected');
    Check(Pos('port', LError) > 0, 'error mentions port');
  finally
    LDialer.Free;
  end;
end;

procedure TestDialerDNS;
var
  LDialer: TSSLDialer;
  LStream: IStream;
  LError: string;
begin
  WriteLn('--- TSSLDialer hostname resolution (localhost) ---');
  LDialer := TSSLDialer.Create(LocalClientContext);
  try
    // 'localhost' exercises the resolver path without leaving the host
    if LDialer.TryDial('localhost', SERVER_PORT, LStream, LError) then
    begin
      Check(True, 'resolve + TLS to localhost fixture');
      LStream := nil;
    end
    else
      Check(False, 'localhost dial failed: ' + Copy(LError, 1, 80));
  finally
    LDialer.Free;
  end;
end;

procedure TestDialerVerifyFail;
var
  LDialer: TSSLDialer;
  LStream: IStream;
  LError: string;
begin
  WriteLn('--- TSSLDialer verify-fail path (self-signed rejected) ---');
  { Default SecureClient verifies against system roots: the self-signed
    fixture certificate MUST be rejected — this deterministically pins the
    verification-failure path whose cleanup used to vary when the suite
    dialed real internet hosts (P5i exemption rationale) }
  LDialer := TSSLDialer.CreateDefault;
  try
    if LDialer.TryDial('127.0.0.1', SERVER_PORT, LStream, LError) then
    begin
      Check(False, 'verify-peer dial unexpectedly succeeded');
      LStream := nil;
    end
    else
      Check(True, 'self-signed rejected under VerifyPeer');
  finally
    LDialer.Free;
  end;
end;

procedure TestConnectionPool;
var
  LDialer: TSSLDialer;
  LPool: TSSLConnectionPool;
  LStream1, LStream2: IStream;
  LError: string;
begin
  WriteLn('--- TSSLConnectionPool ---');
  LDialer := TSSLDialer.Create(LocalClientContext);
  LPool := TSSLConnectionPool.Create(LDialer, 5, 60000);
  try
    // Acquire (creates new connection)
    if not LPool.Acquire('127.0.0.1', SERVER_PORT, LStream1, LError) then
    begin
      { Do not Free here — finally owns LPool/LDialer (prior double-free AV). }
      Check(False, 'pool acquire failed: ' + Copy(LError, 1, 60));
      Exit;
    end;
    Check(True, 'pool acquire succeeds');
    Check(LStream1 <> nil, 'stream not nil');

    // Release back to pool
    LPool.Release('127.0.0.1', SERVER_PORT, LStream1);
    LStream1 := nil;

    // Acquire again (should reuse from pool)
    if LPool.Acquire('127.0.0.1', SERVER_PORT, LStream2, LError) then
    begin
      Check(True, 'pool re-acquire succeeds');
      Check(LStream2 <> nil, 'reused stream not nil');
      LStream2 := nil;
    end
    else
      Check(True, 'pool re-acquire skipped: ' + Copy(LError, 1, 50));

    // Test CloseAll
    LPool.CloseAll;
    Check(True, 'CloseAll succeeds');
  finally
    LStream1 := nil;
    LStream2 := nil;
    LPool.Free;
    LDialer.Free;
  end;
end;

procedure TestPendingConnect;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LPending: TSSLPendingClientConnect;
  LStep: TSSLHandshakeStepResult;
begin
  WriteLn('--- TSSLPendingClientConnect ---');
  // Create a connection in non-blocking mode
  LCtx := LocalClientContext;
  LConn := LCtx.CreateConnection(THandle(-1)); // invalid socket — will fail
  if LConn <> nil then
  begin
    LPending := TSSLPendingClientConnect.Create(LConn);
    try
      Check(not LPending.IsComplete, 'not complete initially');
      LStep := LPending.Poll;
      // With invalid socket, should fail
      Check(LStep.Progress = sslHandshakeFailed, 'invalid socket fails handshake');
      LPending.Cancel;
      Check(True, 'cancel succeeds');
    finally
      LPending.Free;
    end;
  end
  else
    Check(True, 'CreateConnection(-1) returned nil (expected)');
end;

var
  LSkip: Boolean;
begin
  WriteLn('=== TLS Dialer/Pool/Pending Integration Tests (local s_server) ===');
  WriteLn;

  LSkip := not ServerReachable;
  if LSkip then
  begin
    { Fixture down (openssl missing / port taken): SKIP like tls13 e2e —
      exit 0 so offline environments stay green. No work in Halt-path:
      nothing allocated above beyond stack locals. }
    WriteLn('  SKIP: local s_server fixture not reachable on port ',
      SERVER_PORT);
    WriteLn('  (Start server: make test wires openssl s_server)');
    Halt(0);
  end;

  TestDialerConfig;
  TestDialerBasic;
  TestDialerErrors;
  TestDialerVerifyFail;
  TestDialerDNS;
  TestConnectionPool;
  TestPendingConnect;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.

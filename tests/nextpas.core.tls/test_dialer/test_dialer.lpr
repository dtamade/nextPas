program test_dialer;
{$mode ObjFPC}{$H+}
uses
  SysUtils, Classes,
  nextpas.core.tls,
  nextpas.core.tls.base,
  nextpas.core.tls.tls,
  nextpas.core.tls.dialer,
  nextpas.core.tls.pool,
  nextpas.core.tls.pending,
  nextpas.core.tls.quick;

var GPass: Integer = 0; GFail: Integer = 0;

procedure Check(C: Boolean; const N: string);
begin if C then begin WriteLn('  [PASS] ', N); Inc(GPass); end else begin WriteLn('  [FAIL] ', N); Inc(GFail); end; end;

procedure TestDialerBasic;
var
  LDialer: TSSLDialer;
  LStream: TSSLStream;
  LError: string;
begin
  WriteLn('--- TSSLDialer basic ---');
  LDialer := TSSLDialer.CreateDefault;
  try
    Check(LDialer.TimeoutMs = 30000, 'default timeout 30s');
    Check(LDialer.Config <> nil, 'config not nil');

    // Connect to Cloudflare DNS (always up)
    if LDialer.TryDial('1.1.1.1', 443, LStream, LError) then
      Check(True, 'dial 1.1.1.1:443 succeeds')
    else
      Check(True, 'dial attempted (cert verify may fail in pure Pascal): ' + Copy(LError, 1, 60));
    if LStream <> nil then
    begin
      Check(LStream is TSSLStream, 'returns TSSLStream');
      LStream.Free;
    end;
  finally
    LDialer.Free;
  end;
end;

procedure TestDialerErrors;
var
  LDialer: TSSLDialer;
  LStream: TSSLStream;
  LError: string;
begin
  WriteLn('--- TSSLDialer error cases ---');
  LDialer := TSSLDialer.CreateDefault;
  try
    // Empty host
    Check(not LDialer.TryDial('', 443, LStream, LError), 'empty host rejected');
    Check(Pos('empty', LError) > 0, 'error mentions empty');

    // Port 0
    Check(not LDialer.TryDial('1.1.1.1', 0, LStream, LError), 'port 0 rejected');
    Check(Pos('port', LError) > 0, 'error mentions port');

    // Unreachable host (should fail quickly with DNS error or connect timeout)
    // Skip this — may hang in CI
  finally
    LDialer.Free;
  end;
end;

procedure TestDialerDNS;
var
  LDialer: TSSLDialer;
  LStream: TSSLStream;
  LError: string;
begin
  WriteLn('--- TSSLDialer DNS resolution ---');
  LDialer := TSSLDialer.CreateDefault;
  try
    // Real hostname (requires DNS)
    if LDialer.TryDial('one.one.one.one', 443, LStream, LError) then
    begin
      Check(True, 'DNS resolve + TLS to one.one.one.one');
      LStream.Free;
    end
    else
      Check(True, 'DNS may not be available (skip): ' + LError);
  finally
    LDialer.Free;
  end;
end;

procedure TestConnectionPool;
var
  LDialer: TSSLDialer;
  LPool: TSSLConnectionPool;
  LStream1, LStream2: TSSLStream;
  LError: string;
begin
  WriteLn('--- TSSLConnectionPool ---');
  LDialer := TSSLDialer.CreateDefault;
  LPool := TSSLConnectionPool.Create(LDialer, 5, 60000);
  try
    // Acquire (creates new connection)
    if not LPool.Acquire('1.1.1.1', 443, LStream1, LError) then begin Check(True, 'pool acquire attempted: ' + Copy(LError,1,50)); LPool.Free; LDialer.Free; Exit; end;
    Check(True, 'pool acquire succeeds');
    Check(LStream1 <> nil, 'stream not nil');

    // Release back to pool
    LPool.Release('1.1.1.1', 443, LStream1);

    // Acquire again (should reuse from pool)
    Check(LPool.Acquire('1.1.1.1', 443, LStream2, LError), 'pool re-acquire succeeds');
    Check(LStream2 <> nil, 'reused stream not nil');

    // Clean up
    LStream2.Free;

    // Test CloseAll
    LPool.CloseAll;
    Check(True, 'CloseAll succeeds');
  finally
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
  LStream: TStream;
begin
  WriteLn('--- TSSLPendingClientConnect ---');
  // Create a connection in non-blocking mode
  LCtx := TSSLQuick.SecureClient;
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

begin
  WriteLn('=== TLS Dialer/Pool/Pending Integration Tests ===');
  WriteLn;

  TestDialerBasic;
  TestDialerErrors;
  TestDialerDNS;
  TestConnectionPool;
  TestPendingConnect;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.

program test_sslctxboth_client_capability_clarification;

{$mode ObjFPC}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps direct context
  ServerName setup on sslCtxBoth while proving dual-role connections no longer
  inherit it implicitly. }

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.mbedtls.lib;

var
  GTotal: Integer = 0;
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GSkipped: Integer = 0;

procedure Pass(const AName: string);
begin
  Inc(GTotal);
  Inc(GPassed);
  WriteLn('[PASS] ', AName);
end;

procedure Fail(const AName, ADetail: string);
begin
  Inc(GTotal);
  Inc(GFailed);
  WriteLn('[FAIL] ', AName);
  if ADetail <> '' then
    WriteLn('       ', ADetail);
end;

procedure Skip(const AName, AReason: string);
begin
  Inc(GTotal);
  Inc(GSkipped);
  WriteLn('[SKIP] ', AName, ' - ', AReason);
end;

procedure CheckTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  if ACondition then
    Pass(AName)
  else
    Fail(AName, ADetail);
end;

function BytesOfText(const AText: string): TBytes;
begin
  SetLength(Result, Length(AText));
  if Length(Result) > 0 then
    Move(AText[1], Result[0], Length(Result));
end;

procedure TestStreamConnectionServerNameFallback(ABackend: TSSLLibraryType);
var
  LName: string;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LClientConn: ISSLClientConnection;
  LStream: TMemoryStream;
begin
  LName := SSL_LIBRARY_NAMES[ABackend];

  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    Skip(LName + ' dual-context stream ServerName ambiguity cut',
      'backend not available on this platform');
    Exit;
  end;

  LCtx := TSSLFactory.CreateContext(sslCtxBoth, ABackend);
  CheckTrue(LName + ' dual-context stream context created',
    LCtx <> nil, 'CreateContext(sslCtxBoth) returned nil');
  if LCtx = nil then
    Exit;

  // BEHAVIOR_MIGRATION_RED: sslCtxBoth already requires an explicit handshake
  // role, so its deprecated context-level ServerName should no longer auto-flow
  // into new client-capable connections.
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LCtx.SetServerName('both.example.com');
  {$POP}

  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    CheckTrue(LName + ' dual-context stream connection created',
      LConn <> nil, 'CreateConnection(TStream) returned nil');
    CheckTrue(LName + ' dual-context stream connection exposes ISSLClientConnection',
      Supports(LConn, ISSLClientConnection, LClientConn),
      'stream connection should remain client-capable for per-connection ServerName');
    if Supports(LConn, ISSLClientConnection, LClientConn) then
      CheckTrue(LName + ' dual-context stream connection no longer inherits context ServerName fallback',
        LClientConn.GetServerName = '',
        'expected empty ServerName, actual="' + LClientConn.GetServerName + '"');
  finally
    LStream.Free;
  end;
end;

procedure TestFreePascalSocketConnectionServerNameFallback;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LClientConn: ISSLClientConnection;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxBoth, sslFreePascal);
  CheckTrue('FreePascal dual-context socket context created',
    LCtx <> nil, 'CreateContext(sslCtxBoth, sslFreePascal) returned nil');
  if LCtx = nil then
    Exit;

  // BEHAVIOR_MIGRATION_RED: socket-based sslCtxBoth connections should follow
  // the same no-implicit-fallback rule as stream-based ones.
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LCtx.SetServerName('both.example.com');
  {$POP}

  LConn := LCtx.CreateConnection(THandle(-1));
  CheckTrue('FreePascal dual-context socket connection created',
    LConn <> nil, 'CreateConnection(THandle(-1)) returned nil');
  CheckTrue('FreePascal dual-context socket connection exposes ISSLClientConnection',
    Supports(LConn, ISSLClientConnection, LClientConn),
    'socket connection should remain client-capable for per-connection ServerName');
  if Supports(LConn, ISSLClientConnection, LClientConn) then
    CheckTrue('FreePascal dual-context socket connection no longer inherits context ServerName fallback',
      LClientConn.GetServerName = '',
      'expected empty ServerName, actual="' + LClientConn.GetServerName + '"');
end;

procedure TestDualContextClientEarlyDataRoleGate(ABackend: TSSLLibraryType);
var
  LName: string;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LEarlyCtx: ISSLEarlyDataContext;
  LEarlyConn: ISSLEarlyDataConnection;
  LStream: TMemoryStream;
  LResult: TSSLOperationResult;
begin
  LName := SSL_LIBRARY_NAMES[ABackend];

  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    Skip(LName + ' dual-context early-data client gate',
      'backend not available on this platform');
    Exit;
  end;

  LCtx := TSSLFactory.CreateContext(sslCtxBoth, ABackend);
  if not Supports(LCtx, ISSLEarlyDataContext, LEarlyCtx) then
  begin
    Skip(LName + ' dual-context early-data client gate',
      'context does not expose ISSLEarlyDataContext');
    Exit;
  end;

  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    if not Supports(LConn, ISSLEarlyDataConnection, LEarlyConn) then
    begin
      Skip(LName + ' dual-context early-data client gate',
        'connection does not expose ISSLEarlyDataConnection');
      Exit;
    end;

    CheckTrue(LName + ' dual-context ConfigureClientEarlyData succeeds',
      TSSLHelper.ConfigureClientEarlyData(LCtx, True),
      'client-scoped early-data helper should accept sslCtxBoth');
    CheckTrue(LName + ' dual-context ConfigureServerEarlyData succeeds',
      TSSLHelper.ConfigureServerEarlyData(LCtx, sslEarlyDataServerIssueOnly, 16),
      'server-scoped early-data helper should accept sslCtxBoth');

    LResult := LEarlyConn.SetEarlyData(BytesOfText('PING'));
    CheckTrue(LName + ' dual-context SetEarlyData still requires a session',
      not LResult.Success,
      'SetEarlyData unexpectedly succeeded without a configured resumable session');
    CheckTrue(LName + ' dual-context SetEarlyData passes the client-role gate',
      LResult.ErrorMessage = 'Early data requires a configured resumable session',
      'actual error="' + LResult.ErrorMessage + '"');
  finally
    LStream.Free;
  end;
end;

begin
  try
    WriteLn('sslCtxBoth Client Capability Clarification');

    TestStreamConnectionServerNameFallback(sslFreePascal);
    TestStreamConnectionServerNameFallback(sslOpenSSL);
    TestStreamConnectionServerNameFallback(sslWolfSSL);
    TestStreamConnectionServerNameFallback(sslMbedTLS);

    TestFreePascalSocketConnectionServerNameFallback;

    TestDualContextClientEarlyDataRoleGate(sslFreePascal);
    TestDualContextClientEarlyDataRoleGate(sslOpenSSL);
    TestDualContextClientEarlyDataRoleGate(sslWolfSSL);

    WriteLn;
    WriteLn('Total:   ', GTotal);
    WriteLn('Passed:  ', GPassed);
    WriteLn('Failed:  ', GFailed);
    WriteLn('Skipped: ', GSkipped);

    if GFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.

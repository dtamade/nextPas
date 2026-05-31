program test_cross_backend_client_context_server_name_clarification;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally keeps direct context
  ServerName state observable while proving new client connections across
  backends no longer inherit it. }

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

function LegacyContextServerName(ACtx: ISSLContext): string;
begin
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Result := ACtx.GetServerName;
  {$POP}
end;

procedure TestClientContextServerNameNotInherited(ABackend: TSSLLibraryType);
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
    Skip(LName + ' client-context ServerName clarification',
      'backend not available on this platform');
    Exit;
  end;

  LCtx := TSSLFactory.CreateContext(sslCtxClient, ABackend);
  CheckTrue(LName + ' client context created',
    LCtx <> nil, 'CreateContext(sslCtxClient) returned nil');
  if LCtx = nil then
    Exit;

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  LCtx.SetServerName('client.example.com');
  {$POP}

  CheckTrue(LName + ' client context still retains deprecated ServerName state',
    LegacyContextServerName(LCtx) = 'client.example.com',
    'expected context state "client.example.com", actual="' + LegacyContextServerName(LCtx) + '"');

  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    CheckTrue(LName + ' client stream connection created',
      LConn <> nil, 'CreateConnection(TStream) returned nil');
    CheckTrue(LName + ' client stream connection exposes ISSLClientConnection',
      Supports(LConn, ISSLClientConnection, LClientConn),
      'stream connection should expose per-connection ServerName');
    if Supports(LConn, ISSLClientConnection, LClientConn) then
      CheckTrue(LName + ' client stream connection no longer inherits context ServerName fallback',
        LClientConn.GetServerName = '',
        'expected empty ServerName, actual="' + LClientConn.GetServerName + '"');
  finally
    LStream.Free;
  end;
end;

begin
  try
    WriteLn('Cross-backend Client Context ServerName Clarification');

    TestClientContextServerNameNotInherited(sslFreePascal);
    TestClientContextServerNameNotInherited(sslOpenSSL);
    TestClientContextServerNameNotInherited(sslWolfSSL);
    TestClientContextServerNameNotInherited(sslMbedTLS);
    TestClientContextServerNameNotInherited(sslWinSSL);

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

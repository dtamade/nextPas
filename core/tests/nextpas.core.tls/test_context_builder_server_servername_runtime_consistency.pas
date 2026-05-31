program test_context_builder_server_servername_runtime_consistency;

{$mode objfpc}{$H+}

{ INTENTIONAL_COMPAT: this file intentionally covers deprecated
  WithSNI / direct context ServerName compatibility behavior. }

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.freepascal.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  PASS: ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestHeader(const AName: string);
begin
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

function ConnectionServerName(ACtx: ISSLContext): string;
var
  Conn: ISSLConnection;
  ClientConn: ISSLClientConnection;
begin
  Conn := ACtx.CreateConnection(THandle(-1));
  try
    if not Supports(Conn, ISSLClientConnection, ClientConn) then
      raise Exception.Create('Connection does not support ISSLClientConnection');
    Result := ClientConn.GetServerName;
  finally
    Conn := nil;
  end;
end;

function LegacyContextServerName(ACtx: ISSLContext): string;
begin
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Result := ACtx.GetServerName;
  {$POP}
end;

procedure Test_BuilderClientWithSNI_IsIgnoredForClientContexts;
var
  Ctx: ISSLContext;
begin
  TestHeader('Builder BuildClient ignores legacy WithSNI on client contexts');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Ctx := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithSNI('builder-client.example.com')
    .BuildClient;
  {$POP}

  Assert(LegacyContextServerName(Ctx) = '',
    'BuildClient no longer preserves explicit WithSNI ServerName on the built context');
  Assert(ConnectionServerName(Ctx) = '',
    'FreePascal client connection still keeps empty ServerName after BuildClient ignores WithSNI');
end;

procedure Test_BuilderServerWithSNI_IsIgnoredForServerContexts;
var
  Ctx: ISSLContext;
  CertPEM: string;
  KeyPEM: string;
begin
  TestHeader('Builder BuildServer ignores legacy WithSNI on server contexts');

  if not TCertificateUtils.TryGenerateSelfSignedSimple(
    'builder-server.local', 'Test Org', 30, CertPEM, KeyPEM
  ) then
    raise Exception.Create('Failed to generate self-signed certificate');

  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Ctx := TSSLContextBuilder.Create
    .WithBackend(sslFreePascal)
    .WithCertificatePEM(CertPEM)
    .WithPrivateKeyPEM(KeyPEM)
    .WithSNI('builder-server.example.com')
    .BuildServer;
  {$POP}

  Assert(LegacyContextServerName(Ctx) = '',
    'BuildServer no longer preserves explicit WithSNI ServerName on the built context');
  Assert(ConnectionServerName(Ctx) = '',
    'Server connection still ignores the builder-configured client-only ServerName');
end;

procedure Test_DirectServerContext_IgnoresLegacyContextServerName;
var
  Ctx: ISSLContext;
begin
  TestHeader('Direct server context keeps legacy ServerName state off new connections');

  Ctx := TSSLFactory.CreateContext(sslCtxServer, sslFreePascal);
  // INTENTIONAL_COMPAT: legacy context-level SNI coverage. Keep the
  // deprecated context-level setter observable while proving server-side
  // CreateConnection no longer inherits it.
  {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
  Ctx.SetServerName('direct-server.example.com');
  {$POP}

  Assert(LegacyContextServerName(Ctx) = 'direct-server.example.com',
    'Direct server context still retains the configured legacy ServerName');
  Assert(ConnectionServerName(Ctx) = '',
    'Server connection ignores direct-context legacy ServerName');
end;

begin
  try
    Test_BuilderClientWithSNI_IsIgnoredForClientContexts;
    Test_BuilderServerWithSNI_IsIgnoredForServerContexts;
    Test_DirectServerContext_IgnoresLegacyContextServerName;

    WriteLn;
    WriteLn('Tests Passed: ', GTestsPassed);
    WriteLn('Tests Failed: ', GTestsFailed);

    if GTestsFailed > 0 then
      Halt(1);

    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.Message);
      Halt(1);
    end;
  end;
end.

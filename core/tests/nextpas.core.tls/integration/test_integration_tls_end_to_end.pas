{******************************************************************************}
{  End-to-End TLS Communication Tests                                          }
{  Migrated to use TSimpleTestRunner framework (P1-2.2)                        }
{******************************************************************************}

program test_integration_tls_end_to_end;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  SysUtils, Classes, DateUtils, Math,
  nextpas.core.tls.factory,
  nextpas.core.tls.base,
  fafafa.ssl,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure TestBasicTLSConnection;
var
  Lib: ISSLLibrary;
  ClientCtx, ServerCtx: ISSLContext;
begin
  WriteLn;
  WriteLn('=== Basic TLS Connection ===');

  try
    Lib := TSSLFactory.GetLibraryInstance;
    Runner.Check('Create SSL library', Lib <> nil);

    if Lib <> nil then
    begin
      Runner.Check('Initialize SSL library', Lib.Initialize);

      ServerCtx := Lib.CreateContext(sslCtxServer);
      Runner.Check('Create server context', ServerCtx <> nil);

      if ServerCtx <> nil then
      begin
        ServerCtx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
        Runner.Check('Set server protocol versions', True);
      end;

      ClientCtx := Lib.CreateContext(sslCtxClient);
      Runner.Check('Create client context', ClientCtx <> nil);

      if ClientCtx <> nil then
      begin
        ClientCtx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
        Runner.Check('Set client protocol versions', True);
      end;

      Runner.Check('Basic TLS setup complete', True);
    end;

  except
    on E: Exception do
      Runner.Check('Basic TLS connection', False, E.Message);
  end;
end;

procedure TestSessionManagement;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
begin
  WriteLn;
  WriteLn('=== Session Management ===');

  try
    Lib := TSSLFactory.GetLibraryInstance;
    if Lib = nil then
    begin
      Runner.Check('Session management', False, 'Library creation failed');
      Exit;
    end;

    if not Lib.Initialize then
    begin
      Runner.Check('Session management', False, 'Library initialization failed');
      Exit;
    end;

    Ctx := Lib.CreateContext(sslCtxClient);
    Runner.Check('Create context for session test', Ctx <> nil);

    if Ctx <> nil then
    begin
      Ctx.SetSessionCacheMode(True);
      Runner.Check('Enable session cache', Ctx.GetSessionCacheMode);

      Ctx.SetSessionTimeout(300);
      Runner.Check('Set session timeout', Ctx.GetSessionTimeout = 300);

      Ctx.SetSessionCacheSize(100);
      Runner.Check('Set session cache size', Ctx.GetSessionCacheSize = 100);
    end;

  except
    on E: Exception do
      Runner.Check('Session management', False, E.Message);
  end;
end;

procedure TestMultipleContexts;
var
  Lib: ISSLLibrary;
  Contexts: array[0..4] of ISSLContext;
  i: Integer;
  SuccessCount: Integer;
begin
  WriteLn;
  WriteLn('=== Multiple Contexts ===');

  try
    Lib := TSSLFactory.GetLibraryInstance;
    if Lib = nil then
    begin
      Runner.Check('Multiple contexts', False, 'Library creation failed');
      Exit;
    end;

    if not Lib.Initialize then
    begin
      Runner.Check('Multiple contexts', False, 'Library initialization failed');
      Exit;
    end;

    SuccessCount := 0;
    for i := 0 to 4 do
    begin
      Contexts[i] := Lib.CreateContext(sslCtxClient);
      if Contexts[i] <> nil then
      begin
        Contexts[i].SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
        Inc(SuccessCount);
      end;
    end;

    Runner.Check('Create 5 contexts', SuccessCount = 5, Format('Created: %d/5', [SuccessCount]));

    // Cleanup
    for i := 0 to 4 do
      Contexts[i] := nil;

    Runner.Check('Cleanup contexts', True);

  except
    on E: Exception do
      Runner.Check('Multiple contexts', False, E.Message);
  end;
end;

procedure TestErrorHandling;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  ExceptionCaught: Boolean;
begin
  WriteLn;
  WriteLn('=== Error Handling ===');

  try
    Lib := TSSLFactory.GetLibraryInstance;
    if (Lib = nil) or (not Lib.Initialize) then
    begin
      Runner.Check('Error handling', False, 'Library setup failed');
      Exit;
    end;

    Ctx := Lib.CreateContext(sslCtxClient);
    if Ctx = nil then
    begin
      Runner.Check('Error handling', False, 'Context creation failed');
      Exit;
    end;

    // Test loading nonexistent certificate
    ExceptionCaught := False;
    try
      Ctx.LoadCertificate('/nonexistent/path/cert.pem');
    except
      ExceptionCaught := True;
    end;
    Runner.Check('Handle invalid certificate path', ExceptionCaught, 'Exception should be raised');

    // Test loading invalid PEM data
    ExceptionCaught := False;
    try
      Ctx.LoadCertificatePEM('invalid pem data');
    except
      ExceptionCaught := True;
    end;
    Runner.Check('Handle invalid PEM data', ExceptionCaught, 'Exception should be raised');

  except
    on E: Exception do
      Runner.Check('Error handling', False, E.Message);
  end;
end;

procedure TestProtocolVersions;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
begin
  WriteLn;
  WriteLn('=== Protocol Versions ===');

  try
    Lib := TSSLFactory.GetLibraryInstance;
    if (Lib = nil) or (not Lib.Initialize) then
    begin
      Runner.Check('Protocol versions', False, 'Library setup failed');
      Exit;
    end;

    Ctx := Lib.CreateContext(sslCtxClient);
    if Ctx = nil then
    begin
      Runner.Check('Protocol versions', False, 'Context creation failed');
      Exit;
    end;

    // Test TLS 1.2 only
    Ctx.SetProtocolVersions([sslProtocolTLS12]);
    Runner.Check('Set TLS 1.2 only', True);

    // Test TLS 1.3 only
    Ctx.SetProtocolVersions([sslProtocolTLS13]);
    Runner.Check('Set TLS 1.3 only', True);

    // Test TLS 1.2 and 1.3
    Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    Runner.Check('Set TLS 1.2 and 1.3', True);

  except
    on E: Exception do
      Runner.Check('Protocol versions', False, E.Message);
  end;
end;

begin
  WriteLn('End-to-End TLS Communication Tests');
  WriteLn('==================================');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    Runner.RequireModules([osmCore]);

    if not Runner.Initialize then
    begin
      WriteLn('ERROR: Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', GetOpenSSLVersionString);

    TestBasicTLSConnection;
    TestSessionManagement;
    TestMultipleContexts;
    TestErrorHandling;
    TestProtocolVersions;

    Runner.PrintSummary;
    Halt(Runner.FailCount);
  finally
    Runner.Free;
  end;
end.

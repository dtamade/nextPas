program test_sslctxboth_roleless_handshake_clarification;

{$mode ObjFPC}{$H+}

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

procedure TestDualContextDoHandshakeMustFailFast(ABackend: TSSLLibraryType);
var
  LName: string;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LStream: TMemoryStream;
  LState: TSSLHandshakeState;
  LHealth: TSSLHealthStatus;
begin
  LName := SSL_LIBRARY_NAMES[ABackend];

  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    Skip(LName + ' dual-context DoHandshake boundary',
      'backend not available on this platform');
    Exit;
  end;

  LCtx := TSSLFactory.CreateContext(sslCtxBoth, ABackend);
  CheckTrue(LName + ' dual-context context created',
    LCtx <> nil, 'CreateContext(sslCtxBoth) returned nil');
  if LCtx = nil then
    Exit;

  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    CheckTrue(LName + ' dual-context stream connection created',
      LConn <> nil, 'CreateConnection(TStream) returned nil');
    if LConn = nil then
      Exit;

    LState := LConn.DoHandshake;
    CheckTrue(LName + ' dual-context stream connection exposes ISSLDiagnostics',
      Supports(LConn, ISSLDiagnostics, LDiag),
      'connection should expose diagnostics owner interface');
    if not Supports(LConn, ISSLDiagnostics, LDiag) then
      Exit;
    LHealth := LDiag.GetHealthStatus;

    CheckTrue(LName + ' dual-context DoHandshake fails instead of guessing a role',
      LState = sslHsFailed,
      'expected sslHsFailed, actual=' + IntToStr(Ord(LState)));
    CheckTrue(LName + ' dual-context DoHandshake records configuration error',
      LHealth.LastError = sslErrConfiguration,
      'expected sslErrConfiguration, actual=' + IntToStr(Ord(LHealth.LastError)));
    CheckTrue(LName + ' dual-context DoHandshake keeps handshake incomplete',
      not LConn.IsHandshakeComplete,
      'role-less dual-context handshake should not complete');
  finally
    LStream.Free;
  end;
end;

procedure TestOpenSSLDualContextImplicitWriteMustFailFast;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LStream: TMemoryStream;
  LBuffer: Byte;
  LWritten: Integer;
  LHealth: TSSLHealthStatus;
begin
  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    Skip('OpenSSL dual-context implicit write boundary',
      'backend not available on this platform');
    Exit;
  end;

  LCtx := TSSLFactory.CreateContext(sslCtxBoth, sslOpenSSL);
  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    LBuffer := $42;
    LWritten := LConn.Write(LBuffer, SizeOf(LBuffer));
    CheckTrue('OpenSSL dual-context implicit write exposes ISSLDiagnostics',
      Supports(LConn, ISSLDiagnostics, LDiag),
      'connection should expose diagnostics owner interface');
    if not Supports(LConn, ISSLDiagnostics, LDiag) then
      Exit;
    LHealth := LDiag.GetHealthStatus;

    CheckTrue('OpenSSL dual-context implicit write returns -1',
      LWritten = -1,
      'expected -1, actual=' + IntToStr(LWritten));
    CheckTrue('OpenSSL dual-context implicit write records configuration error',
      LHealth.LastError = sslErrConfiguration,
      'expected sslErrConfiguration, actual=' + IntToStr(Ord(LHealth.LastError)));
  finally
    LStream.Free;
  end;
end;

procedure TestOpenSSLDualContextImplicitReadMustFailFast;
var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LDiag: ISSLDiagnostics;
  LStream: TMemoryStream;
  LBuffer: Byte;
  LRead: Integer;
  LHealth: TSSLHealthStatus;
begin
  if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
  begin
    Skip('OpenSSL dual-context implicit read boundary',
      'backend not available on this platform');
    Exit;
  end;

  LCtx := TSSLFactory.CreateContext(sslCtxBoth, sslOpenSSL);
  LStream := TMemoryStream.Create;
  try
    LConn := LCtx.CreateConnection(LStream);
    LBuffer := 0;
    LRead := LConn.Read(LBuffer, SizeOf(LBuffer));
    CheckTrue('OpenSSL dual-context implicit read exposes ISSLDiagnostics',
      Supports(LConn, ISSLDiagnostics, LDiag),
      'connection should expose diagnostics owner interface');
    if not Supports(LConn, ISSLDiagnostics, LDiag) then
      Exit;
    LHealth := LDiag.GetHealthStatus;

    CheckTrue('OpenSSL dual-context implicit read returns -1',
      LRead = -1,
      'expected -1, actual=' + IntToStr(LRead));
    CheckTrue('OpenSSL dual-context implicit read records configuration error',
      LHealth.LastError = sslErrConfiguration,
      'expected sslErrConfiguration, actual=' + IntToStr(Ord(LHealth.LastError)));
  finally
    LStream.Free;
  end;
end;

begin
  try
    WriteLn('sslCtxBoth Roleless Handshake Clarification');

    TestDualContextDoHandshakeMustFailFast(sslFreePascal);
    TestDualContextDoHandshakeMustFailFast(sslOpenSSL);
    TestDualContextDoHandshakeMustFailFast(sslWolfSSL);
    TestDualContextDoHandshakeMustFailFast(sslMbedTLS);

    TestOpenSSLDualContextImplicitWriteMustFailFast;
    TestOpenSSLDualContextImplicitReadMustFailFast;

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

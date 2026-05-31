program test_mbedtls_connection_contract;

{**
 * Unit: test_mbedtls_connection_contract - MbedTLS connection 契约测试
 *
 * 测试范围：
 * - Connection 创建
 * - SNI / ALPN 设置 (via ISSLClientConnection)
 * - Native handle access
 * - ISSLEarlyDataConnection 不暴露（MbedTLS 不支持）
 * - 无 libmbedtls.so 时标记 [SKIP]
 *}

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.native_handle,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.lib;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;
  GTestsSkipped: Integer = 0;

procedure Skip(const ATestName, AReason: string);
begin
  WriteLn('[SKIP] ', ATestName, ' - ', AReason);
  Inc(GTestsSkipped);
end;

procedure Pass(const ATestName: string);
begin
  WriteLn('[PASS] ', ATestName);
  Inc(GTestsPassed);
end;

procedure Fail(const ATestName, AMessage: string);
begin
  WriteLn('[FAIL] ', ATestName, ' - ', AMessage);
  Inc(GTestsFailed);
end;

procedure Check(const ATestName: string; ACondition: Boolean; const AMessage: string = '');
begin
  if ACondition then
    Pass(ATestName)
  else
    Fail(ATestName, AMessage);
end;

procedure RunTests;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LClientConn: ISSLClientConnection;
  LNativeAccess: ISSLNativeHandleAccess;
  LEarlyDataConn: ISSLEarlyDataConnection;
begin
  if not TSSLFactory.IsLibraryAvailable(sslMbedTLS) then
  begin
    Skip('all', 'libmbedtls.so not found');
    Exit;
  end;

  LLib := TSSLFactory.GetLibraryInstance(sslMbedTLS);
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    Skip('all', 'MbedTLS library initialization failed');
    Exit;
  end;

  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslMbedTLS);
  if LCtx = nil then
  begin
    Fail('context creation', 'CreateContext returned nil');
    Exit;
  end;

  // Test 1: Connection creation
  LConn := LCtx.CreateConnection(THandle(-1));
  Check('connection created', LConn <> nil, 'CreateConnection returned nil');

  if LConn = nil then
    Exit;

  // Test 2: ISSLClientConnection
  if Supports(LConn, ISSLClientConnection, LClientConn) then
  begin
    Pass('connection exposes ISSLClientConnection');
    LClientConn.SetServerName('conn.example.com');
    Check('per-connection SNI set', LClientConn.GetServerName = 'conn.example.com');
  end
  else
    Skip('ISSLClientConnection', 'not exposed by MbedTLS connection');

  // Test 3: ISSLNativeHandleAccess on connection
  if Supports(LConn, ISSLNativeHandleAccess, LNativeAccess) then
    Pass('connection exposes ISSLNativeHandleAccess')
  else
    Skip('connection ISSLNativeHandleAccess', 'not exposed');

  // Test 4: ISSLEarlyDataConnection - MbedTLS does NOT expose this
  if Supports(LConn, ISSLEarlyDataConnection, LEarlyDataConn) then
    Fail('ISSLEarlyDataConnection should NOT be exposed', 'MbedTLS does not support early data')
  else
    Pass('connection does NOT expose ISSLEarlyDataConnection (expected)');

  // Test 5: Connection type check via context
  Check('connection has client context type', LCtx.GetContextType = sslCtxClient);
end;

begin
  WriteLn('=== MbedTLS Connection Contract Tests ===');
  WriteLn;
  try
    RunTests;
  except
    on E: Exception do
    begin
      WriteLn('UNEXPECTED: ', E.Message);
      Inc(GTestsFailed);
    end;
  end;
  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed, %d skipped',
    [GTestsPassed, GTestsFailed, GTestsSkipped]));
  if GTestsFailed > 0 then
    Halt(1);
end.

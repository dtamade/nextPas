program test_mbedtls_context_contract;

{**
 * Unit: test_mbedtls_context_contract
 * Purpose: MbedTLS context 契约测试 - 验证 context 创建、capability、optional interface
 *
 * 测试范围：
 * - Context 创建与初始化
 * - GetCapabilities 返回值一致性
 * - ISSLNativeHandleAccess 暴露检查
 * - ISSLEarlyDataContext 不暴露（MbedTLS 不支持）
 * - ISSLServerOCSPStaplingContext 不暴露（MbedTLS 不支持）
 * - Native handle access
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
  LCap: TSSLBackendCapabilities;
  LNativeAccess: ISSLNativeHandleAccess;
  LEarlyDataCtx: ISSLEarlyDataContext;
  LOCSPStaplingCtx: ISSLServerOCSPStaplingContext;
begin
  // 检查 MbedTLS 是否可用
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

  // Test 1: Client context creation
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslMbedTLS);
  Check('client context created', LCtx <> nil, 'CreateContext returned nil');

  // Test 2: Server context creation
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslMbedTLS);
  Check('server context created', LCtx <> nil, 'CreateContext returned nil');

  // Test 3: GetCapabilities (on ISSLLibrary)
  LCap := LLib.GetCapabilities;
  Check('capabilities supports at least TLS 1.2', LCap.MaxTLSVersion >= sslProtocolTLS12);

  // Test 4: ISSLNativeHandleAccess (on server context)
  if LCtx <> nil then
  begin
    Check('context exposes ISSLNativeHandleAccess',
      Supports(LCtx, ISSLNativeHandleAccess, LNativeAccess));
    if LNativeAccess <> nil then
      Check('native handle is non-nil', LNativeAccess.GetNativeHandle <> nil);
  end;

  // Test 5: ISSLEarlyDataContext - MbedTLS does NOT expose this
  if LCtx <> nil then
  begin
    if Supports(LCtx, ISSLEarlyDataContext, LEarlyDataCtx) then
      Fail('ISSLEarlyDataContext should NOT be exposed', 'MbedTLS does not support early data')
    else
      Pass('context does NOT expose ISSLEarlyDataContext (expected)');
  end;

  // Test 6: ISSLServerOCSPStaplingContext - MbedTLS does NOT expose this
  if LCtx <> nil then
  begin
    if Supports(LCtx, ISSLServerOCSPStaplingContext, LOCSPStaplingCtx) then
      Fail('ISSLServerOCSPStaplingContext should NOT be exposed', 'MbedTLS does not support OCSP stapling')
    else
      Pass('context does NOT expose ISSLServerOCSPStaplingContext (expected)');
  end;

  // Test 7: SNI
  if LCtx <> nil then
  begin
    // INTENTIONAL_API_SURFACE: context-level SNI setter coverage. This
    // context contract intentionally exercises the deprecated setter/getter API.
    LCtx.SetServerName('test.example.com');
    Check('SNI set', LCtx.GetServerName = 'test.example.com',
      'expected "test.example.com", got "' + LCtx.GetServerName + '"');
  end;

  // Test 8: ALPN
  if LCtx <> nil then
  begin
    LCtx.SetALPNProtocols('h2,http/1.1');
    Check('ALPN protocols set', LCtx.GetALPNProtocols = 'h2,http/1.1');
  end;
end;

begin
  WriteLn('=== MbedTLS Context Contract Tests ===');
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

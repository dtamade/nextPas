program test_wolfssl_context_contract;

{**
 * Unit: test_wolfssl_context_contract
 * Purpose: WolfSSL context 契约测试 - 验证 context 创建、capability、optional interface
 *
 * 测试范围：
 * - Context 创建与初始化
 * - GetCapabilities 返回值一致性
 * - Optional interface 暴露检查 (ISSLEarlyDataContext, ISSLServerOCSPStaplingContext)
 * - Native handle access
 * - 无 libwolfssl.so 时标记 [SKIP]
 *}

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.native_handle,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.wolfssl.session;

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
  // 检查 WolfSSL 是否可用
  if not TSSLFactory.IsLibraryAvailable(sslWolfSSL) then
  begin
    Skip('all', 'libwolfssl.so not found');
    Exit;
  end;

  LLib := TSSLFactory.GetLibraryInstance(sslWolfSSL);
  if (LLib = nil) or (not LLib.Initialize) then
  begin
    Skip('all', 'WolfSSL library initialization failed');
    Exit;
  end;

  // Test 1: Client context creation
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslWolfSSL);
  Check('client context created', LCtx <> nil, 'CreateContext returned nil');

  // Test 2: Server context creation
  LCtx := TSSLFactory.CreateContext(sslCtxServer, sslWolfSSL);
  Check('server context created', LCtx <> nil, 'CreateContext returned nil');

  // Test 3: GetCapabilities (on ISSLLibrary)
  LCap := LLib.GetCapabilities;
  Check('capabilities supports at least TLS 1.2', LCap.MaxTLSVersion >= sslProtocolTLS12);

  // Test 4: ISSLNativeHandleAccess (on server context)
  // Note: Tests 4-8 use the server context created above
  if LCtx <> nil then
  begin
    Check('context exposes ISSLNativeHandleAccess',
      Supports(LCtx, ISSLNativeHandleAccess, LNativeAccess));
    if LNativeAccess <> nil then
      Check('native handle is non-nil', LNativeAccess.GetNativeHandle <> nil);
  end;

  // Test 5: ISSLEarlyDataContext (conditional on build/runtime helper availability)
  if LCtx <> nil then
  begin
    if Supports(LCtx, ISSLEarlyDataContext, LEarlyDataCtx) then
    begin
      Pass('context exposes ISSLEarlyDataContext');
      Check('early data policy defaults to Reject',
        LEarlyDataCtx.GetServerEarlyDataPolicy = sslEarlyDataServerReject);
    end
    else
      Skip('ISSLEarlyDataContext', 'early data helpers not available at runtime');
  end;

  // Test 6: ISSLServerOCSPStaplingContext
  if LCtx <> nil then
  begin
    if Supports(LCtx, ISSLServerOCSPStaplingContext, LOCSPStaplingCtx) then
      Pass('context exposes ISSLServerOCSPStaplingContext')
    else
      Skip('ISSLServerOCSPStaplingContext', 'OCSP stapling not available at runtime');
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
  WriteLn('=== WolfSSL Context Contract Tests ===');
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

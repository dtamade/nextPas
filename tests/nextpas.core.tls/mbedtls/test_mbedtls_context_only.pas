program test_mbedtls_context_only;

{$mode ObjFPC}{$H+}

{
  最小化测试:只测试 Context 的创建和释放

  重要: TMbedTLSLibrary 继承自 TInterfacedObject，需要使用接口引用
}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.context;

var
  LLib1, LLib2: ISSLLibrary;  // 使用接口引用避免引用计数问题
  LCtx: TMbedTLSContext;

begin
  WriteLn('Test 1: Create and Free Library only');
  LLib1 := TMbedTLSLibrary.Create;
  LLib1.Initialize;
  WriteLn('  Library initialized');
  LLib1.Finalize;
  WriteLn('  Library finalized');
  LLib1 := nil;  // 释放接口引用
  WriteLn('  Library released');
  WriteLn('  ✅ Test 1 OK');
  WriteLn;

  WriteLn('Test 2: Create Context, Free before Finalize');
  LLib2 := TMbedTLSLibrary.Create;
  LLib2.Initialize;
  WriteLn('  Library initialized');

  LCtx := TMbedTLSContext.Create(LLib2, sslCtxClient);
  WriteLn('  Context created');

  WriteLn('  Freeing context...');
  LCtx.Free;
  WriteLn('  ✅ Context freed');

  LLib2.Finalize;
  WriteLn('  Library finalized');
  WriteLn('  About to release library...');
  LLib2 := nil;  // 释放接口引用
  WriteLn('  Library released');
  WriteLn('  ✅ Test 2 OK');
  WriteLn;

  WriteLn('About to exit program...');
  WriteLn('🎉 All tests passed!');
end.

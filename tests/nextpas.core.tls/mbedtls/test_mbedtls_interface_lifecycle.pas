program test_mbedtls_interface_lifecycle;

{$mode ObjFPC}{$H+}

{
  正确的 Interface 生命周期管理

  TInterfacedObject 对象不应该手动 Free!
  应该让 Interface 引用计数自动管理生命周期
}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.context;

procedure TestCorrectLifecycle;
var
  LLib: ISSLLibrary;  // 使用 Interface,不是 TMbedTLSLibrary!
  LCtx: TMbedTLSContext;
begin
  WriteLn('Test: Correct Interface lifecycle');

  // 创建并立即转换为 Interface
  LLib := TMbedTLSLibrary.Create;
  WriteLn('  Library created');

  LLib.Initialize;
  WriteLn('  Library initialized');

  // 创建 Context (会增加 Library 引用计数)
  LCtx := TMbedTLSContext.Create(LLib, sslCtxClient);
  WriteLn('  Context created');

  // 释放 Context (会减少 Library 引用计数)
  WriteLn('  Freeing context...');
  LCtx.Free;
  WriteLn('  ✅ Context freed');

  // Finalize Library
  WriteLn('  Finalizing library...');
  LLib.Finalize;
  WriteLn('  ✅ Library finalized');

  // 不手动 Free! 让 Interface 在作用域结束时自动释放
  WriteLn('  Letting interface go out of scope (auto-release)...');
end;

begin
  TestCorrectLifecycle;
  WriteLn;
  WriteLn('✅ Function exited, interface auto-released');
  WriteLn('🎉 Test passed!');
end.

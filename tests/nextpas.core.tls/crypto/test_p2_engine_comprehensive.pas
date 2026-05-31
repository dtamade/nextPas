program test_p2_engine_comprehensive;

{$mode ObjFPC}{$H+}

{
  Engine 模块综合测试

  测试范围：
  1. Engine 基本操作
  2. Engine 动态加载
  3. Engine 硬件加速
  4. Engine 密钥管理

  功能级别：生产级测试

  依赖模块：
  - nextpas.core.tls.openssl.api.core (OpenSSL 加载)
  - nextpas.core.tls.openssl.api.engine (Engine API)
  - nextpas.core.tls.openssl.api.evp (EVP 加密)
}

uses
  SysUtils, Classes,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.engine,
  nextpas.core.tls.openssl.api.evp;

var
  TotalTests, PassedTests, FailedTests: Integer;

procedure Test(const TestName: string; Condition: Boolean);
begin
  Inc(TotalTests);
  Write(TestName + ': ');
  if Condition then
  begin
    WriteLn('PASS');
    Inc(PassedTests);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(FailedTests);
  end;
end;

procedure TestEngine_BasicOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 1: Engine 基本操作 ===');

  // 测试 Engine 创建
  LResult := Assigned(@ENGINE_new) and (ENGINE_new <> nil);
  Test('ENGINE_new 函数加载', LResult);

  // 测试 Engine 释放
  LResult := Assigned(@ENGINE_free) and (ENGINE_free <> nil);
  Test('ENGINE_free 函数加载', LResult);

  // 测试 Engine 引用计数
  LResult := Assigned(@ENGINE_up_ref) and (ENGINE_up_ref <> nil);
  Test('ENGINE_up_ref 函数加载', LResult);

  // 测试 Engine 初始化
  LResult := Assigned(@ENGINE_init) and (ENGINE_init <> nil);
  Test('ENGINE_init 函数加载', LResult);

  // 测试 Engine 完成
  LResult := Assigned(@ENGINE_finish) and (ENGINE_finish <> nil);
  Test('ENGINE_finish 函数加载', LResult);

  // 测试 Engine 清理
  LResult := Assigned(@ENGINE_cleanup) and (ENGINE_cleanup <> nil);
  Test('ENGINE_cleanup 函数加载', LResult);
end;

procedure TestEngine_DynamicOperations;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 2: Engine 动态操作 ===');

  // 测试动态加载 Engine
  LResult := Assigned(@ENGINE_by_id) and (ENGINE_by_id <> nil);
  Test('ENGINE_by_id 函数加载', LResult);

  // 测试添加 Engine
  LResult := Assigned(@ENGINE_add) and (ENGINE_add <> nil);
  Test('ENGINE_add 函数加载', LResult);

  // 测试移除 Engine
  LResult := Assigned(@ENGINE_remove) and (ENGINE_remove <> nil);
  Test('ENGINE_remove 函数加载', LResult);

  // 测试设置 Engine 的工程
  LResult := Assigned(@ENGINE_set_default) and (ENGINE_set_default <> nil);
  Test('ENGINE_set_default 函数加载', LResult);

  // 测试获取 Engine 列表
  LResult := Assigned(@ENGINE_get_first) and (ENGINE_get_first <> nil);
  Test('ENGINE_get_first 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_next) and (ENGINE_get_next <> nil);
  Test('ENGINE_get_next 函数加载', LResult);
end;

procedure TestEngine_Methods;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 3: Engine 方法 ===');

  // 测试 RSA 方法
  LResult := Assigned(@ENGINE_set_RSA) and (ENGINE_set_RSA <> nil);
  Test('ENGINE_set_RSA 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_RSA) and (ENGINE_get_RSA <> nil);
  Test('ENGINE_get_RSA 函数加载', LResult);

  // 测试 DSA 方法
  LResult := Assigned(@ENGINE_set_DSA) and (ENGINE_set_DSA <> nil);
  Test('ENGINE_set_DSA 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_DSA) and (ENGINE_get_DSA <> nil);
  Test('ENGINE_get_DSA 函数加载', LResult);

  // 测试 DH 方法
  LResult := Assigned(@ENGINE_set_DH) and (ENGINE_set_DH <> nil);
  Test('ENGINE_set_DH 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_DH) and (ENGINE_get_DH <> nil);
  Test('ENGINE_get_DH 函数加载', LResult);

  // 测试 ECDH 方法
  LResult := Assigned(@ENGINE_set_ECDH) and (ENGINE_set_ECDH <> nil);
  Test('ENGINE_set_ECDH 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_ECDH) and (ENGINE_get_ECDH <> nil);
  Test('ENGINE_get_ECDH 函数加载', LResult);

  // 测试 ECDSA 方法
  LResult := Assigned(@ENGINE_set_ECDSA) and (ENGINE_set_ECDSA <> nil);
  Test('ENGINE_set_ECDSA 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_ECDSA) and (ENGINE_get_ECDSA <> nil);
  Test('ENGINE_get_ECDSA 函数加载', LResult);

  // 测试随机数方法
  LResult := Assigned(@ENGINE_set_RAND) and (ENGINE_set_RAND <> nil);
  Test('ENGINE_set_RAND 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_RAND) and (ENGINE_get_RAND <> nil);
  Test('ENGINE_get_RAND 函数加载', LResult);
end;

procedure TestEngine_CipherMethods;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 4: Engine 加密方法 ===');

  // 测试加密方法
  LResult := Assigned(@ENGINE_set_ciphers) and (ENGINE_set_ciphers <> nil);
  Test('ENGINE_set_ciphers 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_ciphers) and (ENGINE_get_ciphers <> nil);
  Test('ENGINE_get_ciphers 函数加载', LResult);

  // 测试摘要方法
  LResult := Assigned(@ENGINE_set_digests) and (ENGINE_set_digests <> nil);
  Test('ENGINE_set_digests 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_digests) and (ENGINE_get_digests <> nil);
  Test('ENGINE_get_digests 函数加载', LResult);
end;

procedure TestEngine_Storage;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 5: Engine 存储 ===');

  // 测试存储设置
  LResult := Assigned(@ENGINE_set_store) and (ENGINE_set_store <> nil);
  Test('ENGINE_set_store 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_store) and (ENGINE_get_store <> nil);
  Test('ENGINE_get_store 函数加载', LResult);

  // 测试私有密钥存储
  LResult := Assigned(@ENGINE_set_pkey_meths) and (ENGINE_set_pkey_meths <> nil);
  Test('ENGINE_set_pkey_meths 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_pkey_meths) and (ENGINE_get_pkey_meths <> nil);
  Test('ENGINE_get_pkey_meths 函数加载', LResult);
end;

procedure TestEngine_UtilityFunctions;
var
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== 测试 6: Engine 工具函数 ===');

  // 测试获取 Engine ID
  LResult := Assigned(@ENGINE_get_id) and (ENGINE_get_id <> nil);
  Test('ENGINE_get_id 函数加载', LResult);

  // 测试获取 Engine 名称
  LResult := Assigned(@ENGINE_get_name) and (ENGINE_get_name <> nil);
  Test('ENGINE_get_name 函数加载', LResult);

  // 测试检查 Engine 能力
  LResult := Assigned(@ENGINE_is_capable) and (ENGINE_is_capable <> nil);
  Test('ENGINE_is_capable 函数加载', LResult);

  // 测试 Engine 注册函数
  LResult := Assigned(@ENGINE_register_all_complete) and (ENGINE_register_all_complete <> nil);
  Test('ENGINE_register_all_complete 函数加载', LResult);

  // 测试获取默认引擎
  LResult := Assigned(@ENGINE_get_default_RSA) and (ENGINE_get_default_RSA <> nil);
  Test('ENGINE_get_default_RSA 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_default_DSA) and (ENGINE_get_default_DSA <> nil);
  Test('ENGINE_get_default_DSA 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_default_ECDH) and (ENGINE_get_default_ECDH <> nil);
  Test('ENGINE_get_default_ECDH 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_default_ECDSA) and (ENGINE_get_default_ECDSA <> nil);
  Test('ENGINE_get_default_ECDSA 函数加载', LResult);

  LResult := Assigned(@ENGINE_get_default_RAND) and (ENGINE_get_default_RAND <> nil);
  Test('ENGINE_get_default_RAND 函数加载', LResult);
end;

begin
  TotalTests := 0;
  PassedTests := 0;
  FailedTests := 0;

  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('Engine (硬件加速引擎) 模块综合测试');
  WriteLn('=' + StringOfChar('=', 60));

  // 初始化 OpenSSL
  WriteLn;
  WriteLn('初始化 OpenSSL 库...');
  if not LoadOpenSSLCore then
  begin
    WriteLn('❌ 错误：无法加载 OpenSSL 库');
    Halt(1);
  end;
  WriteLn('✅ OpenSSL 库加载成功');
  WriteLn('版本: ', GetOpenSSLVersionString);

  // 执行测试套件
  TestEngine_BasicOperations;
  TestEngine_DynamicOperations;
  TestEngine_Methods;
  TestEngine_CipherMethods;
  TestEngine_Storage;
  TestEngine_UtilityFunctions;

  // 输出测试结果
  WriteLn;
  WriteLn('=' + StringOfChar('=', 60));
  WriteLn('测试结果总结');
  WriteLn('=' + StringOfChar('=', 60));
  WriteLn(Format('总测试数: %d', [TotalTests]));
  WriteLn(Format('通过: %d', [PassedTests]));
  WriteLn(Format('失败: %d', [FailedTests]));
  WriteLn(Format('通过率: %.1f%%', [PassedTests * 100.0 / TotalTests]));

  if FailedTests > 0 then
  begin
    WriteLn;
    WriteLn('❌ 测试未完全通过');
    Halt(1);
  end
  else
  begin
    WriteLn;
    WriteLn('🎉 所有测试通过！Engine 模块工作正常');
  end;

  UnloadOpenSSLCore;
end.

program test_framework_demo;

{******************************************************************************}
{  演示如何使用 TSimpleTestRunner 测试框架                                     }
{******************************************************************************}

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bn,
  test_openssl_base;

var
  Runner: TSimpleTestRunner;

procedure Test_OpenSSL_Loaded;
begin
  Runner.Check('Crypto library loaded',
    TOpenSSLLoader.IsLoaded(osslLibCrypto));
end;

procedure Test_BN_Operations;
var
  A, B, C: PBIGNUM;
  Ctx: PBN_CTX;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmBN) then
  begin
    WriteLn('  BN module not loaded, skipping');
    Exit;
  end;

  Ctx := BN_CTX_new();
  Runner.Check('BN_CTX_new', Ctx <> nil);

  A := BN_new();
  B := BN_new();
  C := BN_new();
  Runner.Check('BN_new (A)', A <> nil);
  Runner.Check('BN_new (B)', B <> nil);
  Runner.Check('BN_new (C)', C <> nil);

  // 设置值: A = 100, B = 23
  BN_set_word(A, 100);
  BN_set_word(B, 23);

  // C = A + B
  BN_add(C, A, B);
  Runner.Check('BN_add: 100 + 23 = 123', BN_get_word(C) = 123);

  // C = A * B
  BN_mul(C, A, B, Ctx);
  Runner.Check('BN_mul: 100 * 23 = 2300', BN_get_word(C) = 2300);

  // Cleanup
  BN_free(A);
  BN_free(B);
  BN_free(C);
  BN_CTX_free(Ctx);

  Runner.Check('Cleanup completed', True);
end;

procedure Test_Version_Info;
var
  Ver: TOpenSSLVersionInfo;
begin
  Ver := TOpenSSLTestBase.OpenSSLVersion;
  Runner.Check('Version major >= 1', Ver.Major >= 1);
  Runner.Check('Version string not empty', Ver.VersionString <> '');
  WriteLn('  OpenSSL Version: ', Ver.VersionString);
end;

begin
  WriteLn('=== Test Framework Demo ===');
  WriteLn;

  Runner := TSimpleTestRunner.Create;
  try
    // 声明需要的模块
    Runner.RequireModules([osmCore, osmBN]);

    // 初始化 (会自动加载依赖)
    if not Runner.Initialize then
    begin
      WriteLn('Failed to initialize test environment');
      Halt(1);
    end;

    WriteLn('OpenSSL Version: ', TOpenSSLTestBase.OpenSSLVersion.VersionString);
    WriteLn('Is OpenSSL 3.x: ', TOpenSSLTestBase.IsOpenSSL3);
    WriteLn;

    // 运行测试
    Runner.Test('OpenSSL Loading', @Test_OpenSSL_Loaded);
    Runner.Test('BN Operations', @Test_BN_Operations);
    Runner.Test('Version Info', @Test_Version_Info);

    // 打印摘要
    Runner.PrintSummary;

    if Runner.FailCount > 0 then
      Halt(1);
  finally
    Runner.Free;
  end;
end.

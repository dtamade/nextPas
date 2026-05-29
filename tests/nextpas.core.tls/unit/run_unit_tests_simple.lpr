program run_unit_tests_simple;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  fpcunit, testregistry,consoletestrunner,
  // 测试框架
  test_base,
  // 单元测试
  test_openssl_core_unit,
  test_openssl_async_unit;

var
  App: TTestRunner;

begin
  App := TTestRunner.Create(nil);
  try
    App.Initialize;
    App.Title := 'fafafa.ssl Unit Tests';
    App.Run;
  finally
    App.Free;
  end;
end.

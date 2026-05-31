program run_tests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils,
  fpcunit, testregistry, consoletestrunner,
  test_base,
  test_openssl_core_unit;

var
  App: TTestRunner;

begin
  DefaultFormat := fPlain;
  DefaultRunAllTests := True;
  
  App := TTestRunner.Create(nil);
  try
    App.Initialize;
    App.Run;
  finally
    App.Free;
  end;
end.

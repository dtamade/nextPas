unit test_openssl_core_unit;

{$mode objfpc}{$H+}

{
  OpenSSL Core 模块单元测试

  目标：
  - 库加载状态管理
  - 版本信息获取
  - 重复加载幂等性
  - 库句柄可用性
  - Crypto free 符号回退契约

  说明：当前测试运行于真实库环境；
  对“未加载状态”不可控前置条件使用显式 Skip 契约。
}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  test_base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.crypto;

type
  { TTestOpenSSLCore - OpenSSL Core 模块单元测试 }
  TTestOpenSSLCore = class(TTestBase)
  private
    FSavedLoadedState: Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // 库状态测试
    procedure TestIsLoaded_AfterLoad_ShouldReturnTrue;
    procedure TestIsLoaded_BeforeLoad_ShouldReturnFalse;

    // 版本信息测试
    procedure TestGetVersion_WhenLoaded_ShouldReturnValidString;
    procedure TestGetVersion_WhenNotLoaded_ShouldReturnEmptyOrError;

    // 多次加载测试
    procedure TestLoadMultipleTimes_ShouldBeIdempotent;

    // 库句柄测试
    procedure TestGetCryptoLibHandle_WhenLoaded_ShouldReturnNonZero;
    procedure TestGetSSLLibHandle_WhenLoaded_ShouldReturnNonZero;

    // Crypto 回归测试
    procedure TestLoadCrypto_WhenCryptoFreeAvailable_ShouldExposeOpenSSLFree;
  end;

implementation

{ TTestOpenSSLCore }

procedure TTestOpenSSLCore.SetUp;
begin
  inherited SetUp;
  FSavedLoadedState := TOpenSSLLoader.IsModuleLoaded(osmCore);
end;

procedure TTestOpenSSLCore.TearDown;
begin
  inherited TearDown;
end;

procedure TTestOpenSSLCore.TestIsLoaded_AfterLoad_ShouldReturnTrue;
begin
  LoadOpenSSLCore;
  AssertTrue('TOpenSSLLoader.IsModuleLoaded(osmCore) should return true after LoadOpenSSLCore',
             TOpenSSLLoader.IsModuleLoaded(osmCore));
end;

procedure TTestOpenSSLCore.TestIsLoaded_BeforeLoad_ShouldReturnFalse;
begin
  if FSavedLoadedState then
  begin
    Ignore('Precondition not met: OpenSSL core is already loaded at test start');
    Exit;
  end;

  AssertFalse('TOpenSSLLoader.IsModuleLoaded(osmCore) should return false before LoadOpenSSLCore',
             TOpenSSLLoader.IsModuleLoaded(osmCore));
end;

procedure TTestOpenSSLCore.TestGetVersion_WhenLoaded_ShouldReturnValidString;
var
  Version: string;
begin
  LoadOpenSSLCore;

  Version := GetOpenSSLVersionString;

  AssertTrue('Version string should not be empty', Version <> '');
  AssertTrue('Version should contain version number or dll name',
             (Pos('3.', Version) > 0) or
             (Pos('libcrypto', Version) > 0) or
             (Pos('OpenSSL', Version) > 0));
end;

procedure TTestOpenSSLCore.TestGetVersion_WhenNotLoaded_ShouldReturnEmptyOrError;
var
  Version: string;
  RaisedException: Boolean;
begin
  if FSavedLoadedState then
  begin
    Ignore('Precondition not met: OpenSSL core is already loaded at test start');
    Exit;
  end;

  RaisedException := False;
  Version := '';

  try
    Version := GetOpenSSLVersionString;
  except
    on E: Exception do
      RaisedException := True;
  end;

  AssertTrue('When core is not loaded, call should raise or return empty/unknown version',
    RaisedException or
    (Trim(Version) = '') or
    (Pos('unknown', LowerCase(Version)) > 0) or
    (Pos('not loaded', LowerCase(Version)) > 0));
end;

procedure TTestOpenSSLCore.TestLoadMultipleTimes_ShouldBeIdempotent;
var
  FirstLoadResult, SecondLoadResult: Boolean;
  FirstVersion, SecondVersion: string;
begin
  LoadOpenSSLCore;
  FirstLoadResult := TOpenSSLLoader.IsModuleLoaded(osmCore);
  FirstVersion := GetOpenSSLVersionString;

  LoadOpenSSLCore;
  SecondLoadResult := TOpenSSLLoader.IsModuleLoaded(osmCore);
  SecondVersion := GetOpenSSLVersionString;

  AssertTrue('Should be loaded after first call', FirstLoadResult);
  AssertTrue('Should still be loaded after second call', SecondLoadResult);
  AssertEquals('Version should be same after multiple loads',
               FirstVersion, SecondVersion);
end;

procedure TTestOpenSSLCore.TestGetCryptoLibHandle_WhenLoaded_ShouldReturnNonZero;
var
  Handle: TLibHandle;
begin
  LoadOpenSSLCore;
  Handle := GetCryptoLibHandle;
  AssertTrue('Crypto lib handle should be non-zero', Handle <> NilHandle);
end;

procedure TTestOpenSSLCore.TestGetSSLLibHandle_WhenLoaded_ShouldReturnNonZero;
var
  Handle: TLibHandle;
begin
  LoadOpenSSLCore;
  Handle := GetSSLLibHandle;
  AssertTrue('SSL lib handle should be non-zero', Handle <> NilHandle);
end;

procedure TTestOpenSSLCore.TestLoadCrypto_WhenCryptoFreeAvailable_ShouldExposeOpenSSLFree;
begin
  LoadOpenSSLCore;
  LoadOpenSSLCrypto;

  if Assigned(CRYPTO_free) then
    AssertTrue('OPENSSL_free should be assigned when CRYPTO_free is available',
               Assigned(OPENSSL_free))
  else
    Ignore('CRYPTO_free is unavailable in current OpenSSL build');
end;

initialization
  RegisterTest(TTestOpenSSLCore);

end.

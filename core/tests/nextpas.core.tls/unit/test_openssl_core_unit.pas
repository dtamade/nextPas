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
  nextpas.core.test,
  test_base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.crypto, nextpas.core.exception, nextpas.core.platform.dl, nextpas.core.text, nextpas.core.text.conv;

type
  { TTestOpenSSLCore - OpenSSL Core 模块单元测试 }
  TTestOpenSSLCore = class(TTestBase)
  private
    FSavedLoadedState: Boolean;
  protected
    procedure BeforeEach; override;
    procedure AfterEach; override;
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

procedure TTestOpenSSLCore.BeforeEach;
begin
  inherited BeforeEach;
  FSavedLoadedState := TOpenSSLLoader.IsModuleLoaded(osmCore);
end;

procedure TTestOpenSSLCore.AfterEach;
begin
  inherited AfterEach;
end;

procedure TTestOpenSSLCore.TestIsLoaded_AfterLoad_ShouldReturnTrue;
begin
  LoadOpenSSLCore;
  CheckTrue(TOpenSSLLoader.IsModuleLoaded(osmCore), 'TOpenSSLLoader.IsModuleLoaded(osmCore) should return true after LoadOpenSSLCore');
end;

procedure TTestOpenSSLCore.TestIsLoaded_BeforeLoad_ShouldReturnFalse;
begin
  if FSavedLoadedState then
  begin
    Skip('Precondition not met: OpenSSL core is already loaded at test start');
    Exit;
  end;

  CheckFalse(TOpenSSLLoader.IsModuleLoaded(osmCore), 'TOpenSSLLoader.IsModuleLoaded(osmCore) should return false before LoadOpenSSLCore');
end;

procedure TTestOpenSSLCore.TestGetVersion_WhenLoaded_ShouldReturnValidString;
var
  Version: string;
begin
  LoadOpenSSLCore;

  Version := GetOpenSSLVersionString;

  CheckTrue(Version <> '', 'Version string should not be empty');
  CheckTrue((Pos('3.', Version) > 0) or (Pos('libcrypto', Version) > 0) or (Pos('OpenSSL', Version) > 0), 'Version should contain version number or dll name');
end;

procedure TTestOpenSSLCore.TestGetVersion_WhenNotLoaded_ShouldReturnEmptyOrError;
var
  Version: string;
  RaisedException: Boolean;
begin
  if FSavedLoadedState then
  begin
    Skip('Precondition not met: OpenSSL core is already loaded at test start');
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

  CheckTrue(RaisedException or (Trim(Version) = '') or (Pos('unknown', LowerCase(Version)) > 0) or (Pos('not loaded', LowerCase(Version)) > 0), 'When core is not loaded, call should raise or return empty/unknown version');
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

  CheckTrue(FirstLoadResult, 'Should be loaded after first call');
  CheckTrue(SecondLoadResult, 'Should still be loaded after second call');
  CheckEqual(FirstVersion, SecondVersion, 'Version should be same after multiple loads');
end;

procedure TTestOpenSSLCore.TestGetCryptoLibHandle_WhenLoaded_ShouldReturnNonZero;
var
  Handle: TLibHandle;
begin
  LoadOpenSSLCore;
  Handle := GetCryptoLibHandle;
  CheckTrue(Handle <> NilHandle, 'Crypto lib handle should be non-zero');
end;

procedure TTestOpenSSLCore.TestGetSSLLibHandle_WhenLoaded_ShouldReturnNonZero;
var
  Handle: TLibHandle;
begin
  LoadOpenSSLCore;
  Handle := GetSSLLibHandle;
  CheckTrue(Handle <> NilHandle, 'SSL lib handle should be non-zero');
end;

procedure TTestOpenSSLCore.TestLoadCrypto_WhenCryptoFreeAvailable_ShouldExposeOpenSSLFree;
begin
  LoadOpenSSLCore;
  LoadOpenSSLCrypto;

  if Assigned(CRYPTO_free) then
    CheckTrue(Assigned(OPENSSL_free), 'OPENSSL_free should be assigned when CRYPTO_free is available');
  else
    Skip('CRYPTO_free is unavailable in current OpenSSL build');
end;

end.

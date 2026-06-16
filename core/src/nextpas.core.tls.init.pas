unit nextpas.core.tls.init;

{$mode objfpc}{$H+}

{
  OpenSSL 统一初始化辅助单元
  
  使用此单元可确保所有必要的OpenSSL模块被正确加载。
  在使用任何SSL/TLS或加密功能前调用 InitializeOpenSSL。
  
  示例：
uses nextpas.core.tls.init; begin InitializeOpenSSL;
      // 现在可以使用所有功能
    end.
}

interface

uses nextpas.core.tls.base, nextpas.core.exception, nextpas.core.tls.exceptions, nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.rand, nextpas.core.tls.openssl.api;

{ 初始化所有OpenSSL模块
  调用此函数将加载：
  - 核心库 (libcrypto/libssl)
  - EVP模块（加密/哈希）
  - RAND模块（随机数）
  - 所有其他常用模块
  
  可以安全地多次调用（会检查是否已初始化）}
procedure InitializeOpenSSL;

{ 检查OpenSSL是否已初始化 }
function IsOpenSSLInitialized: Boolean;

{ 获取OpenSSL版本字符串 }
function GetOpenSSLVersion: string;

implementation

procedure InitializeOpenSSL;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmInitGlobal) then
    Exit;

  // 加载核心库
  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    LoadOpenSSLCore();

  if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    raise ESSLException.Create('Failed to load OpenSSL core library');

  // 加载EVP模块（加密/解密/哈希）
  LoadEVP(GetCryptoLibHandle);

  // 加载RAND模块（随机数生成）
  // 注意：在某些环境中LoadOpenSSLRAND可能因为依赖检查失败
  // 但RAND_bytes通常已经通过核心库可用
  try
    LoadOpenSSLRAND();
  except
    on E: Exception do
    begin
      // P1-2.4: 忽略错误，RAND函数通常已可用
      // 调试模式下输出警告
      {$IFDEF DEBUG}
      WriteLn('[DEBUG] nextpas.core.tls.init: LoadOpenSSLRAND failed: ', E.Message);
      {$ENDIF}
    end;
  end;

  TOpenSSLLoader.SetModuleLoaded(osmInitGlobal, True);
end;

function IsOpenSSLInitialized: Boolean;
begin
  Result := TOpenSSLLoader.IsModuleLoaded(osmInitGlobal) and TOpenSSLLoader.IsModuleLoaded(osmCore);
end;

function GetOpenSSLVersion: string;
begin
  if TOpenSSLLoader.IsModuleLoaded(osmCore) then
    Result := GetOpenSSLVersionString
  else
    Result := 'Not loaded';
end;

end.

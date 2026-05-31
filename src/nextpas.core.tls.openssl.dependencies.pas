{
  nextpas.core.tls.openssl.dependencies - 模块依赖图接口

  版本: 1.1
  作者: fafafa.ssl 开发团队
  创建: 2025-12-25

  描述:
    提供 OpenSSL API 模块依赖管理的便捷接口。
    核心实现在 TOpenSSLLoader 中，此单元提供额外的工具函数。

  设计原则:
    - 委托核心功能到 TOpenSSLLoader
    - 提供额外的调试和诊断工具
    - 保持向后兼容性
}

unit nextpas.core.tls.openssl.dependencies;

{$mode ObjFPC}{$H+}

interface

uses
  nextpas.core.tls.openssl.loader;

{**
 * 获取模块的直接依赖
 * @param AModule 要查询的模块
 * @return 模块的直接依赖集合
 * @note 委托给 TOpenSSLLoader.GetModuleDependencies
 *}
function GetModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;

{**
 * 获取模块的所有依赖（包括传递依赖）
 * @param AModule 要查询的模块
 * @return 模块的所有依赖集合
 * @note 委托给 TOpenSSLLoader.GetAllModuleDependencies
 *}
function GetAllModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;

{**
 * 检查模块的所有依赖是否已加载
 * @param AModule 要检查的模块
 * @return 如果所有依赖都已加载则返回 True
 * @note 委托给 TOpenSSLLoader.AreModuleDependenciesLoaded
 *}
function AreModuleDependenciesLoaded(AModule: TOpenSSLModule): Boolean;

{**
 * 获取未加载的依赖模块列表
 * @param AModule 要检查的模块
 * @return 未加载的依赖模块集合
 *}
function GetUnloadedDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;

{**
 * 获取模块名称字符串（用于调试和日志）
 * @param AModule 模块枚举值
 * @return 模块名称字符串
 *}
function GetModuleName(AModule: TOpenSSLModule): string;

{**
 * 获取模块依赖的文本描述（用于调试）
 * @param AModule 模块枚举值
 * @return 依赖描述字符串，如 "RSA -> [Core, BN]"
 *}
function GetModuleDependencyDescription(AModule: TOpenSSLModule): string;

implementation

function GetModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;
begin
  Result := TOpenSSLLoader.GetModuleDependencies(AModule);
end;

function GetAllModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;
begin
  Result := TOpenSSLLoader.GetAllModuleDependencies(AModule);
end;

function AreModuleDependenciesLoaded(AModule: TOpenSSLModule): Boolean;
begin
  Result := TOpenSSLLoader.AreModuleDependenciesLoaded(AModule);
end;

function GetUnloadedDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;
var
  LDeps: TOpenSSLModuleSet;
  LDep: TOpenSSLModule;
begin
  Result := [];
  LDeps := TOpenSSLLoader.GetAllModuleDependencies(AModule);

  for LDep in LDeps do
  begin
    if not TOpenSSLLoader.IsModuleLoaded(LDep) then
      Result := Result + [LDep];
  end;
end;

{$WARN 6018 OFF}
function GetModuleName(AModule: TOpenSSLModule): string;
begin
  case AModule of
    osmCore:       Result := 'Core';
    osmSSL:        Result := 'SSL';
    osmEVP:        Result := 'EVP';
    osmRSA:        Result := 'RSA';
    osmDSA:        Result := 'DSA';
    osmDH:         Result := 'DH';
    osmEC:         Result := 'EC';
    osmECDSA:      Result := 'ECDSA';
    osmECDH:       Result := 'ECDH';
    osmBN:         Result := 'BN';
    osmAES:        Result := 'AES';
    osmDES:        Result := 'DES';
    osmSHA:        Result := 'SHA';
    osmSHA3:       Result := 'SHA3';
    osmMD:         Result := 'MD';
    osmHMAC:       Result := 'HMAC';
    osmCMAC:       Result := 'CMAC';
    osmRAND:       Result := 'RAND';
    osmKDF:        Result := 'KDF';
    osmERR:        Result := 'ERR';
    osmBIO:        Result := 'BIO';
    osmPEM:        Result := 'PEM';
    osmASN1:       Result := 'ASN1';
    osmX509:       Result := 'X509';
    osmPKCS:       Result := 'PKCS';
    osmPKCS7:      Result := 'PKCS7';
    osmPKCS12:     Result := 'PKCS12';
    osmCMS:        Result := 'CMS';
    osmOCSP:       Result := 'OCSP';
    osmBLAKE2:     Result := 'BLAKE2';
    osmChaCha:     Result := 'ChaCha';
    osmModes:      Result := 'Modes';
    osmEngine:     Result := 'Engine';
    osmProvider:   Result := 'Provider';
    osmStack:      Result := 'Stack';
    osmLHash:      Result := 'LHash';
    osmConf:       Result := 'Conf';
    osmThread:     Result := 'Thread';
    osmSRP:        Result := 'SRP';
    osmDSO:        Result := 'DSO';
    osmTS:         Result := 'TS';
    osmCT:         Result := 'CT';
    osmStore:      Result := 'Store';
    osmParam:      Result := 'Param';
    osmTXTDB:      Result := 'TXTDB';
    osmInitGlobal: Result := 'InitGlobal';
    osmInitEncoding: Result := 'InitEncoding';
    osmInitCert:   Result := 'InitCert';
    osmInitCrypto: Result := 'InitCrypto';
  else
    Result := 'Unknown';
  end;
end;
{$WARN 6018 ON}

function GetModuleDependencyDescription(AModule: TOpenSSLModule): string;
var
  LDeps: TOpenSSLModuleSet;
  LDep: TOpenSSLModule;
  LFirst: Boolean;
begin
  Result := GetModuleName(AModule) + ' -> [';
  LDeps := TOpenSSLLoader.GetModuleDependencies(AModule);
  LFirst := True;

  for LDep in LDeps do
  begin
    if not LFirst then
      Result := Result + ', ';
    Result := Result + GetModuleName(LDep);
    LFirst := False;
  end;

  Result := Result + ']';
end;

end.

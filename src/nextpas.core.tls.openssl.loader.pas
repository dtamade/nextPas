unit nextpas.core.tls.openssl.loader;

{******************************************************************************}
{                                                                              }
{  OpenSSL 动态库加载器 - 统一的动态库管理                                      }
{                                                                              }
{  目的: 消除重复的 LoadLibrary/GetProcAddress 代码                           }
{  范围: OpenSSL libcrypto 和 libssl 动态库加载                                }
{                                                                              }
{  设计原则:                                                                   }
{  1. 单例模式 - 全局共享库句柄                                                }
{  2. 懒加载 - 按需加载库                                                      }
{  3. 版本兼容 - 支持 OpenSSL 3.x, 1.1.x, 1.0.x                               }
{  4. 错误处理 - 统一的错误报告机制                                            }
{                                                                              }
{  Phase: 3.3 P0 - 代码去重                                                   }
{  Author: fafafa.ssl team                                                    }
{  Date: 2025-12-16                                                           }
{                                                                              }
{******************************************************************************}

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils,
  ctypes,  // culong, cint 等 C 类型
  {$IFDEF WINDOWS}
  Windows
  {$ELSE}
  dynlibs
  {$ENDIF};

type
  {**
   * OpenSSL 库类型
   *}
  TOpenSSLLibraryType = (
    osslLibCrypto,  // libcrypto (加密库)
    osslLibSSL      // libssl (SSL/TLS库)
  );

  TOpenSSLLibHandle = {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};

  {**
   * OpenSSL API 模块枚举
   * 用于统一管理各模块的加载状态
   *}
  TOpenSSLModule = (
    osmCore,      // 核心库函数
    osmSSL,       // SSL/TLS 函数
    osmEVP,       // EVP 高级加密接口
    osmRSA,       // RSA 非对称加密
    osmDSA,       // DSA 数字签名
    osmDH,        // DH 密钥交换
    osmEC,        // 椭圆曲线
    osmECDSA,     // ECDSA 签名
    osmECDH,      // ECDH 密钥交换
    osmBN,        // 大数运算
    osmAES,       // AES 对称加密
    osmDES,       // DES 加密
    osmSHA,       // SHA 哈希
    osmSHA3,      // SHA-3 哈希
    osmMD,        // 消息摘要
    osmHMAC,      // HMAC
    osmCMAC,      // CMAC
    osmRAND,      // 随机数
    osmKDF,       // 密钥派生函数 (PBKDF2, HKDF, scrypt)
    osmERR,       // 错误处理
    osmBIO,       // BIO I/O
    osmPEM,       // PEM 格式
    osmASN1,      // ASN.1 编解码
    osmX509,      // X.509 证书
    osmPKCS,      // PKCS 标准
    osmPKCS7,     // PKCS#7
    osmPKCS12,    // PKCS#12
    osmCMS,       // CMS
    osmOCSP,      // OCSP
    osmBLAKE2,    // BLAKE2 哈希
    osmChaCha,    // ChaCha20 流加密
    osmModes,     // 加密模式
    osmEngine,    // Engine 接口
    osmProvider,  // OpenSSL 3.0 Provider
    osmStack,     // STACK 数据结构
    osmLHash,     // LHASH 哈希表
    osmConf,      // 配置
    osmThread,    // 线程支持
    osmSRP,       // SRP 协议
    osmDSO,       // 动态库加载
    osmTS,        // 时间戳
    osmCT,        // 证书透明度
    osmStore,     // 证书存储
    osmParam,     // OSSL_PARAM
    osmTXTDB,     // TXT_DB 数据库
    // 高层工具类初始化状态
    osmInitGlobal,    // nextpas.core.tls.init 全局初始化
    osmInitEncoding,  // TEncodingUtils 初始化
    osmInitCrypto,    // TCryptoUtils 初始化
    osmInitCert       // TCertificateUtils 初始化
  );

  {**
   * OpenSSL 模块集合
   *}
  TOpenSSLModuleSet = set of TOpenSSLModule;

  {**
   * 函数绑定记录 - 用于批量加载函数指针
   *}
  TFunctionBinding = record
    Name: PAnsiChar;      // 函数名称
    FuncPtr: PPointer;    // 指向函数指针变量的指针
    Required: Boolean;    // 是否必须（可选，默认 False）
  end;

  {**
   * 函数绑定数组类型
   *}
  TFunctionBindings = array of TFunctionBinding;

  {**
   * OpenSSL 库版本信息
   *}
  TOpenSSLVersionInfo = record
    Major: Integer;         // 主版本号 (3, 1, 等)
    Minor: Integer;         // 次版本号
    Patch: Integer;         // 补丁版本号
    VersionString: string;  // 完整版本字符串
    IsOpenSSL3: Boolean;    // 是否为 OpenSSL 3.x
  end;

  {**
   * OpenSSL 动态库加载器（单例类）
   *
   * 提供统一的 OpenSSL 动态库加载和函数指针获取功能。
   * 所有 OpenSSL API 绑定模块应使用此类而非自行加载库。
   *
   * 使用示例:
   * <code>
   *   // 获取 libcrypto 句柄
   *   LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
   *
   *   // 获取函数指针
   *   EVP_MD_CTX_new := TOpenSSLLoader.GetFunction(LHandle, 'EVP_MD_CTX_new');
   *
   *   // 检查函数是否可用
   *   if TOpenSSLLoader.IsFunctionAvailable(LHandle, 'EVP_MAC_fetch') then
   *     WriteLn('OpenSSL 3.x EVP_MAC API is available');
   * </code>
   *}
  TOpenSSLLoader = class
  private
    class var
      FLibCrypto: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
      FLibSSL: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
      FInitialized: Boolean;
      FVersionInfo: TOpenSSLVersionInfo;
      FLoadedModules: TOpenSSLModuleSet;  // 已加载的模块集合
      FLastLoadFunctionsLoadedCount: Integer;
      FLastLoadFunctionsMissingRequired: string;

    class procedure DetectVersion;
    class function TryLoadLibrary(const ANames: array of string): {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
    class function TryLoadLibraryFromOpenSSLRoot(ALibType: TOpenSSLLibraryType): {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
  public
    // ========== 库加载 ==========

    {**
     * 获取指定类型的库句柄
     *
     * @param ALibType 库类型（libcrypto 或 libssl）
     * @return 库句柄，如果加载失败返回 0
     *
     * 注意: 此方法会自动尝试加载库（懒加载）
     *}
    class function GetLibraryHandle(ALibType: TOpenSSLLibraryType): {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};

    {**
     * 从指定库获取函数指针
     *
     * @param AHandle 库句柄
     * @param AFunctionName 函数名称
     * @return 函数指针，如果函数不存在返回 nil
     *
     * 注意: 此方法不抛出异常，调用者需检查返回值
     *}
    class function GetFunction(AHandle: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF}; const AFunctionName: string): Pointer;

    {**
     * 批量加载函数指针
     *
     * @param AHandle 库句柄
     * @param ABindings 函数绑定数组
     * @return 加载的函数数量
     *
     * 使用示例:
     * <code>
     *   var Bindings: array[0..2] of TFunctionBinding = (
     *     (Name: 'RSA_new';  FuncPtr: @RSA_new;  Required: True),
     *     (Name: 'RSA_free'; FuncPtr: @RSA_free; Required: True),
     *     (Name: 'RSA_size'; FuncPtr: @RSA_size; Required: False)
     *   );
     *   LoadedCount := TOpenSSLLoader.LoadFunctions(Handle, Bindings);
     * </code>
     *}
    class function LoadFunctions(AHandle: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
      const ABindings: array of TFunctionBinding): Integer;

    {**
     * 获取最近一次批量绑定命中的函数数量
     *}
    class function GetLastLoadFunctionsLoadedCount: Integer;

    {**
     * 获取最近一次批量绑定缺失的 required symbol 名单
     * 列表为空字符串时表示没有 required-missing failure
     *}
    class function GetLastLoadFunctionsMissingRequired: string;

    {**
     * 清除函数指针（设置为 nil）
     *
     * @param ABindings 函数绑定数组
     *}
    class procedure ClearFunctions(const ABindings: array of TFunctionBinding);

    {**
     * 检查函数是否可用
     *
     * @param AHandle 库句柄
     * @param AFunctionName 函数名称
     * @return True=函数存在，False=不存在
     *}
    class function IsFunctionAvailable(AHandle: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF}; const AFunctionName: string): Boolean;

    // ========== 模块状态管理 ==========

    {**
     * 检查模块是否已加载
     *
     * @param AModule 模块类型
     * @return True=已加载，False=未加载
     *}
    class function IsModuleLoaded(AModule: TOpenSSLModule): Boolean;

    {**
     * 设置模块加载状态
     *
     * @param AModule 模块类型
     * @param ALoaded 是否已加载
     *}
    class procedure SetModuleLoaded(AModule: TOpenSSLModule; ALoaded: Boolean);

    {**
     * 获取所有已加载的模块
     *
     * @return 已加载模块的集合
     *}
    class function GetLoadedModules: TOpenSSLModuleSet;

    {**
     * 重置所有模块状态
     *}
    class procedure ResetModuleStates;

    // ========== 版本信息 ==========

    {**
     * 获取 OpenSSL 版本信息
     *
     * @return 版本信息结构体
     *}
    class function GetVersionInfo: TOpenSSLVersionInfo;

    {**
     * 检查是否为 OpenSSL 3.x
     *
     * @return True=OpenSSL 3.x, False=1.x 或未加载
     *}
    class function IsOpenSSL3: Boolean;

    {**
     * 卸载所有已加载的库
     *
     * 注意: 通常在程序退出时调用，正常使用不需要手动卸载
     *}
    class procedure UnloadLibraries;

    {**
     * 检查库是否已加载
     *
     * @param ALibType 库类型
     * @return True=已加载，False=未加载
     *}
    class function IsLoaded(ALibType: TOpenSSLLibraryType): Boolean;

    // ========== 依赖管理 ==========

    {**
     * 确保模块的所有依赖已加载
     *
     * @param AModule 模块类型
     * @param ALoadFunc 模块加载函数（可选）
     * @return True=所有依赖已就绪，False=某些依赖无法加载
     *
     * 注意: 此方法会自动加载缺失的依赖模块
     *}
    class function EnsureModuleDependencies(AModule: TOpenSSLModule): Boolean;

    {**
     * 获取模块的直接依赖
     *
     * @param AModule 模块类型
     * @return 模块的直接依赖集合
     *}
    class function GetModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;

    {**
     * 获取模块的所有依赖（包括传递依赖）
     *
     * @param AModule 模块类型
     * @return 模块的所有依赖集合
     *}
    class function GetAllModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;

    {**
     * 检查模块的所有依赖是否已加载
     *
     * @param AModule 模块类型
     * @return True=所有依赖已加载，False=有依赖未加载
     *}
    class function AreModuleDependenciesLoaded(AModule: TOpenSSLModule): Boolean;
  end;

implementation

const
  {**
   * 模块依赖映射表
   * 每个模块声明其直接依赖的模块
   *}
  MODULE_DEPENDENCIES: array[TOpenSSLModule] of TOpenSSLModuleSet = (
    { osmCore }       [],                           // 核心库 - 无依赖
    { osmSSL }        [osmCore],                    // SSL/TLS - 依赖核心
    { osmEVP }        [osmCore],                    // EVP - 依赖核心
    { osmRSA }        [osmCore, osmBN],             // RSA - 依赖核心和大数
    { osmDSA }        [osmCore, osmBN],             // DSA - 依赖核心和大数
    { osmDH }         [osmCore, osmBN],             // DH - 依赖核心和大数
    { osmEC }         [osmCore, osmBN],             // EC - 依赖核心和大数
    { osmECDSA }      [osmCore, osmBN, osmEC],      // ECDSA - 依赖核心、大数和EC
    { osmECDH }       [osmCore, osmBN, osmEC],      // ECDH - 依赖核心、大数和EC
    { osmBN }         [osmCore],                    // 大数 - 依赖核心
    { osmAES }        [osmCore],                    // AES - 依赖核心
    { osmDES }        [osmCore],                    // DES - 依赖核心
    { osmSHA }        [osmCore],                    // SHA - 依赖核心
    { osmSHA3 }       [osmCore, osmEVP],            // SHA3 - 依赖核心和EVP
    { osmMD }         [osmCore, osmEVP],            // MD - 依赖核心和EVP
    { osmHMAC }       [osmCore, osmEVP],            // HMAC - 依赖核心和EVP
    { osmCMAC }       [osmCore, osmEVP],            // CMAC - 依赖核心和EVP
    { osmRAND }       [osmCore],                    // RAND - 依赖核心
    { osmKDF }        [osmCore, osmEVP],            // KDF - 依赖核心和EVP
    { osmERR }        [osmCore],                    // ERR - 依赖核心
    { osmBIO }        [osmCore],                    // BIO - 依赖核心
    { osmPEM }        [osmCore, osmBIO, osmX509],   // PEM - 依赖核心、BIO和X509
    { osmASN1 }       [osmCore],                    // ASN1 - 依赖核心
    { osmX509 }       [osmCore, osmASN1, osmEVP],   // X509 - 依赖核心、ASN1和EVP
    { osmPKCS }       [osmCore, osmX509],           // PKCS - 依赖核心和X509
    { osmPKCS7 }      [osmCore, osmX509, osmBIO],   // PKCS7 - 依赖核心、X509和BIO
    { osmPKCS12 }     [osmCore, osmX509, osmEVP],   // PKCS12 - 依赖核心、X509和EVP
    { osmCMS }        [osmCore, osmX509, osmBIO],   // CMS - 依赖核心、X509和BIO
    { osmOCSP }       [osmCore, osmX509, osmBIO],   // OCSP - 依赖核心、X509和BIO
    { osmBLAKE2 }     [osmCore, osmEVP],            // BLAKE2 - 依赖核心和EVP
    { osmChaCha }     [osmCore, osmEVP],            // ChaCha - 依赖核心和EVP
    { osmModes }      [osmCore],                    // Modes - 依赖核心
    { osmEngine }     [osmCore],                    // Engine - 依赖核心
    { osmProvider }   [osmCore],                    // Provider - 依赖核心
    { osmStack }      [osmCore],                    // Stack - 依赖核心
    { osmLHash }      [osmCore],                    // LHash - 依赖核心
    { osmConf }       [osmCore, osmBIO],            // Conf - 依赖核心和BIO
    { osmThread }     [osmCore],                    // Thread - 依赖核心
    { osmSRP }        [osmCore, osmBN],             // SRP - 依赖核心和大数
    { osmDSO }        [osmCore],                    // DSO - 依赖核心
    { osmTS }         [osmCore, osmX509, osmBIO],   // TS - 依赖核心、X509和BIO
    { osmCT }         [osmCore, osmX509],           // CT - 依赖核心和X509
    { osmStore }      [osmCore, osmX509],           // Store - 依赖核心和X509
    { osmParam }      [osmCore],                    // Param - 依赖核心
    { osmTXTDB }      [osmCore, osmBIO],            // TXTDB - 依赖核心和BIO
    { osmInitGlobal } [],                           // 全局初始化 - 无依赖
    { osmInitEncoding } [osmCore, osmEVP],          // 编码初始化
    { osmInitCrypto } [osmCore, osmEVP],            // 加密工具初始化
    { osmInitCert }   [osmCore, osmX509, osmEVP]    // 证书初始化
  );

{ TOpenSSLLoader }

class function TOpenSSLLoader.TryLoadLibrary(const ANames: array of string): {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
var
  I: Integer;
begin
  Result := 0;
  for I := Low(ANames) to High(ANames) do
  begin
    {$IFDEF WINDOWS}
    Result := LoadLibrary(PChar(ANames[I]));
    {$ELSE}
    Result := LoadLibrary(ANames[I]);
    {$ENDIF}

    if Result <> 0 then
      Break;  // 加载成功
  end;
end;

class function TOpenSSLLoader.TryLoadLibraryFromOpenSSLRoot(
  ALibType: TOpenSSLLibraryType): {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
{$IFDEF WINDOWS}
begin
  Result := 0;
end;
{$ELSE}
var
  LRoot: string;
  LLibDir: string;
begin
  Result := 0;

  LRoot := Trim(GetEnvironmentVariable('OPENSSL_ROOT'));
  if LRoot = '' then
    Exit;

  LLibDir := IncludeTrailingPathDelimiter(LRoot) + 'lib' + PathDelim;

  case ALibType of
    osslLibCrypto:
      Result := TryLoadLibrary([
        LLibDir + 'libcrypto.3.dylib',
        LLibDir + 'libcrypto.dylib',
        LLibDir + 'libcrypto.1.1.dylib',
        LLibDir + 'libcrypto.so.3',
        LLibDir + 'libcrypto.so.1.1',
        LLibDir + 'libcrypto.so'
      ]);
    osslLibSSL:
      Result := TryLoadLibrary([
        LLibDir + 'libssl.3.dylib',
        LLibDir + 'libssl.dylib',
        LLibDir + 'libssl.1.1.dylib',
        LLibDir + 'libssl.so.3',
        LLibDir + 'libssl.so.1.1',
        LLibDir + 'libssl.so'
      ]);
  end;
end;
{$ENDIF}

class function TOpenSSLLoader.GetLibraryHandle(ALibType: TOpenSSLLibraryType): {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
begin
  Result := 0;

  case ALibType of
    osslLibCrypto:
    begin
      if FLibCrypto = 0 then
      begin
        FLibCrypto := TryLoadLibraryFromOpenSSLRoot(osslLibCrypto);

        // 尝试加载 libcrypto，按优先级顺序
        if FLibCrypto = 0 then
          FLibCrypto := TryLoadLibrary([
            {$IFDEF WINDOWS}
            'libcrypto-3-x64.dll',      // OpenSSL 3.x (Windows 64-bit)
            'libcrypto-3.dll',          // OpenSSL 3.x (Windows 32-bit)
            'libcrypto-1_1-x64.dll',    // OpenSSL 1.1.x (Windows 64-bit)
            'libcrypto-1_1.dll',        // OpenSSL 1.1.x (Windows 32-bit)
            'libeay32.dll'              // OpenSSL 1.0.x (Windows)
            {$ELSE}
            'libcrypto.so.3',           // OpenSSL 3.x (Linux/Unix)
            'libcrypto.so.1.1',         // OpenSSL 1.1.x
            'libcrypto.so.1.0.0',       // OpenSSL 1.0.x
            'libcrypto.so',             // 通用符号链接
            'libcrypto.3.dylib',        // OpenSSL 3.x (macOS/Homebrew)
            'libcrypto.1.1.dylib',      // OpenSSL 1.1.x (macOS/Homebrew)
            'libcrypto.dylib'           // macOS
            {$ENDIF}
          ]);

        if FLibCrypto <> 0 then
        begin
          FInitialized := True;
          DetectVersion;
        end;
      end;
      Result := FLibCrypto;
    end;

    osslLibSSL:
    begin
      if FLibSSL = 0 then
      begin
        FLibSSL := TryLoadLibraryFromOpenSSLRoot(osslLibSSL);

        // 尝试加载 libssl
        if FLibSSL = 0 then
          FLibSSL := TryLoadLibrary([
            {$IFDEF WINDOWS}
            'libssl-3-x64.dll',
            'libssl-3.dll',
            'libssl-1_1-x64.dll',
            'libssl-1_1.dll',
            'ssleay32.dll'
            {$ELSE}
            'libssl.so.3',
            'libssl.so.1.1',
            'libssl.so.1.0.0',
            'libssl.so',
            'libssl.3.dylib',           // OpenSSL 3.x (macOS/Homebrew)
            'libssl.1.1.dylib',         // OpenSSL 1.1.x (macOS/Homebrew)
            'libssl.dylib'
            {$ENDIF}
          ]);
      end;
      Result := FLibSSL;
    end;
  end;
end;

class function TOpenSSLLoader.GetFunction(AHandle: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF}; const AFunctionName: string): Pointer;
begin
  Result := nil;

  if AHandle = 0 then
    Exit;

  {$IFDEF WINDOWS}
  Result := GetProcAddress(AHandle, PChar(AFunctionName));
  {$ELSE}
  Result := GetProcAddress(AHandle, PChar(AFunctionName));
  {$ENDIF}
end;

class function TOpenSSLLoader.IsFunctionAvailable(AHandle: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF}; const AFunctionName: string): Boolean;
begin
  Result := GetFunction(AHandle, AFunctionName) <> nil;
end;

class function TOpenSSLLoader.LoadFunctions(AHandle: {$IFDEF WINDOWS}HMODULE{$ELSE}TLibHandle{$ENDIF};
  const ABindings: array of TFunctionBinding): Integer;
var
  I: Integer;
  LFunc: Pointer;
  LRequiredMissing: Boolean;
  LMissingRequired: string;
begin
  Result := 0;
  FLastLoadFunctionsLoadedCount := 0;
  FLastLoadFunctionsMissingRequired := '';
  if AHandle = 0 then
    Exit;

  LRequiredMissing := False;
  LMissingRequired := '';
  for I := Low(ABindings) to High(ABindings) do
  begin
    if ABindings[I].FuncPtr <> nil then
    begin
      LFunc := GetFunction(AHandle, string(ABindings[I].Name));
      ABindings[I].FuncPtr^ := LFunc;
      if LFunc <> nil then
        Inc(Result);

      if (LFunc = nil) and ABindings[I].Required then
      begin
        LRequiredMissing := True;
        if LMissingRequired <> '' then
          LMissingRequired := LMissingRequired + ',';
        LMissingRequired := LMissingRequired + string(ABindings[I].Name);
      end;
    end;
  end;

  FLastLoadFunctionsLoadedCount := Result;
  FLastLoadFunctionsMissingRequired := LMissingRequired;

  if LRequiredMissing then
  begin
    ClearFunctions(ABindings);
    Result := -1;
  end;
end;

class function TOpenSSLLoader.GetLastLoadFunctionsLoadedCount: Integer;
begin
  Result := FLastLoadFunctionsLoadedCount;
end;

class function TOpenSSLLoader.GetLastLoadFunctionsMissingRequired: string;
begin
  Result := FLastLoadFunctionsMissingRequired;
end;

class procedure TOpenSSLLoader.ClearFunctions(const ABindings: array of TFunctionBinding);
var
  I: Integer;
begin
  for I := Low(ABindings) to High(ABindings) do
  begin
    if ABindings[I].FuncPtr <> nil then
      ABindings[I].FuncPtr^ := nil;
  end;
end;

class function TOpenSSLLoader.IsModuleLoaded(AModule: TOpenSSLModule): Boolean;
begin
  Result := AModule in FLoadedModules;
end;

class procedure TOpenSSLLoader.SetModuleLoaded(AModule: TOpenSSLModule; ALoaded: Boolean);
begin
  if ALoaded then
    Include(FLoadedModules, AModule)
  else
    Exclude(FLoadedModules, AModule);
end;

class function TOpenSSLLoader.GetLoadedModules: TOpenSSLModuleSet;
begin
  Result := FLoadedModules;
end;

class procedure TOpenSSLLoader.ResetModuleStates;
begin
  FLoadedModules := [];
end;

class procedure TOpenSSLLoader.DetectVersion;
type
  TOpenSSL_version_num = function: culong; cdecl;
  TOpenSSL_version = function(t: cint): PAnsiChar; cdecl;
var
  LVersionNum: TOpenSSL_version_num;
  LVersion: TOpenSSL_version;
  LVersionValue: culong;
begin
  // 初始化默认值
  FillChar(FVersionInfo, SizeOf(FVersionInfo), 0);
  FVersionInfo.VersionString := 'Unknown';

  if FLibCrypto = 0 then
    Exit;

  // 尝试获取版本号
  LVersionNum := TOpenSSL_version_num(GetFunction(FLibCrypto, 'OpenSSL_version_num'));
  if not Assigned(LVersionNum) then
    LVersionNum := TOpenSSL_version_num(GetFunction(FLibCrypto, 'SSLeay'));  // OpenSSL 1.0.x

  if Assigned(LVersionNum) then
  begin
    LVersionValue := LVersionNum();

    // 解析版本号 (格式: 0xMNNFFPPS - Major, miNor, Fix, Patch, Status)
    FVersionInfo.Major := (LVersionValue shr 28) and $FF;
    FVersionInfo.Minor := (LVersionValue shr 20) and $FF;
    FVersionInfo.Patch := (LVersionValue shr 12) and $FF;
    FVersionInfo.IsOpenSSL3 := FVersionInfo.Major >= 3;
  end;

  // 尝试获取版本字符串
  LVersion := TOpenSSL_version(GetFunction(FLibCrypto, 'OpenSSL_version'));
  if not Assigned(LVersion) then
    LVersion := TOpenSSL_version(GetFunction(FLibCrypto, 'SSLeay_version'));  // OpenSSL 1.0.x

  if Assigned(LVersion) then
    FVersionInfo.VersionString := string(LVersion(0));  // OPENSSL_VERSION
end;

class function TOpenSSLLoader.GetVersionInfo: TOpenSSLVersionInfo;
begin
  if not FInitialized then
    GetLibraryHandle(osslLibCrypto);  // 触发加载和版本检测

  Result := FVersionInfo;
end;

class function TOpenSSLLoader.IsOpenSSL3: Boolean;
begin
  Result := GetVersionInfo.IsOpenSSL3;
end;

class procedure TOpenSSLLoader.UnloadLibraries;
begin
  if FLibCrypto <> 0 then
  begin
    FreeLibrary(FLibCrypto);
    FLibCrypto := 0;
  end;

  if FLibSSL <> 0 then
  begin
    FreeLibrary(FLibSSL);
    FLibSSL := 0;
  end;

  FInitialized := False;
  FLoadedModules := [];
  FVersionInfo.VersionString := '';
  FillChar(FVersionInfo, SizeOf(FVersionInfo), 0);
end;

class function TOpenSSLLoader.IsLoaded(ALibType: TOpenSSLLibraryType): Boolean;
begin
  case ALibType of
    osslLibCrypto: Result := FLibCrypto <> 0;
    osslLibSSL: Result := FLibSSL <> 0;
  end;
end;

class function TOpenSSLLoader.GetModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;
begin
  Result := MODULE_DEPENDENCIES[AModule];
end;

class function TOpenSSLLoader.GetAllModuleDependencies(AModule: TOpenSSLModule): TOpenSSLModuleSet;
var
  LDep: TOpenSSLModule;
  LNewDeps: TOpenSSLModuleSet;
  LChanged: Boolean;
begin
  // 从直接依赖开始
  Result := MODULE_DEPENDENCIES[AModule];

  // 迭代添加传递依赖
  repeat
    LChanged := False;
    LNewDeps := [];

    for LDep in Result do
    begin
      LNewDeps := LNewDeps + MODULE_DEPENDENCIES[LDep];
    end;

    // 如果有新的依赖，添加到结果中
    if not (LNewDeps <= Result) then
    begin
      Result := Result + LNewDeps;
      LChanged := True;
    end;
  until not LChanged;
end;

class function TOpenSSLLoader.AreModuleDependenciesLoaded(AModule: TOpenSSLModule): Boolean;
var
  LDeps: TOpenSSLModuleSet;
  LDep: TOpenSSLModule;
begin
  Result := True;
  LDeps := GetAllModuleDependencies(AModule);

  for LDep in LDeps do
  begin
    if not IsModuleLoaded(LDep) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

class function TOpenSSLLoader.EnsureModuleDependencies(AModule: TOpenSSLModule): Boolean;
var
  LDeps: TOpenSSLModuleSet;
  LDep: TOpenSSLModule;
begin
  // 获取所有依赖（包括传递依赖）
  LDeps := GetAllModuleDependencies(AModule);

  // 检查每个依赖是否已加载
  for LDep in LDeps do
  begin
    if not IsModuleLoaded(LDep) then
    begin
      // 注意：这里只检查依赖是否已加载，不自动加载
      // 因为加载函数在各个模块中定义，这里无法调用
      // 如果需要自动加载，调用者应先加载依赖模块
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

initialization
  TOpenSSLLoader.FLibCrypto := 0;
  TOpenSSLLoader.FLibSSL := 0;
  TOpenSSLLoader.FInitialized := False;
  TOpenSSLLoader.FLoadedModules := [];
  TOpenSSLLoader.FLastLoadFunctionsLoadedCount := 0;
  TOpenSSLLoader.FLastLoadFunctionsMissingRequired := '';

finalization
  TOpenSSLLoader.UnloadLibraries;

end.

{**
 * Unit: nextpas.core.tls.factory
 * Purpose: SSL/TLS 库工厂模式 - 统一创建和管理SSL对象
 *
 * Features:
 * - 自动检测可用的SSL后端（OpenSSL、WinSSL等）
 * - 工厂模式创建SSL对象（Context、Certificate、Store等）
 * - 多后端支持与自动切换
 * - 简化的单一入口API
 *
 * Thread Safety: 所有类方法线程安全
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2025-09-28
 *
 * @example
 * <code>
 *   // 自动检测并创建SSL Context
 *   LCtx := TSSLFactory.CreateContext(sslCtxClient);
 *
 *   // 指定使用OpenSSL后端
 *   LCtx := TSSLFactory.CreateContext(sslCtxClient, sslOpenSSL);
 *
 *   // 使用配置对象创建
 *   LConfig := TSSLConfig.Create;
 *   LConfig.ContextType := sslCtxClient;
 *   LCtx := TSSLFactory.CreateContext(LConfig);
 * </code>
 *}

unit nextpas.core.tls.factory;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{ 禁用弃用 API 警告 - 工厂模式为旧 API 提供兼容层 }
{$WARN 6058 off}  // Symbol is deprecated

interface

uses SysUtils, nextpas.core.tls.base, nextpas.core.tls.exceptions, // 新增：类型化异常 nextpas.core.tls.logging, nextpas.core.tls.collections; // P0: 可替换的 Map 接口;

type
  {** SSL库类类型 (用于内部注册) *}
  TSSLLibraryClass = class of TInterfacedObject;
  TSSLLibraryCreateFunc = function: ISSLLibrary;

  {**
   * SSL库注册信息
   *
   * 用于后端库的注册和管理
   *}
  TSSLLibraryRegistration = record
    LibraryType: TSSLLibraryType;      // 库类型标识
    LibraryClass: TSSLLibraryClass;    // 库类（必须实现 ISSLLibrary）
    CreateFunc: TSSLLibraryCreateFunc; // 显式 creator path；用于保留 backend constructor truth
    Description: string;                // 库描述
    Priority: Integer;                  // 优先级（数字越大越优先）
  end;

  {**
   * TSSLFactory - SSL工厂类
   *
   * 提供统一的SSL对象创建接口，支持多后端自动选择。
   *
   * 主要功能:
   * - 创建SSL Context (客户端/服务器)
   * - 创建证书和证书存储对象
   * - 后端库检测和切换
   * - 库注册和管理
   *
   * 使用模式:
   * <code>
   *   // 最简单：自动检测后端
   *   LCtx := TSSLFactory.CreateContext(sslCtxClient);
   *
   *   // 指定后端
   *   LCtx := TSSLFactory.CreateContext(sslCtxClient, sslOpenSSL);
   *
   *   // 高级：使用配置
   *   LCtx := TSSLFactory.CreateContext(LConfig);
   * </code>
   *}
  TSSLFactory = class
  private
    class var
      // P0: 使用 Map 接口替代动态数组，方便后续替换为 fafafa.core 的 HashMap
      FRegistrationMap: specialize IIntegerMap<TSSLLibraryRegistration>;
      FLibraries: array[TSSLLibraryType] of ISSLLibrary;
      FDefaultLibraryType: TSSLLibraryType;
      FInitialized: Boolean;
      FAutoInitialize: Boolean;
      
    class procedure Initialize;
    class procedure Finalize;
    class function CreateLibraryInstance(ALibType: TSSLLibraryType): ISSLLibrary;
    class procedure CheckInitialized;
  public
    { ==================== 库访问（高级用法） ==================== }

    {**
     * 获取指定类型的库实例
     *
     * @param ALibType 库类型（sslOpenSSL, sslWinSSL等）
     * @return 库实例接口
     * @raises ESSLConfigurationException 库不可用时
     *
     * 注意: 普通用户通常不需要直接使用此方法
     *}
    class function GetLibrary(ALibType: TSSLLibraryType): ISSLLibrary;

    { ==================== 库注册（后端开发者使用） ==================== }

    {**
     * 注册SSL后端库
     *
     * @param ALibType 库类型标识
     * @param ALibraryClass 库类（必须实现 ISSLLibrary）
     * @param ADescription 库描述（可选）
     * @param APriority 优先级（默认0，数字越大越优先）
     *
     * 注意: 此方法供后端实现的初始化代码调用
     *}
    class procedure RegisterLibrary(
      ALibType: TSSLLibraryType;
      ALibraryClass: TSSLLibraryClass;
      const ADescription: string = '';
      APriority: Integer = 0
    );

    class procedure RegisterLibrary(
      ALibType: TSSLLibraryType;
      ACreateFunc: TSSLLibraryCreateFunc;
      const ADescription: string = '';
      APriority: Integer = 0
    );

    {**
     * 取消注册SSL后端库
     *
     * @param ALibType 库类型标识
     *}
    class procedure UnregisterLibrary(ALibType: TSSLLibraryType);
    class procedure UnregisterLibraryForProcessShutdown(ALibType: TSSLLibraryType);

    { ==================== 库检测与查询 ==================== }

    {**
     * 检查指定库是否可用
     *
     * @param ALibType 库类型
     * @return True=可用，False=不可用
     *
     * @example
     * <code>
     *   if TSSLFactory.IsLibraryAvailable(sslOpenSSL) then
     *     WriteLn('OpenSSL is available');
     * </code>
     *}
    class function IsLibraryAvailable(ALibType: TSSLLibraryType): Boolean;

    {**
     * 获取所有可用的库列表
     *
     * @return 可用库类型集合
     *
     * @example
     * <code>
     *   LLibs := TSSLFactory.GetAvailableLibraries;
     *   for LLib in LLibs do
     *     WriteLn(TSSLFactory.GetLibraryDescription(LLib));
     * </code>
     *}
    class function GetAvailableLibraries: TSSLLibraryTypes;

    {**
     * 获取库的描述信息
     *
     * @param ALibType 库类型
     * @return 库描述字符串
     *}
    class function GetLibraryDescription(ALibType: TSSLLibraryType): string;

    {**
     * 自动检测最佳可用库
     *
     * 根据平台和可用性选择最适合的库:
     * - Windows: WinSSL（如果可用）> OpenSSL
     * - Linux/macOS: OpenSSL
     *
     * @return 最佳库类型
     * @raises ESSLConfigurationException 无可用库时
     *}
    class function DetectBestLibrary: TSSLLibraryType;

    { ==================== 默认库管理 ==================== }

    {**
     * 设置默认使用的SSL库
     *
     * @param ALibType 库类型
     * @raises ESSLConfigurationException 库不可用时
     *
     * @example
     * <code>
     *   TSSLFactory.SetDefaultLibrary(sslOpenSSL);
     * </code>
     *}
    class procedure SetDefaultLibrary(ALibType: TSSLLibraryType);

    {**
     * 获取当前默认库
     *
     * @return 默认库类型
     *}
    class function GetDefaultLibrary: TSSLLibraryType;

    { ==================== 对象创建（主要API） ==================== }

    {**
     * 创建SSL Context
     *
     * @param AContextType 上下文类型（sslCtxClient 或 sslCtxServer）
     * @param ALibType 库类型（默认sslAutoDetect自动选择）
     * @return SSL Context接口
     * @raises ESSLInitializationException 初始化失败时
     *
     * @example
     * <code>
     *   // 自动检测库
     *   LCtx := TSSLFactory.CreateContext(sslCtxClient);
     *
     *   // 指定使用OpenSSL
     *   LCtx := TSSLFactory.CreateContext(sslCtxServer, sslOpenSSL);
     * </code>
     *}
    class function CreateContext(
      AContextType: TSSLContextType;
      ALibType: TSSLLibraryType = sslAutoDetect
    ): ISSLContext; overload;

    {**
     * 使用配置对象创建SSL Context
     *
     * @param AConfig SSL配置对象
     * @return SSL Context接口
     * @raises ESSLInitializationException 初始化失败时
     *
     * @example
     * <code>
     *   LConfig := TSSLConfig.Create;
     *   LConfig.ContextType := sslCtxClient;
     *   LConfig.ProtocolVersions := [sslTLS12, sslTLS13];
     *   LCtx := TSSLFactory.CreateContext(LConfig);
     * </code>
     *}
    class function CreateContext(const AConfig: TSSLConfig): ISSLContext; overload;
    class function CreateContext(const AConfig: TSSLContextConfig): ISSLContext; overload;

    class procedure NormalizeConfig(var AConfig: TSSLConfig);

    {**
     * 创建证书对象
     *
     * @param ALibType 库类型（默认自动检测）
     * @return 证书接口
     *}
    class function CreateCertificate(ALibType: TSSLLibraryType = sslAutoDetect): ISSLCertificate;

    {**
     * 创建证书存储对象
     *
     * @param ALibType 库类型（默认自动检测）
     * @return 证书存储接口
     *}
    class function CreateCertificateStore(ALibType: TSSLLibraryType = sslAutoDetect): ISSLCertificateStore;
    
    // 快捷方法 - 简化的服务端上下文
    // 保持当前 server default-config / raw context verify baseline；
    // 如需 non-mTLS / no-verify，请由调用方显式设置 VerifyMode。
    class function CreateServerContext(const ACertFile, AKeyFile: string;
                                      ALibType: TSSLLibraryType = sslAutoDetect): ISSLContext;
    
    // 库管理
    class function GetLibraryInstance(ALibType: TSSLLibraryType = sslAutoDetect): ISSLLibrary;
    class procedure ReleaseLibrary(ALibType: TSSLLibraryType);
    class procedure ReleaseAllLibraries;
    
    // 全局配置
    class procedure SetAutoInitialize(AValue: Boolean);
    class function GetAutoInitialize: Boolean;
    
    // 版本和信息
    class function GetVersionInfo: string;
    class function GetSystemInfo: string;
    
    // 属性 - 注释掉 class property，使用方法代替
    // class property DefaultLibrary: TSSLLibraryType read GetDefaultLibrary write SetDefaultLibrary;
    // class property AutoInitialize: Boolean read GetAutoInitialize write SetAutoInitialize;
    // class property AvailableLibraries: TSSLLibraryTypes read GetAvailableLibraries;
  end;

  { TSSLHelper - 证书/随机/early-data 便捷辅助类；不作为 TLS bootstrap 主入口 }
  TSSLHelper = class
  public
    // 证书验证
    class function VerifyCertificateFile(const AFileName: string): Boolean;
    class function GetCertificateInfo(const AFileName: string): TSSLCertificateInfo;

    // 工具方法
    class function GenerateRandomBytes(ACount: Integer): TBytes;
    class function HashData(const AData: TBytes; AHashType: TSSLHash): string;

    // Early-data optional-interface helpers
    class function SupportsEarlyDataContext(const AContext: ISSLContext): Boolean;
    class function SupportsEarlyDataConnection(const AConnection: ISSLConnection): Boolean;
    class function TryGetEarlyDataContext(const AContext: ISSLContext;
      out AEarlyDataContext: ISSLEarlyDataContext): Boolean;
    class function TryGetEarlyDataConnection(const AConnection: ISSLConnection;
      out AEarlyDataConnection: ISSLEarlyDataConnection): Boolean;
    class function ConfigureClientEarlyData(const AContext: ISSLContext;
      AEnabled: Boolean = True): Boolean;
    class function ConfigureServerEarlyData(const AContext: ISSLContext;
      APolicy: TSSLEarlyDataServerPolicy; AMaxSize: Cardinal): Boolean;
    class function GetEarlyDataStatus(const AConnection: ISSLConnection): TSSLEarlyDataStatus;
    class function GetEarlyDataLimit(const AConnection: ISSLConnection): Cardinal;
  end;

implementation

uses Windows, nextpas.core.crypto.hash, nextpas.core.tls.errors, nextpas.core.tls.random, nextpas.core.tls.freepascal.context.material, nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.evp, nextpas.core.tls.openssl.api.sha, nextpas.core.tls.openssl.api.sha3.evp, nextpas.core.tls.openssl.api.blake2;

var
  GFactoryLock: TRTLCriticalSection;  // 工厂类的全局锁
  GFactoryLockInitialized: Boolean = False;

procedure NormalizeConfigOptions(var AConfig: TSSLConfig);
begin
  // Option-bridge compatibility inputs keep their historical write-through behavior:
  // when callers pass conflicting legacy booleans and explicit Options bits, the
  // legacy booleans update the relevant Options first, then the final Options truth
  // is projected back into the compatibility booleans below.
  if AConfig.EnableCompression then
    Exclude(AConfig.Options, ssoDisableCompression)
  else
    Include(AConfig.Options, ssoDisableCompression);

  Include(AConfig.Options, ssoDisableRenegotiation);

  Include(AConfig.Options, ssoNoSSLv2);
  Include(AConfig.Options, ssoNoSSLv3);
  Include(AConfig.Options, ssoNoTLSv1);
  Include(AConfig.Options, ssoNoTLSv1_1);

  if AConfig.ProtocolVersions <> [] then
  begin
    if sslProtocolSSL2 in AConfig.ProtocolVersions then
      Exclude(AConfig.Options, ssoNoSSLv2)
    else
      Include(AConfig.Options, ssoNoSSLv2);

    if sslProtocolSSL3 in AConfig.ProtocolVersions then
      Exclude(AConfig.Options, ssoNoSSLv3)
    else
      Include(AConfig.Options, ssoNoSSLv3);

    if sslProtocolTLS10 in AConfig.ProtocolVersions then
      Exclude(AConfig.Options, ssoNoTLSv1)
    else
      Include(AConfig.Options, ssoNoTLSv1);

    if sslProtocolTLS11 in AConfig.ProtocolVersions then
      Exclude(AConfig.Options, ssoNoTLSv1_1)
    else
      Include(AConfig.Options, ssoNoTLSv1_1);

    if sslProtocolTLS12 in AConfig.ProtocolVersions then
      Exclude(AConfig.Options, ssoNoTLSv1_2)
    else
      Include(AConfig.Options, ssoNoTLSv1_2);

    if sslProtocolTLS13 in AConfig.ProtocolVersions then
      Exclude(AConfig.Options, ssoNoTLSv1_3)
    else
      Include(AConfig.Options, ssoNoTLSv1_3);

    if (AConfig.PreferredVersion <> sslProtocolUnknown) and
      not (AConfig.PreferredVersion in AConfig.ProtocolVersions) then
      AConfig.PreferredVersion := sslProtocolUnknown;
  end;

  if AConfig.EnableSessionTickets then
    Include(AConfig.Options, ssoEnableSessionTickets)
  else
    Exclude(AConfig.Options, ssoEnableSessionTickets);

  if AConfig.EnableOCSPStapling then
    Include(AConfig.Options, ssoEnableOCSPStapling)
  else
    Exclude(AConfig.Options, ssoEnableOCSPStapling);

  // 设置会话超时默认值
  if AConfig.SessionTimeout <= 0 then
    AConfig.SessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;

  // 设置会话缓存大小默认值
  if AConfig.SessionCacheSize <= 0 then
    AConfig.SessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;

  if AConfig.SessionCacheSize > 0 then
    Include(AConfig.Options, ssoEnableSessionCache)
  else
    Exclude(AConfig.Options, ssoEnableSessionCache);

  if AConfig.VerifyDepth <= 0 then
    AConfig.VerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;

  if AConfig.CipherList = '' then
    AConfig.CipherList := SSL_DEFAULT_CIPHER_LIST;

  if AConfig.CipherSuites = '' then
    AConfig.CipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;

  // Keep compatibility bridge booleans aligned with the final option truth
  // after normalization has finished mutating the option set.
  AConfig.EnableCompression := not (ssoDisableCompression in AConfig.Options);
  AConfig.EnableSessionTickets := ssoEnableSessionTickets in AConfig.Options;
  AConfig.EnableOCSPStapling := ssoEnableOCSPStapling in AConfig.Options;
end;

function ResolveVerifyModeForContextCreation(
  AVerifyMode: TSSLVerifyModes;
  AContextType: TSSLContextType;
  const ACAFile: string;
  const ACAPath: string;
  AUseSystemRoots: Boolean
): TSSLVerifyModes;
begin
  Result := AVerifyMode;

  if AContextType <> sslCtxServer then
    Exit;

  if Result = [] then
    Exit;

  if sslVerifyNone in Result then
  begin
    Result := [];
    Exit;
  end;

  if sslVerifyFailIfNoPeerCert in Result then
    Exit;

  if (sslVerifyPeer in Result) and
    ((Trim(ACAFile) <> '') or
     (Trim(ACAPath) <> '') or
     (AUseSystemRoots)) then
    Exit;

  Result := [];
end;

function ResolveContextVerifyModeForCreation(
  const AConfig: TSSLConfig;
  AContextType: TSSLContextType
): TSSLVerifyModes;
begin
  Result := ResolveVerifyModeForContextCreation(
    AConfig.VerifyMode,
    AContextType,
    AConfig.CAFile,
    AConfig.CAPath,
    AConfig.UseSystemRoots
  );
end;

procedure ApplySystemRootsIfRequested(const AContext: ISSLContext;
  AUseSystemRoots: Boolean; const LLib: ISSLLibrary);
var
  LStore: ISSLCertificateStore;
begin
  if (AContext = nil) or (not AUseSystemRoots) then
    Exit;

  LStore := TSSLFactory.CreateCertificateStore(LLib.GetLibraryType);
  if LStore <> nil then
  begin
    LStore.LoadSystemStore;
    AContext.SetCertificateStore(LStore);
  end;
end;

procedure ValidateRequestLoggingScope(const AConfig: TSSLConfig);
begin
  if AConfig.LogLevel <> sslLogError then
    raise ESSLConfigurationException.CreateWithContext(
      'LogLevel is library-scoped. Configure logging through ISSLLibrary defaults instead of TSSLFactory.CreateContext(const AConfig).',
      sslErrConfiguration,
      'TSSLFactory.CreateContext(const AConfig)',
      0,
      AConfig.LibraryType
    );

  if Assigned(AConfig.LogCallback) then
    raise ESSLConfigurationException.CreateWithContext(
      'LogCallback is library-scoped. Configure logging through ISSLLibrary defaults instead of TSSLFactory.CreateContext(const AConfig).',
      sslErrConfiguration,
      'TSSLFactory.CreateContext(const AConfig)',
      0,
      AConfig.LibraryType
    );
end;

function ContextTypeSupportsServerReplayStore(
  AContextType: TSSLContextType): Boolean;
begin
  Result := AContextType in [sslCtxServer, sslCtxBoth];
end;

function ContextTypeSupportsClientEarlyData(
  AContextType: TSSLContextType): Boolean;
begin
  Result := AContextType in [sslCtxClient, sslCtxBoth];
end;

function ContextTypeSupportsServerEarlyData(
  AContextType: TSSLContextType): Boolean;
begin
  Result := AContextType in [sslCtxServer, sslCtxBoth];
end;

function ReplayStoreClientScopeMessage(
  const AField, ACallSite: string): string;
begin
  Result := Format(
    '%s is server-scoped. Client contexts do not install replay stores; remove it from %s.',
    [AField, ACallSite]
  );
end;

procedure ValidateReplayStoreContextScope(
  AContextType: TSSLContextType;
  const AReplayStoreFile: string;
  const AReplayStoreDirectory: string;
  ALibraryType: TSSLLibraryType;
  const ACallSite: string
);
begin
  if not ContextTypeSupportsServerReplayStore(AContextType) then
  begin
    if Trim(AReplayStoreFile) <> '' then
      raise ESSLConfigurationException.CreateWithContext(
        ReplayStoreClientScopeMessage(
          'server_early_data_replay_store_file',
          ACallSite
        ),
        sslErrConfiguration,
        ACallSite,
        0,
        ALibraryType
      );

    if Trim(AReplayStoreDirectory) <> '' then
      raise ESSLConfigurationException.CreateWithContext(
        ReplayStoreClientScopeMessage(
          'server_early_data_replay_store_directory',
          ACallSite
        ),
        sslErrConfiguration,
        ACallSite,
        0,
        ALibraryType
      );
  end;
end;

procedure LogContextLevelServerNameCompatibilityWarning(const ACallSite: string);
begin
  TSecurityLog.Warning(
    'Factory',
    Format(
      '%s received TSSLConfig.ServerName as deprecated context-level SNI compatibility; ' +
      'CreateContext ignores it for new contexts; prefer per-connection SNI via ' +
      'ISSLClientConnection.SetServerName or TSSLConnector.Connect*(..., ServerName).',
      [ACallSite]
    )
  );
end;

procedure ValidateConnectionCreationScope(const AConfig: TSSLConfig;
  AContextType: TSSLContextType; const ACallSite: string);
begin
  if (AConfig.HandshakeTimeout <> 0) and
    (AConfig.HandshakeTimeout <> SSL_DEFAULT_HANDSHAKE_TIMEOUT) then
    raise ESSLConfigurationException.CreateWithContext(
      'HandshakeTimeout is connection-scoped. Use TSSLConnector.WithTimeout, ' +
      'TSSLAcceptor.WithTimeout, or ISSLConnectionControl.SetTimeout instead of ' + ACallSite + '.',
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );

  if (AConfig.BufferSize <> 0) and
    (AConfig.BufferSize <> SSL_DEFAULT_BUFFER_SIZE) then
    raise ESSLConfigurationException.CreateWithContext(
      'BufferSize is not a context-scoped factory option. Configure buffering in the surrounding ' +
      'transport/IO layer instead of ' + ACallSite + '.',
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );

  if (AContextType = sslCtxServer) and (Trim(AConfig.ServerName) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'ServerName is client-scoped. Server-side connections ignore context-level ServerName; ' +
      'remove it from ' + ACallSite + ' when creating server contexts.',
      sslErrConfiguration,
      ACallSite,
      0,
      AConfig.LibraryType
    );

  ValidateReplayStoreContextScope(
    AContextType,
    AConfig.ServerEarlyDataReplayStoreFile,
    AConfig.ServerEarlyDataReplayStoreDirectory,
    AConfig.LibraryType,
    ACallSite
  );
end;

procedure ApplyEarlyDataContextValues(
  const AContext: ISSLContext;
  AClientEnabled: Boolean;
  AServerPolicy: TSSLEarlyDataServerPolicy;
  AServerMaxEarlyDataSize: Cardinal
);
var
  LEarlyDataContext: ISSLEarlyDataContext;
begin
  if (AContext = nil) or (not Supports(AContext, ISSLEarlyDataContext, LEarlyDataContext)) then
    Exit;

  if ContextTypeSupportsClientEarlyData(AContext.GetContextType) and
    (LEarlyDataContext.GetClientEarlyDataEnabled <> AClientEnabled) then
    LEarlyDataContext.SetClientEarlyDataEnabled(AClientEnabled);

  if ContextTypeSupportsServerEarlyData(AContext.GetContextType) then
  begin
    if LEarlyDataContext.GetServerMaxEarlyDataSize <> AServerMaxEarlyDataSize then
      LEarlyDataContext.SetServerMaxEarlyDataSize(AServerMaxEarlyDataSize);

    if LEarlyDataContext.GetServerEarlyDataPolicy <> AServerPolicy then
      LEarlyDataContext.SetServerEarlyDataPolicy(AServerPolicy);
  end;
end;

procedure ApplyEarlyDataContextConfig(const AContext: ISSLContext; const AConfig: TSSLConfig);
begin
  ApplyEarlyDataContextValues(
    AContext,
    AConfig.ClientEarlyDataEnabled,
    AConfig.ServerEarlyDataPolicy,
    AConfig.ServerMaxEarlyDataSize
  );
end;

procedure ApplyEarlyDataReplayStoreValues(
  const AContext: ISSLContext;
  const AReplayStoreFile: string;
  const AReplayStoreDirectory: string;
  ALibraryType: TSSLLibraryType;
  const ACallSite: string
);
var
  LInstaller: IFreePascalContextEarlyDataReplayInstaller;
  LDirectoryInstaller: IFreePascalContextEarlyDataReplayDirectoryInstaller;
begin
  if (AContext = nil) or
    (not ContextTypeSupportsServerReplayStore(AContext.GetContextType)) then
    Exit;

  if (Trim(AReplayStoreFile) <> '') and
    (Trim(AReplayStoreDirectory) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'Configured server_early_data_replay_store_file and ' +
      'server_early_data_replay_store_directory are mutually exclusive; configure not both',
      sslErrConfiguration,
      ACallSite,
      0,
      ALibraryType
    );

  if Trim(AReplayStoreFile) <> '' then
  begin
    if not Supports(AContext, IFreePascalContextEarlyDataReplayInstaller, LInstaller) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_file requires a backend that implements IFreePascalContextEarlyDataReplayInstaller',
        sslErrConfiguration,
        ACallSite,
        0,
        ALibraryType
      );

    if not LInstaller.InstallFileBackedReplayLedger(AReplayStoreFile) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_file could not install the requested replay store',
        sslErrConfiguration,
        ACallSite,
        0,
        ALibraryType
      );
  end;

  if Trim(AReplayStoreDirectory) <> '' then
  begin
    if not Supports(AContext, IFreePascalContextEarlyDataReplayDirectoryInstaller,
      LDirectoryInstaller) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_directory requires a backend that implements IFreePascalContextEarlyDataReplayDirectoryInstaller',
        sslErrConfiguration,
        ACallSite,
        0,
        ALibraryType
      );

    if not LDirectoryInstaller.InstallDirectoryBackedReplayLedger(
      AReplayStoreDirectory
    ) then
      raise ESSLConfigurationException.CreateWithContext(
        'Configured server_early_data_replay_store_directory could not install the requested replay store',
        sslErrConfiguration,
        ACallSite,
        0,
        ALibraryType
      );
  end;
end;

procedure ApplyEarlyDataReplayStoreConfig(const AContext: ISSLContext;
  const AConfig: TSSLConfig; const ACallSite: string);
begin
  ApplyEarlyDataReplayStoreValues(
    AContext,
    AConfig.ServerEarlyDataReplayStoreFile,
    AConfig.ServerEarlyDataReplayStoreDirectory,
    AConfig.LibraryType,
    ACallSite
  );
end;

procedure NormalizeContextConfigOptions(var AConfig: TSSLContextConfig);
begin
  if AConfig.SessionTimeout <= 0 then
    AConfig.SessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;

  if AConfig.SessionCacheSize <= 0 then
    AConfig.SessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;

  if AConfig.VerifyDepth <= 0 then
    AConfig.VerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;

  if AConfig.CipherList = '' then
    AConfig.CipherList := SSL_DEFAULT_CIPHER_LIST;

  if AConfig.CipherSuites = '' then
    AConfig.CipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;

  if (AConfig.PreferredVersion <> sslProtocolUnknown) and
    (AConfig.ProtocolVersions <> []) and
    not (AConfig.PreferredVersion in AConfig.ProtocolVersions) then
    AConfig.PreferredVersion := sslProtocolUnknown;
end;

procedure ApplyContextConfigToContext(
  const AContext: ISSLContext;
  const AConfig: TSSLContextConfig;
  const ALibrary: ISSLLibrary;
  const ACallSite: string
);
var
  LVerifyMode: TSSLVerifyModes;
begin
  if AContext = nil then
    Exit;

  LVerifyMode := ResolveVerifyModeForContextCreation(
    AConfig.VerifyMode,
    AConfig.ContextType,
    AConfig.CAFile,
    AConfig.CAPath,
    AConfig.UseSystemRoots
  );

  AContext.SetOptions(AConfig.Options);
  AContext.SetSessionCacheSize(AConfig.SessionCacheSize);
  AContext.SetSessionTimeout(AConfig.SessionTimeout);
  AContext.SetSessionCacheMode(ssoEnableSessionCache in AConfig.Options);

  if AConfig.ProtocolVersions <> [] then
    AContext.SetProtocolVersions(AConfig.ProtocolVersions);

  if AConfig.PreferredVersion <> sslProtocolUnknown then
    AContext.SetPreferredVersion(AConfig.PreferredVersion);

  if AConfig.CertificateFile <> '' then
    AContext.LoadCertificate(AConfig.CertificateFile);

  if AConfig.PrivateKeyFile <> '' then
    AContext.LoadPrivateKey(AConfig.PrivateKeyFile, AConfig.PrivateKeyPassword);

  ApplySystemRootsIfRequested(AContext, AConfig.UseSystemRoots, ALibrary);

  if AConfig.CAFile <> '' then
    AContext.LoadCAFile(AConfig.CAFile);

  if AConfig.CAPath <> '' then
    AContext.LoadCAPath(AConfig.CAPath);

  AContext.SetVerifyMode(LVerifyMode);

  if AConfig.VerifyDepth > 0 then
    AContext.SetVerifyDepth(AConfig.VerifyDepth);

  if AConfig.CipherList <> '' then
    AContext.SetCipherList(AConfig.CipherList);

  if AConfig.CipherSuites <> '' then
    AContext.SetCipherSuites(AConfig.CipherSuites);

  if AConfig.ALPNProtocols <> '' then
    AContext.SetALPNProtocols(AConfig.ALPNProtocols);

  ApplyEarlyDataContextValues(
    AContext,
    AConfig.ClientEarlyDataEnabled,
    AConfig.ServerEarlyDataPolicy,
    AConfig.ServerMaxEarlyDataSize
  );
  ApplyEarlyDataReplayStoreValues(
    AContext,
    AConfig.ServerEarlyDataReplayStoreFile,
    AConfig.ServerEarlyDataReplayStoreDirectory,
    AConfig.LibraryType,
    ACallSite
  );
end;

class procedure TSSLFactory.NormalizeConfig(var AConfig: TSSLConfig);
begin
  NormalizeConfigOptions(AConfig);
end;

{ TSSLFactory }

class procedure TSSLFactory.Initialize;
begin
  if not FInitialized then
  begin
    // 初始化全局锁
    if not GFactoryLockInitialized then
    begin
      InitCriticalSection(GFactoryLock);
      GFactoryLockInitialized := True;
    end;
    // P0: 创建 Map 实例（后续可替换为 fafafa.core 的 HashMap）
    FRegistrationMap := TMapFactory.specialize CreateIntegerMap<TSSLLibraryRegistration>;
    FDefaultLibraryType := sslAutoDetect;
    FAutoInitialize := True;
    FInitialized := True;

    // 注册清理过程
    // 在程序退出时自动清理
  end;
end;

class procedure TSSLFactory.Finalize;
begin
  if FInitialized then
  begin
    ReleaseAllLibraries;
    // P0: 清理 Map
    FRegistrationMap := nil;
    if GFactoryLockInitialized then
    begin
      DoneCriticalSection(GFactoryLock);
      GFactoryLockInitialized := False;
    end;
    FInitialized := False;
  end;
end;

class procedure TSSLFactory.CheckInitialized;
begin
  if not FInitialized then
    Initialize;
  if not GFactoryLockInitialized then
    RaiseSSLError('Internal error: Lock not initialized', sslErrGeneral);
end;

class procedure TSSLFactory.RegisterLibrary(ALibType: TSSLLibraryType;
  ALibraryClass: TSSLLibraryClass; const ADescription: string; APriority: Integer);
var
  LReg: TSSLLibraryRegistration;
begin
  CheckInitialized;
  EnterCriticalSection(GFactoryLock);
  try
    // P0: 使用 Map 接口，O(1) 查找（当使用 HashMap 实现时）
    LReg.LibraryType := ALibType;
    LReg.LibraryClass := ALibraryClass;
    LReg.CreateFunc := nil;
    LReg.Description := ADescription;
    LReg.Priority := APriority;
    FRegistrationMap.Put(Ord(ALibType), LReg);
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class procedure TSSLFactory.RegisterLibrary(ALibType: TSSLLibraryType;
  ACreateFunc: TSSLLibraryCreateFunc; const ADescription: string;
  APriority: Integer);
var
  LReg: TSSLLibraryRegistration;
begin
  CheckInitialized;
  EnterCriticalSection(GFactoryLock);
  try
    LReg.LibraryType := ALibType;
    LReg.LibraryClass := nil;
    LReg.CreateFunc := ACreateFunc;
    LReg.Description := ADescription;
    LReg.Priority := APriority;
    FRegistrationMap.Put(Ord(ALibType), LReg);
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class procedure TSSLFactory.UnregisterLibrary(ALibType: TSSLLibraryType);
begin
  CheckInitialized;
  EnterCriticalSection(GFactoryLock);
  try
    // P0: 使用 Map 接口
    if FRegistrationMap.Contains(Ord(ALibType)) then
    begin
      // 释放库实例
      ReleaseLibrary(ALibType);
      // 从 Map 中删除
      FRegistrationMap.Remove(Ord(ALibType));
    end;
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class procedure TSSLFactory.UnregisterLibraryForProcessShutdown(ALibType: TSSLLibraryType);
begin
  if (not FInitialized) or (not GFactoryLockInitialized) then
    Exit;

  EnterCriticalSection(GFactoryLock);
  try
    // 进程退出期只摘除注册和工厂持有的接口引用，避免再次进入后端 Finalize。
    if Assigned(FLibraries[ALibType]) then
      FLibraries[ALibType] := nil;

    if Assigned(FRegistrationMap) and FRegistrationMap.Contains(Ord(ALibType)) then
      FRegistrationMap.Remove(Ord(ALibType));
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class function TSSLFactory.IsLibraryAvailable(ALibType: TSSLLibraryType): Boolean;
var
  LLib: ISSLLibrary;
begin
  Result := False;
  CheckInitialized;

  if ALibType = sslAutoDetect then
  begin
    // P0: 使用 Map 接口
    Result := FRegistrationMap.Count > 0;
    Exit;
  end;

  EnterCriticalSection(GFactoryLock);
  try
    if Assigned(FLibraries[ALibType]) then
      LLib := FLibraries[ALibType]
    else
    begin
      if FRegistrationMap.Contains(Ord(ALibType)) then
      begin
        try
          LLib := CreateLibraryInstance(ALibType);
        except
          LLib := nil;
        end;
      end
      else
        LLib := nil;
    end;

    if Assigned(LLib) then
    begin
      if not LLib.IsInitialized then
      begin
        if not LLib.Initialize then
        begin
          if Assigned(FLibraries[ALibType]) and not FLibraries[ALibType].IsInitialized then
            FLibraries[ALibType] := nil;
          Exit(False);
        end;
      end;

      if not Assigned(FLibraries[ALibType]) then
        FLibraries[ALibType] := LLib;

      Result := LLib.IsInitialized;
    end;
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class function TSSLFactory.GetAvailableLibraries: TSSLLibraryTypes;
var
  LType: TSSLLibraryType;
begin
  Result := [];
  CheckInitialized;
  
  for LType := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if (LType <> sslAutoDetect) and IsLibraryAvailable(LType) then
      Include(Result, LType);
  end;
end;

class function TSSLFactory.GetLibraryDescription(ALibType: TSSLLibraryType): string;
var
  LReg: TSSLLibraryRegistration;
begin
  Result := '';
  CheckInitialized;

  EnterCriticalSection(GFactoryLock);
  try
    // P0: 使用 Map 接口
    if FRegistrationMap.TryGet(Ord(ALibType), LReg) then
    begin
      Result := LReg.Description;
      if Result = '' then
        Result := SSL_LIBRARY_NAMES[ALibType];
    end;
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class function TSSLFactory.DetectBestLibrary: TSSLLibraryType;
var
  LIndex: Integer;
  LBestPriority: Integer;
  LBestType: TSSLLibraryType;
  LCandidates: specialize TArray<TSSLLibraryRegistration>;
begin
  CheckInitialized;

  LBestType := sslAutoDetect;
  LBestPriority := -1;

  // P0: 使用 Map 接口获取所有注册项
  EnterCriticalSection(GFactoryLock);
  try
    LCandidates := FRegistrationMap.Values;
  finally
    LeaveCriticalSection(GFactoryLock);
  end;

  // 现在在锁外检查可用性
  for LIndex := 0 to High(LCandidates) do
  begin
    if (LCandidates[LIndex].Priority > LBestPriority) and
      IsLibraryAvailable(LCandidates[LIndex].LibraryType) then
    begin
      LBestPriority := LCandidates[LIndex].Priority;
      LBestType := LCandidates[LIndex].LibraryType;
    end;
  end;

  // 如果没有找到可用库，按平台默认选择
  if LBestType = sslAutoDetect then
  begin
    {$IFDEF WINDOWS}
    // Windows平台优先使用系统自带的WinSSL
    if IsLibraryAvailable(sslWinSSL) then
      LBestType := sslWinSSL
    else if IsLibraryAvailable(sslOpenSSL) then
      LBestType := sslOpenSSL;
    {$ELSE}
    // 其他平台优先使用OpenSSL
    if IsLibraryAvailable(sslOpenSSL) then
      LBestType := sslOpenSSL
    else if IsLibraryAvailable(sslMbedTLS) then
      LBestType := sslMbedTLS;
    {$ENDIF}
  end;

  Result := LBestType;
end;

class procedure TSSLFactory.SetDefaultLibrary(ALibType: TSSLLibraryType);
begin
  CheckInitialized;
  
  if (ALibType <> sslAutoDetect) and not IsLibraryAvailable(ALibType) then
    raise ESSLConfigurationException.CreateWithContext(
      Format('SSL library %s is not available on this system', [SSL_LIBRARY_NAMES[ALibType]]),
      sslErrLibraryNotFound,
      'TSSLFactory.SetDefaultLibrary',
      0,
      ALibType
    );
  
  FDefaultLibraryType := ALibType;
end;

class function TSSLFactory.GetDefaultLibrary: TSSLLibraryType;
begin
  CheckInitialized;
  
  if FDefaultLibraryType = sslAutoDetect then
    FDefaultLibraryType := DetectBestLibrary;
    
  Result := FDefaultLibraryType;
end;

class function TSSLFactory.CreateLibraryInstance(ALibType: TSSLLibraryType): ISSLLibrary;
var
  LReg: TSSLLibraryRegistration;
  LClass: TSSLLibraryClass;
  LCreateFunc: TSSLLibraryCreateFunc;
begin
  Result := nil;

  // P0: 使用 Map 接口查找注册信息
  LClass := nil;
  LCreateFunc := nil;
  if FRegistrationMap.TryGet(Ord(ALibType), LReg) then
  begin
    LClass := LReg.LibraryClass;
    LCreateFunc := LReg.CreateFunc;
  end;

  if Assigned(LCreateFunc) then
  begin
    try
      Result := LCreateFunc();
    except
      Result := nil;
    end;
    if Assigned(Result) then
      Exit;

    Exit;
  end;

  if Assigned(LClass) then
  begin
    try
      Result := LClass.Create as ISSLLibrary;
    except
      Result := nil;
    end;
    if Assigned(Result) then
      Exit;

    Exit;
  end;

  case ALibType of
    sslWolfSSL:
    begin
      // Optional backend - requires ENABLE_WOLFSSL (nextpas.core.tls.wolfssl.lib)
      raise ESSLConfigurationException.CreateWithContext(
        'WolfSSL backend is not enabled (define ENABLE_WOLFSSL)',
        sslErrUnsupported,
        'TSSLFactory.CreateLibraryInstance'
      );
    end;

    sslMbedTLS:
    begin
      // Optional backend - requires ENABLE_MBEDTLS (nextpas.core.tls.mbedtls.lib)
      raise ESSLConfigurationException.CreateWithContext(
        'MbedTLS backend is not enabled (define ENABLE_MBEDTLS)',
        sslErrUnsupported,
        'TSSLFactory.CreateLibraryInstance'
      );
    end;
  else
    raise ESSLConfigurationException.CreateWithContext(
      Format('SSL backend %s is not registered', [SSL_LIBRARY_NAMES[ALibType]]),
      sslErrLibraryNotFound,
      'TSSLFactory.CreateLibraryInstance',
      0,
      ALibType
    );
  end;
end;

class function TSSLFactory.GetLibrary(ALibType: TSSLLibraryType): ISSLLibrary;
var
  LDefaultLib: TSSLLibraryType;
  LDetected: TSSLLibraryType;
begin
  CheckInitialized;

  if ALibType = sslAutoDetect then
  begin
    // First try to get the default library
    LDefaultLib := GetDefaultLibrary;
    
    // If default is also auto-detect, try to detect best available library
    if LDefaultLib = sslAutoDetect then
    begin
      LDetected := DetectBestLibrary;
      if LDetected = sslAutoDetect then
        raise ESSLException.Create('No SSL library available. Please register a library first.');
      ALibType := LDetected;
    end
    else
      ALibType := LDefaultLib;
  end;

  EnterCriticalSection(GFactoryLock);
  try
    if Assigned(FLibraries[ALibType]) then
      Result := FLibraries[ALibType]
    else
      Result := CreateLibraryInstance(ALibType);

    if Assigned(Result) then
    begin
      if not Result.IsInitialized then
      begin
        if not Result.Initialize then
        begin
          if Assigned(FLibraries[ALibType]) and not FLibraries[ALibType].IsInitialized then
            FLibraries[ALibType] := nil;
          raise ESSLInitializationException.CreateFmt(
            'Failed to initialize %s library (LastError=%d, Details=%s)',
            [SSL_LIBRARY_NAMES[ALibType], Result.GetLastError, Result.GetLastErrorString]);
        end;
      end;

      if not Assigned(FLibraries[ALibType]) then
        FLibraries[ALibType] := Result;
    end;
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class function TSSLFactory.CreateContext(AContextType: TSSLContextType;
  ALibType: TSSLLibraryType): ISSLContext;
var
  LLib: ISSLLibrary;
  LConfig: TSSLConfig;
  LVerifyMode: TSSLVerifyModes;
begin
  LLib := GetLibrary(ALibType);
  LConfig := LLib.GetDefaultConfig;
  LConfig.ContextType := AContextType;
  NormalizeConfigOptions(LConfig);
  ValidateConnectionCreationScope(LConfig, AContextType,
    'TSSLFactory.CreateContext(AContextType, ALibType)');
  LVerifyMode := ResolveContextVerifyModeForCreation(LConfig, AContextType);

  Result := LLib.CreateContext(AContextType);
  if Result <> nil then
  begin
    if LConfig.Options <> [] then
      Result.SetOptions(LConfig.Options);

    if LConfig.ProtocolVersions <> [] then
      Result.SetProtocolVersions(LConfig.ProtocolVersions);

    if LConfig.PreferredVersion <> sslProtocolUnknown then
      Result.SetPreferredVersion(LConfig.PreferredVersion);

    Result.SetVerifyMode(LVerifyMode);

    if LConfig.VerifyDepth > 0 then
      Result.SetVerifyDepth(LConfig.VerifyDepth);

    if LConfig.CipherList <> '' then
      Result.SetCipherList(LConfig.CipherList);

    if LConfig.CipherSuites <> '' then
      Result.SetCipherSuites(LConfig.CipherSuites);

    Result.SetSessionCacheSize(LConfig.SessionCacheSize);
    Result.SetSessionTimeout(LConfig.SessionTimeout);
    Result.SetSessionCacheMode(ssoEnableSessionCache in LConfig.Options);

    ApplySystemRootsIfRequested(Result, LConfig.UseSystemRoots, LLib);

    if LConfig.ServerName <> '' then
      LogContextLevelServerNameCompatibilityWarning(
        'TSSLFactory.CreateContext(AContextType, ALibType)'
      );

    if LConfig.ALPNProtocols <> '' then
      Result.SetALPNProtocols(LConfig.ALPNProtocols);

    ApplyEarlyDataContextConfig(Result, LConfig);
    ApplyEarlyDataReplayStoreConfig(Result, LConfig,
      'TSSLFactory.CreateContext(AContextType, ALibType)');
  end;
end;

class function TSSLFactory.CreateContext(const AConfig: TSSLConfig): ISSLContext;
var
  LLib: ISSLLibrary;
  LConfig: TSSLConfig;
  LVerifyMode: TSSLVerifyModes;
begin
  LConfig := AConfig;
  NormalizeConfigOptions(LConfig);
  ValidateRequestLoggingScope(LConfig);
  ValidateConnectionCreationScope(LConfig, LConfig.ContextType,
    'TSSLFactory.CreateContext(const AConfig)');
  LVerifyMode := ResolveContextVerifyModeForCreation(LConfig, LConfig.ContextType);

  LLib := GetLibrary(LConfig.LibraryType);
  Result := LLib.CreateContext(LConfig.ContextType);
  if Result = nil then
    Exit;

  Result.SetOptions(LConfig.Options);
  Result.SetSessionCacheSize(LConfig.SessionCacheSize);
  Result.SetSessionTimeout(LConfig.SessionTimeout);
  Result.SetSessionCacheMode(ssoEnableSessionCache in LConfig.Options);
  
  // 应用配置
  if LConfig.ProtocolVersions <> [] then
    Result.SetProtocolVersions(LConfig.ProtocolVersions);

  if LConfig.PreferredVersion <> sslProtocolUnknown then
    Result.SetPreferredVersion(LConfig.PreferredVersion);
    
  if LConfig.CertificateFile <> '' then
    Result.LoadCertificate(LConfig.CertificateFile);
    
  if LConfig.PrivateKeyFile <> '' then
    Result.LoadPrivateKey(LConfig.PrivateKeyFile, LConfig.PrivateKeyPassword);

  ApplySystemRootsIfRequested(Result, LConfig.UseSystemRoots, LLib);

  if LConfig.CAFile <> '' then
    Result.LoadCAFile(LConfig.CAFile);

  if LConfig.CAPath <> '' then
    Result.LoadCAPath(LConfig.CAPath);

  Result.SetVerifyMode(LVerifyMode);

  if LConfig.VerifyDepth > 0 then
    Result.SetVerifyDepth(LConfig.VerifyDepth);
    
  if LConfig.CipherList <> '' then
    Result.SetCipherList(LConfig.CipherList);

  if LConfig.CipherSuites <> '' then
    Result.SetCipherSuites(LConfig.CipherSuites);
    
  if LConfig.ServerName <> '' then
    LogContextLevelServerNameCompatibilityWarning(
      'TSSLFactory.CreateContext(const AConfig)'
    );
    
  if LConfig.ALPNProtocols <> '' then
    Result.SetALPNProtocols(LConfig.ALPNProtocols);

  ApplyEarlyDataContextConfig(Result, LConfig);
  ApplyEarlyDataReplayStoreConfig(Result, LConfig,
    'TSSLFactory.CreateContext(const AConfig)');
end;

class function TSSLFactory.CreateContext(const AConfig: TSSLContextConfig): ISSLContext;
var
  LLib: ISSLLibrary;
  LConfig: TSSLContextConfig;
begin
  LConfig := AConfig;
  NormalizeContextConfigOptions(LConfig);
  ValidateReplayStoreContextScope(
    LConfig.ContextType,
    LConfig.ServerEarlyDataReplayStoreFile,
    LConfig.ServerEarlyDataReplayStoreDirectory,
    LConfig.LibraryType,
    'TSSLFactory.CreateContext(const AConfig: TSSLContextConfig)'
  );

  LLib := GetLibrary(LConfig.LibraryType);
  Result := LLib.CreateContext(LConfig.ContextType);
  ApplyContextConfigToContext(
    Result,
    LConfig,
    LLib,
    'TSSLFactory.CreateContext(const AConfig: TSSLContextConfig)'
  );
end;

class function TSSLFactory.CreateCertificate(ALibType: TSSLLibraryType): ISSLCertificate;
var
  LLib: ISSLLibrary;
begin
  LLib := GetLibrary(ALibType);
  Result := LLib.CreateCertificate;
end;

class function TSSLFactory.CreateCertificateStore(ALibType: TSSLLibraryType): ISSLCertificateStore;
var
  LLib: ISSLLibrary;
begin
  LLib := GetLibrary(ALibType);
  Result := LLib.CreateCertificateStore;
end;


class function TSSLFactory.CreateServerContext(const ACertFile, AKeyFile: string;
  ALibType: TSSLLibraryType): ISSLContext;
begin
  Result := CreateContext(sslCtxServer, ALibType);
  Result.LoadCertificate(ACertFile);
  Result.LoadPrivateKey(AKeyFile);
end;

class function TSSLFactory.GetLibraryInstance(ALibType: TSSLLibraryType): ISSLLibrary;
begin
  Result := GetLibrary(ALibType);
end;

class procedure TSSLFactory.ReleaseLibrary(ALibType: TSSLLibraryType);
begin
  CheckInitialized;
  EnterCriticalSection(GFactoryLock);
  try
    if Assigned(FLibraries[ALibType]) then
    begin
      FLibraries[ALibType].Finalize;
      FLibraries[ALibType] := nil;
    end;
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class procedure TSSLFactory.ReleaseAllLibraries;
var
  LType: TSSLLibraryType;
begin
  CheckInitialized;
  EnterCriticalSection(GFactoryLock);
  try
    for LType := Low(TSSLLibraryType) to High(TSSLLibraryType) do
    begin
      if Assigned(FLibraries[LType]) then
      begin
        FLibraries[LType].Finalize;
        FLibraries[LType] := nil;
      end;
    end;
  finally
    LeaveCriticalSection(GFactoryLock);
  end;
end;

class procedure TSSLFactory.SetAutoInitialize(AValue: Boolean);
begin
  CheckInitialized;
  FAutoInitialize := AValue;
end;

class function TSSLFactory.GetAutoInitialize: Boolean;
begin
  CheckInitialized;
  Result := FAutoInitialize;
end;

class function TSSLFactory.GetVersionInfo: string;
var
  LType: TSSLLibraryType;
  LLib: ISSLLibrary;
begin
  Result := 'fafafa.ssl v' + FAFAFA_SSL_VERSION_STRING + LineEnding;
  Result := Result + '可用的SSL库:' + LineEnding;
  
  for LType := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if (LType <> sslAutoDetect) and IsLibraryAvailable(LType) then
    begin
      try
        LLib := GetLibrary(LType);
        Result := Result + Format('  - %s: %s' + LineEnding,
          [SSL_LIBRARY_NAMES[LType], LLib.GetVersionString]);
      except
        on E: Exception do
          TSecurityLog.Debug('Factory', Format('GetLibrary failed for %s: %s', [SSL_LIBRARY_NAMES[LType], E.Message]));
      end;
    end;
  end;
end;

class function TSSLFactory.GetSystemInfo: string;
begin
  Result := 'SSL/TLS System Information' + LineEnding;
  {$IFDEF WINDOWS}
  Result := Result + 'Platform: Windows' + LineEnding;
  Result := Result + Format('OS Version: %d.%d Build %d' + LineEnding,
    [Win32MajorVersion, Win32MinorVersion, Win32BuildNumber]);
  {$ENDIF}
  {$IFDEF LINUX}
  Result := Result + 'Platform: Linux' + LineEnding;
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := Result + 'Platform: macOS' + LineEnding;
  {$ENDIF}
  
  Result := Result + Format('Default Library: %s' + LineEnding,
    [SSL_LIBRARY_NAMES[GetDefaultLibrary]]);
end;

{ TSSLHelper }

class function TSSLHelper.VerifyCertificateFile(const AFileName: string): Boolean;
var
  LCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
begin
  try
    LCert := TSSLFactory.CreateCertificate;
    LCert.LoadFromFile(AFileName);
    
    LStore := TSSLFactory.CreateCertificateStore;
    LStore.LoadSystemStore;
    
    Result := LCert.Verify(LStore);
  except
    Result := False;
  end;
end;

class function TSSLHelper.GetCertificateInfo(const AFileName: string): TSSLCertificateInfo;
var
  LCert: ISSLCertificate;
begin
  LCert := TSSLFactory.CreateCertificate;
  LCert.LoadFromFile(AFileName);
  Result := LCert.GetInfo;
end;


class function TSSLHelper.GenerateRandomBytes(ACount: Integer): TBytes;
begin
  // Phase 3.3 P0: 修复安全漏洞 - 使用加密安全的随机数生成器
  // 原实现使用 Random(256) 是不安全的，不适合加密场景
  // 现使用平台安全随机数源（不依赖特定 SSL 后端）

  if ACount <= 0 then
    raise ESSLInvalidArgument.CreateFmt('Invalid random bytes count: %d', [ACount]);

  try
    Result := GenerateSecureRandomBytes(ACount);
  except
    on E: Exception do
      raise ESSLCryptoError.CreateWithContext(
        Format('Failed to generate cryptographically secure random bytes: %s', [E.Message]),
        sslErrOther,
        'TSSLHelper.GenerateRandomBytes',
        0,
        sslAutoDetect
      );
  end;
end;

class function TSSLHelper.HashData(const AData: TBytes;
  AHashType: TSSLHash): string;
var
  LHashBytes: TBytes;
  LCryptoLib: THandle;
  LDataPtr: PByte;

  function HashTypeName(AType: TSSLHash): string;
  begin
    case AType of
      sslHashMD5: Result := 'MD5';
      sslHashSHA1: Result := 'SHA1';
      sslHashSHA224: Result := 'SHA224';
      sslHashSHA256: Result := 'SHA256';
      sslHashSHA384: Result := 'SHA384';
      sslHashSHA512: Result := 'SHA512';
      sslHashSHA3_256: Result := 'SHA3-256';
      sslHashSHA3_512: Result := 'SHA3-512';
      sslHashBLAKE2b: Result := 'BLAKE2b';
    end;
  end;

  procedure EnsureOpenSSLLoaded;
  begin
    LCryptoLib := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
    if LCryptoLib = 0 then
      raise ESSLInvalidArgument.Create(
        'Requested hash algorithm requires OpenSSL libcrypto, but it is unavailable'
      );
  end;

  procedure EnsureEVPModule;
  begin
    EnsureOpenSSLLoaded;
    if not TOpenSSLLoader.IsModuleLoaded(osmEVP) then
      LoadEVP(LCryptoLib);
  end;
begin
  // Pure Pascal fast-paths
  case AHashType of
    sslHashMD5:    LHashBytes := nextpas.core.crypto.hash.MD5(AData);
    sslHashSHA1:   LHashBytes := nextpas.core.crypto.hash.SHA1(AData);
    sslHashSHA256: LHashBytes := nextpas.core.crypto.hash.SHA256(AData);
    sslHashSHA384: LHashBytes := nextpas.core.crypto.hash.SHA384(AData);
    sslHashSHA512: LHashBytes := nextpas.core.crypto.hash.SHA512(AData);

    sslHashSHA224:
    begin
      EnsureOpenSSLLoaded;
      if not TOpenSSLLoader.IsModuleLoaded(osmSHA) then
        LoadSHAFunctions(LCryptoLib);

      if not Assigned(SHA224) then
        raise ESSLInvalidArgument.CreateFmt(
          '%s is not available in loaded OpenSSL build',
          [HashTypeName(AHashType)]
        );

      SetLength(LHashBytes, SHA224_DIGEST_LENGTH);
      if Length(AData) > 0 then
        LDataPtr := @AData[0]
      else
        LDataPtr := nil;

      if SHA224(LDataPtr, Length(AData), @LHashBytes[0]) = nil then
        raise ESSLInvalidArgument.Create('SHA224 hashing failed');
    end;

    sslHashSHA3_256:
    begin
      EnsureEVPModule;
      if not IsEVPSHA3Available then
        raise ESSLInvalidArgument.CreateFmt(
          '%s is not available in loaded OpenSSL build',
          [HashTypeName(AHashType)]
        );
      LHashBytes := SHA3_256Hash_EVP(AData);
    end;

    sslHashSHA3_512:
    begin
      EnsureEVPModule;
      if not IsEVPSHA3Available then
        raise ESSLInvalidArgument.CreateFmt(
          '%s is not available in loaded OpenSSL build',
          [HashTypeName(AHashType)]
        );
      LHashBytes := SHA3_512Hash_EVP(AData);
    end;

    sslHashBLAKE2b:
    begin
      EnsureOpenSSLLoaded;
      if not TOpenSSLLoader.IsModuleLoaded(osmBLAKE2) then
        LoadBLAKE2Functions(LCryptoLib);

      if not (Assigned(BLAKE2b_Init) or Assigned(BLAKE2b)) then
        raise ESSLInvalidArgument.CreateFmt(
          '%s is not available in loaded OpenSSL build',
          [HashTypeName(AHashType)]
        );

      LHashBytes := BLAKE2b512Hash(AData);
    end;
  end;

  Result := nextpas.core.crypto.hash.HashToHex(LHashBytes);
end;

class function TSSLHelper.SupportsEarlyDataContext(
  const AContext: ISSLContext): Boolean;
var
  LEarlyDataContext: ISSLEarlyDataContext;
begin
  Result := Supports(AContext, ISSLEarlyDataContext, LEarlyDataContext);
end;

class function TSSLHelper.SupportsEarlyDataConnection(
  const AConnection: ISSLConnection): Boolean;
var
  LEarlyDataConnection: ISSLEarlyDataConnection;
begin
  Result := Supports(AConnection, ISSLEarlyDataConnection, LEarlyDataConnection);
end;

class function TSSLHelper.TryGetEarlyDataContext(const AContext: ISSLContext;
  out AEarlyDataContext: ISSLEarlyDataContext): Boolean;
begin
  Result := Supports(AContext, ISSLEarlyDataContext, AEarlyDataContext);
end;

class function TSSLHelper.TryGetEarlyDataConnection(
  const AConnection: ISSLConnection;
  out AEarlyDataConnection: ISSLEarlyDataConnection): Boolean;
begin
  Result := Supports(AConnection, ISSLEarlyDataConnection, AEarlyDataConnection);
end;

class function TSSLHelper.ConfigureClientEarlyData(const AContext: ISSLContext;
  AEnabled: Boolean): Boolean;
var
  LEarlyDataContext: ISSLEarlyDataContext;
  LScopeMatches: Boolean;
begin
  Result := TryGetEarlyDataContext(AContext, LEarlyDataContext);
  LScopeMatches := Result and Assigned(AContext) and
    ContextTypeSupportsClientEarlyData(AContext.GetContextType);
  if LScopeMatches then
    LEarlyDataContext.SetClientEarlyDataEnabled(AEnabled);
  Result := LScopeMatches;
end;

class function TSSLHelper.ConfigureServerEarlyData(const AContext: ISSLContext;
  APolicy: TSSLEarlyDataServerPolicy; AMaxSize: Cardinal): Boolean;
var
  LEarlyDataContext: ISSLEarlyDataContext;
  LScopeMatches: Boolean;
begin
  Result := TryGetEarlyDataContext(AContext, LEarlyDataContext);
  LScopeMatches := Result and Assigned(AContext) and
    ContextTypeSupportsServerEarlyData(AContext.GetContextType);
  if LScopeMatches then
  begin
    LEarlyDataContext.SetServerMaxEarlyDataSize(AMaxSize);
    LEarlyDataContext.SetServerEarlyDataPolicy(APolicy);
  end;
  Result := LScopeMatches;
end;

class function TSSLHelper.GetEarlyDataStatus(
  const AConnection: ISSLConnection): TSSLEarlyDataStatus;
var
  LEarlyDataConnection: ISSLEarlyDataConnection;
begin
  if TryGetEarlyDataConnection(AConnection, LEarlyDataConnection) then
    Result := LEarlyDataConnection.GetEarlyDataStatus
  else
    Result := sslEarlyDataNone;
end;

class function TSSLHelper.GetEarlyDataLimit(
  const AConnection: ISSLConnection): Cardinal;
var
  LEarlyDataConnection: ISSLEarlyDataConnection;
begin
  if TryGetEarlyDataConnection(AConnection, LEarlyDataConnection) then
    Result := LEarlyDataConnection.GetEarlyDataLimit
  else
    Result := 0;
end;

initialization
  // GFactoryLock 在 TSSLFactory.Initialize 中初始化
  TSSLFactory.Initialize;

finalization
  TSSLFactory.Finalize;

end.

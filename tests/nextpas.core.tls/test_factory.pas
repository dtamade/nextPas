program test_factory;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.exceptions,
  fafafa.ssl;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;

type
  TFailingSSLLibrary = class(TInterfacedObject, ISSLLibrary)
  protected
    FLastError: Integer;
    FLastErrorString: string;
  public
    function Initialize: Boolean; virtual;
    procedure Finalize;
    function IsInitialized: Boolean; virtual;

    function GetLibraryType: TSSLLibraryType; virtual;
    function GetVersionString: string; virtual;
    function GetVersionNumber: Cardinal;
    function GetCompileFlags: string;

    function IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean;
    function IsCipherSupported(const aCipherName: string): Boolean;
    function IsFeatureSupported(aFeature: TSSLFeature): Boolean;
    function GetCapabilities: TSSLBackendCapabilities;

    procedure SetDefaultConfig(const aConfig: TSSLConfig);
    function GetDefaultConfig: TSSLConfig;

    function GetLastError: Integer;
    function GetLastErrorString: string;
    procedure ClearError;

    function GetStatistics: TSSLStatistics;
    procedure ResetStatistics;

    procedure SetLogCallback(aCallback: TSSLLogCallback);
    procedure Log(aLevel: TSSLLogLevel; const aMessage: string);

    function CreateContext(aType: TSSLContextType): ISSLContext;
    function CreateCertificate: ISSLCertificate;
    function CreateCertificateStore: ISSLCertificateStore;
  end;

  TAvailableWolfSSLLibraryV1 = class(TFailingSSLLibrary)
  public
    function Initialize: Boolean; override;
    function IsInitialized: Boolean; override;
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
  end;

  TAvailableWolfSSLLibraryV2 = class(TAvailableWolfSSLLibraryV1)
  public
    function GetVersionString: string; override;
  end;

  TAvailableMbedTLSSSLLibrary = class(TFailingSSLLibrary)
  public
    function Initialize: Boolean; override;
    function IsInitialized: Boolean; override;
    function GetLibraryType: TSSLLibraryType; override;
    function GetVersionString: string; override;
  end;

procedure Pass(const TestName: string);
begin
  WriteLn('  [PASS] ', TestName);
  Inc(TestsPassed);
end;

procedure Fail(const TestName, Reason: string);
begin
  WriteLn('  [FAIL] ', TestName, ' - ', Reason);
  Inc(TestsFailed);
end;

function TFailingSSLLibrary.Initialize: Boolean;
begin
  FLastError := 123;
  FLastErrorString := 'synthetic init failure';
  Result := False;
end;

procedure TFailingSSLLibrary.Finalize;
begin
end;

function TFailingSSLLibrary.IsInitialized: Boolean;
begin
  Result := False;
end;

function TFailingSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TFailingSSLLibrary.GetVersionString: string;
begin
  Result := 'FailingSSLLibrary';
end;

function TAvailableWolfSSLLibraryV1.Initialize: Boolean;
begin
  FLastError := 0;
  FLastErrorString := '';
  Result := True;
end;

function TAvailableWolfSSLLibraryV1.IsInitialized: Boolean;
begin
  Result := True;
end;

function TAvailableWolfSSLLibraryV1.GetLibraryType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TAvailableWolfSSLLibraryV1.GetVersionString: string;
begin
  Result := 'TestWolfSSL-V1';
end;

function TAvailableWolfSSLLibraryV2.GetVersionString: string;
begin
  Result := 'TestWolfSSL-V2';
end;

function TAvailableMbedTLSSSLLibrary.Initialize: Boolean;
begin
  FLastError := 0;
  FLastErrorString := '';
  Result := True;
end;

function TAvailableMbedTLSSSLLibrary.IsInitialized: Boolean;
begin
  Result := True;
end;

function TAvailableMbedTLSSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TAvailableMbedTLSSSLLibrary.GetVersionString: string;
begin
  Result := 'TestMbedTLS';
end;

function TFailingSSLLibrary.GetVersionNumber: Cardinal;
begin
  Result := 0;
end;

function TFailingSSLLibrary.GetCompileFlags: string;
begin
  Result := '';
end;

function TFailingSSLLibrary.IsProtocolSupported(aProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := False;
end;

function TFailingSSLLibrary.IsCipherSupported(const aCipherName: string): Boolean;
begin
  Result := False;
end;

function TFailingSSLLibrary.IsFeatureSupported(aFeature: TSSLFeature): Boolean;
begin
  Result := False;
end;

function TFailingSSLLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MinTLSVersion := sslProtocolTLS10;
  Result.MaxTLSVersion := sslProtocolTLS12;
end;

procedure TFailingSSLLibrary.SetDefaultConfig(const aConfig: TSSLConfig);
begin
end;

function TFailingSSLLibrary.GetDefaultConfig: TSSLConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.LibraryType := sslOpenSSL;
  Result.ContextType := sslCtxClient;
end;

function TFailingSSLLibrary.GetLastError: Integer;
begin
  Result := FLastError;
end;

function TFailingSSLLibrary.GetLastErrorString: string;
begin
  Result := FLastErrorString;
end;

procedure TFailingSSLLibrary.ClearError;
begin
  FLastError := 0;
  FLastErrorString := '';
end;

function TFailingSSLLibrary.GetStatistics: TSSLStatistics;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

procedure TFailingSSLLibrary.ResetStatistics;
begin
end;

procedure TFailingSSLLibrary.SetLogCallback(aCallback: TSSLLogCallback);
begin
end;

procedure TFailingSSLLibrary.Log(aLevel: TSSLLogLevel; const aMessage: string);
begin
end;

function TFailingSSLLibrary.CreateContext(aType: TSSLContextType): ISSLContext;
begin
  Result := nil;
end;

function TFailingSSLLibrary.CreateCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TFailingSSLLibrary.CreateCertificateStore: ISSLCertificateStore;
begin
  Result := nil;
end;

procedure TestAutoDetection;
var
  LibType: TSSLLibraryType;
begin
  WriteLn('测试 1: 自动检测最佳库');
  try
    LibType := TSSLFactory.DetectBestLibrary;

    if LibType = sslAutoDetect then
      Fail('DetectBestLibrary', '未能检测到任何可用库')
    else
    begin
      WriteLn('    检测到库: ', SSL_LIBRARY_NAMES[LibType]);
      Pass('DetectBestLibrary');
    end;
  except
    on E: Exception do
      Fail('DetectBestLibrary', E.Message);
  end;
end;

procedure TestRegistrationOverrideUsesRegisteredClass;
var
  Lib: ISSLLibrary;
  LVer: string;
begin
  WriteLn('测试 11: 注册覆盖后实例创建应使用最新注册的类');
  try
    TSSLFactory.ReleaseLibrary(sslWolfSSL);
    TSSLFactory.RegisterLibrary(sslWolfSSL, TAvailableWolfSSLLibraryV1, 'WolfSSL test v1', 10);
    Lib := TSSLFactory.GetLibrary(sslWolfSSL);
    if (Lib <> nil) and (Lib.GetVersionString = 'TestWolfSSL-V1') then
      Pass('Registration v1 used')
    else
    begin
      if Lib = nil then
        LVer := 'nil'
      else
        LVer := Lib.GetVersionString;
      Fail('Registration v1 used', 'Unexpected library/version: ' + LVer);
    end;

    TSSLFactory.ReleaseLibrary(sslWolfSSL);
    TSSLFactory.RegisterLibrary(sslWolfSSL, TAvailableWolfSSLLibraryV2, 'WolfSSL test v2', 20);
    Lib := TSSLFactory.GetLibrary(sslWolfSSL);
    if (Lib <> nil) and (Lib.GetVersionString = 'TestWolfSSL-V2') then
      Pass('Registration override used (v2)')
    else
    begin
      if Lib = nil then
        LVer := 'nil'
      else
        LVer := Lib.GetVersionString;
      Fail('Registration override used', 'Unexpected library/version: ' + LVer);
    end;
  except
    on E: Exception do
      Fail('Registration override', E.Message);
  end;
end;

procedure TestDetectBestLibraryRespectsPriority;
var
  Best: TSSLLibraryType;
begin
  WriteLn('测试 12: DetectBestLibrary 应按 Priority 选择可用库');
  try
    TSSLFactory.ReleaseLibrary(sslMbedTLS);
    TSSLFactory.ReleaseLibrary(sslWolfSSL);

    TSSLFactory.RegisterLibrary(sslMbedTLS, TAvailableMbedTLSSSLLibrary, 'MbedTLS test', 1500);
    TSSLFactory.RegisterLibrary(sslWolfSSL, TAvailableWolfSSLLibraryV2, 'WolfSSL test', 2000);

    Best := TSSLFactory.DetectBestLibrary;
    if Best = sslWolfSSL then
      Pass('DetectBestLibrary priority selection')
    else
      Fail('DetectBestLibrary priority selection', 'Expected sslWolfSSL, got ' + SSL_LIBRARY_NAMES[Best]);
  except
    on E: Exception do
      Fail('DetectBestLibrary priority selection', E.Message);
  end;
end;

procedure TestInitializationFailureErrorDetails;
var
  Lib: ISSLLibrary;
  Msg: string;
begin
  WriteLn('测试 13: 初始化失败错误信息包含后端细节');
  try
    TSSLFactory.ReleaseLibrary(sslOpenSSL);
    TSSLFactory.RegisterLibrary(sslOpenSSL, TFailingSSLLibrary, 'Failing OpenSSL (test)', 1000);

    try
      Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
      if Assigned(Lib) then
        Fail('Init failure details', '期望抛出异常但返回了实例')
      else
        Fail('Init failure details', '期望抛出异常但返回 nil');
    except
      on E: ESSLInitializationException do
      begin
        Msg := E.Message;
        if (Pos('LastError=', Msg) > 0) and (Pos('Details=', Msg) > 0) then
          Pass('Init failure includes backend LastError/Details')
        else
          Fail('Init failure includes backend details', Msg);
      end;
      on E: Exception do
        Fail('Init failure details', E.ClassName + ': ' + E.Message);
    end;
  except
    on E: Exception do
      Fail('Init failure test setup', E.Message);
  end;
end;

procedure TestLibraryCreation;
var
  Lib: ISSLLibrary;
begin
  WriteLn('测试 2: 创建库实例（自动检测）');
  try
    Lib := TSSLFactory.GetLibraryInstance;
    if Assigned(Lib) then
    begin
      if Lib.IsInitialized then
        Pass('TSSLFactory.GetLibraryInstance with auto-detect')
      else
        Fail('GetLibraryInstance', '库未初始化');
    end
    else
      Fail('GetLibraryInstance', '返回 nil');
  except
    on E: Exception do
      Fail('GetLibraryInstance', E.Message);
  end;
end;

procedure TestWinSSLLibrary;
var
  Lib: ISSLLibrary;
begin
  {$IFDEF WINDOWS}
  WriteLn('测试 3: 创建 WinSSL 库');
  try
    Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);
    if Assigned(Lib) then
    begin
      WriteLn('    版本: ', Lib.GetVersionString);
      WriteLn('    类型: ', SSL_LIBRARY_NAMES[Lib.GetLibraryType]);

      if Lib.GetLibraryType = sslWinSSL then
        Pass('WinSSL library creation and type')
      else
        Fail('WinSSL library', '库类型不匹配');
    end
    else
      Fail('WinSSL library', '返回 nil');
  except
    on E: Exception do
      Fail('WinSSL library', E.Message);
  end;
  {$ELSE}
  WriteLn('测试 3: 跳过（非 Windows 平台）');
  {$ENDIF}
end;

procedure TestOpenSSLLibrary;
var
  Lib: ISSLLibrary;
begin
  WriteLn('测试 4: 创建 OpenSSL 库');
  try
    Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if Assigned(Lib) then
    begin
      WriteLn('    版本: ', Lib.GetVersionString);
      WriteLn('    类型: ', SSL_LIBRARY_NAMES[Lib.GetLibraryType]);

      if Lib.GetLibraryType = sslOpenSSL then
        Pass('OpenSSL library creation and type')
      else
        Fail('OpenSSL library', '库类型不匹配');
    end
    else
      Fail('OpenSSL library', '返回 nil');
  except
    on E: Exception do
      Fail('OpenSSL library', E.Message);
  end;
end;

procedure TestContextCreation;
var
  Ctx: ISSLContext;
  Opts: TSSLOptions;
begin
  WriteLn('测试 5: 创建 SSL 上下文');
  try
    Ctx := TSSLFactory.CreateContext(sslCtxClient);
    if Assigned(Ctx) then
    begin
      Pass('TSSLFactory.CreateContext with client type');

      Opts := Ctx.GetOptions;
      if (ssoDisableCompression in Opts) and (ssoDisableRenegotiation in Opts) then
        Pass('Default options security baseline')
      else
        Fail('Default options security baseline', 'Options missing required security flags');
    end
    else
      Fail('TSSLFactory.CreateContext', '上下文未创建');
  except
    on E: Exception do
      Fail('TSSLFactory.CreateContext', E.Message);
  end;
end;

procedure TestLibraryRegistration;
var
  Available: TSSLLibraryTypes;
  LibType: TSSLLibraryType;
begin
  WriteLn('测试 6: 库注册检查');
  try
    Available := TSSLFactory.GetAvailableLibraries;

    if Available = [] then
      Fail('Library registration', '没有可用库')
    else
    begin
      WriteLn('    可用库:');
      for LibType := Low(TSSLLibraryType) to High(TSSLLibraryType) do
      begin
        if LibType in Available then
          WriteLn('      - ', SSL_LIBRARY_NAMES[LibType]);
      end;
      Pass('Library registration check');
    end;
  except
    on E: Exception do
      Fail('Library registration', E.Message);
  end;
end;

procedure TestGetVersionInfo;
var
  VersionInfo: string;
begin
  WriteLn('测试 7: 获取版本信息');
  try
    VersionInfo := TSSLFactory.GetVersionInfo;
    if Length(VersionInfo) > 0 then
    begin
      WriteLn('    版本信息:');
      WriteLn(VersionInfo);
      Pass('GetVersionInfo');
    end
    else
      Fail('GetVersionInfo', '返回空字符串');
  except
    on E: Exception do
      Fail('GetVersionInfo', E.Message);
  end;
end;

procedure TestProtocolSupport;
var
  Lib: ISSLLibrary;
begin
  WriteLn('测试 8: 协议支持检查');
  try
    Lib := TSSLFactory.GetLibraryInstance;
    if Assigned(Lib) then
    begin
      WriteLn('    TLS 1.2: ', Lib.IsProtocolSupported(sslProtocolTLS12));
      WriteLn('    TLS 1.3: ', Lib.IsProtocolSupported(sslProtocolTLS13));
      Pass('Protocol support check');
    end
    else
      Fail('Protocol support', '库未创建');
  except
    on E: Exception do
      Fail('Protocol support', E.Message);
  end;
end;

procedure TestFeatureSupport;
var
  Lib: ISSLLibrary;
begin
  WriteLn('测试 9: 功能支持检查');
  try
    Lib := TSSLFactory.GetLibraryInstance;
    if Assigned(Lib) then
    begin
      WriteLn('    SNI: ', Lib.IsFeatureSupported(sslFeatSNI));
      WriteLn('    ALPN: ', Lib.IsFeatureSupported(sslFeatALPN));
      WriteLn('    Session Cache: ', Lib.IsFeatureSupported(sslFeatSessionCache));
      Pass('Feature support check');
    end
    else
      Fail('Feature support', '库未创建');
  except
    on E: Exception do
      Fail('Feature support', E.Message);
  end;
end;

procedure TestSystemInfo;
var
  SystemInfo: string;
begin
  WriteLn('测试 10: 获取系统信息');
  try
    SystemInfo := TSSLFactory.GetSystemInfo;
    if Length(SystemInfo) > 0 then
    begin
      WriteLn('    系统信息:');
      WriteLn(SystemInfo);
      Pass('GetSystemInfo');
    end
    else
      Fail('GetSystemInfo', '返回空字符串');
  except
    on E: Exception do
      Fail('GetSystemInfo', E.Message);
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('  fafafa.ssl Factory 单元测试');
  WriteLn('========================================');
  WriteLn('');

  TestAutoDetection;
  TestLibraryCreation;
  TestWinSSLLibrary;
  TestOpenSSLLibrary;
  TestContextCreation;
  TestLibraryRegistration;
  TestGetVersionInfo;
  TestProtocolSupport;
  TestFeatureSupport;
  TestSystemInfo;
  TestRegistrationOverrideUsesRegisteredClass;
  TestDetectBestLibraryRespectsPriority;
  TestInitializationFailureErrorDetails;

  WriteLn('');
  WriteLn('========================================');
  WriteLn('  测试结果汇总');
  WriteLn('========================================');
  WriteLn('通过: ', TestsPassed);
  WriteLn('失败: ', TestsFailed);
  WriteLn('总计: ', TestsPassed + TestsFailed);

  if TestsFailed = 0 then
  begin
    WriteLn('');
    WriteLn('所有测试通过！✓');
    ExitCode := 0;
  end
  else
  begin
    WriteLn('');
    WriteLn('有测试失败！✗');
    ExitCode := 1;
  end;
end.

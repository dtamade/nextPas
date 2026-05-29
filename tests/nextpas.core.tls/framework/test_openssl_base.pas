unit test_openssl_base;

{******************************************************************************}
{                                                                              }
{  OpenSSL 测试基类 - 统一的 OpenSSL 测试框架                                  }
{                                                                              }
{  目的: 消除测试文件中重复的初始化代码，提供统一的测试基础设施              }
{                                                                              }
{  功能:                                                                       }
{  - 自动管理 OpenSSL 初始化和清理                                            }
{  - 模块依赖声明和自动加载                                                   }
{  - 版本检测和条件跳过                                                       }
{  - 统一的日志和错误报告                                                     }
{                                                                              }
{  Phase: P1 - 测试框架重构                                                   }
{  Author: fafafa.ssl team                                                    }
{  Date: 2025-12-25                                                           }
{                                                                              }
{******************************************************************************}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  nextpas.core.tls.openssl.loader;

type
  {**
   * 测试结果统计
   *}
  TTestStats = record
    Passed: Integer;
    Failed: Integer;
    Skipped: Integer;
    SkipDependency: Integer;
    SkipVersion: Integer;
    SkipEnvironment: Integer;
    SkipCapability: Integer;
    SkipOther: Integer;
  end;

  TOpenSSLSkipCategory = (
    tscDependency,
    tscVersion,
    tscEnvironment,
    tscCapability,
    tscOther
  );

  {**
   * 测试日志级别
   *}
  TTestLogLevel = (
    tllQuiet,    // 只显示失败
    tllNormal,   // 显示通过/失败
    tllVerbose   // 显示详细信息
  );

  {**
   * OpenSSL 测试基类
   *
   * 所有 OpenSSL 相关测试应继承此类。
   * 提供统一的初始化、依赖管理和日志功能。
   *
   * 使用示例:
   * <code>
   *   type
   *     TMyRSATest = class(TOpenSSLTestBase)
   *     protected
   *       procedure SetUp; override;
   *     published
   *       procedure Test_RSA_KeyGen;
   *     end;
   *
   *   procedure TMyRSATest.SetUp;
   *   begin
   *     inherited;
   *     RequireModules([osmCore, osmRSA, osmBN]);
   *   end;
   * </code>
   *}
  TOpenSSLTestBase = class
  private
    class var
      FOpenSSLInitialized: Boolean;
      FLogLevel: TTestLogLevel;
    var
      FRequiredModules: TOpenSSLModuleSet;
      FSkipReason: string;
      FSkipped: Boolean;
      FStats: TTestStats;
      FCurrentTestName: string;

    function ClassifySkipCategory(const AReasonLower: string): TOpenSSLSkipCategory;
    function NormalizeSkipReason(const Reason: string; out ACategory: TOpenSSLSkipCategory): string;
    procedure RecordSkipCategory(ACategory: TOpenSSLSkipCategory);
  protected
    {** 初始化 - 在测试开始前调用 *}
    procedure SetUp; virtual;

    {** 清理 - 在测试结束后调用 *}
    procedure TearDown; virtual;

    {**
     * 声明本测试需要的模块
     * @param Modules 需要的模块数组
     *}
    procedure RequireModules(const Modules: array of TOpenSSLModule);

    {**
     * 检查模块是否可用，不可用则跳过测试
     * @param AModule 要检查的模块
     * @return True=模块可用，False=不可用（测试将被跳过）
     *}
    function SkipIfMissing(AModule: TOpenSSLModule): Boolean;

    {**
     * 检查 OpenSSL 版本，版本不匹配则跳过测试
     * @param MinMajor 最低主版本号
     * @param MinMinor 最低次版本号 (可选)
     * @return True=版本满足要求，False=版本过低（测试将被跳过）
     *}
    function RequireOpenSSLVersion(MinMajor: Integer; MinMinor: Integer = 0): Boolean;

    {**
     * 标记测试为跳过
     * @param Reason 跳过原因
     *}
    procedure SkipTest(const Reason: string);

    {**
     * 记录测试结果
     * @param TestName 测试名称
     * @param Passed 是否通过
     * @param Details 详细信息 (可选)
     *}
    procedure LogTest(const TestName: string; Passed: Boolean; const Details: string = '');

    {**
     * 记录详细信息
     * @param Msg 信息内容
     *}
    procedure LogVerbose(const Msg: string);

    {**
     * 记录错误信息
     * @param Msg 错误内容
     *}
    procedure LogError(const Msg: string);

    {** 获取测试统计 *}
    property Stats: TTestStats read FStats;

    {** 当前测试是否被跳过 *}
    property Skipped: Boolean read FSkipped;

    {** 跳过原因 *}
    property SkipReason: string read FSkipReason;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    {**
     * 运行所有测试
     * @return 失败的测试数量
     *}
    function RunTests: Integer; virtual;

    {** 打印测试摘要 *}
    procedure PrintSummary;

    {** 获取 OpenSSL 版本信息 *}
    class function OpenSSLVersion: TOpenSSLVersionInfo;

    {** 检查是否为 OpenSSL 3.x *}
    class function IsOpenSSL3: Boolean;

    {** 确保 OpenSSL 已初始化 *}
    class procedure EnsureOpenSSLInitialized;

    {** 设置日志级别 *}
    class property LogLevel: TTestLogLevel read FLogLevel write FLogLevel;
  end;

  {**
   * 简单测试运行器 - 用于非 fpcunit 的测试
   *
   * 使用示例:
   * <code>
   *   var
   *     Runner: TSimpleTestRunner;
   *   begin
   *     Runner := TSimpleTestRunner.Create;
   *     try
   *       Runner.RequireModules([osmCore, osmRSA]);
   *       if not Runner.Initialize then
   *         Halt(1);
   *
   *       Runner.Test('RSA_KeyGen', @Test_RSA_KeyGen_2048);
   *       Runner.Test('RSA_Encrypt', @Test_RSA_Encrypt);
   *
   *       Runner.PrintSummary;
   *       Halt(Runner.FailCount);
   *     finally
   *       Runner.Free;
   *     end;
   *   end;
   * </code>
   *}
  TTestProc = procedure;

  TSimpleTestRunner = class(TOpenSSLTestBase)
  private
    FTestName: string;
  public
    {**
     * 声明本测试需要的模块 (覆盖为 public)
     * @param Modules 需要的模块数组
     *}
    procedure RequireModules(const Modules: array of TOpenSSLModule);

    {**
     * 初始化测试环境
     * @return True=初始化成功，False=依赖不满足
     *}
    function Initialize: Boolean;

    {**
     * 运行单个测试
     * @param Name 测试名称
     * @param Proc 测试过程
     *}
    procedure Test(const Name: string; Proc: TTestProc);

    {**
     * 检查条件并记录结果
     * @param Name 检查名称
     * @param Condition 条件
     * @param Details 详细信息 (可选)
     *}
    procedure Check(const Name: string; Condition: Boolean; const Details: string = '');

    {**
     * 跳过某个检查（不会计入失败）
     * @param Name 检查名称
     * @param Reason 跳过原因
     *}
    procedure Skip(const Name: string; const Reason: string);

    {** 通过的测试数量 *}
    property PassCount: Integer read FStats.Passed;

    {** 失败的测试数量 *}
    property FailCount: Integer read FStats.Failed;

    {** 跳过的测试数量 *}
    property SkipCount: Integer read FStats.Skipped;
  end;

{** 全局日志级别设置 *}
var
  GlobalLogLevel: TTestLogLevel = tllNormal;

implementation

uses
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.dsa,
  nextpas.core.tls.openssl.api.dh,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.ecdh,
  nextpas.core.tls.openssl.api.ecdsa,
  nextpas.core.tls.openssl.api.rand,
  nextpas.core.tls.openssl.api.kdf,
  nextpas.core.tls.openssl.api.hmac,
  nextpas.core.tls.openssl.dependencies;

function SkipCategoryToString(ACategory: TOpenSSLSkipCategory): string;
begin
  case ACategory of
    tscDependency: Result := 'dependency';
    tscVersion: Result := 'version';
    tscEnvironment: Result := 'environment';
    tscCapability: Result := 'capability';
  else
    Result := 'other';
  end;
end;


{ TOpenSSLTestBase }

constructor TOpenSSLTestBase.Create;
begin
  inherited Create;
  FRequiredModules := [];
  FSkipped := False;
  FSkipReason := '';
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TOpenSSLTestBase.Destroy;
begin
  inherited Destroy;
end;

procedure TOpenSSLTestBase.SetUp;
begin
  FSkipped := False;
  FSkipReason := '';
  EnsureOpenSSLInitialized;
end;

procedure TOpenSSLTestBase.TearDown;
begin
  // 子类可以覆盖此方法进行清理
end;

procedure TOpenSSLTestBase.RequireModules(const Modules: array of TOpenSSLModule);
var
  I: Integer;
  M: TOpenSSLModule;
begin
  // Simply add modules to the required set
  // Dependency checking and loading is done in Initialize
  for I := Low(Modules) to High(Modules) do
  begin
    M := Modules[I];
    Include(FRequiredModules, M);
  end;
end;

function TOpenSSLTestBase.ClassifySkipCategory(const AReasonLower: string): TOpenSSLSkipCategory;
begin
  if (Pos('[dependency]', AReasonLower) = 1) or
     (Pos('module', AReasonLower) > 0) or
     (Pos('missing', AReasonLower) > 0) then
    Exit(tscDependency);

  if (Pos('[version]', AReasonLower) = 1) or
     (Pos('requires openssl', AReasonLower) > 0) or
     (Pos('version', AReasonLower) > 0) then
    Exit(tscVersion);

  if (Pos('[environment]', AReasonLower) = 1) or
     (Pos('platform', AReasonLower) > 0) or
     (Pos('windows', AReasonLower) > 0) or
     (Pos('linux', AReasonLower) > 0) or
     (Pos('environment', AReasonLower) > 0) then
    Exit(tscEnvironment);

  if (Pos('[capability]', AReasonLower) = 1) or
     (Pos('not available', AReasonLower) > 0) or
     (Pos('unavailable', AReasonLower) > 0) or
     (Pos('not supported', AReasonLower) > 0) then
    Exit(tscCapability);

  Result := tscOther;
end;

function TOpenSSLTestBase.NormalizeSkipReason(const Reason: string;
  out ACategory: TOpenSSLSkipCategory): string;
var
  LTrimmed: string;
  LReasonLower: string;
  LTag: string;
begin
  LTrimmed := Trim(Reason);
  if LTrimmed = '' then
    LTrimmed := 'unspecified skip reason';

  LReasonLower := LowerCase(LTrimmed);
  ACategory := ClassifySkipCategory(LReasonLower);
  LTag := '[' + SkipCategoryToString(ACategory) + '] ';

  if Pos(LTag, LReasonLower) = 1 then
    Result := LTrimmed
  else
    Result := LTag + LTrimmed;
end;

procedure TOpenSSLTestBase.RecordSkipCategory(ACategory: TOpenSSLSkipCategory);
begin
  case ACategory of
    tscDependency: Inc(FStats.SkipDependency);
    tscVersion: Inc(FStats.SkipVersion);
    tscEnvironment: Inc(FStats.SkipEnvironment);
    tscCapability: Inc(FStats.SkipCapability);
  else
    Inc(FStats.SkipOther);
  end;
end;

function TOpenSSLTestBase.SkipIfMissing(AModule: TOpenSSLModule): Boolean;
begin
  Result := TOpenSSLLoader.IsModuleLoaded(AModule);
  if not Result then
  begin
    SkipTest(Format('Module %s not available', [GetModuleName(AModule)]));
  end;
end;

function TOpenSSLTestBase.RequireOpenSSLVersion(MinMajor: Integer; MinMinor: Integer): Boolean;
var
  Ver: TOpenSSLVersionInfo;
begin
  Ver := OpenSSLVersion;
  Result := (Ver.Major > MinMajor) or
            ((Ver.Major = MinMajor) and (Ver.Minor >= MinMinor));
  if not Result then
  begin
    SkipTest(Format('Requires OpenSSL %d.%d+, got %d.%d',
                   [MinMajor, MinMinor, Ver.Major, Ver.Minor]));
  end;
end;

procedure TOpenSSLTestBase.SkipTest(const Reason: string);
var
  LCategory: TOpenSSLSkipCategory;
begin
  FSkipped := True;
  FSkipReason := NormalizeSkipReason(Reason, LCategory);
  Inc(FStats.Skipped);
  RecordSkipCategory(LCategory);
end;

procedure TOpenSSLTestBase.LogTest(const TestName: string; Passed: Boolean; const Details: string);
begin
  FCurrentTestName := TestName;

  if FSkipped then
  begin
    WriteLn('[SKIP] ', TestName, ' - ', FSkipReason);
    Exit;
  end;

  if Passed then
  begin
    Inc(FStats.Passed);
    if FLogLevel >= tllNormal then
      WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(FStats.Failed);
    WriteLn('[FAIL] ', TestName);
  end;

  if (Details <> '') and ((not Passed) or (FLogLevel >= tllVerbose)) then
    WriteLn('       ', Details);
end;

procedure TOpenSSLTestBase.LogVerbose(const Msg: string);
begin
  if FLogLevel >= tllVerbose then
    WriteLn('  ', Msg);
end;

procedure TOpenSSLTestBase.LogError(const Msg: string);
begin
  WriteLn('  ERROR: ', Msg);
end;

function TOpenSSLTestBase.RunTests: Integer;
begin
  SetUp;
  try
    // 子类应该覆盖此方法来运行测试
  finally
    TearDown;
  end;
  Result := FStats.Failed;
end;

procedure TOpenSSLTestBase.PrintSummary;
begin
  WriteLn;
  WriteLn('=== Test Summary ===');
  WriteLn('Total:   ', FStats.Passed + FStats.Failed + FStats.Skipped);
  WriteLn('Passed:  ', FStats.Passed);
  WriteLn('Failed:  ', FStats.Failed);
  WriteLn('Skipped: ', FStats.Skipped);

  if FStats.Skipped > 0 then
  begin
    WriteLn('Skip Taxonomy:');
    WriteLn('  dependency: ', FStats.SkipDependency);
    WriteLn('  version: ', FStats.SkipVersion);
    WriteLn('  environment: ', FStats.SkipEnvironment);
    WriteLn('  capability: ', FStats.SkipCapability);
    WriteLn('  other: ', FStats.SkipOther);
  end;

  if FStats.Failed = 0 then
    WriteLn('RESULT: ALL TESTS PASSED')
  else
    WriteLn('RESULT: ', FStats.Failed, ' TESTS FAILED');
end;

class function TOpenSSLTestBase.OpenSSLVersion: TOpenSSLVersionInfo;
begin
  EnsureOpenSSLInitialized;
  Result := TOpenSSLLoader.GetVersionInfo;
end;

class function TOpenSSLTestBase.IsOpenSSL3: Boolean;
begin
  Result := TOpenSSLLoader.IsOpenSSL3;
end;

class procedure TOpenSSLTestBase.EnsureOpenSSLInitialized;
begin
  if not FOpenSSLInitialized then
  begin
    // 加载核心库
    if TOpenSSLLoader.GetLibraryHandle(osslLibCrypto) <> 0 then
    begin
      // 加载核心模块
      LoadOpenSSLCore;
      FOpenSSLInitialized := True;
    end;
  end;
end;

{ TSimpleTestRunner }

procedure TSimpleTestRunner.RequireModules(const Modules: array of TOpenSSLModule);
begin
  inherited RequireModules(Modules);
end;

function TSimpleTestRunner.Initialize: Boolean;
var
  M: TOpenSSLModule;
  Missing: string;
begin
  // 首先确保 OpenSSL 库已加载
  EnsureOpenSSLInitialized;

  // 调用 SetUp 来处理基本初始化
  SetUp;

  if FSkipped then
  begin
    WriteLn('Initialization skipped: ', FSkipReason);
    Result := False;
    Exit;
  end;

  // 尝试加载所需模块 - 始终调用加载函数，让模块自己检查是否已加载
  for M in FRequiredModules do
  begin
    // 每个模块的加载函数会自己检查是否已加载，所以这里直接调用
    case M of
      osmCore: LoadOpenSSLCore;
      osmBN: LoadOpenSSLBN;
      osmRSA: LoadOpenSSLRSA;
      osmDSA: LoadOpenSSLDSA;
      osmEVP: LoadEVP(TOpenSSLLoader.GetLibraryHandle(osslLibCrypto));
      osmSSL: LoadOpenSSLSSL;
      osmX509: LoadOpenSSLX509;
      osmPEM: LoadOpenSSLPEM(TOpenSSLLoader.GetLibraryHandle(osslLibCrypto));
      osmBIO: LoadOpenSSLBIO;
      osmASN1: LoadOpenSSLASN1(TOpenSSLLoader.GetLibraryHandle(osslLibCrypto));
      osmEC: LoadECFunctions(TOpenSSLLoader.GetLibraryHandle(osslLibCrypto));
      osmRAND: LoadOpenSSLRAND;
      osmKDF: LoadKDFFunctions;
      osmHMAC: LoadOpenSSLHMAC;
      osmDH: LoadOpenSSLDH;
      osmECDH: LoadOpenSSLECDH;
      osmECDSA: LoadOpenSSLECDSA;
      // 其他模块可以根据需要添加
    end;
  end;

  // 检查所有必需模块是否已加载
  Missing := '';
  for M in FRequiredModules do
  begin
    if not TOpenSSLLoader.IsModuleLoaded(M) then
    begin
      if Missing <> '' then
        Missing := Missing + ', ';
      Missing := Missing + GetModuleName(M);
    end;
  end;

  if Missing <> '' then
  begin
    WriteLn('Missing required modules: ', Missing);
    Result := False;
    Exit;
  end;

  Result := True;
end;

procedure TSimpleTestRunner.Test(const Name: string; Proc: TTestProc);
begin
  FTestName := Name;
  FSkipped := False;

  try
    Proc();
  except
    on E: Exception do
    begin
      LogTest(Name, False, 'Exception: ' + E.Message);
    end;
  end;
end;

procedure TSimpleTestRunner.Check(const Name: string; Condition: Boolean; const Details: string);
var
  FullName: string;
begin
  if FTestName <> '' then
    FullName := FTestName + ': ' + Name
  else
    FullName := Name;

  LogTest(FullName, Condition, Details);
end;

procedure TSimpleTestRunner.Skip(const Name: string; const Reason: string);
var
  FullName: string;
begin
  if FTestName <> '' then
    FullName := FTestName + ': ' + Name
  else
    FullName := Name;

  SkipTest(Reason);
  LogTest(FullName, True);

  // Reset skip state so subsequent checks are not affected.
  SetUp;
end;

initialization
  TOpenSSLTestBase.FOpenSSLInitialized := False;
  TOpenSSLTestBase.FLogLevel := tllNormal;

end.

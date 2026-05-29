program test_winssl_enterprise;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.winssl.enterprise;

type
  TTestResult = record
    TestName: string;
    Passed: Boolean;
    Message: string;
  end;

var
  GResults: array of TTestResult;
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;

procedure AddTestResult(const aTestName: string; aPassed: Boolean; const aMessage: string);
begin
  SetLength(GResults, Length(GResults) + 1);
  with GResults[High(GResults)] do
  begin
    TestName := aTestName;
    Passed := aPassed;
    Message := aMessage;
  end;
  Inc(GTestCount);
  if aPassed then
    Inc(GPassCount);
end;

procedure PrintResults;
var
  i: Integer;
begin
  WriteLn;
  WriteLn('=' + StringOfChar('=', 78));
  WriteLn('WinSSL Enterprise Features Test Results');
  WriteLn('=' + StringOfChar('=', 78));
  WriteLn;
  
  for i := 0 to High(GResults) do
  begin
    if GResults[i].Passed then
      Write('[PASS] ')
    else
      Write('[FAIL] ');
    WriteLn(GResults[i].TestName);
    if GResults[i].Message <> '' then
      WriteLn('       ', GResults[i].Message);
  end;
  
  WriteLn;
  WriteLn('=' + StringOfChar('=', 78));
  WriteLn(Format('Total: %d, Passed: %d, Failed: %d (%.1f%%)',
    [GTestCount, GPassCount, GTestCount - GPassCount,
     (GPassCount / GTestCount) * 100.0]));
  WriteLn('=' + StringOfChar('=', 78));
end;

// Test 1: FIPS 模式检测
procedure TestFIPSDetection;
var
  LFIPSEnabled: Boolean;
begin
  try
    LFIPSEnabled := IsFIPSModeEnabled;
    
    AddTestResult('Test 1: FIPS Mode Detection', True,
      Format('FIPS Mode: %s', [BoolToStr(LFIPSEnabled, 'Enabled', 'Disabled')]));
  except
    on E: Exception do
      AddTestResult('Test 1: FIPS Mode Detection', False, 'Exception: ' + E.Message);
  end;
end;

// Test 2: 企业配置类创建
procedure TestEnterpriseConfigCreation;
var
  LConfig: TSSLEnterpriseConfig;
begin
  try
    LConfig := TSSLEnterpriseConfig.Create;
    try
      AddTestResult('Test 2: Enterprise Config Creation', True,
        'TSSLEnterpriseConfig created successfully');
    finally
      LConfig.Free;
    end;
  except
    on E: Exception do
      AddTestResult('Test 2: Enterprise Config Creation', False, 'Exception: ' + E.Message);
  end;
end;

// Test 3: 从系统加载配置
procedure TestLoadFromSystem;
var
  LConfig: TSSLEnterpriseConfig;
  LSuccess: Boolean;
begin
  try
    LConfig := TSSLEnterpriseConfig.Create;
    try
      LSuccess := LConfig.LoadFromSystem;
      
      AddTestResult('Test 3: Load From System', LSuccess,
        Format('Configuration loaded: %s', [BoolToStr(LSuccess, True)]));
    finally
      LConfig.Free;
    end;
  except
    on E: Exception do
      AddTestResult('Test 3: Load From System', False, 'Exception: ' + E.Message);
  end;
end;

// Test 4: FIPS 模式检测（配置类）
procedure TestFIPSDetectionViaConfig;
var
  LConfig: TSSLEnterpriseConfig;
  LFIPSEnabled: Boolean;
begin
  try
    LConfig := TSSLEnterpriseConfig.Create;
    try
      LConfig.LoadFromSystem;
      LFIPSEnabled := LConfig.IsFIPSEnabled;
      
      AddTestResult('Test 4: FIPS Detection via Config', True,
        Format('FIPS Mode via Config: %s', 
          [BoolToStr(LFIPSEnabled, 'Enabled', 'Disabled')]));
    finally
      LConfig.Free;
    end;
  except
    on E: Exception do
      AddTestResult('Test 4: FIPS Detection via Config', False, 'Exception: ' + E.Message);
  end;
end;

// Test 5: 获取受信任根证书
procedure TestGetTrustedRoots;
var
  LConfig: TSSLEnterpriseConfig;
  LRoots: TStringArray;
begin
  try
    LConfig := TSSLEnterpriseConfig.Create;
    try
      LConfig.LoadFromSystem;
      LRoots := LConfig.GetTrustedRoots;
      
      AddTestResult('Test 5: Get Trusted Roots', True,
        Format('Found %d trusted root certificates', [Length(LRoots)]));
    finally
      LConfig.Free;
    end;
  except
    on E: Exception do
      AddTestResult('Test 5: Get Trusted Roots', False, 'Exception: ' + E.Message);
  end;
end;

// Test 6: 企业 CA 信任检查
procedure TestEnterpriseCATrust;
var
  LConfig: TSSLEnterpriseConfig;
  LTrusted: Boolean;
begin
  try
    LConfig := TSSLEnterpriseConfig.Create;
    try
      LConfig.LoadFromSystem;
      LTrusted := LConfig.IsEnterpriseCATrusted;
      
      AddTestResult('Test 6: Enterprise CA Trust', True,
        Format('Enterprise CA Trusted: %s', 
          [BoolToStr(LTrusted, 'Yes', 'No')]));
    finally
      LConfig.Free;
    end;
  except
    on E: Exception do
      AddTestResult('Test 6: Enterprise CA Trust', False, 'Exception: ' + E.Message);
  end;
end;

// Test 7: 组策略读取
procedure TestGroupPolicyRead;
var
  LConfig: TSSLEnterpriseConfig;
  LPolicies: TStringList;
begin
  try
    LConfig := TSSLEnterpriseConfig.Create;
    try
      LConfig.LoadFromSystem;
      LPolicies := LConfig.GetAllPolicies;
      try
        AddTestResult('Test 7: Group Policy Read', True,
          Format('Found %d group policies', [LPolicies.Count]));
      finally
        LPolicies.Free;
      end;
    finally
      LConfig.Free;
    end;
  except
    on E: Exception do
      AddTestResult('Test 7: Group Policy Read', False, 'Exception: ' + E.Message);
  end;
end;

// Test 8: 配置重新加载
procedure TestConfigReload;
var
  LConfig: TSSLEnterpriseConfig;
begin
  try
    LConfig := TSSLEnterpriseConfig.Create;
    try
      LConfig.LoadFromSystem;
      LConfig.Reload;
      
      AddTestResult('Test 8: Config Reload', True,
        'Configuration reloaded successfully');
    finally
      LConfig.Free;
    end;
  except
    on E: Exception do
      AddTestResult('Test 8: Config Reload', False, 'Exception: ' + E.Message);
  end;
end;

// Test 9: 全局辅助函数 - GetEnterpriseTrustedRoots
procedure TestGetEnterpriseTrustedRootsFunction;
var
  LRoots: TStringArray;
begin
  try
    LRoots := GetEnterpriseTrustedRoots;
    
    AddTestResult('Test 9: GetEnterpriseTrustedRoots Function', True,
      Format('Found %d roots via global function', [Length(LRoots)]));
  except
    on E: Exception do
      AddTestResult('Test 9: GetEnterpriseTrustedRoots Function', False, 
        'Exception: ' + E.Message);
  end;
end;

begin
  WriteLn('WinSSL Enterprise Features Test Suite');
  WriteLn('Testing Windows enterprise integration...');
  WriteLn;
  
  TestFIPSDetection;
  TestEnterpriseConfigCreation;
  TestLoadFromSystem;
  TestFIPSDetectionViaConfig;
  TestGetTrustedRoots;
  TestEnterpriseCATrust;
  TestGroupPolicyRead;
  TestConfigReload;
  TestGetEnterpriseTrustedRootsFunction;
  
  PrintResults;
  
  if GPassCount < GTestCount then
    Halt(1);
end.


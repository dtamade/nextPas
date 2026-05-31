program test_winssl_api_basic;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils
  {$IFDEF WINDOWS}
  , Windows,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api
  {$ENDIF}
  ;

{$IFDEF WINDOWS}
const
  SEC_E_NO_CREDENTIALS = LongInt($8009030E);

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestsSkipped: Integer = 0;
  SkipCredentialMissing: Integer = 0;

procedure WriteTest(const TestName: string);
begin
  Write('  [', TestName, '] ... ');
end;

procedure WritePass;
begin
  WriteLn('[PASS]');
  Inc(TestsPassed);
end;

procedure WriteFail(const Reason: string = '');
begin
  if Reason <> '' then
    WriteLn('[FAIL] - ', Reason)
  else
    WriteLn('[FAIL]');
  Inc(TestsFailed);
end;

procedure WriteSkip(const Reason: string; const Category: string = 'other');
begin
  WriteLn('[SKIP] [', Category, '] ', Reason);
  Inc(TestsSkipped);
end;

procedure WriteCredentialSkip(const Reason: string);
begin
  Inc(SkipCredentialMissing);
  WriteSkip(Reason, 'credential-missing');
end;

procedure TestAPIFunctionsAvailable;
begin
  WriteLn('=== 测试 1: Schannel API 函数可用性 ===');
  WriteLn;

  WriteTest('AcquireCredentialsHandleW 可用');
  if Assigned(@AcquireCredentialsHandleW) then
    WritePass
  else
    WriteFail('函数未找到');

  WriteTest('InitializeSecurityContextW 可用');
  if Assigned(@InitializeSecurityContextW) then
    WritePass
  else
    WriteFail('函数未找到');

  WriteTest('EncryptMessage 可用');
  if Assigned(@EncryptMessage) then
    WritePass
  else
    WriteFail('函数未找到');

  WriteTest('DecryptMessage 可用');
  if Assigned(@DecryptMessage) then
    WritePass
  else
    WriteFail('函数未找到');

  WriteLn;
end;

procedure TestConstants;
begin
  WriteLn('=== 测试 2: 常量值验证 ===');
  WriteLn;

  WriteTest('SCHANNEL_CRED_VERSION');
  if SCHANNEL_CRED_VERSION = 4 then
    WritePass
  else
    WriteFail(Format('期望 4, 实际 %d', [SCHANNEL_CRED_VERSION]));

  WriteTest('SECPKG_CRED_OUTBOUND');
  if SECPKG_CRED_OUTBOUND = $00000002 then
    WritePass
  else
    WriteFail(Format('期望 $00000002, 实际 $%.8x', [SECPKG_CRED_OUTBOUND]));

  WriteLn;
end;

procedure TestBasicCredentialAcquisition;
const
  UNISP_NAME = 'Microsoft Unified Security Protocol Provider';
var
  MyCredHandle: CredHandle;
  SchannelCred: SCHANNEL_CRED;
  MyTimeStamp: TimeStamp;
  Status: SECURITY_STATUS;
begin
  WriteLn('=== 测试 3: 基本凭据获取 ===');
  WriteLn;

  WriteTest('AcquireCredentialsHandleW (客户端)');
  FillChar(SchannelCred, SizeOf(SchannelCred), 0);
  SchannelCred.dwVersion := SCHANNEL_CRED_VERSION;
  SchannelCred.grbitEnabledProtocols := 0;
  SchannelCred.dwFlags := $00000004 or $00000080;

  FillChar(MyCredHandle, SizeOf(MyCredHandle), 0);
  FillChar(MyTimeStamp, SizeOf(MyTimeStamp), 0);

  Status := AcquireCredentialsHandleW(
    nil,
    PWideChar(WideString(UNISP_NAME)),
    SECPKG_CRED_OUTBOUND,
    nil,
    @SchannelCred,
    nil,
    nil,
    @MyCredHandle,
    @MyTimeStamp
  );

  if Status = 0 then
    WritePass
  else if Status = SEC_E_NO_CREDENTIALS then
    WriteCredentialSkip(Format('未获取凭据 (status=0x%.8x)', [Status]))
  else
    WriteFail(Format('返回状态码: 0x%.8x', [Status]));

  if Status = 0 then
  begin
    WriteTest('FreeCredentialsHandle');
    Status := FreeCredentialsHandle(@MyCredHandle);
    if Status = 0 then
      WritePass
    else
      WriteFail(Format('返回状态码: 0x%.8x', [Status]));
  end;

  WriteLn;
end;

procedure PrintSummary;
var
  Total: Integer;
begin
  Total := TestsPassed + TestsFailed + TestsSkipped;
  WriteLn('==============================================');
  WriteLn('测试摘要:');
  WriteLn('  总计: ', Total);
  if Total > 0 then
    WriteLn('  通过: ', TestsPassed, ' (', FormatFloat('0.0', TestsPassed / Total * 100), '%)')
  else
    WriteLn('  通过: ', TestsPassed, ' (0.0%)');
  WriteLn('  失败: ', TestsFailed);
  WriteLn('  跳过: ', TestsSkipped, ' (credential-missing=', SkipCredentialMissing, ')');

  if TestsFailed = 0 then
    WriteLn('✅ WinSSL API 测试通过')
  else
    WriteLn('⚠️ WinSSL API 测试存在失败');
  WriteLn('==============================================');
end;

begin
  WriteLn('');
  WriteLn('==============================================');
  WriteLn('  fafafa.ssl - WinSSL API 基础测试');
  WriteLn('==============================================');
  WriteLn('');
  WriteLn('测试环境:');
  WriteLn('  操作系统: Windows ', GetVersion shr 16, '.', GetVersion and $FFFF);
  WriteLn('  编译器: Free Pascal ', {$I %FPCVERSION%});
  WriteLn('');

  try
    TestAPIFunctionsAvailable;
    TestConstants;
    TestBasicCredentialAcquisition;
  except
    on E: Exception do
    begin
      WriteLn('!!! 严重错误: ', E.Message);
      Inc(TestsFailed);
    end;
  end;

  PrintSummary;
  if TestsFailed > 0 then
    Halt(1);
end.
{$ELSE}
begin
  WriteLn('==============================================');
  WriteLn('  fafafa.ssl - WinSSL API 基础测试');
  WriteLn('==============================================');
  WriteLn('[BLOCKED] [platform] WinSSL API 测试仅支持 Windows 运行时');
  WriteLn('[SKIP] [platform] 当前平台非 Windows，跳过 WinSSL API 绑定验证');
end.
{$ENDIF}

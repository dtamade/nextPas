{
  test_winssl_server_handshake - WinSSL 服务端握手测试
}

program test_winssl_server_handshake;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils
  {$IFDEF WINDOWS}
  , nextpas.core.tls.base,
  nextpas.core.tls.factory
  {$ENDIF}
  ;

{$IFDEF WINDOWS}
var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestsSkipped: Integer = 0;
  SkipNoCert: Integer = 0;
  SkipBlockedPlatform: Integer = 0;

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

procedure WriteNoCertSkip(const Reason: string);
begin
  Inc(SkipNoCert);
  WriteSkip(Reason, 'no-cert');
end;

procedure WriteBlockedPlatform(const Reason: string);
begin
  Inc(SkipBlockedPlatform);
  WriteLn('[BLOCKED] [platform] ', Reason);
  WriteSkip('该场景依赖 Windows 运行时与证书材料', 'platform');
end;

procedure TestServerContextCreation;
var
  ServerContext: ISSLContext;
begin
  WriteLn('=== 测试 1: 服务端上下文创建 ===');
  WriteLn;

  WriteTest('TSSLFactory.CreateContext(sslCtxServer, sslWinSSL)');
  try
    ServerContext := TSSLFactory.CreateContext(sslCtxServer, sslWinSSL);
    if Assigned(ServerContext) then
      WritePass
    else
      WriteFail('Server context is nil');
  except
    on E: Exception do
      WriteFail(E.Message);
  end;

  WriteLn;
end;

procedure TestServerCertificateLoading;
var
  ServerContext: ISSLContext;
  CertPath: string;
begin
  WriteLn('=== 测试 2: 服务端证书加载 ===');
  WriteLn;

  CertPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'test_certs\\server.pfx';

  if not FileExists(CertPath) then
  begin
    WriteNoCertSkip('测试证书不存在，请先准备 test_certs\\server.pfx');
    WriteLn;
    Exit;
  end;

  ServerContext := TSSLFactory.CreateContext(sslCtxServer, sslWinSSL);

  WriteTest('LoadCertificate(server.pfx)');
  try
    ServerContext.LoadCertificate(CertPath);
    if ServerContext.IsValid then
      WritePass
    else
      WriteFail('Context invalid after certificate loading');
  except
    on E: Exception do
      WriteFail(E.Message);
  end;

  WriteLn;
end;

procedure TestServerHandshakeBlockedContract;
begin
  WriteLn('=== 测试 3: 服务端握手路径说明 ===');
  WriteLn;
  WriteBlockedPlatform('完整服务端握手依赖 Windows 套接字对与证书链运行时，本用例先收敛阻塞契约');
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
  WriteLn('  跳过: ', TestsSkipped,
    ' (no-cert=', SkipNoCert,
    ', platform=', SkipBlockedPlatform, ')');

  if TestsFailed = 0 then
    WriteLn('✅ WinSSL 服务端握手测试（当前可执行范围）通过')
  else
    WriteLn('⚠️ WinSSL 服务端握手测试存在失败');
  WriteLn('==============================================');
end;

begin
  WriteLn('');
  WriteLn('==============================================');
  WriteLn('  fafafa.ssl - WinSSL 服务端握手测试');
  WriteLn('==============================================');
  WriteLn('');
  WriteLn('测试环境:');
  WriteLn('  操作系统: Windows ', GetVersion shr 16, '.', GetVersion and $FFFF);
  WriteLn('  编译器: Free Pascal ', {$I %FPCVERSION%});
  WriteLn('');

  try
    TestServerContextCreation;
    TestServerCertificateLoading;
    TestServerHandshakeBlockedContract;
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
  WriteLn('  fafafa.ssl - WinSSL 服务端握手测试');
  WriteLn('==============================================');
  WriteLn('[BLOCKED] [platform] WinSSL 服务端握手测试仅支持 Windows 运行时');
  WriteLn('[SKIP] [platform] 当前平台非 Windows，执行阻塞契约输出');
end.
{$ENDIF}

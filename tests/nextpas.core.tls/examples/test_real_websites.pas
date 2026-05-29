program test_real_websites;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{
  真实网站连接测试（简版）

  目标：
  - 真实网络环境下，对多个 HTTPS 站点做一次完整 TLS 握手
  - 使用当前公共 API：ConnectTCP + TSSLContextBuilder + TSSLConnector
  - 证书验证：WithVerifyPeer + WithSystemRoots

  注意：这是网络依赖示例，离线环境会出现失败/跳过。
}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.context.builder,
  fafafa.examples.tcp;

type
  TWebsiteTest = record
    Host: string;
    Port: Word;
    Description: string;
  end;

const
  TEST_SITES: array[1..10] of TWebsiteTest = (
    (Host: 'www.google.com'; Port: 443; Description: 'Google'),
    (Host: 'github.com'; Port: 443; Description: 'GitHub'),
    (Host: 'api.github.com'; Port: 443; Description: 'GitHub API'),
    (Host: 'www.cloudflare.com'; Port: 443; Description: 'Cloudflare'),
    (Host: 'www.mozilla.org'; Port: 443; Description: 'Mozilla'),
    (Host: 'www.wikipedia.org'; Port: 443; Description: 'Wikipedia'),
    (Host: 'www.npmjs.com'; Port: 443; Description: 'NPM'),
    (Host: 'www.rust-lang.org'; Port: 443; Description: 'Rust'),
    (Host: 'golang.org'; Port: 443; Description: 'Go'),
    (Host: 'www.python.org'; Port: 443; Description: 'Python')
  );

var
  GTotalTests: Integer = 0;
  GPassedTests: Integer = 0;
  GFailedTests: Integer = 0;
  GSkippedTests: Integer = 0;

procedure TestWebsite(const ATest: TWebsiteTest; const AConnector: TSSLConnector);
var
  Sock: TSocketHandle;
  TLS: TSSLStream;
  LVerifyResult: Integer;
  LVerifyResultString: string;
begin
  Inc(GTotalTests);
  Write(Format('[%2d/%2d] %-12s (%s:%d) ... ',
    [GTotalTests, Length(TEST_SITES), ATest.Description, ATest.Host, ATest.Port]));

  Sock := INVALID_SOCKET;
  TLS := nil;
  try
    try
      try
        Sock := ConnectTCP(ATest.Host, ATest.Port);
      except
        on E: Exception do
        begin
          Inc(GSkippedTests);
          WriteLn('⊘ 跳过: ', E.Message);
          Exit;
        end;
      end;

      TLS := AConnector.ConnectSocket(THandle(Sock), ATest.Host);
      GetCertificateVerificationInfo(TLS.Connection, LVerifyResult, LVerifyResultString);

      WriteLn('✓ ',
        ProtocolVersionToString(TLS.Connection.GetProtocolVersion), ' / ',
        TLS.Connection.GetCipherName, ' | ',
        LVerifyResultString);

      Inc(GPassedTests);
    except
      on E: Exception do
      begin
        Inc(GFailedTests);
        WriteLn('✗ ', E.Message);
      end;
    end;
  finally
    if TLS <> nil then
      TLS.Free;
    CloseSocket(Sock);
  end;
end;

var
  NetErr: string;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  I: Integer;
  EffectiveTotal: Integer;
begin
  WriteLn('====================================================');
  WriteLn('fafafa.ssl - 真实网站连接测试（简版）');
  WriteLn('====================================================');
  WriteLn;

  if not InitNetwork(NetErr) then
  begin
    WriteLn('网络初始化失败: ', NetErr);
    Halt(2);
  end;

  try
    Ctx := TSSLContextBuilder.Create
      .WithTLS12And13
      .WithVerifyPeer
      .WithSystemRoots
      .BuildClient;

    Connector := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));

    for I := Low(TEST_SITES) to High(TEST_SITES) do
      TestWebsite(TEST_SITES[I], Connector);

    WriteLn;
    WriteLn('----------------------------------------------------');
    WriteLn('结果汇总:');
    WriteLn('  Total:   ', GTotalTests);
    WriteLn('  Passed:  ', GPassedTests);
    WriteLn('  Failed:  ', GFailedTests);
    if GSkippedTests > 0 then
      WriteLn('  Skipped: ', GSkippedTests);

    EffectiveTotal := GTotalTests - GSkippedTests;
    if EffectiveTotal <= 0 then
      EffectiveTotal := GTotalTests;

    if EffectiveTotal > 0 then
      WriteLn(Format('  Pass rate (excluding skipped): %.1f%%',
        [GPassedTests * 100.0 / EffectiveTotal]));
  finally
    CleanupNetwork;
  end;
end.

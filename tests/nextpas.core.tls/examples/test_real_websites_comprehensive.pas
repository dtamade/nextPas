program test_real_websites_comprehensive;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{
  综合真实网站连接测试 (50+ 站点)

  - 大规模测试 HTTPS 连接兼容性
  - 使用当前公共 API：ConnectTCP + TSSLContextBuilder + TSSLConnector/TSSLStream
  - SNI/hostname：每连接设置（ConnectSocket(..., serverName)）
  - 证书验证：WithVerifyPeer + WithSystemRoots

  注意：这是网络依赖示例。
}

uses
  SysUtils, Classes,
  fafafa.ssl,
  nextpas.core.tls.context.builder,
  fafafa.examples.tcp;

type
  TWebsiteTest = record
    Host: string;
    Port: Word;
    Description: string;
  end;

  TTestResult = record
    Success: Boolean;
    Skipped: Boolean;
    ErrorMessage: string;
    Protocol: string;
    Cipher: string;
    VerifyResult: string;
    ResponseTime: Integer;
  end;

const
  // Top 50+ Global Websites & Tech Services covering various CDNs and CAs
  TEST_SITES: array[1..52] of TWebsiteTest = (
    // Search Engines
    (Host: 'www.google.com'; Port: 443; Description: 'Google'),
    (Host: 'www.bing.com'; Port: 443; Description: 'Bing'),
    (Host: 'duckduckgo.com'; Port: 443; Description: 'DuckDuckGo'),
    (Host: 'www.baidu.com'; Port: 443; Description: 'Baidu'),
    (Host: 'yandex.com'; Port: 443; Description: 'Yandex'),

    // Social Media
    (Host: 'www.facebook.com'; Port: 443; Description: 'Facebook'),
    (Host: 'twitter.com'; Port: 443; Description: 'Twitter'),
    (Host: 'www.instagram.com'; Port: 443; Description: 'Instagram'),
    (Host: 'www.linkedin.com'; Port: 443; Description: 'LinkedIn'),
    (Host: 'www.reddit.com'; Port: 443; Description: 'Reddit'),
    (Host: 'www.tiktok.com'; Port: 443; Description: 'TikTok'),
    (Host: 'weibo.com'; Port: 443; Description: 'Weibo'),

    // Tech & Dev
    (Host: 'github.com'; Port: 443; Description: 'GitHub'),
    (Host: 'gitlab.com'; Port: 443; Description: 'GitLab'),
    (Host: 'bitbucket.org'; Port: 443; Description: 'Bitbucket'),
    (Host: 'stackoverflow.com'; Port: 443; Description: 'Stack Overflow'),
    (Host: 'www.docker.com'; Port: 443; Description: 'Docker'),
    (Host: 'www.npmjs.com'; Port: 443; Description: 'NPM'),
    (Host: 'pypi.org'; Port: 443; Description: 'PyPI'),
    (Host: 'crates.io'; Port: 443; Description: 'Crates.io'),

    // Cloud & CDN
    (Host: 'aws.amazon.com'; Port: 443; Description: 'AWS'),
    (Host: 'azure.microsoft.com'; Port: 443; Description: 'Azure'),
    (Host: 'cloud.google.com'; Port: 443; Description: 'Google Cloud'),
    (Host: 'www.cloudflare.com'; Port: 443; Description: 'Cloudflare'),
    (Host: 'www.akamai.com'; Port: 443; Description: 'Akamai'),
    (Host: 'www.fastly.com'; Port: 443; Description: 'Fastly'),
    (Host: 'www.digitalocean.com'; Port: 443; Description: 'DigitalOcean'),
    (Host: 'www.heroku.com'; Port: 443; Description: 'Heroku'),
    (Host: 'vercel.com'; Port: 443; Description: 'Vercel'),
    (Host: 'netlify.com'; Port: 443; Description: 'Netlify'),

    // E-commerce & Payments
    (Host: 'www.amazon.com'; Port: 443; Description: 'Amazon'),
    (Host: 'www.ebay.com'; Port: 443; Description: 'eBay'),
    (Host: 'www.paypal.com'; Port: 443; Description: 'PayPal'),
    (Host: 'stripe.com'; Port: 443; Description: 'Stripe'),
    (Host: 'www.shopify.com'; Port: 443; Description: 'Shopify'),
    (Host: 'www.taobao.com'; Port: 443; Description: 'Taobao'),
    (Host: 'www.jd.com'; Port: 443; Description: 'JD.com'),

    // Media & Streaming
    (Host: 'www.youtube.com'; Port: 443; Description: 'YouTube'),
    (Host: 'www.netflix.com'; Port: 443; Description: 'Netflix'),
    (Host: 'www.twitch.tv'; Port: 443; Description: 'Twitch'),
    (Host: 'www.spotify.com'; Port: 443; Description: 'Spotify'),
    (Host: 'vimeo.com'; Port: 443; Description: 'Vimeo'),

    // News & Info
    (Host: 'www.wikipedia.org'; Port: 443; Description: 'Wikipedia'),
    (Host: 'www.nytimes.com'; Port: 443; Description: 'NY Times'),
    (Host: 'www.cnn.com'; Port: 443; Description: 'CNN'),
    (Host: 'www.bbc.com'; Port: 443; Description: 'BBC'),
    (Host: 'www.forbes.com'; Port: 443; Description: 'Forbes'),

    // Programming Languages
    (Host: 'www.python.org'; Port: 443; Description: 'Python'),
    (Host: 'golang.org'; Port: 443; Description: 'Go'),
    (Host: 'www.rust-lang.org'; Port: 443; Description: 'Rust'),
    (Host: 'www.php.net'; Port: 443; Description: 'PHP'),
    (Host: 'www.ruby-lang.org'; Port: 443; Description: 'Ruby')
  );

var
  GTotalTests: Integer = 0;
  GPassedTests: Integer = 0;
  GFailedTests: Integer = 0;
  GSkippedTests: Integer = 0;

function RunTest(const ATest: TWebsiteTest; const AConnector: TSSLConnector): TTestResult;
var
  Sock: TSocketHandle;
  TLS: TSSLStream;
  StartMs: QWord;
  Request: RawByteString;
  LVerifyResult: Integer;
begin
  Result.Success := False;
  Result.Skipped := False;
  Result.ErrorMessage := '';
  Result.Protocol := '';
  Result.Cipher := '';
  Result.VerifyResult := '';
  Result.ResponseTime := 0;

  StartMs := GetTickCount64;
  Sock := INVALID_SOCKET;
  TLS := nil;
  try
    try
      try
        Sock := ConnectTCP(ATest.Host, ATest.Port);
      except
        on E: Exception do
        begin
          Result.Skipped := True;
          Result.ErrorMessage := E.Message;
          Exit;
        end;
      end;

      TLS := AConnector.ConnectSocket(THandle(Sock), ATest.Host);
      Result.Protocol := ProtocolVersionToString(TLS.Connection.GetProtocolVersion);
      Result.Cipher := TLS.Connection.GetCipherName;
      GetCertificateVerificationInfo(TLS.Connection, LVerifyResult, Result.VerifyResult);

      // 发送一个轻量 HEAD 请求（只验证加密通道可写即可）
      Request := 'HEAD / HTTP/1.1'#13#10 +
                 'Host: ' + ATest.Host + #13#10 +
                 'User-Agent: fafafa.ssl-test_real_websites_comprehensive/1.0'#13#10 +
                 'Connection: close'#13#10 +
                 #13#10;

      if Length(Request) > 0 then
        TLS.WriteBuffer(Request[1], Length(Request));

      Result.Success := True;
    except
      on E: Exception do
      begin
        Result.Success := False;
        Result.ErrorMessage := E.Message;
      end;
    end;
  finally
    Result.ResponseTime := GetTickCount64 - StartMs;
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
  R: TTestResult;
  EffectiveTotal: Integer;
begin
  WriteLn('================================================================');
  WriteLn('fafafa.ssl - Comprehensive Real Website Test (50+ Sites)');
  WriteLn('================================================================');
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

    WriteLn('----------------------------------------------------------------');

    for I := Low(TEST_SITES) to High(TEST_SITES) do
    begin
      Inc(GTotalTests);
      Write(Format('[%2d/%2d] %-20s ', [GTotalTests, Length(TEST_SITES), TEST_SITES[I].Description]));

      R := RunTest(TEST_SITES[I], Connector);

      if R.Skipped then
      begin
        Inc(GSkippedTests);
        WriteLn('⊘ 跳过: ', R.ErrorMessage);
        Continue;
      end;

      if R.Success then
      begin
        Inc(GPassedTests);
        WriteLn(Format('✓ %s (%s, %dms) | %s',
          [R.Protocol, R.Cipher, R.ResponseTime, R.VerifyResult]));
      end
      else
      begin
        Inc(GFailedTests);
        WriteLn('✗ ', R.ErrorMessage);
      end;
    end;

    WriteLn('----------------------------------------------------------------');

    EffectiveTotal := GTotalTests - GSkippedTests;
    if EffectiveTotal <= 0 then
      EffectiveTotal := GTotalTests;

    WriteLn(Format('Results: %d/%d Passed (%.1f%%)',
      [GPassedTests, EffectiveTotal, GPassedTests * 100.0 / EffectiveTotal]));
    if GFailedTests > 0 then
      WriteLn('Failed:   ', GFailedTests);
    if GSkippedTests > 0 then
      WriteLn('Skipped:  ', GSkippedTests);

    WriteLn('================================================================');
  finally
    CleanupNetwork;
  end;
end.

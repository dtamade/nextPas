program test_real_websites_enhanced;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

{
  增强版真实网站连接测试

  - 完整测试：TCP 连接 + TLS 握手 + 简单 HTTP 请求
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
    Path: string;
    Description: string;
    ExpectedStatus: string;
  end;

  TTestResult = record
    Success: Boolean;
    Skipped: Boolean;
    ErrorMessage: string;
    Protocol: string;
    Cipher: string;
    VerifyResult: string;
    ResponseCode: string;
    ResponseTime: Integer; // ms
  end;

const
  TEST_SITES: array[1..12] of TWebsiteTest = (
    (Host: 'www.google.com'; Port: 443; Path: '/'; Description: 'Google'; ExpectedStatus: '200'),
    (Host: 'github.com'; Port: 443; Path: '/'; Description: 'GitHub'; ExpectedStatus: '200'),
    (Host: 'api.github.com'; Port: 443; Path: '/'; Description: 'GitHub API'; ExpectedStatus: '200'),
    (Host: 'www.cloudflare.com'; Port: 443; Path: '/'; Description: 'Cloudflare'; ExpectedStatus: '200'),
    (Host: 'www.mozilla.org'; Port: 443; Path: '/'; Description: 'Mozilla'; ExpectedStatus: '200'),
    (Host: 'www.wikipedia.org'; Port: 443; Path: '/'; Description: 'Wikipedia'; ExpectedStatus: '200'),
    (Host: 'www.example.com'; Port: 443; Path: '/'; Description: 'Example.com'; ExpectedStatus: '200'),
    (Host: 'badssl.com'; Port: 443; Path: '/'; Description: 'BadSSL'; ExpectedStatus: '200'),
    (Host: 'golang.org'; Port: 443; Path: '/'; Description: 'Go'; ExpectedStatus: '200'),
    (Host: 'www.python.org'; Port: 443; Path: '/'; Description: 'Python'; ExpectedStatus: '200'),
    (Host: 'www.rust-lang.org'; Port: 443; Path: '/'; Description: 'Rust'; ExpectedStatus: '200'),
    (Host: 'www.npmjs.com'; Port: 443; Path: '/'; Description: 'NPM'; ExpectedStatus: '200')
  );

var
  GTotalTests: Integer = 0;
  GPassedTests: Integer = 0;
  GFailedTests: Integer = 0;
  GSkippedTests: Integer = 0;

function ReadFirstBytes(AStream: TStream; AMax: Integer): RawByteString;
var
  Buffer: array of Byte;
  N: Longint;
begin
  Result := '';
  if AMax <= 0 then
    Exit;

  SetLength(Buffer, AMax);
  N := AStream.Read(Buffer[0], AMax);
  if N > 0 then
  begin
    SetLength(Result, N);
    Move(Buffer[0], Result[1], N);
  end;
end;

function ExtractStatusCode(const AResp: RawByteString): string;
var
  LineEnd: Integer;
  Line: string;
  P1, P2: Integer;
begin
  Result := '';
  if AResp = '' then
    Exit;

  LineEnd := Pos(#10, AResp);
  if LineEnd > 0 then
    Line := string(Copy(AResp, 1, LineEnd - 1))
  else
    Line := string(AResp);

  Line := StringReplace(Line, #13, '', [rfReplaceAll]);
  Line := Trim(Line);

  if Pos('HTTP/', Line) <> 1 then
    Exit;

  P1 := Pos(' ', Line);
  if P1 = 0 then
    Exit;

  P1 := P1 + 1;
  while (P1 <= Length(Line)) and (Line[P1] = ' ') do
    Inc(P1);

  P2 := P1;
  while (P2 <= Length(Line)) and (Line[P2] <> ' ') do
    Inc(P2);

  Result := Copy(Line, P1, P2 - P1);
end;

function RunTest(const ATest: TWebsiteTest; const AConnector: TSSLConnector): TTestResult;
var
  Sock: TSocketHandle;
  TLS: TSSLStream;
  StartMs: QWord;
  Request: RawByteString;
  RespHead: RawByteString;
  LVerifyResult: Integer;
begin
  Result.Success := False;
  Result.Skipped := False;
  Result.ErrorMessage := '';
  Result.Protocol := '';
  Result.Cipher := '';
  Result.VerifyResult := '';
  Result.ResponseCode := '';
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

      Request := 'GET ' + ATest.Path + ' HTTP/1.1'#13#10 +
                 'Host: ' + ATest.Host + #13#10 +
                 'User-Agent: fafafa.ssl-test_real_websites_enhanced/1.0'#13#10 +
                 'Accept: */*'#13#10 +
                 'Connection: close'#13#10 +
                 #13#10;

      if Length(Request) > 0 then
        TLS.WriteBuffer(Request[1], Length(Request));

      RespHead := ReadFirstBytes(TLS, 4096);
      Result.ResponseCode := ExtractStatusCode(RespHead);
      if Result.ResponseCode = '' then
        raise Exception.Create('无法解析 HTTP 状态行');

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
  Results: array of TTestResult;
  TotalTime, Count, EffectiveTotal: Integer;
begin
  WriteLn('================================================================');
  WriteLn('fafafa.ssl - Enhanced Real Website Connection Test');
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

    SetLength(Results, Length(TEST_SITES));

    WriteLn('Starting tests...');
    WriteLn('----------------------------------------------------------------');

    for I := Low(TEST_SITES) to High(TEST_SITES) do
    begin
      Inc(GTotalTests);
      Write(Format('[%2d/%2d] %-12s (%s:%d) ... ',
        [GTotalTests, Length(TEST_SITES), TEST_SITES[I].Description, TEST_SITES[I].Host, TEST_SITES[I].Port]));

      R := RunTest(TEST_SITES[I], Connector);
      Results[I - Low(TEST_SITES)] := R;

      if R.Skipped then
      begin
        Inc(GSkippedTests);
        WriteLn('⊘ 跳过: ', R.ErrorMessage);
        Continue;
      end;

      if R.Success then
      begin
        Inc(GPassedTests);
        if (TEST_SITES[I].ExpectedStatus <> '') and (R.ResponseCode <> '') and
           (TEST_SITES[I].ExpectedStatus <> R.ResponseCode) then
          WriteLn(Format('✓ %s | %s | %s | %dms (expected %s)',
            [R.Protocol, R.Cipher, R.ResponseCode, R.ResponseTime, TEST_SITES[I].ExpectedStatus]))
        else
          WriteLn(Format('✓ %s | %s | %s | %dms',
            [R.Protocol, R.Cipher, R.ResponseCode, R.ResponseTime]));
      end
      else
      begin
        Inc(GFailedTests);
        WriteLn('✗ ', R.ErrorMessage);
      end;
    end;

    WriteLn('----------------------------------------------------------------');
    WriteLn;

    WriteLn('================================================================');
    WriteLn('Test Results:');
    WriteLn('  Total:   ', GTotalTests);

    EffectiveTotal := GTotalTests - GSkippedTests;
    if EffectiveTotal <= 0 then
      EffectiveTotal := GTotalTests;

    if EffectiveTotal > 0 then
      WriteLn(Format('  Passed:  %d (%.1f%%)', [GPassedTests, GPassedTests * 100.0 / EffectiveTotal]))
    else
      WriteLn('  Passed:  ', GPassedTests);

    WriteLn('  Failed:  ', GFailedTests);
    if GSkippedTests > 0 then
      WriteLn('  Skipped: ', GSkippedTests);

    if GPassedTests > 0 then
    begin
      TotalTime := 0;
      Count := 0;
      for I := 0 to High(Results) do
        if Results[I].Success then
        begin
          Inc(TotalTime, Results[I].ResponseTime);
          Inc(Count);
        end;

      if Count > 0 then
        WriteLn('  Avg Response Time: ', TotalTime div Count, 'ms');
    end;

    WriteLn('================================================================');
  finally
    CleanupNetwork;
  end;
end.

program test_winssl_performance;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  Windows, SysUtils, Classes, WinSock2, Math,
  
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

type
  TPerformanceMetrics = record
    MinTime: Double;
    MaxTime: Double;
    AvgTime: Double;
    TotalTime: Double;
    Operations: Integer;
  end;

var
  Frequency: Int64;

function GetTimestamp: Int64;
var
  LCounter: Int64;
begin
  QueryPerformanceCounter(LCounter);
  Result := LCounter;
end;

function TimestampToMilliseconds(aStart, aEnd: Int64): Double;
begin
  Result := ((aEnd - aStart) * 1000.0) / Frequency;
end;

procedure InitWinsock;
var
  LWSAData: TWSAData;
begin
  if WSAStartup(MAKEWORD(2, 2), LWSAData) <> 0 then
  begin
    WriteLn('错误: 无法初始化 Winsock');
    Halt(1);
  end;
end;

procedure CleanupWinsock;
begin
  WSACleanup;
end;

function ConnectToHost(const aHost: string; aPort: Word; out aSocket: TSocket): Boolean;
var
  LAddr: TSockAddrIn;
  LHostEnt: PHostEnt;
  LInAddr: TInAddr;
  LTimeout: Integer;
begin
  Result := False;
  aSocket := INVALID_SOCKET;

  aSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if aSocket = INVALID_SOCKET then
    Exit;

  LTimeout := 10000;
  setsockopt(aSocket, SOL_SOCKET, SO_RCVTIMEO, @LTimeout, SizeOf(LTimeout));
  setsockopt(aSocket, SOL_SOCKET, SO_SNDTIMEO, @LTimeout, SizeOf(LTimeout));

  LHostEnt := gethostbyname(PAnsiChar(AnsiString(aHost)));
  if LHostEnt = nil then
  begin
    closesocket(aSocket);
    aSocket := INVALID_SOCKET;
    Exit;
  end;

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(aPort);
  Move(LHostEnt^.h_addr_list^^, LInAddr, SizeOf(LInAddr));
  LAddr.sin_addr := LInAddr;

  Result := connect(aSocket, @LAddr, SizeOf(LAddr)) = 0;
  if not Result then
  begin
    closesocket(aSocket);
    aSocket := INVALID_SOCKET;
  end;
end;

procedure PrintMetrics(const aName: string; const aMetrics: TPerformanceMetrics);
begin
  WriteLn('  ', aName, ':');
  WriteLn('    操作次数: ', aMetrics.Operations);
  WriteLn('    总时间: ', Format('%.2f ms', [aMetrics.TotalTime]));
  WriteLn('    平均时间: ', Format('%.2f ms', [aMetrics.AvgTime]));
  WriteLn('    最小时间: ', Format('%.2f ms', [aMetrics.MinTime]));
  WriteLn('    最大时间: ', Format('%.2f ms', [aMetrics.MaxTime]));
end;

function BenchmarkHandshake(const aHost: string; aIterations: Integer): TPerformanceMetrics;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  i: Integer;
  LStart, LEnd: Int64;
  LTime: Double;
  LSuccessCount: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MinTime := MaxDouble;
  Result.MaxTime := 0;
  LSuccessCount := 0;

  WriteLn('执行 ', aIterations, ' 次 TLS 握手测试...');

  LLib := CreateWinSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('错误: 无法初始化 WinSSL');
    Exit;
  end;

  for i := 1 to aIterations do
  begin
    LSocket := INVALID_SOCKET;

    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost(aHost, 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName(aHost);

      LStart := GetTimestamp;
      if LConn.Connect then
      begin
        LEnd := GetTimestamp;
        LTime := TimestampToMilliseconds(LStart, LEnd);

        Inc(LSuccessCount);
        Result.TotalTime += LTime;

        if LTime < Result.MinTime then
          Result.MinTime := LTime;
        if LTime > Result.MaxTime then
          Result.MaxTime := LTime;

        LConn.Shutdown;
      end;

      closesocket(LSocket);
    end;

    if (i mod 10 = 0) then
      Write('.');
  end;

  WriteLn;

  Result.Operations := LSuccessCount;
  if LSuccessCount > 0 then
    Result.AvgTime := Result.TotalTime / LSuccessCount;
end;

function BenchmarkDataTransfer(const aHost, aPath: string; aIterations: Integer): TPerformanceMetrics;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  i: Integer;
  LStart, LEnd: Int64;
  LTime: Double;
  LRequest: string;
  LBuffer: array[0..4095] of Byte;
  LBytesRead: Integer;
  LTotalBytes: Int64;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MinTime := MaxDouble;
  Result.MaxTime := 0;
  LTotalBytes := 0;

  WriteLn('执行 ', aIterations, ' 次数据传输测试...');

  LLib := CreateWinSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('错误: 无法初始化 WinSSL');
    Exit;
  end;

  for i := 1 to aIterations do
  begin
    LSocket := INVALID_SOCKET;

    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost(aHost, 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName(aHost);

      if LConn.Connect then
      begin
        LRequest := 'GET ' + aPath + ' HTTP/1.1'#13#10 +
                    'Host: ' + aHost + #13#10 +
                    'Connection: close'#13#10 +
                    'User-Agent: PerformanceTest/1.0'#13#10 +
                    #13#10;

        LStart := GetTimestamp;

        if LConn.WriteString(LRequest) then
        begin
          repeat
            LBytesRead := LConn.Read(LBuffer[0], SizeOf(LBuffer));
            if LBytesRead > 0 then
              LTotalBytes += LBytesRead;
          until LBytesRead <= 0;

          LEnd := GetTimestamp;
          LTime := TimestampToMilliseconds(LStart, LEnd);

          Inc(Result.Operations);
          Result.TotalTime += LTime;

          if LTime < Result.MinTime then
            Result.MinTime := LTime;
          if LTime > Result.MaxTime then
            Result.MaxTime := LTime;
        end;

        LConn.Shutdown;
      end;

      closesocket(LSocket);
    end;

    if (i mod 5 = 0) then
      Write('.');
  end;

  WriteLn;

  if Result.Operations > 0 then
  begin
    Result.AvgTime := Result.TotalTime / Result.Operations;
    WriteLn('  总传输数据: ', LTotalBytes, ' bytes (', Format('%.2f KB', [LTotalBytes / 1024]), ')');
    WriteLn('  平均吞吐量: ', Format('%.2f KB/s', [(LTotalBytes / 1024) / (Result.TotalTime / 1000)]));
  end;
end;

function BenchmarkMultipleConnections(const aHost: string; aConnections: Integer): TPerformanceMetrics;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  i: Integer;
  LOverallStart, LOverallEnd: Int64;
  LSuccessCount: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);

  WriteLn('执行 ', aConnections, ' 次连续连接测试...');

  LLib := CreateWinSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('错误: 无法初始化 WinSSL');
    Exit;
  end;

  LSuccessCount := 0;
  LOverallStart := GetTimestamp;

  for i := 1 to aConnections do
  begin
    LSocket := INVALID_SOCKET;

    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
    LContext.SetVerifyMode([]);

    if ConnectToHost(aHost, 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);
      (LConn as ISSLClientConnection).SetServerName(aHost);

      if LConn.Connect then
      begin
        Inc(LSuccessCount);
        LConn.Shutdown;
      end;

      closesocket(LSocket);
    end;

    if (i mod 10 = 0) then
      Write('.');
  end;

  LOverallEnd := GetTimestamp;
  WriteLn;

  Result.Operations := LSuccessCount;
  Result.TotalTime := TimestampToMilliseconds(LOverallStart, LOverallEnd);
  if LSuccessCount > 0 then
    Result.AvgTime := Result.TotalTime / LSuccessCount;

  WriteLn('  成功连接: ', LSuccessCount, '/', aConnections, ' (',
    Format('%.1f%%', [LSuccessCount * 100.0 / aConnections]), ')');
  WriteLn('  连接速率: ', Format('%.2f 连接/秒', [LSuccessCount / (Result.TotalTime / 1000)]));
end;

procedure RunPerformanceTests;
var
  LHandshakeMetrics: TPerformanceMetrics;
  LDataTransferMetrics: TPerformanceMetrics;
  LMultiConnMetrics: TPerformanceMetrics;
begin
  WriteLn('=========================================');
  WriteLn('WinSSL 性能基准测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  // Test 1: Handshake Performance
  WriteLn('【测试 1】TLS 握手性能');
  WriteLn('测试服务器: www.google.com');
  WriteLn('---');
  LHandshakeMetrics := BenchmarkHandshake('www.google.com', 20);
  PrintMetrics('握手性能', LHandshakeMetrics);
  WriteLn;

  // Test 2: Data Transfer Performance
  WriteLn('【测试 2】数据传输性能');
  WriteLn('测试服务器: www.google.com');
  WriteLn('测试资源: /robots.txt');
  WriteLn('---');
  LDataTransferMetrics := BenchmarkDataTransfer('www.google.com', '/robots.txt', 10);
  PrintMetrics('数据传输性能', LDataTransferMetrics);
  WriteLn;

  // Test 3: Multiple Connections Performance
  WriteLn('【测试 3】连续连接性能');
  WriteLn('测试服务器: www.cloudflare.com');
  WriteLn('---');
  LMultiConnMetrics := BenchmarkMultipleConnections('www.cloudflare.com', 30);
  PrintMetrics('连续连接性能', LMultiConnMetrics);
  WriteLn;

  // Summary
  WriteLn('=========================================');
  WriteLn('性能摘要');
  WriteLn('=========================================');
  WriteLn('TLS 握手平均延迟: ', Format('%.2f ms', [LHandshakeMetrics.AvgTime]));
  WriteLn('数据传输平均延迟: ', Format('%.2f ms', [LDataTransferMetrics.AvgTime]));
  WriteLn('连接建立速率: ', Format('%.2f 连接/秒',
    [LMultiConnMetrics.Operations / (LMultiConnMetrics.TotalTime / 1000)]));
  WriteLn('=========================================');
end;

begin
  if not QueryPerformanceFrequency(Frequency) then
  begin
    WriteLn('错误: 系统不支持高精度计时器');
    Halt(1);
  end;

  InitWinsock;
  try
    RunPerformanceTests;
  finally
    CleanupWinsock;
  end;
end.

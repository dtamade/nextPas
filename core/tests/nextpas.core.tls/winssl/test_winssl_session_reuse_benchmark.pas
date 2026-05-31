program test_winssl_session_reuse_benchmark;

{$mode objfpc}{$H+}{$J-}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  Windows, SysUtils, Classes, WinSock2, Math,

  nextpas.core.tls.base,
  nextpas.core.tls.winssl.lib;

type
  TSessionReuseMetrics = record
    WithoutSessionReuse: record
      AttemptCount: Integer;
      TotalTime: Double;
      AvgTime: Double;
      MinTime: Double;
      MaxTime: Double;
      SuccessCount: Integer;
    end;
    WithSessionReuse: record
      AttemptCount: Integer;
      TotalTime: Double;
      AvgTime: Double;
      MinTime: Double;
      MaxTime: Double;
      SuccessCount: Integer;
      SessionConfiguredCount: Integer;
      ObservedReuseCount: Integer;
    end;
    ImprovementPercent: Double;
  end;

var
  Frequency: Int64;

function ResolveBenchmarkHost: string;
begin
  Result := Trim(GetEnvironmentVariable('FAFAFA_WINSSL_SESSION_HOST'));
  if Result = '' then
    Result := 'www.cloudflare.com';
end;

function ResolveIterationCount: Integer;
begin
  Result := StrToIntDef(Trim(GetEnvironmentVariable('FAFAFA_WINSSL_BENCH_ITERATIONS')), 50);
  if Result < 1 then
    Result := 1;
end;

function SafePercentage(ANumerator, ADenominator: Integer): Double;
begin
  if ADenominator <= 0 then
    Exit(0.0);
  Result := (ANumerator * 100.0) / ADenominator;
end;

procedure NormalizeMetrics(var AMetrics: TSessionReuseMetrics);
begin
  if AMetrics.WithoutSessionReuse.SuccessCount = 0 then
  begin
    AMetrics.WithoutSessionReuse.MinTime := 0;
    AMetrics.WithoutSessionReuse.MaxTime := 0;
  end;

  if AMetrics.WithSessionReuse.SuccessCount = 0 then
  begin
    AMetrics.WithSessionReuse.MinTime := 0;
    AMetrics.WithSessionReuse.MaxTime := 0;
  end;

  if (AMetrics.WithoutSessionReuse.AvgTime > 0) and
     (AMetrics.WithSessionReuse.AvgTime > 0) then
    AMetrics.ImprovementPercent :=
      ((AMetrics.WithoutSessionReuse.AvgTime - AMetrics.WithSessionReuse.AvgTime) /
       AMetrics.WithoutSessionReuse.AvgTime) * 100
  else
    AMetrics.ImprovementPercent := 0;
end;

procedure MergeMetrics(var ADest: TSessionReuseMetrics; const ASource: TSessionReuseMetrics);
begin
  if (ASource.WithoutSessionReuse.AttemptCount > 0) or
     (ASource.WithoutSessionReuse.SuccessCount > 0) then
    ADest.WithoutSessionReuse := ASource.WithoutSessionReuse;

  if (ASource.WithSessionReuse.AttemptCount > 0) or
     (ASource.WithSessionReuse.SuccessCount > 0) or
     (ASource.WithSessionReuse.SessionConfiguredCount > 0) or
     (ASource.WithSessionReuse.ObservedReuseCount > 0) then
    ADest.WithSessionReuse := ASource.WithSessionReuse;

  NormalizeMetrics(ADest);
end;

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

function BenchmarkWithoutSessionReuse(const aHost: string; aIterations: Integer): TSessionReuseMetrics;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LSocket: TSocket;
  i: Integer;
  LStart, LEnd: Int64;
  LTime: Double;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.WithoutSessionReuse.AttemptCount := aIterations;
  Result.WithoutSessionReuse.MinTime := MaxDouble;
  Result.WithoutSessionReuse.MaxTime := 0;

  WriteLn('【测试 1】无 Session 复用 - 每次完整握手');
  WriteLn('测试服务器: ', aHost);
  WriteLn('迭代次数: ', aIterations);
  WriteLn('---');

  LLib := CreateWinSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('错误: 无法初始化 WinSSL');
    Exit;
  end;

  for i := 1 to aIterations do
  begin
    LSocket := INVALID_SOCKET;

    // 每次创建新的 Context（不复用凭据）
    LContext := LLib.CreateContext(sslCtxClient);
    LContext.SetProtocolVersions([sslProtocolTLS12]);
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

        Inc(Result.WithoutSessionReuse.SuccessCount);
        Result.WithoutSessionReuse.TotalTime += LTime;

        if LTime < Result.WithoutSessionReuse.MinTime then
          Result.WithoutSessionReuse.MinTime := LTime;
        if LTime > Result.WithoutSessionReuse.MaxTime then
          Result.WithoutSessionReuse.MaxTime := LTime;

        LConn.Shutdown;
      end;

      closesocket(LSocket);
    end;

    if (i mod 10 = 0) then
      Write('.');
  end;

  WriteLn;

  if Result.WithoutSessionReuse.SuccessCount > 0 then
    Result.WithoutSessionReuse.AvgTime := Result.WithoutSessionReuse.TotalTime / Result.WithoutSessionReuse.SuccessCount;
  NormalizeMetrics(Result);

  WriteLn('完成: ', Result.WithoutSessionReuse.SuccessCount, '/', aIterations, ' 次成功');
  WriteLn('平均握手时间: ', Format('%.2f ms', [Result.WithoutSessionReuse.AvgTime]));
  WriteLn;
end;

function BenchmarkWithSessionReuse(const aHost: string; aIterations: Integer): TSessionReuseMetrics;
var
  LLib: ISSLLibrary;
  LContext: ISSLContext;
  LConn: ISSLConnection;
  LResumption: ISSLSessionResumption;
  LSocket: TSocket;
  LSession: ISSLSession;
  i: Integer;
  LStart, LEnd: Int64;
  LTime: Double;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.WithSessionReuse.AttemptCount := aIterations;
  Result.WithSessionReuse.MinTime := MaxDouble;
  Result.WithSessionReuse.MaxTime := 0;

  WriteLn('【测试 2】同 Context + 配置待恢复 Session');
  WriteLn('测试服务器: ', aHost);
  WriteLn('迭代次数: ', aIterations);
  WriteLn('---');

  LLib := CreateWinSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('错误: 无法初始化 WinSSL');
    Exit;
  end;

  // 复用同一个 Context（复用凭据句柄）
  LContext := LLib.CreateContext(sslCtxClient);
  LContext.SetProtocolVersions([sslProtocolTLS12]);
  LContext.SetVerifyMode([]);

  // 首次连接获取 Session
  LSocket := INVALID_SOCKET;
  if ConnectToHost(aHost, 443, LSocket) then
  begin
    LConn := LContext.CreateConnection(LSocket);
    (LConn as ISSLClientConnection).SetServerName(aHost);
    if LConn.Connect then
    begin
      if Supports(LConn, ISSLSessionResumption, LResumption) then
      begin
        LSession := LResumption.GetSession;
        if Assigned(LSession) then
          WriteLn('首次连接成功，保存 Session metadata')
        else
          WriteLn('首次连接成功，但当前未拿到可恢复 Session metadata');
      end
      else
        WriteLn('首次连接成功，但当前连接未暴露 ISSLSessionResumption');
      LConn.Shutdown;
    end;
    closesocket(LSocket);
  end;

  // 后续连接复用 Session
  for i := 1 to aIterations do
  begin
    LSocket := INVALID_SOCKET;

    if ConnectToHost(aHost, 443, LSocket) then
    begin
      LConn := LContext.CreateConnection(LSocket);

      (LConn as ISSLClientConnection).SetServerName(aHost);
      if Supports(LConn, ISSLSessionResumption, LResumption) and
         Assigned(LSession) and LSession.IsValid and LSession.IsResumable then
      begin
        LResumption.SetSession(LSession);
        Inc(Result.WithSessionReuse.SessionConfiguredCount);
      end;

      LStart := GetTimestamp;
      if LConn.Connect then
      begin
        LEnd := GetTimestamp;
        LTime := TimestampToMilliseconds(LStart, LEnd);

        Inc(Result.WithSessionReuse.SuccessCount);
        Result.WithSessionReuse.TotalTime += LTime;

        if LTime < Result.WithSessionReuse.MinTime then
          Result.WithSessionReuse.MinTime := LTime;
        if LTime > Result.WithSessionReuse.MaxTime then
          Result.WithSessionReuse.MaxTime := LTime;

        if Supports(LConn, ISSLSessionResumption, LResumption) and
           LResumption.IsSessionReused then
          Inc(Result.WithSessionReuse.ObservedReuseCount);

        LConn.Shutdown;
      end;

      closesocket(LSocket);
    end;

    if (i mod 10 = 0) then
      Write('.');
  end;

  WriteLn;

  if Result.WithSessionReuse.SuccessCount > 0 then
    Result.WithSessionReuse.AvgTime := Result.WithSessionReuse.TotalTime / Result.WithSessionReuse.SuccessCount;
  NormalizeMetrics(Result);

  WriteLn('完成: ', Result.WithSessionReuse.SuccessCount, '/', aIterations, ' 次成功');
  WriteLn('Session 已配置: ', Result.WithSessionReuse.SessionConfiguredCount, '/', Result.WithSessionReuse.SuccessCount, ' 次 (',
    Format('%.1f%%', [SafePercentage(Result.WithSessionReuse.SessionConfiguredCount,
      Result.WithSessionReuse.SuccessCount)]), ')');
  WriteLn('观测到复用: ', Result.WithSessionReuse.ObservedReuseCount, '/', Result.WithSessionReuse.SuccessCount, ' 次 (',
    Format('%.1f%%', [SafePercentage(Result.WithSessionReuse.ObservedReuseCount,
      Result.WithSessionReuse.SuccessCount)]), ')');
  WriteLn('平均握手时间: ', Format('%.2f ms', [Result.WithSessionReuse.AvgTime]));
  WriteLn;
end;

procedure PrintComparisonReport(const aMetrics: TSessionReuseMetrics);
var
  LImprovement: Double;
begin
  WriteLn('=========================================');
  WriteLn('WinSSL Session 基准对比报告');
  WriteLn('=========================================');
  WriteLn;

  WriteLn('【无 Session 配置（每次新 Context）】');
  WriteLn('  成功连接: ', aMetrics.WithoutSessionReuse.SuccessCount);
  WriteLn('  平均时间: ', Format('%.2f ms', [aMetrics.WithoutSessionReuse.AvgTime]));
  WriteLn('  最小时间: ', Format('%.2f ms', [aMetrics.WithoutSessionReuse.MinTime]));
  WriteLn('  最大时间: ', Format('%.2f ms', [aMetrics.WithoutSessionReuse.MaxTime]));
  WriteLn('  总时间: ', Format('%.2f ms', [aMetrics.WithoutSessionReuse.TotalTime]));
  WriteLn;

  WriteLn('【同 Context + 配置待恢复 Session】');
  WriteLn('  成功连接: ', aMetrics.WithSessionReuse.SuccessCount);
  WriteLn('  Session 已配置: ', aMetrics.WithSessionReuse.SessionConfiguredCount, ' 次 (',
    Format('%.1f%%', [SafePercentage(aMetrics.WithSessionReuse.SessionConfiguredCount,
      aMetrics.WithSessionReuse.SuccessCount)]), ')');
  WriteLn('  观测到复用: ', aMetrics.WithSessionReuse.ObservedReuseCount, ' 次 (',
    Format('%.1f%%', [SafePercentage(aMetrics.WithSessionReuse.ObservedReuseCount,
      aMetrics.WithSessionReuse.SuccessCount)]), ')');
  WriteLn('  平均时间: ', Format('%.2f ms', [aMetrics.WithSessionReuse.AvgTime]));
  WriteLn('  最小时间: ', Format('%.2f ms', [aMetrics.WithSessionReuse.MinTime]));
  WriteLn('  最大时间: ', Format('%.2f ms', [aMetrics.WithSessionReuse.MaxTime]));
  WriteLn('  总时间: ', Format('%.2f ms', [aMetrics.WithSessionReuse.TotalTime]));
  WriteLn;

  if (aMetrics.WithoutSessionReuse.AvgTime > 0) and (aMetrics.WithSessionReuse.AvgTime > 0) then
  begin
    LImprovement := aMetrics.ImprovementPercent;

    WriteLn('【同 Context 延迟差异】');
    WriteLn('  时间减少: ', Format('%.2f ms', [aMetrics.WithoutSessionReuse.AvgTime - aMetrics.WithSessionReuse.AvgTime]));
    WriteLn('  性能提升: ', Format('%.1f%%', [LImprovement]));
    WriteLn;

    if aMetrics.WithSessionReuse.ObservedReuseCount > 0 then
      WriteLn('✓ 当前基准至少观测到了一部分 owner-path reuse 命中；仍应结合目标服务器与 Windows runner 单独复核')
    else if aMetrics.WithSessionReuse.SessionConfiguredCount > 0 then
    begin
      WriteLn('⚠ 当前 conservative truth: observed_reuse=false / session_configured=true');
      WriteLn('  timing delta alone is not proof of native resumed-handshake');
    end
    else
      WriteLn('⚠ 当前没有配置到可恢复 Session，本次只代表 repeated handshake timing');
  end;

  WriteLn('=========================================');
end;

procedure RunSessionReuseBenchmark;
var
  LMetrics: TSessionReuseMetrics;
  LHost: string;
  LIterations: Integer;
begin
  WriteLn('=========================================');
  WriteLn('WinSSL Session 复用性能基准测试');
  WriteLn('测试日期: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  WriteLn('=========================================');
  WriteLn;

  FillChar(LMetrics, SizeOf(LMetrics), 0);
  LHost := ResolveBenchmarkHost;
  LIterations := ResolveIterationCount;

  WriteLn('测试配置:');
  WriteLn('  目标服务器: ', LHost);
  WriteLn('  迭代次数: ', LIterations);
  WriteLn('  协议版本: TLS 1.2');
  WriteLn('  结果解释: 区分 session_configured 与 observed_reuse');
  WriteLn;

  // 测试 1: 无 Session 复用
  MergeMetrics(LMetrics, BenchmarkWithoutSessionReuse(LHost, LIterations));

  // 测试 2: 有 Session 复用
  MergeMetrics(LMetrics, BenchmarkWithSessionReuse(LHost, LIterations));

  // 打印对比报告
  PrintComparisonReport(LMetrics);
end;

begin
  if not QueryPerformanceFrequency(Frequency) then
  begin
    WriteLn('错误: 系统不支持高精度计时器');
    Halt(1);
  end;

  InitWinsock;
  try
    RunSessionReuseBenchmark;
  finally
    CleanupWinsock;
  end;

  WriteLn;
  WriteLn('按回车键退出...');
  ReadLn;
end.

program test_sharded_session_cache;

{$mode objfpc}{$H+}

{**
 * 分片会话缓存测试
 *
 * 测试内容:
 * 1. 基本功能 - Put/Get/Remove
 * 2. 分片分布 - 验证哈希均匀性
 * 3. 并发性能 - 多线程压力测试
 * 4. 过期清理 - 自动过期功能
 *}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes, SyncObjs, DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.session.cache.sharded;

const
  TEST_COUNT = 10000;
  THREAD_COUNT = 8;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFailCount);
  end;
end;

{ 模拟 ISSLSession 用于测试 }
type
  TMockSession = class(TInterfacedObject, ISSLSession)
  private
    FID: string;
    FValid: Boolean;
    FTimeout: Integer;
    FCreationTime: TDateTime;
  public
    constructor Create(const AID: string);

    // ISSLSession 方法
    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;
    function GetNativeHandle: Pointer;
    function Clone: ISSLSession;
  end;

constructor TMockSession.Create(const AID: string);
begin
  inherited Create;
  FID := AID;
  FValid := True;
  FTimeout := 300;
  FCreationTime := Now;
end;

function TMockSession.GetID: string;
begin
  Result := FID;
end;

function TMockSession.GetCreationTime: TDateTime;
begin
  Result := FCreationTime;
end;

function TMockSession.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TMockSession.SetTimeout(ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

function TMockSession.IsValid: Boolean;
begin
  Result := FValid;
end;

function TMockSession.IsResumable: Boolean;
begin
  Result := True;
end;

function TMockSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := sslProtocolTLS12;
end;

function TMockSession.GetCipherName: string;
begin
  Result := 'TLS_AES_256_GCM_SHA384';
end;

function TMockSession.GetPeerCertificate: ISSLCertificate;
begin
  Result := nil;
end;

function TMockSession.Serialize: TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(FID);
end;

function TMockSession.Deserialize(const AData: TBytes): Boolean;
begin
  FID := TEncoding.UTF8.GetString(AData);
  Result := True;
end;

function TMockSession.GetNativeHandle: Pointer;
begin
  Result := nil;
end;

function TMockSession.Clone: ISSLSession;
begin
  Result := TMockSession.Create(FID);
end;

{ 测试 1: 基本功能 }
procedure TestBasicFunctionality;
var
  Cache: TShardedSessionCache;
  Session1, Session2, Retrieved: ISSLSession;
begin
  WriteLn('=== Test 1: Basic Functionality ===');

  Cache := TShardedSessionCache.Create;
  try
    // 创建测试会话
    Session1 := TMockSession.Create('session-001');
    Session2 := TMockSession.Create('session-002');

    // Put
    Cache.Put('example.com', 443, Session1);
    Cache.Put('test.org', 8443, Session2);
    Check('Put sessions', Cache.GetTotalCount = 2);

    // Get
    Retrieved := Cache.Get('example.com', 443);
    Check('Get existing session', Retrieved <> nil);
    Check('Get correct session', (Retrieved <> nil) and (Retrieved.GetID = 'session-001'));

    // Get non-existent
    Retrieved := Cache.Get('nonexistent.com', 443);
    Check('Get non-existent returns nil', Retrieved = nil);

    // Contains
    Check('Contains existing', Cache.Contains('example.com', 443));
    Check('Contains non-existent', not Cache.Contains('nonexistent.com', 443));

    // Remove
    Check('Remove existing', Cache.Remove('example.com', 443));
    Check('After remove count', Cache.GetTotalCount = 1);
    Check('Removed not found', not Cache.Contains('example.com', 443));

    // Clear
    Cache.Clear;
    Check('After clear count', Cache.GetTotalCount = 0);

  finally
    Cache.Free;
  end;
end;

{ 测试 2: 分片分布 }
procedure TestShardDistribution;
var
  Cache: TShardedSessionCache;
  Stats: TShardedCacheStats;
  I: Integer;
  Session: ISSLSession;
  MinCount, MaxCount: Integer;
  Variance: Double;
begin
  WriteLn('');
  WriteLn('=== Test 2: Shard Distribution ===');

  Cache := TShardedSessionCache.Create(1000, 300);
  try
    // 插入大量会话
    for I := 1 to TEST_COUNT do
    begin
      Session := TMockSession.Create('session-' + IntToStr(I));
      Cache.Put('host' + IntToStr(I) + '.example.com', 443, Session);
    end;

    Stats := Cache.GetStats;
    Check('Total count matches', Stats.TotalSessions = TEST_COUNT);

    // 检查分布均匀性
    WriteLn('  Shard distribution:');
    MinCount := Stats.ShardDistribution[0];
    MaxCount := Stats.ShardDistribution[0];

    for I := 0 to SHARD_COUNT - 1 do
    begin
      if Stats.ShardDistribution[I] < MinCount then
        MinCount := Stats.ShardDistribution[I];
      if Stats.ShardDistribution[I] > MaxCount then
        MaxCount := Stats.ShardDistribution[I];
      Write('    [', I:2, ']: ', Stats.ShardDistribution[I]:4);
      if (I + 1) mod 4 = 0 then WriteLn;
    end;

    // 期望每个分片约 625 个 (10000/16)
    // 允许 ±50% 方差
    Variance := (MaxCount - MinCount) / (TEST_COUNT / SHARD_COUNT);
    WriteLn('  Min: ', MinCount, ', Max: ', MaxCount, ', Variance: ', Variance:0:2);
    Check('Distribution variance < 100%', Variance < 1.0);

  finally
    Cache.Free;
  end;
end;

{ 测试 3: 并发性能 }
type
  TConcurrentTestThread = class(TThread)
  private
    FCache: TShardedSessionCache;
    FStartIndex: Integer;
    FCount: Integer;
    FOperations: Int64;
  protected
    procedure Execute; override;
  public
    constructor Create(ACache: TShardedSessionCache; AStartIndex, ACount: Integer);
    property Operations: Int64 read FOperations;
  end;

constructor TConcurrentTestThread.Create(ACache: TShardedSessionCache;
  AStartIndex, ACount: Integer);
begin
  inherited Create(True);
  FCache := ACache;
  FStartIndex := AStartIndex;
  FCount := ACount;
  FOperations := 0;
  FreeOnTerminate := False;
end;

procedure TConcurrentTestThread.Execute;
var
  I: Integer;
  Session: ISSLSession;
  Host: string;
begin
  for I := FStartIndex to FStartIndex + FCount - 1 do
  begin
    Host := 'host' + IntToStr(I) + '.test.com';

    // Put
    Session := TMockSession.Create('thread-session-' + IntToStr(I));
    FCache.Put(Host, 443, Session);
    Inc(FOperations);

    // Get
    Session := FCache.Get(Host, 443);
    Inc(FOperations);
  end;
end;

procedure TestConcurrentPerformance;
var
  Cache: TShardedSessionCache;
  Threads: array[0..THREAD_COUNT-1] of TConcurrentTestThread;
  I: Integer;
  StartTime, EndTime: TDateTime;
  TotalOps: Int64;
  OpsPerSec: Double;
  PerThread: Integer;
begin
  WriteLn('');
  WriteLn('=== Test 3: Concurrent Performance ===');

  Cache := TShardedSessionCache.Create(10000, 300);
  try
    PerThread := TEST_COUNT div THREAD_COUNT;

    // 创建线程
    for I := 0 to THREAD_COUNT - 1 do
      Threads[I] := TConcurrentTestThread.Create(Cache, I * PerThread, PerThread);

    StartTime := Now;

    // 启动所有线程
    for I := 0 to THREAD_COUNT - 1 do
      Threads[I].Start;

    // 等待完成
    for I := 0 to THREAD_COUNT - 1 do
      Threads[I].WaitFor;

    EndTime := Now;

    // 计算总操作数
    TotalOps := 0;
    for I := 0 to THREAD_COUNT - 1 do
    begin
      TotalOps := TotalOps + Threads[I].Operations;
      Threads[I].Free;
    end;

    OpsPerSec := TotalOps / (MilliSecondsBetween(EndTime, StartTime) / 1000);

    WriteLn('  Threads: ', THREAD_COUNT);
    WriteLn('  Total operations: ', TotalOps);
    WriteLn('  Duration: ', MilliSecondsBetween(EndTime, StartTime), ' ms');
    WriteLn('  Throughput: ', OpsPerSec:0:0, ' ops/s');

    Check('Concurrent operations completed', TotalOps = TEST_COUNT * 2);
    Check('Throughput > 50K ops/s', OpsPerSec > 50000);

  finally
    Cache.Free;
  end;
end;

{ 测试 4: 统计功能 }
procedure TestStatistics;
var
  Cache: TShardedSessionCache;
  Stats: TShardedCacheStats;
  I: Integer;
  Session: ISSLSession;
begin
  WriteLn('');
  WriteLn('=== Test 4: Statistics ===');

  Cache := TShardedSessionCache.Create;
  try
    // 插入一些会话
    for I := 1 to 100 do
    begin
      Session := TMockSession.Create('session-' + IntToStr(I));
      Cache.Put('host' + IntToStr(I) + '.com', 443, Session);
    end;

    // 命中一些
    for I := 1 to 50 do
      Cache.Get('host' + IntToStr(I) + '.com', 443);

    // 未命中一些
    for I := 101 to 150 do
      Cache.Get('host' + IntToStr(I) + '.com', 443);

    Stats := Cache.GetStats;

    WriteLn('  Total sessions: ', Stats.TotalSessions);
    WriteLn('  Total hits: ', Stats.TotalHits);
    WriteLn('  Total misses: ', Stats.TotalMisses);
    WriteLn('  Hit rate: ', Stats.HitRate:0:1, '%');
    WriteLn('  Hottest shard: ', Stats.GetHottestShard);
    WriteLn('  Coldest shard: ', Stats.GetColdestShard);

    Check('Stats total sessions', Stats.TotalSessions = 100);
    Check('Stats hits counted', Stats.TotalHits = 50);
    Check('Stats misses counted', Stats.TotalMisses = 50);
    Check('Hit rate calculation', Abs(Stats.HitRate - 50.0) < 1.0);

  finally
    Cache.Free;
  end;
end;

{ 主程序 }
begin
  WriteLn('╔════════════════════════════════════════════════════════╗');
  WriteLn('║  Sharded Session Cache Test Suite                      ║');
  WriteLn('║  Phase 2: Lock-Free Concurrency Optimization           ║');
  WriteLn('╚════════════════════════════════════════════════════════╝');
  WriteLn;

  TestBasicFunctionality;
  TestShardDistribution;
  TestConcurrentPerformance;
  TestStatistics;

  WriteLn;
  WriteLn('========================================');
  WriteLn('  Test Summary');
  WriteLn('========================================');
  WriteLn('Passed: ', GPassCount);
  WriteLn('Failed: ', GFailCount);
  WriteLn('Total:  ', GPassCount + GFailCount);
  WriteLn;

  if GFailCount = 0 then
    WriteLn('All tests passed!')
  else
    WriteLn('Some tests failed.');
end.

{**
 * Unit: nextpas.core.tls.random.pool
 * Purpose: 高性能随机数缓存池实现
 *
 * Phase B 性能优化：通过批量生成和缓存随机数来减少系统调用开销
 *
 * 性能目标：
 * - 当前性能：111,111 ops/s @ 1KB
 * - 目标性能：222,222 - 555,555 ops/s (2-5倍提升)
 *
 * 设计原则：
 * - 线程安全：使用 TCriticalSection 保护共享状态
 * - 安全性：定期重填，避免可预测性
 * - 可配置：支持启用/禁用优化
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-21
 * @phase Phase B - Performance Optimization
 *}

unit nextpas.core.tls.random.pool;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils, Classes, SyncObjs;

const
  { 默认配置 }
  DEFAULT_POOL_SIZE = 8192;        // 8KB 缓存池大小
  DEFAULT_REFILL_THRESHOLD = 1024; // 当剩余 < 1KB 时重填
  DEFAULT_MAX_REQUEST_SIZE = 4096; // 单次请求最大 4KB（超过则直接生成）

type
  {**
   * 随机数缓存池配置
   *}
  TRandomPoolConfig = record
    Enabled: Boolean;              // 是否启用缓存池优化
    PoolSize: Integer;             // 缓存池大小（字节）
    RefillThreshold: Integer;      // 重填阈值（字节）
    MaxRequestSize: Integer;       // 单次请求最大大小（字节）

    class function Default: TRandomPoolConfig; static;
  end;

  {**
   * 随机数缓存池统计信息
   *}
  TRandomPoolStats = record
    TotalRequests: Int64;          // 总请求次数
    CacheHits: Int64;              // 缓存命中次数
    CacheMisses: Int64;            // 缓存未命中次数
    RefillCount: Int64;            // 重填次数
    BytesServed: Int64;            // 已服务字节数
    BytesGenerated: Int64;         // 已生成字节数

    function HitRate: Double;      // 缓存命中率（百分比）
  end;

  {**
   * 随机数缓存池
   *
   * 线程安全的随机数缓存池实现，通过批量生成和缓存随机数
   * 来减少系统调用开销，提升性能 2-5 倍。
   *}
  TRandomPool = class
  private
    FConfig: TRandomPoolConfig;
    FLock: TCriticalSection;
    FBuffer: array of Byte;
    FPosition: Integer;            // 当前读取位置
    FAvailable: Integer;           // 可用字节数
    FStats: TRandomPoolStats;
    FInitialized: Boolean;

    { 从底层随机数生成器填充缓冲区 }
    function RefillBuffer: Boolean;

    { 检查是否需要重填 }
    function NeedsRefill(ARequestSize: Integer): Boolean;

  public
    constructor Create(const AConfig: TRandomPoolConfig);
    destructor Destroy; override;

    {**
     * 从缓存池获取随机字节
     * @param ABuffer 输出缓冲区
     * @param ACount 请求字节数
     * @return True 成功，False 失败
     *}
    function GetBytes(ABuffer: PByte; ACount: Integer): Boolean;

    {**
     * 获取统计信息
     *}
    function GetStats: TRandomPoolStats;

    {**
     * 重置统计信息
     *}
    procedure ResetStats;

    {**
     * 强制重填缓冲区（用于测试）
     *}
    procedure ForceRefill;
  end;

{**
 * 获取全局随机数缓存池实例
 *}
function GetGlobalRandomPool: TRandomPool;

{**
 * 配置全局随机数缓存池
 *}
procedure ConfigureGlobalRandomPool(const AConfig: TRandomPoolConfig);

{**
 * 从缓存池获取随机字节（便捷函数）
 *}
function PooledRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;

implementation

uses
  nextpas.core.tls.random;  // 使用底层随机数生成器

var
  GGlobalPool: TRandomPool = nil;
  GGlobalPoolLock: TCriticalSection = nil;

{ TRandomPoolConfig }

class function TRandomPoolConfig.Default: TRandomPoolConfig;
begin
  Result.Enabled := True;
  Result.PoolSize := DEFAULT_POOL_SIZE;
  Result.RefillThreshold := DEFAULT_REFILL_THRESHOLD;
  Result.MaxRequestSize := DEFAULT_MAX_REQUEST_SIZE;
end;

{ TRandomPoolStats }

function TRandomPoolStats.HitRate: Double;
begin
  if TotalRequests = 0 then
    Result := 0.0
  else
    Result := (CacheHits / TotalRequests) * 100.0;
end;

{ TRandomPool }

constructor TRandomPool.Create(const AConfig: TRandomPoolConfig);
begin
  inherited Create;

  FConfig := AConfig;
  FLock := TCriticalSection.Create;
  SetLength(FBuffer, FConfig.PoolSize);
  FPosition := 0;
  FAvailable := 0;
  FillChar(FStats, SizeOf(FStats), 0);
  FInitialized := False;

  // 初始填充
  if FConfig.Enabled then
    FInitialized := RefillBuffer;
end;

destructor TRandomPool.Destroy;
begin
  // 清零敏感数据
  if Length(FBuffer) > 0 then
    FillChar(FBuffer[0], Length(FBuffer), 0);
  SetLength(FBuffer, 0);

  FLock.Free;
  inherited Destroy;
end;

function TRandomPool.RefillBuffer: Boolean;
begin
  Result := False;

  // 使用底层随机数生成器填充整个缓冲区
  if not SecureRandomBytes(@FBuffer[0], FConfig.PoolSize) then
    Exit;

  FPosition := 0;
  FAvailable := FConfig.PoolSize;
  Inc(FStats.RefillCount);
  Inc(FStats.BytesGenerated, FConfig.PoolSize);

  Result := True;
end;

function TRandomPool.NeedsRefill(ARequestSize: Integer): Boolean;
begin
  Result := FAvailable < FConfig.RefillThreshold;
end;

function TRandomPool.GetBytes(ABuffer: PByte; ACount: Integer): Boolean;
var
  LBytesToCopy: Integer;
begin
  Result := False;

  if (ABuffer = nil) or (ACount <= 0) then
    Exit;

  Inc(FStats.TotalRequests);

  // 如果未启用缓存池或请求过大，直接使用底层生成器
  if not FConfig.Enabled or (ACount > FConfig.MaxRequestSize) then
  begin
    Inc(FStats.CacheMisses);
    Inc(FStats.BytesGenerated, ACount);
    Result := SecureRandomBytes(ABuffer, ACount);
    if Result then
      Inc(FStats.BytesServed, ACount);
    Exit;
  end;

  FLock.Acquire;
  try
    // 检查是否需要重填
    if NeedsRefill(ACount) then
    begin
      if not RefillBuffer then
        Exit;
    end;

    // 如果缓存不足以满足请求，直接生成
    if ACount > FAvailable then
    begin
      Inc(FStats.CacheMisses);
      Inc(FStats.BytesGenerated, ACount);
      Result := SecureRandomBytes(ABuffer, ACount);
      if Result then
        Inc(FStats.BytesServed, ACount);
      Exit;
    end;

    // 从缓存复制数据
    LBytesToCopy := ACount;
    Move(FBuffer[FPosition], ABuffer^, LBytesToCopy);
    Inc(FPosition, LBytesToCopy);
    Dec(FAvailable, LBytesToCopy);

    Inc(FStats.CacheHits);
    Inc(FStats.BytesServed, LBytesToCopy);

    Result := True;
  finally
    FLock.Release;
  end;
end;

function TRandomPool.GetStats: TRandomPoolStats;
begin
  FLock.Acquire;
  try
    Result := FStats;
  finally
    FLock.Release;
  end;
end;

procedure TRandomPool.ResetStats;
begin
  FLock.Acquire;
  try
    FillChar(FStats, SizeOf(FStats), 0);
  finally
    FLock.Release;
  end;
end;

procedure TRandomPool.ForceRefill;
begin
  FLock.Acquire;
  try
    RefillBuffer;
  finally
    FLock.Release;
  end;
end;

{ 全局函数 }

function GetGlobalRandomPool: TRandomPool;
begin
  if GGlobalPool = nil then
  begin
    if GGlobalPoolLock = nil then
      GGlobalPoolLock := TCriticalSection.Create;

    GGlobalPoolLock.Acquire;
    try
      if GGlobalPool = nil then
        GGlobalPool := TRandomPool.Create(TRandomPoolConfig.Default);
    finally
      GGlobalPoolLock.Release;
    end;
  end;

  Result := GGlobalPool;
end;

procedure ConfigureGlobalRandomPool(const AConfig: TRandomPoolConfig);
begin
  if GGlobalPoolLock = nil then
    GGlobalPoolLock := TCriticalSection.Create;

  GGlobalPoolLock.Acquire;
  try
    if GGlobalPool <> nil then
    begin
      GGlobalPool.Free;
      GGlobalPool := nil;
    end;

    GGlobalPool := TRandomPool.Create(AConfig);
  finally
    GGlobalPoolLock.Release;
  end;
end;

function PooledRandomBytes(ABuffer: PByte; ACount: Integer): Boolean;
begin
  Result := GetGlobalRandomPool.GetBytes(ABuffer, ACount);
end;

initialization

finalization
  if GGlobalPool <> nil then
  begin
    GGlobalPool.Free;
    GGlobalPool := nil;
  end;

  if GGlobalPoolLock <> nil then
  begin
    GGlobalPoolLock.Free;
    GGlobalPoolLock := nil;
  end;

end.

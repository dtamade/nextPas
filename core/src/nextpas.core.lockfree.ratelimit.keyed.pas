unit nextpas.core.lockfree.ratelimit.keyed;

{** @desc 按 key 隔离的令牌桶限流表（Keyed Token Bucket Rate Limiter Table）
  @details 每个 string key（如客户端地址/API key/租户）持有独立令牌桶，
    桶参数（rate/burst）全局统一：以恒定速率生成令牌，请求消耗 1 个令牌。
    可选冷却窗（ACooldownSeconds > 0）：拒绝后该 key 在冷却期内必拒，
    Retry-After 返回剩余冷却秒数——防止被限流客户端以令牌恢复节奏持续空耗
    （对齐常见网关限流的 per-profile cooldown 语义）。默认 0 = 纯令牌桶
    （向后兼容）。桶按 key 惰性创建，表有界（LRU 驱逐最久未用 key，
    驱逐重建即满桶）。
    典型用途：per-address/per-tenant HTTP 读路径限速、429 + Retry-After 整形。
  @design 与单桶 TTokenBucketLimiter 互补：单桶无 key 概念，本表解决
    「按 key 隔离 + 有界」组合；refill 按单调时钟惰性计算（无后台线程），
    时钟源可注入（测试推进假时钟验证恢复语义，不依赖真实 sleep）；
    冷却截止时间戳与桶状态同锁保护、同一平行数组布局，零额外分配。
  @concurrency Thread-safe：互斥锁保护桶表，临界区 = 线性查找 + 桶内算术（μs 级）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync;

type
  { 单调时钟源（纳秒）；默认 platform_monotonic_ns，测试注入假时钟。 }
  TKeyedNowNsFn = reference to function: UInt64;

  {** @desc 按 key 隔离的有界令牌桶限流表（线程安全）。 }
  TKeyedTokenBucketLimiter = class
  private
    FRate: Double;
    FBurst: Double;
    FCooldownNs: UInt64;
    FMaxKeys: Integer;
    FNowNs: TKeyedNowNsFn;
    FLock: INativeMutex;
    FKeys: array of string;
    FTokens: array of Double;
    FLastRefillNs: array of UInt64;
    FLastUsedNs: array of UInt64;
    { 冷却截止时间戳（ns）；0 = 不在冷却期。与桶状态同锁同布局。 }
    FDeniedUntilNs: array of UInt64;
    { 线性查找；miss 时新建（满则驱逐最久未用 key）。返回 -1 仅当表满且
      驱逐候选缺失（理论不可达，调用侧放行优先于误伤）。 }
    function FindOrCreate(const AKey: string; const ANowNs: UInt64): Integer;
  public
    { ARatePerSecond：每秒补充令牌数；ABurst：桶容量（突发上限）；
      ACooldownSeconds：拒绝后冷却秒数（0 = 关闭，默认向后兼容）；
      AMaxKeys：桶表容量上限（防 key 风暴，LRU 驱逐最久未用）；
      ANowNs：时钟源（默认 platform_monotonic_ns）。 }
    constructor Create(const ARatePerSecond: Double; const ABurst: Double;
      const AMaxKeys: Integer = 4096; const ANowNs: TKeyedNowNsFn = nil;
      const ACooldownSeconds: Int64 = 0);
    destructor Destroy; override;
    { 取 1 个令牌；拒绝时 ARetryAfterSeconds >= 1（供 Retry-After 头）。
      空 key 恒放行且不计费（调用方负责 key 规范化，如小写地址）。 }
    function TryAcquire(const AKey: string; out ARetryAfterSeconds: Int64): Boolean;
    { 清空全部桶（测试/热重载）。 }
    procedure Reset;
    { 当前桶数（观测/测试）。 }
    function KeyCount: Integer; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math,
  nextpas.core.platform.time;   { platform_monotonic_ns }

function DefaultNowNs: UInt64;
begin
  Result := platform_monotonic_ns;
end;

constructor TKeyedTokenBucketLimiter.Create(const ARatePerSecond: Double;
  const ABurst: Double; const AMaxKeys: Integer; const ANowNs: TKeyedNowNsFn;
  const ACooldownSeconds: Int64);
begin
  inherited Create;
  if IsNaN(ARatePerSecond) or IsInfinite(ARatePerSecond) or
     (ARatePerSecond <= 0) then
    raise EArgumentError.Create('keyed token bucket: rate must be > 0');
  if IsNaN(ABurst) or IsInfinite(ABurst) or (ABurst <= 0) then
    raise EArgumentError.Create('keyed token bucket: burst must be > 0');
  if AMaxKeys < 1 then
    raise EArgumentError.Create('keyed token bucket: max keys must be >= 1');
  if ACooldownSeconds < 0 then
    raise EArgumentError.Create('keyed token bucket: cooldown must be >= 0');
  FRate := ARatePerSecond;
  FBurst := ABurst;
  FCooldownNs := UInt64(ACooldownSeconds) * 1000000000;
  FMaxKeys := AMaxKeys;
  if ANowNs = nil then
    FNowNs := @DefaultNowNs
  else
    FNowNs := ANowNs;
  FLock := Mutex;
end;

destructor TKeyedTokenBucketLimiter.Destroy;
begin
  FKeys := nil;
  FTokens := nil;
  FLastRefillNs := nil;
  FLastUsedNs := nil;
  FDeniedUntilNs := nil;
  FNowNs := nil;
  FLock := nil;
  inherited Destroy;
end;

function TKeyedTokenBucketLimiter.FindOrCreate(const AKey: string;
  const ANowNs: UInt64): Integer;
var
  LI, LEvict: Integer;
begin
  Result := -1;
  LEvict := -1;
  for LI := 0 to High(FKeys) do
  begin
    if FKeys[LI] = AKey then
      Exit(LI);
    if (LEvict < 0) or (FLastUsedNs[LI] < FLastUsedNs[LEvict]) then
      LEvict := LI;
  end;
  if Length(FKeys) >= FMaxKeys then
  begin
    if LEvict < 0 then
      Exit;
    Result := LEvict;
  end
  else
  begin
    SetLength(FKeys, Length(FKeys) + 1);
    SetLength(FTokens, Length(FTokens) + 1);
    SetLength(FLastRefillNs, Length(FLastRefillNs) + 1);
    SetLength(FLastUsedNs, Length(FLastUsedNs) + 1);
    SetLength(FDeniedUntilNs, Length(FDeniedUntilNs) + 1);
    Result := High(FKeys);
  end;
  FKeys[Result] := AKey;
  FTokens[Result] := FBurst;
  FLastRefillNs[Result] := ANowNs;
  FLastUsedNs[Result] := ANowNs;
  FDeniedUntilNs[Result] := 0;
end;

function TKeyedTokenBucketLimiter.TryAcquire(const AKey: string;
  out ARetryAfterSeconds: Int64): Boolean;
var
  LNow: UInt64;
  LIdx: Integer;
  LElapsed, LWait: Double;
begin
  Result := True;
  ARetryAfterSeconds := 0;
  if AKey = '' then
    Exit;
  LNow := FNowNs();
  FLock.Acquire;
  try
    LIdx := FindOrCreate(AKey, LNow);
    if LIdx < 0 then
      Exit;
    { 惰性 refill：自上次起按速率补充；时钟回退（不前进）不扣令牌。 }
    if LNow > FLastRefillNs[LIdx] then
    begin
      LElapsed := (LNow - FLastRefillNs[LIdx]) / 1000000000.0;
      FTokens[LIdx] := FTokens[LIdx] + LElapsed * FRate;
      if FTokens[LIdx] > FBurst then
        FTokens[LIdx] := FBurst;
      FLastRefillNs[LIdx] := LNow;
    end;
    { 冷却窗（F-11）：上次拒绝后的冷却期内必拒，Retry-After = 剩余冷却；
      期满后照常走令牌判定（成功不清除——截止时间已过自然失效）。 }
    if (LNow < FDeniedUntilNs[LIdx]) then
    begin
      LWait := (FDeniedUntilNs[LIdx] - LNow) / 1000000000.0;
      ARetryAfterSeconds := Ceil(LWait);
      if ARetryAfterSeconds < 1 then
        ARetryAfterSeconds := 1;
      Result := False;
      Exit;
    end;
    if FTokens[LIdx] >= 1.0 then
    begin
      FTokens[LIdx] := FTokens[LIdx] - 1.0;
      FLastUsedNs[LIdx] := LNow;
    end
    else
    begin
      { 拒绝：不足 1 个令牌，等待补充到 1 个所需秒数（向上取整）；
        开启冷却窗时取两者较大值（强制歇满冷却，对齐 cooldown 语义）。 }
      LWait := (1.0 - FTokens[LIdx]) / FRate;
      ARetryAfterSeconds := Ceil(LWait);
      if FCooldownNs > 0 then
      begin
        FDeniedUntilNs[LIdx] := LNow + FCooldownNs;
        if ARetryAfterSeconds < Int64(FCooldownNs div 1000000000) then
          ARetryAfterSeconds := Int64(FCooldownNs div 1000000000);
      end;
      if ARetryAfterSeconds < 1 then
        ARetryAfterSeconds := 1;
      Result := False;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TKeyedTokenBucketLimiter.Reset;
begin
  FLock.Acquire;
  try
    FKeys := nil;
    FTokens := nil;
    FLastRefillNs := nil;
    FLastUsedNs := nil;
    FDeniedUntilNs := nil;
  finally
    FLock.Release;
  end;
end;

function TKeyedTokenBucketLimiter.KeyCount: Integer;
begin
  FLock.Acquire;
  try
    Result := Length(FKeys);
  finally
    FLock.Release;
  end;
end;

end.
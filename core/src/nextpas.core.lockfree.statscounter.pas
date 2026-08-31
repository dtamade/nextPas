unit nextpas.core.lockfree.statscounter;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

type
  {** @desc 并发统计计数器
    @details 支持 min/max/sum/count/mean 的并发统计。
      - 所有操作原子化
      - 支持 Reset
      - 适用场景：性能监控、指标收集、延迟统计
  }
  TConcurrentStatsCounter = class
  private
    FCount: Int64;
    FSum: Int64;
    FMin: Int64;
    FMax: Int64;
  public
    constructor Create;
    destructor Destroy; override;

    {** 记录一个值 }
    procedure RecordValue(AValue: Int64);
    {** 获取样本数量 }
    function Count: Int64; inline;
    {** 获取总和 }
    function Sum: Int64; inline;
    {** 获取最小值 }
    function Min: Int64; inline;
    {** 获取最大值 }
    function Max: Int64; inline;
    {** 获取均值 (Sum div Count) }
    function Mean: Int64;
    {** 重置所有统计 }
    procedure Reset;
  end;

implementation

constructor TConcurrentStatsCounter.Create;
begin
  inherited Create;
  FCount := 0;
  FSum := 0;
  FMin := High(Int64);
  FMax := Low(Int64);
end;

destructor TConcurrentStatsCounter.Destroy;
begin
  inherited Destroy;
end;

procedure TConcurrentStatsCounter.RecordValue(AValue: Int64);
var
  LOldMin, LNewMin, LOldMax, LNewMax: Int64;
begin
  atomic_fetch_add_64(FCount, 1);
  atomic_fetch_add_64(FSum, AValue);
  // Update min with CAS loop
  repeat
    LOldMin := atomic_load_64(FMin, mo_relaxed);
    if AValue >= LOldMin then
      Break;
    LNewMin := AValue;
  until atomic_compare_exchange_strong_64(FMin, LOldMin, LNewMin, mo_acq_rel, mo_acquire);
  // Update max with CAS loop
  repeat
    LOldMax := atomic_load_64(FMax, mo_relaxed);
    if AValue <= LOldMax then
      Break;
    LNewMax := AValue;
  until atomic_compare_exchange_strong_64(FMax, LOldMax, LNewMax, mo_acq_rel, mo_acquire);
end;

function TConcurrentStatsCounter.Count: Int64; inline;
begin
  Result := atomic_load_64(FCount, mo_relaxed);
end;

function TConcurrentStatsCounter.Sum: Int64; inline;
begin
  Result := atomic_load_64(FSum, mo_relaxed);
end;

function TConcurrentStatsCounter.Min: Int64; inline;
begin
  Result := atomic_load_64(FMin, mo_relaxed);
  if Result = High(Int64) then
    Result := 0;
end;

function TConcurrentStatsCounter.Max: Int64; inline;
begin
  Result := atomic_load_64(FMax, mo_relaxed);
  if Result = Low(Int64) then
    Result := 0;
end;

function TConcurrentStatsCounter.Mean: Int64;
var
  LCount: Int64;
begin
  LCount := atomic_load_64(FCount, mo_relaxed);
  if LCount = 0 then
    Exit(0);
  Result := atomic_load_64(FSum, mo_relaxed) div LCount;
end;

procedure TConcurrentStatsCounter.Reset;
begin
  atomic_store_64(FCount, 0, mo_release);
  atomic_store_64(FSum, 0, mo_release);
  atomic_store_64(FMin, High(Int64), mo_release);
  atomic_store_64(FMax, Low(Int64), mo_release);
end;

end.

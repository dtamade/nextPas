{******************************************************************************
  nextpas.core.lockfree.timeseries_ringbuffer

  Time Series Ring Buffer — ring buffer with time-series features.

  Design:
  - Fixed-size circular buffer with monotonic timestamps
  - Each entry has a timestamp for time-range queries
  - TTL-based auto-expiration (entries older than TTL are overwritten)
  - Supports range queries: entries between T1 and T2
  - Spin lock for thread safety

  Use cases: metrics collection, log buffering, monitoring, rate limiting.

  2026-07-06  Phase 5
******************************************************************************}
unit nextpas.core.lockfree.timeseries_ringbuffer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors;

const
  TSRING_DEFAULT_CAPACITY = 1024;
  TSRING_DEFAULT_TTL_MS = 300000; { 5 minutes }

type
  TTSRingResult = (
    tsrOk,
    tsrFull,
    tsrEmpty,
    tsrNotFound
  );

  TTSRingEntry = record
    Timestamp: Int64; { monotonic ms }
    ExpiresAt: Int64; { 0 = never expires }
    Value: AnsiString;
  end;

  {**
   * Time Series Ring Buffer — 时间序列环形缓冲区。
   *
   * 固定容量的环形缓冲区，每个条目带时间戳。
   * 支持 TTL 过期、时间范围查询。
   *
   * @constraints
   *   - 容量在创建时固定
   *   - 使用 spin lock 保证线程安全
   *   - 时间戳基于单调时钟
   *}
  TTimeSeriesRingBuffer = class
  private
    FBuffer: array of TTSRingEntry;
    FCapacity: Int32;
    FHead: Int32; { next write position }
    FCount: Int32; { current entry count }
    FDefaultTTL: Int64;
    FLock: Int32;

    function GetNowMs: Int64;
    procedure Lock; inline;
    procedure Unlock; inline;
    function WrapIdx(AIdx: Int32): Int32; inline;
    function ComputeExpiresAt(ANow, ATTLMs: Int64): Int64; inline;
    procedure ExpireOldEntries(ANow: Int64);
  public
    constructor Create(ACapacity: Int32 = TSRING_DEFAULT_CAPACITY;
      ADefaultTTLMs: Int64 = TSRING_DEFAULT_TTL_MS);
    destructor Destroy; override;

    {** @desc 追加一个值（使用默认 TTL） }
    function Append(const AValue: AnsiString): TTSRingResult;
    {** @desc 追加一个值（指定 TTL 毫秒，0=永不过期） }
    function AppendWithTTL(const AValue: AnsiString; ATTLMs: Int64): TTSRingResult;
    {** @desc 获取最近 N 个条目（从新到旧） }
    function GetRecent(ACount: Int32;
      out AEntries: array of TTSRingEntry): Int32;
    {** @desc 获取时间范围内的条目 }
    function GetRange(AFromMs, AToMs: Int64;
      out AEntries: array of TTSRingEntry): Int32;
    {** @desc 获取最新的一个条目 }
    function Latest(out AEntry: TTSRingEntry): TTSRingResult;
    {** @desc 当前条目数量 }
    function Count: Int32;
    {** @desc 容量 }
    function GetCapacity: Int32;
    {** @desc 是否为空 }
    function IsEmpty: Boolean;
    {** @desc 是否已满 }
    function IsFull: Boolean;
    {** @desc 清空所有条目 }
    procedure Clear;
    {** @desc 设置默认 TTL }
    procedure SetDefaultTTL(ATTLMs: Int64);
    {** @desc 清理过期条目 }
    function PurgeExpired: Int32;
  end;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.base,
  nextpas.core.platform.time;

function TTimeSeriesRingBuffer.GetNowMs: Int64;
begin
  Result := Int64(platform_monotonic_ns div 1000000);
end;

procedure TTimeSeriesRingBuffer.Lock;
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_seq_cst, mo_seq_cst) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TTimeSeriesRingBuffer.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

function TTimeSeriesRingBuffer.WrapIdx(AIdx: Int32): Int32;
begin
  Result := AIdx mod FCapacity;
  if Result < 0 then
    Inc(Result, FCapacity);
end;

function TTimeSeriesRingBuffer.ComputeExpiresAt(ANow, ATTLMs: Int64): Int64;
begin
  if ATTLMs <= 0 then
    Exit(0);
  Result := ANow + ATTLMs;
end;

procedure TTimeSeriesRingBuffer.ExpireOldEntries(ANow: Int64);
var
  LIdx, LExpired: Int32;
begin
  LExpired := 0;
  while (FCount > 0) and (LExpired < FCount) do
  begin
    LIdx := WrapIdx(FHead - FCount + LExpired);
    if (FBuffer[LIdx].ExpiresAt > 0) and (FBuffer[LIdx].ExpiresAt <= ANow) then
    begin
      FBuffer[LIdx].Timestamp := 0;
      FBuffer[LIdx].ExpiresAt := 0;
      FBuffer[LIdx].Value := '';
      Inc(LExpired);
    end
    else
      Break;
  end;
  if LExpired > 0 then
  begin
    Dec(FCount, LExpired);
  end;
end;

constructor TTimeSeriesRingBuffer.Create(ACapacity: Int32; ADefaultTTLMs: Int64);
begin
  inherited Create;
  if ACapacity < 1 then ACapacity := TSRING_DEFAULT_CAPACITY;
  FCapacity := ACapacity;
  if ADefaultTTLMs < 0 then
    ADefaultTTLMs := 0;
  FDefaultTTL := ADefaultTTLMs;
  FHead := 0;
  FCount := 0;
  FLock := 0;
  SetLength(FBuffer, FCapacity);
end;

destructor TTimeSeriesRingBuffer.Destroy;
begin
  Clear;
  FBuffer := nil;
  inherited Destroy;
end;

function TTimeSeriesRingBuffer.Append(const AValue: AnsiString): TTSRingResult;
begin
  Result := AppendWithTTL(AValue, FDefaultTTL);
end;

function TTimeSeriesRingBuffer.AppendWithTTL(const AValue: AnsiString;
  ATTLMs: Int64): TTSRingResult;
var
  LIdx: Int32;
  LNow: Int64;
begin
  Lock;
  try
    LNow := GetNowMs;
    ExpireOldEntries(LNow);

    LIdx := WrapIdx(FHead);
    if (FCount >= FCapacity) and (ATTLMs > 0) then
    begin
      { Overwrite oldest }
      FBuffer[WrapIdx(FHead - FCount)].Value := '';
      Dec(FCount);
    end
    else if FCount >= FCapacity then
    begin
      { Overwrite oldest, no TTL }
      FBuffer[WrapIdx(FHead - FCount)].Value := '';
      Dec(FCount);
    end;

    FBuffer[LIdx].Timestamp := LNow;
    FBuffer[LIdx].ExpiresAt := ComputeExpiresAt(LNow, ATTLMs);
    FBuffer[LIdx].Value := AValue;
    FHead := WrapIdx(FHead + 1);
    Inc(FCount);
    Result := tsrOk;
  finally
    Unlock;
  end;
end;

function TTimeSeriesRingBuffer.GetRecent(ACount: Int32;
  out AEntries: array of TTSRingEntry): Int32;
var
  LI, LIdx, LCopy: Int32;
begin
  Lock;
  try
    ExpireOldEntries(GetNowMs);
    LCopy := FCount;
    if ACount < LCopy then
      LCopy := ACount;
    if LCopy > Length(AEntries) then
      LCopy := Length(AEntries);
    Result := LCopy;
    for LI := 0 to LCopy - 1 do
    begin
      LIdx := WrapIdx(FHead - 1 - LI);
      AEntries[LI] := FBuffer[LIdx];
    end;
  finally
    Unlock;
  end;
end;

function TTimeSeriesRingBuffer.GetRange(AFromMs, AToMs: Int64;
  out AEntries: array of TTSRingEntry): Int32;
var
  LI, LIdx, LFound: Int32;
begin
  Lock;
  try
    ExpireOldEntries(GetNowMs);
    LFound := 0;
    for LI := 0 to FCount - 1 do
    begin
      LIdx := WrapIdx(FHead - FCount + LI);
      if (FBuffer[LIdx].Timestamp >= AFromMs) and
         (FBuffer[LIdx].Timestamp <= AToMs) then
      begin
        if LFound < Length(AEntries) then
          AEntries[LFound] := FBuffer[LIdx];
        Inc(LFound);
      end;
    end;
    Result := LFound;
  finally
    Unlock;
  end;
end;

function TTimeSeriesRingBuffer.Latest(out AEntry: TTSRingEntry): TTSRingResult;
begin
  Lock;
  try
    ExpireOldEntries(GetNowMs);
    if FCount = 0 then
      Exit(tsrEmpty);
    AEntry := FBuffer[WrapIdx(FHead - 1)];
    Result := tsrOk;
  finally
    Unlock;
  end;
end;

function TTimeSeriesRingBuffer.Count: Int32;
begin
  Lock;
  try
    ExpireOldEntries(GetNowMs);
    Result := FCount;
  finally
    Unlock;
  end;
end;

function TTimeSeriesRingBuffer.GetCapacity: Int32;
begin
  Result := FCapacity;
end;

function TTimeSeriesRingBuffer.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TTimeSeriesRingBuffer.IsFull: Boolean;
begin
  Result := Count >= FCapacity;
end;

procedure TTimeSeriesRingBuffer.Clear;
var
  LI: Int32;
begin
  Lock;
  try
    for LI := 0 to FCount - 1 do
    begin
      FBuffer[WrapIdx(FHead - FCount + LI)].Timestamp := 0;
      FBuffer[WrapIdx(FHead - FCount + LI)].ExpiresAt := 0;
      FBuffer[WrapIdx(FHead - FCount + LI)].Value := '';
    end;
    FHead := 0;
    FCount := 0;
  finally
    Unlock;
  end;
end;

procedure TTimeSeriesRingBuffer.SetDefaultTTL(ATTLMs: Int64);
begin
  if ATTLMs < 0 then
    ATTLMs := 0;
  atomic_exchange_64(FDefaultTTL, ATTLMs);
end;

function TTimeSeriesRingBuffer.PurgeExpired: Int32;
var
  LBefore: Int32;
begin
  Lock;
  try
    LBefore := FCount;
    ExpireOldEntries(GetNowMs);
    Result := LBefore - FCount;
  finally
    Unlock;
  end;
end;

end.

unit nextpas.core.db.pool.idle;

{** @desc db.pool 空闲队列子模块（L2 基础设施，CONTRACT §2.7）。
       职责：LIFO 热队、惰性驱逐、探活节流判断与容量增长。
       归属：idle 拥有 TPoolIdleEntry 与队列操作，impl 仅薄委托；
       复用 bytes.ops 单源（PoolGrowCap 经 BytesCalcGrowCapWithMin 单 Move 零拷贝），性能 inline 热路径零拷贝。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.collections.smallvec,
  nextpas.core.db.intf,
  nextpas.core.db.pool.base;

const
  POOL_IDLE_BYTES_SINGLE_SOURCE = BYTES_OPS_SINGLE_SOURCE;

{$I nextpas.core.bytes.ops.single_source.inc}

type
  TPoolIdleEntry = record
    Conn: IDbConnection;
    CreatedTick: QWord;
    ReturnedTick: QWord;
  end;
  TPoolIdleVec = specialize TSmallVec<TPoolIdleEntry, 16>;

function PoolIdleGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline;
function PoolStale(const ACreatedTick, ANow: QWord; const APolicy: TDbPoolPolicy): Boolean; inline;
function PoolIdleStale(const AEntry: TPoolIdleEntry; const ANow: QWord; const APolicy: TDbPoolPolicy): Boolean; inline;
function PoolNeedValidate(const AEntry: TPoolIdleEntry; const ANow: QWord; const APolicy: TDbPoolPolicy): Boolean; inline;
procedure PoolIdlePush(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const AEntry: TPoolIdleEntry);
function PoolIdlePop(var AEntries: array of TPoolIdleEntry; var ACount: Integer; var AEntry: TPoolIdleEntry): Boolean; inline;
procedure PoolIdleEvictColdStale(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const ANow: QWord; const APolicy: TDbPoolPolicy);
function PoolIdleTryPopUsable(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const ANow: QWord; const APolicy: TDbPoolPolicy; out AEntry: TPoolIdleEntry): Boolean; inline;
// collections 小容器复用：impl 不再裸数组+手算 GrowCap，改由 TSmallVec 单源（栈内联 16 + 堆 1.5x 增长，单 Move 零拷贝）
procedure PoolIdlePushVec(var AVec: TPoolIdleVec; const AEntry: TPoolIdleEntry); inline;
function PoolIdlePopVec(var AVec: TPoolIdleVec; var AEntry: TPoolIdleEntry): Boolean; inline;
procedure PoolIdleEvictColdStaleVec(var AVec: TPoolIdleVec; const ANow: QWord; const APolicy: TDbPoolPolicy);
function PoolIdleTryPopUsableVec(var AVec: TPoolIdleVec; const ANow: QWord; const APolicy: TDbPoolPolicy; out AEntry: TPoolIdleEntry): Boolean; inline;

implementation

function PoolIdleGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline;
begin
  Result := BytesCalcGrowCapWithMin(AOld, ARequired, 4);
end;

function PoolStale(const ACreatedTick, ANow: QWord; const APolicy: TDbPoolPolicy): Boolean; inline;
begin
  { perf: ns 单源——ANow/ACreatedTick 均为 platform_monotonic_ns (ns)，阈值侧 *1e9 换算，零 div，inline 零 I-Cache 膨胀 }
  Result := (APolicy.MaxLifetimeSec > 0) and
    (ANow >= ACreatedTick + QWord(APolicy.MaxLifetimeSec) * 1000000000);
end;

function PoolIdleStale(const AEntry: TPoolIdleEntry; const ANow: QWord; const APolicy: TDbPoolPolicy): Boolean; inline;
begin
  if PoolStale(AEntry.CreatedTick, ANow, APolicy) then
    Exit(True);
  Result := (APolicy.IdleTimeoutSec > 0) and
    (ANow >= AEntry.ReturnedTick + QWord(APolicy.IdleTimeoutSec) * 1000000000);
end;

function PoolNeedValidate(const AEntry: TPoolIdleEntry; const ANow: QWord; const APolicy: TDbPoolPolicy): Boolean; inline;
begin
  Result := APolicy.ValidateOnAcquire and (ANow >= AEntry.ReturnedTick + 500000000);
end;

procedure PoolIdlePush(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const AEntry: TPoolIdleEntry);
var
  LCap, LNewCap: Integer;
begin
  if ACount < Length(AEntries) then
  begin
    AEntries[ACount] := AEntry;
    Inc(ACount);
    Exit;
  end;
  LCap := Length(AEntries);
  LNewCap := Integer(PoolIdleGrowCap(SizeUInt(LCap), SizeUInt(ACount + 1)));
  SetLength(AEntries, LNewCap);
  AEntries[ACount] := AEntry;
  Inc(ACount);
end;

function PoolIdlePop(var AEntries: array of TPoolIdleEntry; var ACount: Integer; var AEntry: TPoolIdleEntry): Boolean; inline;
begin
  if ACount = 0 then
    Exit(False);
  Dec(ACount);
  AEntry := AEntries[ACount];
  AEntries[ACount] := Default(TPoolIdleEntry);
  Result := True;
end;

procedure PoolIdleEvictColdStale(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const ANow: QWord; const APolicy: TDbPoolPolicy);
var
  I, W, Sample, HotStart: Integer;
  HasStale: Boolean;
begin
  if (APolicy.IdleTimeoutSec <= 0) and (APolicy.MaxLifetimeSec <= 0) then
    Exit;
  if ACount <= 0 then
    Exit;
  // O(1) dual-ended sampling fast-path: IdleTimeout 单调由冷端 4 探针覆盖，MaxLifetime 非单调（CreatedTick 与队列序无关）需热端 4 探针补探；8 探针 O(1) 命中才全量压缩，零漏热端深层过期，避免滞留至 TryPopUsable 循环放大持锁；inline 谓词零拷贝
  Sample := ACount;
  if Sample > 4 then
    Sample := 4;
  HasStale := False;
  for I := 0 to Sample - 1 do
    if PoolIdleStale(AEntries[I], ANow, APolicy) then
    begin
      HasStale := True;
      Break;
    end;
  if (not HasStale) and (APolicy.MaxLifetimeSec > 0) and (ACount > Sample) then
  begin
    HotStart := ACount - 4;
    if HotStart < Sample then
      HotStart := Sample;
    for I := HotStart to ACount - 1 do
      if PoolIdleStale(AEntries[I], ANow, APolicy) then
      begin
        HasStale := True;
        Break;
      end;
  end;
  if not HasStale then
    Exit;
  W := 0;
  for I := 0 to ACount - 1 do
    if PoolIdleStale(AEntries[I], ANow, APolicy) then
      AEntries[I] := Default(TPoolIdleEntry)
    else
    begin
      if W <> I then
      begin
        AEntries[W] := AEntries[I];
        AEntries[I] := Default(TPoolIdleEntry);
      end;
      Inc(W);
    end;
  ACount := W;
end;

function PoolIdleTryPopUsable(var AEntries: array of TPoolIdleEntry; var ACount: Integer; const ANow: QWord; const APolicy: TDbPoolPolicy; out AEntry: TPoolIdleEntry): Boolean; inline;
begin
  { 热路径 LIFO 循环丢弃：while Pop + 双 inline 谓词逐栈顶循环至可用或空，单次持锁内排空深层过期/需探活条目，避免下次 Acquire 触发 EvictColdStale O(n) 全量扫描与锁持有延长；零额外 Move/Default 清零释放不丢，inline 零 I-Cache 膨胀 }
  while PoolIdlePop(AEntries, ACount, AEntry) do
  begin
    if PoolIdleStale(AEntry, ANow, APolicy) then
    begin
      AEntry := Default(TPoolIdleEntry);
      Continue;
    end;
    if PoolNeedValidate(AEntry, ANow, APolicy) then
    begin
      AEntry := Default(TPoolIdleEntry);
      Continue;
    end;
    Exit(True);
  end;
  Result := False;
end;

procedure PoolIdlePushVec(var AVec: TPoolIdleVec; const AEntry: TPoolIdleEntry); inline;
begin
  AVec.Push(AEntry);
end;

function PoolIdlePopVec(var AVec: TPoolIdleVec; var AEntry: TPoolIdleEntry): Boolean; inline;
begin
  Result := AVec.Pop(AEntry);
end;

procedure PoolIdleEvictColdStaleVec(var AVec: TPoolIdleVec; const ANow: QWord; const APolicy: TDbPoolPolicy);
var
  I, W, N, Sample, HotStart: Integer;
  E: TPoolIdleEntry;
  HasStale: Boolean;
begin
  if (APolicy.IdleTimeoutSec <= 0) and (APolicy.MaxLifetimeSec <= 0) then Exit;
  N := Integer(AVec.Count);
  if N <= 0 then Exit;
  // O(1) dual-ended sampling: 冷端 4 + 热端 4（MaxLifetime 非单调补探），8 探针 O(1) 命中才全量压缩，零漏热端深层过期
  Sample := N;
  if Sample > 4 then Sample := 4;
  HasStale := False;
  for I := 0 to Sample - 1 do
  begin
    E := AVec.Get(SizeUInt(I));
    if PoolIdleStale(E, ANow, APolicy) then
    begin
      HasStale := True;
      Break;
    end;
  end;
  if (not HasStale) and (APolicy.MaxLifetimeSec > 0) and (N > Sample) then
  begin
    HotStart := N - 4;
    if HotStart < Sample then HotStart := Sample;
    for I := HotStart to N - 1 do
    begin
      E := AVec.Get(SizeUInt(I));
      if PoolIdleStale(E, ANow, APolicy) then
      begin
        HasStale := True;
        Break;
      end;
    end;
  end;
  if not HasStale then Exit;
  W := 0;
  for I := 0 to N - 1 do
  begin
    E := AVec.Get(SizeUInt(I));
    if PoolIdleStale(E, ANow, APolicy) then
      AVec.Put(SizeUInt(I), Default(TPoolIdleEntry))
    else
    begin
      if W <> I then
      begin
        AVec.Put(SizeUInt(W), E);
        AVec.Put(SizeUInt(I), Default(TPoolIdleEntry));
      end;
      Inc(W);
    end;
  end;
  while Integer(AVec.Count) > W do
  begin
    AVec.Pop(E);
  end;
end;

function PoolIdleTryPopUsableVec(var AVec: TPoolIdleVec; const ANow: QWord; const APolicy: TDbPoolPolicy; out AEntry: TPoolIdleEntry): Boolean; inline;
begin
  while PoolIdlePopVec(AVec, AEntry) do
  begin
    if PoolIdleStale(AEntry, ANow, APolicy) then
    begin
      AEntry := Default(TPoolIdleEntry);
      Continue;
    end;
    if PoolNeedValidate(AEntry, ANow, APolicy) then
    begin
      AEntry := Default(TPoolIdleEntry);
      Continue;
    end;
    Exit(True);
  end;
  Result := False;
end;

end.

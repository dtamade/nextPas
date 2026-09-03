unit nextpas.core.db.pool.concurrency;

{** @desc db.pool 并发桶子模块（L2 基础设施，CONTRACT §2.7）。
       职责：并发桶容量增长与信号量槽位 acquire/release 薄封装；
       归属：并发桶拥有 PoolGrowCap 与 Read/Writer 槽位原语，impl 仅薄委托；
       复用 bytes.ops 单源（PoolGrowCap 经 BytesGrowCapacityWithMin 单 Move 零拷贝，min 4 与 idle/leak 归一），性能 inline 零 I-Cache 膨胀。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync;



function PoolGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline;

function PoolConcurrencyTryAcquireRead(const ASem: ISemaphore; const ATimeoutMs: Integer): Boolean; inline;
function PoolConcurrencyTryAcquireWriter(const ASem: ISemaphore; const ATimeoutMs: Integer): Boolean; inline;
procedure PoolConcurrencyReleaseRead(const ASem: ISemaphore); inline;
procedure PoolConcurrencyReleaseWriter(const ASem: ISemaphore); inline;

implementation

function PoolGrowCap(const AOld, ARequired: SizeUInt): SizeUInt; inline;
begin
  { 单源直连 bytes.ops：容量增长零拷贝单源，idle/leak/concurrency 三面收敛至 BytesGrowCapacityWithMin(min 4)，零额外分配，inline 零 I-Cache 膨胀 }
  Result := BytesGrowCapacityWithMin(AOld, ARequired, 4);
end;

function PoolConcurrencyTryAcquireRead(const ASem: ISemaphore; const ATimeoutMs: Integer): Boolean; inline;
begin
  if ATimeoutMs > 0 then
    Result := ASem.TryAcquireTimeout(Int64(ATimeoutMs) * 1000000)
  else
    Result := ASem.TryAcquire;
end;

function PoolConcurrencyTryAcquireWriter(const ASem: ISemaphore; const ATimeoutMs: Integer): Boolean; inline;
begin
  if ATimeoutMs > 0 then
    Result := ASem.TryAcquireTimeout(Int64(ATimeoutMs) * 1000000)
  else
    Result := ASem.TryAcquire;
end;

procedure PoolConcurrencyReleaseRead(const ASem: ISemaphore); inline;
begin
  ASem.Release;
end;

procedure PoolConcurrencyReleaseWriter(const ASem: ISemaphore); inline;
begin
  ASem.Release;
end;

end.

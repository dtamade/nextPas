unit nextpas.core.window.queue.cow;

{ window.queue cow — COW 增长分治 shard，家族内仅 queue uses。
  职责：CalcGrowCapacity / PrepareCowCopy 单源 via window.impl→bytes.ops 0→32→2× inline 零拷贝 O(1)；
  与 ring/backpressure 三 shard 分治，门面仅高层编排，I-Cache 优雅，资源托管不丢。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.impl,
  nextpas.core.window.queue.base,
  nextpas.core.bytes.ops;

function QueueCowCalcGrowCapacity(AOldCap, AOldCount: Integer; out ANewCap: Integer): Boolean; inline;
procedure QueueCowPrepareCopy(var ANew: array of TWindowWorkItem; const AOldRing: array of TWindowWorkItem; AOldHead, AOldCap, AOldCount, ANewCap: Integer); inline;
function QueueCowSnapGrowCapacity(ACount: Integer): Integer; inline;
procedure RequireQueueCowToken(const AToken: TWindowFamilyToken); inline;

implementation

uses
  nextpas.core.sync.cow;

function QueueCowCalcGrowCapacity(AOldCap, AOldCount: Integer; out ANewCap: Integer): Boolean; inline;
begin
  // 单源 via window.impl WindowGrowCapacity 0→32→2× inline 零拷贝 O(1) capped RingMax 16384，托管不丢
  ANewCap := WindowGrowCapacity(AOldCap);
  if ANewCap > WindowQueueRingMax then Exit(False);
  if (AOldCap >= WindowQueueRingMax) and (AOldCount >= AOldCap) then Exit(False);
  if ANewCap <= AOldCap then Exit(False);
  Result := True;
end;

procedure QueueCowPrepareCopy(var ANew: array of TWindowWorkItem; const AOldRing: array of TWindowWorkItem; AOldHead, AOldCap, AOldCount, ANewCap: Integer); inline;
begin
  // 单源 via sync.cow CowRingPrepareCopy + bytes.ops inline 零拷贝 O(n) 均摊 0→32→2×
  specialize CowRingPrepareCopy<TWindowWorkItem>(ANew, AOldRing, AOldHead, AOldCap, AOldCount, ANewCap);
end;

function QueueCowSnapGrowCapacity(ACount: Integer): Integer; inline;
begin
  // Bulk tiered 三档 via bytes.ops snapshot 单源 1024/4096/8192，inline 零拷贝 O(1) capped 8192，分档尾延迟可观测
  Result := specialize WindowGrowHelper<TWindowWorkItem>(ACount, WindowQueueSnapMax);
end;

procedure RequireQueueCowToken(const AToken: TWindowFamilyToken); inline;
begin
  RequireWindowFamilyToken(AToken);
end;

end.

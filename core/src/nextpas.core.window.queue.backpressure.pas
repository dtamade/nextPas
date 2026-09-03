unit nextpas.core.window.queue.backpressure;

{ window.queue backpressure — 双轨 Cap/Oom 原子计数，inline 零拷贝 O(1) 可复用策略，单源 bytes.ops 阈值，家族内 shard 仅 queue uses。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.window.impl;

type
  TWindowQueueBackpressure = record
  private
    FDropped: Int32;
    FDroppedCap: Int32;
    FDroppedOom: Int32;
  public
    procedure Inc; inline;
    procedure IncCap; inline;
    procedure IncOom; inline;
    function Total: Integer; inline;
    function CapCount: Integer; inline;
    function OomCount: Integer; inline;
    procedure Clear; inline;
  end;

procedure RequireQueueBackpressureToken(const AToken: TWindowFamilyToken); inline;

implementation

procedure RequireQueueBackpressureToken(const AToken: TWindowFamilyToken); inline;
begin
  RequireWindowFamilyToken(AToken);
end;

procedure TWindowQueueBackpressure.Inc; inline;
begin
  atomic_fetch_add(FDropped, 1);
end;

procedure TWindowQueueBackpressure.IncCap; inline;
begin
  atomic_fetch_add(FDropped, 1);
  atomic_fetch_add(FDroppedCap, 1);
end;

procedure TWindowQueueBackpressure.IncOom; inline;
begin
  atomic_fetch_add(FDropped, 1);
  atomic_fetch_add(FDroppedOom, 1);
end;

function TWindowQueueBackpressure.Total: Integer; inline;
begin
  Result := atomic_load(FDropped);
end;

function TWindowQueueBackpressure.CapCount: Integer; inline;
begin
  Result := atomic_load(FDroppedCap);
end;

function TWindowQueueBackpressure.OomCount: Integer; inline;
begin
  Result := atomic_load(FDroppedOom);
end;

procedure TWindowQueueBackpressure.Clear; inline;
begin
  atomic_store(FDropped, 0);
  atomic_store(FDroppedCap, 0);
  atomic_store(FDroppedOom, 0);
end;

end.

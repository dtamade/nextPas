unit nextpas.core.id.snowflake;
{$I nextpas.core.settings.inc}

interface

type
  TSnowflakeId = Int64;

  TSnowflakeGenerator = record
  private
    FInitialized: Boolean;
    FEpochMs: Int64;
    FWorkerId: UInt16;
    FLastMs: Int64;
    FSequence: UInt16;
  public
    procedure Init(AWorkerId: UInt16; AEpochMs: Int64 = 0);
    function Next: TSnowflakeId;
    class function Extract(AId: TSnowflakeId; AEpochMs: Int64;
      out ATimestampMs: Int64; out AWorkerId: UInt16; out ASequence: UInt16): Boolean; static;
  end;

const
  SNOWFLAKE_EPOCH_TWITTER = Int64(1288834974657);
  SNOWFLAKE_EPOCH_DISCORD = Int64(1420070400000);

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.platform.time,
  nextpas.core.platform.thread;

const
  SNOWFLAKE_WORKER_ID_MASK = UInt16($03FF);
  SNOWFLAKE_SEQUENCE_MASK = UInt16($0FFF);
  SNOWFLAKE_TIMESTAMP_SHIFT = 22;
  SNOWFLAKE_WORKER_ID_SHIFT = 12;
  SNOWFLAKE_MAX_TIMESTAMP_DELTA_MS = (Int64(1) shl 41) - 1;
  SNOWFLAKE_NO_LAST_MS = Int64(-1);

function ResolveSnowflakeEpochMs(const AEpochMs: Int64): Int64;
begin
  if AEpochMs = 0 then
    Result := SNOWFLAKE_EPOCH_TWITTER
  else
    Result := AEpochMs;
end;

function ReadSnowflakeTimestampDeltaMs(const AEpochMs: Int64): Int64;
var
  LNowMs: UInt64;
  LEpochMs: UInt64;
  LDeltaMs: UInt64;
begin
  LEpochMs := UInt64(AEpochMs);
  LNowMs := platform_realtime_ns div 1000000;
  if LNowMs < LEpochMs then
    raise EInvalidOperationError.Create('Snowflake clock is before epoch');
  LDeltaMs := LNowMs - LEpochMs;
  if LDeltaMs > UInt64(SNOWFLAKE_MAX_TIMESTAMP_DELTA_MS) then
    raise EOutOfRange.Create('Snowflake timestamp delta exceeds 41 bits');
  Result := Int64(LDeltaMs);
end;

procedure TSnowflakeGenerator.Init(AWorkerId: UInt16; AEpochMs: Int64);
begin
  if AWorkerId > 1023 then
    raise EArgumentError.Create('Snowflake worker id must be <= 1023');
  if AEpochMs < 0 then
    raise EArgumentError.Create('Snowflake epoch must be >= 0');
  FEpochMs := ResolveSnowflakeEpochMs(AEpochMs);
  FWorkerId := AWorkerId and SNOWFLAKE_WORKER_ID_MASK;
  FLastMs := SNOWFLAKE_NO_LAST_MS;
  FSequence := 0;
  FInitialized := True;
end;

function TSnowflakeGenerator.Next: TSnowflakeId;
var
  LMs: Int64;
begin
  if not FInitialized then
    raise EInvalidOperationError.Create('Snowflake generator is not initialized');
  LMs := ReadSnowflakeTimestampDeltaMs(FEpochMs);
  if LMs < FLastMs then
  begin
    while LMs < FLastMs do
    begin
      platform_thread_yield;
      LMs := ReadSnowflakeTimestampDeltaMs(FEpochMs);
    end;
  end;
  if LMs = FLastMs then
  begin
    if FSequence >= SNOWFLAKE_SEQUENCE_MASK then
    begin
      while LMs <= FLastMs do
      begin
        platform_thread_yield;
        LMs := ReadSnowflakeTimestampDeltaMs(FEpochMs);
      end;
      FLastMs := LMs;
      FSequence := 0;
    end
    else
      Inc(FSequence);
  end
  else
  begin
    FLastMs := LMs;
    FSequence := 0;
  end;
  Result := (LMs shl SNOWFLAKE_TIMESTAMP_SHIFT) or
    (Int64(FWorkerId) shl SNOWFLAKE_WORKER_ID_SHIFT) or Int64(FSequence);
end;

class function TSnowflakeGenerator.Extract(AId: TSnowflakeId; AEpochMs: Int64;
  out ATimestampMs: Int64; out AWorkerId: UInt16; out ASequence: UInt16): Boolean;
var
  LDeltaMs: Int64;
  LEpochMs: Int64;
begin
  if AId < 0 then Exit(False);
  if AEpochMs < 0 then Exit(False);
  LDeltaMs := AId shr SNOWFLAKE_TIMESTAMP_SHIFT;
  LEpochMs := ResolveSnowflakeEpochMs(AEpochMs);
  if LEpochMs > High(Int64) - LDeltaMs then Exit(False);
  ATimestampMs := LDeltaMs + LEpochMs;
  AWorkerId := UInt16((AId shr SNOWFLAKE_WORKER_ID_SHIFT) and SNOWFLAKE_WORKER_ID_MASK);
  ASequence := UInt16(AId and SNOWFLAKE_SEQUENCE_MASK);
  Result := True;
end;

end.

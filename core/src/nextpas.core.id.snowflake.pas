unit nextpas.core.id.snowflake;
{$I nextpas.core.settings.inc}

interface

type
  TSnowflakeId = Int64;

  TSnowflakeGenerator = record
  private
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
  nextpas.core.platform.time,
  nextpas.core.platform.thread;

procedure TSnowflakeGenerator.Init(AWorkerId: UInt16; AEpochMs: Int64);
begin
  if AWorkerId > 1023 then
    RunError(201);
  if AEpochMs < 0 then
    RunError(201);
  if AEpochMs = 0 then
    FEpochMs := SNOWFLAKE_EPOCH_TWITTER
  else
    FEpochMs := AEpochMs;
  FWorkerId := AWorkerId and $3FF;
  FLastMs := 0;
  FSequence := 0;
end;

function TSnowflakeGenerator.Next: TSnowflakeId;
var
  LMs: Int64;
begin
  LMs := Int64(platform_realtime_ns div 1000000) - FEpochMs;
  if LMs < FLastMs then
  begin
    while LMs < FLastMs do
    begin
      platform_thread_yield;
      LMs := Int64(platform_realtime_ns div 1000000) - FEpochMs;
    end;
  end;
  if LMs = FLastMs then
  begin
    Inc(FSequence);
    if FSequence > $0FFF then
    begin
      while LMs = FLastMs do
      begin
        platform_thread_yield;
        LMs := Int64(platform_realtime_ns div 1000000) - FEpochMs;
      end;
      FLastMs := LMs;
      FSequence := 0;
    end;
  end
  else
  begin
    FLastMs := LMs;
    FSequence := 0;
  end;
  Result := (LMs shl 22) or (Int64(FWorkerId) shl 12) or Int64(FSequence);
end;

class function TSnowflakeGenerator.Extract(AId: TSnowflakeId; AEpochMs: Int64;
  out ATimestampMs: Int64; out AWorkerId: UInt16; out ASequence: UInt16): Boolean;
begin
  if AId < 0 then Exit(False);
  ATimestampMs := (AId shr 22) + AEpochMs;
  AWorkerId := UInt16((AId shr 12) and $3FF);
  ASequence := UInt16(AId and $FFF);
  Result := True;
end;

end.

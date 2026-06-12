unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.time.base;

type
  TPlatformTimeNanoseconds = nextpas.core.platform.time.base.TPlatformTimeNanoseconds;
  TPlatformCounterValue = nextpas.core.platform.time.base.TPlatformCounterValue;
  TPlatformCounterFrequency = nextpas.core.platform.time.base.TPlatformCounterFrequency;

procedure TestClockReset;
procedure TestClockSetRealtimeMs(const AMs: UInt64);
procedure TestClockSetSequence(const AValues: array of UInt64);
function TestClockCallCount: SizeUInt;

function platform_monotonic_ns: TPlatformTimeNanoseconds;
function platform_realtime_ns: TPlatformTimeNanoseconds;
function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
function platform_qpc_to_ns(const ACounter: TPlatformCounterValue; const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_resolution_from_frequency_ns(const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): TPlatformTimeNanoseconds;
function platform_utc_offset_seconds: Int32;
procedure platform_time_breakdown_utc(ANs: TPlatformTimeNanoseconds; out AResult: TPlatformTimeBreakdown);

implementation

const
  MAX_SEQUENCE_VALUES = 8;

var
  GRealtimeMs: UInt64 = 1000;
  GSequence: array[0..MAX_SEQUENCE_VALUES - 1] of UInt64;
  GSequenceLen: SizeUInt = 0;
  GCallCount: SizeUInt = 0;

procedure TestClockReset;
begin
  GRealtimeMs := 1000;
  GSequenceLen := 0;
  GCallCount := 0;
end;

procedure TestClockSetRealtimeMs(const AMs: UInt64);
begin
  GRealtimeMs := AMs;
  GSequenceLen := 0;
  GCallCount := 0;
end;

procedure TestClockSetSequence(const AValues: array of UInt64);
var
  LI: Integer;
begin
  GSequenceLen := SizeUInt(Length(AValues));
  if GSequenceLen > MAX_SEQUENCE_VALUES then
    GSequenceLen := MAX_SEQUENCE_VALUES;
  for LI := 0 to Integer(GSequenceLen) - 1 do
    GSequence[LI] := AValues[LI];
  GCallCount := 0;
end;

function TestClockCallCount: SizeUInt;
begin
  Result := GCallCount;
end;

function platform_monotonic_ns: TPlatformTimeNanoseconds;
begin
  Result := GRealtimeMs * 1000000;
end;

function platform_realtime_ns: TPlatformTimeNanoseconds;
var
  LIndex: SizeUInt;
begin
  if GSequenceLen > 0 then
  begin
    if GCallCount < GSequenceLen then
      LIndex := GCallCount
    else
      LIndex := GSequenceLen - 1;
    GRealtimeMs := GSequence[LIndex];
  end;
  Inc(GCallCount);
  Result := GRealtimeMs * 1000000;
end;

function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
begin
  Result := 1;
end;

function platform_qpc_to_ns(const ACounter: TPlatformCounterValue; const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  if AFrequency = 0 then
    Exit(0);
  Result := TPlatformTimeNanoseconds((ACounter * 1000000000) div AFrequency);
end;

function platform_resolution_from_frequency_ns(const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  if AFrequency = 0 then
    Exit(1);
  Result := 1000000000 div AFrequency;
  if Result = 0 then
    Result := 1;
end;

function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): TPlatformTimeNanoseconds;
begin
  Result := TPlatformTimeNanoseconds(ASec) * 1000000000 + TPlatformTimeNanoseconds(ANsec);
end;

function platform_utc_offset_seconds: Int32;
begin
  Result := 0;
end;

procedure platform_time_breakdown_utc(ANs: TPlatformTimeNanoseconds; out AResult: TPlatformTimeBreakdown);
begin
  FillChar(AResult, SizeOf(AResult), 0);
end;

end.

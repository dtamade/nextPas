unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

function platform_monotonic_ns: UInt64;
function platform_realtime_ns: UInt64;
function platform_monotonic_resolution_ns: UInt64;

implementation

{$IFDEF UNIX}
uses
  Linux, UnixType;
{$ENDIF}

{$IFDEF WINDOWS}
uses
  Windows;
{$ENDIF}

const
  NANOSECONDS_PER_SECOND = UInt64(1000000000);

{$IFDEF UNIX}
function platform_monotonic_ns: UInt64;
var
  LTs: TimeSpec;
begin
  if clock_gettime(CLOCK_MONOTONIC, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := UInt64(LTs.tv_sec) * NANOSECONDS_PER_SECOND + UInt64(LTs.tv_nsec);
end;

function platform_realtime_ns: UInt64;
var
  LTs: TimeSpec;
begin
  if clock_gettime(CLOCK_REALTIME, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := UInt64(LTs.tv_sec) * NANOSECONDS_PER_SECOND + UInt64(LTs.tv_nsec);
end;

function platform_monotonic_resolution_ns: UInt64;
var
  LTs: TimeSpec;
begin
  if clock_getres(CLOCK_MONOTONIC, @LTs) <> 0 then
  begin
    Result := 1;
    Exit;
  end;
  Result := UInt64(LTs.tv_sec) * NANOSECONDS_PER_SECOND + UInt64(LTs.tv_nsec);
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{$IFDEF WINDOWS}

var
  GFrequency: Int64 = 0;

procedure EnsureFrequency;
begin
  if GFrequency = 0 then
  begin
    if not QueryPerformanceFrequency(GFrequency) then
      GFrequency := 1;
    if GFrequency <= 0 then
      GFrequency := 1;
  end;
end;

function platform_monotonic_ns: UInt64;
var
  LCounter: Int64;
begin
  EnsureFrequency;
  if not QueryPerformanceCounter(LCounter) then
  begin
    Result := 0;
    Exit;
  end;
  Result := UInt64(LCounter) * NANOSECONDS_PER_SECOND div UInt64(GFrequency);
end;

function platform_realtime_ns: UInt64;
var
  LFt: FILETIME;
  LVal: UInt64;
begin
  GetSystemTimeAsFileTime(LFt);
  LVal := (UInt64(LFt.dwHighDateTime) shl 32) or UInt64(LFt.dwLowDateTime);
  Result := (LVal - UInt64(116444736000000000)) * UInt64(100);
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  EnsureFrequency;
  Result := NANOSECONDS_PER_SECOND div UInt64(GFrequency);
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{$IFNDEF UNIX}
{$IFNDEF WINDOWS}
function platform_monotonic_ns: UInt64;
begin
  Result := 0;
end;

function platform_realtime_ns: UInt64;
begin
  Result := 0;
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  Result := 1;
end;
{$ENDIF}
{$ENDIF}

end.

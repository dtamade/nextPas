unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

{ 单调时钟，纳秒精度，不受系统时钟调整影响 }
function PlatformMonotonicNs: UInt64;

{ 实时时钟（UTC），纳秒精度 }
function PlatformRealtimeNs: UInt64;

{ 单调时钟分辨率（纳秒/tick），通常为 1 }
function PlatformMonotonicResolutionNs: UInt64;

implementation

{$IFDEF UNIX}
uses
  Linux, UnixType;

function PlatformMonotonicNs: UInt64;
var
  LTs: TimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @LTs);
  Result := UInt64(LTs.tv_sec) * UInt64(1000000000) + UInt64(LTs.tv_nsec);
end;

function PlatformRealtimeNs: UInt64;
var
  LTs: TimeSpec;
begin
  clock_gettime(CLOCK_REALTIME, @LTs);
  Result := UInt64(LTs.tv_sec) * UInt64(1000000000) + UInt64(LTs.tv_nsec);
end;

function PlatformMonotonicResolutionNs: UInt64;
var
  LTs: TimeSpec;
begin
  clock_getres(CLOCK_MONOTONIC, @LTs);
  Result := UInt64(LTs.tv_sec) * UInt64(1000000000) + UInt64(LTs.tv_nsec);
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{$IFDEF WINDOWS}
uses
  Windows;

var
  GFrequency: Int64 = 0;

procedure EnsureFrequency;
begin
  if GFrequency = 0 then
    QueryPerformanceFrequency(GFrequency);
end;

function PlatformMonotonicNs: UInt64;
var
  LCounter: Int64;
begin
  EnsureFrequency;
  QueryPerformanceCounter(LCounter);
  Result := UInt64(LCounter) * UInt64(1000000000) div UInt64(GFrequency);
end;

function PlatformRealtimeNs: UInt64;
var
  LFt: FILETIME;
  LVal: UInt64;
begin
  GetSystemTimeAsFileTime(LFt);
  LVal := (UInt64(LFt.dwHighDateTime) shl 32) or UInt64(LFt.dwLowDateTime);
  Result := (LVal - UInt64(116444736000000000)) * UInt64(100);
end;

function PlatformMonotonicResolutionNs: UInt64;
begin
  EnsureFrequency;
  Result := UInt64(1000000000) div UInt64(GFrequency);
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

end.

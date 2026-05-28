unit nextpas.core.platform.time.host;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.time.base;

function platform_monotonic_ns: TPlatformTimeNanoseconds;
function platform_realtime_ns: TPlatformTimeNanoseconds;
function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
function platform_qpc_to_ns(
  const ACounter: TPlatformCounterValue;
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_resolution_from_frequency_ns(
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
function platform_timespec_to_ns(
  const ASec: Int64;
  const ANsec: Int64): TPlatformTimeNanoseconds;

implementation

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.math,
  nextpas.core.platform.windows.math
  {$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base
  , nextpas.core.platform.windows.ffi
  {$ENDIF}
  {$IFDEF NEXTPAS_UNIX}
  , nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
  {$ELSEIF defined(NEXTPAS_MACOS)}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  , nextpas.core.platform.android.base
  , nextpas.core.platform.android.ffi
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
  {$ELSE}
  , nextpas.core.platform.unix.base
  , nextpas.core.platform.unix.ffi
  {$ENDIF}
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_WINDOWS}
var
  GWindowsQpcFrequency: Int64 = 0;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
var
  GDarwinTimebaseNumer: UInt64 = 0;
  GDarwinTimebaseDenom: UInt64 = 0;
{$ENDIF}

function platform_qpc_to_ns(
  const ACounter: TPlatformCounterValue;
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.windows.math.windows_qpc_to_ns(ACounter, AFrequency);
end;

function platform_resolution_from_frequency_ns(
  const AFrequency: TPlatformCounterFrequency): TPlatformTimeNanoseconds;
begin
  Result := nextpas.core.platform.windows.math.windows_qpc_resolution_ns(AFrequency);
end;

function platform_timespec_to_ns(
  const ASec: Int64;
  const ANsec: Int64): TPlatformTimeNanoseconds;
var
  LTime: timespec;
begin
  LTime.tv_sec := ASec;
  LTime.tv_nsec := ANsec;
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

{$IFDEF NEXTPAS_UNIX}
  {$DEFINE NEXTPAS_PLATFORM_TIME_HOST_FFI}
{$ENDIF}
{$IFDEF NEXTPAS_WINDOWS}
  {$DEFINE NEXTPAS_PLATFORM_TIME_HOST_FFI}
{$ENDIF}
{$IFNDEF NEXTPAS_PLATFORM_TIME_HOST_FFI}
  {$FATAL 'nextpas.core.platform.time.host: unsupported platform. Implement for your target.'}
{$ENDIF}

{$IFDEF NEXTPAS_UNIX}
function platform_time_posix_clock_ns_u64(const AClockId: Int32): UInt64; inline;
var
  LTime: timespec;
begin
  if clock_gettime(AClockId, @LTime) <> 0 then
    Exit(0);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

function platform_time_posix_clock_resolution_ns_u64(const AClockId: Int32): UInt64; inline;
var
  LTime: timespec;
begin
  if clock_getres(AClockId, @LTime) <> 0 then
    Exit(1);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
  if Result = 0 then
    Result := 1;
end;
{$ENDIF}

{$IFDEF NEXTPAS_MACOS}
function platform_time_mul_div_floor(
  const AValue: UInt64;
  const AMultiplier: UInt64;
  const ADivisor: UInt64): UInt64;
var
  LFactor: UInt64;
  LQuotient: UInt64;
  LRemainder: UInt64;
  LTermQuotient: UInt64;
  LTermRemainder: UInt64;
begin
  if (AValue = 0) or (AMultiplier = 0) then
    Exit(0);
  if ADivisor = 0 then
    Exit(High(UInt64));

  LFactor := AMultiplier;
  LQuotient := 0;
  LRemainder := 0;
  LTermQuotient := AValue div ADivisor;
  LTermRemainder := AValue mod ADivisor;

  while LFactor <> 0 do
  begin
    if (LFactor and UInt64(1)) <> 0 then
    begin
      if LQuotient > High(UInt64) - LTermQuotient then
        Exit(High(UInt64));
      LQuotient := LQuotient + LTermQuotient;

      if LTermRemainder <> 0 then
      begin
        if LRemainder >= ADivisor - LTermRemainder then
        begin
          LRemainder := LRemainder - (ADivisor - LTermRemainder);
          if LQuotient = High(UInt64) then
            Exit(High(UInt64));
          Inc(LQuotient);
        end
        else
          LRemainder := LRemainder + LTermRemainder;
      end;
    end;

    LFactor := LFactor shr 1;
    if LFactor = 0 then
      Break;

    if LTermQuotient > High(UInt64) div 2 then
      LTermQuotient := High(UInt64)
    else
      LTermQuotient := LTermQuotient * 2;

    if LTermRemainder <> 0 then
    begin
      if LTermRemainder >= ADivisor - LTermRemainder then
      begin
        LTermRemainder := LTermRemainder - (ADivisor - LTermRemainder);
        if LTermQuotient <> High(UInt64) then
          Inc(LTermQuotient);
      end
      else
        LTermRemainder := LTermRemainder + LTermRemainder;
    end;
  end;

  Result := LQuotient;
end;

function platform_time_scale_units(
  const AValue: UInt64;
  const ADivisor: UInt64;
  const AMultiplier: UInt64): UInt64;
var
  LDivisor: UInt64;
  LWhole: UInt64;
  LRem: UInt64;
  LFrac: UInt64;
begin
  if AMultiplier = 0 then
    Exit(0);

  LDivisor := ADivisor;
  if LDivisor = 0 then
    LDivisor := 1;

  LWhole := AValue div LDivisor;
  LRem := AValue mod LDivisor;

  if LWhole > High(UInt64) div AMultiplier then
    Exit(High(UInt64));

  Result := LWhole * AMultiplier;

  if LRem = 0 then
    LFrac := 0
  else if LRem <= High(UInt64) div AMultiplier then
    LFrac := (LRem * AMultiplier) div LDivisor
  else
    LFrac := platform_time_mul_div_floor(LRem, AMultiplier, LDivisor);

  if Result > High(UInt64) - LFrac then
    Exit(High(UInt64));

  Result := Result + LFrac;
end;

procedure platform_time_darwin_ensure_timebase;
var
  LInfo: mach_timebase_info_data_t;
begin
  if GDarwinTimebaseDenom = 0 then
  begin
    mach_timebase_info(LInfo);
    GDarwinTimebaseNumer := LInfo.numer;
    GDarwinTimebaseDenom := LInfo.denom;
    if GDarwinTimebaseDenom = 0 then
    begin
      GDarwinTimebaseNumer := 1;
      GDarwinTimebaseDenom := 1;
    end;
  end;
end;

function platform_time_darwin_monotonic_ns_u64: UInt64;
begin
  platform_time_darwin_ensure_timebase;
  Result := platform_time_scale_units(
    mach_absolute_time, GDarwinTimebaseDenom, GDarwinTimebaseNumer);
end;

function platform_time_darwin_monotonic_resolution_ns_u64: UInt64;
begin
  platform_time_darwin_ensure_timebase;
  if GDarwinTimebaseDenom = 0 then
    Result := 1
  else if GDarwinTimebaseNumer >= GDarwinTimebaseDenom then
    Result := (GDarwinTimebaseNumer + GDarwinTimebaseDenom - 1)
      div GDarwinTimebaseDenom
  else
    Result := 1;

  if Result = 0 then
    Result := 1;
end;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
function platform_time_windows_qpc_frequency_u64: UInt64;
begin
  if GWindowsQpcFrequency = 0 then
  begin
    if not QueryPerformanceFrequency(GWindowsQpcFrequency) then
      GWindowsQpcFrequency := 1;
    if GWindowsQpcFrequency <= 0 then
      GWindowsQpcFrequency := 1;
  end;
  Result := UInt64(GWindowsQpcFrequency);
end;

function platform_time_windows_qpc_counter_u64(out ACounter: UInt64): Boolean;
var
  LCounter: Int64;
begin
  LCounter := 0;
  Result := QueryPerformanceCounter(LCounter);
  if not Result then
  begin
    ACounter := 0;
    Exit;
  end;

  if LCounter < 0 then
    ACounter := 0
  else
    ACounter := UInt64(LCounter);
end;

function platform_time_windows_filetime_now_unix_ns: UInt64;
var
  LFileTime: FILETIME;
  LValue: UInt64;
begin
  GetSystemTimeAsFileTime(LFileTime);
  LValue := (UInt64(LFileTime.dwHighDateTime) shl 32)
    or UInt64(LFileTime.dwLowDateTime);
  Result := (LValue - WINDOWS_FILETIME_UNIX_EPOCH_OFFSET_100NS)
    * WINDOWS_FILETIME_NANOSECONDS_PER_TICK;
end;

function platform_time_windows_monotonic_ns_u64: UInt64;
var
  LCounter: UInt64;
begin
  if not platform_time_windows_qpc_counter_u64(LCounter) then
    Exit(0);
  Result := platform_qpc_to_ns(LCounter, platform_time_windows_qpc_frequency_u64);
end;

function platform_time_windows_monotonic_resolution_ns_u64: UInt64;
begin
  Result := platform_resolution_from_frequency_ns(platform_time_windows_qpc_frequency_u64);
  if Result = 0 then
    Result := 1;
end;
{$ENDIF}

function platform_time_host_clock_monotonic_ns_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_MACOS}
  Result := platform_time_darwin_monotonic_ns_u64;
  {$ELSEIF defined(NEXTPAS_UNIX)}
  Result := platform_time_posix_clock_ns_u64(CLOCK_MONOTONIC);
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  Result := platform_time_windows_monotonic_ns_u64;
  {$ENDIF}
end;

function platform_time_host_clock_realtime_ns_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_UNIX}
  Result := platform_time_posix_clock_ns_u64(CLOCK_REALTIME);
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  Result := platform_time_windows_filetime_now_unix_ns;
  {$ENDIF}
end;

function platform_time_host_clock_monotonic_resolution_ns_u64: UInt64; inline;
begin
  {$IFDEF NEXTPAS_MACOS}
  Result := platform_time_darwin_monotonic_resolution_ns_u64;
  {$ELSEIF defined(NEXTPAS_UNIX)}
  Result := platform_time_posix_clock_resolution_ns_u64(CLOCK_MONOTONIC);
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  Result := platform_time_windows_monotonic_resolution_ns_u64;
  {$ENDIF}
end;

function platform_monotonic_ns: TPlatformTimeNanoseconds;
begin
  Result := platform_time_host_clock_monotonic_ns_u64;
end;

function platform_realtime_ns: TPlatformTimeNanoseconds;
begin
  Result := platform_time_host_clock_realtime_ns_u64;
end;

function platform_monotonic_resolution_ns: TPlatformTimeNanoseconds;
begin
  Result := platform_time_host_clock_monotonic_resolution_ns_u64;
end;

end.

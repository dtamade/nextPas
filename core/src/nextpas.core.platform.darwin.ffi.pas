unit nextpas.core.platform.darwin.ffi;

{$I nextpas.core.settings.inc}

interface

type
  mach_timebase_info_data_t = record
    numer: UInt32;
    denom: UInt32;
  end;

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(58);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_REALTIME_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0;

  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 0;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 2;

  PLATFORM_POSIX_EAGAIN = 35;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 45;
  PLATFORM_POSIX_ETIMEDOUT = 60;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(out info: mach_timebase_info_data_t): Int32; cdecl; external 'c' name 'mach_timebase_info';
function pthread_threadid_np(thread: Pointer; thread_id: PUInt64): Int32; cdecl; external 'pthread' name 'pthread_threadid_np';
function platform_errno_location: PInt32; cdecl; external 'c' name '__error';
function platform_posix_errno_value: Int32; inline;
function platform_thread_self_token_u64: UInt64; inline;
function platform_native_thread_id_u64: UInt64; inline;
function platform_cpu_count_i32: Int32; inline;
function darwin_mach_monotonic_ns: UInt64;
function darwin_mach_monotonic_resolution_ns: UInt64;
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32;

implementation

uses
  nextpas.core.platform.posix.ffi;

var
  GDarwinTimebaseNumer: UInt64 = 0;
  GDarwinTimebaseDenom: UInt64 = 0;

function platform_posix_errno_value: Int32; inline;
begin
  Result := platform_errno_location^;
end;

function platform_thread_self_token_u64: UInt64; inline;
begin
  Result := UInt64(PtrUInt(pthread_self));
end;

function platform_native_thread_id_u64: UInt64; inline;
begin
  Result := 0;
  if pthread_threadid_np(nil, @Result) <> 0 then
    Result := platform_thread_self_token_u64;
end;

function platform_cpu_count_i32: Int32; inline;
var
  LResult: PtrInt;
begin
  LResult := sysconf(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

function darwin_mul_div_floor(const AValue: UInt64; const AMultiplier: UInt64; const ADivisor: UInt64): UInt64;
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

function darwin_scale_units(const AValue: UInt64; const ADivisor: UInt64; const AMultiplier: UInt64): UInt64;
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
    LFrac := darwin_mul_div_floor(LRem, AMultiplier, LDivisor);

  if Result > High(UInt64) - LFrac then
    Exit(High(UInt64));

  Result := Result + LFrac;
end;

procedure darwin_ensure_timebase;
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

function darwin_mach_monotonic_ns: UInt64;
begin
  darwin_ensure_timebase;
  Result := darwin_scale_units(mach_absolute_time, GDarwinTimebaseDenom, GDarwinTimebaseNumer);
end;

function darwin_mach_monotonic_resolution_ns: UInt64;
begin
  darwin_ensure_timebase;
  if GDarwinTimebaseDenom = 0 then
    Result := 1
  else if GDarwinTimebaseNumer >= GDarwinTimebaseDenom then
    Result := (GDarwinTimebaseNumer + GDarwinTimebaseDenom - 1) div GDarwinTimebaseDenom
  else
    Result := 1;

  if Result = 0 then
    Result := 1;
end;

function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32;
begin
  Result := PLATFORM_POSIX_ENOTSUP;
end;

end.

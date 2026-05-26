unit nextpas.core.platform.time;

{$I nextpas.core.settings.inc}

interface

{**
 * @desc 单调时钟，纳秒精度
 * @note 契约：绝不倒退，不受系统时钟调整影响
 *       失败时返回 0（不应发生在正常系统上）
 *}
function platform_monotonic_ns: UInt64;

{**
 * @desc 实时时钟，纳秒精度
 * @note 契约：返回自 Unix epoch (1970-01-01T00:00:00Z) 以来的纳秒数
 *       可能因 NTP/手动调整而跳变
 *}
function platform_realtime_ns: UInt64;

{**
 * @desc 单调时钟分辨率
 * @note 契约：返回保守值（实际精度 >= 返回值），最小为 1ns
 *       不高估精度
 *}
function platform_monotonic_resolution_ns: UInt64;

{**
 * @desc QPC 计数器转纳秒（div/mod 安全，不溢出）
 * @note 纯函数，可单测
 *}
function platform_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64;

{**
 * @desc 计数器频率转纳秒级分辨率
 * @note 纯函数，可单测；使用 ceil，不高估时钟精度
 *}
function platform_resolution_from_frequency_ns(const AFrequency: UInt64): UInt64;

{**
 * @desc timespec 转纳秒
 * @note 纯函数，可单测
 *}
function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): UInt64;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_MACOS}, nextpas.core.platform.darwin.ffi{$ENDIF};
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;
{$ENDIF}

const
  NANOSECONDS_PER_SECOND = UInt64(1000000000);

function platform_mul_div_floor(const AValue: UInt64; const AMultiplier: UInt64; const ADivisor: UInt64): UInt64;
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

function platform_scale_units(const AValue: UInt64; const ADivisor: UInt64; const AMultiplier: UInt64): UInt64;
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
    LFrac := platform_mul_div_floor(LRem, AMultiplier, LDivisor);
  if Result > High(UInt64) - LFrac then
    Exit(High(UInt64));

  Result := Result + LFrac;
end;

function platform_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64;
begin
  Result := platform_scale_units(ACounter, AFrequency, NANOSECONDS_PER_SECOND);
end;

function platform_resolution_from_frequency_ns(const AFrequency: UInt64): UInt64;
begin
  if AFrequency = 0 then
    Exit(1);
  if AFrequency >= NANOSECONDS_PER_SECOND then
    Exit(1);
  Result := (NANOSECONDS_PER_SECOND + AFrequency - 1) div AFrequency;
  if Result = 0 then
    Result := 1;
end;

function platform_timespec_to_ns(const ASec: Int64; const ANsec: Int64): UInt64;
var
  LSecNs: UInt64;
  LNsec: UInt64;
begin
  if (ASec < 0) or (ANsec < 0) then
    Exit(0);
  if UInt64(ASec) > High(UInt64) div NANOSECONDS_PER_SECOND then
    Exit(High(UInt64));

  LSecNs := UInt64(ASec) * NANOSECONDS_PER_SECOND;
  LNsec := UInt64(ANsec);
  if LSecNs > High(UInt64) - LNsec then
    Exit(High(UInt64));

  Result := LSecNs + LNsec;
end;

{ ============================================================ }
{ POSIX: clock_gettime(CLOCK_MONOTONIC / CLOCK_REALTIME)       }
{ ============================================================ }
{$IFDEF NEXTPAS_POSIX_CLOCK}

function platform_monotonic_ns: UInt64;
var
  LTs: timespec;
begin
  if clock_gettime(CLOCK_MONOTONIC, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := platform_timespec_to_ns(LTs.tv_sec, LTs.tv_nsec);
end;

function platform_realtime_ns: UInt64;
var
  LTs: timespec;
begin
  if clock_gettime(CLOCK_REALTIME, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := platform_timespec_to_ns(LTs.tv_sec, LTs.tv_nsec);
end;

function platform_monotonic_resolution_ns: UInt64;
var
  LTs: timespec;
begin
  if clock_getres(CLOCK_MONOTONIC, @LTs) <> 0 then
  begin
    Result := 1;
    Exit;
  end;
  Result := platform_timespec_to_ns(LTs.tv_sec, LTs.tv_nsec);
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{ ============================================================ }
{ macOS: mach_absolute_time + clock_gettime (10.12+)           }
{ ============================================================ }
{$IFDEF NEXTPAS_MACOS}

var
  GTimebaseNumer: UInt64 = 0;
  GTimebaseDenom: UInt64 = 0;

procedure EnsureTimebase;
var
  LInfo: mach_timebase_info_data_t;
begin
  if GTimebaseDenom = 0 then
  begin
    mach_timebase_info(LInfo);
    GTimebaseNumer := LInfo.numer;
    GTimebaseDenom := LInfo.denom;
    if GTimebaseDenom = 0 then
    begin
      GTimebaseNumer := 1;
      GTimebaseDenom := 1;
    end;
  end;
end;

function platform_monotonic_ns: UInt64;
var
  LTicks: UInt64;
begin
  EnsureTimebase;
  LTicks := mach_absolute_time;
  Result := platform_scale_units(LTicks, GTimebaseDenom, GTimebaseNumer);
end;

function platform_realtime_ns: UInt64;
var
  LTs: timespec;
begin
  if clock_gettime(CLOCK_REALTIME, @LTs) <> 0 then
  begin
    Result := 0;
    Exit;
  end;
  Result := platform_timespec_to_ns(LTs.tv_sec, LTs.tv_nsec);
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  EnsureTimebase;
  if GTimebaseDenom = 0 then
    Result := 1
  else if GTimebaseNumer >= GTimebaseDenom then
    Result := (GTimebaseNumer + GTimebaseDenom - 1) div GTimebaseDenom
  else
    Result := 1;
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{ ============================================================ }
{ Windows: QueryPerformanceCounter (div/mod safe conversion)   }
{ ============================================================ }
{$IFDEF NEXTPAS_WINDOWS}

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

{**
 * @desc QPC → nanoseconds 无溢出换算
 * @note 使用 div/mod 分段：(counter div freq) * 1e9 + (counter mod freq) * 1e9 / freq
 *       避免 counter * 1e9 的 UInt64 溢出
 *}
function platform_monotonic_ns: UInt64;
var
  LCounter: Int64;
  LFreq: UInt64;
begin
  EnsureFrequency;
  if not QueryPerformanceCounter(LCounter) then
  begin
    Result := 0;
    Exit;
  end;
  LFreq := UInt64(GFrequency);
  Result := platform_qpc_to_ns(UInt64(LCounter), LFreq);
end;

function platform_realtime_ns: UInt64;
var
  LFt: FILETIME;
  LVal: UInt64;
begin
  GetSystemTimeAsFileTime(LFt);
  LVal := (UInt64(LFt.dwHighDateTime) shl 32) or UInt64(LFt.dwLowDateTime);
  // FILETIME is 100ns intervals since 1601-01-01
  // Unix epoch offset: 116444736000000000 * 100ns
  Result := (LVal - UInt64(116444736000000000)) * UInt64(100);
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  EnsureFrequency;
  Result := platform_resolution_from_frequency_ns(UInt64(GFrequency));
  if Result = 0 then
    Result := 1;
end;

{$ENDIF}

{ ============================================================ }
{ Unsupported platform: compile-time error                     }
{ ============================================================ }
{$IFNDEF NEXTPAS_POSIX_CLOCK}
{$IFNDEF NEXTPAS_MACOS}
{$IFNDEF NEXTPAS_WINDOWS}
  {$FATAL 'nextpas.core.platform.time: unsupported platform. Implement for your target.'}
{$ENDIF}
{$ENDIF}
{$ENDIF}

end.

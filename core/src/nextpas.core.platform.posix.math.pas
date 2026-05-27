unit nextpas.core.platform.posix.math;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

const
  PLATFORM_POSIX_NANOSECONDS_PER_SECOND = UInt64(1000000000);

function platform_posix_timespec_to_ns_u64(const ATime: PTimeSpec): UInt64; inline;
procedure platform_posix_timespec_add_ns(var ATime: timespec; const ANanoseconds: UInt64); inline;
function platform_posix_timespec_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  const ANow: PTimeSpec): UInt64; inline;

implementation

function platform_posix_timespec_to_ns_u64(const ATime: PTimeSpec): UInt64; inline;
var
  LSecNs: UInt64;
  LNsec: UInt64;
begin
  if ATime = nil then
    Exit(0);
  if (ATime^.tv_sec < 0) or (ATime^.tv_nsec < 0) then
    Exit(0);
  if UInt64(ATime^.tv_sec) > High(UInt64) div PLATFORM_POSIX_NANOSECONDS_PER_SECOND then
    Exit(High(UInt64));

  LSecNs := UInt64(ATime^.tv_sec) * PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
  LNsec := UInt64(ATime^.tv_nsec);
  if LSecNs > High(UInt64) - LNsec then
    Exit(High(UInt64));

  Result := LSecNs + LNsec;
end;

procedure platform_posix_timespec_add_ns(var ATime: timespec; const ANanoseconds: UInt64); inline;
var
  LSeconds: UInt64;
  LNanos: UInt64;
begin
  LSeconds := ANanoseconds div PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
  LNanos := ANanoseconds mod PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
  ATime.tv_sec := ATime.tv_sec + Int64(LSeconds);
  ATime.tv_nsec := ATime.tv_nsec + Int64(LNanos);
  if ATime.tv_nsec >= Int64(PLATFORM_POSIX_NANOSECONDS_PER_SECOND) then
  begin
    Inc(ATime.tv_sec);
    Dec(ATime.tv_nsec, Int64(PLATFORM_POSIX_NANOSECONDS_PER_SECOND));
  end;
end;

function platform_posix_timespec_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  const ANow: PTimeSpec): UInt64; inline;
var
  LDeadlineNs: UInt64;
  LNowNs: UInt64;
begin
  LDeadlineNs := platform_posix_timespec_to_ns_u64(ADeadline);
  LNowNs := platform_posix_timespec_to_ns_u64(ANow);
  if LDeadlineNs <= LNowNs then
    Exit(0);
  Result := LDeadlineNs - LNowNs;
end;

end.

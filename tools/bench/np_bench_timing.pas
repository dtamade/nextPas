unit np_bench_timing;

{$mode objfpc}{$H+}

interface

const
  BENCH_TIMING_SOURCE = 'process-cpu';

function TryReadProcessCpuNanoseconds(out AValue: Int64): Boolean;
function ElapsedMilliseconds(
  const AStartNanoseconds: Int64;
  const AEndNanoseconds: Int64
): Int64;

implementation

const
  CLOCK_PROCESS_CPUTIME_ID = 2;
  NANOSECONDS_PER_SECOND: Int64 = 1000000000;
  NANOSECONDS_PER_MILLISECOND: Int64 = 1000000;

type
  TClockTimeSpec = record
    tv_sec: Int64;
    tv_nsec: Int64;
  end;

function clock_gettime(
  AClockId: LongInt;
  var ATime: TClockTimeSpec
): LongInt; cdecl; external 'c' name 'clock_gettime';

function TryReadProcessCpuNanoseconds(out AValue: Int64): Boolean;
var
  TimeSpec: TClockTimeSpec;
begin
  AValue := 0;
  Result := clock_gettime(CLOCK_PROCESS_CPUTIME_ID, TimeSpec) = 0;
  if Result then
    AValue := (TimeSpec.tv_sec * NANOSECONDS_PER_SECOND) + TimeSpec.tv_nsec;
end;

function ElapsedMilliseconds(
  const AStartNanoseconds: Int64;
  const AEndNanoseconds: Int64
): Int64;
var
  DeltaNanoseconds: Int64;
begin
  if AEndNanoseconds <= AStartNanoseconds then
    Exit(1);

  DeltaNanoseconds := AEndNanoseconds - AStartNanoseconds;
  Result := DeltaNanoseconds div NANOSECONDS_PER_MILLISECOND;
  if Result <= 0 then
    Result := 1;
end;

end.

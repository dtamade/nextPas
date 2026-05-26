unit nextpas.core.time.cpu;

{$I nextpas.core.settings.inc}

interface

procedure CpuRelax;
procedure SchedYield; inline;
procedure NanoSleep(const ANanoseconds: UInt64); inline;
function CpuCount: Int32; inline;
function CurrentThreadId: UInt64; inline;

implementation

uses
  nextpas.core.platform.thread;

procedure CpuRelax;
begin
  platform_thread_yield;
end;

procedure SchedYield;
begin
  platform_thread_yield;
end;

procedure NanoSleep(const ANanoseconds: UInt64);
begin
  platform_thread_sleep_ns(ANanoseconds);
end;

function CpuCount: Int32;
begin
  Result := platform_cpu_count;
end;

function CurrentThreadId: UInt64;
begin
  Result := platform_thread_id;
end;

end.

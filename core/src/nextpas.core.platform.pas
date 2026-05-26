unit nextpas.core.platform;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.base,
  nextpas.core.platform.time;

type
  TOSKind = nextpas.core.platform.base.TOSKind;
  TCPUArch = nextpas.core.platform.base.TCPUArch;
  TEndianness = nextpas.core.platform.base.TEndianness;

function CurrentOS: TOSKind; inline;
function CurrentCPU: TCPUArch; inline;
function CurrentEndian: TEndianness; inline;
function OSName: string; inline;
function CPUName: string; inline;

{ Time }
function platform_monotonic_ns: UInt64; inline;
function platform_realtime_ns: UInt64; inline;
function platform_monotonic_resolution_ns: UInt64; inline;

implementation

function CurrentOS: TOSKind;
begin
  Result := CURRENT_OS;
end;

function CurrentCPU: TCPUArch;
begin
  Result := CURRENT_CPU;
end;

function CurrentEndian: TEndianness;
begin
  Result := CURRENT_ENDIAN;
end;

function OSName: string;
begin
  case CurrentOS of
    osLinux: Result := 'Linux';
    osMacOS: Result := 'macOS';
    osWindows: Result := 'Windows';
  else
    Result := 'Unknown';
  end;
end;

function CPUName: string;
begin
  case CurrentCPU of
    cpuX86_64: Result := 'x86_64';
    cpuAArch64: Result := 'aarch64';
  else
    Result := 'Unknown';
  end;
end;

function platform_monotonic_ns: UInt64;
begin
  Result := nextpas.core.platform.time.platform_monotonic_ns;
end;

function platform_realtime_ns: UInt64;
begin
  Result := nextpas.core.platform.time.platform_realtime_ns;
end;

function platform_monotonic_resolution_ns: UInt64;
begin
  Result := nextpas.core.platform.time.platform_monotonic_resolution_ns;
end;

end.

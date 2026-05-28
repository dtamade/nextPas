unit nextpas.core.simd.cpuinfo.darwin;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

function DetectCoreCounts(out Physical, Logical: LongInt): Boolean;

implementation

uses
  BaseUnix,
  ctypes;

function sysctlbyname(Name: PAnsiChar; oldp: Pointer; oldlenp: psize_t; newp: Pointer;
  newlen: size_t): cint; cdecl; external name 'sysctlbyname';

function ReadCpuCountByName(const aName: PAnsiChar; out aValue: LongInt): Boolean;
var
  LRawValue: cint;
  LSize: size_t;
begin
  LRawValue := 0;
  LSize := SizeOf(LRawValue);
  Result := sysctlbyname(aName, @LRawValue, @LSize, nil, 0) = 0;
  if Result then
    aValue := LRawValue;
end;

function DetectCoreCounts(out Physical, Logical: LongInt): Boolean;
begin
  Physical := 0;
  Logical := 0;

  if (not ReadCpuCountByName('hw.physicalcpu', Physical)) or (Physical < 1) then
    if (not ReadCpuCountByName('hw.physicalcpu_max', Physical)) or (Physical < 1) then
      ReadCpuCountByName('machdep.cpu.core_count', Physical);

  if (not ReadCpuCountByName('hw.logicalcpu', Logical)) or (Logical < 1) then
    if (not ReadCpuCountByName('hw.activecpu', Logical)) or (Logical < 1) then
      ReadCpuCountByName('hw.ncpu', Logical);

  if Logical < 1 then
    Logical := Physical;
  if Physical < 1 then
    Physical := Logical;

  if Physical < 1 then
    Physical := 1;
  if Logical < 1 then
    Logical := 1;

  Result := (Physical > 0) and (Logical > 0);
end;

end.

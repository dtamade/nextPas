program fafafa_core_simd_cpuinfo_darwin_link_smoke;

{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}

uses
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base;

var
  LInfo: TCPUInfo;
begin
  LInfo := GetCPUInfo;
  if LInfo.Arch = caUnknown then
    Halt(0);
end.

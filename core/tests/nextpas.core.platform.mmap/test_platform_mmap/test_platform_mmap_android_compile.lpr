program test_platform_mmap_android_compile;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.mmap;

var
  M: TPlatformMappedFile;
  R: Int32;

begin
  FillChar(M, SizeOf(M), 0);
  R := platform_mmap_file(nil, M);
  if R = High(Int32) then
    Halt(1);
end.

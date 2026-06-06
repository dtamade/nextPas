program test_memory_manager_rtl;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.mem.manager.rtl;

var
  T: TTestRunner;

procedure TestInstallAllocateUninstall;
var
  LPtr: Pointer;
begin
  Check(not IsRtlMemoryManagerInstalled, 'rtl manager should start uninstalled');

  InstallRtlMemoryManager;
  try
    Check(IsRtlMemoryManagerInstalled, 'rtl manager should report installed');
    GetMem(LPtr, 64);
    try
      Check(LPtr <> nil, 'GetMem should still work after installing manager');
      PByte(LPtr)^ := $5A;
      CheckEqual(Int64($5A), Int64(PByte(LPtr)^), 'allocated memory should be writable');
    finally
      FreeMem(LPtr);
    end;
  finally
    UninstallRtlMemoryManager;
  end;

  Check(not IsRtlMemoryManagerInstalled, 'rtl manager should report uninstalled');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.manager.rtl');
  T.Run('install allocate uninstall', @TestInstallAllocateUninstall);
  T.Summary;
end.

program test_platform_windows_utf16_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.dl,
  nextpas.core.platform.env,
  nextpas.core.platform.files,
  nextpas.core.platform.mmap,
  nextpas.core.platform.path,
  nextpas.core.platform.process,
  nextpas.core.platform.pty
{$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.utf16
{$ENDIF}
  ;

begin
end.

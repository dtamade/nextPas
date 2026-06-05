program test_platform_windows_signal_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.signal;

var
  GSeen: Int32;

procedure SignalHandler(ASignal: Int32); cdecl;
begin
  GSeen := ASignal;
end;

procedure TouchSignalContracts;
begin
  platform_signal_set(PLATFORM_SIGINT, @SignalHandler);
{$IFDEF NEXTPAS_WINDOWS}
  platform_signal_set(PLATFORM_SIGBREAK, @SignalHandler);
{$ENDIF}
end;

begin
  GSeen := 0;
  if GSeen <> 0 then
    Halt(1);
end.

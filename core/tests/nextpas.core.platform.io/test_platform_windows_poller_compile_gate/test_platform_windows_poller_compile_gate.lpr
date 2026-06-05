program test_platform_windows_poller_compile_gate;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.io.base,
  nextpas.core.platform.io
{$IFDEF NEXTPAS_WINDOWS}
  , nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi
{$ENDIF}
  ;

procedure TouchPollerContracts;
var
  LPoller: TPlatformPoller;
  LEntries: array[0..1] of TPlatformPollEntry;
  LCount: Int32;
begin
  FillChar(LPoller, SizeOf(LPoller), 0);
  FillChar(LEntries, SizeOf(LEntries), 0);
  platform_poller_create(LPoller);
  platform_poller_add(LPoller, PtrUInt(0), [peReadable], nil);
  platform_poller_modify(LPoller, PtrUInt(0), [peWritable], nil);
  platform_poller_remove(LPoller, PtrUInt(0));
  platform_poller_enable_wake(LPoller, nil);
  platform_poller_wake(LPoller);
  platform_poller_drain_wake(LPoller);
  platform_poller_wait(LPoller, @LEntries[0], Length(LEntries), 0, LCount);
  platform_poller_close(LPoller);
end;

begin
  TouchPollerContracts;
end.

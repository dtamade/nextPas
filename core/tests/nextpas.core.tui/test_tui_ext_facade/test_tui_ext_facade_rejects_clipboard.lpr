program test_tui_ext_facade_rejects_clipboard;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

var
  LClipboard: TClipboard;

begin
  LClipboard.Method := cmOSC52;
end.

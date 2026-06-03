program test_tui_core_facade_rejects_clipboard;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui;

var
  LClipboard: TClipboard;
  LMethod: Integer;

begin
  LClipboard := Default(TClipboard);
  LMethod := Ord(cmOSC52);
  if LMethod = 0 then
    LClipboard := LClipboard;
end.

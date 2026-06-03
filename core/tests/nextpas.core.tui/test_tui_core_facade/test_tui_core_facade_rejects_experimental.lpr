program test_tui_core_facade_rejects_experimental;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui;

var
  LProtocol: TImageProtocol;

begin
  LProtocol := DetectImageProtocol;
end.

program test_tui_ext_facade_rejects_image_protocol;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

var
  LProtocol: TImageProtocol;

begin
  LProtocol := DetectImageProtocol;
end.

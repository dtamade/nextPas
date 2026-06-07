program test_tui_ext_facade_rejects_canvas;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

var
  LCanvas: ICanvas;

begin
  LCanvas := TCanvas.New(1, 1);
end.

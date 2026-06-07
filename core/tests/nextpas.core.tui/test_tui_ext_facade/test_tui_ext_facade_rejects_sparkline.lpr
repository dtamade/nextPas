program test_tui_ext_facade_rejects_sparkline;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

var
  LSparkline: ISparkline;

begin
  LSparkline := TSparkline.New;
end.

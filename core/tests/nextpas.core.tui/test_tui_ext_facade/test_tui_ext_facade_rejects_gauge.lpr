program test_tui_ext_facade_rejects_gauge;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

var
  LGauge: IGauge;

begin
  LGauge := TGauge.New;
end.

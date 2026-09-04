program ConsoleSmoke;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.builder,
  nextpas.core.tui.ansi,
  nextpas.core.tui.color;

var
  B: TStringBuilder;
begin
  B.Init(64);
  AnsiSgrFg(B, IndexedColor(10));
  Write(B.ToString);
  WriteLn('nextpas crt smoke');
  B.Clear;
  AnsiSgrReset(B);
  Write(B.ToString);
  B.Done;
end.

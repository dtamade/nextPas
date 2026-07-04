program test_tui_experimental_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.experimental,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestExperimentalSurface;
var
  LProtocol: TImageProtocol;
  LClipboard: TClipboard;
begin
  LProtocol := DetectImageProtocol;
  LClipboard := TClipboard.Detect;
  Check(Ord(LProtocol) >= Ord(ipAuto), 'experimental facade exposes image protocol contract');
  Check(Ord(LClipboard.Method) >= Ord(cmOSC52), 'experimental facade exposes clipboard contract');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.experimental_facade');
  T.Test('experimental surface', @TestExperimentalSurface);
  if not T.Run then Halt(1);
end.

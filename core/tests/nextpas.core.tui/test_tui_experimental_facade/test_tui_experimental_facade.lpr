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

procedure TestImageProtocolEnumOrder;
begin
  Check(Ord(ipAuto) < Ord(ipKitty), 'auto < kitty');
  Check(Ord(ipKitty) < Ord(ipSixel), 'kitty < sixel');
  Check(Ord(ipSixel) < Ord(ipHalfBlock), 'sixel < halfblock');
end;

procedure TestDetectImageProtocolInRange;
var
  P: TImageProtocol;
begin
  P := DetectImageProtocol;
  Check((P >= ipAuto) and (P <= ipHalfBlock), 'protocol in range');
end;

procedure TestClipboardMethodsDistinct;
begin
  Check(cmOSC52 <> cmExternal, 'osc52 != external');
  Check(cmExternal <> cmNone, 'external != none');
  Check(cmOSC52 <> cmNone, 'osc52 != none');
end;

procedure TestClipboardDetectMethodValid;
var
  C: TClipboard;
begin
  C := TClipboard.Detect;
  Check((C.Method = cmOSC52) or (C.Method = cmExternal) or (C.Method = cmNone),
    'method is valid enum');
end;

procedure TestHalfBlockProtocolNamed;
begin
  Check(ipHalfBlock <> ipKitty, 'halfblock != kitty');
  Check(ipHalfBlock <> ipSixel, 'halfblock != sixel');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.experimental_facade');
  T.Test('experimental surface', @TestExperimentalSurface);
  T.Test('image protocol enum order', @TestImageProtocolEnumOrder);
  T.Test('detect protocol in range', @TestDetectImageProtocolInRange);
  T.Test('clipboard methods distinct', @TestClipboardMethodsDistinct);
  T.Test('clipboard detect method valid', @TestClipboardDetectMethodValid);
  T.Test('halfblock protocol named', @TestHalfBlockProtocolNamed);
  if not T.Run then Halt(1);
end.

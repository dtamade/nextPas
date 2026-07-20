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

procedure TestAutoNotHalfBlock;
begin
  Check(ipAuto <> ipHalfBlock, 'auto != halfblock');
  Check(ipAuto <> ipSixel, 'auto != sixel');
end;

procedure TestKittyNotSixel;
begin
  Check(ipKitty <> ipSixel, 'kitty != sixel');
  Check(ipKitty <> ipHalfBlock, 'kitty != halfblock');
end;

procedure TestClipboardDetectTwiceStableMethod;
var
  A, B: TClipboard;
begin
  A := TClipboard.Detect;
  B := TClipboard.Detect;
  Check(A.Method = B.Method, 'detect method stable across calls');
end;

procedure TestProtocolOrdinalsNonNegative;
begin
  Check(Ord(ipAuto) >= 0, 'auto >= 0');
  Check(Ord(ipHalfBlock) >= Ord(ipAuto), 'halfblock >= auto');
end;

procedure TestDetectProtocolIdempotent;
var
  A, B: TImageProtocol;
begin
  A := DetectImageProtocol;
  B := DetectImageProtocol;
  Check(A = B, 'detect protocol idempotent');
end;

procedure TestClipboardNoneIsDistinct;
begin
  Check(cmNone <> cmOSC52, 'none != osc52');
  Check(cmNone <> cmExternal, 'none != external');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.experimental_facade');
  T.Test('experimental surface', @TestExperimentalSurface);
  T.Test('image protocol enum order', @TestImageProtocolEnumOrder);
  T.Test('detect protocol in range', @TestDetectImageProtocolInRange);
  T.Test('clipboard methods distinct', @TestClipboardMethodsDistinct);
  T.Test('clipboard detect method valid', @TestClipboardDetectMethodValid);
  T.Test('halfblock protocol named', @TestHalfBlockProtocolNamed);
  T.Test('auto not halfblock', @TestAutoNotHalfBlock);
  T.Test('kitty not sixel', @TestKittyNotSixel);
  T.Test('clipboard detect twice stable', @TestClipboardDetectTwiceStableMethod);
  T.Test('protocol ordinals non-negative', @TestProtocolOrdinalsNonNegative);
  T.Test('detect protocol idempotent', @TestDetectProtocolIdempotent);
  T.Test('clipboard none distinct', @TestClipboardNoneIsDistinct);
  if not T.Run then Halt(1);
end.

program test_tui_image_cap;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.image_cap,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestDetectsKittyProtocolFromKnownHints;
begin
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    'xterm-kitty', '', '', '')),
    'TERM=xterm-kitty selects kitty');
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    '', 'WezTerm', '', '')),
    'TERM_PROGRAM=WezTerm selects kitty');
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    '', 'ghostty', '', '')),
    'TERM_PROGRAM=ghostty selects kitty');
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    '', '', '', 'kitty-window')),
    'KITTY_WINDOW_ID selects kitty');
end;

procedure TestDetectsSixelProtocolFromKnownHints;
begin
  CheckEqual(Ord(ipSixel), Ord(DetectImageProtocolFromHints(
    '', '', 'sixel', '')),
    'TERM_FEATURES=sixel selects sixel');
  CheckEqual(Ord(ipSixel), Ord(DetectImageProtocolFromHints(
    'foot', '', '', '')),
    'TERM=foot selects sixel');
  CheckEqual(Ord(ipSixel), Ord(DetectImageProtocolFromHints(
    '', 'mlterm', '', '')),
    'TERM_PROGRAM=mlterm selects sixel');
  CheckEqual(Ord(ipSixel), Ord(DetectImageProtocolFromHints(
    '', 'contour', '', '')),
    'TERM_PROGRAM=contour selects sixel');
  CheckEqual(Ord(ipSixel), Ord(DetectImageProtocolFromHints(
    'yaft-256color', '', '', '')),
    'TERM=yaft-256color selects sixel');
  CheckEqual(Ord(ipSixel), Ord(DetectImageProtocolFromHints(
    '', 'xterm', '', '')),
    'TERM_PROGRAM=xterm selects sixel');
end;

procedure TestFallsBackConservativelyWithoutEnhancedHints;
begin
  CheckEqual(Ord(ipHalfBlock), Ord(DetectImageProtocolFromHints(
    '', '', '', '')),
    'empty hints fall back to half-block');
  CheckEqual(Ord(ipHalfBlock), Ord(DetectImageProtocolFromHints(
    'xterm-256color', '', '', '')),
    'generic xterm term falls back to half-block');
  CheckEqual(Ord(ipHalfBlock), Ord(DetectImageProtocolFromHints(
    '', 'gnome-terminal', '', '')),
    'generic terminal programs fall back to half-block');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.image_cap');
  T.Run('detects kitty protocol from known hints',
    @TestDetectsKittyProtocolFromKnownHints);
  T.Run('detects sixel protocol from known hints',
    @TestDetectsSixelProtocolFromKnownHints);
  T.Run('falls back conservatively without enhanced hints',
    @TestFallsBackConservativelyWithoutEnhancedHints);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.

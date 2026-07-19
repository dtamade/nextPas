program test_tui_image_cap;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.image_cap,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestKittyTakesPriorityOverSixelHints;
begin
  // TERM has 'kitty' AND TERM_FEATURES has 'sixel' → kitty wins
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    'xterm-kitty', '', 'sixel', '')),
    'kitty TERM wins over sixel features');
  // KITTY_WINDOW_ID set AND TERM=foot → kitty wins
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    'foot', '', '', '12345')),
    'KITTY_WINDOW_ID wins over sixel TERM=foot');
end;

procedure TestDetectionIsCaseSensitive;
begin
  // WezTerm is case-sensitive (capital W)
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    '', 'WezTerm', '', '')),
    'WezTerm (capital W) → kitty');
  // 'wezterm' (lowercase) should NOT match kitty
  CheckEqual(Ord(ipHalfBlock), Ord(DetectImageProtocolFromHints(
    '', 'wezterm', '', '')),
    'wezterm (lowercase) → fallback');
  // 'Foot' (capital F) should NOT match sixel
  CheckEqual(Ord(ipHalfBlock), Ord(DetectImageProtocolFromHints(
    '', 'Foot', '', '')),
    'Foot (capital) → fallback');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.image_cap');
  T.Test('detects kitty protocol from known hints',
    @TestDetectsKittyProtocolFromKnownHints);
  T.Test('detects sixel protocol from known hints',
    @TestDetectsSixelProtocolFromKnownHints);
  T.Test('falls back conservatively without enhanced hints',
    @TestFallsBackConservativelyWithoutEnhancedHints);
  T.Test('kitty takes priority over sixel hints',
    @TestKittyTakesPriorityOverSixelHints);
  T.Test('detection is case-sensitive',
    @TestDetectionIsCaseSensitive);
  if not T.Run then Halt(1);
end.

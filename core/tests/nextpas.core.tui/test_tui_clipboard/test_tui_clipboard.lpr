program test_tui_clipboard;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.clipboard,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestGetOSC52CopyEmpty;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('');
  Check(Pos(#27']52;c;', LResult) = 1, 'Should start with OSC52 prefix');
  Check(Pos(#27'\', LResult) > 0, 'Should end with ST');
end;

procedure TestGetOSC52CopySimple;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('hello');
  Check(Pos(#27']52;c;', LResult) = 1, 'Should start with OSC52 prefix');
  Check(Length(LResult) > 10, 'Should have reasonable length');
end;

procedure TestGetOSC52CopyBase64;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('AB');
  // Base64("AB") = "QUI="
  Check(Pos('QUI=', LResult) > 0, 'Should contain Base64 encoded text');
end;

procedure TestClipboardDetect;
var
  LClip: TClipboard;
begin
  LClip := TClipboard.Detect;
  // In CI/test environment, might be cmNone or cmExternal
  Check(LClip.Method in [cmOSC52, cmExternal, cmNone], 'Method should be valid');
end;

begin
  T := TTestSuite.Create('tui_clipboard');
  T.Test('GetOSC52Copy empty text', @TestGetOSC52CopyEmpty);
  T.Test('GetOSC52Copy simple text', @TestGetOSC52CopySimple);
  T.Test('GetOSC52Copy base64 encoding', @TestGetOSC52CopyBase64);
  T.Test('TClipboard.Detect', @TestClipboardDetect);
  if not T.Run then Halt(1);
end.

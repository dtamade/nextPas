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

{ --- Deepened tests --- }

procedure TestGetOSC52CopySingleChar;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('A');
  // Base64("A") = "QQ=="
  Check(Pos('QQ==', LResult) > 0, 'Single char base64');
  Check(Pos(#27']52;c;', LResult) = 1, 'Prefix present');
  Check(Pos(#27'\', LResult) > 0, 'Suffix present');
end;

procedure TestGetOSC52CopyThreeBytes;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('ABC');
  // Base64("ABC") = "QUJD"
  Check(Pos('QUJD', LResult) > 0, 'Three bytes base64 (no padding)');
end;

procedure TestGetOSC52CopyLongText;
var
  LClip: TClipboard;
  LResult: AnsiString;
  LText: AnsiString;
  LI: Integer;
begin
  LClip.Method := cmNone;
  SetLength(LText, 100);
  for LI := 1 to 100 do
    LText[LI] := Chr(Ord('a') + (LI mod 26));
  LResult := LClip.GetOSC52Copy(LText);
  Check(Pos(#27']52;c;', LResult) = 1, 'Long text prefix');
  Check(Pos(#27'\', LResult) > 0, 'Long text suffix');
  Check(Length(LResult) > 140, 'Long text encoded length');
end;

procedure TestGetOSC52CopyStructure;
var
  LClip: TClipboard;
  LResult: AnsiString;
  LStart, LEnd: Integer;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('test');
  // Structure: ESC]52;c;<base64>ESC\
  LStart := Pos(#27']52;c;', LResult);
  Check(LStart = 1, 'starts at position 1');
  LEnd := Pos(#27'\', LResult);
  Check(LEnd > LStart, 'ST after prefix');
  // Content between prefix and suffix should be base64
  Check(LEnd - LStart > 7, 'has content between prefix and suffix');
end;

begin
  T := TTestSuite.Create('tui_clipboard');
  T.Test('GetOSC52Copy empty text', @TestGetOSC52CopyEmpty);
  T.Test('GetOSC52Copy simple text', @TestGetOSC52CopySimple);
  T.Test('GetOSC52Copy base64 encoding', @TestGetOSC52CopyBase64);
  T.Test('TClipboard.Detect', @TestClipboardDetect);
  T.Test('GetOSC52Copy single char', @TestGetOSC52CopySingleChar);
  T.Test('GetOSC52Copy three bytes', @TestGetOSC52CopyThreeBytes);
  T.Test('GetOSC52Copy long text', @TestGetOSC52CopyLongText);
  T.Test('GetOSC52Copy structure', @TestGetOSC52CopyStructure);
  if not T.Run then Halt(1);
end.

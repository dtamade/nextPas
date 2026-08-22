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

procedure TestCopyNoneReturnsFalse;
var
  LClip: TClipboard;
begin
  LClip.Method := cmNone;
  Check(not LClip.Copy('test'), 'Copy with cmNone should return False');
end;

procedure TestPasteNoneReturnsEmpty;
var
  LClip: TClipboard;
begin
  LClip.Method := cmNone;
  Check(LClip.Paste = '', 'Paste with cmNone should return empty');
end;

procedure TestGetOSC52CopySpecialChars;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('<>&"''');
  Check(Pos(#27']52;c;', LResult) = 1, 'Special chars: prefix present');
  Check(Pos(#27'\', LResult) > 0, 'Special chars: suffix present');
  // Should contain base64 encoded content
  Check(Length(LResult) > 10, 'Special chars: has encoded content');
end;

procedure TestGetOSC52CopyNewlines;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy('line1' + #10 + 'line2');
  Check(Pos(#27']52;c;', LResult) = 1, 'Newlines: prefix present');
  Check(Pos(#27'\', LResult) > 0, 'Newlines: suffix present');
end;

procedure TestDetectMethodValid;
var
  LClip: TClipboard;
begin
  LClip := TClipboard.Detect;
  Check(LClip.Method in [cmOSC52, cmExternal, cmNone], 'Detect: valid method');
  if LClip.Method = cmExternal then
    Check(Length(LClip.ExternalTool) > 0, 'External method has tool name');
end;

procedure TestGetOSC52CopyTwoBytes;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  // Base64("AB") = "QUI=" (1 pad)
  LResult := LClip.GetOSC52Copy('AB');
  Check(Pos('QUI=', LResult) > 0, 'Two bytes base64 (1 pad)');
  Check(Pos(#27']52;c;', LResult) = 1, 'Two bytes: prefix');
  Check(Pos(#27'\', LResult) > 0, 'Two bytes: suffix');
end;

procedure TestGetOSC52CopyFourBytes;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  // Base64("test") = "dGVzdA==" (no padding)
  LResult := LClip.GetOSC52Copy('test');
  Check(Pos('dGVzdA==', LResult) > 0, 'Four bytes base64');
end;

procedure TestGetOSC52CopyZeroes;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  LResult := LClip.GetOSC52Copy(#0#0#0);
  Check(Pos(#27']52;c;', LResult) = 1, 'Zeroes: prefix');
  Check(Pos(#27'\', LResult) > 0, 'Zeroes: suffix');
end;

procedure TestGetOSC52CopyAllPrintable;
var
  LClip: TClipboard;
  LResult: AnsiString;
  LText: AnsiString;
  I: Integer;
begin
  LClip.Method := cmNone;
  SetLength(LText, 95);
  for I := 32 to 126 do
    LText[I - 31] := Chr(I);
  LResult := LClip.GetOSC52Copy(LText);
  Check(Pos(#27']52;c;', LResult) = 1, 'All printable: prefix');
  Check(Pos(#27'\', LResult) > 0, 'All printable: suffix');
  Check(Length(LResult) > 130, 'All printable: encoded length');
end;

procedure TestGetOSC52CopyOneByte;
var
  LClip: TClipboard;
  LResult: AnsiString;
begin
  LClip.Method := cmNone;
  // Base64("A") = "QQ==" (2 pads)
  LResult := LClip.GetOSC52Copy('A');
  Check(Pos('QQ==', LResult) > 0, 'One byte: 2 pad chars');
end;

{ --- k53 (code888 backfeed): tmux DCS passthrough envelope --- }

procedure TestOsc52SeqPlainMatchesLegacy;
var
  LClip: TClipboard;
begin
  { False 分支必须与既有 GetOSC52Copy 输出逐字节一致（零回归） }
  LClip.Method := cmNone;
  Check(Osc52Sequence('hello', False) = LClip.GetOSC52Copy('hello'),
    'plain branch byte-identical to GetOSC52Copy');
end;

procedure TestOsc52SeqPassthroughEnvelope;
var
  LGot, LWant: AnsiString;
begin
  { 锚 grok-build clipboard.rs osc52_sequence("hi", true)：
    ESC Ptmux ; ESC ESC ]52;c;aGk= BEL ST —— 内层 OSC 以 BEL 终止、
    额外翻倍 ESC 开启内层解析、ST 收尾 }
  LGot := Osc52Sequence('hi', True);
  LWant := #27'Ptmux;'#27#27']52;c;' + 'aGk=' + #7#27'\';
  Check(LGot = LWant, 'passthrough envelope exact bytes');
end;

procedure TestOsc52SeqPassthroughEmpty;
var
  LGot: AnsiString;
begin
  { 空载荷：Base64Encode('')='' → 信封骨架仍完整 }
  LGot := Osc52Sequence('', True);
  Check(Pos(#27'Ptmux;'#27#27']52;c;'#7#27'\', LGot) = 1,
    'empty payload keeps full envelope skeleton');
end;

procedure TestClipboardDetectPassthroughField;
var
  LClip: TClipboard;
begin
  { 字段存在且为 Boolean；具体值随环境（CI 无 TMUX → False，
    tmux pane 内 → True）——只验可赋值与读取稳定 }
  LClip := TClipboard.Detect;
  LClip.TmuxPassthrough := True;
  Check(LClip.TmuxPassthrough, 'field assignable and readable');
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
  T.Test('Copy with cmNone returns False', @TestCopyNoneReturnsFalse);
  T.Test('Paste with cmNone returns empty', @TestPasteNoneReturnsEmpty);
  T.Test('GetOSC52Copy special chars', @TestGetOSC52CopySpecialChars);
  T.Test('GetOSC52Copy newlines', @TestGetOSC52CopyNewlines);
  T.Test('Detect method valid', @TestDetectMethodValid);
  T.Test('GetOSC52Copy two bytes', @TestGetOSC52CopyTwoBytes);
  T.Test('GetOSC52Copy four bytes', @TestGetOSC52CopyFourBytes);
  T.Test('GetOSC52Copy zeroes', @TestGetOSC52CopyZeroes);
  T.Test('GetOSC52Copy all printable', @TestGetOSC52CopyAllPrintable);
  T.Test('GetOSC52Copy one byte padding', @TestGetOSC52CopyOneByte);
  T.Test('Osc52Seq plain matches legacy', @TestOsc52SeqPlainMatchesLegacy);
  T.Test('Osc52Seq passthrough envelope', @TestOsc52SeqPassthroughEnvelope);
  T.Test('Osc52Seq passthrough empty', @TestOsc52SeqPassthroughEmpty);
  T.Test('Detect passthrough field', @TestClipboardDetectPassthroughField);
  if not T.Run then Halt(1);
end.

program test_tui_clipboard_wine;
{ Wine runtime smoke for cmWin32 clipboard path — real user32 clipboard
  roundtrip inside Wine.  truth=wine-runtime-smoke; not a substitute for
  real Windows Terminal evidence, but exercises OpenClipboard/Set/Get,
  UTF-8 <-> UTF-16 conversion and handle ownership end to end. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.clipboard,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestDetectWin32;
var
  LClip: TClipboard;
begin
  { Win64 编译下 NEXTPAS_WINDOWS 生效 → Detect 必选原生通道 }
  LClip := TClipboard.Detect;
  Check(LClip.Method = cmWin32, 'detect picks cmWin32 on Windows');
end;

procedure TestCopyPasteRoundtripAscii;
var
  LClip: TClipboard;
begin
  LClip := TClipboard.Detect;
  Check(LClip.Copy('hello clipboard'), 'copy ascii ok');
  Check(LClip.Paste = 'hello clipboard', 'paste roundtrip ascii');
end;

procedure TestCopyPasteRoundtripCjk;
var
  LClip: TClipboard;
begin
  { 中文往返:验证 UTF-8 -> UTF-16 -> CF_UNICODETEXT -> UTF-8 全链无损 }
  LClip := TClipboard.Detect;
  Check(LClip.Copy('测试端点·剪贴板'), 'copy cjk ok');
  Check(LClip.Paste = '测试端点·剪贴板', 'paste roundtrip cjk');
end;

procedure TestCopyOverwritesPrevious;
var
  LClip: TClipboard;
begin
  { 连续两次复制:第二次覆盖第一次(EmptyClipboard + 所有权移交路径) }
  LClip := TClipboard.Detect;
  Check(LClip.Copy('first'), 'copy first');
  Check(LClip.Copy('second'), 'copy second');
  Check(LClip.Paste = 'second', 'second copy overwrites first');
end;

procedure TestCopyEmptyFailsGracefully;
var
  LClip: TClipboard;
begin
  LClip := TClipboard.Detect;
  Check(not LClip.Copy(''), 'empty copy returns False, no crash');
end;

begin
  T := TTestSuite.Create('tui_clipboard_wine');
  T.Test('detect win32', @TestDetectWin32);
  T.Test('roundtrip ascii', @TestCopyPasteRoundtripAscii);
  T.Test('roundtrip cjk', @TestCopyPasteRoundtripCjk);
  T.Test('overwrite previous', @TestCopyOverwritesPrevious);
  T.Test('empty copy graceful', @TestCopyEmptyFailsGracefully);
  if not T.Run then Halt(1);
end.

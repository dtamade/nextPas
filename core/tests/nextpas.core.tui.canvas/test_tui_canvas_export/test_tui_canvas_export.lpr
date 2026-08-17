program test_tui_canvas_export;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.text.utf8,
  nextpas.core.tui.canvas.export,
  nextpas.core.platform.files.text,
  nextpas.core.test;

const
  TXT_FILE = '/tmp/td888_core_export.txt';
  ANSI_FILE = '/tmp/td888_core_export.ansi';
  ESC = #27;

{ 整文件读回; 读失败(不存在等)返回空串 }
function ReadAll(const AFile: AnsiString): AnsiString;
begin
  if not FileReadAllText(AFile, Result) then
    Result := '';
end;

procedure TestExportTxt;
var
  D: TCanvasDoc;
  S: AnsiString;
begin
  D := TCanvasDoc.Create(3, 2);
  try
    { 活动层(层0)画几格, 含宽字 '你' }
    D.SetCell(0, 1, 0, CanvasMakeCell(65, TUI_RED, TUI_BLUE));  { 'A' }
    D.SetCell(0, 0, 1, CanvasMakeCell($4F60,
      RgbColor(255, 0, 0), RgbColor(0, 0, 255)));              { '你' }
    D.SetCell(0, 2, 1, CanvasMakeCell(66, TUI_GREEN, TUI_BLACK)); { 'B' }

    Check(CanvasExportTxt(D, TXT_FILE), 'txt write');
    S := ReadAll(TXT_FILE);
    CheckEqual(S, ' A ' + #10 + UTF8EncodeToStr($4F60) + ' B' + #10,
      'txt content exact');
    CheckEqual(Copy(S, 1, 4), ' A ' + #10, 'txt row0');
    Check(Pos(UTF8EncodeToStr($4F60), S) > 0, 'txt wide glyph utf8');
    Check((Length(S) >= 3) and (S[1] = ' ') and (S[3] = ' '),
      'txt empty cells spaces');
  finally
    D.Free;
  end;
end;

procedure TestExportAnsi;
var
  D: TCanvasDoc;
  S: AnsiString;
begin
  D := TCanvasDoc.Create(3, 2);
  try
    D.SetCell(0, 1, 0, CanvasMakeCell(65, TUI_RED, TUI_BLUE));
    D.SetCell(0, 0, 1, CanvasMakeCell($4F60,
      RgbColor(255, 0, 0), RgbColor(0, 0, 255)));
    D.SetCell(0, 2, 1, CanvasMakeCell(66, TUI_GREEN, TUI_BLACK));

    Check(CanvasExportAnsi(D, ANSI_FILE), 'ansi write');
    S := ReadAll(ANSI_FILE);
    Check(Pos(ESC + '[38;2;255;0;0m', S) > 0, 'ansi fg rgb');
    Check(Pos(ESC + '[48;2;0;0;255m', S) > 0, 'ansi bg rgb');
    Check(Pos(ESC + '[31m', S) > 0, 'ansi fg indexed');       { TUI_RED }
    Check(Pos(ESC + '[44m', S) > 0, 'ansi bg indexed');       { TUI_BLUE }
    Check(Pos(UTF8EncodeToStr($4F60), S) > 0, 'ansi wide glyph');
    CheckEqual(Copy(S, Length(S) - 3, 4), ESC + '[0m', 'ansi ends reset');
  finally
    D.Free;
  end;
end;

procedure TestFailPaths;
var
  D: TCanvasDoc;
begin
  D := TCanvasDoc.Create(3, 2);
  try
    { 写失败: 目标目录不存在 }
    Check(not CanvasExportTxt(D, '/nonexistent_dir/xx.txt'), 'txt fail path');
    Check(not CanvasExportAnsi(D, '/nonexistent_dir/xx.txt'), 'ansi fail path');
    { 空路径拒绝 }
    Check(not CanvasExportTxt(D, ''), 'txt empty path');
  finally
    D.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.export');
  T.Test('export txt', @TestExportTxt);
  T.Test('export ansi', @TestExportAnsi);
  T.Test('fail paths', @TestFailPaths);
  if not T.Run then Halt(1);
end.
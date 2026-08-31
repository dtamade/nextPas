{**
 * nextpas.core.tui.canvas.export - 字符画布导出
 *
 * CanvasExportTxt: 活动层纯字形快照(UTF-8), Ch=0 输出空格, 每行换行;
 * CanvasExportAnsi: 逐格 SGR 前景+背景 + 字形, 末尾 \e[0m 重置。
 * 写文件失败(路径不可写等)返回 False。不直接依赖 FPC RTL。
 *}

unit nextpas.core.tui.canvas.export;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base;

{** @desc 纯字形快照: 活动层 Ch<>0 输出字形(按 TCanvasDoc.GetCell, 宽字转 UTF-8),
    Ch=0 输出空格; 每行以换行结尾; 写文件失败返回 False *}
function CanvasExportTxt(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;
{** @desc ANSI 导出: 每格 SGR 前景+背景(ckRgb → 38;2;r;g;b / 48;2;r;g;b,
    ckIndexed → 3x/4x 索引)+字形, 末尾 \e[0m; 失败返回 False *}
function CanvasExportAnsi(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.utf8,
  nextpas.core.platform.files.text;

const
  ESC = #27;

{ ckIndexed → 16 色 SGR 码(0..7 → 30..37/40..47, 8..15 → 90..97/100..107);
  ckRgb → 38;2/48;2; ckUnset/ckReset 无 SGR。 }
function SgrColor(AColor: TColor; AFg: Boolean): AnsiString;
var
  N: Integer;
begin
  case AColor.Kind of
    ckRgb:
      if AFg then
        Result := ESC + '[38;2;' + IntToStr(AColor.R) + ';' + IntToStr(AColor.G)
          + ';' + IntToStr(AColor.B) + 'm'
      else
        Result := ESC + '[48;2;' + IntToStr(AColor.R) + ';' + IntToStr(AColor.G)
          + ';' + IntToStr(AColor.B) + 'm';
    ckIndexed:
      begin
        N := AColor.Index and 15;
        if AFg then
          Result := ESC + '[' + IntToStr(30 + (N and 7) + (N shr 3) * 60) + 'm'
        else
          Result := ESC + '[' + IntToStr(40 + (N and 7) + (N shr 3) * 60) + 'm';
      end;
  else
    Result := '';
  end;
end;

function CanvasExportTxt(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;
var
  S, Line: AnsiString;
  X, Y: Integer;
  Cell: TCanvasCell;
begin
  Result := False;
  if ADoc = nil then
    Exit;
  S := '';
  for Y := 0 to ADoc.Height - 1 do
  begin
    Line := '';
    for X := 0 to ADoc.Width - 1 do
    begin
      Cell := ADoc.GetCell(ADoc.ActiveIndex, X, Y);
      if Cell.Ch <> 0 then
        Line := Line + UTF8EncodeToStr(Cell.Ch)
      else
        Line := Line + ' ';
    end;
    S := S + Line + #10;
  end;
  Result := FileWriteAllText(AFileName, S);
end;

function CanvasExportAnsi(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;
var
  S, Line: AnsiString;
  X, Y: Integer;
  Cell: TCanvasCell;
begin
  Result := False;
  if ADoc = nil then
    Exit;
  S := '';
  for Y := 0 to ADoc.Height - 1 do
  begin
    Line := '';
    for X := 0 to ADoc.Width - 1 do
    begin
      Cell := ADoc.GetCell(ADoc.ActiveIndex, X, Y);
      Line := Line + SgrColor(Cell.Fg, True) + SgrColor(Cell.Bg, False);
      if Cell.Ch <> 0 then
        Line := Line + UTF8EncodeToStr(Cell.Ch)
      else
        Line := Line + ' ';
    end;
    S := S + Line + #10;
  end;
  S := S + ESC + '[0m';
  Result := FileWriteAllText(AFileName, S);
end;

end.

{**
 * nextpas.core.tui.canvas.export.wide - 宽字形对齐的字符画布导出
 *
 * CanvasExportTxtWideToStr / CanvasExportAnsiWideToStr: 生成导出文本
 *   (不落盘, 供剪贴板/预览等复用), 活动层纯字形快照(UTF-8),
 *   按显示列对齐——双宽字形(如 CJK)输出一次并跳过被其覆盖的右邻格
 *   (与渲染一致), Ch=0 输出空格, 每行换行;
 * CanvasExportTxtWide / CanvasExportAnsiWide: 同一生成逻辑 + 写文件,
 *   写文件失败(路径不可写等)返回 False。不直接依赖 FPC RTL。
 *}

unit nextpas.core.tui.canvas.export.wide;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.color;

{** @desc 宽字形对齐文本导出为字符串: 逐格扫描活动层, 双宽字形输出一次
    并跳过被覆盖的下一格(与渲染一致); 每行以换行结尾。
    文档为空引用返回空串 *}
function CanvasExportTxtWideToStr(ADoc: TCanvasDoc): AnsiString;

{** @desc 宽字形对齐 ANSI 导出为字符串: 每格 SGR 前景+背景 + 字形
    (ckRgb → 38;2;r;g;b / 48;2;r;g;b, ckIndexed → 3x/4x 索引),
    相邻同色省略(终端 SGR 状态跨格/跨行延续), 末尾 \e[0m。
    文档为空引用返回空串 *}
function CanvasExportAnsiWideToStr(ADoc: TCanvasDoc): AnsiString;

{** @desc 宽字形对齐文本导出: 生成字符串后写文件; 失败返回 False *}
function CanvasExportTxtWide(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;

{** @desc 宽字形对齐 ANSI 导出: 生成字符串后写文件; 失败返回 False *}
function CanvasExportAnsiWide(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.utf8,
  nextpas.core.text.width,
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

{ 逐格扫描活动层: 双宽字形输出一次并跳过被覆盖的右邻格(与渲染器
  WideNext 语义一致), 保证导出文本的显示列与画布画面一致。 }
function CanvasExportTxtWideToStr(ADoc: TCanvasDoc): AnsiString;
var
  S, Line: AnsiString;
  X, Y: Integer;
  Cell: TCanvasCell;
  WideNext: Boolean;
begin
  Result := '';
  if ADoc = nil then
    Exit;
  S := '';
  for Y := 0 to ADoc.Height - 1 do
  begin
    Line := '';
    WideNext := False;
    for X := 0 to ADoc.Width - 1 do
    begin
      if WideNext then
      begin
        WideNext := False;
        Continue;
      end;
      Cell := ADoc.GetCell(ADoc.ActiveIndex, X, Y);
      if Cell.Ch <> 0 then
      begin
        Line := Line + UTF8EncodeToStr(Cell.Ch);
        if CodepointWidth(Cell.Ch) > 1 then
          WideNext := True;
      end
      else
        Line := Line + ' ';
    end;
    S := S + Line + #10;
  end;
  Result := S;
end;

function CanvasExportTxtWide(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;
begin
  Result := False;
  if ADoc = nil then
    Exit;
  Result := FileWriteAllText(AFileName, CanvasExportTxtWideToStr(ADoc));
end;

function CanvasExportAnsiWideToStr(ADoc: TCanvasDoc): AnsiString;
var
  S, Line: AnsiString;
  FgS, BgS, LastSgr: AnsiString;
  X, Y: Integer;
  Cell: TCanvasCell;
  WideNext: Boolean;
begin
  Result := '';
  if ADoc = nil then
    Exit;
  S := '';
  LastSgr := '';
  for Y := 0 to ADoc.Height - 1 do
  begin
    Line := '';
    WideNext := False;
    for X := 0 to ADoc.Width - 1 do
    begin
      if WideNext then
      begin
        WideNext := False;
        Continue;
      end;
      Cell := ADoc.GetCell(ADoc.ActiveIndex, X, Y);
      { 同色压缩: 与上一格 SGR 相同则省略(终端 SGR 状态跨格/跨行延续) }
      FgS := SgrColor(Cell.Fg, True);
      BgS := SgrColor(Cell.Bg, False);
      if FgS + BgS <> LastSgr then
      begin
        Line := Line + FgS + BgS;
        LastSgr := FgS + BgS;
      end;
      if Cell.Ch <> 0 then
        Line := Line + UTF8EncodeToStr(Cell.Ch)
      else
        Line := Line + ' ';
      if (Cell.Ch <> 0) and (CodepointWidth(Cell.Ch) > 1) then
        WideNext := True;
    end;
    S := S + Line + #10;
  end;
  Result := S + ESC + '[0m';
end;

function CanvasExportAnsiWide(ADoc: TCanvasDoc; const AFileName: AnsiString): Boolean;
begin
  Result := False;
  if ADoc = nil then
    Exit;
  Result := FileWriteAllText(AFileName, CanvasExportAnsiWideToStr(ADoc));
end;

end.

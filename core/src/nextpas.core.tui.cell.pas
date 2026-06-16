unit nextpas.core.tui.cell;

{**
 * @desc 终端单元格（对齐 ratatui::buffer::Cell），packed record 40 字节。
 *
 * 布局：24 字节 glyph 块（1 长度 + 23 内联字节）+ 12 字节样式（Fg/Bg/Ul）
 * + 2 字节 Modifier + 1 字节 Width + 1 字节 Skip，打包去除填充，恰为
 * 40 字节，可按 5 个 QWord 整体比较。
 *
 * Glyph 内联 23 字节：任何 <=23 字节的 grapheme 完全存于 cell 内，热路径
 * 零堆分配。超过 23 字节静默截断（终端实际使用中所有 grapheme cluster
 * 都 <= 16 字节，含 CJK 与多数 ZWJ 序列）。
 *
 * CELL_EMPTY 对齐 ratatui Cell::EMPTY：空格、默认色（ckReset）、无修饰、
 * 宽度 1、skip=false。buffer reset/resize 用它填充。
 *
 * @note CellEquals 把 40 字节当 5 个 QWord 比较，绕开字段分派。Glyph setter
 *       会清理未使用尾字节，保证覆盖较短 grapheme 后仍保持 canonical。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style;

const
  TUI_CELL_GLYPH_BYTES = 23;

type
  TCellGlyph = packed record
    Len: Byte;
    Bytes: array[0..TUI_CELL_GLYPH_BYTES - 1] of Byte;
  end;

  TCell = packed record
    Glyph: TCellGlyph;
    Fg, Bg, Ul: TColor;
    Modifier: TModifier;
    Width: Byte;       { grapheme 显示宽度：1 或 2 }
    Skip: Boolean;
  end;
  PCell = ^TCell;

const
  { ratatui Cell::EMPTY 等价：空格、默认色、无修饰、宽 1、skip false。
    用作 buffer reset / resize 的填充值。 }
  CELL_EMPTY: TCell = (
    Glyph: (Len: 1; Bytes: (32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0));
    Fg: (Kind: ckReset; Index: 0);
    Bg: (Kind: ckReset; Index: 0);
    Ul: (Kind: ckReset; Index: 0);
    Modifier: [];
    Width: 1;
    Skip: False
  );

procedure CellReset(var ACell: TCell); inline;
procedure CellSetSymbolAscii(var ACell: TCell; const ACh: AnsiChar); inline;
procedure CellSetSymbolBytes(var ACell: TCell; const ABytes; ALen: Byte; AWidth: Byte);
procedure CellApplyStyle(var ACell: TCell; const AStyle: TStyle);
function  CellEquals(const A, B: TCell): Boolean; inline;
function  CellGlyphAsString(const ACell: TCell): AnsiString;

implementation

procedure CellReset(var ACell: TCell);
begin
  ACell := CELL_EMPTY;
end;

procedure CellClearGlyphTail(var ACell: TCell; AStart: Byte); inline;
var
  LI: Integer;
begin
  if AStart >= TUI_CELL_GLYPH_BYTES then
    Exit;
  for LI := AStart to TUI_CELL_GLYPH_BYTES - 1 do
    ACell.Glyph.Bytes[LI] := 0;
end;

procedure CellSetSymbolAscii(var ACell: TCell; const ACh: AnsiChar);
begin
  ACell.Glyph.Len := 1;
  ACell.Glyph.Bytes[0] := Byte(ACh);
  CellClearGlyphTail(ACell, 1);
  ACell.Width := 1;
  ACell.Skip := False;
end;

procedure CellSetSymbolBytes(var ACell: TCell; const ABytes; ALen: Byte; AWidth: Byte);
var
  LSrc: PByte;
begin
  if ALen > TUI_CELL_GLYPH_BYTES then
    ALen := TUI_CELL_GLYPH_BYTES;     { 静默截断（>23 字节 grapheme 属病态） }
  ACell.Glyph.Len := ALen;
  if ALen > 0 then
  begin
    LSrc := @ABytes;
    Move(LSrc^, ACell.Glyph.Bytes[0], ALen);
  end;
  CellClearGlyphTail(ACell, ALen);
  if AWidth = 0 then AWidth := 1;
  ACell.Width := AWidth;
  ACell.Skip := False;
end;

procedure CellApplyStyle(var ACell: TCell; const AStyle: TStyle);
begin
  { ratatui：仅 Some 字段覆盖；AddMod 并入，SubMod 移除。 }
  if ColorIsSet(AStyle.Fg) then ACell.Fg := AStyle.Fg;
  if ColorIsSet(AStyle.Bg) then ACell.Bg := AStyle.Bg;
  if ColorIsSet(AStyle.Ul) then ACell.Ul := AStyle.Ul;
  ACell.Modifier := (ACell.Modifier + AStyle.AddMod) - AStyle.SubMod;
end;

{$if SizeOf(TCell) <> 40}
  {$error TCell size changed from 40 bytes — update CellEquals and Buffer.Diff QWord comparisons}
{$endif}

function CellEquals(const A, B: TCell): Boolean;
var
  LPA, LPB: PQWord;
begin
  LPA := @A;
  LPB := @B;
  Result := (LPA[0] = LPB[0]) and (LPA[1] = LPB[1]) and (LPA[2] = LPB[2]) and
            (LPA[3] = LPB[3]) and (LPA[4] = LPB[4]);
end;

function CellGlyphAsString(const ACell: TCell): AnsiString;
begin
  if ACell.Glyph.Len = 0 then
    Exit('');
  SetLength(Result, ACell.Glyph.Len);
  Move(ACell.Glyph.Bytes[0], Result[1], ACell.Glyph.Len);
end;

end.

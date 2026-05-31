unit nextpas.core.tui.style;

{**
 * @desc 单元格样式（对齐 ratatui::style::Style），packed record 按值传递。
 *
 * 布局：
 *   Fg, Bg, Ul: TColor          (各 4 字节；ckUnset = ratatui None)
 *   AddMod, SubMod: TModifier   (各 2 字节；构造上互斥)
 *
 * Patch 语义逐字取自 ratatui 0.29 Style::patch：
 *   Fg/Bg/Ul   ── other.X.or(self.X)         (other 已设置则胜出)
 *   AddMod     ── (self.AddMod - other.SubMod) + other.AddMod
 *   SubMod     ── (self.SubMod - other.AddMod) + other.SubMod
 *
 * Patch 后单个修饰位不可能同时存在于 AddMod 和 SubMod——接收方先前状态
 * 被 other 中提及它的那一侧覆盖。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier;

type
  TStyle = packed record
    Fg, Bg, Ul: TColor;
    AddMod, SubMod: TModifier;

    class function Default: TStyle; static; inline;

    function WithFg(const AColor: TColor): TStyle;
    function WithBg(const AColor: TColor): TStyle;
    function WithUnderline(const AColor: TColor): TStyle;

    { 加入修饰位并从 SubMod 清除 }
    function WithModifier(const AModifier: TModifier): TStyle;

    { 加入修饰位到 SubMod 并从 AddMod 清除 }
    function WithoutModifier(const AModifier: TModifier): TStyle;

    { 合并两个样式。AOther 按 ratatui 规则逐字段覆盖 Self（见单元头）。 }
    function Patch(const AOther: TStyle): TStyle;
  end;

function StyleDefault: TStyle; inline;
function StyleEquals(const A, B: TStyle): Boolean; inline;

{ 便利构造器——一行创建常用样式 }
function StyleFg(const AColor: TColor): TStyle; inline;
function StyleBg(const AColor: TColor): TStyle; inline;
function StyleFgBg(const AFg, ABg: TColor): TStyle; inline;
function StyleBold: TStyle; inline;
function StyleItalic: TStyle; inline;

implementation

{$if SizeOf(TStyle) <> 16}
  {$error TStyle size changed from 16 bytes — check packenum 1 / packset 2 and TColor/TModifier sizes}
{$endif}

class function TStyle.Default: TStyle;
begin
  Result.Fg := UnsetColor;
  Result.Bg := UnsetColor;
  Result.Ul := UnsetColor;
  Result.AddMod := [];
  Result.SubMod := [];
end;

function StyleDefault: TStyle;
begin
  Result := TStyle.Default;
end;

function TStyle.WithFg(const AColor: TColor): TStyle;
begin
  Result := Self;
  Result.Fg := AColor;
end;

function TStyle.WithBg(const AColor: TColor): TStyle;
begin
  Result := Self;
  Result.Bg := AColor;
end;

function TStyle.WithUnderline(const AColor: TColor): TStyle;
begin
  Result := Self;
  Result.Ul := AColor;
end;

function TStyle.WithModifier(const AModifier: TModifier): TStyle;
begin
  Result := Self;
  Result.AddMod := Result.AddMod + AModifier;
  Result.SubMod := Result.SubMod - AModifier;
end;

function TStyle.WithoutModifier(const AModifier: TModifier): TStyle;
begin
  Result := Self;
  Result.SubMod := Result.SubMod + AModifier;
  Result.AddMod := Result.AddMod - AModifier;
end;

function TStyle.Patch(const AOther: TStyle): TStyle;
begin
  Result := Self;
  if ColorIsSet(AOther.Fg) then Result.Fg := AOther.Fg;
  if ColorIsSet(AOther.Bg) then Result.Bg := AOther.Bg;
  if ColorIsSet(AOther.Ul) then Result.Ul := AOther.Ul;
  Result.AddMod := (Result.AddMod - AOther.SubMod) + AOther.AddMod;
  Result.SubMod := (Result.SubMod - AOther.AddMod) + AOther.SubMod;
end;

function StyleEquals(const A, B: TStyle): Boolean;
begin
  Result := ColorEquals(A.Fg, B.Fg) and
            ColorEquals(A.Bg, B.Bg) and
            ColorEquals(A.Ul, B.Ul) and
            (A.AddMod = B.AddMod) and
            (A.SubMod = B.SubMod);
end;

function StyleFg(const AColor: TColor): TStyle;
begin
  Result := TStyle.Default;
  Result.Fg := AColor;
end;

function StyleBg(const AColor: TColor): TStyle;
begin
  Result := TStyle.Default;
  Result.Bg := AColor;
end;

function StyleFgBg(const AFg, ABg: TColor): TStyle;
begin
  Result := TStyle.Default;
  Result.Fg := AFg;
  Result.Bg := ABg;
end;

function StyleBold: TStyle;
begin
  Result := TStyle.Default;
  Result.AddMod := [mbBold];
end;

function StyleItalic: TStyle;
begin
  Result := TStyle.Default;
  Result.AddMod := [mbItalic];
end;

end.

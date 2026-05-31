unit nextpas.core.tui.color;

{**
 * @desc 终端颜色（对齐 ratatui::style::Color），4 字节 packed record。
 *
 * 四种形态覆盖全部 ratatui 颜色表面：
 *   - ckUnset   ── 等价 Option<Color>::None。Patch 时表示"沿用接收方当前值"。
 *   - ckReset   ── 等价 Color::Reset。后端发 SGR 39/49（默认前/背景）。
 *   - ckIndexed ── 0..255。前 16 项匹配命名色 (TUI_BLACK..TUI_WHITE)，
 *                  16..255 为 256 色调色板。
 *   - ckRgb     ── 24-bit truecolor，后端发 SGR 38;2;r;g;b。
 *
 * record 为 4 字节 (1 + 3)，x86-64 上按寄存器传递。热路径必须按值或
 * const 引用传 TColor，绝不用 var 或经堆。构造用自由函数 UnsetColor /
 * ResetColor / IndexedColor / RgbColor。
 *
 * @note ColorEquals 把 4 字节当单个 LongWord 比较，绕开 Kind 分派。
 *       TColor 是 variant record（case 部分），FPC 不允许在其中混入方法，
 *       故构造器以自由函数提供而非 class function。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}        { 枚举字段占 1 字节（默认 4） }

interface

type
  TColorKind = (ckUnset, ckReset, ckIndexed, ckRgb);

  TColor = packed record
    Kind: TColorKind;
    case Byte of
      0: (Index: Byte);             { ckIndexed }
      1: (R, G, B: Byte);           { ckRgb }
  end;

{ 自由函数构造器（保留 ratatui 风格命名映射） }
function UnsetColor: TColor; inline;
function ResetColor: TColor; inline;
function IndexedColor(const AIndex: Byte): TColor; inline;
function RgbColor(const AR, AG, AB: Byte): TColor; inline;

function ColorEquals(const A, B: TColor): Boolean; inline;
function ColorIsSet(const AColor: TColor): Boolean; inline;

{ 短名便利函数（与 RgbColor/IndexedColor 等价，更简洁） }
function Rgb(const AR, AG, AB: Byte): TColor; inline;
function Idx(const AIndex: Byte): TColor; inline;

const
  { 命名色映射到 indexed 0..15 —— 与 ratatui 完全一致 }
  TUI_BLACK:         TColor = (Kind: ckIndexed; Index: 0);
  TUI_RED:           TColor = (Kind: ckIndexed; Index: 1);
  TUI_GREEN:         TColor = (Kind: ckIndexed; Index: 2);
  TUI_YELLOW:        TColor = (Kind: ckIndexed; Index: 3);
  TUI_BLUE:          TColor = (Kind: ckIndexed; Index: 4);
  TUI_MAGENTA:       TColor = (Kind: ckIndexed; Index: 5);
  TUI_CYAN:          TColor = (Kind: ckIndexed; Index: 6);
  TUI_GRAY:          TColor = (Kind: ckIndexed; Index: 7);
  TUI_DARK_GRAY:     TColor = (Kind: ckIndexed; Index: 8);
  TUI_LIGHT_RED:     TColor = (Kind: ckIndexed; Index: 9);
  TUI_LIGHT_GREEN:   TColor = (Kind: ckIndexed; Index: 10);
  TUI_LIGHT_YELLOW:  TColor = (Kind: ckIndexed; Index: 11);
  TUI_LIGHT_BLUE:    TColor = (Kind: ckIndexed; Index: 12);
  TUI_LIGHT_MAGENTA: TColor = (Kind: ckIndexed; Index: 13);
  TUI_LIGHT_CYAN:    TColor = (Kind: ckIndexed; Index: 14);
  TUI_WHITE:         TColor = (Kind: ckIndexed; Index: 15);

implementation

{$if SizeOf(TColor) <> 4}
  {$error TColor size changed from 4 bytes — ColorEquals LongWord comparison broken (check packenum 1)}
{$endif}

function UnsetColor: TColor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ckUnset;
end;

function ResetColor: TColor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ckReset;
end;

function IndexedColor(const AIndex: Byte): TColor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ckIndexed;
  Result.Index := AIndex;
end;

function RgbColor(const AR, AG, AB: Byte): TColor;
begin
  Result.Kind := ckRgb;
  Result.R := AR;
  Result.G := AG;
  Result.B := AB;
end;

function ColorEquals(const A, B: TColor): Boolean;
var
  LPA, LPB: PLongWord;
begin
  { packed record 4 字节，按单个 LongWord 比较，绕开 kind 分派 }
  LPA := @A;
  LPB := @B;
  Result := LPA^ = LPB^;
end;

function ColorIsSet(const AColor: TColor): Boolean;
begin
  Result := AColor.Kind <> ckUnset;
end;

function Rgb(const AR, AG, AB: Byte): TColor;
begin
  Result := RgbColor(AR, AG, AB);
end;

function Idx(const AIndex: Byte): TColor;
begin
  Result := IndexedColor(AIndex);
end;

end.

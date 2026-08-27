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

{ RGB 线性插值:t∈[0,1],0=AColor,1=BColor;任一端非 ckRgb 时退化为 BColor
  (动画层主题过渡/高亮渐显的通用能力;结果恒为 ckRgb) }
function ColorInterp(const AColor, BColor: TColor; T: Double): TColor;

{ 短名便利函数（与 RgbColor/IndexedColor 等价，更简洁） }
function Rgb(const AR, AG, AB: Byte): TColor; inline;
function Idx(const AIndex: Byte): TColor; inline;
function HexColor(const AHex: AnsiString): TColor;

{ 统一 Hex 编解码：单一真源，palette/docstore 均委托此处 }
function ColorToHex(const AColor: TColor): AnsiString;
function TryParseHexColor(const AHex: AnsiString; out AColor: TColor): Boolean;
procedure ColorToRgb(const AColor: TColor; out AR, AG, AB: Byte);

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

  HEXDIGITS: array[0..15] of Char = '0123456789abcdef';
  COLOR_RGB: array[0..15] of LongWord = ($000000,$800000,$008000,$808000,$000080,$800080,$008080,$C0C0C0,$808080,$FF0000,$00FF00,$FFFF00,$0000FF,$FF00FF,$00FFFF,$FFFFFF);

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

function ColorInterp(const AColor, BColor: TColor; T: Double): TColor;
begin
  if (AColor.Kind <> ckRgb) or (BColor.Kind <> ckRgb) or (T >= 1) then
    Exit(BColor);
  if T <= 0 then
    Exit(AColor);
  Result := RgbColor(
    Round(AColor.R + (BColor.R - AColor.R) * T),
    Round(AColor.G + (BColor.G - AColor.G) * T),
    Round(AColor.B + (BColor.B - AColor.B) * T));
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

function HexValStrict(C: AnsiChar): Integer; inline;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function ColorToHex(const AColor: TColor): AnsiString;
var
  V: LongWord;
begin
  case AColor.Kind of
    ckRgb:
      Result := '#' + HEXDIGITS[(AColor.R shr 4) and $F] + HEXDIGITS[AColor.R and $F]
                    + HEXDIGITS[(AColor.G shr 4) and $F] + HEXDIGITS[AColor.G and $F]
                    + HEXDIGITS[(AColor.B shr 4) and $F] + HEXDIGITS[AColor.B and $F];
    ckIndexed:
      begin
        V := COLOR_RGB[AColor.Index and 15];
        Result := '#' + HEXDIGITS[(V shr 20) and $F] + HEXDIGITS[(V shr 16) and $F]
                      + HEXDIGITS[(V shr 12) and $F] + HEXDIGITS[(V shr 8) and $F]
                      + HEXDIGITS[(V shr 4) and $F] + HEXDIGITS[V and $F];
      end;
  else
    Result := '';
  end;
end;

function TryParseHexColor(const AHex: AnsiString; out AColor: TColor): Boolean;
var
  S: AnsiString;
  L, R, I: Integer;
  RV, GV, BV: Integer;
begin
  Result := False;
  { 手动 Trim：避免依赖 SysUtils，符合 nextpas RTL 约束 }
  L := 1; R := Length(AHex);
  while (L <= R) and (AHex[L] in [#9,#10,#13,' ']) do Inc(L);
  while (R >= L) and (AHex[R] in [#9,#10,#13,' ']) do Dec(R);
  if L > R then Exit;
  S := Copy(AHex, L, R - L + 1);
  { #rgb short form }
  if (Length(S) = 4) and (S[1] = '#') then
  begin
    RV := HexValStrict(S[2]); GV := HexValStrict(S[3]); BV := HexValStrict(S[4]);
    if (RV < 0) or (GV < 0) or (BV < 0) then Exit;
    AColor := RgbColor(RV * 17, GV * 17, BV * 17);
    Exit(True);
  end;
  { #rrggbb }
  if (Length(S) = 7) and (S[1] = '#') then
  begin
    for I := 2 to 7 do if HexValStrict(S[I]) < 0 then Exit;
    RV := HexValStrict(S[2]) * 16 + HexValStrict(S[3]);
    GV := HexValStrict(S[4]) * 16 + HexValStrict(S[5]);
    BV := HexValStrict(S[6]) * 16 + HexValStrict(S[7]);
    AColor := RgbColor(RV, GV, BV);
    Exit(True);
  end;
  { rrggbb without # }
  if Length(S) = 6 then
  begin
    for I := 1 to 6 do if HexValStrict(S[I]) < 0 then Exit;
    RV := HexValStrict(S[1]) * 16 + HexValStrict(S[2]);
    GV := HexValStrict(S[3]) * 16 + HexValStrict(S[4]);
    BV := HexValStrict(S[5]) * 16 + HexValStrict(S[6]);
    AColor := RgbColor(RV, GV, BV);
    Exit(True);
  end;
end;

procedure ColorToRgb(const AColor: TColor; out AR, AG, AB: Byte);
var
  V: LongWord;
begin
  case AColor.Kind of
    ckRgb: begin AR := AColor.R; AG := AColor.G; AB := AColor.B; end;
    ckIndexed:
      begin
        V := COLOR_RGB[AColor.Index and 15];
        AR := Byte((V shr 16) and $FF);
        AG := Byte((V shr 8) and $FF);
        AB := Byte(V and $FF);
      end;
  else begin AR := 0; AG := 0; AB := 0; end;
  end;
end;

function HexColor(const AHex: AnsiString): TColor;
var
  C: TColor;
begin
  if TryParseHexColor(AHex, C) then Exit(C);
  if Length(AHex) = 0 then Exit(ResetColor);
  if AHex[1] = '#' then
  begin
    if Length(AHex) < 7 then Exit(ResetColor);
    if TryParseHexColor(Copy(AHex, 1, 7), C) then Exit(C);
  end
  else
  begin
    if Length(AHex) < 6 then Exit(ResetColor);
    if TryParseHexColor(Copy(AHex, 1, 6), C) then Exit(C);
  end;
  Result := ResetColor;
end;

end.

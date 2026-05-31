unit nextpas.core.tui.borders;

{**
 * @desc 边框侧位标志 + TBlock 使用的盒线字形。
 *
 * TBorders 是边框侧（上/右/下/左）的 set。TBorderSet 是定义边框视觉外观
 * 的 11 个字形（横/竖/四角 + T 接头 + 十字）。
 *
 * 提供 Plain / Rounded / Double / Heavy / Dashed 五套预置字形。盒线字符为
 * 3 字节 UTF-8（U+2500 区），远在 TCell 23 字节内联预算内，无堆分配。
 *}

{$I nextpas.core.settings.inc}
{$packset 1}

interface

type
  TBorderSide = (bsTop, bsRight, bsBottom, bsLeft);
  TBorders = set of TBorderSide;

  { 定义边框视觉外观的 11 个字形 }
  TBorderSet = record
    Horizontal: AnsiString;
    Vertical: AnsiString;
    TopLeft: AnsiString;
    TopRight: AnsiString;
    BottomLeft: AnsiString;
    BottomRight: AnsiString;
    LeftT: AnsiString;
    RightT: AnsiString;
    TopT: AnsiString;
    BottomT: AnsiString;
    Cross: AnsiString;
  end;

const
  BORDERS_NONE: TBorders = [];
  BORDERS_ALL: TBorders = [bsTop, bsRight, bsBottom, bsLeft];

  { Plain 单线盒线 }
  BORDER_HORIZONTAL: AnsiString = #$E2#$94#$80;   { ─ }
  BORDER_VERTICAL:   AnsiString = #$E2#$94#$82;   { │ }
  BORDER_TOP_LEFT:    AnsiString = #$E2#$94#$8C;  { ┌ }
  BORDER_TOP_RIGHT:   AnsiString = #$E2#$94#$90;  { ┐ }
  BORDER_BOTTOM_LEFT: AnsiString = #$E2#$94#$94;  { └ }
  BORDER_BOTTOM_RIGHT:AnsiString = #$E2#$94#$98;  { ┘ }

  { Rounded 圆角 }
  BORDER_ROUNDED_TL:  AnsiString = #$E2#$95#$AD;  { ╭ }
  BORDER_ROUNDED_TR:  AnsiString = #$E2#$95#$AE;  { ╮ }
  BORDER_ROUNDED_BL:  AnsiString = #$E2#$95#$B0;  { ╰ }
  BORDER_ROUNDED_BR:  AnsiString = #$E2#$95#$AF;  { ╯ }

  { 内部分隔接头 }
  BORDER_LEFT_T:      AnsiString = #$E2#$94#$9C;  { ├ }
  BORDER_RIGHT_T:     AnsiString = #$E2#$94#$A4;  { ┤ }
  BORDER_TOP_T:       AnsiString = #$E2#$94#$AC;  { ┬ }
  BORDER_BOTTOM_T:    AnsiString = #$E2#$94#$B4;  { ┴ }
  BORDER_CROSS:       AnsiString = #$E2#$94#$BC;  { ┼ }

  { Double 双线 }
  BORDER_DOUBLE_H:    AnsiString = #$E2#$95#$90;  { ═ }
  BORDER_DOUBLE_V:    AnsiString = #$E2#$95#$91;  { ║ }
  BORDER_DOUBLE_TL:   AnsiString = #$E2#$95#$94;  { ╔ }
  BORDER_DOUBLE_TR:   AnsiString = #$E2#$95#$97;  { ╗ }
  BORDER_DOUBLE_BL:   AnsiString = #$E2#$95#$9A;  { ╚ }
  BORDER_DOUBLE_BR:   AnsiString = #$E2#$95#$9D;  { ╝ }
  BORDER_DOUBLE_LT:   AnsiString = #$E2#$95#$A0;  { ╠ }
  BORDER_DOUBLE_RT:   AnsiString = #$E2#$95#$A3;  { ╣ }
  BORDER_DOUBLE_TT:   AnsiString = #$E2#$95#$A6;  { ╦ }
  BORDER_DOUBLE_BT:   AnsiString = #$E2#$95#$A9;  { ╩ }
  BORDER_DOUBLE_CROSS:AnsiString = #$E2#$95#$AC;  { ╬ }

  { Heavy 粗线 }
  BORDER_HEAVY_H:     AnsiString = #$E2#$94#$81;  { ━ }
  BORDER_HEAVY_V:     AnsiString = #$E2#$94#$83;  { ┃ }
  BORDER_HEAVY_TL:    AnsiString = #$E2#$94#$8F;  { ┏ }
  BORDER_HEAVY_TR:    AnsiString = #$E2#$94#$93;  { ┓ }
  BORDER_HEAVY_BL:    AnsiString = #$E2#$94#$97;  { ┗ }
  BORDER_HEAVY_BR:    AnsiString = #$E2#$94#$9B;  { ┛ }
  BORDER_HEAVY_LT:    AnsiString = #$E2#$94#$A3;  { ┣ }
  BORDER_HEAVY_RT:    AnsiString = #$E2#$94#$AB;  { ┫ }
  BORDER_HEAVY_TT:    AnsiString = #$E2#$94#$B3;  { ┳ }
  BORDER_HEAVY_BT:    AnsiString = #$E2#$94#$BB;  { ┻ }
  BORDER_HEAVY_CROSS: AnsiString = #$E2#$95#$8B;  { ╋ }

  { Dashed 虚线 }
  BORDER_DASHED_H:    AnsiString = #$E2#$94#$84;  { ┄ }
  BORDER_DASHED_V:    AnsiString = #$E2#$94#$86;  { ┆ }

var
  BorderSetPlain: TBorderSet;
  BorderSetRounded: TBorderSet;
  BorderSetDouble: TBorderSet;
  BorderSetHeavy: TBorderSet;
  BorderSetDashed: TBorderSet;

implementation

initialization
  BorderSetPlain.Horizontal  := BORDER_HORIZONTAL;
  BorderSetPlain.Vertical    := BORDER_VERTICAL;
  BorderSetPlain.TopLeft     := BORDER_TOP_LEFT;
  BorderSetPlain.TopRight    := BORDER_TOP_RIGHT;
  BorderSetPlain.BottomLeft  := BORDER_BOTTOM_LEFT;
  BorderSetPlain.BottomRight := BORDER_BOTTOM_RIGHT;
  BorderSetPlain.LeftT       := BORDER_LEFT_T;
  BorderSetPlain.RightT      := BORDER_RIGHT_T;
  BorderSetPlain.TopT        := BORDER_TOP_T;
  BorderSetPlain.BottomT     := BORDER_BOTTOM_T;
  BorderSetPlain.Cross       := BORDER_CROSS;

  BorderSetRounded.Horizontal  := BORDER_HORIZONTAL;
  BorderSetRounded.Vertical    := BORDER_VERTICAL;
  BorderSetRounded.TopLeft     := BORDER_ROUNDED_TL;
  BorderSetRounded.TopRight    := BORDER_ROUNDED_TR;
  BorderSetRounded.BottomLeft  := BORDER_ROUNDED_BL;
  BorderSetRounded.BottomRight := BORDER_ROUNDED_BR;
  BorderSetRounded.LeftT       := BORDER_LEFT_T;
  BorderSetRounded.RightT      := BORDER_RIGHT_T;
  BorderSetRounded.TopT        := BORDER_TOP_T;
  BorderSetRounded.BottomT     := BORDER_BOTTOM_T;
  BorderSetRounded.Cross       := BORDER_CROSS;

  BorderSetDouble.Horizontal  := BORDER_DOUBLE_H;
  BorderSetDouble.Vertical    := BORDER_DOUBLE_V;
  BorderSetDouble.TopLeft     := BORDER_DOUBLE_TL;
  BorderSetDouble.TopRight    := BORDER_DOUBLE_TR;
  BorderSetDouble.BottomLeft  := BORDER_DOUBLE_BL;
  BorderSetDouble.BottomRight := BORDER_DOUBLE_BR;
  BorderSetDouble.LeftT       := BORDER_DOUBLE_LT;
  BorderSetDouble.RightT      := BORDER_DOUBLE_RT;
  BorderSetDouble.TopT        := BORDER_DOUBLE_TT;
  BorderSetDouble.BottomT     := BORDER_DOUBLE_BT;
  BorderSetDouble.Cross       := BORDER_DOUBLE_CROSS;

  BorderSetHeavy.Horizontal  := BORDER_HEAVY_H;
  BorderSetHeavy.Vertical    := BORDER_HEAVY_V;
  BorderSetHeavy.TopLeft     := BORDER_HEAVY_TL;
  BorderSetHeavy.TopRight    := BORDER_HEAVY_TR;
  BorderSetHeavy.BottomLeft  := BORDER_HEAVY_BL;
  BorderSetHeavy.BottomRight := BORDER_HEAVY_BR;
  BorderSetHeavy.LeftT       := BORDER_HEAVY_LT;
  BorderSetHeavy.RightT      := BORDER_HEAVY_RT;
  BorderSetHeavy.TopT        := BORDER_HEAVY_TT;
  BorderSetHeavy.BottomT     := BORDER_HEAVY_BT;
  BorderSetHeavy.Cross       := BORDER_HEAVY_CROSS;

  BorderSetDashed.Horizontal  := BORDER_DASHED_H;
  BorderSetDashed.Vertical    := BORDER_DASHED_V;
  BorderSetDashed.TopLeft     := BORDER_TOP_LEFT;
  BorderSetDashed.TopRight    := BORDER_TOP_RIGHT;
  BorderSetDashed.BottomLeft  := BORDER_BOTTOM_LEFT;
  BorderSetDashed.BottomRight := BORDER_BOTTOM_RIGHT;
  BorderSetDashed.LeftT       := BORDER_LEFT_T;
  BorderSetDashed.RightT      := BORDER_RIGHT_T;
  BorderSetDashed.TopT        := BORDER_TOP_T;
  BorderSetDashed.BottomT     := BORDER_BOTTOM_T;
  BorderSetDashed.Cross       := BORDER_CROSS;

end.

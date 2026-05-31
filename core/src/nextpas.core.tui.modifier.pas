unit nextpas.core.tui.modifier;

{**
 * @desc 文本样式修饰符位集（对齐 ratatui::style::Modifier 的 u16 bitflags）。
 *
 * 九个 SGR 属性位映射为 Pascal `set of TModifierBit`。配合 packset 2，
 * FPC 把 9 元素集合编译为单个 16-bit 字，AddMod/SubMod 的合并通过整数
 * AND/OR/XOR 完成——与 Rust bitflags 等价。
 *
 * @note 热路径直接用 `+ - *`（并/差/交）操作 TModifier，无堆、无类、无分配。
 *       packset 2 是 TCell 40 字节布局的依赖，不可移除。
 *}

{$I nextpas.core.settings.inc}
{$packset 2}        { 9 元素集合打包为 2 字节 (u16) }

interface

type
  TModifierBit = (
    mbBold,        { SGR 1 }
    mbDim,         { SGR 2 }
    mbItalic,      { SGR 3 }
    mbUnderlined,  { SGR 4 }
    mbSlowBlink,   { SGR 5 }
    mbRapidBlink,  { SGR 6 }
    mbReversed,    { SGR 7 }
    mbHidden,      { SGR 8 }
    mbCrossedOut   { SGR 9 }
  );

  TModifier = set of TModifierBit;

const
  MODIFIER_NONE: TModifier = [];

function ModifierEquals(const A, B: TModifier): Boolean; inline;
function ModifierIsEmpty(const AModifier: TModifier): Boolean; inline;

implementation

function ModifierEquals(const A, B: TModifier): Boolean;
begin
  Result := A = B;
end;

function ModifierIsEmpty(const AModifier: TModifier): Boolean;
begin
  Result := AModifier = [];
end;

end.

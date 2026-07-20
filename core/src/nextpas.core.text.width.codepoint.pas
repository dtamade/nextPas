unit nextpas.core.text.width.codepoint;

{**
 * @desc 单码点终端列宽计算（East Asian Width + 零宽组合标记）。
 *
 * 依据 Unicode Standard Annex #11 (East_Asian_Width, UCD 16.0 真表) 与
 * 组合标记/零宽控制的代表性区间，计算单个码点在等宽终端中占用的列数：
 *
 *   - 控制字符（C0/C1）                 -> 0
 *   - 组合标记 / 零宽字符               -> 0
 *   - East Asian Wide / Fullwidth (W/F) -> 2
 *   - 其余（含 Ambiguous A、H、Na、N）  -> 1
 *
 * A→1 与 Rust unicode-width 默认一致（非 CJK locale 宽环境）。
 * 该模块是 text.width 和 text.grapheme 的共同底层依赖。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.utils;

type
  TCodepointRange = nextpas.core.text.unicode.utils.TCodepointRange;

{**
 * @desc 返回单个 Unicode 码点的终端列宽。
 * @params ACodePoint  UCS-4 码点
 * @return 0 / 1 / 2
 *}
function CodepointWidth(const ACodePoint: UInt32): Byte; inline;

implementation

uses
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.props;

{ 零宽表 - 组合标记 Mn/Me 与零宽控制字符的代表性区间。
  按 Lo 升序排列。覆盖常见组合附标、变体选择符、ZWJ/ZWNJ 等。 }
const
  ZERO_WIDTH_RANGES: array[0..52] of TCodepointRange = (
    (Lo: $0300; Hi: $036F),    { Combining Diacritical Marks }
    (Lo: $0483; Hi: $0489),    { Cyrillic combining }
    (Lo: $0591; Hi: $05BD),    { Hebrew points }
    (Lo: $05BF; Hi: $05BF),
    (Lo: $05C1; Hi: $05C2),
    (Lo: $05C4; Hi: $05C5),
    (Lo: $05C7; Hi: $05C7),
    (Lo: $0600; Hi: $0605),    { Arabic prepend marks }
    (Lo: $0610; Hi: $061A),    { Arabic marks }
    (Lo: $064B; Hi: $065F),
    (Lo: $0670; Hi: $0670),
    (Lo: $06D6; Hi: $06DC),
    (Lo: $06DD; Hi: $06DD),    { Arabic end of ayah prepend }
    (Lo: $06DF; Hi: $06E4),
    (Lo: $06E7; Hi: $06E8),
    (Lo: $06EA; Hi: $06ED),
    (Lo: $070F; Hi: $070F),    { Syriac abbreviation mark prepend }
    (Lo: $0711; Hi: $0711),    { Syriac }
    (Lo: $0730; Hi: $074A),
    (Lo: $07A6; Hi: $07B0),    { Thaana }
    (Lo: $07EB; Hi: $07F3),    { NKo combining marks }
    (Lo: $07FD; Hi: $07FD),    { NKo dantayalan }
    (Lo: $0890; Hi: $0891),    { Arabic honorific sign prepend }
    (Lo: $08E2; Hi: $08E2),    { Arabic disputed end of ayah prepend }
    (Lo: $0900; Hi: $0902),    { Devanagari Mn (excl. 0903 Mc) }
    (Lo: $093A; Hi: $093A),
    (Lo: $093C; Hi: $093C),
    (Lo: $0941; Hi: $0948),
    (Lo: $094D; Hi: $094D),
    (Lo: $0951; Hi: $0957),
    (Lo: $0962; Hi: $0963),
    (Lo: $0981; Hi: $0981),    { Bengali Mn (excl. 0982-0983 Mc) }
    (Lo: $09BC; Hi: $09BC),
    (Lo: $09C1; Hi: $09C4),
    (Lo: $09CD; Hi: $09CD),
    (Lo: $0E31; Hi: $0E31),    { Thai }
    (Lo: $0E34; Hi: $0E3A),
    (Lo: $0E47; Hi: $0E4E),
    (Lo: $0EB1; Hi: $0EB1),    { Lao }
    (Lo: $0EB4; Hi: $0EBC),
    (Lo: $1160; Hi: $11FF),    { Hangul Jungseong/Jongseong (conjoining) }
    (Lo: $1AB0; Hi: $1AFF),    { Combining Diacritical Marks Extended }
    (Lo: $1DC0; Hi: $1DFF),    { Combining Diacritical Marks Supplement }
    (Lo: $200B; Hi: $200F),    { ZWSP, ZWNJ, ZWJ, LRM, RLM }
    (Lo: $202A; Hi: $202E),    { bidi embedding/override }
    (Lo: $2060; Hi: $2064),    { word joiner, invisible ops }
    (Lo: $20D0; Hi: $20F0),    { Combining Diacritical Marks for Symbols }
    (Lo: $FE00; Hi: $FE0F),    { Variation Selectors }
    (Lo: $FE20; Hi: $FE2F),    { Combining Half Marks }
    (Lo: $FEFF; Hi: $FEFF),    { ZWNBSP / BOM }
    (Lo: $1E000; Hi: $1E02A),  { Glagolitic Supplement combining }
    (Lo: $E0020; Hi: $E007F),  { Tags }
    (Lo: $E0100; Hi: $E01EF)   { Variation Selectors Supplement }
  );

function CodepointWidth(const ACodePoint: UInt32): Byte;
var
  LEaw: TEastAsianWidth;
begin
  { 控制字符 C0/C1 -> 0 列 }
  if (ACodePoint < 32) or ((ACodePoint >= $7F) and (ACodePoint < $A0)) then
    Exit(0);

  { ASCII 快路径：低于最小 combining 且非控制 }
  if ACodePoint < $0300 then
    Exit(1);

  { 零宽组合标记 / 不可见控制 -> 0 列 }
  if RangeContains(ZERO_WIDTH_RANGES, ACodePoint) then
    Exit(0);

  { UAX#11: Fullwidth / Wide -> 2；其余（A/H/Na/N）-> 1 }
  LEaw := GetEastAsianWidth(ACodePoint);
  if LEaw in [eawFullwidth, eawWide] then
    Exit(2);

  Result := 1;
end;

end.

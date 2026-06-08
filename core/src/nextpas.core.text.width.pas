unit nextpas.core.text.width;

{**
 * @desc 终端显示宽度计算（East Asian Width + grapheme cluster）。
 *
 * 依据 Unicode Standard Annex #11 (East Asian Width) 与组合标记
 * (General Category Mn/Me) 的代表性区间，计算单个码点在等宽终端中占用的
 * 列数：
 *
 *   - 控制字符（C0/C1）           -> 0
 *   - 组合标记 / 零宽字符         -> 0
 *   - East Asian Wide / Fullwidth -> 2
 *   - 其余                        -> 1
 *
 * CodepointWidth 只做单码点宽度；StringDisplayWidth 在非 ASCII 路径通过
 * GraphemeNext 按 grapheme cluster 计宽，确保 ZWJ emoji、keycap、变体选择符
 * 和组合标记等多码点簇按终端单个字形推进。组合标记表覆盖常用脚本
 *（拉丁/西里尔/希伯来/阿拉伯/天城文/孟加拉/泰/老挝/谚文连接等）的代表性
 * 区间，非完整 Unicode Mn/Me 全集。
 *
 * @note 热路径：StringDisplayWidth 对纯 ASCII 输入走 SIMD/标量快路径，
 *       按 CodepointWidth 的控制字符契约计宽；含多字节序列时回退到
 *       grapheme cluster 解码。
 *}

{$I nextpas.core.settings.inc}

interface

type
  { 码点区间 [Lo, Hi]，用于二分查找宽度表 }
  TCodepointRange = record
    Lo, Hi: UInt32;
  end;

{**
 * @desc 返回单个 Unicode 码点的终端列宽。
 * @params ACodePoint  UCS-4 码点
 * @return 0 / 1 / 2
 *}
function CodepointWidth(const ACodePoint: UInt32): Byte; inline;

{**
 * @desc 计算 UTF-8 字节序列的总显示宽度。
 * @params
 *   AData  UTF-8 字节起始指针
 *   ALen   字节长度
 * @return 总列宽（非 ASCII 路径按 grapheme cluster 计宽）
 * @note 纯 ASCII 输入走 SIMD 快路径；非法字节按宽度 1 计。
 *}
function StringDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt;

{**
 * @desc 计算 AnsiString（UTF-8）的总显示宽度。便利重载。
 *}
function StringDisplayWidth(const AStr: AnsiString): SizeUInt; overload; inline;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.grapheme,
  nextpas.core.simd.cpuinfo;

{$ifdef CPUX86_64}
var
  GHasAVX2: Boolean;
{$endif}

{ 宽度表 - East Asian Wide + Fullwidth 区间（Unicode 15.1，W/F 类别），
  按 Lo 升序排列，供二分查找。 }
const
  WIDE_RANGES: array[0..62] of TCodepointRange = (
    (Lo: $1100; Hi: $115F),    { Hangul Jamo }
    (Lo: $231A; Hi: $231B),    { watch, hourglass }
    (Lo: $2329; Hi: $232A),    { angle brackets }
    (Lo: $23E9; Hi: $23EC),    { fast-forward symbols }
    (Lo: $23F0; Hi: $23F0),    { alarm clock }
    (Lo: $23F3; Hi: $23F3),    { hourglass flowing }
    (Lo: $25FD; Hi: $25FE),    { medium small squares }
    (Lo: $2614; Hi: $2615),    { umbrella, hot beverage }
    (Lo: $2630; Hi: $2637),    { trigrams 八卦 }
    (Lo: $2648; Hi: $2653),    { zodiac }
    (Lo: $267F; Hi: $267F),    { wheelchair }
    (Lo: $2693; Hi: $2693),    { anchor }
    (Lo: $26A1; Hi: $26A1),    { high voltage }
    (Lo: $26AA; Hi: $26AB),    { circles }
    (Lo: $26BD; Hi: $26BE),    { soccer, baseball }
    (Lo: $26C4; Hi: $26C5),    { snowman, sun behind cloud }
    (Lo: $26CE; Hi: $26CE),    { ophiuchus }
    (Lo: $26D4; Hi: $26D4),    { no entry }
    (Lo: $26EA; Hi: $26EA),    { church }
    (Lo: $26F2; Hi: $26F3),    { fountain, golf }
    (Lo: $26F5; Hi: $26F5),    { sailboat }
    (Lo: $26FA; Hi: $26FA),    { tent }
    (Lo: $26FD; Hi: $26FD),    { fuel pump }
    (Lo: $2705; Hi: $2705),    { check mark }
    (Lo: $270A; Hi: $270B),    { raised fist, hand }
    (Lo: $2728; Hi: $2728),    { sparkles }
    (Lo: $274C; Hi: $274C),    { cross mark }
    (Lo: $274E; Hi: $274E),    { negative cross mark }
    (Lo: $2753; Hi: $2755),    { question/exclamation marks }
    (Lo: $2757; Hi: $2757),    { heavy exclamation }
    (Lo: $2795; Hi: $2797),    { plus/minus/divide }
    (Lo: $27B0; Hi: $27B0),    { curly loop }
    (Lo: $27BF; Hi: $27BF),    { double curly loop }
    (Lo: $2B1B; Hi: $2B1C),    { large squares }
    (Lo: $2B50; Hi: $2B50),    { star }
    (Lo: $2B55; Hi: $2B55),    { heavy circle }
    (Lo: $2E80; Hi: $303E),    { CJK Radicals .. Symbols/Punctuation }
    (Lo: $3041; Hi: $33FF),    { Hiragana .. CJK Compatibility }
    (Lo: $3400; Hi: $4DBF),    { CJK Extension A }
    (Lo: $4DC0; Hi: $4DFF),    { Yijing Hexagram Symbols 易经卦符 }
    (Lo: $4E00; Hi: $9FFF),    { CJK Unified Ideographs }
    (Lo: $A000; Hi: $A4CF),    { Yi Syllables / Radicals }
    (Lo: $A960; Hi: $A97F),    { Hangul Jamo Extended-A }
    (Lo: $AC00; Hi: $D7A3),    { Hangul Syllables }
    (Lo: $F900; Hi: $FAFF),    { CJK Compatibility Ideographs }
    (Lo: $FE10; Hi: $FE19),    { Vertical Forms }
    (Lo: $FE30; Hi: $FE4F),    { CJK Compatibility Forms }
    (Lo: $FE50; Hi: $FE6B),    { Small Form Variants }
    (Lo: $FF00; Hi: $FF60),    { Fullwidth Forms }
    (Lo: $FFE0; Hi: $FFE6),    { Fullwidth signs }
    (Lo: $16FE0; Hi: $16FE4),  { Tangut/Khitan symbols }
    (Lo: $17000; Hi: $18CD5),  { Tangut, Khitan Small Script }
    (Lo: $18D00; Hi: $18D08),  { Tangut Supplement }
    (Lo: $1AFF0; Hi: $1B16F),  { Kana Extended/Supplement }
    (Lo: $1D300; Hi: $1D356),  { Tai Xuan Jing Symbols 太玄经 }
    (Lo: $1D360; Hi: $1D376),  { Counting Rod Numerals 算筹 }
    (Lo: $1F004; Hi: $1F004),  { mahjong red dragon }
    (Lo: $1F0CF; Hi: $1F0CF),  { playing card black joker }
    (Lo: $1F18E; Hi: $1F18E),  { negative squared AB }
    (Lo: $1F191; Hi: $1F19A),  { squared CL etc. }
    (Lo: $1F200; Hi: $1F2FF),  { enclosed ideographic supplement }
    (Lo: $1F300; Hi: $1FAFF),  { Misc Symbols & Pictographs / Emoji }
    (Lo: $20000; Hi: $3FFFD)   { CJK Extension B..G + Compat Supplement }
  );

{ 零宽表 - 组合标记 Mn/Me 与零宽控制字符的代表性区间（Unicode 15.1）。
  按 Lo 升序排列。覆盖常见组合附标、变体选择符、ZWJ/ZWNJ 等。 }
  ZERO_WIDTH_RANGES: array[0..44] of TCodepointRange = (
    (Lo: $0300; Hi: $036F),    { Combining Diacritical Marks }
    (Lo: $0483; Hi: $0489),    { Cyrillic combining }
    (Lo: $0591; Hi: $05BD),    { Hebrew points }
    (Lo: $05BF; Hi: $05BF),
    (Lo: $05C1; Hi: $05C2),
    (Lo: $05C4; Hi: $05C5),
    (Lo: $05C7; Hi: $05C7),
    (Lo: $0610; Hi: $061A),    { Arabic marks }
    (Lo: $064B; Hi: $065F),
    (Lo: $0670; Hi: $0670),
    (Lo: $06D6; Hi: $06DC),
    (Lo: $06DF; Hi: $06E4),
    (Lo: $06E7; Hi: $06E8),
    (Lo: $06EA; Hi: $06ED),
    (Lo: $0711; Hi: $0711),    { Syriac }
    (Lo: $0730; Hi: $074A),
    (Lo: $07A6; Hi: $07B0),    { Thaana }
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
    (Lo: $E0100; Hi: $E01EF)   { Variation Selectors Supplement }
  );

function RangeContains(const ARanges: array of TCodepointRange;
  const ACodePoint: UInt32): Boolean;
var
  LLo, LHi, LMid: Integer;
begin
  LLo := 0;
  LHi := High(ARanges);
  while LLo <= LHi do
  begin
    LMid := (LLo + LHi) shr 1;
    if ACodePoint < ARanges[LMid].Lo then
      LHi := LMid - 1
    else if ACodePoint > ARanges[LMid].Hi then
      LLo := LMid + 1
    else
      Exit(True);
  end;
  Result := False;
end;

function GraphemeWidthFrom(const AData: PByte; const ALen, AStart: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  LGR: TGraphemeResult;
begin
  Result := 0;
  LPos := AStart;
  while LPos < ALen do
  begin
    LGR := GraphemeNext(@AData[LPos], ALen - LPos);
    Inc(Result, LGR.Width);
    Inc(LPos, LGR.ByteLen);
  end;
end;

function GraphemeFallbackStart(AAsciiPrefixLen: SizeUInt): SizeUInt; inline;
begin
  if AAsciiPrefixLen = 0 then
    Result := 0
  else
    Result := AAsciiPrefixLen - 1;
end;

function IsAsciiControl(const AByte: Byte): Boolean; inline;
begin
  Result := (AByte < 32) or (AByte = $7F);
end;

function AsciiDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
begin
  if ALen = 0 then
    Exit(0);

  Result := ALen;
  for LPos := 0 to ALen - 1 do
    if IsAsciiControl(AData[LPos]) then
      Dec(Result);
end;

function CodepointWidth(const ACodePoint: UInt32): Byte;
begin
  { 控制字符 C0/C1 -> 0 列 }
  if (ACodePoint < 32) or ((ACodePoint >= $7F) and (ACodePoint < $A0)) then
    Exit(0);

  { ASCII / Latin 快路径：低于最小 wide 区间且非零宽 }
  if ACodePoint < $0300 then
    Exit(1);

  { 零宽组合标记 / 不可见控制 -> 0 列 }
  if RangeContains(ZERO_WIDTH_RANGES, ACodePoint) then
    Exit(0);

  { East Asian Wide / Fullwidth -> 2 列 }
  if RangeContains(WIDE_RANGES, ACodePoint) then
    Exit(2);

  Result := 1;
end;

function StringDisplayWidth(const AData: PByte; const ALen: SizeUInt): SizeUInt;
var
  LPos: SizeUInt;
  {$ifdef CPUX86_64}
  LMask: UInt32;
  LP: PByte;
  {$endif}
begin
  if ALen = 0 then
    Exit(0);

  {$ifdef CPUX86_64}
  LPos := 0;

  if (ALen >= 128) and GHasAVX2 then
  begin
    while LPos + 32 <= ALen do
    begin
      LP := @AData[LPos];
      {$asmmode intel}
      asm
        mov rax, [LP]
        vmovdqu ymm0, [rax]
        vpmovmskb eax, ymm0
        mov [LMask], eax
      end;
      {$asmmode default}
      if LMask = 0 then
        Inc(LPos, 32)
      else
        Break;
    end;
    asm vzeroupper end;
  end;

  { SSE2 路径：处理 AVX2 剩余或无 AVX2 时的主循环 }
  while LPos + 16 <= ALen do
  begin
    LP := @AData[LPos];
    {$asmmode intel}
    asm
      mov rax, [LP]
      movdqu xmm0, [rax]
      pmovmskb eax, xmm0
      mov [LMask], eax
    end;
    {$asmmode default}
    if LMask = 0 then
      Inc(LPos, 16)
    else
      Break;
  end;

  { 标量扫描尾部 }
  while (LPos < ALen) and (AData[LPos] < $80) do
    Inc(LPos);
  if LPos = ALen then
    Exit(AsciiDisplayWidth(AData, ALen));

  LPos := GraphemeFallbackStart(LPos);
  Result := AsciiDisplayWidth(AData, LPos) + GraphemeWidthFrom(AData, ALen, LPos);
  {$else}
  { 非 x86_64 标量路径 }
  LPos := 0;
  while (LPos < ALen) and (AData[LPos] < $80) do
    Inc(LPos);
  if LPos = ALen then
    Exit(AsciiDisplayWidth(AData, ALen));

  LPos := GraphemeFallbackStart(LPos);
  Result := AsciiDisplayWidth(AData, LPos) + GraphemeWidthFrom(AData, ALen, LPos);
  {$endif}
end;

function StringDisplayWidth(const AStr: AnsiString): SizeUInt;
begin
  if Length(AStr) = 0 then
    Exit(0);
  Result := StringDisplayWidth(@AStr[1], Length(AStr));
end;

{$ifdef CPUX86_64}
initialization
  GHasAVX2 := HasAVX2;
{$endif}

end.

{**
 * nextpas.core.text.layout - Grapheme→Glyph 布局薄层（四段链首段复用）
 * Owner: text 侧抽取，复用 text.unicode.segment + text.utf8 + text.width
 * 供 graphics.text / tui 等上层消费，保持单一真源：边界=UAX#29 GraphemeClusterByteLen
 * Advance = CodepointWidth×0.6×FontSize×Scale（等宽占位→可变宽），零拷贝 Move 单源 bytes.ops
 *}
unit nextpas.core.text.layout;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.segment,
  nextpas.core.text.width;

type
  TTextLayoutGlyph = record
    Codepoint: UInt32; // 首码点（U+FFFD 兜底）
    Advance: Single;   // 像素步进 = FontSize*Scale*widthFactor
    ByteLen: SizeUInt; // 所属 grapheme 簇字节数
  end;

{ 单簇步进：inline 热路径，可内联消除 }
function LayoutGlyphAdvance(const ACodepoint: UInt32; AFontSize, AScale: Single): Single; inline;
{ 字节流→grapheme→glyph：返回簇字节数，输出首码点 advance，非法 UTF-8 按 1B U+FFFD }
function LayoutNextGrapheme(const AData: PByte; ALen: SizeUInt; AFontSize, AScale: Single; out AGlyph: UInt32; out AAdvance: Single): SizeUInt; inline;
{ 计数 grapheme 数（分配预估）}
function LayoutGraphemeCount(const AText: AnsiString): SizeUInt; inline;

implementation

function LayoutGlyphAdvance(const ACodepoint: UInt32; AFontSize, AScale: Single): Single;
var
  LW: Byte;
begin
  if (AFontSize <= 0) or (AScale <= 0) then
    Exit(0);
  LW := CodepointWidth(ACodepoint);
  // 0 宽→0，1 宽→0.6em，2 宽→1.2em；与 text.grapheme Width 同源
  case LW of
    0: Result := 0;
    2: Result := AFontSize * AScale * 1.2;
  else
    Result := AFontSize * AScale * 0.6;
  end;
end;

function LayoutNextGrapheme(const AData: PByte; ALen: SizeUInt; AFontSize, AScale: Single; out AGlyph: UInt32; out AAdvance: Single): SizeUInt;
var
  LBytes: SizeUInt;
  LDec: TUTF8DecodeResult;
begin
  AGlyph := $FFFD;
  AAdvance := 0;
  if (AData = nil) or (ALen = 0) then
    Exit(0);
  LBytes := GraphemeClusterByteLen(AData, ALen);
  if LBytes = 0 then
    Exit(0);
  // 首码点即 glyph（占位，无 font cmap 依赖；有 font 时上层用 font.shaper 替换）
  LDec := UTF8Decode(AData, LBytes);
  if LDec.ByteLen > 0 then
    AGlyph := LDec.CodePoint
  else
    AGlyph := $FFFD;
  AAdvance := LayoutGlyphAdvance(AGlyph, AFontSize, AScale);
  Result := LBytes;
end;

function LayoutGraphemeCount(const AText: AnsiString): SizeUInt;
var
  LPos, LLen: SizeUInt;
  LGlyph: UInt32;
  LAdv: Single;
begin
  Result := 0;
  LLen := SizeUInt(Length(AText));
  if LLen = 0 then Exit(0);
  LPos := 0;
  while LPos < LLen do
  begin
    LPos := LPos + LayoutNextGrapheme(@AText[LPos+1], LLen - LPos, 10, 1, LGlyph, LAdv);
    Inc(Result);
    if Result > LLen then Break; // 防御坏数据
  end;
end;

end.

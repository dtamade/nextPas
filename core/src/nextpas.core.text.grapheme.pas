unit nextpas.core.text.grapheme;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.utf8;

type
  TGraphemeResult = record
    ByteLen: Integer;
    Width: Integer;
    CodePoints: Integer;
  end;

function GraphemeNext(const AData: PByte; ALen: SizeUInt): TGraphemeResult;

{** @desc 字符串的终端显示宽: 字素簇宽求和, 与 TBuffer 渲染推进同模型
    (基础码点+VS16/键帽/RI 对计 2 列)。供计宽/裁剪侧对齐渲染,
    逐码点累计会把 emoji 序列低报导致右对齐压穿边界 }
function GraphemeStrWidth(const AValue: string): Integer;

implementation

uses
  nextpas.core.text.width.codepoint,
  nextpas.core.text.unicode.utils,
  nextpas.core.text.unicode.segment;

const
  { Terminal width heuristic: FE0F upgrades these bases to double-width.
    Boundary truth is GraphemeClusterByteLen (UAX #29); this table only
    affects display width, not cluster breaks. }
  EMOJI_VARIATION_BASE_RANGES: array[0..69] of TCodepointRange = (
    (Lo: $00A9; Hi: $00A9),
    (Lo: $00AE; Hi: $00AE),
    (Lo: $203C; Hi: $203C),
    (Lo: $2049; Hi: $2049),
    (Lo: $2122; Hi: $2122),
    (Lo: $2139; Hi: $2139),
    (Lo: $2194; Hi: $2199),
    (Lo: $21A9; Hi: $21AA),
    (Lo: $2328; Hi: $2328),
    (Lo: $23CF; Hi: $23CF),
    (Lo: $23ED; Hi: $23EF),
    (Lo: $23F1; Hi: $23F2),
    (Lo: $23F8; Hi: $23FA),
    (Lo: $24C2; Hi: $24C2),
    (Lo: $25AA; Hi: $25AB),
    (Lo: $25B6; Hi: $25B6),
    (Lo: $25C0; Hi: $25C0),
    (Lo: $25FB; Hi: $25FC),
    (Lo: $2600; Hi: $2604),
    (Lo: $260E; Hi: $260E),
    (Lo: $2611; Hi: $2611),
    (Lo: $2618; Hi: $2618),
    (Lo: $261D; Hi: $261D),
    (Lo: $2620; Hi: $2620),
    (Lo: $2622; Hi: $2623),
    (Lo: $2626; Hi: $2626),
    (Lo: $262A; Hi: $262A),
    (Lo: $262E; Hi: $262F),
    (Lo: $2638; Hi: $263A),
    (Lo: $2640; Hi: $2640),
    (Lo: $2642; Hi: $2642),
    (Lo: $265F; Hi: $2660),
    (Lo: $2663; Hi: $2663),
    (Lo: $2665; Hi: $2666),
    (Lo: $2668; Hi: $2668),
    (Lo: $267B; Hi: $267B),
    (Lo: $267E; Hi: $267E),
    (Lo: $2692; Hi: $2692),
    (Lo: $2694; Hi: $2697),
    (Lo: $2699; Hi: $2699),
    (Lo: $269B; Hi: $269C),
    (Lo: $26A0; Hi: $26A0),
    (Lo: $26A7; Hi: $26A7),
    (Lo: $26B0; Hi: $26B1),
    (Lo: $26C8; Hi: $26C8),
    (Lo: $26CF; Hi: $26CF),
    (Lo: $26D1; Hi: $26D1),
    (Lo: $26D3; Hi: $26D3),
    (Lo: $26E9; Hi: $26E9),
    (Lo: $26F0; Hi: $26F1),
    (Lo: $26F4; Hi: $26F4),
    (Lo: $26F7; Hi: $26F9),
    (Lo: $2702; Hi: $2702),
    (Lo: $2708; Hi: $2709),
    (Lo: $270C; Hi: $270D),
    (Lo: $270F; Hi: $270F),
    (Lo: $2712; Hi: $2712),
    (Lo: $2714; Hi: $2714),
    (Lo: $2716; Hi: $2716),
    (Lo: $271D; Hi: $271D),
    (Lo: $2721; Hi: $2721),
    (Lo: $2733; Hi: $2734),
    (Lo: $2744; Hi: $2744),
    (Lo: $2747; Hi: $2747),
    (Lo: $2763; Hi: $2764),
    (Lo: $27A1; Hi: $27A1),
    (Lo: $2934; Hi: $2935),
    (Lo: $2B05; Hi: $2B07),
    (Lo: $1F170; Hi: $1F171),
    (Lo: $1F17E; Hi: $1F17F)
  );

function IsKeycapBase(const ACp: UInt32): Boolean; inline;
begin
  Result := ((ACp >= Ord('0')) and (ACp <= Ord('9'))) or
            (ACp = Ord('#')) or (ACp = Ord('*'));
end;

function IsEmojiVariationBase(const ACp: UInt32): Boolean; inline;
begin
  Result := RangeContains(EMOJI_VARIATION_BASE_RANGES, ACp);
end;

function GraphemeNext(const AData: PByte; ALen: SizeUInt): TGraphemeResult;
var
  LBytes: SizeUInt;
  LPos: SizeUInt;
  LDec: TUTF8DecodeResult;
  LFirstCp: UInt32;
  LCpWidth: Integer;
  LWidth: Integer;
  LCodePoints: Integer;
  LRICount: Integer;
begin
  Result.ByteLen := 0;
  Result.Width := 0;
  Result.CodePoints := 0;

  if (ALen = 0) or (AData = nil) then
    Exit;

  LBytes := GraphemeClusterByteLen(AData, ALen);
  if LBytes = 0 then
    Exit;

  Result.ByteLen := Integer(LBytes);

  LPos := 0;
  LCodePoints := 0;
  LWidth := 0;
  LRICount := 0;
  LFirstCp := 0;

  while LPos < LBytes do
  begin
    LDec := UTF8Decode(@AData[LPos], LBytes - LPos);
    if LDec.ByteLen = 0 then
    begin
      Inc(LPos);
      Inc(LCodePoints);
      if LWidth < 1 then
        LWidth := 1;
      Continue;
    end;

    LCpWidth := CodepointWidth(LDec.CodePoint);

    if LCodePoints = 0 then
    begin
      LFirstCp := LDec.CodePoint;
      LWidth := LCpWidth;
      if (LFirstCp >= $1F1E6) and (LFirstCp <= $1F1FF) then
        LRICount := 1;
    end
    else
    begin
      { Prepend (width 0) + base: take the visible base width. }
      if LCpWidth > LWidth then
        LWidth := LCpWidth;

      if LDec.CodePoint = $FE0F then
      begin
        if IsEmojiVariationBase(LFirstCp) then
          LWidth := 2;
      end
      else if LDec.CodePoint = $20E3 then
      begin
        if IsKeycapBase(LFirstCp) then
          LWidth := 2;
      end
      else if (LDec.CodePoint >= $1F1E6) and (LDec.CodePoint <= $1F1FF) then
      begin
        Inc(LRICount);
        if LRICount = 2 then
          LWidth := 2;
      end;
    end;

    Inc(LPos, LDec.ByteLen);
    Inc(LCodePoints);
  end;

  Result.CodePoints := LCodePoints;
  Result.Width := LWidth;
end;

function GraphemeStrWidth(const AValue: string): Integer;
var
  LPos: SizeUInt;
  LLn: SizeUInt;
  LG: TGraphemeResult;
begin
  Result := 0;
  LLn := SizeUInt(Length(AValue));
  LPos := 1;
  while LPos <= LLn do
  begin
    LG := GraphemeNext(@AValue[LPos], LLn - LPos + 1);
    if LG.ByteLen <= 0 then
      Break;                      { 防御: 尾部非法字节不再推进 }
    Inc(Result, LG.Width);
    Inc(LPos, SizeUInt(LG.ByteLen));
  end;
end;

end.

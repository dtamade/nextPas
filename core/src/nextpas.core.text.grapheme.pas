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

implementation

uses
  nextpas.core.text.width;

type
  TGBCategory = (
    gbOther,
    gbExtend,
    gbZWJ,
    gbSpacingMark,
    gbPrepend,
    gbRegionalIndicator,
    gbEmojiPresentation
  );

  TCodepointRange = record
    Lo: UInt32;
    Hi: UInt32;
  end;

const
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

  INDIC_CONSONANT_RANGES: array[0..13] of TCodepointRange = (
    (Lo: $0915; Hi: $0939),   { Devanagari }
    (Lo: $0958; Hi: $095F),
    (Lo: $0995; Hi: $09B9),   { Bengali }
    (Lo: $0A15; Hi: $0A39),   { Gurmukhi }
    (Lo: $0A95; Hi: $0AB9),   { Gujarati }
    (Lo: $0B15; Hi: $0B39),   { Oriya }
    (Lo: $0B95; Hi: $0BB9),   { Tamil }
    (Lo: $0C15; Hi: $0C39),   { Telugu }
    (Lo: $0C95; Hi: $0CB9),   { Kannada }
    (Lo: $0D15; Hi: $0D39),   { Malayalam }
    (Lo: $1000; Hi: $102A),   { Myanmar }
    (Lo: $1780; Hi: $17A2),   { Khmer }
    (Lo: $A8F2; Hi: $A8F7),   { Devanagari extended conjunct letters }
    (Lo: $A8FB; Hi: $A8FB)
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

function IsIndicLinker(ACp: UInt32): Boolean; inline;
begin
  case ACp of
    $094D, $09CD, $0A4D, $0ACD, $0B4D, $0BCD,
    $0C4D, $0CCD, $0D4D, $0DCA, $1039, $17D2:
      Result := True;
  else
    Result := False;
  end;
end;

function ClassifyCodepoint(ACp: UInt32): TGBCategory;
begin
  if ACp = $200D then Exit(gbZWJ);

  if (ACp >= $0600) and (ACp <= $0605) then Exit(gbPrepend);
  if (ACp = $06DD) or (ACp = $070F) then Exit(gbPrepend);
  if (ACp >= $0890) and (ACp <= $0891) then Exit(gbPrepend);
  if (ACp = $08E2) then Exit(gbPrepend);

  if (ACp >= $1F1E6) and (ACp <= $1F1FF) then Exit(gbRegionalIndicator);

  if (ACp >= $0300) and (ACp <= $036F) then Exit(gbExtend);
  if (ACp >= $0483) and (ACp <= $0489) then Exit(gbExtend);
  if (ACp >= $0591) and (ACp <= $05BD) then Exit(gbExtend);
  if (ACp = $05BF) then Exit(gbExtend);
  if (ACp >= $05C1) and (ACp <= $05C2) then Exit(gbExtend);
  if (ACp >= $05C4) and (ACp <= $05C5) then Exit(gbExtend);
  if (ACp = $05C7) then Exit(gbExtend);
  if (ACp >= $0610) and (ACp <= $061A) then Exit(gbExtend);
  if (ACp >= $064B) and (ACp <= $065F) then Exit(gbExtend);
  if (ACp = $0670) then Exit(gbExtend);
  if (ACp >= $06D6) and (ACp <= $06DC) then Exit(gbExtend);
  if (ACp >= $06DF) and (ACp <= $06E4) then Exit(gbExtend);
  if (ACp >= $06E7) and (ACp <= $06E8) then Exit(gbExtend);
  if (ACp >= $06EA) and (ACp <= $06ED) then Exit(gbExtend);
  if (ACp = $0711) then Exit(gbExtend);
  if (ACp >= $0730) and (ACp <= $074A) then Exit(gbExtend);
  if (ACp >= $07A6) and (ACp <= $07B0) then Exit(gbExtend);
  if (ACp >= $07EB) and (ACp <= $07F3) then Exit(gbExtend);
  if (ACp = $07FD) then Exit(gbExtend);
  if (ACp >= $0900) and (ACp <= $0902) then Exit(gbExtend);
  if (ACp = $093A) or (ACp = $093C) then Exit(gbExtend);
  if (ACp >= $0941) and (ACp <= $0948) then Exit(gbExtend);
  if (ACp = $094D) then Exit(gbExtend);
  if (ACp >= $0951) and (ACp <= $0957) then Exit(gbExtend);
  if (ACp >= $0962) and (ACp <= $0963) then Exit(gbExtend);
  if (ACp = $0981) or (ACp = $09BC) then Exit(gbExtend);
  if (ACp >= $09C1) and (ACp <= $09C4) then Exit(gbExtend);
  if (ACp = $09CD) then Exit(gbExtend);
  if (ACp = $0E31) then Exit(gbExtend);
  if (ACp >= $0E34) and (ACp <= $0E3A) then Exit(gbExtend);
  if (ACp >= $0E47) and (ACp <= $0E4E) then Exit(gbExtend);
  if (ACp = $0EB1) then Exit(gbExtend);
  if (ACp >= $0EB4) and (ACp <= $0EBC) then Exit(gbExtend);
  if (ACp >= $1160) and (ACp <= $11FF) then Exit(gbExtend);
  if (ACp >= $1AB0) and (ACp <= $1AFF) then Exit(gbExtend);
  if (ACp >= $1DC0) and (ACp <= $1DFF) then Exit(gbExtend);
  if (ACp >= $20D0) and (ACp <= $20F0) then Exit(gbExtend);
  if (ACp >= $1E000) and (ACp <= $1E02A) then Exit(gbExtend);
  if (ACp >= $1F3FB) and (ACp <= $1F3FF) then Exit(gbExtend);
  if (ACp >= $FE00) and (ACp <= $FE0F) then Exit(gbExtend);
  if (ACp >= $FE20) and (ACp <= $FE2F) then Exit(gbExtend);
  if (ACp >= $E0100) and (ACp <= $E01EF) then Exit(gbExtend);
  if (ACp >= $E0020) and (ACp <= $E007F) then Exit(gbExtend);
  if IsIndicLinker(ACp) then Exit(gbExtend);

  if (ACp = $0903) then Exit(gbSpacingMark);
  if (ACp >= $093E) and (ACp <= $0940) then Exit(gbSpacingMark);
  if (ACp >= $0949) and (ACp <= $094C) then Exit(gbSpacingMark);
  if (ACp >= $0982) and (ACp <= $0983) then Exit(gbSpacingMark);
  if (ACp >= $09BE) and (ACp <= $09C0) then Exit(gbSpacingMark);
  if (ACp >= $09C7) and (ACp <= $09C8) then Exit(gbSpacingMark);
  if (ACp >= $09CB) and (ACp <= $09CC) then Exit(gbSpacingMark);
  if (ACp = $0A03) then Exit(gbSpacingMark);
  if (ACp >= $0A3E) and (ACp <= $0A40) then Exit(gbSpacingMark);
  if (ACp = $0A83) then Exit(gbSpacingMark);
  if (ACp >= $0ABE) and (ACp <= $0AC0) then Exit(gbSpacingMark);
  if (ACp = $0AC9) then Exit(gbSpacingMark);
  if (ACp >= $0ACB) and (ACp <= $0ACC) then Exit(gbSpacingMark);
  if (ACp >= $0B3E) and (ACp <= $0B40) then Exit(gbSpacingMark);
  if (ACp >= $0B47) and (ACp <= $0B48) then Exit(gbSpacingMark);
  if (ACp >= $0B4B) and (ACp <= $0B4C) then Exit(gbSpacingMark);
  if (ACp = $0B57) then Exit(gbSpacingMark);
  if (ACp >= $0BBE) and (ACp <= $0BC2) then Exit(gbSpacingMark);
  if (ACp >= $0BC6) and (ACp <= $0BC8) then Exit(gbSpacingMark);
  if (ACp >= $0BCA) and (ACp <= $0BCC) then Exit(gbSpacingMark);
  if (ACp >= $0C01) and (ACp <= $0C03) then Exit(gbSpacingMark);
  if (ACp >= $0C41) and (ACp <= $0C44) then Exit(gbSpacingMark);
  if (ACp >= $0C82) and (ACp <= $0C83) then Exit(gbSpacingMark);
  if (ACp = $0CBE) then Exit(gbSpacingMark);
  if (ACp >= $0CC0) and (ACp <= $0CC1) then Exit(gbSpacingMark);
  if (ACp >= $0CC3) and (ACp <= $0CC4) then Exit(gbSpacingMark);
  if (ACp >= $0CC7) and (ACp <= $0CC8) then Exit(gbSpacingMark);
  if (ACp >= $0CCA) and (ACp <= $0CCB) then Exit(gbSpacingMark);
  if (ACp >= $0D3E) and (ACp <= $0D40) then Exit(gbSpacingMark);
  if (ACp >= $0D46) and (ACp <= $0D48) then Exit(gbSpacingMark);
  if (ACp >= $0D4A) and (ACp <= $0D4C) then Exit(gbSpacingMark);
  if (ACp = $0D57) then Exit(gbSpacingMark);
  if (ACp >= $102B) and (ACp <= $102C) then Exit(gbSpacingMark);
  if (ACp = $1031) then Exit(gbSpacingMark);
  if (ACp = $1038) then Exit(gbSpacingMark);
  if (ACp = $17B6) then Exit(gbSpacingMark);
  if (ACp >= $17BE) and (ACp <= $17C5) then Exit(gbSpacingMark);

  if (ACp >= $1F300) and (ACp <= $1FAFF) then Exit(gbEmojiPresentation);
  if (ACp >= $1F600) and (ACp <= $1F64F) then Exit(gbEmojiPresentation);
  if (ACp >= $1F900) and (ACp <= $1F9FF) then Exit(gbEmojiPresentation);
  if (ACp >= $2600) and (ACp <= $27BF) then Exit(gbEmojiPresentation);

  Result := gbOther;
end;

function IsKeycapBase(ACp: UInt32): Boolean; inline;
begin
  Result := ((ACp >= Ord('0')) and (ACp <= Ord('9'))) or
            (ACp = Ord('#')) or (ACp = Ord('*'));
end;

function IsEmojiVariationBase(ACp: UInt32): Boolean; inline;
begin
  Result := RangeContains(EMOJI_VARIATION_BASE_RANGES, ACp);
end;

function IsIndicConsonant(ACp: UInt32): Boolean; inline;
begin
  Result := RangeContains(INDIC_CONSONANT_RANGES, ACp);
end;

function GraphemeNext(const AData: PByte; ALen: SizeUInt): TGraphemeResult;
var
  LPos: SizeUInt;
  LDec: TUTF8DecodeResult;
  LFirstCp: UInt32;
  LFirstCat, LCat: TGBCategory;
  LRICount: Integer;
  LAfterZWJ: Boolean;
  LCanJoinAfterZWJ: Boolean;
  LIndicSeenConsonant: Boolean;
  LIndicAwaitConsonant: Boolean;
begin
  Result.ByteLen := 0;
  Result.Width := 0;
  Result.CodePoints := 0;

  if (ALen = 0) or (AData = nil) then Exit;

  LDec := UTF8Decode(AData, ALen);
  if LDec.ByteLen = 0 then
  begin
    Result.ByteLen := 1;
    Result.Width := 1;
    Result.CodePoints := 1;
    Exit;
  end;

  LFirstCp := LDec.CodePoint;
  LFirstCat := ClassifyCodepoint(LFirstCp);
  LPos := LDec.ByteLen;
  Result.CodePoints := 1;
  Result.Width := CodepointWidth(LFirstCp);

  LRICount := 0;
  if LFirstCat = gbRegionalIndicator then LRICount := 1;
  LAfterZWJ := False;
  LCanJoinAfterZWJ := (LFirstCat = gbEmojiPresentation);
  LIndicSeenConsonant := IsIndicConsonant(LFirstCp);
  LIndicAwaitConsonant := False;

  while LPos < ALen do
  begin
    LDec := UTF8Decode(@AData[LPos], ALen - LPos);
    if LDec.ByteLen = 0 then
    begin
      LDec.CodePoint := $FFFD;
      LDec.ByteLen := 1;
    end;

    LCat := ClassifyCodepoint(LDec.CodePoint);

    if LFirstCat = gbPrepend then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      if LCat <> gbPrepend then
      begin
        Result.Width := CodepointWidth(LDec.CodePoint);
        LFirstCp := LDec.CodePoint;
        LFirstCat := LCat;
        LCanJoinAfterZWJ := (LFirstCat = gbEmojiPresentation);
        LIndicSeenConsonant := IsIndicConsonant(LFirstCp);
        LIndicAwaitConsonant := False;
      end;
      Continue;
    end;

    if LIndicAwaitConsonant and IsIndicConsonant(LDec.CodePoint) then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      LIndicSeenConsonant := True;
      LIndicAwaitConsonant := False;
      LAfterZWJ := False;
      LCanJoinAfterZWJ := False;
      Continue;
    end;

    if LCat = gbExtend then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      if (LDec.CodePoint = $FE0F) and IsEmojiVariationBase(LFirstCp) then
        Result.Width := 2
      else if (LDec.CodePoint = $20E3) and IsKeycapBase(LFirstCp) then
        Result.Width := 2;
      LAfterZWJ := False;
      if LIndicSeenConsonant and IsIndicLinker(LDec.CodePoint) then
        LIndicAwaitConsonant := True;
      Continue;
    end;

    if LCat = gbSpacingMark then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      LAfterZWJ := False;
      LIndicAwaitConsonant := False;
      Continue;
    end;

    if LCat = gbZWJ then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      LAfterZWJ := LCanJoinAfterZWJ;
      LCanJoinAfterZWJ := False;
      Continue;
    end;

    if LAfterZWJ and (LCat = gbEmojiPresentation) then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      LAfterZWJ := False;
      LCanJoinAfterZWJ := True;
      Continue;
    end;

    if (LFirstCat = gbRegionalIndicator) and (LCat = gbRegionalIndicator) and (LRICount = 1) then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      Inc(LRICount);
      Result.Width := 2;
      LAfterZWJ := False;
      LCanJoinAfterZWJ := False;
      LIndicAwaitConsonant := False;
      Continue;
    end;

    Break;
  end;

  Result.ByteLen := Integer(LPos);
  if (LFirstCat = gbRegionalIndicator) and (LRICount = 2) then
    Result.Width := 2;
end;

end.

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

function ClassifyCodepoint(ACp: UInt32): TGBCategory;
begin
  if ACp = $200D then Exit(gbZWJ);

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
  if (ACp >= $1AB0) and (ACp <= $1AFF) then Exit(gbExtend);
  if (ACp >= $1DC0) and (ACp <= $1DFF) then Exit(gbExtend);
  if (ACp >= $20D0) and (ACp <= $20F0) then Exit(gbExtend);
  if (ACp >= $1F3FB) and (ACp <= $1F3FF) then Exit(gbExtend);
  if (ACp >= $FE00) and (ACp <= $FE0F) then Exit(gbExtend);
  if (ACp >= $FE20) and (ACp <= $FE2F) then Exit(gbExtend);
  if (ACp >= $E0100) and (ACp <= $E01EF) then Exit(gbExtend);

  if (ACp >= $0903) and (ACp <= $0903) then Exit(gbSpacingMark);
  if (ACp >= $093E) and (ACp <= $0940) then Exit(gbSpacingMark);
  if (ACp >= $0949) and (ACp <= $094C) then Exit(gbSpacingMark);
  if (ACp >= $0982) and (ACp <= $0983) then Exit(gbSpacingMark);
  if (ACp >= $09BE) and (ACp <= $09C0) then Exit(gbSpacingMark);
  if (ACp >= $09C7) and (ACp <= $09C8) then Exit(gbSpacingMark);
  if (ACp >= $09CB) and (ACp <= $09CC) then Exit(gbSpacingMark);

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
  Result := ACp = $2764;
end;

function GraphemeNext(const AData: PByte; ALen: SizeUInt): TGraphemeResult;
var
  LPos: SizeUInt;
  LDec: TUTF8DecodeResult;
  LFirstCp: UInt32;
  LFirstCat, LCat: TGBCategory;
  LRICount: Integer;
  LAfterZWJ: Boolean;
begin
  Result.ByteLen := 0;
  Result.Width := 0;
  Result.CodePoints := 0;

  if ALen = 0 then Exit;

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
  LAfterZWJ := (LFirstCat = gbZWJ);

  while LPos < ALen do
  begin
    LDec := UTF8Decode(@AData[LPos], ALen - LPos);
    if LDec.ByteLen = 0 then Break;

    LCat := ClassifyCodepoint(LDec.CodePoint);

    if LCat = gbExtend then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      if (LDec.CodePoint = $FE0F) and IsEmojiVariationBase(LFirstCp) then
        Result.Width := 2
      else if (LDec.CodePoint = $20E3) and IsKeycapBase(LFirstCp) then
        Result.Width := 2;
      LAfterZWJ := False;
      Continue;
    end;

    if LCat = gbSpacingMark then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      LAfterZWJ := False;
      Continue;
    end;

    if LCat = gbZWJ then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      LAfterZWJ := True;
      Continue;
    end;

    if LAfterZWJ and (LCat = gbEmojiPresentation) then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      LAfterZWJ := False;
      Continue;
    end;

    if (LFirstCat = gbRegionalIndicator) and (LCat = gbRegionalIndicator) and (LRICount = 1) then
    begin
      Inc(LPos, LDec.ByteLen);
      Inc(Result.CodePoints);
      Inc(LRICount);
      Result.Width := 2;
      LAfterZWJ := False;
      Continue;
    end;

    Break;
  end;

  Result.ByteLen := Integer(LPos);
  if (LFirstCat = gbRegionalIndicator) and (LRICount = 2) then
    Result.Width := 2;
end;

end.

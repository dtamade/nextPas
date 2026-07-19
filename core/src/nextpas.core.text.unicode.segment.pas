unit nextpas.core.text.unicode.segment;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.unicode.types;

type
  // 文本分割类型
  TSegmentType = (
    stGraphemeCluster,  // 字素簇
    stWord,             // 单词
    stLine,             // 行
    stSentence          // 句子
  );

  // 分割结果
  TSegmentResult = record
    Start: SizeInt;
    Length: SizeInt;
    SegmentType: TSegmentType;
  end;

  // 分割结果数组
  TSegmentResultArray = array of TSegmentResult;

  // 分割器接口
  IUnicodeSegmenter = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-F12345678901}']
    function SegmentGraphemeClusters(const AText: string): TSegmentResultArray;
    function SegmentWords(const AText: string): TSegmentResultArray;
    function SegmentLines(const AText: string): TSegmentResultArray;
    function SegmentSentences(const AText: string): TSegmentResultArray;
    function NextGraphemeCluster(const AText: string; const APos: SizeInt): SizeInt;
    function NextWord(const AText: string; const APos: SizeInt): SizeInt;
    function NextLine(const AText: string; const APos: SizeInt): SizeInt;
    function NextSentence(const AText: string; const APos: SizeInt): SizeInt;
  end;

  // 默认分割器实现
  TUnicodeSegmenter = class(TInterfacedObject, IUnicodeSegmenter)
  public
    function SegmentGraphemeClusters(const AText: string): TSegmentResultArray;
    function SegmentWords(const AText: string): TSegmentResultArray;
    function SegmentLines(const AText: string): TSegmentResultArray;
    function SegmentSentences(const AText: string): TSegmentResultArray;
    function NextGraphemeCluster(const AText: string; const APos: SizeInt): SizeInt;
    function NextWord(const AText: string; const APos: SizeInt): SizeInt;
    function NextLine(const AText: string; const APos: SizeInt): SizeInt;
    function NextSentence(const AText: string; const APos: SizeInt): SizeInt;
  end;

// 全局分割器实例
function UnicodeSegmenter: IUnicodeSegmenter;

{ Shared UAX #29 grapheme-cluster core (byte-oriented).
  Returns bytes consumed for the cluster starting at AData. }
function GraphemeClusterByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;

{ Shared UAX #29 word-boundary core (byte-oriented).
  Returns bytes from AData to the next word break. }
function WordBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;

{ Shared UAX #29 sentence-boundary core (byte-oriented).
  Returns bytes from AData to the next sentence break. }
function SentenceBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;

{ Shared UAX #14 line-break opportunity core (byte-oriented).
  Returns bytes from AData to the next line-break opportunity.
  Distinct from NextLine (hard line separators only). }
function LineBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;

implementation

uses
  nextpas.core.text.unicode.props,
  nextpas.core.text.unicode.base,
  nextpas.core.text.utf8;

var
  FUnicodeSegmenter: IUnicodeSegmenter;
  FSegmenterCS: TRTLCriticalSection;

function UnicodeSegmenter: IUnicodeSegmenter;
begin
  if FUnicodeSegmenter = nil then
  begin
    EnterCriticalSection(FSegmenterCS);
    try
      if FUnicodeSegmenter = nil then
        FUnicodeSegmenter := TUnicodeSegmenter.Create;
    finally
      LeaveCriticalSection(FSegmenterCS);
    end;
  end;
  Result := FUnicodeSegmenter;
end;

{ TUnicodeSegmenter }

function TUnicodeSegmenter.SegmentGraphemeClusters(const AText: string): TSegmentResultArray;
var
  LPos, LStart, LLen, LCount, LCapacity: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // 预分配空间，避免动态增长
  LCapacity := LLen div 2 + 1;
  SetLength(LResults, LCapacity);
  LCount := 0;
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextGraphemeCluster(AText, LPos);
    if LCount >= LCapacity then
    begin
      LCapacity := LCapacity * 2;
      SetLength(LResults, LCapacity);
    end;
    LResults[LCount].Start := LStart;
    LResults[LCount].Length := LPos - LStart;
    LResults[LCount].SegmentType := stGraphemeCluster;
    Inc(LCount);
  end;

  SetLength(LResults, LCount);
  Result := LResults;
end;

function TUnicodeSegmenter.SegmentWords(const AText: string): TSegmentResultArray;
var
  LPos, LStart, LLen, LCount, LCapacity: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  LCapacity := LLen div 2 + 1;
  SetLength(LResults, LCapacity);
  LCount := 0;
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextWord(AText, LPos);
    if LPos > LStart then
    begin
      if LCount >= LCapacity then
      begin
        LCapacity := LCapacity * 2;
        SetLength(LResults, LCapacity);
      end;
      LResults[LCount].Start := LStart;
      LResults[LCount].Length := LPos - LStart;
      LResults[LCount].SegmentType := stWord;
      Inc(LCount);
    end
    else
      Break; { prevent infinite loop on zero-length advance }
  end;

  SetLength(LResults, LCount);
  Result := LResults;
end;

function TUnicodeSegmenter.SegmentLines(const AText: string): TSegmentResultArray;
var
  LPos, LStart, LLen, LCount, LCapacity: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // 预分配空间
  LCapacity := 16;
  SetLength(LResults, LCapacity);
  LCount := 0;
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextLine(AText, LPos);
    if LCount >= LCapacity then
    begin
      LCapacity := LCapacity * 2;
      SetLength(LResults, LCapacity);
    end;
    LResults[LCount].Start := LStart;
    LResults[LCount].Length := LPos - LStart;
    LResults[LCount].SegmentType := stLine;
    Inc(LCount);
  end;

  SetLength(LResults, LCount);
  Result := LResults;
end;

function TUnicodeSegmenter.SegmentSentences(const AText: string): TSegmentResultArray;
var
  LPos, LStart, LLen, LCount, LCapacity: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // 预分配空间
  LCapacity := 8;
  SetLength(LResults, LCapacity);
  LCount := 0;
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextSentence(AText, LPos);
    if LCount >= LCapacity then
    begin
      LCapacity := LCapacity * 2;
      SetLength(LResults, LCapacity);
    end;
    LResults[LCount].Start := LStart;
    LResults[LCount].Length := LPos - LStart;
    LResults[LCount].SegmentType := stSentence;
    Inc(LCount);
  end;

  SetLength(LResults, LCount);
  Result := LResults;
end;

function GraphemeClusterByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
{**
 * UAX #29 Grapheme Cluster Boundary core (Unicode 16.0), byte-oriented.
 * See NextGraphemeCluster for rule list.
 *}
var
  LPos: SizeUInt;
  LCurGcb: TGraphemeBreakProperty;
  LDecode: TUTF8DecodeResult;
  LAheadPos: SizeUInt;
  LAheadGcb: TGraphemeBreakProperty;
  LAheadDecode: TUTF8DecodeResult;
  LRICount: SizeInt;
  LInCB: TIndicConjunctBreak;
  LAheadInCB: TIndicConjunctBreak;
  LInCBConsonant: Boolean;
  LInCBLinker: Boolean;
begin
  if (AData = nil) or (ALen = 0) then
    Exit(0);

  LDecode := UTF8Decode(AData, ALen);
  if LDecode.ByteLen = 0 then
    Exit(1); // Invalid UTF-8: consume one byte

  LPos := SizeUInt(LDecode.ByteLen);
  LCurGcb := GetGraphemeBreakProperty(LDecode.CodePoint);
  LInCB := GetIndicConjunctBreak(LDecode.CodePoint);
  LInCBConsonant := (LInCB = icbConsonant);
  LInCBLinker := False;

  if LCurGcb in [gbpCR, gbpLF, gbpControl] then
  begin
    if (LCurGcb = gbpCR) and (LPos < ALen) then
    begin
      LAheadDecode := UTF8Decode(@AData[LPos], ALen - LPos);
      if (LAheadDecode.ByteLen > 0) and
         (GetGraphemeBreakProperty(LAheadDecode.CodePoint) = gbpLF) then
        Exit(LPos + SizeUInt(LAheadDecode.ByteLen));
    end;
    Exit(LPos);
  end;

  if LCurGcb = gbpRegionalIndicator then
    LRICount := 1
  else
    LRICount := 0;

  while LPos < ALen do
  begin
    LAheadDecode := UTF8Decode(@AData[LPos], ALen - LPos);
    if LAheadDecode.ByteLen = 0 then
    begin
      { Ill-formed UTF-8: treat as U+FFFD (Other) consuming 1 byte so
        Prepend × replacement still forms one cluster. }
      LAheadDecode.CodePoint := $FFFD;
      LAheadDecode.ByteLen := 1;
    end;
    LAheadGcb := GetGraphemeBreakProperty(LAheadDecode.CodePoint);
    LAheadInCB := GetIndicConjunctBreak(LAheadDecode.CodePoint);
    LAheadPos := LPos + SizeUInt(LAheadDecode.ByteLen);

    if LAheadGcb in [gbpCR, gbpLF, gbpControl] then
      Break;

    if (LCurGcb = gbpExtendedPictographic) and (LAheadGcb = gbpZWJ) then
    begin
      if LAheadPos < ALen then
      begin
        LAheadDecode := UTF8Decode(@AData[LAheadPos], ALen - LAheadPos);
        if (LAheadDecode.ByteLen > 0) and
           (GetGraphemeBreakProperty(LAheadDecode.CodePoint) = gbpExtendedPictographic) then
        begin
          LCurGcb := gbpExtendedPictographic;
          LRICount := 0;
          LInCBConsonant := False;
          LInCBLinker := False;
          LPos := LAheadPos + SizeUInt(LAheadDecode.ByteLen);
          Continue;
        end;
      end;
    end;

    if LAheadGcb in [gbpExtend, gbpZWJ] then
    begin
      if LCurGcb <> gbpExtendedPictographic then
      begin
        LCurGcb := LAheadGcb;
        LRICount := 0;
      end;
      if LInCBConsonant and (LAheadInCB = icbLinker) then
        LInCBLinker := True;
      LPos := LAheadPos;
      Continue;
    end;

    if LAheadGcb = gbpSpacingMark then
    begin
      if LCurGcb <> gbpExtendedPictographic then
      begin
        LCurGcb := gbpSpacingMark;
        LRICount := 0;
      end;
      LInCBConsonant := False;
      LInCBLinker := False;
      LPos := LAheadPos;
      Continue;
    end;

    if (LAheadInCB = icbConsonant) and LInCBConsonant and LInCBLinker then
    begin
      LCurGcb := LAheadGcb;
      LRICount := 0;
      LInCBConsonant := True;
      LInCBLinker := False;
      LPos := LAheadPos;
      Continue;
    end;

    if LCurGcb = gbpPrepend then
    begin
      LCurGcb := LAheadGcb;
      if LAheadGcb = gbpRegionalIndicator then
        LRICount := 1
      else
        LRICount := 0;
      LInCBConsonant := (LAheadInCB = icbConsonant);
      LInCBLinker := False;
      LPos := LAheadPos;
      Continue;
    end;

    if (LCurGcb = gbpL) and (LAheadGcb in [gbpL, gbpV, gbpLV, gbpLVT]) then
    begin
      LCurGcb := LAheadGcb;
      LRICount := 0;
      LInCBConsonant := False;
      LInCBLinker := False;
      LPos := LAheadPos;
      Continue;
    end;

    if (LCurGcb in [gbpV, gbpLV]) and (LAheadGcb in [gbpV, gbpT]) then
    begin
      LCurGcb := LAheadGcb;
      LRICount := 0;
      LInCBConsonant := False;
      LInCBLinker := False;
      LPos := LAheadPos;
      Continue;
    end;

    if (LCurGcb in [gbpLVT, gbpT]) and (LAheadGcb = gbpT) then
    begin
      LCurGcb := gbpT;
      LRICount := 0;
      LInCBConsonant := False;
      LInCBLinker := False;
      LPos := LAheadPos;
      Continue;
    end;

    if (LCurGcb = gbpRegionalIndicator) and (LAheadGcb = gbpRegionalIndicator) then
    begin
      Inc(LRICount);
      if LRICount mod 2 = 1 then
        Break;
      LCurGcb := gbpRegionalIndicator;
      LInCBConsonant := False;
      LInCBLinker := False;
      LPos := LAheadPos;
      Continue;
    end;

    Break;
  end;

  Result := LPos;
end;

function TUnicodeSegmenter.NextGraphemeCluster(const AText: string; const APos: SizeInt): SizeInt;
var
  LLen: SizeInt;
  LBytes: SizeUInt;
begin
  LLen := Length(AText);
  if APos > LLen then
    Exit(APos);
  if APos < 1 then
    Exit(APos);
  LBytes := GraphemeClusterByteLen(@AText[APos], SizeUInt(LLen - APos + 1));
  Result := APos + SizeInt(LBytes);
end;

function IsWordIgnorable(const AWb: TWordBreakProperty): Boolean; inline;
begin
  Result := AWb in [wbpExtend, wbpFormat, wbpZWJ];
end;

function IsAHLetter(const AWb: TWordBreakProperty): Boolean; inline;
begin
  Result := AWb in [wbpALetter, wbpHebrewLetter];
end;

function IsMidNumLetQ(const AWb: TWordBreakProperty): Boolean; inline;
begin
  Result := AWb in [wbpMidNumLet, wbpSingleQuote];
end;

function WordBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
{**
 * UAX #29 Word Boundary (Unicode 16.0), byte-oriented.
 * Returns the number of bytes from AData to the next word break.
 *}
const
  MAX_CPS = 512;
var
  LCps: array[0..MAX_CPS - 1] of TUnicodeCodepoint;
  LWb: array[0..MAX_CPS - 1] of TWordBreakProperty;
  LByteEnds: array[0..MAX_CPS - 1] of SizeUInt;
  LCount: Integer;
  LPos: SizeUInt;
  LDecode: TUTF8DecodeResult;
  LI, LJ, LK: Integer;
  LLeft, LRight: TWordBreakProperty;
  LIsEP: Boolean;

  function SkipIgnorableBack(AFrom: Integer): Integer;
  begin
    Result := AFrom;
    while (Result >= 0) and IsWordIgnorable(LWb[Result]) do
      Dec(Result);
  end;

  function SkipIgnorableForward(AFrom: Integer): Integer;
  begin
    Result := AFrom;
    while (Result < LCount) and IsWordIgnorable(LWb[Result]) do
      Inc(Result);
  end;

  function NextNonIgnorable(AFrom: Integer): Integer;
  begin
    Result := SkipIgnorableForward(AFrom);
    if Result >= LCount then
      Result := -1;
  end;

  function PrevNonIgnorable(AFrom: Integer): Integer;
  begin
    Result := SkipIgnorableBack(AFrom);
  end;

  function NoBreakBetween(const AIdx: Integer): Boolean;
  { True if there is NO break opportunity between codepoint AIdx and AIdx+1. }
  begin
    Result := False;
    if (AIdx < 0) or (AIdx + 1 >= LCount) then
      Exit(False);

    LLeft := LWb[AIdx];
    LRight := LWb[AIdx + 1];

    { WB3: CR × LF }
    if (LLeft = wbpCR) and (LRight = wbpLF) then
      Exit(True);

    { WB3a: (Newline | CR | LF) ÷ }
    if LLeft in [wbpNewline, wbpCR, wbpLF] then
      Exit(False);

    { WB3b: ÷ (Newline | CR | LF) }
    if LRight in [wbpNewline, wbpCR, wbpLF] then
      Exit(False);

    { WB3c: ZWJ × Extended_Pictographic }
    if LLeft = wbpZWJ then
    begin
      LIsEP := GetGraphemeBreakProperty(LCps[AIdx + 1]) = gbpExtendedPictographic;
      if LIsEP then
        Exit(True);
    end;

    { WB3d: WSegSpace × WSegSpace }
    if (LLeft = wbpWSegSpace) and (LRight = wbpWSegSpace) then
      Exit(True);

    { WB4: do not break before Extend | Format | ZWJ }
    if IsWordIgnorable(LRight) then
      Exit(True);

    { Resolve left through ignorable (WB4): left becomes last non-ignorable at/before AIdx }
    LJ := PrevNonIgnorable(AIdx);
    if LJ < 0 then
      Exit(False); { only ignorables after sot → break before next base (WB999) }
    LLeft := LWb[LJ];
    LRight := LWb[AIdx + 1]; { already non-ignorable }

    { WB5: AHLetter × AHLetter }
    if IsAHLetter(LLeft) and IsAHLetter(LRight) then
      Exit(True);

    { WB6: AHLetter × (MidLetter | MidNumLetQ) AHLetter }
    if IsAHLetter(LLeft) and ((LRight = wbpMidLetter) or IsMidNumLetQ(LRight)) then
    begin
      LK := NextNonIgnorable(AIdx + 2);
      if (LK >= 0) and IsAHLetter(LWb[LK]) then
        Exit(True);
    end;

    { WB7: AHLetter (MidLetter | MidNumLetQ) × AHLetter }
    if IsAHLetter(LRight) and ((LLeft = wbpMidLetter) or IsMidNumLetQ(LLeft)) then
    begin
      LK := PrevNonIgnorable(LJ - 1);
      if (LK >= 0) and IsAHLetter(LWb[LK]) then
        Exit(True);
    end;

    { WB7a: Hebrew_Letter × Single_Quote }
    if (LLeft = wbpHebrewLetter) and (LRight = wbpSingleQuote) then
      Exit(True);

    { WB7b: Hebrew_Letter × Double_Quote Hebrew_Letter }
    if (LLeft = wbpHebrewLetter) and (LRight = wbpDoubleQuote) then
    begin
      LK := NextNonIgnorable(AIdx + 2);
      if (LK >= 0) and (LWb[LK] = wbpHebrewLetter) then
        Exit(True);
    end;

    { WB7c: Hebrew_Letter Double_Quote × Hebrew_Letter }
    if (LLeft = wbpDoubleQuote) and (LRight = wbpHebrewLetter) then
    begin
      LK := PrevNonIgnorable(LJ - 1);
      if (LK >= 0) and (LWb[LK] = wbpHebrewLetter) then
        Exit(True);
    end;

    { WB8: Numeric × Numeric }
    if (LLeft = wbpNumeric) and (LRight = wbpNumeric) then
      Exit(True);

    { WB9: AHLetter × Numeric }
    if IsAHLetter(LLeft) and (LRight = wbpNumeric) then
      Exit(True);

    { WB10: Numeric × AHLetter }
    if (LLeft = wbpNumeric) and IsAHLetter(LRight) then
      Exit(True);

    { WB11: Numeric (MidNum | MidNumLetQ) × Numeric }
    if (LRight = wbpNumeric) and ((LLeft = wbpMidNum) or IsMidNumLetQ(LLeft)) then
    begin
      LK := PrevNonIgnorable(LJ - 1);
      if (LK >= 0) and (LWb[LK] = wbpNumeric) then
        Exit(True);
    end;

    { WB12: Numeric × (MidNum | MidNumLetQ) Numeric }
    if (LLeft = wbpNumeric) and ((LRight = wbpMidNum) or IsMidNumLetQ(LRight)) then
    begin
      LK := NextNonIgnorable(AIdx + 2);
      if (LK >= 0) and (LWb[LK] = wbpNumeric) then
        Exit(True);
    end;

    { WB13: Katakana × Katakana }
    if (LLeft = wbpKatakana) and (LRight = wbpKatakana) then
      Exit(True);

    { WB13a: (AHLetter | Numeric | Katakana | ExtendNumLet) × ExtendNumLet }
    if (LRight = wbpExtendNumLet) and
       (IsAHLetter(LLeft) or (LLeft in [wbpNumeric, wbpKatakana, wbpExtendNumLet])) then
      Exit(True);

    { WB13b: ExtendNumLet × (AHLetter | Numeric | Katakana) }
    if (LLeft = wbpExtendNumLet) and
       (IsAHLetter(LRight) or (LRight in [wbpNumeric, wbpKatakana])) then
      Exit(True);

    { WB15/16: Regional_Indicator × Regional_Indicator (pairs) }
    if (LLeft = wbpRegionalIndicator) and (LRight = wbpRegionalIndicator) then
    begin
      { Count consecutive RIs immediately before AIdx+1, skipping only ignorables
        that are glued (WB4) — RI sequences are contiguous non-ignorable RIs. }
      LK := 0;
      LJ := AIdx;
      while LJ >= 0 do
      begin
        if IsWordIgnorable(LWb[LJ]) then
        begin
          Dec(LJ);
          Continue;
        end;
        if LWb[LJ] <> wbpRegionalIndicator then
          Break;
        Inc(LK);
        Dec(LJ);
      end;
      { LK is number of RIs ending at AIdx inclusive.
        Odd count → pair incomplete → no break (WB15/16). }
      if (LK mod 2) = 1 then
        Exit(True);
    end;

    { WB999: Any ÷ Any }
    Result := False;
  end;

begin
  if (AData = nil) or (ALen = 0) then
    Exit(0);

  { Decode up to MAX_CPS codepoints (enough for any official test row). }
  LCount := 0;
  LPos := 0;
  while (LPos < ALen) and (LCount < MAX_CPS) do
  begin
    LDecode := UTF8Decode(@AData[LPos], ALen - LPos);
    if LDecode.ByteLen = 0 then
    begin
      LCps[LCount] := $FFFD;
      LWb[LCount] := wbpOther;
      LPos := LPos + 1;
    end
    else
    begin
      LCps[LCount] := LDecode.CodePoint;
      LWb[LCount] := GetWordBreakProperty(LDecode.CodePoint);
      LPos := LPos + SizeUInt(LDecode.ByteLen);
    end;
    LByteEnds[LCount] := LPos;
    Inc(LCount);
  end;

  if LCount = 0 then
    Exit(0);

  { Find first break after sot (index 0). }
  for LI := 0 to LCount - 2 do
  begin
    if not NoBreakBetween(LI) then
      Exit(LByteEnds[LI]);
  end;

  { No internal break → whole decoded span (or until we hit MAX_CPS mid-stream). }
  Result := LByteEnds[LCount - 1];
end;

function SentenceBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
{**
 * UAX #29 Sentence Boundary (Unicode 16.0), byte-oriented.
 * Returns the number of bytes from AData to the next sentence break.
 *}
const
  MAX_CPS = 512;
var
  LSb: array[0..MAX_CPS - 1] of TSentenceBreakProperty;
  LByteEnds: array[0..MAX_CPS - 1] of SizeUInt;
  LCount: Integer;
  LPos: SizeUInt;
  LDecode: TUTF8DecodeResult;
  LI, LJ, LK: Integer;
  LLeft, LRight: TSentenceBreakProperty;

  function IsSentenceIgnorable(const ASb: TSentenceBreakProperty): Boolean; inline;
  begin
    Result := ASb in [sbpExtend, sbpFormat];
  end;

  function IsSATerm(const ASb: TSentenceBreakProperty): Boolean; inline;
  begin
    Result := ASb in [sbpSTerm, sbpATerm];
  end;

  function IsParaSep(const ASb: TSentenceBreakProperty): Boolean; inline;
  begin
    Result := ASb in [sbpSep, sbpCR, sbpLF];
  end;

  function PrevNonIgnorable(AFrom: Integer): Integer;
  begin
    Result := AFrom;
    while (Result >= 0) and IsSentenceIgnorable(LSb[Result]) do
      Dec(Result);
  end;

  function EndsWithSATermCloseSp(const AIdx: Integer): Boolean;
  begin
    LJ := PrevNonIgnorable(AIdx);
    if LJ < 0 then
      Exit(False);
    if LSb[LJ] = sbpSp then
    begin
      while LJ >= 0 do
      begin
        if IsSentenceIgnorable(LSb[LJ]) then
        begin
          Dec(LJ);
          Continue;
        end;
        if LSb[LJ] = sbpSp then
        begin
          Dec(LJ);
          Continue;
        end;
        Break;
      end;
      LJ := PrevNonIgnorable(LJ);
      if LJ < 0 then
        Exit(False);
    end;
    if LSb[LJ] = sbpClose then
    begin
      while LJ >= 0 do
      begin
        if IsSentenceIgnorable(LSb[LJ]) then
        begin
          Dec(LJ);
          Continue;
        end;
        if LSb[LJ] = sbpClose then
        begin
          Dec(LJ);
          Continue;
        end;
        Break;
      end;
      LJ := PrevNonIgnorable(LJ);
      if LJ < 0 then
        Exit(False);
    end;
    Result := IsSATerm(LSb[LJ]);
  end;

  function EndsWithSATermClose(const AIdx: Integer): Boolean;
  begin
    LJ := PrevNonIgnorable(AIdx);
    if LJ < 0 then
      Exit(False);
    if LSb[LJ] = sbpClose then
    begin
      while LJ >= 0 do
      begin
        if IsSentenceIgnorable(LSb[LJ]) then
        begin
          Dec(LJ);
          Continue;
        end;
        if LSb[LJ] = sbpClose then
        begin
          Dec(LJ);
          Continue;
        end;
        Break;
      end;
      LJ := PrevNonIgnorable(LJ);
      if LJ < 0 then
        Exit(False);
    end;
    Result := IsSATerm(LSb[LJ]);
  end;

  function EndsWithATermCloseSp(const AIdx: Integer): Boolean;
  begin
    LJ := PrevNonIgnorable(AIdx);
    if LJ < 0 then
      Exit(False);
    if LSb[LJ] = sbpSp then
    begin
      while LJ >= 0 do
      begin
        if IsSentenceIgnorable(LSb[LJ]) then
        begin
          Dec(LJ);
          Continue;
        end;
        if LSb[LJ] = sbpSp then
        begin
          Dec(LJ);
          Continue;
        end;
        Break;
      end;
      LJ := PrevNonIgnorable(LJ);
      if LJ < 0 then
        Exit(False);
    end;
    if LSb[LJ] = sbpClose then
    begin
      while LJ >= 0 do
      begin
        if IsSentenceIgnorable(LSb[LJ]) then
        begin
          Dec(LJ);
          Continue;
        end;
        if LSb[LJ] = sbpClose then
        begin
          Dec(LJ);
          Continue;
        end;
        Break;
      end;
      LJ := PrevNonIgnorable(LJ);
      if LJ < 0 then
        Exit(False);
    end;
    Result := LSb[LJ] = sbpATerm;
  end;

  function NoBreakBetween(const AIdx: Integer): Boolean;
  { True if there is NO break opportunity between codepoint AIdx and AIdx+1. }
  begin
    Result := True;
    if (AIdx < 0) or (AIdx + 1 >= LCount) then
      Exit(True);

    LLeft := LSb[AIdx];
    LRight := LSb[AIdx + 1];

    { SB3: CR × LF }
    if (LLeft = sbpCR) and (LRight = sbpLF) then
      Exit(True);

    { SB4: (Sep | CR | LF) ÷ }
    if IsParaSep(LLeft) then
      Exit(False);

    { SB5: do not break before Extend | Format }
    if IsSentenceIgnorable(LRight) then
      Exit(True);

    LJ := PrevNonIgnorable(AIdx);
    if LJ < 0 then
      Exit(True);

    { Extend/Format after ParaSep are not collapsed into prior base }
    if IsSentenceIgnorable(LLeft) and IsParaSep(LSb[LJ]) then
      Exit(True);

    LLeft := LSb[LJ];
    { LRight already non-ignorable }

    { SB6: ATerm × Numeric }
    if (LLeft = sbpATerm) and (LRight = sbpNumeric) then
      Exit(True);

    { SB7: (Upper | Lower) ATerm × Upper }
    if (LLeft = sbpATerm) and (LRight = sbpUpper) then
    begin
      LK := PrevNonIgnorable(LJ - 1);
      if (LK >= 0) and (LSb[LK] in [sbpUpper, sbpLower]) then
        Exit(True);
    end;

    { SB8: ATerm Close* Sp* × (¬(OLetter | Upper | Lower | ParaSep | SATerm))* Lower }
    if EndsWithATermCloseSp(AIdx) then
    begin
      LK := AIdx + 1;
      while LK < LCount do
      begin
        if IsSentenceIgnorable(LSb[LK]) then
        begin
          Inc(LK);
          Continue;
        end;
        if LSb[LK] = sbpLower then
          Exit(True);
        if LSb[LK] in [sbpOLetter, sbpUpper, sbpLower, sbpSep, sbpCR, sbpLF, sbpSTerm, sbpATerm] then
          Break;
        Inc(LK);
      end;
    end;

    { SB8a: SATerm Close* Sp* × (SContinue | SATerm) }
    if EndsWithSATermCloseSp(AIdx) and (LRight in [sbpSContinue, sbpSTerm, sbpATerm]) then
      Exit(True);

    { SB9: SATerm Close* × (Close | Sp | Sep | CR | LF) }
    if EndsWithSATermClose(AIdx) and (LRight in [sbpClose, sbpSp, sbpSep, sbpCR, sbpLF]) then
      Exit(True);

    { SB10: SATerm Close* Sp* × (Sp | Sep | CR | LF) }
    if EndsWithSATermCloseSp(AIdx) and (LRight in [sbpSp, sbpSep, sbpCR, sbpLF]) then
      Exit(True);

    { SB11: SATerm Close* Sp* (Sep | CR | LF)? ÷ }
    if IsParaSep(LSb[AIdx]) then
    begin
      if EndsWithSATermCloseSp(AIdx - 1) then
        Exit(False);
    end
    else if EndsWithSATermCloseSp(AIdx) then
      Exit(False);

    { SB12: Any × Any }
    Result := True;
  end;

begin
  if (AData = nil) or (ALen = 0) then
    Exit(0);

  LCount := 0;
  LPos := 0;
  while (LPos < ALen) and (LCount < MAX_CPS) do
  begin
    LDecode := UTF8Decode(@AData[LPos], ALen - LPos);
    if LDecode.ByteLen = 0 then
    begin
      LSb[LCount] := sbpOther;
      LPos := LPos + 1;
    end
    else
    begin
      LSb[LCount] := GetSentenceBreakProperty(LDecode.CodePoint);
      LPos := LPos + SizeUInt(LDecode.ByteLen);
    end;
    LByteEnds[LCount] := LPos;
    Inc(LCount);
  end;

  if LCount = 0 then
    Exit(0);

  for LI := 0 to LCount - 2 do
  begin
    if not NoBreakBetween(LI) then
      Exit(LByteEnds[LI]);
  end;

  Result := LByteEnds[LCount - 1];
end;

function LineBreakByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt;
{** UAX #14 line-break opportunities (Unicode 16.0). Not hard NextLine. **}
const
  MAX_CPS = 512;
  LB_ACT_DIR = 0;
  LB_ACT_IND = 1;
  LB_ACT_CMI = 2;
  LB_ACT_CMP = 3;
  LB_ACT_PRH = 4;
  LB_BRK_NO = 0;
  LB_BRK_ALLOW = 1;
  LB_BRK_MUST = 2;
  LB_PAIR_TABLE: array[0..32, 0..32] of Byte = (
    (4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4),
    (0, 4, 4, 1, 1, 4, 4, 4, 4, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 4, 4, 4, 4, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (4, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    (1, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (1, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 4, 2, 4, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0),
    (1, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 0, 1, 4, 4, 4, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 0, 1, 4, 4, 4, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (1, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 4, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (1, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 4, 2, 4, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 1, 4, 4, 4, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0),
    (0, 4, 4, 1, 1, 0, 4, 4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0)
  );
  LB_EA_OP_COUNT = 29;
  LB_EA_OP: array[0..28, 0..1] of TUnicodeCodepoint = (
    ($2329, $2329),
    ($3008, $3008),
    ($300A, $300A),
    ($300C, $300C),
    ($300E, $300E),
    ($3010, $3010),
    ($3014, $3014),
    ($3016, $3016),
    ($3018, $3018),
    ($301A, $301A),
    ($301D, $301D),
    ($FE17, $FE17),
    ($FE35, $FE35),
    ($FE37, $FE37),
    ($FE39, $FE39),
    ($FE3B, $FE3B),
    ($FE3D, $FE3D),
    ($FE3F, $FE3F),
    ($FE41, $FE41),
    ($FE43, $FE43),
    ($FE47, $FE47),
    ($FE59, $FE59),
    ($FE5B, $FE5B),
    ($FE5D, $FE5D),
    ($FF08, $FF08),
    ($FF3B, $FF3B),
    ($FF5B, $FF5B),
    ($FF5F, $FF5F),
    ($FF62, $FF62)
  );
  LB_PF_QU_COUNT = 10;
  LB_PF_QU: array[0..9] of TUnicodeCodepoint = (
    $00BB, $2019, $201D, $203A, $2E03, $2E05, $2E0A, $2E0D, $2E1D, $2E21
  );
  LB_PI_QU_COUNT = 12;
  LB_PI_QU: array[0..11] of TUnicodeCodepoint = (
    $00AB, $2018, $201B, $201C, $201F, $2039, $2E02, $2E04, $2E09, $2E0C, $2E1C, $2E20
  );
var
  LCls: array[0..MAX_CPS - 1] of TLineBreakClass;
  LCps: array[0..MAX_CPS - 1] of TUnicodeCodepoint;
  LByteEnds: array[0..MAX_CPS - 1] of SizeUInt;
  LAfter: array[0..MAX_CPS - 1] of Byte;
  LCount, LI: Integer;
  LPos: SizeUInt;
  LDecode: TUTF8DecodeResult;
  LCur, LNew, LLast, LNewR, LRawCur: TLineBreakClass;
  LAction, LBrk: Byte;
  LSkip: Boolean;
  LFZwj, LFHebrew, LFHyInit, LFAfterOrthoVI: Boolean;
  LRiCount: Integer;
  LCh, LBaseCp: TUnicodeCodepoint;
  LOrigRightU16, LOrigLeftU16: Boolean;

  function InPairTable(const ACls: TLineBreakClass): Boolean; inline;
  begin
    Result := (ACls >= lbcOP) and (ACls <= lbcCB);
  end;

  function IsU16Ortho(const ACls: TLineBreakClass): Boolean; inline;
  begin
    Result := ACls in [lbcAK, lbcAP, lbcAS, lbcVF, lbcVI];
  end;

  function ResolveLB(const ACls: TLineBreakClass): TLineBreakClass;
  begin
    case ACls of
      lbcAI: Result := lbcAL;
      lbcCJ: Result := lbcNS;
      lbcSA, lbcSG, lbcXX: Result := lbcAL;
      lbcAK, lbcAP, lbcAS, lbcVF, lbcVI: Result := lbcID;
    else
      Result := ACls;
    end;
  end;

  function IsEastAsianOP(const ACp: TUnicodeCodepoint): Boolean;
  var
    K: Integer;
  begin
    for K := 0 to LB_EA_OP_COUNT - 1 do
      if (ACp >= LB_EA_OP[K, 0]) and (ACp <= LB_EA_OP[K, 1]) then
        Exit(True);
    Result := False;
  end;

  function IsPfQU(const ACp: TUnicodeCodepoint): Boolean;
  var
    K: Integer;
  begin
    for K := 0 to LB_PF_QU_COUNT - 1 do
      if LB_PF_QU[K] = ACp then
        Exit(True);
    Result := False;
  end;

  function IsPiQU(const ACp: TUnicodeCodepoint): Boolean;
  var
    K: Integer;
  begin
    for K := 0 to LB_PI_QU_COUNT - 1 do
      if LB_PI_QU[K] = ACp then
        Exit(True);
    Result := False;
  end;

begin
  if (AData = nil) or (ALen = 0) then
    Exit(0);

  LCount := 0;
  LPos := 0;
  while (LPos < ALen) and (LCount < MAX_CPS) do
  begin
    LDecode := UTF8Decode(@AData[LPos], ALen - LPos);
    if LDecode.ByteLen = 0 then
    begin
      LCps[LCount] := $FFFD;
      LCls[LCount] := lbcXX;
      LPos := LPos + 1;
    end
    else
    begin
      LCps[LCount] := LDecode.CodePoint;
      LCls[LCount] := GetLineBreakClass(LDecode.CodePoint);
      LPos := LPos + SizeUInt(LDecode.ByteLen);
    end;
    LByteEnds[LCount] := LPos;
    LAfter[LCount] := LB_BRK_NO;
    Inc(LCount);
  end;

  if LCount = 0 then
    Exit(0);
  if LCount = 1 then
    Exit(LByteEnds[0]);

  LCur := ResolveLB(LCls[0]);
  LRawCur := LCls[0];
  LNew := LCur;
  LBaseCp := LCps[0];
  if LCls[0] in [lbcLF, lbcNL] then
  begin
    LCur := lbcBK;
    LRawCur := lbcBK;
  end;
  if LCls[0] = lbcSP then
  begin
    LNew := lbcSP;
    LCur := lbcWJ;
    LRawCur := lbcWJ;
  end;
  { LB10: any remaining CM/ZWJ (incl. at sot / after hard break restart) → AL }
  if LCur in [lbcCM, lbcZWJ] then
  begin
    LCur := lbcAL;
    LRawCur := lbcAL;
  end;
  LLast := lbcXX;
  LFZwj := LCls[0] = lbcZWJ;
  LFHebrew := False;
  LRiCount := 0;
  LFHyInit := (LCls[0] = lbcHY) or (LCps[0] = $2010) or
    ((LCls[0] in [lbcCM, lbcZWJ]) and (LCount > 1) and
     ((LCls[1] = lbcHY) or (LCps[1] = $2010))) or
    (LCur = lbcHY);
  LFAfterOrthoVI := False;

  for LI := 0 to LCount - 2 do
  begin
    if (not (LNew in [lbcCM, lbcZWJ])) or
       (LLast in [lbcBK, lbcCR, lbcLF, lbcNL, lbcSP, lbcZW, lbcXX]) then
      LLast := LNew;
    if LLast in [lbcCM, lbcZWJ] then
      LLast := lbcAL;

    LCh := LCps[LI + 1];
    LNew := LCls[LI + 1];
    LOrigRightU16 := IsU16Ortho(LNew);
    LOrigLeftU16 := IsU16Ortho(LCls[LI]);

    if (LCur = lbcBK) or ((LCur = lbcCR) and (LNew <> lbcLF)) then
    begin
      LAfter[LI] := LB_BRK_MUST;
      { After hard break, next char starts a new line context (LB4/LB5). }
      if LNew = lbcCM then
      begin
        LCur := lbcAL;
        LRawCur := lbcAL;
      end
      else if LNew in [lbcLF, lbcNL] then
      begin
        LCur := lbcBK;
        LRawCur := lbcBK;
      end
      else if LNew = lbcSP then
      begin
        LNew := lbcSP;
        LCur := lbcWJ;
        LRawCur := lbcWJ;
      end
      else
      begin
        LCur := ResolveLB(LNew);
        LRawCur := LNew;
      end;
      LBaseCp := LCh;
      LLast := lbcXX;
      LFZwj := LNew = lbcZWJ;
      LFHebrew := False;
      LRiCount := 0;
      LFHyInit := (LNew = lbcHY) or (LNew = lbcCM);
      Continue;
    end;

    { LB10: remaining CM/ZWJ after SP/ZW/hard breaks only (not after WJ/GL) }
    if (LNew in [lbcCM, lbcZWJ]) and
       (LCur in [lbcSP, lbcZW, lbcBK, lbcCR, lbcLF, lbcNL]) then
      LNew := lbcAL;

    if LNew = lbcSP then
    begin
      LAfter[LI] := LB_BRK_NO;
      LFZwj := False;
      Continue;
    end;
    if LNew in [lbcBK, lbcLF, lbcNL] then
    begin
      LCur := lbcBK;
      LAfter[LI] := LB_BRK_NO;
      LFZwj := False;
      Continue;
    end;
    if LNew = lbcCR then
    begin
      LCur := lbcCR;
      LAfter[LI] := LB_BRK_NO;
      LFZwj := False;
      Continue;
    end;

    LNewR := ResolveLB(LNew);
    LBrk := LB_BRK_ALLOW;
    LSkip := False;

    if (not InPairTable(LCur)) or (not InPairTable(LNewR)) then
    begin
      LBrk := LB_BRK_ALLOW;
      if InPairTable(LNewR) then
        LCur := LNewR
      else
        LCur := lbcAL;
    end
    else
    begin
      LAction := LB_PAIR_TABLE[Ord(LCur) - 1, Ord(LNewR) - 1];
      case LAction of
        LB_ACT_DIR: LBrk := LB_BRK_ALLOW;
        LB_ACT_IND:
          if LLast = lbcSP then LBrk := LB_BRK_ALLOW else LBrk := LB_BRK_NO;
        LB_ACT_CMI:
          if LLast <> lbcSP then
          begin
            LBrk := LB_BRK_NO;
            LSkip := True;
          end
          else
            LBrk := LB_BRK_ALLOW;
        LB_ACT_CMP:
          begin
            LBrk := LB_BRK_NO;
            if LLast <> lbcSP then
              LSkip := True;
          end;
        LB_ACT_PRH: LBrk := LB_BRK_NO;
      else
        LBrk := LB_BRK_ALLOW;
      end;

      if LFZwj then
        LBrk := LB_BRK_NO;

      if ((LCur = lbcCL) and (LNewR in [lbcPO, lbcPR])) or
         ((LCur = lbcCP) and (LNewR in [lbcPO, lbcPR])) or
         ((LCur in [lbcPO, lbcPR]) and (LNewR = lbcOP)) then
        LBrk := LB_BRK_ALLOW;

      if (LLast <> lbcSP) and (LCur in [lbcAL, lbcHL, lbcNU]) and
         (LNewR = lbcOP) and (not IsEastAsianOP(LCh)) then
        LBrk := LB_BRK_NO;
      if (LLast <> lbcSP) and (LCur = lbcCP) and
         (LNewR in [lbcAL, lbcHL, lbcNU]) then
        LBrk := LB_BRK_NO;

      { U16 LB28a + selective LB999 }
      if (IsU16Ortho(LRawCur) or IsU16Ortho(LNew) or (LBaseCp = $25CC)) and (LLast <> lbcSP) then
      begin
        { LB28a: AP × (AK|AS); (AK|AS|◌) × (VF|VI); (… VI) × (AK|◌) }
        if (LRawCur = lbcAP) and (LNew in [lbcAK, lbcAS]) then
          LBrk := LB_BRK_NO
        else if ((LRawCur in [lbcAK, lbcAS]) or (LBaseCp = $25CC)) and
                (LNew in [lbcVF, lbcVI]) then
        begin
          LBrk := LB_BRK_NO;
          if LNew = lbcVI then
            LFAfterOrthoVI := True;
        end
        else if LFAfterOrthoVI and ((LNew in [lbcAK, lbcAS]) or (LCh = $25CC)) then
        begin
          LBrk := LB_BRK_NO;
          LFAfterOrthoVI := False;
        end
        else if (LBaseCp = $25CC) and (LNew in [lbcAK, lbcAS, lbcVI, lbcVF]) then
        begin
          LBrk := LB_BRK_NO;
          if LNew = lbcVI then
            LFAfterOrthoVI := True;
        end
        else if (LBrk = LB_BRK_NO) and (LAction = LB_ACT_IND) then
        begin
          if LNewR in [lbcBA, lbcHY, lbcNS, lbcCM, lbcZWJ, lbcIN] then
            { keep }
          else if IsU16Ortho(LRawCur) and
                  not (LNewR in [lbcQU, lbcGL, lbcWJ, lbcCL, lbcCP, lbcEX, lbcIS, lbcSY, lbcOP, lbcIN]) then
            LBrk := LB_BRK_ALLOW
          else if IsU16Ortho(LNew) and
                  not (LRawCur in [lbcBB, lbcGL, lbcWJ, lbcQU, lbcOP, lbcCL, lbcCP, lbcNS,
                                   lbcEX, lbcIS, lbcSY, lbcHY, lbcBA, lbcAK, lbcAS, lbcAP, lbcVI, lbcVF]) then
            LBrk := LB_BRK_ALLOW;
        end;
        if (LBrk = LB_BRK_NO) and IsU16Ortho(LRawCur) and
           (LNewR in [lbcPO, lbcPR, lbcAL, lbcHL, lbcNU, lbcEM, lbcEB, lbcRI, lbcH2, lbcH3]) then
          LBrk := LB_BRK_ALLOW;
        if not (LNew in [lbcVI, lbcCM, lbcZWJ, lbcAK, lbcAS]) then
          LFAfterOrthoVI := False;
      end;

      { LB8: ZW SP* ÷ before non-ZW }
      if (LLast = lbcSP) and (LCur = lbcZW) and (LNew <> lbcZW) then
        LBrk := LB_BRK_ALLOW
      else if (LCur = lbcZW) and not (LNew in [lbcSP, lbcZW]) then
        LBrk := LB_BRK_ALLOW;

      { LB21a: HL (HY|BA) × [^HL] — no break after Hebrew hyphen before non-HL }
      if LFHebrew and (LCur in [lbcHY, lbcBA]) and (LNewR <> lbcHL) then
        LBrk := LB_BRK_NO;

      { LB30b: EB × EM; [ExtPict & Cn] × EM }
      if (LNewR = lbcEM) and
         ((LCur = lbcEB) or
          ((GetGraphemeBreakProperty(LBaseCp) = gbpExtendedPictographic) and
           (GetGeneralCategory(LBaseCp) = gcuUnassigned))) then
        LBrk := LB_BRK_NO;

      { SY × NU often breaks (pair IND overridden) }
      if (LCur = lbcSY) and (LNewR = lbcNU) then
        LBrk := LB_BRK_ALLOW;


      { LB20a: word-initial hyphen (HY or U+2010 BA) × AL/AI }
      if (((LCur = lbcHY) or (LBaseCp = $2010)) and (LNewR in [lbcAL, lbcAI]) and LFHyInit) then
        LBrk := LB_BRK_NO;

      { LB15a: Pi&QU SP* ×  (no break after opening quote + spaces) }
      if (LCur = lbcQU) and IsPiQU(LBaseCp) and (LLast in [lbcSP, lbcXX]) then
        LBrk := LB_BRK_NO;

      { LB18 SP ÷ — after LB8 ZW SP* already handled }
      if (LLast = lbcSP) and (LCur <> lbcZW) then
      begin
        if LNewR in [lbcZW, lbcWJ, lbcSP] then
          LBrk := LB_BRK_NO
        else if LCur = lbcOP then
          LBrk := LB_BRK_NO { LB14 }
        else if (LCur = lbcQU) and IsPiQU(LBaseCp) then
          LBrk := LB_BRK_NO { LB15a }
        else if (LCur in [lbcCL, lbcCP]) and (LNewR = lbcNS) then
          LBrk := LB_BRK_NO { LB16 }
        else if (LCur = lbcB2) and (LNewR = lbcB2) then
          LBrk := LB_BRK_NO { LB17 }
        else if (LNewR = lbcIS) and (LI + 2 < LCount) and
                (ResolveLB(LCls[LI + 2]) = lbcNU) then
          LBrk := LB_BRK_ALLOW { LB15c SP ÷ IS NU }
        else if LNewR in [lbcCL, lbcCP, lbcEX, lbcIS, lbcSY] then
          LBrk := LB_BRK_NO { LB13 / LB15d }
        else if (LNew = lbcQU) and IsPfQU(LCh) then
          LBrk := LB_BRK_NO { LB15b }
        else
          LBrk := LB_BRK_ALLOW; { LB18 }
      end;

      { LB21a uses LFHebrew from prior HL; do not clear until after HY/BA×non-HL }
      if LCur = lbcHL then
        LFHebrew := True
      else if not (LCur in [lbcHY, lbcBA, lbcCM, lbcZWJ]) then
        LFHebrew := False;

      { LB30a: RI pairs only without intervening SP }
      if (LCur = lbcRI) and (LNewR = lbcRI) and (LLast <> lbcSP) then
      begin
        Inc(LRiCount);
        if (LRiCount mod 2) = 0 then
          LBrk := LB_BRK_ALLOW
        else
          LBrk := LB_BRK_NO;
      end
      else if not (LNew in [lbcCM, lbcZWJ]) and (LNewR <> lbcRI) then
        LRiCount := 0;

      if not LSkip then
      begin
        if (LCur = lbcHY) and not (LNewR in [lbcCM, lbcZWJ, lbcHY]) then
          LFHyInit := False;
        LCur := LNewR;
        if not (LNew in [lbcCM, lbcZWJ, lbcSP]) then
        begin
          LBaseCp := LCh;
          LRawCur := LNew; { raw class of new base }
        end;
        if LNewR = lbcHY then
          LFHyInit := LFHyInit or (LLast in [lbcXX, lbcSP, lbcZW, lbcGL, lbcBK]);
      end;
    end;

    LFZwj := LNew = lbcZWJ;
    LAfter[LI] := LBrk;
  end;

  LAfter[LCount - 1] := LB_BRK_MUST;

  for LI := 0 to LCount - 2 do
  begin
    if LAfter[LI] <> LB_BRK_NO then
      Exit(LByteEnds[LI]);
  end;
  Result := LByteEnds[LCount - 1];
end;

function TUnicodeSegmenter.NextWord(const AText: string; const APos: SizeInt): SizeInt;
var
  LLen: SizeInt;
  LBytes: SizeUInt;
begin
  LLen := Length(AText);
  if APos > LLen then
    Exit(APos);
  if APos < 1 then
    Exit(APos);
  LBytes := WordBreakByteLen(@AText[APos], SizeUInt(LLen - APos + 1));
  if LBytes = 0 then
    Exit(APos); { safety }
  Result := APos + SizeInt(LBytes);
end;

function TUnicodeSegmenter.NextLine(const AText: string; const APos: SizeInt): SizeInt;
var
  LLen: SizeInt;
  LCodepoint: TUnicodeCodepoint;
  LDecode: TUTF8DecodeResult;
begin
  LLen := Length(AText);
  if APos > LLen then
  begin
    Result := APos;
    Exit;
  end;

  // 查找行分隔符
  Result := APos;
  while Result <= LLen do
  begin
    // 解码 UTF-8 字符
    LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
    if LDecode.ByteLen = 0 then
    begin
      // 无效的 UTF-8 序列，跳过一个字节
      Inc(Result);
      Continue;
    end;
    LCodepoint := LDecode.CodePoint;

    // 检查行分隔符
    case LCodepoint of
      $000A: // LF
      begin
        Inc(Result, LDecode.ByteLen);
        Break;
      end;
      $000D: // CR
      begin
        Inc(Result, LDecode.ByteLen);
        // 检查 CRLF
        if (Result <= LLen) then
        begin
          LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
          if (LDecode.ByteLen > 0) and (LDecode.CodePoint = $000A) then
            Inc(Result, LDecode.ByteLen);
        end;
        Break;
      end;
      $0085: // NEL
      begin
        Inc(Result, LDecode.ByteLen);
        Break;
      end;
      $2028: // LS
      begin
        Inc(Result, LDecode.ByteLen);
        Break;
      end;
      $2029: // PS
      begin
        Inc(Result, LDecode.ByteLen);
        Break;
      end;
    else
      Inc(Result, LDecode.ByteLen);
    end;
  end;
end;

function TUnicodeSegmenter.NextSentence(const AText: string; const APos: SizeInt): SizeInt;
var
  LLen: SizeInt;
  LBytes: SizeUInt;
begin
  LLen := Length(AText);
  if APos > LLen then
    Exit(APos);
  if APos < 1 then
    Exit(APos);
  LBytes := SentenceBreakByteLen(@AText[APos], SizeUInt(LLen - APos + 1));
  if LBytes = 0 then
    Exit(APos);
  Result := APos + SizeInt(LBytes);
end;

initialization
  InitCriticalSection(FSegmenterCS);

finalization
  DoneCriticalSection(FSegmenterCS);

end.
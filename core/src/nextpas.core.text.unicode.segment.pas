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
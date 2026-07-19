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

  // 预分配空间
  LCapacity := LLen div 4 + 1;
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
    end;
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

function IsCJKIdeograph(const ACp: TUnicodeCodepoint): Boolean; inline;
begin
  // CJK Unified Ideographs + Extension A + Compatibility Ideographs
  Result := ((ACp >= $4E00) and (ACp <= $9FFF)) or
            ((ACp >= $3400) and (ACp <= $4DBF)) or
            ((ACp >= $F900) and (ACp <= $FAFF));
end;

function TUnicodeSegmenter.NextWord(const AText: string; const APos: SizeInt): SizeInt;
var
  LLen: SizeInt;
  LCodepoint: TUnicodeCodepoint;
  LCategory: TGeneralCategory;
  LInWord: Boolean;
  LDecode: TUTF8DecodeResult;
begin
  LLen := Length(AText);
  if APos > LLen then
  begin
    Result := APos;
    Exit;
  end;

  // 跳过非单词字符
  Result := APos;
  LInWord := False;
  while Result <= LLen do
  begin
    // 解码 UTF-8 字符
    LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
    if LDecode.ByteLen = 0 then
    begin
      // 无效的 UTF-8 序列，跳过一个字节
      if LInWord then
        Break;
      Inc(Result);
      Continue;
    end;
    LCodepoint := LDecode.CodePoint;
    LCategory := GetGeneralCategory(LCodepoint);

    // 判断是否是单词字符
    if IsCJKIdeograph(LCodepoint) then
    begin
      // CJK 表意文字：每个字符是独立的词
      if LInWord then
        Break; // 前面的非 CJK 词结束
      // CJK 字符本身就是一个词
      Inc(Result, LDecode.ByteLen);
      Break;
    end
    else if LCategory in [gcuUppercaseLetter, gcuLowercaseLetter, gcuTitlecaseLetter,
                     gcuModifierLetter, gcuOtherLetter, gcuDecimalNumber,
                     gcuConnectorPunctuation, gcuOtherNumber] then
    begin
      if not LInWord then
        LInWord := True;
    end
    else if LCategory = gcuNonspacingMark then
    begin
      // 组合标记可以是单词的一部分（如重音符号）
      if not LInWord then
        LInWord := True;
    end
    else if (LCategory = gcuDashPunctuation) and LInWord then
    begin
      // 连字符可以是单词的一部分（如 "well-known"）
      // 但需要检查下一个字符是否是字母
      Inc(Result, LDecode.ByteLen);
      // 如果连字符后面不是字母，则单词在此结束
      if Result <= LLen then
      begin
        LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
        if LDecode.ByteLen = 0 then
          Break;
        LCodepoint := LDecode.CodePoint;
        LCategory := GetGeneralCategory(LCodepoint);
        if not (LCategory in [gcuUppercaseLetter, gcuLowercaseLetter, gcuTitlecaseLetter,
                             gcuModifierLetter, gcuOtherLetter]) then
          Break;
      end;
      Continue;
    end
    else
    begin
      if LInWord then
        Break;
    end;

    Inc(Result, LDecode.ByteLen);
  end;
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
  LCodepoint: TUnicodeCodepoint;
  LInSentence: Boolean;
  LDecode: TUTF8DecodeResult;
begin
  LLen := Length(AText);
  if APos > LLen then
  begin
    Result := APos;
    Exit;
  end;

  // 基于 UAX #29 简化实现：查找句子结束符
  Result := APos;
  LInSentence := False;
  while Result <= LLen do
  begin
    // 解码 UTF-8 字符
    LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
    if LDecode.ByteLen = 0 then
    begin
      // 无效的 UTF-8 序列，跳过一个字节
      if LInSentence then
        Break;
      Inc(Result);
      Continue;
    end;
    LCodepoint := LDecode.CodePoint;

    // 检查句子结束符（ASCII + CJK + 其他 Unicode 终止符）
    case LCodepoint of
      $002E, // .
      $003F, // ?
      $0021, // !
      $3002, // 。 IDEOGRAPHIC FULL STOP
      $FF01, // ！ FULLWIDTH EXCLAMATION MARK
      $FF0E, // ． FULLWIDTH FULL STOP
      $FF1F, // ？ FULLWIDTH QUESTION MARK
      $2026, // … HORIZONTAL ELLIPSIS
      $FE12, // ︒ PRESENTATION FORM FOR VERTICAL IDEOGRAPHIC FULL STOP
      $FE15, // ︕ PRESENTATION FORM FOR VERTICAL EXCLAMATION MARK
      $FE16, // ︖ PRESENTATION FORM FOR VERTICAL QUESTION MARK
      $FE52, // ﹒ SMALL FULL STOP
      $FE57, // ﹇ SMALL EXCLAMATION MARK
      $FE5F: // ﹟ SMALL NUMBER SIGN
      begin
        Inc(Result, LDecode.ByteLen);
        LInSentence := True;
        // 跳过连续句子终止符（如 ... ?! !? 等）
        while Result <= LLen do
        begin
          LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
          if LDecode.ByteLen = 0 then
            Break;
          LCodepoint := LDecode.CodePoint;
          case LCodepoint of
            $002E, $003F, $0021, $3002, $FF01, $FF0E, $FF1F,
            $2026, $FE12, $FE15, $FE16, $FE52, $FE57, $FE5F:
              Inc(Result, LDecode.ByteLen);
          else
            Break;
          end;
        end;
        // 遇到句子结束符后，跳过结尾引号/括号再停止
        while Result <= LLen do
        begin
          LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
          if LDecode.ByteLen = 0 then
            Break;
          LCodepoint := LDecode.CodePoint;
          // 跳过结尾标点：引号、括号等
          case LCodepoint of
            $0022, // "
            $0027, // '
            $0029, // )
            $005D, // ]
            $007D, // }
            $FF07, // ＇ FULLWIDTH APOSTROPHE
            $FF09, // ） FULLWIDTH RIGHT PARENTHESIS
            $300D, // 」 RIGHT CORNER BRACKET
            $300F, // 』 RIGHT WHITE CORNER BRACKET
            $3011, // 】 RIGHT BLACK LENTICULAR BRACKET
            $2019, // ' RIGHT SINGLE QUOTATION MARK
            $201D: // " RIGHT DOUBLE QUOTATION MARK
              Inc(Result, LDecode.ByteLen);
          else
            Break;
          end;
        end;
        Break;
      end;
      $000A, // LF
      $000D, // CR
      $0085, // NEL
      $2028, // LS
      $2029: // PS
      begin
        if LInSentence then
          Break;
        Inc(Result, LDecode.ByteLen);
      end;
    else
      Inc(Result, LDecode.ByteLen);
    end;
  end;
end;

initialization
  InitCriticalSection(FSegmenterCS);

finalization
  DoneCriticalSection(FSegmenterCS);

end.
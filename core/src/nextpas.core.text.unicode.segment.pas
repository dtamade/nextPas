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

function TUnicodeSegmenter.NextGraphemeCluster(const AText: string; const APos: SizeInt): SizeInt;
{**
 * UAX #29 Grapheme Cluster Boundary algorithm (Unicode 16.0).
 *
 * Rules implemented:
 *   GB1:  sot ÷
 *   GB3:  CR × LF
 *   GB4:  (Control|CR|LF) ÷
 *   GB5:  ÷ (Control|CR|LF)
 *   GB6:  L × (L|V|LV|LVT)
 *   GB7:  (V|LV) × (V|T)
 *   GB8:  (LVT|T) × T
 *   GB9:  × (Extend|ZWJ)
 *   GB9a: × SpacingMark
 *   GB9b: Prepend ×
 *   GB11: \p{Extended_Pictographic} Extend* ZWJ × \p{Extended_Pictographic}
 *   GB12: sot (RI RI)* RI × RI
 *   GB13: [^RI] (RI RI)* RI × RI
 *   GB999: ÷
 *}
var
  LLen: SizeInt;
  LPos: SizeInt;
  LCurGcb: TGraphemeBreakProperty;
  LDecode: TUTF8DecodeResult;
  LAheadPos: SizeInt;
  LAheadGcb: TGraphemeBreakProperty;
  LAheadDecode: TUTF8DecodeResult;
  LRICount: SizeInt;
begin
  LLen := Length(AText);
  if APos > LLen then
    Exit(APos);

  // Decode first codepoint
  LDecode := UTF8Decode(@AText[APos], LLen - APos + 1);
  if LDecode.ByteLen = 0 then
    Exit(APos + 1); // Invalid UTF-8

  LPos := APos + LDecode.ByteLen;
  LCurGcb := GetGraphemeBreakProperty(LDecode.CodePoint);

  // GB4: (Control | CR | LF) ÷ — always isolated
  if LCurGcb in [gbpCR, gbpLF, gbpControl] then
  begin
    // GB3: CR × LF
    if (LCurGcb = gbpCR) and (LPos <= LLen) then
    begin
      LAheadDecode := UTF8Decode(@AText[LPos], LLen - LPos + 1);
      if (LAheadDecode.ByteLen > 0) and (GetGraphemeBreakProperty(LAheadDecode.CodePoint) = gbpLF) then
        Exit(LPos + LAheadDecode.ByteLen);
    end;
    Exit(LPos);
  end;

  // Track RI pairs: count consecutive RI characters
  if LCurGcb = gbpRegionalIndicator then
    LRICount := 1
  else
    LRICount := 0;

  // Main loop: try to extend the cluster
  while LPos <= LLen do
  begin
    LAheadDecode := UTF8Decode(@AText[LPos], LLen - LPos + 1);
    if LAheadDecode.ByteLen = 0 then
      Break;
    LAheadGcb := GetGraphemeBreakProperty(LAheadDecode.CodePoint);
    LAheadPos := LPos + LAheadDecode.ByteLen;

    // GB4: ÷ (Control | CR | LF)
    if LAheadGcb in [gbpCR, gbpLF, gbpControl] then
      Break;

    // GB11: EP Extend* ZWJ × EP — must be checked BEFORE GB9
    // If current is EP and next is ZWJ, look past ZWJ for EP
    if (LCurGcb = gbpExtendedPictographic) and (LAheadGcb = gbpZWJ) then
    begin
      if LAheadPos <= LLen then
      begin
        LAheadDecode := UTF8Decode(@AText[LAheadPos], LLen - LAheadPos + 1);
        if (LAheadDecode.ByteLen > 0) and
           (GetGraphemeBreakProperty(LAheadDecode.CodePoint) = gbpExtendedPictographic) then
        begin
          // Consume both ZWJ and the following EP
          LCurGcb := gbpExtendedPictographic;
          LRICount := 0;
          LPos := LAheadPos + LAheadDecode.ByteLen;
          Continue;
        end;
      end;
    end;

    // GB9: × (Extend | ZWJ) — after GB11 check
    if LAheadGcb in [gbpExtend, gbpZWJ] then
    begin
      LPos := LAheadPos;
      Continue;
    end;

    // GB9a: × SpacingMark
    if LAheadGcb = gbpSpacingMark then
    begin
      LPos := LAheadPos;
      Continue;
    end;

    // GB9b: Prepend ×
    if LCurGcb = gbpPrepend then
    begin
      LCurGcb := LAheadGcb;
      if LAheadGcb = gbpRegionalIndicator then
        LRICount := 1
      else
        LRICount := 0;
      LPos := LAheadPos;
      Continue;
    end;

    // GB6: L × (L | V | LV | LVT)
    if (LCurGcb = gbpL) and (LAheadGcb in [gbpL, gbpV, gbpLV, gbpLVT]) then
    begin
      LCurGcb := LAheadGcb;
      LRICount := 0;
      LPos := LAheadPos;
      Continue;
    end;

    // GB7: (V | LV) × (V | T)
    if (LCurGcb in [gbpV, gbpLV]) and (LAheadGcb in [gbpV, gbpT]) then
    begin
      LCurGcb := LAheadGcb;
      LRICount := 0;
      LPos := LAheadPos;
      Continue;
    end;

    // GB8: (LVT | T) × T
    if (LCurGcb in [gbpLVT, gbpT]) and (LAheadGcb = gbpT) then
    begin
      LCurGcb := gbpT;
      LRICount := 0;
      LPos := LAheadPos;
      Continue;
    end;

    // GB12-13: Regional Indicator pairs
    if (LCurGcb = gbpRegionalIndicator) and (LAheadGcb = gbpRegionalIndicator) then
    begin
      Inc(LRICount);
      // GB12/13: even count → no break (pair forming), odd → break (pair complete)
      // LRICount=2 means we have 2 RIs = 1 pair → no break
      // LRICount=3 means we have 3 RIs = 1 pair + 1 extra → break before 3rd
      if LRICount mod 2 = 1 then
        Break;
      LCurGcb := gbpRegionalIndicator;
      LPos := LAheadPos;
      Continue;
    end;

    // GB999: ÷ Any — default break
    Break;
  end;

  Result := LPos;
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
  LPrevCategory: TGeneralCategory;
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
  LPrevCategory := gcuUnassigned;
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
      LPrevCategory := LCategory;
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

    LPrevCategory := LCategory;
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
        // 跳过连续相同的句子终止符（如 ... 三个句号）
        while Result <= LLen do
        begin
          LDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
          if (LDecode.ByteLen = 0) or (LDecode.CodePoint <> LCodepoint) then
            Break;
          Inc(Result, LDecode.ByteLen);
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
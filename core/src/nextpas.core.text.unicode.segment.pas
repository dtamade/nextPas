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

function UnicodeSegmenter: IUnicodeSegmenter;
begin
  if FUnicodeSegmenter = nil then
    FUnicodeSegmenter := TUnicodeSegmenter.Create;
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
var
  LLen: SizeInt;
  LCodepoint, LNextCodepoint: TUnicodeCodepoint;
  LCategory, LNextCategory: TGeneralCategory;
  LDecode, LNextDecode: TUTF8DecodeResult;
begin
  LLen := Length(AText);
  if APos > LLen then
  begin
    Result := APos;
    Exit;
  end;

  // 解码第一个字符
  LDecode := UTF8Decode(@AText[APos], LLen - APos + 1);
  if LDecode.ByteLen = 0 then
  begin
    // 无效的 UTF-8 序列，跳过一个字节
    Result := APos + 1;
    Exit;
  end;
  LCodepoint := LDecode.CodePoint;
  Result := APos + LDecode.ByteLen;

  // CR+LF 应该是单个字素簇
  if (LCodepoint = $000D) and (Result <= LLen) then
  begin
    LNextDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
    if (LNextDecode.ByteLen > 0) and (LNextDecode.CodePoint = $000A) then
    begin
      Result := Result + LNextDecode.ByteLen;
      Exit;
    end;
  end;

  // 跳过组合标记（Extend 和 SpacingMark）
  while Result <= LLen do
  begin
    LNextDecode := UTF8Decode(@AText[Result], LLen - Result + 1);
    if LNextDecode.ByteLen = 0 then
      Break;
    LNextCodepoint := LNextDecode.CodePoint;
    LNextCategory := GetGeneralCategory(LNextCodepoint);

    // 只有 Extend (NonspacingMark) 和 SpacingMark 才继续组合
    if not (LNextCategory in [gcuNonspacingMark, gcuSpacingMark]) then
      Break;

    Inc(Result, LNextDecode.ByteLen);
  end;
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
    if LCategory in [gcuUppercaseLetter, gcuLowercaseLetter, gcuTitlecaseLetter,
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

  // 如果以连字符结尾，回退一个字符
  if LInWord and (LPrevCategory = gcuDashPunctuation) then
  begin
    // 需要回退一个字符
    // 这里简化处理，实际应该记录位置
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
  LCategory: TGeneralCategory;
  LInSentence: Boolean;
  LDecode: TUTF8DecodeResult;
begin
  LLen := Length(AText);
  if APos > LLen then
  begin
    Result := APos;
    Exit;
  end;

  // 简单实现：查找句子结束符
  Result := APos;
  LInSentence := False;
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
    LCategory := GetGeneralCategory(LCodepoint);

    // 检查句子结束符
    case LCodepoint of
      $002E, // .
      $003F, // ?
      $0021: // !
      begin
        Inc(Result, LDecode.ByteLen);
        LInSentence := True;
        // 遇到句子结束符后停止
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

end.
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
  LPos, LStart, LLen: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(LResults, 0);
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextGraphemeCluster(AText, LPos);
    SetLength(LResults, Length(LResults) + 1);
    LResults[High(LResults)].Start := LStart;
    LResults[High(LResults)].Length := LPos - LStart;
    LResults[High(LResults)].SegmentType := stGraphemeCluster;
  end;

  Result := LResults;
end;

function TUnicodeSegmenter.SegmentWords(const AText: string): TSegmentResultArray;
var
  LPos, LStart, LLen: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(LResults, 0);
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextWord(AText, LPos);
    if LPos > LStart then
    begin
      SetLength(LResults, Length(LResults) + 1);
      LResults[High(LResults)].Start := LStart;
      LResults[High(LResults)].Length := LPos - LStart;
      LResults[High(LResults)].SegmentType := stWord;
    end;
  end;

  Result := LResults;
end;

function TUnicodeSegmenter.SegmentLines(const AText: string): TSegmentResultArray;
var
  LPos, LStart, LLen: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(LResults, 0);
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextLine(AText, LPos);
    SetLength(LResults, Length(LResults) + 1);
    LResults[High(LResults)].Start := LStart;
    LResults[High(LResults)].Length := LPos - LStart;
    LResults[High(LResults)].SegmentType := stLine;
  end;

  Result := LResults;
end;

function TUnicodeSegmenter.SegmentSentences(const AText: string): TSegmentResultArray;
var
  LPos, LStart, LLen: SizeInt;
  LResults: TSegmentResultArray;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(LResults, 0);
  LPos := 1;
  while LPos <= LLen do
  begin
    LStart := LPos;
    LPos := NextSentence(AText, LPos);
    SetLength(LResults, Length(LResults) + 1);
    LResults[High(LResults)].Start := LStart;
    LResults[High(LResults)].Length := LPos - LStart;
    LResults[High(LResults)].SegmentType := stSentence;
  end;

  Result := LResults;
end;

function TUnicodeSegmenter.NextGraphemeCluster(const AText: string; const APos: SizeInt): SizeInt;
var
  LLen: SizeInt;
  LCodepoint: TUnicodeCodepoint;
  LCategory: TGeneralCategory;
  LDecode: TUTF8DecodeResult;
begin
  LLen := Length(AText);
  if APos > LLen then
  begin
    Result := APos;
    Exit;
  end;

  // 简单实现：跳过组合标记
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
    LCategory := GetGeneralCategory(LCodepoint);

    // 如果不是组合标记，停止
    if not (LCategory in [gcuNonspacingMark, gcuSpacingMark, gcuEnclosingMark]) then
    begin
      Inc(Result, LDecode.ByteLen);
      Break;
    end;

    Inc(Result, LDecode.ByteLen);
  end;
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
      Inc(Result);
      Continue;
    end;
    LCodepoint := LDecode.CodePoint;
    LCategory := GetGeneralCategory(LCodepoint);

    // 判断是否是单词字符
    if LCategory in [gcuUppercaseLetter, gcuLowercaseLetter, gcuTitlecaseLetter,
                     gcuModifierLetter, gcuOtherLetter, gcuDecimalNumber,
                     gcuConnectorPunctuation] then
    begin
      if not LInWord then
        LInWord := True;
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
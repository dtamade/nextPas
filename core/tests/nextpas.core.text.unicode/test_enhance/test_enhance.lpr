program test_unicode_enhance;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

procedure TestScriptProperties;
begin
  // 测试 Script 属性
  CheckEqual(Int64(Ord(usLatin)), Int64(Ord(GetScript(Ord('A')))), 'A is Latin');
  CheckEqual(Int64(Ord(usLatin)), Int64(Ord(GetScript(Ord('a')))), 'a is Latin');
  CheckEqual(Int64(Ord(usCommon)), Int64(Ord(GetScript(Ord('0')))), '0 is Common');
  CheckEqual(Int64(Ord(usCommon)), Int64(Ord(GetScript(Ord(' ')))), 'space is Common');
  Check(IsScript(Ord('A'), usLatin), 'A is Latin script');
  Check(not IsScript(Ord('A'), usGreek), 'A is not Greek script');

  // 测试其他 Script
  CheckEqual(Int64(Ord(usGreek)), Int64(Ord(GetScript($0391))), 'Alpha is Greek');  // Α
  CheckEqual(Int64(Ord(usCyrillic)), Int64(Ord(GetScript($0410))), 'A is Cyrillic');  // А
  CheckEqual(Int64(Ord(usHan)), Int64(Ord(GetScript($4E2D))), '中 is Han');  // 中
end;

procedure TestBlockProperties;
begin
  // 测试 Block 属性
  CheckEqual(Int64(Ord(ubBasicLatin)), Int64(Ord(GetBlock(Ord('A')))), 'A is Basic Latin');
  CheckEqual(Int64(Ord(ubBasicLatin)), Int64(Ord(GetBlock(Ord('a')))), 'a is Basic Latin');
  CheckEqual(Int64(Ord(ubBasicLatin)), Int64(Ord(GetBlock(Ord('0')))), '0 is Basic Latin');
  Check(IsBlock(Ord('A'), ubBasicLatin), 'A is Basic Latin block');
  Check(not IsBlock(Ord('A'), ubLatinExtendedA), 'A is not Latin Extended-A block');

  // 测试其他 Block
  CheckEqual(Int64(Ord(ubGreekAndCoptic)), Int64(Ord(GetBlock($0391))), 'Alpha is Greek and Coptic');  // Α
  CheckEqual(Int64(Ord(ubCyrillic)), Int64(Ord(GetBlock($0410))), 'A is Cyrillic');  // А
  CheckEqual(Int64(Ord(ubCJKUnifiedIdeographs)), Int64(Ord(GetBlock($4E2D))), '中 is CJK Unified Ideographs');  // 中
end;

procedure TestSegmentation;
var
  LResults: TSegmentResultArray;
begin
  // 测试文本分割
  LResults := SegmentGraphemeClusters('Hello');
  CheckEqual(Int64(5), Int64(Length(LResults)), 'Hello has 5 grapheme clusters');

  // 测试 CR+LF 应该是单个字素簇
  LResults := SegmentGraphemeClusters('Line1' + #13#10 + 'Line2');
  CheckEqual(Int64(11), Int64(Length(LResults)), 'CR+LF is single grapheme cluster');

  // 测试组合字符（如重音符号）
  LResults := SegmentGraphemeClusters('café');  // é 可能是组合形式
  Check(LResults[3].Length >= 2, 'Combining mark attached to base character');

  LResults := SegmentWords('Hello World');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Hello World has 2 words');

  // 测试连字符单词
  LResults := SegmentWords('well-known');
  CheckEqual(Int64(1), Int64(Length(LResults)), 'well-known is one word');

  // 测试带数字的单词
  LResults := SegmentWords('test123');
  CheckEqual(Int64(1), Int64(Length(LResults)), 'test123 is one word');

  LResults := SegmentLines('Line1' + #10 + 'Line2');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Two lines');

  // 测试多种行分隔符
  LResults := SegmentLines('Line1' + #13 + 'Line2' + #13#10 + 'Line3');
  CheckEqual(Int64(3), Int64(Length(LResults)), 'Three lines with CR and CRLF');

  LResults := SegmentSentences('Hello. World!');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Two sentences');

  // 测试 CJK 句子结束符
  LResults := SegmentSentences('你好。世界！');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Two CJK sentences');

  // 测试句子后的引号
  LResults := SegmentSentences('He said "Hello." She replied.');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Sentence with closing quote');

  // 测试省略号（U+2026 HORIZONTAL ELLIPSIS）
  LResults := SegmentSentences('Wait' + #$E2#$80#$A6 + ' Really?');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Ellipsis + question');

  // 测试全角句号
  LResults := SegmentSentences('你好．世界！');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Fullwidth period + fullwidth excl');

  // 测试 CJK 单词分割（每个表意文字是独立的词）
  LResults := SegmentWords('你好世界');
  CheckEqual(Int64(4), Int64(Length(LResults)), 'CJK: 4 separate words');
  CheckEqual(Int64(3), Int64(LResults[0].Length), 'CJK: each word is 3 bytes (UTF-8)');
  CheckEqual(Int64(3), Int64(LResults[1].Length), 'CJK: each word is 3 bytes (UTF-8)');

  // 测试中英混合
  LResults := SegmentWords('Hello你好World');
  CheckEqual(Int64(4), Int64(Length(LResults)), 'Mixed: Hello + 你 + 好 + World = 4 words');
end;

procedure TestCollation;
var
  LCollator: IUnicodeCollator;
begin
  // 测试排序规则
  LCollator := UnicodeCollator;

  Check(LCollator.Compare('a', 'b') < 0, 'a < b');
  Check(LCollator.Compare('b', 'a') > 0, 'b > a');
  Check(LCollator.Compare('a', 'a') = 0, 'a = a');
  Check(LCollator.Equals('a', 'a'), 'a equals a');
  Check(not LCollator.Equals('a', 'b'), 'a not equals b');
  Check(LCollator.StartsWith('Hello', 'He'), 'Hello starts with He');
  Check(not LCollator.StartsWith('Hello', 'Wo'), 'Hello not starts with Wo');
  Check(LCollator.EndsWith('Hello', 'lo'), 'Hello ends with lo');
  Check(not LCollator.EndsWith('Hello', 'He'), 'Hello not ends with He');
  Check(LCollator.Contains('Hello World', 'World'), 'Hello World contains World');
  Check(not LCollator.Contains('Hello World', 'xyz'), 'Hello World not contains xyz');
  CheckEqual(Int64(7), Int64(LCollator.IndexOf('Hello World', 'World')), 'World at position 7');
end;

procedure TestEnhancedProperties;
begin
  // 测试增强的属性查询
  Check(IsUpper(Ord('A')), 'A is uppercase');
  Check(IsLower(Ord('a')), 'a is lowercase');
  Check(IsAlpha(Ord('Z')), 'Z is alpha');
  Check(IsDigit(Ord('9')), '9 is digit');
  Check(IsWhitespace(Ord(' ')), 'space is whitespace');
  Check(IsLetter(Ord('Q')), 'Q is letter');
  Check(not IsLetter(Ord('9')), '9 is not letter');
end;

procedure TestConvenienceFunctions;
var
  LArr: array[0..4] of string;
begin
  // CompareText
  Check(CompareText('a', 'b') < 0, 'CompareText a < b');
  Check(CompareText('b', 'a') > 0, 'CompareText b > a');
  CheckEqual(CompareText('hello', 'hello'), 0, 'CompareText equal');

  // GetSortKey
  Check(Length(GetSortKey('A')) > 0, 'GetSortKey non-empty');
  CheckEqual(Length(GetSortKey('')), 0, 'GetSortKey empty');

  // SortStrings
  LArr[0] := 'cherry';
  LArr[1] := 'apple';
  LArr[2] := 'banana';
  LArr[3] := 'date';
  LArr[4] := 'elderberry';
  SortStrings(LArr);
  CheckEqual(LArr[0], 'apple', 'SortStrings [0]');
  CheckEqual(LArr[1], 'banana', 'SortStrings [1]');
  CheckEqual(LArr[2], 'cherry', 'SortStrings [2]');
  CheckEqual(LArr[3], 'date', 'SortStrings [3]');
  CheckEqual(LArr[4], 'elderberry', 'SortStrings [4]');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.enhance');
  T.Test('Script properties', @TestScriptProperties);
  T.Test('Block properties', @TestBlockProperties);
  T.Test('text segmentation', @TestSegmentation);
  T.Test('collation', @TestCollation);
  T.Test('enhanced properties', @TestEnhancedProperties);
  T.Test('convenience functions', @TestConvenienceFunctions);
  if not T.Run then Halt(1);
end.
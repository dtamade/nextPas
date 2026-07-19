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
  { UAX#29: Hello | space | World }
  CheckEqual(Int64(3), Int64(Length(LResults)), 'Hello World has 3 word segments');

  // U+002D HYPHEN-MINUS 在 Word_Break 中为 Other → well | - | known
  LResults := SegmentWords('well-known');
  CheckEqual(Int64(3), Int64(Length(LResults)), 'well-known splits on ASCII hyphen (Other)');

  // 测试带数字的单词 (AHLetter × Numeric)
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

  // 测试省略号（U+2026 HORIZONTAL ELLIPSIS）— 非 STerm/ATerm，不强制断句
  LResults := SegmentSentences('Wait' + #$E2#$80#$A6 + ' Really?');
  CheckEqual(Int64(1), Int64(Length(LResults)), 'Ellipsis alone does not break sentence (UAX#29)');

  // 测试全角句号
  LResults := SegmentSentences('你好．世界！');
  CheckEqual(Int64(2), Int64(Length(LResults)), 'Fullwidth period + fullwidth excl');

  // 测试 ?! 序列合并为一个句子
  LResults := SegmentSentences('Really?! Yes.');
  CheckEqual(Int64(2), Int64(Length(LResults)), '?! merged as one sentence');

  // 测试 !? 序列
  LResults := SegmentSentences('No way!? Indeed.');
  CheckEqual(Int64(2), Int64(Length(LResults)), '!? merged as one sentence');

  // 测试 ... 后跟 ?!
  LResults := SegmentSentences('Wait... Really?! OK.');
  CheckEqual(Int64(3), Int64(Length(LResults)), '... then ?! then period');

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
  Check(LCollator.TextEquals('a', 'a'), 'a equals a');
  Check(not LCollator.TextEquals('a', 'b'), 'a not equals b');
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

procedure TestNextAPIs;
var
  LSeg: IUnicodeSegmenter;
  LPos: SizeInt;
begin
  LSeg := UnicodeSegmenter;

  // NextGraphemeCluster: 从头开始
  LPos := LSeg.NextGraphemeCluster('Hello', 1);
  CheckEqual(Int64(2), Int64(LPos), 'NextGraphemeCluster H→e');

  // NextGraphemeCluster: 从中间开始
  LPos := LSeg.NextGraphemeCluster('Hello', 3);
  CheckEqual(Int64(4), Int64(LPos), 'NextGraphemeCluster l→l (mid)');

  // NextGraphemeCluster: 最后一个字符返回 len+1
  LPos := LSeg.NextGraphemeCluster('Hello', 5);
  CheckEqual(Int64(6), Int64(LPos), 'NextGraphemeCluster o→end');

  // NextWord: 从头开始 — 第一词段 "Hello"
  LPos := LSeg.NextWord('Hello World', 1);
  CheckEqual(Int64(6), Int64(LPos), 'NextWord Hello ends at space');

  // NextWord: 从空格开始 — 空格本身是一段
  LPos := LSeg.NextWord('Hello World', 6);
  CheckEqual(Int64(7), Int64(LPos), 'NextWord space is its own segment');

  // NextLine: 从头开始 — LF 后是 Line2 的第一个字符
  LPos := LSeg.NextLine('Line1' + #10 + 'Line2', 1);
  Check(LPos > 5, 'NextLine advances past LF');

  // NextSentence: 从头开始
  LPos := LSeg.NextSentence('Hello. World!', 1);
  Check(LPos > 1, 'NextSentence advances past period');
end;

procedure TestWordBoundaries;
var
  LResults: TSegmentResultArray;
begin
  // 数字与单词边界
  LResults := SegmentWords('v2.0 release');
  Check(Length(LResults) >= 2, 'v2.0 splits at dot boundary');

  // 标点与 CJK 边界
  LResults := SegmentWords('你好,世界');
  Check(Length(LResults) >= 3, 'CJK comma splits into multiple segments');

  // 纯标点
  LResults := SegmentWords('...');
  Check(Length(LResults) >= 1, 'Punctuation produces word segments');

  // 空字符串
  LResults := SegmentWords('');
  CheckEqual(Int64(0), Int64(Length(LResults)), 'Empty string has no words');

  // 纯空格 — WSegSpace × WSegSpace → 单段
  LResults := SegmentWords('   ');
  CheckEqual(Int64(1), Int64(Length(LResults)), 'Spaces glue as one WSegSpace run');

  // 连字符后跟数字 — 可能拆分为多段
  LResults := SegmentWords('test-123');
  Check(Length(LResults) >= 1, 'test-123 produces word segments');

  // 混合数字和字母
  LResults := SegmentWords('abc123def');
  CheckEqual(Int64(1), Int64(Length(LResults)), 'abc123def is one word');

  // CJK 标点（全角逗号）— 标点作为独立段
  LResults := SegmentWords('你好，世界');
  Check(Length(LResults) >= 3, 'Fullwidth comma splits CJK into segments');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.enhance');
  T.Test('Script properties', @TestScriptProperties);
  T.Test('Block properties', @TestBlockProperties);
  T.Test('text segmentation', @TestSegmentation);
  T.Test('collation', @TestCollation);
  T.Test('enhanced properties', @TestEnhancedProperties);
  T.Test('convenience functions', @TestConvenienceFunctions);
  T.Test('Next* standalone APIs', @TestNextAPIs);
  T.Test('word segmentation boundaries', @TestWordBoundaries);
  if not T.Run then Halt(1);
end.
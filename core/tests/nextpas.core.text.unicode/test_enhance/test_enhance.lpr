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
end;

procedure TestBlockProperties;
begin
  // 测试 Block 属性
  CheckEqual(Int64(Ord(ubBasicLatin)), Int64(Ord(GetBlock(Ord('A')))), 'A is Basic Latin');
  CheckEqual(Int64(Ord(ubBasicLatin)), Int64(Ord(GetBlock(Ord('a')))), 'a is Basic Latin');
  CheckEqual(Int64(Ord(ubBasicLatin)), Int64(Ord(GetBlock(Ord('0')))), '0 is Basic Latin');
  Check(IsBlock(Ord('A'), ubBasicLatin), 'A is Basic Latin block');
  Check(not IsBlock(Ord('A'), ubLatinExtendedA), 'A is not Latin Extended-A block');
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

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.enhance');
  T.Test('Script properties', @TestScriptProperties);
  T.Test('Block properties', @TestBlockProperties);
  T.Test('text segmentation', @TestSegmentation);
  T.Test('collation', @TestCollation);
  T.Test('enhanced properties', @TestEnhancedProperties);
  if not T.Run then Halt(1);
end.
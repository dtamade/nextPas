program test_unicode_data;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode.data,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

procedure TestDataManagerGeneralCategory;
var
  LManager: IUnicodeDataManager;
begin
  LManager := UnicodeData;

  // 基本 ASCII
  CheckEqual(Int64(Ord(gcuUppercaseLetter)), Int64(Ord(LManager.GetGeneralCategory(Ord('A')))), 'A is Lu');
  CheckEqual(Int64(Ord(gcuLowercaseLetter)), Int64(Ord(LManager.GetGeneralCategory(Ord('a')))), 'a is Ll');
  CheckEqual(Int64(Ord(gcuDecimalNumber)), Int64(Ord(LManager.GetGeneralCategory(Ord('0')))), '0 is Nd');
  CheckEqual(Int64(Ord(gcuSpaceSeparator)), Int64(Ord(LManager.GetGeneralCategory(Ord(' ')))), 'space is Zs');

  // CJK
  CheckEqual(Int64(Ord(gcuOtherLetter)), Int64(Ord(LManager.GetGeneralCategory($4E2D))), '中 is Lo');

  // SMP (Musical Symbol)
  CheckEqual(Int64(Ord(gcuOtherSymbol)), Int64(Ord(LManager.GetGeneralCategory($1D11E))), '𝄞 is So');
end;

procedure TestDataManagerBinaryProperty;
var
  LManager: IUnicodeDataManager;
begin
  LManager := UnicodeData;

  Check(LManager.GetBinaryProperty(Ord('A'), ubpUppercase), 'A has Uppercase');
  Check(not LManager.GetBinaryProperty(Ord('a'), ubpUppercase), 'a has no Uppercase');
  Check(LManager.GetBinaryProperty(Ord('a'), ubpLowercase), 'a has Lowercase');
  Check(LManager.GetBinaryProperty(Ord(' '), ubpWhiteSpace), 'space has White_Space');
  Check(LManager.GetBinaryProperty($4E2D, ubpAlphabetic), '中 has Alphabetic');
end;

procedure TestDataManagerScript;
var
  LManager: IUnicodeDataManager;
begin
  LManager := UnicodeData;

  CheckEqual(Int64(Ord(usLatin)), Int64(Ord(LManager.GetScript(Ord('A')))), 'A is Latin');
  CheckEqual(Int64(Ord(usGreek)), Int64(Ord(LManager.GetScript($0391))), 'Alpha is Greek');
  CheckEqual(Int64(Ord(usHan)), Int64(Ord(LManager.GetScript($4E2D))), '中 is Han');
end;

procedure TestDataManagerBlock;
var
  LManager: IUnicodeDataManager;
begin
  LManager := UnicodeData;

  CheckEqual(Int64(Ord(ubBasicLatin)), Int64(Ord(LManager.GetBlock(Ord('A')))), 'A is BasicLatin');
  CheckEqual(Int64(Ord(ubGreekAndCoptic)), Int64(Ord(LManager.GetBlock($0391))), 'Alpha is GreekAndCoptic');
  CheckEqual(Int64(Ord(ubCJKUnifiedIdeographs)), Int64(Ord(LManager.GetBlock($4E2D))), '中 is CJK');
end;

procedure TestDataManagerCaseMapping;
var
  LManager: IUnicodeDataManager;
begin
  LManager := UnicodeData;

  CheckEqual(Int64(Ord('a')), Int64(LManager.GetSimpleLowercaseMapping(Ord('A'))), 'A→a');
  CheckEqual(Int64(Ord('A')), Int64(LManager.GetSimpleUppercaseMapping(Ord('a'))), 'a→A');
  CheckEqual(Int64(Ord('A')), Int64(LManager.GetSimpleTitlecaseMapping(Ord('a'))), 'a→A (title)');

  // Case fold: ß → ss (full), ß → ß (simple, no simple mapping)
  CheckEqual(Int64($00DF), Int64(LManager.GetCaseFoldSimple($00DF)), 'ß simple fold = ß');
end;

procedure TestDataManagerCaseFoldFull;
var
  LManager: IUnicodeDataManager;
  LMap: TCaseFoldMap;
  LLen: Byte;
begin
  LManager := UnicodeData;

  // ß full case fold → ss (2 codepoints)
  LLen := LManager.GetCaseFoldFull($00DF, LMap);
  CheckEqual(Int64(2), Int64(LLen), 'ß full fold len = 2');
  CheckEqual(Int64(Ord('s')), Int64(LMap[0]), 'ß fold[0] = s');
  CheckEqual(Int64(Ord('s')), Int64(LMap[1]), 'ß fold[1] = s');

  // ASCII: full fold same as simple
  LLen := LManager.GetCaseFoldFull(Ord('A'), LMap);
  CheckEqual(Int64(1), Int64(LLen), 'A full fold len = 1');
  CheckEqual(Int64(Ord('a')), Int64(LMap[0]), 'A fold[0] = a');
end;

procedure TestDataManagerDecomposition;
var
  LManager: IUnicodeDataManager;
  LMap: TCaseFoldMap;
  LLen: Byte;
  LIsCompat: Boolean;
begin
  LManager := UnicodeData;

  // ñ (U+00F1) → n + ~ (canonical decomposition, 2 codepoints)
  LLen := LManager.GetDecompositionMapping($00F1, LMap, LIsCompat);
  CheckEqual(Int64(2), Int64(LLen), 'ñ decomp len = 2');
  Check(not LIsCompat, 'ñ is canonical decomp');
  CheckEqual(Int64(Ord('n')), Int64(LMap[0]), 'ñ decomp[0] = n');
  CheckEqual(Int64($0303), Int64(LMap[1]), 'ñ decomp[1] = ~ (combining tilde)');

  // NBSP (U+00A0) → compatibility decomposition → space
  LLen := LManager.GetDecompositionMapping($00A0, LMap, LIsCompat);
  Check(LLen >= 1, 'NBSP decomp len >= 1');
  Check(LIsCompat, 'NBSP is compat decomp');

  // ASCII: no decomposition
  LLen := LManager.GetDecompositionMapping(Ord('A'), LMap, LIsCompat);
  CheckEqual(Int64(0), Int64(LLen), 'A has no decomposition');
end;

procedure TestDataManagerCCC;
var
  LManager: IUnicodeDataManager;
begin
  LManager := UnicodeData;

  // Starter characters have CCC=0
  CheckEqual(Int64(0), Int64(LManager.GetCanonicalCombiningClass(Ord('A'))), 'A CCC=0');
  CheckEqual(Int64(0), Int64(LManager.GetCanonicalCombiningClass($4E2D)), '中 CCC=0');

  // Combining marks have CCC>0
  Check(LManager.GetCanonicalCombiningClass($0300) > 0, 'combining grave CCC>0');
  Check(LManager.GetCanonicalCombiningClass($0301) > 0, 'combining acute CCC>0');
end;

procedure TestDataManagerCompositionExclusion;
var
  LManager: IUnicodeDataManager;
begin
  LManager := UnicodeData;

  // Hangul syllables are excluded
  Check(LManager.GetCompositionExclusion($AC00), '가 is composition excluded');

  // Normal starters are not excluded
  Check(not LManager.GetCompositionExclusion(Ord('A')), 'A is not excluded');
end;

procedure TestDataManagerSingleton;
var
  L1, L2: IUnicodeDataManager;
begin
  L1 := UnicodeData;
  L2 := UnicodeData;
  Check(L1 = L2, 'UnicodeData returns same instance');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.data');
  T.Test('GeneralCategory via DataManager', @TestDataManagerGeneralCategory);
  T.Test('BinaryProperty via DataManager', @TestDataManagerBinaryProperty);
  T.Test('Script via DataManager', @TestDataManagerScript);
  T.Test('Block via DataManager', @TestDataManagerBlock);
  T.Test('CaseMapping via DataManager', @TestDataManagerCaseMapping);
  T.Test('CaseFoldFull via DataManager', @TestDataManagerCaseFoldFull);
  T.Test('Decomposition via DataManager', @TestDataManagerDecomposition);
  T.Test('CCC via DataManager', @TestDataManagerCCC);
  T.Test('CompositionExclusion via DataManager', @TestDataManagerCompositionExclusion);
  T.Test('DataManager singleton', @TestDataManagerSingleton);
  if not T.Run then Halt(1);
end.

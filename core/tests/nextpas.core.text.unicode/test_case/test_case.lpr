program test_case;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.test,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.casefold,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{$I ../test_helpers.inc}

function GermanStreetLower: string;
begin
  Result := 'Stra' + Utf8Of([$00DF]) + 'e';
end;

function GermanStreetSimpleFold: string;
begin
  Result := 'stra' + Utf8Of([$00DF]) + 'e';
end;

procedure TestAsciiCaseMapping;
begin
  CheckEqual(Int64(Ord('A')), Int64(CodepointToUpper(Ord('a'))), 'a upper');
  CheckEqual(Int64(Ord('a')), Int64(CodepointToLower(Ord('A'))), 'A lower');
  CheckEqual(Int64(Ord('A')), Int64(CodepointToTitle(Ord('a'))), 'a title');
end;

procedure TestUnicodeCaseMapping;
begin
  CheckEqual(Int64($011E), Int64(CodepointToUpper($011F)), 'Latin small g with breve upper');
  CheckEqual(Int64($03C9), Int64(CodepointToLower($03A9)), 'Greek omega lower');
  CheckEqual(Int64($010400), Int64(CodepointToUpper($010428)), 'Deseret small long I upper');
  CheckEqual(Int64($010428), Int64(CodepointToLower($010400)), 'Deseret capital long I lower');
end;

procedure TestSimpleCaseFold;
begin
  CheckEqual(Int64(Ord('a')), Int64(CaseFoldSimple(Ord('A'))), 'A simple fold');
  CheckEqual(Int64(Ord('i')), Int64(CaseFoldSimple($0130)), 'capital I with dot simple fold');
  CheckEqual(Int64($03C9), Int64(CaseFoldSimple($03A9)), 'Greek omega simple fold');
end;

procedure TestFullCaseFold;
var
  LMap: TCaseFoldMap;
  LLen: Byte;
begin
  LLen := CaseFoldFull($00DF, LMap);
  CheckEqual(Int64(2), Int64(LLen), 'sharp s full fold len');
  CheckEqual(Int64(Ord('s')), Int64(LMap[0]), 'sharp s full fold first');
  CheckEqual(Int64(Ord('s')), Int64(LMap[1]), 'sharp s full fold second');

  LLen := CaseFoldFull($0130, LMap);
  CheckEqual(Int64(2), Int64(LLen), 'capital I with dot full fold len');
  CheckEqual(Int64(Ord('i')), Int64(LMap[0]), 'capital I with dot full fold first');
  CheckEqual(Int64($0307), Int64(LMap[1]), 'capital I with dot full fold second');

  LLen := CaseFoldFull($03A9, LMap);
  CheckEqual(Int64(1), Int64(LLen), 'Greek omega fallback fold len');
  CheckEqual(Int64($03C9), Int64(LMap[0]), 'Greek omega fallback fold value');
end;

procedure TestIdentityMappings;
var
  LMap: TCaseFoldMap;
begin
  CheckEqual(Int64($4E2D), Int64(CodepointToUpper($4E2D)), 'CJK upper unchanged');
  CheckEqual(Int64($4E2D), Int64(CodepointToLower($4E2D)), 'CJK lower unchanged');
  CheckEqual(Int64($4E2D), Int64(CaseFoldSimple($4E2D)), 'CJK simple fold unchanged');
  CheckEqual(Int64(1), Int64(CaseFoldFull($4E2D, LMap)), 'CJK full fold len');
  CheckEqual(Int64($4E2D), Int64(LMap[0]), 'CJK full fold unchanged');
end;

procedure TestUtf8CaseMappingWrappers;
begin
  CheckEqual('HELLO', UTF8ToUpper('Hello'), 'Hello upper');
  CheckEqual('HELLO', nextpas.core.text.unicode.UTF8ToUpper('Hello'), 'facade Hello upper');
  CheckEqual('hello', UTF8ToLower('Hello'), 'Hello lower');
  CheckEqual('hello', UTF8ToLower('HELLO'), 'HELLO lower');
  CheckEqual('STRASSE', UTF8ToUpper(GermanStreetLower), 'sharp s full upper');
  CheckEqual('strasse', UTF8ToLower('STRASSE'), 'STRASSE lower');
  CheckEqual('strasse', UTF8CaseFold(GermanStreetLower), 'sharp s full fold string');
  CheckEqual(GermanStreetSimpleFold, UTF8CaseFoldSimple(GermanStreetLower), 'sharp s simple fold string');
  CheckEqual('ASCII ONLY', UTF8ToUpper('ascii only'), 'ASCII upper fast path');
  CheckEqual('ascii only', UTF8CaseFoldSimple('ASCII ONLY'), 'ASCII simple fold fast path');
  CheckEqual('', UTF8ToUpper(''), 'empty upper');
  CheckEqual('', UTF8ToLower(''), 'empty lower');
  CheckEqual('', UTF8CaseFold(''), 'empty full fold');
  CheckEqual('', UTF8CaseFoldSimple(''), 'empty simple fold');
end;

procedure TestBoundaryCases;
var
  LMap: TCaseFoldMap;
begin
  CheckEqual(Int64($0000), Int64(CodepointToLower($0000)), 'NUL lower unchanged');
  CheckEqual(Int64($10FFFF), Int64(CodepointToUpper($10FFFF)), 'max codepoint upper unchanged');
  CheckEqual(Int64($D800), Int64(CodepointToTitle($D800)), 'surrogate title unchanged');
  CheckEqual(Int64($0000), Int64(CaseFoldSimple($0000)), 'NUL simple fold unchanged');
  CheckEqual(Int64(1), Int64(CaseFoldFull($10FFFF, LMap)), 'max codepoint full fold len');
  CheckEqual(Int64($10FFFF), Int64(LMap[0]), 'max codepoint full fold unchanged');
  CheckEqual(Int64(1), Int64(CaseFoldFull($D800, LMap)), 'surrogate full fold len');
  CheckEqual(Int64($D800), Int64(LMap[0]), 'surrogate full fold unchanged');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode.case');
  T.Test('ASCII case mapping', @TestAsciiCaseMapping);
  T.Test('Unicode case mapping', @TestUnicodeCaseMapping);
  T.Test('simple case fold', @TestSimpleCaseFold);
  T.Test('full case fold', @TestFullCaseFold);
  T.Test('identity mappings', @TestIdentityMappings);
  T.Test('UTF-8 case mapping wrappers', @TestUtf8CaseMappingWrappers);
  T.Test('boundary cases', @TestBoundaryCases);
  if not T.Run then Halt(1);
end.

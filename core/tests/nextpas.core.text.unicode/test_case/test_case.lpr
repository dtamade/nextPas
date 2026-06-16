program test_case;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.&case,
  nextpas.core.text.unicode;

var
  T: TTestRunner;

procedure AppendUtf8(var ADst: string; const ACp: TUnicodeCodepoint);
var
  LBuf: array[0..3] of Byte;
  LLen: Byte;
  LOldLen: SizeInt;
  I: Byte;
begin
  LLen := UTF8Encode(ACp, @LBuf[0]);
  Check(LLen > 0, 'test codepoint must be UTF-8 encodable');

  LOldLen := Length(ADst);
  SetLength(ADst, LOldLen + LLen);
  for I := 0 to LLen - 1 do
    ADst[LOldLen + I + 1] := AnsiChar(LBuf[I]);
end;

function Utf8Of(const ACps: array of TUnicodeCodepoint): string;
var
  I: SizeInt;
begin
  Result := '';
  for I := 0 to High(ACps) do
    AppendUtf8(Result, ACps[I]);
end;

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
  T := TTestRunner.Create('nextpas.core.text.unicode.case');
  T.Run('ASCII case mapping', @TestAsciiCaseMapping);
  T.Run('Unicode case mapping', @TestUnicodeCaseMapping);
  T.Run('simple case fold', @TestSimpleCaseFold);
  T.Run('full case fold', @TestFullCaseFold);
  T.Run('identity mappings', @TestIdentityMappings);
  T.Run('UTF-8 case mapping wrappers', @TestUtf8CaseMappingWrappers);
  T.Run('boundary cases', @TestBoundaryCases);
  T.Summary;
end.

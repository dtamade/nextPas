program test_base_unicode_hash;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
{$modeswitch unicodestrings}

uses
  nextpas.core.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestHashStringUsesRealUnicodeByteLength;
var
  LValue: string;
  LExpected: THashCode;
  LLegacy: THashCode;
begin
  LValue := 'AΩ';
  CheckEqual(Int64(2), Int64(SizeOf(LValue[1])), 'unicode string element width');

  LExpected := HashBytes(@LValue[1], SizeUInt(Length(LValue)) * SizeUInt(SizeOf(LValue[1])));
  LLegacy := HashBytes(@LValue[1], SizeUInt(Length(LValue)));

  Check(HashString(LValue) = LExpected, 'HashString should hash the full underlying byte sequence');
  Check(HashString(LValue) <> LLegacy, 'HashString should not truncate to character count bytes');
end;

procedure TestHashStringEmptyStringKeepsOffsetBasis;
begin
  CheckEqual(Int64(HashBytes(nil, 0)), Int64(HashString('')), 'empty string hash should equal empty byte hash');
end;

begin
  T := TTestRunner.Create('nextpas.core.base unicode hash');
  T.Run('hash string uses real unicode byte length', @TestHashStringUsesRealUnicodeByteLength);
  T.Run('hash string empty string keeps offset basis', @TestHashStringEmptyStringKeepsOffsetBasis);
  T.Summary;
end.

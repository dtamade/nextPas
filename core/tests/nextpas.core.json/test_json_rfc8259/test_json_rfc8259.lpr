program test_json_rfc8259;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.testing;

var
  T: TTestRunner;

function MustParse(const AJson: PAnsiChar; ALen: SizeUInt): Boolean;
var Doc: TJsonDocument;
begin
  Doc.Init(DefaultAllocator);
  Result := Doc.Parse(TStringView.Create(AJson, ALen));
  Doc.Done;
end;

function MustReject(const AJson: PAnsiChar; ALen: SizeUInt): Boolean;
var Doc: TJsonDocument;
begin
  Doc.Init(DefaultAllocator);
  Result := not Doc.Parse(TStringView.Create(AJson, ALen));
  Doc.Done;
end;

procedure TestValidStructures;
begin
  Check(MustParse('{}', 2), 'empty object');
  Check(MustParse('[]', 2), 'empty array');
  Check(MustParse('[1]', 3), 'array one');
  Check(MustParse('{"a":1}', 7), 'object one');
  Check(MustParse('[[[]]]', 6), 'nested arrays');
  Check(MustParse('[1,2,3,4,5]', 11), 'array multi');
end;

procedure TestValidLiterals;
begin
  Check(MustParse('null', 4), 'null');
  Check(MustParse('true', 4), 'true');
  Check(MustParse('false', 5), 'false');
end;

procedure TestValidNumbers;
begin
  Check(MustParse('0', 1), '0');
  Check(MustParse('-0', 2), '-0');
  Check(MustParse('1', 1), '1');
  Check(MustParse('-1', 2), '-1');
  Check(MustParse('1.5', 3), '1.5');
  Check(MustParse('-1.5', 4), '-1.5');
  Check(MustParse('1e10', 4), '1e10');
  Check(MustParse('1E10', 4), '1E10');
  Check(MustParse('1e+10', 5), '1e+10');
  Check(MustParse('1e-10', 5), '1e-10');
  Check(MustParse('1.23e45', 7), '1.23e45');
  Check(MustParse('123456789', 9), 'large int');
end;

procedure TestValidStrings;
const
  S1 = '""';
  S2 = '"hello"';
  S3 = '"he said '#92'"hi'#92'""';
  S4 = '"'#92'n'#92'r'#92't'#92'b'#92'f'#92'/'#92#92'"';
  S5 = '"'#92'u0041"';
begin
  Check(MustParse(PAnsiChar(S1), Length(S1)), 'empty string');
  Check(MustParse(PAnsiChar(S2), Length(S2)), 'simple string');
  Check(MustParse(PAnsiChar(S3), Length(S3)), 'escaped quotes');
  Check(MustParse(PAnsiChar(S4), Length(S4)), 'all named escapes');
  Check(MustParse(PAnsiChar(S5), Length(S5)), 'unicode escape');
end;

procedure TestRejectInvalid;
begin
  Check(MustReject('', 0), 'empty input');
  Check(MustReject('{', 1), 'unclosed object');
  Check(MustReject('[', 1), 'unclosed array');
  Check(MustReject('{"a"', 4), 'no colon');
  Check(MustReject('{"a":}', 6), 'missing value');
  Check(MustReject('[,]', 3), 'leading comma');
  Check(MustReject('tru', 3), 'truncated true');
  Check(MustReject('nul', 3), 'truncated null');
  Check(MustReject('fals', 4), 'truncated false');
end;

procedure TestRejectBadNumbers;
begin
  Check(MustReject('+1', 2), 'leading plus');
  Check(MustReject('.5', 2), 'leading dot');
  Check(MustReject('1.', 2), 'trailing dot');
  Check(MustReject('01', 2), 'leading zero');
  Check(MustReject('1e', 2), 'truncated exp');
end;

procedure TestRejectBadStrings;
const
  S1 = '"unterminated';
  S_TAB: array[0..3] of AnsiChar = ('"', #9, '"', #0);
  S_NL: array[0..3] of AnsiChar = ('"', #10, '"', #0);
  S_NULL: array[0..3] of AnsiChar = ('"', #0, '"', #0);
  S_CR: array[0..3] of AnsiChar = ('"', #13, '"', #0);
begin
  Check(MustReject(PAnsiChar(S1), Length(S1)), 'unterminated string');
  Check(MustReject(@S_TAB[0], 3), 'bare tab in string');
  Check(MustReject(@S_NL[0], 3), 'bare newline in string');
  Check(MustReject(@S_NULL[0], 3), 'bare null in string');
  Check(MustReject(@S_CR[0], 3), 'bare CR in string');
end;

procedure TestWhitespace;
const
  WS = '  { '#10' "a" '#13#10' : '#9' 1 '#10' } ';
begin
  Check(MustParse(PAnsiChar(WS), Length(WS)), 'whitespace everywhere');
end;

procedure TestTrailingContent;
begin
  Check(MustReject('{}[]', 4), 'trailing array');
  Check(MustReject('1 2', 3), 'trailing number');
  Check(MustReject('null null', 9), 'trailing null');
end;

procedure TestDeepNesting;
var
  Buf: array[0..1099] of AnsiChar;
  I: Int32;
begin
  for I := 0 to 499 do Buf[I] := '[';
  for I := 500 to 999 do Buf[I] := ']';
  Check(MustParse(@Buf[0], 1000), 'depth 500 ok');

  for I := 0 to 549 do Buf[I] := '[';
  for I := 550 to 1099 do Buf[I] := ']';
  Check(MustReject(@Buf[0], 1100), 'depth 550 rejected (limit 512)');
end;

procedure TestEdgeNumbers;
begin
  Check(MustParse('0', 1), '0');
  Check(MustParse('-0', 2), '-0');
  Check(MustParse('0.0', 3), '0.0');
  Check(MustParse('-0.0', 4), '-0.0');
  Check(MustParse('0e1', 3), '0e1');
  Check(MustParse('1e+10', 5), '1e+10');
  Check(MustParse('1e-10', 5), '1e-10');
  Check(MustParse('1.5e2', 5), '1.5e2');
end;

procedure TestAccessorTypeSafety;
var
  Doc: TJsonDocument;
  V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Doc.Parse(TStringView.FromStr('{"n":42,"s":"hi","b":true,"a":[1]}'));
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.ObjectGet('n').AsBool = False, 'int as bool = false');
  Check(V.ObjectGet('s').AsInt = 0, 'str as int = 0');
  Check(V.ObjectGet('b').AsFloat = 0.0, 'bool as float = 0.0');
  Check(V.ObjectGet('n').AsStr.IsEmpty, 'int as str = empty');
  Check(V.ObjectGet('a').AsInt = 0, 'array as int = 0');
  Check(V.ObjectGet('missing').AsInt = 0, 'missing as int = 0');
  Doc.Done;
end;

procedure TestSurrogatePair;
var
  Doc: TJsonDocument;
  V: TJsonValue;
  S: TStringView;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.FromStr('"😀"')), 'surrogate pair parse');
  V := TJsonValue.Create(Doc, Doc.Root);
  S := V.AsStr;
  Check(S.Len = 4, 'emoji is 4 bytes UTF-8');
  Check(Byte(S.Data[0]) = $F0, 'emoji byte 0');
  Check(Byte(S.Data[1]) = $9F, 'emoji byte 1');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(TStringView.FromStr('"\uD800"')), 'lone high surrogate rejected');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(TStringView.FromStr('"\uDC00"')), 'lone low surrogate rejected');
  Doc.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.json.rfc8259');
  T.Run('valid structures', @TestValidStructures);
  T.Run('valid literals', @TestValidLiterals);
  T.Run('valid numbers', @TestValidNumbers);
  T.Run('valid strings', @TestValidStrings);
  T.Run('reject invalid', @TestRejectInvalid);
  T.Run('reject bad numbers', @TestRejectBadNumbers);
  T.Run('reject bad strings', @TestRejectBadStrings);
  T.Run('whitespace', @TestWhitespace);
  T.Run('trailing content', @TestTrailingContent);
  T.Run('deep nesting', @TestDeepNesting);
  T.Run('edge numbers', @TestEdgeNumbers);
  T.Run('accessor type safety', @TestAccessorTypeSafety);
  T.Run('surrogate pair', @TestSurrogatePair);
  T.Summary;
end.

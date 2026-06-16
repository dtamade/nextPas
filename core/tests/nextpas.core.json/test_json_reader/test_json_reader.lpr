program test_json_reader;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.json.types,
  nextpas.core.json.reader,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestSimpleObject;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('{"a":1,"b":"hi"}'), 16));
  Check(R.Next, 'begin obj'); Check(R.TokenKind = jtkBeginObject, 'is {');
  Check(R.Next, 'key a'); Check(R.TokenKind = jtkString, 'key is str');
  CheckEqual('a', R.TokenStr.ToString, 'key=a');
  Check(R.Next, 'val 1'); Check(R.TokenKind = jtkInt, 'is num');
  CheckEqual(Int64(1), R.TokenInt, 'val=1');
  Check(R.Next, 'key b'); CheckEqual('b', R.TokenStr.ToString, 'key=b');
  Check(R.Next, 'val hi'); CheckEqual('hi', R.TokenStr.ToString, 'val=hi');
  Check(R.Next, 'end obj'); Check(R.TokenKind = jtkEndObject, 'is }');
  Check(not R.Next, 'eof');
end;

procedure TestArray;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('[1,2,3]'), 7));
  Check(R.Next, '['); Check(R.TokenKind = jtkBeginArray, 'is [');
  Check(R.Next, '1'); CheckEqual(Int64(1), R.TokenInt, '1');
  Check(R.Next, '2'); CheckEqual(Int64(2), R.TokenInt, '2');
  Check(R.Next, '3'); CheckEqual(Int64(3), R.TokenInt, '3');
  Check(R.Next, ']'); Check(R.TokenKind = jtkEndArray, 'is ]');
end;

procedure TestLiterals;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('[true,false,null]'), 17));
  Check(R.Next, '[');
  Check(R.Next, 'true'); Check(R.TokenKind = jtkBool, 'is bool');
  Check(R.TokenBool = True, 'true');
  Check(R.Next, 'false'); Check(R.TokenBool = False, 'false');
  Check(R.Next, 'null'); Check(R.TokenKind = jtkNull, 'is null');
  Check(R.Next, ']');
end;

procedure TestFloat;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('[3.14,-1.5e+2]'), 14));
  Check(R.Next, '[');
  Check(R.Next, '3.14');
  Check(Abs(R.TokenFloat - 3.14) < 1e-15, 'float 3.14');
  Check(R.Next, '-1.5e2');
  Check(Abs(R.TokenFloat - (-150.0)) < 1e-10, 'float -150');
  Check(R.Next, ']');
end;

procedure TestNested;
var R: TJsonReader; LDepth: Int32;
begin
  R.Init(TStringView.Create(PAnsiChar('{"x":{"y":[1]}}'), 15));
  LDepth := 0;
  while R.Next do
    case R.TokenKind of
      jtkBeginObject, jtkBeginArray: Inc(LDepth);
      jtkEndObject, jtkEndArray: Dec(LDepth);
    else
      ; { 其余 token (键/值/标点) 不影响深度计数 }
    end;
  Check(LDepth = 0, 'balanced');
end;

procedure TestWhitespace;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('  { "x" : 1 }  '), 16));
  Check(R.Next, '{'); Check(R.TokenKind = jtkBeginObject, '{');
  Check(R.Next, 'key'); CheckEqual('x', R.TokenStr.ToString, 'x');
  Check(R.Next, 'val'); CheckEqual(Int64(1), R.TokenInt, '1');
  Check(R.Next, '}'); Check(R.TokenKind = jtkEndObject, '}');
end;

procedure TestEmpty;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('{}'), 2));
  Check(R.Next, '{'); Check(R.TokenKind = jtkBeginObject, '{');
  Check(R.Next, '}'); Check(R.TokenKind = jtkEndObject, '}');
  Check(not R.Next, 'eof');
end;

procedure TestError;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('{invalid}'), 9));
  Check(R.Next, '{');
  Check(not R.Next, 'error on invalid');
  Check(R.TokenKind = jtkError, 'is error');
  Check(R.Error.Message.Len > 0, 'error message');
end;

procedure TestErrorPosition;
var
  R: TJsonReader;
  LErr: TJsonError;
const
  INPUT = '{'#10'  nope';
begin
  R.Init(TStringView.Create(PAnsiChar(INPUT), Length(INPUT)));
  Check(R.Next, 'begin object');
  Check(not R.Next, 'error on invalid literal');
  Check(R.TokenKind = jtkError, 'is error');
  LErr := R.Error;
  CheckEqual('invalid literal', LErr.Message.ToString, 'error message');
  CheckEqual(Int64(4), Int64(LErr.Offset), 'error byte offset');
  CheckEqual(Int64(2), Int64(LErr.Line), 'error line');
  CheckEqual(Int64(3), Int64(LErr.Column), 'error column');
end;

procedure ExpectReaderErrorAt(const AInput, AExpectedMessage, ACase: string;
  AExpectedOffset, AExpectedLine, AExpectedColumn: Int64);
var
  R: TJsonReader;
  LErr: TJsonError;
begin
  R.Init(TStringView.Create(PAnsiChar(AInput), Length(AInput)));
  while R.Next do
    ;
  Check(R.TokenKind = jtkError, ACase + ' token is error');
  LErr := R.Error;
  CheckEqual(AExpectedMessage, LErr.Message.ToString, ACase + ' message');
  CheckEqual(AExpectedOffset, Int64(LErr.Offset), ACase + ' offset');
  CheckEqual(AExpectedLine, Int64(LErr.Line), ACase + ' line');
  CheckEqual(AExpectedColumn, Int64(LErr.Column), ACase + ' column');
end;

procedure TestNestedErrorPositions;
begin
  ExpectReaderErrorAt('{' + #13#10 + '  "s": "ok' + #92 + 'q"' + #10 + '}',
    'invalid escape sequence', 'nested invalid escape after CRLF',
    13, 2, 11);
  ExpectReaderErrorAt('{' + #13#10 + '  "s": "a' + #1 + '"' + #10 + '}',
    'control char in string', 'nested control char after CRLF',
    12, 2, 10);
  ExpectReaderErrorAt('{' + #13#10 + '  "n": 9223372036854775808' + #10 + '}',
    'number overflow', 'nested int64 overflow after CRLF',
    10, 2, 8);
  ExpectReaderErrorAt('{' + #13#10 + '  "n": 01' + #10 + '}',
    'invalid number', 'nested invalid number after CRLF',
    10, 2, 8);
  ExpectReaderErrorAt('{' + #13#10 + '  "n": 1e+}' + #10 + '}',
    'invalid number', 'nested exponent without digits after CRLF',
    13, 2, 11);
end;

procedure TestInvalidTokenSuffixesFailClosed;
begin
  ExpectReaderErrorAt('1x',
    'invalid number', 'number alpha suffix',
    0, 1, 1);
  ExpectReaderErrorAt('{' + #13#10 + '  "n": 1x' + #10 + '}',
    'invalid number', 'nested number alpha suffix after CRLF',
    10, 2, 8);
  ExpectReaderErrorAt('truex',
    'invalid literal', 'true alpha suffix',
    0, 1, 1);
  ExpectReaderErrorAt('{' + #13#10 + '  "b": truex' + #10 + '}',
    'invalid literal', 'nested literal alpha suffix after CRLF',
    10, 2, 8);
end;

procedure TestIntVsFloat;
var R: TJsonReader;
const
  INPUT = '[42,3.14,-1e5,9223372036854775807,-9223372036854775808]';
begin
  R.Init(TStringView.Create(PAnsiChar(INPUT), Length(INPUT)));
  Check(R.Next, '[');
  Check(R.Next, '42'); Check(R.TokenKind = jtkInt, 'int token');
  CheckEqual(Int64(42), R.TokenInt, 'int val');
  Check(R.Next, '3.14'); Check(R.TokenKind = jtkFloat, 'float token');
  Check(Abs(R.TokenFloat - 3.14) < 1e-15, 'float val');
  Check(R.Next, '-1e5'); Check(R.TokenKind = jtkFloat, 'exp float');
  Check(Abs(R.TokenFloat - (-100000.0)) < 0.1, 'exp float val');
  Check(R.Next, 'max int64');
  Check(R.TokenKind = jtkInt, 'max int64 token');
  CheckEqual(High(Int64), R.TokenInt, 'max int64 value');
  Check(R.Next, 'min int64');
  Check(R.TokenKind = jtkInt, 'min int64 token');
  CheckEqual(Low(Int64), R.TokenInt, 'min int64 value');
  Check(R.Next, ']');
end;

procedure TestIntegerOverflow;
var
  R: TJsonReader;
  LErr: TJsonError;
const
  POSITIVE_OVERFLOW = '9223372036854775808';
  NEGATIVE_OVERFLOW = '-9223372036854775809';
  EXPLICIT_FLOAT = '1e20';
  EXPLICIT_FLOAT_OVERFLOW = '1e1000';
begin
  R.Init(TStringView.Create(PAnsiChar(POSITIVE_OVERFLOW), Length(POSITIVE_OVERFLOW)));
  Check(not R.Next, 'positive int64 overflow rejected');
  Check(R.TokenKind = jtkError, 'positive overflow token is error');
  LErr := R.Error;
  CheckEqual('number overflow', LErr.Message.ToString,
    'positive overflow message');
  CheckEqual(Int64(0), Int64(LErr.Offset), 'positive overflow offset');

  R.Init(TStringView.Create(PAnsiChar(NEGATIVE_OVERFLOW), Length(NEGATIVE_OVERFLOW)));
  Check(not R.Next, 'negative int64 overflow rejected');
  Check(R.TokenKind = jtkError, 'negative overflow token is error');
  LErr := R.Error;
  CheckEqual('number overflow', LErr.Message.ToString,
    'negative overflow message');
  CheckEqual(Int64(0), Int64(LErr.Offset), 'negative overflow offset');

  R.Init(TStringView.Create(PAnsiChar(EXPLICIT_FLOAT), Length(EXPLICIT_FLOAT)));
  Check(R.Next, 'explicit float still accepted');
  Check(R.TokenKind = jtkFloat, 'explicit float token');

  R.Init(TStringView.Create(PAnsiChar(EXPLICIT_FLOAT_OVERFLOW),
    Length(EXPLICIT_FLOAT_OVERFLOW)));
  Check(not R.Next, 'explicit float overflow rejected');
  Check(R.TokenKind = jtkError, 'explicit float overflow token is error');
  LErr := R.Error;
  CheckEqual('number overflow', LErr.Message.ToString,
    'explicit float overflow message');
  CheckEqual(Int64(0), Int64(LErr.Offset), 'explicit float overflow offset');
end;

procedure TestInvalidNumberTokens;
var
  R: TJsonReader;
  LErr: TJsonError;

  procedure ExpectInvalidNumber(const AInput, ACase: string);
  begin
    R.Init(TStringView.Create(PAnsiChar(AInput), Length(AInput)));
    Check(not R.Next, ACase + ' rejected');
    Check(R.TokenKind = jtkError, ACase + ' token is error');
    LErr := R.Error;
    CheckEqual('invalid number', LErr.Message.ToString,
      ACase + ' message');
    CheckEqual(Int64(0), Int64(LErr.Offset), ACase + ' offset');
    CheckEqual(Int64(1), Int64(LErr.Line), ACase + ' line');
    CheckEqual(Int64(1), Int64(LErr.Column), ACase + ' column');
  end;

begin
  ExpectInvalidNumber('01', 'leading zero');
  ExpectInvalidNumber('-01', 'negative leading zero');
  ExpectInvalidNumber('-', 'minus only');
  ExpectInvalidNumber('-.1', 'minus without integer digits');
  ExpectInvalidNumber('1.', 'fraction without digits');
  ExpectInvalidNumber('1.e2', 'fraction before exponent without digits');
  ExpectInvalidNumber('1e', 'exponent without digits');
  ExpectInvalidNumber('1e+', 'positive exponent sign without digits');
  ExpectInvalidNumber('1e-', 'negative exponent sign without digits');
end;

procedure TestLongString;
var R: TJsonReader;
const
  INPUT = '["abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOP"]';
begin
  R.Init(TStringView.Create(PAnsiChar(INPUT), Length(INPUT)));
  Check(R.Next, '[');
  Check(R.Next, 'str'); Check(R.TokenKind = jtkString, 'is str');
  CheckEqual(Int64(52), Int64(R.TokenStr.Len), 'len=52');
  Check(R.Next, ']');
end;

procedure TestStringTokenValidation;
var
  R: TJsonReader;
  LErr: TJsonError;
const
  LEGAL_ESCAPE = '"'#92'n"';
  INVALID_ESCAPE = '"'#92'q"';
  BARE_LF = '"line'#10'break"';
begin
  R.Init(TStringView.Create(PAnsiChar(LEGAL_ESCAPE), Length(LEGAL_ESCAPE)));
  Check(R.Next, 'valid escaped string token');
  Check(R.TokenKind = jtkString, 'valid escape token is string');
  CheckEqual(#92'n', R.TokenStr.ToString,
    'reader keeps valid escaped string token as raw view');

  R.Init(TStringView.Create(PAnsiChar(INVALID_ESCAPE), Length(INVALID_ESCAPE)));
  Check(not R.Next, 'invalid escaped string rejected');
  Check(R.TokenKind = jtkError, 'invalid escape token is error');
  LErr := R.Error;
  CheckEqual('invalid escape sequence', LErr.Message.ToString,
    'invalid escape message');
  CheckEqual(Int64(1), Int64(LErr.Offset), 'invalid escape offset');
  CheckEqual(Int64(1), Int64(LErr.Line), 'invalid escape line');
  CheckEqual(Int64(2), Int64(LErr.Column), 'invalid escape column');

  R.Init(TStringView.Create(PAnsiChar(BARE_LF), Length(BARE_LF)));
  Check(not R.Next, 'bare control char in string rejected');
  Check(R.TokenKind = jtkError, 'bare control char token is error');
  LErr := R.Error;
  CheckEqual('control char in string', LErr.Message.ToString,
    'control char message');
  CheckEqual(Int64(5), Int64(LErr.Offset), 'control char offset');
  CheckEqual(Int64(1), Int64(LErr.Line), 'control char line');
  CheckEqual(Int64(6), Int64(LErr.Column), 'control char column');
end;

procedure TestMixedWhitespace;
var R: TJsonReader;
const
  INPUT = #9'{'#13#10' "x"'#9':'#10'1'#13'}';
begin
  R.Init(TStringView.Create(PAnsiChar(INPUT), Length(INPUT)));
  Check(R.Next, '{'); Check(R.TokenKind = jtkBeginObject, '{');
  Check(R.Next, 'key'); CheckEqual('x', R.TokenStr.ToString, 'key');
  Check(R.Next, 'val'); CheckEqual(Int64(1), R.TokenInt, 'val');
  Check(R.Next, '}'); Check(R.TokenKind = jtkEndObject, '}');
end;

begin
  T := TTestRunner.Create('nextpas.core.json.reader');
  T.Run('simple object', @TestSimpleObject);
  T.Run('array', @TestArray);
  T.Run('literals', @TestLiterals);
  T.Run('float', @TestFloat);
  T.Run('nested', @TestNested);
  T.Run('whitespace', @TestWhitespace);
  T.Run('empty', @TestEmpty);
  T.Run('error', @TestError);
  T.Run('error position', @TestErrorPosition);
  T.Run('nested error positions', @TestNestedErrorPositions);
  T.Run('invalid token suffixes fail closed',
    @TestInvalidTokenSuffixesFailClosed);
  T.Run('int vs float', @TestIntVsFloat);
  T.Run('integer overflow', @TestIntegerOverflow);
  T.Run('invalid number tokens', @TestInvalidNumberTokens);
  T.Run('long string', @TestLongString);
  T.Run('string token validation', @TestStringTokenValidation);
  T.Run('mixed whitespace', @TestMixedWhitespace);
  T.Summary;
end.

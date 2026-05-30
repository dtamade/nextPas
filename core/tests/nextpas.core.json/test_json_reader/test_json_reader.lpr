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

procedure TestIntVsFloat;
var R: TJsonReader;
begin
  R.Init(TStringView.Create(PAnsiChar('[42,3.14,-1e5]'), 14));
  Check(R.Next, '[');
  Check(R.Next, '42'); Check(R.TokenKind = jtkInt, 'int token');
  CheckEqual(Int64(42), R.TokenInt, 'int val');
  Check(R.Next, '3.14'); Check(R.TokenKind = jtkFloat, 'float token');
  Check(Abs(R.TokenFloat - 3.14) < 1e-15, 'float val');
  Check(R.Next, '-1e5'); Check(R.TokenKind = jtkFloat, 'exp float');
  Check(Abs(R.TokenFloat - (-100000.0)) < 0.1, 'exp float val');
  Check(R.Next, ']');
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
  T.Run('int vs float', @TestIntVsFloat);
  T.Run('long string', @TestLongString);
  T.Run('mixed whitespace', @TestMixedWhitespace);
  T.Summary;
end.

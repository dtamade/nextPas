program test_text_kv;

{ V3-L0 text.kv 共享词法内核离线自证：
    1 空串/空白 2 单对 3 多对空格 4 引号包裹含空格/@/= 5 单双引号
    6 大小写保留 7 空值 8 重复键 9 异常：缺= /空key/未闭合引号
    10 ScanKV vs ParseKV 一致性 11 100 对容积 12 错误消息保真
    13 分号分隔 14 花括号包裹 15 混合/未闭合花括号 16 ValidateKV 零分配
  均为纯函数离线，不依赖 DB。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.kv,
  nextpas.core.text.conv,
  nextpas.core.exception;

var
  T: TTestSuite;

procedure CheckPairs(const AInput: string; const AExpected: array of string);
var
  LPairs: TKVPairs;
  I: Integer;
begin
  LPairs := ParseKV(AInput);
  CheckEqual(Int64(Length(AExpected) div 2), Int64(Length(LPairs)),
    'pair count');
  for I := 0 to High(LPairs) do
  begin
    CheckEqual(AExpected[I*2], LPairs[I].Key, 'key['+IntToStr(I)+']');
    CheckEqual(AExpected[I*2+1], LPairs[I].Value, 'value['+IntToStr(I)+']');
  end;
end;

procedure TestEmpty;
begin
  CheckPairs('', []);
  CheckPairs('   ', []);
end;

procedure TestSingle;
begin
  CheckPairs('host=localhost', ['host','localhost']);
  CheckPairs('  host=localhost  ', ['host','localhost']);
end;

procedure TestMultipleSpaces;
begin
  CheckPairs('host=db.local port=3307 user=root', ['host','db.local','port','3307','user','root']);
end;

procedure TestQuotedSpacesAndAt;
var P: TKVPairs;
begin
  P := ParseKV('password=''p@ss wd'' host=h');
  CheckEqual(Int64(2), Int64(Length(P)));
  CheckEqual('password', P[0].Key);
  CheckEqual('p@ss wd', P[0].Value);
  CheckEqual('h', P[1].Value);

  CheckPairs('a="hello world" b=''x y''', ['a','hello world','b','x y']);
end;

procedure TestQuotedEquals;
begin
  // '=' inside quoted value must be preserved
  CheckPairs('a=''x=y'' b="p=q"', ['a','x=y','b','p=q']);
end;

procedure TestCasePreserved;
var P: TKVPairs;
begin
  P := ParseKV('SOCKET=/run/mysqld.sock USER=u');
  CheckEqual('SOCKET', P[0].Key);
  CheckEqual('/run/mysqld.sock', P[0].Value);
  CheckEqual('USER', P[1].Key);
end;

procedure TestEmptyValue;
begin
  CheckPairs('a= b=c', ['a','','b','c']);
  CheckPairs('a="" b=x', ['a','','b','x']); // a="" -> empty
end;

procedure TestDuplicateKeys;
var P: TKVPairs;
begin
  P := ParseKV('a=1 a=2 a=3');
  CheckEqual(Int64(3), Int64(Length(P)));
  CheckEqual('1', P[0].Value);
  CheckEqual('2', P[1].Value);
  CheckEqual('3', P[2].Value);
end;

procedure TestMalformed;
begin
  try ParseKV('=v'); Fail('empty key must raise'); except on E: Exception do Check(Pos('malformed', E.Message)>0, 'empty key msg'); end;
  try ParseKV('key'); Fail('missing = must raise'); except on E: Exception do Check(Pos('malformed', E.Message)>0, 'missing = msg'); end;
  try ParseKV('a=b c'); Fail('missing = second token must raise'); except on E: Exception do Check(Pos('malformed', E.Message)>0, 'malformed second'); end;
end;

procedure TestUnterminated;
begin
  try ParseKV('a=''unterminated'); Fail('unterminated single'); except on E: Exception do Check(Pos('unterminated', E.Message)>0, 'unterminated single'); end;
  try ParseKV('a="unterminated'); Fail('unterminated double'); except on E: Exception do Check(Pos('unterminated', E.Message)>0, 'unterminated double'); end;
end;

procedure TestScanVsParse;
var
  LParsed: TKVPairs;
  LScanned: TKVPairs;
  LCount: Integer;
begin
  LParsed := ParseKV('host=127.0.0.1 port=3306 user=root password=''p@ss wd'' db=app socket=/tmp/mysql.sock');
  SetLength(LScanned, 0);
  ScanKV('host=127.0.0.1 port=3306 user=root password=''p@ss wd'' db=app socket=/tmp/mysql.sock',
    procedure(const AKey, AValue: string)
    var L: Integer;
    begin
      L := Length(LScanned);
      SetLength(LScanned, L+1);
      LScanned[L].Key := AKey;
      LScanned[L].Value := AValue;
    end);
  CheckEqual(Int64(Length(LParsed)), Int64(Length(LScanned)), 'scan vs parse count');
  for LCount := 0 to High(LParsed) do
  begin
    CheckEqual(LParsed[LCount].Key, LScanned[LCount].Key, 'scan key '+IntToStr(LCount));
    CheckEqual(LParsed[LCount].Value, LScanned[LCount].Value, 'scan value '+IntToStr(LCount));
  end;
end;

procedure TestLargeVolume;
var
  S: string;
  P: TKVPairs;
  I: Integer;
begin
  S := '';
  for I := 1 to 100 do
    S := S + 'k'+IntToStr(I)+'=v'+IntToStr(I)+' ';
  P := ParseKV(S);
  CheckEqual(Int64(100), Int64(Length(P)), '100 pairs');
  CheckEqual('k1', P[0].Key);
  CheckEqual('v100', P[99].Value);
end;

procedure TestErrorMessagesPreserveKey;
begin
  try ParseKV('mykey="unterminated'); Fail('must raise'); except on E: Exception do Check(Pos('mykey', E.Message)>0, 'msg preserves key'); end;
end;

procedure TestSemicolonDelimited;
begin
  CheckPairs('a=1;b=2;c=3', ['a','1','b','2','c','3']);
  CheckPairs('host=db;port=3306;user=root', ['host','db','port','3306','user','root']);
  CheckPairs('a=1; b=2 ; c=3 ', ['a','1','b','2','c','3']);
  CheckPairs('a=1;;b=2', ['a','1','b','2']);
end;

procedure TestBraceQuoted;
var P: TKVPairs;
begin
  CheckPairs('Driver={PostgreSQL Unicode};Server=localhost', ['Driver','PostgreSQL Unicode','Server','localhost']);
  CheckPairs('Driver={DM8 ODBC DRIVER};Server=127.0.0.1;Port=5236', ['Driver','DM8 ODBC DRIVER','Server','127.0.0.1','Port','5236']);
  CheckPairs('a={x=y;z} b=2', ['a','x=y;z','b','2']);
  // brace value may contain spaces and semicolons
  P := ParseKV('Driver={My Driver};DSN=mydsn');
  CheckEqual('Driver', P[0].Key);
  CheckEqual('My Driver', P[0].Value);
end;

procedure TestMixedAndUnterminatedBrace;
begin
  // mixed space and semicolon + quoted
  CheckPairs('a=1 b=2;c=3 d=''x y'';e={v;w}', ['a','1','b','2','c','3','d','x y','e','v;w']);
  // unterminated brace
  try ParseKV('Driver={unterminated'); Fail('unterminated brace'); except on E: Exception do Check(Pos('unterminated', E.Message)>0, 'unterminated brace'); end;
  // empty with semicolon
  CheckPairs('a=;b=2', ['a','','b','2']);
  // ScanKV parity for semicolon
  CheckPairs('x=1;y=2', ['x','1','y','2']);
end;

procedure TestValidateKV;
var LErr: string;
begin
  Check(ValidateKV('a=1 b=2', LErr), 'valid space');
  Check(ValidateKV('Driver={DM8 ODBC DRIVER};Server=127.0.0.1', LErr), 'valid brace');
  Check(ValidateKV('a=1;b=2;c=3', LErr), 'valid semicolon');
  Check(not ValidateKV('', LErr) and (Pos('empty', LErr)>0), 'empty fails');
  Check(not ValidateKV('   ;  ', LErr) and (Pos('empty', LErr)>0), 'whitespace only fails');
  Check(not ValidateKV('key', LErr) and (Pos('malformed', LErr)>0), 'missing = fails');
  Check(not ValidateKV('=value', LErr) and (Pos('malformed', LErr)>0), 'empty key fails');
  Check(not ValidateKV('a={unterminated', LErr) and (Pos('unterminated', LErr)>0), 'unterminated brace fails');
  Check(not ValidateKV('a=''unterminated', LErr) and (Pos('unterminated', LErr)>0), 'unterminated single fails');
  // parity with ParseKV: same error messages
  try ParseKV('a={x'); except on E: Exception do Check(Pos('unterminated', E.Message)>0, 'parse vs validate parity'); end;
end;

begin
  T := TTestSuite.Create('nextpas.core.text.kv');
  T.Test('empty', @TestEmpty);
  T.Test('single', @TestSingle);
  T.Test('multiple spaces', @TestMultipleSpaces);
  T.Test('quoted spaces and @', @TestQuotedSpacesAndAt);
  T.Test('quoted equals', @TestQuotedEquals);
  T.Test('case preserved', @TestCasePreserved);
  T.Test('empty value', @TestEmptyValue);
  T.Test('duplicate keys', @TestDuplicateKeys);
  T.Test('malformed', @TestMalformed);
  T.Test('unterminated', @TestUnterminated);
  T.Test('scan vs parse', @TestScanVsParse);
  T.Test('large volume 100', @TestLargeVolume);
  T.Test('error preserves key', @TestErrorMessagesPreserveKey);
  T.Test('semicolon delimited', @TestSemicolonDelimited);
  T.Test('brace quoted', @TestBraceQuoted);
  T.Test('mixed and unterminated brace', @TestMixedAndUnterminatedBrace);
  T.Test('validateKV zero-alloc', @TestValidateKV);
  if not T.Run then Halt(1);
end.

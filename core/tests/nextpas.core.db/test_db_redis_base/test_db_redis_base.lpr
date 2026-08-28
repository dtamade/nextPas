program test_db_redis_base;

{ V3-A5 Redis 协议基座契约测试（纯离线，无 IO）：
    1 dbkRedis 枚举序号稳定契约钉死
    2 RespEncodeCommand：帧格式精确字节 / 二进制安全载荷
    3 RespPlanCommand：分词 / ? 顺序槽 / ?N 显式槽 / 未绑定与重复
      逻辑号 fail-fast / 引号字面量整体成词 / 畸形 ?N fail-fast
    4 RespTryParse：五类回复帧精确解析 / RESP2 空形归 null /
      嵌套数组 / 逐字节增量喂入 / 畸形帧 fail-fast
    5 RespErrorType 首词大写化
    6 ClassifyRedis 归一表：词元精确匹配 / 未识别欠归一
  本门禁不需要任何网络或服务端。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.db.base,
  nextpas.core.db.err,
  nextpas.core.db.redis.base,
  nextpas.core.db.redis.resp;

var
  T: TTestSuite;

{ ===== 辅助 ===== }

function SToB(const AStr: string): TBytes;
begin
  SetLength(Result, Length(AStr));
  if AStr <> '' then
    Move(AStr[1], Result[0], Length(AStr));
end;

function BToS(const AB: TBytes): string;
begin
  if Length(AB) = 0 then
    Exit('');
  SetString(Result, PAnsiChar(@AB[0]), Length(AB));
end;

procedure ExpectEDbError(const AProc: TProc; const ATag: string);
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    AProc();
  except
    on E: EDbError do
      LRaised := True;
  end;
  Check(LRaised, ATag + ': expected EDbError');
end;

{ ===== 1 ===== }

procedure TestKindOrdinal;
begin
  CheckEqual(Int64(Ord(dbkUnknown)), 0, 'kind unknown=0');
  CheckEqual(Int64(Ord(dbkSqlite)), 1, 'kind sqlite=1');
  CheckEqual(Int64(Ord(dbkPostgres)), 2, 'kind postgres=2');
  CheckEqual(Int64(Ord(dbkMysql)), 3, 'kind mysql=3');
  CheckEqual(Int64(Ord(dbkOdbc)), 4, 'kind odbc=4');
  CheckEqual(Int64(Ord(dbkRedis)), 5, 'kind redis=5');
end;

{ ===== 2 ===== }

procedure TestEncodeCommand;
var
  LOut: TBytes;
  LEmpty: TRespArgs;
begin
  RespEncodeCommand(TRespArgs.Create(SToB('GET'), SToB('key')), LOut);
  Check(BToS(LOut) = '*2'#13#10'$3'#13#10'GET'#13#10'$3'#13#10'key'#13#10,
    'encode get-key frame');

  { 二进制安全：载荷含 CRLF 与引号原样长度前缀，不转义 }
  RespEncodeCommand(TRespArgs.Create(SToB('SET'),
    SToB('a'#13#10'b"')), LOut);
  Check(BToS(LOut) =
    '*2'#13#10'$3'#13#10'SET'#13#10'$5'#13#10'a'#13#10'b"'#13#10,
    'encode binary-safe payload');

  SetLength(LEmpty, 0);
  RespEncodeCommand(LEmpty, LOut);
  Check(BToS(LOut) = '*0'#13#10, 'encode empty command');
end;

{ ===== 3 ===== }

procedure TestPlanCommand;
var
  LArgs: TRespArgs;
  LBound: TRespArgs;
begin
  { 字面分词 }
  CheckEqual(Int64(2),
    Int64(RespPlanCommand('GET key', [], LArgs)), 'plan two tokens');
  Check((BToS(LArgs[0]) = 'GET') and (BToS(LArgs[1]) = 'key'),
    'plan token values');

  { ? 顺序槽 }
  LBound := TRespArgs.Create(SToB('k1'), SToB('v1'));
  CheckEqual(Int64(3),
    Int64(RespPlanCommand('SET ? ?', LBound, LArgs)),
    'plan sequential slots');
  Check((BToS(LArgs[1]) = 'k1') and (BToS(LArgs[2]) = 'v1'),
    'plan sequential slot values');

  { ?N 显式槽（乱序取用）}
  CheckEqual(Int64(3),
    Int64(RespPlanCommand('MSET ?2 ?1', LBound, LArgs)),
    'plan explicit slots');
  Check((BToS(LArgs[1]) = 'v1') and (BToS(LArgs[2]) = 'k1'),
    'plan explicit slot values');

  { 引号字面量整体成词 }
  CheckEqual(Int64(2),
    Int64(RespPlanCommand('GET ''a b''', [], LArgs)),
    'plan quoted literal splits');
  Check(BToS(LArgs[1]) = 'a b', 'plan quoted literal content');

  { 混合：字面 + ?N }
  CheckEqual(Int64(2),
    Int64(RespPlanCommand('EXISTS key:?1', LBound, LArgs)),
    'plan mixed literal and slot');
  { '?x' 非占位符语法：整体字面键（Redis 键可含 ? 字符）}
  CheckEqual(Int64(2),
    Int64(RespPlanCommand('GET ?x', [], LArgs)),
    'plan qmark-word stays literal');
end;

procedure TestPlanFailFast;
begin
  ExpectEDbError(
    procedure
    var
      LArgs: TRespArgs;
    begin
      RespPlanCommand('GET ?', [], LArgs);
    end, 'unbound sequential slot');

  ExpectEDbError(
    procedure
    var
      LArgs: TRespArgs;
      LBound: TRespArgs;
    begin
      LBound := TRespArgs.Create(SToB('x'));
      RespPlanCommand('GET ?2', LBound, LArgs);
    end, 'explicit slot out of bounds');

  ExpectEDbError(
    procedure
    var
      LArgs: TRespArgs;
      LBound: TRespArgs;
    begin
      LBound := TRespArgs.Create(SToB('x'), SToB('y'));
      RespPlanCommand('PING ?1 ?1', LBound, LArgs);
    end, 'duplicate logical number');

  ExpectEDbError(
    procedure
    var
      LArgs: TRespArgs;
    begin
      RespPlanCommand('GET ''unterminated', [], LArgs);
    end, 'unterminated quote');
end;

{ ===== 4 ===== }

procedure ExpectParsed(const AFrame: string; const ATag: string);
var
  LBuf: TBytes;
  LPos: Integer;
  LV: TRespValue;
  LNeed: Boolean;
begin
  LBuf := SToB(AFrame);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed), ATag + ': parsed');
  Check(LPos = Length(LBuf), ATag + ': consumed whole frame');
end;

procedure TestParseScalars;
var
  LBuf: TBytes;
  LPos: Integer;
  LV: TRespValue;
  LNeed: Boolean;
begin
  LBuf := SToB('+OK'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed) and
    (LV.Kind = rvkSimple) and (BToS(LV.Data) = 'OK'), 'parse simple');

  LBuf := SToB(':12345'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed) and
    (LV.Kind = rvkInteger) and (LV.Int = 12345), 'parse integer');

  LBuf := SToB('$6'#13#10'foobar'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed) and
    (LV.Kind = rvkBulk) and (BToS(LV.Data) = 'foobar'), 'parse bulk');

  { RESP2 空形 }
  LBuf := SToB('$-1'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed) and (LV.Kind = rvkNull),
    'parse null bulk');

  LBuf := SToB('*-1'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed) and (LV.Kind = rvkNull),
    'parse null array');

  { RESP3 _ }
  LBuf := SToB('_'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed) and (LV.Kind = rvkNull),
    'parse resp3 null');

  { 错误帧原样载荷 }
  LBuf := SToB('-ERR unknown command ''FOO'''#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed) and
    (LV.Kind = rvkError) and
    (BToS(LV.Data) = 'ERR unknown command ''FOO'''),
    'parse error payload');
end;

procedure TestParseArrays;
var
  LBuf: TBytes;
  LPos: Integer;
  LV, LE: TRespValue;
  LNeed: Boolean;
begin
  LBuf := SToB('*3'#13#10'$3'#13#10'foo'#13#10':7'#13#10'$-1'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed), 'array frame parses');
  Check(LV.Kind = rvkArray, 'array kind');
  CheckEqual(Int64(Length(LV.Items)), 3, 'array count');
  LE := LV.Items[0];
  Check((LE.Kind = rvkBulk) and (BToS(LE.Data) = 'foo'), 'elem0 bulk');
  LE := LV.Items[1];
  Check((LE.Kind = rvkInteger) and (LE.Int = 7), 'elem1 int');
  Check(LV.Items[2].Kind = rvkNull, 'elem2 null');

  { 嵌套数组 }
  LBuf := SToB('*2'#13#10'*1'#13#10'+A'#13#10'*1'#13#10'+B'#13#10);
  LPos := 0;
  Check(RespTryParse(LBuf, LPos, LV, LNeed), 'nested frame parses');
  Check((LV.Kind = rvkArray) and (Length(LV.Items) = 2),
    'nested outer');
  Check((LV.Items[0].Items[0].Kind = rvkSimple) and
    (BToS(LV.Items[0].Items[0].Data) = 'A'), 'nested inner a');
  Check(BToS(LV.Items[1].Items[0].Data) = 'B', 'nested inner b');
end;

procedure TestIncrementalParse;
var
  LFrame: TBytes;
  LBuf: TBytes;
  LPos, I, LN: Integer;
  LV: TRespValue;
  LNeed: Boolean;
begin
  { 逐字节喂入：数据不足恒 NeedMore，齐了才解析成功 }
  LFrame := SToB('*2'#13#10'$5'#13#10'hello'#13#10':9'#13#10);
  LN := Length(LFrame);
  LPos := 0;
  SetLength(LBuf, 0);
  for I := 1 to LN do
  begin
    SetLength(LBuf, Length(LBuf) + 1);
    LBuf[Length(LBuf) - 1] := LFrame[I - 1];
    if I < LN then
    begin
      LPos := 0;
      Check(not RespTryParse(LBuf, LPos, LV, LNeed) and LNeed,
        'incremental prefix ' + IntToStr(I) + ' needs more');
    end
    else
    begin
      LPos := 0;
      Check(RespTryParse(LBuf, LPos, LV, LNeed) and not LNeed,
        'incremental full frame parses');
      Check(LV.Kind = rvkArray, 'incremental array kind');
    end;
  end;
end;

procedure TestParseFailFast;
var
  LBuf: TBytes;
  LPos: Integer;
  LV: TRespValue;
  LNeed: Boolean;
begin
  { 未知类型字节 }
  LBuf := SToB('@junk'#13#10);
  LPos := 0;
  ExpectEDbError(
    procedure
    begin
      RespTryParse(LBuf, LPos, LV, LNeed);
    end, 'unknown type byte');

  { bulk 长度声明后缺 CRLF 终止 }
  LBuf := SToB('$5'#13#10'hell');
  LPos := 0;
  LNeed := False;
  Check(not RespTryParse(LBuf, LPos, LV, LNeed) and LNeed,
    'truncated bulk needs more');

  LBuf := SToB('$5'#13#10'helloX'#13#10);
  LPos := 0;
  ExpectEDbError(
    procedure
    begin
      RespTryParse(LBuf, LPos, LV, LNeed);
    end, 'bulk bad terminator');

  { 非法整数 }
  LBuf := SToB(':12ab'#13#10);
  LPos := 0;
  ExpectEDbError(
    procedure
    begin
      RespTryParse(LBuf, LPos, LV, LNeed);
    end, 'malformed integer');

  { 负 bulk 长度非 -1 }
  LBuf := SToB('$-2'#13#10);
  LPos := 0;
  ExpectEDbError(
    procedure
    begin
      RespTryParse(LBuf, LPos, LV, LNeed);
    end, 'negative bulk length');
end;

{ ===== 5 ===== }

procedure TestErrorType;
begin
  Check(RespErrorType(SToB('WRONGPASS invalid username-password'))
    = 'WRONGPASS', 'errtype wrongpass');
  Check(RespErrorType(SToB('err lower case')) = 'ERR',
    'errtype uppercases');
  Check(RespErrorType(SToB('MOVED 3999 127.0.0.1:6381')) = 'MOVED',
    'errtype moved');
  Check(RespErrorType(SToB('ERR')) = 'ERR', 'errtype bare word');
  Check(RespErrorType(nil) = '', 'errtype empty payload');
end;

procedure TestInfoFieldValue;
var
  LP: TBytes;

  function V(const AKey: string): string;
  begin
    Result := RespInfoFieldValue(LP, AKey);
  end;

begin
  LP := SToB('# Server'#13#10'redis_version:7.2.4'#13#10 +
    'redis_mode:standalone'#13#10'os:Linux 6.1.0'#13#10);
  Check(V('redis_version') = '7.2.4', 'info redis_version');
  Check(V('redis_mode') = 'standalone', 'info redis_mode');
  Check(V('os') = 'Linux 6.1.0', 'info os value');
  Check(V('missing') = '', 'info missing key');
  Check(V('version') = '', 'info no prefix match');

  { 无段头 + 无尾 CRLF }
  LP := SToB('valkey_version:8.0.0');
  Check(V('valkey_version') = '8.0.0', 'info tailless line');

  { 空载荷 }
  LP := nil;
  Check(V('redis_version') = '', 'info empty payload');
end;

{ ===== 6 ===== }

procedure TestClassifyRedisTable;
var
  LCat: TDbErrorCategory;
  LCon: TDbConstraintKind;

  procedure Expect(const AEType: string; const ACat: TDbErrorCategory;
    const ATag: string);
  begin
    ClassifyRedis(AEType, LCat, LCon);
    Check((LCat = ACat) and (LCon = dckNone), ATag);
  end;

begin
  Expect('ERR', decSyntax, 'classify ERR syntax');
  Expect('WRONGPASS', decAuth, 'classify WRONGPASS auth');
  Expect('NOAUTH', decAuth, 'classify NOAUTH auth');
  Expect('MOVED', decConnection, 'classify MOVED connection');
  Expect('ASK', decConnection, 'classify ASK connection');
  Expect('CLUSTERDOWN', decConnection, 'classify clusterdown');
  Expect('READONLY', decConnection, 'classify readonly replica');
  Expect('LOADING', decCapacity, 'classify LOADING capacity');
  Expect('BUSY', decCapacity, 'classify BUSY capacity');
  Expect('MASTERDOWN', decCapacity, 'classify masterdown');
  Expect('EXECABORT', decTransaction, 'classify EXECABORT txn');
  Expect('NOSCRIPT', decNotSupported, 'classify NOSCRIPT');
  Expect('CROSSSLOT', decSyntax, 'classify CROSSSLOT syntax');
  Expect('TRYAGAIN', decCapacity, 'classify TRYAGAIN capacity');
  Expect('WRONGTYPE', decConstraint, 'classify WRONGTYPE constraint');
  Expect('BUSYGROUP', decUnknown, 'classify BUSYGROUP under');
  Expect('TOTALLY-MADE-UP', decUnknown, 'classify unknown word');
  Expect('', decUnknown, 'classify empty word');
end;

begin
  T := TTestSuite.Create('nextpas.core.db.redis.base');
  T.Test('kind ordinal pin', @TestKindOrdinal);
  T.Test('encode command', @TestEncodeCommand);
  T.Test('plan command', @TestPlanCommand);
  T.Test('plan fail-fast', @TestPlanFailFast);
  T.Test('parse scalars', @TestParseScalars);
  T.Test('parse arrays', @TestParseArrays);
  T.Test('incremental parse', @TestIncrementalParse);
  T.Test('parse fail-fast', @TestParseFailFast);
  T.Test('error type', @TestErrorType);
  T.Test('info field value', @TestInfoFieldValue);
  T.Test('classify redis table', @TestClassifyRedisTable);
  if not T.Run then Halt(1);
end.

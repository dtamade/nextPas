program test_db_array_bind;

{ V3-C2 参数级批量绑定门禁（IDbArrayBinding，pg unnest 数组展开路径）：
    1 离线诚实契约：sqlite SupportsArrayBinding=False ⇔ 探测 nil
    2 pg 能力互证：布尔 True ⇔ 查询对象探测非 nil
    3 int64 往返：含 Low/High(Int64) 边界
    4 文本转义酷刑：引号/反斜杠/换行/制表/花括号串/空串/中文，
      双数组列（pos+text）对齐写入逐行比对
    5 NULL 掩码往返：掩码 True 行 = NULL 且值被忽略；空串 ≠ NULL
    6 bool 往返含 NULL
    7 double 往返：最短往返逐位还原 + NaN/±Inf 原生输出
    8 标量+数组混绑：常量列 × 展开列
    9 RETURNING 读回展开行
   10 Reset 重臂：同批重执行行数翻倍
   11 空批（rows=0）无操作成功
   12 千行对齐健全性
   13-19 fail-fast 组：BeginBind 缺失 / 负行数 / 长度失配 / 掩码失配 /
      重复列 / NUL 元素 / 覆盖不全（全部客户端侧拒绝）
  live 段需本地 PG（NEXTPAS_PG_TEST_CONN），缺省静默跳过；
  heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.os.env,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.db,
  nextpas.core.db.base,
  nextpas.core.db.intf,
  nextpas.core.db.factory.register.sqlite,
  nextpas.core.db.factory.register.pg;

type
  { fail-fast 用例种类 }
  TArrayBindFault = (
    fkNoBeginBind, fkNegativeRows, fkMisalignedLen, fkMaskMismatch,
    fkDupColumn, fkNulElement, fkPartialCoverage
  );

var
  T: TTestSuite;
  GPgConn: string;

function Scalar(AConn: IDbConnection; const ASql: string): string;
var
  LQ: IDbQuery;
begin
  Result := '';
  LQ := AConn.Query(ASql);
  if LQ.Step then
    Result := LQ.GetText(0);
  LQ := nil;
end;

function FirstDouble(AConn: IDbConnection; const ASql: string): Double;
var
  LQ: IDbQuery;
begin
  Result := 0;
  LQ := AConn.Query(ASql);
  if LQ.Step then
    Result := LQ.GetDouble(0);
  LQ := nil;
end;

{ IEEE-754 位模式构造特殊值（避免引入 Math 依赖）：
  quiet NaN / +Inf / -Inf }
function BitsAsDouble(const ABits: UInt64): Double;
begin
  PUInt64(@Result)^ := ABits;
end;

{ ---- 1 离线诚实契约 ---- }

procedure TestSqliteHonestAbsence;
var
  LConn: IDbConnection;
  LCap: IDbCapabilities;
  LB: IDbArrayBinding;
begin
  LConn := ConnectSqlite(':memory:');
  try
    Supports(LConn, IDbCapabilities, LCap);
    Check(LCap <> nil, 'sqlite caps present');
    Check(not LCap.SupportsArrayBinding, 'sqlite array-binding=False');
    LB := DbArrayBinding(LConn.Query('SELECT 1'));
    Check(LB = nil, 'sqlite probe=nil (honest absence)');
  finally
    LConn := nil;
  end;
end;

{ ---- 2 pg 能力互证 ---- }

procedure TestPgCapabilityInterlock;
var
  LConn: IDbConnection;
  LCap: IDbCapabilities;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
begin
  if GPgConn = '' then
  begin
    WriteLn('array-bind capability skipped (NEXTPAS_PG_TEST_CONN not set)');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    Supports(LConn, IDbCapabilities, LCap);
    Check(LCap <> nil, 'pg caps present');
    Check(LCap.SupportsArrayBinding, 'pg array-binding=True');
    LQ := LConn.Query('SELECT 1');
    LB := DbArrayBinding(LQ);
    Check((LB <> nil) = LCap.SupportsArrayBinding,
      'interlock: flag ⇔ query probe');
    LQ := nil;
  finally
    LConn := nil;
  end;
end;

{ ---- 3 int64 往返（含边界值）---- }

procedure TestPgInt64Roundtrip;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbInt64Array;
begin
  if GPgConn = '' then
  begin
    WriteLn('int64 roundtrip skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_i64');
    LConn.Exec('CREATE TABLE t_ab_i64 (v BIGINT)');
    SetLength(LV, 5);
    LV[0] := 1;
    LV[1] := -2;
    LV[2] := High(Int64);
    LV[3] := Low(Int64);
    LV[4] := 0;
    LQ := LConn.Query(
      'INSERT INTO t_ab_i64 SELECT * FROM unnest(?::bigint[])');
    LB := DbArrayBinding(LQ);
    Check(LB <> nil, 'probe non-nil');
    LB.BeginBind(Length(LV));
    LB.BindInt64Column(1, LV);
    Check(not LQ.Step, 'insert yields no rows');
    LB := nil;
    LQ := nil;
    CheckEqual('5', Scalar(LConn, 'SELECT count(*) FROM t_ab_i64'),
      'rowcount=5');
    { sum = 1 - 2 + High + Low + 0 = -2 }
    CheckEqual('-2', Scalar(LConn, 'SELECT sum(v)::text FROM t_ab_i64'),
      'sum incl int64 extremes');
  finally
    LConn := nil;
  end;
end;

{ ---- 4 文本转义酷刑（双数组列对齐写入）---- }

procedure TestPgTextEscapingTorture;
const
  CN = 9;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LT: TDbStringArray;
  LP: TDbInt64Array;
  I: Integer;
  LWant: array[0..CN - 1] of string;
begin
  if GPgConn = '' then
  begin
    WriteLn('text escaping skipped');
    Exit;
  end;
  LWant[0] := 'plain';
  LWant[1] := 'has "quotes"';
  LWant[2] := 'back\slash';
  LWant[3] := 'line'#10'break';
  LWant[4] := 'tab'#9'here';
  LWant[5] := '{1,2}';
  LWant[6] := '';
  LWant[7] := '中文✓';
  LWant[8] := '"';
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_txt');
    LConn.Exec('CREATE TABLE t_ab_txt (pos INT, v TEXT)');
    SetLength(LT, CN);
    SetLength(LP, CN);
    for I := 0 to CN - 1 do
    begin
      LP[I] := I + 1;
      LT[I] := LWant[I];
    end;
    LQ := LConn.Query(
      'INSERT INTO t_ab_txt SELECT * FROM unnest(?::int[], ?::text[])');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(CN);
    LB.BindInt64Column(1, LP);
    LB.BindTextColumn(2, LT);
    while LQ.Step do ;
    LB := nil;
    LQ := nil;
    CheckEqual(IntToStr(CN),
      Scalar(LConn, 'SELECT count(*) FROM t_ab_txt'), 'torture rowcount');
    for I := 0 to CN - 1 do
      CheckEqual(LWant[I],
        Scalar(LConn, 'SELECT v FROM t_ab_txt WHERE pos = ' + IntToStr(I + 1)),
        'torture elem ' + IntToStr(I + 1) + ' byte-exact');
  finally
    LConn := nil;
  end;
end;

{ ---- 5 NULL 掩码往返；空串与 NULL 可区分 ---- }

procedure TestPgNullMaskRoundtrip;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LP: TDbInt64Array;
  LN: TDbInt64Array;
  LMN: TDbBoolArray;
  LT: TDbStringArray;
  LMT: TDbBoolArray;
  I: Integer;
begin
  if GPgConn = '' then
  begin
    WriteLn('null mask roundtrip skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_null');
    LConn.Exec('CREATE TABLE t_ab_null (pos INT, t TEXT, n BIGINT)');
    SetLength(LP, 4);  SetLength(LT, 4);  SetLength(LN, 4);
    SetLength(LMT, 4); SetLength(LMN, 4);
    for I := 0 to 3 do
    begin
      LP[I] := I + 1;
      LT[I] := IntToStr(I);
      LN[I] := (I + 1) * 10;
      LMT[I] := False;
      LMN[I] := False;
    end;
    { t 列：第 3 行 NULL；第 2 行是空串（非 NULL）——两者可区分 }
    LT[1] := '';
    LMT[2] := True;
    { n 列：第 1 行 NULL，掩码优先于被忽略的值 }
    LMN[0] := True;
    LN[0] := 999999;
    LQ := LConn.Query('INSERT INTO t_ab_null SELECT * FROM unnest(' +
      '?::int[], ?::text[], ?::bigint[])');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(4);
    LB.BindInt64Column(1, LP);
    LB.BindTextColumn(2, LT, LMT);
    LB.BindInt64Column(3, LN, LMN);
    while LQ.Step do ;
    LB := nil;
    LQ := nil;

    CheckEqual('', Scalar(LConn,
      'SELECT t FROM t_ab_null WHERE pos = 2'), 'row2 empty string kept');
    Check(Scalar(LConn, 'SELECT t IS NULL FROM t_ab_null WHERE pos = 3')
      = 't', 'row3 text IS NULL (mask wins)');
    Check(Scalar(LConn, 'SELECT n IS NULL FROM t_ab_null WHERE pos = 1')
      = 't', 'row1 int IS NULL (ignored value not leaked)');
    CheckEqual('40', Scalar(LConn,
      'SELECT n FROM t_ab_null WHERE pos = 4'), 'row4 value intact');
  finally
    LConn := nil;
  end;
end;

{ ---- 6 bool 往返含 NULL ---- }

procedure TestPgBoolRoundtrip;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbBoolArray;
  LM: TDbBoolArray;
begin
  if GPgConn = '' then
  begin
    WriteLn('bool roundtrip skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_bool');
    LConn.Exec('CREATE TABLE t_ab_bool (v BOOLEAN)');
    SetLength(LV, 3);
    SetLength(LM, 3);
    LV[0] := True;  LM[0] := False;
    LV[1] := False; LM[1] := False;
    LV[2] := False; LM[2] := True;    { NULL 行，值被忽略 }
    LQ := LConn.Query(
      'INSERT INTO t_ab_bool SELECT * FROM unnest(?::boolean[])');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(3);
    LB.BindBoolColumn(1, LV, LM);
    while LQ.Step do ;
    LB := nil;
    LQ := nil;
    CheckEqual('true', Scalar(LConn,
      'SELECT v::text FROM t_ab_bool WHERE v IS TRUE'), 'true row');
    CheckEqual('false', Scalar(LConn,
      'SELECT v::text FROM t_ab_bool WHERE v IS FALSE'), 'false row');
    CheckEqual('1', Scalar(LConn,
      'SELECT count(*) FROM t_ab_bool WHERE v IS NULL'), 'one null row');
  finally
    LConn := nil;
  end;
end;

{ ---- 7 double 往返：最短往返应逐位还原；NaN/±Inf 原生输出 ---- }

procedure TestPgDoubleRoundtrip;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbDoubleArray;
begin
  if GPgConn = '' then
  begin
    WriteLn('double roundtrip skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_f8');
    LConn.Exec('CREATE TABLE t_ab_f8 (pos BIGINT, v DOUBLE PRECISION)');
    SetLength(LV, 6);
    LV[0] := 0.1;
    LV[1] := -2.5e-8;
    LV[2] := 1e300;
    LV[3] := BitsAsDouble($7FF8000000000000);   { quiet NaN }
    LV[4] := BitsAsDouble($7FF0000000000000);   { +Inf }
    LV[5] := BitsAsDouble($FFF0000000000000);   { -Inf }
    LQ := LConn.Query('INSERT INTO t_ab_f8 ' +
      'SELECT u.ord, u.v FROM unnest(?::float8[]) ' +
      'WITH ORDINALITY AS u(v, ord)');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(6);
    LB.BindDoubleColumn(1, LV);
    while LQ.Step do ;
    LB := nil;
    LQ := nil;
    { 数值三行：同位模式精确比较（Schubfach 最短往返保证无损） }
    Check(FirstDouble(LConn, 'SELECT v FROM t_ab_f8 WHERE pos = 1') = LV[0],
      'double exact roundtrip 0.1');
    Check(FirstDouble(LConn, 'SELECT v FROM t_ab_f8 WHERE pos = 2') = LV[1],
      'double exact roundtrip -2.5e-8');
    Check(FirstDouble(LConn, 'SELECT v FROM t_ab_f8 WHERE pos = 3') = LV[2],
      'double exact roundtrip 1e300');
    { PG 语义：NaN = 'NaN'::float8 比较为真（NaN 与自身相等） }
    CheckEqual('1', Scalar(LConn,
      'SELECT count(*) FROM t_ab_f8 WHERE v = ''NaN''::float8'), 'NaN out');
    CheckEqual('1', Scalar(LConn,
      'SELECT count(*) FROM t_ab_f8 WHERE v = ''Infinity''::float8'),
      '+Inf out');
    CheckEqual('1', Scalar(LConn,
      'SELECT count(*) FROM t_ab_f8 WHERE v = ''-Infinity''::float8'),
      '-Inf out');
  finally
    LConn := nil;
  end;
end;

{ ---- 8 标量+数组混绑 ---- }

procedure TestPgMixedScalarAndArray;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbInt64Array;
  I: Integer;
begin
  if GPgConn = '' then
  begin
    WriteLn('mixed bind skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_mix');
    LConn.Exec('CREATE TABLE t_ab_mix (tag TEXT, k BIGINT)');
    SetLength(LV, 4);
    for I := 0 to 3 do
      LV[I] := (I + 1) * 11;
    LQ := LConn.Query('INSERT INTO t_ab_mix ' +
      'SELECT ?, x FROM unnest(?::bigint[]) AS u(x)');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(4);
    LQ.BindText(1, 'const');            { 标量列 }
    LB.BindInt64Column(2, LV);          { 展开列 }
    while LQ.Step do ;
    LB := nil;
    LQ := nil;
    CheckEqual('4', Scalar(LConn, 'SELECT count(*) FROM t_ab_mix'),
      'mix rowcount');
    CheckEqual('const', Scalar(LConn,
      'SELECT DISTINCT tag FROM t_ab_mix'), 'scalar column broadcast');
  finally
    LConn := nil;
  end;
end;

{ ---- 9 RETURNING 读回展开行 ---- }

procedure TestPgReturningReadback;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbInt64Array;
  LSeen: Int64;
  I: Integer;
begin
  if GPgConn = '' then
  begin
    WriteLn('returning readback skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_ret');
    LConn.Exec('CREATE TABLE t_ab_ret (v BIGINT)');
    SetLength(LV, 5);
    for I := 0 to 4 do
      LV[I] := I + 1;
    LQ := LConn.Query('INSERT INTO t_ab_ret SELECT * ' +
      'FROM unnest(?::bigint[]) RETURNING v');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(5);
    LB.BindInt64Column(1, LV);
    LSeen := 0;
    while LQ.Step do
      Inc(LSeen, LQ.GetInt64(0));
    LB := nil;
    LQ := nil;
    Check(LSeen = 15, 'RETURNING cursor saw expanded rows (sum=15)');
    CheckEqual('15',
      Scalar(LConn, 'SELECT sum(v)::text FROM t_ab_ret'), 'table sum=15');
  finally
    LConn := nil;
  end;
end;

{ ---- 10 Reset 重臂：同批重执行 ---- }

procedure TestPgResetReexecute;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbInt64Array;
begin
  if GPgConn = '' then
  begin
    WriteLn('reset re-exec skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_re');
    LConn.Exec('CREATE TABLE t_ab_re (v BIGINT)');
    SetLength(LV, 3);
    LV[0] := 7; LV[1] := 8; LV[2] := 9;
    LQ := LConn.Query(
      'INSERT INTO t_ab_re SELECT * FROM unnest(?::bigint[])');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(3);
    LB.BindInt64Column(1, LV);
    while LQ.Step do ;
    LQ.Reset;
    while LQ.Step do ;                  { 同参数重跑 }
    LB := nil;
    LQ := nil;
    CheckEqual('6', Scalar(LConn, 'SELECT count(*) FROM t_ab_re'),
      're-exec doubles rows (params persist)');
  finally
    LConn := nil;
  end;
end;

{ ---- 11 空批无操作成功 ---- }

procedure TestPgEmptyBatchNoOp;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbInt64Array;
begin
  if GPgConn = '' then
  begin
    WriteLn('empty batch skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_empty');
    LConn.Exec('CREATE TABLE t_ab_empty (v BIGINT)');
    SetLength(LV, 0);
    LQ := LConn.Query(
      'INSERT INTO t_ab_empty SELECT * FROM unnest(?::bigint[])');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(0);
    LB.BindInt64Column(1, LV);          { 空数组长度 0 = 行数 0，合法 }
    Check(not LQ.Step, 'empty batch no rows');
    LB := nil;
    LQ := nil;
    CheckEqual('0', Scalar(LConn, 'SELECT count(*) FROM t_ab_empty'),
      'empty batch inserted nothing');
  finally
    LConn := nil;
  end;
end;

{ ---- 12 千行对齐健全性 ---- }

procedure TestPgThousandRowsSanity;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV: TDbInt64Array;
  I: Integer;
begin
  if GPgConn = '' then
  begin
    WriteLn('1000-row sanity skipped');
    Exit;
  end;
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_1k');
    LConn.Exec('CREATE TABLE t_ab_1k (v BIGINT)');
    SetLength(LV, 1000);
    for I := 0 to 999 do
      LV[I] := (I * 7) mod 1000003;
    LQ := LConn.Query(
      'INSERT INTO t_ab_1k SELECT * FROM unnest(?::bigint[])');
    LB := DbArrayBinding(LQ);
    LB.BeginBind(1000);
    LB.BindInt64Column(1, LV);
    while LQ.Step do ;
    LB := nil;
    LQ := nil;
    CheckEqual('1000', Scalar(LConn, 'SELECT count(*) FROM t_ab_1k'),
      '1000 rows landed');
    Check(Scalar(LConn, 'SELECT count(*) FROM t_ab_1k WHERE v % 7 = 0')
      <> '', 'spot readback non-empty');
  finally
    LConn := nil;
  end;
end;

{ ---- 13-19 fail-fast 组 ---- }

function FaultMessage(AFault: TArrayBindFault): string;
var
  LConn: IDbConnection;
  LQ: IDbQuery;
  LB: IDbArrayBinding;
  LV3: TDbInt64Array;
  LV5: TDbInt64Array;
  LM2: TDbBoolArray;
  LT3: TDbStringArray;
begin
  Result := '';
  if GPgConn = '' then
    Exit;
  SetLength(LV3, 3);
  SetLength(LV5, 5);
  SetLength(LM2, 2);
  SetLength(LT3, 3);
  LConn := ConnectPostgres(GPgConn);
  try
    LConn.Exec('DROP TABLE IF EXISTS t_ab_fault');
    LConn.Exec('CREATE TABLE t_ab_fault (a BIGINT, b BIGINT)');
    LQ := LConn.Query('INSERT INTO t_ab_fault ' +
      'SELECT * FROM unnest(?::bigint[], ?::bigint[])');
    LB := DbArrayBinding(LQ);
    try
      case AFault of
        fkNoBeginBind:
          LB.BindInt64Column(1, LV3);
        fkNegativeRows:
          LB.BeginBind(-1);
        fkMisalignedLen:
          begin
            LB.BeginBind(5);
            LB.BindInt64Column(1, LV3);       { 3 ≠ 5 }
          end;
        fkMaskMismatch:
          begin
            LB.BeginBind(3);
            LB.BindInt64Column(1, LV3, LM2);  { 掩码 2 ≠ 3 }
          end;
        fkDupColumn:
          begin
            LB.BeginBind(3);
            LB.BindInt64Column(1, LV3);
            LB.BindInt64Column(1, LV3);       { 同批同列第二次 }
          end;
        fkNulElement:
          begin
            LB.BeginBind(3);
            LT3[1] := 'bad'#0'elem';
            LB.BindTextColumn(2, LT3);        { NUL 在字面量编码期拒绝 }
          end;
        fkPartialCoverage:
          begin
            LB.BeginBind(3);
            LB.BindInt64Column(1, LV3);
            while LQ.Step do ;                { 参数 2 未绑定 → Step 抛 }
          end;
      end;
    except
      on E: EDbError do
        Result := E.Message;
    end;
    LB := nil;
    LQ := nil;
  finally
    LConn := nil;
  end;
end;

procedure CheckFault(const AName: string; AFault: TArrayBindFault;
  const AMsgPart: string);
begin
  if GPgConn = '' then
  begin
    WriteLn(AName, ' skipped');
    Exit;
  end;
  Check(Pos(AMsgPart, FaultMessage(AFault)) > 0,
    AName + ': rejected with "' + AMsgPart + '"');
end;

{ fail-fast 七例薄包装（T.Test 需要无参过程指针）。消息断言取稳定
  子串：适配器侧消息统一以 'array bind: ' 开头。 }

procedure TestFaultNoBeginBind;
begin
  CheckFault('fault missing BeginBind', fkNoBeginBind, 'BeginBind');
end;

procedure TestFaultNegativeRows;
begin
  CheckFault('fault negative rows', fkNegativeRows, 'array bind');
end;

procedure TestFaultMisalignedLen;
begin
  CheckFault('fault misaligned length', fkMisalignedLen, 'BeginBind');
end;

procedure TestFaultMaskMismatch;
begin
  CheckFault('fault mask mismatch', fkMaskMismatch, 'array bind');
end;

procedure TestFaultDupColumn;
begin
  CheckFault('fault duplicate column', fkDupColumn, 'array bind');
end;

procedure TestFaultNulElement;
begin
  CheckFault('fault NUL element', fkNulElement, 'NUL');
end;

procedure TestFaultPartialCoverage;
begin
  CheckFault('fault partial coverage', fkPartialCoverage, 'array bind');
end;

begin
  RegisterSqliteDriver;
  GPgConn := GetEnvironmentVariable('NEXTPAS_PG_TEST_CONN');
  T := TTestSuite.Create('nextpas.core.db.array.bind');
  T.Test('sqlite honest absence', @TestSqliteHonestAbsence);
  T.Test('pg capability interlock', @TestPgCapabilityInterlock);
  T.Test('pg int64 roundtrip', @TestPgInt64Roundtrip);
  T.Test('pg text escaping torture', @TestPgTextEscapingTorture);
  T.Test('pg null mask roundtrip', @TestPgNullMaskRoundtrip);
  T.Test('pg bool roundtrip', @TestPgBoolRoundtrip);
  T.Test('pg double roundtrip', @TestPgDoubleRoundtrip);
  T.Test('pg mixed scalar and array', @TestPgMixedScalarAndArray);
  T.Test('pg returning readback', @TestPgReturningReadback);
  T.Test('pg reset re-execute', @TestPgResetReexecute);
  T.Test('pg empty batch noop', @TestPgEmptyBatchNoOp);
  T.Test('pg thousand rows sanity', @TestPgThousandRowsSanity);
  T.Test('fault: missing BeginBind', @TestFaultNoBeginBind);
  T.Test('fault: negative rows', @TestFaultNegativeRows);
  T.Test('fault: misaligned length', @TestFaultMisalignedLen);
  T.Test('fault: mask length mismatch', @TestFaultMaskMismatch);
  T.Test('fault: duplicate column', @TestFaultDupColumn);
  T.Test('fault: NUL element', @TestFaultNulElement);
  T.Test('fault: partial coverage', @TestFaultPartialCoverage);
  if not T.Run then Halt(1);
end.

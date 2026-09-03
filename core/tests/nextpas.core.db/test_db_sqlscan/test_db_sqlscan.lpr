program test_db_sqlscan;

{ V3-C6 SQL 词法扫描共享引擎契约测试（L1 单源直连，db.sqlscan 已物理删除）：
    直连 nextpas.core.text.sqlscan 单源，消除历史 db.sqlscan 一跳 inline 间接（CONTRACT §2.20）；
    1  pg 美元渲染：裸 ? 顺序编号 / 显式 ?N 直映不扰动顺序计数
    2  混合编号不变式：?2,?,?3,? → 槽位 [2,1,3,2]（黄金语料钉死）
    3  字面量/注释吞占位符：'' 转义串、双引号标识符、行/块注释内
       的 ? 不计数不改写；块注释逐字节保形
    4  mysql 方言：反引号标识符 + # 行注释保护；" 视为普通代码
    5  odbc 方言：[ ] 标识符 ]] 转义保护
    6  方言隔离：pg 方言下反引号/#/[ 均为代码字符（词素不误伤）
    7  计数面：$N 最大索引跳过字面量/注释；?-SQL 与裸 $ 计 0
    8  装饰面：命中 N>0 才追加后缀；源数字回显（超 Int32 数字串
       原样保留）；字面量内的 $N 不装饰
    9  四包装互洽：count == len(Slots)；question 槽位最大值 ==
       MaxPlaceholderIndex('?')
   10  身份往返：无占位符 SQL 三方言逐字节原样
   11  边界：空串 / 孤占位符 / 尾随 '-' / CRLF 注释 / 多字节 UTF-8
       字节透传
   12  容量增长：>8 个占位符槽位计划完整（初始容量翻倍路径）
  全部离线纯函数断言，无 IO 无线程。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.text.utils,
  nextpas.core.test,
  nextpas.core.text.sqlscan;

var
  T: TTestSuite;

function CountOccur(const AHay: string; const ANeedle: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  P := Pos(ANeedle, AHay);
  while P > 0 do
  begin
    Inc(Result);
    P := PosEx(ANeedle, AHay, P + Length(ANeedle));
  end;
end;

procedure TestPgDollarRender;
begin
  CheckEqual('select * from t where a = $1 and b = $2',
    SqlScanRenderDollar('select * from t where a = ? and b = ?',
      SQLSCAN_PG));
  { 显式 ?N 直映 }
  CheckEqual('select $7', SqlScanRenderDollar('select ?7', SQLSCAN_PG));
  { 裸 ? 续接顺序计数：显式后 Seq 不受扰动 }
  CheckEqual('select $1,$2,$5,$3',
    SqlScanRenderDollar('select ?,?,?5,?', SQLSCAN_PG));
end;

procedure TestMixedNumberingInvariant;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
  LCnt: Integer;
begin
  { 黄金语料 case 1 的字节级钉子：物理序→逻辑号映射（直连 L1 零跳转发） }
  LCnt := SqlScanTranslateQuestion('select ?2, ?, ?3, ?', SQLSCAN_MYSQL,
    LRw, LSlots);
  CheckEqual(Int64(4), Int64(LCnt));
  CheckEqual('select ?, ?, ?, ?', LRw);
  CheckEqual(Int64(2), Int64(LSlots[0]));
  CheckEqual(Int64(1), Int64(LSlots[1]));
  CheckEqual(Int64(3), Int64(LSlots[2]));
  CheckEqual(Int64(2), Int64(LSlots[3]));
end;

procedure TestLiteralsAndCommentsSwallow;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
begin
  { '' 转义串内的 ? 不计数 }
  SqlScanTranslateQuestion('select ''it''''s ? lit'' as x, ?', SQLSCAN_PG,
    LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  CheckEqual('select ''it''''s ? lit'' as x, ?', LRw);
  { 双引号标识符内的 ? 保护 }
  SqlScanTranslateQuestion('select "weird ? ident" as x, ?', SQLSCAN_PG,
    LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  { 行注释内的 ? 吞掉；注释体逐字节保形（含 #13） }
  SqlScanTranslateQuestion(
    'select ? from t' + #13#10 + '-- crlf ? comment' + #13#10,
    SQLSCAN_PG, LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  CheckEqual('select ? from t' + #13#10 + '-- crlf ? comment' + #13#10,
    LRw);
  { 未终止块注释吞到 EOF；历史怪癖成文：块注释起始 '/' 不落
    输出（五份原实现同款，黄金语料 case10 钉死），'*' 起始体照录 }
  SqlScanTranslateQuestion('select 1 /* unterminated ? block', SQLSCAN_PG,
    LRw, LSlots);
  CheckEqual(Int64(0), Int64(Length(LSlots)));
  CheckEqual('select 1 * unterminated ? block', LRw);
  { 终止块注释同样保形（除起始 '/'）}
  SqlScanTranslateQuestion('select 1 /* block ? comment */ , ?', SQLSCAN_PG,
    LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  CheckEqual('select 1 * block ? comment */ , ?', LRw);
end;

procedure TestMysqlDialect;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
begin
  { 反引号标识符与 # 注释保护 }
  SqlScanTranslateQuestion('select `tick ? x` as a, # c ?' + #10 + ', ?',
    SQLSCAN_MYSQL, LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  CheckEqual('select `tick ? x` as a, # c ?' + #10 + ', ?', LRw);
  { 反引号无转义：`` 即退出 }
  SqlScanTranslateQuestion('select `a``b` , ?', SQLSCAN_MYSQL,
    LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
end;

procedure TestOdbcDialect;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
begin
  { ] ] 转义保护；括号内 ? 不计 }
  SqlScanTranslateQuestion('select [a]]b?] as x, ?', SQLSCAN_ODBC,
    LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  CheckEqual('select [a]]b?] as x, ?', LRw);
end;

procedure TestDialectIsolation;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
begin
  { pg 方言下反引号/#/[ 都是代码字符：其中的 ? 参与计数 }
  SqlScanTranslateQuestion('select `x` , ?', SQLSCAN_PG, LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  SqlScanTranslateQuestion('select [a?] , ?', SQLSCAN_PG, LRw, LSlots);
  CheckEqual(Int64(2), Int64(Length(LSlots)));
  { mysql 方言下 " 是代码字符 }
  SqlScanTranslateQuestion('select "a?" , ?', SQLSCAN_MYSQL,
    LRw, LSlots);
  CheckEqual(Int64(2), Int64(Length(LSlots)));
end;

procedure TestMaxPlaceholderIndex;
begin
  { 注释里的 $N 不计 }
  CheckEqual(Int64(7), Int64(SqlScanMaxPlaceholderIndex(
    'select $7 /* $9 */ -- $3' + #10 + ' $2', SQLSCAN_PG, '$')));
  { ?-SQL 计 0（字符不匹配）}
  CheckEqual(Int64(0), Int64(SqlScanMaxPlaceholderIndex(
    'select * from t where a = ? and b = ?', SQLSCAN_PG, '$')));
  { 裸 $ 贡献 0；混合取最大 }
  CheckEqual(Int64(5), Int64(SqlScanMaxPlaceholderIndex(
    'select $ $5', SQLSCAN_PG, '$')));
  { 纯裸 $ → 0 }
  CheckEqual(Int64(0), Int64(SqlScanMaxPlaceholderIndex(
    'select $$ $$', SQLSCAN_PG, '$')));
end;

procedure TestDecorate;
begin
  { 命中且 N>0 才追加 }
  CheckEqual('values ($1, $2::bytea)',
    SqlScanDecorate('values ($1, $2)', SQLSCAN_PG, '$', [2], '::bytea'));
  { 多索引命中 }
  CheckEqual('values ($1::bytea, $2, $3::bytea)',
    SqlScanDecorate('values ($1, $2, $3)', SQLSCAN_PG, '$', [1, 3],
      '::bytea'));
  { N=0（裸 $）永不装饰 }
  CheckEqual('values ($)', SqlScanDecorate('values ($)', SQLSCAN_PG,
    '$', [0], '::bytea'));
  { 前导零编号源样回显且按数值命中 }
  CheckEqual('select $007::bytea',
    SqlScanDecorate('select $007', SQLSCAN_PG, '$', [7], '::bytea'));
  { 超 Int32 数字串回绕失配 → 不装饰（黄金 case24 同款回绕）}
  CheckEqual('select $100000000000000000000',
    SqlScanDecorate('select $100000000000000000000', SQLSCAN_PG, '$',
      [1], '::bytea'));
  { 字面量内的 $N 不装饰 }
  CheckEqual('select ''$1''',
    SqlScanDecorate('select ''$1''', SQLSCAN_PG, '$', [1], '::bytea'));
end;

procedure TestWrapperConsistency;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
  LCnt, I: Integer;
const
  SAMPLE = 'update t set a=?, b=?2 where id=?3 returning c, d, ?';
begin
  LCnt := SqlScanTranslateQuestion(SAMPLE, SQLSCAN_ODBC, LRw, LSlots);
  CheckEqual(Int64(LCnt), Int64(Length(LSlots)));
  { MaxPlaceholderIndex 记原始编号（?2→2、?3→3、裸 ?→0）：
    显式编号样本上手值 3；count(4) 与之分离是设计语义 }
  CheckEqual(Int64(3),
    Int64(SqlScanMaxPlaceholderIndex(SAMPLE, SQLSCAN_ODBC, '?')));
  { 美元形态占位符个数与槽位计划一致，且每个逻辑编号出现 }
  LRw := SqlScanRenderDollar(SAMPLE, SQLSCAN_ODBC);
  CheckEqual(Int64(LCnt), Int64(CountOccur(LRw, '$')));
  for I := 0 to High(LSlots) do
    Check(Pos('$' + IntToStr(LSlots[I]), LRw) > 0,
      'slot ' + IntToStr(LSlots[I]) + ' present in dollar render');
end;

procedure TestIdentityRoundTrip;
const
  SAMPLES: array[0..2] of string = (
    'select a.b, c + 1 from tbl where x = ''lit'' and y = 3.14',
    '-- leading comment' + #10 + 'select 1 - 2 / 3',
    'insert into t (a, b) values (1, 2)');
var
  I: Integer;
begin
  for I := 0 to High(SAMPLES) do
  begin
    CheckEqual(SAMPLES[I], SqlScanRenderDollar(SAMPLES[I], SQLSCAN_PG));
    CheckEqual(SAMPLES[I], SqlScanRenderDollar(SAMPLES[I], SQLSCAN_MYSQL));
    CheckEqual(SAMPLES[I], SqlScanRenderDollar(SAMPLES[I], SQLSCAN_ODBC));
  end;
end;

procedure TestEdgeCases;
var
  LRw: string;
  LSlots: TSqlScanSlotArray;
begin
  { 空串 }
  CheckEqual(Int64(0), Int64(SqlScanTranslateQuestion('', SQLSCAN_PG,
    LRw, LSlots)));
  CheckEqual('', LRw);
  CheckEqual(Int64(0), Int64(Length(SqlScanRenderDollar('', SQLSCAN_PG))));
  { 孤占位符 }
  CheckEqual('$1', SqlScanRenderDollar('?', SQLSCAN_PG));
  CheckEqual('$', SqlScanRenderDollar('$', SQLSCAN_PG));
  { 尾随 '-' 单字符是代码 }
  CheckEqual('a-', SqlScanRenderDollar('a-', SQLSCAN_PG));
  { 多字节 UTF-8 字节透传（中文注释体不破坏扫描）}
  SqlScanTranslateQuestion('select ? -- 中文注释？' + #10, SQLSCAN_PG,
    LRw, LSlots);
  CheckEqual(Int64(1), Int64(Length(LSlots)));
  CheckEqual('select ? -- 中文注释？' + #10, LRw);
end;

procedure TestCapacityGrowth;
var
  LRw, LExpected: string;
  LSlots: TSqlScanSlotArray;
  LCnt, I: Integer;
  LSql: string;
begin
  { 17 个占位符跨越初始容量 8 的两轮翻倍 }
  LSql := 'select ';
  for I := 1 to 17 do
  begin
    if I > 1 then
      LSql += ',';
    LSql += '?';
  end;
  LCnt := SqlScanTranslateQuestion(LSql, SQLSCAN_MYSQL, LRw, LSlots);
  CheckEqual(Int64(17), Int64(LCnt));
  CheckEqual(Int64(17), Int64(Length(LSlots)));
  for I := 0 to 16 do
    CheckEqual(Int64(I + 1), Int64(LSlots[I]));
  LExpected := 'select ';
  for I := 1 to 17 do
  begin
    if I > 1 then
      LExpected += ',';
    LExpected += '$' + IntToStr(I);
  end;
  CheckEqual(LExpected, SqlScanRenderDollar(LSql, SQLSCAN_PG));
end;

begin
  T := TTestSuite.Create('nextpas.core.db.sqlscan');
  T.Test('pg dollar render sequential+explicit', @TestPgDollarRender);
  T.Test('mixed numbering invariant (golden case 1)', @TestMixedNumberingInvariant);
  T.Test('literals and comments swallow placeholders', @TestLiteralsAndCommentsSwallow);
  T.Test('mysql dialect backtick/hash protection', @TestMysqlDialect);
  T.Test('odbc dialect bracket protection', @TestOdbcDialect);
  T.Test('dialect lexeme isolation', @TestDialectIsolation);
  T.Test('max placeholder index counting', @TestMaxPlaceholderIndex);
  T.Test('decorate suffix on match', @TestDecorate);
  T.Test('wrapper cross-consistency', @TestWrapperConsistency);
  T.Test('identity roundtrip without placeholders', @TestIdentityRoundTrip);
  T.Test('edge cases empty/lone/CRLF/multibyte', @TestEdgeCases);
  T.Test('slot capacity growth beyond initial cap', @TestCapacityGrowth);
  if not T.Run then Halt(1);
end.

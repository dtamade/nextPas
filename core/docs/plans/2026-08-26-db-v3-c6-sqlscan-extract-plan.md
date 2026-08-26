# V3-C6 SQL 词法扫描共享引擎抽取（nextpas.core.db.sqlscan）

> 2026-08-26。依据：roadmap §7.2 抽取候选登记的触发条件已满足——
> 「出现第四份复制」实测为**第五份**：pg.adapter / mysql.adapter /
> odbc.adapter 三份 `TranslatePlaceholders*` 变体 +
> pg.conn 的 `MaxParamIndex` 与 `AppendByteaCasts`（其头注自证
> 「扫描状态机与 MaxParamIndex 完全一致……保证索引对齐」）。同一
> 字符串/标识符/注释状态机在 db 家族内复制五次，任何词法缺陷修复都
> 要人肉同步四处文件。

## 1. 目标

单一纯函数单元 `nextpas.core.db.sqlscan` 收敛全部五份状态机；
四个消费方改为薄委托，公开签名与语义逐字节不变。

## 2. 设计

### 引擎词法集（方言记录）

| 词素 | pg | mysql | odbc |
|---|---|---|---|
| `'…'` 字符串（'' 转义） | ✅ | ✅ | ✅ |
| `"…"` 标识符（"" 转义） | ✅ | —（mysql 默认 " 非 ident） | ✅ |
| `` `…` `` 标识符（无转义） | — | ✅ | — |
| `[…]` 标识符（]] 转义） | — | — | ✅ |
| `--` 行注释（#10 终止） | ✅ | ✅ | ✅ |
| `#` 行注释 | — | ✅ | — |
| `/* … */` 块注释 | ✅ | ✅ | ✅ |

受控边界维持成文：dollar-quote 体不识别（与现状一致）；行注释仅
#10 终止；占位符数字累加不加溢出防护（忠实原实现）。

### 公开面

```pascal
TDbSqlScanDialect = record
  DoubleQuoteIdents, BacktickIdents, BracketIdents,
  HashComments: Boolean;
end;
DBSQLSCAN_PG / DBSQLSCAN_MYSQL / DBSQLSCAN_ODBC 常量;

SqlScanTranslateQuestion(Sql, Dialect, out Rewritten, out Slots): Count;
  { mysql/odbc：'?' 保形改写 + 物理序→逻辑号槽位计划 }
SqlScanRenderDollar(Sql, Dialect): string;
  { pg：'?'→'$N'（裸 ? 走顺序 Seq，显式 ?N 不扰动 Seq），无槽位分配 }
SqlScanMaxPlaceholderIndex(Sql, Dialect, PhChar): Integer;
  { pg.conn 计数面：跳过字面量/注释取最大 N，零输出分配 }
SqlScanDecorate(Sql, Dialect, PhChar, Indexes, Suffix): string;
  { pg.conn AppendByteaCasts 面命中 $N 原位追加后缀（::bytea cast） }
```

四者共享一个私有引擎过程（单遍扫 + IStringBuilder 追加，与现行实现
同数量级零额外分配；dollar/count 路径不建槽数组保 J1 开销比判据）。

## 3. 验收判据

- **黄金语料零漂移**：换牙前用临时 harness 把四消费方的现存实现对
  语料库（≥60 条含酷刑样本）的输出落盘；换牙后同一语料走新包装，
  逐条 diff 必须全等。
- 新门禁 `test_db_sqlscan`：方言矩阵 × 字节级断言（转义/注释吞占位/
  混合编号顺序不变式/空串/裸占位符/CRLF/多字节透传）+ 四包装互洽
  （count==len(Slots)、decorate 后 max 不变等）全绿 heaptrc 0。
- 回归：pg / mysql_adapter / odbc_adapter / unified / conformance /
  stmt_cache / array_bind（bytea cast 直接受害者）七门全绿。
- 文档：roadmap C 线表新增 C6 行 + §7.2 回填 ✅ + README 门禁速查 +
  CONTRACT §2.20 简节；本文件回填实现状态。

## 4. 边界与不做

- 不改任何统一层契约语义；适配器对外函数名/签名不动（测试与消费方
  零感知）。
- redis.adapter 的 RESP 分词器是不同领域（非 SQL），不入本片。
- sqlite 原生 '?' 无翻译需求，不接。

## 5. 实现状态（2026-08-26 当日落地回填）

**已落地**：`nextpas.core.db.sqlscan` 单元（四公开面共享单遍私有引擎）
+ 四消费方薄委托换牙 + test_db_sqlscan 十二组门禁全绿 heaptrc 0 +
CONTRACT §2.20 / README 门禁速查行 / 路线图 C 线表 C6 行与 §7.2 回填。

**零漂移实证链**：
1. 换牙前临时 harness（五份原实现 × 30 案例语料，含混合编号、超
   Int32 编号、未终止字面量/注释、CRLF、多字节等酷刑样本）输出落盘
   `/tmp/sqlscan_golden.txt`；
2. 换牙后新引擎重放同语料 → `diff` **逐字节全等**；
3. 黄金语料同时钉死两处历史怪癖并随契约成文：块注释起始 `/` 不落
   输出；超 Int32 编号回绕记槽（1661992960 实录）。

**门禁偏差登记**：首跑 6 failed 全部为测试断言误写（身份往返样例含
块注释起始、孤 `$` 断言写反、'$N' 长度估算忽略多位数编号、显式编号
样本误比 max==count 等），逐条按黄金实证语义修正——引擎本体零改动。

**家族回归**（2026-08-26，七门全绿）：pg 13 / mysql_adapter 6+1skip /
odbc_adapter 6+1skip / array_bind 19 / stmt_cache 12 / unified 18 /
conformance 2 passed, 0 failed（array_bind 真机 pg 段实证 Decorate
::bytea 路径；mysql/odbc live 段环境门控 Skip 如实登记）。

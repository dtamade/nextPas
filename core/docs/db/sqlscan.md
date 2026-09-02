# nextpas.core.db.sqlscan — SQL 词法扫描共享域契约

**模块**：`nextpas.core.db.sqlscan.{base,intf,pas}` thin re-export `nextpas.core.text.sqlscan` 真源  
**层级**：L1 `text.sqlscan` 真源（L3 家族 thin 转发，零逻辑，依赖 L0）  
**四件套**：`sqlscan.base` ← `sqlscan.intf` ← `sqlscan` 门面（thin，`inline` 转发）  
**对应主契约**：`CONTRACT.md` §1.1 词法扫描行 + §2.20 V3-C6 共享引擎

## 职责

- 家族内五份复制的“字符串/标识符/注释状态机”（pg/mysql/odbc 三份占位符翻译 + pg.conn 计数 + pg.conn bytea 装饰）收敛为 L1 单一纯函数单元 `text.sqlscan`
- 方言词法集记录化：`SQLSCAN_PG/MYSQL/ODBC` ↔ `DBSQLSCAN_*` 别名（`DoubleQuote/Backtick/Bracket/HashComments` 四布尔）
- 四公开面共享单遍引擎：`SqlScanTranslateQuestion`/`SqlScanRenderDollar`/`SqlScanMaxPlaceholderIndex`/`SqlScanDecorate`，公开签名零变化，黄金语料逐字节零漂移

## 性能

- 单遍状态机 `bytes.ops`/`text.builder` 单源，`O(n)` 线性；`RenderDollar`/`MaxIndex` 不建槽数组（热路径零额外分配）
- `inline` 转发零分配：thin 层 `inline` 透传真源，无额外缓冲复制
- 受控边界成文保留（`dollar-quote` 不识别、`#` 仅 `#10` 终止、占位符数字无溢出防护、`/` 起块注释不落输出）

## 稳定性

- 换牙零漂移：原实现 30 案例黄金语料落盘 → 新引擎重放 diff 全等（含 `[2,1,3,2]` 混合编号、超 `Int32` 回绕、未终止字面量）
- 资源零持有：纯函数无句柄，析构无残留；`heaptrc 0 unfreed`：`test_db_sqlscan` 12 组 + 七门回归全绿

## Owner 边界

- 真源在 `nextpas.core.text.sqlscan`（L1），本域仅 thin 转发，不复制 `bytes.ops`；缺能力反哺 `text.builder`/`text.conv`

# nextpas.core.db.trace — 观测钩子域契约

**模块**：`nextpas.core.db.trace.{base,intf,pas}` 聚合连接级 `OnAcquire/OnQuery/OnError` + 512 摘要截断  
**层级**：L3 家族（四后端插桩，池侧 `FlushDiagnostics` 独立；依赖 L0–L2 `sync`/`platform.time`）  
**四件套**：`trace.base` ← `trace.intf` ← `trace` 门面 ← `TDbTraceHub` 聚合实现  
**对应主契约**：`CONTRACT.md` §1.1 观测钩子行 + §2.12 `IDbTraceListener` + §2.10 能力矩阵

## 职责

- `IDbTraceListener` 同步回调面：`OnAcquire`（`SetListener` 非 nil 时锁外补发一次，1:1 配 `OnRelease`）、`OnQuery(DurationMs, Summary)`（成功执行一次，Exec 全程/查询首 Step 窗口）、`OnError(Category, Summary)`（`EDbError.Category` 直透）
- `IDbTraceControl.SetListener(nil)` 关闭；`DbTraceControl(Conn)` 统一探测，未实现 `nil`
- 摘要 `DB_TRACE_SQL_SUMMARY_MAX=512` 折叠连续空白为单空格并截断，占位符原文保留、参数值不入摘要

## 性能

- 默认零成本：无监听器时 `BeginOp` 返回 `False`，不取时钟、不做摘要、不发事件
- `inline` 无监听器快路径；零拷贝摘要：`DbTraceSqlSummary` 按截断上限封顶缓冲、`Move` 零多余分配，`platform_monotonic_ns` 单调时钟
- 借 `bytes.ops` 单源空白折叠（`#9/#10/#13/#32`），不重复实现

## 稳定性

- 硬边界：锁内快照接口引用，锁外回调（C3 析构链教训推广），`FlushDiagnostics` 安全点 `RemoveOnCancel` 不在析构链内触用户代码
- `OnRelease` 于连接析构内必发一次；池化租约借还不在本面（走 `pool` 诊断）
- `heaptrc 0 unfreed`：`test_db_trace` 离线 sqlite 全量 + pg 真机段 + mysql/odbc live 探针

## Owner 边界

- 缺能力先反哺 `platform.time`（单调时钟）、`bytes.ops`（空白折叠）、`sync`（mutex），不绕边界自造时钟

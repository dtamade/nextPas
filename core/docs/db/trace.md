# nextpas.core.db — 观测钩子分册（trace）

**模块路径**：`core/src/nextpas.core.db.trace.pas` + `core/src/nextpas.core.db.intf.pas`（`IDbTraceListener`/`IDbTraceControl`）
**层级**：L2 观测（仅依赖 `base`/`intf`，四后端同构）
**Owner**：core-db lane
**单源**：本册为 `CONTRACT.md §2.12` 单源分册，细节沉至本册，索引与分治不变量仍以 `CONTRACT.md` 为准；`db.trace` 枢纽 `TDbTraceHub` 单源实现见 `nextpas.core.db.trace.pas`。
**最后更新**：2026-09-02（匠心分册落地：CONTRACT 单源逾 880 行解耦，本册独立承载观测契约）

---

## 1. 定向

`IDbTraceListener` 是连接级同步回调面（生命周期 + 执行事件），经可选能力接口 `IDbTraceControl` 挂载；门面 `DbTraceControl(Conn)` 统一探测，未实现返回 `nil`（无值用 `nil` 表达）。默认零成本、无后台线程，诚实同步模型。

- **复用 bytes.ops 单源**：诊断串经 `StringToBytes` 单 `Move` 零拷贝（`BYTES_OPS_SINGLE_SOURCE` 单源，见 `pool`/`trace` 共享纪律）。
- **性能**：无监听器时 `BeginOp` 返回 `False`，不取时钟、不做摘要、不发事件；`DbTraceSqlSummary` 纯函数 `inline` 折叠截断（`DB_TRACE_SQL_SUMMARY_MAX=512`）。
- **稳定性**：枢纽内部锁范围内绝不触碰用户代码（C3 硬边界推广：锁内快照接口引用，锁外回调）；`OnRelease` 在连接析构内准确配对。

## 2. 契约（CONTRACT §2.12 单源）

`IDbTraceListener` 是连接级同步回调面（生命周期 + 执行事件），经可选能力接口 `IDbTraceControl` 挂载；门面 `DbTraceControl(Conn)` 统一探测，未实现返回 `nil`（无值用 `nil` 表达）。语义契约：

- **挂载即补发**：`OnAcquire` 在 `SetListener` 非 `nil` 时同步发出一次，语义 = "本连接已建立"——建连先于挂载的常驻场景（池内层连接等）由此可观测；`OnRelease` = 连接关闭（析构内）。同一监听器的一次挂载对应恰好一次 `OnRelease`。池化租约借还不在本面——池侧观测走 `db.pool` 既有诊断（C3）。
- **执行窗口**：`OnQuery(DurationMs, Summary)` = 成功执行一次。`Exec` 计全程（查询级选项版的 `SET`/恢复机制开销不计入）；查询计"首个 `Step` 全程"（绑定编组 + 服务端执行 + 首行——惰性执行模型的统一执行窗口，无结果集执行也是成功执行），同周期后续 `Step` 不再发，`Reset` 后重新武装。
- **失败路径**：`OnError(Category, Summary)` 于执行路径抛 `EDbError` 时发出，此时不发 `OnQuery`；`Category` 直透 `EDbError.Category` 归一枚举。绑定索引/未绑定参数等编程错误不产生事件（`fail-fast` 先于观测窗口）。
- **摘要**：`Summary` 折叠连续空白为单空格并截断到 `DB_TRACE_SQL_SUMMARY_MAX`（512，防日志爆炸）；占位符原文保留，参数值从不进入摘要（注入安全）。
- **成本模型**：默认零成本——无监听器时不取时钟、不做摘要、不发事件。回调在调用线程同步执行（诚实模型，无后台线程）；实现不得重入本连接。枢纽内部锁范围内绝不触碰用户代码（C3 硬边界推广：锁内快照接口引用，锁外回调）。

四后端接线形态：`sqlite`/`pg`/`mysql` 逐路径插桩（`Exec` 两重载各单点、查询对象首 `Step`；`pg` 的 B2 超时恢复钩与追踪互不影响），`odbc` 收敛于 `DoExec`/`DoQuery` 单点天然无双发。门禁 `test_db_trace`：离线 `sqlite` 全量契约 + 摘要纯函数 + `pg` 真机段（`decSyntax` 直透、占位符保真、`opts` 超时路径）+ `mysql`/`odbc` live 探针（各自 `env` 门控）。

## 3. 实现不变量

- 共享枢纽 `TDbTraceHub`（`nextpas.core.db.trace.pas`）：`SetListener` 锁外同步补发 `OnAcquire`（§2.12）；`BeginOp` 单调时钟 `platform_monotonic_ns` 取点；`NotifyQuery`/`NotifyError` 锁内快照、锁外回调（C3 硬边界）。
- `DbTraceSqlSummary` 纯函数：连续空白（`#9/#10/#13/#32`）折叠为单空格 + 截断 512，尾空格去除，纯函数离线可测。
- 四后端同构接线：`sqlite`/`pg`/`mysql`/`odbc`/`redis` 均已插桩（`redis` 见 `redis.md`），观测钩子与 `pool` 池诊断正交（租约借还不经本面）。

## 4. 依赖与分治不变量

- 仅依赖 `nextpas.core.db.base`/`intf`，不依赖具体后端；L2 观测零上向。
- 业务以 `CONTRACT` 为准、缺能力先反哺 `owner`（观测能力反哺 `trace`，时间反哺 `nextpas.core.time` 单源）。

## 5. 门禁

```bash
make focused FOCUS=core/tests/nextpas.core.db/test_db_trace   # 观测钩子全量契约 + 摘要纯函数 + pg/mysql/odbc 真机段
```

含 `heaptrc 0 unfreed` 硬门禁；`DB_TRACE_SQL_SUMMARY_MAX=512` 与占位符保真见 `test_db_trace` 离线段。

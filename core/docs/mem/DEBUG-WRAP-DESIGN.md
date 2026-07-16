# DEBUG 包装链设计（M2-5）

**状态**: Implemented (M2-5 最小可用：fail / stats / tracking / sentinel)
**关联**: [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §3.4 Tier-2、§8 M2-5
**原则**: 热路径零成本；诊断只叠在 **IAllocator 插件面**，不绑架 `DefaultHeap`。
**实现**: `nextpas.core.mem.debug_wrap` + `DefaultAllocator` 惰性解析；gate `test_debug_wrap`。

---

## 1. 目标体验

```bash
NEXTPAS_MEM_DEBUG=sentinel,leak,stats
```

业务代码仍写：

```pascal
LAlloc := DefaultAllocator;  // 或注入的 IAllocator
P := LAlloc.GetMem(n);
```

无需改调用点即可获得越界/泄漏/统计。

---

## 2. 与双轨的关系（硬边界）

| 轨道 | DEBUG 默认行为 | 原因 |
|------|----------------|------|
| `DefaultHeap` / 过程式 `GetMem` | **不包装** | 热路径禁止 interface 间接调用与诊断税 |
| `DefaultAllocator: IAllocator` | **可包装** | 本就是注入/组合面 |

已实现（opt-in，默认关）：

```bash
NEXTPAS_MEM_DEBUG=tracking,stats
NEXTPAS_MEM_HEAP_DEBUG=1   # 显式同意：过程式 GetMem/FreeMem 改走 DefaultAllocator 诊断链（慢）
# 或 dev 安全 profile（无 DEBUG token 时自动 inject tracking+sentinel）：
NEXTPAS_MEM_HEAP_SAFETY=1
# Arena 适配器 FreeMem(non-nil) 改为 raise（默认仍 no-op）：
NEXTPAS_MEM_ARENA_STRICT=1
```

- 默认 **关**：过程式 `GetMem` 不进 DEBUG 链（热路径零税）。
- 显式 **开**（`HEAP_DEBUG` 或 `HEAP_SAFETY`）：过程式 `GetMem`/`FreeMem`/`AllocMem`/`ReallocMem` 经 `DefaultAllocator`，可被 tracking/stats/sentinel 观察。
- `HEAP_SAFETY` 且无 DEBUG token：自动 `tracking+sentinel`（dev 双 free profile）。
- `DefaultHeap` **永远**不包装；Scorecard / 生产热路径仍用裸 Growing。
- `IsMemHeapDebugEnabled` = HEAP_DEBUG **或** HEAP_SAFETY（过程式路由开关）。
- `GetMemStats` / `FormatMemStats`：`heap_debug` / `debug` / `debug_process` / `debug_coverage_gap`（F1 假阴性可见）。

---

## 3. 环境变量语法

```text
NEXTPAS_MEM_DEBUG=<token>[,<token>...]
NEXTPAS_MEM_HEAP_DEBUG=<truthy>     # 1/true/yes/on
NEXTPAS_MEM_HEAP_SAFETY=<truthy>    # process route + default tracking,sentinel
NEXTPAS_MEM_ARENA_STRICT=<truthy>   # arena IAllocator FreeMem(non-nil) raises
```

| Token | 包装器 | 顺序建议（外→内） |
|-------|--------|-------------------|
| `fail` / `oom` | `TFailAllocator` / `TOomAllocator` | 最外（最先看到请求） |
| `stats` | `TStatsAllocator` / `TAllocStatsAllocator` | 外 |
| `sampling` | `TSamplingAllocator` | 中 |
| `logging` | `TLoggingAllocator` | 中 |
| `tracking` / `leak` | `TTrackingAllocator` / `TLeakReportAllocator` | 内贴近真实后端 |
| `sentinel` | `TSentinelAllocator` | 最内（紧贴真实块） |
| `guard` | `TGuardAllocator` | 与 sentinel 互斥或二选一 |
| `debug` | `TDebugAllocator` | 来源记录，可与 tracking 并存 |

**解析规则**：

- 大小写不敏感；未知 token → 忽略并计入 `IgnoredTokens`
- **Enabled 仅当至少有一个已知 token**（`fail`/`oom`/`stats`/`tracking`/`leak`/`sentinel`）
- 空值 / 未设置 / 纯空白 / 仅未知 token → 无包装，`DefaultAllocator` = Growing IAllocator 单例
- 顺序：固定规范序（上表），**不**按用户书写序乱叠（可预测、可测）
- 同一语义别名合并（`leak` ≡ `tracking` 的一种配置）

规范链（示例 `sentinel,leak,stats`）：

```text
Caller
  → Stats
    → Tracking/Leak
      → Sentinel
        → Growing IAllocator (GetGrowingIAllocator / DefaultHeap)
```

---

## 4. API 形状（已落地）

```pascal
{ nextpas.core.mem.debug_wrap / mem.default re-export }
function DefaultAllocator: IAllocator;
  // ResolveDefaultAllocator：有已知 token 则包装链根，否则 GetGrowingIAllocator

function GetDebugWrapConfig: TMemDebugWrapConfig;
function GetDebugWrapTracking: TTrackingAllocator;  // nil if unused
function GetDebugWrapStats: TStatsAllocator;        // nil if unused
procedure ResetDebugWrapForTests;                   // 仅测试
procedure ParseMemDebugEnv(const AEnv; out AConfig); // 纯解析
```

约束：

- 包装链在 **进程首次** `DefaultAllocator` 时惰性构建，之后单例
- 不在 `DefaultHeap` / Growing 初始化路径上读 env（避免启动抖动）
- 测试可 `ResetDebugWrapForTests` + `platform_env_set` 再触发重建
- 固定叠层（外→内）：fail → stats → tracking → sentinel → RTL
- 已实现 token：`fail`/`oom`、`stats`、`tracking`/`leak`、`sentinel`
- 未实现（保留设计位）：sampling、logging、guard、debug

**不做**：

- 不把 DEBUG 链做成 `IAllocator` 默认热路径
- 不在 Growing 内部插钩子
- 不引入新的全局锁热路径（构建链仅一次 CAS）

---

## 5. 验收

| # | 用例 | 状态 |
|---|------|------|
| 1 | 无 env：`DefaultAllocator` = Growing IAllocator 身份；`DefaultHeap` 行为不变 | ✅ `test_debug_wrap` |
| 2 | `NEXTPAS_MEM_DEBUG=tracking`：分配未 Free → ActiveAllocCount/HasLeaks | ✅ |
| 3 | `sentinel`：经 `DefaultAllocator` 可检出 double-free；越界写细节见 `test_sentinel` | ✅ |
| 4 | `stats`：有可查询计数；热路径 Scorecard 不强制过此路径 | ✅ |
| 5 | 未知 token 不崩溃 | ✅ |
| 6 | `DefaultHeap.GetMem` 在任意 DEBUG env 下仍直调 Growing | ✅ |

Focused gate：

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_debug_wrap
```

---

## 6. 与 Month 3 的衔接

- 上层 HTTP/compiler 热路径继续 `DefaultHeap` / Arena
- 调试构建或测试夹具用 `DefaultAllocator` + env
- 未来 `MemStats` 可从 stats 包装器或 Growing 可观测字段双源导出，但 DEBUG 链不是 MemStats 唯一来源

---

## 7. 实现优先级

1. Token 解析 + 固定叠层顺序 + 单测 — ✅
2. `tracking` + `sentinel` 最小可用 — ✅
3. `stats` — ✅
4. 文档写入 README/API-GUIDE 一小节 — ✅
5. `fail`/`oom` 层已挂接（FailAt=0 默认不失败）— ✅
6. `NEXTPAS_MEM_HEAP_DEBUG` 过程式 GetMem 并入 DefaultAllocator 诊断链 — ✅
   - `IsMemHeapDebugEnabled` 门面可发现；`FormatMemStats` 含 `heap_debug=` + DEBUG 时 `debug_active_*`/`debug_allocs`/`debug_frees`
   - doctor `mem-process-stats` 直接吃 `FormatMemStats`（环境变量即时生效）
   - Gate：`test_debug_wrap` + `test_usability_guardrails` FormatMemStats 双轨
7. CI / verify 联调配方 — ✅
   - `scripts/stage0-heap-debug-env-recipe.sh`：fresh process doctor 断言默认 `heap_debug=n`、
     `NEXTPAS_MEM_HEAP_DEBUG=1` → `heap_debug=y`、`NEXTPAS_MEM_DEBUG=stats` 插件轨独立
   - 入口：`make stage0-heap-debug-recipe`（CI rebuild 后；`verify_local` 复用）
8. F1 覆盖缺口字段 — ✅ `debug_process` / `debug_coverage_gap`（DEBUG-only → gap=y）
9. F3 `NEXTPAS_MEM_HEAP_SAFETY` — ✅ process 路由 + 默认 tracking/sentinel
10. F4 `NEXTPAS_MEM_ARENA_STRICT` — ✅ Arena IAllocator FreeMem dual-mode

`DefaultHeap` 语义未改：DEBUG 只叠 `DefaultAllocator`；HEAP_DEBUG/SAFETY 也不绑架 `DefaultHeap` 本体。

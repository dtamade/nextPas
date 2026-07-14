# DEBUG 包装链设计（M2-5）

**状态**: Design  
**关联**: [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §3.4 Tier-2、§8 M2-5  
**原则**: 热路径零成本；诊断只叠在 **IAllocator 插件面**，不绑架 `DefaultHeap`。

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

可选后续（非本设计必交付）：

```bash
NEXTPAS_MEM_HEAP_DEBUG=1   # 显式同意：过程式 GetMem 改走诊断链（慢）
```

默认 **关**。Scorecard / 生产默认堆永远以裸 Growing 为准。

---

## 3. 环境变量语法

```text
NEXTPAS_MEM_DEBUG=<token>[,<token>...]
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

- 大小写不敏感；未知 token → 忽略并（可选）stderr 警告一次  
- 空值 / 未设置 → 无包装，`DefaultAllocator` = RTL 单例  
- 顺序：固定规范序（上表），**不**按用户书写序乱叠（可预测、可测）  
- 同一语义别名合并（`leak` ≡ `tracking` 的一种配置）

规范链（示例 `sentinel,leak,stats`）：

```text
Caller
  → Stats
    → Tracking/Leak
      → Sentinel
        → RTL (GetRtlAllocator)
```

---

## 4. API 形状（实现切片）

```pascal
{ mem.default 或 mem.debug_bootstrap }
function DefaultAllocator: IAllocator;
  // 若 env 解析结果非空：返回包装链根
  // 否则：GetRtlAllocator

function GetDebugWrapConfig: TMemDebugWrapConfig;  // 测试/可观测
procedure ResetDebugWrapForTests;                   // 仅测试
```

约束：

- 包装链在 **进程首次** `DefaultAllocator` 时惰性构建，之后单例  
- 不在 `DefaultHeap` / Growing 初始化路径上读 env（避免启动抖动）  
- 测试可 `ResetDebugWrapForTests` + `platform_env_set` 再触发重建  

**不做**：

- 不把 DEBUG 链做成 `IAllocator` 默认热路径  
- 不在 Growing 内部插钩子  
- 不引入新的全局锁热路径（构建链仅一次）

---

## 5. 验收（实现时）

| # | 用例 |
|---|------|
| 1 | 无 env：`DefaultAllocator` 仍为 RTL 身份；`DefaultHeap` 行为不变 |
| 2 | `NEXTPAS_MEM_DEBUG=tracking`：分配未 Free → LeakCheck 可检出 |
| 3 | `sentinel`：可检出简单越界写（既有 sentinel 契约） |
| 4 | `stats`：有可查询计数；热路径 Scorecard 不强制过此路径 |
| 5 | 未知 token 不崩溃 |
| 6 | `DefaultHeap.GetMem` 在任意 DEBUG env 下仍直调 Growing（除非显式 HEAP_DEBUG） |

Focused gate 建议：`core/tests/nextpas.core.mem/test_debug_wrap/`（实现时新建）。

---

## 6. 与 Month 3 的衔接

- 上层 HTTP/compiler 热路径继续 `DefaultHeap` / Arena  
- 调试构建或测试夹具用 `DefaultAllocator` + env  
- 未来 `MemStats` 可从 stats 包装器或 Growing 可观测字段双源导出，但 DEBUG 链不是 MemStats 唯一来源  

---

## 7. 实现优先级

1. Token 解析 + 固定叠层顺序 + 单测  
2. `tracking` + `sentinel` 最小可用  
3. `stats`  
4. 文档写入 README/API-GUIDE 一小节  
5. （可选）`NEXTPAS_MEM_HEAP_DEBUG`  

本文件只定设计；落地前不改 `DefaultHeap` 语义。

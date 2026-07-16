# mem 错误策略（冻结）

**状态**: Frozen（2026-07-15）
**权威**: 本文件 + [CONTRACT.md](CONTRACT.md) + [API-GUIDE.md](API-GUIDE.md)
**门禁**: `test_contract_matrix`、`test_usability_guardrails`

本文件冻结 **“何时返回 nil / False，何时抛异常”**，避免调用方在 `if P = nil` 与 `try/except` 之间猜。

---

## 1. 两条铁律

1. **资源不足是正常运行时条件** → 用返回值表达（`nil` / `False`），**不抛**。
   包括：堆 OOM、Arena 容量不足、固定池已满。
2. **编程错误** → 抛 `EAllocError` / `EOutOfMemory`（带 `TAllocError` 码）。
   包括：双重释放、非法指针、不支持的 Realloc、非法对齐参数、size 溢出构造参数。

热路径（`DefaultHeap` / 过程式 `GetMem`）在无 DEBUG 包装时：

- OOM → `nil`
- 双 free / 坏指针 → **未定义行为（UB）**；需要可检测时用 `NEXTPAS_MEM_DEBUG`（**仅插件面**）或显式 `TSentinelAllocator` / `TTrackingAllocator`。

### 1.1 可操作的 Try* 形态（不改变铁律）

同一后端、同一 nil 语义，只是把 `P <> nil` 写成 `Boolean` 出口，方便直线错误分支：

| API | 成功 | 失败（资源不足 / 非法） |
|-----|------|-------------------------|
| `TryGetMem` / `TryAllocMem` | True + ptr | False + nil |
| `TryReallocMem` | True + ptr（`ANewSize=0` 也 True） | False + nil |
| `TryFreeMem` | True（size-class 恢复后 sized free） | False（nil / foreign） |
| `TryArenaAlloc` | True + ptr | False + nil（含 AArena=nil） |
| `TCompilerUnitScope.TryAlloc` | True + ptr | False + nil（含未 BeginScope） |

```pascal
if not TryGetMem(64, P) then
  Exit; // OOM — 不抛
if not TryFreeMem(P) then
  ; // 非本堆指针；已知 size 时优先 FreeMem(P, Size)
```

---

## 2. 按表面分类

| 表面 | 资源不足 | 编程错误 | 备注 |
|------|----------|----------|------|
| `IAllocator` / 过程式堆 | `GetMem`/`AllocMem`/`ReallocMem` → **nil** | 诊断包装器：双 free / 坏指针 → **raise** | 基实现（RTL/Growing）双 free = UB |
| `IArena` | `Alloc*` → **nil** | 非法对齐等 → 通常 **nil**（不 throw） | 不对 Arena 块 `FreeMem` |
| 固定池 `Acquire`/`Release` | 池满 → **nil** / **False** | 双 free / 非本池指针 → **raise** | |
| `IMemoryPool` / Slab `GetMem` | OOM/满 → **nil** | 非法 free → **raise** | |
| 构造 / 配置 | — | 溢出、非法 capacity → **raise** | 如 `AllocArray` 乘法溢出 |

---

## 3. `TAllocError` 使用

| 码 | 语义 | 典型路径 |
|----|------|----------|
| `aeOutOfMemory` | 真内存不足或构造时无法取得后备 | 构造失败 raise；热 GetMem 仍优先 nil |
| `aeCapacityExhausted` | 固定容量耗尽（若实现区分） | 池 |
| `aeInvalidPointer` | 指针不属于本分配器 | Free/Release |
| `aeDoubleFree` | 重复释放 | Free/Release |
| `aeReallocNotSupported` | Traits 声明不支持仍调用 | Arena 适配器等 |
| `aeInvalidLayout` / `aeAlignmentNotSupported` | 大小/对齐非法 | 对齐 API |
| `aeSentinelCorrupted` / `aeChecksumFailure` | 缓冲区破坏 | DEBUG sentinel |
| `aeInternalError` | 后端/库加载失败等 | mimalloc/mmap |

消息格式（推荐，新建 raise 点必须遵守）：

```text
Type.Method: short reason (key=value, ...)
```

示例：`TLocalBlockPool.Release: double free detected`

---

## 4. DEBUG 与错误可见性

| 机制 | 覆盖 | 不覆盖 |
|------|------|--------|
| `NEXTPAS_MEM_DEBUG` | `DefaultAllocator` 插件链 | `DefaultHeap` / 过程式 `GetMem` |
| `TTrackingAllocator` 等 | 被包装的 `IAllocator` | 未注入的堆 |
| `GetMemStats` | DefaultHeap 计数 + 可选 DEBUG 字段 | 不是 sanitizer |

**禁止**在文档或示例中暗示“设 env 即可查所有 `GetMem` 泄漏”。

---

## 5. 变更纪律

- 改本策略 = **显式 breaking 设计变更**，需更新本文件、CONTRACT、API-GUIDE、契约测试。
- 新 Tier-0 实现必须声明落在上表哪一行，并接入 `test_contract_matrix` 对应行。
- 禁止：热路径 GetMem 因 OOM 抛异常；禁止：池满用未文档化的 raise 代替 False/nil。

# text.builder inject-grow sized-free 契约：跨 owner 决策建议书

> 日期：2026-08-10
> 涉及 owner：`nextpas.core.mem`（sized-free 契约 I1）、`nextpas.core.text`（实现）、
> `codex/compiler-system`（stage0 自举约束，2026-08-09 M2 B 系列合入引入）
> 相关红点：`consumer-audit-contracts` I1（`text.builder must use ReallocMemOf on inject grow`）FAIL
> 性质：跨 owner 契约冲突，非简单回归。决策记录：mem owner 批准（2026-08-10），
> 落地为 CA-016（接口面重实现）。

---

## 1. 问题

`core/tests/nextpas.core.mem/test_usability_guardrails/check_consumer_audit_contracts.sh` I1 检查要求：

```sh
need_file "$SRC/nextpas.core.text.builder.pas"
need_grep "$SRC/nextpas.core.text.builder.pas" 'ReallocMemOf' \
  'text.builder must use ReallocMemOf on inject grow (I1)'
```

当前 `nextpas.core.text.builder.pas` **不含** `ReallocMemOf`（`1d8dedab5` M2 B 系列合入后），I1 FAIL。
这是 mem 模块正式 gate（`test_usability_guardrails`）的组成部分，红点曾在 main 与 mem lane 同时存在。

## 2. 已确认事实（2026-08-10 只读调研）

| # | 事实 | 证据 |
|---|------|------|
| F1 | text.builder 原两条 grow 路径：`FAllocator.ReallocMem(FBuf, LNewCap)`（注入 allocator）与 `System.ReallocMem(FBuf, LNewCap)`（无 allocator） | `text.builder.pas:208-214`（落地前） |
| F2 | 替换原因（B 系列注释）：`Avoid nextpas.core.mem facade (arena/pool graph; hangs / false cycles under stage0)` | `text.builder.pas` |
| F3 | text.builder **interface 区已 uses** `nextpas.core.mem.intf` + `nextpas.core.mem.allocator.base`（均为 IAllocator 类型所需），stage0 下已安全使用 | `text.builder.pas` |
| F4 | `nextpas.core.mem.intf` 仅 uses `mem.base`；`nextpas.core.mem.allocator.base` 仅 uses `mem.intf` —— **均无 arena/pool graph** | 两者 `uses` 段 |
| F5 | `nextpas.core.mem`（门面）interface uses 含 `mem.arena.base/intf` 等，implementation uses `mem.pool.allocator` —— arena/pool graph 所在 | `mem.pas` |
| F6 | 门面版 `ReallocMemOf` 厚语义：`AAllocator=nil/DefaultAllocator` 时走 `DefaultHeap.ReallocMem(ptr, old, new)`（sized，`FreeMemOfAllowsSizedHeapFree` 门控），其余 allocator 委托 `AAllocator.ReallocMem` | `mem.pas:489-503` |
| F7 | **16 个单元同时 uses `nextpas.core.mem` 与 `nextpas.core.mem.allocator.base`**（bytes.builder、collections.*、json/toml/yaml/csv/ini/xml 等）→ 若把同名 `ReallocMemOf` 下沉到 allocator.base，这 16 个单元全部 duplicate identifier | grep 全仓 |
| F8 | IAllocator 接口**冻结五方法**（GetMem/AllocMem/ReallocMem/FreeMem + 判等），不可新增 sized 方法 | `mem.intf.pas` |
| F9 | 检查机制为整文件正则（`grep -Eq 'ReallocMemOf'`），注释亦命中 | `check_consumer_audit_contracts.sh` `need_grep()` |
| F10 | summary 中 **CA-013 已被占用**（`CA-003/CA-013 FIXED — text.builder 等 sized free`） | `CONSUMER-AUDIT-SUMMARY-2026-07-17.md` |
| F11 | 仓库已有 WAIVED 先例（CA-011 product-table keepers），格式：`**WAIVED**（原因）` | 同上 |

## 3. 约束矩阵

| 约束 | 含义 | 影响 |
|------|------|------|
| S0 | stage0（FPC 编译 nextpas 编译器）下 text.builder 不得 uses `nextpas.core.mem` 门面（graph 挂死） | 排除"恢复 uses mem.pas" |
| S1 | 禁止同名函数并存（16 个并存单元） | 排除"ReallocMemOf 下沉到 allocator.base" |
| S2 | IAllocator 接口冻结 | 排除"给接口加 sized 方法" |
| S3 | 现有 mem.pas 调用方语义不得变（json/toml/yaml 的 DefaultHeap sized 路径） | 门面厚版必须保留 |
| S4 | I1 检查意图：防 inject-grow 无尺寸化退化 | 改守卫需等价防退化 |

## 4. 方案对比

| 方案 | 动作 | 满足 I1 字面 | stage0 安全 | 代价/风险 | 结论 |
|------|------|:---:|:---:|------|:---:|
| A. 恢复 uses mem.pas | 撤回 B 系列改动，用门面 ReallocMemOf | ✅ | ❌ graph 回归 | 破坏 stage0 自举 | 否决 |
| C. 同名下沉 allocator.base | ReallocMemOf 移入 allocator.base | ✅ | ✅ | 16 单元 duplicate identifier | 否决 |
| D. 自维护 size 表（仿 json.parser） | text.builder 记 FCap 并调门面 FreeMemOf | ✅ | ❌ 仍需门面 | 引入 graph + 重写 | 否决 |
| **E. 接口面 sized helper（不同名）** | `mem.allocator.base` 增加 `ReallocMemSized`/`FreeMemSized`（allocator≠nil→接口方法；nil→System），text.builder 用之，I1 改守卫 | ✅（更新后） | ✅ | 需 mem owner 接受新 helper + 检查更新 | **落地** |

## 5. 落地内容（2026-08-10，mem owner 批准）

1. `nextpas.core.mem.allocator.base` 新增接口面 sized helper：
   - `ReallocMemSized(const AAllocator: IAllocator; APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer`
   - `FreeMemSized(const AAllocator: IAllocator; APtr: Pointer)`
   - 语义：allocator≠nil 委托接口方法（分配器内部跟踪 size）；nil 走 FPC RTL System 堆（自跟踪）。
     与门面 ReallocMemOf 分层：**不触碰 DefaultHeap / arena / pool graph**（stage0 安全）。
2. `nextpas.core.text.builder.pas`：`Grow` 双路径统一为 `ReallocMemSized(FAllocator, FBuf, FCap, LNewCap)`（行为与落地前完全一致：nil→System.ReallocMem in-place / allocator→接口方法）。
3. `check_consumer_audit_contracts.sh` I1 改替代守卫：
   - text.builder 必须含 `ReallocMemSized|ReallocMemOf`（接口面 sized helper）
   - 必须 `uses nextpas.core.mem.intf`（保持接口面分配）
   - **禁止** `uses nextpas.core.mem`（行首 uses 正则，防 stage0 回归）
   - 其余 I 系列检查（element_manager/json/toml）不动
4. `CONSUMER-AUDIT-SUMMARY-2026-07-17.md` 追加：
   `CA-016（text.builder inject-grow）**FIXED（接口面重实现）**（stage0 自举约束：mem 门面 graph 在 nextpas 编译器内不可用；改经 mem.allocator.base.ReallocMemSized——allocator≠nil 委托接口方法 / nil 走 System 堆，两者自跟踪 size）`
5. 本文档归档决策（CA-016 依据）。

## 6. 验证路径（已执行）

- `make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails`（I1 转绿，其余 I 系列不变）
- `make -C core/tests/nextpas.core.text/test_text_builder clean test`（行为回归）
- `make -C core/tests/nextpas.core.bytes/test_bytes clean test`（allocator.base 变更的最小消费者验证）
- stage0 冒烟：`make test TEST_FILTER=compiler-pass`（确认编译器链路不受影响）
- `make hygiene` + `git diff --check`

## 7. 决策记录

- **mem owner**（2026-08-10）：批准 Step 1 + Step 2（豁免字面检查 → 接口面 helper 替代；CA-016 FIXED）。
- **核实记录（2026-08-10，总控）**：已核对 `1d8dedab5`（M2 B 系列合入）——commit message 明示 stage0 下 mem 门面（arena/pool graph）在 nextpas 编译器内不可用，text.builder 的 `ReallocMemOf` → `FAllocator.ReallocMem`/`System.ReallocMem` 即该提交所为；替代守卫（禁行首 uses `nextpas.core.mem`）与提交内容一致，可长期保留。退出条件：stage0 解除门面 graph 约束后切回门面 `ReallocMemOf`。
- **compiler-system owner**：待拍板（核实记录已覆盖客观一致性，长期保留与否由 owner 定夺）。

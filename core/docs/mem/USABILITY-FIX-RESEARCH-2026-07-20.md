# mem 可用性修复 — 专题调研报告

**日期**: 2026-07-20
**状态**: Research complete · **Implemented 2026-07-20**
**输入**: 可用性评估（综合 8.9/10，风险 LOW–MEDIUM）
**约束**: FPC RTL 隔离；热路径零税；Maintenance Idle 不重开 allocator 博物馆；**确认前不改生产代码**
**配套**: [USABILITY-FIX-PLAN-2026-07-20.md](USABILITY-FIX-PLAN-2026-07-20.md)

---

## 1. 调研目标

对评估报告中的 **全部** 发现做：

1. 根因分析（为何存在、是否设计选择）
2. 触点量化（源码/测试/文档/CI）
3. 同类方案对标（Go / Rust / 本仓库既有纪律）
4. 修复策略选项 + 推荐路径
5. 影响范围与风险

**不做**: 边调研边改代码；不合并双轨；不新开无 consumer 的 allocator。

---

## 2. 问题全量清单（评估 → 调研 ID）

| 调研 ID | 评估来源 | 优先级 | 类型 | 一句话 |
|---------|----------|--------|------|--------|
| R-ER-01 | F-ER-01 / P1-1 | **P1** | 缺陷/债务 | raise 消息未统一走 `FormatAllocErrorMsg` |
| R-UX-01 | F-UX-01 / P1-2 | **P1** | 体验 | `debug_coverage_gap` 可见但不够醒目 |
| R-TE-01 | F-TE-01 / P1-3 | **P1** | 隔离违规 | `test_stack_guard` 仍 `uses SysUtils`（死依赖） |
| R-CO-01 | F-CO-01 | **P2** | 契约 | `EOutOfMemory` 不在 `EAllocError` 下，窄 catch 漏捕 |
| R-CO-02 | F-CO-02 | **P2** | 契约 | 历史异常子类 + 混用 raise 形态 |
| R-ER-02 | F-ER-02 | **P2** | 体验 | `BuildAllocMsg` 再拼码文案，消息形态需冻结说明 |
| R-ER-03 | F-ER-03 | **P2** | 设计边界 | 热路径 OOM 仅 nil，无可选 last-failure |
| R-SA-01 | 安全风险 / P2-2 | **P2** | 安全 | 基堆双 free 默认 UB；CI 缺 HEAP_SAFETY 习惯 |
| R-UX-02 | F-UX-02 / P2-3 | **P2** | 可发现 | 无 `examples/nextpas.core.mem` |
| R-UX-03 | F-UX-03 | **P2** | 误用面 | FreeMemOf vs tracking 观察冲突 |
| R-IF-01 | F-IF-01 | **P2** | 认知 | 双轨 + 助手 API 认知税 |
| R-IF-02 | F-IF-02 | **P2** | 认知 | Alloc / GetMem / Acquire 三套动词 |
| R-IF-03 | F-IF-03 / P2-4 | **P2** | 命名 | `UnChecked` vs collections `Unchecked` |
| R-TE-02 | F-TE-02 | **P2** | 门禁 | `lane-focused LANE=mem` 仅 guardrails，未含 contract_matrix |
| R-CO-03 | F-CO-03 | **P3** | 设计边界 | `IAllocator.FreeMem` 单参 vs sized 助手 |

**明确排除（不是缺陷，禁止当「修复」去做）**:

| 项 | 理由 |
|----|------|
| 合并 DefaultHeap 与 IAllocator | SC9 已证 ~7–10× 税；双轨是正确设计 |
| 把 sized free 塞回 IAllocator 五方法 | 接口冻结；破坏插件面 |
| 热路径默认 HEAP_SAFETY | 破坏 SC1 零税目标 |
| 全仓机械 FreeMemOf | 已关闭；tui WAIVE 故意保留 |

---

## 3. 量化基线（2026-07-20 本机扫描）

### 3.1 错误消息

| 指标 | 值 |
|------|-----|
| `raise EAllocError|EOutOfMemory.Create` | **137** |
| 已用 `FormatAllocErrorMsg` | **7**（~5%） |
| 手写已符合 `Type.Method: ` | **86** |
| **bare / 非标准 stem** | **44**（~32%） |
| Top bare 文件 | `fixed_slab`(动态拼接)、`mmap`、`blockpool.sharded`、`mimalloc`、`sentinel` |
| `raise EOutOfMemory.*` | **20** |
| 历史专用类型 raise（EMemFixed/ESlab/…） | **39** |

### 3.2 命名

| 符号 | 位置 | 外部引用 |
|------|------|----------|
| `CopyUnChecked` 等 5 个 `*UnChecked*` | `mem.utils` | `collections.element_manager`×2；pool.slab/fixed_slab/allocator×3 |

### 3.3 FPC RTL 隔离

| 表面 | 状态 |
|------|------|
| 生产 `nextpas.core.mem*.pas` uses SysUtils/Classes | **0** |
| 测试真实 `uses SysUtils` | **1**（`test_stack_guard.lpr`）；且 **无符号引用** → 死 import |
| `TRtlAllocator` → `System.GetMem` | 显式 opt-in；默认堆 Growing（**不**计为违规） |

### 3.4 门禁 / 诊断

| 项 | 现状 |
|----|------|
| `lane-focused LANE=mem` | 仅 `test_usability_guardrails` |
| 文档默认 gate | guardrails **+** `test_contract_matrix`（与脚本不一致） |
| `FormatMemStats` | 已含 `debug_coverage_gap=y/n`，无 `WARN` 前缀 |
| stage0 doctor | 投影 `FormatMemStats`；HEAP_DEBUG recipe 存在；**无** gap 失败策略 |
| HEAP_SAFETY 默认 CI | **无**独立 mem job 强制 |

---

## 4. 逐项根因 + 对标 + 策略

### R-ER-01 FormatAllocErrorMsg 采用率低

**根因**: ERROR-POLICY 冻结了格式与助手，但历史 raise 用手写字面量；新代码（Arena/AllocArray/Sanitize）才走助手。无 source-contract 强制「所有 raise 经助手」。

**对标**:

| 体系 | 做法 |
|------|------|
| Rust | `thiserror` / 统一 `Display`；新代码 clippy 可拦 |
| Go | `fmt.Errorf("pkg: %w", err)` 惯例 + 审查 |
| 本仓库 | guardrails 已测助手本身；**未**扫全库 raise |

**策略选项**:

| 选项 | 做法 | 风险 | 推荐 |
|------|------|------|------|
| A | 全 137 点机械改 `FormatAllocErrorMsg` | 动态拼接（fixed_slab `AOperation`）需小包装 | **推荐** |
| B | 仅 bare 44 + 门禁禁止新 bare | 债务残留 86 手写 | 次选 |
| C | 只加门禁不改旧 | 不一致长期存在 | 否 |

**推荐 A 细节**:

1. 静态字面量：`FormatAllocErrorMsg('TType','Method','reason')`
2. 动态 Method：`FormatAllocErrorMsg('TFixedSlabPool', AOperation, 'pointer cannot be nil')`
3. 动态 reason：`FormatAllocErrorMsg(..., 'offset=' + IntToStr(...))`（IntToStr 用 `text.conv` / 既有路径，禁止 SysUtils）
4. source-contract：新/改 raise 必须含 `FormatAllocErrorMsg` 或白名单（`error.pas` 自举）
5. 门禁：`check_usability_docs` 或独立 `check_alloc_error_msg.sh` 扫 `raise EAllocError.Create` 无助手则失败（允许 `error.pas` 内部）

**影响范围**: ~35 个 mem 单元；行为不变（消息 stem 对齐）；测试若 assert 全文可能需调（优先 assert `IsWellFormed` / `Pos('Type.Method:')`）。

**风险**: LOW（字符串形态微调）；MEDIUM 若测试绑死旧全文。

---

### R-UX-01 debug_coverage_gap 不够醒目

**根因**: F1 已把假阴性变成可观测字段，但默认一行是 `debug_coverage_gap=y` 埋在 flags 中；doctor 不升级为 WARN；新手仍可只开 `NEXTPAS_MEM_DEBUG`。

**对标**: Go pprof 不会「只采样一半默认静默」；Rust miri 需显式开但失败很吵。本仓库已有字段，缺 **告警强度**。

**策略选项**:

| 选项 | 做法 | 风险 | 推荐 |
|------|------|------|------|
| A | `FormatMemStats`/`FormatMemDebugProfile` 在 gap 时追加 ` WARN=debug_coverage_gap` | 解析方需容忍新 token | **推荐** |
| B | doctor 在 gap 时 exit≠0 | 可能吵死合法「只查插件面」场景 | 可选 env |
| C | 仅文档加粗 | 不够 | 不够 alone |

**推荐 A + B 可选**:

- 默认：字符串含 `WARN=debug_coverage_gap`（机器可 grep）
- `NEXTPAS_MEM_DEBUG_GAP_FATAL=1` 时 doctor recipe 失败（opt-in）
- guardrails 断言 gap 时 Format 含 WARN
- README 错误用法表保持

**影响**: `default.pas`、stage0 doctor 投影测试、guardrails、可能 `stage0-heap-debug-env-recipe`。

**风险**: LOW；破坏性仅限日志解析脚本（仓库内可同步）。

---

### R-TE-01 test_stack_guard SysUtils

**根因**: 遗留 uses；`IntToStr` 已由 `nextpas.core.text.conv` 提供；**零符号依赖 SysUtils**。

**对标**: 仓库 FPC RTL 隔离硬约束；bench 等已清。

**策略**: 删除 `SysUtils` 一行；可选 source-contract：mem tests 禁止 `uses SysUtils`。

**风险**: 极低。

---

### R-CO-01 EOutOfMemory vs EAllocError

**根因（设计）**:

```
EAllocError     → ENextPasError          （编程错误域 + TAllocError）
mem.EOutOfMemory → exception.EOutOfMemory → EResourceExhaustedError → ENextPasError
```

资源耗尽挂在资源层次，**有意**不挂 `EAllocError`，以便 `except on EResourceExhaustedError` 仍通。副作用：`except on E: EAllocError` 漏掉 20 处 OOM raise。

**对标**: Rust 用 `AllocError` 一种；Go 少用异常。Pascal 双层次合理但 catch 面要统一。

**策略选项**:

| 选项 | 做法 | 风险 | 推荐 |
|------|------|------|------|
| A | 改 `EOutOfMemory = class(EAllocError)` | **打破**资源层次；`is EResourceExhaustedError` 失败 | **否** |
| B | 统一 catch 纪律 + 助手 `TryGetAllocError(E, out TAllocError)` | 零破坏 | **推荐** |
| C | 构造失败改 raise `EAllocError(aeOutOfMemory)`，真 OOM 仍 nil | 部分统一 | 可作补充 |

**推荐 B**:

1. ERROR-POLICY：推荐 catch **`ENextPasError`**；窄 catch 必须同时考虑 OOM
2. 新增 `function TryAllocErrorCode(E: Exception; out ACode: TAllocError): Boolean`（识别 `EAllocError` 与 mem `EOutOfMemory`）
3. guardrails 覆盖助手
4. **不**改继承关系（高爆炸半径）

**风险**: LOW。

---

### R-CO-02 历史异常类

**根因**: 池模块早期 `EMemFixedPool*` / `ESlabPool*` / `EStackPoolError` / `EGrowingFixed*` / `ERingBufferError` 共 **39** 次 raise；类型已是 `EAllocError` 子类 → **窄 catch EAllocError 已覆盖**。问题是 (1) 类型噪音 (2) 消息未统一助手。

**策略**:

1. **不删** 公开类型（避免 consumer break）——标记文档 deprecated / 推荐 `EAllocError`+码
2. raise 点统一 `EAllocError.Create` 或保留子类但消息走 `FormatAllocErrorMsg`
3. 新代码禁止新增历史子类（source-contract）

**风险**: LOW。

---

### R-ER-02 BuildAllocMsg 二次拼接

**根因**: `Create(code, stem)` → `stem + ': ' + ERROR_MESSAGES[code]`，最终形如：

```text
TLocalBlockPool.Release: double free detected: Double free detected
```

stem 已含 human reason 时与码文案重复。

**对标**: 许多库用 `code` 属性 + 短 message；或 `message [CODE]`。

**策略选项**:

| 选项 | 做法 | 风险 | 推荐 |
|------|------|------|------|
| A | 改 `BuildAllocMsg` 为 `stem + ' [' + AllocErrorToString + ']'` | 改所有 Message 全文 | 可选 |
| B | 冻结当前形态 + 文档写清「最终 Message = stem + code label」+ 解析只认 stem | 零代码 | 基线 |
| C | aMsg 非空时不再拼 ERROR_MESSAGES | 丢码文案 | 否 |

**推荐 A（小改）+ 文档**: 中括号码更易读且减重复感；更新依赖全文的测试。
若希望零行为变：仅 B。
**本规划采纳 A**（用户要求修体验问题）。

**风险**: LOW–MEDIUM（全文断言测试）。

---

### R-ER-03 热路径无 last-OOM 对象

**根因**: ERROR-POLICY 铁律「资源不足 = nil/False」；Growing 热路径不抛。

**对标**: C malloc；Go 分配失败通常 OOM kill；Rust 多数 `AllocError` 在 allocator API。

**策略**:

| 选项 | 推荐 |
|------|------|
| 加 TLS last-failure | **否**（热路径税 + 线程模型复杂度；违反「不抛也不记」简洁模型） |
| 强化 Try* 可发现性 + README | **是**（已有 API，算「修复可用性缺口」） |
| HEAP_DEBUG 下可选计数 | 可选，非必须 |

**关闭标准**: 文档 + examples 展示 `TryGetMem`；guardrails 保证 Try 对称（已有）。**不新增 TLS API**。

---

### R-SA-01 默认双 free UB + CI SAFETY

**根因**: 生产默认零税；检测放在 opt-in DEBUG/SAFETY。正确但 CI 未养成 SAFETY 习惯。

**策略**:

1. **不改**生产默认
2. 新增或扩展：`make focused FOCUS=.../test_double_free` 在 `NEXTPAS_MEM_HEAP_SAFETY=1` 下的 job（或 scorecard 旁 `test_heap_safety_smoke`）
3. 文档 `MEM-HOST-RUNTIME-CI` / README：推荐 PR 可选开 SAFETY
4. 可选：core-ci best-effort 矩阵一行

**风险**: CI 时间 + 假红（若测试依赖 UB）；仅测包装路径则 LOW。

---

### R-UX-02 缺 examples

**根因**: 文档代码块为主；示例落在 http/compiler/bench。

**策略**: 按 `core/examples/nextpas.core.csv/csv_smoke` 模式新增：

| 示例 | 演示 |
|------|------|
| `heap_default` | GetMem/FreeMem(size)/TryGetMem/GetMemStats |
| `arena_request` | CreateDefaultArena + Reset |
| `inject_debug` | DefaultAllocator + tracking；**故意**说明 FreeMemOf vs FreeMem |

产物进 `build/`；Makefile `run`；禁止 SysUtils。

**风险**: 极低。

---

### R-UX-03 FreeMemOf vs tracking

**根因**: FreeMemOf 在无 DEBUG wrap 时对 DefaultHeap 自有块走 sized 热 free，**绕过** `AAllocator.FreeMem` → tracking 计数不降。tui inject 已 WAIVE。

**策略**（非改 FreeMemOf 语义）:

1. API-GUIDE 决策树保持；README 错误表加一行
2. source-contract：`test_tracking*` / tui 路径注释 + guardrails 钉「tracking 测试不用 FreeMemOf 期望 ActiveAllocCount」
3. 可选：`FreeMemOf` 文档 `@warning` 强化

**禁止**: 让 FreeMemOf 总是调 IAllocator（毁掉 SC8/SC9 收益）。

**风险**: LOW。

---

### R-IF-01 / R-IF-02 认知税与三套动词

**根因**: 语义真实不同（Arena / Heap / Pool），不是命名事故。

**策略（文档 + 门面可发现，不合并 API）**:

1. README / API-GUIDE 顶部「三套动词 30 秒表」固定
2. `mem.intf` / `arena.intf` / `pool.base` 接口注释交叉引用
3. guardrails `check_usability_docs` 要求三套表与错误用法表存在（已有部分）
4. examples 三个样板对应三套

**关闭标准**: 新人路径文档完备 + examples 可跑；**不**改公开方法名。

---

### R-IF-03 UnChecked → Unchecked

**根因**: 历史拼写；collections 已用 `Unchecked`。

**触点**: 5 符号定义；外部 4 文件引用（含 collections）。

**策略**:

1. mem.utils：新名 `CopyUnchecked` 等为 canonical
2. 旧名 `CopyUnChecked` 保留为 **inline 转发** 一版（或同 commit 全改无别名——更干净）
3. 更新 mem 内部 + `element_manager`（**受控跨模块**，须在 Ready 报告列出）
4. 文档/collections 笔记同步

**推荐**: 同一切片 **全改无长期别名**（表面小、引用少），避免双名永久。

**风险**: LOW；跨模块需 collections 路径验证。

---

### R-TE-02 lane-focused 范围

**根因**: `scripts/lane-focused.sh` mem 只绑 guardrails；USABILITY-SCORE 写了双 gate。

**策略**:

1. 扩展 lane 为 **顺序跑** guardrails + contract_matrix（`lane-focused` 若只支持单 FOCUS，则改脚本支持 mem 多 path，或引入 `test_mem_lane` 聚合 Makefile）
2. 同步 `docs/worktrees.md` 表

**推荐**: `core/tests/nextpas.core.mem/lane_gate/Makefile` 聚合 `clean test` 调两个子目录；lane 指向聚合。

**风险**: LOW；门禁时间约 ×2。

---

### R-CO-03 IAllocator 单参 FreeMem

**根因**: 五方法冻结；sized 在过程式与 FreeMemOf。

**策略**: **文档冻结为设计**；在 `mem.intf` 注释与 FACADES 写「sized 走 FreeMemOf/过程式」。不改接口。

**关闭标准**: 文档 + 接口注释；评估项转为「设计接受 + 可发现」。

---

## 5. 问题分类总表

| 类别 | ID | 修复形态 |
|------|-----|----------|
| **A 行为/代码统一** | R-ER-01, R-ER-02, R-TE-01, R-IF-03 | 改源码 + 测试 |
| **B 诊断可观测增强** | R-UX-01, R-SA-01 | 字符串/CI/测试 |
| **C 契约/助手** | R-CO-01, R-CO-02 | 助手 + 文档 + raise 统一；不改继承 |
| **D 可发现性** | R-UX-02, R-IF-01, R-IF-02, R-UX-03, R-CO-03, R-ER-03 | examples + 文档 + 注释；不改语义 |
| **E 门禁** | R-TE-02 | lane 脚本/聚合 Makefile |
| **F 禁止项** | 双轨合并、默认 SAFETY、IAllocator 加 FreeMem(size) | 明确不修 |

---

## 6. 影响范围

| 区域 | 路径 |
|------|------|
| mem 源码 | `core/src/nextpas.core.mem*.pas`（raise 面 ~35 文件；default/error/utils） |
| 跨模块 | `core/src/nextpas.core.collections.element_manager.pas`（UnChecked） |
| 测试 | guardrails、contract_matrix、stack_guard、可选 heap_safety smoke |
| 示例 | `core/examples/nextpas.core.mem/*`（新建） |
| 脚本/CI | `scripts/lane-focused.sh`、可能 `stage0-heap-debug-env-recipe`、文档 CI |
| 文档 | ERROR-POLICY、API-GUIDE、README、FACADES、USABILITY-SCORE、ROADMAP 指针 |
| stage0 | doctor 投影若解析 FormatMemStats（WARN token） |

**不在范围**: 新 allocator；全仓 FreeMemOf；compiler/HTTP 产品表；改 Growing 热路径算法。

---

## 7. 风险评估汇总

| 风险 | 等级 | 缓解 |
|------|------|------|
| raise 消息全文变更导致测试红 | MEDIUM | 优先 Pos/IsWellFormed；分文件提交 |
| BuildAllocMsg 格式变更 | LOW–MEDIUM | 同 R-ER-02；单测钉新格式 |
| 跨模块 UnChecked | LOW | 同步 element_manager + collections gate |
| WARN token 破坏外部解析 | LOW | 追加字段不删旧 key |
| lane gate 变慢 | LOW | 两 gate 仍 focused |
| 误改 FreeMemOf/双轨语义 | **HIGH if 做错** | 规划明确禁止；审查 checklist |
| EOutOfMemory 改继承 | **HIGH** | **不采纳** |

**整体实施风险**: **LOW–MEDIUM**（多为一致性与文档；无架构重写）。

---

## 8. 成功标准（调研层）

实施完成后应满足：

1. mem 生产 raise 点 **100%** 经 `FormatAllocErrorMsg`（白名单仅 `error.pas` 自举）
2. bare SysUtils 测试 **0**
3. gap 时 Format 含可 grep 的 WARN
4. `TryAllocErrorCode`（或等价）+ 文档 catch 纪律
5. 三 examples `make run` 绿
6. `lane-focused LANE=mem` ≡ guardrails + contract_matrix
7. UnChecked 拼写统一；SC1 热路径语义与默认税 **不变**
8. Scorecard RELEASE=1 无回归要求（至少 SC1/SC8/SC9 抽样）

---

## 9. 调研结论

| 判断 | 内容 |
|------|------|
| 是否可全部「修复」 | **是**——在「修复=关闭可用性缺口」定义下；设计项用文档/门禁/助手关闭，不硬改架构 |
| 最大真实代码量 | R-ER-01（~130 raise）+ 小幅 error/default/utils |
| 最大产品风险 | 误伤双轨/FreeMemOf/默认堆性能 |
| 建议节奏 | 见实施规划 M0–M4；**确认后**再动代码 |
| 与 Maintenance Idle | 兼容：无新 allocator；属 D6/D7/D2 纪律与可用性债清理 |

---

## 10. 下一步

1. 审阅本报告 + [实施规划](USABILITY-FIX-PLAN-2026-07-20.md)
2. 用户 **确认** 范围（尤其：BuildAllocMsg 改格式 A、UnChecked 跨模块、lane 双 gate）
3. 确认后按里程碑统一实施，禁止边想边改

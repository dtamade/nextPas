# BOOTSTRAP 工作线 — 任务规格

## 目标

推进 nextPas 自举（用 nextPas 编译 nextPas）。`nextpas.core.system` 是编译器与运行时的握手契约层，`compiler/` 是自举的执行引擎。两者合并为一条工作线。

## 当前状态

- system 模块：S0-S5 完成，S6 进行中
- 编译器：50 源文件，1 pass 测试，9 fail 测试
- 19 个 `np.system.*` 契约已文档化，7 个有 HIR/LLVM/测试证据
- LLVM 后端已能编译 hello world → 可执行文件 → exit 0

## 接口交付优先级

**`system.classes` 是全局阻塞点**。TLS (TSSLStream)、HTTP (THttpStream)、fs (TFileStream)、
io (TStream) 等多个模块的核心类型继承自 `TStream`，没有 `system.classes` 门面就无法脱离
FPC `Classes` 单元。`system.classes` 排在所有 Gate 之前。

## 自举 6 道 Gate

### Gate 0: system.classes 最小门面 🔴 全局阻塞点 ⏱️ 3-5 天

**为什么排第一**：TLS (138 个文件)、HTTP、fs、io 等模块的核心类型继承自 `TStream`。
不交付 `system.classes`，这些模块无法迁移脱离 FPC `Classes` 单元，所有其他工作线被阻塞。

**当前真实状态**：`core/src/nextpas.core.system.classes.pas` **已存在**，是纯 re-export facade，
已提供 TStream/THandleStream/TMemoryStream/TStringStream/TSeekOrigin。**缺失** file-text-compat 面
(TFileStream/fm*/TStringList)，影响 19+ TLS 文件 + compiler/toolchain。

**任务**：

1. **收口验证**已存在的 stream-core facade：
   - 确认 `system.classes` 门面通过编译和 source-contract gate
   - 添加单元测试 `core/tests/nextpas.core.system/test_system_classes/`
   - 符号清单：`TStream`, `THandleStream`, `TMemoryStream`, `TStringStream`, `TSeekOrigin`
   - 明确 `TBytesStream` 不属于 system.classes（owner 是 `nextpas.core.io.memory`）

2. **file-text-compat 扩展**（需单独 review）：
   - 审计 TFileStream/TStringList 消费面（19+ 文件）
   - 决策：扩展现有 facade vs 等待纯 Pascal io 模块
   - 如果扩展，加入 `TFileStream`、`fmCreate/fmOpenRead/fmOpenWrite/fmShareDeny*` 常量、`TStringList`

3. **更新 system 文档**：
   - `core/docs/system/README.md`：`Classes 已推迟` → `已最小 live，需收口验证`
   - `core/docs/system/goal-tree.md`：S4 状态更新
   - 创建 `core/docs/system/classes-minimal-pressure.md` 记录审计结果

4. **通知所有工作线** stream-core 面已可用，file-text-compat 面待决策

**验收**：
- [ ] system.classes 已有 facade 通过 source-contract gate
- [ ] file-text-compat 扩展决策完成，文档化
- [ ] 单元测试通过，0 leaks
- [ ] system 文档状态更新（README/goal-tree 不再写 "Classes 已推迟"）
- [ ] `make hygiene` PASS

**参考文档**：
- `core/docs/design-conventions.md` — 门面模式（§2 模块结构范式）
- `core/docs/system/README.md` — owner boundary，Classes 已推迟
- `core/docs/system/compatibility-facades.md` — S4 兼容门面设计
- `docs/plans/2026-06-18-five-lines-work-map.md` — 5 线接口需求矩阵

---

### Gate 1: RTTI 形状一致性 ⏱️ 3-5 天

**为什么 Critical**：collections 模块用 `GetTypeKind(T)` 做类型分发。如果 nextPas 编译器发出的 `TTypeKind` 枚举值和 FPC 不一致，collections 会静默出错。

**任务**：
1. 创建 `tests/compiler/pass/rtti_kind_values_pass.pas`
   - 声明每种基础类型（Integer, String, Boolean, Double, Pointer, Object, Interface, DynamicArray, Record...）
   - 对每种类型调用 `GetTypeKind(T)`，断言返回预期的 `TTypeKind` 枚举值
   - 输出所有枚举值的数值，作为回归 baseline
2. 用 FPC 编译运行，记录预期值
3. 用 nextPas stage0 编译运行，比对
4. 在 `core/tests/nextpas.core.collections/` 中添加 guard 测试：
   - 验证 `TElementManager<string>` 的 `GetTypeKind` 返回 `tkAString`
   - 验证 `TElementManager<Integer>` 的 `GetTypeKind` 返回 `tkInteger`
5. 更新 `core/docs/system/self-hosting-readiness.md` Gate 1 状态

**验收**：
- [ ] `rtti_kind_values_pass.pas` 在 FPC 下 PASS
- [ ] FPC 和 nextPas 输出的 TTypeKind 数值一致
- [ ] collections guard 测试 PASS
- [ ] 0 leaks

**参考文档**：
- `core/docs/system/self-hosting-readiness.md` — Gate 1 详细设计
- `core/docs/system/typinfo-minimal-pressure.md` — 七符号压力集
- `core/src/nextpas.core.system.typinfo.pas` — 当前 TypInfo 门面

---

### Gate 2: 单元生命周期执行 ⏱️ 2-3 周

**为什么 Critical**：自举时编译器自己由多个单元组成。没有 unit_init/unit_fini，多单元程序无法正确初始化。

**前置依赖**：Gate 3（进程生命周期）和 Gate 4（堆管理器）先就位。

**任务**：

**Step 1: UnitGraph 消费（compiler/sema）**
- 文件：`compiler/sema/np_semantic_analyzer.pas`
- 当前：`SeedRuntimeContracts` 只在 program root 层面 seed `process_init/process_fini`
- 扩展：在 `SeedRuntimeContracts` 之后，遍历 `FUnitGraph`，为每个非 root 单元 seed `np.system.unit_init` / `np.system.unit_fini`
- 输出：HIR `runtime-contract` 节点，每个单元一条 init + 一条 fini

**Step 2: HIR 节点生成（compiler/ir）**
- 文件：`compiler/ir/np_hir_builder.pas`
- 新增 HIR 节点类型：`unit-init-runtime`、`unit-fini-runtime`
- 类似已有的 `halt-call-runtime`、`raise-runtime` 节点
- 操作数：单元名称

**Step 3: LLVM 发射（compiler/ir）**
- 文件：`compiler/ir/np_hir_llvm_emitter.pas`
- 新增 LLVM helper：`@np_unit_init`、`@np_unit_fini`
- 或直接调用后端发出的单元级初始化符号

**Step 4: 运行时驱动（rtl/core/system）**
- 文件：`rtl/core/system/System.pas` 或新的入口文件
- `_start` 扩展：
  ```
  _start:
    call @np_process_init
    call @np_unit_init for each unit (topological order)
    call main
    call @np_unit_fini for each unit (reverse order)
    call @np_process_fini
    exit
  ```

**验收**：
- [ ] `hello_with_units.pas`（program uses UnitA; UnitA uses UnitB）正确执行 init 顺序
- [ ] UnitB.init 先于 UnitA.init 执行
- [ ] UnitA.fini 先于 UnitB.fini 执行
- [ ] exit code 正确保留

**参考文档**：
- `core/docs/system/self-hosting-readiness.md` — Gate 2 详细设计
- `core/docs/system/runtime-contracts.md` — 契约名称
- `compiler/sema/np_semantic_analyzer.pas` — 现有 SeedRuntimeContracts

---

### Gate 3: 进程生命周期执行 ⏱️ 3-5 天

**为什么 Important**：process_init/fini 已有语义种子，但 `_start` 入口只做了 halt syscall。

**任务**：
1. 扩展 LLVM emitter 的 `_start` 入口：
   - 在 `main` 调用前插入 `@np_process_init` 调用
   - 在 `main` 返回后插入 `@np_process_fini` 调用
2. 确保 exit code 通过 shutdown 序列保留
3. 添加测试：`tests/compiler/pass/process_lifecycle_pass.pas`
   - program 输出 "init" → "main" → "fini" 验证顺序

**验收**：
- [ ] process_init 在 main 前执行
- [ ] process_fini 在 main 后执行
- [ ] exit code 不被 shutdown 序列破坏

**参考文档**：
- `core/docs/system/self-hosting-readiness.md` — Gate 3
- `core/docs/system/lifecycle-contracts.md` — 进程生命周期契约

---

### Gate 4: 堆管理器集成 ⏱️ 1 天（标记临时）或 1 周（替换 mem）

**为什么 Important**：`@np_alloc/@np_free` 当前直接用 mmap/munmap，没走 `nextpas.core.mem`。

**决策点**（需要总控决定）：
- **路径 A**：替换为 `nextpas.core.mem` 分配器调用（正确但 1 周）
- **路径 B**：文档标记为"临时实现，自举后替换"（务实但留债）

**路径 B 任务**：
1. 在 `compiler/ir/np_hir_llvm_emitter.pas` 中为 `@np_alloc`/`@np_free` 添加注释标记
2. 在 `core/docs/system/self-hosting-readiness.md` Gate 4 状态标记为 "Temporary for bootstrap"
3. 创建 `docs/plans/` 计划文件记录后续替换方案

**路径 A 任务**：
1. 在 LLVM emitter 中将 `@np_alloc` 替换为调用 `nextpas.core.mem` 的分配器入口
2. 将 `@np_free` 替换为调用 `nextpas.core.mem` 的释放入口
3. 确保编译器发出的程序链接到 mem 模块
4. 验证 heaptrc 0-leak

**验收**：
- [ ] 编译器发出的程序内存分配/释放路径有明确归属文档
- [ ] 无论路径 A 还是 B，自举程序能正确分配/释放内存

---

### Gate 5: 异常展开 ⏱️ 2 天

**为什么 Normal**：setjmp/longjmp 方案已基本可用。try/except/finally 可工作。

**任务**：
1. 补充异常测试：
   - `tests/compiler/pass/exception_try_except_pass.pas` — try/except 捕获特定异常
   - `tests/compiler/pass/exception_try_finally_pass.pas` — try/finally 保证执行
   - `tests/compiler/pass/exception_nested_pass.pas` — 嵌套 try 块
2. 验证异常对象创建和字段访问
3. 更新 `core/docs/system/self-hosting-readiness.md` Gate 5 状态

**验收**：
- [ ] try/except/finally 在编译器源码级别的程序中正确工作
- [ ] 异常对象创建、字段访问、消息传递正确
- [ ] 嵌套 try 块展开顺序正确

---

### 编译器测试扩展 ⏱️ 与各 Gate 并行

**当前**：1 pass 测试，9 fail 测试。远远不够。

**目标**：pass >= 20，fail >= 15

**新增 pass 测试**（覆盖基本语言特性）：

| 测试 | 覆盖 |
|------|------|
| `int_arithmetic_pass.pas` | 整数四则运算、溢出 |
| `float_arithmetic_pass.pas` | 浮点运算、精度 |
| `string_concat_pass.pas` | 字符串拼接、长度 |
| `boolean_logic_pass.pas` | and/or/not、短路求值 |
| `if_else_pass.pas` | 条件分支 |
| `while_loop_pass.pas` | while 循环 |
| `for_loop_pass.pas` | for 循环 |
| `case_statement_pass.pas` | case 语句 |
| `array_pass.pas` | 静态数组、动态数组 |
| `record_pass.pas` | record 定义、字段访问 |
| `pointer_pass.pas` | 指针操作、nil |
| `function_pass.pas` | 函数定义、参数传递、返回值 |
| `procedure_pass.pas` | 过程定义、var 参数 |
| `class_create_free_pass.pas` | 类创建、释放 |
| `class_method_pass.pas` | 类方法调用 |
| `class_virtual_pass.pas` | 虚方法、多态 |
| `interface_pass.pas` | 接口、QueryInterface |
| `enum_pass.pas` | 枚举类型 |
| `set_pass.pas` | 集合类型 |
| `string_format_pass.pas` | Format 格式化 |

**新增 fail 测试**（覆盖语义错误）：

| 测试 | 覆盖 |
|------|------|
| `type_mismatch_fail.pas` | 类型不匹配赋值 |
| `undefined_symbol_fail.pas` | 未定义符号 |
| `duplicate_identifier_fail.pas` | 重复标识符 |
| `wrong_arg_count_fail.pas` | 参数数量错误 |
| `incompatible_types_fail.pas` | 不兼容类型操作 |
| `missing_semicolon_fail.pas` | 缺少分号 |

---

## 执行节奏（修正版 — 基于 self-hosting criticality）

```
Week 1:
  - Gate 0: system.classes 收口验证 — 2 天（facade 已存在）
  - Gate 0b: file-text-compat 扩展决策 — 1 天
  - Gate 1: RTTI 测试 — 3 天（可与 G0 并行）
  - 通知所有线 stream-core 面已可用

Week 2:
  - Gate 5: 异常测试 — 2 天（已接近完成，可早收）
  - Gate 3: 进程生命周期 — 3 天
  - 开始 pass/fail 测试扩展

Week 3:
  - Gate 4: 堆管理器 — 决策+实现
  - 继续 pass/fail 测试扩展

Week 4-5:
  - Gate 2: 单元生命周期 — self-hosting critical gate，最长单点任务
  - 完成所有 pass/fail 测试

Week 6:
  - 自举集成验证
  - 用 nextPas 编译 nextPas 编译器本身
  - 收口、文档更新、合并 main
```

## 工具和命令

```bash
# 进入 worktree
cd /home/dtamade/projects/nextPas/.worktrees/bootstrap

# 重建编译器（必须用这个，不能直接 make）
scripts/rebuild-compiler.sh

# 运行编译器测试
make test TEST_FILTER=compiler-pass
make test TEST_FILTER=compiler-fail

# 运行 system 模块测试
make -C core/tests/nextpas.core.system clean test

# 完整验证
make verify

# 卫生检查
make hygiene
```

## 关键参考文档

| 文档 | 路径 | 内容 |
|------|------|------|
| system 模块入口 | `core/docs/system/README.md` | 定位、边界、契约 |
| 目标树 | `core/docs/system/goal-tree.md` | S0-S6 分阶段进度 |
| 运行时契约 | `core/docs/system/runtime-contracts.md` | 19 个 np.system.* 契约 |
| 生命周期契约 | `core/docs/system/lifecycle-contracts.md` | 异常/RTTI/单元生命周期 |
| 自举就绪 | `core/docs/system/self-hosting-readiness.md` | 5 道 Gate 详细设计 |
| 契约覆盖表 | `core/docs/system/contract-coverage-table.md` | HIR→LLVM→测试映射 |
| 编译器集成 | `core/docs/system/compiler-integration-contract.md` | 编译器侧契约 |
| RTL 映射 | `core/docs/system/rtl-mapping.md` | FPC → nextPas 映射 |
| 设计规范 | `core/docs/design-conventions.md` | 框架设计规范 |

## 合并 main 前必须满足

1. worktree clean
2. `make hygiene` PASS
3. `make test TEST_FILTER=compiler-pass` 全绿
4. `make test TEST_FILTER=compiler-fail` 全绿
5. `make -C core/tests/nextpas.core.system clean test` 全绿
6. `git diff --check` 无 trailing whitespace
7. 0 leaks（heaptrc 验证）

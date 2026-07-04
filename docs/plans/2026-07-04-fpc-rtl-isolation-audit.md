# FPC RTL 隔离审计报告（编译器相关）

> 审计日期: 2026-07-04
> 约束: 仅 `nextpas.core.system` 可直接引用 FPC RTL 单元
> 审计范围: compiler/, tools/, rtl/, units/, tests/harness/, tests/toolchain/, compiler/tests/

---

## 审计结果总览

| 区域 | 违规数 | 严重度 |
|------|--------|--------|
| **compiler/ 核心** | 1 | 高 |
| **rtl/ 模块** | 6 | 高 |
| **tools/ 工具** | 4 | 中 |
| **tests/harness/** | 2 | 低 |
| **tests/toolchain/** | 1 | 低 |
| **compiler/tests/** | 3 | 低 |
| **units/ 门面** | 2 | 特殊（FPC RTL 桥接层） |
| **总计** | 19 | — |

---

## P0 — 编译器核心违规（1 处）

### 1. `compiler/sema/np_sema_name_set.pas:31`

```pascal
implementation
uses
  SysUtils;
```

**用途**: `LowerCase(AName)` — 大小写不敏感名称查找

**修复方案**: 替换为 `nextpas.core.text.conv.LowerCase` 或手写 ASCII tolower 循环（编译器内部不处理 Unicode 标识符）。

**风险**: 极低 — `LowerCase` 是纯函数，行为一致。

---

## P1 — RTL 模块违规（6 处）

| # | 文件 | 违规单元 | 用途 | 框架替代 |
|---|------|----------|------|----------|
| 2 | `rtl/core/text/np_text_primitives.pas:8` | Classes, SysUtils | TStream 基类, 字符串操作 | nextpas.core.system.classes, nextpas.core.text |
| 3 | `rtl/core/process/np_process.pas:7` | Classes, SysUtils | TProcess, 字符串操作 | nextpas.core.process |
| 4 | `rtl/core/classes/np_classes.pas:7` | SysUtils | 字符串操作 | nextpas.core.text |
| 5 | `rtl/core/sysutils/np_sysutils.pas:92` | BaseUnix | POSIX 系统调用 | nextpas.core.platform |
| 6 | `rtl/core/sysutils/np_sysutils_test.pas:5` | SysUtils | 测试 | nextpas.core.test |
| 7 | `rtl/core/mem/np_allocator.pas:8` | SysUtils, np_base_types | 内存分配 | nextpas.core.mem |

**分析**: rtl/ 模块是 FPC RTL 的替代实现，部分模块仍依赖 FPC RTL 自身。这违反了"编译器无关性原则"——如果要在 nextpas 编译器下编译 rtl/，这些依赖会导致循环或不可用。

**修复优先级**: P1 — 需要逐步迁移，每处需要评估框架替代的可用性。

---

## P2 — 工具违规（4 处）

| # | 文件 | 违规单元 | 用途 |
|---|------|----------|------|
| 8 | `tools/lexer_snapshot/lex_bench.pas:27` | SysUtils, Classes | 基准测试 |
| 9 | `tools/lexer_snapshot/lex_snapshot.pas:29` | SysUtils, Classes | 快照工具 |
| 10 | `tools/parser_bench/parser_bench.pas:33` | SysUtils, Classes | 基准测试 |
| 11 | `tools/sema_bench/sema_bench.pas:32` | SysUtils, Classes | 基准测试 |

**分析**: 开发/基准工具，不进入生产。但仍应使用框架接口以保持一致性。

**修复方案**: 迁移到 `nextpas.core.bench` + `nextpas.core.fs` + `nextpas.core.text`。

---

## P3 — 测试基础设施违规（3 处）

| # | 文件 | 违规单元 | 用途 |
|---|------|----------|------|
| 12 | `tests/harness/runner.pas:5` | BaseUnix, Classes, Process, SysUtils | 测试运行器 |
| 13 | `tests/harness/snapshot_support.pas:36` | Classes, SysUtils | 快照支持 |
| 14 | `tests/toolchain/toolchain_contract_smoke.pas:17` | Classes, SysUtils, BaseUnix | 工具链测试 |

**分析**: 测试运行器是独立的可执行程序，需要直接使用 FPC RTL 来编译和运行测试。这是可接受的——测试运行器本身不是框架的一部分。

**建议**: 标记为"已知例外"，不强制迁移。

---

## P4 — 编译器测试违规（3 处）

| # | 文件 | 违规单元 | 用途 |
|---|------|----------|------|
| 15 | `compiler/tests/test_variants_contract.pas:5` | Variants | Variants 契约测试 |
| 16 | `compiler/tests/test_semantic_phase1_type_entry.pas:5` | SysUtils | 语义分析测试 |
| 17 | `compiler/tests/test_dynlibs_contract.pas:5` | Dynlibs | DynLibs 契约测试 |

**分析**: 这些测试验证编译器对 FPC RTL 单元的支持。它们必须引用 FPC RTL 单元才能测试编译器是否正确处理这些单元。

**建议**: 标记为"已知例外"——测试 FPC RTL 兼容性需要引用 FPC RTL。

---

## P5 — Units 门面（2 处）

| # | 文件 | 违规单元 | 用途 |
|---|------|----------|------|
| 18 | `units/linux-x86_64/Classes.pas:7` | SysUtils | FPC RTL Classes 桥接 |
| 19 | `units/linux-x86_64/Process.pas:7` | Classes, SysUtils | FPC RTL Process 桥接 |

**分析**: 这些是 `nextpas.core.system.classes` 和 `nextpas.core.system.process` 的底层桥接层，故意引用 FPC RTL 来提供兼容性。这是架构设计的一部分。

**建议**: 标记为"架构例外"——桥接层必须引用被桥接的单元。

---

## 修复路线图

### Phase 1: 编译器核心（1 天）
- [ ] `np_sema_name_set.pas`: `SysUtils.LowerCase` → 手写 ASCII tolower 或 `nextpas.core.text.conv.LowerCase`

### Phase 2: RTL 模块（5-10 天）
- [ ] `np_text_primitives.pas`: Classes/SysUtils → framework 替代
- [ ] `np_process.pas`: Classes/SysUtils → nextpas.core.process
- [ ] `np_classes.pas`: SysUtils → nextpas.core.text
- [ ] `np_sysutils.pas`: BaseUnix → nextpas.core.platform
- [ ] `np_allocator.pas`: SysUtils → nextpas.core.mem

### Phase 3: 工具（2-3 天）
- [ ] 基准测试工具迁移到框架接口

### 已知例外（不修复）
- tests/harness/ — 测试运行器，独立可执行
- compiler/tests/ — 测试 FPC RTL 兼容性
- units/ — FPC RTL 桥接层

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | FPC RTL 隔离审计 |

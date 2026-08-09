# Phase 0: 状态真相统一

> **状态：历史快照（2026-07-06）。本表已不再是「冻结权威状态表」。**
> 当前权威状态见 `PLAN.md` 与
> `docs/plans/2026-07-12-nextpas-compiler-excellence-plan.md`（2026-07-13 truth reset 后）。

> 日期: 2026-07-06
> 目的: 冻结权威状态表，消除文档间状态漂移。
> 决策依据: Codex (gpt-5.6-sol max) 战略审查 + 实际验证。

## 1. 测试状态（实时验证）

| 测试组 | 通过/总数 | 状态 |
|--------|----------|------|
| compiler-pass | 53/53 | ✅ |
| compiler-fail | 16/16 | ✅ |
| diagnostics | 1/1 | ✅ |
| lexer | 11/11 | ✅ |
| parser | 32/32 | ✅ |
| semantic | 100/100 | ✅ |
| toolchain | 1/1 | ✅ |
| mir | 22/23 | ⚠️ 1 pre-existing |

## 2. 编译器能力状态

### 已存在且接在正式 build path

| 能力 | 文件 | 行数 | 状态 |
|------|------|------|------|
| LLVM IR 发射器 | `compiler/ir/np_hir_llvm_emitter.pas` | 330 | ✅ 已接线，唯一后端 |
| 符号表磁盘缓存 | `compiler/frontend/np_symbol_cache.pas` | 241 | ✅ 已接线 (sema 层) |
| 增量编译缓存 | `compiler/frontend/np_incremental_cache.pas` | 879 | ✅ 已接线 (pipeline 层) |
| HIR→MIR 降低 | `compiler/lower/np_hir_lowering.pas` | 380+ | ✅ 已接线 (C3 桥接层) |
| 后端计划 | `compiler/backend/np_backend_plan.pas` | — | ✅ 已接线，使用 LLVM emitter |

### 骨架存在但未接线

| 能力 | 文件 | 行数 | 状态 |
|------|------|------|------|
| 并行编译调度器 | `compiler/frontend/np_parallel_scheduler.pas` | 198 | ⚠️ 仅 Create，未调用 BuildSchedule/GetNextBatch |

### 增量编译真实性审计

**结论: 已存在且接在正式 build path，但未验证 158 单元场景下的实际效果。**

详细分析：
- `TIncrementalCache` 在 `np_compilation_session_pipeline.inc:446-497` 接线
  - 编译前检查: `HasCache()` → `Load()` → 命中则跳过 Sema
  - 编译后保存: `Save()` → 写入 `.nextpas/cache/<unit-id>.npc`
  - 指纹: 源文件内容 SHA256 + 依赖 hash
- `TDiskSymbolCache` 在 `np_sema_seed_imported_unit_bodies.inc:169` 接线
  - 导入单元符号表缓存，减少重复 Sema

**待验证**:
- [ ] 158 单元场景下缓存命中率
- [ ] 热编译是否真的 <3s
- [ ] 依赖变更时缓存失效是否正确

## 3. LLVM 后端状态

**结论: LLVM 是唯一且已就绪的自举后端。**

| 维度 | 状态 |
|------|------|
| IR 发射 | ✅ `THIRLlvmEmitter` 330 行，完整 IR 生成 |
| 后端集成 | ✅ `TBackendPlan` 调用 LLVM emitter |
| 测试覆盖 | ✅ test_tstring_llvm, test_process_lifecycle_llvm 等 |
| 目标 | ✅ 默认 `x86_64-unknown-linux-gnu` |
| Debug info | ✅ DICompileUnit/DISubprogram/DILocation |
| 自举验证 | ✅ C7 self-compile 19/19 |

**决策**: stage2 自举唯一后端 = LLVM on Linux x86_64 ✅ 确认

## 4. 平台排除分类

### A 类：非当前范围（正式标记 out-of-scope）

| 模块 | 原因 |
|------|------|
| `nextpas.core.tls.winssl.*` (10 模块) | Windows-only，依赖 WinCrypt/WinINet |
| `nextpas.core.simd.sse42` | SSE4.2 内联汇编，需特殊处理 |
| `nextpas.core.simd.sse2` | Intel 内联汇编，导致 assembler 失败 |
| `nextpas.core.simd.base` | Intel 内联汇编，导致 assembler 失败 |
| `nextpas.core.simd.dispatch` | 依赖 simd.sse2 |
| `nextpas.core.simd.cpuinfo` | Intel 内联汇编 |
| `nextpas.core.simd.cpuinfo.base` | Intel 内联汇编 |
| `nextpas.core.simd.vec16` | 依赖 simd.sse2 |
| `nextpas.core.io.reactor.iocp` | Windows IOCP，非 Linux 范围 |

### B 类：编译器缺陷，阻塞自举/核心库

| 模块 | 原因 | 影响 |
|------|------|------|
| `nextpas.core.platform.pipe` | FPC 汇编输出问题 | 阻塞 process.pipe |
| `nextpas.core.platform.signal` | FPC 汇编输出问题 | 阻塞信号处理 |
| `nextpas.core.platform.which` | FPC 汇编输出问题 | 阻塞命令查找 |
| `nextpas.core.tui.widget.linechart` | FPC 汇编输出问题 | 阻塞 TUI 组件 |

### C 类：非阻塞质量债（进 backlog）

| 模块 | 原因 |
|------|------|
| `nextpas.core.io.mapped.ring_buffer.sharded` | FPC 编译错误 |
| `nextpas.core.net.server.runtime` | FPC 编译错误 |

## 5. 自举阻塞点分析

### 旧说法 vs 实际状态

| 旧说法 | 实际状态 |
|--------|----------|
| thread.future 被 class helper 阻塞 | ✅ 编译成功 |
| text.format 被 class helper 阻塞 | ✅ 编译成功 |
| text.conv 被 class helper 阻塞 | ✅ 编译成功 |
| process.pipe 被 class helper 阻塞 | ✅ 编译成功 |
| http.router 被 class helper 阻塞 | ✅ 编译成功 |
| class helper 语法不支持 | ✅ 已支持 (通过 FPC 编译) |

### 真正阻塞点

**根因**: unit resolver 编译搜索路径中的所有单元（252 个），包括 `nextpas.core.simd.*`（含 Intel 内联汇编），导致 assembler 失败。

**失败模块**:
- `nextpas.core.simd.base` - Intel 内联汇编
- `nextpas.core.simd.vec16` - 依赖 simd.sse2
- `nextpas.core.simd.dispatch` - 依赖 simd.sse2
- `nextpas.core.simd.cpuinfo` - Intel 内联汇编
- `nextpas.core.simd.cpuinfo.base` - Intel 内联汇编

**修复方案**:
1. unit resolver 增加 platform-exclude 机制
2. SIMD 模块标记为 A 类平台排除
3. 编译器只编译实际依赖的单元

## 6. 当前债务状态

### 编译器债务 C1-C9: ✅ 全部完成

### 语义债务 L1-L5: ✅ 全部完成

### Phase 1 阻塞点: SIMD 汇编排除 ← 当前

### L6: Class helper
- L6-A (最小解锁, 4-6d): ⚠️ 不是阻塞点，保留为后续质量改进
- L6-B (完整语义, 5-8d):   待 Phase 5 后

## 7. 关键决策确认

| # | 决策 | 依据 | 状态 |
|---|------|------|------|
| 1 | stage2 自举唯一后端 = LLVM | LLVM emitter 330 行已接线，C7 self-compile 19/19 | ✅ 确认 |
| 2 | L6 只做 L6-A 最小解锁版 | 优先自举闭环，完整 helper 语义后置 | ✅ 确认 |
| 3 | 增量编译 = 真实性审计 + 产品化 | 已存在且接线，需验证 158 单元场景 | ✅ 确认 |
| 4 | 自举前不做大规模 Sema 重构 | 降低风险，等自举链路稳定 | ✅ 确认 |
| 5 | 平台排除 A/B/C 分类管理 | A 类 out-of-scope，B 类修复，C 类 backlog | ✅ 确认 |
| 6 | "生产可用"单独立项 | 5 个独立质量门，不与自举混同 | ✅ 确认 |

## 8. 下一步

Phase 0 完成，进入 Phase 1: SIMD 汇编排除 + L6-A (1 周)。

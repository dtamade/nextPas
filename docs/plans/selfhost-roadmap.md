# 自举路线图

> 最后更新：2026-07-05
> 合并自 `c8-roadmap-v2.md` + `selfhost-blockers-roadmap.md`，去重并更新至最新状态。

## 当前状态

| 指标 | 值 | 状态 |
|------|-----|------|
| compiler-pass | 34/34 | ✅ |
| self-compile | 19/19 | ✅ |
| core/ 覆盖率 | 963/972 (99.1%) | ✅ |
| C5 `{$IFDEF}` 支持 | 完成 | ✅ 2026-07-03 |
| C6-H4 owned string return | 完成 | ✅ 2026-07-03 |
| C7 自举验证 | 完成 | ✅ 2026-07-03 |
| FPC RTL 清零 | 0 直接 SysUtils/Classes/System 依赖 | ✅ |
| Exception 自足 | nextpas.core.exception | ✅ |
| 平台类型自足 | SizeInt/SizeUInt 等 | ✅ |

**残留**: c2p_win32_compat（平台排除，winssl 等 Windows-only 模块）

## 已完成的 C8 修复

### Parser
- 表达式链式调用 + 函数指针调用 → 8 模块解锁
- 级联错误自动解决
- interface 前向声明 + parser class decl fix
- `{$IFDEF}`/`{$IFNDEF}`/`{$ELSE}`/`{$ENDIF}` 条件编译 → 40 模块解锁

### Sema (S1-S9)
- S1: SetString/SiftDown/InterlockedCompareExchange/SizeUInt
- S2: atomic_thread_fence/FormatDateTime/Create/Max ambiguous overload
- S3: MkdirAll
- S4: TextOfChar/StringsSplit/UnicodeCompareStr/compare_unicodestring
- S5: interface not implemented
- S7: UInt32 类型别名
- S8: metaclass.Create
- S9: abstract methods

### 源码修复 (R1-R8b)
- R1-R4: tls 模块全面修复 (IStream 迁移 + 缺失导入)
- R5: 8 个 tls 子模块修复
- R6: mbedtls 模块 (NativeUInt→QWord, 重复 ctor)
- R7: git.libgit2 模块 (Pcint FFI 类型)
- R8: simd ifdef stubs + wolfssl 修复
- R8b: winssl uses Windows ifdef

### 基础设施
- FPC stub 隔离 (FPC 使用自己的 RTL)
- SysUtils stub 单元循环打破
- System.pas stub 条件化 (`{$IFNDEF FPC}`)
- Phase A: Exception 自给自足
- Phase C: SysUtils stub 降级
- Phase D: nextpas_core_pass 测试
- Phase E: System 类型自足
- P1-Classes 清零: core/src 0 直接 Classes 引用
- P1-SysUtils 清零: 编译器生产单元 0 直接 SysUtils

## 平台排除清单

| 模块 | 原因 | 策略 |
|------|------|------|
| winssl (10 模块) | Windows-only，依赖 WinCrypt/WinINet | 标记平台排除 |
| platform.pipe | FPC 汇编输出问题 | 后续修复 |
| platform.signal | FPC 汇编输出问题 | 后续修复 |
| platform.which | FPC 汇编输出问题 | 后续修复 |
| simd.sse42 | SSE4.2 内联汇编 | 后续修复 |
| tui.widget.linechart | FPC 汇编输出问题 | 后续修复 |
| io.mapped.ring_buffer.sharded | FPC 编译错误 | 后续修复 |
| net.server.runtime | FPC 编译错误 | 后续修复 |

## 下一阶段：C7 深化

| 任务 | 说明 | 预估 |
|------|------|------|
| 目标运行时配置 | target runtime profile | 1-2 轮 |
| 多目标 IR | 跨平台 IR 生成 | 2-3 轮 |
| LLVM O2/LTO | 优化级别 + 链接时优化 | 1-2 轮 |
| permissive overload → 正式 | 替换临时 overload 方案 | 3-5 轮 |

## 未完成的技术债

### 基础设施
- **增量编译**: 符号表热缓存 → 热编译 <1s（158 单元 <3s）
- **并行编译**: 拓扑序分层并行
- **Sema 拆分**: 12,175 行 → 目标 <8000

### 类型系统
- 泛型构造器传播 (collections, crypto.* 等)
- Class helper 完整支持 (thread.future, text.format 等)
- Forward 声明 + nil 兼容性 (simd 等)

### RTL
- P1-平台绑定: 14 个 FFI 绑定通过 platform 抽象层
- P1-零散依赖: 收尾

## 自举成功标准

1. nextpas 编译器能编译自身全部源码
2. 产出的编译器能再次编译自身（bootstrap 验证）
3. 核心运行时 (`nextpas.core.*`) 零 FPC RTL 依赖（FFI 绑定除外）
4. 性能：增量编译 <3s（158 单元），全量编译 <30s（600+ 文件）

## 编译器命令

```bash
# 重建编译器
cd /home/dtamade/projects/nextPas/.worktrees/compiler
scripts/rebuild-compiler.sh

# 编译单个模块
build/stage2-test/nextpas build <source.pas> \
  --target linux-x86_64 \
  --workspace /home/dtamade/projects/nextPas/.worktrees/compiler

# 全量测试
make test TEST_FILTER=compiler-pass
```

## 治理关联
- 项目总控计划: `PLAN.md`
- 目标树: `docs/plans/goal-tree.md`
- 编译器治理: `compiler/CLAUDE.md`

## 历史文档

本文件合并自以下文档（保留供参考，不再单独维护）：
- `docs/plans/c8-roadmap-v2.md` (2026-06-30)
- `docs/plans/selfhost-blockers-roadmap.md` (2026-06-20)
- `docs/plans/2026-06-25-roadmap-revision.md`

## 变更记录

- 2026-07-05: 合并 c8-roadmap-v2 + selfhost-blockers-roadmap，更新至 C7 完成后状态
- 2026-07-03: C7 自举验证完成
- 2026-06-30: c8-roadmap-v2 创建
- 2026-06-20: selfhost-blockers-roadmap v2.0 创建

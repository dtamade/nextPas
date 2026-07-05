# C8 自举路线图 v2 [已归档]

> ⚠️ 本文档已于 2026-07-05 归档。最新路线图见 `docs/plans/selfhost-roadmap.md`
>
> 2026-06-30 统一更新
> 目标：用 nextPas 编译器编译 `core/` 全部 972 模块，最终自举编译编译器自身

---

## 当前状态总览

| 指标 | 值 | 状态 |
|------|-----|------|
| **compiler-pass** | 30/30 | ✅ |
| **self-compile** | 19/19 | ✅ |
| **core/ 模块 (nextpas)** | **915/972 (94.1%)** | 🏁 |
| **core/ 模块 (FPC)** | 949/972 (97.6%) | ✅ |
| **sema probe (100 模块)** | 95/100 | ✅ |

---

## 57 个失败分类（2026-06-30 实测）

### F1: parser `{$IFDEF}` 不支持 — 40 个模块

**根因**: stage0 lexer/parser 不识别 `{$IFDEF}`/`{$IFNDEF}`/`{$ENDIF}` 条件编译指令。

**典型模块**: `nextpas.core.platform.linux.base.pas` (`{$IFDEF NEXTPAS_AARCH64}`)

**修复路径**: parser 增强 — 这是编译器功能特性，不是源码修复。

**涉及模块类型**:
- platform 层的架构分叉 (aarch64/riscv64/i386/win64) — 8 模块
- SIMD 层的 ISA 分叉 (sse41/sse42/aes/sha) — 4 模块
- TLS 层的后端分叉 (ecdh/lhash/sha/stack/crl/logging) — 6 模块
- HTTP 层 (h1/middleware/static) — 7 模块
- 其他 (crypto/hash/git/process/stopwatch/test/yaml/math) — 15 模块

### F2: host-compiler-exec-failed — 12 个模块

| 子类 | 数量 | 说明 |
|------|------|------|
| winssl (Windows-only) | 10 | 依赖 WinCrypt/WinINet，Linux 不可编译 |
| io.mapped.ring_buffer.sharded | 1 | FPC 编译错误 |
| net.server.runtime | 1 | FPC 编译错误 |

**winssl 模块**: 天然不适用于 Linux target，标记为平台排除即可。

### F3: assembler-exec-failed — 5 个模块

| 模块 | 说明 |
|------|------|
| platform.pipe | FPC 汇编输出问题 |
| platform.signal | FPC 汇编输出问题 |
| platform.which | FPC 汇编输出问题 |
| simd.sse42 | SSE4.2 内联汇编 |
| tui.widget.linechart | FPC 汇编输出问题 |

### 已修复：Math stub — ✅

`units/linux-x86_64/Math.pas` 已创建，re-export `nextpas.core.math.scalar` 的 Max/Min。
math.transform 等模块已解锁。

---

## 优先级排序

### P0: 创建 Math stub (解锁 4 模块)

```
预期: 915 → 919/972 (94.5%)
工作量: ~30 分钟
```

步骤:
1. 检查 `nextpas.core.math.scalar` 是否有 `Ceil`/`Floor`/`Max`/`Min`/`Ln`/`Log2`/`Power`
2. 创建 `units/linux-x86_64/Math.pas` stub
3. 验证 4 个 math 模块编译通过

### P1: 排查剩余 2 个 host-compiler-exec-failed (解锁 0-2 模块)

```
预期: 可能 919 → 921/972
工作量: ~1 小时
```

### P2: parser `{$IFDEF}` 支持 (解锁 40 模块 → 96%)

```
预期: 919 → 959/972 (98.7%)
工作量: 2-3 天
```

方案:
- **A: 驱动式预处理**: parser 遇到 `{$IFDEF X}` 时，根据已知符号表决定保留/跳过
- **B: 完整预处理器**: 独立预处理阶段，支持 `{$DEFINE}`/`{$IFDEF}`/`{$ELSE}`/`{$ENDIF}`

**建议选方案 A**: 最小改动，只支持 `{$IFDEF}`/`{$IFNDEF}`/`{$ELSE}`/`{$ENDIF}`，足够覆盖 40 个模块。

### P3: simd.sse42 assembler 修复 (解锁 1 模块)

```
预期: 959 → 960/972 (98.9%)
工作量: ~2 小时
```

### P4: 96% → 99%+ 收尾

排除 winssl (10) 和其他平台特定模块后，理论上可达 960/962 (99.8%)。

---

## 里程碑

| 里程碑 | 目标 | 预计 |
|--------|------|------|
| **M1: Math stub** | 919/972 (94.5%) | 今天 |
| **M2: {$IFDEF}** | 959/972 (98.7%) | 本周 |
| **M3: 收尾** | 960/972 (98.9%) | 本周 |
| **M4: 自举** | 编译器编译自身 + 全部 core | 待定 |

---

## 已完成的 C8 修复

### Parser 修复 (C8-prep)
- P1-P2: 表达式链式调用 + 函数指针调用 → 8 模块解锁
- P3-P6: 级联错误自动解决
- interface 前向声明 + parser class decl fix

### Sema 修复 (S1-S9)
- S1: SetString/SiftDown/InterlockedCompareExchange/SizeUInt → ✅
- S2: atomic_thread_fence/FormatDateTime/Create/Max ambiguous overload → ✅
- S3: MkdirAll → ✅
- S4: TextOfChar/StringsSplit/UnicodeCompareStr/compare_unicodestring → ✅
- S5: interface not implemented → ✅
- S7: UInt32 类型别名 → ✅
- S8: metaclass.Create → ✅
- S9: abstract methods → ✅

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

---

## 技术约束

### workspace 路径
**必须**使用 `--workspace /home/dtamade/projects/nextPas/.worktrees/compiler`
主仓库 (`/home/dtamade/projects/nextPas`) 没有 C8 修复提交。

### 编译器命令
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

### FPC 编译 vs nextpas 编译
- FPC 编译: 使用 FPC 自带的 RTL，通过 `units/linux-x86_64/` 中的 stub 文件
- nextpas 编译: 使用 `nextpas.core.*` 模块，stub 仅提供名称桥接
- 两者使用不同的源码搜索路径

---

## 关键文档

- 本文件: C8 自举路线图
- 差距清单: `2026-06-26-c8-prep-gap-list.md`
- Sema 路线图: `c8-sema-roadmap.md`
- 自举障碍: `selfhost-blockers-roadmap.md`
- 编译器目标树: `compiler/docs/compiler-goal-tree.md`

---

## 变更记录

- 2026-06-30: v2 — 统一状态，整合 C8-prep/Sema/R1-R8b 全部进展
- 2026-06-29: 完成 R8/R8b 修复，compiler-pass 30/30
- 2026-06-27: 完成 S8/S9 修复，sema probe 95/100
- 2026-06-26: C8-prep 完成，83% → 95% (sema probe)

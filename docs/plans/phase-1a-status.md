# Phase 1a 任务清单 — P4a 完成，准备 P1/P5

> **日期**: 2026-06-19
> **状态**: P4a 已全部完成

---

## P4a 状态: ✅ 全部完成

| 组件 | 文件 | 测试 | 状态 |
|------|------|------|------|
| TAtomic 完整套件 (6640 行) | `nextpas.core.atomic.pas` + `.core` + `.types` + `.compat` | 45/45 | ✅ |
| TSyncPool v7 (TLS freelist) | `nextpas.core.sync.pool.pas` | 24/24 | ✅ |
| TFutexMutex (CAS+spin+futex) | `nextpas.core.sync.mutex.pas` | 28/28 | ✅ |
| TRWLock / TSpinLock / Semaphore / Barrier / Event / Once / WaitGroup | 各自单元 | 28/28 | ✅ |

**全部 0 泄漏，性能超越 Go。**

---

## 下一步: Phase 1a 剩余

### P1: Custom TString (SSO + CoW + UTF-8 原生)
- S7.1: TString 基础 layout (24B variant record)
- S7.2: SSO 路径 (≤15B 内联)
- S7.3: CoW 路径 (refcount + copy-on-write)
- S7.4: 与 nextpas.core.text 集成

### P5: RAII for Records
- S11.0: CoW refcount 与 RAII Finalize 协作协议
- S11.1: 编译器 managed field 检测
- S11.2: HIR scope exit 插入
- S11.3: 异常路径 cleanup
- S11.4: managed_record_init/fini

**注意**: P1 和 P5 都需要编译器改动 (sema + HIR + LLVM emission)，是真正的硬任务。
建议 P5 先行 (scope analysis 是 P1 CoW 的前置依赖)。

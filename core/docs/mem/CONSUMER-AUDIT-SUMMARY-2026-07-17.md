# Consumer Audit Summary — 2026-07-17

**完整报告**: [CONSUMER-AUDIT-FINDINGS-2026-07-17.md](CONSUMER-AUDIT-FINDINGS-2026-07-17.md)
**状态**: **FIX CLOSED**（审计 + 全修 slice；归属路线图时代 C）
**活路线图**: [ROADMAP.md](ROADMAP.md) 时代 D 起只做回归锁 / 按触达升级
**分支**: `mem` · worktree `.worktrees/mem`

## 一句话

P0（swiss.i32 错误 IAllocator API）已修；L1+ 分配族已接入 `nextpas.core.mem`；已知 size 的 sized free / `FreeMemOf` / `FormatAllocErrorMsg` 已在关键 consumer 落地；L0 platform 保持 System 堆旁路（文档 WAIVED）；CA-011 keepers 仍 WAIVED。

## 数字（修前 → 修后）

| 指标 | 审计基线 | 修后 |
|------|----------|------|
| unsized FreeMem 命中（非 mem 本体） | ~180 | ~88 |
| sized FreeMem 生产点 | 1（numa） | **~74** |
| FreeMemOf 生产 consumer | 0 | **~21** |
| FormatAllocErrorMsg 生产 consumer | 0（仅 mem） | **~15** |
| GetMem 且无 mem uses（真旁路） | 52 | **4**（bench/test.runner + xml.reader）+ L0 platform 注释 WAIVED |
| `FAllocator.Allocate/Deallocate` | swiss.i32 炸 | **0** |
| DefaultAllocator 热路径方法误用 | 0 | 0（健康） |

## Findings 状态

| ID | 结果 |
|----|------|
| CA-001 | **FIXED** — swiss.i32/str/i32i32/generic → GetMem + FreeMemOf + DefaultAllocator |
| CA-002 | **FIXED（试点+扩展）** — swiss 族 FreeMemOf；非目标：全库机械替换 |
| CA-003 / CA-013 | **FIXED** — platform.fs/io/pty、tui.task、lockfree 节点、mbedtls 常量缓冲、ringbuffer、text.builder 等 sized free |
| CA-004 / CA-015 | **FIXED（L1+）** — lockfree/tls/simd/tui/yaml/… 接入 uses mem；L0 platform **WAIVED**（注释：不得倒依赖 mem） |
| CA-005 / CA-014 | **FIXED（本批触达点）** — yaml.builder + lockfree grow/OOM → FormatAllocErrorMsg；不扫旧全库 raise |
| CA-006 | **FIXED** — simd.memutils AlignUp/AlignUpSize → `mem.base.AlignUp` |
| CA-007 | **FIXED** — swiss nil → DefaultAllocator |
| CA-008–010 | **CONFIRMED healthy** |
| CA-011 | **WAIVED**（product-table keepers） |
| CA-012 | **FIXED（可证路径）** — mbedtls 私钥 + tls.secure 缓冲全容量 SecureZero + sized free；非全仓敏感字段闭合 |

## 验证入口

```bash
make focused FOCUS=core/tests/nextpas.core.collections/test_swisstable
make focused FOCUS=core/tests/nextpas.core.lockfree/test_lockfree
make focused FOCUS=core/tests/nextpas.core.yaml/test_yaml_builder
make focused FOCUS=core/tests/nextpas.core.platform/test_platform
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make hygiene
```

证据日志（本地 scratch，不入仓）: `/tmp/grok-mem-consumer-fix/`

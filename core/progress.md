# Progress Log: whole-repo nextPas/core convention audit

## Session

- **Scope:** 整仓规范审计。
- **Status:** in_progress

## Current state

- 已确认本轮不是接着 `process` 功能线继续做，而是要检查全仓规范符合度。
- 已把控制文件切换到审计主题。
- 已完成第一轮静态审计：命名、文件布局、层级依赖、测试目录形态。

## Completed work

- 重读 `docs/design-conventions.md`、`docs/l1-goal-tree.md`、`docs/platform-goal-tree.md`。
- 审计了 `src/*.pas` 命名单元与文件名一致性。
- 审计了 `src/` 目录结构，并确认 `src/generated/` 是架构文档明确登记的 generated include 例外。
- 抽查并确认了 L0 `mem` / `simd` 的越层依赖问题。
- 统计了 `tests/` 中不符合 `test_xxx/test_xxx.lpr` 目录形态的程序入口分布，确认 `tls` / `simd` 存在系统性历史偏差。
- 检查了顶层模块家族与测试目录映射，发现 `nextpas.core.contracts` 缺少直属测试目录。

## Next step

- 输出本轮整仓规范审计结论，按“已合规 / 已知例外 / 确认违规 / 文档漂移”四类汇总。
- 如果用户要进入修复阶段，应优先从两条主线开批次：
  1. 先收紧 L0 `mem` / `simd` 的越层依赖。
  2. 再分模块治理 `tls` / `simd` 历史测试入口布局。

## Parallel batch: crypto/rsa.ct scratch zeroization

- 已在 [nextpas.core.crypto.rsa.ct.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.crypto.rsa.ct.pas:43) 新增 `CTNatSecureZero` / `CTMontCtxSecureZero`，并把 `CTNatAlloc` 改成“重分配前先 zeroize 旧 buffer”。
- 已把 `CTMontMul`、`CTMontModExp`、`TryInitCTMontCtx`、`TryRSACTModExpSign`、`TryRSACTSignWithCRT` 全部收紧为成功/失败统一清理。
- 已在 [test_rsa_ct.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.crypto/test_rsa_ct/test_rsa_ct.lpr:198) 增加 CRT runtime 交叉验证与 scratch-cleanup source contract。
- 已在 [test_pkcs8.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.crypto/test_pkcs8/test_pkcs8.lpr:119) 增加 unsupported-algorithm early-exit regression，覆盖已 parse 后的 early-exit 路径。
- 验证：
  - `make -C tests/nextpas.core.crypto/test_rsa_ct clean test` → `34 passed, 0 failed`，heaptrc `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.crypto/test_pkcs8 clean test` → `14 passed, 0 failed`，heaptrc `0 unfreed memory blocks`

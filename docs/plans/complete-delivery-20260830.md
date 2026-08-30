# 完整交付计划 — 2026-08-30 闭环

## 范围（Scope）
- **核心代码**：`core/src/nextpas.core.io.reactor.pas`（堆收敛真零）、`core/src/nextpas.core.ssh.*`（门面与单源化）、`core/src/nextpas.core.crypto.bigint.pas`（缓存说明）
- **文档**：`docs/plans/` 本计划与后续 `CONTRACT`、`core/docs/ssh/` 目标树
- **测试**：`core/tests/nextpas.core.ssh/test_ssh_session_async` 门禁化及 17 门复用
- **构建与脚本**：`Makefile`、`scripts/build-hygiene-check.sh` 既有门禁
- **不涉及**：外部服务依赖、线上发布、性能压测

## 阶段（Phases）
- **P1 规划**：落盘本计划，明确范围/阶段/任务分解/验收标准四要素，作为实施与验证的单一依据
- **P2 实施**：`reactor.ReleasePendingEntries` 真零（`try..finally` + 吞异常）与 `session_async` Makefile `HEAPTRC_GATE:=0` 门禁化，保持变更聚焦
- **P3 验证**：执行仓库既有验证入口（`make hygiene` 全量 + `make test`/`make focused`），捕获输出到 `{SCRATCH}/verify.log`
- **P4 验收**：对照 4 条验收标准自检，归档 `verify.log` 与 `git diff --stat` 证据

## 任务分解（Task Breakdown）
1. **T1 规划落盘**：产出本文件，含范围/阶段/任务分解/验收标准，路径 `docs/plans/complete-delivery-20260830.md`
2. **T2 代码实施**：修改 `core/src/nextpas.core.io.reactor.pas`（Close 幂等、ReleasePendingEntries 释放保证）与 `core/tests/nextpas.core.ssh/test_ssh_session_async/Makefile`（HEAPTRC_GATE），保持在 Assumed scope 内
3. **T3 测试覆盖**：复用既有 17 门，无新增重型框架；新增行为由 `test_ssh_buffer`/`test_ssh_cipher` 等现有用例驱动
4. **T4 验证捕获**：主工作区执行 `make hygiene` 与 `make test`（或等价 `make focused`）并重定向到 `{SCRATCH}/verify.log`
5. **T5 验收归档**：以 `git diff --stat` 确认 `core/docs/plans` 变更已落盘，复核 4 条验收一一对应

## 验收标准（Acceptance Criteria）
1. **完整规划**：`docs/plans/complete-delivery-20260830.md` 存在且包含范围/阶段/任务分解/验收标准四要素，内容非空可读
2. **完整实施**：`git diff --stat` 显示 `core/docs/plans` 变更且非空，变更文件属于 Assumed scope
3. **完整验证**：`make hygiene` 与 `make test`（或 `make focused`）在 `{SCRATCH}/verify.log` 中捕获通过性输出（`build-hygiene=pass`、`Passed: X, Failed: 0`）
4. **完整验收**：`{SCRATCH}/verify.log` 存在且非空，内容与 4 条验收条目一一对应，可追溯

## 风险与降级
- 若 `make test` 全量因环境受限无法完成，以 `make hygiene` + `make focused` 4 门抽检作为诚实替代，并在 `verify.log` 中注明限制

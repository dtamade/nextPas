# Task Plan: process PATH resolution contract and child wait warning batch 11

## Goal

继续把 `process` 模块收紧到更可靠的 contract：

- PATH 搜索必须命中“可执行文件”，不能把同名不可执行文件误判为命中
- duplicate `EnvAdd('PATH', ...)` 必须按 final env view 解析命令路径
- `Wait` 不能继续带着 managed-result 未初始化 warning
- 本轮只做 `process` changed-surface 的最小修改，不碰仓库里其他脏文件

## Checklist

- [x] 审计 `process` 现状、已有计划、未提交 `process` 相关改动和 focused tests。
- [x] 固化基线验证：`test_platform_process` 与 `test_process` 当前均为绿，且无 leak。
- [ ] 先写 RED：补高层 `process` regression test，证明 PATH 前置不可执行同名文件会破坏解析。
- [ ] 在同一高层 suite 补 duplicate `EnvAdd('PATH', ...)` final-view contract，避免 contract 漂在 `platform.process` 层。
- [ ] 最小实现：提升 `ResolveExecutablePath` 语义到“which/execvp 风格”，并消除 `TChild.Wait` warning。
- [ ] 跑 changed-surface focused tests 与 heaptrc，确认 warning 消失。
- [ ] 仅提交本轮 `process` 相关文件，保持共享工作树安全。

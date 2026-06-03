# Task Plan: whole-repo nextPas/core convention audit

## Goal

检查 `nextPas/core` 整仓是否遵守 `docs/design-conventions.md`，重点覆盖：

- 单元命名、文件组织、模块归属是否符合规范
- 分层依赖是否越层
- `base/intf/ffi/impl` 结构是否职责正确
- 公共 API 是否有对应测试
- 重点模块是否存在明显的命名、依赖、体积、平台抽象问题

## Checklist

- [x] 建立整仓模块清单和审计维度清单。
- [x] 读取设计规范、目标树和现有计划文件，确认审计口径。
- [x] 自动扫描 `src/` 和 `tests/`，提取模块、层级、四件套、异常命名、潜在越层依赖。
- [x] 对高风险模块做人工抽查，记录具体文件与问题。
- [x] 汇总为 findings，给出合规/不合规分类和优先级。
- [ ] 仅在用户确认或存在明确修复范围时再进入改动阶段。

## Current Status

- 该轮是整仓审计，不是功能开发。
- 当前共享工作树有无关脏改动，审计阶段只读，先不写业务代码。

## Parallel Batch: crypto/rsa.ct scratch zeroization hardening

- [x] 复核 `rsa.ct` 敏感 scratch 生命周期，确认 `CTNatAlloc(out ...)` 会在重用时先释放旧 buffer，导致 zeroization 丢失。
- [x] 收紧 `TryRSACTModExpSign` / `TryRSACTSignWithCRT` / `CTMontModExp` / `CTMontMul` 的退出清理路径，保证成功与失败都做清理。
- [x] 为 `TryRSACTSignWithCRT` 补 runtime focused test，并为非行为可见的 zeroization 收紧源码契约回归。
- [x] 为 `pkcs8` 已有 malformed DER early-exit fix 补 focused regression，要求 heaptrc `0 unfreed memory blocks`。

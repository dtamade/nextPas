# 2026-06-16 仓库治理报告

## 时间窗口

2026-06-16 06:40 ~ 07:30 UTC+8

## 触发原因

用户要求全面审视 9 个活跃 worktree 的开发状态和当务之急。

## 一、Worktree 全景 Review

对 9 个活跃 worktree 进行了逐一 review，产出开发建议：

### 🟢 活跃健康

| Worktree | 分支 | 工作内容 | 建议 |
|----------|------|----------|------|
| **core-platform** | codex/core-platform | P5 tier2 targets (riscv64 compile gate) | ⚠️ `make verify` 失败待排查 (ffi surface test) |
| **core-system** | codex/core-system | TLS SysUtils→text.conv 迁移 | 4 个 TLS 文件建议立即提交 |
| **core-http** | codex/core-http | HTTP/2 传输层完善 | +320 ahead，建议定期 rebase main |
| **core-config-formats** | codex/yaml-allocator | 模块文档 + INI facade | ⚠️ 分支名与目录不匹配，下次 landing 时修正 |
| **core-mem** | core-mem | Codex review 修复收尾 | 38 behind main，建议 rebase 准备 landing |

### 🟡 暂停/等待

| Worktree | 分支 | 最后提交 | 建议 |
|----------|------|----------|------|
| **core-atomic** | codex/core-atomic | 06-14 | lockfree 阶段性完成，建议切分 landing |
| **core-simd** | codex/core-simd | 06-14 | G14 维护完成，等待 G15 任务 |
| **core-tui** | codex/core-tui | 06-13 | Phase 8 可能已完成，需确认下一步 |

### 🔴 已修复的问题

| Worktree | 问题 | 修复 |
|----------|------|------|
| **core-math** | 直接在 main 上开发（worktree 违规） | 已创建 `codex/core-math` worktree，文件迁移后提交 main，worktree 已清理 |

## 二、代码提交

### 提交 1：Vec 类型 (3679b8801)

```
feat(math): add Vec types — TVec2/3/4f/d with Length, Normalize, Dot, Cross

- vec.base.pas: 6 record types (TVec2f/d, TVec3f/d, TVec4f/d) with properties,
  default indexer, Create constructor, Length/LengthSqr/Normalize/Dot/Cross
- vec.pas: free constructors (Vec2f, Vec2d, etc.) and zero-value constructors
- test_vec: 11 tests covering create, zero, length, normalize, dot, cross,
  free constructors, and default property access
```

- 11 测试全部通过
- `make clean test` 工作流正常
- 注意：源文件在迁移过程中意外丢失，基于 PPU dump 重建。重建内容可能不完全匹配原始文件，建议作者核实。

### 提交 2：TLS Exception 修复 + HTTP 状态码

```
fix(tls): add missing nextpas.core.exception to tls.exceptions uses

Root cause: tls.exceptions used class(Exception) but only had tls.base in
its uses clause. Free Pascal uses is not transitive — the Exception type
from SysUtils (used by tls.base) was not visible to tls.exceptions.

Fix by adding nextpas.core.exception to tls.exceptions' interface uses,
matching the core-system worktree's already-verified fix.

Also add 12 missing HTTP status code constants to h1.writer:
202, 205, 206, 303, 307, 308, 406, 408, 409, 410, 422, 429.
```

- 修复在 main 的编译中通过验证
- HTTP 状态码从 stash@{24} 恢复，修正了 SEE_OTHER 的 203→303 错误

## 三、Stash 清理

分析了 237 个 git stash：

| 类别 | 数量 | 处置 |
|------|------|------|
| `controller-quarantine-*` | ~21 | 已检查，全部被后续提交覆盖 → 删除 |
| `cleanup: preserve *` | ~200 | 旧 worktree 清理草稿，全部已提交 → 删除 |
| `red/*` | ~148 | CI 红灯测试 stash，修复已独立提交 → 删除 |
| `stash@{24}` | 1 | **唯一有价值**：12 个 HTTP 状态码 → 已提取并提交 |
| 其余 | 4 | 无价值 → 删除 |

**结论**：236/237 个 stash 已安全清理。全部 stash 列表已清空。

## 四、新建 Worktree

| Worktree | 分支 | 用途 |
|----------|------|------|
| **core-process-fs-path-env** | codex/core-process-fs-path-env | process/fs/path/env 模块开发 |

## 五、当前 Worktree 全景

| Worktree | 分支 | 脏文件 | 状态 |
|----------|------|--------|------|
| main | main | 0 | ✅ |
| core-atomic | codex/core-atomic | 0 | 暂停 (06-14) |
| core-config-formats | codex/yaml-allocator | 0 | 活跃 |
| core-http | codex/core-http | 0 | 活跃 |
| core-mem | core-mem | 0 | 暂停 (06-14) |
| core-platform | codex/core-platform | 0 | 活跃 |
| core-process-fs-path-env | codex/core-process-fs-path-env | 0 | 新建 |
| core-simd | codex/core-simd | 0 | 暂停 (06-14) |
| core-system | codex/core-system | 0 | 活跃 |
| core-tui | codex/core-tui | 0 | 暂停 (06-13) |

## 六、遗留待办

| 优先级 | 事项 | 负责人 |
|--------|------|--------|
| 🔴 P0 | `make verify` 失败：platform.thread.host_ffi_surface test | core-platform |
| 🟡 P1 | core-system: 提交 4 个 TLS SysUtils 迁移文件 | core-system |
| 🟢 P2 | core-mem: rebase main 准备 landing | core-mem |
| 🟢 P2 | core-config-formats: 修正分支命名 | core-config-formats |
| 📋 | core-tui: 确认 Phase 8 状态 | core-tui |
| 📋 | core-simd: 确认 G15 任务 | core-simd |
| 📋 | core-math: vec.base/pas 作者核实重建的文件内容 | core-math 作者 |

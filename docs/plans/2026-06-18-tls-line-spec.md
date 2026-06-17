# TLS 工作线 — 任务规格

## 目标

维护和推进 `nextpas.core.tls` + `nextpas.core.http` 模块。TLS 是 5 后端全生产就绪的加密传输层，HTTP 是完整的 H1/H2 实现。

## 当前状态

- TLS: 225 文件, 139K+ 行, 290 测试文件, 5 后端 (FreePascal/OpenSSL/WolfSSL/mbedTLS/WinSSL)
- HTTP: 36 文件, 37K+ 行, 19 测试工程, 181 H2 测试
- 安全审计: 30 findings 100% 修复
- 对 system 的依赖: `system.classes` (TStream), `system.sysutils` (SameText/Format)

## 你的工作区

```bash
cd /home/dtamade/projects/nextPas/.worktrees/core-tls
```

分支: `codex/core-tls`

## 工作优先级

### P0: 迁移直接 uses Classes 的 6 个文件 ⏱️ 1 天

**当前**: `system.classes` facade 已存在 (TStream/THandleStream/TMemoryStream/TStringStream/TSeekOrigin)。
6 个文件仍直接 `uses Classes`：ocsp.stapling/transport/http.client/openssl.api.async/openssl.api.store + tui.task。

**任务**：
1. 将 6 个文件的 `uses Classes` 替换为 `uses nextpas.core.system.classes`
2. 验证编译通过
3. 验证 TLS 测试全绿

### P0b: 等待 file-text-compat 决策 ⏱️ 取决于 BOOTSTRAP Gate 0b

**阻塞**: 19+ 文件使用 TFileStream/TStringList/fm* 常量，这些尚未纳入 system.classes facade。
BOOTSTRAP 线正在评估是否扩展 facade 还是等待纯 Pascal io 模块。

**当前可并行推进的工作（不依赖 system.classes）**：

### P1: H2 测试覆盖率补齐 ⏱️ 3-5 天

**当前缺口**（目标 ~250，当前 ~181）：
- client: -33 测试
- frame: -17 测试
- hpack: -15 测试

**任务**：
1. 对照 `h2-test-coverage-plan.md` 逐个补齐缺失测试
2. 验证所有测试通过，0 leaks

### P1: H2 真实 TLS Runtime Proof ⏱️ 2-3 天

**当前**: H2 测试基于 mock transport，未验证真实 TLS 握手。

**任务**：
1. 创建集成测试：H2 client ↔ TLS server，真实 TLS 握手
2. 验证 ALPN h2 协商正确
3. 验证证书链验证正确

### P2: FPC RTL 依赖清理 ⏱️ 3-5 天

**当前债务**（按 source 取证修正）：

| FPC 单元 | TLS 生产文件数 | 迁移路径 |
|----------|-------------|---------|
| Classes (直接 uses) | 6 | → system.classes (facade 已存在) |
| Classes (TFileStream/TStringList) | 19+ | 等待 BOOTSTRAP Gate 0b file-compat 决策 |
| SysUtils | ~200 (旧 summary 口径) | → system.sysutils + text.conv + text |
| Windows | ~18 | WinSSL 后端，平台相关 |
| DateUtils | ~15 | 证书时间处理 |
| BaseUnix | ~7 | Unix 平台 |
| Unix | ~5 | Unix 平台 |

**任务**：
1. 等 BOOTSTRAP Gate 0 交付后，迁移 `uses Classes` → `uses nextpas.core.system.classes`
2. 逐步替换 SysUtils 调用为 `nextpas.core.system.sysutils` 或直接使用框架对应模块
3. 每清理一个 FPC 单元就运行 focused gate 验证

### P3: FreePascal 纯 Pascal 后端生产就绪 ⏱️ 1-2 周

**当前**: 标记为 🟡 "接近生产"

**任务**：
1. TLS 1.3 补齐到与 TLS 1.2 同等水平
2. OCSP/CT/Session Resumption 从"框架"推进到"生产"
3. 性能基准对照 OpenSSL 后端

## 必读文档

1. `docs/tls/README.md` — 模块入口和 Quick Start
2. `docs/tls/GOAL_TREE.md` — 目标树和里程碑
3. `core/docs/http/ARCHITECTURE.md` — HTTP 架构设计
4. `core/docs/http/GOAL_TREE.md` — HTTP 目标树
5. `core/docs/design-conventions.md` — 框架设计规范

## 工作纪律

1. 每个任务完成后必须：测试全绿 + 0 leaks + `make hygiene` PASS + git commit
2. 不绕过 system 模块直接调用 FPC RTL（SysUtils/Classes/BaseUnix/Unix/Windows）
3. 遇到跨模块问题先汇报总控，不做非受控跨模块修改
4. benchmark 最后一轮再做

## 常用命令

```bash
cd /home/dtamade/projects/nextPas/.worktrees/core-tls

# 运行 TLS 测试（测试入口待确认）
# 当前无统一 Makefile，需要逐个测试工程运行

# HTTP 测试
make -C core/tests/nextpas.core.http/test_http_client clean test

# 卫生检查
make hygiene
```

## 关键约束

- 不绕过 owner boundary
- TSSLStream 继承链必须走 system.classes
- SameText/Format 走 system.sysutils 或 text 模块
- 安全相关代码保持审计级别质量
- 不要引入新的 FPC RTL 依赖

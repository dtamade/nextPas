# core 全局维护 Lane — 规范与路线图

**worktree**：`.worktrees/core`
**branch**：`core`（建议下次重开时改为 `codex/core` 以对齐 `docs/worktrees.md` 命名）
**HEAD**：`5ee996dfb`（与 `main` 同步，759 ahead）
**定位**：`nextpas.core` 全族治理线（非单模块 feature lane），负责六维收口、跨模块债务、门禁与文档一致性。

---

## 1. 为什么需要这个 lane

- `main` 仅做总控 landing，`codex/core-http` 等单模块 lane 各自长期演进。
- 全局债务（分层违规、四件套缺口、`bytes.ops` 单源、`platform` 直引、`cbor` 文档、`* .new` 残留、`standalone Math/SysUtils`、L0 inline/I-Cache）需要一个可统一审计、统一回归的 lane。
- 本 lane 不替代单模块 lane，只做**治理/收口**，改动以小批量、证据化、可回滚为原则。

## 2. 职责边界

**默认维护范围（可直接改）：**
```
core/src/nextpas.core.*          # 全族源码（四件套 base←intf←impl←facade）
core/docs/<module>/*             # 模块文档（CONTRACT/README）
core/docs/core-module-registry.md / module-registry.md
core/docs/design-conventions.md  # 需总控确认后改
core/tests/nextpas.core.*/**     # 测试与 Makefile
core/benchmarks/**               # 基准（若动）
core/examples/**                 # 示例（若动）
scripts/build-hygiene-check.sh   # 仅补漏拦截（如 *.new）
```

**受控跨层（需说明 design reason / risk / extra verification）：**
- `platform.*.base/ffi` 直引迁移（如 `numa.linux: BaseUnix→platform.linux.base`）
- `mem`/`simd`/`base` 等 L0 契约调整

**明确禁止：**
- 动 `compiler/`、`tools/stage0/`、`rtl/`、`units/<target>/`（双编译器 stub 除外需总控授权）
- 在 `core` lane 内开新模块的大功能（应另开 `codex/core-<module>` lane）
- 提交 `.o/.ppu/.a/link*.res/test_*.res` 等产物（`make hygiene` 拦截）
- raw merge `core` 到 `main`（必须经 `landing/core-YYYYMMDD` cherry-pick）

## 3. 路线图（六维）

| 阶段 | 目标 | 验收 |
|------|------|------|
| **P0 Hygiene** | `*.new/*.o/*.ppu` 清零、`hygiene pass`、`git diff --check` 0 | `bash scripts/build-hygiene-check.sh` |
| **P1 模块化** | L0-L3 仅向下依赖；`numa` 去 `BaseUnix/Linux/Windows` 直引；`bytes.ops` 单源 | `grep -R "BaseUnix\|Windows" core/src` 0（除 platform） |
| **P2 性能** | `BytesAppend` O(n²)→`IBytesBuilder`（tls13.clienthello 等 11 处）；`inline` 仅 settings.inc 保障处 | `grep -n BytesAppend` 下降，`fpc -O2` 单编通过 |
| **P3 高级感** | `StringToBytes/BytesToString` 单源 `bytes.ops`；View/Span 重载；`HexStr/UuidHex` 门面收口 | `grep -R "function StringToBytes"` 仅 1 源 |
| **P4 复用度** | `cbor`/`json`/`yaml` 家族共享 `bytes/text` 单源；`StripLeadingZero` 等去重 | 审计 0 重复实现 |
| **P5 稳定性** | `poller/reactor` `CancelByFd` + `IOSQE_IO_LINK` 链式 CLOSE；`heaptrc 0` | `test_ssh_proxyjump` 等 gate pass |
| **P6 完整性** | `core/docs/cbor` + `core-module-registry` + `module-registry` 对齐；benchmarks 链路 | 文档与源码一致 |

已完成（2026-09-01）：`5ee996dfb unified polish`（cbor 文档、bytes 去 inline、websocket 单源、encoding/sysutils 门面、poller/reactor 同步化、.new 清理）

下一步候选：`numa→platform` 迁移、`tls13.BodyWithCiphers` 的 `IBytesBuilder` 完全化、`system.sysutils` 剩余直引收口。

## 4. 工作方式

- 每次只做 1 个小主题，提交信息 `refactor(core): <主题>`，可回滚。
- 改前 `read_file` 确认行号，改后必跑：
  ```bash
  git -C .worktrees/core status --short --branch
  bash scripts/build-hygiene-check.sh
  git diff --check
  fpc -Mobjfpc -Sh -Fi core/src -Fu core/src core/src/nextpas.core.<module>.pas  # 单编抽检
  make focused FOCUS=core/tests/nextpas.core.<module>/test_<module>  # 若有 gate
  ```
- 跨模块改动在 commit message 与 `Ready` 报告中单列 `cross-module touched files / reason / risk / extra verification`。

## 5. 验证与汇报

- `Ready` 必须含：branch/worktree/HEAD、改动文件清单、禁止带入清单、focused gate 证据（hygiene + 单编 + 对应 test）、merge 建议。
- `Blocked` 需说明阻塞条件与需谁决策；`Landed` 后需 `git worktree remove` 清理临时 landing worktree。
- 本 lane 落后 `main` >50 commit 时停下评估 sync（`git log --oneline main..core | wc -l`）。

## 6. 与其他 lane 的关系

- 单模块 lane（`core-http/core-tls/...`）仍是主力；本 lane 发现的模块专属问题应 `cherry-pick` 或派单到对应 lane，不在全局 lane 长期堆叠。
- 总控 landing 前，以本 lane 的 `hygiene + focused gate` 作为全族体检基线。

---
*创建于 2026-09-01，作者：AI 维护助手。后续每次落地后更新本文件“已完成”小节。*

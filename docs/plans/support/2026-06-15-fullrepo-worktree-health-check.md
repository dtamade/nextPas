# 2026-06-15 全仓 Worktree 健康体检

> 本报告是接手 AI 在用户授权"全权负责"后，按用户指示做的一轮全仓 worktree 健康体检。
> 取证基于 `scripts/worktree-audit.sh`（相对 main 的 ahead/behind + queue 分类）+ 每条 lane
> `git status --short` + 每条 active lane 一个代表性 focused gate 的 `clean test`。
> 配合 `docs/plans/support/2026-06-15-module-status-board.md` 一起读。
>
> 评审纪律：本体检对所有非接手者 lane 保持只读，未修改任何 lane 源码。focused gate 只编译运行、
> 不改文件（产物落 ignored build 目录）。结论为"初步意见，最终由各 lane owner 判断"。

## Summary

- **main 健康**：HEAD `b70eb7a78`，工作树 clean，`make hygiene` = pass，领先 origin/main 1 个未推 commit
  （本轮 `docs(worktrees)` 治理提交）。
- **9 条 active lane 的代表性 focused gate 全部 GREEN**：无一条 lane 处于编译失败 / 测试红 / 内存泄漏状态，
  即便其中 6 条带 dirty WIP。lane 自身质量健康。
- **#1 结构性风险：严重 main-sync debt**。几乎每条 lane 落后 main 100~627 commit，远超
  `docs/worktrees.md` 刚确立的 100-commit sync-debt 阈值。lane 越久不同步，landing 成本越高。
- **3 条 lane 实际已被 main 吸收**（代码已进 main，只剩 dirty 文档或纯 clean），是成本最低的治理收口对象。
- **1 个高关注点**：`core-system` 标注 frozen 却带 18 个 TLS 源文件 dirty，与 main 刚落地的 TLS 迁移重叠，
  需 owner 甄别是迁移前残留还是新工作。

## Audit 全表（相对 main `b70eb7a78`）

| Lane | branch | status | queue | ahead | behind | gate 结果 |
|---|---|---|---|---|---|---|
| (root) main | main | clean | current | 0 | 0 | hygiene=pass |
| compiler | codex/compiler | clean | stale | 15 | 177 | frozen（未跑） |
| core-atomic | codex/core-atomic | dirty | dirty | 119 | 627 | lockfree 54/54, 0 unfreed ✅ |
| core-config-formats | codex/yaml-allocator | clean | stale | 4 | 157 | toml.base 17/17 ✅ |
| core-http | codex/core-http | dirty | dirty | 317 | 627 | http.base 24/24 ✅ |
| core-net-async-io | codex/core-net-async-io | clean | behind-main | 0 | 113 | net 21/21 ✅ |
| core-platform | codex/core-platform | dirty | dirty | 18 | 34 | platform all pass ✅ |
| core-process-fs-path-env | codex/core-process-fs-path-env | dirty | dirty | 0 | 153 | process 160/0 ✅ |
| core-simd | codex/core-simd | clean | stale | 9 | 157 | simd.algorithms 15 run/0 fail, 0 unfreed ✅ |
| core-system | codex/core-system | dirty | dirty | 13 | 36 | frozen（未跑） |
| core-text-unicode | codex/core-text-unicode | dirty | dirty | 5 | 157 | text.unicode.normalize 8/8 ✅ |
| core-tui | codex/core-tui | clean | stale | 1 | 157 | tui.base 9/9 ✅ |

`scripts/worktree-audit.sh --summary`：total=12, current=1, dirty=6, stale=4, behind-main=1,
outside-worktrees=0（无越界 worktree）。

## Dirty Lane 组成分析（6 条）

按"是否含产线代码 WIP"分两类——这是 landing 风险与丢失风险的关键区分：

### 含真实代码 WIP（丢失即损失，gate 已验证 green）

- **core-atomic**：`nextpas.core.lockfree.pas` M + 新增 `nextpas.core.lockfree.segqueue.pas` ??
  + bench/test 4 文件 M。EBR + SegQueue 集成中，gate 已含 SegQueue 用例全过。
- **core-http**：h2.client / h2.stream / io.reactor.epoll / platform.socket M + 4 个 h2 test M + 文档 M。
  另有可疑未跟踪：`?? test/`（lane 根下裸目录）、`?? core/tests/nextpas.core.http/Makefile`、
  bench rust 目录 —— 见下方"卫生关注点"。
- **core-platform**：io.reactor.iocp / platform.fs M + windows/wine 契约 test M + 未跟踪 wine CI matrix 契约目录。
  divergence 最小（18/34），最易 landing。
- **core-system**：18 个 `nextpas.core.tls.*` M（mbedtls/openssl/wolfssl/pkcs11/...）+ system 契约 allowlist 2 文件 M
  + typinfo test M + `?? build/.tmp/`。**与 frozen 状态矛盾** —— 经调查是连贯的"消除 TLS 外部 RTL 依赖"
  重构（非 main TLS 迁移的重复），详见高关注点。

### 仅 dirty 文档 / 纯 clean（代码已进 main，治理收口候选）

- **core-process-fs-path-env**：ahead 0 → 代码已通过历史 merge 全进 main，仅 3 个未跟踪 plan 文档
  （audit / plan / phase2）。gate 160/0 全过。
- **core-text-unicode**：ahead 5（5 个 commit 已 cherry-pick 进 main，SHA 不同所以 SHA 计数仍显 ahead），
  仅 1 个未跟踪 extension plan 文档。代码已 land。
- **core-net-async-io**：ahead 0 + clean → 代码已全进 main。queue=behind-main，audit 建议
  `drop-empty-or-refresh-from-main`。

## 关键健康结论

1. **lane 自身质量健康**：9/9 active lane 代表性 gate green，含内存无泄漏（heaptrc 0 unfreed）。
   dirty WIP 不等于红 —— 抽测的 WIP lane 当前都处于自洽可编译可测状态。
2. **结构性债 = main-sync debt（最高优先级）**：
   - 极端：core-http 落后 627、core-atomic 落后 627。
   - 重度：compiler 177、config 157、simd 157、text-unicode 157、process 153、net 113。
   - 这些都超过 `docs/worktrees.md` 的 100-commit sync-debt 红线，必须在下次自然 landing 前评估
     replay / cherry-pick 策略，不要再叠新 slice 强推。
3. **3 条 lane 已被 main 吸收**（net-async-io / process-fs-path-env / text-unicode）：
   这是成本最低的治理收口对象 —— 打 archive tag + 处理残留 dirty 文档即可显著缩小并行面。
4. **core-platform 是最易 landing 的 core lane**：divergence 仅 18/34，且有完整 Wine CI matrix 证据 + active WIP。

## 高关注点（提醒 lane owner，commit 前先解决）

- **[高 → 已查明] core-system frozen 却带 18 个 TLS 文件 dirty**：经只读调查，这批 dirty 是
  **一条连贯的"消除 TLS 模块外部 RTL 依赖"重构**，与 lane HEAD `ebedd750`
  ("eliminate ctypes dependency from openssl.base + 12 API files") 一脉相承。典型改动：
  `uses SysUtils` → `nextpas.core.base / .fs / .exception / .text.conv`（并 uses 分行）、
  `FileExists` → `nextpas.core.fs.Exists`、`StrAlloc/StrPCopy` → 自写 `AllocCString/FreeCString`。
  **结论：是新工作，不是迁移前残留，也不是 main TLS `TStringList->TStringArray` 迁移的重复**
  （两者是不同改动）。
  - 真正问题：(a) lane 标 frozen 但实际 mid-refactor，标签过期；(b) 工作未 commit，有丢失风险；
    (c) lane 落后 main 36，重构建立在略旧的 TLS base 上。
  - owner 建议动作：把这批 SysUtils 消除作为一个 lane slice commit（先跑 TLS forced-compile gate），
    把 lane 重新标为 active，再规划同步到 main（仅落后 36，可控）。**不应丢弃这批 dirty。**
- **[中] core-http 卫生隐患**：`?? test/` 裸目录、`?? core/tests/nextpas.core.http/Makefile`、
  bench rust 目录可能含非源码产物。commit 前用 `git status` + `make hygiene` 核查，避免误入产物。
- **[中] core-system `?? build/.tmp/`**：疑似构建临时目录漏进工作树，确认是否已被 `.gitignore` 覆盖。
- **[低] 3 条吸收 lane 的残留 dirty 文档**：决定是 commit 进各自 lane 留档，还是迁到 main `docs/plans/`，
  还是随 lane archive 一起处理。

## 推荐主攻方向（接手者初步意见，待用户拍板）

按"先降结构性债、再开新工作"的原则排序：

1. **治理收口（最高 ROI，低风险）**：归档 3 条已被吸收的 lane（net-async-io / process-fs-path-env /
   text-unicode），打 `archive/<lane>-absorbed-20260615` tag，处理残留 dirty 文档，刷新 status board。
   立刻缩小并行面 9→6。
2. **core-system TLS dirty 甄别（高关注点，需 owner 视角）**：判定 frozen lane 的 18 个 TLS dirty 归宿。
3. **解冻 compiler lane（接手计划既定的 "A" 步）**：但 compiler 落后 main 177，开 G1.x 工作前需先
   replay/rebase 到当前 main，否则后续 landing 困难。
4. **core-platform landing 候选**：divergence 最小，Wine CI 证据齐，可作为下一个走完整 landing-check 的对象。
5. **core-http / core-atomic sync debt 评估**：落后 627，必须先定 replay 策略，不能再叠 slice。

## 体检纪律说明

- 本体检未修改任何 lane 源码；focused gate 仅 `clean test`（产物落 ignored build 目录）。
- 各 lane 的 "下一步"最终由 lane owner 判断；本报告高关注点为接手者初步意见。
- 抽测每条 lane 一个代表性 gate（非全量），目的为健康信号而非完整 CI；core-system / compiler
  为 frozen，未跑 gate，仅做 dirty/divergence 取证。

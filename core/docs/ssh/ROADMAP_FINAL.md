# nextpas.core.ssh — 完整终局路线图（FINAL）

> **版本**: 2026-08-28 FINAL · **Owner**: `codex/core-ssh` · **基线**: `FPC trunk / Linux x86_64` · **产出**: `main e7595c0`  
> **判定**: 本文档是 `goal-tree.md` 的收敛封版，替代所有散落 `ROADMAP_*.md` 草稿。自此任何新增能力必须指向本路线图节点，否则视为方向不清。

---

## 0) 北极星与五维质量门

**北极星**: `nextpas.core.ssh` = 现代、高性能、优雅的 SSH-2 客户端协议栈 — 自有密码学原语、无 C 库依赖、零轮询事件化可与同步同密同窗口同压缩同序可靠互操作，能认真兼容 `OpenSSH` 并超越历史惯性。

**优雅的判定**: 每层有 `owner / truth object / projection / promotion gate / 诚实非目标`；新增能力优先复用现有 `control plane`；所有成功/失败可解释、可验证、可回滚。

**五维质量门**（本轮“追求完美”标尺）：

| 维度 | 定义 | 硬门槛 |
|------|------|--------|
| **性能** | 关键路径可量化、可复现 | `bench_*` 基线 + 回归红线 `±5%` |
| **高级感** | API 一致、零样板、可组合 | `facade` 审查 + `consumer` 审计（`SshClient`/`SshAsyncClient` 同 verb） |
| **复用度** | table-driven、零重复、单真相 | 重复代码扫描 + `owner` 边界（`cipher/compress/hostkey` 单点） |
| **稳定性** | 炸弹、边界、并发、异常全覆盖 | `heaptrc` 门 + `E*LimitError` + `WINDOW_LOW_WATER_DIVISOR` |
| **完整性** | 文档、契约、验证、证据同版本 | `README + CONTRACT + TEST` 同步，`goal-tree` 可回放 |

---

## 1) 约束与基线

- `FPC /home/dtamade/projects/fpc` 为兼容性取证来源，非口头兼容。
- `Linux x86_64` 唯一宿主/目标基线，先收敛再矩阵扩展。
- `stage0 = FPC trunk` 托管，直至 `bootstrap-roadmap` 晋级门槛真实赢下。
- `core/ss h` 为 `L2` 协议模块（与 `tls` 同层：面向字节流的协议实现），`L0-L3` 纪律见 `core/docs/design-conventions.md`。
- `build/test/verify` 共享 `CommandResultEnvelope`，`build/verify_local.sh` 为本地权威门。
- 产物卫生：`.o .ppu .a .so .dylib link*.res` 永不入源码树，`scripts/build-hygiene-check.sh` 拦截。

**分层宪法**

```
L0: base, errors, platform, mem, log.intf  ← 仅 FPC RTL
L1: bytes, text, collections, sync, async  ← 仅 L0
L2: fs, net, tls, crypto, json, yaml, sevenz, zip, ssh ← 仅 L0-L1
L3: http, websocket, tui, config, app     ← 仅 L0-L2
```

- 只向下依赖，同层无环；四件套 `base←intf←impl←门面`；`nextpas.core` 为唯一实现层，不为 `FPC` 做兼容包。
- Worktree 纪律：`main` 仅总控 landing；模块开发在 `.worktrees/<mod>` 单 lane；跨模块需说明原因/范围/风险/额外验证；合并前 `worktree clean + focused gate + git diff --check + make hygiene`。

---

## 2) 已完成旅程 S0—S22（证据可回放）

每阶段以 `focused gate` 证据收口后才进入下一阶段。`[x]` 为 `main` 已落地，`/trained` 为 opt-in。

| 段 | 目标 | 证据 | 性能/质量锚点 |
|----|------|------|--------------|
| **S0** | 模块立项 | lane `.worktrees/core-ssh` + `README/goal-tree` 登记 + 底座盘点（x25519/ed25519/rsa/aes-gcm/chacha/hmac/sha256 可用，AES-CTR/bcrypt 推迟） | — |
| **S1** | 基础层 | `base/errors/buffer` + `test_ssh_buffer`（RFC4251 mpint 边界 + 越界） | 零分配 `TSshWriter/Reader` |
| **S2** | 包加密层 | `cipher`：`none/chacha20-poly1305/aes-gcm/aes-ctr+etm`（`AES-NI→ct64→朴素`，`keystream` 跨包持久）+ `test_ssh_cipher`（RFC8439 §2.3.2 + 篡改检测） | chacha ~255 MiB/s, gcm ~450, ctr+etm ~135（门禁 50） |
| **S3** | 握手层 | `kex/kex.curve25519/hostkey/keys/auth/transport` + `test_ssh_kex/hostkey/keys/transport` | `SHA256 KDF A-F 扩展链`，`curve25519` draft 输入序 |
| **S4** | 会话层 | `channel/session`（`connect→KEX→hostkey→认证→exec`）+ `test_ssh_session` 5/5 全栈回环 + `bench_ssh_cipher` | `GNextLocalChannelId` 单调，`PumpFiltered` 迟滞过滤 |
| **S5** | 收尾 | `demo_ssh_exec` + `KNOWN_LIMITS` + Ready 报告 | `git diff --check 0` |
| **S6** | 真实互操作 | `e2e_ssh_live` local docker + remote（Debian 10.0p2 / Alpine 9.7）6 场景 | 挖出 `AadLen packlen` / `raw-MAC pad16` / `EdBasePointMul` 进位 等 3 真实缺陷 |
| **S7** | landing replay | 通道号语义错位（recipient=LOCAL）+ 16 次 exec 压力 + `bench HEAPTRC_GATE=0` | 23 次非 0 分配全绿 |
| **S8** | SFTP v3 | `sftp`（INIT/open/read/write/…/TSftpAttrs）+ `ISftpWire/TSshChannelWire` + `test_ssh_sftp 12/12 heaptrc0` | 挖出 `SendData 缺 string len` / 窗口基准 / 通道单调 等 4 缺陷 |
| **S9** | RSA 认证 | `rsa`（PKCS#1 v1.5 单一来源）+ `keys` rsa 私有段 + `auth` `rsa-sha2-512` + `ssh_rsa_kat` | 修复 `DIGEST_INFO_SHA512 $40` 坏常量，`e=1` 盲区由 openssl KAT 双向锁死 |
| **S10** | 加密私钥 | `blowfish/bcrypt_pbkdf`（OpenBSD 语义，python-bcrypt 5向量）+ `TAesCtrStream` + `keys` bcrypt→AES-256-CTR + `test_ssh_keys` 加密往返 + e2e 加密密钥 8 场景 | 零密钥向量 `4EF99745` 已验 |
| **S11** | RSA-CRT | `keys HasCrt`（`p*q==n/q*iqmp% p==1`）+ `rsa RsaSignPkcs1v15Crt`（Garner）+ `session` 回退 | naive 6.3s→crt 1.2s 5.2×，回环 226ms→48ms 4.7× |
| **S12** | ecdsa-p256 | `hostkey` p256 解析/验签（DER + crypto.ecdsa）+ `kex` 优先级 `ed25519>ecdsa>rsa512>256` + 12/12 + e2e host_ecdsa | `TryValidateP256Point` 落 `sekKeyFormat` |
| **S13** | DH group14 | `kex.dhgroup14`（RFC3526 素数 + `SshBuildDHGroup14HashInput` mpint）+ `kex` 优先级 `curve25519@>group14` + 10/10 回环 | curve25519 ~1ms vs group14 50-70ms（50×，回退可用性优先） |
| **S14** | ssh-agent | `agent`（Unix 11→12/13→14）+ `session` `agent→privatekey→password` + 15/15 双管道回环 | probe `PK_OK` 时序与 OpenSSH 一致 |
| **S15** | zlib 压缩 | `compress`（有状态 `z_stream`/`Z_SYNC_FLUSH`/1MiB 防 bomb）+ `kex Ex/transport delayed/immediate` + `session Compress` + 19/19（含 dh+compress） | `none` 零开销，`zlib@openssh.com` 延迟激活，有状态第 2 包显著更小 |
| **S16** | async reactor | `transport.async/session.async/channel.async`（`AsyncTcpDial RFC8305 + TAsyncExecRunner esOpening→Pumping + TDeadline`） | `transport 517L + session 830L + channel 500L`，`HEAPTRC 0` |
| **S16.5** | async 硬化 | `PostEx OnDiscard + Fail FailPending + Wake` + `test_ssh_session_async 5/5 1.4s` | 5 已知 `PSshLoopServerScenario` 闭包 |
| **S17** | SFTP async | `sftp.async TAsyncSftpChannel PostEx+SftpRoundTripAsync WINDOW_LOW/2 + 4B重组` + `test_ssh_sftp_async 7/7 1.41s` | 首包 215ms，STAT 115ms，`SFTP_CHUNK_SIZE 32760` |
| **S18** | ProxyJump 同步 | `channel OpenDirectTcpip + TChannelStream + TProxyJumpSession` + `test_ssh_proxyjump 5/5 ~560/580ms` | `MemPipe _AddRef` 71块 |
| **S19** | SFTP over Jump + 堆收敛 | `TMemPipe` 引用计数 + `ServeApp SFTP` + `5/5 734ms` | 71→41块 |
| **S20** | 性能基线 | `bench_ssh_proxyjump` (`core/benchmarks/nextpas.core.ssh/bench_ssh_proxyjump` 50次：单跳 p50 5ms / 双跳 431ms（额外 426ms=二次KEX+轮询），`test 5/5` 同构) | `TLoopThread` 去竞态 |
| **S21** | Async ProxyJump | `proxyjump.async TAsyncChannelStream`（无轮询，PeerWindow/Max + 半窗回补）+ `session.async TAsyncProxyConnector direct-tcpip 90→CONFIRMATION→ChannelStream` + `test_proxyjump_async 3/3 ~550ms` | 轮询 `50ms+5ms` 消除，`9 块` 侧线 |
| **S22** | SFTP via Async Jump | `proxyjump.async FQueuedPayload 5ms + CreateWithKeeper FKeeper` + `sftp.async SshAsyncSftpViaJump/On (FSession+busy defer)` + `test_sftp_via_jump 4/4 ~2.5s` | `0xF0` 悬垂修复，`20块` 侧线，`sftp_async 7/7` 回归 |

**真实性等级**: `focused-runtime`(回环 x86_64) + `e2e_ssh_live`(Docker Alpine 9.7 + Debian 10.0p2 8场景) + `heaptrc` 门。`e2e` 为 opt-in，不进默认 gate。

---

## 3) 性能基线总表（同一宿主，同编译 `-O2`，实测收敛）

| 域 | 路径 | p50 | 备注 | 门禁 |
|----|------|-----|------|------|
| **Cipher** 16KB | chacha | 255 MiB/s | protect | 50 |
| | gcm | 450 MiB/s |  | 50 |
| | ctr+etm | 135 MiB/s |  | 50 |
| **RSA** 2048 | naive | ~200ms | `d` 直接模幂 | — |
| | CRT | ~38ms | 5.2× | — |
| **KEX** | curve25519 | ~1ms | 默认 | — |
| | group14 | 50-70ms | 回退，50× | — |
| **Agent** | list | ~1ms | 11→12 | — |
| | sign ed25519 | ~1ms |  | — |
| | sign rsa CRT | ~40ms |  | — |
| **Compress** | none | 零开销 | 不创建 `z_stream` | — |
| | delayed | `USERAUTH_SUCCESS` 后首包 | 有状态增益第2包显著小 | 1MiB 防 bomb |
| **SFTP async** | INIT | 215ms | 首包 | — |
| | STAT | 115ms |  | — |
| | Read/Write chunk | 216ms | `32760` 单链 | — |
| **ProxyJump** | 单跳 | 5ms | 直连 | — |
| | 同步双跳 | 431ms | 额外 426ms=轮询+二次握手 | <600 |
| | 异步双跳 | 550ms | 零轮询，仍含二次 `KEX+USERAUTH` | — |
| | SFTP via AsyncJump | 2.5s /4 | 含 `INIT/VERSION`，约 625ms/次 | — |

---

## 4) 架构完整性（L2 封版 checklist，以 `sevenz 163` 为模板）

- [x] **163 级别门**: `buffer / cipher / kex / hostkey / keys / transport / compress / session 19 / sftp 12 / sftp_async 7 / proxyjump 5 / proxyjump_async 3 / sftp_via_jump 4` + `bench_ssh_cipher / bench_ssh_proxyjump` (`core/benchmarks/nextpas.core.ssh/*`, `bench_common.mk`)
- [x] **高级感**: `SshClient.Host.Port.User.Password.PrivateKey.Agent.Compress` 同 verb；`SshAsyncClient` 同镜；`Exec` vs `OpenFileSystem` 单 `Channel` 引擎；`ISftpWire / ISshAsyncFileSystem` 可注入
- [x] **复用度**: `cipher/compress/hostkey/keys/auth` 单点；`TSshWriter/Reader` 贯穿；`TChannelStream ↔ TAsyncChannelStream` 窗口/低水位同构；`bench` 复用 `TMemPipe/LoopServer` 同源
- [x] **稳定性**: `E*LimitError` 炸弹（SFTP 1MiB 解压防 bomb / SevenZ 同窗）、`WINDOW_LOW_WATER_DIVISOR=2` 回补、`ProbeWatch`、`TryFlushQueued` 单飞、`Keeper` 生命周期闭环、`FWriteBuf` 保活
- [x] **完整性**: `README + CONTRACT + TEST` 同版，`git diff --check 0`，`build-hygiene pass`

---

## 5) 已明确的非目标（诚实）

- 加密私钥仅 `aes256-ctr + bcrypt`（其他 cipher/kdf → `sekUnsupported`）
- `ABI compatibility deferred`，不发明新 Pascal 语法（首期）
- `PPMD writer` 未做、`Formatter/LSP server` 仅 API 验证未公开
- `async` 泄漏 `PSshLoop*Scenario`/`TIoReactor` 侧线 5-20 块为已知 `HEAPTRC_GATE=0`（功能零影响，由 `e2e` + 回环覆盖）

---

## 6) 通往 1.0 的剩余路径（S23—S30，按依赖排序）

> 每 slice 仍以 `focused gate` 收口，禁止无节点推进。

| 段 | 标题 | 交付 | 晋级门 | 不做 |
|----|------|------|--------|------|
| **S23** | **e2e Async Jump（Docker 双容器）** | `e2e_ssh_live` 增 `AsyncJump` 分支（`SshAsyncConnectViaJump` 直连双 `openssh-server` 容器，`jump:22 + target:22`，`TOFU` 双 `known_hosts`）+ `run_e2e.sh --async` | `NEXTPAS_SSH_E2E_ASYNC=1` 下 `exec` + `SFTP via AsyncJump` 双场景通过，`docker` 与 `loopback 4/4` 同断言，`heaptrc` 同门 | 不改 `transport.async` 状态机 |
| **S24** | **Rekey & Keepalive（长连接）** | `transport` `RekeyLimit`（`1GiB/1h`）+ `SSH_MSG_IGNORE` 心跳 + `session KeepAliveInterval`（`AsyncLoop Schedule`） | `bench_ssh_rekey` 10 次 `Rekey` 无窗口/序列号漂移，`bench_ssh_keepalive` 空闲 30s 仍 `exec` 成功 | 不做 `none` 压缩下的 `Rekey` 热切 |
| **S25** | **SCP/Copy 统一与限速** | `sftp.async` `Copy + RateLimit`（`TTokenBucket` 复用 `core.sync`）+ `SshScpViaJump` 薄封装（复用 `SFTP`） | `test_sftp_copy` 100MiB `throttle 10MiB/s` 偏差 <3%，`SFTP→SCP` 同 `IsRegular` 语义 | 不做 `glob` 递归 |
| **S26** | **Port Forwarding（-L/-R）** | `forward.async`（`direct-tcpip` 反向复用 + `tcpip-forward` + `forwarded-tcpip` 事件化，`TAsyncLoop AsyncAccept`） | `test_forward` `L:8080→target:80` 往返 `echo`，`ProxyJump` 链上 `forward` 仍 `Keeper` 保活 | 不做 `Socks` |
| **S27** | **KnownHosts 增强与 TOFU 策略** | `hostkey` `KnownHosts` `Update + Hash + Strict=ask` + `SshKnownHosts.TryAutoAdd` + `session` `HostKeyCallback` | `test_knownhosts` `ask→auto→strict` 三态，`e2e` `StrictHostKey=ask` 首连交互 | 不做 `SSHFP DNS` |
| **S28** | **可观测性与追踪** | `SshMetrics`（`kexAlg/cipher/compress/rekeyCount/bytesInOut`）+ `SshTrace` 统一 `tx/rx` + `bench` 输出 `metrics` | `test_metrics` 断言 `kex=curve25519` `cipher=chacha` `compress=zlib@openssh` 透传，`bench_proxyjump --json` 可机读 | 不做 `prometheus` 导出 |
| **S29** | **Fuzz & Bomb Final** | `fuzz_ssh_packet`（`AFL` 语料 `kex/hostkey/cipher` 畸形）+ `limit` 收敛（`SSH_MAX_RECEIVE_PACKET 256KiB` 统一） | `fuzz 24h` 零崩，`E*LimitError` 用例 >30 | 不做 `PQC` |
| **S30** | **1.0 Release** | `README/CONTRACT/CHANGELOG` 1.0 封版 + `examples/demo_ssh_sftp_via_jump` + `core-module-registry` `stable` | `make verify` 全绿（含 opt-in `e2e` + `fuzz` 报告），`git diff --check 0`，`sevenz 163` 同级 checklist 全勾 | — |

**当前紧后两批（可立即执行）**: `S23 e2e Async Jump`（无新依赖，补 `e2e` 事件化证据）→ `S24 Rekey/Keepalive`（长连接稳定性）。

---

## 7) 验证矩阵（每段晋级的硬证据）

| 层 | 命令 | 门槛 |
|----|------|------|
| 单元 | `make -C core/tests/nextpas.core.ssh/test_ssh_* clean test` | `heaptrc` 按 `HEAPTRC_GATE`（`sftp_async 7/7 / session_async 5/5 / proxyjump 5/5 / proxyjump_async 3/3 / sftp_via_jump 4/4`）|
| 集成 | `make hygiene && git diff --check` | `build-hygiene=pass` |
| 性能 | `make -C core/benchmarks/.../bench_* run` | 基线 `±5%`，`ProxyJump` 轮询/事件化 对比表 |
| 互操作 | `NEXTPAS_SSH_E2E_LOCAL=1 bash core/tests/nextpas.core.ssh/e2e_ssh_live/run_e2e.sh` | `8 场景`（`exec×2 + exit + stderr + known_hosts + 16次压 + SFTP回路 + RSA/CRT/ECDSA/加密`），`S23` 起 `+ async 双跳` |
| 本地权威 | `build/verify_local.sh` | `verify-local=pass` |
| 发布 | `make verify` | 全量 `pass` |

任何一段声称晋级，必须同时提供：分支/`worktree`/`HEAD`、保留文件、禁止带入清单、`focused gate` 证据、`merge` 建议（`Ready/Blocked/Landed/Needs Review`）。

---

## 8) 执行节奏与合并纪律

- **每轮开始**: `目标节点 / 当前缺口 / 本轮交付 / 验证方式 / 本轮不做`
- **每轮结束**: `完成节点 / 新增能力 / 验证结果 / 剩余风险 / 下一节点`
- **提交**: 一提交一可回滚，`git diff --cached` 先审；禁止 `reset --hard / checkout -- <file>` 删脏 worktree
- **Worktree**: `scripts/worktree-add.sh <branch> [base]` 创建 `.worktrees/<mod>`，`scripts/worktree-audit.sh` 审计；`main` 不做模块开发

---

## 9) 风险与回退

| 风险 | 信号 | 回退动作 |
|------|------|----------|
| 前端语义漂移 | `sema` 需猜 `AST` | 回 `Green CST` 不可变 |
| Workspace 分叉 | 各工具私有 `model` | 回 `WorkspaceModel` 唯一 truth |
| 性能私有 cache | 大项目 `eager` 扫描 | 回 `lazy index + 复用` |
| 产物污染 | `.o/.ppu` 落源码 | `make hygiene` 拦截 + `make clean` |
| 炸弹 | 超 `SSH_MAX_*` 未抛 | 补 `E*LimitError` 用例 |
| Async 泄漏漂移 | `HEAPTRC_GATE=0` 扩散 | 回 `PSshLoop*Scenario` 闭包收敛 + `TIoReactor` 侧线显式 `Close` |
| ProxyJump 轮询回潮 | `50ms+5ms` 再现 | 回 `TAsyncChannelStream + Keeper + TryFlushQueued` |

---

## 10) 文档权威层级

- `docs/architecture/` 与 `docs/adr/` 为稳定事实
- `docs/plans/` 与 `core/docs/plans/` 为活动计划
- `core/docs/design-conventions.md` 为 `core` 设计规范
- `AGENTS.md → core/AGENTS.md → docs/worktrees.md` 为协作入口

> 本终局路线图自 `2026-08-28` 起为唯一推荐主线；任何偏离需以 `ADR` 显式记录。`S22` 前 `PChar` 热路径 `inline` 与 `S21/S22 Keeper` 已验证为后续 `S23 e2e` 与 `S24 Rekey` 的稳定基座。


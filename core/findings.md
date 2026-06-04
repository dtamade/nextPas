# Findings: platform.io kqueue wake seam

## Scope

- 本轮继续留在 `nextpas.core.net.server` foundation 线路。
- 目标不是扩 HTTP public behavior，而是把 BSD/macOS `kqueue` host wake seam
  从 stub 补成可复用实现。

## Confirmed truths

### 1. readiness owner 已抽出后，剩余最高价值缺口就是 `kqueue` wake seam

- `nextpas.core.net.server.readiness` 已经拥有 listener/poll/completion/deadline
  主循环骨架。
- 如果 `platform_poller_enable_wake / wake / drain_wake` 在 BSD/macOS 仍是 stub，
  那 `net.server.kqueue` 仍然无法安全复用这条 owner。

### 2. 当前宿主是 Linux，不能伪造 BSD/macOS live proof

- 这轮最诚实的 RED/GREEN 形状不是“宣称 kqueue 已实机跑通”，而是：
  - source-contract focused test 锁定源码不再是 stub
  - Linux 侧跑 `test_net_server`，确认 foundation 基线不回退

### 3. 这轮最稳妥的实现是 self-pipe，而不是额外扩 `EVFILT_USER`

- 现有 POSIX seam 已经有 `pipe`、`fcntl`、`read`、`write`、`close`。
- 直接落 nonblocking + close-on-exec 的 self-pipe，风险最低，也最符合当前
  “先把基础契约做实”的节奏。

### 4. `kqueue` wake seam 现在已落地

- `TPlatformPoller` 现在有 `WakeReadFd` / `WakeWriteFd`
- `platform_poller_close` 现在会关闭 wake pipe
- `platform_poller_enable_wake` 现在会创建 self-pipe、设置 nonblocking /
  close-on-exec，并把 read end 注册进 poller
- `platform_poller_wake` 现在会向 write end 写入 wake byte，并把 full-pipe
  `EAGAIN` 视作“已经唤醒”
- `platform_poller_drain_wake` 现在会循环读取直到 `EAGAIN`

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.platform.io/test_platform_io clean test`
  - 初次失败点：
    - `FAIL: kqueue wake source contract - bsd/macOS poller should track wake read fd`
- GREEN:
  - `make -C tests/nextpas.core.platform.io/test_platform_io clean test`
  - `9/9 passed`
  - heaptrc: `0 unfreed memory blocks`
- module gate:
  - `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `23/23 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- `net.server.kqueue` backend 还没真正注册/落地；这现在是 readiness-family
  下一刀的主目标。
- 还没有 BSD/macOS 实机 compile/runtime proof；后续需要在真实宿主上补充。
- Windows `IOCP` completion-family driver 仍是后续 phase，不在本轮范围。

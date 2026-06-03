# Findings: nextpas.core.net.server backend provider seam

## Scope

- 这轮把 `nextpas.core.net.server` 的 backend 解析从 facade 内硬编码 `case`
  提升成 registry/provider seam。
- 目标是给 future backend 与 phase-2 driver 打开稳定入口，同时保持当前 HTTP contract 不变。

## Confirmed truths

### 1. provider seam 现在已经落地

- `src/nextpas.core.net.server.pas` 现在公开：
  - `TTcpServerFactory`
  - `RegisterTcpServerFactory`
  - `UnregisterTcpServerFactory`
  - `HasTcpServerFactory`
  - `TryGetTcpServerFactory`
  - `ResolveTcpServer`
- `NewTcpServer(...)` 现在只做 facade forward，backend 解析改由 registry 完成。

### 2. built-in backend 已改成“初始化注册”，不是写死在 facade

- builtin `threaded` 始终注册。
- Linux 下 builtin `epoll` 也在 initialization 里注册。
- `kqueue` / `IOCP` 仍然没有 concrete backend，但现在已经有统一注册入口，不必再回到大 `case` 扩散。

### 3. HTTP public contract 没有被重开

- `THttpServer` 仍然只是把 `THttpServerOptions.Backend` 下沉到 `TTcpServerOptions`。
- `NewHttpServer` / `NewHttpClient` 相关 registry 回归仍通过。
- 这轮没有改 H1 parser / writer / server session 逻辑。

### 4. 当前真正剩下的技术主线更清晰了

- shared phase-2 per-connection evented driver
- `kqueue` concrete backend
- `IOCP` concrete backend

provider seam 落地后，剩余问题已经从“怎么接 future backend”收窄成
“怎么驱动 session”。

## Verification evidence

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `18/18 passed`
  - 新增 proof：
    - built-in threaded backend factory exists
    - custom backend factory overrides selection
    - missing backend factory raises `ENotSupportedError`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_registry clean test`
  - `4/4 passed`
  - 证明 HTTP constructor / registry 路径未被 net.server seam 变更误伤
  - heaptrc：`0 unfreed memory blocks`
- `git diff --check -- src/nextpas.core.net.server.pas tests/nextpas.core.net.server/test_net_server/test_net_server.lpr`
  - clean

## Remaining gaps / risks

- 目前 provider seam 仍是 facade-level registry，不等于 phase-2 runtime driver 已存在。
- `kqueue` / `IOCP` 仍无 concrete backend；当前只是“可接入”，不是“已交付”。
- HTTP 侧目前还没有直接消费 provider capability 的更细抽象；这件事只有在多 backend/多 strategy 真正出现时才值得扩 public seam。

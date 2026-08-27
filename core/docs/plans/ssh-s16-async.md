# S16 async reactor 适配 — 设计计划

状态: `in_progress` | 目标: 2026-08-28 完成 MVP 并通过 focused gates

## 背景

- S0-S15 已完成: `none` 零开销压缩 (`zlib@openssh.com` 延迟 / `zlib` 即时), `curve25519` 优先 + `group14` 回退, `ed25519/ecdsa-p256/rsa-sha2`, `agent`, 加密私钥, 10门回环 19/19 全绿.
- 当前 `nextpas.core.ssh` 全部阻塞式: `TcpConnect` + `IReadWriteCloser.Read/Write` 直到 `HEAPTRC 0`. 在 `TAsyncLoop` 中调用会阻塞事件循环线程, 无法与 `http`/`net.async` 共存.
- `nextpas.core.net.async` 已提供 `AsyncTcpDial` (RFC8305 HE, CAD, 多A 裂速), `IAsyncTcpStream.AsyncRead/AsyncWrite`, `TAsyncLoop.Post/Schedule`. 需将 SSH 多阶段握手事件化.

## 目标

1. **非阻塞拨号**: `AsyncTcpDial` 取代 `TcpConnect`, 支持 `TAsyncTcpDialOptions` (超时、token、本地绑定) 透传.
2. **事件化传输**: `TSshClientTransport` 的 `ReadPacket/SendPacket/ExchangeVersions` 拆为 `Async*` 回调链, 序列号与加解密逻辑复用, 压缩 (`ISshCompressor`) 状态与 sync 完全一致.
3. **状态机编排**: `DoHandshake -> DeriveAndApplyNewKeys -> DoServiceRequest -> Authenticate* -> Exec` 改为阶梯回调, 单线程事件循环保证, 无跨线程竞态.
4. **保持阻塞 API**: 既有 `SshConnect/SshConnectOn/ISshSession.Exec` 不变, 新增 `nextpas.core.ssh.async` 门面, 零开销不影响 `none` 路径.
5. **真实性**: 回环测试复用内存管道的 async 适配 (`TAsyncMemPipe` 或 `AsyncTcpStreamAdopt`), heaptrc 0, 与 sync 19/19 同等覆盖.

## 非目标

- 重写 `cipher`/`kex`/`hostkey` 密码学; 仅 I/O 事件化.
- SFTP async (后续 S17), 代理 `ProxyJump` (后续).
- 兼容 Windows IOCP 的特殊分支 (复用 `net.async` 已验证路径).

## 设计

### 依赖方向

```
base ← errors/buffer ← cipher/kex/hostkey/keys/auth/compress ← transport
                                                          ↑ async
                                    async.transport ──────┘
                                    async.session → 门面 async
```

`async.transport` 依赖 `net.async.tcp/dial`, `async.session` 依赖 `async.transport`. 不拉高 `L1`.

### 关键类型

```pascal
// nextpas.core.ssh.transport.async
TAsyncSshTransport = class
  constructor Create(const ALoop: TAsyncLoop; const AStream: IAsyncTcpStream);
  function AsyncExchangeVersions(ACb: TSshAsyncCb): Boolean;
  function AsyncSendPacket(const APkt: TBytes; ACb: TSshAsyncCb): Boolean;
  function AsyncReadPacket(ACb: TSshAsyncPacketCb): Boolean; // 回调带 TBytes
  procedure SetNegotiatedCompression(const ANeg: TSshNegotiated);
  procedure EnableCompression; // 同 sync, 懒创建 z_stream
  procedure ApplyNewKeys(...);
end

// nextpas.core.ssh.session.async
ISshAsyncSession = interface
  function ExecAsync(const ACommand: string; ACallback: TSshExecAsyncCb): Boolean;
  procedure Close;
end
ISshAsyncClientBuilder = interface
  function Host(...): ISshAsyncClientBuilder; // 同 sync builder 但 Host/Port/User 必填
  function DialOptions(const A: TAsyncTcpDialOptions): ISshAsyncClientBuilder;
  function AsyncConnect(ACb: TSshAsyncConnectCb): Boolean;
end
function SshAsyncConnect(const ALoop: TAsyncLoop; const AOptions: TSshConnectOptions;
  ACallback: TSshAsyncConnectCb): Boolean;
```

- 回调签名: `TSshAsyncCb = procedure(AErr: ESSHError; AContext: Pointer)` 或 `AErrorCode:Int32`. 选用 `ESSHError` 携带 `Kind`, 与 sync 异常语义对齐, 但 callback 链不抛异常.
- `TAsyncSshConnector` 内部状态机: `stInit → stDialing → stVersion → stKexInit → stEcdh → stNewKeys → stService → stAuth → stReady`. 每步存 `FNextStep: procedure`, 完成回调 `StepDone` 触发下一步, 失败则 `Fail(E)` 调用户回调并释放.
- `DialOptions`: 默认 `DefaultAsyncTcpDialOptions` + `OverallDeadline` 映射 `ConnectTimeoutMs`. 允许调用方覆写 `ConnectionAttemptDelayMs/MaxInFlight` 以复用 HE 调优.
- `IAsyncTcpStream` 来自 `AsyncTcpDial` 成功回调, 亦支持 `AsyncTcpStreamAdopt(IReadWriteCloser)` 供测试注入.

### I/O 细节

- `AsyncReadExact(ABuf, ACount)` — 循环 `AsyncRead` 直到凑满, 短读继续, `ECONNRESET` 转 `sekIO`. 供 `ReadPacket` 的 4B 头 + `BodyLength` + `Trailer`.
- `AsyncReadLine` — 逐字节 `AsyncRead` 累到 LF, 超 `SSH_IDENT_MAX_LINE*8` 报 `sekProtocol`, 容忍前置文本行.
- `AsyncSendPacket` — `Protect` 后 `AsyncWrite` 整帧, `Write` 缓冲须在回调前保持有效 (拷贝到 `FOutBuf: TBytes` 成员, 回调后释放).
- 序列号 `FSendSeq/FRecvSeq` 跨 `NEWKEYS` 连续, 与 sync 同值, 压缩 `FCompressEnabled` 时先 `Compress` 再 `Protect`.
- 定时: `OverallDeadline` 在 dial 期生效; 握手后可用 `AsyncReadTimeout/AsyncWriteTimeout` 按 `ExecTimeoutMs` 设限 (可选 S16 MVP 不做, 保留参数).

### 复用策略

- `cipher` 的 `CreateSshPacketSender/Receiver`, `KDF`, `SshBuild*` 全部复用, 不拷贝.
- `hostkey` 验证 `SshVerifyHostSignature`, `known_hosts` 加载同步执行 (文件 I/O 小, 仍在事件循环线程, 可后续改 `AsyncFileRead`).
- 压缩 `CreateSshZlibCompressor` 同 `transport` 懒创建, 双 `z_stream` 共享, `Z_SYNC_FLUSH` 语义与 sync 一致.
- 测试 `TMemPipeEnd` 扩展 `IAsyncTcpStream` 适配或用 `AsyncTcpStreamAdopt` 包 `IReadWriteCloser`, 回环 19 用例平移为 async 19.

### 测试矩阵

| 门 | 覆盖 |
|---|---|
| `test_ssh_transport_async` | `AsyncExchangeVersions` 越界/前置行容忍, `AsyncSendPacket/AsyncReadPacket` 加解密往返, 压缩延迟/即时, 短读重组 |
| `test_ssh_session_async` | `SshAsyncConnect` 密码/publickey/加密/rsa-crt/ecdsa + dh 回退 + agent(需 loop) + compress 4 组合, 回环 19 平移, `DialOptions` 覆写, 超时/关闭競态 |
| `test_ssh_kex` 等既有 9 门 | 回归, 保证 sync 零回归 |
| `e2e_ssh_live` async 分支 | `NEXTPAS_SSH_E2E_ASYNC=1` 时走 `SshAsyncConnect` 复跑 8 场景 + SFTP 回路 |

### 性能

- `none` 时 `Async*` 仅增加一次 `Post` 调度, 零额外拷贝.
- `zlib` 复用同一 `z_stream`, `AsyncSend` 批量写整帧, 不做 Nagle 拆包.
- 基准 `bench_ssh_cipher` 不受 async 影响; 新增 `bench_ssh_async` 测 `Dial+Handshake` 均值 (目标 < sync + 10%).

## 实施步骤 (3-commit)

1. **feat(ssh): async transport** — `nextpas.core.ssh.transport.async` + `nextpas.core.ssh.async` 基础门面, `DefaultAsyncSshOptions`, `AsyncTcpDial` 接入, `AsyncExchangeVersions/ReadPacket/SendPacket`.
2. **feat(ssh): async session** — `TAsyncSshConnector` 状态机, `SshAsyncConnect/On/Create`, `ISshAsyncSession.ExecAsync`, `agent/compress` async 分支, `AsyncClientBuilder`.
3. **test/docs** — `test_ssh_session_async` 19 + `test_ssh_transport_async`, README 算法表增 async 行, goal-tree S16, 3-commit landing.

## 风险与缓解

- **回调地狱**: 抽 `StepProc` + `FState` 枚举, 每步单函数, 错误集中 `Fail`.
- **缓冲生命周期**: `FOutBuf` 成员持有至 `AsyncWrite` 回调, 避免栈悬垂.
- **取消**: `IAsyncCancellationToken` 透传 `DialOptions.Token`, 握手期 `Close` 取消 in-flight `AsyncRead/Write` (poller `TryCancelByContext`).
- **兼容**: sync 路径不动, async 仅在 `Compress=False` 时也保持 `none` 零开销; `SshClient.Connect` 仍走阻塞.

## 验收标准

- `make -C core/tests/nextpas.core.ssh/test_ssh_session_async clean test` 19/19, `heaptrc 0`.
- `make hygiene`, `git diff --check` clean.
- `AsyncTcpDial` 真实开销与 sync 偏差 < 15% (本地回环).
- 文档 READY, 3-commit 可 cherry-pick replay 到 `main`.

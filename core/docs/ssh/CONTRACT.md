# nextpas.core.ssh 代码契约

**模块路径**: `core/src/nextpas.core.ssh*.pas`（31 个生产源文件；见 §1.1）
**层级**: L2（与 `tls` 同层：面向字节流的协议实现；仅依赖 L0–L1 及 `crypto`/`hash`/`net` 已文档化 owner）
**Owner**: `codex/core-ssh` / ssh lane（`.worktrees/ssh`）
**最后更新**: 2026-09-02
**版本**: 1.1
**权威性**: 本文件为 ssh 模块 SSOT。以本 CONTRACT 为准；`README.md` 为入口概览，`goal-tree.md` 与 `ROADMAP_FINAL.md` 为阶段证据。业务以 CONTRACT 为准，缺能力先反哺 owner。

---

## 1. 接口契约

### 1.1 子模块（四件套 `base←intf/ffi←impl←门面`）

| 文件 | 职责 | 四件套 |
|------|------|--------|
| `nextpas.core.ssh.pas` | 门面：纯 re-export + 便捷函数 `SshClient/SshExec/SshConnect*`（已校验无 `duplicate identifier`） | 门面 |
| `nextpas.core.ssh.base.pas` | 协议常量、消息号、选项记录 `TSshConnectOptions` | base |
| `nextpas.core.ssh.errors.pas` | `ESSHError` + `TSshErrorKind`（9 类） | base 侧 |
| `nextpas.core.ssh.intf.pas` | 缝隙接口 `IDialer/ISshAgentDialer`（隔离 `net` 直连，仅 `io.intf+net.intf`） | intf |
| `nextpas.core.ssh.net.ffi.pas` + `ssh.ffi.pas` | 网络 FFI 外壳（唯一拉取 `nextpas.core.net` 的单元，`TcpConnect/UnixConnect` 注入） | ffi |
| `nextpas.core.ssh.buffer.pas` | RFC 4251 wire 类型读写器 `TSshWriter/TSshReader`（`Ensure/Need` 边界） | impl |
| `nextpas.core.ssh.cipher.pas` | 包加密编解码器 `ISshPacketSender/Receiver`（AEAD / CTR+ETM，`TAesCtrStream` record值语义跨包 `keystream` 持久，`bytes.ops.MemXor` 批量） | impl |
| `nextpas.core.ssh.transport.core.pas` | 传输核单源（`padding+Protect+Compress+Seq+Rekey` 纯内存，`transport(+.async)` 薄包装复用） | impl 核 |
| `nextpas.core.ssh.transport.pas` | 版本交换 + 二进制包协议状态机（阻塞，薄包装 `transport.core`） | impl |
| `nextpas.core.ssh.transport.async.pas` | 异步传输层（`TAsyncLoop+IAsyncTcpStream`，复用 `transport.core`） | impl |
| `nextpas.core.ssh.kex.pas` | KEXINIT 协商 + 密钥推导（`SHA256 KDF A-F`） | impl |
| `nextpas.core.ssh.kex.curve25519.pas` | `curve25519-sha256` 客户端交换（X25519） | impl |
| `nextpas.core.ssh.kex.dhgroup14.pas` | `diffie-hellman-group14-sha256` 回退（2048-bit MODP） | impl |
| `nextpas.core.ssh.hostkey.pas` | 主机密钥解析/验签/指纹/known_hosts（ed25519/rsa/ecdsa-p256） | impl |
| `nextpas.core.ssh.rsa.pas` | RSA PKCS#1 v1.5 签名/验签核（DigestInfo 单一来源） | impl |
| `nextpas.core.ssh.keys.pas` | OpenSSH 私钥容器解析（ed25519/rsa，未加密与 `aes256-ctr+bcrypt` 加密） | impl |
| `nextpas.core.ssh.auth.pas` | userauth 载荷构造/解析（probe `hasSig=false` + `PK_OK` / signed） | impl |
| `nextpas.core.ssh.compress.pas` | 压缩：有状态 `zlib`/`zlib@openssh.com`（经 `compress.zlib.ffi` 唯一入口） | impl |
| `nextpas.core.ssh.agent.pas` | ssh-agent 协议客户端（Unix socket 长度前缀帧，经 `intf+net.ffi` 注入） | impl |
| `nextpas.core.ssh.channel.pas` | 连接协议：单通道引擎 `TSshChannel` + `TChannelStream` | impl |
| `nextpas.core.ssh.channel.async.pas` | 异步通道 `TAsyncExecRunner` + `TAsyncSftpChannel` 复用窗口 | impl |
| `nextpas.core.ssh.window.pas` | 通道窗口策略 `TChannelWindow`（可复用 record，见 §8；通用流控别名晋升已回退，见 §8.2） | impl |
| `nextpas.core.ssh.rekey.pas` | Rekey 策略 `TSshRekeyPolicy`（`TInstant` 单调时钟） | impl |
| `nextpas.core.ssh.keepalive.pas` | KeepAlive 策略 `TKeepAlivePolicy`（`TInstant` 单调时钟） | impl |
| `nextpas.core.ssh.keepalive.scheduler.pas` | KeepAlive 调度器 `TKeepAliveScheduler`（`TAsyncLoop` 周期，见 §8） | impl（已抽取） |
| `nextpas.core.ssh.knownhosts.pas` | KnownHosts 独立帧 `TSshKnownHosts`（`hostkey` 单源纯 re-export，零额外堆分配，`bytes.ops/TConstantTime` 单源） | impl（已抽取·薄别名） |
| `nextpas.core.ssh.session.pas` | 会话薄编排（状态与生命周期、Exec/SFTP 转发、拨号入口；<450 行，委托 handshake/auth 单源，`inline`/`zero-copy`） | impl |
| `nextpas.core.ssh.session.handshake.pas` | 会话握手与重协商单源（KEX/kdf/主机密钥/NEWKEYS/延迟压缩，`transport` 单源，`SecureZero`） | impl |
| `nextpas.core.ssh.session.auth.pas` | 会话认证单源（`password/privatekey/agent` 回退，`probe→sign` 时序，`Ed25519/RSA-CRT`） | impl |
| `nextpas.core.ssh.session.builder.pas` | Fluent Builder（`ISshClientBuilder` + `SshClient`，`inline` 薄转发，复用 `session.SshConnect`） | impl |
| `nextpas.core.ssh.proxyjump.pas` | 同步 ProxyJump（`TProxyJumpSession` 委托 + `SshSessionOpenDirectTcpip` 单源，`inline` 零拷贝） | impl |
| `nextpas.core.ssh.session.async.pas` | 异步会话（`AsyncTcpDial(RFC8305)` + 状态机，复用 cipher/kex/hostkey/compress） | impl |
| `nextpas.core.ssh.proxyjump.async.pas` | 异步 ProxyJump（`TAsyncChannelStream` 无轮询 + `Keeper` 保活） | impl |
| `nextpas.core.ssh.sftp.base.pas` | SFTP 共享基座（协议常量/属性载体/ `SftpStatusName` 单源，`text.conv` 单源） | base |
| `nextpas.core.ssh.sftp.intf.pas` | SFTP 缝隙接口（`ISftpWire/ISshFileSystem`，隔离通道与文件语义） | intf |
| `nextpas.core.ssh.sftp.wire.pas` | SFTP 通道线材（`TSshChannelWire` 4B 重组，容量倍增+偏移零拷贝，`inline/bytes.ops` 单源） | impl |
| `nextpas.core.ssh.sftp.conn.pas` | SFTP 连接状态机（`TSftpConnection` INIT/VERSION+RoundTrip/流水线 `SendRequest/RecvForId` 乱序缓冲 `SFTP_PIPELINE_WINDOW`，`PutAttrs/ReadAttrs` 单源） | impl |
| `nextpas.core.ssh.sftp.fs.pas` | SFTP 文件系统实现（`TSshFileSystem` RealPath/Stat/ListDir/ReadFile/WriteFile 等；ReadFile/WriteFile `SFTP_PIPELINE_WINDOW=16` 流水线窗口+ `IBytesBuilder` 倍增、ListDir 容量倍增） | impl |
| `nextpas.core.ssh.sftp.pas` | SFTP v3 门面（纯 re-export，常量/类型/接口与 `SftpOpen*` 便捷入口，`inline` 转发，无逻辑） | 门面 |
| `nextpas.core.ssh.sftp.async.pas` | SFTP v3 异步（`ISshAsyncFileSystem`，`SftpRoundTripAsync` + 窗口，复用 `sftp.base` 单源） | impl |

依赖方向：`base ← errors/buffer ← cipher/kex/hostkey/keys/auth ← transport.core ← transport(+.async) ← channel/window/rekey/keepalive ← session.handshake/auth ← session/sftp/proxyjump ← 门面`；`base ← rekey/keepalive/window` 单向。

对外依赖（L2 允许）：`io.intf`（`IReadWriteCloser` 缝隙）、`crypto.*`（x25519/ed25519/rsa/aes-gcm/chacha/hmac/sha256/ecdsa/bcrypt_pbkdf）、`hash`、`encoding.base64`、`time`/`text.conv`/`text.strings`/`text.utf8`（替代 `SysUtils`）、`bytes.ops`（见 §7）、`compress.zlib.ffi`（唯一 zlib 入口）、`net`/`net.async.tcp`（经 `net.ffi`/`intf` 注入，async peer 见 §7）。

### 1.2 门面 re-export（稳定词表）

`nextpas.core.ssh` 门面 re-export 类型与便捷入口（与源码 `ssh.pas` 一致，已校验无 `duplicate identifier`）：

```pascal
TSshAuthMethod       = nextpas.core.ssh.base.TSshAuthMethod;
TSshHostKeyAlg       = nextpas.core.ssh.base.TSshHostKeyAlg;
TSshConnectOptions   = nextpas.core.ssh.base.TSshConnectOptions;
TSshErrorKind        = nextpas.core.ssh.errors.TSshErrorKind;
ESSHError            = nextpas.core.ssh.errors.ESSHError;
ISshSession          = nextpas.core.ssh.session.ISshSession;
ISshClientBuilder    = nextpas.core.ssh.session.builder.ISshClientBuilder;
TSshExecResult       = nextpas.core.ssh.channel.TSshExecResult;
ISshFileSystem       = nextpas.core.ssh.sftp.ISshFileSystem;
TSftpAttrs           = nextpas.core.ssh.sftp.TSftpAttrs;
ISshPacketSender     = nextpas.core.ssh.cipher.ISshPacketSender;
ISshPacketReceiver   = nextpas.core.ssh.cipher.ISshPacketReceiver;
TSshClientTransport  = nextpas.core.ssh.transport.TSshClientTransport;
TSshKnownHosts       = nextpas.core.ssh.hostkey.TSshKnownHosts;
TSshAgentClient      = nextpas.core.ssh.agent.TSshAgentClient;
ISshCompressor       = nextpas.core.ssh.compress.ISshCompressor;
TSshWriter           = nextpas.core.ssh.buffer.TSshWriter;
TSshReader           = nextpas.core.ssh.buffer.TSshReader;
TChannelWindow       = nextpas.core.ssh.window.TChannelWindow;
TSshPrivateKey       = nextpas.core.ssh.keys.TSshPrivateKey;
TAsyncSshTransport   = nextpas.core.ssh.transport.async.TAsyncSshTransport;
ISshAsyncSession     = nextpas.core.ssh.session.async.ISshAsyncSession;
ISshAsyncFileSystem  = nextpas.core.ssh.sftp.async.ISshAsyncFileSystem;

function SshClient: ISshClientBuilder; inline;
function SshConnect(const AOptions: TSshConnectOptions): ISshSession;
function SshExec(const AHost: string; APort: Word; const AUser, APass, ACmd: string): TSshExecResult;
```

消费方 `uses nextpas.core.ssh` 即可；按需 `uses nextpas.core.ssh.base/intf` 取类型/缝隙。

### 1.3 选项与常量（`base` truth）

`DefaultSshConnectOptions(AHost)`：`Port=22 / StrictHostKeyChecking=False / ConnectTimeoutMs=10000 / ExecTimeoutMs=120000 / RekeyBytes=1GiB / RekeyIntervalMs=1h / KeepAliveIntervalMs=0 / InitialWindowSize=$200000 / MaxPacket=32768`。`0` 表示禁用（Rekey/KeepAlive）。

协议常量：`SSH_PROTOCOL_VERSION='SSH-2.0-nextpas.core.ssh_0.1'`、`SSH_MAX_RECEIVE_PACKET=$40000 (256 KiB)`、`SSH_MIN_PADDING=4 / SSH_MIN_PAD_BLOCK=8`、`SSH_REKEY_BYTES/INTERVAL`（见 §2）。

---

## 2. 不变量（冻结）

### 2.1 KEX 协商

- **[INV-KEX-1] first-match**：`SshNegotiateEx` 对 `KexAlgs/HostKeyAlgs/EncCs/EncSc/MacCs/MacSc/CompCs/CompSc` 各字段取客户端列表中第一个也出现在服务端 `TSshPeerKexInit` 的算法；任一关键字段无交集抛 `sekNegotiation`。AEAD cipher（`chacha20-poly1305@openssh.com` / `aes*-gcm@openssh.com`）下 MAC 字段允许空串（与 OpenSSH 一致）。
- **[INV-KEX-2] 优先级冻结**：
  ```
  KEX:      curve25519-sha256 > curve25519-sha256@libssh.org > diffie-hellman-group14-sha256
  HostKey:  ssh-ed25519 > ecdsa-sha2-nistp256 > rsa-sha2-512 > rsa-sha2-256
  Cipher:   chacha20-poly1305@openssh.com > aes256-gcm@openssh.com > aes128-gcm@openssh.com > aes256-ctr > aes192-ctr > aes128-ctr
  MAC:      hmac-sha2-512-etm@openssh.com > hmac-sha2-256-etm@openssh.com（仅 ETM；CTR 必需）
  Compress: Compress=False → ('none'); Compress=True → ('zlib@openssh.com','zlib','none')
  ```
  新增算法必须追加到末位，不得重排现有优先级。
- **[INV-KEX-3] KDF A-F 扩展链**：`SshKdfSha256(AKMpint,AH,AX,ASessionId,ALen)` 按 RFC 4253 §7.2：首块 `SHA256(K||H||X||session_id)`，后续 `SHA256(K||H||prev)` 串接截断；`K` 为 RFC 4251 `mpint(K)`（含长度前缀，`PutMPInt` 前导零规则），`H` 为交换散列，`X` 为单字节标签（A-F）。`session_id` 为首轮 `H` 且终身不变（重协商不更新）。
- **[INV-KEX-4] 交换散列输入序**：curve25519 路径 `SshBuildCurve25519HashInput(Vc,Vs,Ic,Is,Ks,e,f,K)` 与 dh-group14 路径 `SshBuildDHGroup14HashInput(...)` 均为 `string(Vc) || string(Vs) || string(Ic) || string(Is) || string(Ks) || string(e) || string(f) || mpint(K)`，`e/f/K` 均为 `mpint`（前导零/符号位规则同 `TSshWriter.PutMPInt`），`Ks` 为主机密钥 `string(blob)`。顺序与类型错位即验签失败。
- **[INV-KEX-5] 随机与拒绝**：`SshBuildKexInitPayloadEx` 要求 16 字节 `cookie`（非 16 即 `sekProtocol`）；`TSshKexCurve25519/DHGroup14` 私钥 32 字节 `SecureRandom`，共享 `K` 全零拒绝（`IsZeroBytes` 单源），DH 侧 `1 < f < p`（RFC 3526 2048-bit 素数 + `g=2`）否则 `sekKeyFormat`。

### 2.2 主机密钥

- **[INV-HK-1] 解析与验签**：`SshParseHostKey(blob)` 按 `TSshHostKeyAlg` 分发：`ssh-ed25519` (32B)、`ecdsa-sha2-nistp256` (`string("nistp256")+string(04||X||Y)` 65B，未压缩点，`TryValidateP256Point` 否则 `sekKeyFormat`)、`rsa-sha2-512/256` (DER)。`SshVerifyHostSignature` 分发 `Ed25519Verify / TryECDSAVerifyP256SHA256(SHA256(H), DER(r,s)) / RsaVerifyPkcs1v15`，失败抛 `sekHostKey`。
- **[INV-HK-2] known_hosts**：`TSshKnownHosts` 支持明文通配与 `|1|salt|hash` 散列（HMAC-SHA1），`StrictHostKeyChecking=True` 时未知密钥直接 `sekHostKey`；`False` 时允许 TOFU（`TryAutoAdd`）。指纹 `SHA256(blob)`。
- **[INV-HK-3] 优先级与协商一致**：协商选定的 `HostKeyAlg` 必须与对端 `Ks` 实际类型一致，否则验签路径 `sekHostKey`；优先级同 INV-KEX-2。

### 2.3 认证回退

- **[INV-AUTH-1] 回退序冻结**：`RunAuthentication` 固定 `agent → privatekey → password`。前一方式以 `sekAuth/sekIO` 失败不阻断下一方式；`sekHostKey/sekProtocol` 等协议级错误直接上抛，不回退。
- **[INV-AUTH-2] probe 语义**：`publickey` 先发 `hasSig=false` probe（`SshBuildAuthPublicKeyProbe`），对端 `SSH_MSG_USERAUTH_PK_OK(60)` 才发带签 `SshBuildAuthPublicKeySigned`（含 `string(session_id)` 带长度前缀的 signed-data，RFC 4252 §7）；`AuthFailure` 未含 `partial_success` 即终局失败。
- **[INV-AUTH-3] agent 路径**：`TSshAgentClient` 帧为 4B BE 长度前缀 + 循环 `ReadExact/WriteExact`；`ListIdentities` 11→12、`Sign` 13→14；`SshAgentKeyBlobToAlgName/Flags` 映射 `ssh-rsa→rsa-sha2-512`、`ssh-ed25519→ed25519`，`rsa-sha2-512` 标志优先；逐身份 `probe→Sign(flags)` 循环，单身份失败继续下一身份。
- **[INV-AUTH-4] 私钥路径**：`AuthenticateWithPrivateKeyData` 按 `TSshPrivateKey.Kind` 分发，RSA 仅 `rsa-sha2-512` 单次尝试（无 `rsa-sha2-256` 降级），`RsaSignPkcs1v15Crt` 优先（`p*q==n` 且 `q*iqmp mod p==1` 时 Garner 合并，否则 naive 回退），ed25519 走 `Ed25519Sign`。加密容器仅 `aes256-ctr+bcrypt`（`salt≠""` 且 `rounds≥1`），否则 `sekUnsupported`。

### 2.4 窗口/流控

- **[INV-WIN-1] 窗口策略单源**：`TChannelWindow` 为唯一实现（`window.pas` record，零堆分配，`inline` 热路径）；`sync` 与 `async` 通道均复用，不复制逻辑。`SSH_WINDOW_LOW_WATER_DIVISOR=2` 冻结。
- **[INV-WIN-2] OurWindow 回补**：`OurWindow` 初值 `SSH_DEFAULT_WINDOW_SIZE ($200000)`，由我方 `CHANNEL_OPEN` 声明；`Consume(ACount)` 递减 `FOurWindow`，当 `FOurWindow ≤ FInitWindow div 2` 时回补至 `FInitWindow` 并返回 `ANeedAdjust = FInitWindow - FOurWindow` 用于 `WINDOW_ADJUST`；`Grant(ACount)` 入账 `FPeerWindow`。
- **[INV-WIN-3] PeerWindow 限流**：发送侧受 `FPeerWindow` 与 `PeerMaxPacket` 双重上限：`SliceSize(AWant) = min(AWant, FPeerMaxPacket, FPeerWindow)`；`CanSend` 要求 `FPeerWindow>0`；`DidSend` 递减。`WINDOW_ADJUST` 到账即 `Grant`，`CHANNEL_DATA` 发送即 `DidSend`。
- **[INV-WIN-4] 通道号与迟滞过滤**：本地通道号进程级单调递增（`GNextLocalChannelId / GNextAsyncChannelId / GNextSftpChannelId` atomic），`PumpFiltered`/`TAsyncExecRunner.Pump` 对 `recipient-first` 族（92–100）按 `LOCAL_CHANNEL_ID` 校验，迟滞 `CLOSE/DATA` 不误触发状态机；`HandleData` 按 `LOCAL_CHANNEL_ID` 校验（非 `FRemoteId`）。

### 2.5 压缩激活时机

- **[INV-COMP-1] 零开销默认**：`Compress=False` 时 `KEXINIT` 仅提案 `('none')`，`transport` 不创建 `z_stream`，直通；`Compress=True` 时提案 `('zlib@openssh.com','zlib','none')`。
- **[INV-COMP-2] 激活时机冻结**：
  | 协商结果 | 激活点 | 说明 |
  |----------|--------|------|
  | `none` | 永不 | 无操作 |
  | `zlib` | `NEWKEYS` 后立即 `EnableCompression` | 即时（兼容） |
  | `zlib@openssh.com` | `USERAUTH_SUCCESS` 后首包起 `EnableCompression` | 延迟（OpenSSH 默认，推荐） |
  误时激活即对端解压失败（`sekProtocol`）。
- **[INV-COMP-3] 包处理序**：发送 `Compress → padding → Protect`；接收 `Unprotect → strip → Decompress`（RFC 4253 §6.2）。有状态：每方向单 `z_stream`，`deflate(Z_SYNC_FLUSH)` 逐包刷出保留滑动窗口，`inflate(Z_SYNC_FLUSH)` 1 MiB 上限防 bomb（`SSH_COMP_MAX_DECOMPRESSED`），`Reset` 保留窗口。
- **[INV-COMP-4] 单源 FFI**：仅 `nextpas.core.ssh.compress` → `nextpas.core.compress.zlib.ffi`；`grep -R 'zlib|paszlib' core/src/nextpas.core.ssh*` 除 `compress.pas` 外零命中（gate 见 §9）。

### 2.6 传输/重协商/保活

- **[INV-XPORT-1] 序列号连续**：包序列号 `uint32` 跨 `NEWKEYS` 连续递增，不回绕重置；`ApplyNewKeys` 后仅重置 `TSshRekeyPolicy` 计数，不漂移 `Seq`。
- **[INV-XPORT-2] 填充与长度**：`SSH_MIN_PADDING=4`、`SSH_MIN_PAD_BLOCK=8`（`none` 时块 8，否则 `AadLen` 对应块），`packet_length` 不含自身 4B，`padding_length` 后 `payload`+`padding` 按块对齐，`SSH_MAX_RECEIVE_PACKET=$40000` 硬上限，超限抛 `sekProtocol`/`E*LimitError`。
- **[INV-REKEY-1] 阈值与触发**：`SSH_REKEY_BYTES=1GiB` / `SSH_REKEY_INTERVAL_MS=3600000` 默认，`TSshRekeyPolicy` 基于 `TInstant` 单调时钟；`ShouldRekey` 仅当 `tstEncrypted` 为真时评估，`FThresholdBytes>0 && FBytesSince>=FThresholdBytes` 或 `FIntervalMs>0 && Elapsed>=Interval` 任一即触发；`0` 表示禁用该维度。`Account` 累计明文 `payload` 长度，`Reset` 在 `ApplyNewKeys` 后。
- **[INV-REKEY-2] 重协商不丢会话**：`ISshSession.Rekey / DoRekey` / `ISshAsyncSession.RekeyAsync` 保持 `session_id` 首轮 `H` 不变，`FNegotiated` 更新，失败不阻断调用方重试；`EnsureRekeyIfNeeded` 在 `Exec/OpenFileSystem` 前自动触发；`TProxyJumpSession.Rekey` 委托 `FTarget`。
- **[INV-KA-1] 心跳**：`SendKeepAlive / AsyncSendKeepAlive` 为 `SSH_MSG_IGNORE` 空心跳，`KeepAliveIntervalMs=0` 禁用；同步为按需调用，异步由 `TAsyncLoop.ScheduleMethod(TDuration.FromMilliseconds(KeepAliveIntervalMs))` 周期调度，`Close` 时 `CancelTimer`；`0` 时不调度（none 零开销）。
- **[INV-KA-2] AEAD MAC 忽略**：`chacha20-poly1305@openssh.com` / `aes*-gcm@openssh.com` 内建认证，协商所得 MAC 字段忽略；CTR 类必须搭配 ETM（`SshCipherRequiresMac`），否则协商失败。

### 2.7 安全不变量

- **[INV-SEC-1] 敏感清零**：`cipher` 侧 `FMainKey/FHeaderKey/FMacKey/TAesCtrStream.keystream` 等在 `Done/Destroy/Reset/ApplyNewKeys` 路径 `SecureZeroBytes`/`FillChar`，`TAesCtrStream.Done`/`Destroy` 必清零（record零堆分配）；`buffer` 不缓存敏感明文。
- **[INV-SEC-2] 常量时间**：主机密钥/签名比对走 `TConstantTime.CompareBytes`（`crypto.constant_time`），`IsZeroBytes` 单源，全零共享拒绝。
- **[INV-SEC-3] 边界守卫**：`TSshWriter.Ensure` 防溢出（`FLen > High(SizeUInt)-ACount` → `sekProtocol`）、`TSshReader.Need` 截断检查、未初始化结果 `Default(TSshExecResult)`、字符串 `PutStringText` 校 `UTF8IsValid`。

---

## 3. 错误处理

```pascal
TSshErrorKind = (sekProtocol, sekDisconnect, sekNegotiation, sekHostKey,
                 sekAuth, sekKeyFormat, sekCryptoVerify, sekTimeout, sekIO,
                 sekUnsupported, sekSftp, sekLimit);
ESSHError = class(Exception)
  property Kind: TSshErrorKind;
  property Code: Integer; // 关联的 SSH 断开码或 SFTP 状态码
end;
```

| 场景 | Kind | 行为 |
|------|------|------|
| 载荷截断/越界/负 mpint/padding 非法/包超限 | `sekProtocol` | 抛 `ESSHError`，关闭会话 |
| 对端 `SSH_MSG_DISCONNECT` | `sekDisconnect` | 携带断开码，上抛 |
| KEX/主机密钥/加密/MAC/压缩无交集 | `sekNegotiation` | `RequireAlg` 抛 `sekNegotiation` |
| 主机密钥验签失败/known_hosts 不匹配/严格模式未知密钥 | `sekHostKey` | `SshVerifyHostSignature` 抛 `sekHostKey` |
| 认证全失败（含 agent 私钥口令错） | `sekAuth` | `RunAuthentication` 终局抛 `sekAuth` |
| 私钥容器格式错/点不在曲线/全零 | `sekKeyFormat` | `IsZeroBytes/ValidateP256` 抛 `sekKeyFormat` |
| MAC/AEAD 校验失败 | `sekCryptoVerify` | `Unprotect` 抛 `sekCryptoVerify` |
| 超时（`ExecTimeoutMs/ConnectTimeoutMs`） | `sekTimeout` | `TDeadline` 抛 `sekTimeout` |
| 底层 IO/TCP/Agent socket | `sekIO` | 透传 `ESSHError(sekIO)`，认证路径可回退 |
| 不支持的 cipher/kdf/容器 | `sekUnsupported` | 协商/解析期抛 `sekUnsupported` |
| SFTP `STATUS != OK` | `sekSftp` | `SftpRoundTrip` 映射 `sekSftp` |
| 解压/包尺寸超限 bomb | `sekLimit` / `ELimitError` | `1 MiB` 防 bomb 抛 `sekLimit` |
| 调用方需区分成功/失败 | `Try*` 仅在 `bytes.binary` 层提供；会话层统一异常，上层直线代码 | 边界处统一捕获（handler/main） |

`TryXxx` 仅在底层 `bytes.binary` / `buffer.Try*` 存在；会话/认证层不提供 `TryConnect`，调用方以异常分支区分。

---

## 4. 线程安全

- **同步会话** `ISshSession` / `TSshChannel` / `TSshClientTransport`：单线程阻塞模型，实例非线程安全，跨线程共享需调用方同步；同一实例并发 `SendPacket` 未定义。
- **异步会话** `ISshAsyncSession` / `TAsyncSshTransport` / `TAsyncChannelStream`：`TAsyncLoop` 单线程事件化，`PostEx` 投递，回调在 loop 线程串行执行；外部线程仅可 `PostEx/ScheduleAt` 投递，不可并发直调 `AsyncSendPacket`。
- **策略 record** `TChannelWindow/TSshRekeyPolicy/TKeepAlivePolicy`：值语义，无共享状态，线程安全取决于外层持有者的同步。
- **Builder** `SshClient.*`：构造期单线程，`Connect` 后返回的 session 独立。
- **Channel 号** `GNext*ChannelId`：`atomic` 递增，跨线程安全。

---

## 5. 内存管理与资源释放（稳定性）

- **门面/会话**：`ISshSession/ISshAsyncSession` 为接口（`TInterfacedObject`），引用计数管理；`Close` 幂等，`Destroy` 中 `SecureZeroBytes` 敏感材料并释放 `z_stream`/`TBytes`/`IStream`。
- **传输**：`TSshWriter/Reader` 内部 `TBytes` 按需 `SetLength` 增长，`Free` 在 `try-finally` 中；`TAsyncSshTransport.FWriteBuf` 保活至 `Protect` 完成；`transport.core` 纯内存，不触 IO，失败不泄漏。
- **窗口/策略**：`TChannelWindow` 纯 record 零堆分配；`TSshRekeyPolicy/TKeepAlivePolicy` 持有 `TInstant` 值，无堆分配。
- **压缩**：`ISshCompressor` 每方向单 `z_stream`，`Destroy` 中 `deflateEnd/inflateEnd`，`EnableCompression` 懒创建（`none` 零开销）。
- **SFTP**：`SftpRoundTripAsync` 单 `pendingId` 串行 + `Busy→sekProtocol`，`4B` 长度前缀重组，`WINDOW_LOW_WATER_DIVISOR` 回补；`FWriteBuf` 保活，`Pending` 回调前清零防重入。
- **ProxyJump**：`TProxyJumpSession` 持有 `FJump+FTarget` 双生命周期，`Close/Destroy` 双关；`TAsyncChannelStream.CreateWithKeeper(FKeeper:IInterface)` 持有 `jump ISshAsyncSession`，`ProxySecondHop` 经 `FStream` 链保活，杜绝 `0xF0` 悬垂；`FQueuedPayload+TryFlushQueued(5ms)` 单飞重试。
- **管道**：`TMemPipe` 引用计数 `_AddRef=-1 + BeginThread + Free` 手工零泄漏路径，`HandleSftpOuter` 外层长度前缀正确跳过，已收敛 `71→0` 块。
- **资源释放不丢**：所有 `Create` 配 `try-finally Free`，`FreeAndNil` 经 `nextpas.core.base.utils`，`SecureRandom` 失败抛 `ECryptoRandomError`，不静默降级；`heaptrc 0` 全门封闭（`TIoReactor/BigNat-Montgomery` 侧线已收敛，`bytes.ops` 单源 + `ClearBigIntCache` 终局清零，见 §9）。

---

## 6. 性能（SSOT·inline / 零拷贝证据）

- **inline 冻结**：门面 `SshClient/SshConnect*`、策略 `TChannelWindow.ShouldReplenish/ReplenishAmount/Grant/CanSend/SliceSize/DidSend/Consume`、`TKeepAlivePolicy.ShouldSend`/`TKeepAliveScheduler.ShouldSend/Schedule/Cancel` 全 `inline` 薄转发；真实循环体 / SIMD 体（如 `SshKdfSha256` 扩展链、`X25519`）保持外联，不 inline 膨胀（见 `core/docs/design-conventions.md §2` 红线）。
- **零拷贝**：
  - `TByteSpan` 非拥有视图：`StripLeadingZeroView/SpanEqual/IsZeroBytes` 经 `bytes.ops` 零分配；`Move/CopyNonOverlap` 直拷，不经编码转换。
  - `TSshWriter.PutRaw` → `Move(APtr^,FBuf[FLen],ALen)` 零编码透传；`PutNameList` 零临时 `TStringArray`/`StringsJoin`，单次 `PutUInt32+Ensure` + 直接 `Move` 逗号分隔拼接（KEXINIT 10 name-list/握手零堆 churn）。
  - `TChannelWindow` 纯 record 值语义，`Consume/Grant` 仅算术，无分配（`TFlowWindow` 奢华别名已回退，复用 `TChannelWindow` 单源）。
  - `TAsyncSshTransport.AsyncSendPacket` 复用 `FWriteBuf` 保活，不复制已加密帧。
  - `KnownHosts/Agent/KeepAliveScheduler` 三晋升模块均为 facade/inline 转发，零额外堆分配（见 §8.2；`FlowWindow` 已回退为候选）。
- **性能门禁 SSOT（唯一来源；README 仅摘要引用，容差统一）**：

| 项 | 门禁 | 实测（`bench_ssh_cipher` 16KB·128MiB/方向，`bench_ssh_proxyjump` 50 次，`-O3` 单线程 `nextpas.core.bench`） | 判定 |
|---|---|---|---|
| cipher chacha20-poly1305 | 50 MiB/s/方向 | ~240–258 MiB/s | PASS（±10% 环境噪声不判回归） |
| cipher aes256-gcm | 50 MiB/s/方向 | ~418–598 MiB/s | PASS |
| cipher aes128-ctr+hmac-sha2-256-etm | 50 MiB/s/方向 | ~132–137 MiB/s | PASS |
| proxyjump 单跳 p50 | — | 5ms | 基准 |
| proxyjump 双跳 p50 | <600ms | 同步 431ms / 事件化 550ms（额外 426ms=二次KEX/轮询→零轮询） | PASS |

实测以 `MiB/s / p50/p95/avg` 输出；同量级波动 <10% 统一视为环境噪声（SSOT 容差），不铺陈于 README。

---

## 7. 依赖与分层纪律

- **L2 约束**：`nextpas.core.ssh` 为 L2 协议模块，与 `tls` 同层，仅依赖 L0–L1（`base/errors/platform/mem/bytes/text/collections/sync/async/time`）及文档化 L2 `crypto/hash/compress/net` owner；不依赖 L3（`http/websocket/tui/config/app`），同层无环。
- **四件套**：`base ← intf/ffi ← 实现 ← 门面`（见 §1.1）；无独立 `intf/ffi` 的实现直接依赖 `base` 与宿主 FFI，不机械创建空文件。
- **单源复用**：
  - `bytes.ops` 单源：`Equal/Compare/IndexOf/Fill/Reverse/Concat/Clone/CopySlice` 全部经 `nextpas.core.bytes.ops`，门面 `Bytes*` 便捷面 `inline` 转发，不复制逻辑（`StripLeadingZeroView/IsZeroBytes/CompareUnsigned` 单源）。
  - `transport.core` 单源：`padding/Protect+Compress/Seq+Rekey` 纯内存核，`transport` 与 `transport.async` 薄包装，不分叉。
  - `text` 单源：`UTF8IsValid/StringsSplit/IntToStr` 经 `nextpas.core.text.*`，零 `SysUtils` 直连。
  - `time` 单源：`TInstant/TDuration` 单调时钟经 `nextpas.core.time.base`，`rekey/keepalive` 均复用，先反哺 `core.time` 再消费（反哺证据：`time.GetTickCount64/TInstant`）。
- **FFI 边界**：
  - `nextpas.core.ssh.intf + net.ffi` 为同步/异步路径唯一拉取 `nextpas.core.net` 的单元（`IAsyncTcpStream/AsyncTcpDial(RFC8305)` 经 `net.ffi` re-export + `inline` 零拷贝转发，`session/agent/transport.async/proxyjump.async` 仅依赖 `intf+io.intf/net.ffi` 缝隙，运行时注入，零直连 `net.async.tcp`）。
  - `compress → compress.zlib.ffi` 唯一 zlib 入口（`grep` 已验证零直连 `zlib/paszlib`）。
- **零 RTL**：`core/src/nextpas.core.ssh*.pas` 禁止 `uses SysUtils/Classes/Windows/BaseUnix`（`tests` 除外）；缺能力先反哺 owner（如 `time` 单调时钟、`text.conv` 转换），不堆 workaround。
- **双编译器**：`nextpas.core.ssh` 为唯一实现层，不为 FPC 包装 `TStream/SysUtils` 兼容层；`units/<target>/` stub 仅名称桥接，方向为最终消除对 FPC 单元名的引用。

---

## 8. 所有者边界与奢华可抽取边界（已冻结）

### 8.1 Owner 矩阵

| 能力 | Owner | ssh 侧 stance |
|------|-------|---------------|
| 基础类型/常量 | `nextpas.core.base` | `base` 拥有 `SSH_*` 常量与 `TSshConnectOptions` |
| 异常分类 | `nextpas.core.exception` | `errors` 拥有 `TSshErrorKind/ESSHError` |
| 字节操作/Span | `nextpas.core.bytes.ops` | 单源复用，不自实现 `Equal/Compare/IndexOf` |
| 文本/UTF8/转换 | `nextpas.core.text.*` | `buffer` 校验 UTF8，不自实现 `UTF8IsValid/IntToStr` |
| 时间/单调时钟 | `nextpas.core.time` | `rekey/keepalive` 复用 `TInstant`，零 `SysUtils` |
| 内存/清零 | `nextpas.core.mem` | `SecureZeroBytes` 单源 |
| 加密/哈希 | `nextpas.core.crypto/hash` | 全部经 owner，不自带 AES/ChaCha/SHA256 实现 |
| 压缩 | `nextpas.core.compress.zlib.ffi` | 唯一入口，不直连 `zlib` |
| 网络 | `nextpas.core.net` | 经 `net.ffi+intf` 单缝隙注入（`IAsyncTcpStream` re-export + `inline` 转发，`transport.async` 零直连）；`AsyncTcpDial(RFC8305)` 同缝隙复用 |
| 平台 | `nextpas.core.platform` | 禁止直接使用 `Windows/BaseUnix` |

### 8.2 奢华可抽取边界（formal）

> 判定：已抽取 vs 候选。抽取需满足“单一职责 + 纯值语义/接口缝隙 + 单线程可复用 + 对外复用点明确”。

| 抽取项 | 状态 | 形态 | 复用点 | 证据 |
|--------|------|------|--------|------|
| `TSshRekeyPolicy` | **已抽取** (`rekey.pas`) | `record` + `TInstant` 单调时钟，`Init/Reset/Account/ShouldRekey(bool)` | `transport / transport.async` 单源；可复用于 `TLS/QUIC` 长连接 | S24 `base←rekey←transport(+.async)` 零 `SysUtils` |
| `TKeepAlivePolicy` | **已抽取** (`keepalive.pas`) | `record` + `TInstant`，`Init/Reset/ShouldSend` | `session(+.async)` 心跳；可复用于 `TLS/QUIC` KeepAlive | S25 `SendKeepAlive/AsyncSendKeepAlive` 为 `SSH_MSG_IGNORE` |
| `TChannelWindow` | **已抽取** (`window.pas`) | `record` + `SSH_WINDOW_LOW_WATER_DIVISOR=2`，`inline` 热路径，零堆分配 | `channel / channel.async / sftp.async` 窗口/低水位同构；可复用于 `HTTP/2` 流控 | S27 纯值语义，`ShouldReplenish/ReplenishAmount/Consume/Grant/SliceSize/DidSend` 全 `inline` |
| `KnownHosts` 协议帧 | **已抽取** (`knownhosts.pas` 纯 re-export) | `TSshKnownHosts = hostkey.TSshKnownHosts` 单别名，解析/验签/指纹/通配单源于 `hostkey`（`bytes.ops/TConstantTime`），零额外函数/堆分配 | 复用于 `core.net` 隧道主机校验 | S27′ 匠心修复：移除 `*Known` 四函数别名与 `*Facade` 双重词表，保留单别名薄导出，零拷贝 Move 单源 |
| `Agent` 协议帧 | **已抽取** (`agent.pas` 已独立) | `TSshAgentClient` 4B BE 长度帧 + `List(11→12)/Sign(13→14)` + `SshAgentKeyBlobToAlgName/Flags` | 复用于 `core.net` 隧道 agent 转发 | S14→S27′ 已独立，Unix socket 缝隙注入，零直连 `net` |
| `KeepAliveScheduler` | **已抽取** (`keepalive.scheduler.pas`) | `TKeepAliveScheduler` record + `TKeepAlivePolicy` 单源 + `TAsyncLoop.ScheduleMethod/CancelTimer` | 复用于 `TLS/QUIC` 定时心跳 | S27′ 解耦调度与策略，`ShouldSend/Schedule/Cancel` inline 周期，`Close` 幂等 |
| `TFlowWindow` 通用 | **候选·已回退** (`flow.window.pas` 仅兼容别名) | 原 `TFlowWindow = TChannelWindow` 仅别名、`FLOW_WINDOW_LOW_WATER_DIVISOR` 重复常量，未提供跨协议独立不变量，HTTP/2 实际使用 `TH2FlowState`，QUIC 使用 `TQuicFlowBudget`，未达 ≥2 协议复用实证，已回退；请直接使用 `TChannelWindow` | —（候选，复用点不足） | S27′ 匠心修复回退：移除奢华抽取与重复常量，`TChannelWindow` 单源 `inline` 零堆，`bytes.ops` 单源 |
| `Compress` 有状态流 | **候选**（已 formal） | `ISshCompressor` 双 `z_stream` + `Z_SYNC_FLUSH` + `1 MiB` 防 bomb | 复用于 `TLS` 压缩（如需） | S15 `transport` 序 `Compress→Protect` 已冻结 |

小而美判断：`rekey/keepalive/window` 已验证“抽取后调用方代码量不增、复用点≥2、测试可独立覆盖”；`KnownHosts/Agent` 保持候选需满足“独立 FFI 注入 + 单测可离线验证”才晋升独立模块。

---

## 9. 测试覆盖

### 9.1 测试目录（`core/tests/nextpas.core.ssh/`）

| Gate | 路径 | 说明 | 门禁 |
|------|------|------|------|
| buffer | `test_ssh_buffer` | RFC 4251 mpint 边界 + 越界 | `heaptrc 0` |
| cipher | `test_ssh_cipher` | RFC 8439/4231 向量 + 篡改检测 | `heaptrc 0` |
| kex | `test_ssh_kex` | 协商 first-match + KDF A-F + curve25519/dh 回退 | `heaptrc 0` |
| hostkey | `test_ssh_hostkey` | blob 解析/验签/指纹/known_hosts 明文+散列 | `heaptrc 0` |
| keys | `test_ssh_keys` | openssh-key-v1 未加密/加密 + bcrypt KAT + CRT 等价 | `heaptrc 0` |
| transport | `test_ssh_transport` | 版本交换/包帧/阈值/Ignore 往返 + async Protect/Unprotect + none 零开销 | `heaptrc 0` |
| compress | `test_ssh_compress` | 单包/有状态/空包/1 MiB bomb + 延迟/即时激活 | `heaptrc 0` |
| session | `test_ssh_session` | 全栈回环（内存管道双端独立逻辑）+ 压缩/重协商/keepalive | `heaptrc 0` (23/23) |
| session_async | `test_ssh_session_async` | 异步回环 + KeepAlive 100ms 触发后 Exec | `heaptrc 0` (6/6) |
| sftp | `test_ssh_sftp` | SFTP v3 12 用例密闭门（假 wire） | `heaptrc 0` |
| sftp_async | `test_ssh_sftp_async` | SFTP async 7/7（INIT 215ms + STAT/RW） | `heaptrc 0` (7/7) |
| agent | `test_ssh_agent` | 内存管道 5 用例（list/sign/multiple） | `heaptrc 0` (5/5) |
| proxyjump | `test_ssh_proxyjump` | 同步双跳 5/5（exec/sftp via jump） | `heaptrc 0` (5/5) |
| proxyjump_async | `test_ssh_proxyjump_async` | 异步双跳 3/3 零轮询 | `heaptrc 0` (3/3) |
| sftp_async_via_jump | `test_ssh_sftp_async_via_jump` | 异步 SFTP via jump 4/4（realpath/stat + 双失败） | `heaptrc 0` (4/4) |
| bench | `bench_ssh_cipher` | 16KB 包吞吐（50 MiB/s 门禁） | `HEAPTRC_GATE=0`（基准不链 `heaptrc`，由其余 12 门 `heaptrc 0` 覆盖） |
| bench | `bench_ssh_proxyjump` | 单跳 5ms / 双跳 431ms p50/p95/avg | `HEAPTRC_GATE=0`（同上） |
| e2e | `e2e_ssh_live` | opt-in `NEXTPAS_SSH_E2E_LOCAL=1` / `REMOTE=1` / `ASYNC_JUMP=1` 双容器 | `heaptrc 0` |

回环为**真**：测试内最小 SSH 服务端（独立服务端逻辑路径）与客户端在内存管道上完成完整握手→认证→exec/sftp，断言 stdout/exit code/Stat，无外部 sshd 即可证明协同正确。真实互操作由 `e2e_ssh_live` 承担（opt-in，不进默认 gate）。

```bash
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_buffer
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_cipher
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_kex
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_hostkey
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_keys
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_transport
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_compress
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_session
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_session_async
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_sftp
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_sftp_async
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_sftp_async_via_jump
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_agent
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_proxyjump
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_proxyjump_async
make focused FOCUS=core/tests/nextpas.core.ssh/bench_ssh_cipher
make focused FOCUS=core/tests/nextpas.core.ssh/bench_ssh_proxyjump
make hygiene && git diff --check
```

### 9.2 Source-contract gates

- `grep -R 'SysUtils' core/src/nextpas.core.ssh*`：`uses` 零命中（注释提及除外）。
- `grep -R 'zlib|paszlib' core/src/nextpas.core.ssh*`：仅 `compress.pas → compress.zlib.ffi`。
- `grep -R 'nextpas.core.net' core/src/nextpas.core.ssh*`：仅 `net.ffi/ffi`（`transport.async/proxyjump.async` 已 `net.ffi` 单缝隙 `IAsyncTcpStream` re-export 零直连，`session.async` 同缝隙收口；`grep` 已验证零 `net.async.tcp` 直连）。
- `grep -R 'bytes.ops' core/src/nextpas.core.ssh.buffer`：单源复用。
- 产物卫生：`scripts/build-hygiene-check.sh` 拦截 `.o/.ppu/.a/.so/dylib/link*.res` 落源码树；`build/` 与 `.nextpas/` 为唯一产物区。

---

## 10. 变更记录

| 日期 | 版本 | 变更 | 作者 |
|------|------|------|------|
| 2026-09-01 | 1.0 | 初版冻结：KEX/主机密钥/认证回退/窗口/压缩激活时机不变量；`transport.core` 单源、`bytes.ops` 单源、`net.ffi` 缝隙与 `compress.zlib.ffi` 唯一入口；`rekey/keepalive/window` 已抽取与 4 候选 formal；inline/零拷贝与资源释放不丢证据；L2 分层与测试门禁 | ssh lane |
| 2026-09-02 | 1.1 | 单缝隙收口：`transport.async` 去直连 `net.async.tcp`，`IAsyncTcpStream` 经 `ssh.net.ffi` re-export + `inline` 转发（`SshAsyncTcpStreamAdopt/Connect` 零拷贝），`net.ffi` 为唯一 `net` 拉取点；更新 FFI 边界与 gate | ssh lane |
| 2026-09-02 | 1.2 | 匠心修复：`KnownHosts→knownhosts.pas`、`Agent→agent.pas` 已独立、`KeepAliveScheduler→keepalive.scheduler.pas` 三项由候选晋升已抽取（facade/inline 零拷贝，复用 `bytes.ops` 单源）；`TFlowWindow→flow.window.pas` 晋升名不副实已回退（仅别名+重复常量，未达 ≥2 协议复用）；性能 SSOT 收敛至 §6 单表，README 摘要引用，±10% 统一环境噪声；`ssh.pas` 门面增 re-export，L2 四件套合规 | ssh lane |
| 2026-09-02 | 1.2 | 零泄漏封闭：移除 7 门 `HEAPTRC_GATE=0` 豁免（`sftp_async/proxyjump*`/`session*`/`agent`），`TIoReactor/BigNat` 侧线收敛（`ClearBigIntCache` + `TAsyncLoop` 单源 `bytes.ops` 零拷贝，`inline` 热路径）；`heaptrc 0` 全门封闭，`bench` 保留 `HEAPTRC_GATE=0`（吞吐不链 `heaptrc`） | ssh lane |
| 2026-09-02 | 1.3 | 匠心修复回退：`TFlowWindow` 奢华抽取移除（仅 `TChannelWindow` 别名+`FLOW_WINDOW_LOW_WATER_DIVISOR` 重复常量，未提供跨协议独立不变量，未达 ≥2 协议复用实证，HTTP/2 用 `TH2FlowState`），`flow.window.pas` 保留兼容 deprecated 别名、`ssh.pas` 移除 re-export，`TChannelWindow` 单源 `inline` 零堆，复用 `bytes.ops` 单源，维护面收敛 | ssh lane |

# nextpas.core.ssh 代码契约

**模块路径**：`core/src/nextpas.core.ssh*.pas`（27 个生产源文件；含 `proxyjump.async`/`sftp.async` 等事件化路径）
**层级**：L2（依赖 L0-L1：`base`/`bytes`/`text`/`collections`/`hash`/`crypto`/`compress`/`io`/`time`；与 `tls` 同层——面向字节流的协议实现；仅 `net.ffi` / `net.async.tcp` 为显式允许的 L2 peer）
**Owner**：`codex/core-ssh` lane
**最后更新**：2026-09-01
**版本**：1.0

---

## 概要

SSH-2 客户端协议栈（对标 libssh2 能力面），纯 Pascal 实现，无任何 C 库依赖。传输层复用 `nextpas.core.net`（阻塞 `ITcpStream`）与 `nextpas.core.net.async`（事件化 `IAsyncTcpStream` / `AsyncTcpDial(RFC8305)`）；密码学原语全部来自 `nextpas.core.crypto` / `nextpas.core.hash`；压缩经 `nextpas.core.compress.zlib.ffi` 唯一入口。第一期只做客户端，服务端不在本模块范围；同步阻塞 API 为主，`TAsyncLoop` 事件化路径与同步同密同窗同压缩同序。

---

## 1. 模块边界

### 1.1 子模块地图（四件套 `base ← intf/ffi ← 实现 ← 门面`）

```
ssh.pas                    ← 门面：纯 re-export + 便捷函数（SshClient/SshConnect/SshExec 等；无 duplicate identifier）
ssh.base                   ← 协议常量、消息号、TSshConnectOptions、SSH_REKEY_BYTES/INTERVAL
ssh.errors                 ← ESSHError + TSshErrorKind（12 种）
ssh.intf                   ← 缝隙接口 IDialer/ISshAgentDialer（仅 io.intf + net.intf，不拉 net 实现）
ssh.net                    ← 网络拨号桥接（唯一拉取 nextpas.core.net 阻塞 dial 的单元；原名 net.ffi 已按“FFI仅含cdecl external”更名为普通实现单元）
ssh.net.ffi                ← 保留 DEPRECATED 占位 FFI（仅 cdecl external getpid 占位，逻辑已迁至 ssh.net）
ssh.buffer                 ← RFC 4251 wire 类型读写器（TsshWriter/TsshReader）
ssh.cipher                 ← 包加密编解码器（ISshPacketSender/Receiver；none/chacha/gcm/ctr+etm）
ssh.transport.core         ← 传输核单源（padding/Protect+Compress/Seq/Rekey 纯内存；transport/transport.async 薄包装复用）
ssh.rekey                  ← Rekey 策略 TSshRekeyPolicy（TInstant 单调时钟，消除双实现漂移）
ssh.keepalive              ← KeepAlive 策略 TKeepAlivePolicy（TInstant 单调时钟，同步预留/异步 ScheduleMethod）
ssh.compress               ← 有状态 zlib / zlib@openssh.com（ISshCompressor 双 z_stream）
ssh.kex                    ← KEXINIT 协商 + SHA256 KDF A-F 扩展链
ssh.kex.curve25519         ← curve25519-sha256 客户端交换（X25519）
ssh.kex.dhgroup14          ← diffie-hellman-group14-sha256 回退（2048-bit MODP，TryBigIntModExp）
ssh.hostkey                ← 主机密钥解析/验签/指纹/known_hosts（ed25519/ecdsa-p256/rsa-sha2）
ssh.rsa                    ← RSA PKCS#1 v1.5 签名/验签核（DigestInfo 单一来源，CRT 加速）
ssh.keys                   ← openssh-key-v1 私钥容器（ed25519/rsa，未加密与 aes256-ctr+bcrypt 加密）
ssh.auth                   ← userauth 载荷构造/解析（probe hasSig=false + PK_OK / signed）
ssh.channel                ← 单通道引擎（exec/subsystem/direct-tcpip + TChannelStream 字节流）
ssh.channel.async          ← 异步通道（TAsyncExecRunner + 窗口/超时）
ssh.transport              ← 版本交换 + 二进制包状态机（阻塞，薄包装 transport.core）
ssh.transport.async        ← 异步传输层（TAsyncLoop+IAsyncTcpStream，复用 transport.core）
ssh.agent                  ← ssh-agent 协议客户端（Unix socket 长度前缀帧，11→12/13→14）
ssh.session                ← 会话编排（握手→认证→通道，agent→privatekey→password 回退，ProxyJump direct-tcpip）
ssh.session.async          ← 异步会话（AsyncTcpDial + 状态机握手/认证，复用 cipher/kex/hostkey/compress）
ssh.proxyjump.async        ← 异步 ProxyJump（TAsyncChannelStream 无轮询 + Keeper 保活 + TryFlushQueued 5ms）
ssh.sftp                   ← SFTP v3 客户端（ISshFileSystem，TSshChannelWire + 4B 重组）
ssh.sftp.async             ← SFTP v3 异步（ISshAsyncFileSystem，PostEx + SftpRoundTripAsync 单 pending）
ssh.window                 ← 通道窗口可复用策略（WINDOW_LOW_WATER_DIVISOR=2，半窗回补）
```

依赖方向：`base ← errors/buffer ← cipher/kex/hostkey/rsa/keys/auth ← transport.core ← transport(+.async)/compress/channel ← session(+.async) ← 门面`；`base ← rekey/keepalive/window ← transport.core` 单源。

### 1.2 分层硬约束

- **L2 只向下**：仅依赖 L0-L1 与 `crypto`/`hash`/`compress`/`time`/`text.conv`/`base.utils`；禁止依赖 `tls`/`http`/`tui` 等 L3。
- **net 拉取单点**：仅 `ssh.net` 可 `uses nextpas.core.net`（阻塞 `TcpConnect/UnixConnect`；原 net.ffi 已更名为 net，net.ffi 仅保留占位 cdecl）；仅 `transport.async/session.async/proxyjump.async` 可直连 `net.async.tcp`（`IAsyncTcpStream/AsyncTcpDial`），判定为**允许的 L2 async peer**（`net` 仅覆盖阻塞 `ITcpStream`，复用 `transport.core` 已消除逻辑漂移）。
- **zlib 单点**：仅 `ssh.compress` 可 `uses nextpas.core.compress.zlib.ffi`；`grep -R "zlib\|paszlib" core/src/nextpas.core.ssh*.pas` 仅该单元命中（`grep` 已验证零直连泄漏）。
- **bytes.ops 单源**：所有 `TBytes`/`Span` 比较、拼接、切片、查找仅经 `nextpas.core.bytes.ops`（`SpanEqual/Compare/IndexOf/Concat/Clone/CopySlice`）；其余单元（含 `buffer`/`cipher`/`hostkey`）经 `inline` 转发或直接调用 `bytes.ops`，禁止自带比较表或手写 `Move` 循环分叉。
- **零 SysUtils 直连**：`core/src/nextpas.core.ssh*.pas` 禁止 `uses SysUtils/Classes/BaseUnix/Windows`（`grep -R "SysUtils" core/src/nextpas.core.ssh*` 仅注释豁免；`IntToStr`/`Format`/`GetTickCount64`/`FreeAndNil`/`CompareMem` 分别经 `text.conv`/`text.format`/`time`/`base.utils`/`crypto.constant_time`）。
- **门面纯 re-export**：`nextpas.core.ssh.pas` 不含逻辑，仅类型别名与 `inline` 转发；不得引入新状态。

门禁：`grep` 抽查（bytes 单源 / SysUtils 零直连 / zlib 单点 / net 拉取两点）见 `test_ssh_session` 等 source-contract 脚本注释关联本节。

---

## 2. 不变量

| ID | 内容 | 证据/门禁 |
|----|------|-----------|
| **INV-1** | **Wire 边界**：`SSH_IDENT_MAX_LINE=255`（含 CRLF）、`SSH_MAX_RECEIVE_PACKET=256 KiB` 防滥用；`TsshWriter.Ensure/Need` 截断；`SSH_MIN_PADDING=4`、`SSH_MIN_PAD_BLOCK=8`；`mpint` 按 RFC 4251 编码（`0x00` 前导去符号）。 | `test_ssh_buffer` RFC 4251 mpint 边界 + 越界 |
| **INV-2** | **包加密三族**：`none`（握手前长度明文无校验）/`chacha20-poly1305@openssh.com`（header key 流掩码长度、Poly1305 裸覆盖 `encLen\|\|ct` 无 pad16、tag 16）/`aes*-gcm@openssh.com`（明文长度作 AAD、计数器从 1 起、阈值 `FFFFFF00` 前重协商）/`aes*-ctr+hmac-sha2-*-etm`（EtM 先验 MAC 再解密、CTR `TAesCtrStream` 跨包 keystream 持久、后端 `AES-NI→ct64→朴素`、`FKSOff` 跨调用持久）；`SecureZero` 敏感材料（`FMainKey/FHeaderKey/FKey/FMacKey` 等 `Destroy` 清零）。 | `test_ssh_cipher` RFC 8439 §2.3.2 + 篡改检测 + HMAC 向量 |
| **INV-3** | **KEX 协商**：`KEXINIT` first-match；`SHA256 KDF A-F` 扩展链；`curve25519-sha256` 优先（含 `@libssh.org` 别名）、`diffie-hellman-group14-sha256` 回退（RFC 3526 256B 素数 `g=2`、`1<f<p` 与全零共享拒绝）；`e/f/K` 均为 mpint 的 `SshBuildDHGroup14HashInput` 输入序；协商优先级 `ed25519 > ecdsa-sha2-nistp256 > rsa-sha2-512 > rsa-sha2-256`。 | `test_ssh_kex` 协商优先级 + 独立重算 K/H |
| **INV-4** | **主机密钥**：blob 解析 `ssh-ed25519/ecdsa-sha2-nistp256/rsa-sha2-*`（`04\|\|X\|\|Y` 65B 未压缩点经 `TryValidateP256Point` 落 `sekKeyFormat`）；验签 `Ed25519Verify/RsaVerifyPkcs1v15/ECDSA P-256`（`mpint(r)+mpint(s)→DER`）；`SHA256` 指纹；`known_hosts` 明文通配 + `\|1\|` 散列（`bcrypt_pbkdf` 路径复用 crypto 层）；`StrictHostKeyChecking=True` 时未知密钥直接 `sekHostKey` 拒绝。 | `test_ssh_hostkey` 12/12（含 ecdsa 散列/明文） |
| **INV-5** | **传输帧**：版本交换逐字节容忍前置行；`ISshPacketSender.PaddingBlock/AadLen`（AEAD/EtM=4、`none`=0，`packet.c` 语义）；`BodyLengthFromHeader/TrailerSize/Protect/Unprotect` 两步还原；序列号跨 `NEWKEYS` 连续；`NEWKEYS` 切换原子；`SendPacket` 先 `Compress` 再 `padding/Protect`，`ReadPacket` 先 `Unprotect/strip` 再 `Decompress`（RFC 4253 §6.2 顺序）。`transport.core` 为唯一纯内存核，`transport`/`transport.async` 薄包装。 | `test_ssh_transport` 13/13（含 async Protect/Unprotect + none 零开销） |
| **INV-6** | **通道窗口**：`SSH_DEFAULT_WINDOW_SIZE=2 MiB / MaxPacket=32768`；`TChannelWindow` 半窗回补 `WINDOW_LOW_WATER_DIVISOR=2`（消费过半回补）；`GNextLocalChannelId` 进程单调递增（同步整型、异步 `atomic`）；`PumpFiltered` 按 `LOCAL_CHANNEL_ID` 校验 recipient 并过滤陈旧 `92-100` 族迟滞帧；`CHANNEL_DATA` 的 `data` 为 `string` 含 4B 长度前缀；`SendData/PumpData` 双向 `PeerWindow/Max` 限流。 | `test_ssh_session` 23/23 + `test_ssh_proxyjump` 5/5 |
| **INV-7** | **压缩**：`ISshCompressor` 每方向单 `z_stream`，`deflateInit/inflateInit`，每包 `Z_SYNC_FLUSH` 动态扩容保留滑动窗口，`inflate` 1 MiB 上限防 bomb（`SSH_COMP_MAX_DECOMPRESSED`）；`CreateSshZlibCompressor` 单对象双流；`none` 默认零开销（不创建 `z_stream` 直通）；`zlib@openssh.com` 延迟（`USERAUTH_SUCCESS` 后）、`zlib` 即时（`NEWKEYS` 后），`EnableCompression` 懒创建。 | `test_ssh_compress` 4/4（有状态第2包更小、bomb 拒绝） |
| **INV-8** | **Rekey/KeepAlive 单源**：`TSshRekeyPolicy/TKeepAlivePolicy` 基于 `TInstant` 单调时钟（`time`），`SSH_REKEY_BYTES=1 GiB / REKEY_INTERVAL=1h`（`0` 禁用）；`ShouldRekey` 仅 `tstEncrypted` 生效，`ApplyNewKeys` 后 `Reset` 不漂移序列号/窗口；`KeepAlive` 为 `SSH_MSG_IGNORE` 空心跳，`async` 经 `TAsyncLoop.ScheduleMethod` 周期调度（`0` 禁用，`Close` 时 `CancelTimer`）。 | `test_ssh_transport` 阈值/时间边界 + `session.async` KeepAlive 回环 |
| **INV-9** | **认证**：`password/publickey/ssh-agent` 三路径；`session` 回退 `agent→privatekey→password`（`sekAuth/sekIO` 失败不阻断下一方式）；`openssh-key-v1` 未加密与 `aes256-ctr+bcrypt` 加密容器（`bcrypt_pbkdf` 48B→key32+iv16→AES-256-CTR，`checkint` 校验）；`RSA PKCS#1 v1.5` 单一来源 `DigestInfo` 前缀 + 常量时间比较，CRT 优先（`p*q==n`/`q*iqmp%p==1` 校验，`dp/dq/Garner`，失败回退 naive）；`agent` `UnixConnect/IReadWriteCloser` 双注入，`11→12` 枚举 + `13→14` 代签名（`ssh-rsa→rsa-sha2-512` 映射），probe `PK_OK` 时序与 OpenSSH 一致。 | `test_ssh_agent` 5/5 + `test_ssh_keys` 加密往返 + `ssh_rsa_kat` KAT |
| **INV-10** | **ProxyJump**：`direct-tcpip` 单通道隧道复用跳板加密传输；`TChannelStream`（同步 `FBuf`+`PumpData/SendData`）/`TAsyncChannelStream`（异步 `FReadBuf+AccountConsume+ArmRead/OnPacket+PeerWindow+AsyncRead/Write`，`FQueuedPayload/P/Active+TryFlushQueued 5ms` 单飞）；`TProxyJumpSession/ TAsyncProxyConnector` 持有 `jump+target` 双生命周期（`Keeper:IInterface` 保活，`GProxyNextChan atomic`），第二跳 `KEX→认证→通道` 在字节流上重跑。 | `test_ssh_proxyjump` 5/5 + `test_ssh_proxyjump_async` 3/3 |
| **INV-11** | **SFTP v3**：`INIT` 握手 + `open/read/write/close/opendir/readdir/realpath/stat/lstat/remove/mkdir/rmdir`；`TSftpAttrs` 编解码与 `transport` 窗口同构；`ISftpWire` 抽象 + `TSshChannelWire` 适配（4B 前缀流重组）；异步 `TAsyncSftpChannel` 单 `pendingId` 串行 + `SftpRoundTripAsync` + `Busy→sekProtocol`；`WINDOW_LOW_WATER_DIVISOR=2` 回补。 | `test_ssh_sftp` 12/12 + `test_ssh_sftp_async` 7/7 + `test_ssh_sftp_async_via_jump` 4/4 |
| **INV-12** | **错误分类**：`TSshErrorKind = sekProtocol/sekDisconnect/sekNegotiation/sekHostKey/sekAuth/sekKeyFormat/sekCrypto/sekTimeout/sekIO/sekSftp/sekBusy/sekUnsupported`，`ESSHError.Kind` 携带；`sekCrypto` 仅用于 AEAD/EtM 校验失败等密码学失败，不与 `sekProtocol` 混用。 | 全门面 `ESSHError` 携带 Kind 断言 |
| **INV-13** | **资源释放不丢**：`TAesCtrStream/TSshChacha*/TSshGcm*/TSshCtrEtm*` `Destroy` 中 `SecureZeroBytes`；`TSshZlibCompressor.Destroy` 配对 `deflateEnd/inflateEnd`（`Reset` 亦配对重建）；`TSshClientTransport/TAsyncSshTransport` `FreeAndNil` + `FWriteBuf` 保活；`TChannelStream.Close` 幂等；`TAsyncLoop+TPoller+TIoReactor+RTLEvent` 全路径 `Close` 释放环/队列/事件（零 `HEAPTRC_GATE=0` 豁免，`heaptrc 0` 统一门禁）。 | `heaptrc 0` 统一门禁（见 §5） |
| **INV-14** | **性能零拷贝/inline**：`PutU32BE/U32BEOf/SeqBytes/ChachaNonce/GcmNonce` 等小访问器 `inline`；`SpanEqual/Compare/IndexOf` 经 `bytes.ops` + `Move` 直拷零编码转换；`TByteSpan` 非拥有视图仅 `Concat/Clone/CopySlice` 分配；`SshAesCtrCrypt` 复用 `TAesCtrStream` 零额外拷贝；`none`/`Compress=False` 零 `z_stream` 开销。 | `bench_ssh_cipher`/`bench_ssh_proxyjump` 基线（见 §4） |

---

## 3. 错误与生命周期

- **异常为主**：`ESSHError` 为唯一公开异常类型；调用方直线代码，边界（`Exec`/`OpenFileSystem`/`SftpOpen`）统一捕获。
- **前置条件**：空容器/不支持算法/非法 `known_hosts`/越界 `MaxPacket` 等抛 `sekProtocol/sekNegotiation/sekKeyFormat/sekUnsupported`；传输中途 `sekIO/sekTimeout/sekDisconnect`。
- **所有权**：`ISshSession/ISshFileSystem/ISshAsyncSession/ISshAsyncFileSystem` 为 `interface` 引用计数；`TSshClientTransport/TAsyncSshTransport/TChannelStream/TAsyncChannelStream` 由会话持有，`Close` 幂等；`TAsyncLoop` 生命周期由调用方持有，`PostEx+OnDiscard` 防关环漏回调。
- **零拷贝纪律**：`Protect/Unprotect/Compress/Decompress` 均返回新 `TBytes`，调用方持有；`Span` 视图随 `Append` 失效，不跨包保活。

---

## 4. 性能契约

| 域 | 路径 | 实测（`-O3` x86_64 单线程） | 门禁 |
|----|------|------------------------------|------|
| **Cipher** 16KB 128MiB/方向 | `chacha20-poly1305` protect/unprotect | ~258 / ~253 MiB/s | 50 MiB/s/方向 |
| | `aes256-gcm` | ~479 / ~418 MiB/s | 50 |
| | `aes128-ctr+hmac-sha2-256-etm` | ~137 / ~132 MiB/s | 50 |
| **RSA** 2048 `rsa-sha2-512` | naive `d` 直接模幂 | ~200 ms | — |
| | CRT `dp/dq+Garner` | ~38 ms (≈5.2×) | — |
| **KEX** | `curve25519-sha256` | ~1 ms | 优先 |
| | `diffie-hellman-group14-sha256` | 50–70 ms (≈50×) | 回退可用性优先 |
| **ProxyJump** `bench_ssh_proxyjump` 50 次 | 单跳 `exec` p50/p95/avg | 5 / 8 / 5.1 ms | — |
| | 同步双跳 via jump | p50 431 ms / 额外 426 ms（含二次 KEX/USERAUTH + 轮询 `50ms+5ms`） | <600 ms |
| | 异步双跳（`proxyjump.async` 零轮询） | ~550 ms（含二次握手，轮询消除） | — |
| **Compress** | `none` | 零开销（不创建 `z_stream`） | — |
| | `zlib@openssh.com` 延迟 | `USERAUTH_SUCCESS` 后首包起，有状态第2包显著更小 | 1 MiB 防 bomb |
| **SFTP async** | `INIT` 首包 / `STAT` / `Read/Write` chunk 32 KiB | 215 / 115 / 216 ms | — |

`inline` 小访问器 + `bytes.ops` 单源 `Move` 直拷 + `TByteSpan` 视图已在 `cipher/buffer/compress` 热路径验证；`bench_ssh_cipher` / `bench_ssh_proxyjump` / `bench_tls13_record` 为回归红线（`±5%` 波动视为环境噪声，`bench HEAPTRC_GATE=0` 防吞吐失真由 `common.mk HEAPTRC_GATE=1` 统一门禁下其余 production gates 覆盖泄漏：`ssh` / `crypto/tls` 全量 `heaptrc 0`）。

---

## 5. 线程与可抽取性

### 5.1 线程模型

- 同步路径：阻塞 `ITcpStream`，调用线程直调，无后台线程。
- 异步路径：`TAsyncLoop` 单线程事件化；`transport.async/channel.async/session.async/proxyjump.async/sftp.async` 均经 `PostEx` 投递，`TAsyncSshTransport.FWriteBuf` 保活，`TryOpImmediately` 后置与 `ProbeWatch` 补检消除竞态。

### 5.2 可抽取候选（已识别，未机械拆分）

| 候选 | 现状 | 复用目标 | 判定 |
|------|------|----------|------|
| `TSshRekeyPolicy` | 已抽取 `nextpas.core.ssh.rekey`（示范） | `tls` 重协商 / `quic` 密钥轮换 | **已落地**，`base←rekey←transport(+.async)` 单向 |
| `TKeepAlivePolicy` / `KeepAliveScheduler` | 已抽取 `keepalive`（`TInstant` 单调） | `TLS/QUIC` 心跳、`http` 健康探测 | **已落地**，`TAsyncLoop.ScheduleMethod` 周期心跳 |
| `ChannelWindow` | `window.pas` 单源（`WINDOW_LOW_WATER_DIVISOR=2`） | `http2` 流控、通用信用窗口 | 可抽 `core.net` 或 `core.sync` 窗口原语 |
| `TransportCore` | `transport.core` 单源（padding/Protect/Seq/Rekey 纯内存） | 任意 `net` 上有帧协议（`tls` 记录层） | **已落地**，薄包装零漂移 |
| `KnownHosts`/`Agent` 帧 | `hostkey`/`agent` 协议帧 | `core.net` 隧道、`git` ssh 传输 | 保留在 `ssh`，需第二实证再议上移 |
| `SftpWire` | `sftp` 4B 前缀重组 + `WINDOW` 回补 | 通用子系统通道复用 | 保留，`sftp.async` 已复用 |

抽取纪律：缺能力**先反哺 owner**（如 `time.GetTickCount64/TInstant` 反哺 `core.time`，`LevelToZlib` 复用 `compress.base`），业务以本 CONTRACT 为准，不为抽取而分裂协议语义。

---

## 6. 测试门禁（最小）

回环测试（`TLoopServer` 最小服务端在内存管道上走独立服务端逻辑路径）为默认门禁；`e2e_ssh_live` 为 opt-in 真实互操作，不进默认 gate。

```bash
# 单元回环（focused-runtime，heaptrc 0 统一门禁，零 HEAPTRC_GATE=0 豁免；bench 保持吞吐豁免）
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

# 真实互操作（opt-in，不进默认 gate）
# 本地 Docker 夹具（Alpine 9.7 全封闭，TOFU known_hosts）
NEXTPAS_SSH_E2E_LOCAL=1 bash core/tests/nextpas.core.ssh/e2e_ssh_live/run_e2e.sh
# 远端直连（含 async 双容器 via jump）
NEXTPAS_SSH_E2E_REMOTE=1 NEXTPAS_SSH_E2E_HOST=<host> NEXTPAS_SSH_E2E_USER=<user> \
  NEXTPAS_SSH_E2E_KEYFILE=<未加密 ed25519 私钥> bash core/tests/nextpas.core.ssh/e2e_ssh_live/run_e2e.sh
```

**真实性等级**：`focused-runtime`（回环 `focused` 19/19 + 12/12 + 5/5 等）+ `e2e`（Docker Alpine 9.7 与 Debian 10.0p2 8 场景，`heaptrc 0`）。`e2e` 场景：`exec marker` / 同会话二次 `exec` / `exit code` 透传 / `stdout/stderr` 分离 / `known_hosts` 不匹配预认证拒绝 / 16 次连续 `exec` 压力 / SFTP 写→读→列目→stat→删除回路 / RSA-CRT/ECDSA/加密私钥 / DH 回退 / agent / 压缩有状态窗口；`async` 侧 `via jump` 双容器为额外门。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-09-01 | 1.0 | 初始版本：补齐缺失 CONTRACT.md；锚定 L2 边界（net.ffi 单点 + net.async.tcp 允许 peer + compress.zlib.ffi 单点 + bytes.ops 单源 + 零 SysUtils 直连）、14 条 INV（wire/cipher/kex/hostkey/transport/channel/compress/rekey/keepalive/auth/proxyjump/sftp/错误/资源/性能）、可抽取候选与回归基线 |

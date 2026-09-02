# nextpas.core.ssh

SSH-2 客户端协议栈（对标 libssh2 的能力面），纯 Pascal 实现，无任何 C 库依赖。
传输层复用 `nextpas.core.net`（阻塞 `ITcpStream`），密码学原语全部来自
`nextpas.core.crypto` / `nextpas.core.hash`。

## 定位

- L2 协议模块（与 `tls` 同层：面向字节流的协议实现）。
- 第一期只做客户端（libssh2 本身也是客户端为主）；服务端不在本模块范围。
- 同步阻塞 API 为主（贴合 `net.TcpConnect`）；`S16` 起提供 `TAsyncLoop + IAsyncTcpStream` 事件化路径（`AsyncTcpDial(RFC8305)` + 回调状态机），与同步路径零开销复用同一密码学与压缩。

## 算法支持（现代集合）

| 用途 | 支持 |
| --- | --- |
| KEX | `curve25519-sha256`、`curve25519-sha256@libssh.org`、`diffie-hellman-group14-sha256`（回退） |
| 主机密钥 | `ssh-ed25519`、`ecdsa-sha2-nistp256`、`rsa-sha2-512`、`rsa-sha2-256` |
| 加密 | `chacha20-poly1305@openssh.com`、`aes256-gcm@openssh.com`、`aes128-gcm@openssh.com`、`aes256-ctr`、`aes192-ctr`、`aes128-ctr` |
| MAC | `hmac-sha2-256-etm@openssh.com`、`hmac-sha2-512-etm@openssh.com`（仅 ETM；CTR 类算法必需） |
| 压缩 | `none`（默认零开销）、`zlib@openssh.com`（延迟，`USERAUTH_SUCCESS` 后启用）、`zlib`（即时，`NEWKEYS` 后启用）— 有状态流式（每方向 `z_stream`，`Z_SYNC_FLUSH` 逐包刷出，1 MiB 解压上限防 bomb） |
| 认证 | `password`、`publickey`（openssh-key-v1 容器：ssh-ed25519、ssh-rsa；支持未加密与 `aes256-ctr`+`bcrypt` 加密；RSA 走 `rsa-sha2-512` 签名）、`ssh-agent`（Unix socket 11→12 枚举 + 13→14 代签名，支持 ed25519 / rsa-sha2-512/256，回退 `privatekey→password`） |

明确不支持并会在协商阶段给出清晰错误的历史包袱：
SHA-1 KEX、DH group1、非 ETM MAC、ssh-dss（zlib 压缩已支持，见下）。

## API 形态

```pascal
uses nextpas.core.ssh;

{ Fluent builder }
var
  LSession: ISshSession;
  LResult: TSshExecResult;
begin
  LSession := SshClient
    .Host('192.168.1.10')
    .Port(22)
    .User('root')
    .Password('secret')
    .KnownHostsFile('/home/me/.ssh/known_hosts')
    .StrictHostKey(True)
    .Connect;
  try
    LResult := LSession.Exec('uname -a');
    WriteLn('exit=', LResult.ExitCode);
    WriteLn(LResult.StdOutText);
  finally
    LSession.Close;
  end;
end;

{ 一次性便捷函数 }
LResult := SshExec('host', 22, 'user', 'pass', 'ls -l');
```

错误处理遵循 core 惯例：异常为主。`ESSHError` 携带 `Kind: TSshErrorKind`
（协议违规 / 对端断开 / 协商失败 / 主机密钥不符 / 认证失败 / 密钥格式 / 密码学校验 /
超时 / IO / 不支持）。

## 单元结构

```
nextpas.core.ssh.pas                 ← 门面：纯 re-export + 便捷函数（已校验无 `duplicate identifier`）
nextpas.core.ssh.base.pas            ← 协议常量、消息号、选项记录
nextpas.core.ssh.errors.pas          ← ESSHError + 错误分类
nextpas.core.ssh.intf.pas            ← 缝隙接口 `IDialer/ISshAgentDialer`（隔离 `net` 直连，仅 `io.intf+net.intf`）
nextpas.core.ssh.net.ffi.pas         ← 网络 FFI 外壳（唯一拉取 `nextpas.core.net` 的单元，同步 `ISshDialer/ISshAgentDialer` + 异步 `IAsyncTcpStream/SshAsyncTcpDial(RFC8305)` `inline` 零拷贝，`bytes.ops` 单源 `Move`，同层单向经单缝隙统一，`transport.async/session.async/proxyjump.async` 零直连）
nextpas.core.ssh.transport.core.pas  ← 传输核单源（`padding+Protect+Compress+Seq+Rekey` 纯内存，`transport(+.async)` 薄包装复用）
nextpas.core.ssh.rekey.pas           ← Rekey 策略（`TSshRekeyPolicy`，`TInstant` 单调时钟，同步/异步 transport 复用，零 `SysUtils` 直连）
nextpas.core.ssh.keepalive.pas       ← KeepAlive 策略（`TKeepAlivePolicy`，`TInstant` 单调时钟，同步预留/异步 `TAsyncLoop.ScheduleMethod`，零 `SysUtils` 直连）
nextpas.core.ssh.keepalive.scheduler.pas ← KeepAlive 调度器（`TKeepAliveScheduler`，`TAsyncLoop` 周期调度，复用于 TLS/QUIC，见 §8 已晋升）
nextpas.core.flow.window.pas         ← 通用流控窗口 `TFlowWindow`（L1 零堆 `inline`，`FLOW_WINDOW_LOW_WATER_DIVISOR=2`，见 CONTRACT §8；`ssh.window` 为薄兼容门面 re-export）
nextpas.core.ssh.window.pas          ← 通道窗口兼容门面（纯 re-export `flow.window.TFlowWindow` → `TChannelWindow`，`SSH_WINDOW_LOW_WATER_DIVISOR` alias，零堆 `inline`）
nextpas.core.ssh.buffer.pas          ← RFC 4251 wire 类型读写器（`Ensure/Need` 边界 + `SSH_MAX_RECEIVE_PACKET` 上限）
nextpas.core.ssh.cipher.pas          ← 包加密编解码器（AEAD / CTR+ETM，`TAesCtrStream` record值语义跨包 `keystream` 持久，`bytes.ops.MemXor` 批量 + `SecureZero`）
nextpas.core.ssh.transport.pas       ← 版本交换 + 二进制包协议状态机（阻塞，薄包装 `transport.core`）
nextpas.core.ssh.transport.async.pas ← 异步传输层（`TAsyncLoop+IAsyncTcpStream` 事件化，复用 `transport.core`，经 `ssh.net.ffi` 单缝隙复用 `IAsyncTcpStream`，零直连 `net.async.tcp/dial`，`inline` 零拷贝，`bytes.ops` 单源）
nextpas.core.ssh.kex.pas             ← KEXINIT 协商 + 密钥推导（`SHA256 KDF A-F`）
nextpas.core.ssh.kex.curve25519.pas  ← curve25519-sha256 客户端交换（X25519，`IsZeroBytes` 单源拒绝）
nextpas.core.ssh.kex.dhgroup14.pas   ← diffie-hellman-group14-sha256 客户端交换（回退，`TryBigIntModExp` 2048-bit MODP）
nextpas.core.ssh.hostkey.pas         ← 主机密钥解析 / 验签 / 指纹 / known_hosts（ed25519/rsa/ecdsa-p256，`bytes.ops/TConstantTime` 单源，`TSshKnownHosts` 单源 `inline` 零拷贝，薄别名已删除）
nextpas.core.ssh.rsa.pas             ← RSA PKCS#1 v1.5 签名/验签核（DigestInfo 单一来源）
nextpas.core.ssh.keys.pas            ← OpenSSH 私钥容器解析（ed25519 / ssh-rsa，未加密与 aes256-ctr+bcrypt 加密，依赖 crypto.blowfish / bcrypt_pbkdf）
nextpas.core.ssh.auth.pas            ← userauth 载荷构造/解析（probe `hasSig=false` + `PK_OK` / signed）
nextpas.core.ssh.compress.pas        ← 压缩：有状态 `zlib`/`zlib@openssh.com`（`ISshCompressor` 双 `z_stream`，`Z_SYNC_FLUSH`，1 MiB 防 bomb，经 `compress.zlib.ffi` 唯一入口）
nextpas.core.ssh.agent.pas           ← ssh-agent 协议客户端（Unix socket 长度前缀帧，List/Sign，经 `intf+net.ffi` 注入，已晋升独立模块）
nextpas.core.ssh.channel.pas         ← 连接协议：单通道引擎（exec / subsystem / `direct-tcpip` + `TChannelStream` 字节流）
nextpas.core.ssh.channel.async.pas   ← 异步通道（exec `TAsyncExecRunner` + `TAsyncSftpChannel` 复用窗口/低水位回补）
nextpas.core.ssh.session.pas         ← 会话编排（握手→认证→通道，`agent→privatekey→password` 回退，`Compress` 延迟/即时激活；<800 行，Builder/ProxyJump 已拆至独立子模块，`inline` 薄转发，零拷贝 `TChannelStream`）
nextpas.core.ssh.session.builder.pas ← Fluent Builder（`ISshClientBuilder` + 参数收集 + `SshClient` 入口，`inline` 转发，复用 `session.SshConnect` 单源）
nextpas.core.ssh.proxyjump.pas       ← 同步 ProxyJump（`TProxyJumpSession` 委托 + `direct-tcpip` + `SshSessionOpenDirectTcpip` 单源，`inline` 委托，`try-finally` 不泄漏）
nextpas.core.ssh.session.async.pas   ← 异步会话（经 `ssh.net.ffi` 单缝隙复用 `SshAsyncTcpDial(RFC8305)+IAsyncTcpStream` `inline` 零拷贝，`bytes.ops` 单源 `Move`，`try-finally` 释放不丢，零直连 `net.async.tcp/dial`；状态机复用 cipher/kex/hostkey/compress，`Compress` 同语义，`transport.async/session.async/proxyjump.async` 已单缝隙闭合）
nextpas.core.ssh.proxyjump.async.pas ← 异步 ProxyJump（`TAsyncChannelStream` 无轮询 + `Keeper` 保活 + `TryFlushQueued 5ms` 重试）
nextpas.core.ssh.sftp.base.pas       ← SFTP 共享基座（协议常量/属性载体/`SftpStatusName` 单源，`text.conv` 单源）
nextpas.core.ssh.sftp.intf.pas       ← SFTP 缝隙接口（`ISftpWire/ISshFileSystem`，隔离通道与文件语义）
nextpas.core.ssh.sftp.wire.pas       ← SFTP 通道线材（`TSshChannelWire` 委托 `bytes.framing.TWireBuffer` 单源，4B 重组、BytesEnsureCapacity 几何 + FOff 零拷贝 + 32KB/8KB 懒压实，`inline` 热路径）
nextpas.core.ssh.sftp.conn.pas       ← SFTP 连接状态机（`TSftpConnection` INIT/VERSION+RoundTrip，`PutAttrs/ReadAttrs` 单源）
nextpas.core.ssh.sftp.fs.pas         ← SFTP 文件系统实现（`TSshFileSystem` RealPath/Stat/ListDir/ReadFile/WriteFile 等；ReadFile `IBytesBuilder` 倍增、ListDir 容量倍增）
nextpas.core.ssh.sftp.pas            ← SFTP v3 门面（纯 re-export，常量/类型/接口与 `SftpOpen*` 入口，`inline` 转发，无逻辑）
nextpas.core.ssh.sftp.async.pas      ← SFTP v3 异步（`ISshAsyncFileSystem`，`TAsyncLoop+TAsyncSshTransport`，`PostEx` 投递，`SftpRoundTripAsync` + 窗口 + 4B 重组，复用 `sftp.base` 单源）
```

依赖方向：`base ← errors/buffer ← cipher/kex/hostkey/keys/auth ← transport/channel ← session ← 门面`；`base ← rekey/keepalive ← transport.core ← transport(+.async)` 单源。
对外依赖：`io.intf`（IReadWriteCloser 缝隙）、`crypto.*`、`hash`、`encoding.base64`、`time`/`text.conv`（替代 `SysUtils`）。
复用说明：`net.ffi` 为唯一 `nextpas.core.net` 拉取点（同步 `ISshDialer/ISshAgentDialer` + 异步 `IAsyncTcpStream/SshAsyncTcpDial(RFC8305)` `inline` 零拷贝，`bytes.ops` 单源 `Move`，`transport.async+session.async` 零直连，同层单向经单缝隙统一见设计规范 §3）；历史 `ssh.ffi` 空兼容单元已移除，四件套与落盘一致；`compress → compress.zlib.ffi` 唯一 `zlib` 入口（`grep` 已验证零直连 `zlib/paszlib`）。

## 测试与验证

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
make focused FOCUS=core/benchmarks/nextpas.core.ssh/bench_ssh_cipher
make focused FOCUS=core/benchmarks/nextpas.core.ssh/bench_ssh_proxyjump
```

核心验证手段是 **回环测试**：测试内实现一个最小 SSH 服务端（走同样的底层原语但独立的
服务端逻辑路径），与真实客户端实现在内存管道上完成完整握手 → 认证 → exec，
无需外部 sshd 即可证明协议栈各层协同正确。

真实服务器互操作由 **e2e_ssh_live** 承担（opt-in，不进默认 gate）：

```bash
cd core/tests/nextpas.core.ssh/e2e_ssh_live

# 模式一：本地 Docker 夹具（一次性密钥、随机端口、全封闭）
NEXTPAS_SSH_E2E_LOCAL=1 bash run_e2e.sh

# 模式二：直连真实 sshd
NEXTPAS_SSH_E2E_REMOTE=1 \
NEXTPAS_SSH_E2E_HOST=<host> NEXTPAS_SSH_E2E_USER=<user> \
NEXTPAS_SSH_E2E_KEYFILE=<未加密 ed25519 私钥> bash run_e2e.sh
```

场景：exec marker + 同会话二次 exec、远端 exit code 透传、stdout/stderr 分离、
known_hosts 不匹配预认证拒绝、同会话连续 16 次 exec 压力（通道复用回归放大器）、
SFTP 写→读→列目→stat 尺寸校验→删除回路。
`NEXTPAS_SSH_E2E_TRACE=1` 开启帧级追踪（库内 `SshChannelTrace` 钩子，默认 nil 零开销，
含 tx 方向帧头）；`NEXTPAS_SSH_E2E_DUMP=1` 额外转储全部明文包到 `/tmp/np_ssh_dump.txt`
（配合传输层 `SshTransportDump` 钩子）。
运行带 heaptrc 0 泄漏门禁；失败时编排器输出完整 sshd DEBUG3 日志。夹具注意事项：
sshd `StrictModes` 要求 authorized_keys 必须 root 属主且组/其他不可写；
Docker 发布端口每次启动会重排，TOFU 的 known_hosts 需按当次端口重新采集。

ed25519 签名实现另有 RFC 8032 向量与跨长度签验回归
（`core/tests/nextpas.core.crypto/test_ed25519`），并与 OpenSSL/cryptography
做过逐字节交叉比对。

## 性能基准（SSOT 见 `CONTRACT.md §6`，门禁与容差以 CONTRACT 为准）

**传输加解密**（`bench_ssh_cipher` 16KB·128MiB/方向，`-O3` 单线程，门禁 `50 MiB/s/方向` 详见 CONTRACT §6 SSOT 表；±10% 波动为环境噪声，此处仅摘要）：

| 算法 | protect | unprotect | 门禁 |
| --- | --- | --- | --- |
| chacha20-poly1305@openssh.com | ~258 MiB/s | ~253 MiB/s | 50 MiB/s/方向 |
| aes256-gcm@openssh.com | ~479 MiB/s | ~418 MiB/s | 50 MiB/s/方向 |
| aes128-ctr + hmac-sha2-256-etm | ~137 MiB/s | ~132 MiB/s | 50 MiB/s/方向 |

**RSA 签名**（2048-bit，`rsa-sha2-512`，PSKCS#1 v1.5，同一 host，32 次迭代均值，`test_ssh_session` 回环实测）：

| 路径 | 单次签名 | 备注 |
| --- | --- | --- |
| naive（`d` 直接模幂） | ~200ms | 兼容路径（哑 `p/q` 容器回退） |
| CRT（`dp/dq + Garner`） | ~38ms | `p/q/iqmp` 存在且 `p*q==n`/`q*iqmp%p==1` 时自动选用，≈5.2× 加速 |

回环 `LOOP_PUBKEY_RSA` 226ms → `LOOP_PUBKEY_RSA_CRT` 48ms 同样体现约 4.7× 增益。

**KEX**（同一 host，`test_ssh_kex` 独立交换重算）：

| 算法 | 交换耗时 | 备注 |
| --- | --- | --- |
| curve25519-sha256 | ~1ms | 默认首选，X25519 |
| diffie-hellman-group14-sha256 | ~50–70ms | 2048-bit MODP 回退，约 50× 于 curve25519 |

回环 `dh group14 fallback` 61–69ms 与独立 KEX 门 53ms 一致；可用性优先于性能。

**ssh-agent**（内存管道双链路回环，`test_ssh_agent` + `test_ssh_session`）：

| 路径 | 耗时 | 备注 |
| --- | --- | --- |
| `ListIdentities` (ed25519/rsa) | ~1ms | 11→12 |
| `Sign` ed25519 | ~1ms | `Ed25519Sign` |
| `Sign` rsa-sha2-512 (CRT) | ~40ms | `RsaSignPkcs1v15Crt` |
| `agent ed25519` 全栈回环 | ~5ms | probe→PK_OK→sign→exec |
| `agent rsa` 全栈回环 | ~45ms | 含 RSA 签名 |
| `agent multiple` | ~5ms | 2 身份枚举首命中 |

**压缩**（有状态 `zlib`/`zlib@openssh.com`，`test_ssh_compress` + `test_ssh_session` 回环）：

| 路径 | 耗时/大小 | 备注 |
| --- | --- | --- |
| `none`（默认） | 零开销 | 不创建 `z_stream`，直通 |
| `zlib@openssh.com` 延迟激活 | `USERAUTH_SUCCESS` 后首包起压缩 | 与 OpenSSH `delayed` 语义一致 |
| `zlib` 即时 | `NEWKEYS` 后立即压缩 | 兼容 `zlib` 协商 |
| 回环 `compress delayed` (password/pubkey/dh/agent) | 4–7ms / 6ms / 75ms | 19/19 全绿，含 dh 回退与 agent 组合 |
| 解压上限 | 1 MiB | `SSH_COMP_MAX_DECOMPRESSED` 防 bomb |
| 有状态增益 | 第 2 包 1 KiB `A*` 压缩后显著小于首包 | `Z_SYNC_FLUSH` 保留滑动窗口 |

**ProxyJump**（`MemPipe` 双跳, `bench_ssh_proxyjump` 50 次, `-O3`, `heaptrc 0`, `BeginThread` 同步/事件化双路径，`CONTRACT §6 SSOT`）：

| 路径 | p50 | p95 | avg | 备注 |
| --- | --- | --- | --- | --- |
| 单跳 `exec` | 5ms | 8ms | 5.1ms | `SshConnectOn` 直连 |
| 双跳 `exec via jump`（同步） | 431ms | 441ms | 432.7ms | `SshConnectViaJumpOn` (`direct-tcpip` + 二次 `KEX/USERAUTH` + `ServeJumpForward` 轮询 `50ms+5ms`) |
| 双跳 `exec via jump`（事件化） | ~550ms | — | — | `proxyjump.async:TAsyncChannelStream` 零轮询，`TAsyncLoop` 单线程事件化（`proxyjump_async 3/3 heaptrc 0`） |
| 额外开销 | ~426ms | — | 427.6ms | 二次 `KEX`(`curve25519 1ms`/`KDF A-F`)+`USERAUTH`+`CHANNEL_OPEN/CONFIRM` 为主（~415ms），轮询仅 ~5–10ms；事件化消除轮询抖动与空转，不改变加密握手成本，故未降至 ~30ms（`S20` 预期已修正），双路径均 `PASS <600ms` |

`test_ssh_proxyjump` 5/5 回环 (`exec` 569ms / `sftp via jump` 734ms 含 `INIT`) 与 `bench` 同构 `MemPipe`，`SFTP via jump` (`S2.OpenFileSystem → RealPath/Stat`) 复用 `sftp.pas` 同包；双跳额外开销主因二次 `KEX/USERAUTH/CHANNEL_OPEN`（~415ms），同步轮询仅贡献 ~5–10ms 抖动，事件化零轮询但保留同量级握手成本（实测同步 431ms→事件化 ~550ms 系调度与 `TAsyncLoop` 差异，±10% 环境噪声内），单跳零回归。

## 已知限制

- 加密私钥仅支持 `aes256-ctr` + `bcrypt`（KDF rounds≥1，salt 非空）；
  其他 cipher/kdf 组合（`aes128-ctr`、chacha 等加密容器）报 `sekUnsupported`。
- RSA 签名默认走 CRT 加速（`p/q/iqmp` 存在且校验通过时，`dp/dq` + Garner 合并，约 5× 于 naive）；非法/缺失 CRT 自动回退 naive，无声誉风险。
- KEX 已支持 `curve25519-sha256` 优先、`diffie-hellman-group14-sha256` 回退（2048-bit MODP，32 字节随机私钥，mpint 哈希输入）；curve25519 约 1ms，group14 约 50–70ms，默认首选前者。
- 压缩已支持 `zlib@openssh.com`（延迟，推荐）与 `zlib`（即时），默认 `Compress=False` 零开销；按需 `SshClient.Compress(True)` 或 `TSshConnectOptions.Compress:=True` 开启。`async` 路径同语义（`none` 零开销，延迟/即时激活一致）。
- AEAD 算法协商的 MAC 字段被忽略（chacha/gcm 内建认证），与 OpenSSH 行为一致；
  CTR 类必须搭配 ETM MAC。
- `async` 会话 `ISshAsyncSession.ExecAsync` 已完整可传参（`ExecAsync(Cmd,Cb,Ctx)`，`PExecPost.Context` 透传，`PostEx` 单线程，兼容无参调用）；`channel.async:TAsyncExecRunner`（`Open→Exec→Pump` 与窗口/超时一致，`TAsyncLoop` 单线程）；握手/认证/Exec 全链路事件化，`none` 零开销。`SFTP async`（`sftp.async:ISshAsyncFileSystem`）经 `TAsyncSftpChannel`（`PostEx` + `SftpRoundTripAsync` 单 pending + `WINDOW_LOW_WATER_DIVISOR` 回补 + `4B` 重组，`215ms` 首包）与同步同包构造，`test_ssh_sftp_async` 7/7 全绿；`SFTP via AsyncJump` 见上条；`e2e async` 双二进制门禁见上条。
- `ProxyJump` 已完整：同步（`direct-tcpip` + `TChannelStream` 隧道、`TProxyJumpSession` 委托、`SFTP via jump` 734ms, `bench_ssh_proxyjump` 同步 431ms/事件化 ~550ms vs 单跳 5ms，均 `PASS <600ms`）与异步（`proxyjump.async:TAsyncChannelStream` 无轮询 + `session.async:TAsyncProxyConnector/CreateWithKeeper` + `TProxyConn Keeper`，`proxyjump_async 3/3 ~550ms` 零轮询）；`SFTP via AsyncJump`（`SshAsyncSftpViaJump/On` 复用单 `direct-tcpip` 通道 + `Keeper` 保活 + `FQueuedPayload 5ms` 重试，`sftp_via_jump 4/4 ~2.5s` `heaptrc 0`，`sftp_async 7/7` 回归，事件化消除轮询空转与抖动（~5–10ms），保留二次 `KEX/USERAUTH` 主导成本，`S20` 的 ~30ms 预期已修正为握手主导、非轮询主导）。
- `Rekey/KeepAlive`（S24–S26）：`RekeyLimit 1GiB/1h`（`ConfigureRekey` 可配，`ShouldRekey` 按 `tstEncrypted` + 字节/时间阈值，`ApplyNewKeys` 后 `Reset` 不漂移序列号/窗口），`SendKeepAlive/AsyncSendKeepAlive` 为 `SSH_MSG_IGNORE` 空心跳（`none` 零开销），`async` 侧 `TAsyncLoop.ScheduleMethod` 周期调度 `KeepAliveIntervalMs`（`0` 禁用，`Close` 时 `CancelTimer`），`ProxyJump` 透传 `FTarget`；`TSshRekeyPolicy` 已抽取为独立 `nextpas.core.ssh.rekey` 模块（`base←rekey←transport(+.async)`，`TInstant` 单调时钟，消除双实现漂移，`IntToStr`/`GetTickCount64` 等经 `nextpas.core.text.conv`/`time`，零 `SysUtils` 直连）；`S26` 补齐回环边界（`transport 13/13` 含 `async Protect/Unprotect + none`，`session 23/23` 字节/时间边界 + `SendKeepAlive` 回环，`session.async 6/6` KeepAlive 100ms 触发后 Exec 仍成功，`HEAPTRC 0`）。
- `RTL 合规与可抽取性`：`nextpas.core.ssh` 全量经 `nextpas.core` 解决（`time`/`text.conv`/`exception`/`base.utils`），零 `SysUtils`/`Classes` 直连（`tests` 除外）；缺失能力反哺 `core`（如 `time.GetTickCount64`/`TInstant`）；已晋升：`Agent→agent.pas`、`KeepAliveScheduler→keepalive.scheduler.pas` 二项独立模块（见 `CONTRACT.md §8.2`），`KnownHosts` 薄别名 `knownhosts.pas` 已删除回归 `hostkey` 单源（`TSshKnownHosts` 单源 `inline` 零拷贝，`bytes.ops/TConstantTime` 单源，`47→46` 源）、`TFlowWindow` 奢华别名已删除（原 `TFlowWindow = TChannelWindow` 仅别名+重复常量，未提供跨协议独立不变量，未达 ≥2 协议复用实证，已删除；`TChannelWindow` 单源 `inline` 零堆，`bytes.ops` 单源，HTTP/2 用 `TH2FlowState`/QUIC 用 `TQuicFlowBudget`），跨协议复用就绪（`core.net` 隧道 / `TLS/QUIC` 心跳，`window` 暂为 ssh 内单源待 ≥2 协议实证），`rekey/keepalive` 为跨协议示范单源、`window` 为 ssh 内示范单源。
- 对真实 OpenSSH 服务器的互操作已由 `e2e_ssh_live` 验证：同步 `test_ssh_e2e` 本地 Docker Alpine 9.7 与远程 Debian OpenSSH 10.0p2 均 8 场景通过（SFTP 回路、RSA/CRT/ECDSA 与加密私钥）；异步 `test_ssh_e2e_async` 单跳 4 场景 + `via jump` 单容器复跑同门禁，双容器 `AsyncJump`（`target` 内网 + `jump` 映射、双 `known_hosts`、`NEXTPAS_SSH_E2E_ASYNC_JUMP=1`）为 `opt-in` 额外门，`run_e2e.sh` 统一 `heaptrc 0` 泄漏检查与 `--network` 清理。

# nextpas.core.ssh

SSH-2 客户端协议栈（对标 libssh2 的能力面），纯 Pascal 实现，无任何 C 库依赖。
传输层复用 `nextpas.core.net`（阻塞 `ITcpStream`），密码学原语全部来自
`nextpas.core.crypto` / `nextpas.core.hash`。

## 定位

- L2 协议模块（与 `tls` 同层：面向字节流的协议实现）。
- 第一期只做客户端（libssh2 本身也是客户端为主）；服务端不在本模块范围。
- 阻塞同步 API 优先（贴合 `net.TcpConnect` 的使用模型）；async reactor 适配是后续 slice。

## 算法支持（现代集合）

| 用途 | 支持 |
| --- | --- |
| KEX | `curve25519-sha256`、`curve25519-sha256@libssh.org`、`diffie-hellman-group14-sha256`（回退） |
| 主机密钥 | `ssh-ed25519`、`ecdsa-sha2-nistp256`、`rsa-sha2-512`、`rsa-sha2-256` |
| 加密 | `chacha20-poly1305@openssh.com`、`aes256-gcm@openssh.com`、`aes128-gcm@openssh.com`、`aes256-ctr`、`aes192-ctr`、`aes128-ctr` |
| MAC | `hmac-sha2-256-etm@openssh.com`、`hmac-sha2-512-etm@openssh.com`（仅 ETM；CTR 类算法必需） |
| 压缩 | `none` |
| 认证 | `password`、`publickey`（openssh-key-v1 容器：ssh-ed25519、ssh-rsa；支持未加密与 `aes256-ctr`+`bcrypt` 加密；RSA 走 `rsa-sha2-512` 签名）、`ssh-agent`（Unix socket 11→12 枚举 + 13→14 代签名，支持 ed25519 / rsa-sha2-512/256，回退 `privatekey→password`） |

明确不支持并会在协商阶段给出清晰错误的历史包袱：
SHA-1 KEX、DH group1/14、非 ETM MAC、zlib 压缩、ssh-dss。

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
nextpas.core.ssh.pas                 ← 门面：纯 re-export + 便捷函数
nextpas.core.ssh.base.pas            ← 协议常量、消息号、选项记录
nextpas.core.ssh.errors.pas          ← ESSHError + 错误分类
nextpas.core.ssh.buffer.pas          ← RFC 4251 wire 类型读写器
nextpas.core.ssh.cipher.pas          ← 包加密编解码器（AEAD / CTR+ETM）
nextpas.core.ssh.transport.pas       ← 版本交换 + 二进制包协议状态机
nextpas.core.ssh.kex.pas             ← KEXINIT 协商 + 密钥推导
nextpas.core.ssh.kex.curve25519.pas  ← curve25519-sha256 客户端交换
nextpas.core.ssh.kex.dhgroup14.pas   ← diffie-hellman-group14-sha256 客户端交换（回退）
nextpas.core.ssh.hostkey.pas         ← 主机密钥解析 / 验签 / 指纹 / known_hosts（ed25519/rsa/ecdsa-p256）
nextpas.core.ssh.rsa.pas             ← RSA PKCS#1 v1.5 签名/验签核（DigestInfo 单一来源）
nextpas.core.crypto.blowfish.pas     ← Blowfish 分组密码（bcrypt 底座，OpenBSD 语义）
nextpas.core.crypto.bcrypt_pbkdf.pas ← bcrypt_pbkdf 密钥派生（OpenSSH 加密私钥 KDF）
nextpas.core.ssh.keys.pas            ← OpenSSH 私钥容器解析（ed25519 / ssh-rsa，未加密与 aes256-ctr+bcrypt 加密）
nextpas.core.ssh.auth.pas            ← userauth 载荷构造/解析（probe `hasSig=false` + `PK_OK` / signed）
nextpas.core.ssh.agent.pas           ← ssh-agent 协议客户端（Unix socket 长度前缀帧，List/Sign）
nextpas.core.ssh.channel.pas         ← 连接协议：单通道引擎（exec / subsystem）
nextpas.core.ssh.session.pas         ← 会话编排（握手→认证→通道，`agent→privatekey→password` 回退）
nextpas.core.ssh.sftp.pas            ← SFTP v3 客户端（ISshFileSystem 门面）
```

依赖方向：`base ← errors/buffer ← cipher/kex/hostkey/keys/auth ← transport/channel ← session ← 门面`。
对外依赖：`io.intf`（IReadWriteCloser 缝隙）、`crypto.*`、`hash`、`encoding.base64`。

## 测试与验证

```bash
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_buffer
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_cipher
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_kex
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_hostkey
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_keys
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_transport
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_session
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_sftp
make focused FOCUS=core/tests/nextpas.core.ssh/test_ssh_agent
make focused FOCUS=core/tests/nextpas.core.ssh/bench_ssh_cipher
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

## 性能基准

**传输加解密**（bench_ssh_cipher，16KB 包，128 MiB/方向，`-O3`，x86_64 单线程，门禁 50 MiB/s/方向）：

| 算法 | protect | unprotect |
| --- | --- | --- |
| chacha20-poly1305@openssh.com | ~258 MiB/s | ~253 MiB/s |
| aes256-gcm@openssh.com | ~479 MiB/s | ~418 MiB/s |
| aes128-ctr + hmac-sha2-256-etm | ~137 MiB/s | ~132 MiB/s |

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

## 已知限制

- 加密私钥仅支持 `aes256-ctr` + `bcrypt`（KDF rounds≥1，salt 非空）；
  其他 cipher/kdf 组合（`aes128-ctr`、chacha 等加密容器）报 `sekUnsupported`。
- RSA 签名默认走 CRT 加速（`p/q/iqmp` 存在且校验通过时，`dp/dq` + Garner 合并，约 5× 于 naive）；非法/缺失 CRT 自动回退 naive，无声誉风险。
- KEX 已支持 `curve25519-sha256` 优先、`diffie-hellman-group14-sha256` 回退（2048-bit MODP，32 字节随机私钥，mpint 哈希输入）；curve25519 约 1ms，group14 约 50–70ms，默认首选前者。
- 无 zlib 压缩（见 goal-tree 后续 slice 表）；ssh-agent 已落地（`agent` 单元，Unix socket，probe→PK_OK→sign 回退链）。
- AEAD 算法协商的 MAC 字段被忽略（chacha/gcm 内建认证），与 OpenSSH 行为一致；
  CTR 类必须搭配 ETM MAC。
- 对真实 OpenSSH 服务器的互操作已由 e2e_ssh_live 验证（本地 Docker Alpine 9.7 与
  远程 Debian OpenSSH 10.0p2 均 8 场景通过，含 SFTP 回路、RSA/CRT/ECDSA 认证与加密私钥认证）；
  该门为 opt-in，不进默认 gate。

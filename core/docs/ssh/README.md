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
| KEX | `curve25519-sha256`、`curve25519-sha256@libssh.org` |
| 主机密钥 | `ssh-ed25519`、`rsa-sha2-512`、`rsa-sha2-256` |
| 加密 | `chacha20-poly1305@openssh.com`、`aes256-gcm@openssh.com`、`aes128-gcm@openssh.com`、`aes256-ctr`、`aes192-ctr`、`aes128-ctr` |
| MAC | `hmac-sha2-256-etm@openssh.com`、`hmac-sha2-512-etm@openssh.com`（仅 ETM；CTR 类算法必需） |
| 压缩 | `none` |
| 认证 | `password`、`publickey`（OpenSSH 私钥容器，未加密） |

明确不支持并会在协商阶段给出清晰错误的历史包袱：
SHA-1 KEX、DH group1/14、非 ETM MAC、zlib 压缩、ECDSA 主机密钥（枚举已预留）。

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
nextpas.core.ssh.hostkey.pas         ← 主机密钥解析 / 验签 / 指纹 / known_hosts
nextpas.core.ssh.keys.pas            ← OpenSSH 私钥容器解析
nextpas.core.ssh.auth.pas            ← userauth 载荷构造/解析
nextpas.core.ssh.channel.pas         ← 连接协议：通道复用与 exec
nextpas.core.ssh.session.pas         ← 会话编排（握手→认证→通道）
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
make focused FOCUS=core/tests/nextpas.core.ssh/bench_ssh_cipher
```

核心验证手段是 **回环测试**：测试内实现一个最小 SSH 服务端（走同样的底层原语但独立的
服务端逻辑路径），与真实客户端实现在内存管道上完成完整握手 → 认证 → exec，
无需外部 sshd 即可证明协议栈各层协同正确。对外的 live-sshd 冒烟测试为 opt-in
（环境变量门控），不进入默认 gate。

ed25519 签名实现另有 RFC 8032 向量与跨长度签验回归
（`core/tests/nextpas.core.crypto/test_ed25519`），并与 OpenSSL/cryptography
做过逐字节交叉比对。

## 性能基准（bench_ssh_cipher，16KB 包，128 MiB/方向）

x86_64 宿主、`-O3`、单线程实测（数值随机器浮动，门禁下限为单方向 50 MiB/s）：

| 算法 | protect | unprotect |
| --- | --- | --- |
| chacha20-poly1305@openssh.com | ~258 MiB/s | ~253 MiB/s |
| aes256-gcm@openssh.com | ~479 MiB/s | ~418 MiB/s |
| aes128-ctr + hmac-sha2-256-etm | ~137 MiB/s | ~132 MiB/s |

## 已知限制

- 私钥仅支持 **未加密** OpenSSH 容器（ed25519）；加密容器
  （bcrypt_pbkdf + aes256-ctr）与 RSA 私钥签名在后续 slice。
- KEX 仅 `curve25519-sha256`；DH group14-sha256 回退推迟。
- 无 zlib 压缩、无 ssh-agent、无 SFTP（见 goal-tree 后续 slice 表）。
- AEAD 算法协商的 MAC 字段被忽略（chacha/gcm 内建认证），与 OpenSSH 行为一致；
  CTR 类必须搭配 ETM MAC。
- 对真实 OpenSSH 服务器的互操作属后续 slice（live-sshd 冒烟），当前结论等级为
  focused-runtime 回环证据。

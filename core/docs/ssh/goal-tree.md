# nextpas.core.ssh Goal Tree

分阶段目标树。每个阶段以 focused gate 证据收口后才进入下一阶段。

## S0 — 模块立项（当前已完成）

- [x] lane：`.worktrees/core-ssh` + `codex/core-ssh`
- [x] `docs/ssh/README.md` 定位 / 算法表 / 单元结构
- [x] `core-module-registry.md` 登记 `ssh` 条目
- [x] 底座资产盘点：x25519 / ed25519 / rsa 验签路径 / aes-gcm / chacha20poly1305(+ChaCha20Block) /
      hmac-sha2 / sha256 全部可用；AES-CTR 与 bcrypt_pbkdf 缺失，前者在本模块内实现，后者推迟

## S1 — 基础层（纯内存，可完全测试）

- [x] `base`：协议常量、消息号、选项记录
- [x] `errors`：ESSHError + TSshErrorKind
- [x] `buffer`：TsshWriter/TsshReader（byte/bool/uint32/string/mpint/name-list）
- [x] `test_ssh_buffer`：wire 往返 + RFC 4251 mpint 边界向量 + 越界错误

## S2 — 包加密层

- [x] `cipher`：ISshPacketSender/Receiver 抽象 + none/chacha20-poly1305/aes-gcm/aes-ctr+etm 实现
      （CTR keystream 后端分派 AES-NI → ct64 → 朴素；keystream 偏移跨调用持久）
- [x] `test_ssh_cipher`：RFC 8439 §2.3.2 块函数向量映射校验、三族编解码往返、篡改检测、
      RFC 4231 HMAC 向量

## S3 — 握手层

- [x] `kex`：KEXINIT 解析与 first-match 协商、SHA256 KDF（A-F 扩展链）
- [x] `kex.curve25519`：客户端 ECDH 交换 + H 计算（draft-ietf-curdle-ssh-curves §4 输入序）
- [x] `hostkey`：blob 解析、ed25519/rsa-sha2 验签、SHA256 指纹、known_hosts（明文通配 + |1| 散列）
- [x] `keys`：openssh-key-v1 未加密容器解析（ed25519）
- [x] `auth`：userauth 载荷构造（RFC 4252 §7 signed-data：string(session_id) 带长度前缀）
- [x] `transport`：版本交换、包帧、序列号（跨 NEWKEYS 连续）、NEWKEYS 切换
- [x] `test_ssh_kex` / `test_ssh_hostkey` / `test_ssh_keys` / `test_ssh_transport`

## S4 — 会话层

- [x] `channel`：通道打开/数据/窗口/EOF/CLOSE、exec 请求与 exit-status
- [x] `session`：connect → KEX → hostkey 校验 → 认证 → exec 编排；门面 + fluent builder
- [x] `test_ssh_session`：**全栈回环**——测试内最小 SSH 服务端（独立服务端逻辑路径）与客户端
      在内存管道上完成 版本交换→KEX→认证→exec→关闭，断言 stdout/exit code；
      覆盖 password/publickey 正路径与 认证失败/hostkey 拒绝/known_hosts 命中
- [x] bench：cipher protect/unprotect 吞吐（16KB 包，chacha/gcm/ctr+etm）
      实测 chacha ~255 MiB/s、gcm ~450 MiB/s、ctr+etm ~135 MiB/s（门禁下限 50 MiB/s/方向）

## S5 — 收尾

- [x] examples/demo_ssh_exec（argv 驱动，opt-in 手工运行；无参数打印用法并以 2 退出）
- [x] KNOWN_LIMITS 固化到 README（已知限制 + 性能基准表）
- [x] Ready 报告：focused gates 全绿证据 + hygiene + git diff --check

## 已识别的后续 slice（不在当前阶段）

| 项 | 说明 |
| --- | --- |
| bcrypt_pbkdf + aes256-ctr 私钥解密 | OpenSSH 加密私钥容器（需要 blowfish 核心） |
| RSA 私钥签名认证 | PKCS#1 容器解析 + bigint 签名路径 |
| ecdsa-sha2-nistp256 主机密钥 | 枚举已预留，需 mpint(r,s)↔DER 转换 |
| DH group14-sha256 KEX | bigint modpow 可用，作为 curve25519 不可用时的回退 |
| ssh-agent | Unix socket 协议客户端 |
| SFTP v3 | 子系统通道之上的文件操作面 |
| zlib 压缩方法 | compress.deflate 可复用 |
| async reactor 适配 | net.async.dial + 非阻塞读事件化 |
| live-sshd 冒烟 | 环境变量门控的真实互操作测试 |

## 真实性等级声明

当前所有结论以 **focused-runtime**（回环测试在 Linux x86_64 host 上真实执行）为准；
对真实 OpenSSH 服务器的互操作性属于后续 slice，未验证前不声明。

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

## S6 — 真实服务器互操作（已完成）

- [x] `e2e_ssh_live`：opt-in 编排器（`run_e2e.sh`，环境变量门控），两种模式：
      - **local docker 夹具**：alpine + openssh-server 容器，一次性 host/client 密钥、
        随机端口、TOFU 采集 known_hosts，全封闭可重复
      - **remote 直连**：真实 sshd（已验证 Debian OpenSSH 10.0p2 与 Alpine 9.7）
- [x] 场景：exec marker + 同会话二次 exec / 远端 exit code 透传 / stdout-stderr 分离 /
      known_hosts 不匹配预认证拒绝；heaptrc 0 泄漏门禁与 common.mk 同语义
- [x] 互操作中发现并修复的真实缺陷（这正是 live 测试的价值）：
      - AEAD/EtM 帧的 padding 对齐：OpenSSH 对 aadlen 模式要求 packlen（不含 4 字节
        长度字段本身）按块对齐，`ISshPacketSender.AadLen` 表达该语义
        （chacha/gcm/ctr-etm = 4，none = 0）
      - chacha20-poly1305 raw-MAC 帧（poly1305 直接作用于 encLen‖密文，无 RFC 8439 pad16）
      - ed25519 `EdBasePointMul` 有符号 radix-16 末位进位丢失（约 7% 密钥公钥错误，
        触发条件 SHA-512(seed) 末字节高 nibble=7 且低 nibble≥8）；回归向量进入 test_ed25519

## S7 — landing replay 集成收口（已完成）

lane 基于旧基建开发，replay 到当前 main（net.async/io.reactor 新栈）时 e2e 暴露
一个回环测试覆盖不到的潜伏缺陷——这正是 opt-in live 门与 replay 纪律的价值：

- [x] **通道号语义错位**（真实缺陷，约 10% 概率空 stdout）：服务端→客户端帧的
      recipient 字段是我方通道号（恒 LOCAL_CHANNEL_ID=0），HandleData 却与
      FRemoteId（服务端自编号）比对；OpenSSH 复用"最低空闲号"时侥幸成立，
      服务端未及时 GC 旧通道而分配非 0 号时该 exec 全部 DATA 被静默丢弃。
      修复：HandleData 改按 LOCAL_CHANNEL_ID 校验；PumpMessage 中央过滤
      recipient-first 族（92–100）陈旧通道帧，杜绝跨 exec 迟滞 CLOSE/DATA
      误触发状态机。修复验证：23 次非 0 号分配全部正确处理，10 轮全绿
- [x] e2e 增强：同会话连续 16 次 exec 压力场景（回归放大器）、失败输出完整
      sshd 日志、`SshChannelTrace` 可选帧级追踪钩子、编排器 fail-open 修复
      （docker 分支 `exit $?` 曾取到 tail 的退出码）
- [x] bench_ssh_cipher 按 common.mk phase-2 默认开的新规显式 `HEAPTRC_GATE=0`
      （基准不链 heaptrc 防吞吐失真；泄漏纪律由其余门 + e2e 覆盖）

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

## 真实性等级声明

核心结论以 **focused-runtime**（回环测试在 Linux x86_64 host 上真实执行）为基础；
真实服务器互操作已由 **S6 live e2e + S7 replay 集成收口** 补齐：本地 Docker 夹具
（Alpine OpenSSH 9.7）与远程 Debian OpenSSH 10.0p2 均 5 场景通过（含通道复用压力），
heaptrc 0 泄漏。e2e 为 opt-in 门控，不进默认 gate。

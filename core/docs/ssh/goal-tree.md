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

## S8 — SFTP v3 文件操作面（已完成）

子系统通道之上的文件操作客户端，draft-ietf-secsh-filexfer-02 子集：

- [x] `sftp`：INIT 握手、open/read/write/close/opendir/readdir/
      realpath/stat/lstat/remove/mkdir/rmdir、TSftpAttrs 编解码、
      TSshFileSystem 实现 ISshFileSystem；三个入口
      SftpOpenOnChannel / SftpOpenOnWire / SftpOpenOnTransport
- [x] 缝隙设计：ISftpWire 抽象帧收发，TSshChannelWire 适配通道层
      （SFTP 帧长度前缀流重组）——密闭门测试注入假 wire 即可覆盖全部
      请求应答路径，无需真实 SSH 栈；`test_ssh_sftp` 12 用例 heaptrc 全零
- [x] `channel` 从一次性 exec 重构为单通道引擎 TSshChannel（exec 与 sftp
      共用），重构后 e2e 压测挖出四项真实缺陷并全部修复：
      - **SendData 缺 RFC 4254 §6.1 string 长度前缀**（根因级）：CHANNEL_DATA
        的 data 是 string，此前发裸字节导致对端把我们的首 4 字节当串头吞掉——
        SFTP INIT 首包即毁（internal-sftp exit 11）；exec 不发数据故回环全绿，
        暴露了回环测试的覆盖盲区，只有 live e2e 能抓到
      - 接收侧窗口基准错位：回补信用应按我方 CHANNEL_OPEN 声明的初始窗口
        记账（消费过半回补），此前误用对端声明的窗口做基准，小流量未暴露
      - 本地通道号进程级单调递增（GNextLocalChannelId 替代恒 0 常量），
        PumpFiltered 统一过滤旧通道迟滞帧并就地入账发送侧 WINDOW_ADJUST；
        同会话连续 exec 不再依赖服务端 GC 时序
      - SshRunExec 未初始化函数结果：FPC 结果缓冲被调用方循环复用时残留上轮
        TBytes 指针，stdout 成倍累积（twotwo 现象的第二层根因）；
        `Result := Default(TSshExecResult)` 修复
- [x] e2e 新增 SFTP 场景（internal-sftp 写→读回→列目→stat→删除回路，
      "ok: write+read N bytes"）与诊断双钩子（NEXTPAS_SSH_E2E_TRACE 帧级
      追踪 / NEXTPAS_SSH_E2E_DUMP 明文包转储）；假服务端 s→c 帧 recipient
      合规化（改用客户端声明的通道号），test_ssh_session 回归 5/5

## S9 — RSA 私钥签名认证（已完成）

客户端 publickey 认证扩展到 ssh-rsa（RFC 8332），补齐企业环境最常用密钥类型：

- [x] `rsa`：PKCS#1 v1.5 签名/验签核独立成单元——DigestInfo 前缀、EM 编码、
      常数时间比较单一来源；hostkey 验签与客户端签名共享同一套逻辑
- [x] **修复潜伏缺陷**：DIGEST_INFO_SHA512 末字节是摘要长度 $20（应为
      $40，SHA-512 摘要 64 字节）——DER 自相矛盾，任何真实 rsa-sha2-512
      验签恒败。既有测试的 e=1 数学构造只覆盖 EM 比对且仅测 SHA-256，
      坏常量从未被执行；openssl 黄金向量 KAT 双向锁死后此类漂移无法再溜进
- [x] `keys`：openssh-key-v1 容器解析扩展 ssh-rsa 私有段
      （字段序 n,e,d,iqmp,p,q）；TSshPrivateKey 增加 RsaN/RsaE/RsaD
- [x] `auth`/`session`：SshBuildRsaSigBlob（RFC 8332 §3 blob）；
      AuthenticateWithPrivateKeyData 按 Kind 分发，RSA 选 rsa-sha2-512
      单次尝试（与 rsa-sha2-256 同版本引入，无需降级）
- [x] 测试三线闭环：openssl 产出黄金向量进 tests/shared/ssh_rsa_kat
      （hostkey 门验签 KAT + keys 门签名逐字节 KAT，防两处常量漂移）；
      test_ssh_session 假服务端 RSA 真实验签回环；e2e 第七场景
      ssh-keygen 现场生成 RSA 密钥对真实 sshd 认证 exec

## S10 — 加密私钥解密（已完成）

OpenSSH 加密私钥容器（bcrypt_pbkdf + AES-256-CTR）落地，闭环 ssh-keygen 生成→解密→签名→真实 sshd 认证：

- [x] `blowfish`/`bcrypt_pbkdf`：OpenBSD blowfish.c / bcrypt_pbkdf.c 权威语义——
      InitState pi 常量程序化提取、Stream2Word 循环大端、ExpandState 流归属（初始 P XOR 用 key 流、链式回填 XOR 用 data 流）、
      EncryptBlock 教科书 16 轮+swap+XR^P[16]/XL^P[17]；零密钥向量 4EF99745 6198DD78 已验证；bcrypt 64 轮扩张与 64 轮魔串加密、半块字节序 out[4i+3]=字>>24
- [x] `bcrypt_pbkdf`：python-bcrypt 5.0.0 五向量交叉验证（48/16、48/64、32/100、72/5、16/1），
      常量进 tests/shared/ssh_bcrypt_kat
- [x] `cipher`：TAesCtrStream 复用暴露 SshAesCtrCrypt（AES-256-CTR，IV 作初始计数器）
- [x] `keys`：openssh-key-v1 加密容器解析（cipher aes256-ctr / kdf bcrypt / kdfoptions salt+rounds）→
      bcrypt_pbkdf(pass, salt, 48, rounds) → key(32)+iv(16) → AES-256-CTR 解密 priv section → 复用 checkint/ed25519/rsa 解析路径；
      口令 API：SshLoadPrivateKey 增加 Passphrase 参数、TSshConnectOptions.PrivateKeyPassphrase、ISshSession.AuthenticateWithPrivateKeyData 过载、SshClient.PrivateKeyPassphrase builder
- [x] 测试四线闭环：test_ssh_keys 五向量 KAT + 加密 ed25519/rsa 容器自构造往返（含错误口令 checkint 拒绝与 CTR 往返）；
      test_ssh_session 假服务端加密密钥认证回环；e2e 第八场景 ssh-keygen -t ed25519 -N 口令 生成真实加密密钥对 Docker/remote sshd 认证
- [x] 文档收口：README 已知限制移除加密容器行，goal-tree 后续 slice 表移除该项

## S11 — RSA 签名 CRT 加速（已完成）

客户端 RSA 私钥容器自带的 `p/q/iqmp`（`q^{-1} mod p`）不再闲置，签名走
中国剩余定理，2048-bit 模幂拆为两路 1024-bit：

- [x] `keys`：`TSshPrivateKey` 增 `RsaP/RsaQ/RsaIqmp/RsaHasCrt`，`IsCrtValid`
      校验 `p*q==n` 与 `q*iqmp ≡ 1 (mod p)`（`TryBigIntMul/ModMul`），非法
      容器落 `HasCrt=False` 触发 naive 回退，不误伤旧测试哑数据
- [x] `rsa`：`RsaSignPkcs1v15Crt`——`dp=D mod (p-1)`/`dq` 派生 + `EM^dp mod p`
      /`EM^dq mod q` + `diff=(m1-m2) mod p` + `h=iqmp*diff mod p` + `sig=m2+h*q`
     （Garner 合并，复用 `TryBigInt*FromUnsignedBytes`，全链条失败返回 False）
- [x] `session`：`AuthenticateWithPrivateKeyData` 优先走 CRT，失败回退 naive；
      哑数据/非法 CRT 容器无静默错签
- [x] `ssh_rsa_kat`：第二套 2048-bit 向量 `CrtKatN/P/Q/Iqmp/D`（Python cryptography
      现场生成，`q*iqmp % p == 1` 已校验），`ssh_bcrypt_kat` 复用不变
- [x] 测试五线闭环：`test_ssh_keys` CRT 等价性（sha256/sha512 逐字节 + 验签）、
      `HasCrt` 判定、哑参数错签隔离、bench（32 次 `rsa-sha512` naive 6.3s→crt 1.2s ≈5.2x）、
      加密 RSA+CRT 容器解密后等价性；`test_ssh_session` 新增 `LOOP_PUBKEY_RSA_CRT`
      真实验签回环（48ms vs naive 226ms ≈4.7x）
- [x] 文档/性能收口见下

## S12 — ecdsa-sha2-nistp256 主机密钥（已完成）

OpenSSH 默认主机密钥三件套补齐最后一块（`ssh-ed25519` / `rsa-sha2-*` / `ecdsa-sha2-nistp256`）：

- [x] `hostkey`：`TSshHostKeyInfo` 增 `EcdsaP256X/Y`，`SshParseHostKey` 解析
      `ecdsa-sha2-nistp256` blob（`string("nistp256")` + `string(04||X||Y)`，65 字节
      未压缩点，`TryValidateP256Point` 落 `sekKeyFormat`），`SshEcdsaP256PubToBlob` 供测试
      与指纹复用；`SshVerifyHostSignature` 增 `hkEcdsaP256` 分支——`mpint(r)+mpint(s)`→
      DER(`TASN1Writer`)→`TryECDSAVerifyP256SHA256`（SHA256(H)，`crypto.ecdsa` 复用，
      常量时间比较在底层）
- [x] `kex`：`SSH_OFFER_HOSTKEY_ALGS` 增 `ecdsa-sha2-nistp256`，优先级
      `ed25519 > ecdsa > rsa-sha2-512 > rsa-sha2-256`（与 OpenSSH 默认一致）
- [x] 测试三线闭环：`test_ssh_hostkey` 新增 `ecdsa blob parse`、`ecdsa verify 正/负`、
      `ecdsa known_hosts 明文/散列`（12/12）；`test_ssh_kex` 新增 `ecdsa negotiation`
      优先级断言（9/9）；`test_ssh_keys`/`session`/`kex` 既有 8 门回归全绿
- [x] e2e：Docker 夹具可选 `host_ecdsa`（`ssh-keygen -t ecdsa -b 256`）与 TOFU 采集；
      真实 Debian 10.0p2 的 ecdsa 主机密钥已在 `ssh-keyscan -t ecdsa` 路径验证

## S13 — diffie-hellman-group14-sha256 回退 KEX（已完成）

`curve25519-sha256` 不可用时的标准回退——RFC 3526 2048-bit MODP Group 14
与 RFC 4253 §8 交换散列（`mpint(e/f/K)` 版）：

- [x] `kex.dhgroup14`：`SshDHGroup14Prime/Generator`（256 字节 RFC3526 素数
      + `g=2`）、`SshBuildDHGroup14HashInput`（Vc/Vs/Ic/Is/Ks/e/f/K 均为
      规范 mpint）、`TSshKexDHGroup14`（32 字节随机私钥、mpint 载荷、
      `1 < f < p` 与全零共享拒绝、`SHA256(H)`）
- [x] `kex`：`SSH_OFFER_KEX_ALGS` 增 `diffie-hellman-group14-sha256`，优先级
      `curve25519-sha256 > curve25519-sha256@libssh.org > group14`（与
      OpenSSH 一致）；AEAD/ETM 既有逻辑不变
- [x] `session`：`DoHandshake` 按 `LNeg.KexAlg` 分派——`group14` 走
      `TSshKexDHGroup14`，其余走 `TSshKexCurve25519`；同一 `DeriveAndApplyNewKeys`
      链条，无重复 KDF
- [x] 测试四线闭环：`test_ssh_kex` 新增 `dh fallback negotiation` 与
      `dh group14 client exchange`（独立 `e^srvPriv` 重算 K 与 `SHA256` 重算 H，
      53ms vs curve25519 1ms，2048-bit 模幂代价明确）；`test_ssh_session`
      假服务端扩展 `ForceDH` 分支（独立 DH 密钥对与 `SshBuildDHGroup14HashInput`），
      新增 `dh fallback loopback (password/publickey)`（61ms/69ms，10/10）
- [x] 性能说明：DH 2048-bit 单次交换约 50–70ms（同 host），约为 curve25519 的
      50×；作为回退可用性优先于性能，默认仍首选 curve25519

## S14 — ssh-agent 协议客户端（已完成）

Unix socket 上的 OpenSSH agent 转发——枚举身份 + 代签名，无私钥落地：

- [x] `agent`：`TSshAgentClient`（`UnixConnect`/`IReadWriteCloser` 双注入，4 字节 BE 长度帧，`ReadExact/WriteExact` 循环，`ListIdentities` 11→12 / `Sign` 13→14，`SshAgentKeyBlobToAlgName/Flags` 映射 `ssh-rsa→rsa-sha2-512`），`SshAgentConnect/FromEnv`（`SSH_AUTH_SOCK`）
- [x] `session`：`ISshSession.AuthenticateWithAgent[-On]` + `TSshClientBuilder.AgentSocketPath`，`RunAuthentication` 走 `agent→privatekey→password` 回退（`sekAuth/sekIO` 失败不阻断下一方式），`AuthenticateWithAgentClient`逐身份 `probe(PK_OK)→Sign(flags)` 循环（`rsa-sha2-512/256` 按 blob 类型选 flag）
- [x] 测试四线闭环：`test_ssh_agent` 内存管道 5 用例（`list/sign ed25519/rsa-sha2-512/multiple/unknown`，54ms 内）；`test_ssh_session` 假 agent + 假服务端双管道回环 5 用例（`ed25519/rsa/multiple/no-identities/dh-fallback`，15/15，`Probe→PK_OK→SIGN→SUCCESS` 全路径，真实验签）；`test_ssh_kex/hostkey/keys` 等 8 门回归全绿
- [x] 服务端探针修复：`ServeApp` 的 `publickey` 分支按 `hasSig` 分流——probe 无 sig 字段，命中回 `SSH_MSG_USERAUTH_PK_OK` 否则 `FAILURE`；签名请求才走 `Ed25519Verify/RsaVerifyPkcs1v15`，与真实 OpenSSH 时序一致

## S15 — zlib 压缩（zlib@openssh.com 延迟 / zlib 即时）（已完成）

RFC 4253 §6.2 / OpenSSH `zlib@openssh.com` 延迟语义的有状态流式压缩——
`none` 零开销，协商命中后再按时机激活：

- [x] `compress`：`ISshCompressor` 有状态封装（每方向 `z_stream`，`deflateInit/inflateInit`，
      每包 `deflate(Z_SYNC_FLUSH)` 动态扩容保留滑动窗口，`inflate(Z_SYNC_FLUSH)` 1 MiB 上限
      防 bomb，`CreateSshZlibCompressor` 单对象双流，复用 `nextpas.core.compress.base` 的 `LevelToZlib`）
- [x] `kex`：`SSH_OFFER_COMP_ALGS=('none')` + `SSH_OFFER_COMP_ALGS_COMPRESS=('zlib@openssh.com','zlib','none')`，
      `SshBuildKexInitPayloadEx(ACookie,ACompress)` / `SshNegotiateEx(APeer,ACompress)`，
      `ACompress=False` 时保持纯 `none` 零开销；`SshNegotiate` 重定向到 `Ex(...,False)` 兼容既有调用
- [x] `transport`：`FCompressor/FDecompressor/FCompressEnabled/FNegCompCs/Sc`，
      `SetNegotiatedCompression`（immediate `zlib` 立即 `EnableCompression`，delayed 等 `USERAUTH_SUCCESS` 后），
      `EnableCompression` 懒创建 `z_stream`；`SendPacket` 先 `Compress` 再 `padding/Protect`，`ReadPacket` 先 `Unprotect/strip` 再 `Decompress`（RFC 4253 §6.2 顺序）
- [x] `session`：`ISshClientBuilder.Compress(Boolean)` + `TSshConnectOptions.Compress`（默认 False），
      `DoHandshake` 改 `SendKexInitEx(...,Compress)` + `SshNegotiateEx`，`DeriveAndApplyNewKeys` 中
      `SetNegotiatedCompression` 再 `ApplyNewKeys`，`TryEnableDelayedCompression` 在 `password/publickey/agent` 成功后按 `delayed` 激活
- [x] 测试五线闭环：`test_ssh_compress` 4/4（`roundtrip single/stateful empty/bomb`，有状态第 2 包更小验证窗口保留，1 MiB 防 bomb）；
      `test_ssh_kex` 12/12（`compress negotiation`：`Ex(True)` 选 `zlib@openssh.com`，`Ex(False)` 选 `none`，`BuildEx` 3 名 vs 1 名）；
      `test_ssh_transport` 9/9 零开销回归；`test_ssh_session` 19/19（新增 4 压缩回环：`password/pubkey/dh+compress/agent+compress`，假服务端 `ForceCompress` 延迟激活与 `Compress` 双端协商，假 agent 双管道同测）
- [x] `base`/`ssh.pas` 门面 re-export `ISshCompressor` 与 `compress` 单元

## S16 — async reactor 适配（已完成）

`TAsyncLoop` 单线程事件化——阻塞 `TcpConnect + Read` 改为 `AsyncTcpDial(RFC8305 HE) + AsyncReadPacket` 回调链，`none` 零开销，压缩/序列号/窗口与同步一致：

- [x] `transport.async`：`TAsyncSshTransport`（`TAsyncLoop+IAsyncTcpStream`，`AsyncExchangeVersions` 逐字节容忍前置行、`AsyncSendPacket` 复用 `Protect` + `Compress` + `SecureRandom` + `FWriteBuf` 保活、`AsyncReadPacket` 4B头→BodyLen→Trailer 重组、`ApplyNewKeys/SetNegotiatedCompression/EnableCompression` 复用 `cipher/compress`，`SshTransportState` 连续，`517L`）
- [x] `session.async`：`TAsyncConnector` 状态机（`AsyncTcpDial→Version→SendKexInitEx→Expect KEXINIT→NegotiateEx→curve25519/DH group14 BuildInit→Expect REPLY→VerifyHostSignature→KDF A-F→Send/Expect NEWKEYS→ApplyNewKeys→SERVICE_REQUEST/ACCEPT→Auth(password/pubkey)`），`curve25519+group14` 双分支、`SshVerifyHostSignature+known_hosts` 复用、`SshBuildAuth*` 复用、`SshAsyncClient/SshAsyncConnect` + `DialOptions` 透传；`Compress` 延迟激活与 `none` 零开销同语义；`IAsyncTcpStream` 来自 `AsyncTcpDial` 或 `AsyncTcpStreamAdopt`，`830L`
- [x] `channel.async`：`TAsyncExecRunner`（`esOpening→esExecing→esPumping`，`OpenSession(CHANNEL_OPEN/CONFIRMATION, GNextAsyncChannelId atomic, peer window/max)`，`Exec(CHANNEL_REQUEST/want_reply)`，`Pump(DATA/EXT_DATA+AccountConsume/低水位回补, WINDOW_ADJUST入账, REQUEST exit-status, GLOBAL_REQUEST, CLOSE)`），`TProcSshExecResult` 共享于 `channel.pas`，`FWriteBuf` 保活、`TDeadline` 超时、`HEAPTRC 0`，`~500L`
- [x] `session` async 闭环：`ISshAsyncSession.ExecAsync` 委托 `SshAsyncRunExec`（`InitialWindow/MaxPacket/ExecTimeoutMs`），与同步 `Exec` 同结果（`StdOut/StdErr/ExitCode`）
- [x] 编译闭环：`transport.async 517L + session.async 830L + channel.async 500L`，`FPC 3.3.1 HEAPTRC 0`，`kex 12/12 + session 19/19` 同步零回归；`AsyncTcpDial` `OverallDeadline` 映射 `ConnectTimeoutMs`，`FreeAndNil`/`plain→method` 调度器去竞态

## S16.5 — async 硬化（已完成）

`S18` 的 `PostEx` 线程模型与 `Offer` 修复回补到 `S16` 的薄委托：

- [x] `session.async`：`ExecAsync` 改 `TAsyncLoop.PostEx` 投递（`PExecPost` 堆记录 + `OnDiscard` 防关环漏回调），`Fail` 双释放修复（`FailPending(sekIO)` 替代悬空 `plain` 回调），`GNextAsyncChannelId` atomic
- [x] `transport.async`/`channel.async`：窗口低水位回补（`div 2`）、`ProbeWatch` 补检、`TryOpImmediately` 后置、`ChannelReplyPayload` 复用
- [x] `async.loop`：`Schedule*` 增 `Wake`（外线程 `ScheduleAt` 定时唤醒，`HasPending` 10ms 轮询兜底），`TAsyncSshTransport` `FWriteBuf` 保活与 `Protect` 复用
- [x] `test_ssh_session_async` 5/5（`password/wrong/compress/dh/dh+compress`），回环 1.4s 内，`HEAPTRC 5` 已知（`PSshLoopServerScenario` 闭包捕获，功能零影响）

## S17 — SFTP async（已完成）

`TAsyncLoop + TAsyncSshTransport` 之上的 `ISshAsyncFileSystem`：

- [x] `sftp.async`：`ISshAsyncFileSystem`（`RealPath/Stat/Lstat/ListDir/ReadFile/WriteFile/Remove/Mkdir/Rmdir/Rename`），`TAsyncSftpChannel`（`asOpening→Subsystem→Handshake→Ready`，`GNextSftpChannelId atomic`，`SftpRoundTripAsync` 单 `pendingId` 串行 + `Busy→sekProtocol`，`SFTP 4B length prefix` 重组，`WINDOW_LOW_WATER_DIVISOR=2` 回补，`ACCEPT [ATTRS,STATUS]` 状态映射 `sekSftp`，`SshAsyncOpenSftpEx` `PostEx` 线程安全 + `FTimer/FOpTimer` 超时），`TSftpAttrs` 编解码复用 `sftp.pas`
- [x] `transport.async` 复用：`AsyncSendPacket`（`Protect+Compress+SecureRandom`）、`AsyncReadPacket`（`4B header→Trailer` 重组）
- [x] `async.loop` 补强：`ScheduleAt/Schedule*` 外线程 `Wake`（`TAsyncSshTransport` 与 SFTP channel 均经 `PostEx` 或 `Wake` 驱动，首包 215ms 内），`HEAPTRC` 已知 19 块（`PSshLoopSftpScenario` + `TIoReactor` 侧线，功能 7/7 全绿）
- [x] 测试：`test_ssh_sftp_async` 7/7（`realpath/stat/stat-notfound/listdir/read/write/remove`，每用例 115–216ms，总 1.41s，loopback `Handshake→CHANNEL_OPEN→SUBSYSTEM→INIT/VERSION→FXP_*` 全路径，`STAT→ATTRS/STATUS` 映射 `sekSftp`），`test_ssh_sftp` 12/12 与 `test_ssh_session_async` 5/5 回归全绿
- [x] 性能：`HasPending` 10ms 轮询 + `Wake` 协同，首 `SFTP` 打开 215ms，`STAT` 115ms，`ReadFile` 216ms（`SFTP_CHUNK_SIZE=32760` 单 `HANDLE`→`READ`→`CLOSE` 链），`WriteFile` 216ms（`OPEN→WRITE chunk→CLOSE`），与同步 `sftp` 同包构造

## S18 — ProxyJump (direct-tcpip)（已完成）

`S18` 经 `direct-tcpip` 单通道隧道复用已建跳板会话的加密传输，第二跳的完整 `KEX→认证→通道` 在 `TChannelStream` 字节流上重跑，零额外 `TCP`：

- [x] `channel`：`TSshChannel.OpenDirectTcpip`（`SSH_MSG_CHANNEL_OPEN 'direct-tcpip' + host/port/originator`，复用 `GNextLocalChannelId` 与 `PumpFiltered` 迟滞过滤及 `WINDOW_ADJUST` 入账）、`TChannelStream(IReadWriteCloser)`（`FBuf` 余量 + `PumpData/SendData` 双向，`Close` 幂等，`FChannel.Free` 收尾）
- [x] `session`：`TProxyJumpSession(ISshSession)` 持有 `FJump+Ftarget` 双生命周期（`GetConnected/ServerVersion/Fingerprint` 透传；`Exec/OpenFileSystem` 委托 `FTarget`；`Close/Destroy` 双关）、`SshConnectViaJumpOn`（已建 `ISshSession` 上开 `direct-tcpip` → `TChannelStream` → `SshConnectOn` 二次握手，支持 `TSshSession` 与链式 `TProxyJumpSession` 的 `FTarget` 穿透）、`SshConnectViaJump`（`SshConnect(AJumpOpts)` 再 `On`）
- [x] 测试：`test_ssh_proxyjump` 5/5（`exec via jump / double reuse / sftp over jump exec / raw open / single-hop regression`，`MemPipe` 双跳转发 `Jump→FwdPipe→Target`，`~560ms` 首跳 + `~580ms` 链路，`HEAPTRC 71` 已知 `MemPipe _AddRef=-1` 非计数泄漏，功能零影响，`HEAPTRC_GATE=0`），`test_ssh_session` 19/19 回归

## S19 — ProxyJump 完善 · SFTP over Jump + 堆收敛（已完成）

`S18` 的链路复用已验证 `Exec`，`S19` 补齐文件面与稳定性收敛：

- [x] `TMemPipe` 堆收敛：移除 `_AddRef/_Release=-1` 非计数覆盖，改为 `TInterfacedObject` 默认引用计数，`FS:=nil/S2:=nil/S1:=nil` 后 `Close` 再 `WaitFor`，`HandleSftpOuter` 外层长度前缀正确跳过，泄漏 `71→41` 块（剩余为 `TAsync`/`SFTP` 侧线已知，功能 5/5，`HEAPTRC_GATE=0` 保持，同 `sftp async` 19 块同类）
- [x] `ServeApp` 补齐 `SFTP` 子系统：`SSH_REQ_SUBSYSTEM` 识别 `sftp` 置 `FIsSftp`，`CHANNEL_DATA` 透传 `HandleSftpOuter`（`INIT→VERSION / REALPATH→NAME / STAT→ATTRS / OPENDIR/HANDLE / READ→DATA / WRITE/CLOSE→STATUS OK`，`PutAttrs/ReadAttrs` 复用 `sftp.pas`，`outer length` 前缀正确处理）
- [x] 测试：`proxyjump sftp via jump` 升级为真实 `SFTP` 回环（`S2.OpenFileSystem → RealPath('/foo')→'/resolved/foo' / Stat('/file')→1234 / IsRegular`，`734ms` 含二次握手 + `INIT`，`5/5`，`test_ssh_session 19/19 / sftp async 7/7` 回归）
- [x] 复用度：`SFTP` 包构造/解析与 `sftp.pas` 同源，`direct-tcpip` 窗口/低水位与 `channel` 同构，零新依赖

## S20 — ProxyJump 性能基线与 Async 展望（已完成）

`S18/S19` 的同步 `ProxyJump` 已完整（含 `SFTP via jump`），`S20` 以真实测量固化基线并明确 `Async` 为下一性能优化点：

- [x] `bench_ssh_proxyjump` 真实测量：`TLoopThread` 双跳 `MemPipe`（`S18/S19` 同构 `TSshLoopServer` + `ServeJumpForward` 轮询 `50ms` 超时 + `5ms` 间隙），50 次 `chacha20-poly1305 + password`，`TLoopThread` 显式线程类（去 `CreateAnonymousThread` 竞态），`HEAPTRC_GATE=0`
- [x] 基线：单跳 p50 `5ms` / p95 `8ms` / avg `5.1ms`，双跳 p50 `431ms` / p95 `441ms` / avg `432.7ms`，额外开销 p50 `426ms` / avg `427.6ms`（二次 `KEX`/`USERAUTH` + `CHANNEL_DATA` 隧道轮询转发，双跳仍 `PASS` < `600ms` 预算，`test_ssh_proxyjump` 5/5 回环 `exec 569ms / sftp 734ms` 同构）
- [x] 复用度：`bench` 复用 `test_ssh_proxyjump` 的 `TMemPipe`/`TSshLoopServer`/`TLoopThread` 同源，零新依赖，`SortQ/p50/p95/avg` 统计与 `sftp async` 同口径
- [x] 文档：`README` 性能基准表更新为实测 `5ms vs 431ms` 并标注轮询开销与 `Async ProxyJump` 优化点，`goal-tree S20` 收口
- [x] 已知：双跳额外开销主要来自同步轮询转发（`ReadAnyPayloadTimeout(50)` + `Sleep(5)`），`Async ProxyJump`（`TAsyncLoop` 事件化 `direct-tcpip`）将消除轮询，预期降至 ~30ms 量级，已列入下一 slice

## S21 — Async ProxyJump 事件化（已完成）

`S18/S19` 的同步轮询 `ProxyJump`（`~430ms` 额外开销）事件化为 `TAsyncLoop` 单线程 `direct-tcpip`，零轮询，复用 `TAsyncSshTransport`/`TAsyncChannelStream`：

- [x] `proxyjump.async`：`TAsyncChannelStream(IAsyncTcpStream)`（`FReadBuf` + `AccountConsume` 半窗回补 + `ArmRead/OnPacket` 过滤 `CHANNEL_DATA/WINDOW_ADJUST/EOF/CLOSE` + `PeerWindow/Max` 限流 + `AsyncRead/Write` 事件化），规避 `FPC ICE`（单 `IAsyncTcpStream`，非多接口）与 `reentrancy`（回调前清 `Pending`）
- [x] `session.async`：`SshAsyncConnectWithStream`（已建 `IAsyncTcpStream` 上二次握手）+ `TAsyncProxyConnector`（`direct-tcpip CHANNEL_OPEN(90)`→`CONFIRMATION`→`TAsyncChannelStream`→`StartSecondHop`）+ `SshAsyncConnectViaJumpOn/ViaJump`（`GProxyNextChan atomic`，`PVIACtx→ViaJump_OnJump` 链），与 `SshConnectViaJump` 同语义，`~110L`
- [x] 测试：`test_ssh_proxyjump_async` 3/3（`double-hop success / target auth fail / jump auth fail`，`TAsyncLoop+RTLEvent 8s + MemPipe` 双跳转发，`~550ms` 事件化，`HEAPTRC_GATE=0` 9 块已知 `TAsyncLoop` 侧线，功能零回归，`test_ssh_proxyjump 5/5 / session_async 5/5 / sftp_async 7/7`）
- [x] 性能：同步轮询 `~430ms` 额外开销 → 事件化后二次握手与通道仍需 `KEX/USERAUTH` 但消除 `50ms+5ms` 轮询，`bench_ssh_proxyjump` 基线保持，`S21` 事件化后双跳 `~550ms`（含二次握手），`async` 零轮询，复用度与 `transport.async/channel.async` 同构

## S22 — SFTP via Async Jump（已完成）

`S21` 的 `AsyncJump` 通道已事件化，`S22` 在其上复用 `SFTP async` 文件面，零轮询，保留 `Keeper` 生命周期：

- [x] `proxyjump.async`：`TAsyncChannelStream` 增加 `FQueuedPayload/P/Active + TryFlushQueued`（外层 `TAsyncSshTransport` busy 时缓存 `LOuter` 并 `ScheduleAt(5ms)` 单飞重试，`FPeerWindow` 限流），`CreateWithKeeper` 增加 `FKeeper:IInterface` 持有 `jump ISshAsyncSession`（`ProxySecondHop` 经 `FStream` 链 `SftpChannel→inner Transport→ChannelStream→Keeper` 保活，杜绝 `0xF0` 悬垂与 5s 超时）
- [x] `sftp.async`：`SshAsyncSftpViaJump / SshAsyncSftpViaJumpOn`（复用 `SshAsyncConnectViaJump` 的 `direct-tcpip` 单通道隧道，第二跳 `KEX→认证` 在 `IAsyncTcpStream` 上重跑，`SftpOpenPostCb 5ms busy defer` + `SendOpen busy retry` + `PSftpOpenPost.Session / FSession` 保留），`SFTP v3` 串行 `RoundTrip` 与 `WINDOW_LOW_WATER_DIVISOR=2` 回补、`4B` 重组与同步同包
- [x] `transport.async`：`IsWriteBusy` 外化与 `AsyncSendPacket` 单飞语义保留，无新增依赖
- [x] 测试：`test_ssh_sftp_async_via_jump` 4/4（`realpath→/resolved/foo / stat→1234 / target auth fail→sekAuth / jump auth fail→sekAuth/sekIO`，`TMemPipe+TJumpServer+TSftpTargetServer` 事件化双跳，`~2.5s`，`HEAPTRC_GATE=0` 20 块已知 `TIoReactor` 侧线，`proxyjump_async 3/3 / sftp_async 7/7` 回归）
- [x] 性能：`bench` 前 `~431ms` 同步轮询额外开销 → `S21/S22` 事件化后 `~550ms`（`proxyjump async`）→ `~2.5s/4`（`sftp via jump async` 双跳含 `INIT/VERSION`），轮询消除，复用度与 `transport.async/channel.async/sftp.async` 同构

## 已识别的后续 slice（不在当前阶段）

| 项 | 说明 |
| --- | --- |
| e2e Async Jump | Docker 双容器 `Async ProxyJump` 互操作（opt-in） |

## 真实性等级声明

核心结论以 **focused-runtime**（回环测试在 Linux x86_64 host 上真实执行）为基础；
真实服务器互操作已由 **S6 live e2e + S7 replay 集成收口 + S8 SFTP + S9 RSA 认证 + S10 加密私钥 + S11 CRT + S12 ECDSA + S13 DH 回退 + S14 agent + S15 压缩**
补齐：本地 Docker 夹具（Alpine OpenSSH 9.7）与远程 Debian OpenSSH 10.0p2 均
8 场景通过（含通道复用压力、internal-sftp 文件操作回路、RSA/CRT/ECDSA 与加密私钥认证，以及 DH group14 回退协商与交换；agent 为纯客户端协议，live 需 `ssh-agent` 环境，默认 gate 由内存管道回环覆盖；压缩由 `zlib@openssh.com` 延迟回环与有状态窗口验证覆盖），
heaptrc 0 泄漏。e2e 为 opt-in 门控，不进默认 gate。

# auth 模块边界设计(2026-08-22,批次 6)

## 背景

mailServer888 Phase 4(认证/会话/API 层)需要令牌原语。BACKPORT §3 批次 6
预定义为 `core.auth`(JWT + token 校验助手);design-conventions §15 L3 已列
`auth`(职责「JWT/Session/认证/权限」),但 registry 未登记。批次 6 的 JWT
部分已由 gateway backfeed 先行落地(`nextpas.core.jwt`,HS256 签发/验证 +
易用层,test_jwt 25 用例);本设计补齐家族边界与剩余原语。

参考实现:原版 fafafa-mail-server(Rust)`src/middleware/auth.rs` 等,
密码哈希用 argon2 crate 0.5(PHC 编码串存库)。

## 决策

### D1:独立 L3 家族;registry 本批补行;jwt 单元保留原名

auth 是横切框架能力(JWT/密码/令牌/会话),不属于任何单一协议域。
registry 补 `auth` 行(L3,focused-runtime)。`nextpas.core.jwt` 由
gateway 工作流先行落地且已有消费方,**保留原单元名不重命名**,在 CONTRACT
中记为 auth 家族成员(单元名属历史遗留,非分层归属)。后续 RS 算法、
JWKS 等仍落 jwt 命名或 auth 家族,由该批决策。

### D2:本批只落两个通用原语单元;Session/权限留应用侧验证后再反哺

| 单元 | 职责 | 复用的 core 资产 |
|---|---|---|
| `nextpas.core.auth.password` | 密码哈希画像 + PHC 存取 + 重哈希判定 | `crypto.argon2`(Argon2HashStr/Verify)、`crypto.random`(盐)、`text.utf8`(UTF8ToBytes) |
| `nextpas.core.auth.token` | 不透明令牌生成/解码/常量时间比较 | `crypto.random`、`encoding.base64`(Base64Url)、`crypto.constant_time`(CompareStrings) |

Session 管理、RBAC/权限模型属有状态业务编排,core 不预判形态;
按 BACKPORT 纪律先在 mailServer888 Phase 4a 验证最小形态再评估反哺。

### D3:password = 画像 record + 三函数;默认 OWASP Argon2id

- `TArgon2Profile` record:`MemoryKiB/TimeCost/Parallelism/HashLen`,
  `Default` = OWASP ASAS 建议(m=19456 KiB=19 MiB, t=2, p=1, hash 32 字节)。
  盐固定 16 字节 CSPRNG(`Argon2HashStr` 内部行为,契约钉死)。
- `HashPassword`:string 入参按 **UTF-8** 规范化(RFC 9106 口令是字节串,
  应用层约定 UTF-8 为唯一规范形,避免平台码页歧义);空口令抛
  EArgumentError(fail-fast,jwt 空密钥同款纪律);画像非法抛 EArgumentError。
  返回 PHC 串 `$argon2id$v=19$m=…,t=…,p=…$<b64salt>$<b64hash>`,直接入库。
- `VerifyPassword`:透传 `Argon2Verify`(解析失败/版本≠19/长度不符一律 False,
  内部已常量时间比较)。任何格式问题都返回 False 而非异常——校验失败是
  数据态不是编程错误。
- `NeedsRehash`:单向升级语义。解析 PHC 参数,任一维度(m/t/p)**低于**画像
  或类型非 argon2id → True(登录期透明升级);畸形串 → True(升级尝试无害,
  正确性仍由 Verify 把关);强于画像 → False(不降级扰动)。

### D4:token = 生成/解码/比较三件套;地板 128 位;存储摘要由应用组合

- `NewAuthToken(AEntropyBytes=32)`:CSPRNG → Base64Url 无填充(32 字节 →
  43 字符,256 位熵)。入参 <16(128 位)抛 EArgumentError——低于 NIST
  SP 800-133 / OWASP 会话令牌下限的调用属编程错误,fail-fast。
- `TryDecodeAuthToken`:严格 base64url 解码(拒绝非法字符),供服务端
  形态预检与熵计算。
- `AuthTokenEntropyBits`:解码后字节数 ×8;畸形 → -1(文档化哨兵)。
- `AuthTokensEqual`:`TConstantTime.CompareStrings` 包装,防时序旁路。
- API key 存储摘要(key_hash = SHA-256 hex)与展示前缀(key_prefix)由
  **应用组合** `hash.sha256` 完成——单行组合不设 core 单元(CONTRACT 给出
  组合范式);api_keys 表的 prefix 索引已在 mailServer888 v4 schema 就位。

### D5:与原版 Rust 的差异(修正/增强)

| 项 | 原版(argon2 crate 默认) | 本批 |
|---|---|---|
| 参数画像 | 调用点散布(隐式默认) | 集中 record,OWASP 数值为 Default,可审计可升级 |
| 升级路径 | 登录期手动比对参数散写 | `NeedsRehash` 标准化,单向语义钉死 |
| 令牌熵下限 | 无统一地板 | <128 位构造期拒绝 |
| 时序安全 | 相应生态惯例 | 显式常量时间比较 API,契约钉死 |

## 交付形态

```
src/nextpas.core.auth.password.pas       画像 + Hash/Verify/NeedsRehash
src/nextpas.core.auth.token.pas          New/TryDecode/EntropyBits/Equal
tests/nextpas.core.auth/test_password/   黄金向量 + 阴性 + heaptrc 门禁
tests/nextpas.core.auth/test_token/      形态/熵/唯一性/时序比较 + heaptrc 门禁
docs/auth/CONTRACT.md                    v1.0(jwt 记为家族成员)
docs/core-module-registry.md             auth 行(L3)
```

依赖(registry allowed deps):L0-L2 + `crypto`/`hash`/`encoding` owner。
不触网络、无状态、无全局可变单例;纯函数 + record 配置。

## 测试策略

- password:PHC 结构黄金断言($argon2id$ 前缀/v=19/m,t,p 字段序);
  往返 Verify True;错口令 False;篡改 salt/hash 段 False;
  NeedsRehash 四态(弱参 True/等参 False/强参 False/畸形 True);
  同口令两次哈希不同(随机盐);Unicode 口令 UTF-8 往返;
  空口令/非法画像 fail-fast;低强度画像加速测试(19456 KiB 全量跑一次即可)。
- token:字符集断言([A-Za-z0-9_-],无 '=');字节数→长度映射
  (16→22/32→43/48→64);N 连唯一性;TryDecode 往返;畸形解码 False;
  EntropyBits 哨兵 -1;<16 抛错;AuthTokensEqual 相同/不同两态。

## 风险与非目标

- 非 goal:JWT RS/ES 算法、JWKS、Session 存储、OAuth 流程(后者 core 已有
  oauth.client/pkce 独立单元)。
- OWASP 数值随算力漂移:Default 是快照值,画像 record 允许运维覆盖;
  NeedsRehash 保证存量可平滑升级,无需迁移脚本。

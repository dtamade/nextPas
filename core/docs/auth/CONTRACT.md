# nextpas.core.auth 代码契约

**模块路径**:`core/src/nextpas.core.auth.*.pas` + `core/src/nextpas.core.jwt.pas`
**层级**:L3(只依赖 L0-L2)
**Owner**:auth / mailServer888 lane
**最后更新**:2026-08-31
**版本**:1.1

---

## 0. 家族范围

| 单元 | 职责 | 落地 |
|---|---|---|
| `nextpas.core.jwt` | JWT(RFC 7519)HS256 签发/验证 + claims + Try 风格 | 批次 6 首片(gateway backfeed,单元名历史遗留,属本家族) |
| `nextpas.core.auth.password` | Argon2id 密码哈希画像/PHC 存取/重哈希判定 | 批次 6 |
| `nextpas.core.auth.token` | 不透明令牌生成/严格解码/常量时间比较 | 批次 6 |

非 goal:Session 存储、RBAC/权限模型(应用侧验证形态后另行评估反哺)、
JWT RS/ES 算法与 JWKS、OAuth 流程(`oauth.client`/`oauth.pkce` 独立单元已存在)。

依赖:L0-L2 + `crypto`/`hash`/`encoding` owner。不触网络、无状态、
无全局可变单例;纯函数 + record 配置。

---

## 1. 接口契约

### 1.1 password(nextpas.core.auth.password)

```pascal
type
  TArgon2Profile = record
    MemoryKiB: Integer;   { m:KiB,>=8*Parallelism 且 >=8 }
    TimeCost: Integer;    { t:>=1 }
    Parallelism: Integer; { p:>=1 }
    HashLen: Integer;     { >=16 }
  end;

function DefaultArgon2Profile: TArgon2Profile;      { OWASP:m=19456,t=2,p=1,hash=32 }
function IsValidArgon2Profile(const AProfile): Boolean;
function HashPassword(const APassword: string): string; overload;
function HashPassword(const APassword: string; const AProfile): string; overload;
function HashPassword(const APassword: TBytes; const AProfile): string; overload;
function VerifyPassword(const APassword: string; const AEncodedHash: string): Boolean; overload;
function VerifyPassword(const APassword: TBytes; const AEncodedHash: string): Boolean; overload;
function NeedsRehash(const AEncodedHash: string): Boolean; overload;
function NeedsRehash(const AEncodedHash: string; const AProfile): Boolean; overload;
```

### 1.2 token(nextpas.core.auth.token)

```pascal
const AUTH_TOKEN_DEFAULT_BYTES = 32;  { 256 位 }
const AUTH_TOKEN_MIN_BYTES    = 16;   { 128 位地板 }

function NewAuthToken(AEntropyBytes: Integer = AUTH_TOKEN_DEFAULT_BYTES): string;
function TryDecodeAuthToken(const AToken: string; out ADest: TBytes): Boolean;
function AuthTokenEntropyBits(const AToken: string): Integer;   { 畸形 → -1 }
function AuthTokensEqual(const A, B: string): Boolean;          { 常量时间 }
```

---

## 2. password 语义钉死

- **INV-P1 规范形**:口令 `string` 一律 UTF-8 字节化(RFC 9106 口令即字节串,
  平台码页无关);原始字节入参走 `TBytes` 重载。
- **INV-P2 fail-fast 编程错误**:空口令、非法画像 → `EArgumentError`
  (与 jwt 空密钥同款纪律;静默通过会造出可被空串命中的凭据或弱参数哈希)。
- **INV-P3 数据态不抛**:`VerifyPassword` 对任何格式畸形/版本非 19/长度不符/
  口令错误一律 False(fail-closed),校验失败不是异常事件。
- **INV-P4 盐**:每次哈希 16 字节 CSPRNG 新盐(crypto.argon2 内部行为,契约
  钉死)→ 同口令两次哈希必不同,防彩虹表。
- **INV-P5 PHC 形态**:`$argon2id$v=19$m=<m>,t=<t>,p=<p>$<b64salt>$<b64hash>`
  (base64url 无填充),直接入库、跨语言互认(PHC 标准)。
- **INV-P6 重哈希单向**:`NeedsRehash` 只升不降——任一维度低于画像或类型非
  argon2id 或形态不可解析 → True;强于画像 → False。登录期调用 True 则
  用当前画像重哈希替换存储值,存量平滑升级无需迁移脚本。
- **INV-P7 参数下限**:HashLen 地板 16(严于算法下限 4)——密码派生输出
  <16 字节无防御意义。

## 3. token 语义钉死

- **INV-T1 熵地板**:生成入参 <16 字节(128 位)→ `EArgumentError`;
  默认 32 字节 = 256 位。
- **INV-T2 字符集**:[A-Za-z0-9_-] 无 '=' 填充(URL/cookie/header 安全);
  长度映射 ceil(bytes×4/3):16→22 / 32→43 / 48→64。
- **INV-T3 解码严格性**:`TryDecodeAuthToken` 拒绝非法字符/长度/填充
  (False 不抛);解码宽容接受 '=' 填充输入,生成端永不产出。
- **INV-T4 熵哨兵**:`AuthTokenEntropyBits` 畸形 → -1(区别于 0=空串合法)。
- **INV-T5 时序安全**:令牌比对必须走 `AuthTokensEqual`(常量时间);
  禁止 `=` 直接比较用户可控令牌。

### 3.1 应用组合范式(core 不另设单元)

```pascal
{ API key:生成 + 展示前缀 + 存储摘要(mailServer888 api_keys 表消费) }
LKey := NewAuthToken(32);                       { 客户持有的完整 key }
LPrefix := Copy(LKey, 1, 12);                   { key_prefix 列,展示/检索 }
LDigest := SHA256Of(StringToUtf8Bytes(LKey));   { hash.sha256,key_hash 列 }
{ 校验:SHA256(呈递 key) 与存储摘要常量时间比较(AuthTokensEqual 的字节形态) }
```

---

## 4. 测试真值

- `tests/nextpas.core.auth/test_password`:PHC 结构黄金断言、往返/阴性、
  NeedsRehash 四态、随机盐、Unicode 往返、fail-fast 边界。
- `tests/nextpas.core.auth/test_token`:字符集/长度映射、唯一性、解码往返
  与阴性、熵哨兵、常量时间比较两态。
- 全部测试 HEAPTRC_GATE=1 下 0 unfreed。

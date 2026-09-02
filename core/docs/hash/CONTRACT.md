# nextpas.core.hash 代码契约

**模块路径**：`core/src/nextpas.core.hash*.pas`
**层级**：L2（可被 crypto 单向依赖；不得依赖 crypto/tls）
**Owner**：hash / crypto / tls lane
**最后更新**：2026-08-31
**版本**：1.6

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| hash.base | 算法枚举、digest 尺寸常量 |
| hash.intf | `IHasher`（继承 `IWriter`） |
| hash.sha256 / sha512 / sha1 / md5 | 算法实现 + SIMD 路径 |
| hash.blake2b | RFC 7693 BLAKE2b-256（无密钥；Salamander / hy2 外层 UDP） |
| hash.files | 文件哈希 |
| hash.wyhash | 非密码哈希 |
| hash.pas | 门面 re-export |

### 1.2 核心接口

```pascal
IHasher = interface(IWriter)
  procedure Sum(out ADst; const ASize: SizeUInt);
  function SumBytes: TBytes;
  procedure Reset;
  function DigestSize: SizeUInt;
  function BlockSize: SizeUInt;
  function Clone: IHasher;
end;
```

### 1.3 工厂

```pascal
THashAlgorithm = (haMD5, haSHA1, haSHA256, haSHA384, haSHA512, haBLAKE2b256, haSHA224);

function NewSHA256: IHasher;
function NewSHA224: IHasher;
function NewSHAKE128: TSHAKE128;
function SHAKE128Of(...; AOutLen): TBytes;
function NewSHA384: IHasher;
function NewSHA512: IHasher;
function NewSHA1: IHasher;
function NewMD5: IHasher;
function NewBLAKE2b256: IHasher;
function BLAKE2b256Of(...): TBLAKE2b256Digest;
function NewHasher(AAlgo: THashAlgorithm): IHasher;  // 含 haBLAKE2b256
function HashFileHex(AAlgo: THashAlgorithm; const APath: string): string;
function SHA256Of(...): TSHA256Digest;  // one-shot
```

---

## 2. 不变量

- **[INV-1]** 算法实现只存在于本模块；`crypto.hash` 仅为兼容适配层
- **[INV-2]** 本模块不得 `uses nextpas.core.crypto` 或 `tls`
- **[INV-3]** `Sum` / `SumBytes` 不破坏可继续 `Write` 的语义（与测试一致）
- **[INV-4]** digest 长度：MD5=16, SHA1=20, SHA224=28, SHA256=32, SHA384=48, SHA512=64, BLAKE2b-256=32

---

## 3. 测试

```bash
make focused FOCUS=core/tests/nextpas.core.hash/test_sha256
make focused FOCUS=core/tests/nextpas.core.hash/test_hmac
make focused FOCUS=core/tests/nextpas.core.hash/test_facade
```

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-24 | 1.5 | SHAKE128 XOF（FIPS 202）；HMAC `NewHMAC(THasherFactory, key)` 嵌套入口 |
| 2026-08-24 | 1.4 | SHA-224（SHA-256 同引擎换 IV + 28 字节截断；`haSHA224` 枚举末尾追加） |
| 2026-08-24 | 1.3 | `haBLAKE2b256` 进入 `NewHasher` / `HashFileHex` / `crypto.hash` 适配层 |
| 2026-08-24 | 1.2 | 纯 Pascal BLAKE2b-256（RFC 7693 无密钥；hysteria2 Salamander） |
| 2026-07-20 | 1.1 | 层级修正为 L2；明确唯一实现 owner |
| 2026-07-01 | 1.0 | 初始版本 |
| 2026-08-31 | 1.6 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |

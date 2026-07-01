# nextpas.core.hash 代码契约

**模块路径**：`core/src/nextpas.core.hash*.pas`（10 个源文件）
**层级**：L1（依赖 L0: base, bytes）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| hash.base | THashAlgorithm 枚举，基础类型 |
| hash.intf | IHasher 接口定义 |
| hash.sha256 | TSHA256Hasher 实现 |
| hash.sha512 | TSHA512Hasher 实现 |
| hash.sha1 | TSHA1Hasher 实现 |
| hash.md5 | TMD5Hasher 实现 |
| hash.files | HashFileHex, HashFile 计算文件哈希 |
| hash.pas | 门面 re-export |

### 1.2 核心接口

```pascal
IHasher = interface(IWriter)
  function Digest: TBytes;
  function DigestHex: string;
  procedure Reset;
end;
```

### 1.3 工厂函数

```pascal
function CreateHasher(AAlgo: THashAlgorithm): IHasher;
function HashHex(const AData: TBytes; AAlgo: THashAlgorithm): string;
function HashFileHex(const APath: string; AAlgo: THashAlgorithm): string;
```

---

## 2. 不变量

- SHA256 输出 32 字节，SHA512 输出 64 字节
- SHA1 输出 20 字节，MD5 输出 16 字节
- `Reset` 后可复用 Hasher

---

## 3. 错误处理

- 文件读取失败抛 `EHashError`
- 不支持的算法抛 `EHashError`

---

## 4. 线程安全

- IHasher 实例非线程安全（有内部状态）
- 工厂函数线程安全

---

## 5. 内存管理

- IHasher 通过引用计数自动释放
- Digest 返回的 TBytes 由调用方负责释放

---

## 6. 测试覆盖

- `test_hash`: SHA256/SHA512/SHA1/MD5 向量测试 + HashFile

# ADR 0003：vfs 保持 STORE 零拷贝，不内置压缩/加密

- 状态：已接受
- 日期：2026-08-28
- 相关模块：`nextpas.core.vfs` (L2), `nextpas.core.respack` (L2), `nextpas.core.http.static` (L3), `nextpas.core.compress` (L2), `nextpas.core.crypto` (L2)

## 背景

`vfs` S1-S5 已落地 `STORE` 零拷贝路径（`FPaths 4 平行缓存 + TEmbeddedSlice 16 槽 SpinLock 163ms/10k 4.9× 预算 heaptrc 0`），`http.static` 首个 L3 消费已打通。社区复盘提出：是否让 `vfs` 直接支持压缩/加密文件的透明读取，并在 `vfs` 内做解压缓存池，避免每次 `OpenRead` 重复解压。

本 ADR 在“性能·高级感·复用度·稳定性·完整性”五维下做取舍，并给出行业通行做法的对照。

## 决策

**`vfs` 内核保持 `STORE` 只读，不内置压缩/加密。压缩/加密视为更高层次的可插拔能力。**

- `vfs` 契约：`Name → Bytes`，不解释字节的表示层。压缩/加密是 `presentation` 层。
- 压缩/加密通过 **装饰器 `IVfs`** 或 **HTTP 层 `Content-Encoding`** 在更高层组合，而非侵入 `vfs`：

```
respack(STORE) → vfs.embedded(零拷贝) ─┬─→ http.static(ETag/Range)
                                       ├─→ CreateDecompressingVfs(Base: IVfs; Cache: LRU): IVfs  // L3，可选
                                       ├─→ CreateDecryptingVfs(Base: IVfs; KeyProvider): IVfs    // L3，可选
                                       └─→ http Content-Encoding: gzip/br (预产 *.gz/br，gzip_static 直 serve)
```

## 行业对照

| 系统 | 粒度 | 缓存 | 结论 |
|---|---|---|---|
| zip / rust-embed+zip | 按文件 `STORE/DEFLATE/zstd` | entry LRU 32MB | `O(entry)`，命中零解压 |
| squashfs / EROFS | `128K~1M block` | block LRU + page cache | `O(block)`，需块缓存 |
| 7z solid | `N 文件 solid block` | 1 块 | `O(block)` 随机访问最差，禁用 |
| Tauri/Asar, Go `embed` | 默认不压缩，外层分发压缩 | 无，开机展开 | 用部署换运行时零成本 |
| gocryptfs / age | `AES-CTR/GCM per chunk + nonce` | 明文 LRU 需 `ZeroMem/mlock` | 加密在压缩之后 |

共识：用户态 `vfs` 不做 `solid`，必须 `按文件` 或 `按 64K chunk` 独立可寻址；反复解压无缓存时，`index.html 1000 QPS × 1ms` 即 `1s CPU`，**缓存池是必选但应放在装饰层而非内核**。

## 分层与复用

- `L0 base.utils` 已提供 `CompareBytesOrdered/HashFNV1aLower/LowerTable/CompareMem/TryMul` 单源；`vfs.base` 已收敛 `VfsETagStrong/FNV + VfsNameCompare` 单源。
- `vfs L2` 允许依赖 `L0-L1`，但不应依赖 `compress/crypto L2` 形成 `L2→L2` 闭环。装饰器为 `L3`，单向依赖 `L2`，符合 `module-registry` 白名单与 `AGENTS.md` 依赖纪律。
- `http.static` 已单源 `CACHE_REVALIDATE` + 单遍 `EscapeDispositionFilename`，`Content-Encoding` 在此层做 `Vary` 协商最符合 `HTTP` 语义，`CDN` 可直接缓存。

## 后果

- **性能**：`STORE` 保持 `FBase+Offset` 零拷贝 `163ms`，压缩用户仅在装饰层付费。
- **高级感**：`vfs` 保持极简 `IVfs 4 方法 + CaseSensitive`，无 `codec` 分支污染。
- **复用度**：`List/Stat/Sub` 行为三后端完全一致，`VfsNameCompare/VfsETag*` 不漂移。
- **稳定性**：`budget` 溢出、`key` 落盘、`solid` 误用等风险隔离在装饰层，`conformance P1-P8 + heaptrc 0` 不受影响。
- **完整性**：`FORMAT.md` 保持 `CodecId=STORE` 单一，`9 门电池 + registry focused-runtime` 闭环；后续压缩/加密在 `core-vfs-decorators` 新 lane 演进。

## 备选已否决

- **内置**：`vfs` 内 `if Codec != STORE then 查 LRU → 解压 → 入池`，优点是调用方零改动，代价是所有 `STORE` 也付分支与常驻 `LRU`，`List` 需回答逻辑名/物理名、`ContentHash` 取明文/密文、`ETag` 漂移，`INV-V6/P8` 零拷贝断言被破坏。否决。
- **块级 solid**：压缩率最优但随机访问 `O(block)`，`Stat` 热路径回归 10~50×。否决。

## 后续

- S6-A `codec` 仅在 `respack.FORMAT` 预留 `CodecId`，`vfs` 仍 `STORE`。
- S6-B/C 在新 lane 提供 `vfs.compressed / vfs.encrypted` 装饰器（`16槽 32MB LRU + SpinLock` 复用现有池思想，明文 `ZeroMem` 淘汰），`main` 不回退完美基线。

## 约束

- 本 ADR 发布后，任何向 `core/src/nextpas.core.vfs.*` 增加 `compress/crypto` 依赖的改动必须先更新本 ADR 并经 `Needs Review`。
- `respack` 保持 ` STORE` 单一，直至装饰器 lane 证明 `budget` 与 `heaptrc` 达标。

# nextpas.core.zlib 代码契约

**模块路径**：`core/src/nextpas.core.zlib*.pas`（5 个源文件：base/intf/zlib888/ffi/pas，pure 为薄兼容）
**层级**：L2（依赖 L0-L1: base, exception, platform.dl, compress.base 语义复用）
**Owner**：AI（core-zlib lane）
**最后更新**：2026-08-31
**版本**：1.1（S1-S5 收敛）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| zlib.base | 基础类型与常量：`TZlibLevel`、`TZlibErrorCode`、`EZlibError`、Adler-32 常量与 `ZlibAdlerUpdate`、`ZlibLevelToZlib` |
| zlib.intf | 接口契约 `IZlibEncoder`/`IZlibDecoder` + 无状态 Adler 辅助 `ZlibAdler32*` |
| zlib.zlib888 | 纯 Pascal Deflate/Inflate：raw `-15` 与 zlib-wrapped `15` 双路径，32MiB 防 bomb，Adler 校验（302+ P6 的 111/634 性能，Stored 单块大块 Move） |
| zlib.pure | 薄兼容门面：`unit nextpas.core.zlib.pure; uses zlib888` 并 re-export 全量 public 符号（旧 uses 兼容） |
| zlib.ffi | libz 动态绑定 FFI 后端（`compressBound/compress2/uncompress/zlibVersion`，懒加载 `libz.so[.1]`） |
| zlib.pas | 门面四件套聚合 + `ZlibAuto` 后端选择与便捷函数（uses zlib888，pure 保留兼容） |

### 1.2 核心类型

```pascal
TZlibLevel = (zlNone, zlFastest, zlDefault, zlBest);
TZlibErrorCode = (zecInvalidArgument, zecCorruptStream, zecTruncated, zecUnsupported, zecLimitExceeded, zecInternal);
EZlibError = class(ENextPasError) // Category 映射 ecInvalidArgument/ecIO/ecNotSupported/ecResourceExhausted/ecInternal
IZlibEncoder = interface
  function Encode(const AData: TBytes): TBytes;
  function EncodeWithLevel(const AData: TBytes; const ALevel: TZlibLevel): TBytes;
  function Adler32(const AData: TBytes): LongWord;
  function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
end;
IZlibDecoder = interface
  function Decode(const AData: TBytes): TBytes;
  function DecodeWithLimit(const AData: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
  function Adler32(const AData: TBytes): LongWord;
  function Adler32Update(AAdler: LongWord; const AData: Pointer; ALen: SizeUInt): LongWord;
end;
TZlibBackend = (zbAuto, zbPurePascal, zbFfi);
```

### 1.3 核心函数与常量

| 函数/常量 | 说明 |
|-----------|------|
| `ZLIB_ADLER_INIT = 1` | Adler-32 初始值（RFC1950 §8.2） |
| `ZLIB_ADLER_MOD = 65521` | Adler 模数 |
| `ZLIB_ADLER_NMAX = 5552` | 分块取模阈值 |
| `ZLIB_MAX_DECOMPRESS_BYTES = 32MiB` | 解压上限单源（`compress.base GZIP_MAX_DECOMPRESS_BYTES` 别名，门面重导出 `ZLIB_MAX_DECOMPRESS_BYTES_ALIAS`） |
| `ZLIB_WINDOW_BITS_DEFAULT = 15` | zlib 包装 |
| `ZLIB_WINDOW_BITS_RAW = -15` | 裸流 |
| `ZlibAdlerUpdate(AAdler, AData, ALen): LongWord` | 增量 Adler，空输入原样返回 |
| `ZlibLevelToZlib(ALevel): Int32` | `zlNone->0, zlFastest->1, zlDefault->-1, zlBest->9` 委派 `compress.base LevelToZlib` 单源（零表拷贝） |
| `ZlibPureEncode/WithLevel`, `ZlibPureEncodeRaw*` | 纯 Pascal 编码（固定 Huffman + Stored 回退，窗口 32K，hash-chain） |
| `ZlibPureDecode/WithLimit`, `ZlibPureDecodeRaw*` | 纯 Pascal 解码（自动识别 wrapped/raw，Adler 校验，limit） |
| `ZlibFfiEncode/Decode*`, `ZlibFfiAvailable` | FFI 编解码与可用性探针；不可用时抛 `zecUnsupported` |
| `ZlibSetBackend / ZlibActiveBackend / ZlibFfiIsAvailable` | 后端选择：`zbAuto` 按 FFI 可用性降级 |
| `ZlibAcquireEncoder/Decoder` | 按当前后端的编解码器（纯/FFI） |
| `ZlibEncode/Decode*` `ZlibEncodeRaw/DecodeRaw*` | 门面便捷（inline 直达当前后端；Raw 固定走纯 Pascal） |
| `ZlibAdler/AdlerOf/AdlerUpdateWrap` | 门面 Adler 便捷 |
| `ZlibTryEncode*` `ZlibTryDecode*` (`WithError`/`WithLevel`/`WithLimit`) | 豪华 Try*：Bool 守卫 + WithError 诊断，门面直达当前后端 IZlibEncoder/Decoder 亦提供同族 |
| `ZlibPureEncode/Decode` `ZlibFfiEncodeWrap/DecodeWrap` | 直连探针便于回归 |

---

## 2. 不变量

- **[INV-Z1]** 级别映射委派至 `compress.base LevelToZlib` 单源（零表拷贝）：`zlNone=0, zlFastest=1, zlDefault=-1(Z_DEFAULT_COMPRESSION), zlBest=9`，`TryZlibLevelFromOrd` 保证 Ord 往返。
- **[INV-Z2]** Adler-32 与 RFC1950 一致：初值 1、分块 NMAX=5552 取模、空输入返回初值，增量语义与 `Crc32Update` 对齐。
- **[INV-Z3]** 单源解压上限：`ZLIB_MAX_DECOMPRESS_BYTES` 为 `compress.base GZIP_MAX_DECOMPRESS_BYTES` 别名（32MiB），任何 `Decode*WithLimit(0)` 或 `Decode*` 默认值收敛至该上限；超过抛 `EZlibError(zecLimitExceeded, 'zlib: decompressed size exceeds limit')`，映射 `ecResourceExhausted`。
- **[INV-Z4]** 编码输出为 RFC1950 zlib 包装（`header 2B + deflate + adler 4B`），空输入仍输出合法流（header+empty stored block+adler）；`zlNone` 强制 Stored（不压缩）路径。
- **[INV-Z5]** 解码双路径：`Decode` 自动识别 `IsValidZlibHeader` → wrapped（截去 2B 头与 4B adler 后 raw inflate + adler 校验）或 raw（直接 inflate）；`DecodeRaw` 强制 raw；截断/损坏/头非法/超限分别抛 `zecTruncated`/`zecCorruptStream`/`zecLimitExceeded`。
- **[INV-Z6]** Adler 强制校验：wrapped 路径解后计算 `ZlibAdlerUpdate(INIT, decoded)` 与尾部 4B 大端比较，不符抛 `zecCorruptStream('adler mismatch')`；空解码结果 adler 取 INIT。
- **[INV-Z7]** FFI 懒加载零硬依赖：`ZlibFfiAvailable` 首次调用 `platform.dl` 探针 `libz.so.1/.so/.so.1.0` 的 `compressBound/compress2/uncompress/zlibVersion` 四符号齐全才可用；`NEXTPAS_USE_ZLIB_NATIVE` 静态分支供编译期验证；不可用时 `ZlibFfiEncode/Decode` 抛 `zecUnsupported('libz not available')`，`zbAuto/zbFfi` 自动回落纯 Pascal。
- **[INV-Z8]** 后端选择与 facades：`zbPurePascal` 固定纯、`zbFfi` 按可用性降级、`zbAuto` 按 FFI 可用性自动切换；`ZlibEncodeRaw*` 固定走纯 Pascal 避免 FFI raw 不支持分歧；`compress.deflate/gzip` 保持薄转发（仍经 paszlib），`sevenz.coders` 可经 `IZlibEncoder/Decoder` 复用。
- **[INV-Z9]** 纯度与并发：纯 Pascal 编解码器无全局可变状态（固定表 `GFixed*` 双检锁惰性初始化 + `Interlocked`，`GFixedReady LongInt+GFixedLock`/`GOnceDone LongInt+GOnceLock` 两把临界区）、FFI 编解码器无共享状态；一次性函数与 Try* 均为纯函数，并发安全由调用方保证；Try* 族捕获异常返回 Bool/`AError`，不抛异常。
- **[INV-Z10]** 窗口与头校验：`ZLIB_CMF_DEFLATED=$08`、`ZLIB_CMF_WINDOW_MASK=$F0` 掩码仅作载体，`IsValidZlibHeader` 校验 `CMF 高 4bit <=7`、`mod 31 ==0`、`FDICT bit($20)==0`。

---

## 3. 错误处理

| 场景 | 异常 | Code | Category |
|------|------|------|----------|
| 截断流（头不足 6B、stored LEN 不足、bit 不足） | `EZlibError('zlib: truncated stream')` | `zecTruncated` | `ecIO` |
| 损坏流（非法 Huffman、距离超限、stored 异或校验失败、header 非 deflate） | `EZlibError('zlib: corrupt stream')` | `zecCorruptStream` | `ecIO` |
| Adler 不匹配 | `EZlibError('zlib: adler mismatch')` | `zecCorruptStream` | `ecIO` |
| 超过 32MiB 或自定义 Max | `EZlibError('zlib: decompressed size exceeds limit')` | `zecLimitExceeded` | `ecResourceExhausted` |
| libz 不可用 / FFI raw 不支持 | `EZlibError('libz not available'/'raw not supported')` | `zecUnsupported` | `ecNotSupported` |
| 内部长度/距离符号失败 | `EZlibError('zlib: length/dist sym fail')` | `zecInternal` | `ecInternal` |

全部继承 `EZlibError ← ENextPasError`，不触碰 `SysUtils` 异常体系。

---

## 4. 线程安全

- 一次性函数（`ZlibPure*`/`ZlibFfi*`/`ZlibEncode/Decode*`）：✅ 纯函数，调用方并发安全
- 接口实例（`IZlibEncoder/Decoder`）：❌ 非线程安全，单实例单线程；多线程各取各的 `CreateZlibPure*`/`ZlibAcquire*`
- 全局后端选择 `GRequested` 与缓存 `GPureEncoder/GFfiEncoder`：写 `ZlibSetBackend` 需在启动期配置，运行期并发写未定义

---

## 5. 内存管理

- 编码：按 `DeflateEncodeRaw` 估计 `Len+16` 预分配 `BwInit`，`GrowBytes` 按 `ZLIB_MAX_DECOMPRESS_BYTES` 为上限几何扩容；
- 解码：`GrowBytes` 按 `AMax`（默认 32MiB）为上限几何扩容（`0→64` 起步，`x2` 直至上限，否则抛 `LimitExceeded`）；
- 一次性函数返回新 `TBytes`，调用方持有；FFI 路径按 `compressBound` 预分配 `LB` 并按 `Z_BUF_ERROR` 倍增至 `AMax`；
- 空输入编码仍分配合法流（`2+2~4` 定形），空解码返回 `nil`（零分配语义）。

---

## 6. 性能契约（S5 基准校准，1MiB 语料）

| 操作 | 目标 | 实测（x86_64 Linux, -O3） |
|------|------|---------------------------|
| zlib888 encode default 1MiB | ≥ 5 MB/s | 见 `bench_zlib`（`zlib pure encode default` 行，pure 为 thin compat 指向 zlib888） |
| zlib888 decode 1MiB | ≥ 20 MB/s | 见 `bench_zlib`（`zlib pure decode` 行，pure 兼容） |
| ffi encode 1MiB（可用时） | ≥ zlib888 | 同 `bench_zlib ffi` 行 |
| ffi decode 1MiB（可用时） | ≥ zlib888 | 同 `bench_zlib ffi` 行 |
| raw 路径 | 与 wrapped 同阶 | `bench_zlib raw` 行 |

基准入口：`make -C core/benchmarks/nextpas.core.zlib/bench_zlib run`

---

## 7. 测试覆盖（S5 实测校准，2026-08-30）

| 测试目录 | 用例数 | 说明 |
|----------|--------|------|
| `test_zlib` | 30 | adler/empty/store/bomb、raw/wrapped、level 0/1/2/3、32MiB 限、FFI vs zlib888 交叉（pure thin compat）；`TTestSuite` + heaptrc 0 |

30 用例清单：`adler_empty_is_init`、`adler_single_byte_A`、`adler_incremental_matches_one_shot`、`adler_wrapped_vs_raw_consistent`、`empty_wrapped_roundtrip`、`empty_raw_roundtrip`、`empty_wrapped_produces_header_and_adler`、`store_zlNone_roundtrip_1KB`、`store_zlNone_len_greater_than_input`、`level_fastest/default/best_roundtrip`、`level_none_is_stored_not_deflated`、`wrapped/raw_encode_decode_roundtrip_256KB`、`wrapped_decode_accepts_wrapped`、`wrapped_decode_fallback_accepts_raw`、`raw_decode_of_wrapped_not_equal`、`truncated/corrupt/adler_mismatch_raises`、`bomb_default_limit_32MiB_exceeded`、`bomb_custom_small_limit_raises`、`bomb_exact_limit_passes`、`bomb_raw_limit_enforced`、`ffi_available_check`、`ffi_pure_cross_both_directions`、`facade_auto_roundtrip_1MiB`、`facade_raw_wrapped_separation`

---

## 8. 源契约

生产单元（`core/src/nextpas.core.zlib*.pas`）不得直接 `uses SysUtils` 以外 FPC RTL 杂货；`platform.dl` 为唯一 OS 缝，`compress.base` 语义仅复用不拷贝 paszlib。门面只做 re-export 与 inline 转发。

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-26 | 0.1 | S1 base/intf 定稿 | AI |
| 2026-08-27 | 0.5 | S2-S3 pure inflate/deflate 收敛 | AI |
| 2026-08-28 | 0.8 | S4 ffi + facade ZlibAuto | AI |
| 2026-08-30 | 1.0 | S5 收敛：六维（base/intf+pure+ffi+facade+contracts+tests/bench）完整，30 用例 + bench_zlib + registry | AI |
| 2026-08-31 | 1.1 | 重命名 pure→zlib888（302+ P6 的 111/634 性能保留），pure 薄兼容保留；zlNone Stored 单次大块 Move 优化（bench none 546→865+） | AI |

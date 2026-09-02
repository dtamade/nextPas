# nextpas.core.id 代码契约

**模块路径**：`core/src/nextpas.core.id*.pas`（10 个源文件：`id.base` / `id.rng` / `id.uuid` / `id.v7.monotonic` / `id.snowflake` / `id.ksuid` / `id.xid` / `id.ulid` / `id.nanoid` / `id.pas` 门面，~1700 行）
**层级**：L1（依赖 L0: base, bytes, atomic, errors, hash, platform.random/time/thread, text.conv）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1（单源熵 + inline 零拷贝门面 + 四件套 L0-L3 冻结）

---

## 1. 接口契约

### 1.1 子模块地图（四件套 `base ← rng/实现 ← 门面`）

| 文件 | 层 | 职责 |
|------|----|------|
| `id.base` | base | `TUuidString`/`TUlidString`/`TNanoIdString` 别名，`UUID_LENGTH=36`/`ULID_LENGTH=26`/`NANOID_DEFAULT_LENGTH=21`/`NANOID_MAX_LENGTH=4096`/`NANOID_DEFAULT_ALPHABET` 常量 |
| `id.rng` | L1 内核 | 熵单源：4KB `GBuf` + `GLock` 原子锁，`IdRngFillBytes`/`IdRngReseed`；底层 `platform_random_bytes`，失败抛 `EIOError` |
| `id.uuid` | 实现 | `TUuid` 记录（`FBytes[0..15]`）+ `NewV4`/`NewV7`/`NewV7At`/`NewV5`/`Parse`/`TryParse`/`Nil_`/`Max`/`ToString`/`ToStringNoDash`/`ToURN`/`Version`/`Variant`/`IsNil`/`TimestampMs`/`Hash`/`CompareTo`；`UuidV4`/`UuidV7`/`UuidParse`/`UuidIsValid` 自由函数 |
| `id.v7.monotonic` | 实现 | `TUuidV7Generator`（`FLastMs`/`FRandA`）+ 全局 `GlobalV7Gen` + `UuidV7Monotonic`/`UuidV7MonotonicRaw`（同毫秒严格单调，`GV7Lock` 原子互斥） |
| `id.snowflake` | 实现 | `TSnowflakeId=Int64` + `TSnowflakeGenerator`（`FInitialized`/`FEpochMs`/`FWorkerId`/`FLastMs`/`FSequence`）+ `Init`/`Next`/`Extract`；`SNOWFLAKE_EPOCH_TWITTER/DISCORD` |
| `id.ksuid` | 实现 | `TKsuid`（`FBytes[0..19]`，前 4B 时间戳 + 16B 随机）+ `New`/`NewAt`/`Parse`/`TryParse`/`Nil_`/`Timestamp`/`TimestampUnix`/`CompareTo` + `KSUID_EPOCH=1400000000`/`KSUID_STRING_LENGTH=27` Base62 |
| `id.xid` | 实现 | `TXid`（`FBytes[0..11]`）+ `New`/`Parse`/`TryParse`/`Nil_`/`Timestamp`/`CompareTo` + `XID_STRING_LENGTH=20` Crockford-like Base32-hex；`GMachineId[3]`/`GCounter`/`GNewLock`/`GLastTs`/`GLastCnt` 单调保证 |
| `id.ulid` | 实现 | `Ulid`/`UlidFromTimestamp`/`UlidIsValid`/`UlidTimestampMs`/`UlidTryTimestampMs`（48bit 时间戳 + 80bit 随机，Crockford Base32，大小写不敏感） |
| `id.nanoid` | 实现 | `NanoId`/`NanoIdCustom`（`mask` 拒绝采样，`AAlphabet` 2..256 去重校验，`ASize` 1..4096，`LMaxAttempts = ASize*64+1024` 进度守卫） |
| `id.pas` | 门面 | 纯 re-export + `inline` 转发：`UuidV4/V7/V7Monotonic/V7MonotonicRaw/UuidParse/UuidIsValid/Ulid/UlidFromTimestamp/UlidIsValid/UlidTimestampMs/UlidTryTimestampMs/NanoId/NanoIdCustom/KsuidNew/KsuidIsValid/KsuidTimestampUnix/KsuidTryTimestampUnix/XidNew/XidIsValid/XidTimestamp/XidTryTimestamp` |

> **四件套与 L0-L3**：`id.base` 为基类→ `id.rng`/`uuid`/`ulid`/`nanoid`/`ksuid`/`xid`/`snowflake`/`v7.monotonic` 为实现→ `id.pas` 门面仅类型别名 + `inline` 转发；只向下依赖 L0（`base/bytes/atomic/errors/platform/hash/text`），禁止同层循环与跨层反向。

### 1.2 核心类型

```pascal
TUuid = record FBytes: array[0..15] of Byte; ... end;
TKsuid = record FBytes: array[0..19] of Byte; ... end;
TXid = record FBytes: array[0..11] of Byte; ... end;
TSnowflakeId = Int64;
TSnowflakeGenerator = record FInitialized: Boolean; FEpochMs: Int64; FWorkerId: UInt16; FLastMs: Int64; FSequence: UInt16; end;
TUuidV7Generator = record FLastMs: UInt64; FRandA: UInt16; end;
TUuidString = string; TUlidString = string; TNanoIdString = string;
```

### 1.3 门面 inline/零拷贝

- `nextpas.core.id.pas` 全部自由函数标记 `inline`，零额外栈拷贝，单源转发至实现单元（`nextpas.core.id.uuid.UuidV4` 等）；类型/常量亦为别名转发，无重复定义。
- 字符串操作零拷贝语义：`TUuid.ToStringNoDash`/`ToString` 直写 32/36 字符；`Ulid`/`Ksuid`/`Xid` 的 `ToString` 直写固定长度；`TryParse` 失败必保持 `out` 参数不丢（`Xid`/`Ksuid` 失败不暴露半解析字节，见门禁 `test_id_facade_*_contract`）。
- 字节比较/拷贝复用 `bytes.ops` 单源语义：`TUuid.Equals/CompareTo`、`TKsuid.CompareTo`、`TXid.CompareTo` 逐字节字典序，等价 `SpanEqual/SpanCompare`（L1 `bytes.ops` 单源，不在 `id` 内重复实现 `MemEqual` 分支）；`FromBytes/ToBytes` 走 `Move` 零拷贝。

### 1.4 RNG 单源与资源释放不丢

- 单源熵：所有随机路径（`uuid/ulid/nanoid/ksuid/xid/v7.monotonic`）统一经 `IdRngFillBytes`，4KB 缓冲按需 `Refill`（`platform_random_bytes`），`GLock` 以 `atomic_compare_exchange_strong(mo_acquire)` + `CpuPause` 自旋，`try..finally atomic_store(mo_release)` 保证锁释放不丢。
- `FillBytesFromCache` 循环 `Move` 零拷贝分片；大于缓冲的请求经临时 `TBytes` 落地再 `Move`，不泄漏。
- `EnsureXidSeeded` 双检锁（`GXidInitState` 0→1→2，失败回滚至 0 释放不丢）；`TXid.New` 以 `GNewLock` 互斥 + `atomic_fetch_add(GCounter)` 保证全局单调，`try..finally` 释放锁。

### 1.5 算法要点

| 算法 | 位宽/编码 | 时间排序 | RFC/规范 |
|------|-----------|----------|----------|
| UUID v4 | 128-bit / 36 char | ❌ | RFC 9562 §5.4，`FBytes[6] & $0F | $40`，`FBytes[8] & $3F | $80` |
| UUID v7 | 128-bit / 36 char | ✅ | RFC 9562 §5.7，前 48bit 毫秒时间戳 |
| UUID v7 Mono | 128-bit / 36 char | ✅ 严格 | 同毫秒 `FRandA +1`，溢出进位毫秒 |
| UUID v5 | 128-bit / 36 char | ❌ | RFC 9562 §5.3，`SHA1(namespace+name)`，version 5 |
| ULID | 128-bit / 26 char | ✅ | 48bit 时间 + 80bit 随机，Crockford Base32 |
| NanoID | 可变21/26 | ❌ | `mask = 2^n-1` 拒绝采样，URL 安全 |
| Snowflake | 64-bit / Int64 | ✅ | 41bit delta + 10bit worker + 12bit seq，`42/22/12` 移位 |
| KSUID | 160-bit / 27 char | ✅ | 32bit 秒级时间戳（`KSUID_EPOCH=1400000000`）+ 128bit 随机，Base62 |
| XID | 96-bit / 20 char | ✅ | 32bit 秒 + 24bit machine + 16bit pid + 24bit counter，Base32-hex `0123456789abcdefghijklmnopqrstuv` |

---

## 2. 不变量

- **[INV-1]** `TUuid/ TKsuid/ TXid/ TSnowflakeId` 均为值类型，无堆分配；比较为逐字节字典序。
- **[INV-2]** UUID v4/v7 的 `Version/Variant` 位固定（v4=4/v7=7，variant=2 `10xx`）；`TimestampMs` 仅 v7 非零且 ≤ `2^48-1`。
- **[INV-3]** ULID 首字符 `CrockfordVal <=7`（48bit 约束），大小写不敏感；`UlidFromTimestamp` 越界抛 `EOutOfRange`。
- **[INV-4]** KSUID Base62 编码恰好 27 字符，160bit 上界溢出 `TryParse` 返回 False（`z`×27 溢出），`Parse` 抛 `EParseError`。
- **[INV-5]** XID Base32-hex 解码表 `GXidDecodeTable[0..127]` 单源初始化，末字符低 4bit 必须为 0（`LBuf[19] & $0F =0`），counter 24bit 掩码 `XID_COUNTER_MASK=$FFFFFF`。
- **[INV-6]** Snowflake `workerId ≤1023`、`epoch ≥0`，`delta ≤ 2^41-1`，时钟回拨自旋等待（`platform_thread_yield`），同毫秒 `sequence` 溢出进位至下一毫秒。
- **[INV-7]** `TUuidV7Generator` 同毫秒严格单调：`FRandA+1` 溢出 `> $0FFF` 则毫秒进位并重取随机。
- **[INV-8]** NanoID `alphabet` 去重且 2..256，`ASize` 1..4096，熵流无进展达 `ASize*64+1024` 次尝试抛 `EIOError`。
- **[INV-9]** 熵单源：`IdRngFillBytes(ALen=0)` 空操作成功；`ABuf=nil && ALen>0` 抛 `EArgumentNil`；`ALen > High(SizeInt)` 抛 `EArgumentError`；`platform_random_bytes` 失败抛 `EIOError`。
- **[INV-10]** 四件套/L0-L3：`id.pas` 仅 inline 转发，不新增逻辑；`bytes.ops` 单源复用字节比较/拷贝，不在 `id` 内二度实现。
- **[INV-11]** 资源释放不丢：所有原子锁（`GLock/GNewLock/GXidInitState/GV7Lock`）均 `try..finally atomic_store(0, mo_release)`，`FillBytesFromCache` 非异常路径无泄漏。

---

## 3. 错误处理

| 场景 | 异常/返回值 |
|------|-------------|
| `TUuid.Parse` 长度≠36 或缺 `-` 或 hex 非法 | 抛 `EParseError` |
| `TUuid.TryParse` 失败 | 返回 False，`out` 保持调用方原值（不暴露半解析） |
| `TUuid.NewV7At` / `UlidFromTimestamp` 超 48bit | 抛 `EOutOfRange` |
| `KSUID` Base62 非法字符或溢出 | `TryParse=False`，`Parse` 抛 `EParseError` |
| `XID` 长度≠20 或字符非法或末 4bit 非零或含 ≥128 高字节 | `TryParse=False`，`Parse` 抛 `EParseError` |
| `NanoIdCustom` 非法 alphabet/size | 抛 `EArgumentError`；熵流停滞抛 `EIOError` |
| `Snowflake.Init` worker>1023/epoch<0/clock<epoch/delta>2^41 | 抛 `EArgumentError`/`EInvalidOperationError`/`EOutOfRange`；`Extract` 非法入参返回 False |
| `Snowflake.Next` 未初始化 | 抛 `EInvalidOperationError` |
| `TUuidV7Generator.Next` 时间>48bit 或逻辑时间>48bit | 抛 `EOutOfRange` |
| `IdRngFillBytes` nil 目的/超长/底层失败 | `EArgumentNil`/`EArgumentError`/`EIOError` |
| `TXid.New` 逻辑时间超 `High(UInt32)` | 抛 `EOutOfRange` |

---

## 4. 线程安全

| 单元/函数 | 线程安全 | 说明 |
|-----------|----------|------|
| `IdRngFillBytes` / `IdRngReseed` | ✅ | `GLock` 原子互斥，4KB 缓冲并发安全 |
| `TUuid.NewV4/NewV7/NewV5` / `Ulid` / `NanoId` / `TKsuid.New` | ✅ | 经 `IdRngFillBytes` 间接安全 |
| `TXid.New` | ✅ | `EnsureXidSeeded` 双检锁 + `GNewLock` + `GLastTs/GLastCnt` 互斥保证单调 |
| `UuidV7Monotonic` / `UuidV7MonotonicRaw` | ✅ | `GV7Lock` 全局互斥，`GlobalV7Gen` 单调 |
| `TUuidV7Generator.Next` | ❌ | 实例级非原子，调用方外同步 |
| `TSnowflakeGenerator.Next` | ❌ | 实例级 `FLastMs/FSequence`，调用方外同步 |
| 纯函数（`Parse/TryParse/ToString/IsNil/CompareTo/Hash`） | ✅ | 无共享可变状态 |

---

## 5. 内存管理

- 所有 ID 记录为值语义栈上拷贝，无堆分配；`ToString` 返回新 `string`（恰好长度分配），`ToStringNoDash/ToURN` 同理。
- `IdRngFillBytes` 大请求经 `TBytes` 临时缓冲 `SetLength`/`Move` 后即释放，无常驻泄漏；`Xid/KSUID` 的 Base62/Crockford 编解码使用栈上 `LSrc/LTmp/LBuf` 固定数组，零堆分配热路径。
- 失败路径 `TryParse` 不分配；`IdRng`/`Xid` 初始化失败回滚状态并释放锁，资源释放不丢。

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| `test_id` | 主门面：UUID/ULID/NanoID/v7/Snowflake/KSUID/XID 生成+解析+排序+边界+stress 10k |
| `test_uuid` | `TUuid` 记录级：Parse/Equals/Compare/Hash/NoDash/Roundtrip |
| `test_id_facade_*` / `test_id_rng_failure_contract` / `test_id_killer` | 门面+熵源契约：startup 零熵可用性、故障注入、killer |
| `test_snowflake_*` / `test_uuid_v7_*` / `test_xid_counter_wrap_contract` / `test_nanoid_*` / `test_ksuid_*` / `test_ulid_*` | 算法边界：时钟回拨、序列溢出、48/41bit 溢出、Base62/32 编解码、mask 拒绝采样 |
| **合计** | **17 个测试目录** |

执行：

```bash
make -C core/tests/nextpas.core.id/test_id clean test
make focused FOCUS=core/tests/nextpas.core.id/test_uuid_v7_monotonic_clock_contract
scripts/id-contract-check.sh   # 源文件/算法/门面+测试 门禁
```

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-30 | 1.1 | 单源熵+inline 零拷贝门面冻结：`bytes.ops` 单源复用字节比较/拷贝，门面全 `inline` 转发，`TryParse` 失败不丢 out，熵/锁 `try..finally` 释放不丢；KSUID/XID/ULID/Snowflake/v7 单调不变量与错误表对齐实现，补 17 目录门禁与变更记录 | Claude |
| 2026-07-01 | 1.0 | 初始版本：10 文件门面骨架与核心类型 | Claude |

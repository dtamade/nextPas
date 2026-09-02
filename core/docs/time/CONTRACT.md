# nextpas.core.time 代码契约

**模块路径**：`core/src/nextpas.core.time*.pas`（18 个源文件）
**层级**：L1（依赖 L0: base / errors / platform.time / platform.thread）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1
**四件套**：`time.base`（类型载体）← `time.<impl>`（纯实现）← `time.pas`（门面 re-export + inline 转发）；无 `time.intf`/`time.ffi`（无对外 interface 契约与无独立 foreign ABI，跨平台统一经 `platform.time`/`platform.thread` 单源）

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 类型 | 职责 |
|------|------|------|
| time.base | TDuration, TInstant / NS_PER_* 常量 | 时间基础类型（纳秒 Int64 饱和算术，UInt64 单调时钟） |
| time.date | TDate, TDayOfWeek | 日期（JulianDay Int32 存储，公历分解，闰年/DayOfWeek/DayOfYear） |
| time.timeofday | TTimeOfDay | 日内时间（FNanos Int64，纳秒精度，环形 0..NS_PER_DAY-1） |
| time.datetime | TNaiveDateTime | 日期+时间（无时区，FDate+FNanosOfDay） |
| time.offsetdatetime | TOffsetDateTime | 带偏移日期时间（FDateTime+TUtcOffset，UnixNs 互转） |
| time.timezone | TUtcOffset | 时区偏移（秒 Int32，UTC/Local，±18h 校验） |
| time.iso8601 | — | ISO 8601 解析/格式化（含 RFC3339 UTC + offset 变体） |
| time.format | — | 自定义格式化（`%Y/%m/%d%H%M%S%f%z%aAb` DoFormat） |
| time.httpdate | — | HTTP 日期（IMF-fixdate + RFC850/ANSIC 三形态，RFC 7231 §7.1.1.1） |
| time.bucket | — | UTC 时间桶键（epoch 秒 div 桶宽 → 定宽补零，字典序=时间序） |
| time.deadline | TDeadline, TDeadlineKind | 截止时间（dkFinite/dkInfinite，相对/绝对） |
| time.sleep | TSleep, MsSleep | 线程休眠（ForDuration/Until_/MsSleep） |
| time.stopwatch | TStopwatch | 高精度秒表（单调时钟，累计语义） |
| time.timer | TTimer, TTimerState | 一次性定时器（Arm/ArmAt/Cancel/Poll） |
| time.ticker | TTicker, TTick | 固定间隔 tick（Every/Poll，fixed-rate 补跳） |
| time.period | TPeriod | 周期（Y/M/D，ISO 8601 Period） |
| time.cpu | — | CPU/线程时间（CpuRelax/SchedYield/NanoSleep/GetTickCount64） |
| time.pas | — | 门面（类型别名 + inline 转发，零额外分配） |

> **设计约束**：L0-L3 单向依赖，time 仅依赖 L0；`bytes.ops` 单源复用（字符串/字节构造复用 `bytes.ops` 与 `text.conv` 单源，不在 time 内重复实现）；门面与小粒度方法 `inline` 零拷贝转发；记录值语义无堆资源，`TTimer/TTicker/TStopwatch` 均为 `record`，无 `Create/Destroy` 泄漏，休眠/平台调用不持有需释放句柄，未来若持有句柄则 `try-finally` 保证释放不丢。

### 1.2 核心类型

```pascal
TDuration = record // FNs: Int64 纳秒，饱和到 DURATION_MIN/MAX，≈±292年
  class function Zero: TDuration; static; inline;
  class function MaxValue/MinValue: TDuration; static; inline;
  class function FromNanoseconds/Microseconds/Milliseconds/Seconds/Minutes/Hours/Days(const V: Int64): TDuration; static;
  function AsNanoseconds/AsMicroseconds/AsMilliseconds/AsSeconds: Int64; inline;
  function AsSecondsF/AsMinutesF/AsHoursF: Double; inline;
  function IsZero/IsPositive/IsNegative: Boolean; inline;
  function Abs/Negate: TDuration; inline;
  function Add/Sub(const AOther: TDuration): TDuration; // 饱和
  function Mul(const AFactor: Int64): TDuration; function DivBy(const ADivisor: Int64): TDuration; // 0 抛 EInvalidOperationError
  function ToString: string; // 阈值分档  ns/us/ms/s
  function Truncate/Round(const AUnit: TDuration): TDuration;
  class operator +/-(A,B: TDuration): TDuration; inline;
  class operator *(A: TDuration; B: Int64): TDuration; inline;
  class operator =/</>/<=/>= (A,B: TDuration): Boolean; inline;
end;

TInstant = record // FNs: UInt64 单调纳秒
  class function Now: TInstant; static; // platform_monotonic_ns
  function Elapsed: TDuration; inline;
  function DurationSince(const AEarlier: TInstant): TDuration; // 饱和到 Int64 极值
  function Add/Sub(const ADuration: TDuration): TInstant;
  class operator -(A,B: TInstant): TDuration; inline;
  class operator =/</>(A,B: TInstant): Boolean; inline;
end;

TDate = record // FJulianDay: Integer
  class function Create(AYear,AMonth,ADay: Integer): TDate; static; // 校验 1..9999
  class function TryCreate(AYear,AMonth,ADay: Integer; out ADate: TDate): Boolean; static;
  class function FromJulianDay/FromUnixDays(AValue: Integer): TDate; static; inline;
  function ToJulianDay/ToUnixDays: Integer; inline;
  function GetYear/GetMonth/GetDay: Integer; function GetDayOfWeek: TDayOfWeek; function GetDayOfYear/GetQuarter: Integer;
  function IsLeapYear: Boolean; function DaysInMonth/DaysInYear: Integer; function IsWeekend: Boolean;
  function AddDays(ADays: Integer): TDate; inline; function AddMonths/Years(ADelta: Integer): TDate;
  function DaysBetween/DaysUntil(const AOther: TDate): Integer; inline;
  function StartOfMonth/EndOfMonth/StartOfYear/EndOfYear: TDate;
  class operator +/-(ADate: TDate; ADays: Integer): TDate; class operator -(A,B: TDate): Integer;
  function ToISO8601/ToString: string; // yyyy-mm-dd
  class function Today: TDate; static; // platform_realtime_ns + utc_offset
end;

TTimeOfDay = record // FNanos: Int64 0..NS_PER_DAY-1 环绕
  class function Create(AHour,AMinute,ASecond,ANanosecond: Integer): TTimeOfDay; static;
  class function TryCreate(...; out ATime: TTimeOfDay): Boolean; static;
  class function FromNanoseconds(ANanos: Int64): TTimeOfDay; static; // mod 日
  class function Midnight/Noon/MinValue/MaxValue: TTimeOfDay; static; inline;
  function ToNanoseconds: Int64; inline;
  function GetHour/GetMinute/GetSecond/GetMillisecond/GetSubsecondNanos: Integer;
  function AddNanoseconds/Seconds/Minutes/Hours(ADelta: Int64/Integer): TTimeOfDay;
  function DurationUntil/DurationSince(const AOther: TTimeOfDay): TDuration; // 环形 mod
  class operator +(ATime: TTimeOfDay; ADur: TDuration): TTimeOfDay;
  class operator -(ATime: TTimeOfDay; ADur: TDuration): TTimeOfDay;
  class operator -(A,B: TTimeOfDay): TDuration;
  function ToISO8601: string; // 阈值裁剪毫秒/微秒/纳秒
end;

TNaiveDateTime = record // FDate: TDate + FNanosOfDay: Int64
  class function Create(AY,M,D,H,Min,S: Integer; ANs: Integer=0): TNaiveDateTime; static;
  class function FromDateAndTime(const ADate: TDate; const ATime: TTimeOfDay): TNaiveDateTime; static; inline;
  function GetDate/GetTime: TDate/TTimeOfDay; function GetYear/Month/Day/Hour/Minute/Second/Nanosecond: Integer; inline;
  function AddDays(ADays: Integer): TNaiveDateTime; function AddDuration/SubDuration(const ADur: TDuration): TNaiveDateTime;
  function DurationUntil/Since(const AOther: TNaiveDateTime): TDuration;
  function WithDate/WithTime(const ANew: TDate/TTimeOfDay): TNaiveDateTime; inline;
  function ToISO8601: string; // yyyy-mm-ddTHH:MM:SS[.frac] 尾零裁剪
end;

TUtcOffset = record // FSeconds: Int32
  class function UTC: TUtcOffset; static; inline;
  class function FromSeconds(const ASeconds: Int32): TUtcOffset; static; inline;
  class function FromHoursMinutes(AHours,AMinutes: Integer): TUtcOffset; static; // ±18h 校验 EArgumentError
  class function Local: TUtcOffset; static; // platform_utc_offset_seconds
  function TotalSeconds/TotalMinutes/Hours/Minutes: Int32/Integer; inline;
  function IsUtc: Boolean; inline; function ToString: string; // Z / ±HH:MM
end;

TOffsetDateTime = record // FDateTime: TNaiveDateTime + FOffset: TUtcOffset
  class function Now/NowUtc: TOffsetDateTime; static;
  class function Create(const ADateTime: TNaiveDateTime; const AOffset: TUtcOffset): TOffsetDateTime; static;
  class function FromUnixSeconds/Millis/Nanos(const V: Int64): TOffsetDateTime; static;
  function GetDateTime/GetOffset/GetDate/GetTime/GetYear/...: ...; inline;
  function ToUtc/ToOffset(const ANewOffset: TUtcOffset): TOffsetDateTime;
  function ToUnixSeconds/Millis/Nanos: Int64;
  function Add/Sub(const ADuration: TDuration): TOffsetDateTime;
  function DurationUntil(const AOther: TOffsetDateTime): TDuration;
  function ToISO8601: string; // naive + offset
end;

TPeriod = record // FYears/FMonths/FDays: Integer
  class function Zero/Create/OfYears/OfMonths/OfDays(...): TPeriod; static;
  class function ParseISO8601/TryParseISO8601(const AStr: string): TPeriod/Boolean; static; // P[nY][nM][nD]
  function GetYears/Months/Days: Integer; inline; function IsZero: Boolean; inline; function Negate: TPeriod;
  function AddTo(const ADate: TDate): TDate; overload; function AddTo(const ADateTime: TNaiveDateTime): TNaiveDateTime; overload;
  function ToISO8601/ToString: string;
end;
```

### 1.3 ISO 8601 / 格式化 / HTTP 日期 / 桶

```pascal
function ParseISO8601Date(const AStr: string): TDate; function TryParseISO8601Date(const AStr: string; out ADate: TDate): Boolean;
function ParseISO8601Time(const AStr: string): TTimeOfDay; function TryParseISO8601Time(const AStr: string; out ATime: TTimeOfDay): Boolean;
function ParseISO8601DateTime(const AStr: string): TNaiveDateTime; function TryParseISO8601DateTime(const AStr: string; out ADT: TNaiveDateTime): Boolean;
function ParseISO8601DateTimeOffset(const AStr: string): TOffsetDateTime; function TryParseISO8601DateTimeOffset(const AStr: string; out ADT: TOffsetDateTime): Boolean;
function FormatISO8601UTC(const AUnixSeconds: Int64): string; // 'YYYY-MM-DDTHH:MM:SSZ' 定长20，civil_from_days 纯整数，非负校验
// format: %Y %m %d %H %M %S %f(9位纳秒) %z %a%A %b %%，重载 for TOffsetDateTime / TDateTime / TDate / TTimeOfDay
function FormatDateTime(const APattern: string; const ADT: TOffsetDateTime): string; overload;
function FormatDateTime(const APattern: string; const ADT: TDateTime): string; overload;
function FormatDate(const APattern: string; const ADate: TDate): string;
function FormatTime(const APattern: string; const ATime: TTimeOfDay): string;
// httpdate: RFC 7231 IMF-fixdate 主路径 + RFC850/ANSIC fallback，零依赖 TDateTime
function FormatHttpDate(const AUnixTimestamp: Int64): string;
function TryParseHttpDate(const ADate: string; out AUnix: Int64): Boolean;
// bucket: UTC 时间桶，纯整数 div，定宽补零，字典序=时间序
function TimeBucketKey(const AUnixSeconds: Int64; const ABucketSeconds: Int64 = 3600; const AWidth: Integer = 12): string;
```

### 1.4 定时器/计时器/休眠/CPU

```pascal
TStopwatch = record // FStarted/FRunning/FStart/FAccumulated，累计语义
  class function Create: TStopwatch; static; // 零态
  class function StartNew: TStopwatch; static;
  procedure Start; // 已运行则 no-op
  procedure Stop;  // 累加 DurationSince(FStart)
  procedure Reset; // 清零并停止
  procedure Restart; // 清零并重启
  function Elapsed: TDuration; // 运行中 = Accumulated + Now-FStart
  function ElapsedMilliseconds: Int64; inline;
  function IsRunning: Boolean; inline;
end;

TDeadlineKind = (dkFinite, dkInfinite);
TDeadline = record // FKind + FAt: TInstant
  class function At(const AInstant: TInstant): TDeadline; static;
  class function After(const ATimeout: TDuration): TDeadline; static; // <=0 即 Expired
  class function Infinite: TDeadline; static; class function Expired: TDeadline; static;
  function IsInfinite: Boolean; inline; function IsExpired: Boolean; inline; // Infinite 永不过期
  function TimeUntil: TDuration; // Infinite→MaxValue，可为负（已过期）
  function Remaining: TDuration; // Infinite→MaxValue，过期钳至 Zero
  function ToInstant(out AInstant: TInstant): Boolean; // Infinite→False
  class function Min(const A,B: TDeadline): TDeadline; static;
  class operator =(A,B: TDeadline): Boolean;
end;

TTimerState = (tsIdle, tsArmed);
TTimer = record // FState + FDeadline，单次 one-shot Poll 消抖
  class function Create: TTimer; static; class function After(const ADelay: TDuration): TTimer; static;
  procedure Arm(const ADelay: TDuration); procedure ArmAt(const ADeadline: TDeadline); procedure Cancel;
  function IsArmed: Boolean; inline; function GetDeadline: TDeadline; inline;
  function Poll: Boolean; // 到期返回 True 并自动 disarm (Idle+Infinite)
end;

TTick = record ScheduledAt, ObservedAt: TInstant; LateBy: TDuration; Missed: UInt64; end;
TTicker = record // FRunning/FInterval/FNext，fixed-rate 补跳
  class function Every(const AInterval: TDuration): TTicker; static;
  procedure Start(const AInterval: TDuration); procedure Stop;
  function IsRunning: Boolean; inline; function GetInterval: TDuration; inline;
  function NextDeadline: TDeadline; // 未运行→Infinite
  function Poll(out ATick: TTick): Boolean; // 到期填充 LateBy/Missed 并推进 FNext += (Missed+1)*Interval
end;

TSleep = record
  class procedure ForDuration(const ADuration: TDuration); static; // <=0 立即返回
  class procedure Until_(const ADeadline: TDeadline); static; // Infinite→1h 分片，避免溢出
end;
procedure MsSleep(const AMilliseconds: UInt64); // 0 立即返回，经 platform_thread_sleep_ms
// cpu/platform.thread 转发，inline
procedure CpuRelax; procedure SchedYield; inline; procedure NanoSleep(const ANanoseconds: UInt64); inline;
function CpuCount: Int32; inline; function CurrentThreadId: UInt64; inline; function GetTickCount64: UInt64; inline; // monotonic_ns div 1e6
```

### 1.5 门面函数

```pascal
function DateTimeNow: TDateTime;        // 本地：realtime_ns + utc_offset
function DateTimeUtcNow: TDateTime;     // UTC：realtime_ns
function DateTimeSecondsBetween(const ANewer, AOlder: TDateTime): Int64;
function DateTimeMillisecondsBetween(const ANewer, AOlder: TDateTime): Int64;
function DaysBetween(const ANewer, AOlder: TDateTime): Integer; // Abs(Trunc(delta))
function DateTimeAddSeconds(const AValue: TDateTime; const ASeconds: Int64): TDateTime;
function ParseISO8601Date(const AStr: string): TDate; inline;
function TryParseISO8601Date(const AStr: string; out ADate: TDate): Boolean; inline;
function ParseISO8601Time(const AStr: string): TTimeOfDay; inline;
function TryParseISO8601Time(const AStr: string; out ATime: TTimeOfDay): Boolean; inline;
function ParseISO8601DateTime(const AStr: string): TNaiveDateTime; inline;
function TryParseISO8601DateTime(const AStr: string; out ADT: TNaiveDateTime): Boolean; inline;
function FormatDateTime(const APattern: string; const ADT: TDateTime): string; inline; // %Y-%m-%d %H:%M:%S 等 via time.format
function DateTimeToStr(const ADT: TDateTime): string; inline; function DateToStr(const ADT: TDateTime): string; inline;
function GetTickCount64: UInt64; inline; procedure MsSleep(const AMilliseconds: UInt64); inline;
function TimeBucketKey(const AUnixSeconds: Int64; const ABucketSeconds: Int64 = 3600; const AWidth: Integer = 12): string; inline;
function FormatISO8601UTC(const AUnixSeconds: Int64): string; inline;
function EncodeDate(const AYear, AMonth, ADay: Word): TDateTime; function EncodeTime(const AHour, AMinute, ASecond, AMSec: Word): TDateTime;
procedure DecodeDate(const AValue: TDateTime; out AYear, AMonth, ADay: Word); procedure DecodeTime(const AValue: TDateTime; out AHour, AMinute, ASecond, AMSec: Word);
function DateTimeToUnix(const AValue: TDateTime): Int64; function UnixToDateTime(const AValue: Int64): TDateTime; // Double 宽度防 Single 精度丢
```

---

## 2. 不变量

- **[INV-1]** TDuration 内部 Int64 纳秒，饱和算术（溢出→DURATION_MAX/MIN），精度纳秒，`ToString` 按阈值分档不丢符号
- **[INV-2]** TInstant 基于单调时钟 `platform_monotonic_ns`，不受系统时间调整影响；`DurationSince` 负向与超 Int64 饱和正确
- **[INV-3]** TDate 以 JulianDay 存储，范围 0001-01-01..9999-12-31，`Month∈[1,12] Day∈[1,DaysInMonth]`，`Today` 经 realtime + offset 且负向 div 修正
- **[INV-4]** TTimeOfDay 环形日，`Hour∈[0,23] Minute/Second∈[0,59] Nano∈[0,999999999]`，`FromNanoseconds` mod 日，`DurationUntil/Since` 环形非负
- **[INV-5]** TDeadline：`Infinite` 永不过期且 `Remaining/TimeUntil=MaxValue`；`After(<=0)=Expired`（FNs=0 必过期）；`IsExpired := Now>=At`，`Remaining` 非负钳零
- **[INV-6]** TStopwatch：`Resolved: Elapsed = Accumulated + Running? (Now-FStart):0`；`Reset` 清零且停；`Restart` 清零重启；`Start` 去重，`Stop` 幂等
- **[INV-7]** TTimer one-shot：`Poll` 仅 `Armed && Expired` 时触发一次并自动 `Idle+Infinite`
- **[INV-8]** TTicker fixed-rate：`Poll` 触发后 `FNext += (Missed+1)*Interval` 跳过积压，`Missed = LateBy div Interval`
- **[INV-9]** `TimeBucketKey`/`FormatISO8601UTC` 仅非负 Unix 秒，负数 `EArgumentError`；`Bucket` 宽 `<1` 或 `Width < digits(bucket)` 抛 `EArgumentError`；定宽补零保证定长可比
- **[INV-10]** TDateTime 门面：`UNIX_EPOCH=25569.0` 且 `Double` 算术（FPC 字面量默认 Single 会在 2026 量级丢分钟精度），`DateTimeToUnix/UnixToDateTime` 保持亚秒

---

## 3. 错误处理

| 场景 | 行为 |
|------|------|
| 非法日期/时间 `Create` (Month=13/Day越界/Hour=24) | 抛 `Exception('TDate/TTimeOfDay: invalid ...')` |
| `TryCreate/TryParseISO8601*` 失败 | 返回 `False`，不抛异常 |
| ISO 8601 解析失败 `Parse*` | 抛 `Exception('Invalid ISO 8601 ...')` |
| `TUtcOffset.FromHoursMinutes` 超 ±18h | 抛 `EArgumentError` |
| `TDuration.DivBy(0)` | 抛 `EInvalidOperationError('TDuration.DivBy: division by zero')` |
| `TimeBucketKey` 负时间戳/桶宽<1/宽度不足 | 抛 `EArgumentError` |
| `FormatISO8601UTC` 负时间戳 | 抛 `EArgumentError` |
| `TPeriod.ParseISO8601` 非法 | 抛 `Exception('TPeriod: invalid ISO 8601 period ...')` |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| TDuration/TInstant/TDate/TTimeOfDay/TNaiveDateTime/TOffsetDateTime/TUtcOffset/TPeriod | ✅ | 值类型，无共享可变状态 |
| TStopwatch | ❌ | 有状态（FRunning/FAccumulated/FStart），调用方同步 |
| TTimer/TTicker | ❌ | 有状态（FState/FDeadline/FNext），轮询型，调用方同步 |
| TSleep/MsSleep | ✅ | 类方法/纯函数，底层 `platform_thread_sleep_*` |
| DateTimeNow/DateTimeUtcNow/Now/Today/Local | ✅ | 无锁系统调用（realtime/monotonic + offset 原子读） |
| cpu helpers | ✅ | `platform_thread_*`/`platform_cpu_count` |

---

## 5. 内存管理

- 全部核心类型为 `record` 值语义，零堆分配，无 `Create/Destroy`，无全局缓存
- 门面 `inline` 转发，零额外拷贝；`Format`/`Bucket`/`ISO8601` 内部定长 `PChar`/`StringOfChar` 单次分配，复用 `bytes.ops`/`text.conv` 单源
- `TTimer/TTicker` 为 `record`（非 class），`Poll` 自动状态机无需外部释放；无句柄泄漏
- `TSleep` 阻塞时不持有锁/句柄；若未来引入可中断句柄，遵循 `try-finally` 释放不丢

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_time | TDuration/TInstant/Stopwatch/Platform/DateTimeNow/UtcNow/日期算术/MsSleep |
| test_date | TDate 创建/闰年/增减/边界/Today |
| test_time_bucket | 桶键定宽/溢出/负数拒绝 |
| test_iso8601_format | ISO 8601 解析/格式化往返 |
| test_deadline | TDeadline After/At/Infinite/Expired/Remaining/Min |
| test_timer | TTimer Arm/Cancel/Poll one-shot |
| test_period | TPeriod 解析/加法/边界 |
| **合计** | **7 个测试目录**，聚焦 `03` 契约与回归（`make -C core/tests/nextpas.core.time` / `make focused FOCUS=core/tests/nextpas.core.time/test_*`） |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 同步 18 文件真实实现：Stopwatch(Reset/Restart/IsRunning 累计语义)、Deadline(Infinite/Expired/Min/TimeUntil/Remaining/ToInstant)、Timer(one-shot Poll消抖)/Ticker(fixed-rate Missed/LateBy)、Sleep(ForDuration/Until_ 分片)、Cpu/NanoSleep、Bucket/HttpDate/OffsetDateTime/Period/Timezone 全量；修正门面/错误/线程安全/内存与测试清单；重申 L1 单向、四件套、bytes.ops 单源、inline 零拷贝与释放不丢 | Claude |

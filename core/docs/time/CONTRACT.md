# nextpas.core.time 代码契约

**模块路径**：`core/src/nextpas.core.time*.pas`（16 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 类型 | 职责 |
|------|------|------|
| time.base | TDuration, TInstant | 时间基础类型（纳秒精度） |
| time.date | TDate, TDayOfWeek | 日期类型 (Year/Month/Day) |
| time.timeofday | TTimeOfDay | 时间类型 (Hour/Minute/Second/Nanos) |
| time.datetime | TNaiveDateTime | 日期+时间（无时区） |
| time.offsetdatetime | TOffsetDateTime | 带偏移的日期时间 |
| time.timezone | — | 时区支持 |
| time.iso8601 | — | ISO 8601 解析/格式化 |
| time.format | — | 自定义格式化 |
| time.deadline | TDeadline | 截止时间（相对/绝对） |
| time.sleep | TSleep | 线程休眠 |
| time.stopwatch | TStopwatch | 高精度计时器 |
| time.timer | TTimer | 重复/单次定时器 |
| time.ticker | TTicker | 固定间隔 tick |
| time.period | TPeriod | 周期计算 |
| time.cpu | — | CPU 时间测量 |
| time.pas | — | 门面 |

### 1.2 核心类型

```pascal
TDuration = record
  class function FromSeconds(S: Double): TDuration; static;
  class function FromMilliseconds(MS: Int64): TDuration; static;
  class function FromNanoseconds(NS: Int64): TDuration; static;
  function Seconds: Double;
  function Milliseconds: Int64;
  function Nanoseconds: Int64;
  class operator +(A, B: TDuration): TDuration;
  class operator -(A, B: TDuration): TDuration;
  class operator *(A: TDuration; S: Double): TDuration;
  class operator >(A, B: TDuration): Boolean;
  // ... 其他比较运算符
end;

TInstant = record
  class function Now: TInstant; static;
  function Elapsed: TDuration;
  function DurationSince(AEarlier: TInstant): TDuration;
end;

TDate = record
  Year: Int16; Month: Byte; Day: Byte;
  class function Create(AYear: Int16; AMonth, ADay: Byte): TDate; static;
  class function Today: TDate; static;
  function DayOfWeek: TDayOfWeek;
  class operator +(ADate: TDate; ADays: Integer): TDate;
end;

TTimeOfDay = record
  Hour, Minute, Second: Byte;
  Nanos: UInt32;
  class function Create(AH, AM, AS: Byte; ANanos: UInt32 = 0): TTimeOfDay; static;
  class function Now: TTimeOfDay; static;
end;
```

### 1.3 ISO 8601

```pascal
function ParseISO8601Date(AStr: string): TDate;
function TryParseISO8601Date(AStr: string; out ADate: TDate): Boolean;
function ParseISO8601Time(AStr: string): TTimeOfDay;
function ParseISO8601DateTime(AStr: string): TNaiveDateTime;
```

### 1.4 定时器/计时器

```pascal
TStopwatch = record
  class function StartNew: TStopwatch; static;
  procedure Start;
  procedure Stop;
  procedure Reset;
  function Elapsed: TDuration;
  function ElapsedMilliseconds: Int64;
end;

TDeadline = record
  class function After(ADuration: TDuration): TDeadline; static;
  class function At(AInstant: TInstant): TDeadline; static;
  function IsExpired: Boolean;
  function Remaining: TDuration;
end;

TSleep = record
  class procedure Milliseconds(AMS: UInt32); static;
  class procedure Seconds(AS: Double); static;
end;
```

### 1.5 门面函数

```pascal
function DateTimeNow: TDateTime;        // 当前本地时间
function DateTimeUtcNow: TDateTime;     // 当前 UTC
function SecondsBetween(ANewer, AOlder: TDateTime): Int64;
function MillisecondsBetween(ANewer, AOlder: TDateTime): Int64;
function DaysBetween(ANewer, AOlder: TDateTime): Integer;
function DateTimeAddSeconds(AValue: TDateTime; ASeconds: Int64): TDateTime;
```

---

## 2. 不变量

- **[INV-1]** TDuration 内部以纳秒存储，精度到纳秒
- **[INV-2]** TInstant 基于单调时钟（不受系统时间调整影响）
- **[INV-3]** TDate 的 Month ∈ [1,12]，Day ∈ [1, 当月天数]
- **[INV-4]** TTimeOfDay 的 Hour ∈ [0,23]，Minute/Second ∈ [0,59]
- **[INV-5]** TDeadline.IsExpired 在到达时返回 True
- **[INV-6]** TStopwatch 使用 QueryPerformanceCounter (Windows) 或 clock_gettime (Linux)

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 非法日期 (Month=13) | EInvalidArgument |
| ISO 8601 解析失败 | EParseError |
| TryParseISO8601 失败 | 返回 False |
| Duration 除零 | 结果为 Inf |

---

## 4. 线程安全

| 类型 | 线程安全 | 说明 |
|------|----------|------|
| TDuration/TInstant | ✅ | 值类型 |
| TDate/TTimeOfDay | ✅ | 值类型 |
| TStopwatch | ❌ | 有状态，调用方同步 |
| TTimer/TTicker | ❌ | 有回调状态 |
| TSleep | ✅ | 类方法 |
| DateTimeNow/Now | ✅ | 系统调用 |

---

## 5. 内存管理

- TDuration/TInstant/TDate/TTimeOfDay 为 record，值语义
- TTimer/TTicker 为 class，Create/Destroy 管理
- 无全局缓存

---

## 6. 测试覆盖

| 测试目录 | 测试数 | 说明 |
|----------|--------|------|
| test_time_base | ~15 | TDuration/TInstant |
| test_time_date | ~10 | TDate |
| test_time_datetime | ~10 | TNaiveDateTime |
| test_time_iso8601 | ~10 | ISO 8601 解析 |
| test_time_deadline | ~5 | TDeadline |
| 其他 | ~5 | Timer/Stopwatch/Period |
| **合计** | **5 个测试目录** | **~55** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |

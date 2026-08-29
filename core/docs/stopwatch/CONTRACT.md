# nextpas.core.stopwatch 代码契约

**模块路径**：`core/src/nextpas.core.stopwatch*.pas`（7 个源文件）
**层级**：L0（依赖 platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| stopwatch.pas | TStopwatch, TStopwatchScope 高精度计时器 |
| stopwatch.tick | ITick 接口 + 平台选择 |
| stopwatch.tick.x86_64 | x86_64 RDTSC 硬件计时 |
| stopwatch.tick.aarch64 | AArch64 硬件计时 |
| stopwatch.tick.darwin | macOS mach_absolute_time |
| stopwatch.tick.unix | POSIX clock_gettime |
| stopwatch.tick.windows | Windows QueryPerformanceCounter |

### 1.2 核心类型

```pascal
TStopwatch = record
  procedure Start;
  procedure Stop;
  procedure Reset;
  procedure Restart;
  function ElapsedTicks: Int64;
  function ElapsedNs: Int64;
  function ElapsedUs: Int64;
  function ElapsedMs: Int64;
  function ElapsedSeconds: Double;
  function IsRunning: Boolean;
  class function StartNew: TStopwatch; static;
end;

TStopwatchScope = record
  // RAII 风格：构造时 Start，析构时 Stop
end;
```

---

## 2. 不变量

- ElapsedTicks 单调递增
- Reset 后 ElapsedTicks 归零
- Restart = Reset + Start
- StartNew = Reset + Start + 返回实例

---

## 3. 错误处理

- 不抛异常
- 硬件计时不可用时降级到 POSIX 时钟

---

## 4. 线程安全

- TStopwatch 是值类型，调用方自行同步
- 平台 ITick 实现线程安全

---

## 5. 内存管理

- TStopwatch/TStopwatchScope 是栈上值类型

---

## 6. 测试覆盖

- `test_stopwatch`: Start/Stop/Reset/Restart/Elapsed/Scope

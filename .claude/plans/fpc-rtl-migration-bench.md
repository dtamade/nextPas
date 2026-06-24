# bench 模块 FPC RTL 依赖迁移计划

## 执行状态: ✅ 全部完成

**提交**: a388c0ff1 (source) + fb06c2d7f (tests)
**日期**: 2026-06-22
**结果**: 12/12 套件全绿, 463+ tests, 0 leaks, **零 FPC RTL 直接引用**

---

## 完成的迁移

### 新增框架基础设施
- `nextpas.core.system.classes` — 扩展 TThread re-export
- `nextpas.core.system.memmanager` — 新建 TMemoryManager/GetMemoryManager/SetMemoryManager passthrough

### 源文件迁移 (8 files)

| 文件 | 原 FPC RTL | 替换为 |
|------|-----------|--------|
| parallel.pas | Classes (TThread) | nextpas.core.system.classes |
| memtrack.pas | SysUtils | nextpas.core.system.memmanager |
| stats.advanced.pas | SysUtils (unused) | 移除 |
| stats.pas | SysUtils + Math | nextpas.core.math.trig/scalar |
| runner.pas | SysUtils + Math | nextpas.core.text.conv + os.env + math |
| report.pas | SysUtils + StrUtils + Math | nextpas.core.text.conv/format + math.scalar |
| baseline.pas | SysUtils + Classes | nextpas.core.exception + text.conv + platform.time + fs.util |
| xlang.pas | SysUtils + StrUtils | nextpas.core.exception + text.conv + text.strings |

### 测试文件迁移 (11 files)
- SysUtils → nextpas.core.text.conv / nextpas.core.exception / nextpas.core.math.scalar
- SyncObjs → nextpas.core.sync.mutex (TMutex)
- Sleep(N) → TSleep.ForDuration(TDuration.FromMilliseconds(N))
- TFormatSettings locale test → simplified (framework is locale-free)

### 关键设计决策
- TDateTime/Now → UInt64 纳秒时间戳 via platform_realtime_ns
- String helpers (Split/Contains/StartsWith) → Pos/StringsSplit 过程式调用
- FloatToStrF → 框架版本(小数位数)，天然无区域依赖
- IfThen → BoolToStr(Boolean, TrueStr, FalseStr) 或 inline if-else

## 最终依赖状态（实际）

| 文件 | SysUtils | Classes | Math | StrUtils | SyncObjs |
|------|----------|---------|------|----------|----------|
| 所有源文件 | ❌ | ❌ | ❌ | ❌ | ❌ |
| 所有测试文件 | ❌ | ❌ | ❌ | ❌ | ❌ |

**零 FPC RTL 直接引用** — 全部通过 nextpas.core.* 框架接口访问

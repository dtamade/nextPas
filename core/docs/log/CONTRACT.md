# nextpas.core.log 代码契约

**模块路径**：`core/src/nextpas.core.log*.pas`（2 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| log.intf | TLogLevel 枚举, ILogSink 接口 |
| log.pas | TLogRecord, 全局日志函数 |

### 1.2 核心类型

```pascal
TLogLevel = (llTrace, llDebug, llInfo, llWarn, llError, llFatal);

TAttr = record
  Key: string;
  Kind: TAttrKind;  // akString/akInt/akFloat/akBool
  SVal: string;
  IVal: Int64;
  FVal: Double;
  BVal: Boolean;
end;

TLogRecord = record
  Level: TLogLevel;
  Message: string;
  TimestampNs: Int64;
  Attrs: array of TAttr;
  AttrCount: Int32;
  Group: string;
end;

ILogSink = interface
  procedure Write(const ARecord: TLogRecord);
  procedure Flush;
end;
```

### 1.3 全局日志 API

```pascal
procedure LogTrace(const AMsg: string; const AAttrs: array of TAttr);
procedure LogDebug(const AMsg: string; const AAttrs: array of TAttr);
procedure LogInfo(const AMsg: string; const AAttrs: array of TAttr);
procedure LogWarn(const AMsg: string; const AAttrs: array of TAttr);
procedure LogError(const AMsg: string; const AAttrs: array of TAttr);
procedure LogFatal(const AMsg: string; const AAttrs: array of TAttr);

procedure LogSetSink(ASink: ILogSink);
procedure LogSetLevel(ALevel: TLogLevel);
```

---

## 2. 不变量

- **[INV-1]** 低于当前 Level 的日志被丢弃（零开销）
- **[INV-2]** TLogRecord.TimestampNs 为单调时钟纳秒
- **[INV-3]** ILogSink.Write 可能从任意线程调用（sink 负责同步）

---

## 3. 错误处理

- 日志函数不抛异常
- Sink 写入失败被静默忽略

---

## 4. 线程安全

| 操作 | 线程安全 | 说明 |
|------|----------|------|
| LogXxx 函数 | ✅ | 可从任意线程调用 |
| LogSetSink | ❌ | 应在初始化时调用一次 |
| LogSetLevel | ✅ | 原子读写 |
| ILogSink.Write | ❌ | Sink 实现负责同步 |

---

## 5. 内存管理

- TLogRecord 为 record，栈上分配
- TAttr 为 record
- ILogSink 拥有输出资源（文件/socket 等）

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| test_log | Level 过滤 + Sink 写入 |
| test_log_source_contracts | 源契约边界 |
| **合计** | **2 个测试目录** |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-30 | 1.1 | 冻结感修复：更新最后更新至 2026-08-30 并 bump 版本 | Claude |

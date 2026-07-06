# nextpas.core.log 模块规划

> **层级：** L3（依赖 L0-L2）
> **目标：** 生产级结构化日志，对标 Go slog / Rust tracing

## 架构

```
L0: nextpas.core.log.intf.pas     ← ILogger + TLogLevel + TNullLogger（已有）
L3: nextpas.core.log.pas          ← 门面 re-export
    nextpas.core.log.handler.pas  ← ILogHandler 接口 + 多路分发
    nextpas.core.log.console.pas  ← 控制台输出（彩色）
    nextpas.core.log.file.pas     ← 文件输出（rotation）
    nextpas.core.log.json.pas     ← JSON 格式化输出
    nextpas.core.log.record.pas   ← TLogRecord 结构化记录
    nextpas.core.log.logger.pas   ← TStructuredLogger 实现
```

## 核心设计

```pascal
{ log.record.pas — 结构化日志记录 }
type
  TLogField = record
    Key: string;
    Value: string;
  end;

  TLogRecord = record
    Level: TLogLevel;
    Message: string;
    Timestamp: Int64;  // monotonic ns
    Fields: array of TLogField;
    Source: string;    // caller module/function
  end;

{ log.handler.pas — 输出处理器接口 }
type
  ILogHandler = interface
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
  end;

{ log.logger.pas — 结构化 Logger 实现 }
type
  TStructuredLogger = class(TInterfacedObject, ILogger)
  private
    FLevel: TLogLevel;
    FHandlers: array of ILogHandler;
    FFields: array of TLogField;  // 预设字段
  public
    constructor Create(ALevel: TLogLevel);
    procedure AddHandler(const AHandler: ILogHandler);
    procedure WithField(const AKey, AValue: string);
    // ILogger
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace/Debug/Info/Warn/Error/Fatal(const AMessage: string);
  end;

{ 门面 API }
function LogNew(ALevel: TLogLevel = llInfo): ILogger;
function LogConsole(ALevel: TLogLevel = llInfo): ILogger;
function LogFile(const APath: string; ALevel: TLogLevel = llInfo): ILogger;
function LogJSON(const AHandler: ILogHandler): ILogger;
procedure LogSetDefault(const ALogger: ILogger);
function LogDefault: ILogger;

// 全局便利函数
procedure LogTrace(const AMsg: string);
procedure LogDebug(const AMsg: string);
procedure LogInfo(const AMsg: string);
procedure LogWarn(const AMsg: string);
procedure LogError(const AMsg: string);
procedure LogFatal(const AMsg: string);
```

## 实施顺序

| Phase | 内容 |
|-------|------|
| P1 | TLogRecord + ILogHandler + TConsoleHandler |
| P2 | TStructuredLogger (ILogger 实现 + 多 handler + 级别过滤) |
| P3 | 门面 + 全局默认 logger + 便利函数 |
| P4 | TFileHandler (文件输出 + rotation) |
| P5 | TJsonHandler (JSON 格式化) |
| P6 | 结构化字段 (WithField/WithFields) |
| P7 | 测试覆盖 + 基准 |
| P8 | Codex 审查 |

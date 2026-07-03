unit nextpas.core.log.intf;

{$I nextpas.core.settings.inc}

interface

type
  {** 日志级别，从最详细 (llTrace) 到最严重 (llFatal) }
  TLogLevel = (
    llTrace,  { 跟踪：最细粒度的调试信息 }
    llDebug,  { 调试：开发期间的诊断信息 }
    llInfo,   { 信息：正常运行时的关键事件 }
    llWarn,   { 警告：可恢复的异常情况 }
    llError,  { 错误：需要关注但不致命的失败 }
    llFatal   { 致命：进程无法继续运行 }
  );

  {** 日志接口 — 所有日志实现的最小契约。
   *  线程安全由实现保证（TConsoleHandler/TJsonHandler 内部加锁）。
   *  使用 TLogger 的链式 API 构建日志事件，不要直接操作 ILogger。 }
  ILogger = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

  { TNullLogger - no-op logger, safe default }
  TNullLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

function NullLogger: ILogger;

implementation

var
  GNullLogger: ILogger = nil;

function NullLogger: ILogger;
begin
  if GNullLogger = nil then
    GNullLogger := TNullLogger.Create;
  Result := GNullLogger;
end;

{ TNullLogger }

procedure TNullLogger.Log(const ALevel: TLogLevel; const AMessage: string);
begin
end;

procedure TNullLogger.Trace(const AMessage: string);
begin
end;

procedure TNullLogger.Debug(const AMessage: string);
begin
end;

procedure TNullLogger.Info(const AMessage: string);
begin
end;

procedure TNullLogger.Warn(const AMessage: string);
begin
end;

procedure TNullLogger.Error(const AMessage: string);
begin
end;

procedure TNullLogger.Fatal(const AMessage: string);
begin
end;

end.

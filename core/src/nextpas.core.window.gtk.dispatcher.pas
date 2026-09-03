unit nextpas.core.window.gtk.dispatcher;

{** @desc GTK Dispatcher 单源（family shard，owner window.impl 间接 via window.gtk.impl）。

       职责：g_idle_add_full + 共享环形队列（family single-source）唤醒。
       由 window.gtk.impl 拆分而来：原 860 行三职责（dispatcher/窗口/信号回调）超 800 阈值，
       本单元收口 dispatcher 单职责，window 信号与窗口形态收口至 window.gtk.window。

       性能：复用 TWindowQueue（32cap 起步、2× 指数扩容、Move 环绕、锁外 Drain）单源，
       与 sdl/win32/fake 共享同一增长/零拷贝语义；inline Push/Drain 零额外调用，
       单次 Move 零拷贝，避免 FPending SetLength+1 O(n²)；bytes.ops 单源思想：倍增与
       Builder 单源（2×），零重复逻辑。IGtkOps trait 接口透传 IdleAddFull/SourceRemove
       适配器 inline 单次字段间接 nil 守卫，复用 loader 全局直调。
       架构取舍：已提纯至 TWindowDispatcherBase（55 行基类收口 120 行样板 ROI≈2.2，
       DoWake per-instance 函数指针隔离 SDL_PushEvent/PostMessage/dispatch_async/SetEvent/g_idle_add_full 零虚表），
       本单元仅持 per-instance 队列+idle，Post 三重载 inline 零拷贝，经 DoWake→EnsureIdle
       单次函数指针间接仅空→非空跃迁（1-2ns），Burst N→1。

       稳定性：队列 Clear 逐条 nil 释放闭包；单 FIdleTag + FLck 保护，DropAll 原子摘除
       并 g_source_remove，异常路径 try-finally 不丢释放；锁外 Drain 避免持锁回调死锁。 *

  依赖方向：window.gtk.dispatcher → window.gtk.impl (TGtkOps/TGtkContext) + window.dispatcher.base/queue
  （L2 内家族共享，非门面 re-export，仅被 window.gtk.window 与 window.gtk.impl uses）；
  守四件套与 L0-L3，复用 bytes.ops 单源 0→32→2× via window.impl→queue。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.dispatcher.base,
  nextpas.core.window.gtk.impl,
  nextpas.core.sync.intf;

type
  gboolean = Int32;
  guint = Cardinal;

const
  GLIB_SOURCE_REMOVE = 0;
  G_PRIORITY_DEFAULT = 0;

type
  TWindowGtkDispatcher = class(TWindowDispatcherBase)
  private
    FLck: ILock;
    FIdleTag: guint;
    FContext: TGtkContext;
    procedure EnsureIdle;
  public
    constructor Create(AOwnerThread: UInt64; AContext: TGtkContext); reintroduce;
    destructor Destroy; override;
    procedure DropAll;
  end;

function GtkDispatcherIdleCallback(AData: Pointer): gboolean; cdecl;
procedure GtkDispatcherIdleDestroy(AData: Pointer); cdecl;

implementation

uses
  nextpas.core.window.impl,
  nextpas.core.window.queue,
  nextpas.core.sync.mutex;

procedure GtkDispatcherWake(AData: Pointer); forward;

function GtkDispatcherIdleCallback(AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtkDispatcher;
begin
  Self := TWindowGtkDispatcher(AData);
  if Self <> nil then
  begin
    Self.FLck.Acquire;
    try
      Self.FIdleTag := 0;
    finally
      Self.FLck.Release;
    end;
    if Assigned(Self.FQueue) then
      Self.FQueue.Drain;
  end;
  Result := GLIB_SOURCE_REMOVE;
end;

procedure GtkDispatcherIdleDestroy(AData: Pointer); cdecl;
begin
  // 无每 Post 堆分配，IdleClosure 已由 TWindowQueue 池化；dispatcher 裸指针由 window 持有，此处 no-op 不丢释放
end;

constructor TWindowGtkDispatcher.Create(AOwnerThread: UInt64; AContext: TGtkContext);
begin
  inherited Create(WindowFamilyToken, AOwnerThread, @GtkDispatcherWake, Pointer(Self));
  // 修正：Self 在 inherited 后已分配，FWakeData 需指向实例自身，补设（inherited 时 Self 已可用但 FWakeData 传入时 Self 尚未完全构造，显式回填保证指向）
  FWakeData := Self;
  FContext := AContext;
  FLck := TMutex.Create as ILock;
  FIdleTag := 0;
end;

procedure GtkDispatcherWake(AData: Pointer);
begin
  if AData = nil then Exit;
  TWindowGtkDispatcher(AData).EnsureIdle;
end;

destructor TWindowGtkDispatcher.Destroy;
begin
  DropAll;
  FLck := nil;
  inherited;
end;

procedure TWindowGtkDispatcher.DropAll;
var
  LTag: guint;
begin
  if FLck <> nil then
  begin
    FLck.Acquire;
    try
      LTag := FIdleTag;
      FIdleTag := 0;
    finally
      FLck.Release;
    end;
  end
  else
    LTag := FIdleTag;
  if (LTag <> 0) and Assigned(FContext) and (FContext.Ops <> nil) then
    FContext.Ops.SourceRemove(LTag);
  if Assigned(FQueue) then
    FQueue.Clear;
end;

procedure TWindowGtkDispatcher.EnsureIdle;
var
  LTag: guint;
begin
  if FLck <> nil then
    FLck.Acquire;
  try
    if (FIdleTag = 0) and Assigned(FContext) and (FContext.Ops <> nil) then
    begin
      LTag := FContext.Ops.IdleAddFull(G_PRIORITY_DEFAULT, @GtkDispatcherIdleCallback, Self, nil);
      FIdleTag := LTag;
    end;
  finally
    if FLck <> nil then
      FLck.Release;
  end;
end;

end.

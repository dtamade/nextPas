unit nextpas.core.webview.gtk.shell;

{** @desc GTK 窗口壳缝（window.gtk3 Raw 单源）：进程级 GTK 初始化守卫、scheme 上下文注册表、活窗计数、窗口壳创建与嵌入。

       单源：
       - 窗口几何 → nextpas.core.window.gtk3 WindowGtkRaw* 12 项 inline 零拷贝单源（见 window.gtk3）
       - 容量/注册表 → bytes.ops VecGrowCapacity 0→4→2× / TCompactLiveRegistry 单源 inline 零拷贝
       - 日志 → log.intf ILogger 单源分级，NullLogger 零开销
       性能：inline 薄转发 + 零拷贝 Move，短临界 <1µs，ViewHash→HashMix32 单源
       稳定性：Mutex/RWLock 单所有权，try-finally 释放不丢，keep-alive 与 destroy 回调同构 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.sync.mutex,
  nextpas.core.sync.rwlock,
  nextpas.core.log.intf,
  nextpas.core.webview.base,
  nextpas.core.window.base,
  nextpas.core.window.intf;

type
  TGtkDebugLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

procedure ShellLogInit; inline;
procedure ShellTrace(const AMsg: string);

function ShellSchemeContextRegistered(ACtx: Pointer): Boolean;
procedure ShellRememberSchemeContext(ACtx: Pointer);
procedure ShellForgetSchemeContext(ACtx: Pointer);

function ShellLiveWindowCount: Integer; inline;
procedure ShellRegisterLive(AWin: Pointer);
procedure ShellUnregisterLive(AWin: Pointer);

function ShellWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;

procedure ShellInitLocks; inline;
procedure ShellFiniLocks; inline;
procedure ShellInitRegistries; inline;
procedure ShellFiniRegistries; inline;

implementation

uses
  nextpas.core.os.env,
  nextpas.core.webview.live,
  nextpas.core.webview.gtk.viewmap;

var
  GShellSchemeCtxs: specialize TWebviewLiveRegistry<Pointer> = nil;
  GShellLiveWindows: specialize TWebviewLiveRegistry<Pointer> = nil;
  GShellLiveCount: Integer = 0;
  GShellSchemeLock: TMutex = nil;
  GShellLiveLock: TRWLock = nil;
  GShellDebugChecked: Boolean = False;
  GShellDebugEnabled: Boolean = False;
  GShellLogger: ILogger = nil;

{ TGtkDebugLogger — graded stderr sink via log.intf (L0 seam) }
procedure TGtkDebugLogger.Log(const ALevel: TLogLevel; const AMessage: string);
begin
  System.Write(StdErr, '[npw-gtk] ', AMessage, LineEnding);
  System.Flush(StdErr);
end;

procedure TGtkDebugLogger.Trace(const AMessage: string);
begin
  Log(llTrace, AMessage);
end;

procedure TGtkDebugLogger.Debug(const AMessage: string);
begin
  Log(llDebug, AMessage);
end;

procedure TGtkDebugLogger.Info(const AMessage: string);
begin
  Log(llInfo, AMessage);
end;

procedure TGtkDebugLogger.Warn(const AMessage: string);
begin
  Log(llWarn, AMessage);
end;

procedure TGtkDebugLogger.Error(const AMessage: string);
begin
  Log(llError, AMessage);
end;

procedure TGtkDebugLogger.Fatal(const AMessage: string);
begin
  Log(llFatal, AMessage);
end;

procedure ShellLogInit; inline;
begin
  if not GShellDebugChecked then
  begin
    GShellDebugChecked := True;
    GShellDebugEnabled := GetEnv('NPW_GTK_DEBUG') = '1';
    if GShellDebugEnabled then
      GShellLogger := TGtkDebugLogger.Create
    else
      GShellLogger := NullLogger;
  end;
end;

procedure ShellTrace(const AMsg: string);
begin
  ShellLogInit;
  if GShellDebugEnabled then
    GShellLogger.Debug(AMsg);
end;

function ShellSchemeContextRegistered(ACtx: Pointer): Boolean;
var
  I: Integer;
begin
  if GShellSchemeLock <> nil then GShellSchemeLock.Acquire;
  try
    if GShellSchemeCtxs <> nil then
      for I := 0 to GShellSchemeCtxs.Count - 1 do
        if GShellSchemeCtxs.At(I) = ACtx then
          Exit(True);
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.Release;
  end;
  Result := False;
end;

procedure ShellRememberSchemeContext(ACtx: Pointer);
begin
  if GShellSchemeLock <> nil then GShellSchemeLock.Acquire;
  try
    if GShellSchemeCtxs <> nil then
      GShellSchemeCtxs.Register(ACtx);
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.Release;
  end;
end;

procedure ShellForgetSchemeContext(ACtx: Pointer);
begin
  if GShellSchemeLock <> nil then GShellSchemeLock.Acquire;
  try
    if GShellSchemeCtxs <> nil then
      GShellSchemeCtxs.Unregister(ACtx);
  finally
    if GShellSchemeLock <> nil then GShellSchemeLock.Release;
  end;
end;

function ShellLiveWindowCount: Integer; inline;
begin
  if GShellLiveLock <> nil then GShellLiveLock.AcquireRead;
  try
    Result := GShellLiveCount;
  finally
    if GShellLiveLock <> nil then GShellLiveLock.ReleaseRead;
  end;
end;

procedure ShellRegisterLive(AWin: Pointer);
begin
  if GShellLiveLock <> nil then GShellLiveLock.AcquireWrite;
  try
    if GShellLiveWindows <> nil then
      GShellLiveWindows.Register(AWin);
    Inc(GShellLiveCount);
  finally
    if GShellLiveLock <> nil then GShellLiveLock.ReleaseWrite;
  end;
  { viewmap 扩容在自锁内，零阻塞 GLive 读 — 调用方在 shell 上层加 view }
end;

procedure ShellUnregisterLive(AWin: Pointer);
begin
  if GShellLiveLock <> nil then GShellLiveLock.AcquireWrite;
  try
    if GShellLiveWindows <> nil then
      GShellLiveWindows.Unregister(AWin);
  finally
    if GShellLiveLock <> nil then GShellLiveLock.ReleaseWrite;
  end;
end;

function ShellWindowOptionsOf(const AOptions: TWebviewOptions): TWindowOptions; inline;
begin
  Result := DefaultWindowOptions;
  Result.Title := AOptions.Title;
  Result.Width := AOptions.Width;
  Result.Height := AOptions.Height;
  Result.MinWidth := AOptions.MinWidth;
  Result.MinHeight := AOptions.MinHeight;
  Result.MaxWidth := AOptions.MaxWidth;
  Result.MaxHeight := AOptions.MaxHeight;
  Result.Resizable := AOptions.Resizable;
  Result.Maximized := AOptions.Maximized;
  Result.ParentHandle := nil;
end;

procedure ShellInitLocks; inline;
begin
  if GShellSchemeLock = nil then GShellSchemeLock := TMutex.Create;
  if GShellLiveLock = nil then GShellLiveLock := TRWLock.Create;
end;

procedure ShellFiniLocks; inline;
begin
  FreeAndNil(GShellLiveLock);
  FreeAndNil(GShellSchemeLock);
end;

procedure ShellInitRegistries; inline;
begin
  if GShellLiveWindows = nil then
    GShellLiveWindows := specialize TWebviewLiveRegistry<Pointer>.Create;
  if GShellSchemeCtxs = nil then
    GShellSchemeCtxs := specialize TWebviewLiveRegistry<Pointer>.Create;
end;

procedure ShellFiniRegistries; inline;
begin
  FreeAndNil(GShellSchemeCtxs);
  FreeAndNil(GShellLiveWindows);
  GShellLogger := nil;
end;

initialization
  ShellInitLocks;
  ShellInitRegistries;

finalization
  ShellFiniRegistries;
  ShellFiniLocks;

end.

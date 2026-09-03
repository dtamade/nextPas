unit nextpas.core.window.factory;

{** @desc window 后端工厂、fluent Builder 与主循环入口。

       S1 后端可用性事实源：仅 fake 编译内建；gtk/sdl2 随波次
       接入时把 ResolveDefaultKind 切到平台优先并接入探测。
       默认 kind 的选择是本单元唯一职责，禁止散落到后端单元。

       薄委托：探测→ window.probe，注册表/缓存/RunLoop/Pump→ window.registry，
       本单元仅持 Builder 与创建校验（CheckWindowOptions 单源 impl→bytes.ops），
       拆分后 uses 从 13 loader 直连降至 3 家族内共享（probe/registry/live），
       热路径 Build 经 GProbeCache O(1) 零重复 dlopen。

       Builder 形态决策（docs/window/CONTRACT.md §4.3）：
       - Build 可多次调用创建多窗（多窗口路径）。
       - RunLoop 阻塞直到末窗关闭或 WindowExitLoop。
       - 工厂持 loader 真相；base 不知道这些函数的存在。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

type
  {** fluent 构建器。COM 引用计数生命周期，消费方不手写释放。 *}
  IWindowBuilder = interface
    ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A004}']
    function Kind(AKind: TWindowKind): IWindowBuilder;
    function Title(const ATitle: string): IWindowBuilder;
    function Size(AWidth, AHeight: Integer): IWindowBuilder;
    function MinSize(AWidth, AHeight: Integer): IWindowBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
    function Resizable(AResizable: Boolean): IWindowBuilder;
    function StartMaximized(AMaximized: Boolean): IWindowBuilder;
    function Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
    function Options(const AOptions: TWindowOptions): IWindowBuilder;
    function Build: IWindow;
  end;

  {** 入口形态：`TWindowBuilder.New.Title(..)...Build`。 *}
  TWindowBuilder = record
    class function New: IWindowBuilder; static;
  end;

{ 能力探测（factory 持 loader 真相；base 不知道这些函数的存在） }
function WindowBackendAvailable(AKind: TWindowKind): Boolean;
function DefaultWindowKind: TWindowKind;
function WindowBackendDiagnostics: string;

{ 按 kind 创建；不可用抛 EWindowBackendUnavailable }
function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow;
function CreateFakeWindow(const AOptions: TWindowOptions): IWindow;

{ 主循环所有权：阻塞直到最后一个未 Close 的窗口关闭，或 ExitLoop 被调 }
procedure WindowRunLoop;
procedure WindowExitLoop;

{ 非阻塞泵：为 game/directui 的 tick 循环提供不阻塞的单步迭代。
  返回 True 表示做了工作（处理了事件或投递），False 表示空转。
  拒绝 LCL 式消息伪装：调用方只关心"是否该重绘"，不解析 WPARAM。 }
function WindowPumpOnce: Boolean; inline;
procedure WindowPumpAll;

implementation

uses
  nextpas.core.system.typinfo,
  nextpas.core.window.impl,
  nextpas.core.window.fake,
  nextpas.core.window.registry;

function WindowBackendAvailable(AKind: TWindowKind): Boolean;
begin
  // 冷路径：dlopen 探测经 registry GProbeCache 缓存，禁 inline（真实路由体红线），Build 热路径零重复探测
  Result := RegistryBackendAvailable(AKind);
end;

function DefaultWindowKind: TWindowKind;
begin
  // 冷路径：单源遍历 registry BACKENDS[0..7] 经缓存，禁 inline，O(1) 零堆分配
  Result := RegistryDefaultKind;
end;

function WindowBackendDiagnostics: string;
begin
  // 冷路径：诊断串构建触发全量 Probe（经缓存），仅排障/日志调用，禁热路径
  Result := RegistryBackendDiagnostics;
end;

function CreateFakeWindow(const AOptions: TWindowOptions): IWindow;
begin
  CheckWindowOptions(AOptions);
  Result := TFakeWindow.Create(AOptions);
end;

function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow;
var
  B: PBackendDesc;
begin
  CheckWindowOptions(AOptions);
  if not WindowBackendAvailable(AKind) then
    raise EWindowBackendUnavailable.CreateFmt(
      'window backend "%s" is not available in this build — call WindowBackendDiagnostics for sonames/probe details', [
      GetEnumName(TypeInfo(TWindowKind), Ord(AKind))]);
  // 性能：inline O(1) 集合检测零拷贝，单源于 registry CBackendOrder 11 元全序派生的 RegistryIsDesktopKind，消 7 元硬编码双处同步与 wkGtk 别名冗余，wkGtk3 显式涵盖
  if (AOptions.ParentHandle <> nil) and RegistryIsDesktopKind(AKind) then
    raise EWindowUnsupported.Create(
      'ParentHandle is not supported for desktop window backends');
  B := RegistryFindBackend(AKind);
  if (B <> nil) and Assigned(B^.Create) then
    Exit(B^.Create(AOptions));
  raise EWindowBackendUnavailable.CreateFmt(
    'window backend "%s" is registered but has no factory yet', [
    GetEnumName(TypeInfo(TWindowKind), Ord(AKind))]);
end;

procedure WindowRunLoop;
begin
  RegistryRunLoop;
end;

procedure WindowExitLoop;
begin
  RegistryExitLoop;
end;

function WindowPumpOnce: Boolean; inline;
begin
  // 性能：inline 零拷贝薄委托 registry O(1) 单次原子读零遍历/零锁（BENCH 口径与 LiveGtkSmart 优化详见 BENCH.md/CONTRACT §4，WindowQueueSnapMax 8192 via bytes.ops 单源 inline 零拷贝 O(1)均摊）
  Result := RegistryPumpOnce;
end;

procedure WindowPumpAll;
begin
  RegistryPumpAll;
end;

{ ---- Builder ---- }

type
  TBuilderImpl = class(TInterfacedObject, IWindowBuilder)
  private
    FOptions: TWindowOptions;
    FKind: TWindowKind;
    FKindSet: Boolean;
  public
    constructor Create;
    function Kind(AKind: TWindowKind): IWindowBuilder;
    function Title(const ATitle: string): IWindowBuilder;
    function Size(AWidth, AHeight: Integer): IWindowBuilder;
    function MinSize(AWidth, AHeight: Integer): IWindowBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
    function Resizable(AResizable: Boolean): IWindowBuilder;
    function StartMaximized(AMaximized: Boolean): IWindowBuilder;
    function Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
    function Options(const AOptions: TWindowOptions): IWindowBuilder;
    function Build: IWindow;
  end;

constructor TBuilderImpl.Create;
begin
  inherited Create;
  FOptions := DefaultWindowOptions;
  // 单源：默认 kind 不在此硬编码 wkFake 低端回退；未显式 Kind 时 Build 懒取 RegistryDefaultKind，零字面量分散，高阶语义单源
  FKindSet := False;
end;

function TBuilderImpl.Kind(AKind: TWindowKind): IWindowBuilder;
begin
  FKind := AKind;
  FKindSet := True;
  Result := Self;
end;

function TBuilderImpl.Title(const ATitle: string): IWindowBuilder;
begin
  FOptions.Title := ATitle;
  Result := Self;
end;

function TBuilderImpl.Size(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.Size := TWindowSize.Create(AWidth, AHeight);
  Result := Self;
end;

function TBuilderImpl.MinSize(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.Constraints.MinWidth := AWidth;
  FOptions.Constraints.MinHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.Constraints.MaxWidth := AWidth;
  FOptions.Constraints.MaxHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.Resizable(AResizable: Boolean): IWindowBuilder;
begin
  FOptions.Resizable := AResizable;
  Result := Self;
end;

function TBuilderImpl.StartMaximized(AMaximized: Boolean): IWindowBuilder;
begin
  FOptions.Maximized := AMaximized;
  Result := Self;
end;

function TBuilderImpl.Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
begin
  FOptions.ParentHandle := AHandle;
  Result := Self;
end;

function TBuilderImpl.Options(const AOptions: TWindowOptions): IWindowBuilder;
begin
  FOptions := AOptions;
  Result := Self;
end;

function TBuilderImpl.Build: IWindow;
var
  LKind: TWindowKind;
begin
  if FKindSet then
    LKind := FKind
  else
    LKind := DefaultWindowKind;
  Result := CreateWindowOf(LKind, FOptions);
end;

class function TWindowBuilder.New: IWindowBuilder;
begin
  Result := TBuilderImpl.Create;
end;

end.

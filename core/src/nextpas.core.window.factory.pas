unit nextpas.core.window.factory;

{** @desc window 后端工厂、fluent Builder 与主循环入口。

       S1 后端可用性事实源：仅 fake 编译内建；gtk/sdl2 随波次
       接入时把 ResolveDefaultKind 切到平台优先并接入探测。
       默认 kind 的选择是本单元唯一职责，禁止散落到后端单元。

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

{ 按 kind 创建；不可用抛 EWindowBackendUnavailable }
function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow;
function CreateFakeWindow(const AOptions: TWindowOptions): IWindow;

{ 主循环所有权：阻塞直到最后一个未 Close 的窗口关闭，或 ExitLoop 被调 }
procedure WindowRunLoop;
procedure WindowExitLoop;

implementation

uses
  TypInfo,
  nextpas.core.platform.thread,
  nextpas.core.window.fake;

var
  GExitRequested: Boolean = False;

function WindowBackendAvailable(AKind: TWindowKind): Boolean;
begin
  case AKind of
    wkFake: Result := True;
    wkGtk, wkSdl2, wkWin32, wkCocoa, wkAndroid, wkUIKit:
      Result := False;
  else
    Result := False;
  end;
end;

function DefaultWindowKind: TWindowKind;
begin
  { S1：仅 fake 可用；S2 起按"平台原生 > gtk > sdl2"探测顺序实现。
    这里先冻最简分支并写测试钉死（CONTRACT §4.3）。 }
  if WindowBackendAvailable(wkWin32) then
    Result := wkWin32
  else if WindowBackendAvailable(wkCocoa) then
    Result := wkCocoa
  else if WindowBackendAvailable(wkAndroid) then
    Result := wkAndroid
  else if WindowBackendAvailable(wkUIKit) then
    Result := wkUIKit
  else if WindowBackendAvailable(wkGtk) then
    Result := wkGtk
  else if WindowBackendAvailable(wkSdl2) then
    Result := wkSdl2
  else
    Result := wkFake;
end;

function CreateFakeWindow(const AOptions: TWindowOptions): IWindow;
begin
  CheckWindowOptions(AOptions);
  { fake 接受 ParentHandle（供 S5 预演）；桌面后端在 CreateWindowOf 抛 Unsupported }
  Result := TFakeWindow.Create(AOptions);
end;

function CreateWindowOf(AKind: TWindowKind;
  const AOptions: TWindowOptions): IWindow;
begin
  CheckWindowOptions(AOptions);
  if not WindowBackendAvailable(AKind) then
    raise EWindowBackendUnavailable.CreateFmt(
      'window backend "%s" is not available in this build', [
      GetEnumName(TypeInfo(TWindowKind), Ord(AKind))]);

  { 桌面后端 ParentHandle 诚实失败（INV-9） }
  if (AOptions.ParentHandle <> nil) and (AKind in [wkGtk, wkSdl2, wkWin32, wkCocoa]) then
    raise EWindowUnsupported.Create(
      'ParentHandle is not supported for desktop window backends');

  case AKind of
    wkFake: Result := CreateFakeWindow(AOptions);
  else
    raise EWindowBackendUnavailable.CreateFmt(
      'window backend "%s" is registered but has no factory yet', [
      GetEnumName(TypeInfo(TWindowKind), Ord(AKind))]);
  end;
end;

procedure WindowRunLoop;
begin
  GExitRequested := False;
  while not GExitRequested do
  begin
    if FakeLiveWindowCount > 0 then
      FakePumpAll
    else
      Break;
    if FakeLiveWindowCount = 0 then
      Break;
    platform_thread_yield;
    { 若队列已空且无退出请求，下一轮循环检查 live 计数后退出；
      这保证 Close 后立即返回而不死等。 }
    if FakeLiveWindowCount = 0 then
      Break;
    { 避免空转过快：已用 yield 让出时间片 }
    if GExitRequested then
      Break;
  end;
end;

procedure WindowExitLoop;
begin
  GExitRequested := True;
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
  FKind := wkFake;
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
  FOptions.Width := AWidth;
  FOptions.Height := AHeight;
  Result := Self;
end;

function TBuilderImpl.MinSize(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.MinWidth := AWidth;
  FOptions.MinHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
begin
  FOptions.MaxWidth := AWidth;
  FOptions.MaxHeight := AHeight;
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

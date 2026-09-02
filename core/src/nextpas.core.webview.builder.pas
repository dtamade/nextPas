unit nextpas.core.webview.builder;

{** @desc webview fluent Builder：链式组装 TWebviewOptions + invoke/ready 脚本，
       Build 为工厂路由单源收敛（CreateWebviewEx），Run 为 Build+Navigate 便捷。
       与 factory 分离：factory 只管后端注册/探测/创建，builder 只管组装；
       避免同单元 3 Registry+HashSet+原子缓存混杂，高级感简洁。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.window.intf;

type
  {** fluent 构建器。COM 引用计数生命周期，消费方不手写释放。 *}
  IWebviewBuilder = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E007}']
    function Title(const ATitle: string): IWebviewBuilder;
    function Size(AWidth, AHeight: Integer): IWebviewBuilder;
    function MinSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function Resizable(AResizable: Boolean): IWebviewBuilder;
    function StartMaximized: IWebviewBuilder;
    function DebugTools(AEnabled: Boolean): IWebviewBuilder;
    function Scheme(const ASchemeName: string): IWebviewBuilder;
    function DataDirectory(const APath: string): IWebviewBuilder;
    function Ephemeral: IWebviewBuilder;
    function AddInitScript(const AJavascript: string): IWebviewBuilder; inline;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler): IWebviewBuilder;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler): IWebviewBuilder;
    function OnReady(AHandler: TWebviewNotifyHandler): IWebviewBuilder;
    function InitialUrl(const AUrl: string): IWebviewBuilder;
    function InitialHtml(const AHtml: string): IWebviewBuilder;
    function DevServerUrl(const AUrl: string): IWebviewBuilder;
    function Kind(AKind: TWebviewKind): IWebviewBuilder;
    function Parent(const AWindow: IWindow): IWebviewBuilder;
    function Build: IWebviewWindow;
    procedure Run(const AUrl: string);
    procedure RunHtml(const AHtml: string);
  end;

  {** 入口形态：`TWebviewBuilder.New.Title(..)...Run(url)`。 *}
  TWebviewBuilder = record
    class function New: IWebviewBuilder; static;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.collections.hashset,
  nextpas.core.window.factory,
  nextpas.core.webview.validation,
  nextpas.core.webview.live,
  nextpas.core.webview.factory;

type
  TFakeInvokeReg = record
    Cmd: string;
    Sync: TWebviewInvokeSyncHandler;
    Async: TWebviewInvokeAsyncHandler;
    IsAsync: Boolean;
  end;

  TBuilderImpl = class(TInterfacedObject, IWebviewBuilder)
  private
    FOptions: TWebviewOptions;
    FKind: TWebviewKind;
    FParent: IWindow;
    FInvokes: specialize TWebviewLiveRegistry<TFakeInvokeReg>;
    FReady: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>;
    FInitScripts: specialize TWebviewLiveRegistry<string>;
    FDedup: specialize THashSet<string>;
    function ApplyTo(AWin: IWebviewWindow): IWebviewWindow;
    procedure EnsureUniqueCmd(const ACmd: string); inline;
  public
    constructor Create;
    destructor Destroy; override;
    function Kind(AKind: TWebviewKind): IWebviewBuilder;
    function Parent(const AWindow: IWindow): IWebviewBuilder;
    function Title(const ATitle: string): IWebviewBuilder;
    function Size(AWidth, AHeight: Integer): IWebviewBuilder;
    function MinSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function Resizable(AResizable: Boolean): IWebviewBuilder;
    function StartMaximized: IWebviewBuilder;
    function DebugTools(AEnabled: Boolean): IWebviewBuilder;
    function Scheme(const ASchemeName: string): IWebviewBuilder;
    function DataDirectory(const APath: string): IWebviewBuilder;
    function Ephemeral: IWebviewBuilder;
    function AddInitScript(const AJavascript: string): IWebviewBuilder; inline;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler): IWebviewBuilder;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler): IWebviewBuilder;
    function OnReady(AHandler: TWebviewNotifyHandler): IWebviewBuilder;
    function InitialUrl(const AUrl: string): IWebviewBuilder;
    function InitialHtml(const AHtml: string): IWebviewBuilder;
    function DevServerUrl(const AUrl: string): IWebviewBuilder;
    function Build: IWebviewWindow;
    procedure Run(const AUrl: string);
    procedure RunHtml(const AHtml: string);
  end;

class function TWebviewBuilder.New: IWebviewBuilder;
begin
  Result := TBuilderImpl.Create;
end;

constructor TBuilderImpl.Create;
begin
  inherited Create;
  FOptions := DefaultWebviewOptions;
  FKind := DefaultWebviewKind;
  // perf: registry 单源收敛三组 Vec 样板，初始 nil 零分配，Grow 统一经 bytes.ops VecGrow 0→4→2× inline 零额外调用
  FInvokes := specialize TWebviewLiveRegistry<TFakeInvokeReg>.Create;
  FReady := specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create;
  FInitScripts := specialize TWebviewLiveRegistry<string>.Create;
  FDedup := specialize THashSet<string>.Create;
end;

destructor TBuilderImpl.Destroy;
begin
  // stability: registry Free 释放内部 Vec 并 nil 串/接口；dedup 复用 collections.hashset 单源，Swiss Table 自动 Finalize 全量串，资源释放不丢
  FDedup.Free;
  FDedup := nil;
  FInitScripts.Free;
  FReady.Free;
  FInvokes.Free;
  inherited;
end;

function TBuilderImpl.Title(const ATitle: string): IWebviewBuilder; inline;
begin
  FOptions.Title := ATitle;
  Result := Self;
end;

function TBuilderImpl.Size(AWidth, AHeight: Integer): IWebviewBuilder; inline;
begin
  CheckWebviewSize(AWidth, AHeight);
  FOptions.Width := AWidth;
  FOptions.Height := AHeight;
  Result := Self;
end;

function TBuilderImpl.MinSize(AWidth, AHeight: Integer): IWebviewBuilder; inline;
begin
  CheckWebviewMinSize(AWidth, AHeight, FOptions.MaxWidth, FOptions.MaxHeight);
  FOptions.MinWidth := AWidth;
  FOptions.MinHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.MaxSize(AWidth, AHeight: Integer): IWebviewBuilder; inline;
begin
  CheckWebviewMaxSize(AWidth, AHeight, FOptions.MinWidth, FOptions.MinHeight);
  FOptions.MaxWidth := AWidth;
  FOptions.MaxHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.Resizable(AResizable: Boolean): IWebviewBuilder; inline;
begin
  FOptions.Resizable := AResizable;
  Result := Self;
end;

function TBuilderImpl.StartMaximized: IWebviewBuilder; inline;
begin
  FOptions.Maximized := True;
  Result := Self;
end;

function TBuilderImpl.DebugTools(AEnabled: Boolean): IWebviewBuilder; inline;
begin
  FOptions.DebugTools := AEnabled;
  Result := Self;
end;

function TBuilderImpl.Scheme(const ASchemeName: string): IWebviewBuilder; inline;
begin
  if (ASchemeName <> '') and not IsValidWebviewSchemeToken(ASchemeName) then
    raise EWebviewInvalidState.CreateFmt(
      'SchemeName "%s" is not a valid lowercase scheme token', [ASchemeName]);
  FOptions.SchemeName := ASchemeName;
  Result := Self;
end;

function TBuilderImpl.DataDirectory(const APath: string): IWebviewBuilder; inline;
begin
  CheckWebviewSession(FOptions.EphemeralSession, APath);
  FOptions.DataDirectory := APath;
  Result := Self;
end;

function TBuilderImpl.Ephemeral: IWebviewBuilder; inline;
begin
  CheckWebviewSession(True, FOptions.DataDirectory);
  FOptions.EphemeralSession := True;
  Result := Self;
end;

function TBuilderImpl.Kind(AKind: TWebviewKind): IWebviewBuilder; inline;
begin
  FKind := AKind;
  Result := Self;
end;

function TBuilderImpl.Parent(const AWindow: IWindow): IWebviewBuilder; inline;
begin
  FParent := AWindow;
  Result := Self;
end;

function TBuilderImpl.AddInitScript(const AJavascript: string): IWebviewBuilder; inline;
begin
  CheckWebviewInitScript(AJavascript);
  // perf: registry Register -> WebviewLiveAdd -> bytes.ops VecGrow 单源 0→4→2× inline 零额外调用，零拷贝
  FInitScripts.Register(AJavascript);
  Result := Self;
end;

procedure TBuilderImpl.EnsureUniqueCmd(const ACmd: string); inline;
begin
  { perf: inline O(1) 平均哈希去重，复用 collections.hashset 单源 Swiss Table WyHash + 0.75 负载，零额外调用，零拷贝；资源由 THashSet 自动 Finalize 释放不丢，与 assets/bridge 单源一致 }
  if FDedup.Contains(ACmd) then
    raise EWebviewInvalidState.CreateFmt('duplicate invoke cmd in builder: %s', [ACmd]);
  FDedup.Add(ACmd);
end;

function TBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncHandler): IWebviewBuilder;
var
  LReg: TFakeInvokeReg;
begin
  CheckInvokeCmd(ACmd);
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.CreateFmt('invoke handler must not be nil: %s', [ACmd]);
  EnsureUniqueCmd(ACmd);
  // perf: registry Register 单源 VecGrow 0→4→2× inline 零额外调用
  LReg.Cmd := ACmd;
  LReg.Sync := AHandler;
  LReg.Async := nil;
  LReg.IsAsync := False;
  FInvokes.Register(LReg);
  Result := Self;
end;

function TBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncHandler): IWebviewBuilder;
var
  LReg: TFakeInvokeReg;
begin
  CheckInvokeCmd(ACmd);
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.CreateFmt('async invoke handler must not be nil: %s', [ACmd]);
  EnsureUniqueCmd(ACmd);
  LReg.Cmd := ACmd;
  LReg.Sync := nil;
  LReg.Async := AHandler;
  LReg.IsAsync := True;
  FInvokes.Register(LReg);
  Result := Self;
end;

function TBuilderImpl.OnReady(AHandler: TWebviewNotifyHandler): IWebviewBuilder; inline;
begin
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.Create('OnReady handler must not be nil');
  // perf: registry Register 单源 VecGrow inline
  FReady.Register(AHandler);
  Result := Self;
end;

function TBuilderImpl.InitialUrl(const AUrl: string): IWebviewBuilder; inline;
begin
  FOptions.InitialUrl := AUrl;
  Result := Self;
end;

function TBuilderImpl.InitialHtml(const AHtml: string): IWebviewBuilder; inline;
begin
  FOptions.InitialHtml := AHtml;
  Result := Self;
end;

function TBuilderImpl.DevServerUrl(const AUrl: string): IWebviewBuilder; inline;
begin
  FOptions.DevServerUrl := AUrl;
  Result := Self;
end;

function TBuilderImpl.ApplyTo(AWin: IWebviewWindow): IWebviewWindow;
var
  I: Integer;
  LReg: TFakeInvokeReg;
begin
  // perf: registry At inline O(1) + invoke 单源 Vec 单写，零额外堆分配
  for I := 0 to FInvokes.Count - 1 do
  begin
    LReg := FInvokes.At(I);
    if LReg.IsAsync then
      AWin.Invokes.RegisterAsync(LReg.Cmd, LReg.Async)
    else
      AWin.Invokes.Register(LReg.Cmd, LReg.Sync);
  end;
  for I := 0 to FReady.Count - 1 do
    AWin.OnReady(FReady.At(I));
  Result := AWin;
end;

function TBuilderImpl.Build: IWebviewWindow;
begin
  // perf: registry Snapshot -> bytes.ops VecSnapshot 单源 inline (nil fast path + single SetLength + per-elem copy), 零拷贝单源叙事统一
  // perf: 统一路由 DoCreateWebviewRouted 外联（路由/循环体禁 inline），Builder.Parent/CreateWebviewOn 单源收敛零重复分支；Snapshot 经 bytes.ops VecSnapshot 单源零拷贝
  FInitScripts.Snapshot(FOptions.InitScripts);
  if FParent <> nil then
    Result := ApplyTo(CreateWebviewEx(FParent, FKind, FOptions))
  else
    Result := ApplyTo(CreateWebviewOf(FKind, FOptions));
end;

procedure TBuilderImpl.Run(const AUrl: string);
var
  LWin: IWebviewWindow;
begin
  LWin := Build;
  LWin.Navigate(AUrl);
  WindowRunLoop;
end;

procedure TBuilderImpl.RunHtml(const AHtml: string);
var
  LWin: IWebviewWindow;
begin
  LWin := Build;
  LWin.NavigateToString(AHtml);
  WindowRunLoop;
end;

end.

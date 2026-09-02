unit nextpas.core.app.factory;

{** @desc nextpas.core.app 工厂与 Builder：薄封装 webview 工厂。
       P2：App 聚合窗口列表精确计数、自动摘除、Builder 资产挂载聚合；
       所有校验/容量复用 webview.base 单源（WebviewGrowCapacity）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.factory,
  nextpas.core.webview.builder,
  nextpas.core.app.base,
  nextpas.core.app.intf;

type
  TAppBuilder = record
    class function New: IAppBuilder; static;
  end;

function DefaultAppKind: TAppKind; inline;
function AppBackendAvailable(AKind: TAppKind): Boolean; inline;

implementation

uses
  nextpas.core.bytes.ops;

type
  TMountKind = (amEmbedded, amDirectory);
  TMountRec = record
    Kind: TMountKind;
    Prefix: string;
    Provider: IWebviewAssetProvider;
    RootDir: string;
  end;

  TAppImpl = class(TInterfacedObject, IApp)
  private
    FMain: IWebviewWindow;
    FWindows: array of IWebviewWindow;
    FCount: Integer;
    FKind: TAppKind;
    FOnClosed: array of TAppWindowClosedHandler;
    FOnClosedCount: Integer;
    FOnClosedM: array of TAppWindowClosedMethod;
    FOnClosedMCount: Integer;
    FOnClosedP: array of TAppWindowClosedProc;
    FOnClosedPCount: Integer;
    procedure GrowWindows; inline;
    procedure GrowOnClosed; inline;
    procedure GrowOnClosedM; inline;
    procedure GrowOnClosedP; inline;
    procedure HookWindowClose(ALockedWin: IWebviewWindow);
    procedure HandleAnyWindowClosed;
    procedure FireWindowClosed(const AWin: IWebviewWindow);
    procedure CompactClosed;
  public
    constructor Create(const AWindow: IWebviewWindow; AKind: TAppKind);
    destructor Destroy; override;
    function GetMainWindow: IWebviewWindow;
    function WindowCount: Integer;
    function GetWindow(AIdx: Integer): IWebviewWindow;
    function TryGetWindow(AIdx: Integer; out AWin: IWebviewWindow): Boolean;
    function GetWindows: TAppWindows;
    function NewWindowBuilder: IWebviewBuilder;
    function NewWindow: IWebviewBuilder;
    procedure AddWindow(AWin: IWebviewWindow);
    procedure RemoveWindow(AWin: IWebviewWindow);
    procedure OnWindowClosed(AHandler: TAppWindowClosedHandler); overload;
    procedure OnWindowClosed(AHandler: TAppWindowClosedMethod); overload;
    procedure OnWindowClosed(AHandler: TAppWindowClosedProc); overload;
    procedure Run;
    procedure Quit;
    procedure Close;
    function IsClosed: Boolean;
  end;

  TAppBuilderImpl = class(TInterfacedObject, IAppBuilder)
  private
    FBuilder: IWebviewBuilder;
    FKind: TAppKind;
    FMounts: array of TMountRec;
    FMountCount: Integer;
    procedure GrowMounts; inline;
    procedure ApplyMounts(AWin: IWebviewWindow);
  public
    constructor Create;
    function Title(const ATitle: string): IAppBuilder;
    function Size(AWidth, AHeight: Integer): IAppBuilder;
    function MinSize(AWidth, AHeight: Integer): IAppBuilder;
    function MaxSize(AWidth, AHeight: Integer): IAppBuilder;
    function Resizable(AResizable: Boolean): IAppBuilder;
    function StartMaximized: IAppBuilder;
    function DebugTools(AEnabled: Boolean): IAppBuilder;
    function Scheme(const ASchemeName: string): IAppBuilder;
    function DataDirectory(const APath: string): IAppBuilder;
    function Ephemeral: IAppBuilder;
    function AddInitScript(const AJavascript: string): IAppBuilder;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler): IAppBuilder; overload;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncMethod): IAppBuilder; overload;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncProc): IAppBuilder; overload;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler): IAppBuilder; overload;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncMethod): IAppBuilder; overload;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncProc): IAppBuilder; overload;
    function OnReady(AHandler: TWebviewNotifyHandler): IAppBuilder; overload;
    function OnReady(AHandler: TWebviewNotifyMethod): IAppBuilder; overload;
    function OnReady(AHandler: TWebviewNotifyProc): IAppBuilder; overload;
    function InitialUrl(const AUrl: string): IAppBuilder;
    function InitialHtml(const AHtml: string): IAppBuilder;
    function DevServerUrl(const AUrl: string): IAppBuilder;
    function MountEmbedded(const APrefix: string;
      AProvider: IWebviewAssetProvider): IAppBuilder;
    function MountDirectory(const APrefix, ARootDir: string): IAppBuilder;
    function Kind(AKind: TWebviewKind): IAppBuilder;
    function Build: IApp;
    procedure Run(const AUrl: string);
    procedure RunHtml(const AHtml: string);
  end;

class function TAppBuilder.New: IAppBuilder;
begin
  Result := TAppBuilderImpl.Create;
end;

function DefaultAppKind: TAppKind;
begin
  Result := nextpas.core.webview.factory.DefaultWebviewKind;
end;

function AppBackendAvailable(AKind: TAppKind): Boolean;
begin
  Result := nextpas.core.webview.factory.WebviewBackendAvailable(AKind);
end;

{ TAppImpl }

constructor TAppImpl.Create(const AWindow: IWebviewWindow; AKind: TAppKind);
begin
  inherited Create;
  FMain := AWindow;
  FKind := AKind;
  SetLength(FWindows, 0); FCount:=0;
  SetLength(FOnClosed, 0); FOnClosedCount:=0;
  SetLength(FOnClosedM, 0); FOnClosedMCount:=0;
  SetLength(FOnClosedP, 0); FOnClosedPCount:=0;
  if (FMain <> nil) then
  begin
    SetLength(FWindows, 4); FWindows[0]:=FMain; FCount:=1;
    HookWindowClose(FMain);
  end;
end;

destructor TAppImpl.Destroy;
begin
  SetLength(FWindows, 0);
  SetLength(FOnClosed, 0);
  SetLength(FOnClosedM, 0);
  SetLength(FOnClosedP, 0);
  inherited;
end;

procedure TAppImpl.GrowWindows; inline;
begin
  specialize VecGrow<IWebviewWindow>(FWindows, FCount);
end;

procedure TAppImpl.GrowOnClosed; inline;
begin
  specialize VecGrow<TAppWindowClosedHandler>(FOnClosed, FOnClosedCount);
end;

procedure TAppImpl.GrowOnClosedM; inline;
begin
  specialize VecGrow<TAppWindowClosedMethod>(FOnClosedM, FOnClosedMCount);
end;

procedure TAppImpl.GrowOnClosedP; inline;
begin
  specialize VecGrow<TAppWindowClosedProc>(FOnClosedP, FOnClosedPCount);
end;

procedure TAppImpl.HookWindowClose(ALockedWin: IWebviewWindow);
begin
  ALockedWin.OnWindowClosed(
    procedure
    begin
      HandleAnyWindowClosed;
    end);
end;

procedure TAppImpl.HandleAnyWindowClosed;
var I,J: Integer; LWin: IWebviewWindow;
begin
  I:=0;
  while I < FCount do
  begin
    LWin:=FWindows[I];
    if (LWin<>nil) and LWin.IsClosed then
    begin
      for J:=I to FCount-2 do FWindows[J]:=FWindows[J+1];
      FWindows[FCount-1]:=nil; Dec(FCount);
      FireWindowClosed(LWin);
    end else Inc(I);
  end;
end;

procedure TAppImpl.FireWindowClosed(const AWin: IWebviewWindow);
var I: Integer;
begin
  for I:=0 to FOnClosedCount-1 do if Assigned(FOnClosed[I]) then try FOnClosed[I](AWin); except end;
  for I:=0 to FOnClosedMCount-1 do if Assigned(FOnClosedM[I]) then try FOnClosedM[I](AWin); except end;
  for I:=0 to FOnClosedPCount-1 do if Assigned(FOnClosedP[I]) then try FOnClosedP[I](AWin); except end;
end;

procedure TAppImpl.CompactClosed;
var I,J: Integer;
begin
  J:=0;
  for I:=0 to FCount-1 do if (FWindows[I]<>nil) and not FWindows[I].IsClosed then begin if J<>I then FWindows[J]:=FWindows[I]; Inc(J); end;
  for I:=J to FCount-1 do FWindows[I]:=nil; FCount:=J;
end;

function TAppImpl.GetMainWindow: IWebviewWindow; begin Result:=FMain; end;

function TAppImpl.WindowCount: Integer;
begin
  CompactClosed;
  Result:=FCount;
end;

function TAppImpl.GetWindow(AIdx: Integer): IWebviewWindow;
begin
  CompactClosed;
  if (AIdx < 0) or (AIdx >= FCount) then
    raise EAppInvalidState.CreateFmt('window index %d out of range [0,%d)', [AIdx, FCount]);
  Result:=FWindows[AIdx];
end;

function TAppImpl.TryGetWindow(AIdx: Integer; out AWin: IWebviewWindow): Boolean;
begin
  CompactClosed;
  if (AIdx < 0) or (AIdx >= FCount) then
  begin
    AWin := nil;
    Result := False;
  end else
  begin
    AWin := FWindows[AIdx];
    Result := True;
  end;
end;

function TAppImpl.GetWindows: TAppWindows;
var I: Integer;
begin
  Result:=nil;
  CompactClosed;
  SetLength(Result, FCount);
  for I:=0 to FCount-1 do Result[I]:=FWindows[I];
end;

function TAppImpl.NewWindowBuilder: IWebviewBuilder;
begin
  Result := nextpas.core.webview.builder.TWebviewBuilder.New.Kind(FKind);
end;

function TAppImpl.NewWindow: IWebviewBuilder;
begin
  Result := NewWindowBuilder;
end;

procedure TAppImpl.AddWindow(AWin: IWebviewWindow);
var
  I: Integer;
begin
  if (AWin = nil) or AWin.IsClosed then
    raise EAppInvalidState.Create('AddWindow requires open window');
  for I := 0 to FCount - 1 do
    if FWindows[I] = AWin then
      raise EAppInvalidState.Create('window already in app');
  if FCount = Length(FWindows) then GrowWindows;
  FWindows[FCount] := AWin;
  Inc(FCount);
  HookWindowClose(AWin);
end;

procedure TAppImpl.RemoveWindow(AWin: IWebviewWindow);
var I,J: Integer;
begin
  for I:=0 to FCount-1 do if FWindows[I]=AWin then
  begin
    for J:=I to FCount-2 do FWindows[J]:=FWindows[J+1];
    FWindows[FCount-1]:=nil; Dec(FCount);
    FireWindowClosed(AWin);
    Exit;
  end;
end;

procedure TAppImpl.OnWindowClosed(AHandler: TAppWindowClosedHandler);
begin
  if not Assigned(AHandler) then raise EAppInvalidState.Create('OnWindowClosed handler must not be nil');
  if FOnClosedCount=Length(FOnClosed) then GrowOnClosed;
  FOnClosed[FOnClosedCount]:=AHandler; Inc(FOnClosedCount);
end;

procedure TAppImpl.OnWindowClosed(AHandler: TAppWindowClosedMethod);
begin
  if not Assigned(AHandler) then raise EAppInvalidState.Create('OnWindowClosed handler must not be nil');
  if FOnClosedMCount=Length(FOnClosedM) then GrowOnClosedM;
  FOnClosedM[FOnClosedMCount]:=AHandler; Inc(FOnClosedMCount);
end;

procedure TAppImpl.OnWindowClosed(AHandler: TAppWindowClosedProc);
begin
  if not Assigned(AHandler) then raise EAppInvalidState.Create('OnWindowClosed handler must not be nil');
  if FOnClosedPCount=Length(FOnClosedP) then GrowOnClosedP;
  FOnClosedP[FOnClosedPCount]:=AHandler; Inc(FOnClosedPCount);
end;

procedure TAppImpl.Run;
begin
  nextpas.core.webview.factory.WebviewRunLoop;
end;

procedure TAppImpl.Quit;
begin
  nextpas.core.webview.factory.WebviewExitLoop;
end;

procedure TAppImpl.Close;
var
  I: Integer;
  LSnapshot: array of IWebviewWindow;
begin
  // Snapshot to avoid index shift when HandleAnyWindowClosed mutates FWindows.
  SetLength(LSnapshot, FCount);
  for I := 0 to FCount - 1 do
    LSnapshot[I] := FWindows[I];
  for I := 0 to High(LSnapshot) do
    if (LSnapshot[I] <> nil) and (not LSnapshot[I].IsClosed) then
      LSnapshot[I].Close;
end;

function TAppImpl.IsClosed: Boolean;
begin
  Result := WindowCount = 0;
end;

{ TAppBuilderImpl }

constructor TAppBuilderImpl.Create;
begin
  inherited Create;
  FBuilder := nextpas.core.webview.builder.TWebviewBuilder.New;
  FKind := DefaultAppKind;
end;

procedure TAppBuilderImpl.GrowMounts; inline;
begin
  specialize VecGrow<TMountRec>(FMounts, FMountCount);
end;

procedure TAppBuilderImpl.ApplyMounts(AWin: IWebviewWindow);
var
  I: Integer;
begin
  for I := 0 to FMountCount - 1 do
    case FMounts[I].Kind of
      amEmbedded: AWin.Assets.MountEmbedded(FMounts[I].Prefix, FMounts[I].Provider);
      amDirectory: AWin.Assets.MountDirectory(FMounts[I].Prefix, FMounts[I].RootDir);
    end;
end;

function TAppBuilderImpl.Title(const ATitle: string): IAppBuilder;
begin
  FBuilder.Title(ATitle);
  Result := Self;
end;

function TAppBuilderImpl.Size(AWidth, AHeight: Integer): IAppBuilder;
begin
  FBuilder.Size(AWidth, AHeight);
  Result := Self;
end;

function TAppBuilderImpl.MinSize(AWidth, AHeight: Integer): IAppBuilder;
begin
  FBuilder.MinSize(AWidth, AHeight);
  Result := Self;
end;

function TAppBuilderImpl.MaxSize(AWidth, AHeight: Integer): IAppBuilder;
begin
  FBuilder.MaxSize(AWidth, AHeight);
  Result := Self;
end;

function TAppBuilderImpl.Resizable(AResizable: Boolean): IAppBuilder;
begin
  FBuilder.Resizable(AResizable);
  Result := Self;
end;

function TAppBuilderImpl.StartMaximized: IAppBuilder;
begin
  FBuilder.StartMaximized;
  Result := Self;
end;

function TAppBuilderImpl.DebugTools(AEnabled: Boolean): IAppBuilder;
begin
  FBuilder.DebugTools(AEnabled);
  Result := Self;
end;

function TAppBuilderImpl.Scheme(const ASchemeName: string): IAppBuilder;
begin
  FBuilder.Scheme(ASchemeName);
  Result := Self;
end;

function TAppBuilderImpl.DataDirectory(const APath: string): IAppBuilder;
begin
  FBuilder.DataDirectory(APath);
  Result := Self;
end;

function TAppBuilderImpl.Ephemeral: IAppBuilder;
begin
  FBuilder.Ephemeral;
  Result := Self;
end;

function TAppBuilderImpl.AddInitScript(const AJavascript: string): IAppBuilder;
begin
  FBuilder.AddInitScript(AJavascript);
  Result := Self;
end;

function TAppBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncHandler): IAppBuilder;
begin
  FBuilder.RegisterInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncMethod): IAppBuilder;
begin
  FBuilder.RegisterInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncProc): IAppBuilder;
begin
  FBuilder.RegisterInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncHandler): IAppBuilder;
begin
  FBuilder.RegisterAsyncInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncMethod): IAppBuilder;
begin
  FBuilder.RegisterAsyncInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncProc): IAppBuilder;
begin
  FBuilder.RegisterAsyncInvoke(ACmd, AHandler);
  Result := Self;
end;

function TAppBuilderImpl.OnReady(AHandler: TWebviewNotifyHandler): IAppBuilder;
begin
  FBuilder.OnReady(AHandler);
  Result := Self;
end;

function TAppBuilderImpl.OnReady(AHandler: TWebviewNotifyMethod): IAppBuilder;
begin
  FBuilder.OnReady(AHandler);
  Result := Self;
end;

function TAppBuilderImpl.OnReady(AHandler: TWebviewNotifyProc): IAppBuilder;
begin
  FBuilder.OnReady(AHandler);
  Result := Self;
end;

function TAppBuilderImpl.InitialUrl(const AUrl: string): IAppBuilder;
begin
  FBuilder.InitialUrl(AUrl);
  Result := Self;
end;

function TAppBuilderImpl.InitialHtml(const AHtml: string): IAppBuilder;
begin
  FBuilder.InitialHtml(AHtml);
  Result := Self;
end;

function TAppBuilderImpl.DevServerUrl(const AUrl: string): IAppBuilder;
begin
  FBuilder.DevServerUrl(AUrl);
  Result := Self;
end;

function TAppBuilderImpl.MountEmbedded(const APrefix: string;
  AProvider: IWebviewAssetProvider): IAppBuilder;
begin
  if AProvider = nil then
    raise EAppInvalidState.Create('MountEmbedded provider must not be nil');
  if FMountCount = Length(FMounts) then GrowMounts;
  FMounts[FMountCount].Kind := amEmbedded;
  FMounts[FMountCount].Prefix := APrefix;
  FMounts[FMountCount].Provider := AProvider;
  FMounts[FMountCount].RootDir := '';
  Inc(FMountCount);
  Result := Self;
end;

function TAppBuilderImpl.MountDirectory(const APrefix, ARootDir: string): IAppBuilder;
begin
  if ARootDir = '' then
    raise EAppInvalidState.Create('MountDirectory root must not be empty');
  if FMountCount = Length(FMounts) then GrowMounts;
  FMounts[FMountCount].Kind := amDirectory;
  FMounts[FMountCount].Prefix := APrefix;
  FMounts[FMountCount].Provider := nil;
  FMounts[FMountCount].RootDir := ARootDir;
  Inc(FMountCount);
  Result := Self;
end;

function TAppBuilderImpl.Kind(AKind: TWebviewKind): IAppBuilder;
begin
  FBuilder.Kind(AKind);
  FKind := AKind;
  Result := Self;
end;

function TAppBuilderImpl.Build: IApp;
var
  LWin: IWebviewWindow;
begin
  LWin := FBuilder.Build;
  ApplyMounts(LWin);
  Result := TAppImpl.Create(LWin, FKind);
end;

procedure TAppBuilderImpl.Run(const AUrl: string);
var
  LApp: IApp;
begin
  LApp := Build;
  LApp.MainWindow.Navigate(AUrl);
  LApp.Run;
end;

procedure TAppBuilderImpl.RunHtml(const AHtml: string);
var
  LApp: IApp;
begin
  LApp := Build;
  LApp.MainWindow.NavigateToString(AHtml);
  LApp.Run;
end;

end.

unit nextpas.core.window.uikit;

{** @desc UIKit surface attach 后端。
       依托 uikit.ffi/.loader（platform.dl 装载），实现 IWindow 的
       attach 形态：ParentHandle 携带 UIWindow*（宿主提供），几何只读。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf;

function WindowUIKitIsAvailable: Boolean;
function CreateWindowUIKit(const AOptions: TWindowOptions): IWindow;
function UIKitLiveWindowCount: Integer;
procedure WindowUIKitRunLoop;
procedure WindowUIKitQuitLoop;
function UIKitPumpOnce: Boolean;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.thread,
  nextpas.core.sync.event,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.time.base,
  nextpas.core.window.uikit.ffi,
  nextpas.core.window.uikit.loader;

var
  GLoopQuit: Boolean = False;
  GLiveWindows: array of Pointer;
  GDispLock: ILock;
  GDispRing: array of TWindowProcRef;
  GDispHead: Integer = 0;
  GDispCount: Integer = 0;
  GWaitEvent: IEvent;

function WindowUIKitIsAvailable: Boolean;
var
  LInfo: TWindowUIKitLoadInfo;
begin
  Result := TryLoadWindowUIKit(LInfo) and LInfo.Loaded;
end;

function UIKitLiveWindowCount: Integer;
begin
  Result := Length(GLiveWindows);
end;

procedure RegisterLive(AWin: Pointer);
begin
  SetLength(GLiveWindows, Length(GLiveWindows)+1);
  GLiveWindows[High(GLiveWindows)] := AWin;
end;

procedure UnregisterLive(AWin: Pointer);
var
  I: Integer;
begin
  for I := High(GLiveWindows) downto 0 do
    if GLiveWindows[I] = AWin then
    begin
      GLiveWindows[I] := GLiveWindows[High(GLiveWindows)];
      SetLength(GLiveWindows, Length(GLiveWindows)-1);
      Break;
    end;
end;

function EventMethodToRef(AHandler: TWindowEventMethod): TWindowEventHandler;
begin Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end; end;

function EventProcToRef(AHandler: TWindowEventProc): TWindowEventHandler;
begin Result := procedure(const AEvent: TWindowEvent) begin AHandler(AEvent); end; end;

function WindowMethodToRef(AHandler: TWindowProcMethod): TWindowProcRef;
begin Result := procedure begin AHandler(); end; end;

function WindowProcToRef(AHandler: TWindowProc): TWindowProcRef;
begin Result := procedure begin AHandler(); end; end;

procedure DispatcherGrow;
var
  LNewCap, I: Integer;
  LNew: array of TWindowProcRef;
begin
  LNewCap := Length(GDispRing)*2;
  if LNewCap=0 then LNewCap:=32;
  SetLength(LNew, LNewCap);
  for I:=0 to GDispCount-1 do
    LNew[I] := GDispRing[(GDispHead+I) mod Length(GDispRing)];
  GDispRing := LNew;
  GDispHead := 0;
end;

procedure DispatcherPush(AProc: TWindowProcRef);
begin
  if GDispLock=nil then GDispLock := TMutex.Create as ILock;
  if GWaitEvent=nil then GWaitEvent := CreateEvent(False);
  GDispLock.Acquire;
  try
    if GDispCount=Length(GDispRing) then DispatcherGrow;
    GDispRing[(GDispHead+GDispCount) mod Length(GDispRing)] := AProc;
    Inc(GDispCount);
  finally GDispLock.Release; end;
  GWaitEvent.SetEvent;
end;

function DispatcherPop(out AProc: TWindowProcRef): Boolean;
begin
  Result:=False; AProc:=nil;
  if GDispLock=nil then Exit;
  GDispLock.Acquire;
  try
    if GDispCount=0 then Exit;
    AProc:=GDispRing[GDispHead];
    GDispRing[GDispHead]:=nil;
    GDispHead := (GDispHead+1) mod Length(GDispRing);
    Dec(GDispCount);
    Result:=True;
  finally GDispLock.Release; end;
end;

procedure DispatcherDrain;
var
  LProc: TWindowProcRef;
begin
  while DispatcherPop(LProc) do
  begin
    try if Assigned(LProc) then LProc(); except raise; end;
    LProc:=nil;
  end;
end;

type
  TWindowUIKitDispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FOwnerThread: UInt64;
  public
    constructor Create(AOwnerThread: UInt64);
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TWindowUIKitDispatcher.Create(AOwnerThread: UInt64);
begin inherited Create; FOwnerThread := AOwnerThread; end;

function TWindowUIKitDispatcher.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowUIKitDispatcher.Post(AProc: TWindowProcRef);
begin if not Assigned(AProc) then Exit; DispatcherPush(AProc); end;

procedure TWindowUIKitDispatcher.Post(AProc: TWindowProcMethod);
begin Post(WindowMethodToRef(AProc)); end;

procedure TWindowUIKitDispatcher.Post(AProc: TWindowProc);
begin Post(WindowProcToRef(AProc)); end;

type
  TWindowUIKit = class(TInterfacedObject, IWindow, IWindowHost)
  private
    FHandle: TWindowNativeHandle;
    FClosed: Boolean;
    FVisible: Boolean;
    FTitle: string;
    FWidth, FHeight: Integer;
    FOwnerThread: UInt64;
    FDispatcher: IWindowDispatcher;
    FOnEvent: TWindowEventHandler;
    procedure RequireOpen; inline;
    procedure DoDispatch(const AEvent: TWindowEvent); inline;
    procedure RealClose;
    function IsOnMainThread: Boolean; inline;
  protected
    procedure Close;
    function IsClosed: Boolean; inline;
    procedure Show;
    procedure Hide;
    function IsVisible: Boolean;
    procedure Focus;
    procedure SetTitle(const ATitle: string);
    function GetTitle: string;
    procedure SetBounds(AWidth, AHeight: Integer);
    function GetWidth: Integer; inline;
    function GetHeight: Integer; inline;
    procedure SetResizable(AResizable: Boolean);
    procedure Maximize;
    procedure Unmaximize;
    function IsMaximized: Boolean;
    procedure Minimize;
    procedure Restore;
    function IsMinimized: Boolean;
    function GetScaleFactor: Double;
    function NativeHandle: TWindowNativeHandle;
    function GetDispatcher: IWindowDispatcher; inline;
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

constructor TWindowUIKit.Create(const AOptions: TWindowOptions);
var
  LInfo: TWindowUIKitLoadInfo;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadWindowUIKit(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('UIKit backend not available (not iOS host)');
  if AOptions.ParentHandle = nil then
    raise EWindowUnsupported.Create('UIKit attach requires ParentHandle (UIWindow*)');
  FClosed := False;
  FVisible := False;
  FTitle := AOptions.Title;
  if AOptions.Width <= 0 then FWidth := DefaultWindowOptions.Width else FWidth := AOptions.Width;
  if AOptions.Height <= 0 then FHeight := DefaultWindowOptions.Height else FHeight := AOptions.Height;
  FHandle := AOptions.ParentHandle;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowUIKitDispatcher.Create(FOwnerThread);
  RegisterLive(Pointer(Self));
end;

destructor TWindowUIKit.Destroy;
begin
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowUIKit.RequireOpen;
begin if FClosed then raise EWindowClosed.Create('window is closed'); end;

procedure TWindowUIKit.DoDispatch(const AEvent: TWindowEvent);
var
  H: TWindowEventHandler;
begin
  if FClosed then Exit;
  H := FOnEvent;
  if Assigned(H) then H(AEvent);
end;

procedure TWindowUIKit.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  FVisible := False;
  FHandle := nil;
  UnregisterLive(Pointer(Self));
  if UIKitLiveWindowCount = 0 then GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
end;

function TWindowUIKit.IsOnMainThread: Boolean; inline;
begin Result := platform_thread_id = FOwnerThread; end;

procedure TWindowUIKit.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowUIKit.IsClosed: Boolean; inline; begin Result := FClosed; end;

procedure TWindowUIKit.Show;
begin RequireOpen; FVisible := True; end;

procedure TWindowUIKit.Hide;
begin RequireOpen; FVisible := False; end;

function TWindowUIKit.IsVisible: Boolean;
begin RequireOpen; Result := FVisible; end;

procedure TWindowUIKit.Focus;
begin RequireOpen; end;

procedure TWindowUIKit.SetTitle(const ATitle: string);
begin RequireOpen; FTitle := ATitle; end;

function TWindowUIKit.GetTitle: string;
begin RequireOpen; Result := FTitle; end;

procedure TWindowUIKit.SetBounds(AWidth, AHeight: Integer);
begin RequireOpen; end;

function TWindowUIKit.GetWidth: Integer; inline;
begin RequireOpen; Result := FWidth; end;

function TWindowUIKit.GetHeight: Integer; inline;
begin RequireOpen; Result := FHeight; end;

procedure TWindowUIKit.SetResizable(AResizable: Boolean);
begin RequireOpen; end;

procedure TWindowUIKit.Maximize;
begin RequireOpen; end;

procedure TWindowUIKit.Unmaximize;
begin RequireOpen; end;

function TWindowUIKit.IsMaximized: Boolean;
begin RequireOpen; Result := False; end;

procedure TWindowUIKit.Minimize;
begin RequireOpen; end;

procedure TWindowUIKit.Restore;
begin RequireOpen; end;

function TWindowUIKit.IsMinimized: Boolean;
begin RequireOpen; Result := False; end;

function TWindowUIKit.GetScaleFactor: Double;
begin RequireOpen; Result := 2.0; end;

function TWindowUIKit.NativeHandle: TWindowNativeHandle;
begin
  if FClosed then Exit(nil);
  Result := FHandle;
end;

function TWindowUIKit.GetDispatcher: IWindowDispatcher; inline;
begin Result := FDispatcher; end;

procedure TWindowUIKit.OnEvent(AHandler: TWindowEventHandler);
begin RequireOpen; FOnEvent := AHandler; end;

procedure TWindowUIKit.OnEvent(AHandler: TWindowEventMethod);
begin OnEvent(EventMethodToRef(AHandler)); end;

procedure TWindowUIKit.OnEvent(AHandler: TWindowEventProc);
begin OnEvent(EventProcToRef(AHandler)); end;

procedure TWindowUIKit.HostResized(AWidth, AHeight: Integer);
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostResized(AWidth, AHeight); end); Exit; end; RequireOpen; if AWidth<0 then AWidth:=0; if AHeight<0 then AHeight:=0; FWidth:=AWidth; FHeight:=AHeight; E.Kind:=weResized; E.Width:=FWidth; E.Height:=FHeight; E.X:=0; E.Y:=0; E.NewScale:=0; DoDispatch(E); end;

procedure TWindowUIKit.HostScaleChanged(ANewScale: Double);
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostScaleChanged(ANewScale); end); Exit; end; RequireOpen; E.Kind:=weScaleChanged; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=ANewScale; DoDispatch(E); end;

procedure TWindowUIKit.HostCloseRequested;
var E: TWindowEvent;
begin if not IsOnMainThread then begin FDispatcher.Post(procedure begin HostCloseRequested; end); Exit; end; RequireOpen; E.Kind:=weCloseRequested; E.Width:=0; E.Height:=0; E.X:=0; E.Y:=0; E.NewScale:=0; DoDispatch(E); end;

function CreateWindowUIKit(const AOptions: TWindowOptions): IWindow;
begin Result := TWindowUIKit.Create(AOptions); end;

procedure WindowUIKitRunLoop;
begin
  GLoopQuit := False;
  if GWaitEvent=nil then GWaitEvent := CreateEvent(False);
  while not GLoopQuit do
  begin
    DispatcherDrain;
    if UIKitLiveWindowCount = 0 then Break;
    GWaitEvent.Wait;
    if UIKitLiveWindowCount = 0 then Break;
  end;
end;

function UIKitPumpOnce: Boolean;
var LProc: TWindowProcRef;
begin Result := DispatcherPop(LProc); if Result then try if Assigned(LProc) then LProc(); except raise; end; end;

procedure WindowUIKitQuitLoop;
begin
  GLoopQuit := True;
  if GWaitEvent<>nil then GWaitEvent.SetEvent;
  DispatcherDrain;
end;

end.

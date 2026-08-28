{**
  Shared GTK window backend implementation for window.gtk3/gtk4/gtk2.
  This file is included via {$I nextpas.core.window.gtk.impl.inc} from each
  thin wrapper (window.gtk3.pas / window.gtk4.pas / window.gtk2.pas).
  Wrapper must define before inclusion:
    - TGtkLoadInfo = <family-specific>LoadInfo (TGtk3LoadInfo / TGtk4LoadInfo / TGtk2LoadInfo)
    - function TryLoadGtk(out AInfo: TGtkLoadInfo): Boolean;
  and must have uses of the matching family base/ffi/loader + live + thread + sync.

  No external uses here; all symbols (gtk_*, g_*, GDK_*, gboolean etc) come from
  the wrapper's uses clause. Per-unit globals (GInitDone/GInitOk/GLiveRegistry)
  remain isolated per family (separate compilation). *}

var
  GInitDone: Boolean = False;
  GInitOk: Boolean = False;
  GMainLoopRunning: Boolean = False;
  GLiveRegistry: TWindowLiveRegistry;

function EnsureGtkInit: Boolean;
var
  LArgc: Int32 = 0;
begin
  if not GInitDone then
  begin
    Math.SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
      exOverflow, exUnderflow, exPrecision]);
    GInitOk := gtk_init_check(@LArgc, nil) <> 0;
    GInitDone := True;
  end;
  Result := GInitOk;
end;

function WindowGtkIsAvailable: Boolean;
var
  LInfo: TGtkLoadInfo;
begin
  Result := TryLoadGtk(LInfo) and LInfo.Loaded;
end;

{ ---- Dispatcher via g_idle_add_full ---- }

type
  PIdleClosure = ^TIdleClosure;
  TIdleClosure = record
    Proc: TWindowProcRef;
  end;

function IdleCallback(AData: Pointer): gboolean; cdecl;
var
  P: PIdleClosure;
  LProc: TWindowProcRef;
begin
  P := PIdleClosure(AData);
  LProc := P^.Proc;
  P^.Proc := nil;
  Dispose(P);
  try
    if Assigned(LProc) then LProc();
  except
    raise;
  end;
  Result := GLIB_SOURCE_REMOVE;
end;

procedure IdleDestroy(AData: Pointer); cdecl;
var
  P: PIdleClosure;
begin
  P := PIdleClosure(AData);
  if P <> nil then
  begin
    P^.Proc := nil;
    Dispose(P);
  end;
end;

type
  TWindowGtkDispatcher = class(TInterfacedObject, IWindowDispatcher)
  private
    FOwnerThread: UInt64;
    FLck: ILock;
    FPending: array of guint;
    procedure Track(ATag: guint); inline;
    procedure Untrack(ATag: guint); inline;
  public
    constructor Create(AOwnerThread: UInt64);
    destructor Destroy; override;
    procedure DropAll;
    function IsOnMainThread: Boolean; inline;
    procedure Post(AProc: TWindowProcRef); overload;
    procedure Post(AProc: TWindowProcMethod); overload;
    procedure Post(AProc: TWindowProc); overload;
  end;

constructor TWindowGtkDispatcher.Create(AOwnerThread: UInt64);
begin
  inherited Create;
  FOwnerThread := AOwnerThread;
  FLck := TMutex.Create as ILock;
end;

destructor TWindowGtkDispatcher.Destroy;
begin
  DropAll;
  inherited;
end;

procedure TWindowGtkDispatcher.Track(ATag: guint);
begin
  FLck.Acquire;
  try
    SetLength(FPending, Length(FPending)+1);
    FPending[High(FPending)] := ATag;
  finally
    FLck.Release;
  end;
end;

procedure TWindowGtkDispatcher.Untrack(ATag: guint);
var
  I: Integer;
begin
  FLck.Acquire;
  try
    for I := High(FPending) downto 0 do
      if FPending[I] = ATag then
      begin
        FPending[I] := FPending[High(FPending)];
        SetLength(FPending, Length(FPending)-1);
        Break;
      end;
  finally
    FLck.Release;
  end;
end;

procedure TWindowGtkDispatcher.DropAll;
var
  I: Integer;
  LCopy: array of guint;
begin
  FLck.Acquire;
  try
    LCopy := Copy(FPending);
    SetLength(FPending, 0);
  finally
    FLck.Release;
  end;
  for I := 0 to High(LCopy) do
    g_source_remove(LCopy[I]);
end;

function TWindowGtkDispatcher.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowGtkDispatcher.Post(AProc: TWindowProcRef);
var
  P: PIdleClosure;
  LTag: guint;
begin
  if not Assigned(AProc) then Exit;
  New(P);
  P^.Proc := AProc;
  LTag := g_idle_add_full(G_PRIORITY_DEFAULT, @IdleCallback, P, @IdleDestroy);
  Track(LTag);
end;

procedure TWindowGtkDispatcher.Post(AProc: TWindowProcMethod);
begin
  Post(WindowMethodToRef(AProc));
end;

procedure TWindowGtkDispatcher.Post(AProc: TWindowProc);
begin
  Post(WindowProcToRef(AProc));
end;

function GtkLiveWindowCount: Integer;
begin
  if GLiveRegistry = nil then Exit(0);
  Result := GLiveRegistry.Count;
end;

procedure RegisterLive(AWin: Pointer);
begin
  if GLiveRegistry = nil then
    GLiveRegistry := TWindowLiveRegistry.Create;
  GLiveRegistry.Register(AWin);
end;

procedure UnregisterLive(AWin: Pointer);
begin
  if GLiveRegistry = nil then Exit;
  GLiveRegistry.Unregister(AWin);
end;

{ ---- TWindowGtk ---- }

type
  TWindowGtk = class(TInterfacedObject, IWindow)
  private
    FHandle: Pointer;
    FClosed: Boolean;
    FVisible: Boolean;
    FResizable: Boolean;
    FMaximized: Boolean;
    FMinimized: Boolean;
    FTitle: string;
    FWidth: Integer;
    FHeight: Integer;
    FOwnerThread: UInt64;
    FDispatcher: IWindowDispatcher;
    FOnEvent: TWindowEventHandler;
    FSignalDelete: gulong;
    FSignalConfigure: gulong;
    FSignalFocusIn: gulong;
    FSignalFocusOut: gulong;
    FSignalScale: gulong;
    FSignalDestroy: gulong;
    FSignalState: gulong;
    procedure RequireOpen; inline;
    procedure DoDispatch(const AEvent: TWindowEvent); inline;
    procedure RealClose;
    procedure ConnectSignals;
    procedure DisconnectSignals;
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
    function GetDispatcher: IWindowDispatcher;
    procedure OnEvent(AHandler: TWindowEventHandler); overload;
    procedure OnEvent(AHandler: TWindowEventMethod); overload;
    procedure OnEvent(AHandler: TWindowEventProc); overload;
  public
    constructor Create(const AOptions: TWindowOptions);
    destructor Destroy; override;
  end;

{ ---- Signal callbacks ---- }

function CbDelete(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
begin
  Self := TWindowGtk(AData);
  E.Kind := weCloseRequested;
  E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0; E.NewScale := 0;
  Self.DoDispatch(E);
  Result := 1;
end;

function CbConfigure(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
  W, H: gint;
begin
  Self := TWindowGtk(AData);
  W := gtk_widget_get_allocated_width(Self.FHandle);
  H := gtk_widget_get_allocated_height(Self.FHandle);
  Self.FWidth := W;
  Self.FHeight := H;
  E.Kind := weResized;
  E.Width := W; E.Height := H; E.X := 0; E.Y := 0; E.NewScale := 0;
  Self.DoDispatch(E);
  Result := 0;
end;

function CbFocusIn(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
begin
  Self := TWindowGtk(AData);
  E.Kind := weFocusIn;
  E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0; E.NewScale := 0;
  Self.DoDispatch(E);
  Result := 0;
end;

function CbFocusOut(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
begin
  Self := TWindowGtk(AData);
  E.Kind := weFocusOut;
  E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0; E.NewScale := 0;
  Self.DoDispatch(E);
  Result := 0;
end;

procedure CbScaleNotify(AObj: Pointer; AParam: Pointer; AData: Pointer); cdecl;
var
  Self: TWindowGtk;
  E: TWindowEvent;
  S: gint;
begin
  Self := TWindowGtk(AData);
  S := gtk_widget_get_scale_factor(Self.FHandle);
  if S <= 0 then S := 1;
  E.Kind := weScaleChanged;
  E.Width := 0; E.Height := 0; E.X := 0; E.Y := 0;
  E.NewScale := S;
  Self.DoDispatch(E);
end;

procedure CbDestroy(AWidget: Pointer; AData: Pointer); cdecl;
var
  Self: TWindowGtk;
begin
  Self := TWindowGtk(AData);
  if not Self.FClosed then
  begin
    Self.FClosed := True;
    Self.FVisible := False;
    Self.FHandle := nil;
    UnregisterLive(Pointer(Self));
  end;
end;

function CbWindowState(AWidget: Pointer; AEvent: Pointer; AData: Pointer): gboolean; cdecl;
begin
  Result := 0;
end;

{ ---- TWindowGtk impl ---- }

constructor TWindowGtk.Create(const AOptions: TWindowOptions);
var
  LInfo: TGtkLoadInfo;
begin
  inherited Create;
  CheckWindowOptions(AOptions);
  if not TryLoadGtk(LInfo) or not LInfo.Loaded then
    raise EWindowBackendUnavailable.Create('GTK backend not available');
  if not EnsureGtkInit then
    raise EWindowNotInitialized.Create('gtk_init_check failed (no display?)');

  FClosed := False;
  FVisible := False;
  FResizable := AOptions.Resizable;
  FMaximized := AOptions.Maximized;
  FMinimized := False;
  FTitle := AOptions.Title;
  if AOptions.Width <= 0 then
    FWidth := DefaultWindowOptions.Width
  else
    FWidth := AOptions.Width;
  if AOptions.Height <= 0 then
    FHeight := DefaultWindowOptions.Height
  else
    FHeight := AOptions.Height;
  FOwnerThread := platform_thread_id;
  FDispatcher := TWindowGtkDispatcher.Create(FOwnerThread) as IWindowDispatcher;

  FHandle := gtk_window_new(GTK_WINDOW_TOPLEVEL);
  if FHandle = nil then
    raise EWindowNotInitialized.Create('gtk_window_new returned nil');
  gtk_window_set_default_size(FHandle, FWidth, FHeight);
  gtk_window_set_resizable(FHandle, Ord(FResizable));
  if FTitle <> '' then
    gtk_window_set_title(FHandle, PAnsiChar(AnsiString(FTitle)));
  if FMaximized then
    gtk_window_maximize(FHandle);

  ConnectSignals;
  RegisterLive(Pointer(Self));
end;

destructor TWindowGtk.Destroy;
begin
  if not FClosed and (FHandle <> nil) then
  begin
    DisconnectSignals;
  end;
  if FDispatcher <> nil then
  begin
    (FDispatcher as TWindowGtkDispatcher).DropAll;
  end;
  UnregisterLive(Pointer(Self));
  inherited;
end;

procedure TWindowGtk.ConnectSignals;
begin
  FSignalDelete   := g_signal_connect_data(FHandle, 'delete-event', Pointer(@CbDelete), Self, nil, 0);
  FSignalConfigure:= g_signal_connect_data(FHandle, 'configure-event', Pointer(@CbConfigure), Self, nil, 0);
  FSignalFocusIn  := g_signal_connect_data(FHandle, 'focus-in-event', Pointer(@CbFocusIn), Self, nil, 0);
  FSignalFocusOut := g_signal_connect_data(FHandle, 'focus-out-event', Pointer(@CbFocusOut), Self, nil, 0);
  FSignalScale    := g_signal_connect_data(FHandle, 'notify::scale-factor', Pointer(@CbScaleNotify), Self, nil, 0);
  FSignalDestroy  := g_signal_connect_data(FHandle, 'destroy', Pointer(@CbDestroy), Self, nil, 0);
  FSignalState    := g_signal_connect_data(FHandle, 'window-state-event', Pointer(@CbWindowState), Self, nil, 0);
end;

procedure TWindowGtk.DisconnectSignals;
begin
  if FHandle = nil then Exit;
  if FSignalDelete <> 0 then g_signal_handler_disconnect(FHandle, FSignalDelete);
  if FSignalConfigure <> 0 then g_signal_handler_disconnect(FHandle, FSignalConfigure);
  if FSignalFocusIn <> 0 then g_signal_handler_disconnect(FHandle, FSignalFocusIn);
  if FSignalFocusOut <> 0 then g_signal_handler_disconnect(FHandle, FSignalFocusOut);
  if FSignalScale <> 0 then g_signal_handler_disconnect(FHandle, FSignalScale);
  if FSignalDestroy <> 0 then g_signal_handler_disconnect(FHandle, FSignalDestroy);
  if FSignalState <> 0 then g_signal_handler_disconnect(FHandle, FSignalState);
  FSignalDelete := 0; FSignalConfigure := 0; FSignalFocusIn := 0; FSignalFocusOut := 0;
  FSignalScale := 0; FSignalDestroy := 0; FSignalState := 0;
end;

procedure TWindowGtk.RequireOpen;
begin
  if FClosed then
    raise EWindowClosed.Create('window is closed');
end;

procedure TWindowGtk.DoDispatch(const AEvent: TWindowEvent);
var
  H: TWindowEventHandler;
begin
  if FClosed then Exit;
  H := FOnEvent;
  if Assigned(H) then H(AEvent);
end;

function TWindowGtk.IsOnMainThread: Boolean; inline;
begin
  Result := platform_thread_id = FOwnerThread;
end;

procedure TWindowGtk.RealClose;
begin
  if FClosed then Exit;
  FClosed := True;
  FVisible := False;
  if FDispatcher <> nil then
    (FDispatcher as TWindowGtkDispatcher).DropAll;
  DisconnectSignals;
  if FHandle <> nil then
  begin
    gtk_widget_destroy(FHandle);
    FHandle := nil;
  end;
  UnregisterLive(Pointer(Self));
end;

procedure TWindowGtk.Close;
begin
  if FClosed then Exit;
  if not IsOnMainThread then
  begin
    FDispatcher.Post(procedure begin RealClose; end);
    Exit;
  end;
  RealClose;
end;

function TWindowGtk.IsClosed: Boolean; inline;
begin
  Result := FClosed;
end;

procedure TWindowGtk.Show;
begin
  RequireOpen;
  gtk_widget_show_all(FHandle);
  FVisible := True;
end;

procedure TWindowGtk.Hide;
begin
  RequireOpen;
  gtk_widget_hide(FHandle);
  FVisible := False;
end;

function TWindowGtk.IsVisible: Boolean;
begin
  RequireOpen;
  if FHandle <> nil then
    Result := gtk_widget_get_visible(FHandle) <> 0
  else
    Result := FVisible;
end;

procedure TWindowGtk.Focus;
begin
  RequireOpen;
  if FHandle <> nil then
    gtk_widget_grab_focus(FHandle);
end;

procedure TWindowGtk.SetTitle(const ATitle: string);
begin
  RequireOpen;
  FTitle := ATitle;
  if FHandle <> nil then
    gtk_window_set_title(FHandle, PAnsiChar(AnsiString(ATitle)));
end;

function TWindowGtk.GetTitle: string;
var
  P: PAnsiChar;
begin
  RequireOpen;
  if FHandle <> nil then
  begin
    P := gtk_window_get_title(FHandle);
    if P <> nil then
      Result := string(AnsiString(P))
    else
      Result := FTitle;
  end
  else
    Result := FTitle;
end;

procedure TWindowGtk.SetBounds(AWidth, AHeight: Integer);
var
  E: TWindowEvent;
begin
  RequireOpen;
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  FWidth := AWidth;
  FHeight := AHeight;
  if FHandle <> nil then
    gtk_window_resize(FHandle, AWidth, AHeight);
  E.Kind := weResized;
  E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
  DoDispatch(E);
end;

function TWindowGtk.GetWidth: Integer; inline;
begin
  RequireOpen;
  if FHandle <> nil then
    Result := gtk_widget_get_allocated_width(FHandle)
  else
    Result := FWidth;
end;

function TWindowGtk.GetHeight: Integer; inline;
begin
  RequireOpen;
  if FHandle <> nil then
    Result := gtk_widget_get_allocated_height(FHandle)
  else
    Result := FHeight;
end;

procedure TWindowGtk.SetResizable(AResizable: Boolean);
begin
  RequireOpen;
  FResizable := AResizable;
  if FHandle <> nil then
    gtk_window_set_resizable(FHandle, Ord(AResizable));
end;

procedure TWindowGtk.Maximize;
var
  E: TWindowEvent;
begin
  RequireOpen;
  FMaximized := True;
  FMinimized := False;
  if FHandle <> nil then
    gtk_window_maximize(FHandle);
  E.Kind := weResized;
  E.Width := FWidth; E.Height := FHeight; E.X := 0; E.Y := 0; E.NewScale := 0;
  DoDispatch(E);
end;

procedure TWindowGtk.Unmaximize;
begin
  RequireOpen;
  FMaximized := False;
  if FHandle <> nil then
    gtk_window_unmaximize(FHandle);
end;

function TWindowGtk.IsMaximized: Boolean;
begin
  RequireOpen;
  if FHandle <> nil then
    Result := gtk_window_is_maximized(FHandle) <> 0
  else
    Result := FMaximized;
end;

procedure TWindowGtk.Minimize;
begin
  RequireOpen;
  FMinimized := True;
  FMaximized := False;
  if FHandle <> nil then
    gtk_window_iconify(FHandle);
end;

procedure TWindowGtk.Restore;
begin
  RequireOpen;
  FMinimized := False;
  FMaximized := False;
  if FHandle <> nil then
    gtk_window_deiconify(FHandle);
end;

function TWindowGtk.IsMinimized: Boolean;
var
  St: guint;
  GW: Pointer;
begin
  RequireOpen;
  if (FHandle <> nil) then
  begin
    GW := gtk_widget_get_window(FHandle);
    if GW <> nil then
    begin
      St := gdk_window_get_state(GW);
      Result := (St and GDK_WINDOW_STATE_ICONIFIED) <> 0;
      Exit;
    end;
  end;
  Result := FMinimized;
end;

function TWindowGtk.GetScaleFactor: Double;
var
  S: gint;
begin
  RequireOpen;
  if FHandle <> nil then
  begin
    S := gtk_widget_get_scale_factor(FHandle);
    if S <= 0 then S := 1;
    Result := S;
  end
  else
    Result := 1.0;
end;

function TWindowGtk.NativeHandle: TWindowNativeHandle;
var
  GW: Pointer;
begin
  if FClosed or (FHandle = nil) then
    Exit(nil);
  GW := gtk_widget_get_window(FHandle);
  Result := TWindowNativeHandle(GW);
end;

function TWindowGtk.GetDispatcher: IWindowDispatcher; inline;
begin
  Result := FDispatcher;
end;

procedure TWindowGtk.OnEvent(AHandler: TWindowEventHandler);
begin
  RequireOpen;
  FOnEvent := AHandler;
end;

procedure TWindowGtk.OnEvent(AHandler: TWindowEventMethod);
begin
  OnEvent(EventMethodToRef(AHandler));
end;

procedure TWindowGtk.OnEvent(AHandler: TWindowEventProc);
begin
  OnEvent(EventProcToRef(AHandler));
end;

function CreateWindowGtk(const AOptions: TWindowOptions): IWindow;
begin
  Result := TWindowGtk.Create(AOptions);
end;

{ ---- RunLoop helpers exposed for factory ---- }

procedure WindowGtkRunMainLoop;
begin
  GMainLoopRunning := True;
  try
    gtk_main();
  finally
    GMainLoopRunning := False;
  end;
end;

procedure WindowGtkQuitMainLoop;
begin
  if GMainLoopRunning then
    gtk_main_quit();
end;

finalization
  GLiveRegistry.Free;

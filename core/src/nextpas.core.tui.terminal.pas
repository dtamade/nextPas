unit nextpas.core.tui.terminal;

{**
 * @desc TTerminal — 终端运行时核心。
 *
 * 拥有 backend、prev/curr/merged 双缓冲、overlay、输入队列、termios 状态。
 * 帧生命周期：BeginFrame → 渲染 → EndFrame（diff + flush + swap）。
 * 事件循环：PollEvent 阻塞等待输入/信号，产出 TEvent。
 *
 * SIGWINCH：信号 handler 置 flag，PollEvent 消费后合成 evResize
 * （buffer 已 resize，消费方首次重绘不会与尺寸变化竞争）。
 *
 * RAII：析构幂等+异常安全——leave alt screen、show cursor、restore termios、
 * unhook signals，即使部分步骤失败也继续释放资源。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.cap.base,
  nextpas.core.tui.error,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.overlay,
  nextpas.core.tui.event,
  nextpas.core.tui.input,
  nextpas.core.tui.interaction,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.backend.ansi,
  nextpas.core.platform.console,
  nextpas.core.platform.signal;

const
  STDIN_FD  = 0;
  STDOUT_FD = 1;

type
  TTerminalMouseMode = (tmMouseNone, tmMouseClick, tmMouseDrag, tmMouseFull);
  TTerminalWheelMode = (twWheelOff, twWheelMouse, twAlternateScrollKeys);
  TTerminalSelectionMode = (tsTerminalNative, tsApplication);

  TTerminalOptions = packed record
    MouseMode: TTerminalMouseMode;
    WheelMode: TTerminalWheelMode;
    SelectionMode: TTerminalSelectionMode;

    class function Default: TTerminalOptions; static;
    class function EditorDefault: TTerminalOptions; static;
    class function NativeSelectionWheel: TTerminalOptions; static;
    function EffectiveMouseMode: TTerminalMouseMode;
    function RequestsMouseTracking: Boolean;
    function UsesAlternateScrollKeys: Boolean;
  end;

  TFrame = record
    Buffer: TBuffer;
    Overlay: TOverlayBuffer;
    Area: TRect;
    HasCursor: Boolean;
    CursorPos: TPosition;
    FrameId: Cardinal;
  end;

  TTuiImageProtocolCapability = record
    DetectedProtocol: TImageProtocol;
    ActiveProtocol: TImageProtocol;
    Status: TTuiCapabilityStatus;

    class function Create(ADetectedProtocol, AActiveProtocol: TImageProtocol;
      const AStatus: TTuiCapabilityStatus): TTuiImageProtocolCapability; static;
  end;

  TTuiTerminalCapabilityProfile = record
    Truecolor: TTuiCapabilityStatus;
    KittyKeyboard: TTuiCapabilityStatus;
    ImageProtocol: TTuiImageProtocolCapability;

    class function Default: TTuiTerminalCapabilityProfile; static;
  end;

  TTerminal = class
  private
    FBackend: TAnsiBackend;
    FPrev, FCurr, FMerged: TBuffer;
    FOverlay: TOverlayBuffer;
    FFrame: TFrame;
    FFrameActive: Boolean;
    FFrameId: Cardinal;
    FPatches: TDiffEntries;
    FInRawMode: Boolean;
    FRawModeCaptured: Boolean;
    FSavedMode: TPlatformConsoleMode;
    FInputQueue: array of Byte;
    FInputLen: Integer;
    FShouldQuit: Boolean;
    FCapture: TPointerCapture;
    FSession: TInteractionSession;
    FPrevMousePos: TPosition;
    FLastMousePos: TPosition;
    FHasMouseTracking: Boolean;
    FCapabilityProfile: TTuiTerminalCapabilityProfile;
    FCellWidth: Word;
    FCellHeight: Word;
    FOptions: TTerminalOptions;
    FActiveOptions: TTerminalOptions;
    procedure EnsureInputCapacity(AExtra: Integer);
    procedure DropInputBytes(ACount: Integer);
    function ReadAvailableBytes: Integer;
    function TryParseQueuedEvent(AAtEOF, AScanInvalid: Boolean;
      out AEv: TEvent; out ANeedMore: Boolean): Boolean;
    procedure CheckSignals(out AResizeOut: TEvent; out AHasResize: Boolean);
    procedure DetectCapabilities;
    procedure EnsureFrameRuntime(const AOperation: AnsiString);
    procedure EnsureEndFrameAllowed(const AFrame: TFrame);
    procedure ResizeBuffersTo(AWidth, AHeight: Word);
    function GetHasTruecolor: Boolean; inline;
    function GetHasKittyKeyboard: Boolean; inline;
    function GetImageProtocol: TImageProtocol; inline;
  protected
    procedure DoLeaveTui; virtual;
  public
    class function DetectCapabilityProfileFromHints(const AColorTerm,
      ATermProgram, ATerm, ATermFeatures, AKittyWindowId: AnsiString)
      : TTuiTerminalCapabilityProfile; static;

    constructor Create;
    destructor Destroy; override;

    function EnterTui: Boolean; overload;
    function EnterTui(const AOptions: TTerminalOptions): Boolean; overload;
    procedure LeaveTui;

    function BeginFrame: TFrame;
    procedure EndFrame(const AFrame: TFrame);

    function PollEvent(ATimeoutMs: Integer): TEvent;

    procedure RequestQuit; inline;
    function ShouldQuit: Boolean; inline;
    function Area: TRect;

    procedure PostProcessEvent(var AEv: TEvent);
    procedure PromoteMousePos;
    procedure InjectInputBytesForTest(const ABytes: array of Byte);
    function PollQueuedEventForTest(AAtEOF: Boolean; out AEv: TEvent): Boolean;
    procedure InitializeFrameRuntimeForTest(const AArea: TRect);

    property Capture: TPointerCapture read FCapture write FCapture;
    property Session: TInteractionSession read FSession write FSession;
    property PrevMousePos: TPosition read FPrevMousePos write FPrevMousePos;
    property HasMouseTracking: Boolean read FHasMouseTracking;
    property HasTruecolor: Boolean read GetHasTruecolor;
    property HasKittyKeyboard: Boolean read GetHasKittyKeyboard;
    property ImageProtocol: TImageProtocol read GetImageProtocol;
    property CapabilityProfile: TTuiTerminalCapabilityProfile read FCapabilityProfile;
    property CellWidth: Word read FCellWidth;
    property CellHeight: Word read FCellHeight;
    property Options: TTerminalOptions read FOptions write FOptions;
  end;

implementation

var
  GResizePending: LongInt = 0;
  GTermPending: LongInt = 0;
  GSigwinchHooked: Boolean = False;
  GSigtermHooked: Boolean = False;

procedure SigwinchHandler(ASignal: Int32); cdecl;
begin
  InterlockedExchange(GResizePending, 1);
end;

procedure SigtermHandler(ASignal: Int32); cdecl;
begin
  InterlockedExchange(GTermPending, 1);
end;

procedure HookSigwinch;
begin
  if GSigwinchHooked then Exit;
  {$IF declared(PLATFORM_SIGWINCH)}
  if platform_signal_set(PLATFORM_SIGWINCH, @SigwinchHandler) = 0 then
    GSigwinchHooked := True;
  {$ENDIF}
end;

procedure HookSigterm;
begin
  if GSigtermHooked then Exit;
  if platform_signal_set(PLATFORM_SIGTERM, @SigtermHandler) = 0 then
    GSigtermHooked := True;
end;

procedure UnhookSigwinch;
begin
  if not GSigwinchHooked then Exit;
  {$IF declared(PLATFORM_SIGWINCH)}
  platform_signal_reset(PLATFORM_SIGWINCH);
  {$ENDIF}
  GSigwinchHooked := False;
end;

procedure UnhookSigterm;
begin
  if not GSigtermHooked then Exit;
  platform_signal_reset(PLATFORM_SIGTERM);
  GSigtermHooked := False;
end;

function ConsumeResize: Boolean;
begin
  Result := InterlockedExchange(GResizePending, 0) <> 0;
end;

function ConsumeTerminate: Boolean;
begin
  Result := InterlockedExchange(GTermPending, 0) <> 0;
end;

{ TTerminalOptions }

class function TTerminalOptions.Default: TTerminalOptions;
begin
  Result := TTerminalOptions.EditorDefault;
end;

class function TTerminalOptions.EditorDefault: TTerminalOptions;
begin
  Result.MouseMode := tmMouseFull;
  Result.WheelMode := twWheelMouse;
  Result.SelectionMode := tsApplication;
end;

class function TTerminalOptions.NativeSelectionWheel: TTerminalOptions;
begin
  Result.MouseMode := tmMouseNone;
  Result.WheelMode := twAlternateScrollKeys;
  Result.SelectionMode := tsTerminalNative;
end;

function TTerminalOptions.EffectiveMouseMode: TTerminalMouseMode;
begin
  if SelectionMode = tsTerminalNative then
    Result := tmMouseNone
  else
    Result := MouseMode;
end;

function TTerminalOptions.RequestsMouseTracking: Boolean;
begin
  Result := EffectiveMouseMode <> tmMouseNone;
end;

function TTerminalOptions.UsesAlternateScrollKeys: Boolean;
begin
  Result := WheelMode = twAlternateScrollKeys;
end;

function ToAnsiMouseMode(AMode: TTerminalMouseMode): TAnsiMouseMode; inline;
begin
  case AMode of
    tmMouseClick: Result := amMouseClick;
    tmMouseDrag:  Result := amMouseDrag;
    tmMouseFull:  Result := amMouseFull;
  else
    Result := amMouseNone;
  end;
end;

{ Capability profile }

class function TTuiImageProtocolCapability.Create(ADetectedProtocol,
  AActiveProtocol: TImageProtocol; const AStatus: TTuiCapabilityStatus)
  : TTuiImageProtocolCapability;
begin
  Result.DetectedProtocol := ADetectedProtocol;
  Result.ActiveProtocol := AActiveProtocol;
  Result.Status := AStatus;
end;

class function TTuiTerminalCapabilityProfile.Default: TTuiTerminalCapabilityProfile;
begin
  Result.Truecolor := TTuiCapabilityStatus.Create(True, False, False, False,
    'env-hint-missing');
  Result.KittyKeyboard := TTuiCapabilityStatus.Create(True, False, False, False,
    'env-hint-missing');
  Result.ImageProtocol := TTuiImageProtocolCapability.Create(ipHalfBlock, ipHalfBlock,
    TTuiCapabilityStatus.Create(True, False, False, False, 'half-block-fallback'));
end;

{ TTerminal }

class function TTerminal.DetectCapabilityProfileFromHints(const AColorTerm,
  ATermProgram, ATerm, ATermFeatures, AKittyWindowId: AnsiString)
  : TTuiTerminalCapabilityProfile;
var
  LImageProtocol: TImageProtocol;
begin
  Result := TTuiTerminalCapabilityProfile.Default;

  if (AColorTerm = 'truecolor') or (AColorTerm = '24bit') then
    Result.Truecolor := TTuiCapabilityStatus.Create(True, True, True, False, '')
  else
    Result.Truecolor := TTuiCapabilityStatus.Create(True, False, False, False,
      'env-hint-missing');

  if (Pos('kitty', ATermProgram) > 0) or (Pos('kitty', ATerm) > 0) or
     (AKittyWindowId <> '') or
     (Pos('WezTerm', ATermProgram) > 0) or
     (Pos('ghostty', ATermProgram) > 0) then
    Result.KittyKeyboard := TTuiCapabilityStatus.Create(True, True, False, False,
      'session-negotiation-not-implemented')
  else
    Result.KittyKeyboard := TTuiCapabilityStatus.Create(True, False, False, False,
      'env-hint-missing');

  LImageProtocol := DetectImageProtocolFromHints(
    ATerm, ATermProgram, ATermFeatures, AKittyWindowId);
  if LImageProtocol = ipHalfBlock then
    Result.ImageProtocol := TTuiImageProtocolCapability.Create(ipHalfBlock, ipHalfBlock,
      TTuiCapabilityStatus.Create(True, False, False, False, 'half-block-fallback'))
  else
    Result.ImageProtocol := TTuiImageProtocolCapability.Create(
      LImageProtocol,
      LImageProtocol,
      TTuiCapabilityStatus.Create(True, True, True, False, ''));
end;

constructor TTerminal.Create;
begin
  inherited Create;
  FBackend := nil;
  FPrev := nil;
  FCurr := nil;
  FMerged := nil;
  FOverlay := nil;
  FFrameActive := False;
  FFrameId := 0;
  FInRawMode := False;
  FRawModeCaptured := False;
  FShouldQuit := False;
  FInputLen := 0;
  FCapture.Release;
  FSession.State := ssNone;
  FHasMouseTracking := False;
  FCapabilityProfile := TTuiTerminalCapabilityProfile.Default;
  FOptions := TTerminalOptions.Default;
  FActiveOptions := FOptions;
  SetLength(FInputQueue, 256);
end;

destructor TTerminal.Destroy;
begin
  try
    DoLeaveTui;
  except
  end;
  FOverlay.Free;
  FMerged.Free;
  FCurr.Free;
  FPrev.Free;
  FBackend.Free;
  inherited;
end;

function TTerminal.EnterTui: Boolean;
begin
  Result := EnterTui(FOptions);
end;

function TTerminal.EnterTui(const AOptions: TTerminalOptions): Boolean;
var
  LSize: TPlatformConsoleSize;
  LMouseMode: TTerminalMouseMode;
begin
  Result := False;
  if FInRawMode then Exit(True);
  FOptions := AOptions;

  if not platform_console_is_terminal(STDOUT_FD) then Exit;
  if platform_console_get_size_fd(STDOUT_FD, LSize) <> 0 then
  begin
    LSize.Cols := 80;
    LSize.Rows := 24;
  end;
  if platform_console_set_raw(STDIN_FD, FSavedMode) <> 0 then Exit;
  FRawModeCaptured := True;
  FInRawMode := True;

  HookSigwinch;
  HookSigterm;

  try
    FActiveOptions := FOptions;
    LMouseMode := FActiveOptions.EffectiveMouseMode;
    FBackend := TAnsiBackend.Create(STDOUT_FD);
    FBackend.EnterAlternate(ToAnsiMouseMode(LMouseMode),
      FActiveOptions.UsesAlternateScrollKeys);
    FBackend.HideCursor;
    FBackend.ClearScreen;
    FBackend.Flush;

    FPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, LSize.Cols, LSize.Rows));
    FCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, LSize.Cols, LSize.Rows));
    FMerged := TBuffer.CreateEmpty(TRect.Make(0, 0, LSize.Cols, LSize.Rows));
    FOverlay := TOverlayBuffer.Create(TRect.Make(0, 0, LSize.Cols, LSize.Rows));
    DetectCapabilities;
    FHasMouseTracking := FActiveOptions.RequestsMouseTracking;
    FCellWidth := 0;
    FCellHeight := 0;
    FFrameActive := False;
    Result := True;
  except
    LeaveTui;
    Result := False;
  end;
end;

procedure TTerminal.LeaveTui;
begin
  DoLeaveTui;
end;

procedure TTerminal.DoLeaveTui;
begin
  if not FInRawMode then Exit;

  if FBackend <> nil then
  begin
    FBackend.LeaveAlternate(ToAnsiMouseMode(FActiveOptions.EffectiveMouseMode),
      FActiveOptions.UsesAlternateScrollKeys);
    FBackend.ShowCursor;
    FBackend.Flush;
    FBackend.Free;
    FBackend := nil;
  end;
  if FOverlay <> nil then begin FOverlay.Free; FOverlay := nil; end;
  if FMerged <> nil then begin FMerged.Free; FMerged := nil; end;
  if FCurr <> nil then begin FCurr.Free; FCurr := nil; end;
  if FPrev <> nil then begin FPrev.Free; FPrev := nil; end;

  FFrameActive := False;
  FShouldQuit := False;
  if FRawModeCaptured then
    platform_console_restore_raw(STDIN_FD, FSavedMode);
  UnhookSigwinch;
  UnhookSigterm;
  FInRawMode := False;
  FRawModeCaptured := False;
  FHasMouseTracking := False;
end;

{ Frame lifecycle }

function TTerminal.BeginFrame: TFrame;
begin
  EnsureFrameRuntime('BeginFrame');
  if FFrameActive then
    raise ETuiBackend.Create('TTerminal.BeginFrame called with an active frame');
  FCurr.Reset;
  FCurr.ImageProtocol := ImageProtocol;
  FOverlay.Clear;
  Inc(FFrameId);
  if FFrameId = 0 then Inc(FFrameId);
  FFrameActive := True;
  FFrame.Buffer := FCurr;
  FFrame.Overlay := FOverlay;
  FFrame.Area := FCurr.Area;
  FFrame.HasCursor := False;
  FFrame.CursorPos.X := 0;
  FFrame.CursorPos.Y := 0;
  FFrame.FrameId := FFrameId;
  Result := FFrame;
end;

procedure TTerminal.EndFrame(const AFrame: TFrame);
var
  LPatchCount: Integer;
  LTmp: TBuffer;
begin
  EnsureEndFrameAllowed(AFrame);

  if (FCurr.Length_ > 0) and (FMerged.Length_ > 0) then
  begin
    Move(FCurr.ContentPtr^, FMerged.ContentPtr^, FCurr.Length_ * SizeOf(TCell));
    FMerged.DirtyRows := FCurr.DirtyRows;
  end
  else
    FMerged.Reset;
  FOverlay.MergeInto(FCurr, FMerged);
  LPatchCount := FPrev.DiffInto(FMerged, FPatches);
  FBackend.DrawPatchesN(FPatches, LPatchCount);

  if AFrame.HasCursor then
  begin
    FBackend.ShowCursor;
    FBackend.MoveTo(AFrame.CursorPos.X, AFrame.CursorPos.Y);
  end
  else
    FBackend.HideCursor;
  FBackend.Flush;

  LTmp := FPrev;
  FPrev := FMerged;
  FMerged := LTmp;
  FFrameActive := False;
end;

procedure TTerminal.RequestQuit;
begin
  FShouldQuit := True;
end;

function TTerminal.ShouldQuit: Boolean;
begin
  Result := FShouldQuit;
end;

function TTerminal.Area: TRect;
begin
  if FCurr <> nil then Result := FCurr.Area else Result := TRect.Make(0, 0, 0, 0);
end;

procedure TTerminal.EnsureFrameRuntime(const AOperation: AnsiString);
begin
  if (not FInRawMode) or (FBackend = nil) or (FCurr = nil) or
     (FPrev = nil) or (FMerged = nil) or (FOverlay = nil) then
    raise ETuiBackend.CreateFmt('TTerminal.%s requires active TUI mode', [AOperation]);
end;

procedure TTerminal.EnsureEndFrameAllowed(const AFrame: TFrame);
begin
  EnsureFrameRuntime('EndFrame');
  if not FFrameActive then
    raise ETuiBackend.Create('TTerminal.EndFrame called without active BeginFrame');
  if (AFrame.FrameId <> FFrameId) or (AFrame.Buffer <> FCurr) or (AFrame.Overlay <> FOverlay) then
    raise ETuiBackend.Create('TTerminal.EndFrame received a stale frame');
end;

procedure TTerminal.DetectCapabilities;
var
  LCT, LTP, LT, LTF, LKittyWindowId: AnsiString;
begin
  LCT := GetEnvironmentVariable('COLORTERM');
  LTP := GetEnvironmentVariable('TERM_PROGRAM');
  LT := GetEnvironmentVariable('TERM');
  LTF := GetEnvironmentVariable('TERM_FEATURES');
  LKittyWindowId := GetEnvironmentVariable('KITTY_WINDOW_ID');
  FCapabilityProfile := DetectCapabilityProfileFromHints(
    LCT, LTP, LT, LTF, LKittyWindowId);
end;

function TTerminal.GetHasTruecolor: Boolean;
begin
  Result := FCapabilityProfile.Truecolor.Active;
end;

function TTerminal.GetHasKittyKeyboard: Boolean;
begin
  Result := FCapabilityProfile.KittyKeyboard.Active;
end;

function TTerminal.GetImageProtocol: TImageProtocol;
begin
  Result := FCapabilityProfile.ImageProtocol.ActiveProtocol;
end;

procedure TTerminal.ResizeBuffersTo(AWidth, AHeight: Word);
begin
  if FPrev <> nil then FPrev.Resize(TRect.Make(0, 0, AWidth, AHeight));
  if FCurr <> nil then FCurr.Resize(TRect.Make(0, 0, AWidth, AHeight));
  if FMerged <> nil then FMerged.Resize(TRect.Make(0, 0, AWidth, AHeight));
  if FOverlay <> nil then FOverlay.Resize(TRect.Make(0, 0, AWidth, AHeight));
  if FFrameActive then
  begin
    FFrameActive := False;
    Inc(FFrameId);
    if FFrameId = 0 then Inc(FFrameId);
  end;
  if FPrev <> nil then FPrev.Reset;
  if FBackend <> nil then FBackend.ResetStyleCache;
end;

{ Signal + Input }

procedure TTerminal.CheckSignals(out AResizeOut: TEvent; out AHasResize: Boolean);
var
  LSize: TPlatformConsoleSize;
begin
  AHasResize := False;
  if ConsumeTerminate then
    RequestQuit;
  if not ConsumeResize then Exit;
  if platform_console_get_size_fd(STDOUT_FD, LSize) <> 0 then Exit;
  ResizeBuffersTo(LSize.Cols, LSize.Rows);
  FCellWidth := 0;
  FCellHeight := 0;
  AResizeOut := ResizeEvent(LSize.Cols, LSize.Rows);
  AHasResize := True;
end;

procedure TTerminal.EnsureInputCapacity(AExtra: Integer);
var
  LNewCap: Integer;
begin
  if AExtra <= 0 then Exit;
  LNewCap := System.Length(FInputQueue);
  if LNewCap = 0 then LNewCap := 256;
  while (LNewCap - FInputLen) < AExtra do
    LNewCap := LNewCap * 2;
  if LNewCap <> System.Length(FInputQueue) then
    SetLength(FInputQueue, LNewCap);
end;

procedure TTerminal.DropInputBytes(ACount: Integer);
begin
  if ACount <= 0 then Exit;
  if ACount >= FInputLen then
  begin
    FInputLen := 0;
    Exit;
  end;
  Move(FInputQueue[ACount], FInputQueue[0], FInputLen - ACount);
  Dec(FInputLen, ACount);
end;

function TTerminal.ReadAvailableBytes: Integer;
var
  LCap, LGot: Integer;
begin
  Result := 0;
  EnsureInputCapacity(64);
  LCap := System.Length(FInputQueue) - FInputLen;
  LGot := platform_console_read(STDIN_FD, @FInputQueue[FInputLen], LCap);
  if LGot > 0 then
  begin
    Inc(FInputLen, LGot);
    Result := LGot;
  end;
end;

function TTerminal.TryParseQueuedEvent(AAtEOF, AScanInvalid: Boolean;
  out AEv: TEvent; out ANeedMore: Boolean): Boolean;
var
  LConsumed: Integer;
  LR: TParseResult;
begin
  Result := False;
  ANeedMore := False;
  AEv := NoneEvent;
  while FInputLen > 0 do
  begin
    LR := ParseOne(FInputQueue[0], FInputLen, AAtEOF, AEv, LConsumed);
    case LR of
      prSuccess:
        begin
          DropInputBytes(LConsumed);
          if IsNone(AEv) then
            Continue;
          Result := True;
          Exit;
        end;
      prInvalid:
        begin
          DropInputBytes(1);
          if not AScanInvalid then Exit;
        end;
      prNeedMore:
        begin
          ANeedMore := True;
          Exit;
        end;
    end;
  end;
end;

procedure TTerminal.InjectInputBytesForTest(const ABytes: array of Byte);
begin
  EnsureInputCapacity(System.Length(ABytes));
  if System.Length(ABytes) > 0 then
  begin
    Move(ABytes[0], FInputQueue[FInputLen], System.Length(ABytes));
    Inc(FInputLen, System.Length(ABytes));
  end;
end;

function TTerminal.PollQueuedEventForTest(AAtEOF: Boolean; out AEv: TEvent): Boolean;
var
  LNeedMore: Boolean;
begin
  Result := TryParseQueuedEvent(AAtEOF, True, AEv, LNeedMore);
  if Result then PostProcessEvent(AEv);
end;

procedure TTerminal.InitializeFrameRuntimeForTest(const AArea: TRect);
begin
  if FInRawMode then
    DoLeaveTui;
  if FOverlay <> nil then begin FOverlay.Free; FOverlay := nil; end;
  if FMerged <> nil then begin FMerged.Free; FMerged := nil; end;
  if FCurr <> nil then begin FCurr.Free; FCurr := nil; end;
  if FPrev <> nil then begin FPrev.Free; FPrev := nil; end;
  if FBackend <> nil then begin FBackend.Free; FBackend := nil; end;

  FBackend := TAnsiBackend.Create(-1);
  FPrev := TBuffer.CreateEmpty(AArea);
  FCurr := TBuffer.CreateEmpty(AArea);
  FMerged := TBuffer.CreateEmpty(AArea);
  FOverlay := TOverlayBuffer.Create(AArea);
  FCapabilityProfile := TTuiTerminalCapabilityProfile.Default;
  FActiveOptions := FOptions;
  FFrameActive := False;
  FFrameId := 0;
  FInRawMode := True;
  FRawModeCaptured := False;
  FShouldQuit := False;
  FHasMouseTracking := False;
  FCellWidth := 0;
  FCellHeight := 0;
end;

procedure TTerminal.PromoteMousePos;
begin
  FPrevMousePos := FLastMousePos;
end;

procedure TTerminal.PostProcessEvent(var AEv: TEvent);
begin
  case AEv.Kind of
    evNone, evResize, evPaste: ;
    evMouse:
      begin
        FLastMousePos.X := AEv.Mouse.X;
        FLastMousePos.Y := AEv.Mouse.Y;
        if (AEv.Mouse.Kind = mkUp) and FCapture.Active and
           (AEv.Mouse.Button = FCapture.Button) then
        begin
          if FSession.IsActive then FSession.Commit;
          FCapture.Release;
        end;
      end;
    evKey:
      if (AEv.Key.Code = kcEsc) and FSession.IsActive then
      begin
        FSession.Cancel;
        FCapture.Release;
      end;
  end;
end;

function WaitForInput(AFd: Int32; ATimeoutMs: Integer): Boolean;
var
  LResult: TPlatformConsoleWait;
begin
  LResult := platform_console_wait_readable(AFd, ATimeoutMs);
  Result := LResult = cwReadable;
end;

function TTerminal.PollEvent(ATimeoutMs: Integer): TEvent;
var
  LHasResize: Boolean;
  LResz: TEvent;
  LNeedMore: Boolean;
begin
  FPrevMousePos := FLastMousePos;
  Result := NoneEvent;

  CheckSignals(LResz, LHasResize);
  if LHasResize then Exit(LResz);
  if FShouldQuit then Exit(NoneEvent);

  if FInputLen > 0 then
  begin
    if TryParseQueuedEvent(False, True, Result, LNeedMore) then
    begin
      PostProcessEvent(Result);
      Exit;
    end;
    if not LNeedMore then Exit(NoneEvent);
    if not WaitForInput(STDIN_FD, 50) then
    begin
      CheckSignals(LResz, LHasResize);
      if LHasResize then Exit(LResz);
      if FShouldQuit then Exit(NoneEvent);
      if TryParseQueuedEvent(True, False, Result, LNeedMore) then
      begin
        PostProcessEvent(Result);
        Exit;
      end;
      Exit(NoneEvent);
    end;
    if ReadAvailableBytes > 0 then
    begin
      if TryParseQueuedEvent(False, True, Result, LNeedMore) then
      begin
        PostProcessEvent(Result);
        Exit;
      end;
    end;
    Exit(NoneEvent);
  end;

  if not WaitForInput(STDIN_FD, ATimeoutMs) then
  begin
    CheckSignals(LResz, LHasResize);
    if LHasResize then Exit(LResz);
    if FShouldQuit then Exit(NoneEvent);
    if FInputLen > 0 then
    begin
      if TryParseQueuedEvent(True, False, Result, LNeedMore) then
      begin
        PostProcessEvent(Result);
        Exit;
      end;
    end;
    Exit;
  end;

  if ReadAvailableBytes <= 0 then Exit;

  if TryParseQueuedEvent(False, True, Result, LNeedMore) then
  begin
    PostProcessEvent(Result);
    Exit;
  end;

  Result := NoneEvent;
end;

end.

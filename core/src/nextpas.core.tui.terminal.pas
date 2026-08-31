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

uses nextpas.core.mem.intf, nextpas.core.tui.base, nextpas.core.tui.cap.base, nextpas.core.tui.error, nextpas.core.tui.cell, nextpas.core.tui.buffer, nextpas.core.tui.overlay, nextpas.core.tui.event, nextpas.core.tui.input, nextpas.core.tui.interaction, nextpas.core.tui.image_cap, nextpas.core.tui.image_mgr, nextpas.core.tui.ansi, nextpas.core.tui.backend.ansi, nextpas.core.platform.console, nextpas.core.platform.signal, nextpas.core.platform.env, nextpas.core.platform.time;

const
  STDIN_FD  = 0;
  STDOUT_FD = 1;

  { ESC 半序列补全等待窗口：CSI/SS3/OSC 常分块到达（PTY/网络终端），
    窗口太短会把 ESC 前缀误判为裸 ESC 键，余段变打字（方向键全盘失效）。
    250ms 与 xterm 的 ESC 延迟期（escape delay window）同量级：
    真实 ESC 键的单字节输入最多少等 ~250ms，换取序列可靠组装。 }
  kEscSequenceWaitMs = 250;

type
  TTerminalMouseMode = (tmMouseNone, tmMouseClick, tmMouseDrag, tmMouseFull);
  TTerminalWheelMode = (twWheelOff, twWheelMouse, twAlternateScrollKeys);
  TTerminalSelectionMode = (tsTerminalNative, tsApplication);

  TTerminalOptions = packed record
    MouseMode: TTerminalMouseMode;
    WheelMode: TTerminalWheelMode;
    SelectionMode: TTerminalSelectionMode;
    { DECSET 1004 terminal focus reporting (CSI I/O). Default False. }
    FocusReporting: Boolean;
    { DECSET 2004 bracketed paste (CSI 200~/201~). Default False. }
    BracketedPaste: Boolean;
    { DECSET 2026 synchronized update around each EndFrame draw. Default True
      (crossterm/ratatui parity; unknown modes ignored by unsupported terminals). }
    SynchronizedUpdate: Boolean;

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

  { EnterTui diagnostic result — Boolean path kept; inspect after False. }
  TTuiEnterFailure = (
    tefNone,
    tefNotATerminal,
    tefSetRawFailed,
    tefSessionSetupFailed
  );

  TTuiEnterResult = record
    Ok: Boolean;
    Failure: TTuiEnterFailure;
    Reason: AnsiString;

    class function OkResult: TTuiEnterResult; static;
    class function Fail(AFailure: TTuiEnterFailure;
      const AReason: AnsiString): TTuiEnterResult; static;
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
    FImageMgr: TImageManager;
    FResizeImagePending: Boolean;
    FResizePendingSinceNs: Int64;
    FOptions: TTerminalOptions;
    FActiveOptions: TTerminalOptions;
    FAllocator: IAllocator;
    FLinkOverlay: TTuiLinkOverlay;   { 刀 21：本帧 OSC 8 链接 overlay }
    FKittyKeyboardPushed: Boolean;
    FFocusReportingEnabled: Boolean;
    FBracketedPasteEnabled: Boolean;
    { Bracketed paste 聚合:200~ 起 / 201~ 止,内容暂存,整包成一次 evPaste }
    FInBracketedPaste: Boolean;
    FPasteBuffer: AnsiString;
    FLastEnterResult: TTuiEnterResult;
    procedure EnsureInputCapacity(AExtra: Integer);
    procedure DropInputBytes(ACount: Integer);
    function ReadAvailableBytes: Integer;
    function TryParseQueuedEvent(AAtEOF, AScanInvalid: Boolean;
      out AEv: TEvent; out ANeedMore: Boolean): Boolean;
    procedure CheckSignals(out AResizeOut: TEvent; out AHasResize: Boolean);
    procedure DetectCapabilities;
    procedure TryNegotiateKittyKeyboard;
    procedure ApplyKittyKeyboardFlagsReply(AFlags: Integer);
    procedure EnsureFrameRuntime(const AOperation: AnsiString);
    procedure EnsureEndFrameAllowed(const AFrame: TFrame);
    procedure ResizeBuffersTo(AWidth, AHeight: Word);
    function EffectiveWaitTimeout(ATimeoutMs: Integer): Integer;
    function GetHasTruecolor: Boolean; inline;
    function GetHasKittyKeyboard: Boolean; inline;
    function GetImageProtocol: TImageProtocol; inline;
    { bracketed paste 聚合:扫描 FInputQueue 找终止序列 ESC[201~;
      返回可安全消费的字节数,AEndAt>=0 表示命中(文本在 [0..AEndAt) )}
    function PasteScan(AAtEOF: Boolean; out AEndAt: Integer): Integer;
    procedure AppendPasteBytes(ACount: Integer);
  protected
    procedure DoLeaveTui; virtual;
  public
    class function DetectCapabilityProfileFromHints(const AColorTerm,
      ATermProgram, ATerm, ATermFeatures, AKittyWindowId: AnsiString)
      : TTuiTerminalCapabilityProfile; static;

    constructor Create(const AAllocator: IAllocator = nil);
    destructor Destroy; override;

    function EnterTui: Boolean; overload;
    function EnterTui(const AOptions: TTerminalOptions): Boolean; overload;
    function TryEnterTui: TTuiEnterResult; overload;
    function TryEnterTui(const AOptions: TTerminalOptions): TTuiEnterResult; overload;
    procedure LeaveTui;

    { 是否有图片正分帧传输（未传完）。调用方可加速帧循环或用于观测。 }
    function HasPendingImageTransmit: Boolean;

    function BeginFrame: TFrame;
    procedure EndFrame(const AFrame: TFrame);

    { 刀 21：设置本帧 OSC 8 链接 overlay（渲染方真实重渲后调用；空 =
      无链接）。EndFrame 时传给后端做输出包裹；overlay 只影响本帧输出。 }
    procedure SetLinkOverlay(const ALinks: array of TTuiLinkSpan);

    function PollEvent(ATimeoutMs: Integer): TEvent;

    procedure RequestQuit; inline;
    function ShouldQuit: Boolean; inline;
    function Area: TRect;

    procedure PostProcessEvent(var AEv: TEvent);
    procedure PromoteMousePos;
    procedure InjectInputBytesForTest(const ABytes: array of Byte);
    function PollQueuedEventForTest(AAtEOF: Boolean; out AEv: TEvent): Boolean;
    procedure InitializeFrameRuntimeForTest(const AArea: TRect);
    procedure NegotiateKittyKeyboardForTest(ADetected: Boolean);
    function BackendPendingForTest: AnsiString;

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
    property LastEnterResult: TTuiEnterResult read FLastEnterResult;
    { 最近一次完成聚合的粘贴文本(收到 evPaste 后读取) }
    property PasteText: AnsiString read FPasteBuffer;
  end;

implementation


const
  { resize 后图片层归位的稳定阈值：自最后一次 resize 起超过该时长才执行
    归位（delete-all+重传）。拖动窗口时 SIGWINCH 连续到达，若每次立即删
    图重传，封面会反复"消失-整图重传"闪烁；24ms 去抖足够避免毛刺，又比
    原先 60ms 更早结束图片冻结，归位延迟更低。 }
  kImageResizeStableNs = 24 * 1000 * 1000;  { 24ms }
  { 分帧传输的图像流帧间隔：有待传数据时把 PollEvent 等待压到该值，
    让 EndFrame 每流帧推进一档（32KB），整图完成后恢复空闲帧率。 }
  kImageStreamFrameMs = 8;

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

{ TTuiEnterResult }

class function TTuiEnterResult.OkResult: TTuiEnterResult;
begin
  Result.Ok := True;
  Result.Failure := tefNone;
  Result.Reason := '';
end;

class function TTuiEnterResult.Fail(AFailure: TTuiEnterFailure;
  const AReason: AnsiString): TTuiEnterResult;
begin
  Result.Ok := False;
  Result.Failure := AFailure;
  Result.Reason := AReason;
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
  Result.FocusReporting := False;
  Result.BracketedPaste := False;
  Result.SynchronizedUpdate := True;
end;

class function TTerminalOptions.NativeSelectionWheel: TTerminalOptions;
begin
  Result.MouseMode := tmMouseNone;
  Result.WheelMode := twAlternateScrollKeys;
  Result.SelectionMode := tsTerminalNative;
  Result.FocusReporting := False;
  Result.BracketedPaste := False;
  Result.SynchronizedUpdate := True;
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
    { Verified=env-attested: COLORTERM is industry standard; DA/OSC query deferred. }
    Result.Truecolor := TTuiCapabilityStatus.Create(True, True, True, True, '')
  else
    Result.Truecolor := TTuiCapabilityStatus.Create(True, False, False, False,
      'env-hint-missing');

  if (Pos('kitty', ATermProgram) > 0) or (Pos('kitty', ATerm) > 0) or
     (AKittyWindowId <> '') or
     (Pos('WezTerm', ATermProgram) > 0) or
     (Pos('ghostty', ATermProgram) > 0) then
    Result.KittyKeyboard := TTuiCapabilityStatus.Create(True, True, False, False,
      'session-negotiation-pending')
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

constructor TTerminal.Create(const AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
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
  FKittyKeyboardPushed := False;
  FFocusReportingEnabled := False;
  FBracketedPasteEnabled := False;
  FLastEnterResult := TTuiEnterResult.OkResult;
  FImageMgr := nil;
  FResizeImagePending := False;
  FResizePendingSinceNs := 0;
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
  FImageMgr.Free;
  FBackend.Free;
  FAllocator := nil;
  inherited;
end;

function TTerminal.EnterTui: Boolean;
begin
  Result := EnterTui(FOptions);
end;

function TTerminal.TryEnterTui: TTuiEnterResult;
begin
  EnterTui;
  Result := FLastEnterResult;
end;

function TTerminal.TryEnterTui(const AOptions: TTerminalOptions): TTuiEnterResult;
begin
  EnterTui(AOptions);
  Result := FLastEnterResult;
end;

function TTerminal.EnterTui(const AOptions: TTerminalOptions): Boolean;
var
  LSize: TPlatformConsoleSize;
  LMouseMode: TTerminalMouseMode;
begin
  Result := False;
  if FInRawMode then
  begin
    FLastEnterResult := TTuiEnterResult.OkResult;
    Exit(True);
  end;
  FOptions := AOptions;

  if not platform_console_is_terminal(STDOUT_FD) then
  begin
    FLastEnterResult := TTuiEnterResult.Fail(tefNotATerminal, 'not-a-terminal');
    Exit;
  end;
  if platform_console_get_size_fd(STDOUT_FD, LSize) <> 0 then
  begin
    LSize.Cols := 80;
    LSize.Rows := 24;
  end;
  if platform_console_set_raw(STDIN_FD, FSavedMode) <> 0 then
  begin
    FLastEnterResult := TTuiEnterResult.Fail(tefSetRawFailed, 'set-raw-failed');
    Exit;
  end;
  FRawModeCaptured := True;
  FInRawMode := True;

  { Best-effort VT enable (Windows); POSIX no-op / ignore errors. }
  platform_console_enable_ansi;

  HookSigwinch;
  HookSigterm;

  try
    FActiveOptions := FOptions;
    LMouseMode := FActiveOptions.EffectiveMouseMode;
    FBackend := TAnsiBackend.Create(STDOUT_FD, FAllocator);
    FBackend.EnterAlternate(ToAnsiMouseMode(LMouseMode),
      FActiveOptions.UsesAlternateScrollKeys);
    FBackend.HideCursor;
    FBackend.ClearScreen;
    FBackend.Flush;

    FPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, LSize.Cols, LSize.Rows), FAllocator);
    FCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, LSize.Cols, LSize.Rows), FAllocator);
    FMerged := TBuffer.CreateEmpty(TRect.Make(0, 0, LSize.Cols, LSize.Rows), FAllocator);
    FOverlay := TOverlayBuffer.Create(TRect.Make(0, 0, LSize.Cols, LSize.Rows), FAllocator);
    DetectCapabilities;
    TryNegotiateKittyKeyboard;
    if FActiveOptions.FocusReporting then
    begin
      FBackend.EnableFocusReporting;
      FBackend.Flush;
      FFocusReportingEnabled := True;
    end
    else
      FFocusReportingEnabled := False;
    if FActiveOptions.BracketedPaste then
    begin
      FBackend.EnableBracketedPaste;
      FBackend.Flush;
      FBracketedPasteEnabled := True;
    end
    else
      FBracketedPasteEnabled := False;
    FHasMouseTracking := FActiveOptions.RequestsMouseTracking;
    if (LSize.XPixel > 0) and (LSize.Cols > 0) then
      FCellWidth := LSize.XPixel div LSize.Cols
    else
      FCellWidth := 0;
    if (LSize.YPixel > 0) and (LSize.Rows > 0) then
      FCellHeight := LSize.YPixel div LSize.Rows
    else
      FCellHeight := 0;
    FFrameActive := False;
    FLastEnterResult := TTuiEnterResult.OkResult;
    Result := True;
  except
    LeaveTui;
    FLastEnterResult := TTuiEnterResult.Fail(tefSessionSetupFailed, 'session-setup-failed');
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
    if FKittyKeyboardPushed then
    begin
      FBackend.PopKittyKeyboard;
      FKittyKeyboardPushed := False;
      if FCapabilityProfile.KittyKeyboard.Detected then
        FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
          FCapabilityProfile.KittyKeyboard.Requested, True, False, False,
          'session-ended')
      else
        FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
          FCapabilityProfile.KittyKeyboard.Requested, False, False, False,
          'env-hint-missing');
    end;
    if FFocusReportingEnabled then
    begin
      FBackend.DisableFocusReporting;
      FFocusReportingEnabled := False;
    end;
    if FBracketedPasteEnabled then
    begin
      FBackend.DisableBracketedPaste;
      FBracketedPasteEnabled := False;
    end;
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
  FKittyKeyboardPushed := False;
  FFocusReportingEnabled := False;
  FBracketedPasteEnabled := False;
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

procedure TTerminal.SetLinkOverlay(const ALinks: array of TTuiLinkSpan);
var
  LI: Integer;
begin
  System.SetLength(FLinkOverlay, System.Length(ALinks));
  for LI := 0 to System.Length(ALinks) - 1 do
    FLinkOverlay[LI] := ALinks[LI];
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
  { 刀 21：本帧链接 overlay → 后端（绘制命中 cell 时包裹 OSC 8）。
    链接样式已画进 cell（渲染层），glyph/样式差异驱动 diff——此处只需
    在输出层套链接属性，与 diff 机制解耦。 }
  FBackend.SetLinkOverlay(FLinkOverlay);
  if FActiveOptions.SynchronizedUpdate then
    FBackend.BeginSynchronizedUpdate;
  FBackend.DrawPatchesN(FPatches, LPatchCount);
  { 图片协议传输/放置：消费 buffer 里调用方 PlaceImage 的占位。
    kitty/sixel 才输出；half-block（不支持真图片）时为空操作，
    调用方自行降级渲染。惰性创建——协议在 EnterTui 能力检测后才定。 }
  if FImageMgr = nil then
    FImageMgr := TImageManager.Create(GetImageProtocol);
  if FResizeImagePending then
  begin
    if platform_monotonic_ns - FResizePendingSinceNs >= kImageResizeStableNs then
    begin
      FResizeImagePending := False;
      if GetImageProtocol <> ipKitty then
      begin
        { 非 kitty：无按 id 删除能力，保持整清重传（sixel 流式协议） }
        FBackend.AppendRawBytes(PByte(PAnsiChar(#27'_Ga=d,d=a,q=2'#27'\'))^, 16);
        FImageMgr.InvalidateAll;
      end;
      { kitty：Resolve 内按 slot 协调——纯扩大只重放不重传，
        缩小/位移按 id 删除后重传。归位帧一次性传完（ABoosted），
        避免渐进重建让松手后的封面归位显得延迟。 }
      FImageMgr.Resolve(FCurr, FFrameId, FBackend, FCellWidth, FCellHeight,
        FPatches, LPatchCount, True);
    end
    { 尺寸仍在变（拖动中）：冻结图片层，本帧不传输/不放置，避免
      delete-all 风暴 + 新旧坐标重影。图片保持最后一次稳定布局。 }
  end
  else
    FImageMgr.Resolve(FCurr, FFrameId, FBackend, FCellWidth, FCellHeight,
      FPatches, LPatchCount, False);

  if AFrame.HasCursor then
  begin
    FBackend.ShowCursor;
    FBackend.MoveTo(AFrame.CursorPos.X, AFrame.CursorPos.Y);
  end
  else
    FBackend.HideCursor;
  if FActiveOptions.SynchronizedUpdate then
    FBackend.EndSynchronizedUpdate;
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
  LCT := platform_env_get_str('COLORTERM');
  LTP := platform_env_get_str('TERM_PROGRAM');
  LT := platform_env_get_str('TERM');
  LTF := platform_env_get_str('TERM_FEATURES');
  LKittyWindowId := platform_env_get_str('KITTY_WINDOW_ID');
  FCapabilityProfile := DetectCapabilityProfileFromHints(
    LCT, LTP, LT, LTF, LKittyWindowId);
end;

procedure TTerminal.TryNegotiateKittyKeyboard;
begin
  if FBackend = nil then Exit;
  if FKittyKeyboardPushed then
  begin
    { Already pushed this session — keep Active projection consistent.
      Verified only changes via query reply, not re-push. }
    FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
      FCapabilityProfile.KittyKeyboard.Requested,
      True,
      True,
      FCapabilityProfile.KittyKeyboard.Verified,
      FCapabilityProfile.KittyKeyboard.FallbackReason);
    Exit;
  end;
  if FCapabilityProfile.KittyKeyboard.Requested and
     FCapabilityProfile.KittyKeyboard.Detected then
  begin
    FBackend.PushKittyKeyboard;
    FBackend.QueryKittyKeyboard;
    { Flush may fail on test fd (-1) and retain pending; push/query still happened. }
    FBackend.Flush;
    FKittyKeyboardPushed := True;
    { Active after push; Verified waits for CSI ? <flags> u (async, non-blocking). }
    FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
      True, True, True, False, 'query-pending');
  end;
end;

procedure TTerminal.ApplyKittyKeyboardFlagsReply(AFlags: Integer);
begin
  if not FKittyKeyboardPushed then Exit;
  if (AFlags and KittyKeyboardDefaultFlags) <> 0 then
    FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
      True, True, True, True, '')
  else if AFlags > 0 then
    FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
      True, True, True, False, 'query-flags-mismatch')
  else
    FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
      True, True, True, False, 'query-flags-zero');
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

function TTerminal.HasPendingImageTransmit: Boolean;
begin
  Result := (FImageMgr <> nil) and FImageMgr.HasPendingTransmit;
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
  { 图片协议：resize 后布局变化，旧坐标图片会残留。但拖动窗口时
    SIGWINCH 连续到达——若每次立即删图重传，图片会反复"消失-重现"
    闪烁。改为标记 pending：EndFrame 里检测到最后一次 resize 已过去
    kImageResizeStableNs（尺寸稳定）才归位；稳定前冻结图片层（不删
    不传不放，图片停在旧布局）。归位细节：kitty 在 Resolve 内按 slot
    协调（数据分辨率足够时删除旧显示后按新区域重放、不重传；分辨率
    不足才整图重传），非 kitty 整清重传。 }
  FResizeImagePending := True;
  FResizePendingSinceNs := platform_monotonic_ns;
end;

{ 把调用方给的等待超时收敛到"图片层稳定归位所需剩余时间"。
  松手(最后一次 resize)后约 60ms 要出帧归位（扩大重放/缩小重传）；
  若空闲帧率(默认 IdleTickInterval=200ms)比这慢，封面归位会被拖到
  200ms+ 的空闲帧——上下拖拽松手后封面跳变会显得延迟很大。这里把
  等待输入超时压到 min(剩余稳定时间, 原超时)，让 PollEvent 在归位
  时刻准时醒来出帧。 }
function TTerminal.EffectiveWaitTimeout(ATimeoutMs: Integer): Integer;
var
  LElapsedNs, LRemainMs: Int64;
begin
  Result := ATimeoutMs;
  { 图片分帧传输中：空闲帧率(200ms)会拖慢渐进重建（480KB/32KB≈15 帧），
    把等待压到流帧间隔，让 EndFrame 每流帧推进一步，直到传完并放置。 }
  if (FImageMgr <> nil) and FImageMgr.HasPendingTransmit then
  begin
    if (Result < 0) or (kImageStreamFrameMs < Result) then
      Result := kImageStreamFrameMs;
    Exit;
  end;
  if not FResizeImagePending then Exit;
  LElapsedNs := platform_monotonic_ns - FResizePendingSinceNs;
  LRemainMs := (kImageResizeStableNs - LElapsedNs) div 1000000;
  if LRemainMs < 0 then LRemainMs := 0;
  if (Result < 0) or (LRemainMs < Result) then Result := Integer(LRemainMs);
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
  if (LSize.XPixel > 0) and (LSize.Cols > 0) then
    FCellWidth := LSize.XPixel div LSize.Cols
  else
    FCellWidth := 0;
  if (LSize.YPixel > 0) and (LSize.Rows > 0) then
    FCellHeight := LSize.YPixel div LSize.Rows
  else
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

function TTerminal.PasteScan(AAtEOF: Boolean; out AEndAt: Integer): Integer;
{ 在 FInputQueue[0..FInputLen) 里扫描 bracketed paste 终止序列 ESC[201~。
  返回本次可安全消费的字节数;命中时 AEndAt = 终止序列起始偏移,否则 -1。
  未闭合(前缀可能是 201~ 的一部分)且未到 EOF 时,停在 ESC 前等后续字节。 }
var
  I: Integer;
begin
  Result := 0;
  AEndAt := -1;
  I := 0;
  while I < FInputLen do
  begin
    if FInputQueue[I] = 27 then
    begin
      if I + 6 > FInputLen then
      begin
        { 可能是终止序列前缀;EOF 时按文本整段消费,否则停在此处等更多字节 }
        if AAtEOF then
          Result := FInputLen
        else
          Result := I;
        Exit;
      end;
      if (FInputQueue[I + 1] = Ord('[')) and (FInputQueue[I + 2] = Ord('2')) and
         (FInputQueue[I + 3] = Ord('0')) and (FInputQueue[I + 4] = Ord('1')) and
         (FInputQueue[I + 5] = Ord('~')) then
      begin
        AEndAt := I;
        Result := I + 6;   { 含终止序列一并消费 }
        Exit;
      end;
      { 其他 ESC 序列是粘贴内容的字面字节,原样保留 }
      Inc(I);
    end
    else
      Inc(I);
  end;
  Result := FInputLen;
end;

procedure TTerminal.AppendPasteBytes(ACount: Integer);
var
  LOldLen: Integer;
begin
  if ACount <= 0 then Exit;
  LOldLen := Length(FPasteBuffer);
  SetLength(FPasteBuffer, LOldLen + ACount);
  Move(FInputQueue[0], FPasteBuffer[LOldLen + 1], ACount);
end;

function TTerminal.TryParseQueuedEvent(AAtEOF, AScanInvalid: Boolean;
  out AEv: TEvent; out ANeedMore: Boolean): Boolean;
var
  LConsumed, LFlags: Integer;
  LR: TParseResult;
  LEndAt, LTake: Integer;
begin
  Result := False;
  ANeedMore := False;
  AEv := NoneEvent;
  while FInputLen > 0 do
  begin
    { bracketed paste 聚合:内容整段暂存,遇 201~ 才发一次 evPaste。
      逐字符解析会让粘贴里的 \r\n 变 Enter、q/m/1..6 变全局快捷键,
      这正是老版「粘贴触发快捷键」的根因,必须整包收口。 }
    if FInBracketedPaste then
    begin
      LTake := PasteScan(AAtEOF, LEndAt);
      if LEndAt >= 0 then
      begin
        { 命中终止序列:只把文本(终止序列之前)拼入缓冲,序列一并消费 }
        if LEndAt > 0 then
          AppendPasteBytes(LEndAt);
        DropInputBytes(LEndAt + 6);
        FInBracketedPaste := False;
        AEv := PasteEvent;
        Result := True;
        Exit;
      end;
      if LTake > 0 then
        AppendPasteBytes(LTake);
      DropInputBytes(LTake);
      if AAtEOF then
      begin
        { EOF 未闭合:把已聚合内容整包吐出(空内容也发,消费方插空文本无害) }
        FInBracketedPaste := False;
        AEv := PasteEvent;
        Result := True;
        Exit;
      end;
      { 未闭合且未到 EOF:等更多字节,绝不把内容泄漏成独立按键 }
      ANeedMore := True;
      Exit;
    end;

    { Prefer explicit Kitty flags-reply parse so Verified can update. }
    LR := TryParseKittyKeyboardFlagsReply(FInputQueue[0], FInputLen, AAtEOF,
      LFlags, LConsumed);
    if LR = prSuccess then
    begin
      DropInputBytes(LConsumed);
      ApplyKittyKeyboardFlagsReply(LFlags);
      Continue;
    end;
    if LR = prNeedMore then
    begin
      ANeedMore := True;
      Exit;
    end;

    LR := ParseOne(FInputQueue[0], FInputLen, AAtEOF, AEv, LConsumed);
    case LR of
      prSuccess:
        begin
          DropInputBytes(LConsumed);
          if IsPaste(AEv) then
          begin
            { CSI 200~:进入聚合模式,清空缓冲,继续等整包 }
            FInBracketedPaste := True;
            FPasteBuffer := '';
            Continue;
          end;
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
  { 进入过聚合模式且 EOF:把已聚合内容吐出(如测试注入 200~ 后直接 EOF) }
  if FInBracketedPaste and AAtEOF then
  begin
    FInBracketedPaste := False;
    AEv := PasteEvent;
    Result := True;
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

  FBackend := TAnsiBackend.Create(-1, FAllocator);
  FPrev := TBuffer.CreateEmpty(AArea, FAllocator);
  FCurr := TBuffer.CreateEmpty(AArea, FAllocator);
  FMerged := TBuffer.CreateEmpty(AArea, FAllocator);
  FOverlay := TOverlayBuffer.Create(AArea, FAllocator);
  FCapabilityProfile := TTuiTerminalCapabilityProfile.Default;
  FActiveOptions := FOptions;
  FFrameActive := False;
  FFrameId := 0;
  FInRawMode := True;
  FRawModeCaptured := False;
  FShouldQuit := False;
  FHasMouseTracking := False;
  FKittyKeyboardPushed := False;
  FFocusReportingEnabled := False;
  FBracketedPasteEnabled := False;
  FCellWidth := 0;
  FCellHeight := 0;
  if FActiveOptions.FocusReporting then
  begin
    FBackend.EnableFocusReporting;
    FBackend.Flush;
    FFocusReportingEnabled := True;
  end;
  if FActiveOptions.BracketedPaste then
  begin
    FBackend.EnableBracketedPaste;
    FBackend.Flush;
    FBracketedPasteEnabled := True;
  end;
end;

procedure TTerminal.NegotiateKittyKeyboardForTest(ADetected: Boolean);
begin
  EnsureFrameRuntime('NegotiateKittyKeyboardForTest');
  if ADetected then
    FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
      True, True, False, False, 'session-negotiation-pending')
  else
    FCapabilityProfile.KittyKeyboard := TTuiCapabilityStatus.Create(
      True, False, False, False, 'env-hint-missing');
  TryNegotiateKittyKeyboard;
end;

function TTerminal.BackendPendingForTest: AnsiString;
var
  LLen: Integer;
begin
  Result := '';
  if FBackend = nil then Exit;
  LLen := FBackend.PendingLength;
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(FBackend.PendingBytes^, Result[1], LLen);
end;

procedure TTerminal.PromoteMousePos;
begin
  FPrevMousePos := FLastMousePos;
end;

procedure TTerminal.PostProcessEvent(var AEv: TEvent);
begin
  case AEv.Kind of
    evNone, evResize, evPaste, evFocus: ;
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
    if not WaitForInput(STDIN_FD, kEscSequenceWaitMs) then
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

  if not WaitForInput(STDIN_FD, EffectiveWaitTimeout(ATimeoutMs)) then
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

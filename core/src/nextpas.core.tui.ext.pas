unit nextpas.core.tui.ext;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui,
  nextpas.core.tui.focus,
  nextpas.core.tui.interaction,
  nextpas.core.tui.keybind,
  nextpas.core.tui.theme,
  nextpas.core.tui.anim,
  nextpas.core.tui.animator,
  nextpas.core.tui.frame_budget,
  nextpas.core.tui.task,
  nextpas.core.tui.loading,
  nextpas.core.tui.app,
  nextpas.core.tui.app.screen,
  nextpas.core.tui.widget.panel,
  nextpas.core.tui.widget.chat_theme;

type
  TTuiApp = nextpas.core.tui.app.TApp;
  TApp = nextpas.core.tui.app.TApp;
  TTuiFrame = nextpas.core.tui.TFrame;
  TFrame = nextpas.core.tui.TFrame;
  TRect = nextpas.core.tui.TRect;
  TBuffer = nextpas.core.tui.TBuffer;
  TEvent = nextpas.core.tui.TEvent;
  TEventKind = nextpas.core.tui.TEventKind;
  TKeyCodeKind = nextpas.core.tui.TKeyCodeKind;
  TKeyModifier = nextpas.core.tui.TKeyModifier;
  TKeyModifiers = nextpas.core.tui.TKeyModifiers;
  TStyle = nextpas.core.tui.TStyle;
  TTaskId = nextpas.core.tui.task.TTaskId;
  TTaskStatus = nextpas.core.tui.task.TTaskStatus;
  PCancelToken = nextpas.core.tui.task.PCancelToken;
  TCancelToken = nextpas.core.tui.task.TCancelToken;
  PTaskContext = nextpas.core.tui.task.PTaskContext;
  TTaskContext = nextpas.core.tui.task.TTaskContext;
  TTaskResult = nextpas.core.tui.task.TTaskResult;
  TTaskFunc = nextpas.core.tui.task.TTaskFunc;
  TTaskSpec = nextpas.core.tui.task.TTaskSpec;
  TCompletionSlot = nextpas.core.tui.task.TCompletionSlot;
  TTaskManager = nextpas.core.tui.task.TTaskManager;
  TLoadingPhase = nextpas.core.tui.loading.TLoadingPhase;
  TLoadingState = nextpas.core.tui.loading.TLoadingState;
  TLoadingGroup = nextpas.core.tui.loading.TLoadingGroup;
  TAppRenderProc = nextpas.core.tui.app.TAppRenderProc;
  TAppEventProc = nextpas.core.tui.app.TAppEventProc;
  TAppTickProc = nextpas.core.tui.app.TAppTickProc;
  TAppTaskCompletionProc = nextpas.core.tui.app.TAppTaskCompletionProc;
  TTuiScreen = nextpas.core.tui.app.screen.TScreen;
  TScreen = nextpas.core.tui.app.screen.TScreen;
  TTuiScreenStack = nextpas.core.tui.app.screen.TScreenStack;
  TScreenStack = nextpas.core.tui.app.screen.TScreenStack;
  EFtuiScreenError = nextpas.core.tui.app.screen.EFtuiScreenError;
  TTheme = nextpas.core.tui.theme.TTheme;
  TChatTheme = nextpas.core.tui.widget.chat_theme.TTheme;
  IPanel = nextpas.core.tui.widget.panel.IPanel;
  TPanelEdge = nextpas.core.tui.widget.panel.TPanelEdge;
  TPanelEdges = nextpas.core.tui.widget.panel.TPanelEdges;
  TSepTitle = nextpas.core.tui.widget.panel.TSepTitle;
  TPanelGrid = nextpas.core.tui.widget.panel.TPanelGrid;
  TSepHit = nextpas.core.tui.widget.panel.TSepHit;
  TPanel = nextpas.core.tui.widget.panel.TPanel;

const
  peTop = nextpas.core.tui.widget.panel.peTop;
  peBottom = nextpas.core.tui.widget.panel.peBottom;
  peLeft = nextpas.core.tui.widget.panel.peLeft;
  peRight = nextpas.core.tui.widget.panel.peRight;
  peInnerH = nextpas.core.tui.widget.panel.peInnerH;
  peInnerV = nextpas.core.tui.widget.panel.peInnerV;

  TASK_QUEUE_CAPACITY = nextpas.core.tui.task.TASK_QUEUE_CAPACITY;
  MAX_CONCURRENT_TASKS = nextpas.core.tui.task.MAX_CONCURRENT_TASKS;
  tsQueued = nextpas.core.tui.task.tsQueued;
  tsRunning = nextpas.core.tui.task.tsRunning;
  tsCompleted = nextpas.core.tui.task.tsCompleted;
  tsFailed = nextpas.core.tui.task.tsFailed;
  tsCancelled = nextpas.core.tui.task.tsCancelled;
  lpIdle = nextpas.core.tui.loading.lpIdle;
  lpLoading = nextpas.core.tui.loading.lpLoading;
  lpSuccess = nextpas.core.tui.loading.lpSuccess;
  lpError = nextpas.core.tui.loading.lpError;

  PanelEdgesAll: TPanelEdges = [peTop, peBottom, peLeft, peRight, peInnerH, peInnerV];
  PanelEdgesOuter: TPanelEdges = [peTop, peBottom, peLeft, peRight];
  PanelEdgesInner: TPanelEdges = [peInnerH, peInnerV];
  PanelEdgesNone: TPanelEdges = [];

function ColorIsSet(const AColor: nextpas.core.tui.TColor): Boolean; inline;
function IsQuit(const AEv: TEvent): Boolean; inline;
function StyleDefault: TStyle; inline;
function IsCancelled(const Ctx: TTaskContext): Boolean; inline;
function MakeSpec(Func: TTaskFunc; Param: Pointer; ParamSize: UInt32;
  const Name: ShortString): TTaskSpec; inline;
function ThemeDefaultDark: TChatTheme; inline;
function PanelCell(const AGrid: TPanelGrid; ACol, ARow: Integer): nextpas.core.tui.TRect; inline;
function PanelCellSpan(const AGrid: TPanelGrid; ACol, ARow, AColSpan,
  ARowSpan: Integer): nextpas.core.tui.TRect; inline;
function PanelHitTestSep(const AGrid: TPanelGrid; AX, AY: Integer): TSepHit; inline;

implementation

function ColorIsSet(const AColor: nextpas.core.tui.TColor): Boolean;
begin
  Result := nextpas.core.tui.ColorIsSet(AColor);
end;

function IsQuit(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.IsQuit(AEv);
end;

function StyleDefault: TStyle;
begin
  Result := nextpas.core.tui.StyleDefault;
end;

function IsCancelled(const Ctx: TTaskContext): Boolean;
begin
  Result := nextpas.core.tui.task.IsCancelled(Ctx);
end;

function MakeSpec(Func: TTaskFunc; Param: Pointer; ParamSize: UInt32;
  const Name: ShortString): TTaskSpec;
begin
  Result := nextpas.core.tui.task.MakeSpec(Func, Param, ParamSize, Name);
end;

function ThemeDefaultDark: TChatTheme;
begin
  Result := nextpas.core.tui.widget.chat_theme.ThemeDefaultDark;
end;

function PanelCell(const AGrid: TPanelGrid; ACol, ARow: Integer): nextpas.core.tui.TRect;
begin
  Result := nextpas.core.tui.widget.panel.PanelCell(AGrid, ACol, ARow);
end;

function PanelCellSpan(const AGrid: TPanelGrid; ACol, ARow, AColSpan,
  ARowSpan: Integer): nextpas.core.tui.TRect;
begin
  Result := nextpas.core.tui.widget.panel.PanelCellSpan(
    AGrid, ACol, ARow, AColSpan, ARowSpan);
end;

function PanelHitTestSep(const AGrid: TPanelGrid; AX, AY: Integer): TSepHit;
begin
  Result := nextpas.core.tui.widget.panel.PanelHitTestSep(AGrid, AX, AY);
end;

end.

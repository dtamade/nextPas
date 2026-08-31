unit nextpas.core.tui.ext;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui,
  nextpas.core.tui.error,
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
  nextpas.core.tui.widget.chat_theme,
  nextpas.core.tui.widget.scrollview,
  nextpas.core.tui.widget.modal,
  nextpas.core.tui.widget.dialog,
  nextpas.core.tui.widget.split_pane,
  nextpas.core.tui.widget.select,
  nextpas.core.tui.widget.statusbar,
  nextpas.core.tui.widget.progress_group,
  nextpas.core.tui.widget.breadcrumb,
  nextpas.core.tui.widget.timeline,
  nextpas.core.tui.widget.kanban,
  nextpas.core.tui.widget.markdown,
  nextpas.core.tui.widget.tooltip,
  nextpas.core.tui.widget.toast,
  nextpas.core.tui.widget.barchart,
  nextpas.core.tui.widget.linechart,
  nextpas.core.tui.widget.calendar,
  nextpas.core.tui.widget.tree,
  nextpas.core.tui.widget.file_tree,
  nextpas.core.tui.widget.diffview,
  nextpas.core.tui.widget.input_editor,
  nextpas.core.tui.widget.command_palette,
  nextpas.core.tui.widget.notification_center,
  nextpas.core.tui.widget.popover,
  nextpas.core.tui.widget.menu,
  { PH33 P4：解禁扩面（tui888 PH33 计划 §1.4 审计 A−；full facade 同名别名
    在册先例）——数据可视化三件套 }
  nextpas.core.tui.widget.gauge,
  nextpas.core.tui.widget.sparkline,
  nextpas.core.tui.widget.canvas;

type
  ETui = nextpas.core.tui.error.ETui;
  ETuiBackend = nextpas.core.tui.error.ETuiBackend;
  TApp = nextpas.core.tui.app.TApp;
  TFrame = nextpas.core.tui.TFrame;
  TTuiEnterFailure = nextpas.core.tui.TTuiEnterFailure;
  TTuiEnterResult = nextpas.core.tui.TTuiEnterResult;
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
  TScreen = nextpas.core.tui.app.screen.TScreen;
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
  IScrollView = nextpas.core.tui.widget.scrollview.IScrollView;
  TScrollViewState = nextpas.core.tui.widget.scrollview.TScrollViewState;
  TScrollView = nextpas.core.tui.widget.scrollview.TScrollView;
  IModal = nextpas.core.tui.widget.modal.IModal;
  TModalSize = nextpas.core.tui.widget.modal.TModalSize;
  TModal = nextpas.core.tui.widget.modal.TModal;
  IDialog = nextpas.core.tui.widget.dialog.IDialog;
  TDialogButton = nextpas.core.tui.widget.dialog.TDialogButton;
  TDialog = nextpas.core.tui.widget.dialog.TDialog;
  ISplitPane = nextpas.core.tui.widget.split_pane.ISplitPane;
  TSplitDirection = nextpas.core.tui.widget.split_pane.TSplitDirection;
  TSplitPaneState = nextpas.core.tui.widget.split_pane.TSplitPaneState;
  TSplitPane = nextpas.core.tui.widget.split_pane.TSplitPane;
  ISelect = nextpas.core.tui.widget.select.ISelect;
  TSelectState = nextpas.core.tui.widget.select.TSelectState;
  TSelect = nextpas.core.tui.widget.select.TSelect;
  IStatusBar = nextpas.core.tui.widget.statusbar.IStatusBar;
  TStatusSegment = nextpas.core.tui.widget.statusbar.TStatusSegment;
  TStatusBar = nextpas.core.tui.widget.statusbar.TStatusBar;
  IProgressGroup = nextpas.core.tui.widget.progress_group.IProgressGroup;
  TProgressItem = nextpas.core.tui.widget.progress_group.TProgressItem;
  TProgressGroup = nextpas.core.tui.widget.progress_group.TProgressGroup;
  IBreadcrumb = nextpas.core.tui.widget.breadcrumb.IBreadcrumb;
  TBreadcrumb = nextpas.core.tui.widget.breadcrumb.TBreadcrumb;
  TTimelineEvent = nextpas.core.tui.widget.timeline.TTimelineEvent;
  ITimeline = nextpas.core.tui.widget.timeline.ITimeline;
  TTimeline = nextpas.core.tui.widget.timeline.TTimeline;
  TKanbanCard = nextpas.core.tui.widget.kanban.TKanbanCard;
  TKanbanColumn = nextpas.core.tui.widget.kanban.TKanbanColumn;
  TKanbanState = nextpas.core.tui.widget.kanban.TKanbanState;
  IKanban = nextpas.core.tui.widget.kanban.IKanban;
  TKanban = nextpas.core.tui.widget.kanban.TKanban;
  TMdLineKind = nextpas.core.tui.widget.markdown.TMdLineKind;
  TMdLine = nextpas.core.tui.widget.markdown.TMdLine;
  TMdLineArray = nextpas.core.tui.widget.markdown.TMdLineArray;
  TMdTheme = nextpas.core.tui.widget.markdown.TMdTheme;
  IMarkdown = nextpas.core.tui.widget.markdown.IMarkdown;
  TMarkdown = nextpas.core.tui.widget.markdown.TMarkdown;
  TTooltipPosition = nextpas.core.tui.widget.tooltip.TTooltipPosition;
  ITooltip = nextpas.core.tui.widget.tooltip.ITooltip;
  TTooltip = nextpas.core.tui.widget.tooltip.TTooltip;
  TToastPosition = nextpas.core.tui.widget.toast.TToastPosition;
  TToastLevel = nextpas.core.tui.widget.toast.TToastLevel;
  TToastItem = nextpas.core.tui.widget.toast.TToastItem;
  IToastManager = nextpas.core.tui.widget.toast.IToastManager;
  TToastManager = nextpas.core.tui.widget.toast.TToastManager;
  IBarChart = nextpas.core.tui.widget.barchart.IBarChart;
  TBarData = nextpas.core.tui.widget.barchart.TBarData;
  TBarChart = nextpas.core.tui.widget.barchart.TBarChart;
  ILineChart = nextpas.core.tui.widget.linechart.ILineChart;
  TDataSeries = nextpas.core.tui.widget.linechart.TDataSeries;
  TLineChart = nextpas.core.tui.widget.linechart.TLineChart;
  ICalendar = nextpas.core.tui.widget.calendar.ICalendar;
  TCalendarState = nextpas.core.tui.widget.calendar.TCalendarState;
  TCalendar = nextpas.core.tui.widget.calendar.TCalendar;
  ITree = nextpas.core.tui.widget.tree.ITree;
  TTreeNode = nextpas.core.tui.widget.tree.TTreeNode;
  PTreeNode = nextpas.core.tui.widget.tree.PTreeNode;
  TTreeState = nextpas.core.tui.widget.tree.TTreeState;
  TTree = nextpas.core.tui.widget.tree.TTree;
  IFileTree = nextpas.core.tui.widget.file_tree.IFileTree;
  TFileNode = nextpas.core.tui.widget.file_tree.TFileNode;
  TFileTreeState = nextpas.core.tui.widget.file_tree.TFileTreeState;
  TFileTree = nextpas.core.tui.widget.file_tree.TFileTree;
  IDiffView = nextpas.core.tui.widget.diffview.IDiffView;
  TDiffLineKind = nextpas.core.tui.widget.diffview.TDiffLineKind;
  TDiffLine = nextpas.core.tui.widget.diffview.TDiffLine;
  TDiffViewState = nextpas.core.tui.widget.diffview.TDiffViewState;
  TDiffView = nextpas.core.tui.widget.diffview.TDiffView;
  IInputEditor = nextpas.core.tui.widget.input_editor.IInputEditor;
  TInputEditor = nextpas.core.tui.widget.input_editor.TInputEditor;
  ICommandPalette = nextpas.core.tui.widget.command_palette.ICommandPalette;
  TCommandItem = nextpas.core.tui.widget.command_palette.TCommandItem;
  TCommandPaletteState = nextpas.core.tui.widget.command_palette.TCommandPaletteState;
  TCommandPalette = nextpas.core.tui.widget.command_palette.TCommandPalette;
  INotificationCenter = nextpas.core.tui.widget.notification_center.INotificationCenter;
  TNotifLevel = nextpas.core.tui.widget.notification_center.TNotifLevel;
  TNotification = nextpas.core.tui.widget.notification_center.TNotification;
  TNotificationCenterState = nextpas.core.tui.widget.notification_center.TNotificationCenterState;
  TNotificationCenter = nextpas.core.tui.widget.notification_center.TNotificationCenter;
  IPopover = nextpas.core.tui.widget.popover.IPopover;
  TPopoverAnchor = nextpas.core.tui.widget.popover.TPopoverAnchor;
  TPopoverState = nextpas.core.tui.widget.popover.TPopoverState;
  TPopover = nextpas.core.tui.widget.popover.TPopover;
  IMenu = nextpas.core.tui.widget.menu.IMenu;
  TMenuItemKind = nextpas.core.tui.widget.menu.TMenuItemKind;
  TMenuItem = nextpas.core.tui.widget.menu.TMenuItem;
  TMenuState = nextpas.core.tui.widget.menu.TMenuState;
  TMenu = nextpas.core.tui.widget.menu.TMenu;
  { PH33 P4：解禁扩面（gauge/canvas/sparkline）——ext rejects 探针同批删除，
    正测 test_tui_ext_facade 增构造+渲染断言守门 }
  IGauge = nextpas.core.tui.widget.gauge.IGauge;
  TGauge = nextpas.core.tui.widget.gauge.TGauge;
  ISparkline = nextpas.core.tui.widget.sparkline.ISparkline;
  TSparkline = nextpas.core.tui.widget.sparkline.TSparkline;
  ICanvas = nextpas.core.tui.widget.canvas.ICanvas;
  TCanvas = nextpas.core.tui.widget.canvas.TCanvas;

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

  tlInfo = nextpas.core.tui.widget.toast.tlInfo;
  tlSuccess = nextpas.core.tui.widget.toast.tlSuccess;
  tlWarning = nextpas.core.tui.widget.toast.tlWarning;
  tlError = nextpas.core.tui.widget.toast.tlError;

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
function MakeColumn(const ATitle: AnsiString; const ACards: array of TKanbanCard): TKanbanColumn; inline;

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

function MakeColumn(const ATitle: AnsiString; const ACards: array of TKanbanCard): TKanbanColumn;
begin
  Result := nextpas.core.tui.widget.kanban.MakeColumn(ATitle, ACards);
end;

end.

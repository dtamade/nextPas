unit nextpas.core.tui.full;

{**
 * @desc nextpas.core.tui.full 兼容门面——保留迁移期的全量公共 API。
 *       通过类型别名和 inline 转发聚合子模块。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.error,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.overlay,
  nextpas.core.tui.text,
  nextpas.core.tui.text.format,
  nextpas.core.tui.borders,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.grid,
  nextpas.core.tui.layout.dsl,
  nextpas.core.tui.event,
  nextpas.core.tui.input,
  nextpas.core.tui.interaction,
  nextpas.core.tui.focus,
  nextpas.core.tui.keybind,
  nextpas.core.tui.ansi,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.backend.test,
  nextpas.core.tui.terminal,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.sixel,
  nextpas.core.tui.image_mgr,
  nextpas.core.tui.theme,
  nextpas.core.tui.anim,
  nextpas.core.tui.animator,
  nextpas.core.tui.frame_budget,
  nextpas.core.tui.clipboard,
  nextpas.core.tui.task,
  nextpas.core.tui.loading,
  nextpas.core.tui.app,
  nextpas.core.tui.app.screen,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.tui.widget.list,
  nextpas.core.tui.widget.clear,
  nextpas.core.tui.widget.tabs,
  nextpas.core.tui.widget.scrollbar,
  nextpas.core.tui.widget.gauge,
  nextpas.core.tui.widget.sparkline,
  nextpas.core.tui.widget.barchart,
  nextpas.core.tui.widget.canvas,
  nextpas.core.tui.widget.table,
  nextpas.core.tui.widget.input,
  nextpas.core.tui.widget.tree,
  nextpas.core.tui.widget.dialog,
  nextpas.core.tui.widget.menu,
  nextpas.core.tui.widget.panel,
  nextpas.core.tui.widget.split_pane,
  nextpas.core.tui.widget.modal,
  nextpas.core.tui.widget.popover,
  nextpas.core.tui.widget.tooltip,
  nextpas.core.tui.widget.select,
  nextpas.core.tui.widget.scrollview,
  nextpas.core.tui.widget.calendar,
  nextpas.core.tui.widget.breadcrumb,
  nextpas.core.tui.widget.statusbar,
  nextpas.core.tui.widget.timeline,
  nextpas.core.tui.widget.progress_group,
  nextpas.core.tui.widget.linechart,
  nextpas.core.tui.widget.input_editor,
  nextpas.core.tui.widget.diffview,
  nextpas.core.tui.widget.file_tree,
  nextpas.core.tui.widget.kanban,
  nextpas.core.tui.widget.markdown,
  nextpas.core.tui.widget.virtual_list,
  nextpas.core.tui.widget.command_palette,
  nextpas.core.tui.widget.notification_center,
  nextpas.core.tui.widget.form,
  nextpas.core.tui.widget.syntax,
  nextpas.core.tui.widget.toast,
  nextpas.core.tui.widget.chat_theme;

{ 门面 re-export：FPC 不支持自动 re-export，消费方 uses 本单元后
  可直接访问上述所有子模块的公共类型和函数。 }

type
  { 基础类型 }
  TTuiRect = nextpas.core.tui.base.TRect;
  TTuiPosition = nextpas.core.tui.base.TPosition;
  TTuiSize = nextpas.core.tui.base.TSize;
  TTuiDirection = nextpas.core.tui.base.TDirection;
  TRect = nextpas.core.tui.base.TRect;
  TPosition = nextpas.core.tui.base.TPosition;
  TSize = nextpas.core.tui.base.TSize;
  TMargin = nextpas.core.tui.base.TMargin;
  TDirection = nextpas.core.tui.base.TDirection;

  { 样式 }
  TTuiColor = nextpas.core.tui.color.TColor;
  TTuiColorKind = nextpas.core.tui.color.TColorKind;
  TColor = nextpas.core.tui.color.TColor;
  TColorKind = nextpas.core.tui.color.TColorKind;
  TTuiModifier = nextpas.core.tui.modifier.TModifier;
  TTuiModifierBit = nextpas.core.tui.modifier.TModifierBit;
  TModifier = nextpas.core.tui.modifier.TModifier;
  TModifierBit = nextpas.core.tui.modifier.TModifierBit;
  TTuiStyle = nextpas.core.tui.style.TStyle;
  TStyle = nextpas.core.tui.style.TStyle;
  TTuiCell = nextpas.core.tui.cell.TCell;
  TCell = nextpas.core.tui.cell.TCell;
  PCell = nextpas.core.tui.cell.PCell;

  { Image }
  TImageProtocol = nextpas.core.tui.image_cap.TImageProtocol;
  TClipboardMethod = nextpas.core.tui.clipboard.TClipboardMethod;
  TClipboard = nextpas.core.tui.clipboard.TClipboard;

  { Buffer }
  TTuiBuffer = nextpas.core.tui.buffer.TBuffer;
  TTuiDiffEntries = nextpas.core.tui.buffer.TDiffEntries;
  TBuffer = nextpas.core.tui.buffer.TBuffer;
  TDiffEntry = nextpas.core.tui.buffer.TDiffEntry;
  TDiffEntries = nextpas.core.tui.buffer.TDiffEntries;
  TBufferLines = nextpas.core.tui.buffer.TBufferLines;

  { Text }
  TAlignment = nextpas.core.tui.text.TAlignment;
  TSpan = nextpas.core.tui.text.TSpan;
  TSpans = nextpas.core.tui.text.TSpans;
  TLine = nextpas.core.tui.text.TLine;
  TLines = nextpas.core.tui.text.TLines;
  TText = nextpas.core.tui.text.TText;

  { Layout }
  TConstraintKind = nextpas.core.tui.layout.TConstraintKind;
  TConstraint = nextpas.core.tui.layout.TConstraint;
  TConstraints = nextpas.core.tui.layout.TConstraints;
  TRectArray = nextpas.core.tui.layout.TRectArray;
  TIntArray = nextpas.core.tui.layout.TIntArray;
  TLayout = nextpas.core.tui.layout.TLayout;
  TGridResult = nextpas.core.tui.layout.grid.TGridResult;

  { Borders }
  TBorderSide = nextpas.core.tui.borders.TBorderSide;
  TBorders = nextpas.core.tui.borders.TBorders;
  TBorderSet = nextpas.core.tui.borders.TBorderSet;

  { 事件 }
  TTuiEvent = nextpas.core.tui.event.TEvent;
  TTuiEventKind = nextpas.core.tui.event.TEventKind;
  TEvent = nextpas.core.tui.event.TEvent;
  TEventKind = nextpas.core.tui.event.TEventKind;
  TKeyCodeKind = nextpas.core.tui.event.TKeyCodeKind;
  TKeyModifier = nextpas.core.tui.event.TKeyModifier;
  TKeyModifiers = nextpas.core.tui.event.TKeyModifiers;
  TKeyEvent = nextpas.core.tui.event.TKeyEvent;
  TMouseEventKind = nextpas.core.tui.event.TMouseEventKind;
  TMouseButton = nextpas.core.tui.event.TMouseButton;
  TMouseEvent = nextpas.core.tui.event.TMouseEvent;
  TResizeEvent = nextpas.core.tui.event.TResizeEvent;

  { Terminal }
  TTuiTerminal = nextpas.core.tui.terminal.TTerminal;
  TTuiFrame = nextpas.core.tui.terminal.TFrame;
  TTuiTerminalOptions = nextpas.core.tui.terminal.TTerminalOptions;
  TTerminal = nextpas.core.tui.terminal.TTerminal;
  TFrame = nextpas.core.tui.terminal.TFrame;
  TTerminalOptions = nextpas.core.tui.terminal.TTerminalOptions;

  { App }
  TTuiApp = nextpas.core.tui.app.TApp;
  TApp = nextpas.core.tui.app.TApp;
  TTuiScreen = nextpas.core.tui.app.screen.TScreen;
  TScreen = nextpas.core.tui.app.screen.TScreen;
  TTuiScreenStack = nextpas.core.tui.app.screen.TScreenStack;
  TScreenStack = nextpas.core.tui.app.screen.TScreenStack;
  EFtuiScreenError = nextpas.core.tui.app.screen.EFtuiScreenError;
  TTheme = nextpas.core.tui.theme.TTheme;

  { Widget 接口 }
  ITuiWidget = nextpas.core.tui.widget.intf.IWidget;
  ITuiBlock = nextpas.core.tui.widget.block.IBlock;
  IWidget = nextpas.core.tui.widget.intf.IWidget;
  TWidgetRenderFn = nextpas.core.tui.widget.intf.TWidgetRenderFn;
  TWidgetAdapter = nextpas.core.tui.widget.intf.TWidgetAdapter;
  IBlock = nextpas.core.tui.widget.block.IBlock;
  IParagraph = nextpas.core.tui.widget.paragraph.IParagraph;
  IListWidget = nextpas.core.tui.widget.list.IListWidget;
  ITabsWidget = nextpas.core.tui.widget.tabs.ITabsWidget;
  IScrollbar = nextpas.core.tui.widget.scrollbar.IScrollbar;
  ITable = nextpas.core.tui.widget.table.ITable;
  IGauge = nextpas.core.tui.widget.gauge.IGauge;
  ISparkline = nextpas.core.tui.widget.sparkline.ISparkline;
  IBarChart = nextpas.core.tui.widget.barchart.IBarChart;
  ICanvas = nextpas.core.tui.widget.canvas.ICanvas;
  IInput = nextpas.core.tui.widget.input.IInput;
  ITree = nextpas.core.tui.widget.tree.ITree;
  IDialog = nextpas.core.tui.widget.dialog.IDialog;
  IMenu = nextpas.core.tui.widget.menu.IMenu;
  IPanel = nextpas.core.tui.widget.panel.IPanel;
  ISplitPane = nextpas.core.tui.widget.split_pane.ISplitPane;
  IModal = nextpas.core.tui.widget.modal.IModal;
  IPopover = nextpas.core.tui.widget.popover.IPopover;
  ITooltip = nextpas.core.tui.widget.tooltip.ITooltip;
  ISelect = nextpas.core.tui.widget.select.ISelect;
  IScrollView = nextpas.core.tui.widget.scrollview.IScrollView;
  ICalendar = nextpas.core.tui.widget.calendar.ICalendar;
  IBreadcrumb = nextpas.core.tui.widget.breadcrumb.IBreadcrumb;
  IStatusBar = nextpas.core.tui.widget.statusbar.IStatusBar;
  ITimeline = nextpas.core.tui.widget.timeline.ITimeline;
  IProgressGroup = nextpas.core.tui.widget.progress_group.IProgressGroup;
  ILineChart = nextpas.core.tui.widget.linechart.ILineChart;
  IInputEditor = nextpas.core.tui.widget.input_editor.IInputEditor;
  IDiffView = nextpas.core.tui.widget.diffview.IDiffView;
  IFileTree = nextpas.core.tui.widget.file_tree.IFileTree;
  IKanban = nextpas.core.tui.widget.kanban.IKanban;
  IMarkdown = nextpas.core.tui.widget.markdown.IMarkdown;
  IVirtualList = nextpas.core.tui.widget.virtual_list.IVirtualList;
  ICommandPalette = nextpas.core.tui.widget.command_palette.ICommandPalette;
  INotificationCenter = nextpas.core.tui.widget.notification_center.INotificationCenter;
  ICheckbox = nextpas.core.tui.widget.form.ICheckbox;
  IRadioGroup = nextpas.core.tui.widget.form.IRadioGroup;
  IHighlighter = nextpas.core.tui.widget.syntax.IHighlighter;
  IToastManager = nextpas.core.tui.widget.toast.IToastManager;

  TListItem = nextpas.core.tui.widget.list.TListItem;
  TListItems = nextpas.core.tui.widget.list.TListItems;
  TListState = nextpas.core.tui.widget.list.TListState;
  TWrap = nextpas.core.tui.widget.paragraph.TWrap;
  TTabsState = nextpas.core.tui.widget.tabs.TTabsState;
  TScrollbarHit = nextpas.core.tui.widget.scrollbar.TScrollbarHit;
  TInputState = nextpas.core.tui.widget.input.TInputState;
  TGaugeThreshold = nextpas.core.tui.widget.gauge.TGaugeThreshold;
  TBarData = nextpas.core.tui.widget.barchart.TBarData;
  TContentAlign = nextpas.core.tui.widget.table.TContentAlign;
  TTableColumn = nextpas.core.tui.widget.table.TTableColumn;
  TTableRow = nextpas.core.tui.widget.table.TTableRow;
  TTableState = nextpas.core.tui.widget.table.TTableState;
  TTreeNode = nextpas.core.tui.widget.tree.TTreeNode;
  PTreeNode = nextpas.core.tui.widget.tree.PTreeNode;
  TTreeState = nextpas.core.tui.widget.tree.TTreeState;
  TDialogButton = nextpas.core.tui.widget.dialog.TDialogButton;
  TMenuItemKind = nextpas.core.tui.widget.menu.TMenuItemKind;
  TMenuItem = nextpas.core.tui.widget.menu.TMenuItem;
  TMenuState = nextpas.core.tui.widget.menu.TMenuState;
  TPanelEdge = nextpas.core.tui.widget.panel.TPanelEdge;
  TPanelEdges = nextpas.core.tui.widget.panel.TPanelEdges;
  TSepTitle = nextpas.core.tui.widget.panel.TSepTitle;
  TPanelGrid = nextpas.core.tui.widget.panel.TPanelGrid;
  TSepHit = nextpas.core.tui.widget.panel.TSepHit;
  TSplitDirection = nextpas.core.tui.widget.split_pane.TSplitDirection;
  TSplitPaneState = nextpas.core.tui.widget.split_pane.TSplitPaneState;
  TModalSize = nextpas.core.tui.widget.modal.TModalSize;
  TPopoverAnchor = nextpas.core.tui.widget.popover.TPopoverAnchor;
  TPopoverState = nextpas.core.tui.widget.popover.TPopoverState;
  TTooltipPosition = nextpas.core.tui.widget.tooltip.TTooltipPosition;
  TSelectState = nextpas.core.tui.widget.select.TSelectState;
  TScrollViewState = nextpas.core.tui.widget.scrollview.TScrollViewState;
  TCalendarState = nextpas.core.tui.widget.calendar.TCalendarState;
  TStatusSegment = nextpas.core.tui.widget.statusbar.TStatusSegment;
  TTimelineEvent = nextpas.core.tui.widget.timeline.TTimelineEvent;
  TProgressItem = nextpas.core.tui.widget.progress_group.TProgressItem;
  TDataSeries = nextpas.core.tui.widget.linechart.TDataSeries;
  TDiffLineKind = nextpas.core.tui.widget.diffview.TDiffLineKind;
  TDiffLine = nextpas.core.tui.widget.diffview.TDiffLine;
  TDiffViewState = nextpas.core.tui.widget.diffview.TDiffViewState;
  TFileNode = nextpas.core.tui.widget.file_tree.TFileNode;
  TFileTreeState = nextpas.core.tui.widget.file_tree.TFileTreeState;
  TKanbanCard = nextpas.core.tui.widget.kanban.TKanbanCard;
  TKanbanColumn = nextpas.core.tui.widget.kanban.TKanbanColumn;
  TKanbanState = nextpas.core.tui.widget.kanban.TKanbanState;
  TMdLineKind = nextpas.core.tui.widget.markdown.TMdLineKind;
  TMdLine = nextpas.core.tui.widget.markdown.TMdLine;
  TMdLineArray = nextpas.core.tui.widget.markdown.TMdLineArray;
  TMdTheme = nextpas.core.tui.widget.markdown.TMdTheme;
  TItemProviderFunc = nextpas.core.tui.widget.virtual_list.TItemProviderFunc;
  TVirtualListState = nextpas.core.tui.widget.virtual_list.TVirtualListState;
  TCommandItem = nextpas.core.tui.widget.command_palette.TCommandItem;
  TCommandPaletteState = nextpas.core.tui.widget.command_palette.TCommandPaletteState;
  TNotifLevel = nextpas.core.tui.widget.notification_center.TNotifLevel;
  TNotification = nextpas.core.tui.widget.notification_center.TNotification;
  TNotificationCenterState = nextpas.core.tui.widget.notification_center.TNotificationCenterState;
  TTokenKind = nextpas.core.tui.widget.syntax.TTokenKind;
  PToken = nextpas.core.tui.widget.syntax.PToken;
  TToken = nextpas.core.tui.widget.syntax.TToken;
  TTokenArray = nextpas.core.tui.widget.syntax.TTokenArray;
  TLineState = nextpas.core.tui.widget.syntax.TLineState;
  TGetLineFunc = nextpas.core.tui.widget.syntax.TGetLineFunc;
  TPascalHighlighter = nextpas.core.tui.widget.syntax.TPascalHighlighter;
  TSyntaxDoc = nextpas.core.tui.widget.syntax.TSyntaxDoc;
  TSyntaxTheme = nextpas.core.tui.widget.syntax.TSyntaxTheme;
  TToastPosition = nextpas.core.tui.widget.toast.TToastPosition;
  TToastLevel = nextpas.core.tui.widget.toast.TToastLevel;
  TToastItem = nextpas.core.tui.widget.toast.TToastItem;

  TBlock = nextpas.core.tui.widget.block.TBlock;
  TParagraph = nextpas.core.tui.widget.paragraph.TParagraph;
  TListWidget = nextpas.core.tui.widget.list.TListWidget;
  TClearWidget = nextpas.core.tui.widget.clear.TClearWidget;
  TTabsWidget = nextpas.core.tui.widget.tabs.TTabsWidget;
  TScrollbar = nextpas.core.tui.widget.scrollbar.TScrollbar;
  TGauge = nextpas.core.tui.widget.gauge.TGauge;
  TSparkline = nextpas.core.tui.widget.sparkline.TSparkline;
  TBarChart = nextpas.core.tui.widget.barchart.TBarChart;
  TCanvas = nextpas.core.tui.widget.canvas.TCanvas;
  TTable = nextpas.core.tui.widget.table.TTable;
  TInput = nextpas.core.tui.widget.input.TInput;
  TTree = nextpas.core.tui.widget.tree.TTree;
  TDialog = nextpas.core.tui.widget.dialog.TDialog;
  TMenu = nextpas.core.tui.widget.menu.TMenu;
  TPanel = nextpas.core.tui.widget.panel.TPanel;
  TSplitPane = nextpas.core.tui.widget.split_pane.TSplitPane;
  TModal = nextpas.core.tui.widget.modal.TModal;
  TPopover = nextpas.core.tui.widget.popover.TPopover;
  TTooltip = nextpas.core.tui.widget.tooltip.TTooltip;
  TSelect = nextpas.core.tui.widget.select.TSelect;
  TScrollView = nextpas.core.tui.widget.scrollview.TScrollView;
  TCalendar = nextpas.core.tui.widget.calendar.TCalendar;
  TBreadcrumb = nextpas.core.tui.widget.breadcrumb.TBreadcrumb;
  TStatusBar = nextpas.core.tui.widget.statusbar.TStatusBar;
  TTimeline = nextpas.core.tui.widget.timeline.TTimeline;
  TProgressGroup = nextpas.core.tui.widget.progress_group.TProgressGroup;
  TLineChart = nextpas.core.tui.widget.linechart.TLineChart;
  TInputEditor = nextpas.core.tui.widget.input_editor.TInputEditor;
  TDiffView = nextpas.core.tui.widget.diffview.TDiffView;
  TFileTree = nextpas.core.tui.widget.file_tree.TFileTree;
  TKanban = nextpas.core.tui.widget.kanban.TKanban;
  TMarkdown = nextpas.core.tui.widget.markdown.TMarkdown;
  TVirtualList = nextpas.core.tui.widget.virtual_list.TVirtualList;
  TCommandPalette = nextpas.core.tui.widget.command_palette.TCommandPalette;
  TNotificationCenter = nextpas.core.tui.widget.notification_center.TNotificationCenter;
  TCheckbox = nextpas.core.tui.widget.form.TCheckbox;
  TRadioGroup = nextpas.core.tui.widget.form.TRadioGroup;
  TToastManager = nextpas.core.tui.widget.toast.TToastManager;

  TChatTheme = nextpas.core.tui.widget.chat_theme.TTheme;

const
  ckUnset = nextpas.core.tui.color.ckUnset;
  ckReset = nextpas.core.tui.color.ckReset;
  ckIndexed = nextpas.core.tui.color.ckIndexed;
  ckRgb = nextpas.core.tui.color.ckRgb;

  TUI_BLACK: TColor = (Kind: ckIndexed; Index: 0);
  TUI_RED: TColor = (Kind: ckIndexed; Index: 1);
  TUI_GREEN: TColor = (Kind: ckIndexed; Index: 2);
  TUI_YELLOW: TColor = (Kind: ckIndexed; Index: 3);
  TUI_BLUE: TColor = (Kind: ckIndexed; Index: 4);
  TUI_MAGENTA: TColor = (Kind: ckIndexed; Index: 5);
  TUI_CYAN: TColor = (Kind: ckIndexed; Index: 6);
  TUI_GRAY: TColor = (Kind: ckIndexed; Index: 7);
  TUI_DARK_GRAY: TColor = (Kind: ckIndexed; Index: 8);
  TUI_LIGHT_RED: TColor = (Kind: ckIndexed; Index: 9);
  TUI_LIGHT_GREEN: TColor = (Kind: ckIndexed; Index: 10);
  TUI_LIGHT_YELLOW: TColor = (Kind: ckIndexed; Index: 11);
  TUI_LIGHT_BLUE: TColor = (Kind: ckIndexed; Index: 12);
  TUI_LIGHT_MAGENTA: TColor = (Kind: ckIndexed; Index: 13);
  TUI_LIGHT_CYAN: TColor = (Kind: ckIndexed; Index: 14);
  TUI_WHITE: TColor = (Kind: ckIndexed; Index: 15);

  mbBold = nextpas.core.tui.modifier.mbBold;
  mbDim = nextpas.core.tui.modifier.mbDim;
  mbItalic = nextpas.core.tui.modifier.mbItalic;
  mbUnderlined = nextpas.core.tui.modifier.mbUnderlined;
  mbSlowBlink = nextpas.core.tui.modifier.mbSlowBlink;
  mbRapidBlink = nextpas.core.tui.modifier.mbRapidBlink;
  mbReversed = nextpas.core.tui.modifier.mbReversed;
  mbHidden = nextpas.core.tui.modifier.mbHidden;
  mbCrossedOut = nextpas.core.tui.modifier.mbCrossedOut;
  MODIFIER_NONE: TModifier = [];

  ipAuto = nextpas.core.tui.image_cap.ipAuto;
  ipKitty = nextpas.core.tui.image_cap.ipKitty;
  ipSixel = nextpas.core.tui.image_cap.ipSixel;
  ipHalfBlock = nextpas.core.tui.image_cap.ipHalfBlock;
  cmOSC52 = nextpas.core.tui.clipboard.cmOSC52;
  cmExternal = nextpas.core.tui.clipboard.cmExternal;
  cmNone = nextpas.core.tui.clipboard.cmNone;

  ckLength = nextpas.core.tui.layout.ckLength;
  ckMin = nextpas.core.tui.layout.ckMin;
  ckMax = nextpas.core.tui.layout.ckMax;
  ckPercentage = nextpas.core.tui.layout.ckPercentage;
  ckFill = nextpas.core.tui.layout.ckFill;

  BORDERS_NONE: TBorders = [];
  BORDERS_ALL: TBorders = [bsTop, bsRight, bsBottom, bsLeft];
  BORDER_HORIZONTAL: AnsiString = #$E2#$94#$80;
  BORDER_VERTICAL: AnsiString = #$E2#$94#$82;
  BORDER_TOP_LEFT: AnsiString = #$E2#$94#$8C;
  BORDER_TOP_RIGHT: AnsiString = #$E2#$94#$90;
  BORDER_BOTTOM_LEFT: AnsiString = #$E2#$94#$94;
  BORDER_BOTTOM_RIGHT: AnsiString = #$E2#$94#$98;
  BORDER_ROUNDED_TL: AnsiString = #$E2#$95#$AD;
  BORDER_ROUNDED_TR: AnsiString = #$E2#$95#$AE;
  BORDER_ROUNDED_BL: AnsiString = #$E2#$95#$B0;
  BORDER_ROUNDED_BR: AnsiString = #$E2#$95#$AF;
  BORDER_LEFT_T: AnsiString = #$E2#$94#$9C;
  BORDER_RIGHT_T: AnsiString = #$E2#$94#$A4;
  BORDER_TOP_T: AnsiString = #$E2#$94#$AC;
  BORDER_BOTTOM_T: AnsiString = #$E2#$94#$B4;
  BORDER_CROSS: AnsiString = #$E2#$94#$BC;
  BORDER_DOUBLE_H: AnsiString = #$E2#$95#$90;
  BORDER_DOUBLE_V: AnsiString = #$E2#$95#$91;
  BORDER_DOUBLE_TL: AnsiString = #$E2#$95#$94;
  BORDER_DOUBLE_TR: AnsiString = #$E2#$95#$97;
  BORDER_DOUBLE_BL: AnsiString = #$E2#$95#$9A;
  BORDER_DOUBLE_BR: AnsiString = #$E2#$95#$9D;
  BORDER_DOUBLE_LT: AnsiString = #$E2#$95#$A0;
  BORDER_DOUBLE_RT: AnsiString = #$E2#$95#$A3;
  BORDER_DOUBLE_TT: AnsiString = #$E2#$95#$A6;
  BORDER_DOUBLE_BT: AnsiString = #$E2#$95#$A9;
  BORDER_DOUBLE_CROSS: AnsiString = #$E2#$95#$AC;
  BORDER_HEAVY_H: AnsiString = #$E2#$94#$81;
  BORDER_HEAVY_V: AnsiString = #$E2#$94#$83;
  BORDER_HEAVY_TL: AnsiString = #$E2#$94#$8F;
  BORDER_HEAVY_TR: AnsiString = #$E2#$94#$93;
  BORDER_HEAVY_BL: AnsiString = #$E2#$94#$97;
  BORDER_HEAVY_BR: AnsiString = #$E2#$94#$9B;
  BORDER_HEAVY_LT: AnsiString = #$E2#$94#$A3;
  BORDER_HEAVY_RT: AnsiString = #$E2#$94#$AB;
  BORDER_HEAVY_TT: AnsiString = #$E2#$94#$B3;
  BORDER_HEAVY_BT: AnsiString = #$E2#$94#$BB;
  BORDER_HEAVY_CROSS: AnsiString = #$E2#$95#$8B;
  BORDER_DASHED_H: AnsiString = #$E2#$94#$84;
  BORDER_DASHED_V: AnsiString = #$E2#$94#$86;

  evNone = nextpas.core.tui.event.evNone;
  evKey = nextpas.core.tui.event.evKey;
  evMouse = nextpas.core.tui.event.evMouse;
  evResize = nextpas.core.tui.event.evResize;
  evPaste = nextpas.core.tui.event.evPaste;
  kcChar = nextpas.core.tui.event.kcChar;
  kcEnter = nextpas.core.tui.event.kcEnter;
  kcEsc = nextpas.core.tui.event.kcEsc;
  kcTab = nextpas.core.tui.event.kcTab;
  kcBackTab = nextpas.core.tui.event.kcBackTab;
  kcBackspace = nextpas.core.tui.event.kcBackspace;
  kcDelete = nextpas.core.tui.event.kcDelete;
  kcLeft = nextpas.core.tui.event.kcLeft;
  kcRight = nextpas.core.tui.event.kcRight;
  kcUp = nextpas.core.tui.event.kcUp;
  kcDown = nextpas.core.tui.event.kcDown;
  kcHome = nextpas.core.tui.event.kcHome;
  kcEnd = nextpas.core.tui.event.kcEnd;
  kcPageUp = nextpas.core.tui.event.kcPageUp;
  kcPageDown = nextpas.core.tui.event.kcPageDown;
  kcInsert = nextpas.core.tui.event.kcInsert;
  kcF = nextpas.core.tui.event.kcF;
  kmCtrl = nextpas.core.tui.event.kmCtrl;
  kmAlt = nextpas.core.tui.event.kmAlt;
  kmShift = nextpas.core.tui.event.kmShift;

  peTop = nextpas.core.tui.widget.panel.peTop;
  peBottom = nextpas.core.tui.widget.panel.peBottom;
  peLeft = nextpas.core.tui.widget.panel.peLeft;
  peRight = nextpas.core.tui.widget.panel.peRight;
  peInnerH = nextpas.core.tui.widget.panel.peInnerH;
  peInnerV = nextpas.core.tui.widget.panel.peInnerV;

  PanelEdgesAll: TPanelEdges = [peTop, peBottom, peLeft, peRight, peInnerH, peInnerV];
  PanelEdgesOuter: TPanelEdges = [peTop, peBottom, peLeft, peRight];
  PanelEdgesInner: TPanelEdges = [peInnerH, peInnerV];
  PanelEdgesNone: TPanelEdges = [];

  shNone = nextpas.core.tui.widget.scrollbar.shNone;
  shAbove = nextpas.core.tui.widget.scrollbar.shAbove;
  shThumb = nextpas.core.tui.widget.scrollbar.shThumb;
  shBelow = nextpas.core.tui.widget.scrollbar.shBelow;
  mlNormal = nextpas.core.tui.widget.markdown.mlNormal;
  mlH1 = nextpas.core.tui.widget.markdown.mlH1;
  mlH2 = nextpas.core.tui.widget.markdown.mlH2;
  mlH3 = nextpas.core.tui.widget.markdown.mlH3;
  mlBullet = nextpas.core.tui.widget.markdown.mlBullet;
  mlNumbered = nextpas.core.tui.widget.markdown.mlNumbered;
  mlCode = nextpas.core.tui.widget.markdown.mlCode;
  mlCodeBlock = nextpas.core.tui.widget.markdown.mlCodeBlock;
  mlHRule = nextpas.core.tui.widget.markdown.mlHRule;
  tlInfo = nextpas.core.tui.widget.toast.tlInfo;
  tlSuccess = nextpas.core.tui.widget.toast.tlSuccess;
  tlWarning = nextpas.core.tui.widget.toast.tlWarning;
  tlError = nextpas.core.tui.widget.toast.tlError;
  tkNormal = nextpas.core.tui.widget.syntax.tkNormal;
  tkKeyword = nextpas.core.tui.widget.syntax.tkKeyword;
  tkString = nextpas.core.tui.widget.syntax.tkString;
  tkComment = nextpas.core.tui.widget.syntax.tkComment;
  tkNumber = nextpas.core.tui.widget.syntax.tkNumber;
  tkDirective = nextpas.core.tui.widget.syntax.tkDirective;
  tkSymbol = nextpas.core.tui.widget.syntax.tkSymbol;

  caLeft = nextpas.core.tui.text.caLeft;
  caCenter = nextpas.core.tui.text.caCenter;
  caRight = nextpas.core.tui.text.caRight;

  WRAP_TRIM: TWrap = (Trim: True);

function PositionMake(const AX, AY: Word): TPosition; inline;
function SizeMake(const AWidth, AHeight: Word): TSize; inline;
function MarginMake(const AHorizontal, AVertical: Word): TMargin; inline;
function RectEquals(const A, B: TRect): Boolean; inline;
function PositionEquals(const A, B: TPosition): Boolean; inline;

function UnsetColor: TColor; inline;
function ResetColor: TColor; inline;
function IndexedColor(const AIndex: Byte): TColor; inline;
function RgbColor(const AR, AG, AB: Byte): TColor; inline;
function ColorEquals(const A, B: TColor): Boolean; inline;
function ColorIsSet(const AColor: TColor): Boolean; inline;
function Rgb(const AR, AG, AB: Byte): TColor; inline;
function Idx(const AIndex: Byte): TColor; inline;
function HexColor(const AHex: AnsiString): TColor; inline;
function ModifierEquals(const A, B: TModifier): Boolean; inline;
function ModifierIsEmpty(const AModifier: TModifier): Boolean; inline;
function DetectImageProtocol: TImageProtocol; inline;

function StyleDefault: TStyle; inline;
function StyleEquals(const A, B: TStyle): Boolean; inline;
function StyleFg(const AColor: TColor): TStyle; inline;
function StyleBg(const AColor: TColor): TStyle; inline;
function StyleFgBg(const AFg, ABg: TColor): TStyle; inline;
function StyleBold: TStyle; inline;
function StyleItalic: TStyle; inline;

function BorderSetPlain: TBorderSet; inline;
function BorderSetRounded: TBorderSet; inline;
function BorderSetDouble: TBorderSet; inline;
function BorderSetHeavy: TBorderSet; inline;
function BorderSetDashed: TBorderSet; inline;

function LengthConstraint(AN: Word): TConstraint; inline;
function MinConstraint(AN: Word): TConstraint; inline;
function MaxConstraint(AN: Word): TConstraint; inline;
function PercentageConstraint(AN: Word): TConstraint; inline;
function FillConstraint(AWeight: Word): TConstraint; inline;
function RatioConstraint(ANumerator, ADenominator: Word): TConstraint; inline;
function HorizontalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
function VerticalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
function ComputeSlotSizes(ATotal: Integer; const ACs: array of TConstraint): TIntArray;
function Fixed(AN: Word): TConstraint; inline;
function Flex(AWeight: Word = 1): TConstraint; inline;
function Pct(AN: Word): TConstraint; inline;
function AtLeast(AN: Word): TConstraint; inline;
function AtMost(AN: Word): TConstraint; inline;
function Even(ACount: Word): TConstraints;
function V(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
function H(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
function Grid(const AArea: TRect; const ARowConstraints: array of TConstraint;
  const AColConstraints: array of TConstraint): TGridResult; overload;
function Grid(const AArea: TRect; ARowCount, AColCount: Integer): TGridResult; overload;

function NoneEvent: TEvent; inline;
function KeyCharEvent(ACh: LongWord; AMods: TKeyModifiers): TEvent; inline;
function KeyCodeEvent(ACode: TKeyCodeKind; AMods: TKeyModifiers): TEvent; inline;
function KeyFunctionEvent(AF: Byte; AMods: TKeyModifiers): TEvent; inline;
function MouseEvent(AKind: TMouseEventKind; ABtn: TMouseButton;
  AX, AY: Word; AMods: TKeyModifiers): TEvent; inline;
function ResizeEvent(AWidth, AHeight: Word): TEvent; inline;
function PasteEvent: TEvent; inline;
function IsNone(const AEv: TEvent): Boolean; inline;
function IsKey(const AEv: TEvent): Boolean; inline;
function IsMouse(const AEv: TEvent): Boolean; inline;
function IsResize(const AEv: TEvent): Boolean; inline;
function IsPaste(const AEv: TEvent): Boolean; inline;
function IsKeyChar(const AEv: TEvent; ACh: LongWord): Boolean; inline;
function IsKeyCode(const AEv: TEvent; ACode: TKeyCodeKind): Boolean; inline;
function IsQuit(const AEv: TEvent): Boolean; inline;
function FormatBytes(ABytes: Int64): AnsiString; inline;
function FormatBytesKB(AKB: Int64): AnsiString; inline;

function PanelCell(const AGrid: TPanelGrid; ACol, ARow: Integer): TRect; inline;
function PanelCellPadded(const APanel: TPanel; const AGrid: TPanelGrid;
  ACol, ARow: Integer): TRect;
function PanelCellSpan(const AGrid: TPanelGrid; ACol, ARow, AColSpan,
  ARowSpan: Integer): TRect;
function PanelHitTestSep(const AGrid: TPanelGrid; AX, AY: Integer): TSepHit;

function MakeColumn(const ATitle: AnsiString;
  const ACards: array of TKanbanCard): TKanbanColumn;
function ParseMarkdownLines(const ASource: AnsiString): TMdLineArray;
function FuzzyMatch(const APattern, AText: AnsiString): Boolean; inline;
function FuzzyScore(const APattern, AText: AnsiString): Integer; inline;
function TokenizePascal(const ALine: AnsiString): TTokenArray;
function TokenizePascalStateful(const ALine: AnsiString;
  const AStateIn: TLineState; out AStateOut: TLineState): TTokenArray;
function IsPascalKeyword(const AWord: AnsiString): Boolean; inline;
function IsPascalKeywordP(AP: PAnsiChar; ALen: Integer): Boolean; inline;
function ThemeDefaultDark: TChatTheme; inline;

implementation

function PositionMake(const AX, AY: Word): TPosition;
begin
  Result := nextpas.core.tui.base.PositionMake(AX, AY);
end;

function SizeMake(const AWidth, AHeight: Word): TSize;
begin
  Result := nextpas.core.tui.base.SizeMake(AWidth, AHeight);
end;

function MarginMake(const AHorizontal, AVertical: Word): TMargin;
begin
  Result := nextpas.core.tui.base.MarginMake(AHorizontal, AVertical);
end;

function RectEquals(const A, B: TRect): Boolean;
begin
  Result := nextpas.core.tui.base.RectEquals(A, B);
end;

function PositionEquals(const A, B: TPosition): Boolean;
begin
  Result := nextpas.core.tui.base.PositionEquals(A, B);
end;

function UnsetColor: TColor;
begin
  Result := nextpas.core.tui.color.UnsetColor;
end;

function ResetColor: TColor;
begin
  Result := nextpas.core.tui.color.ResetColor;
end;

function IndexedColor(const AIndex: Byte): TColor;
begin
  Result := nextpas.core.tui.color.IndexedColor(AIndex);
end;

function RgbColor(const AR, AG, AB: Byte): TColor;
begin
  Result := nextpas.core.tui.color.RgbColor(AR, AG, AB);
end;

function ColorEquals(const A, B: TColor): Boolean;
begin
  Result := nextpas.core.tui.color.ColorEquals(A, B);
end;

function ColorIsSet(const AColor: TColor): Boolean;
begin
  Result := nextpas.core.tui.color.ColorIsSet(AColor);
end;

function Rgb(const AR, AG, AB: Byte): TColor;
begin
  Result := nextpas.core.tui.color.Rgb(AR, AG, AB);
end;

function Idx(const AIndex: Byte): TColor;
begin
  Result := nextpas.core.tui.color.Idx(AIndex);
end;

function HexColor(const AHex: AnsiString): TColor;
begin
  Result := nextpas.core.tui.color.HexColor(AHex);
end;

function ModifierEquals(const A, B: TModifier): Boolean;
begin
  Result := nextpas.core.tui.modifier.ModifierEquals(A, B);
end;

function ModifierIsEmpty(const AModifier: TModifier): Boolean;
begin
  Result := nextpas.core.tui.modifier.ModifierIsEmpty(AModifier);
end;

function DetectImageProtocol: TImageProtocol;
begin
  Result := nextpas.core.tui.image_cap.DetectImageProtocol;
end;

function StyleDefault: TStyle;
begin
  Result := nextpas.core.tui.style.StyleDefault;
end;

function StyleEquals(const A, B: TStyle): Boolean;
begin
  Result := nextpas.core.tui.style.StyleEquals(A, B);
end;

function StyleFg(const AColor: TColor): TStyle;
begin
  Result := nextpas.core.tui.style.StyleFg(AColor);
end;

function StyleBg(const AColor: TColor): TStyle;
begin
  Result := nextpas.core.tui.style.StyleBg(AColor);
end;

function StyleFgBg(const AFg, ABg: TColor): TStyle;
begin
  Result := nextpas.core.tui.style.StyleFgBg(AFg, ABg);
end;

function StyleBold: TStyle;
begin
  Result := nextpas.core.tui.style.StyleBold;
end;

function StyleItalic: TStyle;
begin
  Result := nextpas.core.tui.style.StyleItalic;
end;

function BorderSetPlain: TBorderSet;
begin
  Result := nextpas.core.tui.borders.BorderSetPlain;
end;

function BorderSetRounded: TBorderSet;
begin
  Result := nextpas.core.tui.borders.BorderSetRounded;
end;

function BorderSetDouble: TBorderSet;
begin
  Result := nextpas.core.tui.borders.BorderSetDouble;
end;

function BorderSetHeavy: TBorderSet;
begin
  Result := nextpas.core.tui.borders.BorderSetHeavy;
end;

function BorderSetDashed: TBorderSet;
begin
  Result := nextpas.core.tui.borders.BorderSetDashed;
end;

function LengthConstraint(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.LengthConstraint(AN);
end;

function MinConstraint(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.MinConstraint(AN);
end;

function MaxConstraint(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.MaxConstraint(AN);
end;

function PercentageConstraint(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.PercentageConstraint(AN);
end;

function FillConstraint(AWeight: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.FillConstraint(AWeight);
end;

function RatioConstraint(ANumerator, ADenominator: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.RatioConstraint(ANumerator, ADenominator);
end;

function HorizontalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := nextpas.core.tui.layout.HorizontalSplit(AArea, ACs);
end;

function VerticalSplit(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := nextpas.core.tui.layout.VerticalSplit(AArea, ACs);
end;

function ComputeSlotSizes(ATotal: Integer; const ACs: array of TConstraint): TIntArray;
begin
  Result := nextpas.core.tui.layout.ComputeSlotSizes(ATotal, ACs);
end;

function Fixed(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.dsl.Fixed(AN);
end;

function Flex(AWeight: Word = 1): TConstraint;
begin
  Result := nextpas.core.tui.layout.dsl.Flex(AWeight);
end;

function Pct(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.dsl.Pct(AN);
end;

function AtLeast(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.dsl.AtLeast(AN);
end;

function AtMost(AN: Word): TConstraint;
begin
  Result := nextpas.core.tui.layout.dsl.AtMost(AN);
end;

function Even(ACount: Word): TConstraints;
begin
  Result := nextpas.core.tui.layout.dsl.Even(ACount);
end;

function V(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := nextpas.core.tui.layout.dsl.V(AArea, ACs);
end;

function H(const AArea: TRect; const ACs: array of TConstraint): TRectArray;
begin
  Result := nextpas.core.tui.layout.dsl.H(AArea, ACs);
end;

function Grid(const AArea: TRect; const ARowConstraints: array of TConstraint;
  const AColConstraints: array of TConstraint): TGridResult;
begin
  Result := nextpas.core.tui.layout.grid.Grid(AArea, ARowConstraints, AColConstraints);
end;

function Grid(const AArea: TRect; ARowCount, AColCount: Integer): TGridResult;
begin
  Result := nextpas.core.tui.layout.grid.Grid(AArea, ARowCount, AColCount);
end;

function NoneEvent: TEvent;
begin
  Result := nextpas.core.tui.event.NoneEvent;
end;

function KeyCharEvent(ACh: LongWord; AMods: TKeyModifiers): TEvent;
begin
  Result := nextpas.core.tui.event.KeyCharEvent(ACh, AMods);
end;

function KeyCodeEvent(ACode: TKeyCodeKind; AMods: TKeyModifiers): TEvent;
begin
  Result := nextpas.core.tui.event.KeyCodeEvent(ACode, AMods);
end;

function KeyFunctionEvent(AF: Byte; AMods: TKeyModifiers): TEvent;
begin
  Result := nextpas.core.tui.event.KeyFunctionEvent(AF, AMods);
end;

function MouseEvent(AKind: TMouseEventKind; ABtn: TMouseButton;
  AX, AY: Word; AMods: TKeyModifiers): TEvent;
begin
  Result := nextpas.core.tui.event.MouseEvent(AKind, ABtn, AX, AY, AMods);
end;

function ResizeEvent(AWidth, AHeight: Word): TEvent;
begin
  Result := nextpas.core.tui.event.ResizeEvent(AWidth, AHeight);
end;

function PasteEvent: TEvent;
begin
  Result := nextpas.core.tui.event.PasteEvent;
end;

function IsNone(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsNone(AEv);
end;

function IsKey(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsKey(AEv);
end;

function IsMouse(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsMouse(AEv);
end;

function IsResize(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsResize(AEv);
end;

function IsPaste(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsPaste(AEv);
end;

function IsKeyChar(const AEv: TEvent; ACh: LongWord): Boolean;
begin
  Result := nextpas.core.tui.event.IsKeyChar(AEv, ACh);
end;

function IsKeyCode(const AEv: TEvent; ACode: TKeyCodeKind): Boolean;
begin
  Result := nextpas.core.tui.event.IsKeyCode(AEv, ACode);
end;

function IsQuit(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsQuit(AEv);
end;

function FormatBytes(ABytes: Int64): AnsiString;
begin
  Result := nextpas.core.tui.text.format.FormatBytes(ABytes);
end;

function FormatBytesKB(AKB: Int64): AnsiString;
begin
  Result := nextpas.core.tui.text.format.FormatBytesKB(AKB);
end;

function PanelCell(const AGrid: TPanelGrid; ACol, ARow: Integer): TRect;
begin
  Result := nextpas.core.tui.widget.panel.PanelCell(AGrid, ACol, ARow);
end;

function PanelCellPadded(const APanel: TPanel; const AGrid: TPanelGrid;
  ACol, ARow: Integer): TRect;
begin
  Result := nextpas.core.tui.widget.panel.PanelCellPadded(APanel, AGrid, ACol, ARow);
end;

function PanelCellSpan(const AGrid: TPanelGrid; ACol, ARow, AColSpan,
  ARowSpan: Integer): TRect;
begin
  Result := nextpas.core.tui.widget.panel.PanelCellSpan(AGrid, ACol, ARow, AColSpan, ARowSpan);
end;

function PanelHitTestSep(const AGrid: TPanelGrid; AX, AY: Integer): TSepHit;
begin
  Result := nextpas.core.tui.widget.panel.PanelHitTestSep(AGrid, AX, AY);
end;

function MakeColumn(const ATitle: AnsiString;
  const ACards: array of TKanbanCard): TKanbanColumn;
begin
  Result := nextpas.core.tui.widget.kanban.MakeColumn(ATitle, ACards);
end;

function ParseMarkdownLines(const ASource: AnsiString): TMdLineArray;
begin
  Result := nextpas.core.tui.widget.markdown.ParseMarkdownLines(ASource);
end;

function FuzzyMatch(const APattern, AText: AnsiString): Boolean;
begin
  Result := nextpas.core.tui.widget.command_palette.FuzzyMatch(APattern, AText);
end;

function FuzzyScore(const APattern, AText: AnsiString): Integer;
begin
  Result := nextpas.core.tui.widget.command_palette.FuzzyScore(APattern, AText);
end;

function TokenizePascal(const ALine: AnsiString): TTokenArray;
begin
  Result := nextpas.core.tui.widget.syntax.TokenizePascal(ALine);
end;

function TokenizePascalStateful(const ALine: AnsiString;
  const AStateIn: TLineState; out AStateOut: TLineState): TTokenArray;
begin
  Result := nextpas.core.tui.widget.syntax.TokenizePascalStateful(ALine, AStateIn, AStateOut);
end;

function IsPascalKeyword(const AWord: AnsiString): Boolean;
begin
  Result := nextpas.core.tui.widget.syntax.IsPascalKeyword(AWord);
end;

function IsPascalKeywordP(AP: PAnsiChar; ALen: Integer): Boolean;
begin
  Result := nextpas.core.tui.widget.syntax.IsPascalKeywordP(AP, ALen);
end;

function ThemeDefaultDark: TChatTheme;
begin
  Result := nextpas.core.tui.widget.chat_theme.ThemeDefaultDark;
end;

end.

unit nextpas.core.tui;

{**
 * @desc nextpas.core.tui Core 门面——终端正确性最小闭包（slim）。
 *       仅 re-export 类型/常量薄别名，零行为转发；几何/颜色/样式/布局/事件等
 *       行为函数请按需 uses 子facade（tui.base / tui.color / tui.style / tui.borders /
 *       tui.layout / tui.layout.dsl / tui.event 等），终端/画布能力请按需
 *       uses tui.terminal / tui.canvas 独立子家族（六域四件套已兑现，见 CONTRACT §1.4）。
 *       性能：零拷贝 TByteSpan 复用 bytes.ops 单源，热点 inline 在子域承载（TerminalAnsiEscSpan/
 *       CanvasCellSpan 等），本门面零堆分配；稳定性：Buffer/Terminal Destroy 幂等配对释放，
 *       heaptrc0 双路径门禁（HEAPTRC_GATE=1）。
 *       边界：不混 ext/terminal/canvas，core 仅 L3→L0-L2，不依赖 tls/net/http，缺能力反哺 owner。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
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
  nextpas.core.tui.ansi,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.backend.test,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.tui.widget.list,
  nextpas.core.tui.widget.clear,
  nextpas.core.tui.widget.tabs,
  nextpas.core.tui.widget.scrollbar,
  nextpas.core.tui.widget.table,
  nextpas.core.tui.widget.input;

type
  TRect = nextpas.core.tui.base.TRect;
  TPosition = nextpas.core.tui.base.TPosition;
  TSize = nextpas.core.tui.base.TSize;
  TMargin = nextpas.core.tui.base.TMargin;
  TDirection = nextpas.core.tui.base.TDirection;

  TColor = nextpas.core.tui.color.TColor;
  TColorKind = nextpas.core.tui.color.TColorKind;
  TModifier = nextpas.core.tui.modifier.TModifier;
  TModifierBit = nextpas.core.tui.modifier.TModifierBit;
  TStyle = nextpas.core.tui.style.TStyle;
  TCell = nextpas.core.tui.cell.TCell;
  PCell = nextpas.core.tui.cell.PCell;

  TBuffer = nextpas.core.tui.buffer.TBuffer;
  TDiffEntry = nextpas.core.tui.buffer.TDiffEntry;
  TDiffEntries = nextpas.core.tui.buffer.TDiffEntries;
  TBufferLines = nextpas.core.tui.buffer.TBufferLines;

  TAlignment = nextpas.core.tui.text.TAlignment;
  TSpan = nextpas.core.tui.text.TSpan;
  TSpans = nextpas.core.tui.text.TSpans;
  TLine = nextpas.core.tui.text.TLine;
  TLines = nextpas.core.tui.text.TLines;
  TText = nextpas.core.tui.text.TText;

  TConstraintKind = nextpas.core.tui.layout.TConstraintKind;
  TConstraint = nextpas.core.tui.layout.TConstraint;
  TConstraints = nextpas.core.tui.layout.TConstraints;
  TRectArray = nextpas.core.tui.layout.TRectArray;
  TIntArray = nextpas.core.tui.layout.TIntArray;
  TLayout = nextpas.core.tui.layout.TLayout;
  TGridResult = nextpas.core.tui.layout.grid.TGridResult;

  TBorderSide = nextpas.core.tui.borders.TBorderSide;
  TBorders = nextpas.core.tui.borders.TBorders;
  TBorderSet = nextpas.core.tui.borders.TBorderSet;

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
  TFocusEventKind = nextpas.core.tui.event.TFocusEventKind;
  TFocusEvent = nextpas.core.tui.event.TFocusEvent;

  IWidget = nextpas.core.tui.widget.intf.IWidget;
  TWidgetRenderFn = nextpas.core.tui.widget.intf.TWidgetRenderFn;
  TWidgetAdapter = nextpas.core.tui.widget.intf.TWidgetAdapter;
  IBlock = nextpas.core.tui.widget.block.IBlock;
  IParagraph = nextpas.core.tui.widget.paragraph.IParagraph;
  IListWidget = nextpas.core.tui.widget.list.IListWidget;
  ITabsWidget = nextpas.core.tui.widget.tabs.ITabsWidget;
  IScrollbar = nextpas.core.tui.widget.scrollbar.IScrollbar;
  ITable = nextpas.core.tui.widget.table.ITable;
  IInput = nextpas.core.tui.widget.input.IInput;

  TListItem = nextpas.core.tui.widget.list.TListItem;
  TListItems = nextpas.core.tui.widget.list.TListItems;
  TListState = nextpas.core.tui.widget.list.TListState;
  TWrap = nextpas.core.tui.widget.paragraph.TWrap;
  TTabsState = nextpas.core.tui.widget.tabs.TTabsState;
  TScrollbarHit = nextpas.core.tui.widget.scrollbar.TScrollbarHit;
  TInputState = nextpas.core.tui.widget.input.TInputState;
  TContentAlign = nextpas.core.tui.widget.table.TContentAlign;
  TTableColumn = nextpas.core.tui.widget.table.TTableColumn;
  TTableRow = nextpas.core.tui.widget.table.TTableRow;
  TTableState = nextpas.core.tui.widget.table.TTableState;

  TBlock = nextpas.core.tui.widget.block.TBlock;
  TParagraph = nextpas.core.tui.widget.paragraph.TParagraph;
  TListWidget = nextpas.core.tui.widget.list.TListWidget;
  TClearWidget = nextpas.core.tui.widget.clear.TClearWidget;
  TTabsWidget = nextpas.core.tui.widget.tabs.TTabsWidget;
  TScrollbar = nextpas.core.tui.widget.scrollbar.TScrollbar;
  TTable = nextpas.core.tui.widget.table.TTable;
  TInput = nextpas.core.tui.widget.input.TInput;

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

  evNone = nextpas.core.tui.event.evNone;
  evKey = nextpas.core.tui.event.evKey;
  evMouse = nextpas.core.tui.event.evMouse;
  evResize = nextpas.core.tui.event.evResize;
  evPaste = nextpas.core.tui.event.evPaste;
  evFocus = nextpas.core.tui.event.evFocus;
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
  fkIn = nextpas.core.tui.event.fkIn;
  fkOut = nextpas.core.tui.event.fkOut;

  shNone = nextpas.core.tui.widget.scrollbar.shNone;
  shAbove = nextpas.core.tui.widget.scrollbar.shAbove;
  shThumb = nextpas.core.tui.widget.scrollbar.shThumb;
  shBelow = nextpas.core.tui.widget.scrollbar.shBelow;

  caLeft = nextpas.core.tui.text.caLeft;
  caCenter = nextpas.core.tui.text.caCenter;
  caRight = nextpas.core.tui.text.caRight;

  WRAP_TRIM: TWrap = (Trim: True);

{ 薄别名函数已收敛至子facade按需 uses：
  - 几何: nextpas.core.tui.base (PositionMake/SizeMake/MarginMake/RectEquals/PositionEquals)
  - 颜色/样式: nextpas.core.tui.color / modifier / style (UnsetColor/Rgb/HexColor/StyleDefault/StyleFg 等)
  - 边框: nextpas.core.tui.borders (BorderSetPlain/Rounded/Double/Heavy/Dashed)
  - 布局: nextpas.core.tui.layout + layout.dsl + layout.grid (LengthConstraint/Fixed/Flex/Pct/V/H/Grid 等)
  - 事件: nextpas.core.tui.event (NoneEvent/KeyCharEvent/IsFocus/IsKeyChar/IsQuit 等)
  - 终端: nextpas.core.tui.terminal.base/.intf/.terminal (TTerminal/TFrame/TTerminalOptions/TerminalAnsiEscSpan inline 零拷贝 TByteSpan via bytes.ops)
  - 画布: nextpas.core.tui.canvas.base/.intf/.canvas (CanvasIsEmptyCell/CanvasCellSpan inline)
  本门面不再堆砌 60+ inline 转发；热点 inline/零拷贝证据由子域承载（bytes.ops 单源），堆零分配，所有权归子家族；DoLeaveTui 幂等释放 heaptrc0 双门禁。 }

implementation

end.

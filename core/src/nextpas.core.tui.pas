unit nextpas.core.tui;

{**
 * @desc nextpas.core.tui Core 门面——默认暴露终端正确性的最小闭包。
 *       非基础 app/runtime、图像、clipboard、复杂 widget 能力通过 ext /
 *       experimental / full 门面显式引入。
 *       边界：终端能力（TTerminal/TTuiEnter*/TFrame）由 `tui.terminal`
 *       子家族独立拥有，本门面仅 `T* = tui.terminal.T*` 薄别名 `inline` 转发，
 *       无独立堆分配；泄漏门禁与子家族共享 `HEAPTRC_GATE=1` heaptrc0
 *      （`DoLeaveTui` 幂等释放不丢），`bytes.ops` 单源复用不复制。
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
  nextpas.core.tui.ansi,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.backend.test,
  nextpas.core.tui.terminal,
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

  TTuiEnterFailure = nextpas.core.tui.terminal.TTuiEnterFailure;
  TTuiEnterResult = nextpas.core.tui.terminal.TTuiEnterResult;
  TTerminal = nextpas.core.tui.terminal.TTerminal;
  TFrame = nextpas.core.tui.terminal.TFrame;
  TTerminalOptions = nextpas.core.tui.terminal.TTerminalOptions;

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
function FocusEvent(AKind: TFocusEventKind): TEvent; inline;
function IsNone(const AEv: TEvent): Boolean; inline;
function IsKey(const AEv: TEvent): Boolean; inline;
function IsMouse(const AEv: TEvent): Boolean; inline;
function IsResize(const AEv: TEvent): Boolean; inline;
function IsPaste(const AEv: TEvent): Boolean; inline;
function IsFocus(const AEv: TEvent): Boolean; inline;
function IsFocusIn(const AEv: TEvent): Boolean; inline;
function IsFocusOut(const AEv: TEvent): Boolean; inline;
function IsKeyChar(const AEv: TEvent; ACh: LongWord): Boolean; inline;
function IsKeyCode(const AEv: TEvent; ACode: TKeyCodeKind): Boolean; inline;
function IsQuit(const AEv: TEvent): Boolean; inline;

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

function Flex(AWeight: Word): TConstraint;
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

function FocusEvent(AKind: TFocusEventKind): TEvent;
begin
  Result := nextpas.core.tui.event.FocusEvent(AKind);
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

function IsFocus(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsFocus(AEv);
end;

function IsFocusIn(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsFocusIn(AEv);
end;

function IsFocusOut(const AEv: TEvent): Boolean;
begin
  Result := nextpas.core.tui.event.IsFocusOut(AEv);
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

end.

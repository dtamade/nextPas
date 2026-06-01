# Widget Catalog

All widgets implement `IWidget` via `class(TInterfacedObject, IWidget, IXxx)`.
Factory: `TXxx.New(...): IXxx`. Builder methods return the specific interface.

## Core Widgets

| Widget | Interface | Stateful | Description |
|--------|-----------|----------|-------------|
| TBlock | IBlock | No | Container with borders and title |
| TParagraph | IParagraph | No | Word-wrapped text block |
| TListWidget | IListWidget | Yes | Vertical scrolling list with highlight |
| TTable | ITable | Yes | Column-aligned data table with header |
| TGauge | IGauge | No | Horizontal progress bar (sub-cell precision) |
| TTabsWidget | ITabsWidget | No | Horizontal tab bar |
| TScrollbar | IScrollbar | No | Vertical scrollbar (track/thumb) |
| TClearWidget | IWidget | No | Fills area with empty cells |
| TInput | IInput | Yes | Single-line text input with cursor |
| TSparkline | ISparkline | No | Braille-based line sparkline |
| TBarChart | IBarChart | No | Vertical bar chart (Unicode blocks) |
| TCanvas | ICanvas | No | Braille dot-matrix drawing surface |

## Extended Widgets

| Widget | Interface | Stateful | Description |
|--------|-----------|----------|-------------|
| TTree | ITree | Yes | Hierarchical tree with expand/collapse |
| TDialog | IDialog | No | Modal dialog with buttons |
| TMenu | IMenu | Yes | Vertical menu with shortcuts |
| TPanel | IPanel | No | Grid layout with borders/separators |
| TSplitPane | ISplitPane | Yes | Horizontal/vertical split |
| TModal | IModal | No | Centered overlay with dim background |
| TPopover | IPopover | Yes | Positioned popup |
| TTooltip | ITooltip | No | Anchored tooltip with border |
| TSelect | ISelect | Yes | Dropdown selection |
| TScrollView | IScrollView | Yes | Scrollable viewport |
| TCalendar | ICalendar | Yes | Month grid calendar |
| TBreadcrumb | IBreadcrumb | No | Path breadcrumb trail |
| TStatusBar | IStatusBar | No | Left/center/right segment bar |
| TTimeline | ITimeline | No | Vertical event timeline |
| TProgressGroup | IProgressGroup | No | Multiple progress bars |
| TLineChart | ILineChart | No | Multi-series braille line chart |
| TInputEditor | IInputEditor | Yes | Multi-line editor with undo/redo |
| TDiffView | IDiffView | Yes | Side-by-side diff viewer |
| TFileTree | IFileTree | Yes | File system tree browser |
| TKanban | IKanban | Yes | Multi-column card board |
| TMarkdown | IMarkdown | No | Rendered markdown text |
| TVirtualList | IVirtualList | Yes | Windowed list for large datasets |
| TCommandPalette | ICommandPalette | Yes | Fuzzy-search command launcher |
| TNotificationCenter | INotificationCenter | Yes | Notification panel |
| TToastManager | IToastManager | No | Timed toast messages |
| TCheckbox | ICheckbox | No | Toggle checkbox |
| TRadioGroup | IRadioGroup | No | Single-selection radio group |

## Supporting Types And Utilities

| Type | Kind | Description |
|------|------|-------------|
| TWidgetRenderFn | reference | Custom render callback used by `TWidgetAdapter` |
| TWidgetAdapter | class | Wraps a non-nil `TWidgetRenderFn` as `IWidget` |
| TScrollbarHit | enum | Hit-test result for scrollbar track/thumb interactions |
| TPanelGrid | record | Grid layout result returned by `IPanel.Layout` and `RenderGrid` |
| TSepHit | record | Separator hit-test result for panel grids |
| chat_theme | record | Color theme data (not a widget) |

## Usage Pattern

```pascal
var
  LBlock: IBlock;
  LList: IListWidget;
  LState: TListState;
begin
  LBlock := TBlock.Bordered('Items');
  LList := TListWidget.FromStrings(['Apple', 'Banana', 'Cherry'])
    .WithBlock(LBlock)
    .WithHighlightStyle(TStyle.Default.WithModifier([mbReversed]));

  LState := TListState.Empty;
  LState.Select(0);

  // In render loop:
  LList.RenderStateful(Area, Frame.Buffer, LState);
end;
```

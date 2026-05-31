unit nextpas.core.tui;

{**
 * @desc nextpas.core.tui 门面——消费方只需 uses nextpas.core.tui 即可获得
 *       全部公共 API。通过类型别名和 inline 转发聚合子模块。
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
  nextpas.core.tui.anim,
  nextpas.core.tui.animator,
  nextpas.core.tui.theme,
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
  nextpas.core.tui.widget.input;

{ 门面 re-export：FPC 不支持自动 re-export，消费方 uses 本单元后
  可直接访问上述所有子模块的公共类型和函数。 }

type
  { 基础类型 }
  TTuiRect = nextpas.core.tui.base.TRect;
  TTuiPosition = nextpas.core.tui.base.TPosition;
  TTuiSize = nextpas.core.tui.base.TSize;
  TTuiDirection = nextpas.core.tui.base.TDirection;

  { 样式 }
  TTuiColor = nextpas.core.tui.color.TColor;
  TTuiColorKind = nextpas.core.tui.color.TColorKind;
  TTuiModifier = nextpas.core.tui.modifier.TModifier;
  TTuiModifierBit = nextpas.core.tui.modifier.TModifierBit;
  TTuiStyle = nextpas.core.tui.style.TStyle;
  TTuiCell = nextpas.core.tui.cell.TCell;

  { Buffer }
  TTuiBuffer = nextpas.core.tui.buffer.TBuffer;
  TTuiDiffEntries = nextpas.core.tui.buffer.TDiffEntries;

  { 事件 }
  TTuiEvent = nextpas.core.tui.event.TEvent;
  TTuiEventKind = nextpas.core.tui.event.TEventKind;

  { Terminal }
  TTuiTerminal = nextpas.core.tui.terminal.TTerminal;
  TTuiFrame = nextpas.core.tui.terminal.TFrame;
  TTuiTerminalOptions = nextpas.core.tui.terminal.TTerminalOptions;

  { App }
  TTuiApp = nextpas.core.tui.app.TApp;

  { Widget 接口 }
  ITuiWidget = nextpas.core.tui.widget.intf.IWidget;
  ITuiBlock = nextpas.core.tui.widget.block.IBlock;

implementation

end.

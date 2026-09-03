program test_tui_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fs,
  nextpas.core.fs.util,
  nextpas.core.text.conv,
  nextpas.core.test;

const
  TUI_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.pas';
  TUI_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.pas';
  TUI_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.base.pas';
  TUI_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.base.pas';
  TUI_COLOR_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.color.pas';
  TUI_COLOR_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.color.pas';
  TUI_STYLE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.style.pas';
  TUI_STYLE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.style.pas';
  TUI_CELL_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.cell.pas';
  TUI_CELL_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.cell.pas';
  TUI_BUFFER_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.buffer.pas';
  TUI_BUFFER_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.buffer.pas';
  TUI_EVENT_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.event.pas';
  TUI_EVENT_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.event.pas';
  TUI_WIDGET_INTF_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.widget.intf.pas';
  TUI_WIDGET_INTF_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.widget.intf.pas';
  TUI_WIDGET_BLOCK_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.tui.widget.block.pas';
  TUI_WIDGET_BLOCK_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.tui.widget.block.pas';

var
  T: TTestSuite;

function ReadSourceFile(const APath: string): string;
begin
  Result := LowerCase(FsReadFileText(APath));
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function SourceExists(const APathFromTest, APathFromRoot: string): Boolean;
begin
  Result := FileExists(APathFromTest) or FileExists(APathFromRoot);
end;

procedure CheckTokenPresent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckTokenAbsent(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckNoImplementationLeaks(const ASource, ALabel: string);
begin
  CheckTokenAbsent(ASource, 'function tbuffer.create', ALabel + ' must not implement TBuffer.Create');
  CheckTokenAbsent(ASource, 'procedure tbuffer.render', ALabel + ' must not implement TBuffer.Render');
  CheckTokenAbsent(ASource, 'function tcolor.', ALabel + ' must not implement TColor methods');
  CheckTokenAbsent(ASource, 'function tstyle.', ALabel + ' must not implement TStyle methods');
  CheckTokenAbsent(ASource, 'function tcell.', ALabel + ' must not implement TCell methods');
  CheckTokenAbsent(ASource, 'procedure tterminal.', ALabel + ' must not implement TTerminal methods');
end;

procedure TestTuiFacadeIsThin;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LTuiSource, 'unit nextpas.core.tui;',
    'TUI facade must be the top-level facade unit');

  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.base',
    'TUI facade must re-export tui.base');
  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.color',
    'TUI facade must re-export tui.color');
  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.style',
    'TUI facade must re-export tui.style');
  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.cell',
    'TUI facade must re-export tui.cell');
  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.buffer',
    'TUI facade must re-export tui.buffer');
  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.event',
    'TUI facade must re-export tui.event');
  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.widget.intf',
    'TUI facade must re-export tui.widget.intf');
  CheckTokenPresent(LTuiSource, 'nextpas.core.tui.widget.block',
    'TUI facade must re-export tui.widget.block');

  CheckTokenPresent(LTuiSource, 'trect = nextpas.core.tui.base.trect',
    'TUI facade must re-export TRect');
  CheckTokenPresent(LTuiSource, 'tposition = nextpas.core.tui.base.tposition',
    'TUI facade must re-export TPosition');
  CheckTokenPresent(LTuiSource, 'tsize = nextpas.core.tui.base.tsize',
    'TUI facade must re-export TSize');
  CheckTokenPresent(LTuiSource, 'tcolor = nextpas.core.tui.color.tcolor',
    'TUI facade must re-export TColor');
  CheckTokenPresent(LTuiSource, 'tstyle = nextpas.core.tui.style.tstyle',
    'TUI facade must re-export TStyle');
  CheckTokenPresent(LTuiSource, 'tcell = nextpas.core.tui.cell.tcell',
    'TUI facade must re-export TCell');
  CheckTokenPresent(LTuiSource, 'tbuffer = nextpas.core.tui.buffer.tbuffer',
    'TUI facade must re-export TBuffer');
  CheckTokenPresent(LTuiSource, 'tevent = nextpas.core.tui.event.tevent',
    'TUI facade must re-export TEvent');
  CheckTokenPresent(LTuiSource, 'teventkind = nextpas.core.tui.event.teventkind',
    'TUI facade must re-export TEventKind');
  CheckTokenPresent(LTuiSource, 'iwidget = nextpas.core.tui.widget.intf.iwidget',
    'TUI facade must re-export IWidget');
  CheckTokenPresent(LTuiSource, 'iblock = nextpas.core.tui.widget.block.iblock',
    'TUI facade must re-export IBlock');
  CheckTokenPresent(LTuiSource, 'tblock = nextpas.core.tui.widget.block.tblock',
    'TUI facade must re-export TBlock');

  CheckTokenAbsent(LTuiSource, 'function positionmake',
    'TUI facade must NOT forward PositionMake (slim: use tui.base)');
  CheckTokenAbsent(LTuiSource, 'function sizemake',
    'TUI facade must NOT forward SizeMake (slim: use tui.base)');
  CheckTokenAbsent(LTuiSource, 'function rectequals',
    'TUI facade must NOT pile RectEquals (use tui.base)');
  CheckTokenAbsent(LTuiSource, 'function colorequals',
    'TUI facade must NOT pile ColorEquals (use tui.color)');
  CheckTokenAbsent(LTuiSource, 'function styledefault',
    'TUI facade must NOT pile StyleDefault (use tui.style)');
  CheckTokenAbsent(LTuiSource, 'function bordersetplain',
    'TUI facade must NOT pile BorderSetPlain (use tui.borders)');
  CheckTokenAbsent(LTuiSource, 'function terminalisansies',
    'TUI facade must NOT pile Terminal helpers (use tui.terminal)');
  CheckTokenAbsent(LTuiSource, 'nextpas.core.tui.terminal',
    'TUI facade must NOT uses tui.terminal (on-demand subfacade)');

  CheckTokenPresent(LTuiSource, 'tui_black: tcolor',
    'TUI facade must export TUI_BLACK color constant');
  CheckTokenPresent(LTuiSource, 'tui_red: tcolor',
    'TUI facade must export TUI_RED color constant');
  CheckTokenPresent(LTuiSource, 'tui_green: tcolor',
    'TUI facade must export TUI_GREEN color constant');
  CheckTokenPresent(LTuiSource, 'tui_blue: tcolor',
    'TUI facade must export TUI_BLUE color constant');
  CheckTokenPresent(LTuiSource, 'tui_white: tcolor',
    'TUI facade must export TUI_WHITE color constant');

  CheckTokenPresent(LTuiSource, 'evnone = nextpas.core.tui.event.evnone',
    'TUI facade must re-export evNone event constant');
  CheckTokenPresent(LTuiSource, 'evkey = nextpas.core.tui.event.evkey',
    'TUI facade must re-export evKey event constant');
  CheckTokenPresent(LTuiSource, 'evmouse = nextpas.core.tui.event.evmouse',
    'TUI facade must re-export evMouse event constant');
  CheckTokenPresent(LTuiSource, 'evresize = nextpas.core.tui.event.evresize',
    'TUI facade must re-export evResize event constant');
  CheckTokenPresent(LTuiSource, 'kcchar = nextpas.core.tui.event.kcchar',
    'TUI facade must re-export kcChar key constant');
  CheckTokenPresent(LTuiSource, 'kcEnter = nextpas.core.tui.event.kcEnter',
    'TUI facade must re-export kcEnter key constant');
  CheckTokenPresent(LTuiSource, 'kcEsc = nextpas.core.tui.event.kcEsc',
    'TUI facade must re-export kcEsc key constant');
  CheckTokenPresent(LTuiSource, 'kcTab = nextpas.core.tui.event.kcTab',
    'TUI facade must re-export kcTab key constant');

  CheckTokenAbsent(LTuiSource, 'function tcolor.create',
    'TUI facade must not implement TColor.Create');
  CheckTokenAbsent(LTuiSource, 'procedure tbuffer.render',
    'TUI facade must not implement TBuffer.Render');
  CheckTokenAbsent(LTuiSource, 'procedure tterminal.run',
    'TUI facade must not implement TTerminal.Run');
  CheckTokenAbsent(LTuiSource, 'function tevent.key',
    'TUI facade must not implement TEvent.Key');
  CheckTokenAbsent(LTuiSource, 'procedure tblock.render',
    'TUI facade must not implement TBlock.Render');
  CheckNoImplementationLeaks(LTuiSource, 'TUI facade');
end;

procedure TestTuiBaseStaysPure;
var
  LBaseSource: string;
begin
  LBaseSource := ReadSourceFile(ResolveSourcePath(TUI_BASE_SOURCE_PATH_FROM_TEST, TUI_BASE_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LBaseSource, 'tdirection = (',
    'tui.base must own TDirection enum');

  CheckTokenPresent(LBaseSource, 'function positionmake',
    'tui.base must own PositionMake');
  CheckTokenPresent(LBaseSource, 'function sizemake',
    'tui.base must own SizeMake');
  CheckTokenPresent(LBaseSource, 'function marginmake',
    'tui.base must own MarginMake');
  CheckTokenPresent(LBaseSource, 'function rectequals',
    'tui.base must own RectEquals');

  CheckTokenAbsent(LBaseSource, 'tcolor =',
    'tui.base must not own TColor');
  CheckTokenAbsent(LBaseSource, 'tstyle =',
    'tui.base must not own TStyle');
  CheckTokenAbsent(LBaseSource, 'tcell =',
    'tui.base must not own TCell');
  CheckTokenAbsent(LBaseSource, 'tevent =',
    'tui.base must not own TEvent');
  CheckTokenAbsent(LBaseSource, 'iwidget =',
    'tui.base must not own IWidget');
end;

procedure TestTuiColorStaysPure;
var
  LColorSource: string;
begin
  LColorSource := ReadSourceFile(ResolveSourcePath(TUI_COLOR_SOURCE_PATH_FROM_TEST, TUI_COLOR_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LColorSource, 'tcolorkind = (',
    'tui.color must own TColorKind enum');
  CheckTokenPresent(LColorSource, 'function unsetcolor',
    'tui.color must own UnsetColor');
  CheckTokenPresent(LColorSource, 'function resetcolor',
    'tui.color must own ResetColor');
  CheckTokenPresent(LColorSource, 'function indexedcolor',
    'tui.color must own IndexedColor');
  CheckTokenPresent(LColorSource, 'function rgbcolor',
    'tui.color must own RgbColor');
  CheckTokenPresent(LColorSource, 'function colorequals',
    'tui.color must own ColorEquals');
  CheckTokenPresent(LColorSource, 'function colorisset',
    'tui.color must own ColorIsSet');

  CheckTokenAbsent(LColorSource, 'trect =',
    'tui.color must not own TRect');
  CheckTokenAbsent(LColorSource, 'tstyle =',
    'tui.color must not own TStyle');
  CheckTokenAbsent(LColorSource, 'tcell =',
    'tui.color must not own TCell');
end;

procedure TestTuiWidgetIntfStaysPure;
var
  LIntfSource: string;
begin
  LIntfSource := ReadSourceFile(ResolveSourcePath(TUI_WIDGET_INTF_SOURCE_PATH_FROM_TEST, TUI_WIDGET_INTF_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LIntfSource, 'iwidget = interface',
    'tui.widget.intf must own IWidget interface');
  CheckTokenPresent(LIntfSource, 'procedure render',
    'IWidget must declare Render method');
  CheckTokenPresent(LIntfSource, 'twidgetrenderfn = reference to procedure',
    'tui.widget.intf must own TWidgetRenderFn type');
  CheckTokenPresent(LIntfSource, 'twidgetadapter = class',
    'tui.widget.intf must own TWidgetAdapter class');

  CheckTokenAbsent(LIntfSource, 'tcolor =',
    'tui.widget.intf must not own TColor');
  CheckTokenAbsent(LIntfSource, 'tstyle =',
    'tui.widget.intf must not own TStyle');
  CheckTokenAbsent(LIntfSource, 'tbuffer =',
    'tui.widget.intf must not own TBuffer');
end;

procedure TestTuiWidgetBlockStaysPure;
var
  LBlockSource: string;
begin
  LBlockSource := ReadSourceFile(ResolveSourcePath(TUI_WIDGET_BLOCK_SOURCE_PATH_FROM_TEST, TUI_WIDGET_BLOCK_SOURCE_PATH_FROM_ROOT));

  CheckTokenPresent(LBlockSource, 'iblock = interface',
    'tui.widget.block must own IBlock interface');
  CheckTokenPresent(LBlockSource, 'tblock = class',
    'tui.widget.block must own TBlock class');
  CheckTokenPresent(LBlockSource, 'function new',
    'TBlock must have New constructor');
  CheckTokenPresent(LBlockSource, 'function withborderset',
    'TBlock must have WithBorderSet method');
  CheckTokenPresent(LBlockSource, 'function withborderstyle',
    'TBlock must have WithBorderStyle method');
  CheckTokenPresent(LBlockSource, 'function withtitle',
    'TBlock must have WithTitle method');
  CheckTokenPresent(LBlockSource, 'procedure render',
    'TBlock must implement Render');

  CheckTokenAbsent(LBlockSource, 'tcolor =',
    'tui.widget.block must not own TColor');
  CheckTokenAbsent(LBlockSource, 'tevent =',
    'tui.widget.block must not own TEvent');
end;

procedure TestTuiFacadeForwardsCorrectly;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));

  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.color.unsetcolor',
    'TUI facade must NOT forward UnsetColor (slim: use tui.color)');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.color.resetcolor',
    'TUI facade must NOT forward ResetColor');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.color.indexedcolor',
    'TUI facade must NOT forward IndexedColor');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.color.rgbcolor',
    'TUI facade must NOT forward RgbColor');

  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.style.styledefault',
    'TUI facade must NOT forward StyleDefault (use tui.style)');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.style.stylefg(',
    'TUI facade must NOT forward StyleFg');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.style.stylebg(',
    'TUI facade must NOT forward StyleBg');

  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.borders.bordersetplain',
    'TUI facade must NOT forward BorderSetPlain (use tui.borders)');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.borders.bordersetrounded',
    'TUI facade must NOT forward BorderSetRounded');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.borders.bordersetdouble',
    'TUI facade must NOT forward BorderSetDouble');

  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.event.noneevent',
    'TUI facade must NOT forward NoneEvent (use tui.event)');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.event.keycharevent',
    'TUI facade must NOT forward KeyCharEvent');
end;


procedure TestTuiFacadeForwardsFocusEvent;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.event.focusevent',
    'TUI facade must NOT forward FocusEvent (slim)');
end;

procedure TestTuiFacadeForwardsIsFocus;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.event.isfocus',
    'TUI facade must NOT forward IsFocus (slim)');
end;

procedure TestTuiFacadeForwardsIsFocusInOut;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.event.isfocusin',
    'TUI facade must NOT forward IsFocusIn (slim)');
  CheckTokenAbsent(LTuiSource, 'result := nextpas.core.tui.event.isfocusout',
    'TUI facade must NOT forward IsFocusOut (slim)');
end;

procedure TestTuiFacadeExportsEvFocus;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));
  CheckTokenPresent(LTuiSource, 'evfocus = nextpas.core.tui.event.evfocus',
    'TUI facade must re-export evFocus');
end;

procedure TestTuiFacadeExportsFocusEventKind;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));
  CheckTokenPresent(LTuiSource, 'tfocuseventkind = nextpas.core.tui.event.tfocuseventkind',
    'TUI facade must re-export TFocusEventKind');
  CheckTokenPresent(LTuiSource, 'tfocusevent = nextpas.core.tui.event.tfocusevent',
    'TUI facade must re-export TFocusEvent');
end;

procedure TestTuiFacadeExportsFkInOut;
var
  LTuiSource: string;
begin
  LTuiSource := ReadSourceFile(ResolveSourcePath(TUI_SOURCE_PATH_FROM_TEST, TUI_SOURCE_PATH_FROM_ROOT));
  CheckTokenPresent(LTuiSource, 'fkin = nextpas.core.tui.event.fkin',
    'TUI facade must re-export fkIn');
  CheckTokenPresent(LTuiSource, 'fkout = nextpas.core.tui.event.fkout',
    'TUI facade must re-export fkOut');
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.facade_surface');
  T.Test('TUI facade is thin', @TestTuiFacadeIsThin);
  T.Test('tui.base stays pure', @TestTuiBaseStaysPure);
  T.Test('tui.color stays pure', @TestTuiColorStaysPure);
  T.Test('tui.widget.intf stays pure', @TestTuiWidgetIntfStaysPure);
  T.Test('tui.widget.block stays pure', @TestTuiWidgetBlockStaysPure);
  T.Test('TUI facade forwards correctly', @TestTuiFacadeForwardsCorrectly);
    T.Test('TUI facade forwards FocusEvent', @TestTuiFacadeForwardsFocusEvent);
  T.Test('TUI facade forwards IsFocus', @TestTuiFacadeForwardsIsFocus);
  T.Test('TUI facade forwards IsFocusIn/Out', @TestTuiFacadeForwardsIsFocusInOut);
  T.Test('TUI facade exports evFocus', @TestTuiFacadeExportsEvFocus);
  T.Test('TUI facade exports FocusEvent types', @TestTuiFacadeExportsFocusEventKind);
  T.Test('TUI facade exports fkIn/fkOut', @TestTuiFacadeExportsFkInOut);
if not T.Run then Halt(1);
end.

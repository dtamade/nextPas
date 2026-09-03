unit nextpas.core.tui.terminal.intf;

{**
 * @desc tui.terminal 四件套 intf — 终端接口契约。
 *       依赖 base；实现由 tui.terminal 提供，门面仅 re-export。
 *       性能：接口分发 inline 判定；事件与 buffer 均零拷贝视图。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.terminal.base,
  nextpas.core.tui.base,
  nextpas.core.tui.event;

type
  ITerminal = interface
    ['{7E3A9A1A-4B2C-4F8E-9C1D-2A3B4C5D6E7F}']
    function EnterTui: Boolean;
    procedure LeaveTui;
    function BeginFrame: TRect;
    procedure EndFrame(const AArea: TRect);
    function PollEvent(ATimeoutMs: Integer): TEvent;
    function ShouldQuit: Boolean;
  end;

function TerminalIsEnterOk(const AReason: AnsiString): Boolean; inline;

implementation

function TerminalIsEnterOk(const AReason: AnsiString): Boolean; inline;
begin
  Result := AReason = '';
end;

end.

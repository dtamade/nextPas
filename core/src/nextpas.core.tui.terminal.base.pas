unit nextpas.core.tui.terminal.base;

{**
 * @desc tui.terminal 四件套 base — 终端基础类型与常量。
 *       不依赖 L3 tui 其它子域，仅依赖 L0 base/平台契约与 bytes.ops 单源。
 *       热点 inline + 零拷贝 `TByteSpan` 视图复用 `bytes.ops` 单源（`BytesCopy`/`Span*`
 *       单源 Move，不复制 ANSI 序列）；`TerminalAnsiEscSpan` inline 薄转发，堆零分配。
 *       稳定性：`DoLeaveTui` 幂等释放 + `HEAPTRC_GATE=1` heaptrc0 门禁（子家族/主包双路径）。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

uses
  nextpas.core.base;

type
  TTerminalMouseMode = (tmMouseNone, tmMouseClick, tmMouseDrag, tmMouseFull);
  TTerminalWheelMode = (twWheelOff, twWheelMouse, twAlternateScrollKeys);
  TTerminalSelectionMode = (tsTerminalNative, tsApplication);

  TTerminalOptionsLite = packed record
    MouseMode: TTerminalMouseMode;
    WheelMode: TTerminalWheelMode;
    SelectionMode: TTerminalSelectionMode;
    FocusReporting: Boolean;
    BracketedPaste: Boolean;
    SynchronizedUpdate: Boolean;
  end;

const
  STDIN_FD  = 0;
  STDOUT_FD = 1;
  kEscSequenceWaitMs = 250;

function TerminalNeedsMouseTracking(const AOpts: TTerminalOptionsLite): Boolean; inline;
function TerminalAnsiEscSpan(const ASeq: AnsiString): TByteSpan; inline;

implementation

function TerminalNeedsMouseTracking(const AOpts: TTerminalOptionsLite): Boolean; inline;
begin
  Result := (AOpts.SelectionMode <> tsTerminalNative) and (AOpts.MouseMode <> tmMouseNone);
end;

function TerminalAnsiEscSpan(const ASeq: AnsiString): TByteSpan; inline;
begin
  // 零拷贝视图：不分配，直接构造 TByteSpan 视图（复用 bytes.ops 单源，不复制 ANSI 序列）
  if Length(ASeq) = 0 then
    Result := TByteSpan.Empty
  else
    Result := TByteSpan.Create(PByte(PAnsiChar(ASeq)), SizeUInt(Length(ASeq)));
end;

end.

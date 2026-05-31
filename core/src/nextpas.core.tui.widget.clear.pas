unit nextpas.core.tui.widget.clear;

{**
 * @desc TClearWidget — 最简 widget，把区域内每个 cell 重置为 CELL_EMPTY。
 *
 * 用于弹窗/覆盖层在绘制前擦除底层内容。无配置、无状态。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf;

type
  TClearWidget = class(TInterfacedObject, IWidget)
  public
    class function New: IWidget; static;
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

class function TClearWidget.New: IWidget;
begin
  Result := TClearWidget.Create;
end;

procedure TClearWidget.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LClip: TRect;
  LX, LY: Integer;
  LCP: PCell;
begin
  LClip := ABuffer.Area.Intersection(AArea);
  if LClip.IsEmpty then Exit;
  for LY := LClip.Top to LClip.Bottom - 1 do
    for LX := LClip.Left to LClip.Right - 1 do
    begin
      LCP := ABuffer.CellAt(LX, LY);
      if LCP <> nil then
        LCP^ := CELL_EMPTY;
    end;
end;

end.

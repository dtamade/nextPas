unit nextpas.core.tui.widget.split_pane;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event;

type
  TSplitDirection = (sdHorizontal, sdVertical);

  TSplitPaneState = record
    Ratio: Double;
    Dragging: Boolean;

    class function Default: TSplitPaneState; static;
  end;

  TSplitPane = record
    Direction: TSplitDirection;
    MinSize1: Integer;
    MinSize2: Integer;
    DividerStyle: TStyle;
    DividerChar: AnsiString;
    ShowDivider: Boolean;

    class function Horizontal: TSplitPane; static;
    class function Vertical: TSplitPane; static;
    function WithMinSize1(N: Integer): TSplitPane;
    function WithMinSize2(N: Integer): TSplitPane;
    function WithDividerStyle(const S: TStyle): TSplitPane;
    function WithDividerChar(const C: AnsiString): TSplitPane;

    function Split(const Area: TRect; const State: TSplitPaneState;
      out Pane1, Pane2, Divider: TRect): Boolean;
    procedure RenderDivider(const Divider: TRect; ABuf: TBuffer);
    function HandleMouse(const Area: TRect; const M: TMouseEvent;
      var State: TSplitPaneState): Boolean;
  end;

implementation

{ TSplitPaneState }

class function TSplitPaneState.Default: TSplitPaneState;
begin
  Result.Ratio := 0.5;
  Result.Dragging := False;
end;

{ TSplitPane }

class function TSplitPane.Horizontal: TSplitPane;
begin
  Result.Direction := sdHorizontal;
  Result.MinSize1 := 3;
  Result.MinSize2 := 3;
  Result.DividerStyle := TStyle.Default;
  Result.DividerChar := #$E2#$94#$82;  // U+2502 │
  Result.ShowDivider := True;
end;

class function TSplitPane.Vertical: TSplitPane;
begin
  Result.Direction := sdVertical;
  Result.MinSize1 := 1;
  Result.MinSize2 := 1;
  Result.DividerStyle := TStyle.Default;
  Result.DividerChar := #$E2#$94#$80;  // U+2500 ─
  Result.ShowDivider := True;
end;

function TSplitPane.WithMinSize1(N: Integer): TSplitPane;
begin
  Result := Self;
  Result.MinSize1 := N;
end;

function TSplitPane.WithMinSize2(N: Integer): TSplitPane;
begin
  Result := Self;
  Result.MinSize2 := N;
end;

function TSplitPane.WithDividerStyle(const S: TStyle): TSplitPane;
begin
  Result := Self;
  Result.DividerStyle := S;
end;

function TSplitPane.WithDividerChar(const C: AnsiString): TSplitPane;
begin
  Result := Self;
  Result.DividerChar := C;
end;

function TSplitPane.Split(const Area: TRect; const State: TSplitPaneState;
  out Pane1, Pane2, Divider: TRect): Boolean;
var
  Total, DivSize, Size1, Size2: Integer;
  R: Double;
begin
  Result := False;
  Pane1 := TRect.Make(0, 0, 0, 0);
  Pane2 := TRect.Make(0, 0, 0, 0);
  Divider := TRect.Make(0, 0, 0, 0);

  if Area.IsEmpty then Exit;

  DivSize := 0;
  if ShowDivider then DivSize := 1;

  if Direction = sdHorizontal then
    Total := Area.Width
  else
    Total := Area.Height;

  if Total < MinSize1 + MinSize2 + DivSize then Exit;

  R := State.Ratio;
  if R < 0.0 then R := 0.0;
  if R > 1.0 then R := 1.0;

  Size1 := Round((Total - DivSize) * R);
  if Size1 < MinSize1 then Size1 := MinSize1;
  Size2 := Total - DivSize - Size1;
  if Size2 < MinSize2 then
  begin
    Size2 := MinSize2;
    Size1 := Total - DivSize - Size2;
    if Size1 < MinSize1 then Size1 := MinSize1;
  end;

  if Direction = sdHorizontal then
  begin
    Pane1 := TRect.Make(Area.X, Area.Y, Size1, Area.Height);
    Divider := TRect.Make(Area.X + Size1, Area.Y, DivSize, Area.Height);
    Pane2 := TRect.Make(Area.X + Size1 + DivSize, Area.Y, Size2, Area.Height);
  end
  else
  begin
    Pane1 := TRect.Make(Area.X, Area.Y, Area.Width, Size1);
    Divider := TRect.Make(Area.X, Area.Y + Size1, Area.Width, DivSize);
    Pane2 := TRect.Make(Area.X, Area.Y + Size1 + DivSize, Area.Width, Size2);
  end;
  Result := True;
end;

procedure TSplitPane.RenderDivider(const Divider: TRect; ABuf: TBuffer);
var I: Integer;
begin
  if Divider.IsEmpty then Exit;
  if not ShowDivider then Exit;

  if Direction = sdHorizontal then
  begin
    for I := 0 to Divider.Height - 1 do
      ABuf.SetStringN(Divider.X, Divider.Y + I, DividerChar, 1, DividerStyle);
  end
  else
  begin
    for I := 0 to Divider.Width - 1 do
      ABuf.SetStringN(Divider.X + I, Divider.Y, DividerChar, 1, DividerStyle);
  end;
end;

function TSplitPane.HandleMouse(const Area: TRect; const M: TMouseEvent;
  var State: TSplitPaneState): Boolean;
var
  Total, Pos: Integer;
begin
  Result := False;

  case M.Kind of
    mkDown:
    begin
      State.Dragging := True;
      Result := True;
    end;
    mkUp:
    begin
      State.Dragging := False;
      Result := True;
    end;
    mkMoved, mkDrag:
    begin
      if not State.Dragging then Exit;
      if Direction = sdHorizontal then
      begin
        Total := Area.Width;
        Pos := Integer(M.X) - Area.X;
      end
      else
      begin
        Total := Area.Height;
        Pos := Integer(M.Y) - Area.Y;
      end;
      if Total <= 0 then Exit;
      State.Ratio := Pos / Total;
      if State.Ratio < 0.0 then State.Ratio := 0.0;
      if State.Ratio > 1.0 then State.Ratio := 1.0;
      Result := True;
    end;
  else end;
end;

end.

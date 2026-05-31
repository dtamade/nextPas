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
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.event;

type
  TSplitDirection = (sdHorizontal, sdVertical);

  TSplitPaneState = record
    Ratio: Double;
    Dragging: Boolean;

    class function Default: TSplitPaneState; static;
  end;

  ISplitPane = interface(IWidget)
    ['{F4A5B6C7-8D9E-0F1A-2B3C-4D5E6F7A8B9C}']
    function WithMinSize1(N: Integer): ISplitPane;
    function WithMinSize2(N: Integer): ISplitPane;
    function WithDividerStyle(const S: TStyle): ISplitPane;
    function WithDividerChar(const C: AnsiString): ISplitPane;
    function Split(const Area: TRect; const State: TSplitPaneState;
      out Pane1, Pane2, Divider: TRect): Boolean;
    procedure RenderDivider(const Divider: TRect; ABuffer: TBuffer);
    function HandleMouse(const Area: TRect; const M: TMouseEvent;
      var State: TSplitPaneState): Boolean;
  end;

  TSplitPane = class(TInterfacedObject, IWidget, ISplitPane)
  private
    FDirection: TSplitDirection;
    FMinSize1: Integer;
    FMinSize2: Integer;
    FDividerStyle: TStyle;
    FDividerChar: AnsiString;
    FShowDivider: Boolean;
  public
    class function Horizontal: ISplitPane; static;
    class function Vertical: ISplitPane; static;

    { ISplitPane builder }
    function WithMinSize1(N: Integer): ISplitPane;
    function WithMinSize2(N: Integer): ISplitPane;
    function WithDividerStyle(const S: TStyle): ISplitPane;
    function WithDividerChar(const C: AnsiString): ISplitPane;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    { ISplitPane }
    function Split(const Area: TRect; const State: TSplitPaneState;
      out Pane1, Pane2, Divider: TRect): Boolean;
    procedure RenderDivider(const Divider: TRect; ABuffer: TBuffer);
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

class function TSplitPane.Horizontal: ISplitPane;
var
  LObj: TSplitPane;
begin
  LObj := TSplitPane.Create;
  LObj.FDirection := sdHorizontal;
  LObj.FMinSize1 := 3;
  LObj.FMinSize2 := 3;
  LObj.FDividerStyle := TStyle.Default;
  LObj.FDividerChar := #$E2#$94#$82;  // U+2502
  LObj.FShowDivider := True;
  Result := LObj;
end;

class function TSplitPane.Vertical: ISplitPane;
var
  LObj: TSplitPane;
begin
  LObj := TSplitPane.Create;
  LObj.FDirection := sdVertical;
  LObj.FMinSize1 := 1;
  LObj.FMinSize2 := 1;
  LObj.FDividerStyle := TStyle.Default;
  LObj.FDividerChar := #$E2#$94#$80;  // U+2500
  LObj.FShowDivider := True;
  Result := LObj;
end;

function TSplitPane.WithMinSize1(N: Integer): ISplitPane;
begin
  FMinSize1 := N;
  Result := Self;
end;

function TSplitPane.WithMinSize2(N: Integer): ISplitPane;
begin
  FMinSize2 := N;
  Result := Self;
end;

function TSplitPane.WithDividerStyle(const S: TStyle): ISplitPane;
begin
  FDividerStyle := S;
  Result := Self;
end;

function TSplitPane.WithDividerChar(const C: AnsiString): ISplitPane;
begin
  FDividerChar := C;
  Result := Self;
end;

procedure TSplitPane.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  { SplitPane is a layout helper; Render is a no-op. Use Split + RenderDivider. }
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
  if FShowDivider then DivSize := 1;

  if FDirection = sdHorizontal then
    Total := Area.Width
  else
    Total := Area.Height;

  if Total < FMinSize1 + FMinSize2 + DivSize then Exit;

  R := State.Ratio;
  if R < 0.0 then R := 0.0;
  if R > 1.0 then R := 1.0;

  Size1 := Round((Total - DivSize) * R);
  if Size1 < FMinSize1 then Size1 := FMinSize1;
  Size2 := Total - DivSize - Size1;
  if Size2 < FMinSize2 then
  begin
    Size2 := FMinSize2;
    Size1 := Total - DivSize - Size2;
    if Size1 < FMinSize1 then Size1 := FMinSize1;
  end;

  if FDirection = sdHorizontal then
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

procedure TSplitPane.RenderDivider(const Divider: TRect; ABuffer: TBuffer);
var I: Integer;
begin
  if Divider.IsEmpty then Exit;
  if not FShowDivider then Exit;

  if FDirection = sdHorizontal then
  begin
    for I := 0 to Divider.Height - 1 do
      ABuffer.SetStringN(Divider.X, Divider.Y + I, FDividerChar, 1, FDividerStyle);
  end
  else
  begin
    for I := 0 to Divider.Width - 1 do
      ABuffer.SetStringN(Divider.X + I, Divider.Y, FDividerChar, 1, FDividerStyle);
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
      if FDirection = sdHorizontal then
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

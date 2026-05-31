unit nextpas.core.tui.widget.scrollview;

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
  nextpas.core.tui.widget.block;

type
  TScrollViewState = record
    OffsetY: Integer;
    ContentHeight: Integer;

    class function Empty: TScrollViewState; static;
    procedure ScrollUp(N: Integer = 1);
    procedure ScrollDown(N: Integer = 1);
    procedure PageUp(ViewHeight: Integer);
    procedure PageDown(ViewHeight: Integer);
    procedure ScrollToTop;
    procedure ScrollToBottom(ViewHeight: Integer);
    procedure EnsureVisible(Row, ViewHeight: Integer);
  end;

  IScrollView = interface(IWidget)
    ['{E3F4A5B6-7C8D-9E0F-1A2B-3C4D5E6F7A8B}']
    function WithStyle(const S: TStyle): IScrollView;
    function WithScrollbarStyle(const S: TStyle): IScrollView;
    function WithShowScrollbar(V: Boolean): IScrollView;
    function WithBlock(ABlock: IBlock): IScrollView;
    function ContentArea(const Area: TRect): TRect;
    procedure RenderStateful(const Area: TRect; ABuffer: TBuffer; var State: TScrollViewState);
  end;

  TScrollView = class(TInterfacedObject, IWidget, IScrollView)
  private
    FStyle: TStyle;
    FScrollbarStyle: TStyle;
    FShowScrollbar: Boolean;
    FBlock: IBlock;
  public
    class function New: IScrollView; static;

    { IScrollView builder }
    function WithStyle(const S: TStyle): IScrollView;
    function WithScrollbarStyle(const S: TStyle): IScrollView;
    function WithShowScrollbar(V: Boolean): IScrollView;
    function WithBlock(ABlock: IBlock): IScrollView;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    { IScrollView }
    function ContentArea(const Area: TRect): TRect;
    procedure RenderStateful(const Area: TRect; ABuffer: TBuffer; var State: TScrollViewState);
  end;

implementation

uses
  SysUtils;

{ TScrollViewState }

class function TScrollViewState.Empty: TScrollViewState;
begin
  Result.OffsetY := 0;
  Result.ContentHeight := 0;
end;

procedure TScrollViewState.ScrollUp(N: Integer);
begin
  Dec(OffsetY, N);
  if OffsetY < 0 then OffsetY := 0;
end;

procedure TScrollViewState.ScrollDown(N: Integer);
begin
  Inc(OffsetY, N);
end;

procedure TScrollViewState.PageUp(ViewHeight: Integer);
begin
  ScrollUp(ViewHeight);
end;

procedure TScrollViewState.PageDown(ViewHeight: Integer);
begin
  ScrollDown(ViewHeight);
end;

procedure TScrollViewState.ScrollToTop;
begin
  OffsetY := 0;
end;

procedure TScrollViewState.ScrollToBottom(ViewHeight: Integer);
begin
  if ContentHeight > ViewHeight then
    OffsetY := ContentHeight - ViewHeight
  else
    OffsetY := 0;
end;

procedure TScrollViewState.EnsureVisible(Row, ViewHeight: Integer);
begin
  if Row < OffsetY then
    OffsetY := Row;
  if Row >= OffsetY + ViewHeight then
    OffsetY := Row - ViewHeight + 1;
  if OffsetY < 0 then OffsetY := 0;
end;

{ TScrollView }

class function TScrollView.New: IScrollView;
var
  LObj: TScrollView;
begin
  LObj := TScrollView.Create;
  LObj.FStyle := TStyle.Default;
  LObj.FScrollbarStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  LObj.FShowScrollbar := True;
  LObj.FBlock := nil;
  Result := LObj;
end;

function TScrollView.WithStyle(const S: TStyle): IScrollView;
begin
  FStyle := S;
  Result := Self;
end;

function TScrollView.WithScrollbarStyle(const S: TStyle): IScrollView;
begin
  FScrollbarStyle := S;
  Result := Self;
end;

function TScrollView.WithShowScrollbar(V: Boolean): IScrollView;
begin
  FShowScrollbar := V;
  Result := Self;
end;

function TScrollView.WithBlock(ABlock: IBlock): IScrollView;
begin
  FBlock := ABlock;
  Result := Self;
end;

procedure TScrollView.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  { ScrollView is stateful-only; Render without state is a no-op. }
end;

function TScrollView.ContentArea(const Area: TRect): TRect;
var Inner: TRect;
begin
  if FBlock <> nil then
    Inner := FBlock.Inner(Area)
  else
    Inner := Area;
  if FShowScrollbar and (Inner.Width > 1) then
    Result := TRect.Make(Inner.X, Inner.Y, Inner.Width - 1, Inner.Height)
  else
    Result := Inner;
end;

procedure TScrollView.RenderStateful(const Area: TRect; ABuffer: TBuffer; var State: TScrollViewState);
var
  Inner: TRect;
  ScrollCol, ViewH, ThumbPos, ThumbLen, MaxOffset, I: Integer;
begin
  if Area.IsEmpty then Exit;

  ABuffer.SetStyle(Area, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(Area, ABuffer);
    Inner := FBlock.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  ViewH := Inner.Height;

  // Clamp offset
  if State.ContentHeight <= ViewH then
    State.OffsetY := 0
  else
  begin
    MaxOffset := State.ContentHeight - ViewH;
    if State.OffsetY > MaxOffset then State.OffsetY := MaxOffset;
    if State.OffsetY < 0 then State.OffsetY := 0;
  end;

  // Render scrollbar
  if FShowScrollbar and (Inner.Width > 0) and (State.ContentHeight > ViewH) then
  begin
    ScrollCol := Inner.X + Inner.Width - 1;

    // Thumb size and position
    ThumbLen := (ViewH * ViewH) div State.ContentHeight;
    if ThumbLen < 1 then ThumbLen := 1;
    if State.ContentHeight > ViewH then
      ThumbPos := (State.OffsetY * (ViewH - ThumbLen)) div (State.ContentHeight - ViewH)
    else
      ThumbPos := 0;

    for I := 0 to ViewH - 1 do
    begin
      if (I >= ThumbPos) and (I < ThumbPos + ThumbLen) then
        ABuffer.SetStringN(ScrollCol, Inner.Y + I, #$E2#$96#$88, 1, FScrollbarStyle)
      else
        ABuffer.SetStringN(ScrollCol, Inner.Y + I, #$E2#$96#$91, 1, FScrollbarStyle);
    end;
  end;
end;

end.

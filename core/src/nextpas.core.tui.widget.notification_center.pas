unit nextpas.core.tui.widget.notification_center;

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
  nextpas.core.tui.widget.block,
  nextpas.core.tui.borders;

type
  TNotifLevel = (nlInfo, nlWarning, nlError, nlSuccess);

  TNotification = record
    Title: AnsiString;
    Body: AnsiString;
    Level: TNotifLevel;
    Read: Boolean;
    Timestamp: AnsiString;
    class function Make(const ATitle: AnsiString; ALevel: TNotifLevel): TNotification; static;
    function WithBody(const B: AnsiString): TNotification;
    function WithTimestamp(const T: AnsiString): TNotification;
  end;

  TNotificationCenterState = record
    Selected: Integer;
    ScrollY: Integer;
    Visible: Boolean;
  end;

  INotificationCenter = interface(IWidget)
    ['{E7F8A9B0-C1D2-3456-EFAB-789012345678}']
    procedure Push(const N: TNotification);
    procedure MarkRead(Index: Integer);
    procedure MarkAllRead;
    procedure Clear;
    function GetCount: Integer;
    function UnreadCount: Integer;
    function GetItem(I: Integer): TNotification;
    procedure RenderStateful(const AArea: TRect; ABuf: TBuffer;
      var AState: TNotificationCenterState);
    property Count: Integer read GetCount;
  end;

  TNotificationCenter = class(TInterfacedObject, IWidget, INotificationCenter)
  private
    FItems: array of TNotification;
    FCount: Integer;
    FStyle: TStyle;
    FSelectedStyle: TStyle;
    FUnreadStyle: TStyle;
    FWidth: Integer;
  public
    class function New: INotificationCenter; static;

    procedure Push(const N: TNotification);
    procedure MarkRead(Index: Integer);
    procedure MarkAllRead;
    procedure Clear;
    function GetCount: Integer; inline;
    function UnreadCount: Integer;
    function GetItem(I: Integer): TNotification;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
    { INotificationCenter }
    procedure RenderStateful(const AArea: TRect; ABuf: TBuffer;
      var AState: TNotificationCenterState);
  end;

implementation

{ TNotification }

class function TNotification.Make(const ATitle: AnsiString; ALevel: TNotifLevel): TNotification;
begin
  Result.Title := ATitle;
  Result.Body := '';
  Result.Level := ALevel;
  Result.Read := False;
  Result.Timestamp := '';
end;

function TNotification.WithBody(const B: AnsiString): TNotification;
begin Result := Self; Result.Body := B; end;

function TNotification.WithTimestamp(const T: AnsiString): TNotification;
begin Result := Self; Result.Timestamp := T; end;

{ TNotificationCenter }

class function TNotificationCenter.New: INotificationCenter;
var LSelf: TNotificationCenter;
begin
  LSelf := TNotificationCenter.Create;
  LSelf.FItems := nil;
  LSelf.FCount := 0;
  LSelf.FStyle := TStyle.Default;
  LSelf.FSelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  LSelf.FUnreadStyle := TStyle.Default.WithModifier([mbBold]);
  LSelf.FWidth := 40;
  Result := LSelf;
end;

procedure TNotificationCenter.Push(const N: TNotification);
begin
  Inc(FCount);
  SetLength(FItems, FCount);
  FItems[FCount - 1] := N;
end;

procedure TNotificationCenter.MarkRead(Index: Integer);
begin
  if (Index >= 0) and (Index < FCount) then
    FItems[Index].Read := True;
end;

procedure TNotificationCenter.MarkAllRead;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    FItems[I].Read := True;
end;

procedure TNotificationCenter.Clear;
begin
  FItems := nil;
  FCount := 0;
end;

function TNotificationCenter.GetCount: Integer;
begin
  Result := FCount;
end;

function TNotificationCenter.UnreadCount: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to FCount - 1 do
    if not FItems[I].Read then Inc(Result);
end;

function TNotificationCenter.GetItem(I: Integer): TNotification;
begin
  Result := FItems[I];
end;

procedure TNotificationCenter.Render(const AArea: TRect; ABuffer: TBuffer);
var LState: TNotificationCenterState;
begin
  LState.Selected := 0; LState.ScrollY := 0; LState.Visible := True;
  RenderStateful(AArea, ABuffer, LState);
end;

procedure TNotificationCenter.RenderStateful(const AArea: TRect; ABuf: TBuffer; var AState: TNotificationCenterState);
var
  PanelX, PanelW, PanelH, I, Y, Row, ViewH: Integer;
  PanelArea, Inner: TRect;
  LineSty: TStyle;
  LevelStr: AnsiChar;
  UnreadStr: string[8];
begin
  if not AState.Visible then Exit;
  if AArea.IsEmpty then Exit;

  PanelW := FWidth;
  if PanelW > AArea.Width then PanelW := AArea.Width;
  PanelH := AArea.Height;
  PanelX := AArea.X + AArea.Width - PanelW;

  PanelArea := TRect.Make(PanelX, AArea.Y, PanelW, PanelH);
  ABuf.SetStyle(PanelArea, FStyle);

  Str(UnreadCount, UnreadStr);
  TBlock.New.WithBorders(BORDERS_ALL)
    .WithTitle(' Notifications (' + UnreadStr + ') ')
    .WithBorderStyle(FStyle)
    .Render(PanelArea, ABuf);

  Inner := TRect.Make(PanelX + 1, AArea.Y + 1, PanelW - 2, PanelH - 2);
  ViewH := Inner.Height;

  if AState.ScrollY > FCount - ViewH then
    AState.ScrollY := FCount - ViewH;
  if AState.ScrollY < 0 then AState.ScrollY := 0;

  Y := Inner.Y;
  for I := 0 to ViewH - 1 do
  begin
    Row := AState.ScrollY + I;
    if Row >= FCount then Break;

    if Row = AState.Selected then
      LineSty := FSelectedStyle
    else if not FItems[Row].Read then
      LineSty := FUnreadStyle
    else
      LineSty := FStyle;

    case FItems[Row].Level of
      nlInfo: LevelStr := 'i';
      nlWarning: LevelStr := '!';
      nlError: LevelStr := 'x';
      nlSuccess: LevelStr := '+';
    end;

    ABuf.SetStringN(Inner.X, Y, '[', 1, LineSty);
    ABuf.SetStringN(Inner.X + 1, Y, LevelStr, 1, LineSty);
    ABuf.SetStringN(Inner.X + 2, Y, '] ', 2, LineSty);
    ABuf.SetStringN(Inner.X + 4, Y, FItems[Row].Title, Inner.Width - 4, LineSty);
    Inc(Y);
  end;
end;

end.

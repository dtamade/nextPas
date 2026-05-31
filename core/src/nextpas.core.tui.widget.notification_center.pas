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

  TNotificationCenter = class
  private
    FItems: array of TNotification;
    FCount: Integer;
    FStyle: TStyle;
    FSelectedStyle: TStyle;
    FUnreadStyle: TStyle;
    FWidth: Integer;
  public
    constructor Create;
    procedure Push(const N: TNotification);
    procedure MarkRead(Index: Integer);
    procedure MarkAllRead;
    procedure Clear;
    function Count: Integer; inline;
    function UnreadCount: Integer;
    function GetItem(I: Integer): TNotification;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TNotificationCenterState);
    property Style: TStyle read FStyle write FStyle;
    property SelectedStyle: TStyle read FSelectedStyle write FSelectedStyle;
    property UnreadStyle: TStyle read FUnreadStyle write FUnreadStyle;
    property Width: Integer read FWidth write FWidth;
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

constructor TNotificationCenter.Create;
begin
  inherited Create;
  FItems := nil;
  FCount := 0;
  FStyle := TStyle.Default;
  FSelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  FUnreadStyle := TStyle.Default.WithModifier([mbBold]);
  FWidth := 40;
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

function TNotificationCenter.Count: Integer;
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

procedure TNotificationCenter.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TNotificationCenterState);
var
  PanelX, PanelW, PanelH, I, Y, Row, ViewH: Integer;
  PanelArea, Inner: TRect;
  LineSty: TStyle;
  LevelStr: AnsiChar;
  UnreadStr: string[8];
begin
  if not State.Visible then Exit;
  if Area.IsEmpty then Exit;

  PanelW := FWidth;
  if PanelW > Area.Width then PanelW := Area.Width;
  PanelH := Area.Height;
  PanelX := Area.X + Area.Width - PanelW;

  PanelArea := TRect.Make(PanelX, Area.Y, PanelW, PanelH);
  ABuf.SetStyle(PanelArea, FStyle);

  Str(UnreadCount, UnreadStr);
  TBlock.New.WithBorders(BORDERS_ALL)
    .WithTitle(' Notifications (' + UnreadStr + ') ')
    .WithBorderStyle(FStyle)
    .Render(PanelArea, ABuf);

  Inner := TRect.Make(PanelX + 1, Area.Y + 1, PanelW - 2, PanelH - 2);
  ViewH := Inner.Height;

  if State.ScrollY > FCount - ViewH then
    State.ScrollY := FCount - ViewH;
  if State.ScrollY < 0 then State.ScrollY := 0;

  Y := Inner.Y;
  for I := 0 to ViewH - 1 do
  begin
    Row := State.ScrollY + I;
    if Row >= FCount then Break;

    if Row = State.Selected then
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

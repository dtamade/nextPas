unit nextpas.core.tui.widget.timeline;

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
  nextpas.core.tui.widget.intf;

type
  TTimelineEvent = record
    Time: AnsiString;
    Title: AnsiString;
    Description: AnsiString;
    Style: TStyle;
    class function Make(const ATime, ATitle: AnsiString): TTimelineEvent; static;
    function WithDescription(const D: AnsiString): TTimelineEvent;
    function WithStyle(const S: TStyle): TTimelineEvent;
  end;

  TTimeline = record
    Events: array of TTimelineEvent;
    Style: TStyle;
    LineStyle: TStyle;
    NodeChar: AnsiString;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const AEvents: array of TTimelineEvent): TTimeline; static;
    function WithStyle(const S: TStyle): TTimeline;
    function WithLineStyle(const S: TStyle): TTimeline;
    function WithNodeChar(const C: AnsiString): TTimeline;
    function WithBlock(const B: TBlock): TTimeline;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

uses
  SysUtils, nextpas.core.text.width, nextpas.core.text.utf8;

class function TTimelineEvent.Make(const ATime, ATitle: AnsiString): TTimelineEvent;
begin
  Result.Time := ATime;
  Result.Title := ATitle;
  Result.Description := '';
  Result.Style := TStyle.Default;
end;

function TTimelineEvent.WithDescription(const D: AnsiString): TTimelineEvent;
begin Result := Self; Result.Description := D; end;

function TTimelineEvent.WithStyle(const S: TStyle): TTimelineEvent;
begin Result := Self; Result.Style := S; end;

class function TTimeline.Create(const AEvents: array of TTimelineEvent): TTimeline;
var I: Integer;
begin
  SetLength(Result.Events, Length(AEvents));
  for I := 0 to High(AEvents) do
    Result.Events[I] := AEvents[I];
  Result.Style := TStyle.Default;
  Result.LineStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  Result.NodeChar := #$E2#$97#$8F; // ●
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TTimeline.WithStyle(const S: TStyle): TTimeline;
begin Result := Self; Result.Style := S; end;

function TTimeline.WithLineStyle(const S: TStyle): TTimeline;
begin Result := Self; Result.LineStyle := S; end;

function TTimeline.WithNodeChar(const C: AnsiString): TTimeline;
begin Result := Self; Result.NodeChar := C; end;

function TTimeline.WithBlock(const B: TBlock): TTimeline;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

procedure TTimeline.Render(const Area: TRect; ABuf: TBuffer);
var
  Inner: TRect;
  I, Y, TimeW, NodeX, TextX, TextW: Integer;
begin
  if Area.IsEmpty then Exit;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  // Layout: [time] [node] [title/desc]
  TimeW := 0;
  for I := 0 to High(Events) do
    if Integer(StringDisplayWidth(Events[I].Time)) > TimeW then
      TimeW := Integer(StringDisplayWidth(Events[I].Time));
  Inc(TimeW); // space

  NodeX := Inner.X + TimeW;
  TextX := NodeX + 2;
  TextW := Inner.Width - TimeW - 2;
  if TextW < 1 then TextW := 1;

  Y := Inner.Y;
  for I := 0 to High(Events) do
  begin
    if Y >= Inner.Y + Inner.Height then Break;

    // Time
    ABuf.SetStringN(Inner.X, Y, Events[I].Time, TimeW, LineStyle);

    // Node marker
    ABuf.SetStringN(NodeX, Y, NodeChar, 1, Events[I].Style);

    // Title
    ABuf.SetStringN(TextX, Y, Events[I].Title, TextW, Events[I].Style);
    Inc(Y);

    // Description (if present and space available)
    if (Events[I].Description <> '') and (Y < Inner.Y + Inner.Height) then
    begin
      // Connector line
      ABuf.SetStringN(NodeX, Y, #$E2#$94#$82, 1, LineStyle); // │
      ABuf.SetStringN(TextX, Y, Events[I].Description, TextW, Style);
      Inc(Y);
    end;

    // Connector to next
    if (I < High(Events)) and (Y < Inner.Y + Inner.Height) then
    begin
      ABuf.SetStringN(NodeX, Y, #$E2#$94#$82, 1, LineStyle); // │
      Inc(Y);
    end;
  end;
end;

end.

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

  ITimeline = interface(IWidget)
    ['{B4C5D6E7-F8A9-0123-BCDE-456789012345}']
    function WithStyle(const S: TStyle): ITimeline;
    function WithLineStyle(const S: TStyle): ITimeline;
    function WithNodeChar(const C: AnsiString): ITimeline;
    function WithBlock(ABlock: IBlock): ITimeline;
  end;

  TTimeline = class(TInterfacedObject, IWidget, ITimeline)
  private
    FEvents: array of TTimelineEvent;
    FStyle: TStyle;
    FLineStyle: TStyle;
    FNodeChar: AnsiString;
    FBlock: IBlock;
  public
    class function New(const AEvents: array of TTimelineEvent): ITimeline; static;

    function WithStyle(const S: TStyle): ITimeline;
    function WithLineStyle(const S: TStyle): ITimeline;
    function WithNodeChar(const C: AnsiString): ITimeline;
    function WithBlock(ABlock: IBlock): ITimeline;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

uses
  SysUtils, nextpas.core.text.width, nextpas.core.text.utf8;

class function TTimelineEvent.Make(const ATime, ATitle: AnsiString): TTimelineEvent;
begin
  Result.Time := ATime; Result.Title := ATitle;
  Result.Description := ''; Result.Style := TStyle.Default;
end;

function TTimelineEvent.WithDescription(const D: AnsiString): TTimelineEvent;
begin Result := Self; Result.Description := D; end;

function TTimelineEvent.WithStyle(const S: TStyle): TTimelineEvent;
begin Result := Self; Result.Style := S; end;

{ TTimeline }

class function TTimeline.New(const AEvents: array of TTimelineEvent): ITimeline;
var LSelf: TTimeline; I: Integer;
begin
  LSelf := TTimeline.Create;
  SetLength(LSelf.FEvents, Length(AEvents));
  for I := 0 to High(AEvents) do LSelf.FEvents[I] := AEvents[I];
  LSelf.FStyle := TStyle.Default;
  LSelf.FLineStyle := TStyle.Default.WithFg(TUI_DARK_GRAY);
  LSelf.FNodeChar := #$E2#$97#$8F;
  LSelf.FBlock := nil;
  Result := LSelf;
end;

function TTimeline.WithStyle(const S: TStyle): ITimeline;
begin FStyle := S; Result := Self; end;

function TTimeline.WithLineStyle(const S: TStyle): ITimeline;
begin FLineStyle := S; Result := Self; end;

function TTimeline.WithNodeChar(const C: AnsiString): ITimeline;
begin FNodeChar := C; Result := Self; end;

function TTimeline.WithBlock(ABlock: IBlock): ITimeline;
begin FBlock := ABlock; Result := Self; end;

procedure TTimeline.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Inner: TRect;
  I, Y, TimeW, NodeX, TextX, TextW: Integer;
begin
  if AArea.IsEmpty then Exit;
  ABuffer.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  TimeW := 0;
  for I := 0 to High(FEvents) do
    if Integer(StringDisplayWidth(FEvents[I].Time)) > TimeW then
      TimeW := Integer(StringDisplayWidth(FEvents[I].Time));
  Inc(TimeW);

  NodeX := Inner.X + TimeW;
  TextX := NodeX + 2;
  TextW := Inner.Width - TimeW - 2;
  if TextW < 1 then TextW := 1;

  Y := Inner.Y;
  for I := 0 to High(FEvents) do
  begin
    if Y >= Inner.Y + Inner.Height then Break;
    ABuffer.SetStringN(Inner.X, Y, FEvents[I].Time, TimeW, FLineStyle);
    ABuffer.SetStringN(NodeX, Y, FNodeChar, 1, FEvents[I].Style);
    ABuffer.SetStringN(TextX, Y, FEvents[I].Title, TextW, FEvents[I].Style);
    Inc(Y);
    if (FEvents[I].Description <> '') and (Y < Inner.Y + Inner.Height) then
    begin
      ABuffer.SetStringN(NodeX, Y, #$E2#$94#$82, 1, FLineStyle);
      ABuffer.SetStringN(TextX, Y, FEvents[I].Description, TextW, FStyle);
      Inc(Y);
    end;
    if (I < High(FEvents)) and (Y < Inner.Y + Inner.Height) then
    begin
      ABuffer.SetStringN(NodeX, Y, #$E2#$94#$82, 1, FLineStyle);
      Inc(Y);
    end;
  end;
end;

end.

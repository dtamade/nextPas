unit nextpas.core.tui.widget.toast;

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
  nextpas.core.tui.buffer;

type
  TToastPosition = (tpTopRight, tpBottomRight, tpTopCenter, tpBottomCenter);
  TToastLevel = (tlInfo, tlSuccess, tlWarning, tlError);

  TToastItem = record
    Message: AnsiString;
    Level: TToastLevel;
    RemainingMs: Integer;
  end;

  TToastManager = class
  private
    FItems: array of TToastItem;
    FPosition: TToastPosition;
    FDurationMs: Integer;
    FMaxVisible: Integer;
    FWidth: Integer;
    FInfoStyle: TStyle;
    FSuccessStyle: TStyle;
    FWarningStyle: TStyle;
    FErrorStyle: TStyle;
  public
    constructor Create;
    procedure Push(const Msg: AnsiString; Level: TToastLevel);
    procedure Tick(DeltaMs: Integer);
    procedure Render(const Container: TRect; ABuf: TBuffer);
    function Count: Integer;
    function Visible: Integer;

    property Position: TToastPosition read FPosition write FPosition;
    property DurationMs: Integer read FDurationMs write FDurationMs;
    property MaxVisible: Integer read FMaxVisible write FMaxVisible;
    property Width: Integer read FWidth write FWidth;
    property InfoStyle: TStyle read FInfoStyle write FInfoStyle;
    property SuccessStyle: TStyle read FSuccessStyle write FSuccessStyle;
    property WarningStyle: TStyle read FWarningStyle write FWarningStyle;
    property ErrorStyle: TStyle read FErrorStyle write FErrorStyle;
  end;

implementation

constructor TToastManager.Create;
begin
  inherited;
  FItems := nil;
  FPosition := tpTopRight;
  FDurationMs := 3000;
  FMaxVisible := 5;
  FWidth := 30;
  FInfoStyle := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_BLUE);
  FSuccessStyle := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_GREEN);
  FWarningStyle := TStyle.Default.WithFg(TUI_BLACK).WithBg(TUI_YELLOW);
  FErrorStyle := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_RED);
end;

procedure TToastManager.Push(const Msg: AnsiString; Level: TToastLevel);
var N: Integer;
begin
  N := Length(FItems);
  SetLength(FItems, N + 1);
  FItems[N].Message := Msg;
  FItems[N].Level := Level;
  FItems[N].RemainingMs := FDurationMs;
end;

procedure TToastManager.Tick(DeltaMs: Integer);
var I, W: Integer;
begin
  W := 0;
  for I := 0 to High(FItems) do
  begin
    Dec(FItems[I].RemainingMs, DeltaMs);
    if FItems[I].RemainingMs > 0 then
    begin
      if W <> I then FItems[W] := FItems[I];
      Inc(W);
    end;
  end;
  SetLength(FItems, W);
end;

function TToastManager.Count: Integer;
begin
  Result := Length(FItems);
end;

function TToastManager.Visible: Integer;
begin
  Result := Length(FItems);
  if Result > FMaxVisible then Result := FMaxVisible;
end;

procedure TToastManager.Render(const Container: TRect; ABuf: TBuffer);
var
  I, N, X, Y, H: Integer;
  Sty: TStyle;
  Txt: AnsiString;
begin
  if Container.IsEmpty then Exit;
  N := Visible;
  if N = 0 then Exit;

  H := N;

  case FPosition of
    tpTopRight:
    begin
      X := Container.X + Container.Width - FWidth;
      Y := Container.Y;
    end;
    tpBottomRight:
    begin
      X := Container.X + Container.Width - FWidth;
      Y := Container.Y + Container.Height - H;
    end;
    tpTopCenter:
    begin
      X := Container.X + (Container.Width - FWidth) div 2;
      Y := Container.Y;
    end;
    tpBottomCenter:
    begin
      X := Container.X + (Container.Width - FWidth) div 2;
      Y := Container.Y + Container.Height - H;
    end;
  end;

  if X < Container.X then X := Container.X;

  for I := 0 to N - 1 do
  begin
    case FItems[I].Level of
      tlInfo: Sty := FInfoStyle;
      tlSuccess: Sty := FSuccessStyle;
      tlWarning: Sty := FWarningStyle;
      tlError: Sty := FErrorStyle;
    end;

    ABuf.SetStyle(TRect.Make(X, Y + I, FWidth, 1), Sty);
    Txt := ' ' + FItems[I].Message;
    ABuf.SetStringN(X, Y + I, Txt, FWidth, Sty);
  end;
end;

end.

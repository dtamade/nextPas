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
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf;

type
  TToastPosition = (tpTopRight, tpBottomRight, tpTopCenter, tpBottomCenter);
  TToastLevel = (tlInfo, tlSuccess, tlWarning, tlError);

  TToastItem = record
    Message: AnsiString;
    Level: TToastLevel;
    RemainingMs: Integer;
  end;

  IToastManager = interface(IWidget)
    ['{F8A9B0C1-D2E3-4567-FABC-890123456789}']
    procedure Push(const Msg: AnsiString; Level: TToastLevel);
    procedure Tick(DeltaMs: Integer);
    function GetCount: Integer;
    function GetVisible: Integer;
    property Count: Integer read GetCount;
    property Visible: Integer read GetVisible;
  end;

  TToastManager = class(TInterfacedObject, IWidget, IToastManager)
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
    class function New: IToastManager; static;

    procedure Push(const Msg: AnsiString; Level: TToastLevel);
    procedure Tick(DeltaMs: Integer);
    function GetCount: Integer;
    function GetVisible: Integer;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

class function TToastManager.New: IToastManager;
var LSelf: TToastManager;
begin
  LSelf := TToastManager.Create;
  LSelf.FItems := nil;
  LSelf.FPosition := tpTopRight;
  LSelf.FDurationMs := 3000;
  LSelf.FMaxVisible := 5;
  LSelf.FWidth := 30;
  LSelf.FInfoStyle := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_BLUE);
  LSelf.FSuccessStyle := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_GREEN);
  LSelf.FWarningStyle := TStyle.Default.WithFg(TUI_BLACK).WithBg(TUI_YELLOW);
  LSelf.FErrorStyle := TStyle.Default.WithFg(TUI_WHITE).WithBg(TUI_RED);
  Result := LSelf;
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

function TToastManager.GetCount: Integer;
begin
  Result := Length(FItems);
end;

function TToastManager.GetVisible: Integer;
begin
  Result := Length(FItems);
  if Result > FMaxVisible then Result := FMaxVisible;
end;

procedure TToastManager.Render(const AArea: TRect; ABuffer: TBuffer);
var
  I, N, X, Y, H: Integer;
  Sty: TStyle;
  Txt: AnsiString;
begin
  if AArea.IsEmpty then Exit;
  N := GetVisible;
  if N = 0 then Exit;

  H := N;

  case FPosition of
    tpTopRight:
    begin
      X := AArea.X + AArea.Width - FWidth;
      Y := AArea.Y;
    end;
    tpBottomRight:
    begin
      X := AArea.X + AArea.Width - FWidth;
      Y := AArea.Y + AArea.Height - H;
    end;
    tpTopCenter:
    begin
      X := AArea.X + (AArea.Width - FWidth) div 2;
      Y := AArea.Y;
    end;
    tpBottomCenter:
    begin
      X := AArea.X + (AArea.Width - FWidth) div 2;
      Y := AArea.Y + AArea.Height - H;
    end;
  end;

  if X < AArea.X then X := AArea.X;

  for I := 0 to N - 1 do
  begin
    case FItems[I].Level of
      tlInfo: Sty := FInfoStyle;
      tlSuccess: Sty := FSuccessStyle;
      tlWarning: Sty := FWarningStyle;
      tlError: Sty := FErrorStyle;
    end;

    ABuffer.SetStyle(TRect.Make(X, Y + I, FWidth, 1), Sty);
    Txt := ' ' + FItems[I].Message;
    ABuffer.SetStringN(X, Y + I, Txt, FWidth, Sty);
  end;
end;

end.

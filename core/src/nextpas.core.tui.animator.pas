unit nextpas.core.tui.animator;

{$I nextpas.core.settings.inc}


interface

type
  TEasingFn = function(T: Double): Double;

  TAnimState = (asIdle, asRunning, asDone);

  TAnimSlot = record
    Target: PDouble;
    StartVal: Double;
    EndVal: Double;
    StartMs: QWord;
    DurationMs: Integer;
    Easing: TEasingFn;
    State: TAnimState;
  end;

  TAnimator = record
  private
    FSlots: array[0..63] of TAnimSlot;
    FCount: Integer;
    function FindSlotForTarget(ATarget: PDouble): Integer;
  public
    procedure Tick(NowMs: QWord);
    function Start(ATarget: PDouble; AFrom, ATo: Double;
      ADurationMs: Integer; AEasing: TEasingFn): Integer;
    procedure Cancel(Id: Integer);
    procedure CancelTarget(ATarget: PDouble);
    function AnyRunning: Boolean; inline;
    function RunningCount: Integer; inline;
  end;

function EaseLinear(T: Double): Double;
function EaseInQuad(T: Double): Double;
function EaseOutQuad(T: Double): Double;
function EaseInOutQuad(T: Double): Double;
function EaseOutCubic(T: Double): Double;
function EaseInOutCubic(T: Double): Double;
function EaseOutBack(T: Double): Double;
function EaseOutBounce(T: Double): Double;
function EaseSpring(T: Double): Double;

implementation

function EaseLinear(T: Double): Double;
begin Result := T; end;

function EaseInQuad(T: Double): Double;
begin Result := T * T; end;

function EaseOutQuad(T: Double): Double;
begin Result := T * (2 - T); end;

function EaseInOutQuad(T: Double): Double;
begin
  if T < 0.5 then Result := 2 * T * T
  else Result := -1 + (4 - 2 * T) * T;
end;

function EaseOutCubic(T: Double): Double;
var U: Double;
begin U := T - 1; Result := U * U * U + 1; end;

function EaseInOutCubic(T: Double): Double;
begin
  if T < 0.5 then Result := 4 * T * T * T
  else Result := (T - 1) * (2 * T - 2) * (2 * T - 2) + 1;
end;

function EaseOutBack(T: Double): Double;
const C1 = 1.70158; C3 = C1 + 1;
begin Result := 1 + C3 * (T - 1) * (T - 1) * (T - 1) + C1 * (T - 1) * (T - 1); end;

function EaseOutBounce(T: Double): Double;
const N1 = 7.5625; D1 = 2.75;
begin
  if T < 1/D1 then Result := N1 * T * T
  else if T < 2/D1 then begin T := T - 1.5/D1; Result := N1 * T * T + 0.75; end
  else if T < 2.5/D1 then begin T := T - 2.25/D1; Result := N1 * T * T + 0.9375; end
  else begin T := T - 2.625/D1; Result := N1 * T * T + 0.984375; end;
end;

function EaseSpring(T: Double): Double;
begin
  Result := 1 - Cos(T * 4.5 * Pi) * Exp(-T * 6);
end;

{ TAnimator }

function TAnimator.FindSlotForTarget(ATarget: PDouble): Integer;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    if (FSlots[I].Target = ATarget) and (FSlots[I].State = asRunning) then
      Exit(I);
  Result := -1;
end;

procedure TAnimator.Tick(NowMs: QWord);
var
  I: Integer;
  T, V: Double;
begin
  for I := 0 to FCount - 1 do
  begin
    if FSlots[I].State <> asRunning then Continue;
    if FSlots[I].StartMs = 0 then
      FSlots[I].StartMs := NowMs;
    if NowMs >= FSlots[I].StartMs + QWord(FSlots[I].DurationMs) then
    begin
      FSlots[I].Target^ := FSlots[I].EndVal;
      FSlots[I].State := asDone;
    end
    else
    begin
      T := (NowMs - FSlots[I].StartMs) / FSlots[I].DurationMs;
      if T < 0 then T := 0;
      V := FSlots[I].Easing(T);
      FSlots[I].Target^ := FSlots[I].StartVal + (FSlots[I].EndVal - FSlots[I].StartVal) * V;
    end;
  end;
end;

function TAnimator.Start(ATarget: PDouble; AFrom, ATo: Double;
  ADurationMs: Integer; AEasing: TEasingFn): Integer;
var Idx, I: Integer;
begin
  Idx := FindSlotForTarget(ATarget);
  if Idx < 0 then
  begin
    if FCount >= 64 then
    begin
      Idx := -1;
      for I := 0 to 63 do
        if FSlots[I].State in [asIdle, asDone] then begin Idx := I; Break; end;
      if Idx < 0 then Idx := 0;
    end
    else
    begin
      Idx := FCount;
      Inc(FCount);
    end;
  end;
  FSlots[Idx].Target := ATarget;
  FSlots[Idx].StartVal := AFrom;
  FSlots[Idx].EndVal := ATo;
  FSlots[Idx].StartMs := 0;
  FSlots[Idx].DurationMs := ADurationMs;
  FSlots[Idx].Easing := AEasing;
  FSlots[Idx].State := asRunning;
  Result := Idx;
end;

procedure TAnimator.Cancel(Id: Integer);
begin
  if (Id >= 0) and (Id < FCount) then
    FSlots[Id].State := asIdle;
end;

procedure TAnimator.CancelTarget(ATarget: PDouble);
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FSlots[I].Target = ATarget then
      FSlots[I].State := asIdle;
end;

function TAnimator.AnyRunning: Boolean;
var I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FSlots[I].State = asRunning then Exit(True);
  Result := False;
end;

function TAnimator.RunningCount: Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to FCount - 1 do
    if FSlots[I].State = asRunning then Inc(Result);
end;

end.

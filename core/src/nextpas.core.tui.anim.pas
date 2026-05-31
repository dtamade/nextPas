unit nextpas.core.tui.anim;

// Animation primitives: easing functions, spinners, and transitions.
//
// All easing functions take T in [0..1] and return a value in [0..1].
// TTransition drives a value from StartVal to EndVal over DurationMs
// using a configurable easing curve.
// TSpinner provides cycling frame-based text animations.

{$I nextpas.core.settings.inc}


interface

type
  TEasingFunc = function(T: Double): Double;

  TSpinnerKind = (skDots, skLine, skBraille, skMoon, skArrow);

  TSpinner = record
    Frames: array of AnsiString;
    IntervalMs: Integer;

    class function Create(Kind: TSpinnerKind): TSpinner; static;
    class function Custom(const AFrames: array of AnsiString; AIntervalMs: Integer): TSpinner; static;
    function Frame(Tick: Integer): AnsiString;
    function FrameAt(ElapsedMs: QWord): AnsiString;
    function IsAnimating: Boolean; inline;
  end;

  TTransition = record
    StartVal: Double;
    EndVal: Double;
    DurationMs: Integer;
    ElapsedMs: Integer;
    Easing: TEasingFunc;

    class function Create(AStart, AEnd: Double; ADurationMs: Integer): TTransition; static;
    function WithEasing(E: TEasingFunc): TTransition;
    procedure Advance(DeltaMs: Integer);
    function Value: Double;
    function Done: Boolean; inline;
    procedure Reset;
  end;

function EaseLinear(T: Double): Double;
function EaseInQuad(T: Double): Double;
function EaseOutQuad(T: Double): Double;
function EaseInOutQuad(T: Double): Double;
function EaseInCubic(T: Double): Double;
function EaseOutCubic(T: Double): Double;
function EaseInOutCubic(T: Double): Double;
function EaseBounce(T: Double): Double;

function Lerp(A, B: Integer; T: Double): Integer; inline;
function LerpF(A, B, T: Double): Double; inline;

implementation

function EaseLinear(T: Double): Double;
begin
  Result := T;
end;

function EaseInQuad(T: Double): Double;
begin
  Result := T * T;
end;

function EaseOutQuad(T: Double): Double;
begin
  Result := T * (2.0 - T);
end;

function EaseInOutQuad(T: Double): Double;
begin
  if T < 0.5 then
    Result := 2.0 * T * T
  else
    Result := -1.0 + (4.0 - 2.0 * T) * T;
end;

function EaseInCubic(T: Double): Double;
begin
  Result := T * T * T;
end;

function EaseOutCubic(T: Double): Double;
var
  U: Double;
begin
  U := T - 1.0;
  Result := U * U * U + 1.0;
end;

function EaseInOutCubic(T: Double): Double;
begin
  if T < 0.5 then
    Result := 4.0 * T * T * T
  else
    Result := (T - 1.0) * (2.0 * T - 2.0) * (2.0 * T - 2.0) + 1.0;
end;

function EaseBounce(T: Double): Double;
var
  U: Double;
begin
  if T < (1.0 / 2.75) then
    Result := 7.5625 * T * T
  else if T < (2.0 / 2.75) then
  begin
    U := T - (1.5 / 2.75);
    Result := 7.5625 * U * U + 0.75;
  end
  else if T < (2.5 / 2.75) then
  begin
    U := T - (2.25 / 2.75);
    Result := 7.5625 * U * U + 0.9375;
  end
  else
  begin
    U := T - (2.625 / 2.75);
    Result := 7.5625 * U * U + 0.984375;
  end;
end;

function Lerp(A, B: Integer; T: Double): Integer;
begin
  Result := Round(A + (B - A) * T);
end;

function LerpF(A, B, T: Double): Double;
begin
  Result := A + (B - A) * T;
end;

class function TSpinner.Create(Kind: TSpinnerKind): TSpinner;
begin
  Result.IntervalMs := 80;
  case Kind of
    skDots: begin
      SetLength(Result.Frames, 10);
      Result.Frames[0] := #$E2#$A0#$8B; // ⠋
      Result.Frames[1] := #$E2#$A0#$99; // ⠙
      Result.Frames[2] := #$E2#$A0#$B9; // ⠹
      Result.Frames[3] := #$E2#$A0#$B8; // ⠸
      Result.Frames[4] := #$E2#$A0#$BC; // ⠼
      Result.Frames[5] := #$E2#$A0#$B4; // ⠴
      Result.Frames[6] := #$E2#$A0#$A6; // ⠦
      Result.Frames[7] := #$E2#$A0#$A7; // ⠧
      Result.Frames[8] := #$E2#$A0#$87; // ⠇
      Result.Frames[9] := #$E2#$A0#$8F; // ⠏
    end;
    skLine: begin
      SetLength(Result.Frames, 4);
      Result.Frames[0] := '|';
      Result.Frames[1] := '/';
      Result.Frames[2] := '-';
      Result.Frames[3] := '\';
      Result.IntervalMs := 130;
    end;
    skBraille: begin
      SetLength(Result.Frames, 8);
      Result.Frames[0] := #$E2#$A3#$BE; // ⣾
      Result.Frames[1] := #$E2#$A3#$BD; // ⣽
      Result.Frames[2] := #$E2#$A3#$BB; // ⣻
      Result.Frames[3] := #$E2#$A2#$BF; // ⢿
      Result.Frames[4] := #$E2#$A1#$BF; // ⡿
      Result.Frames[5] := #$E2#$A3#$9F; // ⣟
      Result.Frames[6] := #$E2#$A3#$AF; // ⣯
      Result.Frames[7] := #$E2#$A3#$B7; // ⣷
    end;
    skMoon: begin
      SetLength(Result.Frames, 8);
      Result.Frames[0] := #$F0#$9F#$8C#$91; // U+1F311
      Result.Frames[1] := #$F0#$9F#$8C#$92; // U+1F312
      Result.Frames[2] := #$F0#$9F#$8C#$93; // U+1F313
      Result.Frames[3] := #$F0#$9F#$8C#$94; // U+1F314
      Result.Frames[4] := #$F0#$9F#$8C#$95; // U+1F315
      Result.Frames[5] := #$F0#$9F#$8C#$96; // U+1F316
      Result.Frames[6] := #$F0#$9F#$8C#$97; // U+1F317
      Result.Frames[7] := #$F0#$9F#$8C#$98; // U+1F318
      Result.IntervalMs := 150;
    end;
    skArrow: begin
      SetLength(Result.Frames, 8);
      Result.Frames[0] := #$E2#$86#$90; // ←
      Result.Frames[1] := #$E2#$86#$96; // ↖
      Result.Frames[2] := #$E2#$86#$91; // ↑
      Result.Frames[3] := #$E2#$86#$97; // ↗
      Result.Frames[4] := #$E2#$86#$92; // →
      Result.Frames[5] := #$E2#$86#$98; // ↘
      Result.Frames[6] := #$E2#$86#$93; // ↓
      Result.Frames[7] := #$E2#$86#$99; // ↙
    end;
  end;
end;

class function TSpinner.Custom(const AFrames: array of AnsiString; AIntervalMs: Integer): TSpinner;
var
  I: Integer;
begin
  SetLength(Result.Frames, Length(AFrames));
  for I := 0 to High(AFrames) do
    Result.Frames[I] := AFrames[I];
  Result.IntervalMs := AIntervalMs;
end;

function TSpinner.Frame(Tick: Integer): AnsiString;
var
  N: Integer;
begin
  N := Length(Frames);
  if N = 0 then
    Result := ''
  else
    Result := Frames[((Tick mod N) + N) mod N];
end;

function TSpinner.FrameAt(ElapsedMs: QWord): AnsiString;
var
  N: Integer;
  Idx: QWord;
begin
  N := Length(Frames);
  if N = 0 then
    Result := ''
  else
  begin
    if IntervalMs <= 0 then
      Idx := 0
    else
      Idx := (ElapsedMs div QWord(IntervalMs)) mod QWord(N);
    Result := Frames[Idx];
  end;
end;

function TSpinner.IsAnimating: Boolean;
begin
  Result := Length(Frames) > 1;
end;

class function TTransition.Create(AStart, AEnd: Double; ADurationMs: Integer): TTransition;
begin
  Result.StartVal := AStart;
  Result.EndVal := AEnd;
  Result.DurationMs := ADurationMs;
  Result.ElapsedMs := 0;
  Result.Easing := @EaseLinear;
end;

function TTransition.WithEasing(E: TEasingFunc): TTransition;
begin
  Result := Self;
  Result.Easing := E;
end;

procedure TTransition.Advance(DeltaMs: Integer);
begin
  ElapsedMs := ElapsedMs + DeltaMs;
  if ElapsedMs > DurationMs then
    ElapsedMs := DurationMs;
end;

function TTransition.Value: Double;
var
  Progress: Double;
begin
  if DurationMs <= 0 then
  begin
    Result := EndVal;
    Exit;
  end;
  Progress := ElapsedMs / DurationMs;
  if Progress < 0.0 then Progress := 0.0;
  if Progress > 1.0 then Progress := 1.0;
  Result := StartVal + (EndVal - StartVal) * Easing(Progress);
end;

function TTransition.Done: Boolean;
begin
  Result := ElapsedMs >= DurationMs;
end;

procedure TTransition.Reset;
begin
  ElapsedMs := 0;
end;

end.

unit nextpas.core.audio.studio.automation;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

type
  TAutomationPoint = record
    Frame: UInt64;
    Value: Single;
  end;

  TAutomationCurve = class
  private
    FPoints: array of TAutomationPoint;
    FSnap: array of TAutomationPoint; // realtime scratch: steady-state zero-alloc
    FLock: TRTLCriticalSection;
    function FindSegment(AFrame: UInt64; out AIdx: Integer): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddPoint(AFrame: UInt64; AValue: Single);
    procedure Clear;
    function Count: Integer;
    function ValueAt(AFrame: UInt64): Single;
    function FillRealtimeValues(AStartFrame: UInt64; ACount: Integer; ADst: PSingle): Integer;
  end;

function HermiteInterpolate(A0, A1, A2, A3: Single; AT: Single): Single;

implementation

function HermiteInterpolate(A0, A1, A2, A3: Single; AT: Single): Single;
var T2, T3: Single; M0, M1: Single;
begin
  T2 := AT * AT;
  T3 := T2 * AT;
  M0 := (A2 - A0) * 0.5;
  M1 := (A3 - A1) * 0.5;
  Result := (2*T3 - 3*T2 + 1)*A1 + (T3 - 2*T2 + AT)*M0 + (-2*T3 + 3*T2)*A2 + (T3 - T2)*M1;
end;

constructor TAutomationCurve.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
end;

destructor TAutomationCurve.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

procedure TAutomationCurve.AddPoint(AFrame: UInt64; AValue: Single);
var L, I: Integer;
begin
  EnterCriticalSection(FLock);
  try
    L := Length(FPoints);
    SetLength(FPoints, L + 1);
    // insertion sort: shift tail until sorted (O(n), single pass, vs O(n^2) bubble)
    I := L;
    while (I > 0) and (FPoints[I-1].Frame > AFrame) do
    begin
      FPoints[I] := FPoints[I-1];
      Dec(I);
    end;
    FPoints[I].Frame := AFrame;
    FPoints[I].Value := AValue;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TAutomationCurve.FindSegment(AFrame: UInt64; out AIdx: Integer): Boolean;
var I: Integer;
begin
  Result := False;
  AIdx := -1;
  for I := 0 to High(FPoints) - 1 do
    if (AFrame >= FPoints[I].Frame) and (AFrame < FPoints[I+1].Frame) then
    begin AIdx := I; Result := True; Exit; end;
end;

procedure TAutomationCurve.Clear;
begin
  EnterCriticalSection(FLock);
  try SetLength(FPoints, 0);
  finally LeaveCriticalSection(FLock); end;
end;

function TAutomationCurve.Count: Integer;
begin
  EnterCriticalSection(FLock);
  try Result := Length(FPoints);
  finally LeaveCriticalSection(FLock); end;
end;

function TAutomationCurve.ValueAt(AFrame: UInt64): Single;
var I: Integer; LIdx: Integer; T: Single; A0, A1, A2, A3: Single;
begin
  EnterCriticalSection(FLock);
  try
    if Length(FPoints) = 0 then Exit(0);
    if AFrame <= FPoints[0].Frame then Exit(FPoints[0].Value);
    if AFrame >= FPoints[High(FPoints)].Frame then Exit(FPoints[High(FPoints)].Value);
    if FindSegment(AFrame, LIdx) then
    begin
      A1 := FPoints[LIdx].Value;
      A2 := FPoints[LIdx+1].Value;
      if LIdx > 0 then A0 := FPoints[LIdx-1].Value else A0 := A1;
      if LIdx + 2 < Length(FPoints) then A3 := FPoints[LIdx+2].Value else A3 := A2;
      T := (AFrame - FPoints[LIdx].Frame) / (FPoints[LIdx+1].Frame - FPoints[LIdx].Frame);
      Result := HermiteInterpolate(A0, A1, A2, A3, T);
    end
    else
      Result := FPoints[High(FPoints)].Value;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TAutomationCurve.FillRealtimeValues(AStartFrame: UInt64; ACount: Integer; ADst: PSingle): Integer;
var
  LSnapLen, I, LSeg: Integer;
  LFrame: UInt64;
  T: Single;
  A0, A1, A2, A3: Single;
begin
  Result := 0;
  if (ADst = nil) or (ACount <= 0) then Exit;
  // snapshot once: reuse FSnap scratch (steady-state zero-alloc after warm-up)
  EnterCriticalSection(FLock);
  try
    LSnapLen := Length(FPoints);
    if Length(FSnap) < LSnapLen then
      SetLength(FSnap, LSnapLen);
    if LSnapLen > 0 then
      Move(FPoints[0], FSnap[0], LSnapLen * SizeOf(TAutomationPoint));
  finally
    LeaveCriticalSection(FLock);
  end;
  if LSnapLen = 0 then
  begin
    for I := 0 to ACount - 1 do ADst[I] := 0;
    Exit(ACount);
  end;
  // monotonic walk: segment index only moves forward as AStartFrame increases
  LSeg := -1;
  for I := 0 to LSnapLen - 2 do
    if AStartFrame >= FSnap[I].Frame then LSeg := I else Break;
  for I := 0 to ACount - 1 do
  begin
    LFrame := AStartFrame + UInt64(I);
    if LFrame <= FSnap[0].Frame then ADst[I] := FSnap[0].Value
    else if LFrame >= FSnap[LSnapLen-1].Frame then ADst[I] := FSnap[LSnapLen-1].Value
    else
    begin
      while (LSeg + 1 < LSnapLen - 1) and (LFrame >= FSnap[LSeg+1].Frame) do Inc(LSeg);
      while (LSeg >= 0) and (LFrame < FSnap[LSeg].Frame) do Dec(LSeg);
      if (LSeg < 0) then LSeg := 0;
      if LSeg >= LSnapLen - 1 then LSeg := LSnapLen - 2;
      A1 := FSnap[LSeg].Value; A2 := FSnap[LSeg+1].Value;
      if LSeg > 0 then A0 := FSnap[LSeg-1].Value else A0 := A1;
      if LSeg + 2 < LSnapLen then A3 := FSnap[LSeg+2].Value else A3 := A2;
      if FSnap[LSeg+1].Frame = FSnap[LSeg].Frame then T := 0 else
        T := (LFrame - FSnap[LSeg].Frame) / (FSnap[LSeg+1].Frame - FSnap[LSeg].Frame);
      ADst[I] := HermiteInterpolate(A0, A1, A2, A3, T);
    end;
  end;
  Result := ACount;
end;

end.

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
var L, I, J: Integer; LTmp: TAutomationPoint;
begin
  EnterCriticalSection(FLock);
  try
    L := Length(FPoints);
    SetLength(FPoints, L + 1);
    FPoints[L].Frame := AFrame;
    FPoints[L].Value := AValue;
    for I := 1 to High(FPoints) do
      for J := I downto 1 do
        if FPoints[J].Frame < FPoints[J-1].Frame then
        begin
          LTmp := FPoints[J];
          FPoints[J] := FPoints[J-1];
          FPoints[J-1] := LTmp;
        end
        else
          Break;
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
var I: Integer;
begin
  Result := 0;
  if (ADst = nil) or (ACount <= 0) then Exit;
  for I := 0 to ACount - 1 do
    ADst[I] := ValueAt(AStartFrame + UInt64(I));
  Result := ACount;
end;

end.

unit nextpas.core.audio.codec.vorbis.sse;

{$I nextpas.core.settings.inc}

interface

function VorbisSseWindow(const AData: array of Single; var AOut: array of Single): Boolean;
function VorbisSseMdct(const AIn: array of Single; var AOut: array of Single): Boolean;
function VorbisSseFloor(const AIn: array of Single): Single;

implementation

function VorbisSseWindow(const AData: array of Single; var AOut: array of Single): Boolean;
var I: Integer;
begin
  Result := False;
  if Length(AData) = 0 then Exit;
  if Length(AOut) < Length(AData) then Exit;
  for I := 0 to High(AData) do
    AOut[I] := AData[I] * 0.5 * (1 - Cos(2 * Pi * I / Length(AData)));
  Result := True;
end;

function VorbisSseMdct(const AIn: array of Single; var AOut: array of Single): Boolean;
var I: Integer;
begin
  Result := False;
  if (Length(AIn) = 0) or (Length(AOut) = 0) then Exit;
  for I := 0 to High(AIn) do
    if I <= High(AOut) then
      AOut[I] := AIn[I];
  Result := True;
end;

function VorbisSseFloor(const AIn: array of Single): Single;
var I: Integer; S: Single;
begin
  S := 0;
  for I := 0 to High(AIn) do
    S := S + Abs(AIn[I]);
  Result := S;
end;

end.

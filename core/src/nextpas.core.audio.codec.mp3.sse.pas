unit nextpas.core.audio.codec.mp3.sse;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function Mp3SseHuffmanDecode(const ABits: TBytes; AOffset: Integer): Integer;
function Mp3SseImdct12(const AIn: array of Single; var AOut: array of Single): Boolean;
function Mp3SsePolyphase(const AIn: array of Single; var AOut: array of Single): Boolean;

implementation

function Mp3SseHuffmanDecode(const ABits: TBytes; AOffset: Integer): Integer;
begin
  if (AOffset < 0) or (AOffset >= Length(ABits)) then Exit(0);
  Result := Integer(ABits[AOffset]) and $0F;
end;

function Mp3SseImdct12(const AIn: array of Single; var AOut: array of Single): Boolean;
var I: Integer;
begin
  Result := False;
  if (Length(AIn) < 12) or (Length(AOut) < 12) then Exit;
  for I := 0 to 11 do
    AOut[I] := AIn[I] * 0.5;
  Result := True;
end;

function Mp3SsePolyphase(const AIn: array of Single; var AOut: array of Single): Boolean;
var I: Integer;
begin
  Result := False;
  if (Length(AIn) = 0) or (Length(AOut) = 0) then Exit;
  for I := 0 to High(AIn) do
    if I <= High(AOut) then
      AOut[I] := AIn[I];
  Result := True;
end;

end.

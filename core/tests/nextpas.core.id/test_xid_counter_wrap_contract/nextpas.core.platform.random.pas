unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

procedure TestRandomReset;
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

implementation

procedure TestRandomReset;
begin
end;

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LI: PtrUInt;
begin
  if ALen = 0 then
    Exit(0);
  if ABuf = nil then
    Exit(-1);

  for LI := 0 to ALen - 1 do
    PByte(ABuf + LI)^ := 0;

  if ALen >= 6 then
  begin
    PByte(ABuf + 0)^ := $01;
    PByte(ABuf + 1)^ := $02;
    PByte(ABuf + 2)^ := $03;
    PByte(ABuf + 3)^ := $FF;
    PByte(ABuf + 4)^ := $FF;
    PByte(ABuf + 5)^ := $FE;
  end;
  Result := 0;
end;

end.

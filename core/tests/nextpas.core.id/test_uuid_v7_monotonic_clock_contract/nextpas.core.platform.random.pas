unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

implementation

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LI: PtrUInt;
begin
  if ALen = 0 then
    Exit(0);
  if ABuf = nil then
    Exit(-1);
  for LI := 0 to ALen - 1 do
    PByte(ABuf + LI)^ := $FF;
  Result := 0;
end;

end.

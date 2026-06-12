unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

procedure TestRandomReset;
procedure TestRandomSetPattern(const AFirstByte, ASecondByte: Byte);
function TestRandomCallCount: SizeUInt;
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

implementation

var
  GCallCount: SizeUInt = 0;
  GFirstByte: Byte = $FF;
  GSecondByte: Byte = $00;

procedure TestRandomReset;
begin
  GCallCount := 0;
  GFirstByte := $FF;
  GSecondByte := $00;
end;

procedure TestRandomSetPattern(const AFirstByte, ASecondByte: Byte);
begin
  GFirstByte := AFirstByte;
  GSecondByte := ASecondByte;
end;

function TestRandomCallCount: SizeUInt;
begin
  Result := GCallCount;
end;

function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;
var
  LI: PtrUInt;
begin
  if ALen = 0 then
    Exit(0);
  if ABuf = nil then
    Exit(-1);

  Inc(GCallCount);
  for LI := 0 to ALen - 1 do
    if LI < 10 then
      PByte(ABuf + LI)^ := GFirstByte
    else
      PByte(ABuf + LI)^ := GSecondByte;
  Result := 0;
end;

end.

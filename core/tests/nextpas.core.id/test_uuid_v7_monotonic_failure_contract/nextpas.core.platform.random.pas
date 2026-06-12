unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

const
  TEST_RANDOM_FAILURE = 4321;

procedure TestRandomReset;
procedure TestRandomSetFailure(const AEnabled: Boolean);
procedure TestRandomSetFillByte(const AValue: Byte);
function TestRandomCallCount: SizeUInt;
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

implementation

var
  GFail: Boolean = False;
  GCallCount: SizeUInt = 0;
  GFillByte: Byte = 1;

procedure TestRandomReset;
begin
  GFail := False;
  GCallCount := 0;
  GFillByte := 1;
end;

procedure TestRandomSetFailure(const AEnabled: Boolean);
begin
  GFail := AEnabled;
end;

procedure TestRandomSetFillByte(const AValue: Byte);
begin
  GFillByte := AValue;
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
  if GFail then
    Exit(TEST_RANDOM_FAILURE);
  for LI := 0 to ALen - 1 do
    PByte(ABuf + LI)^ := GFillByte;
  Result := 0;
end;

end.

unit nextpas.core.platform.random;

{$I nextpas.core.settings.inc}

interface

const
  TEST_RANDOM_FAILURE = 5678;

procedure TestRandomReset;
procedure TestRandomSetFailure(const AEnabled: Boolean);
function TestRandomCallCount: SizeUInt;
function platform_random_bytes(ABuf: Pointer; ALen: PtrUInt): Int32;

implementation

var
  GFail: Boolean = True;
  GCallCount: SizeUInt = 0;
  GNextByte: Byte = 1;

procedure TestRandomReset;
begin
  GFail := True;
  GCallCount := 0;
  GNextByte := 1;
end;

procedure TestRandomSetFailure(const AEnabled: Boolean);
begin
  GFail := AEnabled;
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
  begin
    PByte(ABuf + LI)^ := GNextByte;
    Inc(GNextByte);
    if GNextByte = 0 then
      GNextByte := 1;
  end;
  Result := 0;
end;

end.

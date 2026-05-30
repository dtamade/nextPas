unit nextpas.core.id.rng;
{$I nextpas.core.settings.inc}

interface

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);

implementation

uses
  nextpas.core.platform.random;

const
  BUF_SIZE = 4096;

var
  GBuf: array[0..BUF_SIZE - 1] of Byte;
  GPos: SizeUInt = BUF_SIZE;

procedure Refill;
begin
  platform_random_bytes(@GBuf[0], BUF_SIZE);
  GPos := 0;
end;

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);
var
  LAvail, LCopy: SizeUInt;
begin
  while ALen > 0 do
  begin
    if GPos >= BUF_SIZE then
      Refill;
    LAvail := BUF_SIZE - GPos;
    if ALen < LAvail then LCopy := ALen else LCopy := LAvail;
    Move(GBuf[GPos], ABuf^, LCopy);
    Inc(GPos, LCopy);
    Inc(PByte(ABuf), LCopy);
    Dec(ALen, LCopy);
  end;
end;

end.

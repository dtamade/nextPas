unit nextpas.core.id.rng;
{$I nextpas.core.settings.inc}

interface

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);
procedure IdRngReseed;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.random;

const
  BUF_SIZE = 4096;

var
  GBuf: array[0..BUF_SIZE - 1] of Byte;
  GPos: SizeUInt = BUF_SIZE;
  GLock: Int32 = 0;

procedure Refill;
var LRet: Int32;
begin
  LRet := platform_random_bytes(@GBuf[0], BUF_SIZE);
  if LRet <> 0 then
  begin
    AtomicStore32(GLock, 0, moRelease);
    RunError(217);
  end;
  GPos := 0;
end;

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);
var
  LAvail, LCopy: SizeUInt;
begin
  while AtomicCompareExchange32(GLock, 0, 1) <> 0 do
    CpuPause;
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
  AtomicStore32(GLock, 0, moRelease);
end;

procedure IdRngReseed;
begin
  while AtomicCompareExchange32(GLock, 0, 1) <> 0 do
    CpuPause;
  GPos := BUF_SIZE;
  AtomicStore32(GLock, 0, moRelease);
end;

end.

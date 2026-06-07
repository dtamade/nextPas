unit nextpas.core.id.rng;
{$I nextpas.core.settings.inc}

interface

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);
procedure IdRngReseed;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.base,
  nextpas.core.errors,
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
    raise EIOError.Create('IdRngFillBytes: random source failed');
  GPos := 0;
end;

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);
var
  LAvail, LCopy: SizeUInt;
  LDst: PByte;
begin
  if ALen = 0 then
    Exit;
  if ABuf = nil then
    raise EArgumentNil.Create('IdRngFillBytes: destination is nil');

  LDst := PByte(ABuf);
  while AtomicCompareExchange32(GLock, 0, 1) <> 0 do
    CpuPause;
  try
    while ALen > 0 do
    begin
      if GPos >= BUF_SIZE then
        Refill;
      LAvail := BUF_SIZE - GPos;
      if ALen < LAvail then LCopy := ALen else LCopy := LAvail;
      Move(GBuf[GPos], LDst^, LCopy);
      Inc(GPos, LCopy);
      Inc(LDst, LCopy);
      Dec(ALen, LCopy);
    end;
  finally
    AtomicStore32(GLock, 0, moRelease);
  end;
end;

procedure IdRngReseed;
begin
  while AtomicCompareExchange32(GLock, 0, 1) <> 0 do
    CpuPause;
  try
    GPos := BUF_SIZE;
  finally
    AtomicStore32(GLock, 0, moRelease);
  end;
end;

end.

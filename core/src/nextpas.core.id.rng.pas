unit nextpas.core.id.rng;
{$I nextpas.core.settings.inc}

interface

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);
procedure IdRngReseed;

implementation

uses nextpas.core.atomic, nextpas.core.base, nextpas.core.errors, nextpas.core.platform.random, nextpas.core.text.conv;

const
  BUF_SIZE = 4096;
  MAX_REQUEST_SIZE = SizeUInt(High(SizeInt));

var
  GBuf: array[0..BUF_SIZE - 1] of Byte;
  GPos: SizeUInt = BUF_SIZE;
  GLock: Int32 = 0;

procedure Refill;
var
  LBuf: array[0..BUF_SIZE - 1] of Byte;
  LRet: Int32;
begin
  LRet := platform_random_bytes(@LBuf[0], BUF_SIZE);
  if LRet <> 0 then
    raise EIOError.Create('IdRngFillBytes: platform_random_bytes failed: ' + IntToStr(LRet));
  Move(LBuf[0], GBuf[0], BUF_SIZE);
  GPos := 0;
end;

procedure FillBytesFromCache(ABuf: Pointer; ALen: SizeUInt);
var
  LAvail, LCopy: SizeUInt;
  LDst: PByte;
begin
  LDst := PByte(ABuf);
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
end;

function CacheCanSatisfyCurrentRequest(const ALen: SizeUInt): Boolean;
begin
  if GPos >= BUF_SIZE then
    Refill;
  Result := ALen <= BUF_SIZE - GPos;
end;

procedure IdRngFillBytes(ABuf: Pointer; ALen: SizeUInt);
var
  LTemp: array of Byte;
begin
  if ALen = 0 then
    Exit;
  if ABuf = nil then
    raise EArgumentNil.Create('IdRngFillBytes: destination is nil');
  if ALen > MAX_REQUEST_SIZE then
    raise EArgumentError.Create('IdRngFillBytes: length exceeds maximum request size');

  while AtomicCompareExchange32(GLock, 0, 1) <> 0 do
    CpuPause;
  try
    if CacheCanSatisfyCurrentRequest(ALen) then
      FillBytesFromCache(ABuf, ALen)
    else
    begin
      SetLength(LTemp, ALen);
      FillBytesFromCache(@LTemp[0], ALen);
      Move(LTemp[0], PByte(ABuf)^, ALen);
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

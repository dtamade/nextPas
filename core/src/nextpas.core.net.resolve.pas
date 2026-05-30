unit nextpas.core.net.resolve;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base;

function NetResolve(const AHost: string): TNetAddress;
function NetResolveIPv4(const AIP: string): UInt32;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.socket;

function NetResolveIPv4(const AIP: string): UInt32;
var
  LParts: array[0..3] of Byte;
  LI, LStart, LPart: Integer;
  LS: string;
begin
  LStart := 1;
  LPart := 0;
  for LI := 1 to Length(AIP) + 1 do
  begin
    if (LI > Length(AIP)) or (AIP[LI] = '.') then
    begin
      if LPart > 3 then
        raise EArgumentError.Create('invalid IPv4: ' + AIP);
      LS := Copy(AIP, LStart, LI - LStart);
      LParts[LPart] := Byte(StrToInt(LS));
      Inc(LPart);
      LStart := LI + 1;
    end;
  end;
  if LPart <> 4 then
    raise EArgumentError.Create('invalid IPv4: ' + AIP);
  Result := UInt32(LParts[0]) or (UInt32(LParts[1]) shl 8)
    or (UInt32(LParts[2]) shl 16) or (UInt32(LParts[3]) shl 24);
end;

function IsIPv4Literal(const AHost: string): Boolean;
var
  LI: Integer;
begin
  if Length(AHost) = 0 then Exit(False);
  for LI := 1 to Length(AHost) do
    if not (AHost[LI] in ['0'..'9', '.']) then
      Exit(False);
  Result := True;
end;

function NetResolve(const AHost: string): TNetAddress;
var
  LHints: addrinfo;
  LRes: PAddrInfo;
  LResult: cint;
  LSa: ^sockaddr_in;
  LA: UInt32;
begin
  if (AHost = '') or (AHost = 'localhost') then
    Exit(TNetAddress.IPv4('127.0.0.1', 0));

  if IsIPv4Literal(AHost) then
    Exit(TNetAddress.IPv4(AHost, 0));

  FillChar(LHints, SizeOf(LHints), 0);
  LHints.ai_family := PLATFORM_AF_INET;
  LHints.ai_socktype := PLATFORM_SOCK_STREAM;
  LRes := nil;

  LResult := getaddrinfo(PAnsiChar(AHost), nil, @LHints, @LRes);
  if (LResult <> 0) or (LRes = nil) then
    raise ENetworkError.Create('DNS resolve failed for: ' + AHost);

  try
    LSa := Pointer(LRes^.ai_addr);
    LA := LSa^.sin_addr.s_addr;
    Result.IP := IntToStr(LA and $FF) + '.' + IntToStr((LA shr 8) and $FF) + '.' +
      IntToStr((LA shr 16) and $FF) + '.' + IntToStr((LA shr 24) and $FF);
    Result.Port := 0;
    Result.IsIPv6 := False;
  finally
    freeaddrinfo(LRes);
  end;
end;

end.

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
  nextpas.core.platform.socket;

function NetResolveIPv4(const AIP: string): UInt32;
var
  LParts: array[0..3] of Byte;
  LI, LStart, LPart, LVal: Integer;
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
      LVal := StrToInt(LS);
      if (LVal < 0) or (LVal > 255) then
        raise EArgumentError.Create('invalid IPv4 octet: ' + AIP);
      LParts[LPart] := Byte(LVal);
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
  LAddr: UInt32;
  LResult: Int32;
begin
  if (AHost = '') or (AHost = 'localhost') then
    Exit(TNetAddress.IPv4('127.0.0.1', 0));

  if IsIPv4Literal(AHost) then
    Exit(TNetAddress.IPv4(AHost, 0));

  LResult := platform_socket_resolve_ipv4(PAnsiChar(AHost), LAddr);
  if LResult <> 0 then
    raise ENetworkError.Create('DNS resolve failed for: ' + AHost);

  Result.IP := IntToStr(LAddr and $FF) + '.' + IntToStr((LAddr shr 8) and $FF) + '.' +
    IntToStr((LAddr shr 16) and $FF) + '.' + IntToStr((LAddr shr 24) and $FF);
  Result.Port := 0;
  Result.IsIPv6 := False;
end;

end.

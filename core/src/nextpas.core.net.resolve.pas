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
  nextpas.core.platform.posix.base;

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

function NetResolve(const AHost: string): TNetAddress;
begin
  Result := TNetAddress.IPv4(AHost, 0);
  if (AHost = 'localhost') or (AHost = '') then
    Result.IP := '127.0.0.1';
end;

end.

unit nextpas.core.net.base;

{$I nextpas.core.settings.inc}

interface

type
  TNetAddress = record
    IP: string;
    Port: UInt16;
    IsIPv6: Boolean;
    function ToString: string;
    class function Create(const AIP: string; APort: UInt16): TNetAddress; static;
    class function IPv4(const AIP: string; APort: UInt16): TNetAddress; static;
    class function IPv6(const AIP: string; APort: UInt16): TNetAddress; static;
    class function Loopback(APort: UInt16): TNetAddress; static;
    class function Any(APort: UInt16): TNetAddress; static;
  end;

const
  NET_DEFAULT_BACKLOG = 128;
  NET_DEFAULT_BUFFER_SIZE = 65536;

implementation

uses
  SysUtils;

class function TNetAddress.Create(const AIP: string; APort: UInt16): TNetAddress;
begin
  Result.IP := AIP;
  Result.Port := APort;
  Result.IsIPv6 := Pos(':', AIP) > 0;
end;

class function TNetAddress.IPv4(const AIP: string; APort: UInt16): TNetAddress;
begin
  Result.IP := AIP;
  Result.Port := APort;
  Result.IsIPv6 := False;
end;

class function TNetAddress.IPv6(const AIP: string; APort: UInt16): TNetAddress;
begin
  Result.IP := AIP;
  Result.Port := APort;
  Result.IsIPv6 := True;
end;

class function TNetAddress.Loopback(APort: UInt16): TNetAddress;
begin
  Result.IP := '127.0.0.1';
  Result.Port := APort;
  Result.IsIPv6 := False;
end;

class function TNetAddress.Any(APort: UInt16): TNetAddress;
begin
  Result.IP := '0.0.0.0';
  Result.Port := APort;
  Result.IsIPv6 := False;
end;

function TNetAddress.ToString: string;
begin
  if IsIPv6 then
    Result := '[' + IP + ']:' + IntToStr(Port)
  else
    Result := IP + ':' + IntToStr(Port);
end;

end.

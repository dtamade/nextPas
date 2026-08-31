unit nextpas.core.net.base;
{**
 * @desc 网络模块基础类型：TNetAddress、常量。
 *}

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
    function WithPort(APort: UInt16): TNetAddress;
  end;

const
  { 监听 accept 队列深度。128 在万级连接风暴(如 mailServer888 连接级压测 8000+
    直连)下会瞬间打满:队列满后内核丢弃新 SYN(默认 tcp_abort_on_overflow=0),
    客户端 connect 等到重传超时失败。Linux 内核按 somaxconn(默认 4096)min() 截断,
    故取该上限;其他平台(SYSTEMV/QNX 等)128-1024 起步,同步放宽无副作用。 }
  NET_DEFAULT_BACKLOG = 4096;
  NET_DEFAULT_BUFFER_SIZE = 65536;

implementation

uses
  nextpas.core.text.conv;

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

function TNetAddress.WithPort(APort: UInt16): TNetAddress;
begin
  Result := Self;
  Result.Port := APort;
end;

function TNetAddress.ToString: string;
begin
  if IsIPv6 then
    Result := '[' + IP + ']:' + IntToStr(Port)
  else
    Result := IP + ':' + IntToStr(Port);
end;

end.

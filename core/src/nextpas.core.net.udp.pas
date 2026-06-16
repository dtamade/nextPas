unit nextpas.core.net.udp;
{**
 * @desc UDP socket 实现：SendTo/RecvFrom 无连接数据报。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf;

function NetUdpBind(const AAddr: string; const APort: UInt16): IUdpSocket;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.socket;

type
  TUdpSocket = class(TInterfacedObject, IUdpSocket)
  private
    FSocket: TPlatformSocket;
    FLocal: TNetAddress;
    FClosed: Boolean;
    procedure EnsureOpen(const AOperation: string);
  public
    constructor Create(const ASocket: TPlatformSocket; const ALocal: TNetAddress);
    destructor Destroy; override;
    function SendTo(const ABuf; const ACount: SizeUInt; const AAddr: TNetAddress): SizeUInt;
    function RecvFrom(var ABuf; const ACount: SizeUInt; out AAddr: TNetAddress): SizeUInt;
    function LocalAddr: TNetAddress;
    procedure Close;
  end;

function Htons(AVal: UInt16): UInt16; inline;
begin
  Result := platform_htons(AVal);
end;

function Ntohs(AVal: UInt16): UInt16; inline;
begin
  Result := platform_htons(AVal);
end;

constructor TUdpSocket.Create(const ASocket: TPlatformSocket; const ALocal: TNetAddress);
begin
  inherited Create;
  FSocket := ASocket;
  FLocal := ALocal;
  FClosed := False;
end;

destructor TUdpSocket.Destroy;
begin
  if not FClosed then
    platform_socket_close(FSocket);
  inherited;
end;

procedure TUdpSocket.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise ENetworkError.Create('udp socket ' + AOperation + ' after close');
end;

function TUdpSocket.SendTo(const ABuf; const ACount: SizeUInt; const AAddr: TNetAddress): SizeUInt;
var
  LSa: sockaddr_in;
  LSaLen: Int32;
  LSent: Int32;
  LResult: Int32;
begin
  EnsureOpen('sendto');
  if platform_sockaddr_from_ipv4(AAddr.IP, AAddr.Port, LSa, LSaLen) <> 0 then
    raise ENetworkError.Create('udp sendto: invalid address');
  LResult := platform_socket_sendto(FSocket, @ABuf, Int32(ACount), 0,
    @LSa, LSaLen, LSent);
  if LResult <> 0 then
    raise ENetworkError.Create('udp sendto failed (' + IntToStr(LResult) + ')');
  Result := SizeUInt(LSent);
end;

function TUdpSocket.RecvFrom(var ABuf; const ACount: SizeUInt; out AAddr: TNetAddress): SizeUInt;
var
  LSa: sockaddr_in;
  LSaLen: socklen_t;
  LRecvd: Int32;
  LResult: Int32;
begin
  EnsureOpen('recvfrom');
  LSaLen := SizeOf(LSa);
  LResult := platform_socket_recvfrom(FSocket, @ABuf, Int32(ACount), 0,
    @LSa, @LSaLen, LRecvd);
  if LResult <> 0 then
    raise ENetworkError.Create('udp recvfrom failed (' + IntToStr(LResult) + ')');
  platform_sockaddr_to_ipv4(LSa, AAddr.IP, AAddr.Port);
  AAddr.IsIPv6 := False;
  Result := SizeUInt(LRecvd);
end;

function TUdpSocket.LocalAddr: TNetAddress;
begin
  Result := FLocal;
end;

procedure TUdpSocket.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    platform_socket_close(FSocket);
    FSocket := PLATFORM_INVALID_SOCKET;
  end;
end;

function NetUdpBind(const AAddr: string; const APort: UInt16): IUdpSocket;
var
  LSock: TPlatformSocket;
  LSa: sockaddr_in;
  LSaLen: Int32;
  LOne: Int32;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  LLocal := TNetAddress.Create(AAddr, APort);
  LResult := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('udp bind: socket create failed');
  LOne := 1;
  platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LOne, SizeOf(LOne));
  if platform_sockaddr_from_ipv4(AAddr, APort, LSa, LSaLen) <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('udp bind: invalid address');
  end;
  LResult := platform_socket_bind(LSock, @LSa, LSaLen);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('udp bind failed');
  end;
  LSaLen := SizeOf(LSa);
  if platform_socket_getsockname(LSock, @LSa, @LSaLen) = 0 then
    LLocal.Port := platform_htons(LSa.sin_port);
  Result := TUdpSocket.Create(LSock, LLocal);
end;

end.

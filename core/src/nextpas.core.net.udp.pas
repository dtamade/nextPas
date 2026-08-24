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
  nextpas.core.platform.socket,
  nextpas.core.platform.socket.base;

type
  TUdpSocket = class(TInterfacedObject, IUdpSocket, IUdpSocketRuntime)
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
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
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
  Close;
  inherited;
end;

procedure TUdpSocket.EnsureOpen(const AOperation: string);
begin
  if FClosed then
    raise ENetworkError.Create('udp ' + AOperation + ' after close');
end;

function TUdpSocket.SendTo(const ABuf; const ACount: SizeUInt; const AAddr: TNetAddress): SizeUInt;
var
  LSa: TPlatformSockAddr;
  LSent: Int32;
  LResult: Int32;
begin
  EnsureOpen('sendto');
  if nextpas.core.platform.socket.platform_sockaddr_ipv4(AAddr.Port,
    platform_ipv4_parse(AAddr.IP), LSa) <> 0 then
    raise ENetworkError.Create('udp sendto: invalid address');
  while True do
  begin
    LResult := platform_socket_sendto(FSocket, @ABuf, Int32(ACount), 0,
      @LSa.Storage[0], Int32(LSa.Len), LSent);
    if LResult = 0 then
      Break;
    if platform_socket_error_interrupted(LResult) then
      Continue;
    raise ENetworkError.Create('udp sendto failed (' + IntToStr(LResult) + ')');
  end;
  Result := SizeUInt(LSent);
end;

function TUdpSocket.RecvFrom(var ABuf; const ACount: SizeUInt; out AAddr: TNetAddress): SizeUInt;
var
  LSa: TPlatformSockAddr;
  LSaLen: Int32;
  LRecvd: Int32;
  LResult: Int32;
  LIP: UInt32;
  LPort: UInt16;
begin
  EnsureOpen('recvfrom');
  LSa.Clear;
  while True do
  begin
    LSaLen := SizeOf(LSa.Storage);
    LResult := platform_socket_recvfrom(FSocket, @ABuf, Int32(ACount), 0,
      @LSa.Storage[0], @LSaLen, LRecvd);
    if LResult = 0 then
      Break;
    if platform_socket_error_interrupted(LResult) then
      Continue;
    raise ENetworkError.Create('udp recvfrom failed (' + IntToStr(LResult) + ')');
  end;
  LSa.Len := UInt32(LSaLen);
  platform_sockaddr_ipv4_extract(LSa, LIP, LPort);
  AAddr.IP := platform_ipv4_to_string(platform_ntohl(LIP));
  AAddr.Port := LPort;
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

function TUdpSocket.NativeSocketHandle: PtrUInt;
begin
  Result := PtrUInt(FSocket.Value);
end;

procedure TUdpSocket.SetBlocking(const ABlocking: Boolean);
begin
  EnsureOpen('set blocking');
  if platform_socket_set_nonblocking(FSocket, not ABlocking) <> 0 then
    raise ENetworkError.Create('udp set blocking failed');
end;

function NetUdpBind(const AAddr: string; const APort: UInt16): IUdpSocket;
var
  LSock: TPlatformSocket;
  LSa: TPlatformSockAddr;
  LSaLen: Int32;
  LOne: Int32;
  LResult: Int32;
  LLocal: TNetAddress;
  LIP: UInt32;
  LPort: UInt16;
begin
  LLocal := TNetAddress.Create(AAddr, APort);
  LResult := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_DGRAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('udp bind: socket create failed');
  LOne := 1;
  platform_socket_setsockopt(LSock, PLATFORM_SOL_SOCKET, PLATFORM_SO_REUSEADDR, @LOne, SizeOf(LOne));
  if nextpas.core.platform.socket.platform_sockaddr_ipv4(APort,
    platform_ipv4_parse(AAddr), LSa) <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('udp bind: invalid address');
  end;
  LResult := platform_socket_bind(LSock, @LSa.Storage[0], Int32(LSa.Len));
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('udp bind failed');
  end;
  LSa.Clear;
  LSaLen := SizeOf(LSa.Storage);
  if platform_socket_getsockname(LSock, @LSa.Storage[0], @LSaLen) = 0 then
  begin
    LSa.Len := UInt32(LSaLen);
    platform_sockaddr_ipv4_extract(LSa, LIP, LPort);
    LLocal.Port := LPort;
  end;
  Result := TUdpSocket.Create(LSock, LLocal);
end;

end.

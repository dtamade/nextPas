unit nextpas.core.net.tcp;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf;

function NetTcpListen(const AAddr: string; const APort: UInt16): ITcpListener;
function NetTcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;

implementation

uses
  SysUtils,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.errors,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.socket,
  nextpas.core.net.resolve;

type
  TTcpStream = class(TInterfacedObject, IReader, IWriter, IStream, ITcpStream)
  private
    FSocket: TPlatformSocket;
    FLocal: TNetAddress;
    FRemote: TNetAddress;
    FClosed: Boolean;
  public
    constructor Create(const ASocket: TPlatformSocket;
      const ALocal, ARemote: TNetAddress);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
  end;

  TTcpListener = class(TInterfacedObject, ITcpListener)
  private
    FSocket: TPlatformSocket;
    FLocal: TNetAddress;
    FClosed: Boolean;
  public
    constructor Create(const ASocket: TPlatformSocket; const ALocal: TNetAddress);
    destructor Destroy; override;
    function Accept: ITcpStream;
    function LocalAddr: TNetAddress;
    procedure Close;
  end;

function Htons(AVal: UInt16): UInt16; inline;
begin
  Result := ((AVal and $FF) shl 8) or ((AVal shr 8) and $FF);
end;

function Ntohs(AVal: UInt16): UInt16; inline;
begin
  Result := ((AVal and $FF) shl 8) or ((AVal shr 8) and $FF);
end;

procedure FillSockAddr(const AAddr: TNetAddress; out ASa: sockaddr_in; out ALen: Int32);
begin
  FillChar(ASa, SizeOf(ASa), 0);
  ASa.sin_family := AF_INET;
  ASa.sin_port := Htons(AAddr.Port);
  if (AAddr.IP = '0.0.0.0') or (AAddr.IP = '') then
    ASa.sin_addr.s_addr := 0
  else
    ASa.sin_addr.s_addr := NetResolveIPv4(AAddr.IP);
  ALen := SizeOf(sockaddr_in);
end;

function AddrFromSockAddr(const ASa: sockaddr_in): TNetAddress;
var
  LA: UInt32;
begin
  LA := ASa.sin_addr.s_addr;
  Result.IP := IntToStr(LA and $FF) + '.' +
    IntToStr((LA shr 8) and $FF) + '.' +
    IntToStr((LA shr 16) and $FF) + '.' +
    IntToStr((LA shr 24) and $FF);
  Result.Port := Ntohs(ASa.sin_port);
  Result.IsIPv6 := False;
end;

{ TTcpStream }

constructor TTcpStream.Create(const ASocket: TPlatformSocket;
  const ALocal, ARemote: TNetAddress);
begin
  inherited Create;
  FSocket := ASocket;
  FLocal := ALocal;
  FRemote := ARemote;
  FClosed := False;
end;

destructor TTcpStream.Destroy;
begin
  if not FClosed then
    platform_socket_close(FSocket);
  inherited;
end;

function TTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRecvd: Int32;
  LResult: Int32;
begin
  if ACount = 0 then Exit(0);
  LResult := platform_socket_recv(FSocket, @ABuf, Int32(ACount), 0, LRecvd);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp read failed (' + IntToStr(LResult) + ')');
  Result := SizeUInt(LRecvd);
end;

function TTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LSent: Int32;
  LResult: Int32;
  LPtr: PByte;
  LRemaining: SizeUInt;
begin
  if ACount = 0 then Exit(0);
  LPtr := @ABuf;
  LRemaining := ACount;
  Result := 0;
  while LRemaining > 0 do
  begin
    LResult := platform_socket_send(FSocket, LPtr, Int32(LRemaining), 0, LSent);
    if LResult <> 0 then
      raise ENetworkError.Create('tcp write failed (' + IntToStr(LResult) + ')');
    if LSent = 0 then
      Break;
    Inc(LPtr, LSent);
    Dec(LRemaining, SizeUInt(LSent));
    Inc(Result, SizeUInt(LSent));
  end;
end;

function TTcpStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  raise ENotSupportedError.Create('tcp stream does not support seek');
end;

procedure TTcpStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    platform_socket_close(FSocket);
  end;
end;

function TTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TTcpStream.SetPosition(const AValue: Int64);
begin
  raise ENotSupportedError.Create('tcp stream does not support seek');
end;

function TTcpStream.LocalAddr: TNetAddress;
begin
  Result := FLocal;
end;

function TTcpStream.RemoteAddr: TNetAddress;
begin
  Result := FRemote;
end;

procedure TTcpStream.Shutdown;
begin
  platform_socket_shutdown(FSocket, SHUT_WR);
end;

procedure TTcpStream.SetNoDelay(const AValue: Boolean);
var
  LVal: Int32;
begin
  if AValue then LVal := 1 else LVal := 0;
  platform_socket_setsockopt(FSocket, IPPROTO_TCP, TCP_NODELAY, @LVal, SizeOf(LVal));
end;

procedure TTcpStream.SetKeepAlive(const AValue: Boolean);
var
  LVal: Int32;
begin
  if AValue then LVal := 1 else LVal := 0;
  platform_socket_setsockopt(FSocket, SOL_SOCKET, SO_KEEPALIVE, @LVal, SizeOf(LVal));
end;

{ TTcpListener }

constructor TTcpListener.Create(const ASocket: TPlatformSocket; const ALocal: TNetAddress);
begin
  inherited Create;
  FSocket := ASocket;
  FLocal := ALocal;
  FClosed := False;
end;

destructor TTcpListener.Destroy;
begin
  if not FClosed then
    platform_socket_close(FSocket);
  inherited;
end;

function TTcpListener.Accept: ITcpStream;
var
  LClient: TPlatformSocket;
  LAddr, LLocalAddr: sockaddr_in;
  LAddrLen: socklen_t;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  LAddrLen := SizeOf(LAddr);
  LResult := platform_socket_accept(FSocket, @LAddr, @LAddrLen, LClient);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp accept failed (' + IntToStr(LResult) + ')');
  LAddrLen := SizeOf(LLocalAddr);
  if platform_socket_getsockname(LClient, @LLocalAddr, @LAddrLen) = 0 then
    LLocal := AddrFromSockAddr(LLocalAddr)
  else
    LLocal := FLocal;
  Result := TTcpStream.Create(LClient, LLocal, AddrFromSockAddr(LAddr));
end;

function TTcpListener.LocalAddr: TNetAddress;
begin
  Result := FLocal;
end;

procedure TTcpListener.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    platform_socket_close(FSocket);
  end;
end;

{ Factory functions }

function NetTcpListen(const AAddr: string; const APort: UInt16): ITcpListener;
var
  LSock: TPlatformSocket;
  LSa: sockaddr_in;
  LSaLen: Int32;
  LOne: Int32;
  LResult: Int32;
  LLocal: TNetAddress;
begin
  LLocal := TNetAddress.Create(AAddr, APort);
  LResult := platform_socket_create(AF_INET, SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp listen: socket create failed (' + IntToStr(LResult) + ')');
  LOne := 1;
  platform_socket_setsockopt(LSock, SOL_SOCKET, SO_REUSEADDR, @LOne, SizeOf(LOne));
  FillSockAddr(LLocal, LSa, LSaLen);
  LResult := platform_socket_bind(LSock, @LSa, LSaLen);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp listen: bind failed (' + IntToStr(LResult) + ')');
  end;
  LResult := platform_socket_listen(LSock, NET_DEFAULT_BACKLOG);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp listen: listen failed (' + IntToStr(LResult) + ')');
  end;
  { Get actual bound address (important when port=0) }
  LSaLen := SizeOf(LSa);
  if platform_socket_getsockname(LSock, @LSa, @LSaLen) = 0 then
    LLocal := AddrFromSockAddr(LSa);
  Result := TTcpListener.Create(LSock, LLocal);
end;

function NetTcpConnect(const AAddr: string; const APort: UInt16): ITcpStream;
var
  LSock: TPlatformSocket;
  LSa: sockaddr_in;
  LSaLen: Int32;
  LResult: Int32;
  LRemote: TNetAddress;
begin
  LRemote := TNetAddress.Create(AAddr, APort);
  LResult := platform_socket_create(AF_INET, SOCK_STREAM, 0, LSock);
  if LResult <> 0 then
    raise ENetworkError.Create('tcp connect: socket create failed (' + IntToStr(LResult) + ')');
  FillSockAddr(LRemote, LSa, LSaLen);
  LResult := platform_socket_connect(LSock, @LSa, LSaLen);
  if LResult <> 0 then
  begin
    platform_socket_close(LSock);
    raise ENetworkError.Create('tcp connect failed (' + IntToStr(LResult) + ')');
  end;
  LSaLen := SizeOf(LSa);
  if platform_socket_getsockname(LSock, @LSa, @LSaLen) = 0 then
    Result := TTcpStream.Create(LSock, AddrFromSockAddr(LSa), LRemote)
  else
    Result := TTcpStream.Create(LSock, TNetAddress.Any(0), LRemote);
end;

end.

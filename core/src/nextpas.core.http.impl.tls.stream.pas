unit nextpas.core.http.impl.tls.stream;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
  nextpas.core.tls.base;

type
  ITlsTcpStreamInfo = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000001101}']
    function SelectedALPN: string;
  end;

function NewTlsClientTcpStream(const AConn: ITcpStream; const AContext: ISSLContext;
  const AServerName, AALPNProtocols: string): ITcpStream;
function NewTlsServerTcpStream(const AConn: ITcpStream;
  const AContext: ISSLContext): ITcpStream;
function TlsTcpStreamSelectedALPN(const AConn: ITcpStream): string;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.exception,
  nextpas.core.http.base,
  nextpas.core.time.base,
  nextpas.core.tls.quick,
  nextpas.core.tls.tls;

type
  TTlsTransportStream = class(TInterfacedObject, IStream)
  private
    FConn: ITcpStream;
  public
    constructor Create(const AConn: ITcpStream);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64;
      const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  end;

  TTlsTcpStream = class(TInterfacedObject, IReader, IWriter, IStream,
    ITcpStream, ITlsTcpStreamInfo)
  private
    FInner: ITcpStream;
    FIStream: IStream;
    FStream: TSSLStream;
    FClosed: Boolean;
    function TimeoutMsFromDeadline(const ADeadline: TDeadline): Integer;
  public
    constructor Create(const AInner: ITcpStream; const AStream: IStream);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64;
      const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
    procedure SetCancelToken(const AToken: INetCancelToken);
    function SelectedALPN: string;
  end;

function RequireTlsContext(const AContext: ISSLContext): ISSLContext;
begin
  if AContext <> nil then
    Exit(AContext);
  Result := TSSLQuick.SecureClient;
end;

function NewTlsClientTcpStream(const AConn: ITcpStream; const AContext: ISSLContext;
  const AServerName, AALPNProtocols: string): ITcpStream;
var
  LContext: ISSLContext;
  LTransport: IStream;
  LConnector: TSSLConnector;
  LTlsStream: IStream;
begin
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'TLS client stream requires connection');
  LContext := RequireTlsContext(AContext);
  LTransport := TTlsTransportStream.Create(AConn);
  LConnector := TSSLConnector.FromContext(LContext);
  if AALPNProtocols <> '' then
    LConnector := LConnector.WithALPN(AALPNProtocols);
  LTlsStream := LConnector.ConnectStream(LTransport, AServerName);
  Result := TTlsTcpStream.Create(AConn, LTlsStream);
end;

function NewTlsServerTcpStream(const AConn: ITcpStream;
  const AContext: ISSLContext): ITcpStream;
var
  LTransport: IStream;
  LAcceptor: TSSLAcceptor;
  LTlsStream: IStream;
begin
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'TLS server stream requires connection');
  if AContext = nil then
    raise EHttpError.Create(hekArgument, 'TLS server stream requires context');
  LTransport := TTlsTransportStream.Create(AConn);
  LAcceptor := TSSLAcceptor.FromContext(AContext);
  LTlsStream := LAcceptor.AcceptStream(LTransport);
  Result := TTlsTcpStream.Create(AConn, LTlsStream);
end;

function TlsTcpStreamSelectedALPN(const AConn: ITcpStream): string;
var
  LInfo: ITlsTcpStreamInfo;
begin
  Result := '';
  if (AConn <> nil) and Supports(AConn, ITlsTcpStreamInfo, LInfo) then
    Result := LInfo.SelectedALPN;
end;

{ TTlsTransportStream }

constructor TTlsTransportStream.Create(const AConn: ITcpStream);
begin
  inherited Create;
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'TLS transport stream requires connection');
  FConn := AConn;
end;

function TTlsTransportStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (FConn = nil) or (ACount = 0) then
    Exit(0);
  Result := FConn.Read(ABuf, ACount);
end;

function TTlsTransportStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (FConn = nil) or (ACount = 0) then
    Exit(0);
  Result := FConn.Write(ABuf, ACount);
end;

function TTlsTransportStream.Seek(const AOffset: Int64;
  const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
begin
  Result := 0;
  raise EHttpError.Create(hekArgument, 'TLS transport stream is not seekable');
end;

procedure TTlsTransportStream.Close;
begin
  { Connection lifecycle is managed by the caller }
end;

function TTlsTransportStream.GetSize: Int64;
begin
  Result := 0;
end;

function TTlsTransportStream.GetPosition: Int64;
begin
  Result := 0;
end;

procedure TTlsTransportStream.SetPosition(const AValue: Int64);
begin
  raise EHttpError.Create(hekArgument, 'TLS transport stream is not seekable');
end;

{ TTlsTcpStream }

constructor TTlsTcpStream.Create(const AInner: ITcpStream;
  const AStream: IStream);
begin
  inherited Create;
  if AInner = nil then
    raise EHttpError.Create(hekArgument, 'TLS stream requires inner connection');
  if AStream = nil then
    raise EHttpError.Create(hekArgument, 'TLS stream requires TLS transport');
  FInner := AInner;
  FIStream := AStream;
  FStream := AStream as TSSLStream;
  FClosed := False;
end;

destructor TTlsTcpStream.Destroy;
begin
  Close;
  FStream := nil;
  FIStream := nil;
  FInner := nil;
  inherited Destroy;
end;

function TTlsTcpStream.TimeoutMsFromDeadline(
  const ADeadline: TDeadline): Integer;
var
  LRemaining: TDuration;
  LMs: Int64;
begin
  if ADeadline.IsInfinite then
    Exit(-1);
  if ADeadline.IsExpired then
    Exit(0);
  LRemaining := ADeadline.Remaining;
  LMs := LRemaining.AsMilliseconds;
  if (LMs <= 0) and (LRemaining.AsNanoseconds > 0) then
    LMs := 1;
  if LMs > High(Integer) then
    Exit(High(Integer));
  Result := Integer(LMs);
end;

function TTlsTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (FStream = nil) or FClosed or (ACount = 0) then
    Exit(0);
  Result := SizeUInt(FStream.Read(ABuf, Longint(ACount)));
end;

function TTlsTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if (FStream = nil) or FClosed or (ACount = 0) then
    Exit(0);
  Result := SizeUInt(FStream.Write(ABuf, Longint(ACount)));
end;

function TTlsTcpStream.Seek(const AOffset: Int64;
  const AOrigin: nextpas.core.io.base.TSeekOrigin): Int64;
begin
  if FStream = nil then
    Exit(0);
  Result := FStream.Seek(AOffset, AOrigin);
end;

procedure TTlsTcpStream.Close;
begin
  if FClosed then
    Exit;
  FClosed := True;
  if FStream <> nil then
    FStream.Close;
end;

function TTlsTcpStream.GetSize: Int64;
begin
  Result := 0;
end;

function TTlsTcpStream.GetPosition: Int64;
begin
  Result := 0;
end;

procedure TTlsTcpStream.SetPosition(const AValue: Int64);
begin
  raise EHttpError.Create(hekArgument, 'TLS stream is not seekable');
end;

function TTlsTcpStream.LocalAddr: TNetAddress;
begin
  if FInner <> nil then
    Result := FInner.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function TTlsTcpStream.RemoteAddr: TNetAddress;
begin
  if FInner <> nil then
    Result := FInner.RemoteAddr
  else
    Result := TNetAddress.Any(0);
end;

procedure TTlsTcpStream.Shutdown;
begin
  Close;
end;

procedure TTlsTcpStream.SetNoDelay(const AValue: Boolean);
begin
  if FInner <> nil then
    FInner.SetNoDelay(AValue);
end;

procedure TTlsTcpStream.SetKeepAlive(const AValue: Boolean);
begin
  if FInner <> nil then
    FInner.SetKeepAlive(AValue);
end;

procedure TTlsTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
  { SSL layer timeout alone is not enough: TLS still blocks on FInner socket
    SO_RCVTIMEO. Forward so ApplyDeadline(Timeout) can re-arm after ConnectTimeout. }
  if FStream <> nil then
    FStream.SetReadTimeout(TimeoutMsFromDeadline(ADeadline));
  if FInner <> nil then
    FInner.SetReadDeadline(ADeadline);
end;

procedure TTlsTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
  if FStream <> nil then
    FStream.SetWriteTimeout(TimeoutMsFromDeadline(ADeadline));
  if FInner <> nil then
    FInner.SetWriteDeadline(ADeadline);
end;

procedure TTlsTcpStream.SetCancelToken(const AToken: INetCancelToken);
begin
  { TLS decrypt path still blocks on inner socket; forward cancel for mid-read. }
  if FInner <> nil then
    FInner.SetCancelToken(AToken);
end;

function TTlsTcpStream.SelectedALPN: string;
begin
  if FStream <> nil then
    Result := FStream.GetSelectedALPN
  else
    Result := '';
end;

end.

unit nextpas.core.http.impl.h1;
{**
 * @desc HTTP/1.x server transport owner + client re-export.
 *       Connection state: impl.h1.conn; blocking driver: impl.h1.serve;
 *       poll/epoll driver: impl.h1.poll.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf, nextpas.core.net.intf, nextpas.core.net.server.intf,
  nextpas.core.net.server.base, nextpas.core.platform.io.base,
  nextpas.core.tls.base, nextpas.core.http.base, nextpas.core.http.intf,
  nextpas.core.http.impl.h1.client,
  nextpas.core.http.impl.h1.conn;

type
  { Re-export client options/factory owner: impl.h1.client }
  TH1ClientTransportOptions = nextpas.core.http.impl.h1.client.TH1ClientTransportOptions;
  { Re-export server options/state owner: impl.h1.conn }
  TH1ServerTransportOptions = nextpas.core.http.impl.h1.conn.TH1ServerTransportOptions;

function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;

implementation

uses
  nextpas.core.errors;

type
  TH1ServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory, IHttpServerSessionFactoryWithContext)
  private
    FOptions: TH1ServerTransportOptions;
    procedure ValidateInputs(const AConn: ITcpStream; const AHandler: IHttpHandler);
    function HandleConnection(const AConn: ITcpStream; const AHandler: IHttpHandler): Boolean;
  public
    constructor Create(const AOptions: TH1ServerTransportOptions);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
  end;

constructor TH1ServerTransport.Create(const AOptions: TH1ServerTransportOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

procedure TH1ServerTransport.ValidateInputs(const AConn: ITcpStream;
  const AHandler: IHttpHandler);
begin
  if AConn = nil then
    raise EHttpError.Create(hekArgument, 'h1 server transport requires connection');
  if AHandler = nil then
    raise EHttpError.Create(hekArgument, 'h1 server transport requires handler');
end;

function TH1ServerTransport.HandleConnection(const AConn: ITcpStream;
  const AHandler: IHttpHandler): Boolean;
var
  LState: TH1ServerConnectionState;
begin
  ValidateInputs(AConn, AHandler);
  LState := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
  try
    Result := LState.Run = tscoServer;
  finally
    LState.Free;
  end;
end;

function TH1ServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
begin
  if HandleConnection(AConn, AHandler) then
    Result := tscoServer
  else
    Result := tscoHandler;
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  ValidateInputs(AConn, AHandler);
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions);
end;

function TH1ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  ValidateInputs(AConn, AHandler);
  Result := TH1ServerConnectionState.Create(AConn, AHandler, FOptions, AContext);
end;




function NewH1ClientTransport(const AOptions: TH1ClientTransportOptions): IHttpTransport;
begin
  Result := nextpas.core.http.impl.h1.client.NewH1ClientTransport(AOptions);
end;

function NewH1ServerTransport(const AOptions: TH1ServerTransportOptions): IHttpServerTransport;
begin
  Result := TH1ServerTransport.Create(AOptions);
end;

end.

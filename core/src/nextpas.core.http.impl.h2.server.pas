unit nextpas.core.http.impl.h2.server;
{**
 * @desc HTTP/2 server transport factory. Adapts the shared HTTP server
 *       facade/runtime seam onto TH2ServerSession so the TCP foundation can
 *       drive H2 connections through direct session factories.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h2.types;

function NewH2ServerTransport(
  const AOptions: TH2ServerTransportOptions): IHttpServerTransport;

implementation

uses
  nextpas.core.errors,
  nextpas.core.http.impl.h2.session;

type
  TH2ServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory, IHttpServerSessionFactoryWithContext)
  private
    FOptions: TH2ServerTransportOptions;
    procedure ValidateInputs(const AConn: ITcpStream;
      const AHandler: IHttpHandler);
    function CreateSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
  public
    constructor Create(const AOptions: TH2ServerTransportOptions);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
  end;

constructor TH2ServerTransport.Create(
  const AOptions: TH2ServerTransportOptions);
begin
  inherited Create;
  AOptions.Validate;
  FOptions := AOptions;
end;

procedure TH2ServerTransport.ValidateInputs(const AConn: ITcpStream;
  const AHandler: IHttpHandler);
begin
  if AConn = nil then
    raise EArgumentError.Create('h2 server transport requires connection');
  if AHandler = nil then
    raise EArgumentError.Create('h2 server transport requires handler');
end;

function TH2ServerTransport.CreateSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  ValidateInputs(AConn, AHandler);
  Result := TH2ServerSession.Create(AConn, AHandler, FOptions);
end;

function TH2ServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
var
  LSession: ITcpServerSession;
begin
  LSession := CreateSession(AConn, AHandler);
  Result := LSession.Run;
end;

function TH2ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  Result := CreateSession(AConn, AHandler);
end;

function TH2ServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Result := CreateSession(AConn, AHandler);
end;

function NewH2ServerTransport(
  const AOptions: TH2ServerTransportOptions): IHttpServerTransport;
begin
  Result := TH2ServerTransport.Create(AOptions);
end;

end.

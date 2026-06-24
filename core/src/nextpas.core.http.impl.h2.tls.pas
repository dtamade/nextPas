unit nextpas.core.http.impl.h2.tls;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.intf,
  nextpas.core.net.server.intf,
  nextpas.core.net.server.base,
  nextpas.core.tls.base,
  nextpas.core.http.intf;

function NewH2TlsServerTransport(const AContext: ISSLContext;
  const AInnerTransport: IHttpServerTransport): IHttpServerTransport;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.impl.h2.types,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.tls.http2.alpn;

type
  TH2TlsServerSession = class(TInterfacedObject, ITcpServerSession)
  private
    FRawConn: ITcpStream;
    FHandler: IHttpHandler;
    FContext: ISSLContext;
    FInnerTransport: IHttpServerTransport;
    FSessionContext: ITcpServerSessionContext;
    function CreateInnerSession(const ATlsConn: ITcpStream): ITcpServerSession;
  public
    constructor Create(const ARawConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ISSLContext; const AInnerTransport: IHttpServerTransport;
      const ASessionContext: ITcpServerSessionContext);
    function Run: TTcpServerConnOwnership;
  end;

  TH2TlsServerTransport = class(TInterfacedObject, IHttpServerTransport,
    IHttpServerSessionFactory, IHttpServerSessionFactoryWithContext)
  private
    FContext: ISSLContext;
    FInnerTransport: IHttpServerTransport;
    function CreateSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const ASessionContext: ITcpServerSessionContext): ITcpServerSession;
  public
    constructor Create(const AContext: ISSLContext;
      const AInnerTransport: IHttpServerTransport);
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
  end;

constructor TH2TlsServerSession.Create(const ARawConn: ITcpStream;
  const AHandler: IHttpHandler; const AContext: ISSLContext;
  const AInnerTransport: IHttpServerTransport;
  const ASessionContext: ITcpServerSessionContext);
begin
  inherited Create;
  if ARawConn = nil then
    raise EArgumentError.Create('h2 TLS server session requires connection');
  if AHandler = nil then
    raise EArgumentError.Create('h2 TLS server session requires handler');
  if AContext = nil then
    raise EArgumentError.Create('h2 TLS server session requires context');
  if AInnerTransport = nil then
    raise EArgumentError.Create('h2 TLS server session requires transport');
  FRawConn := ARawConn;
  FHandler := AHandler;
  FContext := AContext;
  FInnerTransport := AInnerTransport;
  FSessionContext := ASessionContext;
end;

function TH2TlsServerSession.CreateInnerSession(
  const ATlsConn: ITcpStream): ITcpServerSession;
var
  LContextFactory: IHttpServerSessionFactoryWithContext;
  LFactory: IHttpServerSessionFactory;
begin
  Result := nil;
  if (FSessionContext <> nil) and Supports(FInnerTransport,
    IHttpServerSessionFactoryWithContext, LContextFactory) then
    Exit(LContextFactory.NewSession(ATlsConn, FHandler, FSessionContext));
  if Supports(FInnerTransport, IHttpServerSessionFactory, LFactory) then
    Exit(LFactory.NewSession(ATlsConn, FHandler));
end;

function TH2TlsServerSession.Run: TTcpServerConnOwnership;
var
  LTlsConn: ITcpStream;
  LSelectedALPN: string;
  LSession: ITcpServerSession;
begin
  LTlsConn := NewTlsServerTcpStream(FRawConn, FContext);
  LSelectedALPN := LowerCase(Trim(TlsTcpStreamSelectedALPN(LTlsConn)));
  if LSelectedALPN <> HTTP2_ALPN_PROTOCOL then
    raise EHttpError.Create('h2 TLS server requires negotiated ALPN "h2"');

  LSession := CreateInnerSession(LTlsConn);
  if LSession <> nil then
    Exit(LSession.Run);
  Result := FInnerTransport.ServeConn(LTlsConn, FHandler);
end;

constructor TH2TlsServerTransport.Create(const AContext: ISSLContext;
  const AInnerTransport: IHttpServerTransport);
begin
  inherited Create;
  if AContext = nil then
    raise EArgumentError.Create('h2 TLS server transport requires context');
  if AInnerTransport = nil then
    raise EArgumentError.Create('h2 TLS server transport requires inner transport');
  AContext.SetALPNProtocols(HTTP2_ALPN_PROTOCOL);
  FContext := AContext;
  FInnerTransport := AInnerTransport;
end;

function TH2TlsServerTransport.CreateSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const ASessionContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Result := TH2TlsServerSession.Create(AConn, AHandler, FContext,
    FInnerTransport, ASessionContext);
end;

function TH2TlsServerTransport.ServeConn(const AConn: ITcpStream;
  const AHandler: IHttpHandler): TTcpServerConnOwnership;
var
  LSession: ITcpServerSession;
begin
  LSession := CreateSession(AConn, AHandler, nil);
  Result := LSession.Run;
end;

function TH2TlsServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler): ITcpServerSession;
begin
  Result := CreateSession(AConn, AHandler, nil);
end;

function TH2TlsServerTransport.NewSession(const AConn: ITcpStream;
  const AHandler: IHttpHandler;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
begin
  Result := CreateSession(AConn, AHandler, AContext);
end;

function NewH2TlsServerTransport(const AContext: ISSLContext;
  const AInnerTransport: IHttpServerTransport): IHttpServerTransport;
begin
  Result := TH2TlsServerTransport.Create(AContext, AInnerTransport);
end;

end.

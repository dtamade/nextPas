{**
 * nextpas.core.agent.transport.http - 生产 IAgentTransport 薄门面。
 *
 * 组装 http.core（RoundTrip/头体）与 http.stream（IReader 流）为完整
 * IAgentTransport；对外 API 不变，消费方零改动。
 *}

unit nextpas.core.agent.transport.http;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.intf,
  nextpas.core.http.intf;

function NewHttpTransport(const AProviderName: string): IAgentTransport;
function NewHttpTransportWithClient(const AProviderName: string;
  const AClient: IHttpClient): IAgentTransport;

implementation

uses
  nextpas.core.http.client,
  nextpas.core.agent.base,
  nextpas.core.agent.transport.http.core,
  nextpas.core.agent.transport.http.stream;

type
  THttpTransport = class(TInterfacedObject, IAgentTransport)
  private
    FProvider: string;
    FClient: IHttpClient;
  public
    constructor Create(const AProviderName: string;
      const AClient: IHttpClient);
    procedure RoundTrip(const AReq: TWireRequest; out AResp: TWireResponse);
    function OpenStream(const AReq: TWireRequest): IAgentWireStream;
  end;

constructor THttpTransport.Create(const AProviderName: string;
  const AClient: IHttpClient);
begin
  inherited Create;
  FProvider := AProviderName;
  FClient := AClient;
end;

procedure THttpTransport.RoundTrip(const AReq: TWireRequest;
  out AResp: TWireResponse);
begin
  CoreRoundTrip(FProvider, FClient, AReq, AResp);
end;

function THttpTransport.OpenStream(
  const AReq: TWireRequest): IAgentWireStream;
begin
  Result := NewWireStream(FProvider, FClient, AReq);
end;

function NewHttpTransportWithClient(const AProviderName: string;
  const AClient: IHttpClient): IAgentTransport;
begin
  Result := THttpTransport.Create(AProviderName, AClient);
end;

function NewHttpTransport(const AProviderName: string): IAgentTransport;
begin
  Result := NewHttpTransportWithClient(AProviderName, NewHttpClient);
end;

end.

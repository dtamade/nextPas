unit nextpas.core.http.transports;
{**
 * @desc HTTP transports facade. Pure re-export of server/client factories and
 *       client fetch helpers (Get/Post, ensure success, decode, body helpers).
 *       Owners (`nextpas.core.http.server`/`client`/`base`, `nextpas.core.net.server`,
 *       `nextpas.core.bytes.ops` single source) retain logic; facade only aggregates
 *       via inline thin forwarding. Thin consumers needing only transports should
 *       `uses nextpas.core.http.transports`; full surface remains `uses nextpas.core.http`.
 *
 *       Performance: inline thin forwarding (const string/TBytes/ IClient const),
 *       real loops/SIMD stay out-of-line per design-conventions; bytes.ops single
 *       source stays in owners (e.g. `CanonicalPoolHostKey`, header compare). Zero-copy
 *       views where applicable (TByteSpan, body Bytes reference without copy when possible).
 *       Stability: resource release via owner (`try/finally`/`Close`/`PoolClear`/`HttpReleaseResponseBody`);
 *       facade adds no ownership. CONTRACT is truth, missing capability → back-feed owner.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.server,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.json;

type
  THttpServer = nextpas.core.http.server.THttpServer;
  THttpServerOptions = nextpas.core.http.base.THttpServerOptions;
  THttpClient = nextpas.core.http.client.THttpClient;
  THttpClientOptions = nextpas.core.http.base.THttpClientOptions;
  THttpDialFunc = nextpas.core.http.base.THttpDialFunc;
  TTcpServerBackend = nextpas.core.http.base.TTcpServerBackend;
  IJsonDocument = nextpas.core.json.IJsonDocument;

function DefaultTcpServerBackend: TTcpServerBackend; inline;
function TcpServerBackendName(const ABackend: TTcpServerBackend): string; inline;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport): IHttpServer; overload; inline;
function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport;
  const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler): IHttpServer; overload; inline;
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions): IHttpServer; overload; inline;
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  AArenaCapacity: SizeUInt): IHttpServer; overload; inline;
function NewHttpServerWithRequestArena(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions; AArenaCapacity: SizeUInt): IHttpServer; overload; inline;

function NewHttpClient: IHttpClient; overload; inline;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient; overload; inline;
function NewHttpClient(const ATransport: IHttpTransport): IHttpClient; overload; inline;
function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient; overload; inline;

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64; inline;
function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64; inline;
procedure HttpReleaseResponseBody(const AResp: IHttpResponse); inline;
function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes; inline;
function HttpReadResponseBodyString(const AResp: IHttpResponse): string; inline;
function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string; inline;
function HttpDecodeContentEncoding(const AEncoding: string;
  const ABody: TBytes; const AMaxSize: Int64 = 0): TBytes; inline;
function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64 = 0): TBytes; inline;
function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64 = 0): string; inline;
function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse; overload; inline;
function HttpEnsureSuccess(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IHttpResponse; overload; inline;
function HttpGetString(const AClient: IHttpClient; const AUrl: string): string; inline;
function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes; inline;
function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument; overload; inline;
function HttpReadResponseJson(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IJsonDocument; overload; inline;
function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument; inline;
function HttpPostString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string; inline;
function HttpPutString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string; inline;
function HttpPatchString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string; inline;
function HttpDeleteString(const AClient: IHttpClient;
  const AUrl: string): string; inline;
function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse; inline;
function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse; inline;
function HttpPostJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpPutJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpPatchJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpDeleteJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpPostJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
function HttpPutJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
function HttpPatchJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
function ExtractCharsetFromContentType(const AContentType: string): string; inline;

implementation

function DefaultTcpServerBackend: TTcpServerBackend;
begin
  Result := nextpas.core.net.server.DefaultTcpServerBackend;
end;

function TcpServerBackendName(const ABackend: TTcpServerBackend): string;
begin
  Result := nextpas.core.net.server.TcpServerBackendName(ABackend);
end;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler);
end;

function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler, AOptions);
end;

function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler, ATransport);
end;

function NewHttpServer(const AHandler: IHttpHandler; const ATransport: IHttpServerTransport; const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := nextpas.core.http.server.NewHttpServer(AHandler, ATransport, AOptions);
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := NewHttpServer(AHandler, THttpServerOptions.Production.WithRequestArena);
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := NewHttpServer(AHandler, AOptions.WithRequestArena);
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler; AArenaCapacity: SizeUInt): IHttpServer;
begin
  Result := NewHttpServer(AHandler, THttpServerOptions.Production.WithRequestArena(AArenaCapacity));
end;

function NewHttpServerWithRequestArena(const AHandler: IHttpHandler; const AOptions: THttpServerOptions; AArenaCapacity: SizeUInt): IHttpServer;
begin
  Result := NewHttpServer(AHandler, AOptions.WithRequestArena(AArenaCapacity));
end;

function NewHttpClient: IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient;
end;

function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient(AOptions);
end;

function NewHttpClient(const ATransport: IHttpTransport): IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient(ATransport);
end;

function NewHttpClient(const ATransport: IHttpTransport; const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := nextpas.core.http.client.NewHttpClient(ATransport, AOptions);
end;

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string; const ADest: IWriter): Int64;
begin
  Result := nextpas.core.http.client.HttpGetToWriter(AClient, AUrl, ADest);
end;

function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
begin
  Result := nextpas.core.http.client.HttpGetToFile(AClient, AUrl, ADestPath);
end;

procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
begin
  nextpas.core.http.client.HttpReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyBytes(AResp);
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyString(AResp);
end;

function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyStringAuto(AResp);
end;

function HttpDecodeContentEncoding(const AEncoding: string; const ABody: TBytes; const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.client.HttpDecodeContentEncoding(AEncoding, ABody, AMaxSize);
end;

function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse; const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyBytesDecoded(AResp, AMaxSize);
end;

function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse; const AMaxSize: Int64): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyStringDecoded(AResp, AMaxSize);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpEnsureSuccess(AResp);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse; const AMethod, AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpEnsureSuccess(AResp, AMethod, AUrl);
end;

function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.HttpGetString(AClient, AUrl);
end;

function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
begin
  Result := nextpas.core.http.client.HttpGetBytes(AClient, AUrl);
end;

function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpReadResponseJson(AResp);
end;

function HttpReadResponseJson(const AResp: IHttpResponse; const AMethod, AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpReadResponseJson(AResp, AMethod, AUrl);
end;

function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpGetJson(AClient, AUrl);
end;

function HttpPostString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPostString(AClient, AUrl, AContentType, ABody);
end;

function HttpPutString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPutString(AClient, AUrl, AContentType, ABody);
end;

function HttpPatchString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPatchString(AClient, AUrl, AContentType, ABody);
end;

function HttpDeleteString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.HttpDeleteString(AClient, AUrl);
end;

function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpHead(AClient, AUrl);
end;

function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpOptions(AClient, AUrl);
end;

function HttpPostJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpPostJson(AClient, AUrl, ABody);
end;

function HttpPutJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpPutJson(AClient, AUrl, ABody);
end;

function HttpPatchJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpPatchJson(AClient, AUrl, ABody);
end;

function HttpDeleteJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpDeleteJson(AClient, AUrl, ABody);
end;

function HttpPostJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpPostJsonDocument(AClient, AUrl, ABody);
end;

function HttpPutJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpPutJsonDocument(AClient, AUrl, ABody);
end;

function HttpPatchJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpPatchJsonDocument(AClient, AUrl, ABody);
end;

function ExtractCharsetFromContentType(const AContentType: string): string;
begin
  Result := nextpas.core.http.client.ExtractCharsetFromContentType(AContentType);
end;

end.

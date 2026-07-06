# nextpas.core.http API 参考

## 门面

```pascal
uses nextpas.core.http;
```

所有公共类型和函数通过门面单元导出。

---

## 基础类型

### THttpMethod

```pascal
THttpMethod = (hmGet, hmHead, hmPost, hmPut, hmDelete, hmPatch, hmOptions);
```

### THttpVersion

```pascal
THttpVersion = (hv10, hv11, hv20);
```

### TUrl

```pascal
TUrl = record
  Scheme: string;    // 'http', 'https'
  Host: string;      // 'example.com'
  Port: UInt16;      // 0 = default
  Path: string;      // '/api/users'
  Query: string;     // 'id=123'
  Fragment: string;  // '#section'
  function HostPort: string;
end;
```

---

## 接口

### IHttpHeaders

```pascal
IHttpHeaders = interface
  function Get(const AName: string): string;
  function Has(const AName: string): Boolean;
  procedure Set_(const AName, AValue: string);
  procedure Add(const AName, AValue: string);
  procedure Del(const AName: string);
  function Count: Integer;
  function Names: TArray<string>;
end;
```

### IHttpRequest

```pascal
IHttpRequest = interface
  function Method: THttpMethod;
  function Url: TUrl;
  function Headers: IHttpHeaders;
  function Body: IReader;
  function ContentLength: Int64;
end;
```

### IHttpResponse

```pascal
IHttpResponse = interface
  function StatusCode: UInt16;
  function Headers: IHttpHeaders;
  function Body: IReader;
  function ContentLength: Int64;
end;
```

### IHttpHandler

```pascal
IHttpHandler = interface
  function Handle(const AReq: IHttpRequest): IHttpResponse;
end;
```

### IHttpMiddleware

```pascal
IHttpMiddleware = interface
  procedure BeforeRequest(const AReq: IHttpRequest);
  procedure AfterResponse(const AResp: IHttpResponse);
  procedure OnError(const AErr: Exception);
end;
```

### IHttpRouter

```pascal
IHttpRouter = interface
  procedure Get(const APath: string; AHandler: IHttpHandler);
  procedure Post(const APath: string; AHandler: IHttpHandler);
  procedure Put(const APath: string; AHandler: IHttpHandler);
  procedure Delete(const APath: string; AHandler: IHttpHandler);
  procedure Patch(const APath: string; AHandler: IHttpHandler);
  procedure Use(AMiddleware: IHttpMiddleware);
  procedure Group(const APrefix: string; ASetup: TProc<IHttpRouter>);
end;
```

### IHttpClient

```pascal
IHttpClient = interface
  function Get(const AUrl: string): IHttpResponse;
  function Post(const AUrl: string; const ABody: TBytes): IHttpResponse;
  function Put(const AUrl: string; const ABody: TBytes): IHttpResponse;
  function Delete(const AUrl: string): IHttpResponse;
  function Patch(const AUrl: string; const ABody: TBytes): IHttpResponse;
  function Send(const AReq: IHttpRequest): IHttpResponse;
  procedure CloseIdleConnections;
end;
```

### IHttpServer

```pascal
IHttpServer = interface
  procedure Get(const APath: string; AHandler: IHttpHandler);
  procedure Post(const APath: string; AHandler: IHttpHandler);
  procedure Use(AMiddleware: IHttpMiddleware);
  procedure ListenAndServe;
  procedure Close;
end;
```

---

## 工厂函数

### NewHttpClient

```pascal
function NewHttpClient: IHttpClient;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
```

### NewHttpServer

```pascal
function NewHttpServer(APort: UInt16): IHttpServer;
function NewHttpServer(APort: UInt16; const AOptions: THttpServerOptions): IHttpServer;
```

### NewHttpResponse

```pascal
function NewHttpResponse(AStatusCode: UInt16; const ABody: string): IHttpResponse;
function NewHttpResponse(AStatusCode: UInt16; const ABody: TBytes): IHttpResponse;
function NewHttpResponse(AStatusCode: UInt16; AHeaders: IHttpHeaders; ABody: IReader): IHttpResponse;
```

### NewHttpRequest

```pascal
function NewHttpRequest(AMethod: THttpMethod; const AUrl: string): IHttpRequest;
function NewHttpRequest(AMethod: THttpMethod; const AUrl: string; const ABody: TBytes): IHttpRequest;
```

---

## 辅助函数

### Body 读取

```pascal
function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
procedure HttpGetToWriter(const AResp: IHttpResponse; const AWriter: IWriter);
procedure HttpGetToFile(const AResp: IHttpResponse; const APath: string);
```

### Header 辅助

```pascal
function NewHttpHeaders: IHttpHeaders;
function NewHttpHeaders(const APairs: array of string): IHttpHeaders;
```

---

## 中间件

### CORS

```pascal
function NewCorsMiddleware(const AOrigins: array of string): IHttpMiddleware;
function NewCorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;
```

### Logger

```pascal
function NewLoggerMiddleware: IHttpMiddleware;
function NewLoggerMiddleware(ALogger: ILogger): IHttpMiddleware;
```

### Recovery

```pascal
function NewRecoveryMiddleware: IHttpMiddleware;
```

### Timeout

```pascal
function NewTimeoutMiddleware(AMs: UInt32): IHttpMiddleware;
```

---

## 静态文件

```pascal
function NewStaticFileHandler(const ARoot: string): IHttpHandler;
function NewStaticFileHandler(const ARoot: string; const AOptions: TStaticFileOptions): IHttpHandler;
```

---

## WebSocket

```pascal
function NewWebSocketHandler(AOnMessage: TWebSocketMessageHandler): IHttpHandler;
function NewWebSocketHandler(const AOptions: TWebSocketOptions): IHttpHandler;
```

---

## 错误类型

```pascal
EHttpError = class(Exception);           // HTTP 协议错误
EHttpParseError = class(EHttpError);     // 解析错误
EHttpTimeout = class(EHttpError);        // 超时
EHttpRedirect = class(EHttpError);       // 重定向错误
```

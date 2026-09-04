unit nextpas.core.http.middlewares;
{**
 * @desc HTTP middleware family facade. Pure re-export of product
 *       middleware factories (cors/recovery/logger/.../hsts) via inline
 *       zero-copy forwarding. Owner modules retain logic; this unit only
 *       aggregates. Consumers needing only router/server/client should use
 *       `nextpas.core.http`; those needing middleware use this facade
 *       (or the full `nextpas.core.http` umbrella if still desired).
 *
 *       Performance: inline thin forwarding (const string/TBytes), real
 *       loops/SIMD stay out-of-line per design-conventions. Bytes reuse
 *       `nextpas.core.bytes.ops` single source in owner impl.
 *       Stability: resource release via owner (try/finally); facade adds
 *       no ownership. CONTRACT is truth.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.auth,
  nextpas.core.http.middleware.cors,
  nextpas.core.http.middleware.recovery,
  nextpas.core.http.middleware.responsetime,
  nextpas.core.http.middleware.bodylimit,
  nextpas.core.http.middleware.contenttype,
  nextpas.core.http.middleware.logger,
  nextpas.core.http.middleware.requestid,
  nextpas.core.http.middleware.cachecontrol,
  nextpas.core.http.middleware.ratelimit,
  nextpas.core.http.middleware.healthcheck,
  nextpas.core.http.middleware.metrics,
  nextpas.core.http.middleware.methodguard,
  nextpas.core.http.middleware.bodycache,
  nextpas.core.http.middleware.serverheader,
  nextpas.core.http.middleware.context,
  nextpas.core.http.middleware.requestarena,
  nextpas.core.http.middleware.compression,
  nextpas.core.http.middleware.decompress,
  nextpas.core.http.middleware.deadline,
  nextpas.core.http.middleware.hsts,
  nextpas.core.http.mem,
  nextpas.core.http.router,
  nextpas.core.thread.intf,
  nextpas.core.log,
  nextpas.core.http.message;

type
  TMiddlewareWrapFunc = nextpas.core.http.middleware.TMiddlewareWrapFunc;
  TRequestPredicate = nextpas.core.http.middleware.TRequestPredicate;
  TRecoveryCallback = nextpas.core.http.middleware.recovery.TRecoveryCallback;
  TRateLimitOptions = nextpas.core.http.middleware.ratelimit.TRateLimitOptions;
  TAuthOptions = nextpas.core.http.middleware.auth.TAuthOptions;
  TAuthValidatorFunc = nextpas.core.http.middleware.auth.TAuthValidatorFunc;
  TAuthCredentialKind = nextpas.core.http.middleware.auth.TAuthCredentialKind;
  TRequestIdGenerator = nextpas.core.http.middleware.requestid.TRequestIdGenerator;
  TCorsOptions = nextpas.core.http.middleware.cors.TCorsOptions;
  THttpMetrics = nextpas.core.http.middleware.metrics.THttpMetrics;
  IHttpMetricsCollector = nextpas.core.http.middleware.metrics.IHttpMetricsCollector;
  THttpMetricsCallback = nextpas.core.http.middleware.metrics.THttpMetricsCallback;
  THttpMetricsFieldsCallback = nextpas.core.http.middleware.metrics.THttpMetricsFieldsCallback;
  THstsOptions = nextpas.core.http.middleware.hsts.THstsOptions;
  IArena = nextpas.core.http.mem.IArena;
  IAllocator = nextpas.core.http.mem.IAllocator;
  TGrowingAllocator = nextpas.core.http.mem.TGrowingAllocator;
  IHttpContext = nextpas.core.http.intf.IHttpContext;
  TLogger = nextpas.core.log.TLogger;
  TLogExtrasProvider = nextpas.core.http.middleware.logger.TLogExtrasProvider;

const
  HTTP_DEFAULT_REQUEST_ARENA = nextpas.core.http.mem.HTTP_DEFAULT_REQUEST_ARENA;
  HTTP_DEFAULT_BODY_READ_MAX = nextpas.core.http.base.HTTP_DEFAULT_BODY_READ_MAX;
  AUTH_SUBJECT_KEY = nextpas.core.http.middleware.auth.AUTH_SUBJECT_KEY;

{ Chain primitives }
function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler; overload; inline;
function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler; overload; inline;
function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler; overload; inline;
function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware; inline;
function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
function WhenMiddleware(const APredicate: TRequestPredicate; const AMiddleware: IHttpMiddleware): IHttpMiddleware;
function AsyncMiddleware(const APool: IThreadPool): IHttpMiddleware; inline;

{ Product middleware }
function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware; inline;
function RecoveryMiddleware: IHttpMiddleware; inline;
function RecoveryMiddlewareWith(const AOnError: TRecoveryCallback): IHttpMiddleware; inline;
function ResponseTimeMiddleware: IHttpMiddleware; inline;
function BodyLimitMiddleware(const AMaxBytes: Int64): IHttpMiddleware; inline;
function ContentTypeMiddleware(const AAccepted: array of string): IHttpMiddleware; inline;
function LoggerMiddleware: IHttpMiddleware; inline;
function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware; inline;
function LoggerMiddlewareWithExtras(const AExtras: TLogExtrasProvider): IHttpMiddleware; inline;
function LoggerMiddlewareWithExtrasAndLogger(const AExtras: TLogExtrasProvider; const ALogger: TLogger): IHttpMiddleware; inline;
function RequestIdMiddleware: IHttpMiddleware; inline;
function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware; inline;
function RequestIdMiddlewareWithGenerator(const AHeaderName: string; const AGenerator: TRequestIdGenerator): IHttpMiddleware; inline;
function CacheControlMiddleware(const AValue: string): IHttpMiddleware; inline;
function NoCacheMiddleware: IHttpMiddleware; inline;
function MaxAgeMiddleware(const ASeconds: Int64): IHttpMiddleware; inline;
function RateLimitMiddleware: IHttpMiddleware; inline;
function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware; inline;
function AuthMiddleware(const AOptions: TAuthOptions): IHttpMiddleware; inline;
function AuthMiddlewareWithValidator(const AValidator: TAuthValidatorFunc): IHttpMiddleware; inline;
function HealthCheckMiddleware: IHttpMiddleware; inline;
function HealthCheckMiddlewareAt(const APath: string): IHttpMiddleware; inline;
function NewHttpMetricsCollector: IHttpMetricsCollector; inline;
function MetricsMiddleware(const ACollector: IHttpMetricsCollector): IHttpMiddleware; inline;
function MetricsMiddlewareWith(const ACallback: THttpMetricsCallback): IHttpMiddleware; inline;
function MethodGuardMiddleware(const AAllowed: array of THttpMethod): IHttpMiddleware; inline;
function BodyCacheMiddleware: IHttpMiddleware; inline;
function BodyCacheMiddlewareWith(const AMaxBytes: Int64): IHttpMiddleware; inline;
function BodyCacheMiddlewareUnlimited: IHttpMiddleware; inline;
function MetricsMiddlewareWithFields(const ACallback: THttpMetricsFieldsCallback): IHttpMiddleware; inline;
function ServerHeaderMiddleware: IHttpMiddleware; inline;
function ServerHeaderMiddlewareWith(const ACustomName: string): IHttpMiddleware; inline;
function ContextMiddleware: IHttpMiddleware; inline;
function NewHttpContext: IHttpContext; inline;
function HttpContextOf(const AReq: IHttpRequest): IHttpContext; inline;
function HttpContextGetString(const ACtx: IHttpContext; const AKey: string): string; inline;
procedure HttpContextSetString(const ACtx: IHttpContext; const AKey, AValue: string); inline;
function HttpContextGetInt64(const ACtx: IHttpContext; const AKey: string): Int64; inline;
procedure HttpContextSetInt64(const ACtx: IHttpContext; const AKey: string; const AValue: Int64); inline;
function RequestArenaMiddleware: IHttpMiddleware; inline;
function RequestArenaMiddlewareWith(ACapacity: SizeUInt): IHttpMiddleware; inline;
function HttpRequestArenaOf(const AReq: IHttpRequest): IArena; inline;
function HttpRequestAllocatorOf(const AReq: IHttpRequest): IAllocator; inline;
procedure HttpUseRequestArena(const ARouter: IHttpRouter; ACapacity: SizeUInt = 0); inline;
function HttpWithRequestArena(const AHandler: IHttpHandler; ACapacity: SizeUInt = 0): IHttpHandler; inline;
function CompressionMiddleware: IHttpMiddleware; inline;
function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware; inline;
function DecompressMiddleware(const AMaxSize: Int64 = HTTP_DEFAULT_BODY_READ_MAX): IHttpMiddleware; inline;
function DecompressMiddlewareUnlimited: IHttpMiddleware; inline;
function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware; inline;
function DeadlineMiddlewareWith(ATimeoutMs: Int64; const AMaxBufferBytes: Int64): IHttpMiddleware; inline;
function DeadlineMiddlewareUnlimitedBuffer(ATimeoutMs: Int64): IHttpMiddleware; inline;
function HstsMiddleware: IHttpMiddleware; inline;
function HstsMiddlewareWith(const AOptions: THstsOptions): IHttpMiddleware; inline;

{ Request-scoped mem helpers }
function HttpCreateRequestArena(ACapacity: SizeUInt = 0): IArena; inline;
function HttpCreateRequestAllocator(ACapacity: SizeUInt = 0): IAllocator; inline;
function HttpProcessHeap: TGrowingAllocator; inline;
function HttpProcessAllocator: IAllocator; inline;
function HttpFormatProcessMemStats: string; inline;

implementation

function HandlerFunc(const AFunc: THttpHandlerFunc): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.HandlerFunc(AFunc);
end;

function HandlerFunc(const AMethod: THttpHandlerMethod): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.HandlerFunc(AMethod);
end;

function HandlerFunc(const AProc: THttpHandlerProc): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.HandlerFunc(AProc);
end;

function MiddlewareFunc(const AWrapFunc: TMiddlewareWrapFunc): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.MiddlewareFunc(AWrapFunc);
end;

function Chain(const AHandler: IHttpHandler; const AMiddlewares: array of IHttpMiddleware): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.Chain(AHandler, AMiddlewares);
end;

function WhenMiddleware(const APredicate: TRequestPredicate; const AMiddleware: IHttpMiddleware): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.WhenMiddleware(APredicate, AMiddleware);
end;

function AsyncMiddleware(const APool: IThreadPool): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.AsyncMiddleware(APool);
end;

function CorsMiddleware(const AOptions: TCorsOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.cors.CorsMiddleware(AOptions);
end;

function RecoveryMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.recovery.RecoveryMiddleware;
end;

function RecoveryMiddlewareWith(const AOnError: TRecoveryCallback): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.recovery.RecoveryMiddlewareWith(AOnError);
end;

function ResponseTimeMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.responsetime.ResponseTimeMiddleware;
end;

function BodyLimitMiddleware(const AMaxBytes: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.bodylimit.BodyLimitMiddleware(AMaxBytes);
end;

function ContentTypeMiddleware(const AAccepted: array of string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.contenttype.ContentTypeMiddleware(AAccepted);
end;

function LoggerMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.logger.LoggerMiddleware;
end;

function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.logger.LoggerMiddlewareWith(ALogger);
end;

function LoggerMiddlewareWithExtras(const AExtras: TLogExtrasProvider): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.logger.LoggerMiddlewareWithExtras(AExtras);
end;

function LoggerMiddlewareWithExtrasAndLogger(const AExtras: TLogExtrasProvider; const ALogger: TLogger): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.logger.LoggerMiddlewareWithExtrasAndLogger(AExtras, ALogger);
end;

function RequestIdMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.requestid.RequestIdMiddleware;
end;

function RequestIdMiddlewareWith(const AHeaderName: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.requestid.RequestIdMiddlewareWith(AHeaderName);
end;

function RequestIdMiddlewareWithGenerator(const AHeaderName: string; const AGenerator: TRequestIdGenerator): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.requestid.RequestIdMiddlewareWithGenerator(AHeaderName, AGenerator);
end;

function CacheControlMiddleware(const AValue: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.cachecontrol.CacheControlMiddleware(AValue);
end;

function NoCacheMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.cachecontrol.NoCacheMiddleware;
end;

function MaxAgeMiddleware(const ASeconds: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.cachecontrol.MaxAgeMiddleware(ASeconds);
end;

function RateLimitMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.ratelimit.RateLimitMiddleware;
end;

function RateLimitMiddlewareWith(const AOptions: TRateLimitOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.ratelimit.RateLimitMiddlewareWith(AOptions);
end;

function AuthMiddleware(const AOptions: TAuthOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.auth.AuthMiddleware(AOptions);
end;

function AuthMiddlewareWithValidator(const AValidator: TAuthValidatorFunc): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.auth.AuthMiddlewareWithValidator(AValidator);
end;

function HealthCheckMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.healthcheck.HealthCheckMiddleware;
end;

function HealthCheckMiddlewareAt(const APath: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.healthcheck.HealthCheckMiddlewareAt(APath);
end;

function NewHttpMetricsCollector: IHttpMetricsCollector;
begin
  Result := nextpas.core.http.middleware.metrics.NewHttpMetricsCollector;
end;

function MetricsMiddleware(const ACollector: IHttpMetricsCollector): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.metrics.MetricsMiddleware(ACollector);
end;

function MetricsMiddlewareWith(const ACallback: THttpMetricsCallback): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.metrics.MetricsMiddlewareWith(ACallback);
end;

function MethodGuardMiddleware(const AAllowed: array of THttpMethod): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.methodguard.MethodGuardMiddleware(AAllowed);
end;

function BodyCacheMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.bodycache.BodyCacheMiddleware;
end;

function BodyCacheMiddlewareWith(const AMaxBytes: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.bodycache.BodyCacheMiddlewareWith(AMaxBytes);
end;

function BodyCacheMiddlewareUnlimited: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.bodycache.BodyCacheMiddlewareUnlimited;
end;

function MetricsMiddlewareWithFields(const ACallback: THttpMetricsFieldsCallback): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.metrics.MetricsMiddlewareWithFields(ACallback);
end;

function ServerHeaderMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.serverheader.ServerHeaderMiddleware;
end;

function ServerHeaderMiddlewareWith(const ACustomName: string): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.serverheader.ServerHeaderMiddlewareWith(ACustomName);
end;

function ContextMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.context.ContextMiddleware;
end;

function NewHttpContext: IHttpContext;
begin
  Result := nextpas.core.http.middleware.context.NewHttpContext;
end;

function HttpContextOf(const AReq: IHttpRequest): IHttpContext;
begin
  Result := nextpas.core.http.middleware.context.HttpContextOf(AReq);
end;

function HttpContextGetString(const ACtx: IHttpContext; const AKey: string): string;
begin
  Result := nextpas.core.http.middleware.context.HttpContextGetString(ACtx, AKey);
end;

procedure HttpContextSetString(const ACtx: IHttpContext; const AKey, AValue: string);
begin
  nextpas.core.http.middleware.context.HttpContextSetString(ACtx, AKey, AValue);
end;

function HttpContextGetInt64(const ACtx: IHttpContext; const AKey: string): Int64;
begin
  Result := nextpas.core.http.middleware.context.HttpContextGetInt64(ACtx, AKey);
end;

procedure HttpContextSetInt64(const ACtx: IHttpContext; const AKey: string; const AValue: Int64);
begin
  nextpas.core.http.middleware.context.HttpContextSetInt64(ACtx, AKey, AValue);
end;

function RequestArenaMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.requestarena.RequestArenaMiddleware;
end;

function RequestArenaMiddlewareWith(ACapacity: SizeUInt): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.requestarena.RequestArenaMiddlewareWith(ACapacity);
end;

function HttpRequestArenaOf(const AReq: IHttpRequest): IArena;
begin
  Result := nextpas.core.http.middleware.requestarena.HttpRequestArenaOf(AReq);
end;

function HttpRequestAllocatorOf(const AReq: IHttpRequest): IAllocator;
begin
  Result := nextpas.core.http.middleware.requestarena.HttpRequestAllocatorOf(AReq);
end;

procedure HttpUseRequestArena(const ARouter: IHttpRouter; ACapacity: SizeUInt);
begin
  if ARouter = nil then
    raise EHttpError.Create(hekArgument, 'HttpUseRequestArena: router must not be nil');
  if ACapacity = 0 then
    ARouter.Use(RequestArenaMiddleware)
  else
    ARouter.Use(RequestArenaMiddlewareWith(ACapacity));
end;

function HttpWithRequestArena(const AHandler: IHttpHandler; ACapacity: SizeUInt): IHttpHandler;
begin
  Result := nextpas.core.http.middleware.requestarena.HttpWithRequestArena(AHandler, ACapacity);
end;

function CompressionMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.compression.CompressionMiddleware;
end;

function CompressionMiddlewareWith(AMinSize: SizeUInt): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.compression.CompressionMiddlewareWith(AMinSize);
end;

function DecompressMiddleware(const AMaxSize: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.decompress.DecompressMiddleware(AMaxSize);
end;

function DecompressMiddlewareUnlimited: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.decompress.DecompressMiddlewareUnlimited;
end;

function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorUnsupportedMediaType(AW, AMessage);
end;

function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorGatewayTimeout(AW, AMessage);
end;

function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.deadline.DeadlineMiddleware(ATimeoutMs);
end;

function DeadlineMiddlewareWith(ATimeoutMs: Int64; const AMaxBufferBytes: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.deadline.DeadlineMiddlewareWith(ATimeoutMs, AMaxBufferBytes);
end;

function DeadlineMiddlewareUnlimitedBuffer(ATimeoutMs: Int64): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.deadline.DeadlineMiddlewareUnlimitedBuffer(ATimeoutMs);
end;

function HstsMiddleware: IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.hsts.HstsMiddleware;
end;

function HstsMiddlewareWith(const AOptions: THstsOptions): IHttpMiddleware;
begin
  Result := nextpas.core.http.middleware.hsts.HstsMiddlewareWith(AOptions);
end;

function HttpCreateRequestArena(ACapacity: SizeUInt): IArena;
begin
  Result := nextpas.core.http.mem.HttpCreateRequestArena(ACapacity);
end;

function HttpCreateRequestAllocator(ACapacity: SizeUInt): IAllocator;
begin
  Result := nextpas.core.http.mem.HttpCreateRequestAllocator(ACapacity);
end;

function HttpProcessHeap: TGrowingAllocator;
begin
  Result := nextpas.core.http.mem.HttpProcessHeap;
end;

function HttpProcessAllocator: IAllocator;
begin
  Result := nextpas.core.http.mem.HttpProcessAllocator;
end;

function HttpFormatProcessMemStats: string;
begin
  Result := nextpas.core.http.mem.HttpFormatProcessMemStats;
end;

end.

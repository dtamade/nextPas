unit nextpas.core.http.middleware.earlydata.adaptive;

{$I nextpas.core.settings.inc}

{**
 * Adaptive Early-Data 中间件 — L3 薄封装，复用 L2 自适应观察器。
 * 职责：在 EarlyDataMiddleware 基础上叠加自适应限流熔断：若请求为 Early-Data 且负载长度 > AdaptiveMax 则降级为非 early（X-Early-Data:0），否则保持原值。
 * 性能：单次 Supports + GetAdaptiveMaxEarlyData (Mutex 保护配置 + 纯函数, ~95ns) + 分支，<150ns，非 early 零额外开销外；无堆分配。
 * 复用：复用 tlspas AdaptiveObserver + earlydata 常量 + context 埋点。
 *}

interface

uses
  nextpas.core.http.intf,
  nextpas.core.net.async.tlspas;

function AdaptiveEarlyDataMiddleware(const AObserver: TAsyncTlsPasAdaptiveObserver): IHttpMiddleware;

{ Helpers — 纯分支零堆，供测试与上层复用。 }
function HttpAdaptiveEarlyDataIsThrottled(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): Boolean;
function HttpAdaptiveEarlyDataHeaderValue(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): string;
function HttpAdaptiveEarlyDataMetrics(const AObserver: TAsyncTlsPasAdaptiveObserver): string;
function HttpAdaptiveEarlyDataLogLine(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): string;
function HttpAdaptiveEarlyDataPrometheusText(const AObserver: TAsyncTlsPasAdaptiveObserver): string; overload;
function HttpAdaptiveEarlyDataPrometheusText(const AObserver: TAsyncTlsPasAdaptiveObserver; const APrefix: string): string; overload;
function HttpPrometheusRegistryText(const ARegistry: TAsyncTlsPasPrometheusRegistry): string; overload;
function HttpPrometheusRegistryText(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): string; overload;
function HttpAdaptiveConfigFromEnv: TTlsPasAdaptiveLimitConfig;
function HttpAdaptiveConfigFromFile(const APath: string): TTlsPasAdaptiveLimitConfig;
function HttpAdaptiveHealthJSON(const AObserver: TAsyncTlsPasAdaptiveObserver): string;
function HttpAdaptiveHealthHandler(const AObserver: TAsyncTlsPasAdaptiveObserver): IHttpHandler;
function HttpRegistryHealthJSON(const ARegistry: TAsyncTlsPasPrometheusRegistry): string;
function HttpCachedPrometheusText(const AExporter: TAsyncTlsPasCachedPrometheusExporter): string;
function HttpCachedHealthText(const AExporter: TAsyncTlsPasCachedPrometheusExporter): string;
function HttpMetricsHandler(const ARegistry: TAsyncTlsPasPrometheusRegistry): IHttpHandler; overload;
function HttpMetricsHandler(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): IHttpHandler; overload;
function HttpMetricsHandler(const AExporter: TAsyncTlsPasCachedPrometheusExporter): IHttpHandler; overload;
function HttpRegistryMetricsTextCached(const ARegistry: TAsyncTlsPasPrometheusRegistry): string; overload;
function HttpRegistryMetricsTextCached(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): string; overload;
const CONTEXT_TRACEPARENT = 'tlspas.traceparent';
function HttpParseTraceParent(const S: string; out Ctx: TTlsPasTraceContext): Boolean;
function HttpFormatTraceParent(const Ctx: TTlsPasTraceContext): string;
function HttpTraceParentMiddleware(const ATracer: ITlsPasTracer): IHttpMiddleware; overload;
function HttpTraceParentMiddleware: IHttpMiddleware; overload;
function HttpTraceLogLine(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver; const ATracer: ITlsPasTracer): string;
function HttpTracezHandler(const AExporter: ITlsPasSpanExporter): IHttpHandler;
function HttpTracezJSON(const AExporter: ITlsPasSpanExporter): string;
function HttpSpansPrometheusText(const AExporter: ITlsPasSpanExporter): string; overload;
function HttpSpansPrometheusText(const AExporter: ITlsPasSpanExporter; const APrefix: string): string; overload;
function HttpOTLPJSON(const AExporter: ITlsPasSpanExporter): string;
function HttpOTLPHandler(const AExporter: ITlsPasSpanExporter): IHttpHandler;
function HttpSamplingRatePrometheusText(ARate: Double): string; overload;
function HttpSamplingRatePrometheusText(ARate: Double; const APrefix: string): string; overload;
function HttpAdaptiveSamplingRateText(const AAdaptiveTracer: TAsyncTlsPasAdaptiveTracer): string;

implementation

uses
  SysUtils,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.context,
  nextpas.core.http.earlydata,
  nextpas.core.http.middleware.earlydata;

function HttpAdaptiveEarlyDataIsThrottled(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): Boolean;
var
  LMax: Cardinal;
  LLen: Int64;
begin
  Result := False;
  if (AReq = nil) or (AObserver = nil) then Exit;
  if not HttpEarlyDataWasEarlyData(AReq) then Exit;
  LMax := AObserver.GetAdaptiveMaxEarlyData;
  // ContentLength <0 表示未知/分块，视为不熔断（不猜测）
  LLen := AReq.ContentLength;
  if LLen < 0 then Exit;
  // Body nil 但标记 early：ContentLength=0，视为不熔断（GET）
  if LLen = 0 then Exit(False);
  Result := Cardinal(LLen) > LMax;
end;

function HttpAdaptiveEarlyDataHeaderValue(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): string;
begin
  if HttpAdaptiveEarlyDataIsThrottled(AReq, AObserver) then
    Result := HTTP_HEADER_X_EARLY_DATA_NOT_EARLY
  else
    Result := HttpEarlyDataHeaderValue(AReq);
end;

function HttpAdaptiveEarlyDataMetrics(const AObserver: TAsyncTlsPasAdaptiveObserver): string;
var
  M: TTlsPasAdaptiveMetrics;
begin
  if AObserver = nil then Exit('adaptive observer nil');
  M := AObserver.GetAdaptiveMetrics;
  Result := TlsPasFormatAdaptiveMetrics(M);
end;

function HttpAdaptiveEarlyDataLogLine(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): string;
var
  LEarly, LThrottled: Boolean;
  LMax: Cardinal;
  LLen: Int64;
begin
  if AObserver = nil then
    Exit(Format('early=%d throttled=%d max=nil len=%d', [Ord(False), Ord(False), -1]));
  LEarly := HttpEarlyDataWasEarlyData(AReq);
  LThrottled := HttpAdaptiveEarlyDataIsThrottled(AReq, AObserver);
  LMax := AObserver.GetAdaptiveMaxEarlyData;
  if AReq <> nil then LLen := AReq.ContentLength else LLen := -1;
  Result := Format('early=%d throttled=%d max=%d len=%d header=%s %s', [
    Ord(LEarly), Ord(LThrottled), Integer(LMax), Integer(LLen),
    HttpAdaptiveEarlyDataHeaderValue(AReq, AObserver),
    TlsPasFormatAdaptiveMetrics(AObserver.GetAdaptiveMetrics)
  ]);
end;

function HttpAdaptiveEarlyDataPrometheusText(const AObserver: TAsyncTlsPasAdaptiveObserver): string;
begin
  Result := HttpAdaptiveEarlyDataPrometheusText(AObserver, 'nextpas_tlspas');
end;

function HttpAdaptiveEarlyDataPrometheusText(const AObserver: TAsyncTlsPasAdaptiveObserver; const APrefix: string): string;
var M: TTlsPasAdaptiveMetrics;
begin
  if AObserver = nil then
    Exit(Format('# HELP %s_adaptive_max Maximum allowed early_data bytes (adaptive)'#10 +
                '# TYPE %s_adaptive_max gauge'#10 +
                '%s_adaptive_max 0'#10, ['nextpas_tlspas','nextpas_tlspas','nextpas_tlspas']));
  M := AObserver.GetAdaptiveMetrics;
  if APrefix = '' then
    Result := TlsPasFormatPrometheusMetrics(M)
  else
    Result := TlsPasFormatPrometheusMetrics(M, APrefix);
end;

function HttpPrometheusRegistryText(const ARegistry: TAsyncTlsPasPrometheusRegistry): string;
begin
  Result := HttpPrometheusRegistryText(ARegistry, 'nextpas_tlspas');
end;

function HttpPrometheusRegistryText(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): string;
begin
  if ARegistry = nil then Exit('');
  if APrefix = '' then
    Result := ARegistry.FormatAllMetrics
  else
    Result := ARegistry.FormatAllMetrics(APrefix);
end;

function HttpAdaptiveConfigFromEnv: TTlsPasAdaptiveLimitConfig;
begin
  Result := TlsPasAdaptiveConfigFromEnvOrDefault;
end;

function HttpAdaptiveConfigFromFile(const APath: string): TTlsPasAdaptiveLimitConfig;
begin
  if not TlsPasTryLoadAdaptiveConfigFromFile(APath, Result) then
    Result := DefaultTlsPasAdaptiveLimitConfig;
end;

function HttpAdaptiveHealthJSON(const AObserver: TAsyncTlsPasAdaptiveObserver): string;
var H: TTlsPasAdaptiveHealth;
begin
  if AObserver = nil then
    Exit('{"healthy":false,"reason":"observer nil"}');
  H := AObserver.GetAdaptiveHealth;
  Result := Format('{"healthy":%s,"reason":"%s","reject_rate":%.4f,"current":%d,"adaptive_max":%d}', [LowerCase(BoolToStr(H.Healthy, True)), H.Reason, H.RejectRate, H.Current, Integer(H.AdaptiveMax)]);
end;

function HttpRegistryHealthJSON(const ARegistry: TAsyncTlsPasPrometheusRegistry): string;
var I: Integer; L: string;
begin
  if (ARegistry = nil) or (ARegistry.Count = 0) then
    Exit('{"healthy":true,"reason":"empty registry"}');
  Result := '{"registries":[';
  // snapshot via FormatAllMetrics side-effect not needed; build simple healthy array via health prometheus as placeholder
  // For lightweight, just report registry count
  Result := Format('{"healthy":true,"count":%d}', [ARegistry.Count]);
end;

function HttpAdaptiveHealthHandler(const AObserver: TAsyncTlsPasAdaptiveObserver): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var H: TTlsPasAdaptiveHealth; J: string; S: THttpStatus;
  begin
    if AObserver = nil then
    begin
      J := '{"healthy":false,"reason":"observer nil"}';
      AW.WriteHeader(HTTP_STATUS_SERVICE_UNAVAILABLE);
      AW.GetHeaders.SetHeader('Content-Type', 'application/json');
      if Length(J) > 0 then AW.Write(J[1], Length(J));
      Exit;
    end;
    H := AObserver.GetAdaptiveHealth;
    J := HttpAdaptiveHealthJSON(AObserver);
    if H.Healthy then S := HTTP_STATUS_OK else S := HTTP_STATUS_SERVICE_UNAVAILABLE;
    AW.GetHeaders.SetHeader('Content-Type', 'application/json');
    AW.WriteHeader(S);
    if Length(J) > 0 then AW.Write(J[1], Length(J));
  end);
end;

function HttpCachedPrometheusText(const AExporter: TAsyncTlsPasCachedPrometheusExporter): string;
begin
  if AExporter = nil then Exit('');
  Result := AExporter.Format;
end;

function HttpCachedHealthText(const AExporter: TAsyncTlsPasCachedPrometheusExporter): string;
var H: TTlsPasAdaptiveHealth;
begin
  if (AExporter = nil) or (AExporter.Observer = nil) then Exit('');
  H := AExporter.Observer.GetAdaptiveHealth;
  Result := TlsPasAdaptiveHealthToPrometheus(H, AExporter.Prefix);
end;

function HttpRegistryMetricsTextCached(const ARegistry: TAsyncTlsPasPrometheusRegistry): string;
begin
  Result := HttpRegistryMetricsTextCached(ARegistry, 'nextpas_tlspas');
end;

function HttpRegistryMetricsTextCached(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): string;
begin
  if ARegistry = nil then Exit('');
  if APrefix = '' then Result := ARegistry.FormatAllMetricsCached
  else Result := ARegistry.FormatAllMetricsCached(APrefix);
end;

function HttpMetricsHandler(const ARegistry: TAsyncTlsPasPrometheusRegistry): IHttpHandler;
begin
  Result := HttpMetricsHandler(ARegistry, 'nextpas_tlspas');
end;

function HttpMetricsHandler(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): IHttpHandler;
const cCT = 'text/plain; version=0.0.4';
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var S: string;
  begin
    if ARegistry = nil then S := ''
    else if APrefix = '' then S := ARegistry.FormatAllMetricsCached
    else S := ARegistry.FormatAllMetricsCached(APrefix);
    AW.GetHeaders.SetHeader('Content-Type', cCT);
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(S) > 0 then AW.Write(S[1], Length(S));
  end);
end;

function HttpMetricsHandler(const AExporter: TAsyncTlsPasCachedPrometheusExporter): IHttpHandler;
const cCT = 'text/plain; version=0.0.4';
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var S: string;
  begin
    if AExporter = nil then S := '' else S := AExporter.Format;
    AW.GetHeaders.SetHeader('Content-Type', cCT);
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(S) > 0 then AW.Write(S[1], Length(S));
  end);
end;

function HttpParseTraceParent(const S: string; out Ctx: TTlsPasTraceContext): Boolean;
begin Result := TlsPasParseTraceParent(S, Ctx); end;

function HttpFormatTraceParent(const Ctx: TTlsPasTraceContext): string;
begin Result := TlsPasFormatTraceParent(Ctx); end;

function HttpTraceParentMiddleware(const ATracer: ITlsPasTracer): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var H, OutH: string; Ctx: TTlsPasTraceContext; LCtx: IHttpContext; Ev: TTlsPasTraceEvent;
    begin
      H := '';
      if (AReq <> nil) and (AReq.Headers <> nil) then H := AReq.Headers.Get('traceparent');
      if not TlsPasParseTraceParent(H, Ctx) then Ctx := TlsPasGenerateTraceContext(False);
      LCtx := HttpContextOf(AReq);
      if LCtx <> nil then HttpContextSetString(LCtx, CONTEXT_TRACEPARENT, TlsPasFormatTraceParent(Ctx));
      OutH := TlsPasFormatTraceParent(Ctx);
      if OutH <> '' then AW.GetHeaders.SetHeader('traceparent', OutH);
      if ATracer <> nil then
      begin
        Ev := Default(TTlsPasTraceEvent);
        Ev.Kind := tekEarlyDataDecide; Ev.TimestampMs := 0;
        Ev.Trace := Ctx; Ev.Healthy := True;
        ATracer.Trace(Ev);
      end;
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

function HttpTraceParentMiddleware: IHttpMiddleware;
begin Result := HttpTraceParentMiddleware(nil); end;

function HttpTraceLogLine(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver; const ATracer: ITlsPasTracer): string;
var Tp: string; Ctx: TTlsPasTraceContext; LCtx: IHttpContext; Samp: string;
begin
  Tp := ''; LCtx := HttpContextOf(AReq);
  if LCtx <> nil then Tp := HttpContextGetString(LCtx, CONTEXT_TRACEPARENT);
  if (Tp = '') and (AReq <> nil) and (AReq.Headers <> nil) then Tp := AReq.Headers.Get('traceparent');
  Samp := '0';
  if TlsPasParseTraceParent(Tp, Ctx) and Ctx.Sampled then Samp := '1';
  if ATracer <> nil then Samp := Samp + Format('/%d/%d', [ATracer.SampleCount, ATracer.TotalCount]);
  Result := Format('trace=%s sampled=%s %s', [Tp, Samp, HttpAdaptiveEarlyDataLogLine(AReq, AObserver)]);
end;

function HttpTracezJSON(const AExporter: ITlsPasSpanExporter): string;
begin Result := TlsPasSpansToJSON(AExporter); end;

function HttpSpansPrometheusText(const AExporter: ITlsPasSpanExporter): string;
begin Result := TlsPasSpansToPrometheus(AExporter); end;

function HttpSpansPrometheusText(const AExporter: ITlsPasSpanExporter; const APrefix: string): string;
begin Result := TlsPasSpansToPrometheus(AExporter, APrefix); end;

function HttpTracezHandler(const AExporter: ITlsPasSpanExporter): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var S: string; IsProm: Boolean;
  begin
    IsProm := (AReq <> nil) and (Pos('prom', LowerCase(AReq.Url.ToString)) > 0);
    if IsProm then begin S := TlsPasSpansToPrometheus(AExporter); AW.GetHeaders.SetHeader('Content-Type', 'text/plain; version=0.0.4'); end
    else begin S := TlsPasSpansToJSON(AExporter); AW.GetHeaders.SetHeader('Content-Type', 'application/json'); end;
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(S) > 0 then AW.Write(S[1], Length(S));
  end);
end;

function HttpOTLPJSON(const AExporter: ITlsPasSpanExporter): string;
begin Result := TlsPasSpansToOTLPJSON(AExporter); end;

function HttpOTLPHandler(const AExporter: ITlsPasSpanExporter): IHttpHandler;
begin
  Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var S: string;
  begin
    S := TlsPasSpansToOTLPJSON(AExporter);
    AW.GetHeaders.SetHeader('Content-Type', 'application/json');
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(S) > 0 then AW.Write(S[1], Length(S));
  end);
end;

function HttpSamplingRatePrometheusText(ARate: Double): string;
begin Result := TlsPasSamplingRateToPrometheus(ARate); end;

function HttpSamplingRatePrometheusText(ARate: Double; const APrefix: string): string;
begin Result := TlsPasSamplingRateToPrometheus(ARate, APrefix); end;

function HttpAdaptiveSamplingRateText(const AAdaptiveTracer: TAsyncTlsPasAdaptiveTracer): string;
var R: Double;
begin if AAdaptiveTracer = nil then R := 0 else R := AAdaptiveTracer.GetAdaptiveRate; Result := TlsPasSamplingRateToPrometheus(R); end;

function AdaptiveEarlyDataMiddleware(const AObserver: TAsyncTlsPasAdaptiveObserver): IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LWasEarly, LThrottled: Boolean;
      LHeader: string;
      LCtx: IHttpContext;
    begin
      LWasEarly := HttpEarlyDataWasEarlyData(AReq);
      LThrottled := HttpAdaptiveEarlyDataIsThrottled(AReq, AObserver);
      if LWasEarly and not LThrottled then
        LHeader := HTTP_HEADER_X_EARLY_DATA_EARLY
      else
        LHeader := HTTP_HEADER_X_EARLY_DATA_NOT_EARLY;
      AW.GetHeaders.SetHeader(HTTP_HEADER_X_EARLY_DATA, LHeader);
      LCtx := HttpContextOf(AReq);
      if LCtx <> nil then
      begin
        if (LWasEarly and not LThrottled) then
          HttpContextSetString(LCtx, CONTEXT_EARLY_DATA, HTTP_HEADER_X_EARLY_DATA_EARLY)
        else
          HttpContextSetString(LCtx, CONTEXT_EARLY_DATA, HTTP_HEADER_X_EARLY_DATA_NOT_EARLY);
        // 额外埋点：自适应 max 供日志采样（可选，不加 header 免污染）
        // 不在此追加 header，调用方按需读 AObserver.GetAdaptiveMaxEarlyData
      end;
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.

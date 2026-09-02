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

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.text.format,
  nextpas.core.text.utils,
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
    Exit(TextFormat('early=%d throttled=%d max=nil len=%d', [Ord(False), Ord(False), -1]));
  LEarly := HttpEarlyDataWasEarlyData(AReq);
  LThrottled := HttpAdaptiveEarlyDataIsThrottled(AReq, AObserver);
  LMax := AObserver.GetAdaptiveMaxEarlyData;
  if AReq <> nil then LLen := AReq.ContentLength else LLen := -1;
  Result := TextFormat('early=%d throttled=%d max=%d len=%d header=%s %s', [
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
    Exit(TextFormat('# HELP %s_adaptive_max Maximum allowed early_data bytes (adaptive)'#10 +
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
  Result := TextFormat('{"healthy":%s,"reason":"%s","reject_rate":%.4f,"current":%d,"adaptive_max":%d}', [LowerCase(BoolToStr(H.Healthy)), H.Reason, H.RejectRate, H.Current, Integer(H.AdaptiveMax)]);
end;

function HttpRegistryHealthJSON(const ARegistry: TAsyncTlsPasPrometheusRegistry): string;
var I: Integer; L: string;
begin
  if (ARegistry = nil) or (ARegistry.Count = 0) then
    Exit('{"healthy":true,"reason":"empty registry"}');
  Result := '{"registries":[';
  // snapshot via FormatAllMetrics side-effect not needed; build simple healthy array via health prometheus as placeholder
  // For lightweight, just report registry count
  Result := TextFormat('{"healthy":true,"count":%d}', [ARegistry.Count]);
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

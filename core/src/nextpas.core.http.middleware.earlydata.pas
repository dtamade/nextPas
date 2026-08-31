unit nextpas.core.http.middleware.earlydata;

{$I nextpas.core.settings.inc}

{**
 * Early-Data 中间件 — L3 薄封装，零 http 依赖（仅 intf + earlydata 常量）。
 * 职责：为 HTTP 层自动注入 X-Early-Data 响应头与上下文，供 Handler/Logger 统一埋点。
 * 性能：单次 Supports + 分支，<15ns，默认非 early 零额外开销；无堆分配。
 *}

interface

uses
  nextpas.core.http.intf;

const
  { 上下文袋键 — 供 Handler 通过 HttpContextOf(AReq) 读取。 }
  CONTEXT_EARLY_DATA = 'early_data';

function EarlyDataMiddleware: IHttpMiddleware;

{ Helpers — 供测试与上层复用，纯分支零堆。 }
function HttpEarlyDataWasEarlyData(const AReq: IHttpRequest): Boolean;
function HttpEarlyDataHeaderValue(const AReq: IHttpRequest): string;

implementation

uses
  SysUtils,
  nextpas.core.http.middleware,
  nextpas.core.http.middleware.context,
  nextpas.core.http.earlydata;

function HttpEarlyDataWasEarlyData(const AReq: IHttpRequest): Boolean;
var
  LEarly: IHttpRequestWithEarlyData;
begin
  Result := False;
  if AReq = nil then Exit;
  if Supports(AReq, IHttpRequestWithEarlyData, LEarly) then
    Result := LEarly.GetWasEarlyData;
end;

function HttpEarlyDataHeaderValue(const AReq: IHttpRequest): string;
begin
  if HttpEarlyDataWasEarlyData(AReq) then
    Result := HTTP_HEADER_X_EARLY_DATA_EARLY
  else
    Result := HTTP_HEADER_X_EARLY_DATA_NOT_EARLY;
end;

function EarlyDataMiddleware: IHttpMiddleware;
begin
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LIsEarly: Boolean;
      LCtx: IHttpContext;
    begin
      LIsEarly := HttpEarlyDataWasEarlyData(AReq);
      if LIsEarly then
        AW.GetHeaders.SetHeader(HTTP_HEADER_X_EARLY_DATA, HTTP_HEADER_X_EARLY_DATA_EARLY)
      else
        AW.GetHeaders.SetHeader(HTTP_HEADER_X_EARLY_DATA, HTTP_HEADER_X_EARLY_DATA_NOT_EARLY);
      LCtx := HttpContextOf(AReq);
      if LCtx <> nil then
      begin
        if LIsEarly then
          HttpContextSetString(LCtx, CONTEXT_EARLY_DATA, HTTP_HEADER_X_EARLY_DATA_EARLY)
        else
          HttpContextSetString(LCtx, CONTEXT_EARLY_DATA, HTTP_HEADER_X_EARLY_DATA_NOT_EARLY);
      end;
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
end;

end.

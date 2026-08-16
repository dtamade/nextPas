unit nextpas.core.http.middleware.logger;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf,
  nextpas.core.log;

{ Default logger middleware — uses structured TLogger with method, path, status, duration }
function LoggerMiddleware: IHttpMiddleware;

{ Logger middleware with structured logging via TLogger }
function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware;

{ 日志附加字段（key/value 对；logger 写 http_request 事件时按序追加）。
  provider 在 handler 返回后、日志写出前调用——此时可安全读取 AReq
  （headers / context bag，若 context 中间件在其内层已 attach）与 AW
  （status / response headers）。返回空数组 = 无附加。 }
type
  TLogField = record
    Key: string;
    Value: string;
  end;
  TLogFieldArray = array of TLogField;
  TLogExtrasProvider = function(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter): TLogFieldArray;

{ Logger middleware with extras provider（默认 TLogger；provider 附加字段
  写入日志事件——method/path/status/duration 之后的追加属性）}
function LoggerMiddlewareWithExtras(const AExtras: TLogExtrasProvider): IHttpMiddleware;

{ Logger middleware with extras provider + custom TLogger }
function LoggerMiddlewareWithExtrasAndLogger(
  const AExtras: TLogExtrasProvider; const ALogger: TLogger): IHttpMiddleware;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.time.base,
  nextpas.core.text.conv;

function LoggerMiddleware: IHttpMiddleware;
begin
  Result := LoggerMiddlewareWith(DefaultLogger);
end;

function LoggerMiddlewareWith(const ALogger: TLogger): IHttpMiddleware;
begin
  Result := LoggerMiddlewareWithExtrasAndLogger(nil, ALogger);
end;

function LoggerMiddlewareWithExtras(const AExtras: TLogExtrasProvider): IHttpMiddleware;
begin
  Result := LoggerMiddlewareWithExtrasAndLogger(AExtras, DefaultLogger);
end;

function LoggerMiddlewareWithExtrasAndLogger(
  const AExtras: TLogExtrasProvider; const ALogger: TLogger): IHttpMiddleware;
var
  LExtras: TLogExtrasProvider;
begin
  LExtras := AExtras;
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LStart: TInstant;
      LDuration: TDuration;
      LEvent: PLogEvent;
      LFields: TLogFieldArray;
      LI: Integer;
    begin
      LStart := TInstant.Now;
      ANext.ServeHTTP(AReq, AW);
      LDuration := LStart.Elapsed;
      LEvent := ALogger.Info;
      LEvent^.Str('method', HttpMethodToStr(AReq.Method));
      LEvent^.Str('path', AReq.Path);
      LEvent^.Int('status', Int64(AW.GetStatus));
      LEvent^.Str('duration', LDuration.ToString);
      if LExtras <> nil then
      begin
        LFields := LExtras(AReq, AW);
        for LI := 0 to Length(LFields) - 1 do
          LEvent^.Str(LFields[LI].Key, LFields[LI].Value);
      end;
      LEvent^.Msg('http_request');
    end);
  end);
end;

end.

unit nextpas.core.http.earlydata;

{$I nextpas.core.settings.inc}

{**
 * HTTP Early-Data 桥接 — L3 薄封装，零 http 依赖，仅复用 tlspas 决策与观测。
 * 职责：为 HTTP 层提供 X-Early-Data 头值与流判定，供 Server/Client 统一埋点。
 * 依赖：仅 L2 tlspas + net.intf，无 http 具体类型，避免循环。
 * 性能：纯分支/接口查询，单次 <10ns，默认非 TLS 流零开销（空串）。
 *}

interface

uses
  nextpas.core.net.async.tlspas,
  nextpas.core.net.async.tcp;

const
  HTTP_HEADER_X_EARLY_DATA = 'X-Early-Data';
  HTTP_HEADER_X_EARLY_DATA_EARLY = '1';
  HTTP_HEADER_X_EARLY_DATA_NOT_EARLY = '0';

function HttpEarlyDataHeaderValueFromDecision(ADecision: TTlsPasEarlyDataDecision): string; inline;
function HttpEarlyDataHeaderValueFromStream(const AStream: IAsyncTcpStream): string;
function HttpIsEarlyDataStream(const AStream: IAsyncTcpStream): Boolean;
function HttpEarlyDataDecisionToLog(const ADecision: TTlsPasEarlyDataDecision): string; inline;

implementation

uses
  SysUtils;

function HttpEarlyDataHeaderValueFromDecision(ADecision: TTlsPasEarlyDataDecision): string;
begin
  Result := TlsPasEarlyDataDecisionToHeaderValue(ADecision);
end;

function HttpEarlyDataHeaderValueFromStream(const AStream: IAsyncTcpStream): string;
var Info: ITlsPasEarlyDataInfo;
begin
  Result := '';
  if not Assigned(AStream) then Exit;
  if Supports(AStream, ITlsPasEarlyDataInfo, Info) then
  begin
    if Info.GetWasEarlyDataAccepted then
      Result := HTTP_HEADER_X_EARLY_DATA_EARLY
    else
      Result := HTTP_HEADER_X_EARLY_DATA_NOT_EARLY;
  end;
end;

function HttpIsEarlyDataStream(const AStream: IAsyncTcpStream): Boolean;
var Info: ITlsPasEarlyDataInfo;
begin
  Result := False;
  if not Assigned(AStream) then Exit;
  if Supports(AStream, ITlsPasEarlyDataInfo, Info) then
    Result := Info.GetWasEarlyDataAccepted;
end;

function HttpEarlyDataDecisionToLog(const ADecision: TTlsPasEarlyDataDecision): string;
begin
  Result := TlsPasEarlyDataDecisionToStr(ADecision) + ' header=' + HttpEarlyDataHeaderValueFromDecision(ADecision);
end;

end.

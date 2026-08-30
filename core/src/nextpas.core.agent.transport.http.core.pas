{**
 * nextpas.core.agent.transport.http.core - HTTP wire core (RoundTrip).
 *
 * 薄拆自 nextpas.core.agent.transport.http：承载非流式路径、头部/体
 * 辅助与请求构造；与 stream 域为兄弟依赖（同依赖 base/intf/http），
 * 由 facade 组装为 IAgentTransport。
 *}

unit nextpas.core.agent.transport.http.core;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.intf,
  nextpas.core.http.base,
  nextpas.core.http.client,
  nextpas.core.agent.base,
  nextpas.core.agent.base.helpers,
  nextpas.core.agent.intf;

procedure CoreRoundTrip(const AProvider: string;
  const AClient: IHttpClient; const AReq: TWireRequest;
  out AResp: TWireResponse);

function HeadersToArray(const AHeaders: IHttpHeaders): TWireHeaderArray;
function BuildPostRequest(const AReq: TWireRequest;
  const AStatusProc: THttpResponseStatusProc = nil;
  const AChunkProc: THttpResponseBodyChunkProc = nil): IHttpRequest;
function ReadAllBody(const AReader: IReader): string;
function ReadAllBodyLimited(const AReader: IReader; ALimit: SizeInt): string;

implementation

uses
  nextpas.core.exception,
  nextpas.core.http.message,
  nextpas.core.agent.provider.common,
  nextpas.core.agent.errors;

const
  CReadChunkBytes = 32 * 1024;
  CMaxErrorBodyBytes = nextpas.core.agent.base.CAgentMaxWireTotalHeaderBytes;
  CMaxSuccessBodyBytes = nextpas.core.agent.base.CAgentMaxSuccessBodyBytes;

function HeadersToArray(const AHeaders: IHttpHeaders): TWireHeaderArray;
var
  LN, LIdx: Integer;
  LArr: TWireHeaderArray;
begin
  LN := AHeaders.Count;
  SetLength(LArr, LN);
  LIdx := 0;
  AHeaders.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LIdx < LN then
      begin
        LArr[LIdx].Name := AName;
        LArr[LIdx].Value := AValue;
        Inc(LIdx);
      end;
    end);
  Result := LArr;
end;

function ReadAllBody(const AReader: IReader): string;
const
  CInitialCapBytes = 8 * 1024;
var
  LBuf: array[0..CReadChunkBytes - 1] of Byte;
  LAcc: string;
  LCap: SizeInt;
  LN: SizeUInt;
  LTotal: SizeInt;
begin
  LCap := CInitialCapBytes;
  SetLength(LAcc, LCap);
  LTotal := 0;
  repeat
    LN := AReader.Read(LBuf[0], CReadChunkBytes);
    if LN = 0 then
      Break;
    if LTotal + SizeInt(LN) > CMaxSuccessBodyBytes then
      raise EAgentError.CreateLocal(aecProtocol,
        'wire: response body exceeds CAgentMaxSuccessBodyBytes (8MiB) limit');
    while LTotal + SizeInt(LN) > LCap do
    begin
      LCap := LCap * 2;
      SetLength(LAcc, LCap);
    end;
    Move(LBuf[0], PAnsiChar(@LAcc[LTotal + 1])^, LN);
    Inc(LTotal, SizeInt(LN));
  until False;
  SetLength(LAcc, LTotal);
  Result := LAcc;
end;

function ReadAllBodyLimited(const AReader: IReader; ALimit: SizeInt): string;
const
  CInitialCapBytes = 8 * 1024;
var
  LBuf: array[0..CReadChunkBytes - 1] of Byte;
  LAcc: string;
  LCap: SizeInt;
  LN: SizeUInt;
  LTotal: SizeInt;
begin
  LCap := CInitialCapBytes;
  if LCap > ALimit then
    LCap := ALimit;
  if LCap < 1 then
    LCap := 1;
  SetLength(LAcc, LCap);
  LTotal := 0;
  repeat
    LN := AReader.Read(LBuf[0], CReadChunkBytes);
    if LN = 0 then
      Break;
    if LTotal + SizeInt(LN) > ALimit then
      raise EAgentError.CreateLocal(aecProtocol,
        'wire: response body exceeds ' + IntToStr(ALimit) + ' bytes limit');
    while LTotal + SizeInt(LN) > LCap do
    begin
      LCap := LCap * 2;
      if LCap > ALimit then
        LCap := ALimit;
      SetLength(LAcc, LCap);
    end;
    Move(LBuf[0], PAnsiChar(@LAcc[LTotal + 1])^, LN);
    Inc(LTotal, SizeInt(LN));
  until False;
  SetLength(LAcc, LTotal);
  Result := LAcc;
end;

function BuildPostRequest(const AReq: TWireRequest;
  const AStatusProc: THttpResponseStatusProc = nil;
  const AChunkProc: THttpResponseBodyChunkProc = nil): IHttpRequest;
var
  B: THttpRequestBuilder;
  I: Integer;
begin
  AgentValidateWireHeaders(AReq.Headers);
  B := THttpRequestBuilder.Create(hmPost, AReq.Url)
    .ContentType('application/json');
  for I := 0 to High(AReq.Headers) do
    B := B.Header(AReq.Headers[I].Name, AReq.Headers[I].Value);
  if AReq.TotalTimeoutMs <> CTimeoutDefault then
    B := B.Timeout(AReq.TotalTimeoutMs);
  if Assigned(AChunkProc) then
    B := B.ResponseBodyChunk(AChunkProc).SkipBodyBuffer;
  if Assigned(AStatusProc) then
    B := B.ResponseStatus(AStatusProc);
  Result := B.Body(AReq.BodyJson).Build;
end;

procedure CoreRoundTrip(const AProvider: string;
  const AClient: IHttpClient; const AReq: TWireRequest;
  out AResp: TWireResponse);
var
  LResp: IHttpResponse;
  LHdrs: TWireHeaderArray;
  LBody: string;
  LStatus: Integer;
begin
  try
    LResp := AClient.Send(BuildPostRequest(AReq));
  except
    on HE: EHttpError do
    begin
      case HE.Kind of
        hekTimeout:  raise EAgentError.CreateLocal(aecTimeout,
                       'http transport: ' + HE.Message);
        hekCanceled: raise EAgentCancelled.Create;
        hekProtocol,
        hekParse:    raise EAgentError.CreateLocal(aecProtocol,
                       'http transport: ' + HE.Message);
      else
        raise EAgentError.CreateLocal(aecTransport,
          'http transport: ' + HE.Message);
      end;
    end;
  end;
  try
    LHdrs := HeadersToArray(LResp.Headers);
    LStatus := Integer(LResp.StatusCode);
    if (LStatus < 200) or (LStatus > 299) then
      LBody := ReadAllBodyLimited(LResp.Body, CMaxErrorBodyBytes)
    else
      LBody := ReadAllBody(LResp.Body);
    AResp.StatusCode := LStatus;
    AResp.Headers := LHdrs;
    AResp.RequestId := ProbeRequestId(LHdrs);
    AResp.BodyText := LBody;
  finally
    LResp.Close;
    LResp := nil;
  end;
  if (LStatus < 200) or (LStatus > 299) then
    raise BuildUpstreamError(AProvider, LBody, LStatus, LHdrs);
end;

end.

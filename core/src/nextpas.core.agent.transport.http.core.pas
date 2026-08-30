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
  nextpas.core.bytes.base,
  nextpas.core.bytes.builder,
  nextpas.core.bytes.ops,
  nextpas.core.text.conv,
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

function ReadAllBody(const AReader: IReader): string; inline;
const
  CInitialCapBytes = 8 * 1024;
var
  LBuilder: IBytesBuilder;
  LBuf: array[0..CReadChunkBytes - 1] of Byte;
  LN: SizeUInt;
  LBytes: TBytes;
begin
  if AReader = nil then
    Exit('');
  LBuilder := CreateBytesBuilder(CInitialCapBytes);
  repeat
    LN := AReader.Read(LBuf[0], CReadChunkBytes);
    if LN = 0 then
      Break;
    if LBuilder.Length + LN > SizeUInt(CMaxSuccessBodyBytes) then
      raise EAgentError.CreateLocal(aecProtocol,
        'wire: response body exceeds CAgentMaxSuccessBodyBytes (8MiB) limit');
    LBuilder.AppendBytes(@LBuf[0], LN); { 复用 bytes.builder 几何扩容单源，零重复 }
  until False;
  LBytes := LBuilder.ToBytes; { 单次分配；接口自动释放，异常安全 }
  Result := BytesToString(LBytes); { inline Move；零拷贝借用统一经 bytes.ops }
end;

function ReadAllBodyLimited(const AReader: IReader; ALimit: SizeInt): string; inline;
const
  CInitialCapBytes = 8 * 1024;
var
  LBuilder: IBytesBuilder;
  LBuf: array[0..CReadChunkBytes - 1] of Byte;
  LN: SizeUInt;
  LInitCap: SizeInt;
  LBytes: TBytes;
begin
  if AReader = nil then
    Exit('');
  LInitCap := CInitialCapBytes;
  if LInitCap > ALimit then
    LInitCap := ALimit;
  if LInitCap < 1 then
    LInitCap := 1;
  LBuilder := CreateBytesBuilder(SizeUInt(LInitCap));
  repeat
    LN := AReader.Read(LBuf[0], CReadChunkBytes);
    if LN = 0 then
      Break;
    if LBuilder.Length + LN > SizeUInt(ALimit) then
      raise EAgentError.CreateLocal(aecProtocol,
        'wire: response body exceeds ' + nextpas.core.text.conv.IntToStr(ALimit) + ' bytes limit');
    LBuilder.AppendBytes(@LBuf[0], LN); { 复用 bytes.builder 几何扩容单源，零重复；接口释放保证 }
  until False;
  LBytes := LBuilder.ToBytes;
  Result := BytesToString(LBytes); { inline Move；零拷贝借用统一经 bytes.ops }
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

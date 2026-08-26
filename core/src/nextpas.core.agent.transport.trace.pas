(*
 * nextpas.core.agent.transport.trace - 请求级追踪装饰器（W11）。
 *
 * 契约权威：API.md §3.2。包装任意 IAgentTransport，一处接线三适配器
 * 全覆盖；与 WithRetry 叠装（traced 在内层）时每次尝试各产一对事件，
 * 重试可见性自然产生无需专用 onRetry 钩子。
 *
 * 配对语义：OnRequest 派发前、OnResponse 落定后；transport 异常路径先发
 * Failed=True/Status=-1 配对事件再原样上抛，不改写失败语义。流式只报
 * 建流耗时（ResponseBytes=-1），SSE 事件级观测归 fold/loop 层。
 * sink 回调内不得抛出——失败路径的 sink 异常会顶替传输错误上抛；
 * 成功路径 sink 异常直接冒泡。时钟经 IAgentClock 注入，测试零睡眠。
 *)

unit nextpas.core.agent.transport.trace;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock;

{ AName 进每条事件的 Provider 字段；ASink/ASink 非空校验在工厂层拦截。
  AClock 缺省用系统时钟 }
function NewTracedTransport(const AName: string;
  const ASink: IAgentTraceSink; const AInner: IAgentTransport;
  const AClock: IAgentClock = nil): IAgentTransport;

implementation

type
  TTracedTransport = class(TInterfacedObject, IAgentTransport)
  private
    FName: string;
    FSink: IAgentTraceSink;
    FInner: IAgentTransport;
    FClock: IAgentClock;
    procedure FireRequest(const AReq: TWireRequest; AStream: Boolean);
    procedure FireResponse(const AReq: TWireRequest; AStream, AFailed: Boolean;
      AStatus, ADurationMs: Int64; const ARequestId: string;
      AResponseBytes: Int64);
  public
    constructor Create(const AName: string; const ASink: IAgentTraceSink;
      const AInner: IAgentTransport; const AClock: IAgentClock);
    procedure RoundTrip(const AReq: TWireRequest; out AResp: TWireResponse);
    function OpenStream(const AReq: TWireRequest): IAgentWireStream;
  end;

function Utf8Len(const S: string): Int64;
var
  I: Integer;
  C: Char;
begin
  { H+ 字符串 Length 是 UTF-16 单位数；wire 载荷口径是 UTF-8 字节 }
  Result := 0;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if Ord(C) < $80 then
      Inc(Result)
    else if Ord(C) < $800 then
      Inc(Result, 2)
    else if Ord(C) < $10000 then
      Inc(Result, 3)
    else
      Inc(Result, 4);
  end;
end;

constructor TTracedTransport.Create(const AName: string;
  const ASink: IAgentTraceSink; const AInner: IAgentTransport;
  const AClock: IAgentClock);
begin
  inherited Create;
  FName := AName;
  FSink := ASink;
  FInner := AInner;
  FClock := AClock;
end;

procedure TTracedTransport.FireRequest(const AReq: TWireRequest;
  AStream: Boolean);
var
  Info: TTraceRequestInfo;
begin
  Info := Default(TTraceRequestInfo);
  Info.Provider := FName;
  Info.Url := AReq.Url;
  Info.Stream := AStream;
  Info.BodyBytes := Utf8Len(AReq.BodyJson);
  FSink.OnRequest(Info);
end;

procedure TTracedTransport.FireResponse(const AReq: TWireRequest;
  AStream, AFailed: Boolean; AStatus, ADurationMs: Int64;
  const ARequestId: string; AResponseBytes: Int64);
var
  Info: TTraceResponseInfo;
begin
  Info := Default(TTraceResponseInfo);
  Info.Provider := FName;
  Info.Url := AReq.Url;
  Info.Stream := AStream;
  Info.Status := AStatus;
  Info.Failed := AFailed;
  Info.DurationMs := ADurationMs;
  Info.ResponseBytes := AResponseBytes;
  Info.RequestId := ARequestId;
  FSink.OnResponse(Info);
end;

procedure TTracedTransport.RoundTrip(const AReq: TWireRequest;
  out AResp: TWireResponse);
var
  LT0: Int64;
begin
  FireRequest(AReq, False);
  LT0 := FClock.NowMs;
  try
    FInner.RoundTrip(AReq, AResp);
  except
    { 失败配对事件先行再原样上抛（契约：此处 sink 抛错会顶替传输错误）}
    FireResponse(AReq, False, True, -1, FClock.NowMs - LT0, '', -1);
    raise;
  end;
  FireResponse(AReq, False, False, AResp.StatusCode, FClock.NowMs - LT0,
    AResp.RequestId, Utf8Len(AResp.BodyText));
end;

function TTracedTransport.OpenStream(
  const AReq: TWireRequest): IAgentWireStream;
var
  LT0: Int64;
begin
  FireRequest(AReq, True);
  LT0 := FClock.NowMs;
  try
    Result := FInner.OpenStream(AReq);
  except
    FireResponse(AReq, True, True, -1, FClock.NowMs - LT0, '', -1);
    raise;
  end;
  { 流式 Status/ResponseBytes 均不可得（wire 层不暴露）；-1 即哨兵 }
  FireResponse(AReq, True, False, -1, FClock.NowMs - LT0, '', -1);
end;

function NewTracedTransport(const AName: string;
  const ASink: IAgentTraceSink; const AInner: IAgentTransport;
  const AClock: IAgentClock): IAgentTransport;
begin
  if (ASink = nil) or (AInner = nil) then
    raise EAgentError.CreateLocal(aecConfig,
      'trace: sink and inner transport are required');
  if AClock = nil then
    Result := TTracedTransport.Create(AName, ASink, AInner, NewSystemClock)
  else
    Result := TTracedTransport.Create(AName, ASink, AInner, AClock);
end;

end.

{**
 * nextpas.core.agent.provider.openai.factory - OpenAI/Grok provider 工厂与 BuildUrl。
 *
 * 职责：TOpenAIOptions/TGrokOptions 规格、BuildOpenAIUrl/BuildGrokUrl 纯 URL 拼接、
 * TOpenAIProvider 实现与 New*Provider/*FromEnv 工厂（含 env reader 注入）。
 * 属 provider.openai 四象限拆分之四（factory），与 encode/decode/decoder
 * 互不循环，仅向下依赖 base/errors/intf/common/transport/fold。
 * 供 provider.openai 门面 inline 转发；调用方仍 `uses ...openai` 零改动。
 *}

unit nextpas.core.agent.provider.openai.factory;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.common;

const
  COPENAI_DEFAULT_BASE_URL = 'https://api.openai.com';
  COPENAI_CONNECT_TIMEOUT_MS = 10000;
  COPENAI_TOTAL_TIMEOUT_MS = 300000;

  COPENAI_MAX_COMPLETION_TOKENS_PREFIXES: array[0..2] of string =
    ('o1', 'o3', 'gpt-5');

  COPENAI_ENV_API_KEY = 'NEXTPAS_AGENT_OPENAI_API_KEY';
  COPENAI_ENV_MODEL = 'NEXTPAS_AGENT_OPENAI_MODEL';
  COPENAI_ENV_BASE_URL = 'NEXTPAS_AGENT_OPENAI_BASE_URL';

  CGROK_DEFAULT_BASE_URL = 'https://api.x.ai';
  CGROK_ENV_API_KEY = 'NEXTPAS_AGENT_GROK_API_KEY';
  CGROK_ENV_MODEL = 'NEXTPAS_AGENT_GROK_MODEL';
  CGROK_ENV_BASE_URL = 'NEXTPAS_AGENT_GROK_BASE_URL';

type
  TOpenAIOptions = record
    Common: TProviderOptions;
    Organization: string;
    class function New(const AModel: string): TOpenAIOptions; static;
  end;

  TGrokOptions = record
    Common: TProviderOptions;
    class function New(const AModel: string): TGrokOptions; static;
  end;

function BuildOpenAIUrl(const ABaseUrl: string): string;
function BuildGrokUrl(const ABaseUrl: string): string;

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
function NewOpenAIProviderFromEnv: IAgentProvider;
type
  TAgentEnvReader = function(const AName: string): string;
function NewOpenAIProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;

function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
function NewGrokProviderFromEnv: IAgentProvider;
function NewGrokProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;

implementation

uses
  nextpas.core.os.env,
  nextpas.core.agent.fold,
  nextpas.core.agent.transport.http,
  nextpas.core.agent.provider.openai.encode,
  nextpas.core.agent.provider.openai.decode,
  nextpas.core.agent.provider.openai.decoder;

function BuildOpenAIUrl(const ABaseUrl: string): string;
begin
  Result := AgentJoinWireUrl(ABaseUrl, COPENAI_DEFAULT_BASE_URL, '/chat/completions');
end;

function BuildGrokUrl(const ABaseUrl: string): string;
begin
  Result := AgentJoinWireUrl(ABaseUrl, CGROK_DEFAULT_BASE_URL, '/chat/completions');
end;

{ ---- provider 与 completion ---- }

type
  TOpenAIProvider = class(TInterfacedObject, IAgentProvider)
  private
    FOpts: TOpenAIOptions;
    FTransport: IAgentTransport;
    FLog: ILogger;
    FName: string;
    function ResolveModel(const AReq: TCompletionRequest): string;
    function BuildWireRequest(const AReq: TCompletionRequest;
      AStream: Boolean): TWireRequest;
  public
    constructor Create(const AOpts: TOpenAIOptions;
      const AName: string = 'openai');
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

constructor TOpenAIProvider.Create(const AOpts: TOpenAIOptions;
  const AName: string);
begin
  inherited Create;
  FOpts := AOpts;
  FName := AName;
  FLog := AOpts.Common.Logger;
  if FOpts.Common.Transport <> nil then
    FTransport := FOpts.Common.Transport
  else
    FTransport := NewHttpTransport(FName);
end;

function TOpenAIProvider.GetName: string;
begin
  Result := FName;
end;

function TOpenAIProvider.ResolveModel(
  const AReq: TCompletionRequest): string;
begin
  if AReq.Model <> '' then
    Exit(AReq.Model);
  if FOpts.Common.Model <> '' then
    Exit(FOpts.Common.Model);
  raise EAgentError.CreateLocal(aecConfig,
    'openai: model is required (request.Model or options.Common.Model)');
end;

function TOpenAIProvider.BuildWireRequest(const AReq: TCompletionRequest;
  AStream: Boolean): TWireRequest;
var
  LReq: TCompletionRequest;
begin
  AgentRequireApiKey(FOpts.Common.ApiKey, COPENAI_ENV_API_KEY);
  LReq := AReq;
  LReq.Model := ResolveModel(AReq);
  Result := Default(TWireRequest);
  Result.Url := BuildOpenAIUrl(FOpts.Common.BaseUrl);
  Result.BodyJson := EncodeOpenAIRequest(LReq, AStream);
  AgentWireAddOpenAIHeaders(Result, FOpts.Common, FOpts.Organization);
  AgentWireApplyIdempotency(Result, AReq);
end;

function TOpenAIProvider.Complete(const AReq: TCompletionRequest): TMessage;
var
  LResp: TWireResponse;
begin
  FTransport.RoundTrip(BuildWireRequest(AReq, False), LResp);
  DecodeOpenAIResponse(LResp.BodyText, Result, FLog);
end;

function TOpenAIProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
begin
  if Assigned(AToken) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
  Result := Complete(AReq);
end;

function TOpenAIProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewOpenAIWireDecoder(FLog), nil, FName);
end;

function TOpenAIProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
begin
  Result := TWireBackedCompletion.Create(
    FTransport.OpenStream(BuildWireRequest(AReq, True)),
    NewOpenAIWireDecoder(FLog), AToken, FName);
end;

{ ---- 工厂 ---- }

class function TOpenAIOptions.New(const AModel: string): TOpenAIOptions;
begin
  Result := Default(TOpenAIOptions);
  Result.Common.BaseUrl := COPENAI_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := COPENAI_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := COPENAI_TOTAL_TIMEOUT_MS;
end;

function NewOpenAIProvider(const AOpts: TOpenAIOptions): IAgentProvider;
begin
  Result := TOpenAIProvider.Create(AOpts);
end;

function NewOpenAIProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;
var
  O: TOpenAIOptions;
  LUrl: string;
begin
  if not Assigned(AReader) then
    Exit(nil);
  O := TOpenAIOptions.New('');
  O.Common.ApiKey := AReader(COPENAI_ENV_API_KEY);
  O.Common.Model := AReader(COPENAI_ENV_MODEL);
  LUrl := AReader(COPENAI_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewOpenAIProvider(O);
end;

function NewOpenAIProviderFromEnv: IAgentProvider;
begin
  Result := NewOpenAIProviderFromEnvWithReader(@GetEnvironmentVariable);
end;

{ ---- Grok 家族（wire 同族，仅默认端点与归因名不同）---- }

class function TGrokOptions.New(const AModel: string): TGrokOptions;
begin
  Result := Default(TGrokOptions);
  Result.Common.BaseUrl := CGROK_DEFAULT_BASE_URL;
  Result.Common.Model := AModel;
  Result.Common.ConnectTimeoutMs := COPENAI_CONNECT_TIMEOUT_MS;
  Result.Common.TotalTimeoutMs := COPENAI_TOTAL_TIMEOUT_MS;
end;

function NewGrokProvider(const AOpts: TGrokOptions): IAgentProvider;
var
  LO: TOpenAIOptions;
begin
  LO := Default(TOpenAIOptions);
  LO.Common := AOpts.Common;
  Result := TOpenAIProvider.Create(LO, 'grok');
end;

function NewGrokProviderFromEnvWithReader(const AReader: TAgentEnvReader): IAgentProvider;
var
  O: TGrokOptions;
  LUrl: string;
begin
  if not Assigned(AReader) then
    Exit(nil);
  O := TGrokOptions.New('');
  O.Common.ApiKey := AReader(CGROK_ENV_API_KEY);
  O.Common.Model := AReader(CGROK_ENV_MODEL);
  LUrl := AReader(CGROK_ENV_BASE_URL);
  if LUrl <> '' then
    O.Common.BaseUrl := LUrl;
  if (O.Common.ApiKey = '') or (O.Common.Model = '') then
    Exit(nil);
  Result := NewGrokProvider(O);
end;

function NewGrokProviderFromEnv: IAgentProvider;
begin
  Result := NewGrokProviderFromEnvWithReader(@GetEnvironmentVariable);
end;

end.

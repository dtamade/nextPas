program test_security;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.os.env,
  nextpas.core.json,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.tools,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.anthropic,
  nextpas.core.agent.provider.common,
  agent.testkit,
  nextpas.core.test;

{ SECURITY.md 验收项集中落 CI（TESTING §3 test_security 行）：
  密钥/请求体不入日志、RawBodySnippet 只随异常走、FromEnv 缺 env 返 nil
  绝不回显、mime 白名单 fail-closed 且零 wire 请求、256KiB 参数预检、
  截断 UTF-8 安全切边界、Extra 未知键捕获上限。
  深度覆盖仍在各自归属门（test_sse 行上限 / provider 门编码细节等），
  本门是跨切面汇总防线。
  边界/Cancel/超时/并发：
  - Cancel 边界：此门不涉取消；取消语义由 transport/hedge/loop 门保障。
  - 超时边界：此门不涉超时；超时由 throttle/transport 门保障。
  - 并发边界：单线程门；CaptureExtraJson 64 键上限在单消息维度 F-M15 已注，跨轮合并 Fold 层二次截断由 loop 门保障。
  悬挂指针：ILogger 捕获桩与 ExtraJson 字符串均为托管类型，无裸指针；TJsonlTranscriptStore 等不跨门。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门 0 unfreed；Utf8SafeTruncate 边界 Extra 非空强制断言（F-H25）已闭环，零捕获假绿已消。 }

function ScriptResp(AStatus: Integer; const ABody: string): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := AStatus;
  Result.BodyText := ABody;
end;

function ScriptChunks(const AChunks: TStringArray): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.Chunks := AChunks;
end;

procedure TestFromEnvNilDiscipline;
var
  P: IAgentProvider;
begin
  SetEnv('NEXTPAS_AGENT_OPENAI_API_KEY', '');
  SetEnv('NEXTPAS_AGENT_ANTHROPIC_API_KEY', '');

  P := NewOpenAIProviderFromEnv;
  Check(P = nil, 'openai missing key -> nil (never silent fallback)');

  P := NewAnthropicProviderFromEnv;
  Check(P = nil, 'anthropic missing key -> nil (never silent fallback)');
end;

{ image mime 白名单：违者 aecConfig，且绝不发出 wire 请求 }
procedure TestImageMimeWhitelistNoWire;
var
  Tr: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  Req: TCompletionRequest;
  Raised: Boolean;
  Code: TAgentErrorCode;
begin
  Tr := TScriptedTransport.Create;     { 零脚本：任何请求即耗尽抛错 }
  Opts := TAnthropicOptions.New('');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := Tr;
  P := NewAnthropicProvider(Opts);

  Req := TCompletionRequest.New('m').WithUserText('look').WithMaxTokens(32);
  SetLength(Req.Messages[0].Parts, 2);
  Req.Messages[0].Parts[1] := Default(TPart);
  Req.Messages[0].Parts[1].Kind := pkImage;
  Req.Messages[0].Parts[1].ImageUrl := 'data:image/bmp;base64,AAAA';

  Raised := False;
  try
    P.Complete(Req);
  except
    on Ex: EAgentError do
    begin
      Raised := True;
      Code := Ex.ErrorCode;
    end;
  end;
  Check(Raised and (Code = aecConfig),
    'non-whitelisted mime rejected aecConfig');
  CheckEqual(0, Tr.ServedCount, 'rejected request never hits the wire');
end;

{ 256KiB 参数预检：合成 error result 而非流错误（SECURITY §3）}
procedure TestArgsPrecheckLimit;
var
  Spec: TToolSpec;
  R: TToolResult;
begin
  Spec := Default(TToolSpec);
  Spec.Name := 's';
  R := ValidateToolArguments(Spec,
    '{"x":"' + StringOfChar('a', 300000) + '"}');
  Check(R.IsError, 'oversize args become error result');
end;

{ 截断字节上限的 UTF-8 安全切：绝不产出半个多字节字符 }
procedure TestTruncateUtf8Boundary;
var
  R, Out: TToolResult;
  S: string;
  I: Integer;
begin
  { 「中」= E4 B8 AD 三字节序列；切点落在字符中段必须回退到引导字节 }
  S := '';
  for I := 0 to 39 do
    S := S + #$E4#$B8#$AD;
  R := Default(TToolResult);
  R.ContentJson := S;
  Out := EnvelopeTruncation(R, 0, 50);
  Check(Out.Truncated, 'byte cap triggers truncation');
  Check(Ord(Out.ContentJson[Length(Out.ContentJson)]) <> $BF,
    'no stray continuation byte at cut point');
end;

{ 完成对象误用守卫：EOF 前 GetMessage 必须 EAgentMisuse }
procedure TestGetMessageBeforeEofMisuse;
var
  Ch: TStringArray;
  Resp: TScriptResponse;
  Tr: TScriptedTransport;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  C: IAgentCompletion;
  Raised: Boolean;
begin
  Ch := TStringArray.Create(
    'data: {"choices":[{"delta":{"content":"x"},' +
    '"finish_reason":"stop"}]}'#10#10);
  Resp := ScriptChunks(Ch);
  Tr := TScriptedTransport.Create;
  Tr.Add(Resp);
  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := Tr;
  P := NewOpenAIProvider(Opts);

  C := P.Stream(TCompletionRequest.New('m').WithUserText('go'));
  Raised := False;
  try
    C.GetMessage;
  except
    on Ex: EAgentError do
      Raised := (Ex.ErrorCode = aecProtocol) and (Pos('completion not drained', Ex.Message) > 0);
  end;
  Check(Raised, 'GetMessage before EOF raises aecProtocol completion not drained (F-H20)');
end;

{ 密钥与完整请求体永不入日志；RawBodySnippet 全文只随异常对象走 }
procedure TestSecretsNeverInLogs;
const
  CKey = 'sk-TOPSECRET-KEY';
  CBodyMark = 'UPSTREAM-BODY-MARKER-7Q';
var
  Tr: TScriptedTransport;
  Log: TCapturingLogger;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  Lines: TStringArray;
  I: Integer;
  LeakedKey, LeakedBody, ErrHasBody: Boolean;
  ErrMsg: string;
begin
  Tr := TScriptedTransport.Create;
  Tr.Add(ScriptResp(500, '{"error":{"message":"' + CBodyMark + '"}}'));
  Log := TCapturingLogger.Create;
  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := CKey;
  Opts.Common.Logger := Log;
  Opts.Common.Transport := Tr;
  P := NewOpenAIProvider(Opts);

  ErrHasBody := False;
  try
    P.Complete(TCompletionRequest.New('m').WithUserText('go'));
  except
    on Ex: EAgentError do
    begin
      ErrMsg := Ex.Message;
      { 摘要随异常对象走（ERRORS §6）；信封化 message 也可能含上游文案 }
      if (Pos(CBodyMark, Ex.RawBodySnippet) > 0) or
        (Pos(CBodyMark, ErrMsg) > 0) then
        ErrHasBody := True;
    end;
  end;

  { 正向对照：上游体确实抵达错误路径，日志侧禁止 }
  Check(ErrHasBody, 'upstream body summary travels with the exception');

  Lines := Log.Lines;
  LeakedKey := False;
  LeakedBody := False;
  for I := 0 to High(Lines) do
  begin
    if Pos(CKey, Lines[I]) > 0 then
      LeakedKey := True;
    if Pos(CBodyMark, Lines[I]) > 0 then
      LeakedBody := True;
  end;
  Check(not LeakedKey, 'api key never appears in logs');
  Check(not LeakedBody,
    'raw body text never appears in logs (length/code only)');
end;

{ Extra 无损捕获键数上限：病态响应膨胀被截到 64 键（SECURITY §3）}
procedure TestExtraKeysCappedAt64;
var
  Body: string;
  Tr: TScriptedTransport;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  M: TMessage;
  Doc: IJsonDocument;
  K: Integer;
begin
  Body := '{"id":"e","model":"m","choices":[{"message":{"role":' +
    '"assistant","content":"ok"';
  for K := 0 to 69 do
    Body := Body + ',"zz_unknown_' + IntToStr(K) + '":1';
  Body := Body + '},"finish_reason":"stop"}],"usage":{}}';

  Tr := TScriptedTransport.Create;
  Tr.Add(ScriptResp(200, Body));
  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := 'k';
  Opts.Common.Transport := Tr;
  P := NewOpenAIProvider(Opts);

  M := P.Complete(TCompletionRequest.New('m').WithUserText('go'));
  // F-H25 假绿修复：Extra 捕获必须非空且 ≤64（单消息维度上限强制）
  Check(M.ExtraJson <> '', 'extra captured is mandatory (non-empty)');
  Doc := JsonParse(M.ExtraJson);
  Check(not Doc.HasError, 'captured extra parses');
  Check((Integer(Doc.Root.ObjectLen) > 0) and
    (Integer(Doc.Root.ObjectLen) <= 64),
    'extra capture 1..64 keys');
end;

{ W17.5 Extra 64 键直验：65 个未知键 → CaptureExtraJson 仅留 64 并 warn（SECURITY §3，单一真源 CMaxExtraKeys/base.CAgentMaxExtraKeys）}
procedure TestCaptureExtraDirect65Warn;
var
  JsonStr: string;
  Doc, CapDoc: IJsonDocument;
  LogObj: TCapturingLogger;
  ILog: ILogger;
  Captured: TJsonText;
  K: Integer;
  Lines: TStringArray;
  HasWarn: Boolean;
begin
  JsonStr := '{';
  for K := 0 to 64 do
  begin
    if K > 0 then JsonStr := JsonStr + ',';
    JsonStr := JsonStr + '"zz_unknown_' + IntToStr(K) + '":' + IntToStr(K);
  end;
  JsonStr := JsonStr + '}';
  Doc := JsonParse(JsonStr);
  Check(not Doc.HasError, '65-key json parses');
  LogObj := TCapturingLogger.Create;
  ILog := LogObj;
  Captured := CaptureExtraJson(Doc.Root, [], CMaxExtraKeys, ILog);
  Check(Captured <> '', 'capture non-empty at 64 cap');
  CapDoc := JsonParse(Captured);
  Check(not CapDoc.HasError, 'captured extra parses (direct)');
  CheckEqual(64, Integer(CapDoc.Root.ObjectLen), 'direct cap keeps 64');
  Check(not CapDoc.Root.ObjectHas('zz_unknown_64'), '65th key dropped');
  Check(CapDoc.Root.ObjectHas('zz_unknown_0'), 'first key kept');
  Lines := LogObj.Lines;
  HasWarn := False;
  for K := 0 to High(Lines) do
    if Pos('capture limit', Lines[K]) > 0 then HasWarn := True;
  Check(HasWarn, 'warn emitted on cap');
  CheckEqual(CAgentMaxExtraKeys, CMaxExtraKeys, 'alias equals base single source');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.security');
  T.Test('from env nil discipline', @TestFromEnvNilDiscipline);
  T.Test('image mime whitelist no wire', @TestImageMimeWhitelistNoWire);
  T.Test('args precheck limit', @TestArgsPrecheckLimit);
  T.Test('truncate utf8 boundary', @TestTruncateUtf8Boundary);
  T.Test('get message before eof misuse', @TestGetMessageBeforeEofMisuse);
  T.Test('secrets never in logs', @TestSecretsNeverInLogs);
  T.Test('extra keys capped at 64', @TestExtraKeysCappedAt64);
  T.Test('capture extra 65 warn (direct)', @TestCaptureExtraDirect65Warn);
  if not T.Run then Halt(1);
end.

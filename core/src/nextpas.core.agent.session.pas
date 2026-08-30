{**
 * nextpas.core.agent.session - W5 会话转录 JSONL 落地存储。
 *
 * 契约权威：core/docs/agent/SESSION.md（行格式 schema v1、崩溃恢复语义、
 * fsync 节奏、Fork 语义）。实现与文档冲突时先改文档。
 *}

unit nextpas.core.agent.session;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.text.format,
  nextpas.core.fs,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.text.builder,
  nextpas.core.text.conv,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf;

const
  CTranscriptSchemaVersion = 1;
  CMaxThreadIdLen = 128;

type
  { 转录文件损坏：完整行解析失败/形状不符/未知 kind 或版本——fail-closed，
    绝不静默吞掉伪装成短历史（SESSION.md §4）}
  ETranscriptCorrupt = class(EAgentError);

  { IAgentTranscriptStore 的 JSONL 落地实现：一线程一文件
    <RootDir>/<ThreadId>.jsonl；同一线程 id 单写者假设（SESSION.md §7）}
  TJsonlTranscriptStore = class(TInterfacedObject, IAgentTranscriptStore)
  private
    FRootDir: string;              { 带尾分隔符 }
    FSyncEachAppend: Boolean;
    function ThreadPath(const AThreadId: string): string;
    procedure LoadFile(const APath: string; out AMsgs: TMessageArray);
  public
    constructor Create(const ARootDir: string;
      ASyncEachAppend: Boolean = True);

    procedure Append(const AThreadId: string; const AMsg: TMessage);
    function Load(const AThreadId: string): TMessageArray;
    procedure Delete(const AThreadId: string);
    { Fork：对源线程按 Load 恢复语义取干净快照（torn tail 已剔除），
      原子写入目标线程；目标已存在或自 fork 抛 EAgentMisuse }
    procedure Fork(const ASrcThreadId, ADstThreadId: string);

    property RootDir: string read FRootDir;
    property SyncEachAppend: Boolean read FSyncEachAppend;
  end;

function NewJsonlTranscriptStore(const ARootDir: string;
  ASyncEachAppend: Boolean = True): IAgentTranscriptStore;

{ 存储行编解码（schema v1）：四个 TJsonText 字段一律以 JSON 字符串嵌入，
  builder 转义保证行内永无裸换行、torn-tail 判据因此永远可靠（SESSION.md §3）}
function TranscriptMessageToJson(const AMsg: TMessage): TJsonText;
function TranscriptMessageFromJson(const AJson: TJsonText;
  ALineNo: Integer): TMessage;

{ [A-Za-z0-9._-] 非空、首字符不为点、长度 <= CMaxThreadIdLen（防路径穿越）}
function IsValidThreadId(const AThreadId: string): Boolean;

implementation

uses
  nextpas.core.bytes.ops;

const
  ROLE_NAMES: array[TMessageRole] of string =
    ('system', 'user', 'assistant', 'tool');
  PART_NAMES: array[TPartKind] of string =
    ('text', 'thinking', 'tool_call', 'tool_result', 'image');
  FINISH_NAMES: array[TFinishReason] of string =
    ('none', 'stop', 'length', 'tool_calls', 'content_filter');

function Corrupt(ALineNo: Integer; const AWhy: string): ETranscriptCorrupt;
begin
  Result := ETranscriptCorrupt.CreateLocal(aecProtocol,
    TextFormat('transcript line %d: %s', [ALineNo, AWhy]));
end;

procedure Misuse(const AWhy: string);
begin
  raise EAgentMisuse.Create(AWhy);
end;

procedure ValidateThreadId(const AThreadId: string);
begin
  if not IsValidThreadId(AThreadId) then
    Misuse('thread id violates charset policy');   { 不回显原值 }
end;

function IsValidThreadId(const AThreadId: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  if (AThreadId = '') or (Length(AThreadId) > CMaxThreadIdLen) then
    Exit;
  if AThreadId[1] = '.' then
    Exit;                            { 排除 '.' / '..' 及一切点首名 }
  for I := 1 to Length(AThreadId) do
  begin
    C := AThreadId[I];
    if not (((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
            ((C >= '0') and (C <= '9')) or (C = '_') or (C = '-') or
            (C = '.')) then
      Exit;
  end;
  Result := True;
end;

{ ---- 编码 ---- }

procedure WritePartJson(const ABld: IJsonBuilder; const AP: TPart);
begin
  ABld.BeginObject;
  ABld.Key('kind');
  ABld.Str(PART_NAMES[AP.Kind]);
  case AP.Kind of
    pkText, pkThinking:
      if AP.Text <> '' then
      begin
        ABld.Key('text');
        ABld.Str(AP.Text);
      end;
    pkToolCall:
      begin
        if AP.ToolCallId <> '' then
        begin
          ABld.Key('call_id');
          ABld.Str(AP.ToolCallId);
        end;
        if AP.ToolName <> '' then
        begin
          ABld.Key('name');
          ABld.Str(AP.ToolName);
        end;
        if AP.ArgumentsJson <> '' then
        begin
          ABld.Key('args');
          ABld.Str(AP.ArgumentsJson);
        end;
      end;
    pkToolResult:
      begin
        if AP.ToolCallId <> '' then
        begin
          ABld.Key('call_id');
          ABld.Str(AP.ToolCallId);
        end;
        if AP.ResultJson <> '' then
        begin
          ABld.Key('result');
          ABld.Str(AP.ResultJson);
        end;
        if AP.IsError then
        begin
          ABld.Key('is_error');
          ABld.Bool(True);
        end;
      end;
    pkImage:
      if AP.ImageUrl <> '' then
      begin
        ABld.Key('image');
        ABld.Str(AP.ImageUrl);
      end;
  end;
  if (AP.Kind = pkThinking) and (AP.Signature <> '') then
  begin
    ABld.Key('sig');
    ABld.Str(AP.Signature);
  end;
  if AP.ExtraJson <> '' then
  begin
    ABld.Key('extra');
    ABld.Str(AP.ExtraJson);
  end;
  ABld.EndObject;
end;

function TranscriptMessageToJson(const AMsg: TMessage): TJsonText;
var
  B: IJsonBuilder;
  I: Integer;
begin
  B := JsonBuilder;
  B.BeginObject;
  B.Key('v');
  B.Int(CTranscriptSchemaVersion);
  B.Key('kind');
  B.Str('msg');
  B.Key('msg');
  B.BeginObject;
  B.Key('role');
  B.Str(ROLE_NAMES[AMsg.Role]);
  if AMsg.Id <> '' then
  begin
    B.Key('id');
    B.Str(AMsg.Id);
  end;
  if AMsg.Model <> '' then
  begin
    B.Key('model');
    B.Str(AMsg.Model);
  end;
  if AMsg.FinishReason <> frNone then
  begin
    B.Key('finish');
    B.Str(FINISH_NAMES[AMsg.FinishReason]);
  end;
  if AMsg.Usage.Known then
  begin
    B.Key('usage');
    B.BeginObject;
    B.Key('in');
    B.Int(AMsg.Usage.InputTokens);
    B.Key('out');
    B.Int(AMsg.Usage.OutputTokens);
    B.Key('cache_r');
    B.Int(AMsg.Usage.CacheReadInputTokens);
    B.Key('cache_w');
    B.Int(AMsg.Usage.CacheWriteInputTokens);
    B.Key('reason');
    B.Int(AMsg.Usage.ReasoningTokens);
    B.EndObject;
  end;
  if Length(AMsg.Parts) > 0 then
  begin
    B.Key('parts');
    B.BeginArray;
    for I := 0 to High(AMsg.Parts) do
      WritePartJson(B, AMsg.Parts[I]);
    B.EndArray;
  end;
  if AMsg.ExtraJson <> '' then
  begin
    B.Key('extra');
    B.Str(AMsg.ExtraJson);
  end;
  B.EndObject;
  B.EndObject;
  Result := B.ToString;
end;

{ ---- 解码 ---- }

function ReqStr(const AO: TJsonValue; const AKey: string;
  ALineNo: Integer): string;
var
  V: TJsonValue;
begin
  V := AO.Get(AKey);
  if (not V.IsValid) or (not V.IsStr) then
    raise Corrupt(ALineNo, 'field "' + AKey + '" missing or not a string');
  Result := V.AsStr.ToString;
end;

function OptStr(const AO: TJsonValue; const AKey: string;
  ALineNo: Integer): string;
var
  V: TJsonValue;
begin
  Result := '';
  V := AO.Get(AKey);
  if V.IsValid then
  begin
    if not V.IsStr then
      raise Corrupt(ALineNo, 'field "' + AKey + '" must be a string');
    Result := V.AsStr.ToString;
  end;
end;

function OptBool(const AO: TJsonValue; const AKey: string;
  ALineNo: Integer): Boolean;
var
  V: TJsonValue;
begin
  Result := False;
  V := AO.Get(AKey);
  if V.IsValid then
  begin
    if not V.IsBool then
      raise Corrupt(ALineNo, 'field "' + AKey + '" must be a boolean');
    Result := V.AsBool;
  end;
end;

procedure OptInt(const AO: TJsonValue; const AKey: string;
  ALineNo: Integer; out AValue: Int64);
var
  V: TJsonValue;
begin
  AValue := CUsageUnknown;
  V := AO.Get(AKey);
  if V.IsValid then
  begin
    if not V.IsInt then
      raise Corrupt(ALineNo, 'field "' + AKey + '" must be an integer');
    AValue := V.AsInt;
  end;
end;

function RoleFromName(const AName: string; ALineNo: Integer): TMessageRole;
var
  R: TMessageRole;
begin
  for R := Low(TMessageRole) to High(TMessageRole) do
    if ROLE_NAMES[R] = AName then
      Exit(R);
  raise Corrupt(ALineNo, 'unknown role "' + AName + '"');
end;

function PartKindFromName(const AName: string; ALineNo: Integer): TPartKind;
var
  K: TPartKind;
begin
  for K := Low(TPartKind) to High(TPartKind) do
    if PART_NAMES[K] = AName then
      Exit(K);
  raise Corrupt(ALineNo, 'unknown part kind "' + AName + '"');
end;

function FinishFromName(const AName: string; ALineNo: Integer): TFinishReason;
var
  F: TFinishReason;
begin
  for F := Low(TFinishReason) to High(TFinishReason) do
    if FINISH_NAMES[F] = AName then
      Exit(F);
  raise Corrupt(ALineNo, 'unknown finish reason "' + AName + '"');
end;

function DecodePart(const APV: TJsonValue; ALineNo: Integer): TPart;
begin
  if not APV.IsObject then
    raise Corrupt(ALineNo, 'part is not an object');
  Result := Default(TPart);
  Result.Kind := PartKindFromName(ReqStr(APV, 'kind', ALineNo), ALineNo);
  Result.Text := OptStr(APV, 'text', ALineNo);
  Result.ToolCallId := OptStr(APV, 'call_id', ALineNo);
  Result.ToolName := OptStr(APV, 'name', ALineNo);
  Result.ArgumentsJson := OptStr(APV, 'args', ALineNo);
  Result.ResultJson := OptStr(APV, 'result', ALineNo);
  Result.ImageUrl := OptStr(APV, 'image', ALineNo);
  Result.Signature := OptStr(APV, 'sig', ALineNo);
  Result.ExtraJson := OptStr(APV, 'extra', ALineNo);
  Result.IsError := OptBool(APV, 'is_error', ALineNo);
end;

function TranscriptMessageFromJson(const AJson: TJsonText;
  ALineNo: Integer): TMessage;
var
  Doc: IJsonDocument;
  RV, MV, UV, PV: TJsonValue;
  LS: string;
  I: Integer;
begin
  Doc := JsonParse(AJson);
  if Doc.HasError then
    raise Corrupt(ALineNo, 'invalid json');
  RV := Doc.Root;
  if not RV.IsObject then
    raise Corrupt(ALineNo, 'record is not an object');
  if RV.Get('v').AsInt <> CTranscriptSchemaVersion then
    raise Corrupt(ALineNo, 'unknown schema version');   { fail-closed }
  if OptStr(RV, 'kind', ALineNo) <> 'msg' then
    raise Corrupt(ALineNo, 'unknown record kind');

  MV := RV.Get('msg');
  if not MV.IsObject then
    raise Corrupt(ALineNo, 'msg payload missing or not an object');

  Result := Default(TMessage);
  Result.Role := RoleFromName(ReqStr(MV, 'role', ALineNo), ALineNo);
  Result.Id := OptStr(MV, 'id', ALineNo);
  Result.Model := OptStr(MV, 'model', ALineNo);
  LS := OptStr(MV, 'finish', ALineNo);
  if LS <> '' then
    Result.FinishReason := FinishFromName(LS, ALineNo);

  Result.Usage.InputTokens := CUsageUnknown;
  Result.Usage.OutputTokens := CUsageUnknown;
  Result.Usage.CacheReadInputTokens := CUsageUnknown;
  Result.Usage.CacheWriteInputTokens := CUsageUnknown;
  Result.Usage.ReasoningTokens := CUsageUnknown;
  UV := MV.Get('usage');
  if UV.IsValid then
  begin
    if not UV.IsObject then
      raise Corrupt(ALineNo, 'usage must be an object');
    OptInt(UV, 'in', ALineNo, Result.Usage.InputTokens);
    OptInt(UV, 'out', ALineNo, Result.Usage.OutputTokens);
    OptInt(UV, 'cache_r', ALineNo, Result.Usage.CacheReadInputTokens);
    OptInt(UV, 'cache_w', ALineNo, Result.Usage.CacheWriteInputTokens);
    OptInt(UV, 'reason', ALineNo, Result.Usage.ReasoningTokens);
  end;

  PV := MV.Get('parts');
  if PV.IsValid then
  begin
    if not PV.IsArray then
      raise Corrupt(ALineNo, 'parts must be an array');
    SetLength(Result.Parts, PV.ArrayLen);
    for I := 0 to Integer(PV.ArrayLen) - 1 do
      Result.Parts[I] := DecodePart(PV.ArrayGet(I), ALineNo);
  end;

  Result.ExtraJson := OptStr(MV, 'extra', ALineNo);
end;

{ ---- 存储行为 ---- }

constructor TJsonlTranscriptStore.Create(const ARootDir: string;
  ASyncEachAppend: Boolean);
begin
  inherited Create;
  if ARootDir = '' then
    Misuse('root dir required');
  FSyncEachAppend := ASyncEachAppend;
  FRootDir := PathEnsureSep(ARootDir);
  MkdirAll(FRootDir, PermDirDefault);
end;

function TJsonlTranscriptStore.ThreadPath(
  const AThreadId: string): string;
begin
  Result := FRootDir + AThreadId + '.jsonl';
end;

procedure TJsonlTranscriptStore.LoadFile(const APath: string;
  out AMsgs: TMessageArray);
var
  LText: string;
  LLen, LPos, LSegStart, LLineNo, LN: Integer;
  LLine: string;
  LM: TMessage;
begin
  AMsgs := nil;
  LText := ReadFileText(APath);
  LLen := Length(LText);
  LSegStart := 1;
  LLineNo := 0;
  LPos := 1;
  while LPos <= LLen do
  begin
    if LText[LPos] = #10 then
    begin
      Inc(LLineNo);
      LLine := System.Copy(LText, LSegStart, LPos - LSegStart);
      LN := Length(LLine);
      if (LN > 0) and (LLine[LN] = #13) then
        System.Delete(LLine, LN, 1);   { Windows CRLF 兼容；类方法 Delete 遮蔽需限定 }
      if LLine <> '' then
      begin
        LM := TranscriptMessageFromJson(LLine, LLineNo);
        SetLength(AMsgs, Length(AMsgs) + 1);
        AMsgs[High(AMsgs)] := LM;
      end;
      LSegStart := LPos + 1;
    end;
    Inc(LPos);
  end;
  { 末段无换行 = torn tail：丢弃不计（SESSION.md §4）}
end;

{ 正例(F-L03)：Write → Sync → Close 每行落盘，SyncEachAppend=true 时
  崩溃最多丢 torn tail（末段无 \n 丢弃，LoadFile 已实现）；False 模式
  窗口扩大属显式权衡，行内无裸换行由 builder 转义保证 }
procedure TJsonlTranscriptStore.Append(const AThreadId: string;
  const AMsg: TMessage);
var
  LF: IFile;
  LPayload: string;
begin
  ValidateThreadId(AThreadId);
  LPayload := TranscriptMessageToJson(AMsg) + #10;
  LF := Open(ThreadPath(AThreadId), [fmWrite, fmAppend, fmCreate]);
  try
    LF.Write(PChar(LPayload)^, Length(LPayload));
    if FSyncEachAppend then
      LF.Sync;
  finally
    LF.Close;
  end;
end;

function TJsonlTranscriptStore.Load(
  const AThreadId: string): TMessageArray;
begin
  ValidateThreadId(AThreadId);
  Result := nil;
  if Exists(ThreadPath(AThreadId)) then
    LoadFile(ThreadPath(AThreadId), Result);
end;

procedure TJsonlTranscriptStore.Delete(const AThreadId: string);
begin
  ValidateThreadId(AThreadId);
  if Exists(ThreadPath(AThreadId)) then
    Remove(ThreadPath(AThreadId));     { 幂等；失败让 fs 异常穿透 }
end;

procedure TJsonlTranscriptStore.Fork(
  const ASrcThreadId, ADstThreadId: string);
var
  LMsgs: TMessageArray;
  LSB: IStringBuilder;
  I: Integer;
  LDstPath: string;
begin
  ValidateThreadId(ASrcThreadId);
  ValidateThreadId(ADstThreadId);
  if ASrcThreadId = ADstThreadId then
    Misuse('fork source equals target');
  LDstPath := ThreadPath(ADstThreadId);
  if Exists(LDstPath) then
    Misuse('fork target already exists');

  if Exists(ThreadPath(ASrcThreadId)) then
    LoadFile(ThreadPath(ASrcThreadId), LMsgs)
  else
    LMsgs := nil;
  LSB := MakeStringBuilder(CAgentSessionForkInitialCap);
  for I := 0 to High(LMsgs) do
  begin
    LSB.AppendStr(TranscriptMessageToJson(LMsgs[I]));
    LSB.AppendChar(#10);
  end;
  WriteAtomic(LDstPath, StringToBytes(LSB.ToString));
end;

function NewJsonlTranscriptStore(const ARootDir: string;
  ASyncEachAppend: Boolean = True): IAgentTranscriptStore;
begin
  Result := TJsonlTranscriptStore.Create(ARootDir, ASyncEachAppend);
end;

end.

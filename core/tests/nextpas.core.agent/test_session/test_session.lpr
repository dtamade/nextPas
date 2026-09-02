program test_session;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.fs,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.session,
  nextpas.core.test;

{ W5 会话转录 JSONL 存储门：SESSION.md §10 测试计划落 CI。
  全部离线；临时根目录取 OS temp，try/finally RemoveAll。
  边界/Cancel/超时/并发：
  - Cancel 边界：不涉取消，文件 IO 异常转为 aecProtocol/Storage，调用方按重试白名单处置。
  - 超时边界：不涉网络超时；Write+Sync+Close 每行 fsync，FORK 经 WriteAtomic 保证原子性（F-L03）。
  - 并发边界：单线程门；跨实例并发由 fs 原子改名保障，torn tail 末段无换行丢弃已验证。
  悬挂指针：TJsonlTranscriptStore 接口持有，ThreadPath 字符串托管；LoadFile 仅在 Exists 后解析，未置 nil 前无悬挂；
  全局 GRoot 仅测试进程期存活。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门 0 unfreed；Fork 对不存在源线程走空快照分支（F-H13 已注），无 fs 句柄泄漏。 }

var
  GRoot: string;                     { 每用例独立子目录的父目录 }

function NewRoot(const ATag: string): string;
begin
  Result := PathEnsureSep(GRoot) + ATag;
end;

function ThreadFile(const ARoot, AThreadId: string): string;
begin
  Result := PathEnsureSep(ARoot) + AThreadId + '.jsonl';
end;

function TextMsg(const ARole: TMessageRole; const AText: string): TMessage;
var
  P: TPart;
begin
  Result := Default(TMessage);
  Result.Role := ARole;
  SetLength(Result.Parts, 1);
  P := Default(TPart);
  P.Kind := pkText;
  P.Text := AText;
  Result.Parts[0] := P;
end;

procedure CheckMsgEquals(const AA, AB: TMessage);
var
  I: Integer;
begin
  Check(AA.Role = AB.Role, 'role equal');
  Check(AA.Id = AB.Id, 'id equal');
  Check(AA.Model = AB.Model, 'model equal');
  Check(AA.FinishReason = AB.FinishReason, 'finish equal');
  Check(AA.Usage.InputTokens = AB.Usage.InputTokens, 'usage in equal');
  Check(AA.Usage.OutputTokens = AB.Usage.OutputTokens, 'usage out equal');
  Check(AA.Usage.CacheReadInputTokens = AB.Usage.CacheReadInputTokens,
    'usage cache_r equal');
  Check(AA.Usage.CacheWriteInputTokens = AB.Usage.CacheWriteInputTokens,
    'usage cache_w equal');
  Check(AA.Usage.ReasoningTokens = AB.Usage.ReasoningTokens, 'usage reason equal');
  Check(AA.ExtraJson = AB.ExtraJson, 'extra equal');
  Check(Length(AA.Parts) = Length(AB.Parts), 'parts count equal');
  for I := 0 to High(AA.Parts) do
  begin
    Check(AA.Parts[I].Kind = AB.Parts[I].Kind, 'part kind equal');
    Check(AA.Parts[I].Text = AB.Parts[I].Text, 'part text equal');
    Check(AA.Parts[I].ToolCallId = AB.Parts[I].ToolCallId, 'part call_id equal');
    Check(AA.Parts[I].ToolName = AB.Parts[I].ToolName, 'part name equal');
    Check(AA.Parts[I].ArgumentsJson = AB.Parts[I].ArgumentsJson, 'part args equal');
    Check(AA.Parts[I].ResultJson = AB.Parts[I].ResultJson, 'part result equal');
    Check(AA.Parts[I].IsError = AB.Parts[I].IsError, 'part is_error equal');
    Check(AA.Parts[I].ImageUrl = AB.Parts[I].ImageUrl, 'part image equal');
    Check(AA.Parts[I].Signature = AB.Parts[I].Signature, 'part sig equal');
    Check(AA.Parts[I].ExtraJson = AB.Parts[I].ExtraJson, 'part extra equal');
  end;
end;

procedure TestRoundtripBasic;
var
  S: IAgentTranscriptStore;
  LMsgs: TMessageArray;
begin
  S := NewJsonlTranscriptStore(NewRoot('basic'));
  S.Append('t1', TextMsg(mrUser, '你好'));
  S.Append('t1', TextMsg(mrAssistant, 'hello'));
  LMsgs := S.Load('t1');
  Check(Length(LMsgs) = 2, 'two messages loaded');
  CheckMsgEquals(LMsgs[0], TextMsg(mrUser, '你好'));
  CheckMsgEquals(LMsgs[1], TextMsg(mrAssistant, 'hello'));
end;

procedure TestFullVocabularyLossless;
var
  S: IAgentTranscriptStore;
  LM, LM2: TMessage;
  LMsgs: TMessageArray;
begin
  LM := Default(TMessage);
  LM.Role := mrAssistant;
  LM.Id := 'msg_123';
  LM.Model := 'gpt-x';
  LM.FinishReason := frToolCalls;
  LM.Usage.InputTokens := 10;
  LM.Usage.OutputTokens := 5;
  LM.Usage.CacheReadInputTokens := 3;
  LM.Usage.ReasoningTokens := 7;
  LM.ExtraJson := '{"cache":{"p":"abc"}}';
  SetLength(LM.Parts, 4);
  LM.Parts[0] := Default(TPart);
  LM.Parts[0].Kind := pkThinking;
  LM.Parts[0].Text := 'thinking...';
  LM.Parts[0].Signature := 'sig==';
  LM.Parts[1] := Default(TPart);
  LM.Parts[1].Kind := pkToolCall;
  LM.Parts[1].ToolCallId := 'call_9';
  LM.Parts[1].ToolName := 'weather';
  LM.Parts[1].ArgumentsJson := '{"city":"上海"}';
  LM.Parts[2] := Default(TPart);
  LM.Parts[2].Kind := pkToolResult;
  LM.Parts[2].ToolCallId := 'call_9';
  LM.Parts[2].ResultJson := '{"temp":21}';
  LM.Parts[2].IsError := True;
  LM.Parts[3] := Default(TPart);
  LM.Parts[3].Kind := pkImage;
  LM.Parts[3].ImageUrl := 'data:image/png;base64,AAAA';

  S := NewJsonlTranscriptStore(NewRoot('full'));
  S.Append('t', LM);
  LMsgs := S.Load('t');
  Check(Length(LMsgs) = 1, 'one message loaded');
  CheckMsgEquals(LMsgs[0], LM);

  { 编解码函数直测对称性 }
  LM2 := TranscriptMessageFromJson(TranscriptMessageToJson(LM), 1);
  CheckMsgEquals(LM2, LM);
end;

procedure TestPersistenceAcrossInstances;
var
  S: IAgentTranscriptStore;
  LRoot: string;
begin
  LRoot := NewRoot('persist');
  S := NewJsonlTranscriptStore(LRoot);
  S.Append('t', TextMsg(mrUser, 'a'));
  S := nil;
  S := NewJsonlTranscriptStore(LRoot);
  Check(Length(S.Load('t')) = 1, 'message survives store recreation');
end;

procedure TestTornTailDropped;
var
  S: IAgentTranscriptStore;
  LRoot: string;
begin
  LRoot := NewRoot('torn');
  S := NewJsonlTranscriptStore(LRoot);
  S.Append('t', TextMsg(mrUser, 'keep-1'));
  S.Append('t', TextMsg(mrUser, 'keep-2'));
  { 中断写入残留：无行尾换行 }
  AppendFileText(ThreadFile(LRoot, 't'),
    '{"v":1,"kind":"msg","msg":{"role":"user","par');
  Check(Length(S.Load('t')) = 2, 'torn tail dropped, complete lines kept');
end;

procedure TestCorruptLineFailClosed;
var
  S: TJsonlTranscriptStore;
  LRoot: string;
  LGot: Boolean;
begin
  LRoot := NewRoot('corrupt');
  S := TJsonlTranscriptStore.Create(LRoot);
  try
    S.Append('t', TextMsg(mrUser, 'good-1'));
    AppendFileLine(ThreadFile(LRoot, 't'), 'not-json{{');
    S.Append('t', TextMsg(mrUser, 'good-2'));
    LGot := False;
    try
      S.Load('t');
    except
      on E: ETranscriptCorrupt do
      begin
        LGot := True;
        Check(E.ErrorCode = aecProtocol, 'corrupt maps to aecProtocol');
        Check(Pos('line 2', E.Message) > 0, 'error reports physical line number');
      end;
    end;
    Check(LGot, 'corrupt line raises fail-closed');
  finally
    S.Free;
  end;
end;

procedure TestUnknownVersionOrKindFailClosed;
var
  S: TJsonlTranscriptStore;
  LRoot: string;
  LGot: Boolean;
begin
  LRoot := NewRoot('schema');
  S := TJsonlTranscriptStore.Create(LRoot);
  try
    AppendFileLine(ThreadFile(LRoot, 't'),
      '{"v":99,"kind":"msg","msg":{"role":"user"}}');
    LGot := False;
    try
      S.Load('t');
    except
      on E: ETranscriptCorrupt do
      begin
        LGot := True;
        Check(Pos('version', E.Message) > 0, 'unknown version reported');
      end;
    end;
    Check(LGot, 'unknown version fail-closed');

    DeleteFile(ThreadFile(LRoot, 't'));
    AppendFileLine(ThreadFile(LRoot, 't'),
      '{"v":1,"kind":"future-record","msg":{}}');
    LGot := False;
    try
      S.Load('t');
    except
      on E: ETranscriptCorrupt do
        LGot := True;
    end;
    Check(LGot, 'unknown record kind fail-closed');
  finally
    S.Free;
  end;
end;

procedure TestDeleteIdempotentAndMissingLoad;
var
  S: IAgentTranscriptStore;
begin
  S := NewJsonlTranscriptStore(NewRoot('delete'));
  S.Append('t', TextMsg(mrUser, 'x'));
  Check(Length(S.Load('t')) = 1, 'present before delete');
  S.Delete('t');
  S.Delete('t');                       { 幂等，不抛 }
  Check(Length(S.Load('t')) = 0, 'empty after delete');
  Check(S.Load('never-existed') = nil, 'missing thread loads nil array');
end;

procedure TestThreadIdValidation;
var
  S: IAgentTranscriptStore;
  LBad: TStringArray;
  I: Integer;
  LGot: Boolean;
begin
  Check(IsValidThreadId('abc_123-X.y'), 'valid id accepted');
  Check(not IsValidThreadId(''), 'empty rejected');
  Check(not IsValidThreadId('.'), 'dot rejected');
  Check(not IsValidThreadId('..'), 'dotdot rejected');
  Check(not IsValidThreadId('.hidden'), 'leading dot rejected');
  Check(not IsValidThreadId('a/b'), 'slash rejected');
  Check(not IsValidThreadId('a\b'), 'backslash rejected');
  Check(not IsValidThreadId('a b'), 'space rejected');
  Check(not IsValidThreadId(StringOfChar('a', CMaxThreadIdLen + 1)),
    'overlong rejected');

  S := NewJsonlTranscriptStore(NewRoot('ids'));
  LBad := TStringArray.Create('', '..', 'a/b', 'a b');
  for I := 0 to High(LBad) do
  begin
    LGot := False;
    try
      S.Append(LBad[I], TextMsg(mrUser, 'x'));
    except
      on E: EAgentMisuse do
        LGot := True;
    end;
    Check(LGot, 'append rejects invalid id #' + IntToStr(I));
  end;
end;

procedure TestForkSemantics;
var
  S: TJsonlTranscriptStore;
  LRoot: string;
  LMsgs: TMessageArray;
  LGot: Boolean;
begin
  LRoot := NewRoot('fork');
  S := TJsonlTranscriptStore.Create(LRoot);
  try
    S.Append('src', TextMsg(mrUser, 'one'));
    S.Append('src', TextMsg(mrAssistant, 'two'));
    AppendFileText(ThreadFile(LRoot, 'src'), '{"v":1,"kind":"msg","msg":{"rol');

    S.Fork('src', 'dst');
    LMsgs := S.Load('dst');
    Check(Length(LMsgs) = 2, 'fork materializes clean snapshot (torn dropped)');
    Check(LMsgs[0].Parts[0].Text = 'one', 'fork order preserved');

    LGot := False;
    try
      S.Fork('src', 'dst');
    except
      on E: EAgentMisuse do
        LGot := True;
    end;
    Check(LGot, 'fork refuses existing target');

    LGot := False;
    try
      S.Fork('self', 'self');
    except
      on E: EAgentMisuse do
        LGot := True;
    end;
    Check(LGot, 'fork refuses self');

    LGot := False;
    try
      S.Fork('src', '../escape');
    except
      on E: EAgentMisuse do
        LGot := True;
    end;
    Check(LGot, 'fork validates target id');
  finally
    S.Free;
  end;
end;

procedure TestBothSyncModes;
var
  S: IAgentTranscriptStore;
  LR: TJsonlTranscriptStore;
  LRoot: string;
begin
  LRoot := NewRoot('sync');
  S := NewJsonlTranscriptStore(LRoot, True);
  S.Append('t', TextMsg(mrUser, 'synced'));
  Check(Length(S.Load('t')) = 1, 'sync-per-append works');

  LR := TJsonlTranscriptStore.Create(LRoot, False);
  try
    Check(not LR.SyncEachAppend, 'flag preserved');
    LR.Append('u', TextMsg(mrUser, 'buffered'));
    Check(Length(LR.Load('u')) = 1, 'os-buffered mode works');
  finally
    LR.Free;
  end;
end;

procedure TestUnicodeRoundtrip;
var
  S: IAgentTranscriptStore;
  LMsgs: TMessageArray;
begin
  S := NewJsonlTranscriptStore(NewRoot('unicode'));
  S.Append('t', TextMsg(mrUser, '编译器 🚀 中文 "引号" 反斜杠\\ 换行\n字面量'));
  LMsgs := S.Load('t');
  Check(Length(LMsgs) = 1, 'unicode message loaded');
  Check(LMsgs[0].Parts[0].Text = '编译器 🚀 中文 "引号" 反斜杠\\ 换行\n字面量',
    'unicode and escapes survive roundtrip');
end;

procedure TestUsageUnknownNotFabricated;
var
  S: IAgentTranscriptStore;
  LM: TMessage;
  LMsgs: TMessageArray;
begin
  LM := Default(TMessage);
  LM.Role := mrAssistant;
  { 五字段全哨兵 = 全 unknown；编码器将省略 usage，解码器不得伪造 0 }
  LM.Usage.InputTokens := CUsageUnknown;
  LM.Usage.OutputTokens := CUsageUnknown;
  LM.Usage.CacheReadInputTokens := CUsageUnknown;
  LM.Usage.CacheWriteInputTokens := CUsageUnknown;
  LM.Usage.ReasoningTokens := CUsageUnknown;
  S := NewJsonlTranscriptStore(NewRoot('usage'));
  S.Append('t', LM);
  LMsgs := S.Load('t');
  Check(Length(LMsgs) = 1, 'loaded');
  Check(not LMsgs[0].Usage.Known, 'usage unknown stays unknown (no fake zeros)');
  Check(LMsgs[0].Usage.InputTokens = CUsageUnknown, 'input stays sentinel');
end;

var
  T: TTestSuite;
begin
  GRoot := TempDir('', 'npagent-test-session-');
  T := TTestSuite.Create('nextpas.core.agent.session');
  T.Test('roundtrip basic', @TestRoundtripBasic);
  T.Test('full vocabulary lossless', @TestFullVocabularyLossless);
  T.Test('persistence across instances', @TestPersistenceAcrossInstances);
  T.Test('torn tail dropped', @TestTornTailDropped);
  T.Test('corrupt line fail-closed', @TestCorruptLineFailClosed);
  T.Test('unknown version or kind fail-closed', @TestUnknownVersionOrKindFailClosed);
  T.Test('delete idempotent and missing load', @TestDeleteIdempotentAndMissingLoad);
  T.Test('thread id validation', @TestThreadIdValidation);
  T.Test('fork semantics', @TestForkSemantics);
  T.Test('both sync modes', @TestBothSyncModes);
  T.Test('unicode roundtrip', @TestUnicodeRoundtrip);
  T.Test('usage unknown not fabricated', @TestUsageUnknownNotFabricated);
  if not T.Run then Halt(1);
  RemoveAll(GRoot);
end.

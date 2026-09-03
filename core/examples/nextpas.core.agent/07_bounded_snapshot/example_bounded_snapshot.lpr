program example_bounded_snapshot;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.utf8,
  nextpas.core.agent.base,
  nextpas.core.agent.intf,
  nextpas.core.agent.pricing,
  nextpas.core.agent.snapshot,
  nextpas.core.agent.provider.fake;

{ 07 有界快照：6000 B 预算内的系统提示合并去重 + 加权估算 + 簇安全截断 + 成本联动
  契约锚点：PROMPT-BUDGET.md §2/§5/§7 + PERFORMANCE.md §7.1 + API.md §10
  运行：make -C core/examples/nextpas.core.agent/07_bounded_snapshot run
  离线可跑：fake provider 零网络，带 emoji 序列演示半切防护 }

const
  CBUDGET = 6000;
  CSCRIPT =
    '[{"deltas":[' +
    '{"kind":"text_delta","text":"已收到有界快照"},' +
    '{"kind":"finish","reason":"stop"},' +
    '{"kind":"usage","in":18,"out":6}]}]';

function MakeHistoryWithDupSystem: TMessageArray;
var
  M: TMessage;
begin
  SetLength(Result, 3);
  // 模拟历史中残留的 mrSystem（去重后不应膨胀前缀）
  M := Default(TMessage);
  M.Role := mrSystem;
  SetLength(M.Parts, 1);
  M.Parts[0] := Default(TPart);
  M.Parts[0].Kind := pkText;
  M.Parts[0].Text := '你是一个简洁的助手';
  Result[0] := M;
  M := Default(TMessage);
  M.Role := mrUser;
  SetLength(M.Parts, 1);
  M.Parts[0].Kind := pkText;
  M.Parts[0].Text := '介绍 TLS 1.3';
  Result[1] := M;
  M := Default(TMessage);
  M.Role := mrAssistant;
  SetLength(M.Parts, 1);
  M.Parts[0].Kind := pkText;
  M.Parts[0].Text := 'TLS 1.3 是 ...';
  Result[2] := M;
end;

var
  LReq: TCompletionRequest;
  LProv: IAgentProvider;
  LSysText, LTrunc: string;
  LBudgetCut: Integer;
  LTokens, LCost: Int64;
  LReply: TMessage;
  LRaw, LFill: string;
begin
  // 构造含重复 system 的请求：顶层 System + 历史 mrSystem
  LReq := TCompletionRequest.New('fake-model')
    .WithSystem('你是一个简洁的助手，优先用中文回答。') // 与历史第一条重复，触发去重
    .WithMessages(MakeHistoryWithDupSystem)
    .WithUserText('用一句话总结上一条');

  // 有界快照：system 去重拼接（PROMPT-BUDGET §2）——演示两条路径：
  // 1) 底层原语 AgentBuildSystemText 直调  2) 一站式 BuildBoundedSnapshot（经 nextpas.core.agent.snapshot 复用）
  LSysText := AgentBuildSystemText(LReq.System, LReq.Messages);
  WriteLn('system merged bytes: ', Length(LSysText));
  WriteLn('system merged preview: ', Copy(LSysText, 1, 80));
  WriteLn('snapshot via module: ', Length(BuildBoundedSnapshot(LReq.System, LReq.Messages, CBUDGET)), ' bytes (budget ', CBUDGET, ')');

  // 加权估算：每轮预算守卫（PROMPT-BUDGET §3）——底层 vs 模块一站式
  LTokens := AgentEstimateTokens(LSysText);
  LCost := EstimateCost(LTokens, 0);
  WriteLn('weighted tokens ~', LTokens, ' cost ~', LCost, ' μUSD');
  WriteLn('snapshot tokens via module ~', BoundedSnapshotTokens(BuildBoundedSnapshot(LReq.System, LReq.Messages, CBUDGET)),
    ' cost ~', BoundedSnapshotCost(BuildBoundedSnapshot(LReq.System, LReq.Messages, CBUDGET), 0), ' μUSD');

  // 簇安全截断演示：含 ZWJ/RI 序列的长 system（经 nextpas.core 数值域构造，避免直接依赖 FPC RTL StringOfChar/SysUtils）
  begin
    SetLength(LFill, CBUDGET);
    if CBUDGET > 0 then
      FillChar(LFill[1], CBUDGET, Byte('a'));
    LRaw := LSysText + ' ' + LFill + ' 👨‍👩‍👧 🇨🇳 1️⃣';
  end;
  if Length(LRaw) > CBUDGET then
  begin
    // 后向 UTF-8 边界 + 单一真源截断（PERFORMANCE §7.1）
    LBudgetCut := AgentUtf8SafeCutLen(LRaw, CBUDGET);
    LTrunc := AgentUtf8SafeTruncate(LRaw, LBudgetCut);
    WriteLn('raw ', Length(LRaw), ' -> truncated ', Length(LTrunc),
      ' (cut=', LBudgetCut, ', utf8-safe)');
    // 证明未半切：截后仍为合法 UTF-8，可被 LowerCase 等消费而不抛错
    WriteLn('tail bytes ok: ', Length(LTrunc) <= CBUDGET);
  end
  else
    LTrunc := LRaw;

  // 成本联动：用截后文本作为预算内快照的计费输入
  LTokens := AgentEstimateTokens(LTrunc);
  LCost := EstimateCost(LTokens, 64); // 假设 64 输出 token
  WriteLn('bounded snapshot tokens ~', LTokens, ' est cost(prompt+64out)=', LCost, ' μUSD');

  // 离线闭环：fake provider 验证请求侧不受截断影响（PROMPT-BUDGET §7）
  LProv := NewFakeProvider(CSCRIPT);
  // 将截后 system 作为真实请求的 system 字段发送，证明 wire 侧零额外拷贝
  LReq.System := LTrunc;
  LReply := LProv.Complete(LReq);
  WriteLn('reply: ', MessageText(LReply));
  if LReply.Usage.Known then
    WriteLn('usage: in=', LReply.Usage.InputTokens, ' out=', LReply.Usage.OutputTokens,
      ' cost=', EstimateCost(LReply.Usage), ' μUSD');
end.

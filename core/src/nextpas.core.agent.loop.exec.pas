{**
 * nextpas.core.agent.loop.exec - 工具批装配与分组执行。
 *
 * 职责：Slot 建模（skExec/skBlocked/skInvalid/skUnknown）、
 * 合成错误信封、W13 相邻 tcParallel 分组调度、Pre/Post hook 编排、
 * 截断信封化与 RunToolBatch 接线。
 * 契约权威：API.md §6；LIFECYCLE §5；ARCHITECTURE §2。
 * 分层：仅依赖 types + base / intf / tools / clock / thread，无循环。
 *}

unit nextpas.core.agent.loop.exec;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.cancellation,
  nextpas.core.thread.intf,
  nextpas.core.agent.base,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.tools,
  nextpas.core.agent.loop.types;

type
  TSlotKind = (skExec, skBlocked, skInvalid, skUnknown);

  TSlot = record
    Kind: TSlotKind;
    CallPartIdx: Integer;            { assistant 消息内的 pkToolCall 下标 }
    Spec: TToolSpec;
    Res: TToolResult;                { 最终回喂载荷（已截断信封化）}
  end;

procedure LoopSynthErr(var ASlot: TSlot; const AMsg: string);

function LoopFindSpec(const ASpecs: TToolSpecArray;
  const AName: string): TToolSpec;

function LoopHasSpec(const ASpecs: TToolSpecArray;
  const AName: string): Boolean;

function LoopFindTool(const ATools: array of IAgentTool;
  const AName: string): IAgentTool;

{ 分组执行：W13 相邻 tcParallel 段整段并行，非并行独占单批。
  AJobs 为待执行 job 数组（非拥有视图由调用方持有），FPool 负责提交。 }
procedure LoopRunGrouped(const AJobs: array of TToolJob;
  const APool: IThreadPool; const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken);

{ 截断信封化 + PostHook 编排：对已完成的 Slots 做 EnvelopeTruncation
  并调用 PostHook（只见截断后载荷，DoS 时序）。返回是否触发 hvStop。 }
function LoopFinalizeSlots(var ASlots: array of TSlot;
  const ASlotJob: array of Integer; const AJobs: array of TToolJob;
  ATruncateLines, ATruncateBytes: Integer;
  const APostHook: TLoopHook; out AStopped: Boolean): Integer;

implementation

uses
  nextpas.core.json.builder;

procedure LoopSynthErr(var ASlot: TSlot; const AMsg: string);
var
  LB: IJsonBuilder;
begin
  LB := JsonBuilder;
  LB.BeginObject;
  LB.Key('error');
  LB.Str(AMsg);
  LB.EndObject;
  ASlot.Res := Default(TToolResult);
  ASlot.Res.ContentJson := LB.ToString;
  ASlot.Res.IsError := True;
end;

function LoopFindSpec(const ASpecs: TToolSpecArray;
  const AName: string): TToolSpec;
var
  I: Integer;
begin
  for I := 0 to High(ASpecs) do
    if ASpecs[I].Name = AName then
      Exit(ASpecs[I]);
  Result := Default(TToolSpec);
end;

function LoopHasSpec(const ASpecs: TToolSpecArray;
  const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ASpecs) do
    if ASpecs[I].Name = AName then
      Exit(True);
  Result := False;
end;

function LoopFindTool(const ATools: array of IAgentTool;
  const AName: string): IAgentTool;
var
  I: Integer;
begin
  for I := 0 to High(ATools) do
    if ATools[I].Spec.Name = AName then
      Exit(ATools[I]);
  Result := nil;
end;

procedure LoopRunGrouped(const AJobs: array of TToolJob;
  const APool: IThreadPool; const AClock: IAgentClock;
  const AToken: IAsyncCancellationToken);
var
  G, H, I: Integer;
  Group: array of TToolJob;
  One: array[0..0] of TToolJob;
begin
  if Length(AJobs) = 0 then
    Exit;
  G := 0;
  while G <= High(AJobs) do
  begin
    if Assigned(AToken) and AToken.IsCancelled then
      Break;
    if tcParallel in AJobs[G].Tool.Spec.Capabilities then
    begin
      H := G;
      while (H < High(AJobs)) and
        (tcParallel in AJobs[H + 1].Tool.Spec.Capabilities) do
        Inc(H);
      SetLength(Group, H - G + 1);
      for I := G to H do
        Group[I - G] := AJobs[I];
      RunToolBatch(Group, APool, AClock, AToken);
      G := H + 1;
    end
    else
    begin
      One[0] := AJobs[G];
      RunToolBatch(One, APool, AClock, AToken);
      Inc(G);
    end;
  end;
  SetLength(Group, 0);
end;

function LoopFinalizeSlots(var ASlots: array of TSlot;
  const ASlotJob: array of Integer; const AJobs: array of TToolJob;
  ATruncateLines, ATruncateBytes: Integer;
  const APostHook: TLoopHook; out AStopped: Boolean): Integer;
var
  I: Integer;
  Env: TToolResult;
  Verdict: THookVerdict;
begin
  AStopped := False;
  Result := 0;
  for I := 0 to High(ASlots) do
  begin
    if ASlots[I].Kind = skBlocked then
      Continue;
    // 预算口径：allowance 内所有非 Blocked 槽（skExec/skInvalid/skUnknown）均消耗 MaxToolCalls
    // skInvalid/skUnknown 无 Job，跳过截断/hook 但仍计预算，防止异常参数绕过预算
    if (ASlots[I].Kind = skExec) and (ASlotJob[I] >= 0) and (ASlotJob[I] < Length(AJobs)) then
    begin
      Env := EnvelopeTruncation(AJobs[ASlotJob[I]].Res,
        ATruncateLines, ATruncateBytes);
      if Assigned(APostHook) then
      begin
        Verdict := APostHook(ASlots[I].Spec, Env.ContentJson);
        if Verdict = hvBlock then
        begin
          LoopSynthErr(ASlots[I], 'blocked by post-tool-result hook');
          Env := ASlots[I].Res;
        end
        else if Verdict = hvStop then
          AStopped := True;
      end;
      ASlots[I].Res := Env;
    end;
    Inc(Result);
  end;
end;

end.

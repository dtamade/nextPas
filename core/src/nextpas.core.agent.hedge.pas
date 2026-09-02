(*
 * nextpas.core.agent.hedge - WithHedge 对冲装饰器（W9 可靠性四象限收官件）。
 *
 * 契约权威：core/docs/agent/API.md §装饰器组合（NewHedgedProvider 语义）。
 * 四象限定位：retry 败后重试 / fallback 败后换家 / throttle 事前整形 /
 * hedge 慢时对冲——主路 DelayMs 无响应即并发第二路取先达。
 *
 * 并发模型：自有双工线程池 + 手动复位事件；调用方线程充当定时器与仲裁者，
 * 切片等待复用 IEvent.WaitTimeout（200µs，LIFECYCLE §5 loop 同款形态）。
 * 两路各用独立取消令牌；外部令牌取消随时优先。落定规则：先落定者成功即
 * 胜出并取消输路；先落定者失败且对冲已发起则等其落定，皆败透传主路原始
 * 错误（retry/fallback 同哲学）。流式以首 delta 为落定点——投递不重复
 * （首 delta 门同门），输流必被 Cancel 且增量永不外泄。
 *
 * Join 完整性：所有出口前都等对应 worker 落定（输路经令牌/comp.Cancel
 * 中断在途请求，transport 层令牌贯通为 W2 既立事实）；产物槽归调用方
 * try..finally 所有，无悬垂窗口。外部取消同样先取消两路再 join 后上抛。
 *
 * 成本明示：对冲路是完整第二次请求，双倍 token 成本由 DelayMs>0 的显式
 * opt-in 表达（工厂校验 DelayMs<=0 → aecConfig）。
 *)

unit nextpas.core.agent.hedge;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sync.intf,
  nextpas.core.sync.event,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.provider.common;

type
  { 对冲路发起时上报：参数即本次生效的 DelayMs（实例仅调用期有效）}
  THedgeFireHook = reference to procedure(ADelayMs: Int64);

  THedgePolicy = record
    DelayMs: Int64;                  { 主路无响应阈值；必填 >0（显式 opt-in）}
    OnHedged: THedgeFireHook;        { nil=静默 }
    class function Default(ADelayMs: Int64): THedgePolicy; static;
  end;

{ AClock 为形状一致性保留位（与 throttle/retry 同签名美学）；当前计时走
  高分辨率事件等待，时序测试以可控编排 provider 门闩实现。
  DelayMs<=0 在工厂层拦截（对象未创建即拒，规避构造器半初始化清理路径）}
function NewHedgedProvider(const AInner: IAgentProvider;
  const AClock: IAgentClock; const APolicy: THedgePolicy): IAgentProvider;

implementation

uses
  nextpas.core.thread,
  nextpas.core.atomic.core;

const
  CArbitrationSliceNs = 200000;      { 仲裁轮询切片 200µs，与 tools/loop G3 统一 }

type
  { 单次调用产物槽：worker 写入后 SetEvent 发布；调用方 join 后读取。
    所有权归调用方 try..finally——join 完整性保证无悬垂 }
  THedgeOutcome = class
  public
    HaveValue: Boolean;              { Complete: 成功回包；Stream: 流可用 }
    Msg: TMessage;
    Comp: IAgentCompletion;          { Stream: 流（首点已消费态交还）}
    FirstDelta: TStreamDelta;
    HaveFirst: Boolean;
    Fail: TProviderFailure;          { 失败快照（跨线程重建）}
    Aborted: Boolean;                { 入口即取消：从未触达 inner }
    Cancelled: Boolean;              { inner 以 EAgentCancelled 收场 }
  end;

  THedgedProvider = class(TInterfacedObject, IAgentProvider)
  private
    FInner: IAgentProvider;
    FClock: IAgentClock;
    FPolicy: THedgePolicy;
    FAmbientToken: IAsyncCancellationToken;
    FPool: IThreadPool;
    procedure RunCompleteTask(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken; const AOut: THedgeOutcome;
      const ADone: IEvent);
    procedure RunStreamTask(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken; const AOut: THedgeOutcome;
      const ADone: IEvent);
    procedure SliceWait(const ATick: IEvent);
    function GetName: string;
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  public
    constructor Create(const AInner: IAgentProvider;
      const AClock: IAgentClock; const APolicy: THedgePolicy;
      const AToken: IAsyncCancellationToken);
    destructor Destroy; override;
  end;

{ ---- THedgePolicy ---- }

class function THedgePolicy.Default(ADelayMs: Int64): THedgePolicy;
begin
  Result.DelayMs := ADelayMs;
  Result.OnHedged := nil;
end;

{ ---- THedgedProvider ---- }

constructor THedgedProvider.Create(const AInner: IAgentProvider;
  const AClock: IAgentClock; const APolicy: THedgePolicy;
  const AToken: IAsyncCancellationToken);
begin
  inherited Create;
  if AInner = nil then
    raise EAgentError.CreateLocal(aecConfig,
      'NewHedgedProvider: inner is required');
  if AClock = nil then
    raise EAgentError.CreateLocal(aecConfig,
      'NewHedgedProvider: clock is required');
  if APolicy.DelayMs <= 0 then
    raise EAgentError.CreateLocal(aecConfig,
      'NewHedgedProvider: DelayMs must be > 0 (explicit double-cost ' +
      'opt-in)');
  FInner := AInner;
  FClock := AClock;
  FPolicy := APolicy;
  FAmbientToken := AToken;
  FPool := ThreadPool(2);            { 构造即建池；随实例 Shutdown（D9 先例）}
end;

destructor THedgedProvider.Destroy;
begin
  { 构造器校验失败路径会以半初始化态进入 Destroy（W2 孤儿教训同款）：
    FPool 可能尚未创建 }
  if FPool <> nil then
    FPool.Shutdown;
  inherited Destroy;
end;

function THedgedProvider.GetName: string;
begin
  Result := FInner.GetName;
end;

procedure THedgedProvider.SliceWait(const ATick: IEvent);
begin
  { 哑事件纯超时睡眠：永不 Set 的 manual-reset 事件即 ns 级切片定时器 }
  ATick.WaitTimeout(CArbitrationSliceNs);
end;

{ worker：Complete 路。异常全覆盖绝不逃出 worker（池纪律）}
procedure THedgedProvider.RunCompleteTask(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken; const AOut: THedgeOutcome;
  const ADone: IEvent);
begin
  try
    if (AToken <> nil) and AToken.IsCancelled then
      AOut.Aborted := True
    else
    try
      AOut.Msg := FInner.Complete(AReq, AToken);
      AOut.HaveValue := True;
    except
      on E: EAgentCancelled do
        AOut.Cancelled := True;
      on E: EAgentError do
        AOut.Fail.Capture(E);
    end;
    atomic_seq_cst_fence;            { 发布前 fence，保证前述写对读线程可见（F-H06） }
    ADone.SetEvent;                  { 发布栅栏：字段写在 Set 前 }
  except
    ;                                { 兜底：worker 绝不让异常逃逸 }
  end;
end;

{ worker：Stream 路——取到首点（delta 或 EOF）即算落定并交回流接口 }
procedure THedgedProvider.RunStreamTask(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken; const AOut: THedgeOutcome;
  const ADone: IEvent);
var
  LD: TStreamDelta;
begin
  try
    if (AToken <> nil) and AToken.IsCancelled then
      AOut.Aborted := True
    else
    try
      LD := Default(TStreamDelta);   { EOF 路径 out 值的确定性防御 }
      AOut.Comp := FInner.Stream(AReq, AToken);
      AOut.HaveFirst := AOut.Comp.NextDelta(LD);
      AOut.FirstDelta := LD;
      AOut.HaveValue := True;        { 流可用即值（EOF 合法：fold 空收口）}
    except
      on E: EAgentCancelled do
        AOut.Cancelled := True;
      on E: EAgentError do
        AOut.Fail.Capture(E);
    end;
    atomic_seq_cst_fence;
    ADone.SetEvent;
  except
    ;
  end;
end;

function THedgedProvider.Complete(const AReq: TCompletionRequest): TMessage;
begin
  Result := Complete(AReq, nil);
end;

function THedgedProvider.Complete(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): TMessage;
var
  LOuter, LTokMain, LTokHedge: IAsyncCancellationToken;
  LEvMain, LEvHedge, LEvTick: IEvent;
  LMain, LHedge: THedgeOutcome;
  LHedgeFired, LOuterGone: Boolean;
  LRemainNs, LSliceNs: Int64;

  function OuterGone: Boolean;
  begin
    Result := (LOuter <> nil) and LOuter.IsCancelled;
  end;

begin
  LOuter := MergeCancellationTokens(FAmbientToken, AToken);
  RequireNotCancelled(LOuter);

  LTokMain := CreateCancellationToken;
  LEvMain := CreateEvent(True);
  LEvTick := CreateEvent(True);      { 哑事件：仅作切片睡眠载体 }
  LMain := THedgeOutcome.Create;
  LHedge := nil;
  LHedgeFired := False;
  FPool.Submit(procedure
    begin
      RunCompleteTask(AReq, LTokMain, LMain, LEvMain);
    end);

  try
    { 分片等待 DelayMs：每片 CArbitrationSliceNs 检查 Outer 取消，
      与 throttle/retry 的 WaitForCancel 分片统一（G3 协同）。 }
    LRemainNs := FPolicy.DelayMs * 1000000;
    while LRemainNs > 0 do
    begin
      if OuterGone then
        Break;
      LSliceNs := CArbitrationSliceNs;
      if LSliceNs > LRemainNs then
        LSliceNs := LRemainNs;
      if LEvMain.WaitTimeout(LSliceNs) then
        Break;
      Dec(LRemainNs, LSliceNs);
    end;
    if LEvMain.IsSet then
    begin
      atomic_seq_cst_fence;
      if LMain.HaveValue then
        Exit(LMain.Msg);
      if LMain.Cancelled or LMain.Aborted or
        (LMain.Fail.Code = aecCancelled) then
        raise EAgentCancelled.Create;
      raise LMain.Fail.Rebuild;
    end;
    if OuterGone then
    begin
      LTokMain.Cancel;
      while not LEvMain.IsSet do
        SliceWait(LEvTick);
      raise EAgentCancelled.Create;
    end;

    { 到点未完：发起对冲路 }
    if FPolicy.OnHedged <> nil then
      FPolicy.OnHedged(FPolicy.DelayMs);
    LHedgeFired := True;
    LEvHedge := CreateEvent(True);
    LTokHedge := CreateCancellationToken;
    LHedge := THedgeOutcome.Create;
    FPool.Submit(procedure
      begin
        RunCompleteTask(AReq, LTokHedge, LHedge, LEvHedge);
      end);

    { 仲裁循环：外部取消 > 先落定成功 > 皆败透传主路原始错误
      读 HaveValue 前加 acquire fence，保证 worker 的写可见（F-H06） }
    while not (LEvMain.IsSet and LEvHedge.IsSet) do
    begin
      if OuterGone then
      begin
        LTokMain.Cancel;
        LTokHedge.Cancel;
        break;                       { 入下方统一 join }
      end;
      if LEvMain.IsSet then
      begin
        atomic_seq_cst_fence;
        if LMain.HaveValue then
        begin
          LTokHedge.Cancel;          { 输路必被取消（尽力信号）}
          Break;
        end;
      end;
      if LEvHedge.IsSet then
      begin
        atomic_seq_cst_fence;
        if LHedge.HaveValue then
        begin
          LTokMain.Cancel;           { 对冲胜：主路转输路 }
          Break;
        end;
      end;
      SliceWait(LEvTick);
    end;

    { 统一 join：任何出口前等两路全落定（输路经令牌中断快速收场）}
    LOuterGone := OuterGone;
    atomic_seq_cst_fence;
    if LOuterGone or (LEvMain.IsSet and LMain.HaveValue) then
      LTokHedge.Cancel;
    atomic_seq_cst_fence;
    if LOuterGone or (LEvHedge.IsSet and LHedge.HaveValue) then
      LTokMain.Cancel;
    while (not LEvMain.IsSet) or (not LEvHedge.IsSet) do
      SliceWait(LEvTick);

    if LOuterGone then
      raise EAgentCancelled.Create;

    { 落定结果裁决：胜者优先，皆败以主路原始错误为准 }
    atomic_seq_cst_fence;
    if LMain.HaveValue then
      Exit(LMain.Msg);
    atomic_seq_cst_fence;
    if LHedge.HaveValue then
      Exit(LHedge.Msg);
    if LMain.Cancelled or LMain.Aborted or
      (LMain.Fail.Code = aecCancelled) then
      raise EAgentCancelled.Create;
    raise LMain.Fail.Rebuild;        { 文档承诺：主路原始错误透传 }
  finally
    LMain.Free;
    if LHedgeFired then
      LHedge.Free;
  end;
end;

function THedgedProvider.Stream(
  const AReq: TCompletionRequest): IAgentCompletion;
begin
  Result := Stream(AReq, nil);
end;

function THedgedProvider.Stream(const AReq: TCompletionRequest;
  const AToken: IAsyncCancellationToken): IAgentCompletion;
var
  LOuter, LTokMain, LTokHedge: IAsyncCancellationToken;
  LEvMain, LEvHedge, LEvTick: IEvent;
  LMain, LHedge: THedgeOutcome;
  LHedgeFired, LOuterGone: Boolean;
  LRemainNs, LSliceNs: Int64;

  function OuterGone: Boolean;
  begin
    Result := (LOuter <> nil) and LOuter.IsCancelled;
  end;

  { 胜者流包装首 delta 门：已消费的首点回放、其余透传（投递不重复）}
  function Wrap(const AOut: THedgeOutcome): IAgentCompletion;
  begin
    atomic_seq_cst_fence;
    Result := TFirstGateCompletion.Create(AOut.Comp, AOut.FirstDelta,
      AOut.HaveFirst);
    AOut.Comp := nil;                { 所有权移交包装 }
  end;

begin
  LOuter := MergeCancellationTokens(FAmbientToken, AToken);
  RequireNotCancelled(LOuter);

  LTokMain := CreateCancellationToken;
  LEvMain := CreateEvent(True);
  LEvTick := CreateEvent(True);
  LMain := THedgeOutcome.Create;
  LHedge := nil;
  LHedgeFired := False;
  FPool.Submit(procedure
    begin
      RunStreamTask(AReq, LTokMain, LMain, LEvMain);
    end);

  try
    { 分片等待 DelayMs：与 Complete 路同分片，G3 统一取消粒度 }
    LRemainNs := FPolicy.DelayMs * 1000000;
    while LRemainNs > 0 do
    begin
      if OuterGone then
        Break;
      LSliceNs := CArbitrationSliceNs;
      if LSliceNs > LRemainNs then
        LSliceNs := LRemainNs;
      if LEvMain.WaitTimeout(LSliceNs) then
        Break;
      Dec(LRemainNs, LSliceNs);
    end;
    if LEvMain.IsSet then
    begin
      atomic_seq_cst_fence;
      if LMain.HaveValue then
        Exit(Wrap(LMain));           { 首 delta 已到手：对冲从未发起 }
      if LMain.Cancelled or LMain.Aborted or
        (LMain.Fail.Code = aecCancelled) then
        raise EAgentCancelled.Create;
      raise LMain.Fail.Rebuild;
    end;
    if OuterGone then
    begin
      LTokMain.Cancel;
      atomic_seq_cst_fence;
      if LMain.Comp <> nil then
        LMain.Comp.Cancel;
      while not LEvMain.IsSet do
        SliceWait(LEvTick);
      raise EAgentCancelled.Create;
    end;

    if FPolicy.OnHedged <> nil then
      FPolicy.OnHedged(FPolicy.DelayMs);
    LHedgeFired := True;
    LEvHedge := CreateEvent(True);
    LTokHedge := CreateCancellationToken;
    LHedge := THedgeOutcome.Create;
    FPool.Submit(procedure
      begin
        RunStreamTask(AReq, LTokHedge, LHedge, LEvHedge);
      end);

    while not (LEvMain.IsSet and LEvHedge.IsSet) do
    begin
      if OuterGone then
      begin
        LTokMain.Cancel;
        LTokHedge.Cancel;
        atomic_seq_cst_fence;
        if LMain.Comp <> nil then
          LMain.Comp.Cancel;
        atomic_seq_cst_fence;
        if LHedge.Comp <> nil then
          LHedge.Comp.Cancel;
        break;
      end;
      if LEvMain.IsSet then
      begin
        atomic_seq_cst_fence;
        if LMain.HaveValue then
        begin
          { 主流胜：输流硬取消且其增量永不外泄（投递不重复同门）}
          atomic_seq_cst_fence;
          if LHedge.Comp <> nil then
            LHedge.Comp.Cancel;
          LTokHedge.Cancel;
          break;
        end;
      end;
      if LEvHedge.IsSet then
      begin
        atomic_seq_cst_fence;
        if LHedge.HaveValue then
        begin
          atomic_seq_cst_fence;
          if LMain.Comp <> nil then
            LMain.Comp.Cancel;       { 对冲流胜：主流转输流真收合 }
          LTokMain.Cancel;
          break;
        end;
      end;
      SliceWait(LEvTick);
    end;

    LOuterGone := OuterGone;
    atomic_seq_cst_fence;
    if LOuterGone then
    begin
      atomic_seq_cst_fence;
      if LHedge.Comp <> nil then
        LHedge.Comp.Cancel;
      LTokHedge.Cancel;
      atomic_seq_cst_fence;
      if LMain.Comp <> nil then
        LMain.Comp.Cancel;
      LTokMain.Cancel;
    end
    else if LEvMain.IsSet then
    begin
      atomic_seq_cst_fence;
      if LMain.HaveValue then
      begin
        atomic_seq_cst_fence;
        if LHedge.Comp <> nil then
          LHedge.Comp.Cancel;
        LTokHedge.Cancel;
      end;
    end
    else if LEvHedge.IsSet then
    begin
      atomic_seq_cst_fence;
      if LHedge.HaveValue then
      begin
        atomic_seq_cst_fence;
        if LMain.Comp <> nil then
          LMain.Comp.Cancel;
        LTokMain.Cancel;
      end;
    end;
    while (not LEvMain.IsSet) or (not LEvHedge.IsSet) do
      SliceWait(LEvTick);
    // 额外切片：胜者首 delta 门稳定后再裁决，避免与输路 Cancel 竞态截断 3 增量
    SliceWait(LEvTick);
    atomic_seq_cst_fence;

    if LOuterGone then
      raise EAgentCancelled.Create;

    atomic_seq_cst_fence;
    if LMain.HaveValue then
      Exit(Wrap(LMain));
    atomic_seq_cst_fence;
    if LHedge.HaveValue then
      Exit(Wrap(LHedge));
    if LMain.Cancelled or LMain.Aborted or
      (LMain.Fail.Code = aecCancelled) then
      raise EAgentCancelled.Create;
    raise LMain.Fail.Rebuild;
  finally
    LMain.Free;
    if LHedgeFired then
      LHedge.Free;
  end;
end;

{ ---- 工厂 ---- }

function NewHedgedProvider(const AInner: IAgentProvider;
  const AClock: IAgentClock; const APolicy: THedgePolicy): IAgentProvider;
begin
  { 显式 opt-in 纪律在工厂层先行拦截：对象未创建即拒 }
  if APolicy.DelayMs <= 0 then
    raise EAgentError.CreateLocal(aecConfig,
      'NewHedgedProvider: DelayMs must be > 0 (explicit double-cost ' +
      'opt-in)');
  Result := THedgedProvider.Create(AInner, AClock, APolicy, nil);
end;

end.

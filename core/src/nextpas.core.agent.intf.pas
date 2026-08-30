{**
 * nextpas.core.agent.intf - agent 模块接缝接口。
 *
 * 契约权威：core/docs/agent/API.md §3。loop/session/tools 域只消费本单元
 * 词表，永远看不到 wire 类型（ARCHITECTURE §1）。
 *}

unit nextpas.core.agent.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.async.cancellation,
  nextpas.core.agent.base,
  nextpas.core.agent.errors;

type
  { 时钟：真实实现见 nextpas.core.agent.clock；SleepMs 可被令牌打断，
    返回 True=自然睡满，False=被取消 }
  IAgentClock = interface
    function NowMs: Int64;
    function SleepMs(AMs: Int64;
      const AToken: IAsyncCancellationToken): Boolean;
  end;

  { ---- wire 层（自定义 transport / 测试装饰器的落点；不进门面）----
    TWire* 记录词表物理定义在 nextpas.core.agent.base }

  { 真增量：socket 到一帧返一帧；False=EOF 或已取消（用 GetCancelled 区分）}
  IAgentWireStream = interface
    function NextEvent(out AEvent: TWireSSEEvent): Boolean;
    procedure Cancel;                { 幂等，任意线程 }
    function GetCancelled: Boolean;
  end;

  { 失败一律抛 EAgentError（aecTransport/aecTimeout/上游状态经公共分类器归约
    的码）；无布尔返回值——成功即 out 参数有效，失败即异常 }
  IAgentTransport = interface
    procedure RoundTrip(const AReq: TWireRequest; out AResp: TWireResponse);
    function OpenStream(const AReq: TWireRequest): IAgentWireStream;
  end;

  { W11 请求级追踪汇（API.md §3.2）：transport.trace 装饰器产出事件对。
    契约：回调内不得抛出——失败路径的 sink 异常会顶替传输错误上抛 }
  IAgentTraceSink = interface
    procedure OnRequest(const AInfo: TTraceRequestInfo);
    procedure OnResponse(const AInfo: TTraceResponseInfo);
  end;

  { 流帧解码器（API.md §8，D13 公开编解码器）：把厂商 SSE 帧归约为词表增量。
    provider 工厂内部与 Stream() 路径共用同一实现；Finalize 抹平 usage/finish
    到达顺序。实例不跨消息复用、非线程安全（单角色独占） }
  IAgentWireDecoder = interface
    { ping 等 0 增量帧合法（ADeltas 为空数组）；违反协议抛 aecProtocol }
    procedure DecodeEvent(const AEvent: TWireSSEEvent;
      out ADeltas: TStreamDeltaArray);
    { 流终止后调用一次；重复调用返回空数组 }
    procedure Finalize(out ADeltas: TStreamDeltaArray);
  end;

  { ---- 词表层（loop/session/消费方只见这些）---- }

  IAgentCompletion = interface
    function NextDelta(out ADelta: TStreamDelta): Boolean;  { False=EOF }
    procedure Cancel;                { 幂等，任意线程；使 NextDelta 返回 False }
    function GetCancelled: Boolean;  { EOF 后读取区分取消 }
    function GetMessage: TMessage;   { EOF 后有效：内部 fold 的最终消息；
                                       sdkError 缓存于此时刻抛出（ERRORS §6）}
    function GetUsage: TTokenUsage;  { EOF 后有效；未知字段=CUsageUnknown }
  end;

  IAgentProvider = interface
    function GetName: string;        { 'openai'|'anthropic'|'fake' }
    { 工具经 AReq.Tools 随请求携带（builder 链不断裂）；可选令牌重载用于
      全程取消（Stream 的令牌触发时自动 Cancel 返回的 completion）}
    function Complete(const AReq: TCompletionRequest): TMessage; overload;
    function Complete(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): TMessage; overload;
    function Stream(
      const AReq: TCompletionRequest): IAgentCompletion; overload;
    function Stream(const AReq: TCompletionRequest;
      const AToken: IAsyncCancellationToken): IAgentCompletion; overload;
  end;

  { W12 能力接口（API.md §3.3）：token 预估，仅部分适配器实现——anthropic
    有厂商 count_tokens 端点（WIRE-MAPPINGS §2.7）；openai/grok/responses
    族无对应端点诚实不实现。消费方 Supports 探测，未支持走自有降级路径 }
  IAgentTokenCounter = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-111111000012}']
    { 同步阻塞调用；错误分类与 Complete 一致（aecConfig 本地装配错 /
      上游按 §2.4 分类透传；响应缺 input_tokens 即 aecProtocol）}
    function CountTokens(const AReq: TCompletionRequest): Int64;
  end;

  { T1.4 用量汇（API.md §3.2）：nil 退化/线程安全不 raise（tk888 IMetricsSink 同契约） }
  IAgentUsageSink = interface
    ['{C3D4E5F6-A7B8-90AB-CDEF-555555000015}']
    procedure RecordUsage(const AProvider: string; const AReq: TCompletionRequest;
      const AUsage: TTokenUsage; ACostUsd6: Int64);
  end;

  { ---- 工具 ---- }

  IToolContext = interface
    function Token: IAsyncCancellationToken;  { 取消传播进工具实现 }
    function CallIndex: Integer;             { 本轮批内序号 }
  end;

  IAgentTool = interface
    function Spec: TToolSpec;
    { 实现方约定：不抛异常，失败走 TToolResult.IsError=True（异常由 loop 兜底
      转 aecToolFailed 合成 error result——两道防线）}
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

  { ---- 会话（W4 起；接口先行冻结讨论）---- }
  { ThreadId 所有权：由消费方生成并持有（建议 core.id 的 ulid/v7）；
    loop 不感知会话身份，store 的 Append/Load 顺序即 transcript 数组序 }

  IAgentTranscriptStore = interface
    procedure Append(const AThreadId: string; const AMsg: TMessage);
    function Load(const AThreadId: string): TMessageArray;
    procedure Delete(const AThreadId: string);
    procedure Fork(const ASrcThreadId, ADstThreadId: string);
  end;

  IAgentTranscriptFork = interface
    ['{7A1B2C3D-4E5F-4A6B-8C9D-0E1F2A3B4C5D}']
    procedure Fork(const ASrcThreadId, ADstThreadId: string);
  end;

implementation

end.

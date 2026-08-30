{**
 * nextpas.core.agent.loop - 薄门面：re-export + 委托至 loop.impl。
 *
 * 职责：零逻辑，仅别名透出 types 词表与 impl 实现，保持调用方
 * `uses nextpas.core.agent.loop` 零改动。体积 ≤350 行。
 * 实现权威：nextpas.core.agent.loop.impl；契约：API.md §6。
 * 分层：facade → types + impl → budget + exec，无循环。
 *}

unit nextpas.core.agent.loop;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.loop.types,
  nextpas.core.agent.loop.impl;

type
  TLoopOutcome = nextpas.core.agent.loop.types.TLoopOutcome;
  TLoopEventKind = nextpas.core.agent.loop.types.TLoopEventKind;
  TLoopEvent = nextpas.core.agent.loop.types.TLoopEvent;
  TLoopEventHandler = nextpas.core.agent.loop.types.TLoopEventHandler;
  TLoopEventHandlerMethod = nextpas.core.agent.loop.types.TLoopEventHandlerMethod;
  TLoopEventHandlerProc = nextpas.core.agent.loop.types.TLoopEventHandlerProc;
  THookVerdict = nextpas.core.agent.loop.types.THookVerdict;
  TLoopHook = nextpas.core.agent.loop.types.TLoopHook;
  TLoopHookMethod = nextpas.core.agent.loop.types.TLoopHookMethod;
  TLoopHookProc = nextpas.core.agent.loop.types.TLoopHookProc;
  TAgentLoopOptions = nextpas.core.agent.loop.types.TAgentLoopOptions;
  IAgentLoopRun = nextpas.core.agent.loop.types.IAgentLoopRun;
  TAgentLoop = nextpas.core.agent.loop.impl.TAgentLoop;

const
  CLOOP_GUIDANCE_TEXT = nextpas.core.agent.loop.types.CLOOP_GUIDANCE_TEXT;
  { 枚举值重导出：bare lev*/ro*/hv* 在 `uses loop` 作用域直接可见 }
  levRunStart = nextpas.core.agent.loop.types.levRunStart;
  levRoundStart = nextpas.core.agent.loop.types.levRoundStart;
  levRoundEnd = nextpas.core.agent.loop.types.levRoundEnd;
  levToolCallStart = nextpas.core.agent.loop.types.levToolCallStart;
  levToolCallEnd = nextpas.core.agent.loop.types.levToolCallEnd;
  levBudgetWarning = nextpas.core.agent.loop.types.levBudgetWarning;
  levRunEnd = nextpas.core.agent.loop.types.levRunEnd;
  roCompleted = nextpas.core.agent.loop.types.roCompleted;
  roCancelled = nextpas.core.agent.loop.types.roCancelled;
  roBudgetExhausted = nextpas.core.agent.loop.types.roBudgetExhausted;
  roDoomLoop = nextpas.core.agent.loop.types.roDoomLoop;
  roRoundsExhausted = nextpas.core.agent.loop.types.roRoundsExhausted;
  roFailed = nextpas.core.agent.loop.types.roFailed;
  hvProceed = nextpas.core.agent.loop.types.hvProceed;
  hvBlock = nextpas.core.agent.loop.types.hvBlock;
  hvStop = nextpas.core.agent.loop.types.hvStop;

implementation

end.

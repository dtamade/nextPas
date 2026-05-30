unit nextpas.core.coroutine.base;

{$I nextpas.core.settings.inc}

interface

type
  {** TCoroutineID - 协程唯一标识符 *}
  TCoroutineID = Integer;

  {** TCoroutineState - 协程生命周期状态 *}
  TCoroutineState = (
    csIdle,       { 未启动 }
    csRunning,    { 正在执行 }
    csSuspended,  { 挂起等待 }
    csFinished    { 已完成 }
  );

  {** TYieldKind - 挂起类型 *}
  TYieldKind = (
    ykNone,       { 无挂起 }
    ykFrames,     { 等待 N 帧 }
    ykSeconds,    { 等待 N 秒 }
    ykUntil,      { 等待条件为真 }
    ykCoroutine   { 等待另一个协程完成 }
  );

  {** TCoroStepKind - 序列步骤类型 *}
  TCoroStepKind = (
    cskAction,      { 执行动作 }
    cskWaitSeconds, { 等待秒数 }
    cskWaitFrames,  { 等待帧数 }
    cskWaitUntil,   { 等待条件 }
    cskEnd          { 序列结束 }
  );

  {** TCoroutineProc - 协程主体过程 *}
  TCoroutineProc = procedure(ACoroID: TCoroutineID; AUserData: Pointer);

  {** TCoroutineCondition - 条件检查函数 *}
  TCoroutineCondition = function(AUserData: Pointer): Boolean;

  {** TCoroStepAction - 步骤动作 *}
  TCoroStepAction = procedure(AUserData: Pointer);

  {** TCoroStep - 协程序列中的单个步骤 *}
  TCoroStep = record
    Kind: TCoroStepKind;
    Action: TCoroStepAction;
    Seconds: Single;
    Frames: Integer;
    Condition: TCoroutineCondition;
    ConditionData: Pointer;
  end;
  PCoroStep = ^TCoroStep;

const
  COROUTINE_INVALID_ID = -1;
  COROUTINE_MAX_ACTIVE = 256;

implementation

end.

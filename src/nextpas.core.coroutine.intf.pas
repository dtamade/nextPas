unit nextpas.core.coroutine.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.coroutine.base;

type
  {**
   * ICoroutineManager - 协程管理器接口
   *
   * @desc
   *   管理无栈协程的生命周期：启动、挂起、恢复、停止。
   *   基于状态表驱动，每帧调用 Update 推进所有活跃协程。
   *}
  ICoroutineManager = interface
    ['{B2C4D6E8-1A3B-5C7D-9E0F-2A4B6C8D0E1F}']

    {** 启动一个协程，返回其 ID *}
    function Start(AProc: TCoroutineProc; AUserData: Pointer = nil;
      ATag: Integer = 0): TCoroutineID;

    {** 启动一个步骤序列协程 *}
    function StartSequence(ASteps: PCoroStep; AStepCount: Integer;
      AUserData: Pointer = nil; ATag: Integer = 0): TCoroutineID;

    {** 停止指定协程 *}
    procedure Stop(AID: TCoroutineID);

    {** 停止所有带指定 Tag 的协程 *}
    procedure StopByTag(ATag: Integer);

    {** 停止所有协程 *}
    procedure StopAll;

    {** 挂起：等待 N 帧 *}
    procedure YieldFrames(AID: TCoroutineID; AFrames: Integer);

    {** 挂起：等待 N 秒 *}
    procedure YieldSeconds(AID: TCoroutineID; ASeconds: Single);

    {** 挂起：等待条件为真 *}
    procedure YieldUntil(AID: TCoroutineID; ACondition: TCoroutineCondition;
      AConditionData: Pointer = nil);

    {** 挂起：等待另一个协程完成 *}
    procedure YieldCoroutine(AID: TCoroutineID; AWaitFor: TCoroutineID);

    {** 每帧调用，推进所有活跃协程 *}
    procedure Update(ADeltaTime: Single);

    {** 查询协程状态 *}
    function GetState(AID: TCoroutineID): TCoroutineState;

    {** 当前活跃协程数 *}
    function GetActiveCount: Integer;
  end;

implementation

end.

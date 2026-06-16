unit nextpas.core.async;
{**
 * @desc 异步模块门面：re-export async.base / timer / loop / task / io.base 全部公共类型。
 *       消费方只需 uses nextpas.core.async 即可使用完整异步框架。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.async.task,
  nextpas.core.io.base,
  nextpas.core.io.poller;

type
  TAsyncCallback = nextpas.core.async.base.TAsyncCallback;
  TAsyncCallbackRef = nextpas.core.async.base.TAsyncCallbackRef;
  TAsyncCallbackMethod = nextpas.core.async.base.TAsyncCallbackMethod;
  TAsyncTimerHandle = nextpas.core.async.base.TAsyncTimerHandle;
  TTimerHeap = nextpas.core.async.timer.TTimerHeap;
  TAsyncLoop = nextpas.core.async.loop.TAsyncLoop;
  TAsyncTaskStatus = nextpas.core.async.base.TAsyncTaskStatus;
  TAsyncTaskState = nextpas.core.async.base.TAsyncTaskState;
  PAsyncTask = nextpas.core.async.task.PAsyncTask;
  TAsyncTask = nextpas.core.async.task.TAsyncTask;
  TIoCompletion = nextpas.core.io.base.TIoCompletion;
  TIoCompletionRef = nextpas.core.io.base.TIoCompletionRef;
  TIoCompletionMethod = nextpas.core.io.base.TIoCompletionMethod;

const
  atsIdle: TAsyncTaskStatus = nextpas.core.async.base.atsIdle;
  atsPending: TAsyncTaskStatus = nextpas.core.async.base.atsPending;
  atsCompleted: TAsyncTaskStatus = nextpas.core.async.base.atsCompleted;
  atsFailed: TAsyncTaskStatus = nextpas.core.async.base.atsFailed;
  atsTimedOut: TAsyncTaskStatus = nextpas.core.async.base.atsTimedOut;
  atsCancelled: TAsyncTaskStatus = nextpas.core.async.base.atsCancelled;

implementation

end.

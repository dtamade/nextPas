unit nextpas.core.async;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.async.task,
  nextpas.core.io.poller;

type
  TAsyncCallback = nextpas.core.async.base.TAsyncCallback;
  TAsyncTimerHandle = nextpas.core.async.base.TAsyncTimerHandle;
  TTimerHeap = nextpas.core.async.timer.TTimerHeap;
  TAsyncLoop = nextpas.core.async.loop.TAsyncLoop;
  TAsyncTaskStatus = nextpas.core.async.base.TAsyncTaskStatus;
  TAsyncTaskState = nextpas.core.async.base.TAsyncTaskState;
  PAsyncTask = nextpas.core.async.task.PAsyncTask;
  TAsyncTask = nextpas.core.async.task.TAsyncTask;
  TIoCompletion = nextpas.core.io.poller.TIoCompletion;

const
  atsIdle: TAsyncTaskStatus = nextpas.core.async.base.atsIdle;
  atsPending: TAsyncTaskStatus = nextpas.core.async.base.atsPending;
  atsCompleted: TAsyncTaskStatus = nextpas.core.async.base.atsCompleted;
  atsFailed: TAsyncTaskStatus = nextpas.core.async.base.atsFailed;
  atsTimedOut: TAsyncTaskStatus = nextpas.core.async.base.atsTimedOut;
  atsCancelled: TAsyncTaskStatus = nextpas.core.async.base.atsCancelled;

implementation

end.

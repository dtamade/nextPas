unit nextpas.core.async;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.io.poller;

type
  TAsyncCallback = nextpas.core.async.base.TAsyncCallback;
  TAsyncTimerHandle = nextpas.core.async.base.TAsyncTimerHandle;
  TAsyncTaskState = nextpas.core.async.base.TAsyncTaskState;
  TTimerHeap = nextpas.core.async.timer.TTimerHeap;
  TAsyncLoop = nextpas.core.async.loop.TAsyncLoop;
  TIoCompletion = nextpas.core.io.poller.TIoCompletion;

implementation

end.

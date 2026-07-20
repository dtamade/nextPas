unit nextpas.core.async;
{**
 * @desc 异步模块门面：re-export async.base / timer / loop / task 与高级子模块公共类型。
 *       TAsyncLoop 为 class；暴露 Post/PostEx/PostRef/PostMethod 与 Schedule/ScheduleEx。
 *       消费方只需 uses nextpas.core.async 即可使用完整异步框架。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.async.base,
  nextpas.core.async.timer,
  nextpas.core.async.loop,
  nextpas.core.async.task,
  nextpas.core.async.mutex,
  nextpas.core.async.semaphore,
  nextpas.core.async.channel,
  nextpas.core.async.condvar,
  nextpas.core.async.taskgroup,
  nextpas.core.async.timeout,
  nextpas.core.async.shutdown,
  nextpas.core.async.combinators,
  nextpas.core.async.retry,
  nextpas.core.async.signal,
  nextpas.core.async.buffer,
  nextpas.core.async.cancellation,
  nextpas.core.io.poller;

type
  TAsyncCallback = nextpas.core.async.base.TAsyncCallback;
  TAsyncCallbackRef = nextpas.core.async.base.TAsyncCallbackRef;
  TAsyncCallbackMethod = nextpas.core.async.base.TAsyncCallbackMethod;
  TIoCompletion = nextpas.core.async.base.TIoCompletion;
  TIoCompletionRef = nextpas.core.async.base.TIoCompletionRef;
  TAsyncTimerHandle = nextpas.core.async.base.TAsyncTimerHandle;
  TTimerHeap = nextpas.core.async.timer.TTimerHeap;
  TAsyncLoop = nextpas.core.async.loop.TAsyncLoop;
  TAsyncTaskStatus = nextpas.core.async.base.TAsyncTaskStatus;
  TAsyncTaskState = nextpas.core.async.base.TAsyncTaskState;
  PAsyncTask = nextpas.core.async.task.PAsyncTask;
  TAsyncTask = nextpas.core.async.task.TAsyncTask;
  TAsyncCallbackStorage = nextpas.core.async.task.TAsyncCallbackStorage;
  IAsyncMutex = nextpas.core.async.mutex.IAsyncMutex;
  IAsyncSemaphore = nextpas.core.async.semaphore.IAsyncSemaphore;
  IAsyncChannel = nextpas.core.async.channel.IAsyncChannel;
  IAsyncCondVar = nextpas.core.async.condvar.IAsyncCondVar;
  TAsyncTaskGroupState = nextpas.core.async.taskgroup.TAsyncTaskGroupState;
  TAsyncTaskGroupOption = nextpas.core.async.taskgroup.TAsyncTaskGroupOption;
  TAsyncTaskGroupOptions = nextpas.core.async.taskgroup.TAsyncTaskGroupOptions;
  IAsyncTaskGroup = nextpas.core.async.taskgroup.IAsyncTaskGroup;
  TAsyncTimeoutResult = nextpas.core.async.timeout.TAsyncTimeoutResult;
  IAsyncTimeout = nextpas.core.async.timeout.IAsyncTimeout;
  TShutdownPhase = nextpas.core.async.shutdown.TShutdownPhase;
  TShutdownOption = nextpas.core.async.shutdown.TShutdownOption;
  TShutdownOptions = nextpas.core.async.shutdown.TShutdownOptions;
  IAsyncShutdown = nextpas.core.async.shutdown.IAsyncShutdown;
  TCombinatorOptions = nextpas.core.async.combinators.TCombinatorOptions;
  TAsyncRetryResult = nextpas.core.async.retry.TAsyncRetryResult;
  TAsyncRetryOptions = nextpas.core.async.retry.TAsyncRetryOptions;
  TSignalCallback = nextpas.core.async.signal.TSignalCallback;
  TSignalOption = nextpas.core.async.signal.TSignalOption;
  TSignalOptions = nextpas.core.async.signal.TSignalOptions;
  IAsyncSignalHandler = nextpas.core.async.signal.IAsyncSignalHandler;
  TAsyncBuffer = nextpas.core.async.buffer.TAsyncBuffer;
  TBufferOption = nextpas.core.async.buffer.TBufferOption;
  TBufferOptions = nextpas.core.async.buffer.TBufferOptions;
  IAsyncBufferPool = nextpas.core.async.buffer.IAsyncBufferPool;
  TCancelCallback = nextpas.core.async.cancellation.TCancelCallback;
  IAsyncCancellationToken = nextpas.core.async.cancellation.IAsyncCancellationToken;

function CreateAsyncMutex(const ALoop: TAsyncLoop): IAsyncMutex; inline;
function CreateAsyncSemaphore(const ALoop: TAsyncLoop;
  AInitialCount: Int32): IAsyncSemaphore; inline;
function CreateAsyncChannel(const ALoop: TAsyncLoop): IAsyncChannel; inline;
function CreateBoundedAsyncChannel(const ALoop: TAsyncLoop;
  ACapacity: UInt32): IAsyncChannel; inline;
function CreateAsyncCondVar(const ALoop: TAsyncLoop): IAsyncCondVar; inline;
function CreateCancellationToken: IAsyncCancellationToken; inline;
function CreateTaskGroup(const ALoop: TAsyncLoop;
  AOptions: TAsyncTaskGroupOptions = [];
  AToken: IAsyncCancellationToken = nil): IAsyncTaskGroup; inline;

const
  atsIdle: TAsyncTaskStatus = nextpas.core.async.base.atsIdle;
  atsPending: TAsyncTaskStatus = nextpas.core.async.base.atsPending;
  atsCompleted: TAsyncTaskStatus = nextpas.core.async.base.atsCompleted;
  atsFailed: TAsyncTaskStatus = nextpas.core.async.base.atsFailed;
  atsTimedOut: TAsyncTaskStatus = nextpas.core.async.base.atsTimedOut;
  atsCancelled: TAsyncTaskStatus = nextpas.core.async.base.atsCancelled;

  agoFailFast: TAsyncTaskGroupOption = nextpas.core.async.taskgroup.agoFailFast;
  agoCancelOnTimeout: TAsyncTaskGroupOption = nextpas.core.async.taskgroup.agoCancelOnTimeout;

  atrCompleted: TAsyncTimeoutResult = nextpas.core.async.timeout.atrCompleted;
  atrTimedOut: TAsyncTimeoutResult = nextpas.core.async.timeout.atrTimedOut;
  atrCancelled: TAsyncTimeoutResult = nextpas.core.async.timeout.atrCancelled;

  spRunning: TShutdownPhase = nextpas.core.async.shutdown.spRunning;
  spDraining: TShutdownPhase = nextpas.core.async.shutdown.spDraining;
  spForceClose: TShutdownPhase = nextpas.core.async.shutdown.spForceClose;
  spClosed: TShutdownPhase = nextpas.core.async.shutdown.spClosed;

  soGraceful: TShutdownOption = nextpas.core.async.shutdown.soGraceful;
  soAbortOnTimeout: TShutdownOption = nextpas.core.async.shutdown.soAbortOnTimeout;
  soLogProgress: TShutdownOption = nextpas.core.async.shutdown.soLogProgress;

  arrSuccess: TAsyncRetryResult = nextpas.core.async.retry.arrSuccess;
  arrMaxRetries: TAsyncRetryResult = nextpas.core.async.retry.arrMaxRetries;
  arrCancelled: TAsyncRetryResult = nextpas.core.async.retry.arrCancelled;

implementation

function CreateAsyncMutex(const ALoop: TAsyncLoop): IAsyncMutex;
begin
  Result := nextpas.core.async.mutex.CreateAsyncMutex(ALoop);
end;

function CreateAsyncSemaphore(const ALoop: TAsyncLoop;
  AInitialCount: Int32): IAsyncSemaphore;
begin
  Result := nextpas.core.async.semaphore.CreateAsyncSemaphore(ALoop, AInitialCount);
end;

function CreateAsyncChannel(const ALoop: TAsyncLoop): IAsyncChannel;
begin
  Result := nextpas.core.async.channel.CreateAsyncChannel(ALoop);
end;

function CreateBoundedAsyncChannel(const ALoop: TAsyncLoop;
  ACapacity: UInt32): IAsyncChannel;
begin
  Result := nextpas.core.async.channel.CreateBoundedAsyncChannel(ALoop, ACapacity);
end;

function CreateAsyncCondVar(const ALoop: TAsyncLoop): IAsyncCondVar;
begin
  Result := nextpas.core.async.condvar.CreateAsyncCondVar(ALoop);
end;

function CreateCancellationToken: IAsyncCancellationToken;
begin
  Result := nextpas.core.async.cancellation.CreateCancellationToken;
end;

function CreateTaskGroup(const ALoop: TAsyncLoop;
  AOptions: TAsyncTaskGroupOptions;
  AToken: IAsyncCancellationToken): IAsyncTaskGroup;
begin
  Result := nextpas.core.async.taskgroup.CreateTaskGroup(ALoop, AOptions, AToken);
end;

end.

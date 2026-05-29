unit nextpas.core.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool,
  nextpas.core.thread.future,
  nextpas.core.thread.cancel;

type
  TThreadTask = nextpas.core.thread.base.TThreadTask;
  TFutureState = nextpas.core.thread.base.TFutureState;
  IThreadPool = nextpas.core.thread.intf.IThreadPool;
  ICancellationToken = nextpas.core.thread.intf.ICancellationToken;
  ICancellationSource = nextpas.core.thread.intf.ICancellationSource;

function ThreadPool(const AWorkerCount: Integer = 0): IThreadPool; inline;
function CancellationSource: ICancellationSource; inline;

implementation

function ThreadPool(const AWorkerCount: Integer): IThreadPool;
begin
  Result := nextpas.core.thread.pool.CreateThreadPool(AWorkerCount);
end;

function CancellationSource: ICancellationSource;
begin
  Result := nextpas.core.thread.cancel.CreateCancellationSource;
end;

end.

unit nextpas.core.thread;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool;

type
  TThreadTask = nextpas.core.thread.base.TThreadTask;
  IThreadPool = nextpas.core.thread.intf.IThreadPool;

function ThreadPool(const AWorkerCount: Integer = 0): IThreadPool; inline;

implementation

function ThreadPool(const AWorkerCount: Integer): IThreadPool;
begin
  Result := nextpas.core.thread.pool.CreateThreadPool(AWorkerCount);
end;

end.

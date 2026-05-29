unit nextpas.core.thread.base;

{$I nextpas.core.settings.inc}

interface

type
  TThreadTask = reference to procedure;

  TFutureState = (
    fsPending,
    fsCompleted,
    fsFailed,
    fsCancelled
  );

implementation

end.

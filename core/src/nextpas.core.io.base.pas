unit nextpas.core.io.base;

{$I nextpas.core.settings.inc}

interface

type
  TSeekOrigin = (
    soBeginning,
    soCurrent,
    soEnd
  );

  { I/O completion callback types — single definition shared by poller/reactors/async }
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);
  TIoCompletionRef = reference to procedure(AUserData: UInt64; AResult: Int32;
    AContext: Pointer);

const
  IO_EOF = -1;

implementation

end.

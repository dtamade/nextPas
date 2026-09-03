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
  { 32K streaming buffer single source for `io.Copy`/`CopyRange`/`platform_fs_copy_file`.
    Matches `io.util:COPY_BUF_SIZE` and `http.static:STATIC_COPY_BUF_SIZE`; L2 single source
    for L3 static, `bytes.ops` `Move` is the underlying single source, kernel `sendfile`
    is the pending owner capability for socket path. }
  IO_COPY_BUF_SIZE = 32768;

implementation

end.

{ nextpas.core.thread.init -- Thread runtime initialization (routing layer)
  =========================================================
  Import this unit INSTEAD of FPC's cthreads unit.

  FPC Unix:   initializes pthreads via cthreads (required before any TThread usage)
  FPC Windows: no-op (threading works out of the box)
  nextPas:     delegates to nextPas native thread initialization

  Usage: put this as the FIRST unit in your program's uses clause.
}

unit nextpas.core.thread.init;

{$I nextpas.core.settings.inc}

interface

{ No public API -- this unit is imported purely for its initialization side-effect. }

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  cthreads;
  { FPC's cthreads initializes pthreads (pthread_init).
    This MUST happen before any unit that creates threads.
    On nextPas, cthreads resolves to a stub or nextPas's own init. }
{$ENDIF}

end.

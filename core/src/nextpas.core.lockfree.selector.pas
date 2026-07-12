unit nextpas.core.lockfree.selector;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.platform.thread;

type
  {** @desc Select 结果 }
  TSelectResult = record
    Index: PtrInt;
    Completed: Boolean;
  end;

const
  SELECTOR_MAX_SPIN = 32;
  SELECTOR_BACKOFF_NS = 1000;
  SELECTOR_TIMEOUT_ZERO = 0;

implementation

end.

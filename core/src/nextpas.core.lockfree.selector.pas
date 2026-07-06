unit nextpas.core.lockfree.selector;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
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

implementation

end.

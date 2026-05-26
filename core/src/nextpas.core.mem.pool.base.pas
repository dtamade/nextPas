unit nextpas.core.mem.pool.base;

{$I nextpas.core.settings.inc}

interface

type
  // 最小基座接口（可用于统一抽象，但不强制大小语义）
  IPool = interface
    ['{6B2E8E2D-0C3A-4E6C-9D7F-2B7E4B7A9A10}']
    function Acquire(out aPtr: Pointer): Boolean;
    function TryAcquire(out aPtr: Pointer): Boolean; // alias/semantics same as Acquire (non-throwing)
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer; // returns acquired count
    procedure Release(aPtr: Pointer);
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
    procedure Reset;
  end;

implementation

end.

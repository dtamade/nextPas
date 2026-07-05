unit nextpas.core.system.memmanager;
{**
 * @desc Minimal memory manager hook facade for framework modules
 *   that need to intercept allocations (e.g. benchmark memory tracking).
 *
 *   This is the ONLY place that re-exports System.TMemoryManager.
 *
 *   WARNING: SetMemoryManager is a low-level API. Passing nil function
 *   pointers will cause crashes. Callers are responsible for providing
 *   a valid memory manager record.
 *
 *   FPC RTL dependency note: This unit directly depends on System.TMemoryManager,
 *   System.GetMemoryManager, and System.SetMemoryManager. This is acceptable
 *   because memory manager hooks are inherently compiler/runtime-specific and
 *   cannot be abstracted through nextpas.core.* without losing the ability to
 *   intercept allocations at the RTL level.
 *}

{$I nextpas.core.settings.inc}

interface

type
  TMemoryManager = System.TMemoryManager;

{** Get the current memory manager }
procedure GetMemoryManager(out AMemMgr: TMemoryManager);

{** Set a custom memory manager.
    WARNING: All function pointers in AMemMgr must be non-nil.
    Passing nil pointers will cause immediate crashes on next allocation. }
procedure SetMemoryManager(const AMemMgr: TMemoryManager);

implementation

procedure GetMemoryManager(out AMemMgr: TMemoryManager);
begin
  System.GetMemoryManager(AMemMgr);
end;

procedure SetMemoryManager(const AMemMgr: TMemoryManager);
begin
  System.SetMemoryManager(AMemMgr);
end;

end.

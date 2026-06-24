unit nextpas.core.system.memmanager;
{**
 * @desc Minimal memory manager hook facade for framework modules
 *   that need to intercept allocations (e.g. benchmark memory tracking).
 *
 *   This is the ONLY place that re-exports System.TMemoryManager.
 *}

{$I nextpas.core.settings.inc}

interface

type
  TMemoryManager = System.TMemoryManager;

{** Get the current memory manager }
procedure GetMemoryManager(out AMemMgr: TMemoryManager);

{** Set a custom memory manager }
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

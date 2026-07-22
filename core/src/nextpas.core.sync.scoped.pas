unit nextpas.core.sync.scoped;
{**
 * Scoped combinators: run a procedure under a lock without manual acquire/release.
 * Complements ILock.Lock RAII guards for callback-style critical sections.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.base,
  nextpas.core.sync.intf;

procedure WithLock(const ALock: ILock; const AProc: TSyncProc);
procedure WithReadLock(const ARW: IRWLock; const AProc: TSyncProc);
procedure WithWriteLock(const ARW: IRWLock; const AProc: TSyncProc);
function Guard(const ALock: ILock): ILockGuard; inline;
function ReadGuard(const ARW: IRWLock): ILockGuard; inline;
function WriteGuard(const ARW: IRWLock): ILockGuard; inline;

implementation

procedure WithLock(const ALock: ILock; const AProc: TSyncProc);
begin
  ALock.Acquire;
  try
    if Assigned(AProc) then
      AProc();
  finally
    ALock.Release;
  end;
end;

procedure WithReadLock(const ARW: IRWLock; const AProc: TSyncProc);
begin
  ARW.AcquireRead;
  try
    if Assigned(AProc) then
      AProc();
  finally
    ARW.ReleaseRead;
  end;
end;

procedure WithWriteLock(const ARW: IRWLock; const AProc: TSyncProc);
begin
  ARW.AcquireWrite;
  try
    if Assigned(AProc) then
      AProc();
  finally
    ARW.ReleaseWrite;
  end;
end;

function Guard(const ALock: ILock): ILockGuard;
begin
  Result := ALock.Lock;
end;

function ReadGuard(const ARW: IRWLock): ILockGuard;
begin
  Result := ARW.ReadLock;
end;

function WriteGuard(const ARW: IRWLock): ILockGuard;
begin
  Result := ARW.WriteLock;
end;

end.

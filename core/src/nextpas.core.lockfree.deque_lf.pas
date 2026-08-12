{******************************************************************************
  nextpas.core.lockfree.deque_lf — historical unit name (Phase D alias)

  Implementation lives in nextpas.core.lockfree.deque_spin as
  TConcurrentSpinDeque. This unit re-exports TDequeResult and provides
  the legacy type name TLockFreeDeque for source compatibility.

  Progress: spin-lock only — NOT lock-free / NOT wait-free.
  Prefer: uses nextpas.core.lockfree.deque_spin; TConcurrentSpinDeque
  True LF deque: nextpas.core.lockfree.deque / TWorkStealingDeque

  2026-07-21  Phase D: alias shell; impl moved to deque_spin
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.deque_lf;

interface

uses
  nextpas.core.lockfree.deque_spin;

const
  DEQUE_DEFAULT_CAPACITY = nextpas.core.lockfree.deque_spin.DEQUE_DEFAULT_CAPACITY;
  { 枚举值不随类型别名自动可见，逐成员 re-export 以保持旧源码兼容 }
  dqOk = nextpas.core.lockfree.deque_spin.dqOk;
  dqEmpty = nextpas.core.lockfree.deque_spin.dqEmpty;
  dqFull = nextpas.core.lockfree.deque_spin.dqFull;

type
  TDequeResult = nextpas.core.lockfree.deque_spin.TDequeResult;
  {** Preferred honest name — same class as TConcurrentSpinDeque. }
  TConcurrentSpinDeque = nextpas.core.lockfree.deque_spin.TConcurrentSpinDeque;
  {** @deprecated Historical name. Use TConcurrentSpinDeque (deque_spin).
      Same type identity (alias); progress remains spin-lock, not lock-free. }
  TLockFreeDeque = TConcurrentSpinDeque;

implementation

end.

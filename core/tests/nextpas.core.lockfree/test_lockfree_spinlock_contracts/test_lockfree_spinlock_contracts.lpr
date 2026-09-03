program test_lockfree_spinlock_contracts;

{$mode objfpc}{$H+}

uses
  nextpas.core.fs,
  nextpas.core.test;

const
  LOCK_UNIT_COUNT = 17;
  LOCK_UNITS: array[0..LOCK_UNIT_COUNT - 1] of string = (
    'nextpas.core.lockfree.arccache.pas',
    'nextpas.core.lockfree.cowarray.pas',
    'nextpas.core.lockfree.leakybucket.pas',
    'nextpas.core.lockfree.lfu.pas',
    'nextpas.core.lockfree.lru.pas',
    'nextpas.core.lockfree.lru_cache.pas',
    'nextpas.core.lockfree.misragries.pas',
    'nextpas.core.lockfree.ratelimit.pas',
    'nextpas.core.lockfree.reservoirsampling.pas',
    'nextpas.core.lockfree.slidingwindow.pas',
    'nextpas.core.lockfree.spacesaving.pas',
    'nextpas.core.lockfree.tdigest.pas',
    'nextpas.core.lockfree.timerwheel.pas',
    'nextpas.core.lockfree.timeseries_ringbuffer.pas',
    'nextpas.core.lockfree.ttl_cache.pas',
    'nextpas.core.lockfree.unrolled_list.pas',
    'nextpas.core.lockfree.wrr.pas'
  );

function ReadSource(const AFileName: string): string;
begin
  Result := ReadFileText('../../../src/' + AFileName);
end;

procedure TestSpinLocksAcquireZeroToOne;
var
  LFileName: string;
  LSource: string;
begin
  for LFileName in LOCK_UNITS do
  begin
    LSource := ReadSource(LFileName);
    Check(Pos(', 1, 0', LSource) = 0,
      LFileName + ' must acquire zero-initialized locks with expected=0, desired=1');
  end;
end;

begin
  TestSpinLocksAcquireZeroToOne;
  WriteLn('All scoped spin-lock CAS contracts passed!');
end.

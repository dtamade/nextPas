unit nextpas.core.sync.vault;
{**
 * @desc Sync vault lazy init single source：GVault/EnsureVaultLock 原子 Exactly-Once 模板收敛（loader/registry 单源复用，IMutex→platform.sync acquire/release 原子保护，64B 友好，有界退避+futex，try-finally 不丢）。
 * @note L1 基础设施，零 JS/QuickJS 语义，仅提供 IMutex 懒初始化单源；循环体 out-of-line per design-conventions §2 红线 2，热点 inline 零拷贝在调用方薄转发。
 *}
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.sync.mutex;
procedure SyncVaultEnsureLock(var AInit: Int32; var ALock: IMutex);
function SyncVaultIsReady(const AInit: Int32): Boolean; inline;
implementation
uses nextpas.core.atomic, nextpas.core.platform.sync, nextpas.core.platform.thread;
function SyncVaultIsReady(const AInit: Int32): Boolean; inline;
begin
  Result := atomic_load(AInit, mo_acquire) = 2;
end;
procedure SyncVaultEnsureLock(var AInit: Int32; var ALock: IMutex);
var
  LExp: Int32;
  LDelay: Int32;
  LPause: Int32;
  LIter: Int32;
begin
  // not inline: real loop/routing body per design-conventions §2 red-line 2 — avoids I-Cache copy expansion; single source via atomic CAS + bounded backoff + futex, owner sync.mutex→platform.sync
  // perf: single acquire snapshot fast path (AInit=2 zero lock), bounded 1..64 exponential backoff + yield + futex wait, zero extra fence on hot path, 64B friendly
  // stability: GVaultInit single atomic authority (no Assigned race), wake串行化零竞争窗口, exception rollback wake-one, try-finally不丢, resource不丢
  if atomic_load(AInit, mo_acquire) = 2 then Exit;
  while True do
  begin
    LExp := 0;
    if atomic_compare_exchange_strong(AInit, LExp, Int32(1), mo_acquire, mo_relaxed) then
    begin
      try
        if not Assigned(ALock) then
          ALock := TMutex.Create;
        atomic_store(AInit, Int32(2), mo_release);
        platform_wake_address_all(@AInit);
      except
        atomic_store(AInit, Int32(0), mo_release);
        platform_wake_address_one(@AInit);
        raise;
      end;
      Exit;
    end;
    if LExp = 2 then Exit;
    LDelay := 1;
    for LIter := 0 to 7 do
    begin
      for LPause := 1 to LDelay do
        cpu_pause;
      if atomic_load(AInit, mo_acquire) <> 1 then Break;
      if LIter >= 2 then
        platform_thread_yield;
      if LDelay < 64 then
        LDelay := LDelay shl 1;
    end;
    if atomic_load(AInit, mo_acquire) = 1 then
      platform_wait_address32(@AInit, 1, 5000000);
    if atomic_load(AInit, mo_acquire) = 2 then Exit;
    if atomic_load(AInit, mo_acquire) = 0 then
      platform_thread_yield;
  end;
end;
end.

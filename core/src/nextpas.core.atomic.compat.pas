unit nextpas.core.atomic.compat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic;

// NOTE: This unit intentionally exposes legacy / potentially-misleading overloads.
// In v3, these APIs should not live in the main nextpas.core.atomic surface.
// Legacy PascalCase compatibility facade mirrored for older call sites.

// ── Legacy Pointer RMW/arith overloads (Pointer + Pointer / bitwise on pointers) ──
function atomic_fetch_add(var aObj: Pointer; aArg: Pointer): Pointer; overload; inline;
function atomic_fetch_sub(var aObj: Pointer; aArg: Pointer): Pointer; overload; inline;
function atomic_fetch_and(var aObj: Pointer; aArg: Pointer): Pointer; overload; inline;
function atomic_fetch_or (var aObj: Pointer; aArg: Pointer): Pointer; overload; inline;
function atomic_fetch_xor(var aObj: Pointer; aArg: Pointer): Pointer; overload; inline;
function atomic_increment(var aObj: Pointer): Pointer; overload; inline;
function atomic_decrement(var aObj: Pointer): Pointer; overload; inline;

// ── Legacy helper names kept for older call sites ──
function make_atomic_tagged_ptr_t(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t; inline;
function atomic_load_atomic_tagged_ptr_t(var aObj: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t; inline;
procedure atomic_store_atomic_tagged_ptr_t(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t); inline;
function atomic_compare_exchange_strong_atomic_tagged_ptr_t(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean; inline;

function atomic_load_ptr(var aObj: Pointer; aOrder: memory_order_t): Pointer; inline;
function atomic_load_ptr(var aObj: Pointer): Pointer; inline;
procedure atomic_store_ptr(var aObj: Pointer; aDesired: Pointer; aOrder: memory_order_t); inline;
procedure atomic_store_ptr(var aObj: Pointer; aDesired: Pointer); inline;
function atomic_compare_exchange_strong_ptr(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean; inline;

procedure CpuPause; inline;

function atomic_is_lock_free_32: Boolean; inline;
{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_is_lock_free_64: Boolean; inline;
{$ENDIF}
function atomic_is_lock_free_ptr: Boolean; inline;

function AtomicLoad32(var ATarget: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
procedure AtomicStore32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst); inline;
function AtomicExchange32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchSub32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchAnd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchOr32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicFetchXor32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder = moSeqCst): Int32; inline;
function AtomicIsLockFree32: Boolean; inline;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function AtomicLoad64(var ATarget: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
procedure AtomicStore64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst); inline;
function AtomicExchange64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
function AtomicFetchSub64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder = moSeqCst): Int64; inline;
function AtomicIsLockFree64: Boolean; inline;
{$ENDIF}

function AtomicLoadPtr(var ATarget: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer; inline;
procedure AtomicStorePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder = moSeqCst); inline;
function AtomicExchangePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer; inline;
function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder = moSeqCst): Pointer; inline;
function AtomicIsLockFreePtr: Boolean; inline;
function AtomicWait32(var ATarget: Int32; const AExpected: Int32; const ATimeoutNs: Int64 = -1): Int32; inline;
function AtomicNotifyOne32(var ATarget: Int32): Int32; inline;
function AtomicNotifyAll32(var ATarget: Int32): Int32; inline;

procedure AtomicThreadFence(const AOrder: TMemoryOrder = moSeqCst); inline;
procedure AtomicSignalFence(const AOrder: TMemoryOrder = moSeqCst); inline;

implementation

function atomic_fetch_add(var aObj: Pointer; aArg: Pointer): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_add(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_add_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
  {$POP}
end;

function atomic_fetch_sub(var aObj: Pointer; aArg: Pointer): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_sub(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_sub_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
  {$POP}
end;

function atomic_fetch_and(var aObj: Pointer; aArg: Pointer): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_and(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_and_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
  {$POP}
end;

function atomic_fetch_or(var aObj: Pointer; aArg: Pointer): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_or(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_or_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
  {$POP}
end;

function atomic_fetch_xor(var aObj: Pointer; aArg: Pointer): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_xor(PInt32(@aObj)^, PInt32(@aArg)^));
  {$ELSE}
    Result := Pointer(nextpas.core.atomic.atomic_fetch_xor_64(PInt64(@aObj)^, PInt64(@aArg)^));
  {$ENDIF}
  {$POP}
end;

function atomic_increment(var aObj: Pointer): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(nextpas.core.atomic.atomic_increment(PInt32(@aObj)^));
  {$ELSE}
    Result := Pointer(nextpas.core.atomic.atomic_increment_64(PInt64(@aObj)^));
  {$ENDIF}
  {$POP}
end;

function atomic_decrement(var aObj: Pointer): Pointer;
begin
  {$PUSH}
  {$WARN 4055 OFF} // Conversion between ordinals and pointers is not portable
  {$IF SIZEOF(Pointer) = 4}
    Result := Pointer(nextpas.core.atomic.atomic_decrement(PInt32(@aObj)^));
  {$ELSE}
    Result := Pointer(nextpas.core.atomic.atomic_decrement_64(PInt64(@aObj)^));
  {$ENDIF}
  {$POP}
end;

function make_atomic_tagged_ptr_t(aPtr: Pointer; aTag: {$IFDEF CPU64}UInt16{$ELSE}UInt32{$ENDIF}): atomic_tagged_ptr_t;
begin
  Result := atomic_tagged_ptr(aPtr, aTag);
end;

function atomic_load_atomic_tagged_ptr_t(var aObj: atomic_tagged_ptr_t; aOrder: memory_order_t): atomic_tagged_ptr_t;
begin
  Result := atomic_tagged_ptr_load(aObj, aOrder);
end;

procedure atomic_store_atomic_tagged_ptr_t(var aObj: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t; aOrder: memory_order_t);
begin
  atomic_tagged_ptr_store(aObj, aDesired, aOrder);
end;

function atomic_compare_exchange_strong_atomic_tagged_ptr_t(var aObj: atomic_tagged_ptr_t; var aExpected: atomic_tagged_ptr_t; aDesired: atomic_tagged_ptr_t): Boolean;
begin
  Result := atomic_tagged_ptr_compare_exchange_strong(aObj, aExpected, aDesired);
end;

function atomic_load_ptr(var aObj: Pointer; aOrder: memory_order_t): Pointer;
begin
  Result := atomic_load(aObj, aOrder);
end;

function atomic_load_ptr(var aObj: Pointer): Pointer;
begin
  Result := atomic_load(aObj);
end;

procedure atomic_store_ptr(var aObj: Pointer; aDesired: Pointer; aOrder: memory_order_t);
begin
  atomic_store(aObj, aDesired, aOrder);
end;

procedure atomic_store_ptr(var aObj: Pointer; aDesired: Pointer);
begin
  atomic_store(aObj, aDesired);
end;

function atomic_compare_exchange_strong_ptr(var aObj: Pointer; var aExpected: Pointer; aDesired: Pointer): Boolean;
begin
  Result := atomic_compare_exchange_strong(aObj, aExpected, aDesired);
end;

procedure CpuPause;
begin
  nextpas.core.atomic.CpuPause;
end;

function atomic_is_lock_free_32: Boolean;
begin
  Result := nextpas.core.atomic.atomic_is_lock_free_32;
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function atomic_is_lock_free_64: Boolean;
begin
  Result := nextpas.core.atomic.atomic_is_lock_free_64;
end;
{$ENDIF}

function atomic_is_lock_free_ptr: Boolean;
begin
  Result := nextpas.core.atomic.atomic_is_lock_free_ptr;
end;

function AtomicLoad32(var ATarget: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicLoad32(ATarget, AOrder);
end;

procedure AtomicStore32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder);
begin
  nextpas.core.atomic.AtomicStore32(ATarget, AValue, AOrder);
end;

function AtomicExchange32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicExchange32(ATarget, AValue, AOrder);
end;

function AtomicCompareExchange32(var ATarget: Int32; const AExpected, ADesired: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicCompareExchange32(ATarget, AExpected, ADesired, AOrder);
end;

function AtomicFetchAdd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicFetchAdd32(ATarget, AValue, AOrder);
end;

function AtomicFetchSub32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicFetchSub32(ATarget, AValue, AOrder);
end;

function AtomicFetchAnd32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicFetchAnd32(ATarget, AValue, AOrder);
end;

function AtomicFetchOr32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicFetchOr32(ATarget, AValue, AOrder);
end;

function AtomicFetchXor32(var ATarget: Int32; const AValue: Int32; const AOrder: TMemoryOrder): Int32;
begin
  Result := nextpas.core.atomic.AtomicFetchXor32(ATarget, AValue, AOrder);
end;

function AtomicIsLockFree32: Boolean;
begin
  Result := nextpas.core.atomic.AtomicIsLockFree32;
end;

{$IF DEFINED(CPU64) OR DEFINED(CPUX86)}
function AtomicLoad64(var ATarget: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := nextpas.core.atomic.AtomicLoad64(ATarget, AOrder);
end;

procedure AtomicStore64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder);
begin
  nextpas.core.atomic.AtomicStore64(ATarget, AValue, AOrder);
end;

function AtomicExchange64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := nextpas.core.atomic.AtomicExchange64(ATarget, AValue, AOrder);
end;

function AtomicCompareExchange64(var ATarget: Int64; const AExpected, ADesired: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := nextpas.core.atomic.AtomicCompareExchange64(ATarget, AExpected, ADesired, AOrder);
end;

function AtomicFetchAdd64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := nextpas.core.atomic.AtomicFetchAdd64(ATarget, AValue, AOrder);
end;

function AtomicFetchSub64(var ATarget: Int64; const AValue: Int64; const AOrder: TMemoryOrder): Int64;
begin
  Result := nextpas.core.atomic.AtomicFetchSub64(ATarget, AValue, AOrder);
end;

function AtomicIsLockFree64: Boolean;
begin
  Result := nextpas.core.atomic.AtomicIsLockFree64;
end;
{$ENDIF}

function AtomicLoadPtr(var ATarget: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  Result := nextpas.core.atomic.AtomicLoadPtr(ATarget, AOrder);
end;

procedure AtomicStorePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder);
begin
  nextpas.core.atomic.AtomicStorePtr(ATarget, AValue, AOrder);
end;

function AtomicExchangePtr(var ATarget: Pointer; const AValue: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  Result := nextpas.core.atomic.AtomicExchangePtr(ATarget, AValue, AOrder);
end;

function AtomicCompareExchangePtr(var ATarget: Pointer; const AExpected, ADesired: Pointer; const AOrder: TMemoryOrder): Pointer;
begin
  Result := nextpas.core.atomic.AtomicCompareExchangePtr(ATarget, AExpected, ADesired, AOrder);
end;

function AtomicIsLockFreePtr: Boolean;
begin
  Result := nextpas.core.atomic.AtomicIsLockFreePtr;
end;

function AtomicWait32(var ATarget: Int32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
begin
  Result := nextpas.core.atomic.AtomicWait32(ATarget, AExpected, ATimeoutNs);
end;

function AtomicNotifyOne32(var ATarget: Int32): Int32;
begin
  Result := nextpas.core.atomic.AtomicNotifyOne32(ATarget);
end;

function AtomicNotifyAll32(var ATarget: Int32): Int32;
begin
  Result := nextpas.core.atomic.AtomicNotifyAll32(ATarget);
end;

procedure AtomicThreadFence(const AOrder: TMemoryOrder);
begin
  nextpas.core.atomic.AtomicThreadFence(AOrder);
end;

procedure AtomicSignalFence(const AOrder: TMemoryOrder);
begin
  nextpas.core.atomic.AtomicSignalFence(AOrder);
end;

end.

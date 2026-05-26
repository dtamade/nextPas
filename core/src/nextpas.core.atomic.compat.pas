unit nextpas.core.atomic.compat;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic;

// NOTE: This unit intentionally exposes legacy / potentially-misleading overloads.
// In v3, these APIs should not live in the main nextpas.core.atomic surface.

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

end.

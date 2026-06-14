{******************************************************************************}
{                                                                              }
{  nextpas.core.tls.openssl.api.thread - OpenSSL Thread Module Pascal Binding           }
{                                                                              }
{  Copyright (c) 2024 fafafa                                                  }
{                                                                              }
{******************************************************************************}
unit nextpas.core.tls.openssl.api.thread;

{$mode ObjFPC}{$H+}

interface

uses Windows, cthreads, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.api.consts, nextpas.core.tls.openssl.loader; type CRYPTO_RWLOCK = record end;
  PCRYPTO_RWLOCK = ^CRYPTO_RWLOCK;
  
  CRYPTO_THREAD_LOCAL = TOpenSSLULong;
  PCRYPTO_THREAD_LOCAL = ^CRYPTO_THREAD_LOCAL;
  
  CRYPTO_THREAD_ID = TOpenSSLULong;
  PCRYPTO_THREAD_ID = ^CRYPTO_THREAD_ID;
  
  CRYPTO_ONCE = TOpenSSLInt;
  PCRYPTO_ONCE = ^CRYPTO_ONCE;
  
  { Thread callback types }
  TCRYPTO_thread_fn = procedure(arg: Pointer); cdecl;
  TCRYPTO_once_fn = procedure; cdecl;
  TCRYPTO_thread_stop_fn = procedure(arg: Pointer); cdecl;
  
  { Legacy thread types }
  TCRYPTO_lock_fn = procedure(mode: TOpenSSLInt; type_: TOpenSSLInt; const file_: PChar; line: TOpenSSLInt); cdecl;
  TCRYPTO_id_fn = function: TOpenSSLULong; cdecl;
  TCRYPTO_dynlock_create_fn = function(const file_: PChar; line: TOpenSSLInt): Pointer; cdecl;
  TCRYPTO_dynlock_lock_fn = procedure(mode: TOpenSSLInt; l: Pointer; const file_: PChar; line: TOpenSSLInt); cdecl;
  TCRYPTO_dynlock_destroy_fn = procedure(l: Pointer; const file_: PChar; line: TOpenSSLInt); cdecl;
  
  { Function pointers for dynamic loading }
  { Thread functions }
  TCRYPTOThreadSetup = function: TOpenSSLInt; cdecl;
  TCRYPTOThreadCleanup = function: TOpenSSLInt; cdecl;
  TCRYPTOThreadRunOnce = function(once: PCRYPTO_ONCE; init: TCRYPTO_once_fn): TOpenSSLInt; cdecl;
  TCRYPTOThreadGetCurrentID = function: CRYPTO_THREAD_ID; cdecl;
  TCRYPTOThreadCompareID = function(a, b: CRYPTO_THREAD_ID): TOpenSSLInt; cdecl;
  
  { RW Lock functions }
  TCRYPTOThreadRWLockNew = function: PCRYPTO_RWLOCK; cdecl;
  TCRYPTOThreadReadLock = function(lock: PCRYPTO_RWLOCK): TOpenSSLInt; cdecl;
  TCRYPTOThreadWriteLock = function(lock: PCRYPTO_RWLOCK): TOpenSSLInt; cdecl;
  TCRYPTOThreadUnlock = function(lock: PCRYPTO_RWLOCK): TOpenSSLInt; cdecl;
  TCRYPTOThreadRWLockFree = procedure(lock: PCRYPTO_RWLOCK); cdecl;
  
  { Thread local storage }
  TCRYPTOThreadLocalNew = function(key: PCRYPTO_THREAD_LOCAL; cleanup: TCRYPTO_thread_stop_fn): TOpenSSLInt; cdecl;
  TCRYPTOThreadLocalSet = function(key: PCRYPTO_THREAD_LOCAL; val: Pointer): TOpenSSLInt; cdecl;
  TCRYPTOThreadLocalGet = function(key: PCRYPTO_THREAD_LOCAL): Pointer; cdecl;
  TCRYPTOThreadLocalFree = function(key: PCRYPTO_THREAD_LOCAL): TOpenSSLInt; cdecl;
  
  { Atomic operations }
  TCRYPTOAtomicAdd = function(val: POpenSSLInt; amount: TOpenSSLInt; ret: POpenSSLInt; lock: PCRYPTO_RWLOCK): TOpenSSLInt; cdecl;
  TCRYPTOAtomicOr = function(val: PUInt64; op: UInt64; ret: PUInt64; lock: PCRYPTO_RWLOCK): TOpenSSLInt; cdecl;
  TCRYPTOAtomicLoad = function(val: PUInt64; ret: PUInt64; lock: PCRYPTO_RWLOCK): TOpenSSLInt; cdecl;
  
  { Legacy thread functions }
  TCRYPTOSetLockingCallback = procedure(func: TCRYPTO_lock_fn); cdecl;
  TCRYPTOSetIDCallback = procedure(func: TCRYPTO_id_fn); cdecl;
  TCRYPTONumLocks = function: TOpenSSLInt; cdecl;
  TCRYPTOSetDynlockCreateCallback = procedure(func: TCRYPTO_dynlock_create_fn); cdecl;
  TCRYPTOSetDynlockLockCallback = procedure(func: TCRYPTO_dynlock_lock_fn); cdecl;
  TCRYPTOSetDynlockDestroyCallback = procedure(func: TCRYPTO_dynlock_destroy_fn); cdecl;
  TCRYPTOLock = procedure(type_: TOpenSSLInt); cdecl;
  TCRYPTOUnlock = procedure(type_: TOpenSSLInt); cdecl;
  TCRYPTOThreadID = function: TOpenSSLULong; cdecl;

var
  { Function variables }
  { Thread functions }
  CRYPTO_thread_setup: TCRYPTOThreadSetup = nil;
  CRYPTO_thread_cleanup: TCRYPTOThreadCleanup = nil;
  CRYPTO_THREAD_run_once: TCRYPTOThreadRunOnce = nil;
  CRYPTO_THREAD_get_current_id: TCRYPTOThreadGetCurrentID = nil;
  CRYPTO_THREAD_compare_id: TCRYPTOThreadCompareID = nil;
  
  { RW Lock functions }
  CRYPTO_THREAD_lock_new: TCRYPTOThreadRWLockNew = nil;
  CRYPTO_THREAD_read_lock: TCRYPTOThreadReadLock = nil;
  CRYPTO_THREAD_write_lock: TCRYPTOThreadWriteLock = nil;
  CRYPTO_THREAD_unlock: TCRYPTOThreadUnlock = nil;
  CRYPTO_THREAD_lock_free: TCRYPTOThreadRWLockFree = nil;
  
  { Thread local storage }
  CRYPTO_THREAD_local_new: TCRYPTOThreadLocalNew = nil;
  CRYPTO_THREAD_set_local: TCRYPTOThreadLocalSet = nil;
  CRYPTO_THREAD_get_local: TCRYPTOThreadLocalGet = nil;
  CRYPTO_THREAD_cleanup_local: TCRYPTOThreadLocalFree = nil;
  
  { Atomic operations }
  CRYPTO_atomic_add: TCRYPTOAtomicAdd = nil;
  CRYPTO_atomic_or: TCRYPTOAtomicOr = nil;
  CRYPTO_atomic_load: TCRYPTOAtomicLoad = nil;
  
  { Legacy functions }
  CRYPTO_set_locking_callback: TCRYPTOSetLockingCallback = nil;
  CRYPTO_set_id_callback: TCRYPTOSetIDCallback = nil;
  CRYPTO_num_locks: TCRYPTONumLocks = nil;
  CRYPTO_set_dynlock_create_callback: TCRYPTOSetDynlockCreateCallback = nil;
  CRYPTO_set_dynlock_lock_callback: TCRYPTOSetDynlockLockCallback = nil;
  CRYPTO_set_dynlock_destroy_callback: TCRYPTOSetDynlockDestroyCallback = nil;
  CRYPTO_lock: TCRYPTOLock = nil;
  CRYPTO_unlock: TCRYPTOUnlock = nil;
  CRYPTO_thread_id_func: TCRYPTOThreadID = nil;

{ Load/Unload functions }
function LoadThread(const ALibCrypto: THandle): Boolean;
procedure UnloadThread;

{ Helper functions }
function CreateThreadLock: PCRYPTO_RWLOCK;
procedure FreeThreadLock(Lock: PCRYPTO_RWLOCK);
function LockForRead(Lock: PCRYPTO_RWLOCK): Boolean;
function LockForWrite(Lock: PCRYPTO_RWLOCK): Boolean;
function UnlockThread(Lock: PCRYPTO_RWLOCK): Boolean;
function GetCurrentThreadID: CRYPTO_THREAD_ID;
function AtomicIncrement(var Value: TOpenSSLInt; Lock: PCRYPTO_RWLOCK = nil): TOpenSSLInt;
function AtomicDecrement(var Value: TOpenSSLInt; Lock: PCRYPTO_RWLOCK = nil): TOpenSSLInt;

implementation

uses nextpas.core.tls.openssl.api.utils; const ThreadBindings: array[0..25] of TFunctionBinding = ( (Name: 'CRYPTO_thread_setup'; FuncPtr: @CRYPTO_thread_setup; Required: False);
    (Name: 'CRYPTO_thread_cleanup';            FuncPtr: @CRYPTO_thread_cleanup;            Required: False),
    (Name: 'CRYPTO_THREAD_run_once';           FuncPtr: @CRYPTO_THREAD_run_once;           Required: False),
    (Name: 'CRYPTO_THREAD_get_current_id';     FuncPtr: @CRYPTO_THREAD_get_current_id;     Required: False),
    (Name: 'CRYPTO_THREAD_compare_id';         FuncPtr: @CRYPTO_THREAD_compare_id;         Required: False),
    { RW Lock functions }
    (Name: 'CRYPTO_THREAD_lock_new';           FuncPtr: @CRYPTO_THREAD_lock_new;           Required: False),
    (Name: 'CRYPTO_THREAD_read_lock';          FuncPtr: @CRYPTO_THREAD_read_lock;          Required: False),
    (Name: 'CRYPTO_THREAD_write_lock';         FuncPtr: @CRYPTO_THREAD_write_lock;         Required: False),
    (Name: 'CRYPTO_THREAD_unlock';             FuncPtr: @CRYPTO_THREAD_unlock;             Required: False),
    (Name: 'CRYPTO_THREAD_lock_free';          FuncPtr: @CRYPTO_THREAD_lock_free;          Required: False),
    { Thread local storage }
    (Name: 'CRYPTO_THREAD_local_new';          FuncPtr: @CRYPTO_THREAD_local_new;          Required: False),
    (Name: 'CRYPTO_THREAD_set_local';          FuncPtr: @CRYPTO_THREAD_set_local;          Required: False),
    (Name: 'CRYPTO_THREAD_get_local';          FuncPtr: @CRYPTO_THREAD_get_local;          Required: False),
    (Name: 'CRYPTO_THREAD_cleanup_local';      FuncPtr: @CRYPTO_THREAD_cleanup_local;      Required: False),
    { Atomic operations }
    (Name: 'CRYPTO_atomic_add';                FuncPtr: @CRYPTO_atomic_add;                Required: False),
    (Name: 'CRYPTO_atomic_or';                 FuncPtr: @CRYPTO_atomic_or;                 Required: False),
    (Name: 'CRYPTO_atomic_load';               FuncPtr: @CRYPTO_atomic_load;               Required: False),
    { Legacy functions }
    (Name: 'CRYPTO_set_locking_callback';      FuncPtr: @CRYPTO_set_locking_callback;      Required: False),
    (Name: 'CRYPTO_set_id_callback';           FuncPtr: @CRYPTO_set_id_callback;           Required: False),
    (Name: 'CRYPTO_num_locks';                 FuncPtr: @CRYPTO_num_locks;                 Required: False),
    (Name: 'CRYPTO_set_dynlock_create_callback';  FuncPtr: @CRYPTO_set_dynlock_create_callback;  Required: False),
    (Name: 'CRYPTO_set_dynlock_lock_callback';    FuncPtr: @CRYPTO_set_dynlock_lock_callback;    Required: False),
    (Name: 'CRYPTO_set_dynlock_destroy_callback'; FuncPtr: @CRYPTO_set_dynlock_destroy_callback; Required: False),
    (Name: 'CRYPTO_lock';                      FuncPtr: @CRYPTO_lock;                      Required: False),
    (Name: 'CRYPTO_unlock';                    FuncPtr: @CRYPTO_unlock;                    Required: False),
    (Name: 'CRYPTO_thread_id';                 FuncPtr: @CRYPTO_thread_id_func;            Required: False)
  );

function LoadThread(const ALibCrypto: THandle): Boolean;
begin
  Result := False;
  if TOpenSSLLoader.IsModuleLoaded(osmThread) then Exit(True);
  if ALibCrypto = 0 then Exit;

  { Batch load all thread functions }
  TOpenSSLLoader.LoadFunctions(ALibCrypto, ThreadBindings);

  { Thread functions are optional, so we consider it loaded even if some are missing }
  Result := True;
  TOpenSSLLoader.SetModuleLoaded(osmThread, Result);
end;

procedure UnloadThread;
begin
  if not TOpenSSLLoader.IsModuleLoaded(osmThread) then Exit;

  { Clear all function pointers }
  TOpenSSLLoader.ClearFunctions(ThreadBindings);

  TOpenSSLLoader.SetModuleLoaded(osmThread, False);
end;

{ Helper functions }

function CreateThreadLock: PCRYPTO_RWLOCK;
begin
  Result := nil;
  if Assigned(CRYPTO_THREAD_lock_new) then
    Result := CRYPTO_THREAD_lock_new();
end;

procedure FreeThreadLock(Lock: PCRYPTO_RWLOCK);
begin
  if (Lock <> nil) and Assigned(CRYPTO_THREAD_lock_free) then
    CRYPTO_THREAD_lock_free(Lock);
end;

function LockForRead(Lock: PCRYPTO_RWLOCK): Boolean;
begin
  Result := False;
  if (Lock <> nil) and Assigned(CRYPTO_THREAD_read_lock) then
    Result := CRYPTO_THREAD_read_lock(Lock) = 1;
end;

function LockForWrite(Lock: PCRYPTO_RWLOCK): Boolean;
begin
  Result := False;
  if (Lock <> nil) and Assigned(CRYPTO_THREAD_write_lock) then
    Result := CRYPTO_THREAD_write_lock(Lock) = 1;
end;

function UnlockThread(Lock: PCRYPTO_RWLOCK): Boolean;
begin
  Result := False;
  if (Lock <> nil) and Assigned(CRYPTO_THREAD_unlock) then
    Result := CRYPTO_THREAD_unlock(Lock) = 1;
end;

function GetCurrentThreadID: CRYPTO_THREAD_ID;
begin
  if Assigned(CRYPTO_THREAD_get_current_id) then
    Result := CRYPTO_THREAD_get_current_id()
  else
  {$IFDEF WINDOWS}
    Result := GetCurrentThreadId;
  {$ELSE}
    Result := TOpenSSLULong(GetThreadID);
  {$ENDIF}
end;

function AtomicIncrement(var Value: TOpenSSLInt; Lock: PCRYPTO_RWLOCK): TOpenSSLInt;
begin
  if Assigned(CRYPTO_atomic_add) then
    CRYPTO_atomic_add(@Value, 1, @Result, Lock)
  else
  begin
    if Lock <> nil then
      LockForWrite(Lock);
    Inc(Value);
    Result := Value;
    if Lock <> nil then
      UnlockThread(Lock);
  end;
end;

function AtomicDecrement(var Value: TOpenSSLInt; Lock: PCRYPTO_RWLOCK): TOpenSSLInt;
begin
  if Assigned(CRYPTO_atomic_add) then
    CRYPTO_atomic_add(@Value, -1, @Result, Lock)
  else
  begin
    if Lock <> nil then
      LockForWrite(Lock);
    Dec(Value);
    Result := Value;
    if Lock <> nil then
      UnlockThread(Lock);
  end;
end;

initialization

finalization
  UnloadThread;

end.
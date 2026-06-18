unit nextpas.core.tls.openssl.api.lhash;

{$mode ObjFPC}{$H+}

interface

uses nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.exceptions, nextpas.core.tls.openssl.base, nextpas.core.tls.openssl.loader,
  nextpas.core.platform.dl;

type
  // LHASH node structure (opaque)
  OPENSSL_LH_NODE = record
    opaque_data: Pointer;
  end;
  POPENSSL_LH_NODE = ^OPENSSL_LH_NODE;
  
  // LHASH structure (opaque)
  OPENSSL_LHASH = record
    opaque_data: Pointer;
  end;
  POPENSSL_LHASH = ^OPENSSL_LHASH;
  
  // Typed LHASH definitions
  PLHASH_OF_CONF_VALUE = POPENSSL_LHASH;
  PLHASH_OF_OBJ_NAME = POPENSSL_LHASH;
  PLHASH_OF_ERR_STRING_DATA = POPENSSL_LHASH;
  PLHASH_OF_OPENSSL_STRING = POPENSSL_LHASH;
  PLHASH_OF_OPENSSL_CSTRING = POPENSSL_LHASH;
  
  // LHASH comparison function
  TLHASH_COMP_FN = function(const a, b: Pointer): Integer; cdecl;
  TOPENSSL_LH_COMPFUNC = TLHASH_COMP_FN;
  
  // LHASH hash function
  TLHASH_HASH_FN = function(const a: Pointer): LongWord; cdecl;
  TOPENSSL_LH_HASHFUNC = TLHASH_HASH_FN;
  
  // LHASH doall function
  TLHASH_DOALL_FN = procedure(a: Pointer); cdecl;
  TOPENSSL_LH_DOALL_FUNC = TLHASH_DOALL_FN;
  
  // LHASH doall with arg function
  TLHASH_DOALL_ARG_FN = procedure(a: Pointer; arg: Pointer); cdecl;
  TOPENSSL_LH_DOALL_FUNCARG = TLHASH_DOALL_ARG_FN;
  
  // LHASH stats structure
  OPENSSL_LHASH_STATS = record
    num_items: Cardinal;
    num_nodes: Cardinal;
    num_alloc_nodes: Cardinal;
    num_expands: Cardinal;
    num_expand_reallocs: Cardinal;
    num_contracts: Cardinal;
    num_contract_reallocs: Cardinal;
    num_hash_calls: Cardinal;
    num_comp_calls: Cardinal;
    num_retrieve: Cardinal;
    num_retrieve_miss: Cardinal;
    num_hash_comps: Cardinal;
  end;
  POPENSSL_LHASH_STATS = ^OPENSSL_LHASH_STATS;
  
  // Function pointer types
  TOPENSSL_LH_new = function(h: TOPENSSL_LH_HASHFUNC; c: TOPENSSL_LH_COMPFUNC): POPENSSL_LHASH; cdecl;
  TOPENSSL_LH_free = procedure(lh: POPENSSL_LHASH); cdecl;
  TOPENSSL_LH_flush = procedure(lh: POPENSSL_LHASH); cdecl;
  TOPENSSL_LH_insert = function(lh: POPENSSL_LHASH; data: Pointer): Pointer; cdecl;
  TOPENSSL_LH_delete = function(lh: POPENSSL_LHASH; const data: Pointer): Pointer; cdecl;
  TOPENSSL_LH_retrieve = function(lh: POPENSSL_LHASH; const data: Pointer): Pointer; cdecl;
  TOPENSSL_LH_doall = procedure(lh: POPENSSL_LHASH; func: TOPENSSL_LH_DOALL_FUNC); cdecl;
  TOPENSSL_LH_doall_arg = procedure(lh: POPENSSL_LHASH; func: TOPENSSL_LH_DOALL_FUNCARG; arg: Pointer); cdecl;
  TOPENSSL_LH_strhash = function(const c: PAnsiChar): LongWord; cdecl;
  TOPENSSL_LH_num_items = function(const lh: POPENSSL_LHASH): LongWord; cdecl;
  TOPENSSL_LH_get_down_load = function(const lh: POPENSSL_LHASH): LongWord; cdecl;
  TOPENSSL_LH_set_down_load = procedure(lh: POPENSSL_LHASH; down_load: LongWord); cdecl;
  TOPENSSL_LH_stats = procedure(const lh: POPENSSL_LHASH; fp: PBIO); cdecl;
  TOPENSSL_LH_node_stats = procedure(const lh: POPENSSL_LHASH; fp: PBIO); cdecl;
  TOPENSSL_LH_node_usage_stats = procedure(const lh: POPENSSL_LHASH; fp: PBIO); cdecl;
  TOPENSSL_LH_stats_bio = procedure(const lh: POPENSSL_LHASH; outp: PBIO); cdecl;
  TOPENSSL_LH_node_stats_bio = procedure(const lh: POPENSSL_LHASH; outp: PBIO); cdecl;
  TOPENSSL_LH_node_usage_stats_bio = procedure(const lh: POPENSSL_LHASH; outp: PBIO); cdecl;
  
  // Legacy compatibility
  Tlh_new = TOPENSSL_LH_new;
  Tlh_free = TOPENSSL_LH_free;
  Tlh_insert = TOPENSSL_LH_insert;
  Tlh_delete = TOPENSSL_LH_delete;
  Tlh_retrieve = TOPENSSL_LH_retrieve;
  Tlh_doall = TOPENSSL_LH_doall;
  Tlh_doall_arg = TOPENSSL_LH_doall_arg;
  Tlh_strhash = TOPENSSL_LH_strhash;
  Tlh_num_items = TOPENSSL_LH_num_items;

var
  // LHASH functions
  OPENSSL_LH_new: TOPENSSL_LH_new = nil;
  OPENSSL_LH_free: TOPENSSL_LH_free = nil;
  OPENSSL_LH_flush: TOPENSSL_LH_flush = nil;
  OPENSSL_LH_insert: TOPENSSL_LH_insert = nil;
  OPENSSL_LH_delete: TOPENSSL_LH_delete = nil;
  OPENSSL_LH_retrieve: TOPENSSL_LH_retrieve = nil;
  OPENSSL_LH_doall: TOPENSSL_LH_doall = nil;
  OPENSSL_LH_doall_arg: TOPENSSL_LH_doall_arg = nil;
  OPENSSL_LH_strhash: TOPENSSL_LH_strhash = nil;
  OPENSSL_LH_num_items: TOPENSSL_LH_num_items = nil;
  OPENSSL_LH_get_down_load: TOPENSSL_LH_get_down_load = nil;
  OPENSSL_LH_set_down_load: TOPENSSL_LH_set_down_load = nil;
  OPENSSL_LH_stats: TOPENSSL_LH_stats = nil;
  OPENSSL_LH_node_stats: TOPENSSL_LH_node_stats = nil;
  OPENSSL_LH_node_usage_stats: TOPENSSL_LH_node_usage_stats = nil;
  OPENSSL_LH_stats_bio: TOPENSSL_LH_stats_bio = nil;
  OPENSSL_LH_node_stats_bio: TOPENSSL_LH_node_stats_bio = nil;
  OPENSSL_LH_node_usage_stats_bio: TOPENSSL_LH_node_usage_stats_bio = nil;
  
  // Legacy compatibility functions
  lh_new: Tlh_new = nil;
  lh_free: Tlh_free = nil;
  lh_insert: Tlh_insert = nil;
  lh_delete: Tlh_delete = nil;
  lh_retrieve: Tlh_retrieve = nil;
  lh_doall: Tlh_doall = nil;
  lh_doall_arg: Tlh_doall_arg = nil;
  lh_strhash: Tlh_strhash = nil;
  lh_num_items: Tlh_num_items = nil;

// Load and unload functions
function LoadLHashFunctions: Boolean;
procedure UnloadLHashFunctions;

// High-level helper functions
function CreateStringHashTable: POPENSSL_LHASH;
procedure FreeHashTable(Hash: POPENSSL_LHASH);
function InsertIntoHashTable(Hash: POPENSSL_LHASH; Key: PAnsiChar; Data: Pointer): Boolean;
function RetrieveFromHashTable(Hash: POPENSSL_LHASH; Key: PAnsiChar): Pointer;
function DeleteFromHashTable(Hash: POPENSSL_LHASH; Key: PAnsiChar): Pointer;
function GetHashTableItemCount(Hash: POPENSSL_LHASH): LongWord;

// String hash helpers
function HashString(const Str: string): LongWord;
function HashStringWrapper(const p: Pointer): LongWord; cdecl;
function CompareStrings(const a, b: Pointer): Integer; cdecl;
function HashPointer(const p: Pointer): LongWord; cdecl;
function ComparePointers(const a, b: Pointer): Integer; cdecl;

implementation

// Phase 3.3 P0+ - nextpas.core.tls.openssl.loader 已移至 interface uses 子句

function LoadLHashFunctions: Boolean;
var
  LHandle: TPlatformLibrary;
begin
  Result := False;

  // Phase 3.3 P0+ - 使用统一的动态库加载器（替换 ~25 行重复代码）
  LHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  if not LibLoaded(LHandle) then
    Exit;
    
  // Load LHASH functions (OpenSSL 1.1.0+)
  OPENSSL_LH_new := TOPENSSL_LH_new(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_new'));
  OPENSSL_LH_free := TOPENSSL_LH_free(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_free'));
  OPENSSL_LH_flush := TOPENSSL_LH_flush(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_flush'));
  OPENSSL_LH_insert := TOPENSSL_LH_insert(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_insert'));
  OPENSSL_LH_delete := TOPENSSL_LH_delete(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_delete'));
  OPENSSL_LH_retrieve := TOPENSSL_LH_retrieve(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_retrieve'));
  OPENSSL_LH_doall := TOPENSSL_LH_doall(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_doall'));
  OPENSSL_LH_doall_arg := TOPENSSL_LH_doall_arg(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_doall_arg'));
  OPENSSL_LH_strhash := TOPENSSL_LH_strhash(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_strhash'));
  OPENSSL_LH_num_items := TOPENSSL_LH_num_items(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_num_items'));
  OPENSSL_LH_get_down_load := TOPENSSL_LH_get_down_load(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_get_down_load'));
  OPENSSL_LH_set_down_load := TOPENSSL_LH_set_down_load(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_set_down_load'));
  OPENSSL_LH_stats := TOPENSSL_LH_stats(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_stats'));
  OPENSSL_LH_node_stats := TOPENSSL_LH_node_stats(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_node_stats'));
  OPENSSL_LH_node_usage_stats := TOPENSSL_LH_node_usage_stats(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_node_usage_stats'));
  OPENSSL_LH_stats_bio := TOPENSSL_LH_stats_bio(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_stats_bio'));
  OPENSSL_LH_node_stats_bio := TOPENSSL_LH_node_stats_bio(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_node_stats_bio'));
  OPENSSL_LH_node_usage_stats_bio := TOPENSSL_LH_node_usage_stats_bio(TOpenSSLLoader.GetFunction(LHandle, 'OPENSSL_LH_node_usage_stats_bio'));
  
  // Try legacy lh_* functions for compatibility (pre-1.1.0)
  if not Assigned(OPENSSL_LH_new) then
  begin
    lh_new := Tlh_new(TOpenSSLLoader.GetFunction(LHandle, 'lh_new'));
    lh_free := Tlh_free(TOpenSSLLoader.GetFunction(LHandle, 'lh_free'));
    lh_insert := Tlh_insert(TOpenSSLLoader.GetFunction(LHandle, 'lh_insert'));
    lh_delete := Tlh_delete(TOpenSSLLoader.GetFunction(LHandle, 'lh_delete'));
    lh_retrieve := Tlh_retrieve(TOpenSSLLoader.GetFunction(LHandle, 'lh_retrieve'));
    lh_doall := Tlh_doall(TOpenSSLLoader.GetFunction(LHandle, 'lh_doall'));
    lh_doall_arg := Tlh_doall_arg(TOpenSSLLoader.GetFunction(LHandle, 'lh_doall_arg'));
    lh_strhash := Tlh_strhash(TOpenSSLLoader.GetFunction(LHandle, 'lh_strhash'));
    lh_num_items := Tlh_num_items(TOpenSSLLoader.GetFunction(LHandle, 'lh_num_items'));
    
    // Map legacy functions to modern ones
    if Assigned(lh_new) then
    begin
      OPENSSL_LH_new := TOPENSSL_LH_new(@lh_new);
      OPENSSL_LH_free := TOPENSSL_LH_free(@lh_free);
      OPENSSL_LH_insert := TOPENSSL_LH_insert(@lh_insert);
      OPENSSL_LH_delete := TOPENSSL_LH_delete(@lh_delete);
      OPENSSL_LH_retrieve := TOPENSSL_LH_retrieve(@lh_retrieve);
      OPENSSL_LH_doall := TOPENSSL_LH_doall(@lh_doall);
      OPENSSL_LH_doall_arg := TOPENSSL_LH_doall_arg(@lh_doall_arg);
      OPENSSL_LH_strhash := TOPENSSL_LH_strhash(@lh_strhash);
      OPENSSL_LH_num_items := TOPENSSL_LH_num_items(@lh_num_items);
    end;
  end
  else
  begin
    // Map modern functions to legacy names for compatibility
    lh_new := OPENSSL_LH_new;
    lh_free := OPENSSL_LH_free;
    lh_insert := OPENSSL_LH_insert;
    lh_delete := OPENSSL_LH_delete;
    lh_retrieve := OPENSSL_LH_retrieve;
    lh_doall := OPENSSL_LH_doall;
    lh_doall_arg := OPENSSL_LH_doall_arg;
    lh_strhash := OPENSSL_LH_strhash;
    lh_num_items := OPENSSL_LH_num_items;
  end;

  Result := Assigned(OPENSSL_LH_new) or Assigned(lh_new);
  TOpenSSLLoader.SetModuleLoaded(osmLHash, Result);
end;

procedure UnloadLHashFunctions;
begin
  // Clear LHASH functions
  OPENSSL_LH_new := nil;
  OPENSSL_LH_free := nil;
  OPENSSL_LH_flush := nil;
  OPENSSL_LH_insert := nil;
  OPENSSL_LH_delete := nil;
  OPENSSL_LH_retrieve := nil;
  OPENSSL_LH_doall := nil;
  OPENSSL_LH_doall_arg := nil;
  OPENSSL_LH_strhash := nil;
  OPENSSL_LH_num_items := nil;
  OPENSSL_LH_get_down_load := nil;
  OPENSSL_LH_set_down_load := nil;
  OPENSSL_LH_stats := nil;
  OPENSSL_LH_node_stats := nil;
  OPENSSL_LH_node_usage_stats := nil;
  OPENSSL_LH_stats_bio := nil;
  OPENSSL_LH_node_stats_bio := nil;
  OPENSSL_LH_node_usage_stats_bio := nil;
  
  // Clear legacy functions
  lh_new := nil;
  lh_free := nil;
  lh_insert := nil;
  lh_delete := nil;
  lh_retrieve := nil;
  lh_doall := nil;
  lh_doall_arg := nil;
  lh_strhash := nil;
  lh_num_items := nil;

  TOpenSSLLoader.SetModuleLoaded(osmLHash, False);

  // 注意: 库卸载由 TOpenSSLLoader 自动处理（在 finalization 部分）
end;


// Callback functions
function HashStringWrapper(const p: Pointer): LongWord; cdecl;
begin
  if Assigned(OPENSSL_LH_strhash) then
    Result := OPENSSL_LH_strhash(PAnsiChar(p))
  else
    Result := LongWord(PtrUInt(p));
end;

function CompareStrings(const a, b: Pointer): Integer; cdecl;
begin
  Result := StrComp(PAnsiChar(a), PAnsiChar(b));
end;

function HashPointer(const p: Pointer): LongWord; cdecl;
begin
  Result := LongWord(PtrUInt(p));
end;

function ComparePointers(const a, b: Pointer): Integer; cdecl;
begin
  if PtrUInt(a) < PtrUInt(b) then
    Result := -1
  else if PtrUInt(a) > PtrUInt(b) then
    Result := 1
  else
    Result := 0;
end;

// High-level helper function implementations

function CreateStringHashTable: POPENSSL_LHASH;
begin
  if not Assigned(OPENSSL_LH_new) then
    raise ESSLException.Create('LHASH functions not loaded');
    
  Result := OPENSSL_LH_new(TOPENSSL_LH_HASHFUNC(@HashStringWrapper), TOPENSSL_LH_COMPFUNC(@CompareStrings));
  if Result = nil then
    raise ESSLException.Create('Failed to create hash table');
end;

procedure FreeHashTable(Hash: POPENSSL_LHASH);
begin
  if (Hash <> nil) and Assigned(OPENSSL_LH_free) then
    OPENSSL_LH_free(Hash);
end;

function InsertIntoHashTable(Hash: POPENSSL_LHASH; Key: PAnsiChar; Data: Pointer): Boolean;
var
  old: Pointer;
begin
  Result := False;
  
  if (Hash = nil) or not Assigned(OPENSSL_LH_insert) then
    Exit;
    
  old := OPENSSL_LH_insert(Hash, Data);
  Result := True;
  
  // If old is not nil, there was a previous entry with the same key
  // In a real implementation, you might want to free the old data
end;

function RetrieveFromHashTable(Hash: POPENSSL_LHASH; Key: PAnsiChar): Pointer;
begin
  Result := nil;
  
  if (Hash <> nil) and Assigned(OPENSSL_LH_retrieve) then
    Result := OPENSSL_LH_retrieve(Hash, Key);
end;

function DeleteFromHashTable(Hash: POPENSSL_LHASH; Key: PAnsiChar): Pointer;
begin
  Result := nil;
  
  if (Hash <> nil) and Assigned(OPENSSL_LH_delete) then
    Result := OPENSSL_LH_delete(Hash, Key);
end;

function GetHashTableItemCount(Hash: POPENSSL_LHASH): LongWord;
begin
  Result := 0;
  
  if (Hash <> nil) and Assigned(OPENSSL_LH_num_items) then
    Result := OPENSSL_LH_num_items(Hash);
end;

function HashString(const Str: string): LongWord;
var
  astr: AnsiString;
begin
  Result := 0;
  
  if Assigned(OPENSSL_LH_strhash) then
  begin
    astr := AnsiString(Str);
    Result := OPENSSL_LH_strhash(PAnsiChar(astr));
  end;
end;

initialization
  
finalization
  UnloadLHashFunctions;
  
end.
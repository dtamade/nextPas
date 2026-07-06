{**
 * @desc Compiler internal functions for the nextPas system kernel.
 *
 * Defines fpc_* series functions with compilerproc directive.
 * These are stubs — real implementations provided by runtime.
 * Depends on base.inc, str.inc.
 *
 * NOTE: This file is only included under nextPas.
 * For FPC, functions are provided by FPC runtime.
 *}

{ String management — compiler internal }
function fpc_ansistr_incr_ref(S: Pointer): Pointer; compilerproc;
function fpc_ansistr_decr_ref(S: Pointer): Pointer; compilerproc;
function fpc_ansistr_assign(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_ansistr_concat(Dest: Pointer; const S1, S2: AnsiString): Pointer; compilerproc;
function fpc_ansistr_compare(const S1, S2: AnsiString): SizeInt; compilerproc;
function fpc_ansistr_compare_equal(const S1, S2: AnsiString): SizeInt; compilerproc;
function fpc_ansistr_length(S: Pointer): SizeInt; compilerproc;
function fpc_ansistr_setlength(S: Pointer; NewLen: SizeInt): Pointer; compilerproc;
function fpc_ansistr_unique(S: Pointer): Pointer; compilerproc;
function fpc_ansistr_copy(const S: AnsiString; Index, Count: SizeInt): AnsiString; compilerproc;
function fpc_ansistr_delete(S: Pointer; Index, Count: SizeInt): Pointer; compilerproc;
function fpc_ansistr_insert(S: Pointer; const Sub: AnsiString; Index: SizeInt): Pointer; compilerproc;
function fpc_ansistr_pos(const Sub, S: AnsiString): SizeInt; compilerproc;
function fpc_ansistr_char(S: Pointer; Index: SizeInt): AnsiChar; compilerproc;
function fpc_ansistr_pchar(S: Pointer): PAnsiChar; compilerproc;
function fpc_ansistr_to_shortstring(Dest: Pointer; const S: AnsiString): Pointer; compilerproc;
function fpc_ansistr_from_shortstring(Dest: Pointer; const S: ShortString): Pointer; compilerproc;
function fpc_ansistr_from_pchar(S: PAnsiChar): AnsiString; compilerproc;
function fpc_ansistr_from_char(C: AnsiChar): AnsiString; compilerproc;
function fpc_ansistr_from_widestring(const S: WideString): AnsiString; compilerproc;
function fpc_ansistr_from_unicodestring(const S: UnicodeString): AnsiString; compilerproc;
function fpc_ansistr_to_widestring(const S: AnsiString): WideString; compilerproc;
function fpc_ansistr_to_unicodestring(const S: AnsiString): UnicodeString; compilerproc;

{ WideString management — compiler internal }
function fpc_widestr_incr_ref(S: Pointer): Pointer; compilerproc;
function fpc_widestr_decr_ref(S: Pointer): Pointer; compilerproc;
function fpc_widestr_assign(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_widestr_concat(Dest: Pointer; const S1, S2: WideString): Pointer; compilerproc;
function fpc_widestr_compare(const S1, S2: WideString): SizeInt; compilerproc;
function fpc_widestr_compare_equal(const S1, S2: WideString): SizeInt; compilerproc;
function fpc_widestr_length(S: Pointer): SizeInt; compilerproc;
function fpc_widestr_setlength(S: Pointer; NewLen: SizeInt): Pointer; compilerproc;
function fpc_widestr_unique(S: Pointer): Pointer; compilerproc;
function fpc_widestr_copy(const S: WideString; Index, Count: SizeInt): WideString; compilerproc;
function fpc_widestr_delete(S: Pointer; Index, Count: SizeInt): Pointer; compilerproc;
function fpc_widestr_insert(S: Pointer; const Sub: WideString; Index: SizeInt): Pointer; compilerproc;
function fpc_widestr_pos(const Sub, S: WideString): SizeInt; compilerproc;
function fpc_widestr_char(S: Pointer; Index: SizeInt): WideChar; compilerproc;
function fpc_widestr_pwidechar(S: Pointer): PWideChar; compilerproc;
function fpc_widestr_to_ansistring(const S: WideString): AnsiString; compilerproc;
function fpc_widestr_from_ansistring(const S: AnsiString): WideString; compilerproc;
function fpc_widestr_from_unicodestring(const S: UnicodeString): WideString; compilerproc;
function fpc_widestr_to_unicodestring(const S: WideString): UnicodeString; compilerproc;

{ UnicodeString management — compiler internal }
function fpc_unicodestr_incr_ref(S: Pointer): Pointer; compilerproc;
function fpc_unicodestr_decr_ref(S: Pointer): Pointer; compilerproc;
function fpc_unicodestr_assign(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_unicodestr_concat(Dest: Pointer; const S1, S2: UnicodeString): Pointer; compilerproc;
function fpc_unicodestr_compare(const S1, S2: UnicodeString): SizeInt; compilerproc;
function fpc_unicodestr_compare_equal(const S1, S2: UnicodeString): SizeInt; compilerproc;
function fpc_unicodestr_length(S: Pointer): SizeInt; compilerproc;
function fpc_unicodestr_setlength(S: Pointer; NewLen: SizeInt): Pointer; compilerproc;
function fpc_unicodestr_unique(S: Pointer): Pointer; compilerproc;
function fpc_unicodestr_copy(const S: UnicodeString; Index, Count: SizeInt): UnicodeString; compilerproc;
function fpc_unicodestr_delete(S: Pointer; Index, Count: SizeInt): Pointer; compilerproc;
function fpc_unicodestr_insert(S: Pointer; const Sub: UnicodeString; Index: SizeInt): Pointer; compilerproc;
function fpc_unicodestr_pos(const Sub, S: UnicodeString): SizeInt; compilerproc;
function fpc_unicodestr_char(S: Pointer; Index: SizeInt): WideChar; compilerproc;
function fpc_unicodestr_pwidechar(S: Pointer): PWideChar; compilerproc;
function fpc_unicodestr_to_ansistring(const S: UnicodeString): AnsiString; compilerproc;
function fpc_unicodestr_to_widestring(const S: UnicodeString): WideString; compilerproc;
function fpc_unicodestr_from_ansistring(const S: AnsiString): UnicodeString; compilerproc;
function fpc_unicodestr_from_widestring(const S: WideString): UnicodeString; compilerproc;

{ Dynamic array management — compiler internal }
function fpc_dynarray_incr_ref(S: Pointer): Pointer; compilerproc;
function fpc_dynarray_decr_ref(S: Pointer): Pointer; compilerproc;
function fpc_dynarray_assign(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_dynarray_length(S: Pointer): SizeInt; compilerproc;
function fpc_dynarray_setlength(S: Pointer; NewLen: SizeInt; TypeInfo: Pointer): Pointer; compilerproc;
function fpc_dynarray_unique(S: Pointer): Pointer; compilerproc;
function fpc_dynarray_copy(const S: Pointer; Index, Count: SizeInt; TypeInfo: Pointer): Pointer; compilerproc;
function fpc_dynarray_delete(S: Pointer; Index, Count: SizeInt): Pointer; compilerproc;
function fpc_dynarray_insert(S: Pointer; const Sub: Pointer; Index: SizeInt): Pointer; compilerproc;
function fpc_dynarray_pos(const Sub, S: Pointer): SizeInt; compilerproc;
function fpc_dynarray_get(S: Pointer; Index: SizeInt): Pointer; compilerproc;
function fpc_dynarray_put(S: Pointer; Index: SizeInt; Value: Pointer): Pointer; compilerproc;

{ Variant management — compiler internal }
function fpc_variant_init(S: Pointer): Pointer; compilerproc;
function fpc_variant_clear(S: Pointer): Pointer; compilerproc;
function fpc_variant_assign(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_variant_copy(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_variant_cmp(const S1, S2: Variant): SizeInt; compilerproc;
function fpc_variant_cmp_equal(const S1, S2: Variant): SizeInt; compilerproc;
function fpc_variant_concat(Dest: Pointer; const S1, S2: Variant): Pointer; compilerproc;
function fpc_variant_length(S: Pointer): SizeInt; compilerproc;
function fpc_variant_type(S: Pointer): SizeInt; compilerproc;
function fpc_variant_is_empty(S: Pointer): Boolean; compilerproc;
function fpc_variant_is_null(S: Pointer): Boolean; compilerproc;
function fpc_variant_is_numeric(S: Pointer): Boolean; compilerproc;
function fpc_variant_is_string(S: Pointer): Boolean; compilerproc;
function fpc_variant_to_int(const S: Variant): Int64; compilerproc;
function fpc_variant_to_float(const S: Variant): Double; compilerproc;
function fpc_variant_to_str(const S: Variant): AnsiString; compilerproc;
function fpc_variant_from_int(Value: Int64): Variant; compilerproc;
function fpc_variant_from_float(Value: Double): Variant; compilerproc;
function fpc_variant_from_str(const Value: AnsiString): Variant; compilerproc;

{ Interface management — compiler internal }
function fpc_intf_incr_ref(S: Pointer): Pointer; compilerproc;
function fpc_intf_decr_ref(S: Pointer): Pointer; compilerproc;
function fpc_intf_assign(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_intf_copy(Dest, Src: Pointer): Pointer; compilerproc;
function fpc_intf_clear(S: Pointer): Pointer; compilerproc;
function fpc_intf_is_nil(S: Pointer): Boolean; compilerproc;
function fpc_intf_is_equal(const S1, S2: IUnknown): Boolean; compilerproc;
function fpc_intf_query_interface(S: Pointer; const IID: TGUID; out Obj): LongInt; compilerproc;
function fpc_intf_addref(S: Pointer): LongInt; compilerproc;
function fpc_intf_release(S: Pointer): LongInt; compilerproc;

{ Exception handling — compiler internal }
function fpc_setjmp(var S: jmp_buf): LongInt; compilerproc;
procedure fpc_longjmp(var S: jmp_buf; Value: LongInt); compilerproc;
function fpc_get_exception_address: Pointer; compilerproc;
function fpc_get_exception_object: Pointer; compilerproc;
function fpc_get_exception_class: TClass; compilerproc;
function fpc_try_push(var S: ExceptionRecord): LongInt; compilerproc;
procedure fpc_try_pop(S: ExceptionRecord); compilerproc;
procedure fpc_raise_exception(S: Exception); compilerproc;
procedure fpc_finally_end; compilerproc;
procedure fpc_except_end; compilerproc;

{ Memory management — compiler internal }
function fpc_getmem(Size: SizeInt): Pointer; compilerproc;
function fpc_freemem(P: Pointer): SizeInt; compilerproc;
function fpc_reallocmem(P: Pointer; Size: SizeInt): Pointer; compilerproc;
function fpc_getmem_aligned(Size: SizeInt; Align: SizeInt): Pointer; compilerproc;
function fpc_freemem_aligned(P: Pointer): SizeInt; compilerproc;
function fpc_allocmem(Size: SizeInt): Pointer; compilerproc;
function fpc_memsize(P: Pointer): SizeInt; compilerproc;

{ Halt / Exit — compiler internal }
procedure fpc_exit; compilerproc;
procedure fpc_halt(Code: LongInt); compilerproc;
procedure fpc_haltproc; compilerproc;

implementation

{ All stubs — real implementations provided by runtime }

{ String management stubs }
function fpc_ansistr_incr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_ansistr_decr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_ansistr_assign(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_ansistr_concat(Dest: Pointer; const S1, S2: AnsiString): Pointer; begin Result := Dest; end;
function fpc_ansistr_compare(const S1, S2: AnsiString): SizeInt; begin Result := 0; end;
function fpc_ansistr_compare_equal(const S1, S2: AnsiString): SizeInt; begin Result := 0; end;
function fpc_ansistr_length(S: Pointer): SizeInt; begin Result := 0; end;
function fpc_ansistr_setlength(S: Pointer; NewLen: SizeInt): Pointer; begin Result := S; end;
function fpc_ansistr_unique(S: Pointer): Pointer; begin Result := S; end;
function fpc_ansistr_copy(const S: AnsiString; Index, Count: SizeInt): AnsiString; begin Result := ''; end;
function fpc_ansistr_delete(S: Pointer; Index, Count: SizeInt): Pointer; begin Result := S; end;
function fpc_ansistr_insert(S: Pointer; const Sub: AnsiString; Index: SizeInt): Pointer; begin Result := S; end;
function fpc_ansistr_pos(const Sub, S: AnsiString): SizeInt; begin Result := 0; end;
function fpc_ansistr_char(S: Pointer; Index: SizeInt): AnsiChar; begin Result := #0; end;
function fpc_ansistr_pchar(S: Pointer): PAnsiChar; begin Result := nil; end;
function fpc_ansistr_to_shortstring(Dest: Pointer; const S: AnsiString): Pointer; begin Result := Dest; end;
function fpc_ansistr_from_shortstring(Dest: Pointer; const S: ShortString): Pointer; begin Result := Dest; end;
function fpc_ansistr_from_pchar(S: PAnsiChar): AnsiString; begin Result := ''; end;
function fpc_ansistr_from_char(C: AnsiChar): AnsiString; begin Result := ''; end;
function fpc_ansistr_from_widestring(const S: WideString): AnsiString; begin Result := ''; end;
function fpc_ansistr_from_unicodestring(const S: UnicodeString): AnsiString; begin Result := ''; end;
function fpc_ansistr_to_widestring(const S: AnsiString): WideString; begin Result := ''; end;
function fpc_ansistr_to_unicodestring(const S: AnsiString): UnicodeString; begin Result := ''; end;

{ WideString management stubs }
function fpc_widestr_incr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_widestr_decr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_widestr_assign(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_widestr_concat(Dest: Pointer; const S1, S2: WideString): Pointer; begin Result := Dest; end;
function fpc_widestr_compare(const S1, S2: WideString): SizeInt; begin Result := 0; end;
function fpc_widestr_compare_equal(const S1, S2: WideString): SizeInt; begin Result := 0; end;
function fpc_widestr_length(S: Pointer): SizeInt; begin Result := 0; end;
function fpc_widestr_setlength(S: Pointer; NewLen: SizeInt): Pointer; begin Result := S; end;
function fpc_widestr_unique(S: Pointer): Pointer; begin Result := S; end;
function fpc_widestr_copy(const S: WideString; Index, Count: SizeInt): WideString; begin Result := ''; end;
function fpc_widestr_delete(S: Pointer; Index, Count: SizeInt): Pointer; begin Result := S; end;
function fpc_widestr_insert(S: Pointer; const Sub: WideString; Index: SizeInt): Pointer; begin Result := S; end;
function fpc_widestr_pos(const Sub, S: WideString): SizeInt; begin Result := 0; end;
function fpc_widestr_char(S: Pointer; Index: SizeInt): WideChar; begin Result := #0; end;
function fpc_widestr_pwidechar(S: Pointer): PWideChar; begin Result := nil; end;
function fpc_widestr_to_ansistring(const S: WideString): AnsiString; begin Result := ''; end;
function fpc_widestr_from_ansistring(const S: AnsiString): WideString; begin Result := ''; end;
function fpc_widestr_from_unicodestring(const S: UnicodeString): WideString; begin Result := ''; end;
function fpc_widestr_to_unicodestring(const S: WideString): UnicodeString; begin Result := ''; end;

{ UnicodeString management stubs }
function fpc_unicodestr_incr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_unicodestr_decr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_unicodestr_assign(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_unicodestr_concat(Dest: Pointer; const S1, S2: UnicodeString): Pointer; begin Result := Dest; end;
function fpc_unicodestr_compare(const S1, S2: UnicodeString): SizeInt; begin Result := 0; end;
function fpc_unicodestr_compare_equal(const S1, S2: UnicodeString): SizeInt; begin Result := 0; end;
function fpc_unicodestr_length(S: Pointer): SizeInt; begin Result := 0; end;
function fpc_unicodestr_setlength(S: Pointer; NewLen: SizeInt): Pointer; begin Result := S; end;
function fpc_unicodestr_unique(S: Pointer): Pointer; begin Result := S; end;
function fpc_unicodestr_copy(const S: UnicodeString; Index, Count: SizeInt): UnicodeString; begin Result := ''; end;
function fpc_unicodestr_delete(S: Pointer; Index, Count: SizeInt): Pointer; begin Result := S; end;
function fpc_unicodestr_insert(S: Pointer; const Sub: UnicodeString; Index: SizeInt): Pointer; begin Result := S; end;
function fpc_unicodestr_pos(const Sub, S: UnicodeString): SizeInt; begin Result := 0; end;
function fpc_unicodestr_char(S: Pointer; Index: SizeInt): WideChar; begin Result := #0; end;
function fpc_unicodestr_pwidechar(S: Pointer): PWideChar; begin Result := nil; end;
function fpc_unicodestr_to_ansistring(const S: UnicodeString): AnsiString; begin Result := ''; end;
function fpc_unicodestr_to_widestring(const S: UnicodeString): WideString; begin Result := ''; end;
function fpc_unicodestr_from_ansistring(const S: AnsiString): UnicodeString; begin Result := ''; end;
function fpc_unicodestr_from_widestring(const S: WideString): UnicodeString; begin Result := ''; end;

{ Dynamic array management stubs }
function fpc_dynarray_incr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_dynarray_decr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_dynarray_assign(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_dynarray_length(S: Pointer): SizeInt; begin Result := 0; end;
function fpc_dynarray_setlength(S: Pointer; NewLen: SizeInt; TypeInfo: Pointer): Pointer; begin Result := S; end;
function fpc_dynarray_unique(S: Pointer): Pointer; begin Result := S; end;
function fpc_dynarray_copy(const S: Pointer; Index, Count: SizeInt; TypeInfo: Pointer): Pointer; begin Result := nil; end;
function fpc_dynarray_delete(S: Pointer; Index, Count: SizeInt): Pointer; begin Result := S; end;
function fpc_dynarray_insert(S: Pointer; const Sub: Pointer; Index: SizeInt): Pointer; begin Result := S; end;
function fpc_dynarray_pos(const Sub, S: Pointer): SizeInt; begin Result := 0; end;
function fpc_dynarray_get(S: Pointer; Index: SizeInt): Pointer; begin Result := nil; end;
function fpc_dynarray_put(S: Pointer; Index: SizeInt; Value: Pointer): Pointer; begin Result := S; end;

{ Variant management stubs }
function fpc_variant_init(S: Pointer): Pointer; begin Result := S; end;
function fpc_variant_clear(S: Pointer): Pointer; begin Result := S; end;
function fpc_variant_assign(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_variant_copy(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_variant_cmp(const S1, S2: Variant): SizeInt; begin Result := 0; end;
function fpc_variant_cmp_equal(const S1, S2: Variant): SizeInt; begin Result := 0; end;
function fpc_variant_concat(Dest: Pointer; const S1, S2: Variant): Pointer; begin Result := Dest; end;
function fpc_variant_length(S: Pointer): SizeInt; begin Result := 0; end;
function fpc_variant_type(S: Pointer): SizeInt; begin Result := 0; end;
function fpc_variant_is_empty(S: Pointer): Boolean; begin Result := False; end;
function fpc_variant_is_null(S: Pointer): Boolean; begin Result := False; end;
function fpc_variant_is_numeric(S: Pointer): Boolean; begin Result := False; end;
function fpc_variant_is_string(S: Pointer): Boolean; begin Result := False; end;
function fpc_variant_to_int(const S: Variant): Int64; begin Result := 0; end;
function fpc_variant_to_float(const S: Variant): Double; begin Result := 0.0; end;
function fpc_variant_to_str(const S: Variant): AnsiString; begin Result := ''; end;
function fpc_variant_from_int(Value: Int64): Variant; begin Result := Null; end;
function fpc_variant_from_float(Value: Double): Variant; begin Result := Null; end;
function fpc_variant_from_str(const Value: AnsiString): Variant; begin Result := Null; end;

{ Interface management stubs }
function fpc_intf_incr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_intf_decr_ref(S: Pointer): Pointer; begin Result := S; end;
function fpc_intf_assign(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_intf_copy(Dest, Src: Pointer): Pointer; begin Result := Dest; end;
function fpc_intf_clear(S: Pointer): Pointer; begin Result := S; end;
function fpc_intf_is_nil(S: Pointer): Boolean; begin Result := True; end;
function fpc_intf_is_equal(const S1, S2: IUnknown): Boolean; begin Result := False; end;
function fpc_intf_query_interface(S: Pointer; const IID: TGUID; out Obj): LongInt; begin Result := -1; end;
function fpc_intf_addref(S: Pointer): LongInt; begin Result := 0; end;
function fpc_intf_release(S: Pointer): LongInt; begin Result := 0; end;

{ Exception handling stubs }
function fpc_setjmp(var S: jmp_buf): LongInt; begin Result := 0; end;
procedure fpc_longjmp(var S: jmp_buf; Value: LongInt); begin end;
function fpc_get_exception_address: Pointer; begin Result := nil; end;
function fpc_get_exception_object: Pointer; begin Result := nil; end;
function fpc_get_exception_class: TClass; begin Result := nil; end;
function fpc_try_push(var S: ExceptionRecord): LongInt; begin Result := 0; end;
procedure fpc_try_pop(S: ExceptionRecord); begin end;
procedure fpc_raise_exception(S: Exception); begin end;
procedure fpc_finally_end; begin end;
procedure fpc_except_end; begin end;

{ Memory management stubs }
function fpc_getmem(Size: SizeInt): Pointer; begin Result := nil; end;
function fpc_freemem(P: Pointer): SizeInt; begin Result := 0; end;
function fpc_reallocmem(P: Pointer; Size: SizeInt): Pointer; begin Result := nil; end;
function fpc_getmem_aligned(Size: SizeInt; Align: SizeInt): Pointer; begin Result := nil; end;
function fpc_freemem_aligned(P: Pointer): SizeInt; begin Result := 0; end;
function fpc_allocmem(Size: SizeInt): Pointer; begin Result := nil; end;
function fpc_memsize(P: Pointer): SizeInt; begin Result := 0; end;

{ Halt / Exit stubs }
procedure fpc_exit; begin end;
procedure fpc_halt(Code: LongInt); begin end;
procedure fpc_haltproc; begin end;

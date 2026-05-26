unit nextpas.core.mem.mimalloc.ffi;

{$I nextpas.core.settings.inc}

interface

{ mimalloc C API declarations (cdecl external 'mimalloc') }

function mi_malloc(const ASize: SizeUInt): Pointer; cdecl; external 'mimalloc';
function mi_calloc(const ACount, ASize: SizeUInt): Pointer; cdecl; external 'mimalloc';
function mi_realloc(const APtr: Pointer; const ANewSize: SizeUInt): Pointer; cdecl; external 'mimalloc';
procedure mi_free(const APtr: Pointer); cdecl; external 'mimalloc';
function mi_malloc_aligned(const ASize, AAlignment: SizeUInt): Pointer; cdecl; external 'mimalloc';
procedure mi_free_aligned(const APtr: Pointer; const AAlignment: SizeUInt); cdecl; external 'mimalloc';
function mi_malloc_usable_size(const APtr: Pointer): SizeUInt; cdecl; external 'mimalloc';

implementation

end.

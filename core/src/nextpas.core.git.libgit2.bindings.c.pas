unit nextpas.core.git.libgit2.bindings.c;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

function memcpy(dest: Pointer; src: Pointer; n: TSizeT): Pointer; cdecl; external 'c' name 'memcpy';
function memmove(dest: Pointer; src: Pointer; n: TSizeT): Pointer; cdecl; external 'c' name 'memmove';
function memset(s: Pointer; c: LongInt; n: TSizeT): Pointer; cdecl; external 'c' name 'memset';
function memcmp(s1: Pointer; s2: Pointer; n: TSizeT): LongInt; cdecl; external 'c' name 'memcmp';
function strlen(s: PAnsiChar): TSizeT; cdecl; external 'c' name 'strlen';
function strcmp(s1: PAnsiChar; s2: PAnsiChar): LongInt; cdecl; external 'c' name 'strcmp';
function time(t: PTimeT): TTimeT; cdecl; external 'c' name 'time';
function difftime(var &end: TTimeT; beginning: TTimeT): Double; cdecl; external 'c' name 'difftime';
function mktime(tp: PTm): TTimeT; cdecl; external 'c' name 'mktime';
function localtime(timer: PTimeT): PTm; cdecl; external 'c' name 'localtime';
function gmtime(timer: PTimeT): PTm; cdecl; external 'c' name 'gmtime';
function asctime(tp: PTm): PAnsiChar; cdecl; external 'c' name 'asctime';
function ctime(timer: PTimeT): PAnsiChar; cdecl; external 'c' name 'ctime';
function strftime(s: PAnsiChar; maxsize: TSizeT; format: PAnsiChar; tp: PTm): TSizeT; cdecl; external 'c' name 'strftime';
function clock(): TClockT; cdecl; external 'c' name 'clock';
function nanosleep(req: PTimespec; rem: PTimespec): LongInt; cdecl; external 'c' name 'nanosleep';
function clock_gettime(clk_id: LongInt; tp: PTimespec): LongInt; cdecl; external 'c' name 'clock_gettime';
function clock_getres(clk_id: LongInt; res: PTimespec): LongInt; cdecl; external 'c' name 'clock_getres';
function clock_settime(clk_id: LongInt; tp: PTimespec): LongInt; cdecl; external 'c' name 'clock_settime';
function utimensat(dirfd: LongInt; pathname: PAnsiChar; times: PTimespec; flags: LongInt): LongInt; cdecl; external 'c' name 'utimensat';
function futimens(fd: LongInt; times: PTimespec): LongInt; cdecl; external 'c' name 'futimens';
function malloc(size: TSizeT): Pointer; cdecl; external 'c' name 'malloc';
function calloc(nmemb: TSizeT; size: TSizeT): Pointer; cdecl; external 'c' name 'calloc';
function realloc(ptr: Pointer; size: TSizeT): Pointer; cdecl; external 'c' name 'realloc';
procedure free(ptr: Pointer); cdecl; external 'c' name 'free';
procedure abort(); cdecl;
procedure exit_(status: LongInt); cdecl;
function atoi(nptr: PAnsiChar): LongInt; cdecl; external 'c' name 'atoi';
function atol(nptr: PAnsiChar): Int64; cdecl; external 'c' name 'atol';
function atoll(nptr: PAnsiChar): Int64; cdecl; external 'c' name 'atoll';
function strtod(nptr: PAnsiChar; endptr: PPAnsiChar): Double; cdecl; external 'c' name 'strtod';
function strtof(nptr: PAnsiChar; endptr: PPAnsiChar): Single; cdecl; external 'c' name 'strtof';
function atof(nptr: PAnsiChar): Double; cdecl; external 'c' name 'atof';
function strtol(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl; external 'c' name 'strtol';
function strtoul(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl; external 'c' name 'strtoul';
function strtoll(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): Int64; cdecl; external 'c' name 'strtoll';
function strtoull(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): QWord; cdecl; external 'c' name 'strtoull';
function abs(j: LongInt): LongInt; cdecl; external 'c' name 'abs';
function labs(j: Int64): Int64; cdecl; external 'c' name 'labs';
function rand(): LongInt; cdecl; external 'c' name 'rand';
procedure srand(seed: LongWord); cdecl; external 'c' name 'srand';
procedure qsort(base: Pointer; nmemb: TSizeT; size: TSizeT; compar: TRawProc9779B54A); cdecl; external 'c' name 'qsort';
function getenv(name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';
function _wgetenv(name: PWcharT): PWcharT; cdecl; external 'c' name '_wgetenv';
function wcslen(s: PWcharT): TSizeT; cdecl; external 'c' name 'wcslen';
function setenv(name: PAnsiChar; value: PAnsiChar; overwrite: LongInt): LongInt; cdecl; external 'c' name 'setenv';
function unsetenv(name: PAnsiChar): LongInt; cdecl; external 'c' name 'unsetenv';
function putenv(var &string: PAnsiChar): LongInt; cdecl; external 'c' name 'putenv';
function system_(command: PAnsiChar): LongInt; cdecl; external 'c' name 'system';
function atexit(var &function: TRawProcE21ED0E9): LongInt; cdecl; external 'c' name 'atexit';
function realpath(path: PAnsiChar; resolved_path: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'realpath';
function imaxabs(j: TIntmaxT): TIntmaxT; cdecl; external 'c' name 'imaxabs';
function strtoimax(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): TIntmaxT; cdecl; external 'c' name 'strtoimax';
function strtoumax(nptr: PAnsiChar; endptr: PPAnsiChar; base: LongInt): TUintmaxT; cdecl; external 'c' name 'strtoumax';

implementation
// Minimal Pascal shims for abort/exit – zero heap, inline not needed (rare path)
procedure abort(); cdecl;
begin
  System.RunError(217);
end;
procedure exit_(status: LongInt); cdecl;
begin
  System.Halt(status);
end;
// atoi/atol/atoll/rand/srand are implemented in shim_strconv/shim_rand units
// to keep this unit <800 lines (domain: C stdlib)
end.

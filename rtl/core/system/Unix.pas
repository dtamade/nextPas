unit Unix;

{**
 * @desc Minimal Unix facade for nextPas self-hosting.
 *
 * Provides the POSIX C library surface needed by nextpas.core modules
 * (currently only fpSysConf for simd.cpuinfo). This is the nextPas
 * equivalent of FPC's Unix unit — a thin binding over libc.
 *
 * Extend this file as more FPC Unix surface is needed for self-hosting.
 *}

{$mode objfpc}{$H+}

interface

type
  { C-compatible types for POSIX calls }
  cint = LongInt;
  clong = NativeInt;

{**
 * @desc POSIX sysconf(3) — query system configuration values.
 * @params AName  configuration constant (e.g. _SC_NPROCESSORS_ONLN)
 * @return  the configuration value, or -1 on error
 *}
function fpSysConf(AName: cint): clong; cdecl;

const
  { Common sysconf constants }
  _SC_NPROCESSORS_ONLN = 84;
  _SC_NPROCESSORS_CONF = 83;
  _SC_PAGESIZE = 30;
  _SC_OPEN_MAX = 4;
  _SC_CLK_TCK = 2;

implementation

function fpSysConf(AName: cint): clong; cdecl; external 'c' name 'sysconf';

end.

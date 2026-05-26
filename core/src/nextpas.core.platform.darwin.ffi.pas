unit nextpas.core.platform.darwin.ffi;

{$I nextpas.core.settings.inc}

interface

type
  mach_timebase_info_data_t = record
    numer: UInt32;
    denom: UInt32;
  end;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(out info: mach_timebase_info_data_t): Int32; cdecl; external 'c' name 'mach_timebase_info';

implementation

end.

unit nextpas.core.math.ffi;

{$I nextpas.core.settings.inc}

interface

{**
 * C libm 数学函数绑定
 * 跨平台：Linux/macOS/Windows 都有 libm（或 msvcrt）
 *}

function platform_sin(AX: Double): Double; cdecl; external 'm' name 'sin';
function platform_cos(AX: Double): Double; cdecl; external 'm' name 'cos';
function platform_tan(AX: Double): Double; cdecl; external 'm' name 'tan';
function platform_asin(AX: Double): Double; cdecl; external 'm' name 'asin';
function platform_acos(AX: Double): Double; cdecl; external 'm' name 'acos';
function platform_atan(AX: Double): Double; cdecl; external 'm' name 'atan';
function platform_atan2(AY, AX: Double): Double; cdecl; external 'm' name 'atan2';
function platform_exp(AX: Double): Double; cdecl; external 'm' name 'exp';
function platform_log(AX: Double): Double; cdecl; external 'm' name 'log';
function platform_log2(AX: Double): Double; cdecl; external 'm' name 'log2';
function platform_log10(AX: Double): Double; cdecl; external 'm' name 'log10';
function platform_pow(ABase, AExp: Double): Double; cdecl; external 'm' name 'pow';
function platform_sqrt(AX: Double): Double; cdecl; external 'm' name 'sqrt';
function platform_floor(AX: Double): Double; cdecl; external 'm' name 'floor';
function platform_ceil(AX: Double): Double; cdecl; external 'm' name 'ceil';
function platform_fabs(AX: Double): Double; cdecl; external 'm' name 'fabs';
function platform_fmod(AX, AY: Double): Double; cdecl; external 'm' name 'fmod';
function platform_round(AX: Double): Double; cdecl; external 'm' name 'round';

{ Single precision }
function platform_sinf(AX: Single): Single; cdecl; external 'm' name 'sinf';
function platform_cosf(AX: Single): Single; cdecl; external 'm' name 'cosf';
function platform_sqrtf(AX: Single): Single; cdecl; external 'm' name 'sqrtf';
function platform_atan2f(AY, AX: Single): Single; cdecl; external 'm' name 'atan2f';
function platform_powf(ABase, AExp: Single): Single; cdecl; external 'm' name 'powf';
function platform_floorf(AX: Single): Single; cdecl; external 'm' name 'floorf';
function platform_ceilf(AX: Single): Single; cdecl; external 'm' name 'ceilf';
function platform_fabsf(AX: Single): Single; cdecl; external 'm' name 'fabsf';

implementation

end.

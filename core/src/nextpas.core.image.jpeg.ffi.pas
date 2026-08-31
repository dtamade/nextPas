{**
 * nextpas.core.image.jpeg.ffi - libjpeg ABI 声明（FFI seam）
 * 仅含类型与符号名，不含逻辑；由 loader 经 platform.dl 动态解析。
 * 纯 Pascal 后端不依赖此单元。
 *}
unit nextpas.core.image.jpeg.ffi;

{$I nextpas.core.settings.inc}

interface

const
  LIBJPEG_SO_NAMES: array[0..3] of AnsiString = (
    'libjpeg.so.8',
    'libjpeg.so',
    'libjpeg-turbo.so',
    'libturbojpeg.so.0'
  );
  LIBJPEG_PROBE_SYMBOL = 'jpeg_std_error';

type
  PJpegErrorMgr = Pointer;
  TJpegStdErrorFunc = function(ErrMgr: PJpegErrorMgr): PJpegErrorMgr; cdecl;

implementation

end.

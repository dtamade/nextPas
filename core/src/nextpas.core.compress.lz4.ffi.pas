unit nextpas.core.compress.lz4.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function LZ4_compressBound(AInputSize: Int32): Int32; cdecl; external 'lz4';
function LZ4_compress_default(const ASrc: Pointer; ADst: Pointer;
  ASrcSize: Int32; ADstCapacity: Int32): Int32; cdecl; external 'lz4';
function LZ4_decompress_safe(const ASrc: Pointer; ADst: Pointer;
  ACompressedSize: Int32; ADstCapacity: Int32): Int32; cdecl; external 'lz4';

implementation

end.

unit nextpas.core.compress.zlib.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  zlib;

{ This unit re-exports the FPC paszlib API.
  When NEXTPAS_USE_ZLIB_NATIVE is defined, the linker resolves
  against the system libz.so instead of the Pascal implementation.
  The paszlib unit already uses cdecl external 'z' when linking
  against the native library, so this unit simply documents the
  compile-time switch and provides a verification entry point. }

type
  z_stream = zlib.z_stream;
  z_streamp = zlib.z_streamp;
  pBytef = zlib.pBytef;
  ULong = zlib.ULong;

const
  Z_OK = zlib.Z_OK;
  Z_STREAM_END = zlib.Z_STREAM_END;
  Z_NEED_DICT = zlib.Z_NEED_DICT;
  Z_ERRNO = zlib.Z_ERRNO;
  Z_STREAM_ERROR = zlib.Z_STREAM_ERROR;
  Z_DATA_ERROR = zlib.Z_DATA_ERROR;
  Z_MEM_ERROR = zlib.Z_MEM_ERROR;
  Z_BUF_ERROR = zlib.Z_BUF_ERROR;
  Z_VERSION_ERROR = zlib.Z_VERSION_ERROR;
  Z_NO_FLUSH = zlib.Z_NO_FLUSH;
  Z_PARTIAL_FLUSH = zlib.Z_PARTIAL_FLUSH;
  Z_SYNC_FLUSH = zlib.Z_SYNC_FLUSH;
  Z_FULL_FLUSH = zlib.Z_FULL_FLUSH;
  Z_FINISH = zlib.Z_FINISH;
  Z_BLOCK = zlib.Z_BLOCK;
  Z_DEFLATED = zlib.Z_DEFLATED;
  Z_NO_COMPRESSION = zlib.Z_NO_COMPRESSION;
  Z_BEST_SPEED = zlib.Z_BEST_SPEED;
  Z_BEST_COMPRESSION = zlib.Z_BEST_COMPRESSION;
  Z_DEFAULT_COMPRESSION = zlib.Z_DEFAULT_COMPRESSION;
  Z_DEFAULT_STRATEGY = zlib.Z_DEFAULT_STRATEGY;
  Z_MAX_WBITS = 15;

function NativeZlibVersion: PAnsiChar;
function deflateInit(var strm: z_stream; level: Integer): Integer;
function deflateInit2(var strm: z_stream; level, method, windowBits, memLevel, strategy: Integer): Integer;
function deflate(var strm: z_stream; flush: Integer): Integer;
function deflateEnd(var strm: z_stream): Integer;
function inflateInit(var strm: z_stream): Integer;
function inflateInit2(var strm: z_stream; windowBits: Integer): Integer;
function inflate(var strm: z_stream; flush: Integer): Integer;
function inflateEnd(var strm: z_stream): Integer;
function zlibVersion: PChar;

implementation

function NativeZlibVersion: PAnsiChar;
begin
  Result := zlib.zlibVersion;
end;

function deflateInit(var strm: z_stream; level: Integer): Integer;
begin
  Result := zlib.deflateInit(strm, level);
end;

function deflateInit2(var strm: z_stream; level, method, windowBits, memLevel, strategy: Integer): Integer;
begin
  Result := zlib.deflateInit2(strm, level, method, windowBits, memLevel, strategy);
end;

function deflate(var strm: z_stream; flush: Integer): Integer;
begin
  Result := zlib.deflate(strm, flush);
end;

function deflateEnd(var strm: z_stream): Integer;
begin
  Result := zlib.deflateEnd(strm);
end;

function inflateInit(var strm: z_stream): Integer;
begin
  Result := zlib.inflateInit(strm);
end;

function inflateInit2(var strm: z_stream; windowBits: Integer): Integer;
begin
  Result := zlib.inflateInit2(strm, windowBits);
end;

function inflate(var strm: z_stream; flush: Integer): Integer;
begin
  Result := zlib.inflate(strm, flush);
end;

function inflateEnd(var strm: z_stream): Integer;
begin
  Result := zlib.inflateEnd(strm);
end;

function zlibVersion: PChar;
begin
  Result := PChar(NativeZlibVersion);
end;

end.

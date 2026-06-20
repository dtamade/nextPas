unit zlib;

{$mode objfpc}{$H+}

interface

const
  Z_OK = 0;
  Z_STREAM_END = 1;
  Z_NEED_DICT = 2;
  Z_ERRNO = -1;
  Z_STREAM_ERROR = -2;
  Z_DATA_ERROR = -3;
  Z_MEM_ERROR = -4;
  Z_BUF_ERROR = -5;
  Z_VERSION_ERROR = -6;
  Z_NO_FLUSH = 0;
  Z_PARTIAL_FLUSH = 1;
  Z_SYNC_FLUSH = 2;
  Z_FULL_FLUSH = 3;
  Z_FINISH = 4;
  Z_BLOCK = 5;
  Z_DEFLATED = 8;
  Z_DEFAULT_COMPRESSION = -1;
  Z_DEFAULT_STRATEGY = 0;
  Z_MAX_WBITS = 15;
  Z_OK_OR_Z_STREAM_END: set of Byte = [Z_OK, Z_STREAM_END];

type
  alloc_func = function(opaque: Pointer; items, size: Cardinal): Pointer; cdecl;
  free_func = procedure(opaque, address: Pointer); cdecl;

  z_stream = record
    next_in: PByte;
    avail_in: Cardinal;
    total_in: Cardinal;
    next_out: PByte;
    avail_out: Cardinal;
    total_out: Cardinal;
    msg: PByte;
    state: Pointer;
    zalloc: alloc_func;
    zfree: free_func;
    opaque: Pointer;
    data_type: Integer;
    adler: Cardinal;
    reserved: Cardinal;
  end;
  z_streamp = ^z_stream;

function deflateInit_(strm: z_streamp; level: Integer; version: PChar; stream_size: Integer): Integer; cdecl;
function deflate(strm: z_streamp; flush: Integer): Integer; cdecl;
function deflateEnd(strm: z_streamp): Integer; cdecl;
function inflateInit_(strm: z_streamp; version: PChar; stream_size: Integer): Integer; cdecl;
function inflate(strm: z_streamp; flush: Integer): Integer; cdecl;
function inflateEnd(strm: z_streamp): Integer; cdecl;
function zlibVersion: PChar; cdecl;

function deflateInit(var strm: z_stream; level: Integer): Integer;
function inflateInit(var strm: z_stream): Integer;

implementation

function deflateInit_(strm: z_streamp; level: Integer; version: PChar; stream_size: Integer): Integer; cdecl; begin Result := Z_VERSION_ERROR; end;
function deflate(strm: z_streamp; flush: Integer): Integer; cdecl; begin Result := Z_STREAM_ERROR; end;
function deflateEnd(strm: z_streamp): Integer; cdecl; begin Result := Z_STREAM_ERROR; end;
function inflateInit_(strm: z_streamp; version: PChar; stream_size: Integer): Integer; cdecl; begin Result := Z_VERSION_ERROR; end;
function inflate(strm: z_streamp; flush: Integer): Integer; cdecl; begin Result := Z_STREAM_ERROR; end;
function inflateEnd(strm: z_streamp): Integer; cdecl; begin Result := Z_STREAM_ERROR; end;
function zlibVersion: PChar; cdecl; begin Result := '1.0.0'; end;

function deflateInit(var strm: z_stream; level: Integer): Integer;
begin
  Result := deflateInit_(@strm, level, zlibVersion, SizeOf(z_stream));
end;

function inflateInit(var strm: z_stream): Integer;
begin
  Result := inflateInit_(@strm, zlibVersion, SizeOf(z_stream));
end;

end.

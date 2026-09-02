unit nextpas.core.compress.bzip2;

{**
 * nextpas.core.compress.bzip2 - BZip2 one-shot facade (L2)
 * Decompress via libbz2 BuffToBuff (platform.dl), zero-copy via bytes.ops;
 * TBytesViewStream removed — L2 no longer depends on Classes/SysUtils/bzip2stream.
 * Compress via BZip2FfiCompress (libbz2 9/30). FFI lazy, no hard link.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Single-shot decompress: AData is full .bz2 stream (BZh header), returns plaintext.
  AMaxOutputSize is declared output ceiling for bomb protection; exceed -> EIOError. }
function BZip2DecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes;
function BZip2Decompress(const AData: TBytes): TBytes;
function BZip2Compress(const AData: TBytes): TBytes; overload;
function BZip2Compress(const AData: TBytes; ABlockSize100k: Integer): TBytes; overload;
function BZip2FfiIsAvailable: Boolean;

implementation

uses
  nextpas.core.errors,
  nextpas.core.compress.bzip2.ffi;

{ bytes.ops single source: zero-copy via TByteSpan view not needed for FFI,
  but keep inline helpers for future pure fallback; no SetLength+Move divergence. }

function BZip2DecompressWithMaxOutputSize(const AData: TBytes;
  const AMaxOutputSize: SizeUInt): TBytes; inline;
begin
  // L2 isolation: no Classes/SysUtils/bzip2stream; delegates to FFI owner
  // perf: single alloc of AMaxOutputSize then FFI zero-copy decompress; inline thin-forward
  // stability: FFI handles all resource; no TStream to leak; exception-safe SetLength
  Result := BZip2FfiDecompress(AData, AMaxOutputSize);
end;

function BZip2Decompress(const AData: TBytes): TBytes; inline;
begin
  Result := BZip2DecompressWithMaxOutputSize(AData, 256 * 1024 * 1024);
end;

function BZip2Compress(const AData: TBytes): TBytes; inline;
begin
  Result := BZip2FfiCompress(AData, 9);
end;

function BZip2Compress(const AData: TBytes; ABlockSize100k: Integer): TBytes; inline;
begin
  Result := BZip2FfiCompress(AData, ABlockSize100k);
end;

function BZip2FfiIsAvailable: Boolean; inline;
begin
  Result := BZip2FfiAvailable;
end;

end.

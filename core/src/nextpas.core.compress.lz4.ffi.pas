unit nextpas.core.compress.lz4.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function NativeLz4Compress(const AData: TBytes): TBytes;
function NativeLz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
function NativeLz4CompressBound(const AInputSize: Int32): Int32;

implementation

uses
  nextpas.core.errors
  {$IFNDEF NEXTPAS_USE_LZ4_NATIVE}
  , nextpas.core.compress.lz4
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_USE_LZ4_NATIVE}

function LZ4_compressBound(AInputSize: Int32): Int32; cdecl; external 'lz4';
function LZ4_compress_default(const ASrc: Pointer; ADst: Pointer;
  ASrcSize: Int32; ADstCapacity: Int32): Int32; cdecl; external 'lz4';
function LZ4_decompress_safe(const ASrc: Pointer; ADst: Pointer;
  ACompressedSize: Int32; ADstCapacity: Int32): Int32; cdecl; external 'lz4';

function NativeLz4CompressBound(const AInputSize: Int32): Int32;
begin
  Result := LZ4_compressBound(AInputSize);
end;

function NativeLz4Compress(const AData: TBytes): TBytes;
var
  LBound, LCompressed: Int32;
begin
  if Length(AData) = 0 then
  begin
    Result := nil;
    Exit;
  end;
  LBound := LZ4_compressBound(Length(AData));
  SetLength(Result, LBound);
  LCompressed := LZ4_compress_default(@AData[0], @Result[0], Length(AData), LBound);
  if LCompressed <= 0 then
    raise EIOError.Create('lz4 native: compress failed');
  SetLength(Result, LCompressed);
end;

function NativeLz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
var
  LDecompressed: Int32;
begin
  if (Length(AData) = 0) or (AOriginalSize <= 0) then
  begin
    Result := nil;
    Exit;
  end;
  SetLength(Result, AOriginalSize);
  LDecompressed := LZ4_decompress_safe(@AData[0], @Result[0], Length(AData), AOriginalSize);
  if LDecompressed < 0 then
    raise EIOError.Create('lz4 native: decompress failed');
  if LDecompressed <> AOriginalSize then
    raise EIOError.Create('lz4 native: size mismatch');
end;

{$ELSE}

function NativeLz4CompressBound(const AInputSize: Int32): Int32;
begin
  Result := Int32(nextpas.core.compress.lz4.Lz4CompressBound(AInputSize));
end;

function NativeLz4Compress(const AData: TBytes): TBytes;
begin
  Result := nextpas.core.compress.lz4.Lz4Compress(AData);
end;

function NativeLz4Decompress(const AData: TBytes; const AOriginalSize: Int32): TBytes;
begin
  Result := nextpas.core.compress.lz4.Lz4Decompress(AData, AOriginalSize);
end;

{$ENDIF}

end.

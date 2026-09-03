unit nextpas.core.compress.bzip2.ffi;

{**
 * nextpas.core.compress.bzip2.ffi - libbz2 dynamic binding (optional)
 *
 * Lazy loads libbz2.so(.1) via platform.dl; exposes BuffToBuffCompress.
 * Zero hard link; fallback to error when library unavailable.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

function BZip2FfiAvailable: Boolean;
function BZip2FfiCompress(const ASrc: TBytes): TBytes; overload;
function BZip2FfiCompress(const ASrc: TBytes; ABlockSize100k: Integer): TBytes; overload;
function BZip2FfiDecompressAvailable: Boolean;
function BZip2FfiDecompress(const ASrc: TBytes; const AMaxOutputSize: SizeUInt): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.dl;

type
  TBZBuffToBuffCompress = function(
    ADest: PByte; var ADestLen: Cardinal;
    ASrc: PByte; ASourceLen: Cardinal;
    ABlockSize100k: Integer; AVerbosity: Integer; AWorkFactor: Integer): Integer; cdecl;
  TBZBuffToBuffDecompress = function(
    ADest: PByte; var ADestLen: Cardinal;
    ASrc: PByte; ASourceLen: Cardinal;
    ASmall: Integer; AVerbosity: Integer): Integer; cdecl;

const
  BZ_OK = 0;
  BZ_OUTBUFF_FULL = -8;

var
  GOnceDone: Boolean = False;
  GLibLoaded: Boolean = False;
  GCompress: TBZBuffToBuffCompress = nil;
  GDecompress: TBZBuffToBuffDecompress = nil;

function LoadLib: Boolean;
var
  LNames: array[0..2] of PAnsiChar;
  LI: Integer;
  LLib: TPlatformLibrary;
  LSymComp: Pointer;
  LSymDecomp: Pointer;
begin
  Result := False;
  LNames[0] := 'libbz2.so.1';
  LNames[1] := 'libbz2.so';
  LNames[2] := 'libbz2.so.1.0';
  for LI := 0 to High(LNames) do
  begin
    if platform_dl_open(LNames[LI], PLATFORM_DL_LAZY, LLib) = 0 then
    begin
      LSymComp := nil;
      LSymDecomp := nil;
      LLib.Sym('BZ2_bzBuffToBuffCompress', LSymComp);
      LLib.Sym('BZ2_bzBuffToBuffDecompress', LSymDecomp);
      if Assigned(LSymComp) then
        GCompress := TBZBuffToBuffCompress(LSymComp);
      if Assigned(LSymDecomp) then
        GDecompress := TBZBuffToBuffDecompress(LSymDecomp);
      Result := Assigned(GCompress) or Assigned(GDecompress);
      Break;
    end;
  end;
end;

function BZip2FfiAvailable: Boolean;
begin
  if not GOnceDone then
  begin
    GLibLoaded := LoadLib;
    GOnceDone := True;
  end;
  Result := GLibLoaded and Assigned(GCompress);
end;

function BZip2FfiDecompressAvailable: Boolean; inline;
begin
  if not GOnceDone then
    BZip2FfiAvailable;
  Result := GLibLoaded and Assigned(GDecompress);
end;

function BZip2FfiCompress(const ASrc: TBytes): TBytes;
begin
  Result := BZip2FfiCompress(ASrc, 9);
end;

function BZip2FfiCompress(const ASrc: TBytes; ABlockSize100k: Integer): TBytes;
var
  LDestLen: Cardinal;
  LBound: Cardinal;
  LRet: Integer;
  LBlk: Integer;
begin
  Result := nil;
  if not BZip2FfiAvailable then
    raise ENotSupportedError.Create('libbz2 not available');
  if Length(ASrc) = 0 then
    Exit(nil);
  LBlk := ABlockSize100k;
  if (LBlk < 1) or (LBlk > 9) then
    LBlk := 9;
  LBound := Cardinal(Trunc(Length(ASrc) * 1.01)) + 600;
  if LBound < 64 then
    LBound := 64;
  SetLength(Result, LBound);
  LDestLen := LBound;
  LRet := GCompress(@Result[0], LDestLen, @ASrc[0], Cardinal(Length(ASrc)), LBlk, 0, 30);
  if LRet <> BZ_OK then
    raise EIOError.CreateFmt('bzip2 compress failed (code %d)', [LRet]);
  SetLength(Result, LDestLen);
end;

function BZip2FfiDecompress(const ASrc: TBytes; const AMaxOutputSize: SizeUInt): TBytes;
var
  LDestLen: Cardinal;
  LRet: Integer;
  LProbe: array[0..0] of Byte;
  LProbeLen: Cardinal;
begin
  Result := nil;
  if Length(ASrc) = 0 then
    raise EIOError.Create('bzip2: truncated stream');
  if not BZip2FfiDecompressAvailable then
    raise ENotSupportedError.Create('libbz2 not available');
  if AMaxOutputSize = 0 then
  begin
    // bomb probe: attempt 1-byte decompress; any output => exceeds limit
    LProbeLen := 1;
    LRet := GDecompress(@LProbe[0], LProbeLen, @ASrc[0], Cardinal(Length(ASrc)), 0, 0);
    if LRet = BZ_OK then
    begin
      if LProbeLen > 0 then
        raise EIOError.Create('bzip2: decompressed size exceeds limit');
      Exit(nil);
    end;
    if LRet = BZ_OUTBUFF_FULL then
      raise EIOError.Create('bzip2: decompressed size exceeds limit');
    raise EIOError.CreateFmt('bzip2 decompress failed (code %d)', [LRet]);
  end;
  if AMaxOutputSize > High(Cardinal) then
    raise EIOError.Create('bzip2: max output size exceeds limit');
  SetLength(Result, AMaxOutputSize);
  LDestLen := Cardinal(AMaxOutputSize);
  LRet := GDecompress(@Result[0], LDestLen, @ASrc[0], Cardinal(Length(ASrc)), 0, 0);
  if LRet = BZ_OUTBUFF_FULL then
    raise EIOError.Create('bzip2: decompressed size exceeds limit');
  if LRet <> BZ_OK then
    raise EIOError.CreateFmt('bzip2 decompress failed (code %d)', [LRet]);
  SetLength(Result, LDestLen);
end;

end.

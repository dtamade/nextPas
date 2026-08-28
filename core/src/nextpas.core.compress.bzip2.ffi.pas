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
function BZip2FfiCompress(const ASrc: TBytes): TBytes;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.dl;

type
  TBZBuffToBuffCompress = function(
    ADest: PByte; var ADestLen: Cardinal;
    ASrc: PByte; ASourceLen: Cardinal;
    ABlockSize100k: Integer; AVerbosity: Integer; AWorkFactor: Integer): Integer; cdecl;

const
  BZ_OK = 0;

var
  GOnceDone: Boolean = False;
  GLibLoaded: Boolean = False;
  GCompress: TBZBuffToBuffCompress = nil;

function LoadLib: Boolean;
var
  LNames: array[0..2] of PAnsiChar;
  LI: Integer;
  LLib: TPlatformLibrary;
  LSym: Pointer;
begin
  Result := False;
  LNames[0] := 'libbz2.so.1';
  LNames[1] := 'libbz2.so';
  LNames[2] := 'libbz2.so.1.0';
  for LI := 0 to High(LNames) do
  begin
    if platform_dl_open(LNames[LI], PLATFORM_DL_LAZY, LLib) = 0 then
    begin
      if LLib.Sym('BZ2_bzBuffToBuffCompress', LSym) = 0 then
      begin
        GCompress := TBZBuffToBuffCompress(LSym);
        Result := True;
      end;
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

function BZip2FfiCompress(const ASrc: TBytes): TBytes;
var
  LDestLen: Cardinal;
  LBound: Cardinal;
  LRet: Integer;
begin
  Result := nil;
  if not BZip2FfiAvailable then
    raise ENotSupportedError.Create('libbz2 not available');
  if Length(ASrc) = 0 then
    Exit(nil);
  LBound := Cardinal(Trunc(Length(ASrc) * 1.01)) + 600;
  if LBound < 64 then
    LBound := 64;
  SetLength(Result, LBound);
  LDestLen := LBound;
  LRet := GCompress(@Result[0], LDestLen, @ASrc[0], Cardinal(Length(ASrc)), 9, 0, 30);
  if LRet <> BZ_OK then
    raise EIOError.CreateFmt('bzip2 compress failed (code %d)', [LRet]);
  SetLength(Result, LDestLen);
end;

end.

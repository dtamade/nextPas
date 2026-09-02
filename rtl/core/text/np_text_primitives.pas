unit np_text_primitives;

{$mode objfpc}{$H+}
{$UNITPATH ../base}

interface

uses
  SysUtils, np_base_types, nextpas.core.exception, nextpas.core.fs.util;

function NormalizeCoreIdentity(const AValue: string): string;
function NormalizeCorePath(const APath: string): string;
function CorePathStartsWith(
  const APath: string;
  const APrefix: string
): Boolean;
function TryReadCoreTextFile(
  const APath: string;
  out ACanonicalPath: string;
  out ASourceText: string
): TCoreResult;

implementation

function NormalizeCoreIdentity(const AValue: string): string;
begin
  Result := LowerCase(Trim(AValue));
end;

function NormalizeCorePath(const APath: string): string;
begin
  Result := ExpandFileName(APath);
end;

function CorePathStartsWith(
  const APath: string;
  const APrefix: string
): Boolean;
var
  NormalizedPath: string;
  NormalizedPrefix: string;
begin
  NormalizedPath := IncludeTrailingPathDelimiter(NormalizeCorePath(APath));
  NormalizedPrefix := IncludeTrailingPathDelimiter(NormalizeCorePath(APrefix));
  Result := Pos(NormalizedPrefix, NormalizedPath) = 1;
end;

function TryReadCoreTextFile(
  const APath: string;
  out ACanonicalPath: string;
  out ASourceText: string
): TCoreResult;
var
  LSize: Int64;
begin
  ACanonicalPath := '';
  ASourceText := '';

  if Trim(APath) = '' then
    Exit(BuildCoreResult(crcInvalidArgument, 'path must not be empty'));

  ACanonicalPath := NormalizeCorePath(APath);
  if not FileExists(ACanonicalPath) then
    Exit(BuildCoreResult(crcNotFound, 'file not found: ' + ACanonicalPath));

  { Size pre-check: reuse FsFileSize (core.fs) with 64MiB bulk limit to avoid OOM
    on arbitrary large file. Aligns with FORMAT_BULK_PARSE_MAX_BYTES. }
  try
    LSize := FsFileSize(ACanonicalPath);
    if LSize > Int64(64) * 1024 * 1024 then
      Exit(BuildCoreResult(crcInvalidArgument,
        'file too large (' + IntToStr(LSize) + ' bytes, limit 67108864): ' + ACanonicalPath));
  except
    on E: ENotFoundError do
      Exit(BuildCoreResult(crcNotFound, 'file not found: ' + ACanonicalPath));
    on E: ENextPasError do
      Exit(BuildCoreResult(crcIoError, 'failed to stat file: ' + ACanonicalPath));
  end;

  { Read via nextpas.core.fs.util instead of FPC TFileStream so the compile
    chain stops consuming the Classes stub. FsReadFileText handles BOM /
    UTF-8 / UTF-16 and falls back to Latin-1 for non-UTF-8 (net improvement
    over the old raw byte conversion). Catch on the concrete core exception
    types: under FPC, ENextPasError derives from SysUtils.Exception; under
    nextPas, the SysUtils stub Exception is an unrelated class(TObject), so
    `on Exception` would not match here. }
  try
    ASourceText := FsReadFileText(ACanonicalPath);
  except
    on E: ENotFoundError do
      Exit(BuildCoreResult(crcNotFound, 'file not found: ' + ACanonicalPath));
    on E: ENextPasError do
      Exit(BuildCoreResult(crcIoError, 'failed to read file: ' + ACanonicalPath));
  end;

  { Avoid bare zero-arg `BuildCoreOkResult` — stage0 residual-calls it as
    @BuildCoreOkResult() without body/sret. Materialize TCoreResult fields. }
  Result.Code := crcOk;
  Result.Detail := '';
end;

end.

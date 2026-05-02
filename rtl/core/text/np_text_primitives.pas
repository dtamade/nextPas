unit np_text_primitives;

{$mode objfpc}{$H+}
{$UNITPATH ../base}

interface

uses
  Classes, SysUtils, np_base_types;

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
  Stream: TFileStream;
  Buffer: RawByteString;
begin
  ACanonicalPath := '';
  ASourceText := '';

  if Trim(APath) = '' then
    Exit(BuildCoreResult(crcInvalidArgument, 'path must not be empty'));

  ACanonicalPath := NormalizeCorePath(APath);
  if not FileExists(ACanonicalPath) then
    Exit(BuildCoreResult(crcNotFound, 'file not found: ' + ACanonicalPath));

  try
    Stream := TFileStream.Create(ACanonicalPath, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Buffer, Stream.Size);
      if Stream.Size > 0 then
        Stream.ReadBuffer(Buffer[1], Stream.Size);
    finally
      Stream.Free;
    end;
  except
    on Exception do
      Exit(BuildCoreResult(crcIoError, 'failed to read file: ' + ACanonicalPath));
  end;

  ASourceText := string(Buffer);
  Result := BuildCoreOkResult;
end;

end.

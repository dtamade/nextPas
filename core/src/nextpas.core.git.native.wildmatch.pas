unit nextpas.core.git.native.wildmatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Single-source wildmatch for gitignore / gitattributes — thin wrapper over L1 text owner.

  Owner has moved to `nextpas.core.text.wildmatch` (L1) for cross-module reuse
  (fs / http / tui) via bytes.ops single source. This unit remains as a
  compatibility shim: all symbols inline-forward to the text owner, zero SysUtils,
  zero libgit2, inline hot path, zero-copy range scan. }

function GitWildSegment(const APattern, AName: string): Boolean; inline;
function GitWildSegmentRange(const APattern: string; APatPos, APatLen: Integer;
  const AName: string; ANamePos, ANameLen: Integer): Boolean; inline;
function GitSegmentsMatch(const APattern, APath: string): Boolean; inline;
function GitHasUnescapedSlash(const AValue: string): Boolean; inline;

implementation

uses
  nextpas.core.text.wildmatch;

function GitWildSegment(const APattern, AName: string): Boolean; inline;
begin
  Result := WildSegment(APattern, AName);
end;

function GitWildSegmentRange(const APattern: string; APatPos, APatLen: Integer;
  const AName: string; ANamePos, ANameLen: Integer): Boolean; inline;
begin
  Result := WildSegmentRange(APattern, APatPos, APatLen, AName, ANamePos, ANameLen);
end;

function GitSegmentsMatch(const APattern, APath: string): Boolean; inline;
begin
  Result := WildSegmentsMatch(APattern, APath);
end;

function GitHasUnescapedSlash(const AValue: string): Boolean; inline;
begin
  Result := HasUnescapedSlash(AValue);
end;

end.

unit nextpas.core.git.native.wildmatch;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base;

{ Deprecated thin shim — owner has moved to `nextpas.core.text.wildmatch` (L1).

  Single-source wildmatch for gitignore / gitattributes — now owned by L1
  `nextpas.core.text.wildmatch` for cross-module reuse (fs / http / tui)
  via `nextpas.core.bytes.ops` single source (GrowArrayCapacity, inline hot
  path, zero-copy range scan, no alloc). This unit is a residual delegation
  layer kept only for BC; new code must `uses nextpas.core.text.wildmatch`
  directly. Zero SysUtils, zero libgit2, inline forwarding, zero-copy views. }

function GitWildSegment(const APattern, AName: string): Boolean; inline; deprecated 'Use nextpas.core.text.wildmatch.WildSegment (L1 owner, inline/zero-copy, bytes.ops single source)';
function GitWildSegmentRange(const APattern: string; APatPos, APatLen: Integer;
  const AName: string; ANamePos, ANameLen: Integer): Boolean; inline; deprecated 'Use nextpas.core.text.wildmatch.WildSegmentRange';
function GitSegmentsMatch(const APattern, APath: string): Boolean; inline; deprecated 'Use nextpas.core.text.wildmatch.WildSegmentsMatch';
function GitHasUnescapedSlash(const AValue: string): Boolean; inline; deprecated 'Use nextpas.core.text.wildmatch.HasUnescapedSlash';

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

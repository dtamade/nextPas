unit nextpas.core.git.native.lsfiles;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.index;

{ Ls-files subfamily: index listing à la `git ls-files`.
  Cached (default), stage, and with -z handling via raw list. }

type
  TGitLsFilesOptions = record
    WithStage: Boolean; // --stage: mode oid stage<TAB>path
    WithCached: Boolean; // --cached (default true, kept for API symmetry)
  end;

function DefaultGitLsFilesOptions: TGitLsFilesOptions;

function GitLsFiles(const AGitDir: string): TStringArray; overload;
function GitLsFiles(const AGitDir: string; const AOptions: TGitLsFilesOptions): TStringArray; overload;
function GitLsFilesDetailed(const AGitDir: string): TGitIndexEntryArray;
function GitLsFilesStage(const AGitDir: string): TStringArray;

implementation

uses
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.git.native.write;

function DefaultGitLsFilesOptions: TGitLsFilesOptions;
begin
  Result.WithStage := False;
  Result.WithCached := True;
end;

function GitLsFilesInternal(const AGitDir: string; const AOptions: TGitLsFilesOptions): TStringArray;
var
  Idx: TGitIndexFile;
  I: Integer;
  Line: string;
begin
  Result := nil;
  if AGitDir = '' then raise EGitError.Create('ls-files: gitdir empty');
  Idx := GitReadIndex(AGitDir);
  SetLength(Result, Length(Idx.Entries));
  for I := 0 to High(Idx.Entries) do
  begin
    if AOptions.WithStage then
    begin
      Line := GitModeToString(Idx.Entries[I].Mode) + ' ' + GitOidToHex(Idx.Entries[I].Oid) + ' ' + IntToStr(Idx.Entries[I].Stage) + #9 + Idx.Entries[I].Path;
      Result[I] := Line;
    end
    else
      Result[I] := Idx.Entries[I].Path;
  end;
end;

function GitLsFiles(const AGitDir: string): TStringArray;
var Opts: TGitLsFilesOptions;
begin
  Opts := DefaultGitLsFilesOptions;
  Result := GitLsFilesInternal(AGitDir, Opts);
end;

function GitLsFiles(const AGitDir: string; const AOptions: TGitLsFilesOptions): TStringArray;
begin
  Result := GitLsFilesInternal(AGitDir, AOptions);
end;

function GitLsFilesDetailed(const AGitDir: string): TGitIndexEntryArray;
var Idx: TGitIndexFile;
begin
  if AGitDir = '' then raise EGitError.Create('ls-files: gitdir empty');
  Idx := GitReadIndex(AGitDir);
  Result := Copy(Idx.Entries, 0, Length(Idx.Entries));
end;

function GitLsFilesStage(const AGitDir: string): TStringArray;
var Opts: TGitLsFilesOptions;
begin
  Opts := DefaultGitLsFilesOptions;
  Opts.WithStage := True;
  Result := GitLsFilesInternal(AGitDir, Opts);
end;

end.

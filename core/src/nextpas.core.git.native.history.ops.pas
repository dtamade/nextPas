unit nextpas.core.git.native.history.ops;

{$I nextpas.core.settings.inc}

{**
 * @desc History shard — ops domain (shortlog/catfile/cherrypick/revert)
 * Invariant: shortlog grouping + catfile pretty + cherrypick/revert via
 *   parent-diff flat apply + checkout materialize. No revwalk/diff parsing
 *   beyond owner delegation.
 * Fan-in: 4 owner units — shortlog/catfile/cherrypick/revert.
 * Perf: all forwards `inline`; zero-copy via bytes.ops single source
 *   (TByteSpan, PByte+Len, TGitOid 20B Move).
 * Stability: ownership in owners (checkout try..finally index); facade zero
 *   alloc/zero leak, TBytes refcounted.
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.shortlog,
  nextpas.core.git.native.catfile,
  nextpas.core.git.native.cherrypick,
  nextpas.core.git.native.revert;

type
  TGitShortlogEntry = nextpas.core.git.native.shortlog.TGitShortlogEntry;
  TGitShortlogArray = nextpas.core.git.native.shortlog.TGitShortlogArray;
  TGitCatFile = nextpas.core.git.native.catfile.TGitCatFile;
  TGitOid = nextpas.core.git.native.base.TGitOid;

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray; overload; inline;
function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray; overload; inline;
function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string; overload; inline;
function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string; overload; inline;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile; overload; inline;
function GitCatFile(const AGitDir, ARev: string): TGitCatFile; overload; inline;
function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string; overload; inline;
function GitCatFileType(const AGitDir, ARev: string): string; overload; inline;
function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer; overload; inline;
function GitCatFileSize(const AGitDir, ARev: string): Integer; overload; inline;
function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string; overload; inline;
function GitCatFilePretty(const AGitDir, ARev: string): string; overload; inline;

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload; inline;
function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload; inline;

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; overload; inline;
function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; overload; inline;

implementation

function GitShortlog(const AGitDir, ARef: string; AMaxCount: Integer): TGitShortlogArray; inline;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlog(AGitDir, ARef, AMaxCount);
end;

function GitShortlog(const AGitDir: string; AMaxCount: Integer): TGitShortlogArray; inline;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlog(AGitDir, AMaxCount);
end;

function GitShortlogText(const AGitDir, ARef: string; AMaxCount: Integer): string; inline;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlogText(AGitDir, ARef, AMaxCount);
end;

function GitShortlogText(const AGitDir: string; AMaxCount: Integer): string; inline;
begin
  Result := nextpas.core.git.native.shortlog.GitShortlogText(AGitDir, AMaxCount);
end;

function GitCatFile(const AGitDir: string; const AOid: TGitOid): TGitCatFile; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFile(AGitDir, AOid);
end;

function GitCatFile(const AGitDir, ARev: string): TGitCatFile; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFile(AGitDir, ARev);
end;

function GitCatFileType(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileType(AGitDir, AOid);
end;

function GitCatFileType(const AGitDir, ARev: string): string; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileType(AGitDir, ARev);
end;

function GitCatFileSize(const AGitDir: string; const AOid: TGitOid): Integer; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileSize(AGitDir, AOid);
end;

function GitCatFileSize(const AGitDir, ARev: string): Integer; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFileSize(AGitDir, ARev);
end;

function GitCatFilePretty(const AGitDir: string; const AOid: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFilePretty(AGitDir, AOid);
end;

function GitCatFilePretty(const AGitDir, ARev: string): string; inline;
begin
  Result := nextpas.core.git.native.catfile.GitCatFilePretty(AGitDir, ARev);
end;

function GitCherryPick(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.cherrypick.GitCherryPick(AGitDir, AWorkTree, ATargetOid);
end;

function GitCherryPick(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.cherrypick.GitCherryPick(AGitDir, AWorkTree, ATargetRef);
end;

function GitRevert(const AGitDir, AWorkTree: string; const ATargetOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.revert.GitRevert(AGitDir, AWorkTree, ATargetOid);
end;

function GitRevert(const AGitDir, AWorkTree, ATargetRef: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.revert.GitRevert(AGitDir, AWorkTree, ATargetRef);
end;

end.

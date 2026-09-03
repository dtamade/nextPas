unit nextpas.core.git.native.branches;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.git.native.base,
  nextpas.core.git.native.stash,
  nextpas.core.git.native.notes,
  nextpas.core.git.native.branch,
  nextpas.core.git.native.tag;

type
  TGitOid = nextpas.core.git.native.base.TGitOid;
  TGitStashEntry = nextpas.core.git.native.stash.TGitStashEntry;
  TGitStashArray = nextpas.core.git.native.stash.TGitStashArray;
  TGitNoteEntry = nextpas.core.git.native.notes.TGitNoteEntry;
  TGitNoteArray = nextpas.core.git.native.notes.TGitNoteArray;
  TGitBranchEntry = nextpas.core.git.native.branch.TGitBranchEntry;
  TGitBranchArray = nextpas.core.git.native.branch.TGitBranchArray;
  TGitTagEntry = nextpas.core.git.native.tag.TGitTagEntry;
  TGitTagArray = nextpas.core.git.native.tag.TGitTagArray;

function GitStashExists(const AGitDir: string): Boolean; inline;
function GitStashCount(const AGitDir: string): Integer; inline;
function GitStashList(const AGitDir: string): TGitStashArray; inline;
function GitStashAt(const AGitDir: string; AIndex: Integer): TGitStashEntry; inline;
function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string;
  AIncludeUntracked: Boolean): TGitOid; overload; inline;
function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string): TGitOid; overload; inline;
function GitStashApply(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid; overload; inline;
function GitStashApply(const AGitDir, AWorkTree: string): TGitOid; overload; inline;
procedure GitStashDrop(const AGitDir: string; AIndex: Integer); overload; inline;
procedure GitStashDrop(const AGitDir: string); overload; inline;
function GitStashPop(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid; overload; inline;
function GitStashPop(const AGitDir, AWorkTree: string): TGitOid; overload; inline;
procedure GitStashClear(const AGitDir: string); inline;

function GitNotesRefExists(const AGitDir, ARefName: string): Boolean; overload; inline;
function GitNotesRefExists(const AGitDir: string): Boolean; overload; inline;
function GitNotesList(const AGitDir, ARefName: string): TGitNoteArray; overload; inline;
function GitNotesList(const AGitDir: string): TGitNoteArray; overload; inline;
function GitNotesGet(const AGitDir: string; const ATarget: TGitOid): TBytes; overload; inline;
function GitNotesGet(const AGitDir, ARefName: string; const ATarget: TGitOid): TBytes; overload; inline;
function GitNotesGetStr(const AGitDir: string; const ATarget: TGitOid): string; overload; inline;
function GitNotesGetStr(const AGitDir, ARefName: string; const ATarget: TGitOid): string; overload; inline;
function GitNotesExists(const AGitDir: string; const ATarget: TGitOid): Boolean; overload; inline;
function GitNotesExists(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; overload; inline;
function GitNotesAdd(const AGitDir: string; const ATarget: TGitOid; const ANote: string): TGitOid; overload; inline;
function GitNotesAdd(const AGitDir, ARefName: string; const ATarget: TGitOid; const ANote: string): TGitOid; overload; inline;
function GitNotesAddBytes(const AGitDir, ARefName: string; const ATarget: TGitOid; const AData: TBytes): TGitOid; inline;
function GitNotesRemove(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; overload; inline;
function GitNotesRemove(const AGitDir: string; const ATarget: TGitOid): Boolean; overload; inline;

function GitBranchList(const AGitDir: string): TGitBranchArray; inline;
function GitBranchExists(const AGitDir, ABranchName: string): Boolean; inline;
function GitBranchGetOid(const AGitDir, ABranchName: string): TGitOid; inline;
function GitBranchCurrent(const AGitDir: string): string; inline;
function GitBranchIsDetached(const AGitDir: string): Boolean; inline;
function GitBranchCreate(const AGitDir, ABranchName: string; const AOid: TGitOid): TGitOid; inline;
function GitBranchCreateFromRef(const AGitDir, ABranchName, ARefName: string): TGitOid; inline;
procedure GitBranchDelete(const AGitDir, ABranchName: string); inline;
function GitBranchRename(const AGitDir, AOldName, ANewName: string): TGitOid; inline;

function GitTagList(const AGitDir: string): TGitTagArray; inline;
function GitTagExists(const AGitDir, ATagName: string): Boolean; inline;
function GitTagGetOid(const AGitDir, ATagName: string): TGitOid; inline;
function GitTagGetPeeled(const AGitDir, ATagName: string): TGitOid; inline;
function GitTagCreateLightweight(const AGitDir, ATagName: string; const ATargetOid: TGitOid): TGitOid; inline;
function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage: string): TGitOid; overload; inline;
function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage, ATaggerName, ATaggerEmail: string): TGitOid; overload; inline;
procedure GitTagDelete(const AGitDir, ATagName: string); inline;
function GitTagRename(const AGitDir, AOldName, ANewName: string): TGitOid; inline;

implementation

function GitStashExists(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashExists(AGitDir);
end;

function GitStashCount(const AGitDir: string): Integer; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashCount(AGitDir);
end;

function GitStashList(const AGitDir: string): TGitStashArray; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashList(AGitDir);
end;

function GitStashAt(const AGitDir: string; AIndex: Integer): TGitStashEntry; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashAt(AGitDir, AIndex);
end;

function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string;
  AIncludeUntracked: Boolean): TGitOid; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashPush(AGitDir, AWorkTree, AMessage, AIncludeUntracked);
end;

function GitStashPush(const AGitDir, AWorkTree: string; const AMessage: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashPush(AGitDir, AWorkTree, AMessage);
end;

function GitStashApply(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashApply(AGitDir, AWorkTree, AIndex);
end;

function GitStashApply(const AGitDir, AWorkTree: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashApply(AGitDir, AWorkTree);
end;

procedure GitStashDrop(const AGitDir: string; AIndex: Integer); inline;
begin
  nextpas.core.git.native.stash.GitStashDrop(AGitDir, AIndex);
end;

procedure GitStashDrop(const AGitDir: string); inline;
begin
  nextpas.core.git.native.stash.GitStashDrop(AGitDir);
end;

function GitStashPop(const AGitDir, AWorkTree: string; AIndex: Integer): TGitOid; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashPop(AGitDir, AWorkTree, AIndex);
end;

function GitStashPop(const AGitDir, AWorkTree: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.stash.GitStashPop(AGitDir, AWorkTree);
end;

procedure GitStashClear(const AGitDir: string); inline;
begin
  nextpas.core.git.native.stash.GitStashClear(AGitDir);
end;

function GitNotesRefExists(const AGitDir, ARefName: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesRefExists(AGitDir, ARefName);
end;

function GitNotesRefExists(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesRefExists(AGitDir);
end;

function GitNotesList(const AGitDir, ARefName: string): TGitNoteArray; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesList(AGitDir, ARefName);
end;

function GitNotesList(const AGitDir: string): TGitNoteArray; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesList(AGitDir);
end;

function GitNotesGet(const AGitDir: string; const ATarget: TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesGet(AGitDir, ATarget);
end;

function GitNotesGet(const AGitDir, ARefName: string; const ATarget: TGitOid): TBytes; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesGet(AGitDir, ARefName, ATarget);
end;

function GitNotesGetStr(const AGitDir: string; const ATarget: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesGetStr(AGitDir, ATarget);
end;

function GitNotesGetStr(const AGitDir, ARefName: string; const ATarget: TGitOid): string; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesGetStr(AGitDir, ARefName, ATarget);
end;

function GitNotesExists(const AGitDir: string; const ATarget: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesExists(AGitDir, ATarget);
end;

function GitNotesExists(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesExists(AGitDir, ARefName, ATarget);
end;

function GitNotesAdd(const AGitDir: string; const ATarget: TGitOid; const ANote: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesAdd(AGitDir, ATarget, ANote);
end;

function GitNotesAdd(const AGitDir, ARefName: string; const ATarget: TGitOid; const ANote: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesAdd(AGitDir, ARefName, ATarget, ANote);
end;

function GitNotesAddBytes(const AGitDir, ARefName: string; const ATarget: TGitOid; const AData: TBytes): TGitOid; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesAddBytes(AGitDir, ARefName, ATarget, AData);
end;

function GitNotesRemove(const AGitDir, ARefName: string; const ATarget: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesRemove(AGitDir, ARefName, ATarget);
end;

function GitNotesRemove(const AGitDir: string; const ATarget: TGitOid): Boolean; inline;
begin
  Result := nextpas.core.git.native.notes.GitNotesRemove(AGitDir, ATarget);
end;

function GitBranchList(const AGitDir: string): TGitBranchArray; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchList(AGitDir);
end;

function GitBranchExists(const AGitDir, ABranchName: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchExists(AGitDir, ABranchName);
end;

function GitBranchGetOid(const AGitDir, ABranchName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchGetOid(AGitDir, ABranchName);
end;

function GitBranchCurrent(const AGitDir: string): string; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchCurrent(AGitDir);
end;

function GitBranchIsDetached(const AGitDir: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchIsDetached(AGitDir);
end;

function GitBranchCreate(const AGitDir, ABranchName: string; const AOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchCreate(AGitDir, ABranchName, AOid);
end;

function GitBranchCreateFromRef(const AGitDir, ABranchName, ARefName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchCreateFromRef(AGitDir, ABranchName, ARefName);
end;

procedure GitBranchDelete(const AGitDir, ABranchName: string); inline;
begin
  nextpas.core.git.native.branch.GitBranchDelete(AGitDir, ABranchName);
end;

function GitBranchRename(const AGitDir, AOldName, ANewName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.branch.GitBranchRename(AGitDir, AOldName, ANewName);
end;

function GitTagList(const AGitDir: string): TGitTagArray; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagList(AGitDir);
end;

function GitTagExists(const AGitDir, ATagName: string): Boolean; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagExists(AGitDir, ATagName);
end;

function GitTagGetOid(const AGitDir, ATagName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagGetOid(AGitDir, ATagName);
end;

function GitTagGetPeeled(const AGitDir, ATagName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagGetPeeled(AGitDir, ATagName);
end;

function GitTagCreateLightweight(const AGitDir, ATagName: string; const ATargetOid: TGitOid): TGitOid; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagCreateLightweight(AGitDir, ATagName, ATargetOid);
end;

function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagCreateAnnotated(AGitDir, ATagName, ATargetOid, AMessage);
end;

function GitTagCreateAnnotated(const AGitDir, ATagName: string; const ATargetOid: TGitOid; const AMessage, ATaggerName, ATaggerEmail: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagCreateAnnotated(AGitDir, ATagName, ATargetOid, AMessage, ATaggerName, ATaggerEmail);
end;

procedure GitTagDelete(const AGitDir, ATagName: string); inline;
begin
  nextpas.core.git.native.tag.GitTagDelete(AGitDir, ATagName);
end;

function GitTagRename(const AGitDir, AOldName, ANewName: string): TGitOid; inline;
begin
  Result := nextpas.core.git.native.tag.GitTagRename(AGitDir, AOldName, ANewName);
end;

end.

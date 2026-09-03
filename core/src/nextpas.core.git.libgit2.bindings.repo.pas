unit nextpas.core.git.libgit2.bindings.repo;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

function git_repository_open(var &out: PPGitRepository; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_open';
function git_repository_open_from_worktree(var &out: PPGitRepository; wt: PGitWorktree): LongInt; cdecl; external 'c' name 'git_repository_open_from_worktree';
function git_repository_wrap_odb(var &out: PPGitRepository; odb: PGitOdb): LongInt; cdecl; external 'c' name 'git_repository_wrap_odb';
function git_repository_discover(var &out: PGitBuf; start_path: PAnsiChar; across_fs: LongInt; ceiling_dirs: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_discover';
function git_repository_open_ext(var &out: PPGitRepository; path: PAnsiChar; flags: LongWord; ceiling_dirs: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_open_ext';
function git_repository_open_bare(var &out: PPGitRepository; bare_path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_open_bare';
procedure git_repository_free(repo: PGitRepository); cdecl; external 'c' name 'git_repository_free';
function git_repository_init(var &out: PPGitRepository; path: PAnsiChar; is_bare: LongWord): LongInt; cdecl; external 'c' name 'git_repository_init';
function git_repository_init_options_init(opts: PGitRepositoryInitOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_repository_init_options_init';
function git_repository_init_ext(var &out: PPGitRepository; repo_path: PAnsiChar; opts: PGitRepositoryInitOptions): LongInt; cdecl; external 'c' name 'git_repository_init_ext';
function git_repository_head(var &out: PPGitReference; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_head';
function git_repository_head_for_worktree(var &out: PPGitReference; repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_head_for_worktree';
function git_repository_head_detached(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_head_detached';
function git_repository_head_detached_for_worktree(repo: PGitRepository; name: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_head_detached_for_worktree';
function git_repository_head_unborn(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_head_unborn';
function git_repository_is_empty(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_empty';
function git_repository_item_path(var &out: PGitBuf; repo: PGitRepository; item: TGitRepositoryItemT): LongInt; cdecl; external 'c' name 'git_repository_item_path';
function git_repository_path(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_path';
function git_repository_workdir(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_workdir';
function git_repository_commondir(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_commondir';
function git_repository_set_workdir(repo: PGitRepository; workdir: PAnsiChar; update_gitlink: LongInt): LongInt; cdecl; external 'c' name 'git_repository_set_workdir';
function git_repository_is_bare(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_bare';
function git_repository_is_worktree(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_worktree';
function git_repository_config(var &out: PPGitConfig; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_config';
function git_repository_config_snapshot(var &out: PPGitConfig; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_config_snapshot';
function git_repository_odb(var &out: PPGitOdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_odb';
function git_repository_refdb(var &out: PPGitRefdb; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_refdb';
function git_repository_index(var &out: PPGitIndex; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_index';
function git_repository_message(var &out: PGitBuf; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_message';
function git_repository_message_remove(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_message_remove';
function git_repository_state_cleanup(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_state_cleanup';
function git_repository_fetchhead_foreach(repo: PGitRepository; callback: TGitRepositoryFetchheadForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_repository_fetchhead_foreach';
function git_repository_mergehead_foreach(repo: PGitRepository; callback: TGitRepositoryMergeheadForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_repository_mergehead_foreach';
function git_repository_hashfile(var &out: PGitOid; repo: PGitRepository; path: PAnsiChar; &type: TGitObjectT; as_path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_hashfile';
function git_repository_set_head(repo: PGitRepository; refname: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_set_head';
function git_repository_set_head_detached(repo: PGitRepository; committish: PGitOid): LongInt; cdecl; external 'c' name 'git_repository_set_head_detached';
function git_repository_set_head_detached_from_annotated(repo: PGitRepository; committish: PGitAnnotatedCommit): LongInt; cdecl; external 'c' name 'git_repository_set_head_detached_from_annotated';
function git_repository_detach_head(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_detach_head';
function git_repository_state(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_state';
function git_repository_set_namespace(repo: PGitRepository; nmspace: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_set_namespace';
function git_repository_get_namespace(repo: PGitRepository): PAnsiChar; cdecl; external 'c' name 'git_repository_get_namespace';
function git_repository_is_shallow(repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_is_shallow';
function git_repository_ident(name: PPAnsiChar; email: PPAnsiChar; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_ident';
function git_repository_set_ident(repo: PGitRepository; name: PAnsiChar; email: PAnsiChar): LongInt; cdecl; external 'c' name 'git_repository_set_ident';
function git_repository_oid_type(repo: PGitRepository): TGitOidT; cdecl; external 'c' name 'git_repository_oid_type';
function git_repository_commit_parents(commits: PGitCommitarray; repo: PGitRepository): LongInt; cdecl; external 'c' name 'git_repository_commit_parents';
function git_annotated_commit_from_ref(var &out: PPGitAnnotatedCommit; repo: PGitRepository; ref: PGitReference): LongInt; cdecl; external 'c' name 'git_annotated_commit_from_ref';
function git_annotated_commit_from_fetchhead(var &out: PPGitAnnotatedCommit; repo: PGitRepository; branch_name: PAnsiChar; remote_url: PAnsiChar; id: PGitOid): LongInt; cdecl; external 'c' name 'git_annotated_commit_from_fetchhead';
function git_annotated_commit_lookup(var &out: PPGitAnnotatedCommit; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_annotated_commit_lookup';
function git_annotated_commit_from_revspec(var &out: PPGitAnnotatedCommit; repo: PGitRepository; revspec: PAnsiChar): LongInt; cdecl; external 'c' name 'git_annotated_commit_from_revspec';
function git_annotated_commit_id(commit: PGitAnnotatedCommit): PGitOid; cdecl; external 'c' name 'git_annotated_commit_id';
function git_annotated_commit_ref(commit: PGitAnnotatedCommit): PAnsiChar; cdecl; external 'c' name 'git_annotated_commit_ref';
procedure git_annotated_commit_free(commit: PGitAnnotatedCommit); cdecl; external 'c' name 'git_annotated_commit_free';

implementation
end.

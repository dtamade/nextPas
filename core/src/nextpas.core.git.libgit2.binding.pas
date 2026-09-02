unit nextpas.core.git.libgit2.binding;
{** @desc libgit2 运行时加载层：通过 platform.dl 动态绑定 FFI 符号。
       职责：仅做 dlopen/dlsym 与符号转发，不定义类型词汇；类型词汇
       复用 nextpas.core.git.libgit2.base → nextpas.core.git.libgit2.ffi，
       与静态轨道 nextpas.core.git.libgit2.bindings 互补（base/ffi 分工）。 *}

{$I nextpas.core.settings.inc}
// acq:allow-style-file

interface

uses nextpas.core.base, nextpas.core.exception, nextpas.core.git.libgit2.ffi;

// Basic library functions
// Runtime loader contract
function EnsureLibGit2Loaded: Boolean;
function IsLibGit2Loaded: Boolean;
function GetLibGit2LoadedPath: string;

function git_libgit2_init: cint; cdecl;
function git_libgit2_shutdown: cint; cdecl;
function git_libgit2_version(major, minor, rev: Pcint): cint; cdecl;

// Repository operations
function git_repository_open(out repo: git_repository; const path: PChar): cint; cdecl;
function git_repository_init(out repo: git_repository; const path: PChar; is_bare: cuint): cint; cdecl;
function git_repository_discover(out out_buf: git_buf; const start_path: PChar; across_fs: cint; const ceiling_dirs: PChar): cint; cdecl;
function git_repository_head(out head_ref: git_reference; repo: git_repository): cint; cdecl;
function git_repository_is_bare(repo: git_repository): cint; cdecl;
function git_repository_is_empty(repo: git_repository): cint; cdecl;
function git_repository_path(repo: git_repository): PChar; cdecl;
function git_repository_workdir(repo: git_repository): PChar; cdecl;
function git_repository_set_head(repo: git_repository; const refname: PChar): cint; cdecl;
function git_repository_set_head_detached(repo: git_repository; const commitish: Pgit_oid): cint; cdecl;
function git_repository_head_unborn(repo: git_repository): cint; cdecl;
procedure git_repository_free(repo: git_repository); cdecl;

// Clone operations
function git_clone(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl;

// Remote operations
function git_remote_lookup(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl;
function git_remote_fetch(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl;
function git_remote_push(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl;
function git_remote_list(out out_list: git_strarray; repo: git_repository): cint; cdecl;
function git_remote_url(remote: git_remote): PChar; cdecl;
function git_remote_name(remote: git_remote): PChar; cdecl;
procedure git_remote_free(remote: git_remote); cdecl;

// Reference operations
function git_reference_lookup(out ref_out: git_reference; repo: git_repository; const name: PChar): cint; cdecl;
function git_reference_name(ref: git_reference): PChar; cdecl;
function git_reference_target(ref: git_reference): Pgit_oid; cdecl;
function git_reference_symbolic_target(ref: git_reference): PChar; cdecl;
function git_reference_type(ref: git_reference): git_reference_t; cdecl;
function git_reference_set_target(out out_ref: git_reference; ref: git_reference; const id: Pgit_oid; const log_message: PChar): cint; cdecl;
procedure git_reference_free(ref: git_reference); cdecl;

// Graph / ancestry operations
function git_graph_ahead_behind(out ahead: csize_t; out behind: csize_t; repo: git_repository;
  const local: Pgit_oid; const upstream: Pgit_oid): cint; cdecl;

// Merge operations
function git_merge_commits(out out_index: git_index; repo: git_repository; our_commit: git_commit; their_commit: git_commit;
  const opts: Pointer): cint; cdecl;

// Branch operations
function git_branch_create(out ref_out: git_reference; repo: git_repository; const branch_name: PChar; target: git_commit; force: cint): cint; cdecl;
function git_branch_delete(branch: git_reference): cint; cdecl;
function git_branch_iterator_new(out iter: git_branch_iterator; repo: git_repository; list_flags: git_branch_t): cint; cdecl;
function git_branch_next(out ref_out: git_reference; out branch_type: git_branch_t; iter: git_branch_iterator): cint; cdecl;
procedure git_branch_iterator_free(iter: git_branch_iterator); cdecl;

// Object operations
function git_object_lookup(out obj: git_object; repo: git_repository; const id: Pgit_oid; obj_type: git_object_t): cint; cdecl;
function git_object_id(obj: git_object): Pgit_oid; cdecl;
function git_object_type(obj: git_object): git_object_t; cdecl;
function git_object_peel(out peeled: git_object; obj: git_object; target_type: git_object_t): cint; cdecl;
procedure git_object_free(obj: git_object); cdecl;
function git_tree_lookup(out tree: git_tree; repo: git_repository; const id: Pgit_oid): cint; cdecl;
procedure git_tree_free(tree: git_tree); cdecl;
procedure git_commit_free(commit: git_commit); cdecl;

// Commit operations
function git_commit_lookup(out commit: git_commit; repo: git_repository; const id: Pgit_oid): cint; cdecl;
function git_commit_message(commit: git_commit): PChar; cdecl;
function git_commit_author(commit: git_commit): Pgit_signature_t; cdecl;
function git_commit_committer(commit: git_commit): Pgit_signature_t; cdecl;
function git_commit_time(commit: git_commit): git_time_t; cdecl;
function git_commit_parentcount(commit: git_commit): cuint; cdecl;
function git_commit_tree(out tree: git_tree; commit: git_commit): cint; cdecl;
function git_commit_create(out id: git_oid; repo: git_repository; const update_ref: PChar;
  author: git_signature; committer: git_signature; const message_encoding: PChar; const message: PChar;
  tree: git_tree; parent_count: csize_t; const parents: Pointer): cint; cdecl;

// OID operations
function git_oid_fromstr(out id: git_oid; const str: PChar): cint; cdecl;
function git_oid_tostr(out str: PChar; size: csize_t; const id: Pgit_oid): PChar; cdecl;

// Revparse (resolve ref/spec like 'HEAD', 'main~2' to an object)
function git_revparse_single(out obj: git_object; repo: git_repository; const spec: PChar): cint; cdecl;

// Commit parent access
function git_commit_parent(out parent: git_commit; commit: git_commit; n: cuint): cint; cdecl;

// Diff operations (tree-to-tree / tree-to-workdir+index)
function git_diff_tree_to_tree(out diff: git_diff; repo: git_repository; old_tree: git_tree; new_tree: git_tree; const opts: Pointer): cint; cdecl;
function git_diff_tree_to_workdir_with_index(out diff: git_diff; repo: git_repository; old_tree: git_tree; const opts: Pointer): cint; cdecl;
function git_diff_num_deltas(diff: git_diff): csize_t; cdecl;
function git_diff_get_delta(diff: git_diff; idx: csize_t): Pgit_diff_delta_t; cdecl;
procedure git_diff_free(diff: git_diff); cdecl;

// Patch access (per-file diff hunks/lines)
function git_patch_from_diff(out patch: git_patch; diff: git_diff; idx: csize_t): cint; cdecl;
function git_patch_num_hunks(patch: git_patch): csize_t; cdecl;
function git_patch_get_hunk(out hunk: Pgit_diff_hunk; out lines_in_hunk: csize_t; patch: git_patch; hunk_idx: csize_t): cint; cdecl;
function git_patch_get_line_in_hunk(out line: Pgit_diff_line; patch: git_patch; hunk_idx: csize_t; line_idx: csize_t): cint; cdecl;
procedure git_patch_free(patch: git_patch); cdecl;

// Revwalk (commit traversal along parents)
function git_revwalk_new(out walk: git_revwalk; repo: git_repository): cint; cdecl;
function git_revwalk_push_head(walk: git_revwalk): cint; cdecl;
function git_revwalk_push(walk: git_revwalk; const id: Pgit_oid): cint; cdecl;
function git_revwalk_next(out out_oid: git_oid; walk: git_revwalk): cint; cdecl;
function git_revwalk_sorting(walk: git_revwalk; sort_mode: cuint): cint; cdecl;
procedure git_revwalk_free(walk: git_revwalk); cdecl;
function git_oid_fmt(out str: PChar; const id: Pgit_oid): cint; cdecl;
function git_oid_cmp(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
function git_oid_equal(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
function git_oid_iszero(const id: Pgit_oid): cint; cdecl;

// Blame operations
function git_blame_file(out blame: git_blame; repo: git_repository; const path: PChar; const opts: Pointer): cint; cdecl;
function git_blame_get_hunk_count(blame: git_blame): cuint; cdecl;
function git_blame_get_hunk_byindex(blame: git_blame; index: cuint): Pgit_blame_hunk; cdecl;
procedure git_blame_free(blame: git_blame); cdecl;

// Error handling
function git_error_last: Pgit_error_t; cdecl;
procedure git_error_clear; cdecl;
function git_error_set_str(error_class: cint; const str: PChar): cint; cdecl;

// Status operations
function git_status_list_new(out status_list: git_status_list; repo: git_repository; const opts: Pointer): cint; cdecl;
function git_status_list_entrycount(status_list: git_status_list): csize_t; cdecl;
  // Iterate status (no struct; use a callback to avoid layout issues)
  function git_status_foreach(repo: git_repository; cb: git_status_cb; payload: Pointer): cint; cdecl;



procedure git_status_list_free(status_list: git_status_list); cdecl;

// Index operations
function git_repository_index(out index: git_index; repo: git_repository): cint; cdecl;
function git_index_add_bypath(index: git_index; const path: PChar): cint; cdecl;
function git_index_add_all(index: git_index; const pathspec: Pgit_strarray; flags: cuint; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
function git_index_remove_bypath(index: git_index; const path: PChar): cint; cdecl;
function git_index_update_all(index: git_index; const pathspec: Pgit_strarray; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
function git_index_write(index: git_index): cint; cdecl;
function git_index_read_tree(index: git_index; tree: git_tree): cint; cdecl;
function git_index_write_tree(out id: git_oid; index: git_index): cint; cdecl;
function git_index_write_tree_to(out id: git_oid; index: git_index; repo: git_repository): cint; cdecl;
function git_index_has_conflicts(index: git_index): cint; cdecl;

  // Checkout operations
  function git_checkout_head(repo: git_repository; const opts: Pointer): cint; cdecl;
  function git_checkout_tree(repo: git_repository; tree: git_object; const opts: Pointer): cint; cdecl;

procedure git_index_free(index: git_index); cdecl;

// Configuration operations
function git_repository_config(out cfg: git_config; repo: git_repository): cint; cdecl;
function git_config_open_default(out cfg: git_config): cint; cdecl;
function git_config_get_string(out out_value: PChar; cfg: git_config; const name: PChar): cint; cdecl;
function git_config_set_string(cfg: git_config; const name: PChar; const value: PChar): cint; cdecl;
procedure git_config_free(cfg: git_config); cdecl;
// Config iteration (k42: repo config entry enumeration; include-resolved merged view)
function git_config_iterator_new(out iter: git_config_iterator; cfg: git_config): cint; cdecl;
function git_config_next(out entry: Pgit_config_entry; iter: git_config_iterator): cint; cdecl;
procedure git_config_entry_free(entry: Pgit_config_entry); cdecl;
procedure git_config_iterator_free(iter: git_config_iterator); cdecl;

// Option initialization functions (use Pointer to avoid cross-unit type coupling)
function git_remote_init_callbacks(opts: Pointer; version: cuint): cint; cdecl;
function git_fetch_options_init(opts: Pointer; version: cuint): cint; cdecl;
function git_push_options_init(opts: Pointer; version: cuint): cint; cdecl;
function git_proxy_options_init(opts: Pointer; version: cuint): cint; cdecl;
function git_clone_options_init(opts: Pointer; version: cuint): cint; cdecl;
function git_checkout_options_init(opts: Pointer; version: cuint): cint; cdecl;

// Credential creation (minimal set)
function git_credential_default_new(out cred: Pointer): cint; cdecl;
function git_credential_userpass_plaintext_new(out cred: Pointer; const username, password: PChar): cint; cdecl;
function git_credential_username_new(out cred: Pointer; const username: PChar): cint; cdecl;
function git_credential_ssh_key_from_agent(out cred: Pointer; const username: PChar): cint; cdecl;

// Signature operations
function git_signature_new(out sig: git_signature; const name: PChar; const email: PChar; time: git_time_t; offset: cint): cint; cdecl;
function git_signature_now(out sig: git_signature; const name: PChar; const email: PChar): cint; cdecl;
procedure git_signature_free(sig: git_signature); cdecl;

// Utility frees
procedure git_strarray_free(arr: Pgit_strarray); cdecl;
procedure git_buf_dispose(buffer: Pgit_buf); cdecl;

// Worktree operations
function git_worktree_add(out wt: git_worktree; repo: git_repository;
  const name: PChar; const path: PChar;
  const opts: Pgit_worktree_add_options): cint; cdecl;
function git_worktree_lookup(out wt: git_worktree; repo: git_repository;
  const name: PChar): cint; cdecl;
function git_worktree_list(out list: git_strarray;
  repo: git_repository): cint; cdecl;
function git_worktree_name(wt: git_worktree): PChar; cdecl;
function git_worktree_path(wt: git_worktree): PChar; cdecl;
function git_worktree_is_locked(reason: Pgit_buf; wt: git_worktree): cint; cdecl;
function git_worktree_prune(wt: git_worktree;
  const opts: Pgit_worktree_prune_options): cint; cdecl;
function git_worktree_add_options_init(
  opts: Pgit_worktree_add_options; version: cuint): cint; cdecl;
function git_worktree_prune_options_init(
  opts: Pgit_worktree_prune_options; version: cuint): cint; cdecl;
procedure git_worktree_free(wt: git_worktree); cdecl;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.platform.dl,
  nextpas.core.os.env;

function LibLoaded(const ALib: TPlatformLibrary): Boolean; inline;
begin
  {$IFDEF NEXTPAS_WINDOWS}
  Result := ALib.Handle <> 0;
  {$ELSE}
  Result := ALib.Handle <> nil;
  {$ENDIF}
end;

function GetProcSymbol(const ALib: TPlatformLibrary; const AName: PAnsiChar): Pointer; inline;
var
  LAddr: Pointer;
begin
  // Zero-copy symbol lookup; no heap, no SysUtils.
  if platform_dl_sym(ALib, AName, LAddr) = 0 then
    Result := LAddr
  else
    Result := nil;
end;

// Inline zero-copy OID helpers (performance: Move/CompareMem, no allocation)
procedure BindingCopyOid(out Dst: git_oid; const Src: git_oid); inline;
begin
  Move(Src.id[0], Dst.id[0], SizeOf(Src.id));
end;

function BindingOidEquals(const A, B: git_oid): Boolean; inline;
begin
  Result := CompareMem(@A.id[0], @B.id[0], SizeOf(A.id));
end;

const
  LIBGIT2_PATH_ENV = 'NEXTPAS_LIBGIT2_PATH';

type
  TLibGit2_git_libgit2_init = function: cint; cdecl;
  TLibGit2_git_libgit2_shutdown = function: cint; cdecl;
  TLibGit2_git_libgit2_version = function(major, minor, rev: Pcint): cint; cdecl;
  TLibGit2_git_repository_open = function(out repo: git_repository; const path: PChar): cint; cdecl;
  TLibGit2_git_repository_init = function(out repo: git_repository; const path: PChar; is_bare: cuint): cint; cdecl;
  TLibGit2_git_repository_discover = function(out out_buf: git_buf; const start_path: PChar; across_fs: cint; const ceiling_dirs: PChar): cint; cdecl;
  TLibGit2_git_repository_head = function(out head_ref: git_reference; repo: git_repository): cint; cdecl;
  TLibGit2_git_repository_is_bare = function(repo: git_repository): cint; cdecl;
  TLibGit2_git_repository_is_empty = function(repo: git_repository): cint; cdecl;
  TLibGit2_git_repository_path = function(repo: git_repository): PChar; cdecl;
  TLibGit2_git_repository_workdir = function(repo: git_repository): PChar; cdecl;
  TLibGit2_git_repository_set_head = function(repo: git_repository; const refname: PChar): cint; cdecl;
  TLibGit2_git_repository_set_head_detached = function(repo: git_repository; const commitish: Pgit_oid): cint; cdecl;
  TLibGit2_git_repository_head_unborn = function(repo: git_repository): cint; cdecl;
  TLibGit2_git_repository_free = procedure(repo: git_repository); cdecl;
  TLibGit2_git_clone = function(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl;
  TLibGit2_git_remote_lookup = function(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl;
  TLibGit2_git_remote_fetch = function(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl;
  TLibGit2_git_remote_push = function(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl;
  TLibGit2_git_remote_list = function(out out_list: git_strarray; repo: git_repository): cint; cdecl;
  TLibGit2_git_remote_url = function(remote: git_remote): PChar; cdecl;
  TLibGit2_git_remote_name = function(remote: git_remote): PChar; cdecl;
  TLibGit2_git_remote_free = procedure(remote: git_remote); cdecl;
  TLibGit2_git_reference_lookup = function(out ref_out: git_reference; repo: git_repository; const name: PChar): cint; cdecl;
  TLibGit2_git_reference_name = function(ref: git_reference): PChar; cdecl;
  TLibGit2_git_reference_target = function(ref: git_reference): Pgit_oid; cdecl;
  TLibGit2_git_reference_symbolic_target = function(ref: git_reference): PChar; cdecl;
  TLibGit2_git_reference_type = function(ref: git_reference): git_reference_t; cdecl;
  TLibGit2_git_reference_set_target = function(out out_ref: git_reference; ref: git_reference; const id: Pgit_oid; const log_message: PChar): cint; cdecl;
  TLibGit2_git_reference_free = procedure(ref: git_reference); cdecl;
  TLibGit2_git_graph_ahead_behind = function(out ahead: csize_t; out behind: csize_t; repo: git_repository; const local: Pgit_oid; const upstream: Pgit_oid): cint; cdecl;
  TLibGit2_git_merge_commits = function(out out_index: git_index; repo: git_repository; our_commit: git_commit; their_commit: git_commit; const opts: Pointer): cint; cdecl;
  TLibGit2_git_branch_create = function(out ref_out: git_reference; repo: git_repository; const branch_name: PChar; target: git_commit; force: cint): cint; cdecl;
  TLibGit2_git_branch_delete = function(branch: git_reference): cint; cdecl;
  TLibGit2_git_branch_iterator_new = function(out iter: git_branch_iterator; repo: git_repository; list_flags: git_branch_t): cint; cdecl;
  TLibGit2_git_branch_next = function(out ref_out: git_reference; out branch_type: git_branch_t; iter: git_branch_iterator): cint; cdecl;
  TLibGit2_git_branch_iterator_free = procedure(iter: git_branch_iterator); cdecl;
  TLibGit2_git_object_lookup = function(out obj: git_object; repo: git_repository; const id: Pgit_oid; obj_type: git_object_t): cint; cdecl;
  TLibGit2_git_object_id = function(obj: git_object): Pgit_oid; cdecl;
  TLibGit2_git_object_type = function(obj: git_object): git_object_t; cdecl;
  TLibGit2_git_object_peel = function(out peeled: git_object; obj: git_object; target_type: git_object_t): cint; cdecl;
  TLibGit2_git_object_free = procedure(obj: git_object); cdecl;
  TLibGit2_git_tree_lookup = function(out tree: git_tree; repo: git_repository; const id: Pgit_oid): cint; cdecl;
  TLibGit2_git_tree_free = procedure(tree: git_tree); cdecl;
  TLibGit2_git_commit_free = procedure(commit: git_commit); cdecl;
  TLibGit2_git_commit_lookup = function(out commit: git_commit; repo: git_repository; const id: Pgit_oid): cint; cdecl;
  TLibGit2_git_commit_message = function(commit: git_commit): PChar; cdecl;
  TLibGit2_git_commit_author = function(commit: git_commit): Pgit_signature_t; cdecl;
  TLibGit2_git_commit_committer = function(commit: git_commit): Pgit_signature_t; cdecl;
  TLibGit2_git_commit_time = function(commit: git_commit): git_time_t; cdecl;
  TLibGit2_git_commit_parentcount = function(commit: git_commit): cuint; cdecl;
  TLibGit2_git_commit_tree = function(out tree: git_tree; commit: git_commit): cint; cdecl;
  TLibGit2_git_commit_create = function(out id: git_oid; repo: git_repository; const update_ref: PChar; author: git_signature; committer: git_signature; const message_encoding: PChar; const message: PChar; tree: git_tree; parent_count: csize_t; const parents: Pointer): cint; cdecl;
  TLibGit2_git_oid_fromstr = function(out id: git_oid; const str: PChar): cint; cdecl;
  TLibGit2_git_oid_tostr = function(out str: PChar; size: csize_t; const id: Pgit_oid): PChar; cdecl;
  TLibGit2_git_revparse_single = function(out obj: git_object; repo: git_repository; const spec: PChar): cint; cdecl;
  TLibGit2_git_commit_parent = function(out parent: git_commit; commit: git_commit; n: cuint): cint; cdecl;
  TLibGit2_git_diff_tree_to_tree = function(out diff: git_diff; repo: git_repository; old_tree: git_tree; new_tree: git_tree; const opts: Pointer): cint; cdecl;
  TLibGit2_git_diff_tree_to_workdir_with_index = function(out diff: git_diff; repo: git_repository; old_tree: git_tree; const opts: Pointer): cint; cdecl;
  TLibGit2_git_diff_num_deltas = function(diff: git_diff): csize_t; cdecl;
  TLibGit2_git_diff_get_delta = function(diff: git_diff; idx: csize_t): Pgit_diff_delta_t; cdecl;
  TLibGit2_git_diff_free = procedure(diff: git_diff); cdecl;
  TLibGit2_git_patch_from_diff = function(out patch: git_patch; diff: git_diff; idx: csize_t): cint; cdecl;
  TLibGit2_git_patch_num_hunks = function(patch: git_patch): csize_t; cdecl;
  TLibGit2_git_patch_get_hunk = function(out hunk: Pgit_diff_hunk; out lines_in_hunk: csize_t; patch: git_patch; hunk_idx: csize_t): cint; cdecl;
  TLibGit2_git_patch_get_line_in_hunk = function(out line: Pgit_diff_line; patch: git_patch; hunk_idx: csize_t; line_idx: csize_t): cint; cdecl;
  TLibGit2_git_patch_free = procedure(patch: git_patch); cdecl;
  TLibGit2_git_revwalk_new = function(out walk: git_revwalk; repo: git_repository): cint; cdecl;
  TLibGit2_git_revwalk_push_head = function(walk: git_revwalk): cint; cdecl;
  TLibGit2_git_revwalk_push = function(walk: git_revwalk; const id: Pgit_oid): cint; cdecl;
  TLibGit2_git_revwalk_next = function(out out_oid: git_oid; walk: git_revwalk): cint; cdecl;
  TLibGit2_git_revwalk_sorting = function(walk: git_revwalk; sort_mode: cuint): cint; cdecl;
  TLibGit2_git_revwalk_free = procedure(walk: git_revwalk); cdecl;
  TLibGit2_git_oid_fmt = function(out str: PChar; const id: Pgit_oid): cint; cdecl;
  TLibGit2_git_oid_cmp = function(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
  TLibGit2_git_oid_equal = function(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
  TLibGit2_git_oid_iszero = function(const id: Pgit_oid): cint; cdecl;
  TLibGit2_git_blame_file = function(out blame: git_blame; repo: git_repository; const path: PChar; const opts: Pointer): cint; cdecl;
  TLibGit2_git_blame_get_hunk_count = function(blame: git_blame): cuint; cdecl;
  TLibGit2_git_blame_get_hunk_byindex = function(blame: git_blame; index: cuint): Pgit_blame_hunk; cdecl;
  TLibGit2_git_blame_free = procedure(blame: git_blame); cdecl;
  TLibGit2_git_error_last = function: Pgit_error_t; cdecl;
  TLibGit2_git_error_clear = procedure; cdecl;
  TLibGit2_git_error_set_str = function(error_class: cint; const str: PChar): cint; cdecl;
  TLibGit2_git_status_list_new = function(out status_list: git_status_list; repo: git_repository; const opts: Pointer): cint; cdecl;
  TLibGit2_git_status_list_entrycount = function(status_list: git_status_list): csize_t; cdecl;
  TLibGit2_git_status_foreach = function(repo: git_repository; cb: git_status_cb; payload: Pointer): cint; cdecl;
  TLibGit2_git_status_list_free = procedure(status_list: git_status_list); cdecl;
  TLibGit2_git_repository_index = function(out index: git_index; repo: git_repository): cint; cdecl;
  TLibGit2_git_index_add_bypath = function(index: git_index; const path: PChar): cint; cdecl;
  TLibGit2_git_index_add_all = function(index: git_index; const pathspec: Pgit_strarray; flags: cuint; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
  TLibGit2_git_index_remove_bypath = function(index: git_index; const path: PChar): cint; cdecl;
  TLibGit2_git_index_update_all = function(index: git_index; const pathspec: Pgit_strarray; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
  TLibGit2_git_index_write = function(index: git_index): cint; cdecl;
  TLibGit2_git_index_read_tree = function(index: git_index; tree: git_tree): cint; cdecl;
  TLibGit2_git_index_write_tree = function(out id: git_oid; index: git_index): cint; cdecl;
  TLibGit2_git_index_write_tree_to = function(out id: git_oid; index: git_index; repo: git_repository): cint; cdecl;
  TLibGit2_git_index_has_conflicts = function(index: git_index): cint; cdecl;
  TLibGit2_git_checkout_head = function(repo: git_repository; const opts: Pointer): cint; cdecl;
  TLibGit2_git_checkout_tree = function(repo: git_repository; tree: git_object; const opts: Pointer): cint; cdecl;
  TLibGit2_git_index_free = procedure(index: git_index); cdecl;
  TLibGit2_git_repository_config = function(out cfg: git_config; repo: git_repository): cint; cdecl;
  TLibGit2_git_config_open_default = function(out cfg: git_config): cint; cdecl;
  TLibGit2_git_config_get_string = function(out out_value: PChar; cfg: git_config; const name: PChar): cint; cdecl;
  TLibGit2_git_config_set_string = function(cfg: git_config; const name: PChar; const value: PChar): cint; cdecl;
  TLibGit2_git_config_free = procedure(cfg: git_config); cdecl;
  TLibGit2_git_config_iterator_new = function(out iter: git_config_iterator; cfg: git_config): cint; cdecl;
  TLibGit2_git_config_next = function(out entry: Pgit_config_entry; iter: git_config_iterator): cint; cdecl;
  TLibGit2_git_config_entry_free = procedure(entry: Pgit_config_entry); cdecl;
  TLibGit2_git_config_iterator_free = procedure(iter: git_config_iterator); cdecl;
  TLibGit2_git_remote_init_callbacks = function(opts: Pointer; version: cuint): cint; cdecl;
  TLibGit2_git_fetch_options_init = function(opts: Pointer; version: cuint): cint; cdecl;
  TLibGit2_git_push_options_init = function(opts: Pointer; version: cuint): cint; cdecl;
  TLibGit2_git_proxy_options_init = function(opts: Pointer; version: cuint): cint; cdecl;
  TLibGit2_git_clone_options_init = function(opts: Pointer; version: cuint): cint; cdecl;
  TLibGit2_git_checkout_options_init = function(opts: Pointer; version: cuint): cint; cdecl;
  TLibGit2_git_credential_default_new = function(out cred: Pointer): cint; cdecl;
  TLibGit2_git_credential_userpass_plaintext_new = function(out cred: Pointer; const username, password: PChar): cint; cdecl;
  TLibGit2_git_credential_username_new = function(out cred: Pointer; const username: PChar): cint; cdecl;
  TLibGit2_git_credential_ssh_key_from_agent = function(out cred: Pointer; const username: PChar): cint; cdecl;
  TLibGit2_git_signature_new = function(out sig: git_signature; const name: PChar; const email: PChar; time: git_time_t; offset: cint): cint; cdecl;
  TLibGit2_git_signature_now = function(out sig: git_signature; const name: PChar; const email: PChar): cint; cdecl;
  TLibGit2_git_signature_free = procedure(sig: git_signature); cdecl;
  TLibGit2_git_strarray_free = procedure(arr: Pgit_strarray); cdecl;
  TLibGit2_git_buf_dispose = procedure(buffer: Pgit_buf); cdecl;

  TLibGit2_git_worktree_add = function(out wt: git_worktree; repo: git_repository;
    const name: PChar; const path: PChar;
    const opts: Pgit_worktree_add_options): cint; cdecl;
  TLibGit2_git_worktree_lookup = function(out wt: git_worktree; repo: git_repository;
    const name: PChar): cint; cdecl;
  TLibGit2_git_worktree_list = function(out list: git_strarray;
    repo: git_repository): cint; cdecl;
  TLibGit2_git_worktree_name = function(wt: git_worktree): PChar; cdecl;
  TLibGit2_git_worktree_path = function(wt: git_worktree): PChar; cdecl;
  TLibGit2_git_worktree_is_locked = function(reason: Pgit_buf; wt: git_worktree): cint; cdecl;
  TLibGit2_git_worktree_prune = function(wt: git_worktree;
    const opts: Pgit_worktree_prune_options): cint; cdecl;
  TLibGit2_git_worktree_add_options_init = function(
    opts: Pgit_worktree_add_options; version: cuint): cint; cdecl;
  TLibGit2_git_worktree_prune_options_init = function(
    opts: Pgit_worktree_prune_options; version: cuint): cint; cdecl;
  TLibGit2_git_worktree_free = procedure(wt: git_worktree); cdecl;

var
  GLibGit2Handle: TPlatformLibrary;
  GLibGit2Loaded: Boolean = False;
  GLibGit2LoadedPath: string = '';
  GLibGit2Lock: TRTLCriticalSection;
  dyn_git_libgit2_init: TLibGit2_git_libgit2_init = nil;
  dyn_git_libgit2_shutdown: TLibGit2_git_libgit2_shutdown = nil;
function static_git_libgit2_init: cint; cdecl; external LIBGIT2_LIB name 'git_libgit2_init';
function static_git_libgit2_shutdown: cint; cdecl; external LIBGIT2_LIB name 'git_libgit2_shutdown';
function static_git_libgit2_version(major, minor, rev: Pcint): cint; cdecl; external LIBGIT2_LIB name 'git_libgit2_version';
function static_git_repository_open(out repo: git_repository; const path: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_repository_open';
function static_git_repository_init(out repo: git_repository; const path: PChar; is_bare: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_repository_init';
function static_git_repository_discover(out out_buf: git_buf; const start_path: PChar; across_fs: cint; const ceiling_dirs: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_repository_discover';
function static_git_repository_head(out head_ref: git_reference; repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_repository_head';
function static_git_repository_is_bare(repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_repository_is_bare';
function static_git_repository_is_empty(repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_repository_is_empty';
function static_git_repository_path(repo: git_repository): PChar; cdecl; external LIBGIT2_LIB name 'git_repository_path';
function static_git_repository_workdir(repo: git_repository): PChar; cdecl; external LIBGIT2_LIB name 'git_repository_workdir';
function static_git_repository_set_head(repo: git_repository; const refname: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_repository_set_head';
function static_git_repository_set_head_detached(repo: git_repository; const commitish: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_repository_set_head_detached';
function static_git_repository_head_unborn(repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_repository_head_unborn';
procedure static_git_repository_free(repo: git_repository); cdecl; external LIBGIT2_LIB name 'git_repository_free';
function static_git_clone(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_clone';
function static_git_remote_lookup(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_remote_lookup';
function static_git_remote_fetch(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_remote_fetch';
function static_git_remote_push(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_remote_push';
function static_git_remote_list(out out_list: git_strarray; repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_remote_list';
function static_git_remote_url(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB name 'git_remote_url';
function static_git_remote_name(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB name 'git_remote_name';
procedure static_git_remote_free(remote: git_remote); cdecl; external LIBGIT2_LIB name 'git_remote_free';
function static_git_reference_lookup(out ref_out: git_reference; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_reference_lookup';
function static_git_reference_name(ref: git_reference): PChar; cdecl; external LIBGIT2_LIB name 'git_reference_name';
function static_git_reference_target(ref: git_reference): Pgit_oid; cdecl; external LIBGIT2_LIB name 'git_reference_target';
function static_git_reference_symbolic_target(ref: git_reference): PChar; cdecl; external LIBGIT2_LIB name 'git_reference_symbolic_target';
function static_git_reference_type(ref: git_reference): git_reference_t; cdecl; external LIBGIT2_LIB name 'git_reference_type';
function static_git_reference_set_target(out out_ref: git_reference; ref: git_reference; const id: Pgit_oid; const log_message: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_reference_set_target';
procedure static_git_reference_free(ref: git_reference); cdecl; external LIBGIT2_LIB name 'git_reference_free';
function static_git_graph_ahead_behind(out ahead: csize_t; out behind: csize_t; repo: git_repository;
  const local: Pgit_oid; const upstream: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_graph_ahead_behind';
function static_git_merge_commits(out out_index: git_index; repo: git_repository; our_commit: git_commit; their_commit: git_commit;
  const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_merge_commits';
function static_git_branch_create(out ref_out: git_reference; repo: git_repository; const branch_name: PChar; target: git_commit; force: cint): cint; cdecl; external LIBGIT2_LIB name 'git_branch_create';
function static_git_branch_delete(branch: git_reference): cint; cdecl; external LIBGIT2_LIB name 'git_branch_delete';
function static_git_branch_iterator_new(out iter: git_branch_iterator; repo: git_repository; list_flags: git_branch_t): cint; cdecl; external LIBGIT2_LIB name 'git_branch_iterator_new';
function static_git_branch_next(out ref_out: git_reference; out branch_type: git_branch_t; iter: git_branch_iterator): cint; cdecl; external LIBGIT2_LIB name 'git_branch_next';
procedure static_git_branch_iterator_free(iter: git_branch_iterator); cdecl; external LIBGIT2_LIB name 'git_branch_iterator_free';
function static_git_object_lookup(out obj: git_object; repo: git_repository; const id: Pgit_oid; obj_type: git_object_t): cint; cdecl; external LIBGIT2_LIB name 'git_object_lookup';
function static_git_object_id(obj: git_object): Pgit_oid; cdecl; external LIBGIT2_LIB name 'git_object_id';
function static_git_object_type(obj: git_object): git_object_t; cdecl; external LIBGIT2_LIB name 'git_object_type';
function static_git_object_peel(out peeled: git_object; obj: git_object; target_type: git_object_t): cint; cdecl; external LIBGIT2_LIB name 'git_object_peel';
procedure static_git_object_free(obj: git_object); cdecl; external LIBGIT2_LIB name 'git_object_free';
function static_git_tree_lookup(out tree: git_tree; repo: git_repository; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_tree_lookup';
procedure static_git_tree_free(tree: git_tree); cdecl; external LIBGIT2_LIB name 'git_tree_free';
procedure static_git_commit_free(commit: git_commit); cdecl; external LIBGIT2_LIB name 'git_commit_free';
function static_git_commit_lookup(out commit: git_commit; repo: git_repository; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_commit_lookup';
function static_git_commit_message(commit: git_commit): PChar; cdecl; external LIBGIT2_LIB name 'git_commit_message';
function static_git_commit_author(commit: git_commit): Pgit_signature_t; cdecl; external LIBGIT2_LIB name 'git_commit_author';
function static_git_commit_committer(commit: git_commit): Pgit_signature_t; cdecl; external LIBGIT2_LIB name 'git_commit_committer';
function static_git_commit_time(commit: git_commit): git_time_t; cdecl; external LIBGIT2_LIB name 'git_commit_time';
function static_git_commit_parentcount(commit: git_commit): cuint; cdecl; external LIBGIT2_LIB name 'git_commit_parentcount';
function static_git_commit_tree(out tree: git_tree; commit: git_commit): cint; cdecl; external LIBGIT2_LIB name 'git_commit_tree';
function static_git_commit_create(out id: git_oid; repo: git_repository; const update_ref: PChar;
  author: git_signature; committer: git_signature; const message_encoding: PChar; const message: PChar;
  tree: git_tree; parent_count: csize_t; const parents: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_commit_create';
function static_git_oid_fromstr(out id: git_oid; const str: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_oid_fromstr';
function static_git_oid_tostr(out str: PChar; size: csize_t; const id: Pgit_oid): PChar; cdecl; external LIBGIT2_LIB name 'git_oid_tostr';
function static_git_revparse_single(out obj: git_object; repo: git_repository; const spec: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_revparse_single';
function static_git_commit_parent(out parent: git_commit; commit: git_commit; n: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_commit_parent';
function static_git_diff_tree_to_tree(out diff: git_diff; repo: git_repository; old_tree: git_tree; new_tree: git_tree; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_diff_tree_to_tree';
function static_git_diff_tree_to_workdir_with_index(out diff: git_diff; repo: git_repository; old_tree: git_tree; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_diff_tree_to_workdir_with_index';
function static_git_diff_num_deltas(diff: git_diff): csize_t; cdecl; external LIBGIT2_LIB name 'git_diff_num_deltas';
function static_git_diff_get_delta(diff: git_diff; idx: csize_t): Pgit_diff_delta_t; cdecl; external LIBGIT2_LIB name 'git_diff_get_delta';
procedure static_git_diff_free(diff: git_diff); cdecl; external LIBGIT2_LIB name 'git_diff_free';
function static_git_patch_from_diff(out patch: git_patch; diff: git_diff; idx: csize_t): cint; cdecl; external LIBGIT2_LIB name 'git_patch_from_diff';
function static_git_patch_num_hunks(patch: git_patch): csize_t; cdecl; external LIBGIT2_LIB name 'git_patch_num_hunks';
function static_git_patch_get_hunk(out hunk: Pgit_diff_hunk; out lines_in_hunk: csize_t; patch: git_patch; hunk_idx: csize_t): cint; cdecl; external LIBGIT2_LIB name 'git_patch_get_hunk';
function static_git_patch_get_line_in_hunk(out line: Pgit_diff_line; patch: git_patch; hunk_idx: csize_t; line_idx: csize_t): cint; cdecl; external LIBGIT2_LIB name 'git_patch_get_line_in_hunk';
procedure static_git_patch_free(patch: git_patch); cdecl; external LIBGIT2_LIB name 'git_patch_free';
function static_git_revwalk_new(out walk: git_revwalk; repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_revwalk_new';
function static_git_revwalk_push_head(walk: git_revwalk): cint; cdecl; external LIBGIT2_LIB name 'git_revwalk_push_head';
function static_git_revwalk_push(walk: git_revwalk; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_revwalk_push';
function static_git_revwalk_next(out out_oid: git_oid; walk: git_revwalk): cint; cdecl; external LIBGIT2_LIB name 'git_revwalk_next';
function static_git_revwalk_sorting(walk: git_revwalk; sort_mode: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_revwalk_sorting';
procedure static_git_revwalk_free(walk: git_revwalk); cdecl; external LIBGIT2_LIB name 'git_revwalk_free';
function static_git_blame_file(out blame: git_blame; repo: git_repository; const path: PChar; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_blame_file';
function static_git_blame_get_hunk_count(blame: git_blame): cuint; cdecl; external LIBGIT2_LIB name 'git_blame_get_hunk_count';
function static_git_blame_get_hunk_byindex(blame: git_blame; index: cuint): Pgit_blame_hunk; cdecl; external LIBGIT2_LIB name 'git_blame_get_hunk_byindex';
procedure static_git_blame_free(blame: git_blame); cdecl; external LIBGIT2_LIB name 'git_blame_free';
function static_git_oid_fmt(out str: PChar; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_oid_fmt';
function static_git_oid_cmp(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_oid_cmp';
function static_git_oid_equal(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_oid_equal';
function static_git_oid_iszero(const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB name 'git_oid_iszero';
function static_git_error_last: Pgit_error_t; cdecl; external LIBGIT2_LIB name 'git_error_last';
procedure static_git_error_clear; cdecl; external LIBGIT2_LIB name 'git_error_clear';
function static_git_error_set_str(error_class: cint; const str: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_error_set_str';
function static_git_status_list_new(out status_list: git_status_list; repo: git_repository; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_status_list_new';
function static_git_status_list_entrycount(status_list: git_status_list): csize_t; cdecl; external LIBGIT2_LIB name 'git_status_list_entrycount';
  function static_git_status_foreach(repo: git_repository; cb: git_status_cb; payload: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_status_foreach';
procedure static_git_status_list_free(status_list: git_status_list); cdecl; external LIBGIT2_LIB name 'git_status_list_free';
function static_git_repository_index(out index: git_index; repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_repository_index';
function static_git_index_add_bypath(index: git_index; const path: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_index_add_bypath';
function static_git_index_add_all(index: git_index; const pathspec: Pgit_strarray; flags: cuint; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_index_add_all';
function static_git_index_remove_bypath(index: git_index; const path: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_index_remove_bypath';
function static_git_index_update_all(index: git_index; const pathspec: Pgit_strarray; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_index_update_all';
function static_git_index_write(index: git_index): cint; cdecl; external LIBGIT2_LIB name 'git_index_write';
function static_git_index_read_tree(index: git_index; tree: git_tree): cint; cdecl; external LIBGIT2_LIB name 'git_index_read_tree';
function static_git_index_write_tree(out id: git_oid; index: git_index): cint; cdecl; external LIBGIT2_LIB name 'git_index_write_tree';
function static_git_index_write_tree_to(out id: git_oid; index: git_index; repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_index_write_tree_to';
function static_git_index_has_conflicts(index: git_index): cint; cdecl; external LIBGIT2_LIB name 'git_index_has_conflicts';
  function static_git_checkout_head(repo: git_repository; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_checkout_head';
  function static_git_checkout_tree(repo: git_repository; tree: git_object; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_checkout_tree';
procedure static_git_index_free(index: git_index); cdecl; external LIBGIT2_LIB name 'git_index_free';
function static_git_repository_config(out cfg: git_config; repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_repository_config';
function static_git_config_open_default(out cfg: git_config): cint; cdecl; external LIBGIT2_LIB name 'git_config_open_default';
function static_git_config_get_string(out out_value: PChar; cfg: git_config; const name: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_config_get_string';
function static_git_config_set_string(cfg: git_config; const name: PChar; const value: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_config_set_string';
procedure static_git_config_free(cfg: git_config); cdecl; external LIBGIT2_LIB name 'git_config_free';
function static_git_config_iterator_new(out iter: git_config_iterator; cfg: git_config): cint; cdecl; external LIBGIT2_LIB name 'git_config_iterator_new';
function static_git_config_next(out entry: Pgit_config_entry; iter: git_config_iterator): cint; cdecl; external LIBGIT2_LIB name 'git_config_next';
procedure static_git_config_entry_free(entry: Pgit_config_entry); cdecl; external LIBGIT2_LIB name 'git_config_entry_free';
procedure static_git_config_iterator_free(iter: git_config_iterator); cdecl; external LIBGIT2_LIB name 'git_config_iterator_free';
function static_git_remote_init_callbacks(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_remote_init_callbacks';
function static_git_fetch_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_fetch_options_init';
function static_git_push_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_push_options_init';
function static_git_proxy_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_proxy_options_init';
function static_git_clone_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_clone_options_init';
function static_git_checkout_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_checkout_options_init';
function static_git_credential_default_new(out cred: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_credential_default_new';
function static_git_credential_userpass_plaintext_new(out cred: Pointer; const username, password: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_credential_userpass_plaintext_new';
function static_git_credential_username_new(out cred: Pointer; const username: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_credential_username_new';
function static_git_credential_ssh_key_from_agent(out cred: Pointer; const username: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_credential_ssh_key_from_agent';
function static_git_signature_new(out sig: git_signature; const name: PChar; const email: PChar; time: git_time_t; offset: cint): cint; cdecl; external LIBGIT2_LIB name 'git_signature_new';
function static_git_signature_now(out sig: git_signature; const name: PChar; const email: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_signature_now';
procedure static_git_signature_free(sig: git_signature); cdecl; external LIBGIT2_LIB name 'git_signature_free';
procedure static_git_strarray_free(arr: Pgit_strarray); cdecl; external LIBGIT2_LIB name 'git_strarray_free';
procedure static_git_buf_dispose(buffer: Pgit_buf); cdecl; external LIBGIT2_LIB name 'git_buf_dispose';

function static_git_worktree_add(out wt: git_worktree; repo: git_repository;
  const name: PChar; const path: PChar;
  const opts: Pgit_worktree_add_options): cint; cdecl; external LIBGIT2_LIB name 'git_worktree_add';
function static_git_worktree_lookup(out wt: git_worktree; repo: git_repository;
  const name: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_worktree_lookup';
function static_git_worktree_list(out list: git_strarray;
  repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_worktree_list';
function static_git_worktree_name(wt: git_worktree): PChar; cdecl; external LIBGIT2_LIB name 'git_worktree_name';
function static_git_worktree_path(wt: git_worktree): PChar; cdecl; external LIBGIT2_LIB name 'git_worktree_path';
function static_git_worktree_is_locked(reason: Pgit_buf; wt: git_worktree): cint; cdecl; external LIBGIT2_LIB name 'git_worktree_is_locked';
function static_git_worktree_prune(wt: git_worktree;
  const opts: Pgit_worktree_prune_options): cint; cdecl; external LIBGIT2_LIB name 'git_worktree_prune';
function static_git_worktree_add_options_init(
  opts: Pgit_worktree_add_options; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_worktree_add_options_init';
function static_git_worktree_prune_options_init(
  opts: Pgit_worktree_prune_options; version: cuint): cint; cdecl; external LIBGIT2_LIB name 'git_worktree_prune_options_init';
procedure static_git_worktree_free(wt: git_worktree); cdecl; external LIBGIT2_LIB name 'git_worktree_free';

function EnsureLibGit2Loaded: Boolean;
begin
  Result := True;
end;

function IsLibGit2Loaded: Boolean;
begin
  Result := True;
end;

function GetLibGit2LoadedPath: string;
begin
  Result := LIBGIT2_LIB;
end;

function git_libgit2_init: cint; cdecl;
begin
  Result := static_git_libgit2_init();
end;

function git_libgit2_shutdown: cint; cdecl;
begin
  Result := static_git_libgit2_shutdown();
end;

function git_libgit2_version(major, minor, rev: Pcint): cint; cdecl;
begin
  Result := static_git_libgit2_version(major, minor, rev);
end;

function git_repository_open(out repo: git_repository; const path: PChar): cint; cdecl;
begin
  Result := static_git_repository_open(repo, path);
end;

function git_repository_init(out repo: git_repository; const path: PChar; is_bare: cuint): cint; cdecl;
begin
  Result := static_git_repository_init(repo, path, is_bare);
end;

function git_repository_discover(out out_buf: git_buf; const start_path: PChar; across_fs: cint; const ceiling_dirs: PChar): cint; cdecl;
begin
  Result := static_git_repository_discover(out_buf, start_path, across_fs, ceiling_dirs);
end;

function git_repository_head(out head_ref: git_reference; repo: git_repository): cint; cdecl;
begin
  Result := static_git_repository_head(head_ref, repo);
end;

function git_repository_is_bare(repo: git_repository): cint; cdecl;
begin
  Result := static_git_repository_is_bare(repo);
end;

function git_repository_is_empty(repo: git_repository): cint; cdecl;
begin
  Result := static_git_repository_is_empty(repo);
end;

function git_repository_path(repo: git_repository): PChar; cdecl;
begin
  Result := static_git_repository_path(repo);
end;

function git_repository_workdir(repo: git_repository): PChar; cdecl;
begin
  Result := static_git_repository_workdir(repo);
end;

function git_repository_set_head(repo: git_repository; const refname: PChar): cint; cdecl;
begin
  Result := static_git_repository_set_head(repo, refname);
end;

function git_repository_set_head_detached(repo: git_repository; const commitish: Pgit_oid): cint; cdecl;
begin
  Result := static_git_repository_set_head_detached(repo, commitish);
end;

function git_repository_head_unborn(repo: git_repository): cint; cdecl;
begin
  Result := static_git_repository_head_unborn(repo);
end;

procedure git_repository_free(repo: git_repository); cdecl;
begin
  static_git_repository_free(repo);
end;

function git_clone(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl;
begin
  Result := static_git_clone(repo, url, local_path, options);
end;

function git_remote_lookup(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl;
begin
  Result := static_git_remote_lookup(remote, repo, name);
end;

function git_remote_fetch(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl;
begin
  Result := static_git_remote_fetch(remote, refspecs, opts, reflog_message);
end;

function git_remote_push(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl;
begin
  Result := static_git_remote_push(remote, refspecs, opts);
end;

function git_remote_list(out out_list: git_strarray; repo: git_repository): cint; cdecl;
begin
  Result := static_git_remote_list(out_list, repo);
end;

function git_remote_url(remote: git_remote): PChar; cdecl;
begin
  Result := static_git_remote_url(remote);
end;

function git_remote_name(remote: git_remote): PChar; cdecl;
begin
  Result := static_git_remote_name(remote);
end;

procedure git_remote_free(remote: git_remote); cdecl;
begin
  static_git_remote_free(remote);
end;

function git_reference_lookup(out ref_out: git_reference; repo: git_repository; const name: PChar): cint; cdecl;
begin
  Result := static_git_reference_lookup(ref_out, repo, name);
end;

function git_reference_name(ref: git_reference): PChar; cdecl;
begin
  Result := static_git_reference_name(ref);
end;

function git_reference_target(ref: git_reference): Pgit_oid; cdecl;
begin
  Result := static_git_reference_target(ref);
end;

function git_reference_symbolic_target(ref: git_reference): PChar; cdecl;
begin
  Result := static_git_reference_symbolic_target(ref);
end;

function git_reference_type(ref: git_reference): git_reference_t; cdecl;
begin
  Result := static_git_reference_type(ref);
end;

function git_reference_set_target(out out_ref: git_reference; ref: git_reference; const id: Pgit_oid; const log_message: PChar): cint; cdecl;
begin
  Result := static_git_reference_set_target(out_ref, ref, id, log_message);
end;

procedure git_reference_free(ref: git_reference); cdecl;
begin
  static_git_reference_free(ref);
end;

function git_graph_ahead_behind(out ahead: csize_t; out behind: csize_t; repo: git_repository;
  const local: Pgit_oid; const upstream: Pgit_oid): cint; cdecl;
begin
  Result := static_git_graph_ahead_behind(ahead, behind, repo, local, upstream);
end;

function git_merge_commits(out out_index: git_index; repo: git_repository; our_commit: git_commit; their_commit: git_commit;
  const opts: Pointer): cint; cdecl;
begin
  Result := static_git_merge_commits(out_index, repo, our_commit, their_commit, opts);
end;

function git_branch_create(out ref_out: git_reference; repo: git_repository; const branch_name: PChar; target: git_commit; force: cint): cint; cdecl;
begin
  Result := static_git_branch_create(ref_out, repo, branch_name, target, force);
end;

function git_branch_delete(branch: git_reference): cint; cdecl;
begin
  Result := static_git_branch_delete(branch);
end;

function git_branch_iterator_new(out iter: git_branch_iterator; repo: git_repository; list_flags: git_branch_t): cint; cdecl;
begin
  Result := static_git_branch_iterator_new(iter, repo, list_flags);
end;

function git_branch_next(out ref_out: git_reference; out branch_type: git_branch_t; iter: git_branch_iterator): cint; cdecl;
begin
  Result := static_git_branch_next(ref_out, branch_type, iter);
end;

procedure git_branch_iterator_free(iter: git_branch_iterator); cdecl;
begin
  static_git_branch_iterator_free(iter);
end;

function git_object_lookup(out obj: git_object; repo: git_repository; const id: Pgit_oid; obj_type: git_object_t): cint; cdecl;
begin
  Result := static_git_object_lookup(obj, repo, id, obj_type);
end;

function git_object_id(obj: git_object): Pgit_oid; cdecl;
begin
  Result := static_git_object_id(obj);
end;

function git_object_type(obj: git_object): git_object_t; cdecl;
begin
  Result := static_git_object_type(obj);
end;

function git_object_peel(out peeled: git_object; obj: git_object; target_type: git_object_t): cint; cdecl;
begin
  Result := static_git_object_peel(peeled, obj, target_type);
end;

procedure git_object_free(obj: git_object); cdecl;
begin
  static_git_object_free(obj);
end;

function git_tree_lookup(out tree: git_tree; repo: git_repository; const id: Pgit_oid): cint; cdecl;
begin
  Result := static_git_tree_lookup(tree, repo, id);
end;

procedure git_tree_free(tree: git_tree); cdecl;
begin
  static_git_tree_free(tree);
end;

procedure git_commit_free(commit: git_commit); cdecl;
begin
  static_git_commit_free(commit);
end;

function git_commit_lookup(out commit: git_commit; repo: git_repository; const id: Pgit_oid): cint; cdecl;
begin
  Result := static_git_commit_lookup(commit, repo, id);
end;

function git_commit_message(commit: git_commit): PChar; cdecl;
begin
  Result := static_git_commit_message(commit);
end;

function git_commit_author(commit: git_commit): Pgit_signature_t; cdecl;
begin
  Result := static_git_commit_author(commit);
end;

function git_commit_committer(commit: git_commit): Pgit_signature_t; cdecl;
begin
  Result := static_git_commit_committer(commit);
end;

function git_commit_time(commit: git_commit): git_time_t; cdecl;
begin
  Result := static_git_commit_time(commit);
end;

function git_commit_parentcount(commit: git_commit): cuint; cdecl;
begin
  Result := static_git_commit_parentcount(commit);
end;

function git_commit_tree(out tree: git_tree; commit: git_commit): cint; cdecl;
begin
  Result := static_git_commit_tree(tree, commit);
end;

function git_commit_create(out id: git_oid; repo: git_repository; const update_ref: PChar;
  author: git_signature; committer: git_signature; const message_encoding: PChar; const message: PChar;
  tree: git_tree; parent_count: csize_t; const parents: Pointer): cint; cdecl;
begin
  Result := static_git_commit_create(id, repo, update_ref, author, committer, message_encoding, message, tree, parent_count, parents);
end;

function git_oid_fromstr(out id: git_oid; const str: PChar): cint; cdecl;
begin
  Result := static_git_oid_fromstr(id, str);
end;

function git_oid_tostr(out str: PChar; size: csize_t; const id: Pgit_oid): PChar; cdecl;
begin
  Result := static_git_oid_tostr(str, size, id);
end;

function git_revparse_single(out obj: git_object; repo: git_repository; const spec: PChar): cint; cdecl;
begin
  Result := static_git_revparse_single(obj, repo, spec);
end;

function git_commit_parent(out parent: git_commit; commit: git_commit; n: cuint): cint; cdecl;
begin
  Result := static_git_commit_parent(parent, commit, n);
end;

function git_diff_tree_to_tree(out diff: git_diff; repo: git_repository; old_tree: git_tree; new_tree: git_tree; const opts: Pointer): cint; cdecl;
begin
  Result := static_git_diff_tree_to_tree(diff, repo, old_tree, new_tree, opts);
end;

function git_diff_tree_to_workdir_with_index(out diff: git_diff; repo: git_repository; old_tree: git_tree; const opts: Pointer): cint; cdecl;
begin
  Result := static_git_diff_tree_to_workdir_with_index(diff, repo, old_tree, opts);
end;

function git_diff_num_deltas(diff: git_diff): csize_t; cdecl;
begin
  Result := static_git_diff_num_deltas(diff);
end;

function git_diff_get_delta(diff: git_diff; idx: csize_t): Pgit_diff_delta_t; cdecl;
begin
  Result := static_git_diff_get_delta(diff, idx);
end;

procedure git_diff_free(diff: git_diff); cdecl;
begin
  static_git_diff_free(diff);
end;

function git_patch_from_diff(out patch: git_patch; diff: git_diff; idx: csize_t): cint; cdecl;
begin
  Result := static_git_patch_from_diff(patch, diff, idx);
end;

function git_patch_num_hunks(patch: git_patch): csize_t; cdecl;
begin
  Result := static_git_patch_num_hunks(patch);
end;

function git_patch_get_hunk(out hunk: Pgit_diff_hunk; out lines_in_hunk: csize_t; patch: git_patch; hunk_idx: csize_t): cint; cdecl;
begin
  Result := static_git_patch_get_hunk(hunk, lines_in_hunk, patch, hunk_idx);
end;

function git_patch_get_line_in_hunk(out line: Pgit_diff_line; patch: git_patch; hunk_idx: csize_t; line_idx: csize_t): cint; cdecl;
begin
  Result := static_git_patch_get_line_in_hunk(line, patch, hunk_idx, line_idx);
end;

procedure git_patch_free(patch: git_patch); cdecl;
begin
  static_git_patch_free(patch);
end;

function git_revwalk_new(out walk: git_revwalk; repo: git_repository): cint; cdecl;
begin
  Result := static_git_revwalk_new(walk, repo);
end;

function git_revwalk_push_head(walk: git_revwalk): cint; cdecl;
begin
  Result := static_git_revwalk_push_head(walk);
end;

function git_revwalk_push(walk: git_revwalk; const id: Pgit_oid): cint; cdecl;
begin
  Result := static_git_revwalk_push(walk, id);
end;

function git_revwalk_next(out out_oid: git_oid; walk: git_revwalk): cint; cdecl;
begin
  Result := static_git_revwalk_next(out_oid, walk);
end;

function git_revwalk_sorting(walk: git_revwalk; sort_mode: cuint): cint; cdecl;
begin
  Result := static_git_revwalk_sorting(walk, sort_mode);
end;

procedure git_revwalk_free(walk: git_revwalk); cdecl;
begin
  static_git_revwalk_free(walk);
end;

function git_blame_file(out blame: git_blame; repo: git_repository; const path: PChar; const opts: Pointer): cint; cdecl;
begin
  Result := static_git_blame_file(blame, repo, path, opts);
end;

function git_blame_get_hunk_count(blame: git_blame): cuint; cdecl;
begin
  Result := static_git_blame_get_hunk_count(blame);
end;

function git_blame_get_hunk_byindex(blame: git_blame; index: cuint): Pgit_blame_hunk; cdecl;
begin
  Result := static_git_blame_get_hunk_byindex(blame, index);
end;

procedure git_blame_free(blame: git_blame); cdecl;
begin
  static_git_blame_free(blame);
end;

function git_oid_fmt(out str: PChar; const id: Pgit_oid): cint; cdecl;
begin
  Result := static_git_oid_fmt(str, id);
end;

function git_oid_cmp(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
begin
  Result := static_git_oid_cmp(a, b);
end;

function git_oid_equal(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
begin
  Result := static_git_oid_equal(a, b);
end;

function git_oid_iszero(const id: Pgit_oid): cint; cdecl;
begin
  Result := static_git_oid_iszero(id);
end;

function git_error_last: Pgit_error_t; cdecl;
begin
  Result := static_git_error_last();
end;

procedure git_error_clear; cdecl;
begin
  static_git_error_clear();
end;

function git_error_set_str(error_class: cint; const str: PChar): cint; cdecl;
begin
  Result := static_git_error_set_str(error_class, str);
end;

function git_status_list_new(out status_list: git_status_list; repo: git_repository; const opts: Pointer): cint; cdecl;
begin
  Result := static_git_status_list_new(status_list, repo, opts);
end;

function git_status_list_entrycount(status_list: git_status_list): csize_t; cdecl;
begin
  Result := static_git_status_list_entrycount(status_list);
end;

  function git_status_foreach(repo: git_repository; cb: git_status_cb; payload: Pointer): cint; cdecl;
begin
  Result := static_git_status_foreach(repo, cb, payload);
end;

procedure git_status_list_free(status_list: git_status_list); cdecl;
begin
  static_git_status_list_free(status_list);
end;

function git_repository_index(out index: git_index; repo: git_repository): cint; cdecl;
begin
  Result := static_git_repository_index(index, repo);
end;

function git_index_add_bypath(index: git_index; const path: PChar): cint; cdecl;
begin
  Result := static_git_index_add_bypath(index, path);
end;

function git_index_add_all(index: git_index; const pathspec: Pgit_strarray; flags: cuint; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
begin
  Result := static_git_index_add_all(index, pathspec, flags, callback, payload);
end;

function git_index_remove_bypath(index: git_index; const path: PChar): cint; cdecl;
begin
  Result := static_git_index_remove_bypath(index, path);
end;

function git_index_update_all(index: git_index; const pathspec: Pgit_strarray; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
begin
  Result := static_git_index_update_all(index, pathspec, callback, payload);
end;

function git_index_write(index: git_index): cint; cdecl;
begin
  Result := static_git_index_write(index);
end;

function git_index_read_tree(index: git_index; tree: git_tree): cint; cdecl;
begin
  Result := static_git_index_read_tree(index, tree);
end;

function git_index_write_tree(out id: git_oid; index: git_index): cint; cdecl;
begin
  Result := static_git_index_write_tree(id, index);
end;

function git_index_write_tree_to(out id: git_oid; index: git_index; repo: git_repository): cint; cdecl;
begin
  Result := static_git_index_write_tree_to(id, index, repo);
end;

function git_index_has_conflicts(index: git_index): cint; cdecl;
begin
  Result := static_git_index_has_conflicts(index);
end;

  function git_checkout_head(repo: git_repository; const opts: Pointer): cint; cdecl;
begin
  Result := static_git_checkout_head(repo, opts);
end;

  function git_checkout_tree(repo: git_repository; tree: git_object; const opts: Pointer): cint; cdecl;
begin
  Result := static_git_checkout_tree(repo, tree, opts);
end;

procedure git_index_free(index: git_index); cdecl;
begin
  static_git_index_free(index);
end;

function git_repository_config(out cfg: git_config; repo: git_repository): cint; cdecl;
begin
  Result := static_git_repository_config(cfg, repo);
end;

function git_config_open_default(out cfg: git_config): cint; cdecl;
begin
  Result := static_git_config_open_default(cfg);
end;

function git_config_get_string(out out_value: PChar; cfg: git_config; const name: PChar): cint; cdecl;
begin
  Result := static_git_config_get_string(out_value, cfg, name);
end;

function git_config_set_string(cfg: git_config; const name: PChar; const value: PChar): cint; cdecl;
begin
  Result := static_git_config_set_string(cfg, name, value);
end;

procedure git_config_free(cfg: git_config); cdecl;
begin
  static_git_config_free(cfg);
end;

function git_config_iterator_new(out iter: git_config_iterator; cfg: git_config): cint; cdecl;
begin
  Result := static_git_config_iterator_new(iter, cfg);
end;

function git_config_next(out entry: Pgit_config_entry; iter: git_config_iterator): cint; cdecl;
begin
  Result := static_git_config_next(entry, iter);
end;

procedure git_config_entry_free(entry: Pgit_config_entry); cdecl;
begin
  static_git_config_entry_free(entry);
end;

procedure git_config_iterator_free(iter: git_config_iterator); cdecl;
begin
  static_git_config_iterator_free(iter);
end;

function git_remote_init_callbacks(opts: Pointer; version: cuint): cint; cdecl;
begin
  Result := static_git_remote_init_callbacks(opts, version);
end;

function git_fetch_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  Result := static_git_fetch_options_init(opts, version);
end;

function git_push_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  Result := static_git_push_options_init(opts, version);
end;

function git_proxy_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  Result := static_git_proxy_options_init(opts, version);
end;

function git_clone_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  Result := static_git_clone_options_init(opts, version);
end;

function git_checkout_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  Result := static_git_checkout_options_init(opts, version);
end;

function git_credential_default_new(out cred: Pointer): cint; cdecl;
begin
  Result := static_git_credential_default_new(cred);
end;

function git_credential_userpass_plaintext_new(out cred: Pointer; const username, password: PChar): cint; cdecl;
begin
  Result := static_git_credential_userpass_plaintext_new(cred, username, password);
end;

function git_credential_username_new(out cred: Pointer; const username: PChar): cint; cdecl;
begin
  Result := static_git_credential_username_new(cred, username);
end;

function git_credential_ssh_key_from_agent(out cred: Pointer; const username: PChar): cint; cdecl;
begin
  Result := static_git_credential_ssh_key_from_agent(cred, username);
end;

function git_signature_new(out sig: git_signature; const name: PChar; const email: PChar; time: git_time_t; offset: cint): cint; cdecl;
begin
  Result := static_git_signature_new(sig, name, email, time, offset);
end;

function git_signature_now(out sig: git_signature; const name: PChar; const email: PChar): cint; cdecl;
begin
  Result := static_git_signature_now(sig, name, email);
end;

procedure git_signature_free(sig: git_signature); cdecl;
begin
  static_git_signature_free(sig);
end;

procedure git_strarray_free(arr: Pgit_strarray); cdecl;
begin
  static_git_strarray_free(arr);
end;

procedure git_buf_dispose(buffer: Pgit_buf); cdecl;
begin
  static_git_buf_dispose(buffer);
end;

function git_worktree_add(out wt: git_worktree; repo: git_repository;
  const name: PChar; const path: PChar;
  const opts: Pgit_worktree_add_options): cint; cdecl;
begin
  Result := static_git_worktree_add(wt, repo, name, path, opts);
end;

function git_worktree_lookup(out wt: git_worktree; repo: git_repository;
  const name: PChar): cint; cdecl;
begin
  Result := static_git_worktree_lookup(wt, repo, name);
end;

function git_worktree_list(out list: git_strarray;
  repo: git_repository): cint; cdecl;
begin
  Result := static_git_worktree_list(list, repo);
end;

function git_worktree_name(wt: git_worktree): PChar; cdecl;
begin
  Result := static_git_worktree_name(wt);
end;

function git_worktree_path(wt: git_worktree): PChar; cdecl;
begin
  Result := static_git_worktree_path(wt);
end;

function git_worktree_is_locked(reason: Pgit_buf; wt: git_worktree): cint; cdecl;
begin
  Result := static_git_worktree_is_locked(reason, wt);
end;

function git_worktree_prune(wt: git_worktree;
  const opts: Pgit_worktree_prune_options): cint; cdecl;
begin
  Result := static_git_worktree_prune(wt, opts);
end;

function git_worktree_add_options_init(
  opts: Pgit_worktree_add_options; version: cuint): cint; cdecl;
begin
  Result := static_git_worktree_add_options_init(opts, version);
end;

function git_worktree_prune_options_init(
  opts: Pgit_worktree_prune_options; version: cuint): cint; cdecl;
begin
  Result := static_git_worktree_prune_options_init(opts, version);
end;

procedure git_worktree_free(wt: git_worktree); cdecl;
begin
  static_git_worktree_free(wt);
end;


end.

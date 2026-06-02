unit nextpas.core.git.libgit2.binding;

{$I nextpas.core.settings.inc}
// acq:allow-style-file

interface

{$IFDEF NEXTPAS_CORE_GIT_LIBGIT2_STATIC}
  {$IFDEF DARWIN}
  {$linklib git2}
  {$ENDIF}
{$ENDIF}

uses
  ctypes,
  nextpas.core.git.libgit2.ffi;

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
function git_reference_lookup(out reference: git_reference; repo: git_repository; const name: PChar): cint; cdecl;
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
function git_oid_fmt(out str: PChar; const id: Pgit_oid): cint; cdecl;
function git_oid_cmp(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
function git_oid_equal(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
function git_oid_iszero(const id: Pgit_oid): cint; cdecl;

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

implementation

uses
  SysUtils
  {$IFNDEF NEXTPAS_CORE_GIT_LIBGIT2_STATIC}
  , Dynlibs
  {$ENDIF}
  ;

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
  TLibGit2_git_repository_free = procedure(repo: git_repository); cdecl;
  TLibGit2_git_clone = function(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl;
  TLibGit2_git_remote_lookup = function(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl;
  TLibGit2_git_remote_fetch = function(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl;
  TLibGit2_git_remote_push = function(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl;
  TLibGit2_git_remote_list = function(out out_list: git_strarray; repo: git_repository): cint; cdecl;
  TLibGit2_git_remote_url = function(remote: git_remote): PChar; cdecl;
  TLibGit2_git_remote_name = function(remote: git_remote): PChar; cdecl;
  TLibGit2_git_remote_free = procedure(remote: git_remote); cdecl;
  TLibGit2_git_reference_lookup = function(out reference: git_reference; repo: git_repository; const name: PChar): cint; cdecl;
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
  TLibGit2_git_oid_fmt = function(out str: PChar; const id: Pgit_oid): cint; cdecl;
  TLibGit2_git_oid_cmp = function(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
  TLibGit2_git_oid_equal = function(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
  TLibGit2_git_oid_iszero = function(const id: Pgit_oid): cint; cdecl;
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

{$IFDEF NEXTPAS_CORE_GIT_LIBGIT2_STATIC}
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
procedure static_git_repository_free(repo: git_repository); cdecl; external LIBGIT2_LIB name 'git_repository_free';
function static_git_clone(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_clone';
function static_git_remote_lookup(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_remote_lookup';
function static_git_remote_fetch(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_remote_fetch';
function static_git_remote_push(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB name 'git_remote_push';
function static_git_remote_list(out out_list: git_strarray; repo: git_repository): cint; cdecl; external LIBGIT2_LIB name 'git_remote_list';
function static_git_remote_url(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB name 'git_remote_url';
function static_git_remote_name(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB name 'git_remote_name';
procedure static_git_remote_free(remote: git_remote); cdecl; external LIBGIT2_LIB name 'git_remote_free';
function static_git_reference_lookup(out reference: git_reference; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB name 'git_reference_lookup';
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

function git_reference_lookup(out reference: git_reference; repo: git_repository; const name: PChar): cint; cdecl;
begin
  Result := static_git_reference_lookup(reference, repo, name);
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

{$ELSE}
var
  GLibGit2Handle: TLibHandle = NilHandle;
  GLibGit2Loaded: Boolean = False;
  GLibGit2LoadedPath: string = '';
  GLibGit2Lock: TRTLCriticalSection;
  dyn_git_libgit2_init: TLibGit2_git_libgit2_init = nil;
  dyn_git_libgit2_shutdown: TLibGit2_git_libgit2_shutdown = nil;
  dyn_git_libgit2_version: TLibGit2_git_libgit2_version = nil;
  dyn_git_repository_open: TLibGit2_git_repository_open = nil;
  dyn_git_repository_init: TLibGit2_git_repository_init = nil;
  dyn_git_repository_discover: TLibGit2_git_repository_discover = nil;
  dyn_git_repository_head: TLibGit2_git_repository_head = nil;
  dyn_git_repository_is_bare: TLibGit2_git_repository_is_bare = nil;
  dyn_git_repository_is_empty: TLibGit2_git_repository_is_empty = nil;
  dyn_git_repository_path: TLibGit2_git_repository_path = nil;
  dyn_git_repository_workdir: TLibGit2_git_repository_workdir = nil;
  dyn_git_repository_set_head: TLibGit2_git_repository_set_head = nil;
  dyn_git_repository_set_head_detached: TLibGit2_git_repository_set_head_detached = nil;
  dyn_git_repository_free: TLibGit2_git_repository_free = nil;
  dyn_git_clone: TLibGit2_git_clone = nil;
  dyn_git_remote_lookup: TLibGit2_git_remote_lookup = nil;
  dyn_git_remote_fetch: TLibGit2_git_remote_fetch = nil;
  dyn_git_remote_push: TLibGit2_git_remote_push = nil;
  dyn_git_remote_list: TLibGit2_git_remote_list = nil;
  dyn_git_remote_url: TLibGit2_git_remote_url = nil;
  dyn_git_remote_name: TLibGit2_git_remote_name = nil;
  dyn_git_remote_free: TLibGit2_git_remote_free = nil;
  dyn_git_reference_lookup: TLibGit2_git_reference_lookup = nil;
  dyn_git_reference_name: TLibGit2_git_reference_name = nil;
  dyn_git_reference_target: TLibGit2_git_reference_target = nil;
  dyn_git_reference_symbolic_target: TLibGit2_git_reference_symbolic_target = nil;
  dyn_git_reference_type: TLibGit2_git_reference_type = nil;
  dyn_git_reference_set_target: TLibGit2_git_reference_set_target = nil;
  dyn_git_reference_free: TLibGit2_git_reference_free = nil;
  dyn_git_graph_ahead_behind: TLibGit2_git_graph_ahead_behind = nil;
  dyn_git_merge_commits: TLibGit2_git_merge_commits = nil;
  dyn_git_branch_create: TLibGit2_git_branch_create = nil;
  dyn_git_branch_delete: TLibGit2_git_branch_delete = nil;
  dyn_git_branch_iterator_new: TLibGit2_git_branch_iterator_new = nil;
  dyn_git_branch_next: TLibGit2_git_branch_next = nil;
  dyn_git_branch_iterator_free: TLibGit2_git_branch_iterator_free = nil;
  dyn_git_object_lookup: TLibGit2_git_object_lookup = nil;
  dyn_git_object_id: TLibGit2_git_object_id = nil;
  dyn_git_object_type: TLibGit2_git_object_type = nil;
  dyn_git_object_peel: TLibGit2_git_object_peel = nil;
  dyn_git_object_free: TLibGit2_git_object_free = nil;
  dyn_git_tree_lookup: TLibGit2_git_tree_lookup = nil;
  dyn_git_commit_lookup: TLibGit2_git_commit_lookup = nil;
  dyn_git_commit_message: TLibGit2_git_commit_message = nil;
  dyn_git_commit_author: TLibGit2_git_commit_author = nil;
  dyn_git_commit_committer: TLibGit2_git_commit_committer = nil;
  dyn_git_commit_time: TLibGit2_git_commit_time = nil;
  dyn_git_commit_parentcount: TLibGit2_git_commit_parentcount = nil;
  dyn_git_commit_tree: TLibGit2_git_commit_tree = nil;
  dyn_git_commit_create: TLibGit2_git_commit_create = nil;
  dyn_git_oid_fromstr: TLibGit2_git_oid_fromstr = nil;
  dyn_git_oid_tostr: TLibGit2_git_oid_tostr = nil;
  dyn_git_oid_fmt: TLibGit2_git_oid_fmt = nil;
  dyn_git_oid_cmp: TLibGit2_git_oid_cmp = nil;
  dyn_git_oid_equal: TLibGit2_git_oid_equal = nil;
  dyn_git_oid_iszero: TLibGit2_git_oid_iszero = nil;
  dyn_git_error_last: TLibGit2_git_error_last = nil;
  dyn_git_error_clear: TLibGit2_git_error_clear = nil;
  dyn_git_error_set_str: TLibGit2_git_error_set_str = nil;
  dyn_git_status_list_new: TLibGit2_git_status_list_new = nil;
  dyn_git_status_list_entrycount: TLibGit2_git_status_list_entrycount = nil;
  dyn_git_status_foreach: TLibGit2_git_status_foreach = nil;
  dyn_git_status_list_free: TLibGit2_git_status_list_free = nil;
  dyn_git_repository_index: TLibGit2_git_repository_index = nil;
  dyn_git_index_add_bypath: TLibGit2_git_index_add_bypath = nil;
  dyn_git_index_add_all: TLibGit2_git_index_add_all = nil;
  dyn_git_index_remove_bypath: TLibGit2_git_index_remove_bypath = nil;
  dyn_git_index_update_all: TLibGit2_git_index_update_all = nil;
  dyn_git_index_write: TLibGit2_git_index_write = nil;
  dyn_git_index_read_tree: TLibGit2_git_index_read_tree = nil;
  dyn_git_index_write_tree: TLibGit2_git_index_write_tree = nil;
  dyn_git_index_write_tree_to: TLibGit2_git_index_write_tree_to = nil;
  dyn_git_index_has_conflicts: TLibGit2_git_index_has_conflicts = nil;
  dyn_git_checkout_head: TLibGit2_git_checkout_head = nil;
  dyn_git_checkout_tree: TLibGit2_git_checkout_tree = nil;
  dyn_git_index_free: TLibGit2_git_index_free = nil;
  dyn_git_repository_config: TLibGit2_git_repository_config = nil;
  dyn_git_config_open_default: TLibGit2_git_config_open_default = nil;
  dyn_git_config_get_string: TLibGit2_git_config_get_string = nil;
  dyn_git_config_set_string: TLibGit2_git_config_set_string = nil;
  dyn_git_config_free: TLibGit2_git_config_free = nil;
  dyn_git_remote_init_callbacks: TLibGit2_git_remote_init_callbacks = nil;
  dyn_git_fetch_options_init: TLibGit2_git_fetch_options_init = nil;
  dyn_git_push_options_init: TLibGit2_git_push_options_init = nil;
  dyn_git_proxy_options_init: TLibGit2_git_proxy_options_init = nil;
  dyn_git_clone_options_init: TLibGit2_git_clone_options_init = nil;
  dyn_git_checkout_options_init: TLibGit2_git_checkout_options_init = nil;
  dyn_git_credential_default_new: TLibGit2_git_credential_default_new = nil;
  dyn_git_credential_userpass_plaintext_new: TLibGit2_git_credential_userpass_plaintext_new = nil;
  dyn_git_credential_username_new: TLibGit2_git_credential_username_new = nil;
  dyn_git_credential_ssh_key_from_agent: TLibGit2_git_credential_ssh_key_from_agent = nil;
  dyn_git_signature_new: TLibGit2_git_signature_new = nil;
  dyn_git_signature_now: TLibGit2_git_signature_now = nil;
  dyn_git_signature_free: TLibGit2_git_signature_free = nil;
  dyn_git_strarray_free: TLibGit2_git_strarray_free = nil;
  dyn_git_buf_dispose: TLibGit2_git_buf_dispose = nil;

{$IFDEF NEXTPAS_UNIX}
function c_getenv(name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';
{$ENDIF}

function ReadProcessEnv(const AName: string): string;
var
  LName: string;
  {$IFDEF NEXTPAS_UNIX}
  LValue: PAnsiChar;
  {$ENDIF}
begin
  LName := AName;
  {$IFDEF NEXTPAS_UNIX}
  LValue := c_getenv(PAnsiChar(LName));
  if LValue <> nil then
    Result := string(LValue)
  else
    Result := '';
  {$ELSE}
  Result := GetEnvironmentVariable(LName);
  {$ENDIF}
end;

procedure ClearLibGit2Symbols;
begin
  dyn_git_libgit2_init := nil;
  dyn_git_libgit2_shutdown := nil;
  dyn_git_libgit2_version := nil;
  dyn_git_repository_open := nil;
  dyn_git_repository_init := nil;
  dyn_git_repository_discover := nil;
  dyn_git_repository_head := nil;
  dyn_git_repository_is_bare := nil;
  dyn_git_repository_is_empty := nil;
  dyn_git_repository_path := nil;
  dyn_git_repository_workdir := nil;
  dyn_git_repository_set_head := nil;
  dyn_git_repository_set_head_detached := nil;
  dyn_git_repository_free := nil;
  dyn_git_clone := nil;
  dyn_git_remote_lookup := nil;
  dyn_git_remote_fetch := nil;
  dyn_git_remote_push := nil;
  dyn_git_remote_list := nil;
  dyn_git_remote_url := nil;
  dyn_git_remote_name := nil;
  dyn_git_remote_free := nil;
  dyn_git_reference_lookup := nil;
  dyn_git_reference_name := nil;
  dyn_git_reference_target := nil;
  dyn_git_reference_symbolic_target := nil;
  dyn_git_reference_type := nil;
  dyn_git_reference_set_target := nil;
  dyn_git_reference_free := nil;
  dyn_git_graph_ahead_behind := nil;
  dyn_git_merge_commits := nil;
  dyn_git_branch_create := nil;
  dyn_git_branch_delete := nil;
  dyn_git_branch_iterator_new := nil;
  dyn_git_branch_next := nil;
  dyn_git_branch_iterator_free := nil;
  dyn_git_object_lookup := nil;
  dyn_git_object_id := nil;
  dyn_git_object_type := nil;
  dyn_git_object_peel := nil;
  dyn_git_object_free := nil;
  dyn_git_tree_lookup := nil;
  dyn_git_commit_lookup := nil;
  dyn_git_commit_message := nil;
  dyn_git_commit_author := nil;
  dyn_git_commit_committer := nil;
  dyn_git_commit_time := nil;
  dyn_git_commit_parentcount := nil;
  dyn_git_commit_tree := nil;
  dyn_git_commit_create := nil;
  dyn_git_oid_fromstr := nil;
  dyn_git_oid_tostr := nil;
  dyn_git_oid_fmt := nil;
  dyn_git_oid_cmp := nil;
  dyn_git_oid_equal := nil;
  dyn_git_oid_iszero := nil;
  dyn_git_error_last := nil;
  dyn_git_error_clear := nil;
  dyn_git_error_set_str := nil;
  dyn_git_status_list_new := nil;
  dyn_git_status_list_entrycount := nil;
  dyn_git_status_foreach := nil;
  dyn_git_status_list_free := nil;
  dyn_git_repository_index := nil;
  dyn_git_index_add_bypath := nil;
  dyn_git_index_add_all := nil;
  dyn_git_index_remove_bypath := nil;
  dyn_git_index_update_all := nil;
  dyn_git_index_write := nil;
  dyn_git_index_read_tree := nil;
  dyn_git_index_write_tree := nil;
  dyn_git_index_write_tree_to := nil;
  dyn_git_index_has_conflicts := nil;
  dyn_git_checkout_head := nil;
  dyn_git_checkout_tree := nil;
  dyn_git_index_free := nil;
  dyn_git_repository_config := nil;
  dyn_git_config_open_default := nil;
  dyn_git_config_get_string := nil;
  dyn_git_config_set_string := nil;
  dyn_git_config_free := nil;
  dyn_git_remote_init_callbacks := nil;
  dyn_git_fetch_options_init := nil;
  dyn_git_push_options_init := nil;
  dyn_git_proxy_options_init := nil;
  dyn_git_clone_options_init := nil;
  dyn_git_checkout_options_init := nil;
  dyn_git_credential_default_new := nil;
  dyn_git_credential_userpass_plaintext_new := nil;
  dyn_git_credential_username_new := nil;
  dyn_git_credential_ssh_key_from_agent := nil;
  dyn_git_signature_new := nil;
  dyn_git_signature_now := nil;
  dyn_git_signature_free := nil;
  dyn_git_strarray_free := nil;
  dyn_git_buf_dispose := nil;
end;

procedure ResetLibGit2LoaderState;
begin
  ClearLibGit2Symbols;
  GLibGit2Loaded := False;
  GLibGit2LoadedPath := '';
  if GLibGit2Handle <> NilHandle then
  begin
    FreeLibrary(GLibGit2Handle);
    GLibGit2Handle := NilHandle;
  end;
end;

function TryResolveCoreLibGit2Symbols: Boolean;
begin
  Pointer(dyn_git_libgit2_init) := GetProcedureAddress(GLibGit2Handle, 'git_libgit2_init');
  Pointer(dyn_git_libgit2_shutdown) := GetProcedureAddress(GLibGit2Handle, 'git_libgit2_shutdown');
  Pointer(dyn_git_libgit2_version) := GetProcedureAddress(GLibGit2Handle, 'git_libgit2_version');
  Result := Assigned(dyn_git_libgit2_init) and
            Assigned(dyn_git_libgit2_shutdown) and
            Assigned(dyn_git_libgit2_version);
end;

function TryLoadLibGit2FromPath(const APath: string): Boolean;
var
  LHandle: TLibHandle;
begin
  Result := False;
  if APath = '' then
    Exit;

  LHandle := LoadLibrary(PChar(APath));
  if LHandle = NilHandle then
    Exit;

  GLibGit2Handle := LHandle;
  GLibGit2LoadedPath := APath;
  if not TryResolveCoreLibGit2Symbols then
  begin
    ResetLibGit2LoaderState;
    Exit(False);
  end;

  GLibGit2Loaded := True;
  Result := True;
end;

function TryLoadLibGit2FromCandidates: Boolean;
const
  {$IFDEF MSWINDOWS}
  CANDIDATES: array[0..1] of string = ('git2.dll', 'libgit2.dll');
  {$ELSEIF defined(DARWIN)}
  CANDIDATES: array[0..2] of string = ('libgit2.1.dylib', 'libgit2.dylib', 'git2');
  {$ELSE}
  CANDIDATES: array[0..6] of string = ('libgit2.so', 'libgit2.so.1.9', 'libgit2.so.1.8', 'libgit2.so.1.7', 'libgit2.so.1.6', 'libgit2.so.1.5', 'git2');
  {$ENDIF}
var
  I: Integer;
begin
  Result := False;
  for I := Low(CANDIDATES) to High(CANDIDATES) do
  begin
    if TryLoadLibGit2FromPath(CANDIDATES[I]) then
      Exit(True);
  end;
end;

function EnsureLibGit2Loaded: Boolean;
var
  LOverridePath: string;
begin
  if GLibGit2Loaded then
    Exit(True);

  EnterCriticalSection(GLibGit2Lock);
  try
    if GLibGit2Loaded then
      Exit(True);

    LOverridePath := ReadProcessEnv(LIBGIT2_PATH_ENV);
    if LOverridePath <> '' then
      Exit(TryLoadLibGit2FromPath(LOverridePath));

    Result := TryLoadLibGit2FromCandidates;
  finally
    LeaveCriticalSection(GLibGit2Lock);
  end;
end;

function IsLibGit2Loaded: Boolean;
begin
  EnterCriticalSection(GLibGit2Lock);
  try
    Result := GLibGit2Loaded;
  finally
    LeaveCriticalSection(GLibGit2Lock);
  end;
end;

function GetLibGit2LoadedPath: string;
begin
  EnterCriticalSection(GLibGit2Lock);
  try
    Result := GLibGit2LoadedPath;
  finally
    LeaveCriticalSection(GLibGit2Lock);
  end;
end;

function ResolveLibGit2Symbol(const AName: string): Pointer;
begin
  if not EnsureLibGit2Loaded then
    raise Exception.Create('libgit2 is not available');

  Result := GetProcedureAddress(GLibGit2Handle, PChar(AName));
  if Result = nil then
    raise Exception.Create('libgit2 symbol not available: ' + AName);
end;

function git_libgit2_init: cint; cdecl;
begin
  if not Assigned(dyn_git_libgit2_init) then
    Pointer(dyn_git_libgit2_init) := ResolveLibGit2Symbol('git_libgit2_init');
  Result := dyn_git_libgit2_init();
end;

function git_libgit2_shutdown: cint; cdecl;
begin
  if not Assigned(dyn_git_libgit2_shutdown) then
    Pointer(dyn_git_libgit2_shutdown) := ResolveLibGit2Symbol('git_libgit2_shutdown');
  Result := dyn_git_libgit2_shutdown();
end;

function git_libgit2_version(major, minor, rev: Pcint): cint; cdecl;
begin
  if not Assigned(dyn_git_libgit2_version) then
    Pointer(dyn_git_libgit2_version) := ResolveLibGit2Symbol('git_libgit2_version');
  Result := dyn_git_libgit2_version(major, minor, rev);
end;

function git_repository_open(out repo: git_repository; const path: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_open) then
    Pointer(dyn_git_repository_open) := ResolveLibGit2Symbol('git_repository_open');
  Result := dyn_git_repository_open(repo, path);
end;

function git_repository_init(out repo: git_repository; const path: PChar; is_bare: cuint): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_init) then
    Pointer(dyn_git_repository_init) := ResolveLibGit2Symbol('git_repository_init');
  Result := dyn_git_repository_init(repo, path, is_bare);
end;

function git_repository_discover(out out_buf: git_buf; const start_path: PChar; across_fs: cint; const ceiling_dirs: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_discover) then
    Pointer(dyn_git_repository_discover) := ResolveLibGit2Symbol('git_repository_discover');
  Result := dyn_git_repository_discover(out_buf, start_path, across_fs, ceiling_dirs);
end;

function git_repository_head(out head_ref: git_reference; repo: git_repository): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_head) then
    Pointer(dyn_git_repository_head) := ResolveLibGit2Symbol('git_repository_head');
  Result := dyn_git_repository_head(head_ref, repo);
end;

function git_repository_is_bare(repo: git_repository): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_is_bare) then
    Pointer(dyn_git_repository_is_bare) := ResolveLibGit2Symbol('git_repository_is_bare');
  Result := dyn_git_repository_is_bare(repo);
end;

function git_repository_is_empty(repo: git_repository): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_is_empty) then
    Pointer(dyn_git_repository_is_empty) := ResolveLibGit2Symbol('git_repository_is_empty');
  Result := dyn_git_repository_is_empty(repo);
end;

function git_repository_path(repo: git_repository): PChar; cdecl;
begin
  if not Assigned(dyn_git_repository_path) then
    Pointer(dyn_git_repository_path) := ResolveLibGit2Symbol('git_repository_path');
  Result := dyn_git_repository_path(repo);
end;

function git_repository_workdir(repo: git_repository): PChar; cdecl;
begin
  if not Assigned(dyn_git_repository_workdir) then
    Pointer(dyn_git_repository_workdir) := ResolveLibGit2Symbol('git_repository_workdir');
  Result := dyn_git_repository_workdir(repo);
end;

function git_repository_set_head(repo: git_repository; const refname: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_set_head) then
    Pointer(dyn_git_repository_set_head) := ResolveLibGit2Symbol('git_repository_set_head');
  Result := dyn_git_repository_set_head(repo, refname);
end;

function git_repository_set_head_detached(repo: git_repository; const commitish: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_set_head_detached) then
    Pointer(dyn_git_repository_set_head_detached) := ResolveLibGit2Symbol('git_repository_set_head_detached');
  Result := dyn_git_repository_set_head_detached(repo, commitish);
end;

procedure git_repository_free(repo: git_repository); cdecl;
begin
  if not Assigned(dyn_git_repository_free) then
    Pointer(dyn_git_repository_free) := ResolveLibGit2Symbol('git_repository_free');
  dyn_git_repository_free(repo);
end;

function git_clone(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_clone) then
    Pointer(dyn_git_clone) := ResolveLibGit2Symbol('git_clone');
  Result := dyn_git_clone(repo, url, local_path, options);
end;

function git_remote_lookup(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_remote_lookup) then
    Pointer(dyn_git_remote_lookup) := ResolveLibGit2Symbol('git_remote_lookup');
  Result := dyn_git_remote_lookup(remote, repo, name);
end;

function git_remote_fetch(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_remote_fetch) then
    Pointer(dyn_git_remote_fetch) := ResolveLibGit2Symbol('git_remote_fetch');
  Result := dyn_git_remote_fetch(remote, refspecs, opts, reflog_message);
end;

function git_remote_push(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_remote_push) then
    Pointer(dyn_git_remote_push) := ResolveLibGit2Symbol('git_remote_push');
  Result := dyn_git_remote_push(remote, refspecs, opts);
end;

function git_remote_list(out out_list: git_strarray; repo: git_repository): cint; cdecl;
begin
  if not Assigned(dyn_git_remote_list) then
    Pointer(dyn_git_remote_list) := ResolveLibGit2Symbol('git_remote_list');
  Result := dyn_git_remote_list(out_list, repo);
end;

function git_remote_url(remote: git_remote): PChar; cdecl;
begin
  if not Assigned(dyn_git_remote_url) then
    Pointer(dyn_git_remote_url) := ResolveLibGit2Symbol('git_remote_url');
  Result := dyn_git_remote_url(remote);
end;

function git_remote_name(remote: git_remote): PChar; cdecl;
begin
  if not Assigned(dyn_git_remote_name) then
    Pointer(dyn_git_remote_name) := ResolveLibGit2Symbol('git_remote_name');
  Result := dyn_git_remote_name(remote);
end;

procedure git_remote_free(remote: git_remote); cdecl;
begin
  if not Assigned(dyn_git_remote_free) then
    Pointer(dyn_git_remote_free) := ResolveLibGit2Symbol('git_remote_free');
  dyn_git_remote_free(remote);
end;

function git_reference_lookup(out reference: git_reference; repo: git_repository; const name: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_reference_lookup) then
    Pointer(dyn_git_reference_lookup) := ResolveLibGit2Symbol('git_reference_lookup');
  Result := dyn_git_reference_lookup(reference, repo, name);
end;

function git_reference_name(ref: git_reference): PChar; cdecl;
begin
  if not Assigned(dyn_git_reference_name) then
    Pointer(dyn_git_reference_name) := ResolveLibGit2Symbol('git_reference_name');
  Result := dyn_git_reference_name(ref);
end;

function git_reference_target(ref: git_reference): Pgit_oid; cdecl;
begin
  if not Assigned(dyn_git_reference_target) then
    Pointer(dyn_git_reference_target) := ResolveLibGit2Symbol('git_reference_target');
  Result := dyn_git_reference_target(ref);
end;

function git_reference_symbolic_target(ref: git_reference): PChar; cdecl;
begin
  if not Assigned(dyn_git_reference_symbolic_target) then
    Pointer(dyn_git_reference_symbolic_target) := ResolveLibGit2Symbol('git_reference_symbolic_target');
  Result := dyn_git_reference_symbolic_target(ref);
end;

function git_reference_type(ref: git_reference): git_reference_t; cdecl;
begin
  if not Assigned(dyn_git_reference_type) then
    Pointer(dyn_git_reference_type) := ResolveLibGit2Symbol('git_reference_type');
  Result := dyn_git_reference_type(ref);
end;

function git_reference_set_target(out out_ref: git_reference; ref: git_reference; const id: Pgit_oid; const log_message: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_reference_set_target) then
    Pointer(dyn_git_reference_set_target) := ResolveLibGit2Symbol('git_reference_set_target');
  Result := dyn_git_reference_set_target(out_ref, ref, id, log_message);
end;

procedure git_reference_free(ref: git_reference); cdecl;
begin
  if not Assigned(dyn_git_reference_free) then
    Pointer(dyn_git_reference_free) := ResolveLibGit2Symbol('git_reference_free');
  dyn_git_reference_free(ref);
end;

function git_graph_ahead_behind(out ahead: csize_t; out behind: csize_t; repo: git_repository;
  const local: Pgit_oid; const upstream: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_graph_ahead_behind) then
    Pointer(dyn_git_graph_ahead_behind) := ResolveLibGit2Symbol('git_graph_ahead_behind');
  Result := dyn_git_graph_ahead_behind(ahead, behind, repo, local, upstream);
end;

function git_merge_commits(out out_index: git_index; repo: git_repository; our_commit: git_commit; their_commit: git_commit;
  const opts: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_merge_commits) then
    Pointer(dyn_git_merge_commits) := ResolveLibGit2Symbol('git_merge_commits');
  Result := dyn_git_merge_commits(out_index, repo, our_commit, their_commit, opts);
end;

function git_branch_create(out ref_out: git_reference; repo: git_repository; const branch_name: PChar; target: git_commit; force: cint): cint; cdecl;
begin
  if not Assigned(dyn_git_branch_create) then
    Pointer(dyn_git_branch_create) := ResolveLibGit2Symbol('git_branch_create');
  Result := dyn_git_branch_create(ref_out, repo, branch_name, target, force);
end;

function git_branch_delete(branch: git_reference): cint; cdecl;
begin
  if not Assigned(dyn_git_branch_delete) then
    Pointer(dyn_git_branch_delete) := ResolveLibGit2Symbol('git_branch_delete');
  Result := dyn_git_branch_delete(branch);
end;

function git_branch_iterator_new(out iter: git_branch_iterator; repo: git_repository; list_flags: git_branch_t): cint; cdecl;
begin
  if not Assigned(dyn_git_branch_iterator_new) then
    Pointer(dyn_git_branch_iterator_new) := ResolveLibGit2Symbol('git_branch_iterator_new');
  Result := dyn_git_branch_iterator_new(iter, repo, list_flags);
end;

function git_branch_next(out ref_out: git_reference; out branch_type: git_branch_t; iter: git_branch_iterator): cint; cdecl;
begin
  if not Assigned(dyn_git_branch_next) then
    Pointer(dyn_git_branch_next) := ResolveLibGit2Symbol('git_branch_next');
  Result := dyn_git_branch_next(ref_out, branch_type, iter);
end;

procedure git_branch_iterator_free(iter: git_branch_iterator); cdecl;
begin
  if not Assigned(dyn_git_branch_iterator_free) then
    Pointer(dyn_git_branch_iterator_free) := ResolveLibGit2Symbol('git_branch_iterator_free');
  dyn_git_branch_iterator_free(iter);
end;

function git_object_lookup(out obj: git_object; repo: git_repository; const id: Pgit_oid; obj_type: git_object_t): cint; cdecl;
begin
  if not Assigned(dyn_git_object_lookup) then
    Pointer(dyn_git_object_lookup) := ResolveLibGit2Symbol('git_object_lookup');
  Result := dyn_git_object_lookup(obj, repo, id, obj_type);
end;

function git_object_id(obj: git_object): Pgit_oid; cdecl;
begin
  if not Assigned(dyn_git_object_id) then
    Pointer(dyn_git_object_id) := ResolveLibGit2Symbol('git_object_id');
  Result := dyn_git_object_id(obj);
end;

function git_object_type(obj: git_object): git_object_t; cdecl;
begin
  if not Assigned(dyn_git_object_type) then
    Pointer(dyn_git_object_type) := ResolveLibGit2Symbol('git_object_type');
  Result := dyn_git_object_type(obj);
end;

function git_object_peel(out peeled: git_object; obj: git_object; target_type: git_object_t): cint; cdecl;
begin
  if not Assigned(dyn_git_object_peel) then
    Pointer(dyn_git_object_peel) := ResolveLibGit2Symbol('git_object_peel');
  Result := dyn_git_object_peel(peeled, obj, target_type);
end;

procedure git_object_free(obj: git_object); cdecl;
begin
  if not Assigned(dyn_git_object_free) then
    Pointer(dyn_git_object_free) := ResolveLibGit2Symbol('git_object_free');
  dyn_git_object_free(obj);
end;

function git_tree_lookup(out tree: git_tree; repo: git_repository; const id: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_tree_lookup) then
    Pointer(dyn_git_tree_lookup) := ResolveLibGit2Symbol('git_tree_lookup');
  Result := dyn_git_tree_lookup(tree, repo, id);
end;

function git_commit_lookup(out commit: git_commit; repo: git_repository; const id: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_commit_lookup) then
    Pointer(dyn_git_commit_lookup) := ResolveLibGit2Symbol('git_commit_lookup');
  Result := dyn_git_commit_lookup(commit, repo, id);
end;

function git_commit_message(commit: git_commit): PChar; cdecl;
begin
  if not Assigned(dyn_git_commit_message) then
    Pointer(dyn_git_commit_message) := ResolveLibGit2Symbol('git_commit_message');
  Result := dyn_git_commit_message(commit);
end;

function git_commit_author(commit: git_commit): Pgit_signature_t; cdecl;
begin
  if not Assigned(dyn_git_commit_author) then
    Pointer(dyn_git_commit_author) := ResolveLibGit2Symbol('git_commit_author');
  Result := dyn_git_commit_author(commit);
end;

function git_commit_committer(commit: git_commit): Pgit_signature_t; cdecl;
begin
  if not Assigned(dyn_git_commit_committer) then
    Pointer(dyn_git_commit_committer) := ResolveLibGit2Symbol('git_commit_committer');
  Result := dyn_git_commit_committer(commit);
end;

function git_commit_time(commit: git_commit): git_time_t; cdecl;
begin
  if not Assigned(dyn_git_commit_time) then
    Pointer(dyn_git_commit_time) := ResolveLibGit2Symbol('git_commit_time');
  Result := dyn_git_commit_time(commit);
end;

function git_commit_parentcount(commit: git_commit): cuint; cdecl;
begin
  if not Assigned(dyn_git_commit_parentcount) then
    Pointer(dyn_git_commit_parentcount) := ResolveLibGit2Symbol('git_commit_parentcount');
  Result := dyn_git_commit_parentcount(commit);
end;

function git_commit_tree(out tree: git_tree; commit: git_commit): cint; cdecl;
begin
  if not Assigned(dyn_git_commit_tree) then
    Pointer(dyn_git_commit_tree) := ResolveLibGit2Symbol('git_commit_tree');
  Result := dyn_git_commit_tree(tree, commit);
end;

function git_commit_create(out id: git_oid; repo: git_repository; const update_ref: PChar;
  author: git_signature; committer: git_signature; const message_encoding: PChar; const message: PChar;
  tree: git_tree; parent_count: csize_t; const parents: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_commit_create) then
    Pointer(dyn_git_commit_create) := ResolveLibGit2Symbol('git_commit_create');
  Result := dyn_git_commit_create(id, repo, update_ref, author, committer, message_encoding, message, tree, parent_count, parents);
end;

function git_oid_fromstr(out id: git_oid; const str: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_oid_fromstr) then
    Pointer(dyn_git_oid_fromstr) := ResolveLibGit2Symbol('git_oid_fromstr');
  Result := dyn_git_oid_fromstr(id, str);
end;

function git_oid_tostr(out str: PChar; size: csize_t; const id: Pgit_oid): PChar; cdecl;
begin
  if not Assigned(dyn_git_oid_tostr) then
    Pointer(dyn_git_oid_tostr) := ResolveLibGit2Symbol('git_oid_tostr');
  Result := dyn_git_oid_tostr(str, size, id);
end;

function git_oid_fmt(out str: PChar; const id: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_oid_fmt) then
    Pointer(dyn_git_oid_fmt) := ResolveLibGit2Symbol('git_oid_fmt');
  Result := dyn_git_oid_fmt(str, id);
end;

function git_oid_cmp(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_oid_cmp) then
    Pointer(dyn_git_oid_cmp) := ResolveLibGit2Symbol('git_oid_cmp');
  Result := dyn_git_oid_cmp(a, b);
end;

function git_oid_equal(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_oid_equal) then
    Pointer(dyn_git_oid_equal) := ResolveLibGit2Symbol('git_oid_equal');
  Result := dyn_git_oid_equal(a, b);
end;

function git_oid_iszero(const id: Pgit_oid): cint; cdecl;
begin
  if not Assigned(dyn_git_oid_iszero) then
    Pointer(dyn_git_oid_iszero) := ResolveLibGit2Symbol('git_oid_iszero');
  Result := dyn_git_oid_iszero(id);
end;

function git_error_last: Pgit_error_t; cdecl;
begin
  if not Assigned(dyn_git_error_last) then
    Pointer(dyn_git_error_last) := ResolveLibGit2Symbol('git_error_last');
  Result := dyn_git_error_last();
end;

procedure git_error_clear; cdecl;
begin
  if not Assigned(dyn_git_error_clear) then
    Pointer(dyn_git_error_clear) := ResolveLibGit2Symbol('git_error_clear');
  dyn_git_error_clear();
end;

function git_error_set_str(error_class: cint; const str: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_error_set_str) then
    Pointer(dyn_git_error_set_str) := ResolveLibGit2Symbol('git_error_set_str');
  Result := dyn_git_error_set_str(error_class, str);
end;

function git_status_list_new(out status_list: git_status_list; repo: git_repository; const opts: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_status_list_new) then
    Pointer(dyn_git_status_list_new) := ResolveLibGit2Symbol('git_status_list_new');
  Result := dyn_git_status_list_new(status_list, repo, opts);
end;

function git_status_list_entrycount(status_list: git_status_list): csize_t; cdecl;
begin
  if not Assigned(dyn_git_status_list_entrycount) then
    Pointer(dyn_git_status_list_entrycount) := ResolveLibGit2Symbol('git_status_list_entrycount');
  Result := dyn_git_status_list_entrycount(status_list);
end;

  function git_status_foreach(repo: git_repository; cb: git_status_cb; payload: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_status_foreach) then
    Pointer(dyn_git_status_foreach) := ResolveLibGit2Symbol('git_status_foreach');
  Result := dyn_git_status_foreach(repo, cb, payload);
end;

procedure git_status_list_free(status_list: git_status_list); cdecl;
begin
  if not Assigned(dyn_git_status_list_free) then
    Pointer(dyn_git_status_list_free) := ResolveLibGit2Symbol('git_status_list_free');
  dyn_git_status_list_free(status_list);
end;

function git_repository_index(out index: git_index; repo: git_repository): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_index) then
    Pointer(dyn_git_repository_index) := ResolveLibGit2Symbol('git_repository_index');
  Result := dyn_git_repository_index(index, repo);
end;

function git_index_add_bypath(index: git_index; const path: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_index_add_bypath) then
    Pointer(dyn_git_index_add_bypath) := ResolveLibGit2Symbol('git_index_add_bypath');
  Result := dyn_git_index_add_bypath(index, path);
end;

function git_index_add_all(index: git_index; const pathspec: Pgit_strarray; flags: cuint; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_index_add_all) then
    Pointer(dyn_git_index_add_all) := ResolveLibGit2Symbol('git_index_add_all');
  Result := dyn_git_index_add_all(index, pathspec, flags, callback, payload);
end;

function git_index_remove_bypath(index: git_index; const path: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_index_remove_bypath) then
    Pointer(dyn_git_index_remove_bypath) := ResolveLibGit2Symbol('git_index_remove_bypath');
  Result := dyn_git_index_remove_bypath(index, path);
end;

function git_index_update_all(index: git_index; const pathspec: Pgit_strarray; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_index_update_all) then
    Pointer(dyn_git_index_update_all) := ResolveLibGit2Symbol('git_index_update_all');
  Result := dyn_git_index_update_all(index, pathspec, callback, payload);
end;

function git_index_write(index: git_index): cint; cdecl;
begin
  if not Assigned(dyn_git_index_write) then
    Pointer(dyn_git_index_write) := ResolveLibGit2Symbol('git_index_write');
  Result := dyn_git_index_write(index);
end;

function git_index_read_tree(index: git_index; tree: git_tree): cint; cdecl;
begin
  if not Assigned(dyn_git_index_read_tree) then
    Pointer(dyn_git_index_read_tree) := ResolveLibGit2Symbol('git_index_read_tree');
  Result := dyn_git_index_read_tree(index, tree);
end;

function git_index_write_tree(out id: git_oid; index: git_index): cint; cdecl;
begin
  if not Assigned(dyn_git_index_write_tree) then
    Pointer(dyn_git_index_write_tree) := ResolveLibGit2Symbol('git_index_write_tree');
  Result := dyn_git_index_write_tree(id, index);
end;

function git_index_write_tree_to(out id: git_oid; index: git_index; repo: git_repository): cint; cdecl;
begin
  if not Assigned(dyn_git_index_write_tree_to) then
    Pointer(dyn_git_index_write_tree_to) := ResolveLibGit2Symbol('git_index_write_tree_to');
  Result := dyn_git_index_write_tree_to(id, index, repo);
end;

function git_index_has_conflicts(index: git_index): cint; cdecl;
begin
  if not Assigned(dyn_git_index_has_conflicts) then
    Pointer(dyn_git_index_has_conflicts) := ResolveLibGit2Symbol('git_index_has_conflicts');
  Result := dyn_git_index_has_conflicts(index);
end;

  function git_checkout_head(repo: git_repository; const opts: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_checkout_head) then
    Pointer(dyn_git_checkout_head) := ResolveLibGit2Symbol('git_checkout_head');
  Result := dyn_git_checkout_head(repo, opts);
end;

  function git_checkout_tree(repo: git_repository; tree: git_object; const opts: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_checkout_tree) then
    Pointer(dyn_git_checkout_tree) := ResolveLibGit2Symbol('git_checkout_tree');
  Result := dyn_git_checkout_tree(repo, tree, opts);
end;

procedure git_index_free(index: git_index); cdecl;
begin
  if not Assigned(dyn_git_index_free) then
    Pointer(dyn_git_index_free) := ResolveLibGit2Symbol('git_index_free');
  dyn_git_index_free(index);
end;

function git_repository_config(out cfg: git_config; repo: git_repository): cint; cdecl;
begin
  if not Assigned(dyn_git_repository_config) then
    Pointer(dyn_git_repository_config) := ResolveLibGit2Symbol('git_repository_config');
  Result := dyn_git_repository_config(cfg, repo);
end;

function git_config_open_default(out cfg: git_config): cint; cdecl;
begin
  if not Assigned(dyn_git_config_open_default) then
    Pointer(dyn_git_config_open_default) := ResolveLibGit2Symbol('git_config_open_default');
  Result := dyn_git_config_open_default(cfg);
end;

function git_config_get_string(out out_value: PChar; cfg: git_config; const name: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_config_get_string) then
    Pointer(dyn_git_config_get_string) := ResolveLibGit2Symbol('git_config_get_string');
  Result := dyn_git_config_get_string(out_value, cfg, name);
end;

function git_config_set_string(cfg: git_config; const name: PChar; const value: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_config_set_string) then
    Pointer(dyn_git_config_set_string) := ResolveLibGit2Symbol('git_config_set_string');
  Result := dyn_git_config_set_string(cfg, name, value);
end;

procedure git_config_free(cfg: git_config); cdecl;
begin
  if not Assigned(dyn_git_config_free) then
    Pointer(dyn_git_config_free) := ResolveLibGit2Symbol('git_config_free');
  dyn_git_config_free(cfg);
end;

function git_remote_init_callbacks(opts: Pointer; version: cuint): cint; cdecl;
begin
  if not Assigned(dyn_git_remote_init_callbacks) then
    Pointer(dyn_git_remote_init_callbacks) := ResolveLibGit2Symbol('git_remote_init_callbacks');
  Result := dyn_git_remote_init_callbacks(opts, version);
end;

function git_fetch_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  if not Assigned(dyn_git_fetch_options_init) then
    Pointer(dyn_git_fetch_options_init) := ResolveLibGit2Symbol('git_fetch_options_init');
  Result := dyn_git_fetch_options_init(opts, version);
end;

function git_push_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  if not Assigned(dyn_git_push_options_init) then
    Pointer(dyn_git_push_options_init) := ResolveLibGit2Symbol('git_push_options_init');
  Result := dyn_git_push_options_init(opts, version);
end;

function git_proxy_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  if not Assigned(dyn_git_proxy_options_init) then
    Pointer(dyn_git_proxy_options_init) := ResolveLibGit2Symbol('git_proxy_options_init');
  Result := dyn_git_proxy_options_init(opts, version);
end;

function git_clone_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  if not Assigned(dyn_git_clone_options_init) then
    Pointer(dyn_git_clone_options_init) := ResolveLibGit2Symbol('git_clone_options_init');
  Result := dyn_git_clone_options_init(opts, version);
end;

function git_checkout_options_init(opts: Pointer; version: cuint): cint; cdecl;
begin
  if not Assigned(dyn_git_checkout_options_init) then
    Pointer(dyn_git_checkout_options_init) := ResolveLibGit2Symbol('git_checkout_options_init');
  Result := dyn_git_checkout_options_init(opts, version);
end;

function git_credential_default_new(out cred: Pointer): cint; cdecl;
begin
  if not Assigned(dyn_git_credential_default_new) then
    Pointer(dyn_git_credential_default_new) := ResolveLibGit2Symbol('git_credential_default_new');
  Result := dyn_git_credential_default_new(cred);
end;

function git_credential_userpass_plaintext_new(out cred: Pointer; const username, password: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_credential_userpass_plaintext_new) then
    Pointer(dyn_git_credential_userpass_plaintext_new) := ResolveLibGit2Symbol('git_credential_userpass_plaintext_new');
  Result := dyn_git_credential_userpass_plaintext_new(cred, username, password);
end;

function git_credential_username_new(out cred: Pointer; const username: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_credential_username_new) then
    Pointer(dyn_git_credential_username_new) := ResolveLibGit2Symbol('git_credential_username_new');
  Result := dyn_git_credential_username_new(cred, username);
end;

function git_credential_ssh_key_from_agent(out cred: Pointer; const username: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_credential_ssh_key_from_agent) then
    Pointer(dyn_git_credential_ssh_key_from_agent) := ResolveLibGit2Symbol('git_credential_ssh_key_from_agent');
  Result := dyn_git_credential_ssh_key_from_agent(cred, username);
end;

function git_signature_new(out sig: git_signature; const name: PChar; const email: PChar; time: git_time_t; offset: cint): cint; cdecl;
begin
  if not Assigned(dyn_git_signature_new) then
    Pointer(dyn_git_signature_new) := ResolveLibGit2Symbol('git_signature_new');
  Result := dyn_git_signature_new(sig, name, email, time, offset);
end;

function git_signature_now(out sig: git_signature; const name: PChar; const email: PChar): cint; cdecl;
begin
  if not Assigned(dyn_git_signature_now) then
    Pointer(dyn_git_signature_now) := ResolveLibGit2Symbol('git_signature_now');
  Result := dyn_git_signature_now(sig, name, email);
end;

procedure git_signature_free(sig: git_signature); cdecl;
begin
  if not Assigned(dyn_git_signature_free) then
    Pointer(dyn_git_signature_free) := ResolveLibGit2Symbol('git_signature_free');
  dyn_git_signature_free(sig);
end;

procedure git_strarray_free(arr: Pgit_strarray); cdecl;
begin
  if not Assigned(dyn_git_strarray_free) then
    Pointer(dyn_git_strarray_free) := ResolveLibGit2Symbol('git_strarray_free');
  dyn_git_strarray_free(arr);
end;

procedure git_buf_dispose(buffer: Pgit_buf); cdecl;
begin
  if not Assigned(dyn_git_buf_dispose) then
    Pointer(dyn_git_buf_dispose) := ResolveLibGit2Symbol('git_buf_dispose');
  dyn_git_buf_dispose(buffer);
end;

initialization
  InitCriticalSection(GLibGit2Lock);

finalization
  EnterCriticalSection(GLibGit2Lock);
  try
    ResetLibGit2LoaderState;
  finally
    LeaveCriticalSection(GLibGit2Lock);
    DoneCriticalSection(GLibGit2Lock);
  end;
{$ENDIF}

end.

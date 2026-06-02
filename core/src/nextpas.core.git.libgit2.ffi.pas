unit nextpas.core.git.libgit2.ffi;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// acq:allow-style-file

interface

{$IFDEF DARWIN}
{$linklib git2}
{$ENDIF}

uses
ctypes;

const
  {$IFDEF MSWINDOWS}
  LIBGIT2_LIB = 'git2.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  // Prefer the unversioned soname symlink. This is the most portable option
  // across minor libgit2 versions on developer machines.
  // If runtime-only packages do not provide this, install libgit2 development files
  // or bundle libgit2 via 3rd/libgit2 as documented in docs/LIBGIT2_INTEGRATION.md.
  LIBGIT2_LIB = 'libgit2.so';
  {$ENDIF}
  {$IFDEF DARWIN}
  LIBGIT2_LIB = 'libgit2.1.dylib';
  {$ENDIF}

type
  // Basic type definitions
  // `size_t` in C is pointer-sized; this matters on Windows 64-bit (LLP64).
  csize_t = SizeUInt;
  git_time_t = cint64;
  git_off_t = cint64;

  // Forward declarations
  git_repository = Pointer;
  git_remote = Pointer;
  git_reference = Pointer;
  git_object = Pointer;
  git_commit = Pointer;
  git_tree = Pointer;
  git_blob = Pointer;
  git_tag = Pointer;
  git_index = Pointer;
  git_config = Pointer;
  git_signature = Pointer;
  git_diff = Pointer;
  git_status_list = Pointer;
  git_branch_iterator = Pointer;
  git_revwalk = Pointer;

  // Git OID (Object ID)
  git_oid = record
    id: array[0..19] of Byte;
  end;
  Pgit_oid = ^git_oid;

  git_buf = record
    ptr: PChar;
    reserved: csize_t;
    size: csize_t;
  end;
  Pgit_buf = ^git_buf;

  // String array used by various list APIs (e.g. remote listing)
  git_strarray = record
    strings: PPChar;
    count: csize_t;
  end;
  Pgit_strarray = ^git_strarray;

  // Git time structure
  git_time = record
    time: git_time_t;
    offset: cint;
    sign: cchar;
  end;
  Pgit_time = ^git_time;

  // Git signature structure
  git_signature_t = record
    name: PChar;
    email: PChar;
    when: git_time;
  end;
  Pgit_signature_t = ^git_signature_t;

  // Error handling
  git_error_t = record
    message: PChar;
    klass: cint;
  end;
  Pgit_error_t = ^git_error_t;

  // Callback function types
  git_progress_cb = function(const str: PChar; len: csize_t; payload: Pointer): cint; cdecl;
  // Per libgit2, the checkout progress callback is void (procedure)
  git_checkout_progress_cb = procedure(const path: PChar; completed_steps, total_steps: csize_t; payload: Pointer); cdecl;
  // Callback for APIs that add/remove/update files matching a pathspec
  git_index_matched_path_cb = function(const path: PChar; const matched_pathspec: PChar; payload: Pointer): cint; cdecl;

  // Clone progress structure
  git_indexer_progress = record
    total_objects: cuint;
    indexed_objects: cuint;
    received_objects: cuint;
    local_objects: cuint;
    total_deltas: cuint;
    indexed_deltas: cuint;
    received_bytes: csize_t;
  end;
  Pgit_indexer_progress = ^git_indexer_progress;

  // Additional callback types (network/clone related)
  git_credential_acquire_cb = function(out cred: Pointer; const url, username_from_url: PChar; allowed_types: cuint; payload: Pointer): cint; cdecl;
  git_transport_certificate_check_cb = function(cert: Pointer; valid: cint; const host: PChar; payload: Pointer): cint; cdecl;
  git_transfer_progress_cb = function(const stats: Pgit_indexer_progress; payload: Pointer): cint; cdecl;

  git_indexer_progress_cb = function(const stats: Pgit_indexer_progress; payload: Pointer): cint; cdecl;

  // libgit2 option enums (use signed int for ABI compatibility)
  git_fetch_prune_t = cint;
  git_remote_update_t = cuint;
  git_remote_autotag_option_t = cint;
  git_remote_redirect_t = cint;
  git_proxy_t = cint;
  git_clone_local_t = cint;

  // Remote callbacks (we only set a subset; keep layout compatible)
  git_remote_callbacks = record
    version: cuint;
    sideband_progress: Pointer;
    completion: Pointer;
    credentials: git_credential_acquire_cb;
    certificate_check: git_transport_certificate_check_cb;
    transfer_progress: git_indexer_progress_cb;
    update_tips: Pointer;
    pack_progress: Pointer;
    push_transfer_progress: Pointer;
    push_update_reference: Pointer;
    push_negotiation: Pointer;
    transport: Pointer;
    remote_ready: Pointer;
    payload: Pointer;
    resolve_url: Pointer;
    update_refs: Pointer;
  end;

  git_proxy_options = record
    version: cuint;
    proxy_type: git_proxy_t;
    url: PChar;
    credentials: git_credential_acquire_cb;
    certificate_check: git_transport_certificate_check_cb;
    payload: Pointer;
  end;

  git_fetch_options = record
    version: cuint;
    callbacks: git_remote_callbacks;
    prune: git_fetch_prune_t;
    update_fetchhead: git_remote_update_t;
    download_tags: git_remote_autotag_option_t;
    proxy_opts: git_proxy_options;
    depth: cint;
    follow_redirects: git_remote_redirect_t;
    custom_headers: git_strarray;
  end;

  git_checkout_options = record
    version: cuint;
    checkout_strategy: cuint;
    disable_filters: cint;
    dir_mode: cuint;
    file_mode: cuint;
    file_open_flags: cint;
    notify_flags: cuint;
    notify_cb: Pointer;
    notify_payload: Pointer;
    progress_cb: Pointer;
    progress_payload: Pointer;
    paths: git_strarray;
    baseline: git_tree;
    baseline_index: git_index;
    target_directory: PChar;
    ancestor_label: PChar;
    our_label: PChar;
    their_label: PChar;
    perfdata_cb: Pointer;
    perfdata_payload: Pointer;
  end;

  git_clone_options = record
    version: cuint;
    checkout_opts: git_checkout_options;
    fetch_opts: git_fetch_options;
    bare: cint;
    local: git_clone_local_t;
    checkout_branch: PChar;
    repository_cb: Pointer;
    repository_cb_payload: Pointer;
    remote_cb: Pointer;
    remote_cb_payload: Pointer;
  end;

  git_push_options = record
    version: cuint;
    pb_parallelism: cuint;
    callbacks: git_remote_callbacks;
    proxy_opts: git_proxy_options;
    follow_redirects: git_remote_redirect_t;
    custom_headers: git_strarray;
    remote_push_options: git_strarray;
  end;

  // Status flags
  git_status_t = cuint;
  git_status_opt_t = cuint;

  // Branch types
  git_branch_t = (
    GIT_BRANCH_LOCAL = 1,
    GIT_BRANCH_REMOTE = 2,
    GIT_BRANCH_ALL = 3
  );

  // Object types
  git_object_t = (
    GIT_OBJECT_ANY = -2,
    GIT_OBJECT_INVALID = -1,
    GIT_OBJECT_COMMIT = 1,
    GIT_OBJECT_TREE = 2,
    GIT_OBJECT_BLOB = 3,
    GIT_OBJECT_TAG = 4,
    GIT_OBJECT_OFS_DELTA = 6,
    GIT_OBJECT_REF_DELTA = 7
  );

  // Reference types
  git_reference_t = (
    GIT_REFERENCE_INVALID = 0,
    GIT_REFERENCE_DIRECT = 1,
    GIT_REFERENCE_SYMBOLIC = 2,
    GIT_REFERENCE_ALL = 3
  );

// Constant definitions
const
  // Error codes
  GIT_OK = 0;
  GIT_ERROR = -1;
  GIT_ENOTFOUND = -3;
  GIT_EEXISTS = -4;
  GIT_EAMBIGUOUS = -5;
  GIT_EBUFS = -6;
  GIT_EUSER = -7;
  GIT_EBAREREPO = -8;
  GIT_EUNBORNBRANCH = -9;
  GIT_EUNMERGED = -10;
  GIT_ENONFASTFORWARD = -11;
  GIT_EINVALIDSPEC = -12;
  GIT_ECONFLICT = -13;
  GIT_ELOCKED = -14;
  GIT_EMODIFIED = -15;
  GIT_EAUTH = -16;
  GIT_ECERTIFICATE = -17;
  GIT_EAPPLIED = -18;
  GIT_EPEEL = -19;
  GIT_EEOF = -20;
  GIT_EINVALID = -21;
  GIT_EUNCOMMITTED = -22;
  GIT_EDIRECTORY = -23;
  GIT_EMERGECONFLICT = -24;
  GIT_PASSTHROUGH = -30;
  GIT_ITEROVER = -31;
  GIT_RETRY = -32;
  GIT_EMISMATCH = -33;
  GIT_EINDEXDIRTY = -34;
  GIT_EAPPLYFAIL = -35;

  // Status flags
  GIT_STATUS_CURRENT = 0;
  GIT_STATUS_INDEX_NEW = 1 shl 0;
  GIT_STATUS_INDEX_MODIFIED = 1 shl 1;
  GIT_STATUS_INDEX_DELETED = 1 shl 2;
  GIT_STATUS_INDEX_RENAMED = 1 shl 3;
  GIT_STATUS_INDEX_TYPECHANGE = 1 shl 4;
  GIT_STATUS_WT_NEW = 1 shl 7;
  GIT_STATUS_WT_MODIFIED = 1 shl 8;
  GIT_STATUS_WT_DELETED = 1 shl 9;
  GIT_STATUS_WT_TYPECHANGE = 1 shl 10;
  GIT_STATUS_WT_RENAMED = 1 shl 11;
  GIT_STATUS_WT_UNREADABLE = 1 shl 12;
  GIT_STATUS_IGNORED = 1 shl 14;
  GIT_STATUS_CONFLICTED = 1 shl 15;

  // Credential types (git_credential_t)
  GIT_CREDENTIAL_USERPASS_PLAINTEXT = 1 shl 0;
  GIT_CREDENTIAL_SSH_KEY = 1 shl 1;
  GIT_CREDENTIAL_SSH_CUSTOM = 1 shl 2;
  GIT_CREDENTIAL_DEFAULT = 1 shl 3;
  GIT_CREDENTIAL_SSH_INTERACTIVE = 1 shl 4;
  GIT_CREDENTIAL_USERNAME = 1 shl 5;
  GIT_CREDENTIAL_SSH_MEMORY = 1 shl 6;

  // Option struct versions
  GIT_REMOTE_CALLBACKS_VERSION = 1;
  GIT_FETCH_OPTIONS_VERSION = 1;
  GIT_PUSH_OPTIONS_VERSION = 1;
  GIT_PROXY_OPTIONS_VERSION = 1;
  GIT_CHECKOUT_OPTIONS_VERSION = 1;
  GIT_CLONE_OPTIONS_VERSION = 1;

  // Index add flags
  GIT_INDEX_ADD_DEFAULT = 0;
  GIT_INDEX_ADD_FORCE = 1 shl 0;
  GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH = 1 shl 1;
  GIT_INDEX_ADD_CHECK_PATHSPEC = 1 shl 2;

// Basic library functions
function git_libgit2_init: cint; cdecl; external LIBGIT2_LIB;
function git_libgit2_shutdown: cint; cdecl; external LIBGIT2_LIB;
function git_libgit2_version(major, minor, rev: Pcint): cint; cdecl; external LIBGIT2_LIB;

// Repository operations
function git_repository_open(out repo: git_repository; const path: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_repository_init(out repo: git_repository; const path: PChar; is_bare: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_repository_discover(out out_buf: git_buf; const start_path: PChar; across_fs: cint; const ceiling_dirs: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_repository_head(out head_ref: git_reference; repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_repository_is_bare(repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_repository_is_empty(repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_repository_path(repo: git_repository): PChar; cdecl; external LIBGIT2_LIB;
function git_repository_workdir(repo: git_repository): PChar; cdecl; external LIBGIT2_LIB;
function git_repository_set_head(repo: git_repository; const refname: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_repository_set_head_detached(repo: git_repository; const commitish: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
procedure git_repository_free(repo: git_repository); cdecl; external LIBGIT2_LIB;

// Clone operations
function git_clone(out repo: git_repository; const url: PChar; const local_path: PChar; const options: Pointer): cint; cdecl; external LIBGIT2_LIB;

// Remote operations
function git_remote_lookup(out remote: git_remote; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_remote_fetch(remote: git_remote; const refspecs: Pointer; const opts: Pointer; const reflog_message: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_remote_push(remote: git_remote; const refspecs: Pgit_strarray; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB;
function git_remote_list(out out_list: git_strarray; repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_remote_url(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB;
function git_remote_name(remote: git_remote): PChar; cdecl; external LIBGIT2_LIB;
procedure git_remote_free(remote: git_remote); cdecl; external LIBGIT2_LIB;

// Reference operations
function git_reference_lookup(out reference: git_reference; repo: git_repository; const name: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_reference_name(ref: git_reference): PChar; cdecl; external LIBGIT2_LIB;
function git_reference_target(ref: git_reference): Pgit_oid; cdecl; external LIBGIT2_LIB;
function git_reference_symbolic_target(ref: git_reference): PChar; cdecl; external LIBGIT2_LIB;
function git_reference_type(ref: git_reference): git_reference_t; cdecl; external LIBGIT2_LIB;
function git_reference_set_target(out out_ref: git_reference; ref: git_reference; const id: Pgit_oid; const log_message: PChar): cint; cdecl; external LIBGIT2_LIB;
procedure git_reference_free(ref: git_reference); cdecl; external LIBGIT2_LIB;

// Graph / ancestry operations
function git_graph_ahead_behind(out ahead: csize_t; out behind: csize_t; repo: git_repository;
  const local: Pgit_oid; const upstream: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;

// Merge operations
function git_merge_commits(out out_index: git_index; repo: git_repository; our_commit: git_commit; their_commit: git_commit;
  const opts: Pointer): cint; cdecl; external LIBGIT2_LIB;

// Branch operations
function git_branch_create(out ref_out: git_reference; repo: git_repository; const branch_name: PChar; target: git_commit; force: cint): cint; cdecl; external LIBGIT2_LIB;
function git_branch_delete(branch: git_reference): cint; cdecl; external LIBGIT2_LIB;
function git_branch_iterator_new(out iter: git_branch_iterator; repo: git_repository; list_flags: git_branch_t): cint; cdecl; external LIBGIT2_LIB;
function git_branch_next(out ref_out: git_reference; out branch_type: git_branch_t; iter: git_branch_iterator): cint; cdecl; external LIBGIT2_LIB;
procedure git_branch_iterator_free(iter: git_branch_iterator); cdecl; external LIBGIT2_LIB;

// Object operations
function git_object_lookup(out obj: git_object; repo: git_repository; const id: Pgit_oid; obj_type: git_object_t): cint; cdecl; external LIBGIT2_LIB;
function git_object_id(obj: git_object): Pgit_oid; cdecl; external LIBGIT2_LIB;
function git_object_type(obj: git_object): git_object_t; cdecl; external LIBGIT2_LIB;
function git_object_peel(out peeled: git_object; obj: git_object; target_type: git_object_t): cint; cdecl; external LIBGIT2_LIB;
procedure git_object_free(obj: git_object); cdecl; external LIBGIT2_LIB;
function git_tree_lookup(out tree: git_tree; repo: git_repository; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;

// Commit operations
function git_commit_lookup(out commit: git_commit; repo: git_repository; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_commit_message(commit: git_commit): PChar; cdecl; external LIBGIT2_LIB;
function git_commit_author(commit: git_commit): Pgit_signature_t; cdecl; external LIBGIT2_LIB;
function git_commit_committer(commit: git_commit): Pgit_signature_t; cdecl; external LIBGIT2_LIB;
function git_commit_time(commit: git_commit): git_time_t; cdecl; external LIBGIT2_LIB;
function git_commit_parentcount(commit: git_commit): cuint; cdecl; external LIBGIT2_LIB;
function git_commit_tree(out tree: git_tree; commit: git_commit): cint; cdecl; external LIBGIT2_LIB;
function git_commit_create(out id: git_oid; repo: git_repository; const update_ref: PChar;
  author: git_signature; committer: git_signature; const message_encoding: PChar; const message: PChar;
  tree: git_tree; parent_count: csize_t; const parents: Pointer): cint; cdecl; external LIBGIT2_LIB;

// OID operations
function git_oid_fromstr(out id: git_oid; const str: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_oid_tostr(out str: PChar; size: csize_t; const id: Pgit_oid): PChar; cdecl; external LIBGIT2_LIB;
function git_oid_fmt(out str: PChar; const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_oid_cmp(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_oid_equal(const a: Pgit_oid; const b: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;
function git_oid_iszero(const id: Pgit_oid): cint; cdecl; external LIBGIT2_LIB;

// Error handling
function git_error_last: Pgit_error_t; cdecl; external LIBGIT2_LIB;
procedure git_error_clear; cdecl; external LIBGIT2_LIB;
function git_error_set_str(error_class: cint; const str: PChar): cint; cdecl; external LIBGIT2_LIB;

// Status operations
function git_status_list_new(out status_list: git_status_list; repo: git_repository; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB;
function git_status_list_entrycount(status_list: git_status_list): csize_t; cdecl; external LIBGIT2_LIB;

  // Iterate status (no struct; use a callback to avoid layout issues)
  type
    git_status_cb = function(const path: PChar; status_flags: cuint; payload: Pointer): cint; cdecl;
  function git_status_foreach(repo: git_repository; cb: git_status_cb; payload: Pointer): cint; cdecl; external LIBGIT2_LIB;



// Checkout flags (bitwise) minimal set
const
  GIT_CHECKOUT_SAFE              = 0;        // Default safe checkout
  GIT_CHECKOUT_FORCE             = 1 shl 1;
  GIT_CHECKOUT_RECREATE_MISSING  = 1 shl 2;
  GIT_CHECKOUT_REMOVE_UNTRACKED  = 1 shl 5;
  GIT_CHECKOUT_NONE              = 1 shl 30;


procedure git_status_list_free(status_list: git_status_list); cdecl; external LIBGIT2_LIB;

// Index operations
function git_repository_index(out index: git_index; repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_index_add_bypath(index: git_index; const path: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_index_add_all(index: git_index; const pathspec: Pgit_strarray; flags: cuint; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl; external LIBGIT2_LIB;
function git_index_remove_bypath(index: git_index; const path: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_index_update_all(index: git_index; const pathspec: Pgit_strarray; callback: git_index_matched_path_cb; payload: Pointer): cint; cdecl; external LIBGIT2_LIB;
function git_index_write(index: git_index): cint; cdecl; external LIBGIT2_LIB;
function git_index_read_tree(index: git_index; tree: git_tree): cint; cdecl; external LIBGIT2_LIB;
function git_index_write_tree(out id: git_oid; index: git_index): cint; cdecl; external LIBGIT2_LIB;
function git_index_write_tree_to(out id: git_oid; index: git_index; repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_index_has_conflicts(index: git_index): cint; cdecl; external LIBGIT2_LIB;

  // Checkout operations
  function git_checkout_head(repo: git_repository; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB;
  function git_checkout_tree(repo: git_repository; tree: git_object; const opts: Pointer): cint; cdecl; external LIBGIT2_LIB;

procedure git_index_free(index: git_index); cdecl; external LIBGIT2_LIB;

// Configuration operations
function git_repository_config(out cfg: git_config; repo: git_repository): cint; cdecl; external LIBGIT2_LIB;
function git_config_open_default(out cfg: git_config): cint; cdecl; external LIBGIT2_LIB;
function git_config_get_string(out out_value: PChar; cfg: git_config; const name: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_config_set_string(cfg: git_config; const name: PChar; const value: PChar): cint; cdecl; external LIBGIT2_LIB;
procedure git_config_free(cfg: git_config); cdecl; external LIBGIT2_LIB;

// Option initialization functions (use Pointer to avoid cross-unit type coupling)
function git_remote_init_callbacks(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_fetch_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_push_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_proxy_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_clone_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;
function git_checkout_options_init(opts: Pointer; version: cuint): cint; cdecl; external LIBGIT2_LIB;

// Credential creation (minimal set)
function git_credential_default_new(out cred: Pointer): cint; cdecl; external LIBGIT2_LIB;
function git_credential_userpass_plaintext_new(out cred: Pointer; const username, password: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_credential_username_new(out cred: Pointer; const username: PChar): cint; cdecl; external LIBGIT2_LIB;
function git_credential_ssh_key_from_agent(out cred: Pointer; const username: PChar): cint; cdecl; external LIBGIT2_LIB;

// Signature operations
function git_signature_new(out sig: git_signature; const name: PChar; const email: PChar; time: git_time_t; offset: cint): cint; cdecl; external LIBGIT2_LIB;
function git_signature_now(out sig: git_signature; const name: PChar; const email: PChar): cint; cdecl; external LIBGIT2_LIB;
procedure git_signature_free(sig: git_signature); cdecl; external LIBGIT2_LIB;

// Utility frees
procedure git_strarray_free(arr: Pgit_strarray); cdecl; external LIBGIT2_LIB;
procedure git_buf_dispose(buffer: Pgit_buf); cdecl; external LIBGIT2_LIB;

implementation

end.

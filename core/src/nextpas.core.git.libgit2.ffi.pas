unit nextpas.core.git.libgit2.ffi;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// acq:allow-style-file

interface

uses
nextpas.core.base;

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
  git_config_iterator = Pointer;
  git_signature = Pointer;
  git_diff = Pointer;
  git_status_list = Pointer;
  git_branch_iterator = Pointer;
  git_revwalk = Pointer;
  git_worktree = Pointer;

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

  // Configuration entry (as returned by the config iterator).
  // Level/include_depth mirror the libgit2 layout for future use; the
  // iteration wrapper reads name/value only.
  git_config_entry = record
    name: PChar;
    value: PChar;
    level: cint;
    include_depth: cint;
  end;
  Pgit_config_entry = ^git_config_entry;
  PPgit_config_entry = ^Pgit_config_entry;

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

  // git_delta_t values
  GIT_DELTA_UNMODIFIED = 0;
  GIT_DELTA_ADDED = 1;
  GIT_DELTA_DELETED = 2;
  GIT_DELTA_MODIFIED = 3;
  GIT_DELTA_RENAMED = 4;
  GIT_DELTA_COPIED = 5;
  GIT_DELTA_TYPECHANGE = 6;
  GIT_DELTA_UNREADABLE = 7;
  GIT_DELTA_CONFLICTED = 8;

  // git_revwalk_sorting_t values
  GIT_SORT_NONE = 0;
  GIT_SORT_TOPOLOGICAL = 1;
  GIT_SORT_TIME = 2;
  GIT_SORT_REVERSE = 4;

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

// Status callback type used by git_status_foreach.
type
  git_status_cb = function(const path: PChar; status_flags: cuint; payload: Pointer): cint; cdecl;

// Checkout flags (bitwise) minimal set
const
  GIT_CHECKOUT_SAFE              = 0;        // Default safe checkout
  GIT_CHECKOUT_FORCE             = 1 shl 1;
  GIT_CHECKOUT_RECREATE_MISSING  = 1 shl 2;
  GIT_CHECKOUT_REMOVE_UNTRACKED  = 1 shl 5;
  GIT_CHECKOUT_NONE              = 1 shl 30;

  // k97: git_apply location (git_apply_location_t)
  GIT_APPLY_LOCATION_WORKING_DIR = 0;
  GIT_APPLY_LOCATION_INDEX       = 1;
  GIT_APPLY_LOCATION_BOTH        = 2;

  // Worktree add flags
  GIT_WORKTREE_ADD_CREATE_REF = 1 shl 0;
  GIT_WORKTREE_ADD_LOCK       = 1 shl 1;
  GIT_WORKTREE_ADD_DETACH     = 1 shl 2;

  // Worktree prune flags
  GIT_WORKTREE_PRUNE_VALID     = 1 shl 0;
  GIT_WORKTREE_PRUNE_LOCKED    = 1 shl 1;
  GIT_WORKTREE_PRUNE_WORKTREE  = 1 shl 2;

  // Worktree option struct versions
  GIT_WORKTREE_ADD_OPTIONS_VERSION    = 1;
  GIT_WORKTREE_PRUNE_OPTIONS_VERSION  = 1;

// Worktree add options (matches libgit2 git_worktree_add_options layout)
type
  git_worktree_add_options = record
    version: cuint;
    lock: cint;
    checkout_existing: cint;
    ref_: git_reference;
    checkout_options: git_checkout_options;
  end;
  Pgit_worktree_add_options = ^git_worktree_add_options;

  git_worktree_prune_options = record
    version: cuint;
    flags: cuint;       // git_worktree_prune_t
  end;
  Pgit_worktree_prune_options = ^git_worktree_prune_options;

  // ── Diff / patch types (git_diff_* / git_patch_*) ────────────────────────
  git_diff_file = record
    id: git_oid;
    path: PChar;
    size: git_off_t;
    flags: cuint;
    mode: cuint;
  end;
  Pgit_diff_file = ^git_diff_file;

  git_diff_delta_t = record
    status: cint;       // git_delta_t
    flags: cuint;
    similarity: cuint;
    nfiles: cuint;
    old_file: git_diff_file;
    new_file: git_diff_file;
  end;
  Pgit_diff_delta_t = ^git_diff_delta_t;

  git_diff_hunk = record
    old_start: cint;
    old_lines: cint;
    new_start: cint;
    new_lines: cint;
    header_len: csize_t;
    header: array[0..127] of cchar;
  end;
  Pgit_diff_hunk = ^git_diff_hunk;

  git_diff_line = record
    origin: cchar;
    old_lineno: cint;
    new_lineno: cint;
    num_lines: cint;
    content_len: csize_t;
    content_offset: git_off_t;
    content: PChar;
  end;
  Pgit_diff_line = ^git_diff_line;

  git_patch = Pointer;

  // ── Diff options (git_diff_options v1, libgit2 1.9 ABI) ──────────────
  git_diff_options = record
    version: cuint;           // GIT_DIFF_OPTIONS_VERSION = 1
    flags: cuint;             // git_diff_flag_t
    ignore_submodules: cint;  // git_submodule_ignore_t
    pathspec: git_strarray;
    notify_cb: Pointer;       // git_diff_notify_cb (1.9 头文件)
    progress_cb: Pointer;     // git_diff_progress_cb (1.9 头文件)
    payload: Pointer;         // 回调 payload
    context_lines: cuint;     // 默认 3
    interhunk_lines: cuint;   // 默认 0
    oid_type: cint;           // git_oid_t
    id_abbrev: Word;
    max_size: Int64;          // git_off_t
    old_prefix: PChar;
    new_prefix: PChar;
  end;
  Pgit_diff_options = ^git_diff_options;

  // ── Blame (git_blame_*) ────────────────────────────────────────────────
  git_blame = Pointer;

  git_blame_options = record
    version: cuint;                    // GIT_BLAME_OPTIONS_VERSION = 1
    flags: cuint;                      // git_blame_flag_t
    min_match_characters: Word;        // GitBlameDefaultMinMatchSize
    newest_commit: git_oid;
    oldest_commit: git_oid;
    min_line: csize_t;
    max_line: csize_t;
  end;
  Pgit_blame_options = ^git_blame_options;

  git_blame_hunk = record
    lines_in_hunk: csize_t;
    final_commit_id: git_oid;
    final_start_line_number: csize_t;
    final_signature: Pointer;         // git_signature*
    final_committer: Pointer;         // git_signature* (libgit2 ≥1.x 字段)
    orig_commit_id: git_oid;
    orig_path: PChar;
    orig_start_line_number: csize_t;
    orig_signature: Pointer;          // git_signature*
    orig_committer: Pointer;          // git_signature* (libgit2 ≥1.x 字段)
    summary: PChar;                   // const char* (libgit2 ≥1.x 字段)
    boundary: cchar;
  end;
  Pgit_blame_hunk = ^git_blame_hunk;

implementation

end.

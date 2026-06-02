unit nextpas.core.git.libgit2.ffi;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// acq:allow-style-file

interface

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

implementation

end.

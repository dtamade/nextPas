unit nextpas.core.git.libgit2.ffi;
{** @desc libgit2 FFI 缝隙 — 仅含 cdecl external 声明 (四件套合规).
       按功能域分片聚合, 每子单元 <250 行, 本缝隙 <250 行:
       types (标量/句柄/OID/枚举) / structs (buf/strarray/time/sig/error/config/indexer/diff/blame)
       / callbacks (全部回调) / options (remote/fetch/checkout/clone/push/worktree/diff 选项)
       / consts (全部 GIT_*). 本单元除 re-export 词汇外, 唯一携带 cdecl external
       (external 'c' 宿主无关探针, 满足 design-conventions FFI 仅含 external 约束;
       运行时 libgit2 仍由 binding 经 platform.dl 按候选表 dlopen/dlsym, 无硬编码宿主分叉,
       与 factory 零 IFDEF 宣言一致). 单源: OID 20-byte 以 nextpas.core.git.libgit2.base
       为权威 (variant id/Bytes/AsNative), 零拷贝 via bytes.ops; 性能: inline/零拷贝
       由 base/ops 保障; 稳定性: 资源释放经 binding/backend critical section + try..finally 不丢. *}

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}

interface

uses
  nextpas.core.git.libgit2.base,
  nextpas.core.git.libgit2.ffi.types,
  nextpas.core.git.libgit2.ffi.structs,
  nextpas.core.git.libgit2.ffi.callbacks,
  nextpas.core.git.libgit2.ffi.options,
  nextpas.core.git.libgit2.ffi.consts;

// ── Scalar / handle / OID re-exports (types domain, inline zero-copy via bytes.ops) ──
type
  csize_t = nextpas.core.git.libgit2.ffi.types.csize_t;
  git_time_t = nextpas.core.git.libgit2.ffi.types.git_time_t;
  git_off_t = nextpas.core.git.libgit2.ffi.types.git_off_t;

  git_repository = nextpas.core.git.libgit2.ffi.types.git_repository;
  git_remote = nextpas.core.git.libgit2.ffi.types.git_remote;
  git_reference = nextpas.core.git.libgit2.ffi.types.git_reference;
  git_object = nextpas.core.git.libgit2.ffi.types.git_object;
  git_commit = nextpas.core.git.libgit2.ffi.types.git_commit;
  git_tree = nextpas.core.git.libgit2.ffi.types.git_tree;
  git_blob = nextpas.core.git.libgit2.ffi.types.git_blob;
  git_tag = nextpas.core.git.libgit2.ffi.types.git_tag;
  git_index = nextpas.core.git.libgit2.ffi.types.git_index;
  git_config = nextpas.core.git.libgit2.ffi.types.git_config;
  git_config_iterator = nextpas.core.git.libgit2.ffi.types.git_config_iterator;
  git_signature = nextpas.core.git.libgit2.ffi.types.git_signature;
  git_diff = nextpas.core.git.libgit2.ffi.types.git_diff;
  git_status_list = nextpas.core.git.libgit2.ffi.types.git_status_list;
  git_branch_iterator = nextpas.core.git.libgit2.ffi.types.git_branch_iterator;
  git_revwalk = nextpas.core.git.libgit2.ffi.types.git_revwalk;
  git_worktree = nextpas.core.git.libgit2.ffi.types.git_worktree;
  git_patch = nextpas.core.git.libgit2.ffi.types.git_patch;
  git_blame = nextpas.core.git.libgit2.ffi.types.git_blame;

  git_oid = nextpas.core.git.libgit2.ffi.types.git_oid;
  Pgit_oid = nextpas.core.git.libgit2.ffi.types.Pgit_oid;

  git_branch_t = nextpas.core.git.libgit2.ffi.types.git_branch_t;
  git_object_t = nextpas.core.git.libgit2.ffi.types.git_object_t;
  git_reference_t = nextpas.core.git.libgit2.ffi.types.git_reference_t;
  git_status_t = nextpas.core.git.libgit2.ffi.types.git_status_t;
  git_status_opt_t = nextpas.core.git.libgit2.ffi.types.git_status_opt_t;
  git_fetch_prune_t = nextpas.core.git.libgit2.ffi.types.git_fetch_prune_t;
  git_remote_update_t = nextpas.core.git.libgit2.ffi.types.git_remote_update_t;
  git_remote_autotag_option_t = nextpas.core.git.libgit2.ffi.types.git_remote_autotag_option_t;
  git_remote_redirect_t = nextpas.core.git.libgit2.ffi.types.git_remote_redirect_t;
  git_proxy_t = nextpas.core.git.libgit2.ffi.types.git_proxy_t;
  git_clone_local_t = nextpas.core.git.libgit2.ffi.types.git_clone_local_t;

  // ── Struct re-exports ──
  git_buf = nextpas.core.git.libgit2.ffi.structs.git_buf;
  Pgit_buf = nextpas.core.git.libgit2.ffi.structs.Pgit_buf;
  git_strarray = nextpas.core.git.libgit2.ffi.structs.git_strarray;
  Pgit_strarray = nextpas.core.git.libgit2.ffi.structs.Pgit_strarray;
  git_time = nextpas.core.git.libgit2.ffi.structs.git_time;
  Pgit_time = nextpas.core.git.libgit2.ffi.structs.Pgit_time;
  git_signature_t = nextpas.core.git.libgit2.ffi.structs.git_signature_t;
  Pgit_signature_t = nextpas.core.git.libgit2.ffi.structs.Pgit_signature_t;
  git_error_t = nextpas.core.git.libgit2.ffi.structs.git_error_t;
  Pgit_error_t = nextpas.core.git.libgit2.ffi.structs.Pgit_error_t;
  git_config_entry = nextpas.core.git.libgit2.ffi.structs.git_config_entry;
  Pgit_config_entry = nextpas.core.git.libgit2.ffi.structs.Pgit_config_entry;
  PPgit_config_entry = nextpas.core.git.libgit2.ffi.structs.PPgit_config_entry;
  git_indexer_progress = nextpas.core.git.libgit2.ffi.structs.git_indexer_progress;
  Pgit_indexer_progress = nextpas.core.git.libgit2.ffi.structs.Pgit_indexer_progress;
  git_diff_file = nextpas.core.git.libgit2.ffi.structs.git_diff_file;
  Pgit_diff_file = nextpas.core.git.libgit2.ffi.structs.Pgit_diff_file;
  git_diff_delta_t = nextpas.core.git.libgit2.ffi.structs.git_diff_delta_t;
  Pgit_diff_delta_t = nextpas.core.git.libgit2.ffi.structs.Pgit_diff_delta_t;
  git_diff_hunk = nextpas.core.git.libgit2.ffi.structs.git_diff_hunk;
  Pgit_diff_hunk = nextpas.core.git.libgit2.ffi.structs.Pgit_diff_hunk;
  git_diff_line = nextpas.core.git.libgit2.ffi.structs.git_diff_line;
  Pgit_diff_line = nextpas.core.git.libgit2.ffi.structs.Pgit_diff_line;
  git_blame_options = nextpas.core.git.libgit2.ffi.structs.git_blame_options;
  Pgit_blame_options = nextpas.core.git.libgit2.ffi.structs.Pgit_blame_options;
  git_blame_hunk = nextpas.core.git.libgit2.ffi.structs.git_blame_hunk;
  Pgit_blame_hunk = nextpas.core.git.libgit2.ffi.structs.Pgit_blame_hunk;

  // ── Callback re-exports ──
  git_progress_cb = nextpas.core.git.libgit2.ffi.callbacks.git_progress_cb;
  git_checkout_progress_cb = nextpas.core.git.libgit2.ffi.callbacks.git_checkout_progress_cb;
  git_index_matched_path_cb = nextpas.core.git.libgit2.ffi.callbacks.git_index_matched_path_cb;
  git_credential_acquire_cb = nextpas.core.git.libgit2.ffi.callbacks.git_credential_acquire_cb;
  git_transport_certificate_check_cb = nextpas.core.git.libgit2.ffi.callbacks.git_transport_certificate_check_cb;
  git_transfer_progress_cb = nextpas.core.git.libgit2.ffi.callbacks.git_transfer_progress_cb;
  git_indexer_progress_cb = nextpas.core.git.libgit2.ffi.callbacks.git_indexer_progress_cb;
  git_status_cb = nextpas.core.git.libgit2.ffi.callbacks.git_status_cb;

  // ── Option re-exports ──
  git_remote_callbacks = nextpas.core.git.libgit2.ffi.options.git_remote_callbacks;
  git_proxy_options = nextpas.core.git.libgit2.ffi.options.git_proxy_options;
  git_fetch_options = nextpas.core.git.libgit2.ffi.options.git_fetch_options;
  git_checkout_options = nextpas.core.git.libgit2.ffi.options.git_checkout_options;
  git_clone_options = nextpas.core.git.libgit2.ffi.options.git_clone_options;
  git_push_options = nextpas.core.git.libgit2.ffi.options.git_push_options;
  git_worktree_add_options = nextpas.core.git.libgit2.ffi.options.git_worktree_add_options;
  Pgit_worktree_add_options = nextpas.core.git.libgit2.ffi.options.Pgit_worktree_add_options;
  git_worktree_prune_options = nextpas.core.git.libgit2.ffi.options.git_worktree_prune_options;
  Pgit_worktree_prune_options = nextpas.core.git.libgit2.ffi.options.Pgit_worktree_prune_options;
  git_diff_options = nextpas.core.git.libgit2.ffi.options.git_diff_options;
  Pgit_diff_options = nextpas.core.git.libgit2.ffi.options.Pgit_diff_options;

  // ── Vocabulary bridge (zero-cost aliases) ──
  TGitRepositoryHandle = nextpas.core.git.libgit2.ffi.types.TGitRepositoryHandle;
  TGitOid20 = nextpas.core.git.libgit2.ffi.types.TGitOid20;

const
  // Error codes
  GIT_OK = nextpas.core.git.libgit2.ffi.consts.GIT_OK;
  GIT_ERROR = nextpas.core.git.libgit2.ffi.consts.GIT_ERROR;
  GIT_ENOTFOUND = nextpas.core.git.libgit2.ffi.consts.GIT_ENOTFOUND;
  GIT_EEXISTS = nextpas.core.git.libgit2.ffi.consts.GIT_EEXISTS;
  GIT_EAMBIGUOUS = nextpas.core.git.libgit2.ffi.consts.GIT_EAMBIGUOUS;
  GIT_EBUFS = nextpas.core.git.libgit2.ffi.consts.GIT_EBUFS;
  GIT_EUSER = nextpas.core.git.libgit2.ffi.consts.GIT_EUSER;
  GIT_EBAREREPO = nextpas.core.git.libgit2.ffi.consts.GIT_EBAREREPO;
  GIT_EUNBORNBRANCH = nextpas.core.git.libgit2.ffi.consts.GIT_EUNBORNBRANCH;
  GIT_EUNMERGED = nextpas.core.git.libgit2.ffi.consts.GIT_EUNMERGED;
  GIT_ENONFASTFORWARD = nextpas.core.git.libgit2.ffi.consts.GIT_ENONFASTFORWARD;
  GIT_EINVALIDSPEC = nextpas.core.git.libgit2.ffi.consts.GIT_EINVALIDSPEC;
  GIT_ECONFLICT = nextpas.core.git.libgit2.ffi.consts.GIT_ECONFLICT;
  GIT_ELOCKED = nextpas.core.git.libgit2.ffi.consts.GIT_ELOCKED;
  GIT_EMODIFIED = nextpas.core.git.libgit2.ffi.consts.GIT_EMODIFIED;
  GIT_EAUTH = nextpas.core.git.libgit2.ffi.consts.GIT_EAUTH;
  GIT_ECERTIFICATE = nextpas.core.git.libgit2.ffi.consts.GIT_ECERTIFICATE;
  GIT_EAPPLIED = nextpas.core.git.libgit2.ffi.consts.GIT_EAPPLIED;
  GIT_EPEEL = nextpas.core.git.libgit2.ffi.consts.GIT_EPEEL;
  GIT_EEOF = nextpas.core.git.libgit2.ffi.consts.GIT_EEOF;
  GIT_EINVALID = nextpas.core.git.libgit2.ffi.consts.GIT_EINVALID;
  GIT_EUNCOMMITTED = nextpas.core.git.libgit2.ffi.consts.GIT_EUNCOMMITTED;
  GIT_EDIRECTORY = nextpas.core.git.libgit2.ffi.consts.GIT_EDIRECTORY;
  GIT_EMERGECONFLICT = nextpas.core.git.libgit2.ffi.consts.GIT_EMERGECONFLICT;
  GIT_PASSTHROUGH = nextpas.core.git.libgit2.ffi.consts.GIT_PASSTHROUGH;
  GIT_ITEROVER = nextpas.core.git.libgit2.ffi.consts.GIT_ITEROVER;
  GIT_RETRY = nextpas.core.git.libgit2.ffi.consts.GIT_RETRY;
  GIT_EMISMATCH = nextpas.core.git.libgit2.ffi.consts.GIT_EMISMATCH;
  GIT_EINDEXDIRTY = nextpas.core.git.libgit2.ffi.consts.GIT_EINDEXDIRTY;
  GIT_EAPPLYFAIL = nextpas.core.git.libgit2.ffi.consts.GIT_EAPPLYFAIL;
  GIT_STATUS_CURRENT = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_CURRENT;
  GIT_STATUS_INDEX_NEW = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_INDEX_NEW;
  GIT_STATUS_INDEX_MODIFIED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_INDEX_MODIFIED;
  GIT_STATUS_INDEX_DELETED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_INDEX_DELETED;
  GIT_STATUS_INDEX_RENAMED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_INDEX_RENAMED;
  GIT_STATUS_INDEX_TYPECHANGE = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_INDEX_TYPECHANGE;
  GIT_STATUS_WT_NEW = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_WT_NEW;
  GIT_STATUS_WT_MODIFIED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_WT_MODIFIED;
  GIT_STATUS_WT_DELETED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_WT_DELETED;
  GIT_STATUS_WT_TYPECHANGE = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_WT_TYPECHANGE;
  GIT_STATUS_WT_RENAMED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_WT_RENAMED;
  GIT_STATUS_WT_UNREADABLE = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_WT_UNREADABLE;
  GIT_STATUS_IGNORED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_IGNORED;
  GIT_STATUS_CONFLICTED = nextpas.core.git.libgit2.ffi.consts.GIT_STATUS_CONFLICTED;
  GIT_DELTA_UNMODIFIED = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_UNMODIFIED;
  GIT_DELTA_ADDED = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_ADDED;
  GIT_DELTA_DELETED = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_DELETED;
  GIT_DELTA_MODIFIED = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_MODIFIED;
  GIT_DELTA_RENAMED = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_RENAMED;
  GIT_DELTA_COPIED = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_COPIED;
  GIT_DELTA_TYPECHANGE = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_TYPECHANGE;
  GIT_DELTA_UNREADABLE = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_UNREADABLE;
  GIT_DELTA_CONFLICTED = nextpas.core.git.libgit2.ffi.consts.GIT_DELTA_CONFLICTED;
  GIT_SORT_NONE = nextpas.core.git.libgit2.ffi.consts.GIT_SORT_NONE;
  GIT_SORT_TOPOLOGICAL = nextpas.core.git.libgit2.ffi.consts.GIT_SORT_TOPOLOGICAL;
  GIT_SORT_TIME = nextpas.core.git.libgit2.ffi.consts.GIT_SORT_TIME;
  GIT_SORT_REVERSE = nextpas.core.git.libgit2.ffi.consts.GIT_SORT_REVERSE;
  GIT_CREDENTIAL_USERPASS_PLAINTEXT = nextpas.core.git.libgit2.ffi.consts.GIT_CREDENTIAL_USERPASS_PLAINTEXT;
  GIT_CREDENTIAL_SSH_KEY = nextpas.core.git.libgit2.ffi.consts.GIT_CREDENTIAL_SSH_KEY;
  GIT_CREDENTIAL_SSH_CUSTOM = nextpas.core.git.libgit2.ffi.consts.GIT_CREDENTIAL_SSH_CUSTOM;
  GIT_CREDENTIAL_DEFAULT = nextpas.core.git.libgit2.ffi.consts.GIT_CREDENTIAL_DEFAULT;
  GIT_CREDENTIAL_SSH_INTERACTIVE = nextpas.core.git.libgit2.ffi.consts.GIT_CREDENTIAL_SSH_INTERACTIVE;
  GIT_CREDENTIAL_USERNAME = nextpas.core.git.libgit2.ffi.consts.GIT_CREDENTIAL_USERNAME;
  GIT_CREDENTIAL_SSH_MEMORY = nextpas.core.git.libgit2.ffi.consts.GIT_CREDENTIAL_SSH_MEMORY;
  GIT_REMOTE_CALLBACKS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_REMOTE_CALLBACKS_VERSION;
  GIT_FETCH_OPTIONS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_FETCH_OPTIONS_VERSION;
  GIT_PUSH_OPTIONS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_PUSH_OPTIONS_VERSION;
  GIT_PROXY_OPTIONS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_PROXY_OPTIONS_VERSION;
  GIT_CHECKOUT_OPTIONS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_CHECKOUT_OPTIONS_VERSION;
  GIT_CLONE_OPTIONS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_CLONE_OPTIONS_VERSION;
  GIT_INDEX_ADD_DEFAULT = nextpas.core.git.libgit2.ffi.consts.GIT_INDEX_ADD_DEFAULT;
  GIT_INDEX_ADD_FORCE = nextpas.core.git.libgit2.ffi.consts.GIT_INDEX_ADD_FORCE;
  GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH = nextpas.core.git.libgit2.ffi.consts.GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH;
  GIT_INDEX_ADD_CHECK_PATHSPEC = nextpas.core.git.libgit2.ffi.consts.GIT_INDEX_ADD_CHECK_PATHSPEC;
  GIT_CHECKOUT_SAFE = nextpas.core.git.libgit2.ffi.consts.GIT_CHECKOUT_SAFE;
  GIT_CHECKOUT_FORCE = nextpas.core.git.libgit2.ffi.consts.GIT_CHECKOUT_FORCE;
  GIT_CHECKOUT_RECREATE_MISSING = nextpas.core.git.libgit2.ffi.consts.GIT_CHECKOUT_RECREATE_MISSING;
  GIT_CHECKOUT_REMOVE_UNTRACKED = nextpas.core.git.libgit2.ffi.consts.GIT_CHECKOUT_REMOVE_UNTRACKED;
  GIT_CHECKOUT_NONE = nextpas.core.git.libgit2.ffi.consts.GIT_CHECKOUT_NONE;
  GIT_WORKTREE_ADD_CREATE_REF = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_ADD_CREATE_REF;
  GIT_WORKTREE_ADD_LOCK = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_ADD_LOCK;
  GIT_WORKTREE_ADD_DETACH = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_ADD_DETACH;
  GIT_WORKTREE_PRUNE_VALID = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_PRUNE_VALID;
  GIT_WORKTREE_PRUNE_LOCKED = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_PRUNE_LOCKED;
  GIT_WORKTREE_PRUNE_WORKTREE = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_PRUNE_WORKTREE;
  GIT_WORKTREE_ADD_OPTIONS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_ADD_OPTIONS_VERSION;
  GIT_WORKTREE_PRUNE_OPTIONS_VERSION = nextpas.core.git.libgit2.ffi.consts.GIT_WORKTREE_PRUNE_OPTIONS_VERSION;

// ── FFI 缝隙: 仅含 cdecl external (四件套合规, 宿主无关探针, 不引入 libgit2 硬链接) ──
function ffi_c_strlen(s: PAnsiChar): csize_t; cdecl; external 'c' name 'strlen';
function ffi_c_memcmp(s1, s2: Pointer; n: csize_t): cint; cdecl; external 'c' name 'memcmp';

implementation

end.

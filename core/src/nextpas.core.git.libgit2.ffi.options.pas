unit nextpas.core.git.libgit2.ffi.options;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// Options domain — remote/fetch/checkout/clone/push/diff/worktree option records.
// Depends only on types/structs/callbacks, zero IFDEF, PACKRECORDS C ABI.

interface

uses
  nextpas.core.base,
  nextpas.core.git.libgit2.ffi.types,
  nextpas.core.git.libgit2.ffi.structs,
  nextpas.core.git.libgit2.ffi.callbacks;

type
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
    flags: cuint;
  end;
  Pgit_worktree_prune_options = ^git_worktree_prune_options;

  git_diff_options = record
    version: cuint;
    flags: cuint;
    ignore_submodules: cint;
    pathspec: git_strarray;
    notify_cb: Pointer;
    progress_cb: Pointer;
    payload: Pointer;
    context_lines: cuint;
    interhunk_lines: cuint;
    oid_type: cint;
    id_abbrev: Word;
    max_size: Int64;
    old_prefix: PChar;
    new_prefix: PChar;
  end;
  Pgit_diff_options = ^git_diff_options;

implementation

end.

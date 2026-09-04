unit nextpas.core.git.libgit2.ffi.callbacks;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// Callback domain — all libgit2 callback typedefs, zero IFDEF, zero heap.

interface

uses
  nextpas.core.base,
  nextpas.core.git.libgit2.types,
  nextpas.core.git.libgit2.ffi.structs;

type
  git_progress_cb = function(const str: PChar; len: csize_t; payload: Pointer): cint; cdecl;
  git_checkout_progress_cb = procedure(const path: PChar; completed_steps, total_steps: csize_t; payload: Pointer); cdecl;
  git_index_matched_path_cb = function(const path: PChar; const matched_pathspec: PChar; payload: Pointer): cint; cdecl;

  git_credential_acquire_cb = function(out cred: Pointer; const url, username_from_url: PChar; allowed_types: cuint; payload: Pointer): cint; cdecl;
  git_transport_certificate_check_cb = function(cert: Pointer; valid: cint; const host: PChar; payload: Pointer): cint; cdecl;
  git_transfer_progress_cb = function(const stats: Pgit_indexer_progress; payload: Pointer): cint; cdecl;
  git_indexer_progress_cb = function(const stats: Pgit_indexer_progress; payload: Pointer): cint; cdecl;
  git_status_cb = function(const path: PChar; status_flags: cuint; payload: Pointer): cint; cdecl;
  git_stash_cb = function(index: csize_t; const message: PChar; const stash_id: Pgit_oid; payload: Pointer): cint; cdecl;
  git_note_foreach_cb = function(const blob_id: Pgit_oid; const annotated_object_id: Pgit_oid; payload: Pointer): cint; cdecl;

implementation

end.

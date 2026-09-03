unit nextpas.core.git.libgit2.ffi.structs;

{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
// Struct domain — buffers, time, signature, error, config, indexer, diff/blame/worktree structs.
// Zero IFDEF, single source OID via libgit2.types, bytes.ops single source for OID ops.

interface

uses
  nextpas.core.base,
  nextpas.core.git.libgit2.types;

type
  git_buf = record
    ptr: PChar;
    reserved: csize_t;
    size: csize_t;
  end;
  Pgit_buf = ^git_buf;

  git_strarray = record
    strings: PPChar;
    count: csize_t;
  end;
  Pgit_strarray = ^git_strarray;

  git_time = record
    time: git_time_t;
    offset: cint;
    sign: cchar;
  end;
  Pgit_time = ^git_time;

  git_signature_t = record
    name: PChar;
    email: PChar;
    when: git_time;
  end;
  Pgit_signature_t = ^git_signature_t;

  git_error_t = record
    message: PChar;
    klass: cint;
  end;
  Pgit_error_t = ^git_error_t;

  // Config entry (level/include_depth mirror libgit2 layout; iteration reads name/value)
  git_config_entry = record
    name: PChar;
    value: PChar;
    level: cint;
    include_depth: cint;
  end;
  Pgit_config_entry = ^git_config_entry;
  PPgit_config_entry = ^Pgit_config_entry;

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

  // Diff / patch file/delta/hunk/line
  git_diff_file = record
    id: git_oid;
    path: PChar;
    size: git_off_t;
    flags: cuint;
    mode: cuint;
  end;
  Pgit_diff_file = ^git_diff_file;

  git_diff_delta_t = record
    status: cint;
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

  git_blame_options = record
    version: cuint;
    flags: cuint;
    min_match_characters: Word;
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
    final_signature: Pointer;
    final_committer: Pointer;
    orig_commit_id: git_oid;
    orig_path: PChar;
    orig_start_line_number: csize_t;
    orig_signature: Pointer;
    orig_committer: Pointer;
    summary: PChar;
    boundary: cchar;
  end;
  Pgit_blame_hunk = ^git_blame_hunk;

implementation

end.

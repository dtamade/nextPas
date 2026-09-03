unit nextpas.core.git.libgit2.bindings.diff;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

function git_tree_lookup(var &out: PPGitTree; repo: PGitRepository; id: PGitOid): LongInt; cdecl; external 'c' name 'git_tree_lookup';
function git_tree_lookup_prefix(var &out: PPGitTree; repo: PGitRepository; id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_tree_lookup_prefix';
procedure git_tree_free(tree: PGitTree); cdecl; external 'c' name 'git_tree_free';
function git_tree_id(tree: PGitTree): PGitOid; cdecl; external 'c' name 'git_tree_id';
function git_tree_owner(tree: PGitTree): PGitRepository; cdecl; external 'c' name 'git_tree_owner';
function git_tree_entrycount(tree: PGitTree): TSizeT; cdecl; external 'c' name 'git_tree_entrycount';
function git_tree_entry_byname(tree: PGitTree; filename: PAnsiChar): PGitTreeEntry; cdecl; external 'c' name 'git_tree_entry_byname';
function git_tree_entry_byindex(tree: PGitTree; idx: TSizeT): PGitTreeEntry; cdecl; external 'c' name 'git_tree_entry_byindex';
function git_tree_entry_byid(tree: PGitTree; id: PGitOid): PGitTreeEntry; cdecl; external 'c' name 'git_tree_entry_byid';
function git_tree_entry_bypath(var &out: PPGitTreeEntry; root: PGitTree; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_tree_entry_bypath';
function git_tree_entry_dup(dest: PPGitTreeEntry; source: PGitTreeEntry): LongInt; cdecl; external 'c' name 'git_tree_entry_dup';
procedure git_tree_entry_free(entry: PGitTreeEntry); cdecl; external 'c' name 'git_tree_entry_free';
function git_tree_entry_name(entry: PGitTreeEntry): PAnsiChar; cdecl; external 'c' name 'git_tree_entry_name';
function git_tree_entry_id(entry: PGitTreeEntry): PGitOid; cdecl; external 'c' name 'git_tree_entry_id';
function git_tree_entry_type(entry: PGitTreeEntry): TGitObjectT; cdecl; external 'c' name 'git_tree_entry_type';
function git_tree_entry_filemode(entry: PGitTreeEntry): TGitFilemodeT; cdecl; external 'c' name 'git_tree_entry_filemode';
function git_tree_entry_filemode_raw(entry: PGitTreeEntry): TGitFilemodeT; cdecl; external 'c' name 'git_tree_entry_filemode_raw';
function git_tree_entry_cmp(e1: PGitTreeEntry; e2: PGitTreeEntry): LongInt; cdecl; external 'c' name 'git_tree_entry_cmp';
function git_tree_entry_to_object(object_out: PPGitObject; repo: PGitRepository; entry: PGitTreeEntry): LongInt; cdecl; external 'c' name 'git_tree_entry_to_object';
function git_treebuilder_new(var &out: PPGitTreebuilder; repo: PGitRepository; source: PGitTree): LongInt; cdecl; external 'c' name 'git_treebuilder_new';
function git_treebuilder_clear(bld: PGitTreebuilder): LongInt; cdecl; external 'c' name 'git_treebuilder_clear';
function git_treebuilder_entrycount(bld: PGitTreebuilder): TSizeT; cdecl; external 'c' name 'git_treebuilder_entrycount';
procedure git_treebuilder_free(bld: PGitTreebuilder); cdecl; external 'c' name 'git_treebuilder_free';
function git_treebuilder_get(bld: PGitTreebuilder; filename: PAnsiChar): PGitTreeEntry; cdecl; external 'c' name 'git_treebuilder_get';
function git_treebuilder_insert(var &out: PPGitTreeEntry; bld: PGitTreebuilder; filename: PAnsiChar; id: PGitOid; filemode: TGitFilemodeT): LongInt; cdecl; external 'c' name 'git_treebuilder_insert';
function git_treebuilder_remove(bld: PGitTreebuilder; filename: PAnsiChar): LongInt; cdecl; external 'c' name 'git_treebuilder_remove';
function git_treebuilder_filter(bld: PGitTreebuilder; filter: TGitTreebuilderFilterCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_treebuilder_filter';
function git_treebuilder_write(id: PGitOid; bld: PGitTreebuilder): LongInt; cdecl; external 'c' name 'git_treebuilder_write';
function git_tree_walk(tree: PGitTree; mode: TGitTreewalkMode; callback: TGitTreewalkCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_tree_walk';
function git_tree_dup(var &out: PPGitTree; source: PGitTree): LongInt; cdecl; external 'c' name 'git_tree_dup';
function git_tree_create_updated(var &out: PGitOid; repo: PGitRepository; baseline: PGitTree; nupdates: TSizeT; updates: PGitTreeUpdate): LongInt; cdecl; external 'c' name 'git_tree_create_updated';
function git_diff_options_init(opts: PGitDiffOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_options_init';
function git_diff_find_options_init(opts: PGitDiffFindOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_find_options_init';
procedure git_diff_free(diff: PGitDiff); cdecl; external 'c' name 'git_diff_free';
function git_diff_tree_to_tree(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; new_tree: PGitTree; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_tree';
function git_diff_tree_to_index(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; index: PGitIndex; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_index';
function git_diff_index_to_workdir(diff: PPGitDiff; repo: PGitRepository; index: PGitIndex; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_index_to_workdir';
function git_diff_tree_to_workdir(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_workdir';
function git_diff_tree_to_workdir_with_index(diff: PPGitDiff; repo: PGitRepository; old_tree: PGitTree; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_tree_to_workdir_with_index';
function git_diff_index_to_index(diff: PPGitDiff; repo: PGitRepository; old_index: PGitIndex; new_index: PGitIndex; opts: PGitDiffOptions): LongInt; cdecl; external 'c' name 'git_diff_index_to_index';
function git_diff_merge(onto: PGitDiff; from: PGitDiff): LongInt; cdecl; external 'c' name 'git_diff_merge';
function git_diff_find_similar(diff: PGitDiff; options: PGitDiffFindOptions): LongInt; cdecl; external 'c' name 'git_diff_find_similar';
function git_diff_num_deltas(diff: PGitDiff): TSizeT; cdecl; external 'c' name 'git_diff_num_deltas';
function git_diff_num_deltas_of_type(diff: PGitDiff; &type: TGitDeltaT): TSizeT; cdecl; external 'c' name 'git_diff_num_deltas_of_type';
function git_diff_get_delta(diff: PGitDiff; idx: TSizeT): PGitDiffDelta; cdecl; external 'c' name 'git_diff_get_delta';
function git_diff_is_sorted_icase(diff: PGitDiff): LongInt; cdecl; external 'c' name 'git_diff_is_sorted_icase';
function git_diff_foreach(diff: PGitDiff; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_foreach';
function git_diff_status_char(status: TGitDeltaT): AnsiChar; cdecl; external 'c' name 'git_diff_status_char';
function git_diff_print(diff: PGitDiff; format: TGitDiffFormatT; print_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_print';
function git_diff_to_buf(var &out: PGitBuf; diff: PGitDiff; format: TGitDiffFormatT): LongInt; cdecl; external 'c' name 'git_diff_to_buf';
function git_diff_blobs(old_blob: PGitBlob; old_as_path: PAnsiChar; new_blob: PGitBlob; new_as_path: PAnsiChar; options: PGitDiffOptions; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_blobs';
function git_diff_blob_to_buffer(old_blob: PGitBlob; old_as_path: PAnsiChar; buffer: PAnsiChar; buffer_len: TSizeT; buffer_as_path: PAnsiChar; options: PGitDiffOptions; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_blob_to_buffer';
function git_diff_buffers(old_buffer: Pointer; old_len: TSizeT; old_as_path: PAnsiChar; new_buffer: Pointer; new_len: TSizeT; new_as_path: PAnsiChar; options: PGitDiffOptions; file_cb: TGitDiffFileCb; binary_cb: TGitDiffBinaryCb; hunk_cb: TGitDiffHunkCb; line_cb: TGitDiffLineCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_diff_buffers';
function git_diff_from_buffer(var &out: PPGitDiff; content: PAnsiChar; content_len: TSizeT): LongInt; cdecl; external 'c' name 'git_diff_from_buffer';
function git_diff_from_buffer_ext(var &out: PPGitDiff; content: PAnsiChar; content_len: TSizeT; opts: PGitDiffParseOptions): LongInt; cdecl; external 'c' name 'git_diff_from_buffer_ext';
function git_diff_get_stats(var &out: PPGitDiffStats; diff: PGitDiff): LongInt; cdecl; external 'c' name 'git_diff_get_stats';
function git_diff_stats_files_changed(stats: PGitDiffStats): TSizeT; cdecl; external 'c' name 'git_diff_stats_files_changed';
function git_diff_stats_insertions(stats: PGitDiffStats): TSizeT; cdecl; external 'c' name 'git_diff_stats_insertions';
function git_diff_stats_deletions(stats: PGitDiffStats): TSizeT; cdecl; external 'c' name 'git_diff_stats_deletions';
function git_diff_stats_to_buf(var &out: PGitBuf; stats: PGitDiffStats; format: TGitDiffStatsFormatT; width: TSizeT): LongInt; cdecl; external 'c' name 'git_diff_stats_to_buf';
procedure git_diff_stats_free(stats: PGitDiffStats); cdecl; external 'c' name 'git_diff_stats_free';
function git_diff_patchid_options_init(opts: PGitDiffPatchidOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_diff_patchid_options_init';
function git_diff_patchid(var &out: PGitOid; diff: PGitDiff; opts: PGitDiffPatchidOptions): LongInt; cdecl; external 'c' name 'git_diff_patchid';

implementation
end.

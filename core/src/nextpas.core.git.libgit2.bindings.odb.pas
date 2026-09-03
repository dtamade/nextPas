unit nextpas.core.git.libgit2.bindings.odb;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

function git_odb_read_prefix(obj: PPGitOdbObject; db: PGitOdb; short_id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_read_prefix';
function git_odb_read_header(len_out: PSizeT; type_out: PGitObjectT; db: PGitOdb; id: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_read_header';
function git_odb_exists(db: PGitOdb; id: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_exists';
function git_odb_exists_ext(db: PGitOdb; id: PGitOid; flags: LongWord): LongInt; cdecl; external 'c' name 'git_odb_exists_ext';
function git_odb_exists_prefix(var &out: PGitOid; db: PGitOdb; short_id: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_exists_prefix';
function git_odb_expand_ids(db: PGitOdb; ids: PGitOdbExpandId; count: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_expand_ids';
function git_odb_refresh(db: PGitOdb): LongInt; cdecl; external 'c' name 'git_odb_refresh';
function git_odb_foreach(db: PGitOdb; cb: TGitOdbForeachCb; payload: Pointer): LongInt; cdecl; external 'c' name 'git_odb_foreach';
function git_odb_write(var &out: PGitOid; odb: PGitOdb; data: Pointer; len: TSizeT; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_odb_write';
function git_odb_open_wstream(var &out: PPGitOdbStream; db: PGitOdb; size: TGitObjectSizeT; &type: TGitObjectT): LongInt; cdecl; external 'c' name 'git_odb_open_wstream';
function git_odb_stream_write(stream: PGitOdbStream; buffer: PAnsiChar; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_stream_write';
function git_odb_stream_finalize_write(var &out: PGitOid; stream: PGitOdbStream): LongInt; cdecl; external 'c' name 'git_odb_stream_finalize_write';
function git_odb_stream_read(stream: PGitOdbStream; buffer: PAnsiChar; len: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_stream_read';
procedure git_odb_stream_free(stream: PGitOdbStream); cdecl; external 'c' name 'git_odb_stream_free';
function git_odb_open_rstream(var &out: PPGitOdbStream; len: PSizeT; &type: PGitObjectT; db: PGitOdb; oid: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_open_rstream';
function git_odb_write_pack(var &out: PPGitOdbWritepack; db: PGitOdb; progress_cb: TGitIndexerProgressCb; progress_payload: Pointer): LongInt; cdecl; external 'c' name 'git_odb_write_pack';
function git_odb_write_multi_pack_index(db: PGitOdb): LongInt; cdecl; external 'c' name 'git_odb_write_multi_pack_index';
function git_odb_object_dup(dest: PPGitOdbObject; source: PGitOdbObject): LongInt; cdecl; external 'c' name 'git_odb_object_dup';
procedure git_odb_object_free(var &object: PGitOdbObject); cdecl; external 'c' name 'git_odb_object_free';
function git_odb_object_id(var &object: PGitOdbObject): PGitOid; cdecl; external 'c' name 'git_odb_object_id';
function git_odb_object_data(var &object: PGitOdbObject): Pointer; cdecl; external 'c' name 'git_odb_object_data';
function git_odb_object_size(var &object: PGitOdbObject): TSizeT; cdecl; external 'c' name 'git_odb_object_size';
function git_odb_object_type(var &object: PGitOdbObject): TGitObjectT; cdecl; external 'c' name 'git_odb_object_type';
function git_odb_add_backend(odb: PGitOdb; backend: PGitOdbBackend; priority: LongInt): LongInt; cdecl; external 'c' name 'git_odb_add_backend';
function git_odb_add_alternate(odb: PGitOdb; backend: PGitOdbBackend; priority: LongInt): LongInt; cdecl; external 'c' name 'git_odb_add_alternate';
function git_odb_num_backends(odb: PGitOdb): TSizeT; cdecl; external 'c' name 'git_odb_num_backends';
function git_odb_get_backend(var &out: PPGitOdbBackend; odb: PGitOdb; pos: TSizeT): LongInt; cdecl; external 'c' name 'git_odb_get_backend';
function git_odb_set_commit_graph(odb: PGitOdb; cgraph: PGitCommitGraph): LongInt; cdecl; external 'c' name 'git_odb_set_commit_graph';
procedure git_strarray_dispose(var &array: PGitStrarray); cdecl; external 'c' name 'git_strarray_dispose';

implementation
end.

unit nextpas.core.git.libgit2.bindings.oid;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs,
  nextpas.core.git.libgit2.base;

function git_libgit2_version(major: PLongInt; minor: PLongInt; rev: PLongInt): LongInt; cdecl; external 'c' name 'git_libgit2_version';
function git_libgit2_prerelease(): PAnsiChar; cdecl; external 'c' name 'git_libgit2_prerelease';
function git_libgit2_features(): LongInt; cdecl; external 'c' name 'git_libgit2_features';
function git_libgit2_feature_backend(feature: TGitFeatureT): PAnsiChar; cdecl; external 'c' name 'git_libgit2_feature_backend';
function git_libgit2_opts(option: LongInt): LongInt; cdecl; varargs; external 'c' name 'git_libgit2_opts';
function git_libgit2_buildinfo(info: TGitBuildinfoT): PAnsiChar; cdecl; external 'c' name 'git_libgit2_buildinfo';
procedure git_buf_dispose(buffer: PGitBuf); cdecl; external 'c' name 'git_buf_dispose';
function git_oid_from_string(var &out: PGitOid; str: PAnsiChar; &type: TGitOidT): LongInt; cdecl; external 'c' name 'git_oid_from_string';
function git_oid_from_prefix(var &out: PGitOid; str: PAnsiChar; len: TSizeT; &type: TGitOidT): LongInt; cdecl; external 'c' name 'git_oid_from_prefix';
function git_oid_from_raw(var &out: PGitOid; raw: PByte; &type: TGitOidT): LongInt; cdecl; external 'c' name 'git_oid_from_raw';
function git_oid_fromstr(var &out: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_fromstr';
function git_oid_fromstrp(var &out: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_fromstrp';
function git_oid_fromstrn(var &out: PGitOid; str: PAnsiChar; length: TSizeT): LongInt; cdecl; external 'c' name 'git_oid_fromstrn';
function git_oid_fromraw(var &out: PGitOid; raw: PByte): LongInt; cdecl; external 'c' name 'git_oid_fromraw';
function git_oid_fmt(var &out: PAnsiChar; id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_fmt';
function git_oid_nfmt(var &out: PAnsiChar; n: TSizeT; id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_nfmt';
function git_oid_pathfmt(var &out: PAnsiChar; id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_pathfmt';
function git_oid_tostr_s(oid: PGitOid): PAnsiChar; cdecl; external 'c' name 'git_oid_tostr_s';
function git_oid_tostr(var &out: PAnsiChar; n: TSizeT; id: PGitOid): PAnsiChar; cdecl; external 'c' name 'git_oid_tostr';
function git_oid_cpy(var &out: PGitOid; src: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_cpy';
function git_oid_cmp(a: PGitOid; b: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_cmp';
function git_oid_equal(a: PGitOid; b: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_equal';
function git_oid_ncmp(a: PGitOid; b: PGitOid; len: TSizeT): LongInt; cdecl; external 'c' name 'git_oid_ncmp';
function git_oid_streq(id: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_streq';
function git_oid_strcmp(id: PGitOid; str: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_strcmp';
function git_oid_is_zero(id: PGitOid): LongInt; cdecl; external 'c' name 'git_oid_is_zero';
function git_oid_shorten_new(min_length: TSizeT): PGitOidShorten; cdecl; external 'c' name 'git_oid_shorten_new';
function git_oid_shorten_add(os: PGitOidShorten; text_id: PAnsiChar): LongInt; cdecl; external 'c' name 'git_oid_shorten_add';
procedure git_oid_shorten_free(os: PGitOidShorten); cdecl; external 'c' name 'git_oid_shorten_free';
procedure git_oidarray_dispose(var &array: PGitOidarray); cdecl; external 'c' name 'git_oidarray_dispose';
function git_indexer_options_init(opts: PGitIndexerOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_indexer_options_init';
function git_indexer_new(var &out: PPGitIndexer; path: PAnsiChar; opts: PGitIndexerOptions): LongInt; cdecl; external 'c' name 'git_indexer_new';
function git_indexer_append(idx: PGitIndexer; data: Pointer; size: TSizeT; stats: PGitIndexerProgress): LongInt; cdecl; external 'c' name 'git_indexer_append';
function git_indexer_commit(idx: PGitIndexer; stats: PGitIndexerProgress): LongInt; cdecl; external 'c' name 'git_indexer_commit';
function git_indexer_hash(idx: PGitIndexer): PGitOid; cdecl; external 'c' name 'git_indexer_hash';
function git_indexer_name(idx: PGitIndexer): PAnsiChar; cdecl; external 'c' name 'git_indexer_name';
procedure git_indexer_free(idx: PGitIndexer); cdecl; external 'c' name 'git_indexer_free';
function git_odb_options_init(opts: PGitOdbOptions; version: LongWord): LongInt; cdecl; external 'c' name 'git_odb_options_init';
function git_odb_new(odb: PPGitOdb): LongInt; cdecl; external 'c' name 'git_odb_new';
function git_odb_new_ext(odb: PPGitOdb; opts: PGitOdbOptions): LongInt; cdecl; external 'c' name 'git_odb_new_ext';
function git_odb_open(odb_out: PPGitOdb; objects_dir: PAnsiChar): LongInt; cdecl; external 'c' name 'git_odb_open';
function git_odb_open_ext(odb_out: PPGitOdb; objects_dir: PAnsiChar; opts: PGitOdbOptions): LongInt; cdecl; external 'c' name 'git_odb_open_ext';
function git_odb_add_disk_alternate(odb: PGitOdb; path: PAnsiChar): LongInt; cdecl; external 'c' name 'git_odb_add_disk_alternate';
procedure git_odb_free(db: PGitOdb); cdecl; external 'c' name 'git_odb_free';
function git_odb_read(obj: PPGitOdbObject; db: PGitOdb; id: PGitOid): LongInt; cdecl; external 'c' name 'git_odb_read';

// Bridge inline helpers (single source 20-byte authority via libgit2.base.git_oid / native.base.TGitOid, bytes.ops SpanEqual/SpanCopy single source, inline zero-copy)
// perf: inline + zero-copy TByteSpan 20B SpanEqual via bytes.ops single source (~3×QWord MemEqual), no heap, converges with libgit2.base.GitOidEquals / native.base.GitOidSame ≤80ns
function BindingsGitOidEquals(const A, B: nextpas.core.git.libgit2.base.git_oid): Boolean; inline;
procedure BindingsGitOidCopy(out Dst: nextpas.core.git.libgit2.base.git_oid; const Src: nextpas.core.git.libgit2.base.git_oid); inline;

implementation
uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.ops;

function BindingsGitOidEquals(const A, B: nextpas.core.git.libgit2.base.git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy SpanEqual via bytes.ops single source, 20B -> ~3×QWord MemEqual, zero-copy TByteSpan view, no alloc, single source libgit2.base.GitOidEquals
  Result := SpanEqual(
    TByteSpan.Create(@A.id[0], GIT_OID_RAWSZ),
    TByteSpan.Create(@B.id[0], GIT_OID_RAWSZ));
end;
procedure BindingsGitOidCopy(out Dst: nextpas.core.git.libgit2.base.git_oid; const Src: nextpas.core.git.libgit2.base.git_oid); inline;
begin
  // perf: inline zero-copy SpanCopy via bytes.ops single source, 20B -> single Move, no heap, single source libgit2.base.GitOidCopy, try..finally safe
  SpanCopy(TByteSpan.Create(@Dst.id[0], GIT_OID_RAWSZ), TByteSpan.Create(@Src.id[0], GIT_OID_RAWSZ));
end;
end.

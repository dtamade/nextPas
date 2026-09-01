unit nextpas.core.git.libgit2.bindings.oid;
{$I nextpas.core.settings.inc}
{$PACKRECORDS C}
interface
uses
  nextpas.core.git.libgit2.bindings.types,
  nextpas.core.git.libgit2.bindings.structs;

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

// Bridge inline helpers (performance: inline + zero-copy TByteSpan/SpanEqual/Move, 20B ~3×QWord)
// Reuses bytes.ops single source (SpanEqual via MemEqual / Move) for byte ops
function BindingsGitOidEquals(const A, B: TGitOid): Boolean; inline;
procedure BindingsGitOidCopy(out Dst: TGitOid; const Src: TGitOid); inline;

implementation
uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.bytes.ops;

function BindingsGitOidEquals(const A, B: TGitOid): Boolean; inline;
begin
  { perf: inline + zero-copy TByteSpan 20B SpanEqual via bytes.ops single source (~3×QWord MemEqual), no &type branch, pure 20B authority, converges with GitOidSame benchmark }
  Result := SpanEqual(
    TByteSpan.Create(@A.id[0], 20),
    TByteSpan.Create(@B.id[0], 20));
end;
procedure BindingsGitOidCopy(out Dst: TGitOid; const Src: TGitOid); inline;
begin
  Dst.&type := Src.&type;
  // inline zero-copy: single Move, no heap, no SysUtils
  Move(Src.id[0], Dst.id[0], SizeOf(Src.id));
end;
end.

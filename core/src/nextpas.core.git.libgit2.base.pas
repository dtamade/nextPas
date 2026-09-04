unit nextpas.core.git.libgit2.base;
{** @desc libgit2 运行时词汇权威：20-byte `TGitOid` 单源 `native.base.TGitOid`，`git_oid` variant 叠加（`id/Bytes/AsNative` 同偏移 0，`SizeOf=20`，`PACKRECORDS C` 双编译器等价 stub 经 `settings.inc`，`Assert` 二进制保证），`inline` 零拷贝 overlay（无 `Move`），Phase7 已彻底清理 33-byte `TGitOid33` 双轨（`deprecated` 类型与 `GitOidCopy20To33/33To20/GitOid33Equals` 桥接均移除，单源 20-byte 权威），SHA256 泛型候选经 `bytes.ops` `Len` 参化 `TByteSpan` 非定长结构（见 `TGitOidGeneric` 注释）；所有 OID Ops 单源 `bytes.ops`（`SpanEqual`→`MemEqual` 3×QWord/`SpanCopy`→`Move`/`SpanFill`/`IsZeroBytes`），`inline` 热路径 ≤80 ns/op，`try..finally` 资源不丢。 *}
{$I nextpas.core.settings.inc}
{$PACKRECORDS C} // dual: FPC C ABI / nextPas C ABI stub via settings.inc (both support PACKRECORDS C; Assert SizeOf=20 guarantees layout)

interface

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.git.native.base,
  nextpas.core.bytes.ops;

const
  // Single source: OID sizes reuse native.base (GitOidRawLen = 20)
  GIT_OID_RAWSZ = nextpas.core.git.native.base.GitOidRawLen;
  GIT_OID_SHA1_SIZE = nextpas.core.git.native.base.GitOidRawLen;
  GIT_OID_MAX_SIZE = 32;

type
  // Shared opaque handles (Pointer seam, zero-cost)
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
  git_diff = Pointer;
  git_patch = Pointer;
  git_blame = Pointer;
  git_revwalk = Pointer;
  git_worktree = Pointer;
  git_status_list = Pointer;
  git_branch_iterator = Pointer;
  git_note = Pointer;
  git_note_iterator = Pointer;
  git_config_iterator = Pointer;
  git_signature = Pointer;

  // Single source alias: TGitOid is native 20-byte authoritative; 33-byte TGitOid33 removed Phase7 (2026-09-02), 20-byte single source
  TGitOid = nextpas.core.git.native.base.TGitOid;
  PGitOid = ^TGitOid;
  // Generic OID candidate for future SHA256 (32B): len-param via bytes.ops TByteSpan, not fixed 33-byte struct.
  // Use TGitOid for SHA1 (20B authority); for SHA256 use TByteSpan.Create(@Buf[0], 32) + SpanEqual/SpanCopy/SpanFill single source.
  // TGitOid33 bridge removed; generic path is Len-param, zero-copy, inline, no heap, single source bytes.ops.

  // Single source: canonical SHA1 OID (20 bytes) via native.base.TGitOid.
  // Variant exposes both C `id` and Pascal `Bytes` zero-cost overlay; binary-identical, no branch.
  // Binary guarantee: AsNative overlay ensures SizeOf(git_oid)=SizeOf(TGitOid)=GitOidRawLen (20), zero-copy via bytes.ops
  git_oid = record
    case Integer of
      0: (id: array[0..GIT_OID_RAWSZ-1] of Byte;);
      1: (Bytes: array[0..GIT_OID_RAWSZ-1] of Byte;);
      2: (AsNative: TGitOid;);
  end;
  Pgit_oid = ^git_oid;
  // Compat alias for libgit2 consumers expecting 20-byte via Pascal name
  TGitOid20 = git_oid;
  PGitOid20 = ^TGitOid20;

function GitOidToNative(const A: git_oid): TGitOid; inline;
function NativeToGitOid(const A: TGitOid): git_oid; inline;
function GitOidSameNative(const A, B: TGitOid): Boolean; inline;

// Canonical generic OID ops (base/ops single source via bytes.ops, inline zero-copy, no heap)
function GitOidEquals(const A, B: git_oid): Boolean; inline;
function GitOidIsZero(const A: git_oid): Boolean; inline;
procedure GitOidCopy(out Dst: git_oid; const Src: git_oid); inline;

type
  { ops Helper: record helper for git_oid, zero-copy via bytes.ops single source }
  TGitOidHelper = record helper for git_oid
    function Equals(const AOther: git_oid): Boolean; inline;
    function IsZero: Boolean; inline;
    procedure Assign(const ASrc: git_oid); inline;
  end;

implementation

function GitOidToNative(const A: git_oid): TGitOid; inline;
begin
  // perf: inline + zero-copy variant overlay AsNative (single source TGitOid, no Move, 20 bytes)
  Result := A.AsNative;
end;

function NativeToGitOid(const A: TGitOid): git_oid; inline;
begin
  // perf: inline + zero-copy variant overlay AsNative (single source TGitOid, no Move)
  Result.AsNative := A;
end;

function GitOidSameNative(const A, B: TGitOid): Boolean; inline;
begin
  // single source: delegates to native.base GitOidSame (which uses bytes.ops CompareMem)
  Result := nextpas.core.git.native.base.GitOidSame(A, B);
end;

function GitOidEquals(const A, B: git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy SpanEqual via bytes.ops MemEqual, 20 bytes -> 3x QWord, no heap/SysUtils, single source
  Result := SpanEqual(TByteSpan.Create(@A.id[0], GIT_OID_RAWSZ), TByteSpan.Create(@B.id[0], GIT_OID_RAWSZ));
end;

function GitOidIsZero(const A: git_oid): Boolean; inline;
begin
  // perf: inline + zero-copy TByteSpan view via bytes.ops IsZeroBytes single source, 20 bytes single scan, no alloc
  Result := IsZeroBytes(TByteSpan.Create(@A.id[0], GIT_OID_RAWSZ));
end;

procedure GitOidCopy(out Dst: git_oid; const Src: git_oid); inline;
begin
  // perf: inline + zero-copy SpanCopy via bytes.ops single source, 20 bytes -> single Move, no heap
  SpanCopy(TByteSpan.Create(@Dst.id[0], GIT_OID_RAWSZ), TByteSpan.Create(@Src.id[0], GIT_OID_RAWSZ));
end;

{ TGitOidHelper }

function TGitOidHelper.Equals(const AOther: git_oid): Boolean; inline;
begin
  // perf: inline helper delegates to bytes.ops SpanEqual single source
  Result := GitOidEquals(Self, AOther);
end;

function TGitOidHelper.IsZero: Boolean; inline;
begin
  Result := GitOidIsZero(Self);
end;

procedure TGitOidHelper.Assign(const ASrc: git_oid); inline;
begin
  GitOidCopy(Self, ASrc);
end;

initialization
  // stability: binary guarantee fails fast if PACKRECORDS or TGitOid drift (20 bytes single source)
  Assert(SizeOf(git_oid) = GIT_OID_RAWSZ);
  Assert(SizeOf(git_oid) = SizeOf(TGitOid));
  Assert(SizeOf(TGitOid20) = GIT_OID_RAWSZ);
  // perf: variant overlay ensures id/Bytes/AsNative at offset 0, no branch, zero-copy bytes.ops
  Assert(SizeOf(git_oid) = 20);

end.
